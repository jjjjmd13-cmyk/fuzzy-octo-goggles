extends "res://tests/qa_test.gd"
## LEAVE-04: 호스트 프로세스가 갑자기 죽으면(강제 종료) 클라이언트가 무한 대기하지 않고 이유와 함께 메뉴로 돌아온다.
##
## 이 프로세스가 클라이언트다. 호스트는 enet_host_peer.tscn 을 자식 프로세스로 띄우고,
## 접속이 끝나면 OS.kill 로 죽인다 (TESTING.md B 방법).

const PORT := 24621
const HOST_SCENE := "res://tests/net/enet_host_peer.tscn"
const JOIN_ATTEMPTS := 5
## 호스트가 사라진 뒤 메뉴로 돌아오기까지 허용하는 시간
const MAX_DETECT_SEC := 40.0

var _host_pid := -1


func run_test() -> void:
	get_tree().current_scene = null
	_host_pid = OS.create_process(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"), HOST_SCENE, "--", "--port=%d" % PORT,
	])
	if not check(_host_pid > 0, "호스트 프로세스 실행"):
		return

	# 호스트가 뜨는 데 시간이 걸리므로 접속이 실패하면 몇 번 다시 시도한다.
	var joined := false
	for attempt in JOIN_ATTEMPTS:
		if not _host_alive():
			return
		Net.join_enet("127.0.0.1", PORT)
		var result: Array = await _first_of_start_or_end()
		if result[0] == "started":
			joined = true
			break
		print("클라이언트: 접속 재시도 (%s)" % result[1])
	if not check(joined, "호스트에 접속"):
		return
	var world := get_tree().current_scene
	while world.get_player(multiplayer.get_unique_id()) == null:
		if not _host_alive():
			return
		await get_tree().process_frame

	OS.kill(_host_pid)
	var killed_at := Time.get_ticks_msec()
	print("클라이언트: 호스트 강제 종료")
	var ended := []
	Net.session_ended.connect(func(reason: String) -> void: ended.append(reason), CONNECT_ONE_SHOT)
	while ended.is_empty() and (Time.get_ticks_msec() - killed_at) / 1000.0 < MAX_DETECT_SEC:
		await get_tree().process_frame
	var elapsed := (Time.get_ticks_msec() - killed_at) / 1000.0
	if not check(not ended.is_empty(), "호스트가 죽은 뒤 %.0f초 안에 세션이 끝남" % MAX_DETECT_SEC):
		return
	print("클라이언트: 호스트 끊김 감지까지 %.1f초 (%s)" % [elapsed, ended[0]])
	check(not String(ended[0]).is_empty(), "끊긴 이유가 있음")
	check_eq(get_tree().current_scene.scene_file_path, Net.MENU_SCENE, "메뉴로 돌아옴")


## 호스트가 (강제 종료 전에) 먼저 끝나 버렸으면 실패로 기록하고 false.
func _host_alive() -> bool:
	if OS.is_process_running(_host_pid):
		return true
	fail("호스트가 먼저 끝남 (종료 코드 %d)" % OS.get_process_exit_code(_host_pid))
	return false


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


func _exit_tree() -> void:
	if _host_pid > 0 and OS.is_process_running(_host_pid):
		OS.kill(_host_pid)
