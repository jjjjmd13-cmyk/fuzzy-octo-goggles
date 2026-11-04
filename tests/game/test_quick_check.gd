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
	quick.queue_free()
	await get_tree().process_frame

	# 수건 빠른 확인: 헹굼까지 끝난 강아지, 톡톡
	Engine.set_meta("quick_check_feature", "towel")
	quick = load(QUICK_SCENE).instantiate()
	add_child(quick)
	shop = quick.shop
	shop.input_enabled = false
	shop.guests._process(1.5)
	shop.next_guest()
	await get_tree().physics_frame
	check_eq(shop.stage_tool(), "towel", "수건: 바로 수건 단계")
	shop.pick("towel")
	for i in 80:
		shop.tap_at(shop.dog.model.to_global(shop.dog._body_center() + Vector3(cos(i * 0.9), 0.3 * sin(i * 0.4), sin(i * 0.9)) * 0.3))
	check_eq(shop.stage_tool(), "dryer", "톡톡 다 닦으면 드라이 단계 (%s)" % str(shop.progress()))
	quick.queue_free()
	await get_tree().process_frame

	# 드라이기 빠른 확인: 헹굼까지 끝난 강아지, 드라이기만 하면 끝
	Engine.set_meta("quick_check_feature", "dryer")
	quick = load(QUICK_SCENE).instantiate()
	add_child(quick)
	shop = quick.shop
	shop.input_enabled = false
	shop.guests._process(1.5)
	shop.next_guest()
	check(shop.has_dog, "드라이기 확인: 강아지 맡김")
	check_eq(shop.stage_tool(), "dryer", "바로 드라이 단계")
	check(shop.dog.mask.ratio("scrub") >= 0.99 and shop.dog.foam_count() == 0, "적시기·거품·헹굼은 끝난 상태")
	check(shop._hint.contains("드라이기"), "드라이기를 집으라는 글 (%s)" % shop._hint)
	shop.pick("dryer")
	for i in 200:
		var p: Vector3 = shop.dog.model.to_global(shop.dog._body_center() + Vector3(cos(i * 0.7), 0.4 * sin(i * 0.3), sin(i * 0.7)) * 0.3)
		shop.use_tool_at(p, 1.0 / 30.0)
		if shop.done:
			break
	check_eq(shop.stage_tool(), "brush", "드라이 뒤엔 빗질 (%s)" % str(shop.progress()))
	check(shop.dog.fluff > 0.9, "털 뽕")
	quick.queue_free()
	await get_tree().process_frame

	# 빗질 빠른 확인: 드라이까지 끝난 강아지, 엉킨 뭉치만 풀면 끝
	Engine.set_meta("quick_check_feature", "brush")
	quick = load(QUICK_SCENE).instantiate()
	add_child(quick)
	shop = quick.shop
	shop.input_enabled = false
	shop.guests._process(1.5)
	shop.next_guest()
	await get_tree().physics_frame
	check_eq(shop.stage_tool(), "brush", "빗질: 바로 빗질 단계")
	check(shop.progress().tangles > 0, "엉킨 뭉치가 보임 (%d)" % shop.progress().tangles)
	shop.pick("brush")
	# 빗질은 뭉치에 대고 위 → 아래로 쓸기 (대고만 있으면 아주 느림)
	for pos in shop.tangles.world_positions():
		for k in 30:
			shop.use_tool_at(pos + Vector3(0, 0.05 - (k % 10) * 0.01, 0), 1.0 / 30.0)
	check(shop.done, "뭉치를 다 풀면 끝 (%s)" % str(shop.progress()))
	quick.queue_free()
	await get_tree().process_frame

	# 도구 업그레이드 빠른 확인: 가장 좋은 도구를 산 상태
	Engine.set_meta("quick_check_feature", "upgrade")
	quick = load(QUICK_SCENE).instantiate()
	add_child(quick)
	shop = quick.shop
	for tool_id in shop.tool_level:
		check_eq(shop.next_price(tool_id), -1, "업그레이드 확인: %s 가 최고 단계 (%s)" % [tool_id, shop.tool_name(tool_id)])
	check_eq(shop.money, 0, "산 값은 미리 채워서 돈은 0")
	quick.queue_free()
	await get_tree().process_frame

	# 미용 빠른 확인: 가위 있음, 곰돌이컷 요청, 바로 미용 단계
	Engine.set_meta("quick_check_feature", "trim")
	quick = load(QUICK_SCENE).instantiate()
	add_child(quick)
	shop = quick.shop
	shop.input_enabled = false
	shop.guests._process(1.5)
	shop.next_guest()
	await get_tree().physics_frame
	check(shop.owns_scissors and shop._pickups.scissors.visible, "미용: 가위가 선반에")
	check_eq(shop.trim_request, "bear", "미용: 곰돌이컷 요청")
	check_eq(shop.stage_tool(), "scissors", "미용: 바로 가위 단계")
	check_eq(shop.progress().tangles, 0, "미용: 빗질은 끝난 상태")
	check(shop.trim.wanted_total() > 0, "미용: 자를 곳 다발")
	Engine.remove_meta("quick_check_feature")
