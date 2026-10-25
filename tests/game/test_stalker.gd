extends "res://tests/qa_test.gd"
## 혼자 하기로 어둠 게이지와 그림자 추적자 상태 기계 확인 (GDD 13장 완료 조건 5, 혼자일 때 쓰러짐 → 실패).
##
## 1. 빛 밖에서 게이지가 오르면 추적 → 0.8초 준비 → 잡음 → 쓰러짐 → (혼자라) 실패 → 다시 시작
## 2. 등불을 든 사람을 쫓을 때 빛 경계에서 멈춤 (빛 안으로 안 들어옴)
## 3. 등불을 키워 빛이 추적자를 덮으면 후퇴
## 어둠 게이지 상승만 빠르게 바꾼다 (테스트 시간을 줄이려고). 나머지는 balance.tres 값 그대로.

const Stalker := preload("res://scripts/game/stalker.gd")

var world: Node
var expedition: Node
var stalker: CharacterBody3D
var me: Node
var _states_seen := {}


func run_test() -> void:
	time_limit_sec = 90.0
	var fast: Resource = Tuning.data.duplicate()
	fast.dark_gain_unlit = 40.0
	fast.proto_fail_restart_delay = 1.0
	Tuning.data = fast

	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	expedition = world.expedition
	stalker = world.stalker
	me = world.get_player(1)
	stalker.state_changed.connect(func(s: int) -> void: _states_seen[s] = true)
	expedition.drain_enabled = false

	# 처음엔 등불 빛 안 → 게이지 0 근처, 추적 안 함
	await _wait(1.0)
	check(me.dark < 1.0, "빛 안에서는 어둠 게이지가 쌓이지 않음 (%.1f)" % me.dark)
	check(stalker.state != Stalker.State.STALK, "빛 안에 있을 때는 추적하지 않음")

	# --- 1. 빛 밖 → 추적 → 공격 → 쓰러짐
	me.handlamp_on = false
	await _move_me(Vector3(12, 0, 2))  # 방 B, 등불(방 A)에서 13 m
	var t := 0.0
	var saw_attack_before_down := false
	while not me.downed and t < 30.0:
		if stalker.state == Stalker.State.ATTACK:
			saw_attack_before_down = true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	check(_states_seen.has(Stalker.State.STALK), "추적 상태로 바뀜")
	check(saw_attack_before_down, "잡기 전에 공격 준비 상태를 거침")
	check(me.downed, "추적자에게 잡혀 쓰러짐 (%.1f초)" % t)
	await get_tree().physics_frame
	check_eq(stalker.state, Stalker.State.FLEE, "잡은 뒤 후퇴")
	check_eq(expedition.phase, expedition.Phase.FAILED, "혼자일 때 쓰러지면 원정 실패")
	await _wait(1.5)
	check_eq(expedition.phase, expedition.Phase.PLAYING, "실패 뒤 다시 시작")
	check(not me.downed, "다시 시작하면 일어나 있음")

	# --- 2. 등불을 든 사람을 쫓음 → 빛 경계에서 멈춤
	await _move_me(world.lantern.ground_position + Vector3(0, 0, 1))
	expedition.send_request(expedition.ACT_PICKUP_LANTERN)
	check_eq(world.lantern.holder_peer, 1, "등불 주움")
	await _move_me(Vector3(12, 0, 2))
	stalker.reset()
	var radius: float = world.lantern.light_radius()
	var closest := 1000.0
	var stalked := false
	t = 0.0
	while t < 10.0:
		me.dark = 100.0  # 빛 안이라도 '거리 무시 추적' 대상이 되게 강제
		if stalker.state == Stalker.State.STALK:
			stalked = true
		closest = minf(closest, expedition.horizontal_distance(stalker.global_position, me.global_position))
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	check(stalked, "등불 든 사람도 게이지 100이면 추적")
	check(closest >= radius - 0.3, "빛 경계에서 멈춤: 가장 가까이 %.2f m (반경 %.1f m)" % [closest, radius])
	check(not me.downed, "빛 안에서는 잡히지 않음")

	# --- 3. 등불을 키워 추적자를 빛으로 덮으면 후퇴
	expedition.send_request(expedition.ACT_LANTERN_LEVEL, 1)
	t = 0.0
	while stalker.state != Stalker.State.FLEE and t < 3.0:
		me.dark = 100.0
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	check_eq(stalker.state, Stalker.State.FLEE, "빛을 비추면 후퇴 (%.2f초)" % t)
	check(t >= Tuning.data.stalker_light_flee_time - 0.05, "빛에 0.5초 이상 걸쳐야 후퇴 (%.2f초)" % t)
	await Net.leave_session()


func _move_me(pos: Vector3) -> void:
	me.teleport(Vector3(pos.x, 0.1, pos.z), 0.0)
	for i in 3:
		await get_tree().physics_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout
