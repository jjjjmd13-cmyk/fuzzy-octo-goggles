extends "res://tests/qa_test.gd"
## 3일 진행 · 저장 (MILESTONE_V3_SLICE 5장):
## 영업이 끝나면 자동 저장 → 정산에서 산 것도 저장 → 메뉴로 나감 → 메뉴에 "이어하기 (2일차 아침부터)" →
## 이어하면 2일차 아침 화면, 돈·산 물건이 그대로 → 2·3일차 → 끝 화면(3일 합계, 다음에 열리는 것 잠긴 칸) →
## 메뉴로. 3일차를 끝낸 저장은 이어하기가 없다. 저장 파일은 시험용 경로를 쓴다.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const SaveGame := preload("res://scripts/core/save_game.gd")

var world: Node


func run_test() -> void:
	time_limit_sec = 120.0
	get_tree().root.size = Vector2i(1280, 800)
	var data: Resource = Tuning.data
	data.slice_guests_per_day = PackedInt32Array([1, 1, 1])
	data.proto_owner_arrive_time = 0.4
	data.owner_reaction_time = 0.4
	data.proto_owner_leave_time = 0.4
	SaveGame.path = "user://test_slice_save.json"
	SaveGame.erase()
	check(not SaveGame.can_continue(), "처음엔 이어하기 없음")

	# --- 1일차: 영업이 끝나면 자동 저장, 정산에서 산 것도 저장
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	_bind()
	await _finish_guest()
	await _wait(func() -> bool: return world.day.closed, world.day.FAST_FORWARD_TIME + 2.0)
	await _frames(2)
	var saved := SaveGame.read()
	check(not saved.is_empty() and int(saved.next_day) == 2, "영업이 끝나면 자동 저장 (다음 날 = 2) %s" % [saved])
	check_eq(int(saved.money), world.store.money, "저장된 돈")
	world.store.money = 200
	world.hud.buy_plant.pressed.emit()
	await _frames(2)
	saved = SaveGame.read()
	check(bool(saved.plant) and int(saved.money) == 200 - data.slice_price_plant, "정산 때 산 화분·남은 돈도 저장")
	var basic_left: int = world.store.basic_uses

	# --- 끄고 다시 켜기: 메뉴에 이어하기
	await Net.leave_session()
	await _frames(2)
	var menu: Node = get_tree().current_scene
	check(menu.continue_button.visible and menu.continue_button.text.contains("2일차"), "메뉴: 이어하기 (2일차 아침부터)")
	menu.continue_button.pressed.emit()
	await Net.session_started
	_bind()
	await _frames(3)
	check(world.day.morning and world.day.day == 2, "이어하기 → 2일차 아침 화면")
	check(world.hud.morning_panel.visible, "아침 화면이 보임")
	check(world.store.plant and world.store.money == 200 - data.slice_price_plant and world.store.basic_uses == basic_left, "돈·산 물건·남은 샴푸가 그대로")
	check_eq(world.day.total_served, 1, "3일 합계도 이어짐")
	world.day.send_open()
	await _frames(2)

	# --- 2·3일차 → 끝 화면
	for day_number in [2, 3]:
		check_eq(world.day.day, day_number, "%d일차" % day_number)
		await _finish_guest()
		await _wait(func() -> bool: return world.day.closed, world.day.FAST_FORWARD_TIME + 2.0)
		await _frames(2)
		if day_number < 3:
			world.day.send_next_day()
			await _frames(2)
			check(int(SaveGame.read().next_day) == 3, "다음 날을 누르면 저장 (3일차 아침)")
			world.day.send_open()
			await _frames(2)
	check(world.hud.settle_panel.visible and world.hud.end_button.visible, "3일차 정산 → 끝 버튼")
	world.hud.end_button.pressed.emit()
	await _frames(2)
	check(world.hud.end_panel.visible and not world.hud.settle_panel.visible, "끝 화면")
	check(_has_text(world.hud.end_panel, "체험판은 여기까지"), "끝 화면 문구: 체험판은 여기까지")
	check(world.hud.get_node_or_null("Confetti") != null and "clap" in world.sfx.played, "끝 화면 축하: 색종이 + 박수")
	check(world.hud.end_totals.text.contains("씻긴 손님 3명"), "3일 합계 (%s)" % world.hud.end_totals.text)
	check(_has_text(world.hud.end_panel, "잠김"), "다음에 열리는 것 잠긴 칸")
	check(bool(SaveGame.read().finished) and not SaveGame.can_continue(), "3일차를 끝낸 저장은 이어하기 없음")
	world.hud.end_menu_button.pressed.emit()
	await _wait(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.has_method("_continue"), 2.0)
	await _frames(2)
	check(not get_tree().current_scene.continue_button.visible, "메뉴로: 이어하기 버튼 없음")
	SaveGame.erase()
	SaveGame.path = "user://slice_save.json"


func _bind() -> void:
	world = get_tree().current_scene
	world.input_enabled = false


func _finish_guest() -> void:
	var station: WashStation = world.station
	await _wait(station.is_washing, 3.0)
	while station.stage < WashStation.Stage.PAY:
		station._advance()
		await _frames(1)
	await _wait(func() -> bool: return not station.coins.is_empty(), 1.0)
	var guard := 0
	while not station.coins.is_empty() and guard < 10:
		guard += 1
		station.send_collect(0)
		await _frames(2)
	await _wait(func() -> bool: return station.owner_phase == WashStation.OwnerPhase.EMPTY, 3.0)


func _has_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for child in node.get_children():
		if _has_text(child, text):
			return true
	return false


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(done: Callable, seconds: float) -> void:
	var left := seconds
	while not done.call() and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
