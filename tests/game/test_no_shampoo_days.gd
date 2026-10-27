extends "res://tests/qa_test.gd"
## 막힘 0건 (MILESTONE_V3_SLICE 9장, 기획 #54 검토): 샴푸를 한 번도 사지 않고 1~3일차 손님을 모두 끝까지.
## 시작 샴푸 8마리분 < 손님 4 + 5 + 6. 샴푸가 떨어지면 물로만 씻고(기분 −) 진행은 계속된다.
## 정산 화면엔 "남은 샴푸 / 내일 손님" 이 보이고 모자라면 빨갛게.
## 시간을 줄이려고 주인 걷기·반응 시간과 영업 시간을 시험 안에서만 줄이고, 단계는 바로 넘긴다
## (샴푸 짜기는 실제 요청 경로 _request_dose 로).

const WashStation := preload("res://scripts/sim/wash_station.gd")

var world: Node
var station: WashStation
var day: Node
var store: Node
var hud: CanvasLayer
var _water_only := 0


func run_test() -> void:
	time_limit_sec = 200.0
	get_tree().root.size = Vector2i(1280, 800)
	var data: Resource = Tuning.data
	data.proto_owner_arrive_time = 0.4
	data.owner_reaction_time = 0.4
	data.proto_owner_leave_time = 0.4
	data.day_open_minutes_real = 2.0
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	world.input_enabled = false
	station = world.station
	day = world.day
	store = world.store
	hud = world.hud
	var start_shampoo: int = store.basic_uses + store.peach_uses

	for day_number in range(1, data.slice_days + 1):
		check_eq(day.day, day_number, "%d일차" % day_number)
		for i in day.guests_today():
			await _finish_guest()
		await _wait(func() -> bool: return day.closed, day.FAST_FORWARD_TIME + 3.0)
		check(day.closed, "%d일차 끝까지 (샴푸 안 삼)" % day_number)
		check_eq(day.served, day.guests_today(), "%d일차 손님 모두 씻김" % day_number)
		await _frames(2)
		if day_number < data.slice_days:
			check(hud.settle_supply.visible and hud.settle_supply.text.contains("내일 손님 %d명" % day.guests_on(day_number + 1)), "정산: 남은 샴푸 / 내일 손님 (%s)" % hud.settle_supply.text)
			if store.basic_uses + store.peach_uses < day.guests_on(day_number + 1):
				check(hud.settle_supply.text.contains("모자라요"), "샴푸가 모자라면 빨갛게 알림")
			day.send_next_day()
			await _frames(2)
			day.send_open()
			await _frames(2)
	var total: int = 0
	for n in range(1, data.slice_days + 1):
		total += day.guests_on(n)
	check(_water_only == total - start_shampoo, "샴푸 %d마리분을 다 쓴 뒤 %d명은 물로만 씻음" % [start_shampoo, _water_only])
	check_eq(store.basic_uses + store.peach_uses, 0, "샴푸를 다 씀")


func _finish_guest() -> void:
	await _wait(station.is_washing, Tuning.data.proto_owner_arrive_time + 3.0)
	station._advance()
	await _frames(1)
	# 샴푸 짜기: 실제 요청 경로 (호스트가 병에서 한 마리분을 쓰거나, 없으면 물로만)
	station._request_dose.rpc_id(1, station.dog_info.x, 1)
	await _frames(2)
	if station.out_of_shampoo:
		_water_only += 1
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


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(done: Callable, seconds: float) -> void:
	var left := seconds
	while not done.call() and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
