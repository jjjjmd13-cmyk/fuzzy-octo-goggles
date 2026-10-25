extends "res://tests/qa_test.gd"
## NET-03: 최대 4명. 클라이언트 4개가 동시에 접속하면 3개만 들어오고 1개(5번째)는 거절된다.
##
## 어느 클라이언트가 거절될지는 접속 순서에 달려 있어서, 클라이언트는 각자 결과에 맞는 쪽을 확인한다.
##   들어온 쪽: 호스트가 나갈 때까지 기다렸다가 메뉴 복귀 확인
##   거절된 쪽: 접속 제한 시간 안에 이유와 함께 메뉴로 돌아옴
## 호스트는 3명이 들어온 뒤 거절된 쪽이 끝날 만큼 기다리며 인원이 4명을 넘지 않는지 본다.

## 기획 기준 최대 인원 (GDD: 1~4인). Net.MAX_PLAYERS 를 쓰지 않는 건 그 값이 잘못 바뀌어도 잡으려고.
const MAX_PLAYERS := 4
const ACCEPTED_CLIENTS := MAX_PLAYERS - 1
## Net 접속 시간 초과(10초)보다 넉넉하게. 그동안 거절된 쪽이 결과를 낸다.
const REJECT_WAIT_SEC := 13.0

var _joined := {}


func run_test() -> void:
	get_tree().current_scene = null
	if role == "server":
		await _run_server()
	else:
		await _run_client()


func _run_server() -> void:
	Net.host_enet(port)
	await Net.session_started
	report_ready()
	var world := get_tree().current_scene
	var players := world.get_node("Players")
	var max_seen := 0
	var waited := 0.0
	while _joined.size() < ACCEPTED_CLIENTS or waited < REJECT_WAIT_SEC:
		max_seen = maxi(max_seen, players.get_child_count())
		if _joined.size() >= ACCEPTED_CLIENTS:
			waited += get_process_delta_time()
		await get_tree().process_frame
	check_eq(max_seen, MAX_PLAYERS, "최대 인원 (넘으면 안 됨)")
	check_eq(players.get_child_count(), MAX_PLAYERS, "끝까지 4명")
	check_eq(multiplayer.get_peers().size(), ACCEPTED_CLIENTS, "접속한 클라이언트 수")
	await Net.leave_session("테스트 종료")


func _run_client() -> void:
	Net.join_enet("127.0.0.1", port)
	var result: Array = await _first_of_start_or_end()
	if result[0] == "started":
		var world := get_tree().current_scene
		while world.get_player(multiplayer.get_unique_id()) == null:
			await get_tree().process_frame
		_report_joined.rpc_id(1)
		print("클라이언트: 들어옴 (ID %d)" % multiplayer.get_unique_id())
		await Net.session_ended
		check_eq(get_tree().current_scene.scene_file_path, Net.MENU_SCENE, "호스트가 나간 뒤 메뉴")
	else:
		var reason: String = result[1]
		print("클라이언트: 거절됨 (%s)" % reason)
		check(not reason.is_empty(), "거절 이유가 있음")
		check_eq(get_tree().current_scene.scene_file_path, Net.MENU_SCENE, "거절된 뒤 메뉴")


## session_started / session_ended 중 먼저 오는 쪽.
func _first_of_start_or_end() -> Array:
	var result := []
	var on_start := func() -> void: if result.is_empty(): result.append_array(["started", ""])
	var on_end := func(reason: String) -> void: if result.is_empty(): result.append_array(["ended", reason])
	Net.session_started.connect(on_start)
	Net.session_ended.connect(on_end)
	while result.is_empty():
		await get_tree().process_frame
	Net.session_started.disconnect(on_start)
	Net.session_ended.disconnect(on_end)
	return result


@rpc("any_peer", "reliable")
func _report_joined() -> void:
	_joined[multiplayer.get_remote_sender_id()] = true
