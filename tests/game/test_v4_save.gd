extends "res://tests/qa_test.gd"
## V4 저장·이어하기 (사람 대표 순서 2): 하루가 끝나면(정산)·정산 판에서 사면·[다음 날] 을 누르면 저장.
## 저장 항목: 돈 · 날짜 · 도구 단계 · 가위 · 남은 샴푸 · 빗 닳음 · 꾸미기 · 아직 안 들인 택배 상자.
## 메뉴 "V4 이어하기" 로 다시 열면 그날 처음부터 같은 상태. 빠른 확인은 저장하지 않음. 깨진 파일은 무시.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const MENU_SCENE := preload("res://scenes/menu/main_menu.tscn")
const V4Save := preload("res://scripts/v4/v4_save.gd")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	var real_path := V4Save.path
	V4Save.path = "user://test_v4_save.json"
	V4Save.erase()
	check(not V4Save.can_continue(), "저장이 없으면 이어하기 없음")

	# 1일차: 상태를 만들고 하루 끝 → 저장 (다음에 시작할 날 = 2)
	shop = await _open_shop(false)
	check_eq(shop.shampoo_left, float(Tuning.data.v4_shampoo_start), "처음 샴푸 %d마리분" % Tuning.data.v4_shampoo_start)
	shop.money = 2000
	check(shop.buy("shower") and shop.buy("shower") and shop.buy("brush") and shop.buy("scissors"), "샤워기 3단계·빗 2단계·가위 사기")
	shop.set_tier("dryer", 4)
	shop.shampoo_left = 6.25
	shop.brush_used = 9
	shop.decor = {"owned": ["plant_round", "rug_paw"], "placed": {"plant": "plant_round"}}
	shop.parcels = [{"item": "shampoo_bottle", "kind": "shampoo", "size": "small", "arrived": true}, {"item": "rug_paw", "kind": "decor", "size": "medium", "arrived": true}]
	var money: int = shop.money
	shop.end_day()
	var saved := V4Save.read()
	check(not saved.is_empty(), "하루가 끝나면 저장됨")
	check_eq(saved.next_day, 2, "이어하면 2일차부터")
	check_eq(saved.money, money, "가진 돈")
	check_eq(saved.tool_level, {"shower": 2, "shampoo": 0, "towel": 0, "dryer": 4, "brush": 1}, "도구 단계")
	check(saved.owns_scissors, "가위")
	check_eq(saved.shampoo_left, 6.25, "남은 샴푸 (소수 그대로)")
	check_eq(saved.brush_used, 9, "빗 닳음")
	check_eq(saved.decor, {"owned": ["plant_round", "rug_paw"], "placed": {"plant": "plant_round"}}, "꾸미기 (산 것·놓인 것)")
	check_eq(saved.parcels.size(), 2, "아직 안 들인 택배 상자 2개")
	check_eq(saved.parcels[1], {"item": "rug_paw", "kind": "decor", "size": "medium", "arrived": true}, "상자 내용·크기·도착")

	# 정산 판에서 사면 바로 저장
	shop._settle.buy_requested.emit("towel")
	check_eq(V4Save.read().parcels[-1], {"item": "tool:towel", "kind": "tool", "size": "small", "arrived": false}, "정산 판에서 산 수건은 내일 아침 올 상자로 저장됨")
	check_eq(V4Save.read().money, shop.money, "산 뒤의 돈이 저장됨")
	# [다음 날] → 2일차 시작에 저장 (영업 중에 끄면 2일차 처음부터)
	shop._settle.next_day_requested.emit()
	check_eq(shop.day, 2, "2일차")
	check_eq(V4Save.read().next_day, 2, "다음 날을 누르면 그날부터 이어하기")
	var expect: Dictionary = shop.save_state(2)
	shop.free()

	# 메뉴: "V4 이어하기 (2일차부터)"
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	var button := menu.find_child("V4ContinueButton", true, false) as Button
	check(button != null and button.visible, "메뉴에 V4 이어하기 버튼")
	if button != null:
		check(button.text.contains("2일차"), "버튼에 이어할 날 (%s)" % button.text)
	menu.free()

	# 이어하기: 같은 상태로 2일차 처음부터
	V4Save.continue_requested = true
	shop = await _open_shop(false)
	check(not V4Save.continue_requested, "이어하기 표시는 한 번 쓰고 지움")
	check_eq(shop.save_state(2), expect, "이어한 상태가 저장 전과 같음")
	check_eq(shop.day, 2, "2일차부터")
	check_eq(shop.tool_name("shower"), shop.TOOL_LEVEL_NAMES.shower[2], "선반 샤워기 3단계 (%s)" % shop.tool_name("shower"))
	check(shop.owns_scissors and shop._pickups.scissors.visible, "가위가 선반에")
	check(is_equal_approx(shop.guests.trim_chance, Tuning.data.v4_trim_request_ratio), "가위가 있으니 미용 요청 손님")
	check(shop._hint.contains("택배 상자 2개"), "밖에 남은 상자 안내 (%s)" % shop._hint)
	shop.free()

	# 빠른 확인은 저장하지 않음 (진짜 저장 파일 그대로)
	var before := FileAccess.get_file_as_string(V4Save.path)
	shop = await _open_shop(true)
	shop.money = 9999
	shop.end_day()
	check_eq(FileAccess.get_file_as_string(V4Save.path), before, "빠른 확인은 저장 안 함")
	shop.free()
	# 빠른 확인 [저장·이어하기]: 예시를 따로 된 파일로 쓰고 읽어 시작
	shop = SCENE.instantiate()
	shop.input_enabled = false
	shop.quick_dogs = 1
	shop.quick_feature = "save"
	add_child(shop)
	await get_tree().physics_frame
	check_eq(shop.day, 4, "빠른 확인 [저장·이어하기]: 4일차")
	check_eq(shop.money, 620, "돈 620")
	check_eq(shop.tool_level.brush, 4, "빗 5단계")
	check_eq(shop.parcels.size(), 2, "택배 상자 2개")
	check_eq(FileAccess.get_file_as_string(V4Save.path), before, "진짜 저장 파일은 안 건드림")
	check(not FileAccess.file_exists("user://v4_quick_save.json"), "빠른 확인 파일은 지움")
	shop.free()

	# 깨진 파일·다른 버전·빠진 키
	_write_raw("{ 깨짐")
	check(V4Save.read().is_empty() and not V4Save.can_continue(), "깨진 파일은 무시")
	_write_raw(JSON.stringify({"version": V4Save.VERSION + 1, "money": 5}))
	check(V4Save.read().is_empty(), "다른 버전은 무시")
	_write_raw(JSON.stringify({"version": V4Save.VERSION, "next_day": 3, "money": 50, "tool_level": {"shower": 99, "comb": 2}}))
	var partial := V4Save.read()
	check_eq(partial.next_day, 3, "빠진 키가 있어도 읽음")
	check_eq(partial.tool_level.shower, Tuning.data.v4_tool_tiers - 1, "넘친 단계는 최종 단계로")
	check(not partial.tool_level.has("comb"), "모르는 도구는 버림")
	check_eq(partial.shampoo_left, float(Tuning.data.v4_shampoo_start), "빠진 샴푸는 처음 값")
	check_eq(partial.parcels, [], "빠진 상자는 없음")

	V4Save.erase()
	V4Save.path = real_path


func _open_shop(quick: bool) -> Node3D:
	var opened: Node3D = SCENE.instantiate()
	opened.input_enabled = false
	if quick:
		opened.quick_dogs = 1
		opened.quick_feature = "day"
	add_child(opened)
	opened.guests._opening.clear()
	opened.guests._spawn_left = 1e9
	for i in 3:
		await get_tree().physics_frame
	return opened


func _write_raw(text: String) -> void:
	var file := FileAccess.open(V4Save.path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
