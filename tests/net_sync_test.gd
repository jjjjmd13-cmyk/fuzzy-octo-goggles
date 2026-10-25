extends Node
## 헤드리스 네트워크 테스트: 서버 1 + 클라이언트 1 (ENet, 별도 프로세스 두 개).
## tests/run_tests.sh 가 두 프로세스를 띄운다.
##
## 확인하는 것:
##   1. 클라이언트 접속 → 서버가 스폰한 플레이어 2명이 양쪽에 모두 보임
##   2. 양쪽이 앞으로 걸으면 상대 화면에서도 위치가 바뀜 (양방향 동기화)
##   3. 호스트가 나가면 클라이언트가 메인 메뉴로 돌아감
## 성공하면 NET_TEST_SERVER_OK / NET_TEST_CLIENT_OK 를 출력하고 0 으로 끝난다.

const TIMEOUT_SEC := 30.0
const MIN_MOVE := 1.0

var _role := ""
var _port := 24600
var _client_ok := false
var _server_done := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
		elif arg.begins_with("--port="):
			_port = arg.trim_prefix("--port=").to_int()
	# Net 이 씬을 바꿀 때 이 노드는 남아 있어야 하므로 현재 씬에서 뺀다.
	get_tree().current_scene = null
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_finish.bind(false, "시간 초과"))
	match _role:
		"server":
			_run_server()
		"client":
			_run_client()
		_:
			_finish(false, "--role=server|client 필요")


func _run_server() -> void:
	Net.host_enet(_port)
	await Net.session_started
	print("NET_TEST_SERVER_LISTENING port=%d" % _port)
	var client_id: int = await Net.player_joined
	print("서버: 클라이언트 %d 접속" % client_id)

	var host_player := await _wait_player(1)
	var client_player := await _wait_player(client_id)
	var client_start := client_player.position
	Input.action_press("move_forward")
	while client_player.position.distance_to(client_start) < MIN_MOVE or not _client_ok:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	print("서버: 클라이언트 플레이어 이동 확인 %s → %s, 호스트 위치 %s" % [client_start, client_player.position, host_player.position])

	# 호스트가 나간다 → 클라이언트는 메뉴로 돌아가야 한다.
	_server_done = true
	await Net.leave_session("테스트 종료")
	for i in 10:
		await get_tree().process_frame
	_finish(true, "")


func _run_client() -> void:
	Net.join_enet("127.0.0.1", _port)
	await Net.session_started
	var my_id := multiplayer.get_unique_id()
	print("클라이언트: 접속됨, 내 ID %d" % my_id)

	var host_player := await _wait_player(1)
	var my_player := await _wait_player(my_id)
	if not my_player.is_multiplayer_authority():
		_finish(false, "내 플레이어의 권한이 내게 없음")
		return
	# 내 캐릭터도 서버가 정한 자리(원점이 아님)에서 시작해야 한다.
	var world := get_tree().current_scene
	var expected: Vector3 = world.get_node("SpawnPoints").get_child(my_player.slot).position
	if my_player.slot != 1 or my_player.position.distance_to(expected) > 0.5:
		_finish(false, "내 플레이어 시작 위치/슬롯이 틀림: slot=%d pos=%s 기대 %s" % [my_player.slot, my_player.position, expected])
		return
	var host_start := host_player.position
	Input.action_press("move_forward")
	while host_player.position.distance_to(host_start) < MIN_MOVE:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	print("클라이언트: 호스트 플레이어 이동 확인 %s → %s" % [host_start, host_player.position])
	_report_client_ok.rpc_id(1)

	var reason: String = await Net.session_ended
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != Net.MENU_SCENE:
		_finish(false, "호스트가 나간 뒤 메뉴로 돌아가지 않음")
		return
	print("클라이언트: 호스트 퇴장 → 메뉴 복귀 (%s)" % reason)
	_finish(true, "")


@rpc("any_peer", "reliable")
func _report_client_ok() -> void:
	_client_ok = true


func _wait_player(peer_id: int) -> Node3D:
	while true:
		var world := get_tree().current_scene
		if world != null and world.has_method("get_player"):
			var player: Node3D = world.get_player(peer_id)
			if player != null:
				return player
		await get_tree().process_frame
	return null


func _finish(ok: bool, reason: String) -> void:
	if ok:
		print("NET_TEST_%s_OK" % _role.to_upper())
		get_tree().quit(0)
	else:
		printerr("NET_TEST_%s_FAIL: %s" % [_role.to_upper(), reason])
		get_tree().quit(1)
