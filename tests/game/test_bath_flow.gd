extends "res://tests/qa_test.gd"
## 혼자 하기로 손님 한 마리의 흐름 전체 (GDD_V2 4.2 완료 조건 2~7, 10). 입력은 실제 Space 이벤트.
## 등장·자리 → 들기 → 욕조 4초 → 꺼내기 → 내려놓으면 털고 도망·웅덩이 → 잡기 → 드라이어 3초
## → 출구로 보내기(띵) → 하트가 다 빈 손님은 흥 → 영업 끝 결과 → 아무 키로 다시 시작.
## 손님 간격만 길게 바꿔 한 마리씩 다룬다 (나머지 수치는 bath_balance.tres 그대로).

const Guest := preload("res://scripts/game/guest.gd")

var world: Node
var shop: Node
var me: Node3D


func run_test() -> void:
	time_limit_sec = 90.0
	var data: Resource = Tuning.data.duplicate()
	data.party_first_guest_delay = PackedFloat32Array([0.2, 0.2, 0.2, 0.2])
	data.party_guest_interval = PackedFloat32Array([999, 999, 999, 999])
	Tuning.data = data
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	shop = world.shop
	me = world.get_player(1)
	var sfx: Node = world.sfx

	# --- 2. 등장 → 빈 자리에 앉음
	await _wait(0.5)
	var guests := world.get_node("Guests")
	if not check_eq(guests.get_child_count(), 1, "손님 한 마리 등장"):
		return
	var guest: Node3D = guests.get_child(0)
	check(sfx.played.has("splat"), "진흙 손님 소리 (철퍽)")
	check_eq(guest.state, Guest.State.MUDDY, "처음엔 진흙")
	await _until(func() -> bool: return guest.phase == Guest.Phase.SEATED, 6.0)
	var seat: Vector3 = world.get_node("Seats").get_child(0).global_position
	check(guest.ground_position.distance_to(seat) < 0.1, "첫 자리에 앉음")
	check_eq(guest.hearts_left(), 3, "하트 3개")

	# --- 3. 들기 → 욕조에 넣기 → 4초 → 젖음
	await _stand_facing(guest.ground_position + Vector3(0.9, 0, 0), guest.ground_position)
	check_eq(world.hud.prompt_label.text, "Space: 강아지 들기", "화면 안내")
	await _space()
	check_eq(guest.holder_peer, 1, "Space → 들기")
	var bath: Node3D = world.get_node("Machines/Bath")
	await _stand_facing(bath.global_position + Vector3(0, 0, 1.5), bath.global_position)
	check_eq(world.hud.prompt_label.text, "Space: 욕조에 넣기", "욕조 안내")
	await _space()
	check_eq(bath.occupant, String(guest.name), "욕조에 들어감")
	check_eq(guest.state, Guest.State.FOAM, "거품 상태")
	var patience_before: float = guest.patience
	await _wait(Tuning.data.machine_bath_time + 0.2)
	check_eq(guest.state, Guest.State.WET, "욕조 4초 → 젖음")
	check(bath.done, "욕조 다 됨")
	check(sfx.played.has("bubble_pop"), "뽀글 → 펑 소리")
	check(patience_before - guest.patience < 0.6, "기계가 도는 동안 하트가 거의 안 줄어듦 (%.2f)" % (patience_before - guest.patience))

	# --- 꺼내기 → 내려놓으면 털고 도망
	await _space()
	check_eq(guest.holder_peer, 1, "Space → 욕조에서 꺼내기")
	check(bath.occupant.is_empty(), "욕조 비었음")
	await _stand_facing(Vector3(0, 0, 1), Vector3(0, 0, 0))
	var held_patience: float = guest.patience
	await _wait(0.5)
	check(is_equal_approx(held_patience, guest.patience), "들려 있는 동안 하트가 안 줄어듦")
	await _space()
	check_eq(guest.phase, Guest.Phase.SHAKING, "젖은 손님을 내려놓으면 몸 털기")
	check(sfx.played.has("drip"), "뚝뚝 소리")
	var puddles := world.get_node("Puddles")
	check(puddles.get_child_count() >= 3, "털 때 주변에 웅덩이 (%d)" % puddles.get_child_count())
	var drop_pos: Vector3 = guest.ground_position
	await _wait(Tuning.data.escape_shake_time + 1.5)
	check_eq(guest.phase, Guest.Phase.ESCAPING, "털고 나서 도망")
	check(guest.ground_position.distance_to(drop_pos) > 1.0, "뛰어다님 (%.1f m)" % guest.ground_position.distance_to(drop_pos))
	check(puddles.get_child_count() >= 4, "뛰면서 웅덩이를 남김 (%d)" % puddles.get_child_count())

	# --- 잡기 → 멈춤 → 드라이어 3초 → 뽀송
	var catch_from: Vector3 = guest.ground_position + Vector3(0.6, 0, 0)
	await _stand_facing(catch_from, guest.ground_position, true)
	await _space()
	check_eq(guest.holder_peer, 1, "도망가는 손님 잡기")
	check_eq(guest.phase, Guest.Phase.FREE, "잡으면 얌전해짐")
	var dryer: Node3D = world.get_node("Machines/Dryer")
	await _stand_facing(dryer.global_position + Vector3(0, 0, 1.5), dryer.global_position)
	await _space()
	check_eq(dryer.occupant, String(guest.name), "드라이어에 들어감")
	await _wait(Tuning.data.machine_dryer_time + 0.2)
	check_eq(guest.state, Guest.State.DRY, "드라이어 3초 → 뽀송")
	check(sfx.played.has("poof"), "뽀옹 소리")
	await _space()
	check_eq(guest.holder_peer, 1, "드라이어에서 꺼내기")

	# --- 6. 뽀송 손님을 내려놓으면 앉아 있음 → 다시 들고 출구로
	await _stand_facing(Vector3(2, 0, 2), Vector3(2, 0, 1))
	await _space()
	check_eq(guest.phase, Guest.Phase.FREE, "뽀송 손님은 내려놓아도 앉아 있음")
	var sit_pos: Vector3 = guest.ground_position
	await _wait(0.8)
	check(guest.ground_position.distance_to(sit_pos) < 0.01, "움직이지 않음")
	await _space()
	var exit: Node3D = world.get_node("Exit")
	await _stand_facing(exit.global_position + Vector3(-1.3, 0, 0), exit.global_position)
	check_eq(world.hud.prompt_label.text, "Space: 손님 보내기", "출구 안내")
	await _space()
	await _wait(0.1)
	check_eq(shop.delivered, 1, "보낸 손님 1")
	check(not is_instance_valid(guest) or guest.is_queued_for_deletion(), "손님이 나감")
	check(sfx.played.has("ding"), "띵 소리")

	# --- 4. 하트가 다 비면 흥
	shop._spawn_timer = 0.1  # 다음 손님을 바로 부름 (간격은 999 그대로)
	await _until(func() -> bool: return guests.get_child_count() > 0, 3.0)
	if not check_eq(guests.get_child_count(), 1, "다음 손님 등장"):
		return
	var impatient: Node3D = guests.get_child(0)
	impatient.patience = 0.3
	await _wait(0.6)
	check_eq(shop.angry, 1, "하트가 다 빈 손님은 화나서 나감")
	check(sfx.played.has("huff"), "흥 소리")
	await _wait(Tuning.data.guest_angry_leave_time + 0.3)
	check(not is_instance_valid(impatient), "나간 손님이 사라짐")

	# --- 7. 영업 끝 → 결과 → 아무 키로 다시 시작
	shop.time_left = 0.2
	await _wait(0.5)
	check_eq(shop.phase, shop.Phase.RESULTS, "영업 끝")
	check(world.hud.results.visible, "결과 화면")
	check(world.hud.results_label.text.contains("보낸 손님  1"), "결과에 보낸 수")
	check_eq(shop.stars, 0, "1인 별 1개는 3마리부터")
	var round_before: int = shop.round_id
	_key(KEY_X)
	await _settle()
	check_eq(shop.phase, shop.Phase.OPEN, "아무 키 → 다시 시작")
	check_eq(shop.round_id, round_before + 1, "새 판")
	check_eq(shop.delivered, 0, "점수 초기화")
	await Net.leave_session()


## 서서 target 쪽을 보게 한다. 플레이어 방향(net_yaw)이 판정에 쓰인다.
func _stand_facing(pos: Vector3, target: Vector3, quick := false) -> void:
	var to := target - pos
	me.teleport(Vector3(pos.x, 0.1, pos.z), atan2(-to.x, -to.z))
	for i in (1 if quick else 3):
		await get_tree().physics_frame


func _space() -> void:
	_key(KEY_SPACE)
	await _settle()


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


func _until(condition: Callable, timeout: float) -> void:
	var t := 0.0
	while not condition.call() and t < timeout:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
