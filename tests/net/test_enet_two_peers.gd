extends "res://tests/qa_test.gd"
## ENet 서버 1 + 클라이언트 1 협동 테스트.
##
## 이 프로세스가 호스트가 되고, 클라이언트는 enet_client_peer.tscn 을 별도 Godot 프로세스로
## 띄운다. Net 은 루트 MultiplayerAPI 와 씬 전환을 그대로 쓰므로, 한 프로세스에 피어
## 두 개를 넣는 대신 실제 게임과 같은 경로로 시험한다. 클라이언트 출력도 같은 로그에 찍힌다.
##
## 확인하는 것:
##   1. 클라이언트 접속 → 양쪽에 플레이어 2명, 클라이언트 캐릭터는 정해진 자리에서 시작
##   2. 양쪽이 자리를 바꾸면 상대 화면에서도 자리가 바뀜 (양방향 동기화).
##      V3 는 걸어 다니지 않고 작업대 자리에 앉으므로, 위치 대신 자리(seat)로 확인한다.
##   3. 호스트가 나가면 클라이언트가 메뉴로 돌아감 (클라이언트 종료 코드로 확인)

const PORT := 24611
const CLIENT_SCENE := "res://tests/net/enet_client_peer.tscn"

var _client_pid := -1
var _client_ok := false
var _client_id := 0


func run_test() -> void:
	get_tree().current_scene = null
	Net.host_enet(PORT)
	await Net.session_started

	_client_pid = OS.create_process(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--", "--port=%d" % PORT,
	])
	if not check(_client_pid > 0, "클라이언트 프로세스 실행"):
		return
	Net.player_joined.connect(func(id: int) -> void: _client_id = id)
	while _client_id == 0:
		if not _client_alive():
			return
		await get_tree().process_frame
	var client_id := _client_id
	print("서버: 클라이언트 %d 접속" % client_id)

	var world := get_tree().current_scene
	var client_player: Node3D = await _wait_player(world, client_id)
	if client_player == null:
		return
	world.switch_seat()
	while not _client_ok or client_player.seat != 1:
		if not _client_alive() or not is_instance_valid(client_player):
			fail("클라이언트 플레이어가 중간에 사라짐")
			return
		await get_tree().process_frame
	print("서버: 클라이언트 자리 바꿈 확인 (seat %d)" % client_player.seat)

	# 호스트가 나간다 → 클라이언트는 메뉴로 돌아가서 종료 코드 0 으로 끝나야 한다.
	await Net.leave_session("테스트 종료")
	while OS.is_process_running(_client_pid):
		await get_tree().process_frame
	check_eq(OS.get_process_exit_code(_client_pid), 0, "클라이언트 쪽 검사 결과(종료 코드)")


@rpc("any_peer", "reliable")
func _report_client_ok() -> void:
	_client_ok = true


func _wait_player(world: Node, peer_id: int) -> Node3D:
	while world.get_player(peer_id) == null:
		if not _client_alive():
			return null
		await get_tree().process_frame
	return world.get_player(peer_id)


## 클라이언트가 먼저 끝나 버렸으면 실패로 기록하고 false.
func _client_alive() -> bool:
	if OS.is_process_running(_client_pid):
		return true
	fail("클라이언트가 먼저 끝남 (종료 코드 %d)" % OS.get_process_exit_code(_client_pid))
	return false


func _exit_tree() -> void:
	if _client_pid > 0 and OS.is_process_running(_client_pid):
		OS.kill(_client_pid)
