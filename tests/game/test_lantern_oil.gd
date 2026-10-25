extends "res://tests/qa_test.gd"
## 혼자 하기로 큰 등불·공용 기름 규칙 확인 (GDD 13장 완료 조건 3·4).
## 줍기·밝기 3단계·내려놓기, 손등, 기름 소모 속도, 기름병, 기름 0 → 심지 → 완전한 어둠.

var world: Node
var expedition: Node
var oil: Node
var lantern: Node3D
var me: Node


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	expedition = world.expedition
	oil = world.oil_tank
	lantern = world.lantern
	me = world.get_player(1)
	var data: Resource = Tuning.data
	world.stalker.set_physics_process(false)  # 이 테스트는 추적자를 보지 않는다

	check_eq(expedition.party_size, 1, "혼자 하기 인원")
	check_eq(oil.oil, 90.0, "1인 시작 기름 (인원별 표)")
	check_eq(lantern.level, 1, "등불 기본 단계 = 보통")
	check_eq(lantern.light_radius(), 8.0, "보통 반경")

	# 등불이 바닥에 있고 손등이 켜져 있음 → (4 + 0.5) × 0.7 /분
	check(me.is_handlamp_lit(), "손등 켜짐")
	check(is_equal_approx(expedition.oil_drain_per_minute(), 4.5 * 0.7), "소모 = (보통 + 손등) × 1인 배율")
	var before: float = oil.oil
	await _wait(3.0)
	var used: float = before - oil.oil
	var expected_used := 4.5 * 0.7 / 60.0 * 3.0
	check(absf(used - expected_used) <= 4.5 * 0.7 / 60.0 * data.oil_tick_interval + 0.0001,
		"3초 소모 %.4f (기대 %.4f, 한 틱 오차)" % [used, expected_used])

	# 멀어서 못 줍는다 → 가까이 가면 줍는다
	expedition.send_request(expedition.ACT_PICKUP_LANTERN)
	check_eq(lantern.holder_peer, 0, "2 m 밖에서는 못 주움")
	await _move_me(lantern.ground_position + Vector3(0, 0, 1))
	expedition.send_request(expedition.ACT_PICKUP_LANTERN)
	check_eq(lantern.holder_peer, 1, "등불 주움")
	check(not me.is_handlamp_lit(), "등불을 들면 손등 꺼짐")
	check(is_equal_approx(expedition.oil_drain_per_minute(), 4.0 * 0.7), "손등 없이 등불만 소모")

	# 밝기 3단계
	expedition.send_request(expedition.ACT_LANTERN_LEVEL, 1)
	check_eq(lantern.light_radius(), 12.0, "키움 12 m")
	expedition.send_request(expedition.ACT_LANTERN_LEVEL, 1)
	check_eq(lantern.level, 2, "최대 단계에서 더 안 올라감")
	expedition.send_request(expedition.ACT_LANTERN_LEVEL, -1)
	expedition.send_request(expedition.ACT_LANTERN_LEVEL, -1)
	check_eq(lantern.light_radius(), 5.0, "낮춤 5 m")
	check(is_equal_approx(expedition.oil_drain_per_minute(), 2.0 * 0.7), "낮춤 소모")

	# 내려놓기
	expedition.send_request(expedition.ACT_DROP_LANTERN)
	check_eq(lantern.holder_peer, 0, "내려놓음")
	check(Expedition_hdist(lantern.ground_position, me.global_position) < 1.0, "발 앞에 놓임")

	# 손등 끄기
	me.handlamp_on = false
	check(not me.is_handlamp_lit(), "손등 끔")

	# 기름병: +15, 한 번만
	oil.oil = 50.0
	var bottle: Node3D = world.get_bottle(0)
	await _move_me(bottle.global_position + Vector3(0.5, 0, 0))
	expedition.send_request(expedition.ACT_PICKUP_BOTTLE, 0)
	expedition.send_request(expedition.ACT_PICKUP_BOTTLE, 0)
	check_eq(oil.oil, 65.0, "기름병 +15 한 번만")
	check(bottle.taken, "기름병 사라짐")
	oil.oil = 95.0
	oil.add(15.0)
	check_eq(oil.oil, data.oil_max, "최대치를 넘지 않음")

	# 기름 부족: 키움 금지, 보통까지
	oil.oil = 15.0
	lantern.level = 2
	check_eq(lantern.effective_level(), 1, "기름 20 이하 → 최대 보통")

	# 기름 0 → 심지 → 완전한 어둠
	oil.oil = 0.01
	await _wait(1.0)
	check_eq(oil.oil, 0.0, "기름은 0 아래로 안 내려감")
	check(oil.in_wick(), "심지 시간")
	check_eq(lantern.light_radius(), data.light_wick_radius, "심지 반경 2 m")
	check(not lantern.is_big_light(), "심지는 큰 빛이 아님")
	oil.wick_left = 0.3
	await _wait(1.0)
	check(oil.is_dark(), "완전한 어둠")
	check_eq(lantern.light_radius(), 0.0, "등불 꺼짐")
	check(not me.is_handlamp_lit(), "기름 없으면 손등도 꺼짐")

	# F5 디버그: 기름 30으로 다시 시작
	expedition.send_request(expedition.ACT_DEBUG_RESTART, int(data.proto_debug_oil_start))
	check_eq(oil.oil, 30.0, "디버그 다시 시작 기름 30")
	check(not bottle.taken, "다시 시작하면 기름병 복구")
	await Net.leave_session()


func Expedition_hdist(a: Vector3, b: Vector3) -> float:
	return expedition.horizontal_distance(a, b)


func _move_me(pos: Vector3) -> void:
	me.teleport(Vector3(pos.x, 0.1, pos.z), 0.0)
	for i in 3:
		await get_tree().physics_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout
