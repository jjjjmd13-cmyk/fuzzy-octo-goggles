extends "res://tests/qa_test.gd"
## LEAVE-01: 클라이언트가 정상적으로 나가면 호스트에서 그 캐릭터가 사라지고, 호스트는 게임을 계속한다.


func run_test() -> void:
	# Net 이 씬을 바꿀 때 이 노드는 남아 있어야 하므로 현재 씬에서 뺀다.
	get_tree().current_scene = null
	if role == "server":
		await _run_server()
	else:
		await _run_client()


func _run_server() -> void:
	Net.host_enet(port)
	await Net.session_started
	report_ready()
	var client_id: int = await Net.player_joined
	var world := get_tree().current_scene
	while world.get_player(client_id) == null:
		await get_tree().process_frame

	var left_id: int = await Net.player_left
	check_eq(left_id, client_id, "나간 피어 ID")
	# 호스트가 캐릭터를 지우는 데 몇 프레임 걸릴 수 있다.
	for i in 10:
		await get_tree().process_frame
	check(world.get_player(client_id) == null, "나간 클라이언트의 캐릭터가 호스트에서 사라짐")
	check_eq(world.get_node("Players").get_child_count(), 1, "남은 플레이어 수")
	check(get_tree().current_scene == world and Net.is_in_session(), "호스트는 게임을 계속함 (월드·세션 유지)")
	check(world.get_player(1) != null, "호스트 캐릭터는 그대로")
	await Net.leave_session("테스트 종료")


func _run_client() -> void:
	Net.join_enet("127.0.0.1", port)
	await Net.session_started
	var world := get_tree().current_scene
	while world.get_node("Players").get_child_count() < 2:
		await get_tree().process_frame
	# 일시 메뉴의 "메뉴로 나가기" 와 같은 경로
	await Net.leave_session()
	check_eq(get_tree().current_scene.scene_file_path, Net.MENU_SCENE, "나간 클라이언트는 메뉴")
	# 호스트가 접속 끊김을 처리할 시간을 준 뒤 끝낸다.
	await get_tree().create_timer(1.0).timeout
