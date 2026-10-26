extends "res://tests/qa_test.gd"
## 물웅덩이 미끄러짐과 대시 (TUNING_V2 1장·2.2, GDD_V2 4.2 완료 조건 5).
## 웅덩이를 밟으면 진행 방향으로 2.5 m, 0.6초 조작 불가, 들고 있던 손님은 그대로, 미끄러짐 소리.
## Shift 대시는 약 2.5 m, 쿨타임 동안 다시 안 됨.

var world: Node
var me: Node3D


func run_test() -> void:
	var data: Resource = Tuning.data.duplicate()
	data.party_first_guest_delay = PackedFloat32Array([0.1, 0.1, 0.1, 0.1])
	data.party_guest_interval = PackedFloat32Array([999, 999, 999, 999])
	Tuning.data = data
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	me = world.get_player(1)
	await _wait(0.3)
	var guest: Node3D = world.get_node("Guests").get_child(0)

	# 손님을 들고, 앞(-Z)에 웅덩이를 하나 둔다
	guest.phase = guest.Phase.SEATED
	guest.ground_position = Vector3(0, 0, 2)
	await _teleport(Vector3(0, 0, 3), 0.0)
	await _press(KEY_SPACE)
	check_eq(guest.holder_peer, 1, "손님을 듦")
	world.shop.spawn_puddle(Vector3(0, 0, 1.2))
	await get_tree().process_frame

	# 앞으로 걸어 웅덩이를 밟음 → 미끄러짐
	var slipped := [false, Vector3.ZERO]
	me.slipped.connect(func() -> void:
		slipped[0] = true
		slipped[1] = me.global_position, CONNECT_ONE_SHOT)
	Input.action_press("move_forward")
	var t := 0.0
	while not slipped[0] and t < 2.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	if not check(slipped[0], "웅덩이를 밟으면 미끄러짐"):
		Input.action_release("move_forward")
		return
	# 미끄러지는 동안 반대로 눌러도 소용없음
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _wait(data.puddle_slide_time + 0.05)
	Input.action_release("move_back")
	var slid: float = slipped[1].distance_to(me.global_position)
	check(absf(slid - data.puddle_slide_distance) < 0.4, "약 %.1f m 미끄러짐 (실제 %.2f m)" % [data.puddle_slide_distance, slid])
	check(me.global_position.z < slipped[1].z, "진행 방향(-Z)으로 미끄러짐")
	check_eq(guest.holder_peer, 1, "미끄러져도 손님은 그대로")
	check(world.sfx.played.has("slip"), "미끄러짐 소리")
	check_eq(guest.phase, guest.Phase.FREE, "손님은 웅덩이에서 안 미끄러짐 (들린 상태 그대로)")

	# 대시
	await _teleport(Vector3(-3, 0, 4), 0.0)
	var start := me.global_position
	await _press(KEY_SHIFT)
	await _wait(0.3)
	var dashed := start.distance_to(me.global_position)
	check(absf(dashed - data.player_dash_distance) < 0.4, "대시 약 %.1f m (실제 %.2f m)" % [data.player_dash_distance, dashed])
	var start2 := me.global_position
	await _press(KEY_SHIFT)
	await _wait(0.3)
	check(start2.distance_to(me.global_position) < 0.2, "쿨타임 동안 대시 안 됨")
	await Net.leave_session()


func _teleport(pos: Vector3, yaw: float) -> void:
	me.teleport(Vector3(pos.x, 0.1, pos.z), yaw)
	for i in 3:
		await get_tree().physics_frame


func _press(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	for i in 2:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
