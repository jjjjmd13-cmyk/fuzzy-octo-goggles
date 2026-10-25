extends "res://tests/qa_test.gd"
## 서버가 없는 주소로 접속하면 멈추지 않고 이유와 함께 메뉴로 돌아온다 (Net 접속 시간 초과 10초).

## 아무도 열지 않는 포트 (TESTING.md B 방법 포트 범위)
const PORT := 24631
const MAX_WAIT_SEC := 15.0


func run_test() -> void:
	get_tree().current_scene = null
	var started := Time.get_ticks_msec()
	var on_start := func() -> void: fail("서버가 없는데 접속됨")
	Net.session_started.connect(on_start)
	Net.join_enet("127.0.0.1", PORT)
	var reason: String = await Net.session_ended
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("접속 실패까지 %.1f초: %s" % [elapsed, reason])
	check(not reason.is_empty(), "실패 이유가 있음")
	check(elapsed <= MAX_WAIT_SEC, "%.0f초 안에 메뉴로 (실제 %.1f초)" % [MAX_WAIT_SEC, elapsed])
	check_eq(get_tree().current_scene.scene_file_path, Net.MENU_SCENE, "메뉴로 돌아옴")
	check_eq(Net.last_end_reason, reason, "메뉴에 보여 줄 이유")
