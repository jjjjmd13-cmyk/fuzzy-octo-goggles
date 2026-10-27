extends "res://tests/qa_test.gd"
## 정산 → 쇼핑 → 다음 날 (MILESTONE_V3_SLICE 4장):
## 영업이 끝나면 정산 화면(씻긴·떠난 손님, 요금 + 팁, 가장 기뻐한 손님 얼굴) → 컴퓨터 쇼핑 4칸
## (샴푸 2 · 넓은 샤워기 · 창가 화분, 산 것이 눈에 보이고 효과가 있음) → "다음 날" → 아침 화면(새로 열린 것) → 영업 시작.
## 하루를 짧게 하려고 손님 수·영업 시간을 시험 안에서만 줄인다.

const WashStation := preload("res://scripts/sim/wash_station.gd")

var world: Node
var station: WashStation
var day: Node
var store: Node
var hud: CanvasLayer


func run_test() -> void:
	time_limit_sec = 90.0
	get_tree().root.size = Vector2i(1280, 800)
	var data: Resource = Tuning.data
	data.slice_guests_per_day = PackedInt32Array([1, 1, 1])
	data.day_open_minutes_real = 0.5
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	world.input_enabled = false
	station = world.station
	day = world.day
	store = world.store
	hud = world.hud

	# --- 1일차 손님 한 명을 씻겨 보내면 정산
	await _finish_guest()
	await _wait(func() -> bool: return day.closed, day.FAST_FORWARD_TIME + 2.0)
	await _frames(2)
	check(day.closed and hud.settle_panel.visible, "영업이 끝나면 정산 화면")
	check(hud.settle_stats.text.contains("씻긴 손님 1명") and hud.settle_stats.text.contains("떠난 손님 0명"), "정산: 손님 수 (%s)" % hud.settle_stats.text)
	check(hud.settle_stats.text.contains("요금 %d" % data.money_wash_price), "정산: 요금 + 팁 나눠서")
	check(day.earned >= data.money_wash_price and day.earned - day.tips == data.money_wash_price, "번 돈 = 요금 %d + 팁 %d" % [day.earned - day.tips, day.tips])
	check(hud.settle_face.visible and hud.settle_best.text.contains("강아지"), "오늘 가장 기뻐한 손님 얼굴")
	check(hud.is_menu_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "정산 화면에선 마우스 커서가 보임")
	check(hud.next_day_button.visible and not hud.settle_end_label.visible, "1일차엔 다음 날 버튼")

	# --- 컴퓨터 쇼핑: 4칸, 업그레이드·꾸미기는 한 번만
	hud.settle_shop_button.pressed.emit()
	await _wait(func() -> bool: return world.local_seat() == 1, 1.0)
	await _frames(2)
	check(hud.shop_panel.visible and not hud.settle_panel.visible, "쇼핑하기 → 컴퓨터 자리")
	check_eq(hud.shop_panel.get_node("Box/Grid").get_child_count(), 4, "쇼핑 화면 4칸 (탭 없음)")
	check(hud.shop_next_day.visible, "컴퓨터 자리에도 다음 날 버튼")
	store.money = data.slice_price_wide_shower + data.slice_price_plant
	var radius_before: float = station.shower_radius()
	var patience_before: float = day.patience()
	hud.buy_wide_shower.pressed.emit()
	hud.buy_plant.pressed.emit()
	await _frames(2)
	check(store.wide_shower and store.plant and store.money == 0, "넓은 샤워기·창가 화분을 삼")
	check(is_equal_approx(station.shower_radius(), radius_before * data.slice_wide_shower_mult), "넓은 샤워기: 붓 반경 ×%.1f" % data.slice_wide_shower_mult)
	check(is_equal_approx(day.patience(), patience_before * data.slice_plant_patience_mult), "창가 화분: 참을성 ×%.1f" % data.slice_plant_patience_mult)
	check(station.plant.visible, "산 화분이 가게에 놓임")
	store.money = 1000
	await _frames(2)
	check(hud.buy_wide_shower.disabled and hud.buy_wide_shower.text.contains("샀어요"), "업그레이드는 한 번만")

	# --- 다음 날 → 아침 화면 (새로 열린 것) → 영업 시작
	hud.shop_next_day.pressed.emit()
	await _frames(3)
	check(day.morning and day.day == 2, "다음 날 아침")
	check(hud.morning_panel.visible and hud.morning_news.text.contains("고양이"), "아침 화면: 고양이 손님이 오기 시작 (%s)" % hud.morning_news.text)
	check(not hud.shop_panel.visible, "아침엔 쇼핑 화면을 가림")
	hud.open_button.pressed.emit()
	await _frames(3)
	check(not day.morning and not day.closed and day.served == 0, "영업 시작: 새 날 (2일차)")
	check(station.owner_phase == WashStation.OwnerPhase.ARRIVE, "2일차 첫 손님이 들어옴")
	check(store.wide_shower and station.plant.visible, "산 것은 다음 날에도 그대로")

	# --- 마지막 날 정산엔 다음 날이 없음
	day.day = data.slice_days
	await _finish_guest()
	await _wait(func() -> bool: return day.closed, day.FAST_FORWARD_TIME + 2.0)
	world.switch_seat()
	await _wait(func() -> bool: return world.local_seat() == 0, 1.0)
	await _frames(3)
	check(hud.settle_panel.visible and hud.settle_end_label.visible and not hud.next_day_button.visible, "3일차 정산 뒤엔 '여기까지' (다음 날 없음)")
	day.send_next_day()
	await _frames(2)
	check_eq(day.day, data.slice_days, "마지막 날 뒤로는 넘어가지 않음")


func _finish_guest() -> void:
	await _wait(station.is_washing, Tuning.data.proto_owner_arrive_time + 2.0)
	while station.stage < WashStation.Stage.PAY:
		station._advance()
		await _frames(1)
	await _wait(func() -> bool: return not station.coins.is_empty(), 1.0)
	var guard := 0
	while not station.coins.is_empty() and guard < 10:
		guard += 1
		station.send_collect(0)
		await _frames(2)
	await _wait(func() -> bool: return station.owner_phase == WashStation.OwnerPhase.EMPTY, Tuning.data.owner_reaction_time + Tuning.data.proto_owner_leave_time + 2.0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(done: Callable, seconds: float) -> void:
	var left := seconds
	while not done.call() and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
