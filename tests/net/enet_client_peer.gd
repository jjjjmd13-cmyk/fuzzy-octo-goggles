extends Node
## test_enet_two_peers 의 클라이언트 쪽 (그 테스트가 별도 프로세스로 띄움, 혼자 실행하지 않음).
## 노드 이름이 서버 쪽 테스트 노드와 같아야 RPC 가 닿는다 (/root/NetTest).
## 성공하면 종료 코드 0, 실패하면 QA_TEST_FAIL 줄을 찍고 1.

const TIMEOUT_SEC := 50.0

var _port := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			_port = arg.trim_prefix("--port=").to_int()
	get_tree().current_scene = null
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_finish.bind(false, "시간 초과"))
	if _port <= 0:
		_finish(false, "--port=N 필요")
		return
	Net.join_enet("127.0.0.1", _port)
	await Net.session_started
	var my_id := multiplayer.get_unique_id()
	print("클라이언트: 접속됨, 내 ID %d" % my_id)

	var world := get_tree().current_scene
	var host_player: Node3D = await _wait_player(world, 1)
	var my_player: Node3D = await _wait_player(world, my_id)
	if not my_player.is_multiplayer_authority():
		_finish(false, "내 플레이어의 권한이 내게 없음")
		return
	# 내 캐릭터도 서버가 정한 자리(원점이 아님)에서 시작해야 한다.
	var expected: Vector3 = world.get_node("SpawnPoints").get_child(my_player.slot).position
	if my_player.slot != 1 or my_player.position.distance_to(expected) > 0.5:
		_finish(false, "내 플레이어 시작 위치/슬롯이 틀림: slot=%d pos=%s 기대 %s" % [my_player.slot, my_player.position, expected])
		return

	# V3: 걸어 다니지 않으므로 자리(seat) 바꾸기로 양방향 동기화를 확인한다.
	world.switch_seat()
	while host_player.seat != 1:
		await get_tree().process_frame
	print("클라이언트: 호스트 자리 바꿈 확인 (seat %d)" % host_player.seat)
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
	pass


func _wait_player(world: Node, peer_id: int) -> Node3D:
	while world.get_player(peer_id) == null:
		await get_tree().process_frame
	return world.get_player(peer_id)


func _finish(ok: bool, reason: String) -> void:
	if ok:
		print("클라이언트: 통과")
		get_tree().quit(0)
	else:
		print("QA_TEST_FAIL: 클라이언트: %s" % reason)
		get_tree().quit(1)
