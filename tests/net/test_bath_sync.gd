extends "res://tests/qa_test.gd"
## 2인(ENet) 목욕탕 동기화 (GDD_V2 4.2 완료 조건 8: 손님·기계·웅덩이·영업 시간은 호스트 권한, 두 화면이 같음).
## 호스트 1 + 클라이언트 1 (.roles). 호스트가 단계마다 _ask 로 클라이언트에 시키고 _report 로 답을 받는다.
##
## 1. 손님 등장이 클라이언트에도 보임, 인원은 2인 (간격 표 2인 값)
## 2. 클라이언트가 Space 로 손님을 들고 욕조에 넣음 → 호스트에서도 같은 상태
## 3. 욕조가 끝나면(호스트 타이머) 클라이언트 화면도 젖음
## 4. 클라이언트가 젖은 손님을 꺼내 내려놓음 → 양쪽에서 도망·웅덩이 수가 같음
## 5. 클라이언트의 위조(내 화면 값 조작)는 호스트를 못 바꿈
## 6. 영업 끝 → 클라이언트도 결과 화면, 클라이언트가 아무 키 → 호스트가 새 판

const Guest := preload("res://scripts/game/guest.gd")
const SETTLE_SEC := 0.5

var _reports := {}


func run_test() -> void:
	time_limit_sec = 90.0
	var data: Resource = Tuning.data.duplicate()
	data.party_first_guest_delay = PackedFloat32Array([999, 999, 999, 999])
	data.party_guest_interval = PackedFloat32Array([999, 999, 999, 999])
	Tuning.data = data
	get_tree().current_scene = null
	if role == "server":
		await _run_server()
	else:
		await _run_client()


# ---------------------------------------------------------------- 호스트

func _run_server() -> void:
	Net.host_enet(port)
	await Net.session_started
	report_ready()
	var client_id: int = await Net.player_joined
	var world := get_tree().current_scene
	while world.get_player(client_id) == null:
		await get_tree().process_frame
	var shop: Node = world.shop
	if not await _ask(client_id, "ready"):
		return

	# 1. 손님 등장
	shop._spawn_timer = 0.0
	await _wait(SETTLE_SEC)
	check_eq(shop.party_size, 2, "인원 2")
	var guests := world.get_node("Guests")
	if not check_eq(guests.get_child_count(), 1, "호스트: 손님 등장"):
		return
	var guest: Node3D = guests.get_child(0)
	guest.ground_position = Vector3(0, 0, 0)  # 자리까지 기다리지 않게 방 가운데에 앉힘
	guest.phase = Guest.Phase.SEATED
	await _wait(SETTLE_SEC)
	await _ask(client_id, "guest", String(guest.name))

	# 2. 클라이언트가 들고 욕조에 넣음
	await _ask(client_id, "pickup", String(guest.name))
	await _wait(SETTLE_SEC)
	check_eq(guest.holder_peer, client_id, "호스트: 클라이언트가 손님을 듦")
	var bath: Node3D = world.get_node("Machines/Bath")
	await _ask(client_id, "load_bath")
	await _wait(SETTLE_SEC)
	check_eq(bath.occupant, String(guest.name), "호스트: 욕조에 들어감")

	# 3. 욕조 끝 → 젖음
	await _wait(Tuning.data.machine_bath_time + 0.3)
	check_eq(guest.state, Guest.State.WET, "호스트: 젖음")
	await _ask(client_id, "state", String(guest.name), Guest.State.WET)

	# 4. 꺼내서 내려놓음 → 도망·웅덩이
	await _ask(client_id, "unload_and_drop")
	await _wait(Tuning.data.escape_shake_time + 1.5)
	check_eq(guest.phase, Guest.Phase.ESCAPING, "호스트: 도망 중")
	var puddles := world.get_node("Puddles")
	await _ask(client_id, "escaping", String(guest.name), puddles.get_child_count())

	# 5. 위조
	await _ask(client_id, "forge", String(guest.name))
	await _wait(SETTLE_SEC)
	check_eq(shop.delivered, 0, "클라이언트 화면 조작으로 점수가 안 바뀜")
	check_eq(guest.state, Guest.State.WET, "클라이언트 화면 조작으로 손님 상태가 안 바뀜")

	# 6. 영업 끝 → 결과 → 클라이언트가 다시 시작
	var round_before: int = shop.round_id
	shop.time_left = 0.1
	await _wait(SETTLE_SEC)
	check_eq(shop.phase, shop.Phase.RESULTS, "호스트: 결과")
	await _ask(client_id, "results_restart")
	await _wait(SETTLE_SEC)
	check_eq(shop.round_id, round_before + 1, "클라이언트의 아무 키로 새 판")
	check_eq(shop.phase, shop.Phase.OPEN, "다시 영업")
	await Net.leave_session("테스트 종료")


func _ask(client_id: int, step: String, target := "", value := 0) -> bool:
	_reports.erase(step)
	_do.rpc_id(client_id, step, target, value)
	while not _reports.has(step):
		await get_tree().process_frame
	var report: Array = _reports[step]
	return check(report[0], "클라이언트 [%s]: %s" % [step, report[1]])


@rpc("any_peer", "reliable")
func _report(step: String, ok: bool, message: String) -> void:
	_reports[step] = [ok, message]


# ---------------------------------------------------------------- 클라이언트

func _run_client() -> void:
	Net.join_enet("127.0.0.1", port)
	await Net.session_started
	await Net.session_ended
	check_eq(get_tree().current_scene.scene_file_path, Net.MENU_SCENE, "호스트가 나간 뒤 메뉴")


@rpc("authority", "reliable")
func _do(step: String, target: String, value: int) -> void:
	var world := get_tree().current_scene
	while world.get_local_player() == null:
		await get_tree().process_frame
	var me: Node3D = world.get_local_player()
	var guest: Node3D = world.get_node("Guests").get_node_or_null(target) if not target.is_empty() else null
	var ok := true
	var message := ""
	match step:
		"ready":
			message = "준비"
		"guest":
			ok = guest != null and guest.ground_position.distance_to(Vector3.ZERO) < 0.2
			message = "손님 %s 보임, 위치 %s" % [target, guest.ground_position if guest else "-"]
		"pickup":
			await _stand_facing(me, Vector3(0, 0, 0.9), guest.ground_position)
			await _space()
			await _wait(SETTLE_SEC)
			ok = guest.holder_peer == me.get_peer_id()
			message = "든 사람 %d" % guest.holder_peer
		"load_bath":
			var bath: Node3D = world.get_node("Machines/Bath")
			await _stand_facing(me, bath.global_position + Vector3(0, 0, 1.5), bath.global_position)
			await _space()
			await _wait(SETTLE_SEC)
			ok = bath.occupant == String(world.get_node("Guests").get_child(0).name)
			message = "욕조 %s" % bath.occupant
		"state":
			ok = guest.state == value
			message = "상태 %d (기대 %d)" % [guest.state, value]
		"unload_and_drop":
			await _space()  # 욕조에서 꺼내기 (욕조 앞에 서 있음)
			await _wait(SETTLE_SEC)
			await _stand_facing(me, Vector3(0, 0, 1), Vector3(0, 0, 0))
			await _space()
			message = "꺼내서 내려놓음"
		"escaping":
			var puddles: int = world.get_node("Puddles").get_child_count()
			ok = guest.phase == Guest.Phase.ESCAPING and absi(puddles - value) <= 1
			message = "단계 %d, 웅덩이 %d (호스트 %d)" % [guest.phase, puddles, value]
		"forge":
			world.shop.delivered = 99  # 내 화면 값만 바꿈
			guest.state = Guest.State.DRY
			world.shop.request_use.rpc_id(1)  # 정상 통로 (호스트가 판정 → 아무 일 없음)
			message = "위조"
		"results_restart":
			ok = world.hud.results.visible
			message = "결과 화면 %s" % world.hud.results.visible
			var event := InputEventKey.new()
			event.physical_keycode = KEY_X
			event.pressed = true
			Input.parse_input_event(event)
			await get_tree().process_frame
			event = event.duplicate()
			event.pressed = false
			Input.parse_input_event(event)
		_:
			ok = false
			message = "모르는 단계"
	if not ok:
		fail("[%s] %s" % [step, message])
	_report.rpc_id(1, step, ok, message)


# ---------------------------------------------------------------- 공용

func _stand_facing(me: Node3D, pos: Vector3, target: Vector3) -> void:
	var to := target - pos
	me.teleport(Vector3(pos.x, 0.1, pos.z), atan2(-to.x, -to.z))
	await _wait(0.3)  # 새 위치가 호스트에 동기화될 시간


func _space() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_SPACE
		event.pressed = pressed
		Input.parse_input_event(event)
	for i in 3:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
