extends "res://tests/qa_test.gd"
## 첫 플레이 테스트(사람 대표, 혼자 하기) 피드백 확인.
##  3. 휠 밝기: 등불을 안 들었으면 안내, 들면 단계가 바뀌고 크게 알림 (실제 입력 이벤트로)
##  4. 추적자: 어둠 속에서 몸이 닿으면 바로 공격 준비, 몸을 통과할 수 없음,
##     등불을 들고 있어도 2분 안에 빛 가장자리까지 와서 모습을 드러냄
##  1. 시작 안내가 보이고, 출구에 도착하면 원정 성공 → 다시 시작

const Stalker := preload("res://scripts/game/stalker.gd")

var world: Node
var expedition: Node
var hud: Node
var me: Node


func run_test() -> void:
	time_limit_sec = 300.0
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	expedition = world.expedition
	hud = world.hud
	me = world.get_player(1)
	expedition.drain_enabled = false
	world.stalker.set_physics_process(false)
	await _frames(3)

	check(hud.intro_panel.visible, "시작 안내가 보임")

	# --- 3. 휠 밝기
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await _input_settle()
	check_eq(world.lantern.level, 1, "등불 안 들었을 때 휠 → 밝기 그대로")
	check_eq(hud.notice_label.text, hud.TEXT.need_lantern_hint, "등불을 들라는 안내")
	await _move_me(world.lantern.ground_position + Vector3(0, 0, 1))
	_key(KEY_E)
	await _input_settle()
	check_eq(world.lantern.holder_peer, 1, "E 로 등불 주움")
	_wheel(MOUSE_BUTTON_WHEEL_UP)
	await _input_settle()
	check_eq(world.lantern.level, 2, "휠 위 → 키움")
	check(hud.notice_label.text.contains("키움") and hud.notice_label.text.contains("12"), "밝기 바뀜을 크게 알림 (%s)" % hud.notice_label.text)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await _input_settle()
	check_eq(world.lantern.level, 0, "휠 아래 두 번 → 낮춤")
	expedition.send_request(expedition.ACT_DROP_LANTERN)

	# --- 4a. 몸을 통과할 수 없음
	var stalker: CharacterBody3D = world.stalker
	await _move_me(Vector3(12, 0, 3))
	stalker.global_position = Vector3(12, 0.05, 1.5)
	await _frames(2)
	Input.action_press("move_forward")
	await _wait(1.0)
	Input.action_release("move_forward")
	check(me.global_position.z > stalker.global_position.z + 0.5, "추적자 몸을 통과하지 못함 (나 z=%.2f, 추적자 z=%.2f)" % [me.global_position.z, stalker.global_position.z])

	# --- 4b. 어둠 속에서 닿으면 바로 공격 준비 (어둠 게이지와 상관없이)
	me.dark = 0.0
	stalker.reset()
	stalker.global_position = me.global_position + Vector3(0.5, 0, 0)
	stalker.set_physics_process(true)
	await _wait(0.3)
	check_eq(stalker.state, Stalker.State.ATTACK, "닿자마자 공격 준비 (어둠 %.0f)" % me.dark)
	await _wait(1.0)
	check(me.downed or expedition.phase != expedition.Phase.PLAYING, "준비 동작 뒤 잡힘")
	await _wait(Tuning.data.proto_fail_restart_delay + 0.5)
	check_eq(expedition.phase, expedition.Phase.PLAYING, "다시 시작")

	# --- 4c. 등불을 들고 빛 안에만 있어도, 2분(게임 시간) 안에 빛 가장자리에 모습을 드러냄
	await _move_me(world.lantern.ground_position + Vector3(0, 0, 1))
	expedition.send_request(expedition.ACT_PICKUP_LANTERN)
	await _move_me(Vector3(10, 0, 0))
	stalker.reset()
	Engine.time_scale = 4.0
	var game_time := 0.0
	var radius: float = world.lantern.light_radius()
	var seen := false
	while game_time < 120.0:
		await get_tree().physics_frame
		game_time += get_physics_process_delta_time()
		if expedition.horizontal_distance(stalker.global_position, me.global_position) <= radius + 2.0:
			seen = true
			break
	Engine.time_scale = 1.0
	print("빛 가장자리에 나타나기까지 게임 시간 %.1f초" % game_time)
	check(seen, "등불을 들고 있어도 %.0f초 안에 빛 가장자리(%.0f m 안)에 나타남" % [game_time, radius + 2.0])
	check(not me.downed, "빛 안에서는 잡히지 않음")

	# --- 1. 출구 도착 → 원정 성공 → 다시 시작
	stalker.set_physics_process(false)
	await _move_me(world.get_node("Exit").global_position + Vector3(0, 0, 1))
	await _frames(3)
	check_eq(expedition.phase, expedition.Phase.SUCCEEDED, "출구에 도착하면 원정 성공")
	check(hud.center_label.text.contains("성공"), "성공 화면 (%s)" % hud.center_label.text)
	await _wait(Tuning.data.proto_fail_restart_delay + 0.5)
	check_eq(expedition.phase, expedition.Phase.PLAYING, "성공 뒤 다시 시작")
	check(hud.intro_panel.visible, "다시 시작하면 안내가 다시 보임")
	await Net.leave_session()


## 넣은 입력은 다음 idle 프레임에 처리되므로 process_frame 을 기다린다.
func _input_settle() -> void:
	for i in 3:
		await get_tree().process_frame


func _wheel(button: MouseButton) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


func _move_me(pos: Vector3) -> void:
	me.teleport(Vector3(pos.x, 0.1, pos.z), 0.0)
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout
