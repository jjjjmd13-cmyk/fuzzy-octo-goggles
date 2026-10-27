extends "res://tests/qa_test.gd"
## 손님 2종·성격 2개 (MILESTONE_V3_SLICE 3장):
## 1일차 강아지만·성격 없음, 2일차 고양이·간지럼쟁이, 3일차 겁쟁이 /
## 고양이 = 온도 범위 좁음·젖어 있으면 기분 −·머리에 바가지 크게 싫어함·요금 높음 /
## 간지럼쟁이 = 배·발 금방 찰랑 + 기분 − / 겁쟁이 = 온도 범위 더 좁음·눈에 물 벌점 2배 / 카드에 성격 그림·한 줄.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const ShopDay := preload("res://scripts/sim/shop_day.gd")
const WashHands := preload("res://tests/game/wash_hands.gd")

var world: Node
var station: WashStation
var sfx: Node


func run_test() -> void:
	time_limit_sec = 90.0
	get_tree().root.size = Vector2i(1280, 800)
	var data: Resource = Tuning.data

	# --- 날마다 열리는 손님 종류 (같은 시드로 200명씩)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {1: {}, 2: {}, 3: {}}
	for day_number in [1, 2, 3]:
		for i in 200:
			var kind := ShopDay.kind_of(_pack(ShopDay.roll_kind(day_number, rng)))
			seen[day_number]["s%d" % kind.x] = true
			seen[day_number]["p%d" % kind.y] = true
	check(seen[1].size() == 2 and seen[1].has("s0") and seen[1].has("p0"), "1일차 = 강아지만, 성격 없음 %s" % [seen[1].keys()])
	check(seen[2].has("s1") and seen[2].has("p1") and not seen[2].has("p2"), "2일차 = 고양이·간지럼쟁이, 겁쟁이 아직 %s" % [seen[2].keys()])
	check(seen[3].has("p2"), "3일차 = 겁쟁이도 옴")
	# 새 손님을 꼭 보게: 2일차 2번째 고양이·3번째 간지럼쟁이, 3일차 2번째 겁쟁이 (시드가 달라도 항상)
	for seed_value in 30:
		rng.seed = seed_value
		check_eq(ShopDay.roll_kind(2, rng, 2).x, WashStation.Species.CAT, "2일차 2번째 손님은 고양이 (시드 %d)" % seed_value)
		check_eq(ShopDay.roll_kind(2, rng, 3).y, WashStation.Personality.TICKLISH, "2일차 3번째 손님은 간지럼쟁이 (시드 %d)" % seed_value)
		check_eq(ShopDay.roll_kind(3, rng, 2).y, WashStation.Personality.TIMID, "3일차 2번째 손님은 겁쟁이 (시드 %d)" % seed_value)
		check_eq(ShopDay.roll_kind(1, rng, 2), Vector2i.ZERO, "1일차는 보장 없이 강아지만 (시드 %d)" % seed_value)

	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	world.input_enabled = false
	station = world.station
	sfx = world.sfx
	await _wait(station.is_washing, data.proto_owner_arrive_time + 1.0)
	check(not station.is_cat() and station.personality() == WashStation.Personality.NONE, "1일차 첫 손님은 성격 없는 강아지")
	check_eq(station.temp_good(), data.tool_shower_temp_good, "강아지 온도 범위는 기본")

	# --- 고양이: 모형·온도·젖으면 기분 −·머리에 바가지·요금
	await _next_guest(Vector2i(WashStation.Species.CAT, WashStation.Personality.NONE))
	check(station.dog.model.get_script().resource_path.ends_with("toy_cat_model.gd"), "고양이 모형")
	check(station.dog.model.find_child("Ear_L", true, false) != null and station.dog.model.find_child("Tail_3", true, false) != null, "고양이도 귀·꼬리 따로 (같은 부품 약속)")
	check(world.hud.card_title.text.contains("고양이"), "요청 카드에 고양이")
	check(station.next_hint().contains("고양이") or station.owner_phase != WashStation.OwnerPhase.ARRIVE, "안내도 고양이")
	check_eq(station.temp_good(), data.slice_cat_temp_good, "고양이 온도 '좋음' 범위가 좁음")
	check(is_equal_approx(station.temperature, (data.slice_cat_temp_good[0] + data.slice_cat_temp_good[1]) / 2.0), "물 온도는 이 손님 범위 가운데에서 시작 (%.3f)" % station.temperature)
	station._advance()
	await _frames(2)
	var mood_before: float = station.mood
	await get_tree().create_timer(2.0).timeout
	check(station.mood < mood_before - 0.004, "고양이는 젖어 있는 동안 기분이 조금씩 나빠짐 (%.3f → %.3f)" % [mood_before, station.mood])
	mood_before = station.mood
	station._report_event.rpc_id(1, station.dog_info.x, "pour_head")
	await _frames(1)
	check(station.mood <= mood_before + data.proto_cat_pour_head_mood + 0.01, "고양이 머리에 바가지 → 크게 싫어함")
	await _pay_and_leave()
	check(_paid >= data.slice_cat_price, "고양이 요금 %d (받은 돈 %d)" % [data.slice_cat_price, _paid])

	# --- 간지럼쟁이: 배·발은 금방 찰랑 + 기분 −, 등은 보통
	await _next_guest(Vector2i(WashStation.Species.DOG, WashStation.Personality.TICKLISH))
	check(world.hud.card_trait.visible and world.hud.card_trait.text.contains("간지럼쟁이"), "요청 카드에 성격 한 줄")
	var model: Node3D = station.dog.model
	var belly: Vector3 = model.to_global(model.body_center + Vector3(0, -0.12, 0.02))
	var paw: Vector3 = model.to_global(Vector3(0.08, 0.02, 0.1))
	var back: Vector3 = model.to_global(model.body_center + Vector3(0, 0.12, -0.05))
	check(station.is_belly_or_paw(belly) and station.is_belly_or_paw(paw) and not station.is_belly_or_paw(back), "배·발 / 등 구분")
	mood_before = station.mood
	sfx.played.clear()
	for i in int((data.proto_ticklish_time + 0.2) / 0.05):
		station._update_tickle(belly, 0.05)
	await _frames(2)
	check("squeak" in sfx.played, "배를 문지르면 금방 다리 찰랑 (%.1f초)" % data.proto_ticklish_time)
	check(station.mood < mood_before, "간지럼쟁이 배 찰랑 → 기분 −")
	sfx.played.clear()
	station._tickle_anchor = null
	for i in int((data.proto_ticklish_time + 0.2) / 0.05):
		station._update_tickle(back, 0.05)
	await _frames(2)
	check(not ("squeak" in sfx.played), "등은 금방 찰랑하지 않음")
	await _pay_and_leave()

	# --- 겁쟁이: 온도 범위 더 좁음, 눈에 물 벌점 2배. 고양이 + 겁쟁이 = 겹치는 범위
	await _next_guest(Vector2i(WashStation.Species.CAT, WashStation.Personality.TIMID))
	var good := station.temp_good()
	check(is_equal_approx(good[0], maxf(data.slice_cat_temp_good[0], data.slice_timid_temp_good[0])) and is_equal_approx(good[1], minf(data.slice_cat_temp_good[1], data.slice_timid_temp_good[1])), "고양이 겁쟁이 = 겹치는 온도 범위 %s" % [good])
	station.mood = 0.8
	station._report_event.rpc_id(1, station.dog_info.x, "eye")
	await _frames(1)
	check(is_equal_approx(station.mood, 0.8 + data.mood_eye_hit * data.proto_timid_eye_mult), "겁쟁이 눈에 물 벌점 ×%.0f" % data.proto_timid_eye_mult)
	await _frames(2)
	check(world.hud.card_trait.text.contains("겁쟁이"), "요청 카드에 겁쟁이")


var _paid := 0


## 목욕대를 비우고 그 종류의 손님을 바로 받음 (하루 영업 대기열 대신 직접)
func _next_guest(kind: Vector2i) -> void:
	if station.owner_phase != WashStation.OwnerPhase.EMPTY:
		await _pay_and_leave()
	station.take_guest(station.dog_number() + 100, 0, false, kind)
	await _wait(station.is_washing, Tuning.data.proto_owner_arrive_time + 1.0)
	await _frames(2)


func _pay_and_leave() -> void:
	while station.stage < WashStation.Stage.PAY:
		station._advance()
		await _frames(1)
	await _wait(func() -> bool: return not station.coins.is_empty(), 1.0)
	_paid = 0
	for value in station.coins:
		_paid += value
	var guard := 0
	while not station.coins.is_empty() and guard < 10:
		guard += 1
		station.send_collect(0)
		await _frames(2)
	await _wait(func() -> bool: return station.owner_phase == WashStation.OwnerPhase.EMPTY, Tuning.data.owner_reaction_time + Tuning.data.proto_owner_leave_time + 2.0)


func _pack(kind: Vector2i) -> int:
	return kind.x + kind.y * 4


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(done: Callable, seconds: float) -> void:
	var left := seconds
	while not done.call() and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
