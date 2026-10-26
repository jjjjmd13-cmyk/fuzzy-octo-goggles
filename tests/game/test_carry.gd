extends "res://tests/qa_test.gd"
## 혼자 하기로 들기·내려놓기 확인 (실제 입력 이벤트 E 로).
## 멀면 못 듦 → 가까이 가서 E → 들고 있으면 손 위치를 따라옴·느려짐 → E 로 앞에 내려놓음.
## 한 번에 하나만 듦. 화면 이동은 고정 카메라 기준(화면 위 = 앞).

var world: Node
var rules: Node
var me: Node3D


func run_test() -> void:
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	rules = world.carry_rules
	me = world.get_player(1)
	var crate: Node3D = world.get_node("Props/CrateB")
	var other: Node3D = world.get_node("Props/CrateA")
	await _frames(3)

	check_eq(rules.pickup_candidate(me), null, "시작 자리에서는 들 수 있는 물건이 없음")
	_key(KEY_E)
	await _settle()
	check_eq(crate.holder_peer, 0, "멀리서 E → 안 들림")

	await _move_me(crate.global_position + Vector3(0, 0, 1.0))
	check_eq(rules.pickup_candidate(me), crate, "가까이 가면 들 수 있음")
	check_eq(world.hud.prompt_label.text, "E: 상자 들기", "화면 안내")
	_key(KEY_E)
	await _settle()
	check_eq(crate.holder_peer, 1, "E → 들기")
	check(me.is_carrying(), "들고 있음")
	await _frames(2)
	check(crate.global_position.distance_to(me.get_carry_transform().origin) < 0.05, "손 위치를 따라옴")

	# 들고 있으면 다른 물건은 못 듦
	rules.send_request(rules.ACT_PICKUP, other)
	check_eq(other.holder_peer, 0, "한 번에 하나만")

	# 들고 걸으면 느림 (걷기 × carry_speed_mult)
	var start := me.global_position
	Input.action_press("move_forward")
	await _wait(1.0)
	Input.action_release("move_forward")
	var moved := start.distance_to(me.global_position)
	var walk: float = Tuning.data.player_walk_speed
	check(moved < walk * 1.0 * 0.95, "들고 걸으면 느림 (%.2f m/s, 걷기 %.1f)" % [moved, walk])
	check(me.global_position.z < start.z - 0.5, "화면 위(W) = -Z 로 감")
	await _wait(0.3)

	# E → 앞에 내려놓기
	_key(KEY_E)
	await _settle()
	check_eq(crate.holder_peer, 0, "E → 내려놓기")
	var forward := -me.global_basis.z
	var expected: Vector3 = me.global_position + Vector3(forward.x, 0, forward.z).normalized() * Tuning.data.carry_drop_distance
	check(rules.horizontal_distance(crate.ground_position, expected) < 0.05, "몸 앞에 놓임")
	await _wait(0.3)
	check(rules.horizontal_distance(crate.global_position, expected) < 0.1, "바닥 위치로 내려옴")

	# 건네기: 혼자면 받을 사람이 없음 → 그대로
	_key(KEY_E)
	await _settle()
	rules.send_request(rules.ACT_GIVE)
	check_eq(crate.holder_peer, 1, "받을 동료가 없으면 건네지지 않음")
	await Net.leave_session()


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


## 넣은 입력은 다음 idle 프레임에 처리된다.
func _settle() -> void:
	for i in 3:
		await get_tree().process_frame


func _move_me(pos: Vector3) -> void:
	me.teleport(Vector3(pos.x, 0.1, pos.z), 0.0)
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
