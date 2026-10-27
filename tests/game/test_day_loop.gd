extends "res://tests/qa_test.gd"
## 하루 영업 (MILESTONE_V3_SLICE 1장): 벽시계, 차례로 오는 손님, 대기 의자·기다림 몸짓, 기다리다 떠남,
## 대기 손님이 목욕대로, 6시 뒤 새 손님 없음, 영업 끝.
## 시간을 줄이려고 영업 시간·참을성 수치를 시험 안에서만 줄인다. 씻기는 단계를 바로 넘긴다 (손동작은 test_wash_flow).

const WashStation := preload("res://scripts/sim/wash_station.gd")

var world: Node
var station: WashStation
var day: Node
var sfx: Node


func run_test() -> void:
	time_limit_sec = 120.0
	get_tree().root.size = Vector2i(1280, 800)
	var data: Resource = Tuning.data
	# 1분 영업: 손님 4명이 약 13초 간격 (마지막 손님까지 받아도 6시 전에 끝나서 "빨리 돌리기"를 봄)
	data.day_open_minutes_real = 1.0
	data.slice_owner_patience = 5.0
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	world.input_enabled = false
	station = world.station
	day = world.day
	sfx = world.sfx

	# --- 1일차: 첫 손님은 바로 (이슈 #40)
	await _frames(2)
	check_eq(day.day, 1, "1일차")
	check_eq(day.guests_today(), data.slice_guests_per_day[0], "1일차 손님 수")
	check_eq(station.dog_number(), 1, "첫 손님이 바로 옴")
	check_eq(station.owner_phase, WashStation.OwnerPhase.ARRIVE, "주인이 문으로 들어옴")
	check("bell" in sfx.played, "문 종 딸랑")
	check(not world.hud.get_node("Card").visible, "맡기기 전엔 요청 카드가 없음 (말풍선만)")
	await _wait(station.is_washing, data.proto_owner_arrive_time + 1.0)
	check(station.is_washing(), "시작 %.1f초 안에 씻기 시작 (이슈 #40)" % (data.proto_owner_arrive_time + 1.0))
	check(world.hud.get_node("Card").visible, "맡기면 요청 카드가 걸림 (접수)")
	var hour_before: float = day.hour()
	check(hour_before > 9.0 and hour_before < 10.0, "벽시계가 9시부터 감 (%.2f)" % hour_before)

	# --- 목욕대가 차 있으니 다음 손님은 대기 의자로
	await _wait(func() -> bool: return day.queue_ids.size() >= 1, day.arrival_time(1) + 1.0)
	check_eq(day.queue_ids.size(), 1, "두 번째 손님이 대기 의자에서 기다림")
	await _frames(2)
	var waiting: Node3D = station.waiting_area.owners.get(day.queue_ids[0])
	check(waiting != null, "대기 손님 모형이 있음")
	check(waiting.get_node_or_null("HeldDog") != null and waiting.holding, "대기 손님은 강아지를 안고 있음")
	check(day.queue_variants[0] != station.owner_variant, "대기 손님과 목욕대 주인의 옷이 다름")
	check_eq(station.waiting_area.get_child_count(), data.slice_queue_seats + 1, "대기 의자 %d개 + 손님 1명" % data.slice_queue_seats)
	await _wait(func() -> bool: return waiting.wait_level >= 1, data.slice_owner_patience)
	check(waiting.wait_level >= 1, "오래 기다리면 시계를 봄")
	await _wait(func() -> bool: return waiting.wait_level >= 3, data.slice_owner_patience)
	check_eq(waiting.wait_level, 3, "더 기다리면 시무룩")
	await _wait(func() -> bool: return day.walked_out >= 1, data.slice_owner_patience)
	check_eq(day.walked_out, 1, "너무 오래 기다리면 떠남")
	check(day.queue_ids.is_empty(), "떠난 손님은 대기열에서 빠짐")
	check("sigh" in sfx.played, "떠날 때 한숨")
	check(day.hour() > hour_before, "시계가 감")

	# --- 세 번째 손님이 기다리는 동안 첫 손님을 끝내면 대기 손님이 바로 목욕대로
	await _wait(func() -> bool: return day.queue_ids.size() >= 1, day.arrival_time(2) - day.clock + 1.0)
	var third: int = day.queue_ids[0]
	await _finish_guest()
	check_eq(day.served, 1, "씻겨 보낸 손님 1명")
	check(day.earned >= data.money_wash_price, "번 돈 = 요금 + 팁 (%d)" % day.earned)
	await _wait(func() -> bool: return station.owner_phase == WashStation.OwnerPhase.ARRIVE, 1.0)
	check_eq(station.dog_number(), third, "대기 손님이 목욕대로")
	check(station.owner_from_queue, "대기 의자에서 걸어옴")
	await _finish_guest()
	# 네 번째 손님: 목욕대가 비고 기다리는 손님도 없으면 조금 뒤 앞당겨 옴
	await _wait(func() -> bool: return day.arrived == 4, data.proto_next_dog_delay + 1.0)
	check_eq(day.arrived, 4, "목욕대가 비면 다음 손님이 앞당겨 옴")
	check(not day.closed, "손님이 남았으면 영업 중")
	await _finish_guest()
	await _frames(3)
	check(day.closing and not day.closed, "일찍 끝나면 벽시계를 6시까지 빠르게 돌림")
	check(world.hud.hint_label.text.contains("다 받았어요"), "문 닫는 중 안내")
	await _wait(func() -> bool: return day.closed, day.FAST_FORWARD_TIME + 1.0)
	check(day.closed, "오늘 손님이 다 오고 다 끝나면 영업 끝")
	check(is_equal_approx(day.hour(), 18.0), "벽시계가 6시")
	check_eq(day.served + day.walked_out, day.guests_today(), "씻긴 손님 + 떠난 손님 = 오늘 손님")
	check(world.hud.settle_panel.visible, "영업 끝 → 정산 화면")

	# --- 6시가 지나면 새 손님은 안 옴 (목욕 중인 손님은 끝까지)
	data.day_open_minutes_real = 0.05
	data.slice_owner_patience = 100.0
	data.proto_guest_spacing = 2.0
	day.start_day(2)
	await _frames(2)
	check_eq(day.day, 2, "2일차")
	check_eq(day.guest_number_today(station.dog_number()), 1, "요청 카드는 그날 첫 손님부터 셈")
	await _wait(func() -> bool: return not day.is_open(), day.open_seconds() + 1.0)
	await get_tree().create_timer(1.0).timeout
	var arrived_by_six: int = day.arrived
	check(arrived_by_six < day.guests_today(), "6시까지 온 손님만 (%d / %d)" % [arrived_by_six, day.guests_today()])
	check(not day.closed, "6시가 지나도 목욕 중·대기 손님은 끝까지")
	for i in arrived_by_six:
		await _finish_guest()
	await _frames(3)
	check_eq(day.arrived, arrived_by_six, "6시 뒤 새 손님 없음")
	check(day.closed, "남은 손님을 다 보내면 영업 끝")


## 씻기 단계를 바로 넘기고 동전을 주워 주인이 나갈 때까지
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
