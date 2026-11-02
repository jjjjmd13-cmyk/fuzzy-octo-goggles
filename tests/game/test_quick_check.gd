extends "res://tests/qa_test.gd"
## 빠른 확인 (개발용): 메뉴에 기능별 버튼, 누르면 손님이 바로 대기 (참을성·벽시계 끔),
## 강아지를 다 돌려주면 "확인 끝! 새로 들어간 것: …". 출시 프리셋은 dev 폴더를 뺀다.

const MENU_SCENE := preload("res://scenes/menu/main_menu.tscn")
const QUICK_SCENE := "res://scenes/dev/quick_check.tscn"


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)

	# 메뉴: 기능마다 버튼
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var button := menu.find_child("Quick_day", true, false) as Button
	check(button != null and button.is_visible_in_tree(), "메뉴에 빠른 확인 [하루 돌리기] 버튼")
	menu.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().process_frame

	# 출시 프리셋은 dev 폴더를 뺌 (테스트 빌드 프리셋은 그대로)
	var presets := ConfigFile.new()
	check_eq(presets.load("res://export_presets.cfg"), OK, "export_presets.cfg 읽음")
	var release := 0
	for section in presets.get_sections():
		if not section.ends_with("]") and presets.has_section_key(section, "name"):
			var preset_name: String = presets.get_value(section, "name")
			var excluded: String = presets.get_value(section, "exclude_filter", "")
			if preset_name.contains("Steam Release"):
				release += 1
				check(excluded.contains("scenes/dev/*") and excluded.contains("scripts/dev/*"), "%s 는 dev 폴더 제외" % preset_name)
	check_eq(release, 2, "스팀 출시 프리셋 2개 (Windows·Linux)")

	# 하루 돌리기 빠른 확인: 강아지 2마리
	Engine.set_meta("quick_check_feature", "day")
	var quick: Node = load(QUICK_SCENE).instantiate()
	add_child(quick)
	var shop: Node3D = quick.shop
	shop.input_enabled = false
	var guests: Node3D = shop.guests
	check(guests.quick, "참을성 끔")
	guests._process(1.5)
	check_eq(guests.guests.size(), 1, "바로 손님 1명 대기")
	guests._process(1000.0)
	check_eq(guests.left_count, 0, "빠른 확인에선 손님이 안 떠남")
	for i in 2:
		guests._process(3.0)
		shop.next_guest()
		check(shop.has_dog, "%d번째 강아지 맡김" % (i + 1))
		shop.done = true
		shop.next_guest()
	guests._process(60.0)
	check_eq(guests.guests.size(), 0, "강아지 2마리 뒤엔 손님이 더 안 옴")
	check_eq(guests.served, 2, "2마리 돌려줌")
	shop._update_day(0.1)
	check(shop.day_over, "2마리 다 돌려주면 끝")
	var done_panel := quick.find_child("QuickDone", true, false)
	check(done_panel != null, "확인 끝 화면")
	if done_panel != null:
		check(done_panel.summary_text.contains("새로 들어간 것: 하루 돌리기"), "새로 들어간 것 (%s)" % done_panel.summary_text)
	Engine.remove_meta("quick_check_feature")
