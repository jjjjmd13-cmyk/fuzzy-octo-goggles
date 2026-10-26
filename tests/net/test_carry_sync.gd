extends "res://tests/qa_test.gd"
## 2인 들기 동기화와 호스트 권한 (호스트 1 + 클라이언트 1, .roles).
##
## 1. 호스트가 든 물건이 클라이언트 화면에서도 호스트 손에 있음
## 2. 클라이언트가 든 물건이 호스트에서도 클라이언트 것
## 3. 같은 물건을 둘이 집으려 하면 한 사람만 듦 (양쪽 화면이 같음)
## 4. 건네기: 클라이언트 → 호스트
## 5. 위조 요청(먼 물건 줍기, 없는 동작, 내 화면 값 조작)은 호스트를 못 바꿈
## 6. 물건을 든 채 클라이언트가 나가면 호스트에서 그 자리에 떨어짐
## 호스트가 단계마다 _ask 로 클라이언트에 할 일을 시키고, 클라이언트는 _report 로 답한다.

const SETTLE_SEC := 0.5

var _reports := {}


func run_test() -> void:
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
	var rules: Node = world.carry_rules
	var me: Node3D = world.get_player(1)
	var crate_a: Node3D = world.get_node("Props/CrateA")
	var crate_b: Node3D = world.get_node("Props/CrateB")
	var crate_c: Node3D = world.get_node("Props/CrateC")
	if not await _ask(client_id, "ready"):
		return

	# 1. 호스트가 A 를 듦
	await _teleport(me, crate_a.global_position + Vector3(0, 0, 1))
	rules.send_request(rules.ACT_PICKUP, crate_a)
	check_eq(crate_a.holder_peer, 1, "호스트가 A 를 듦")
	await _wait(SETTLE_SEC)
	await _ask(client_id, "holder", "CrateA", 1)

	# 2. 클라이언트가 B 를 듦
	await _ask(client_id, "grab", "CrateB")
	await _wait(SETTLE_SEC)
	check_eq(crate_b.holder_peer, client_id, "호스트 화면: 클라이언트가 B 를 듦")

	# 3. C 를 둘이 집으려 함: 클라이언트가 B 를 내려놓고 C 로 가서 요청, 호스트도 A 를 내려놓고 요청
	rules.send_request(rules.ACT_DROP)
	await _ask(client_id, "drop")
	await _teleport(me, crate_c.global_position + Vector3(-0.8, 0, 0.6))
	await _ask(client_id, "grab", "CrateC")
	rules.send_request(rules.ACT_PICKUP, crate_c)
	await _wait(SETTLE_SEC)
	check_eq(crate_c.holder_peer, client_id, "먼저 온 요청(클라이언트)만 처리됨")
	check(rules.held_by(1) == null, "호스트는 아무것도 못 듦")
	await _ask(client_id, "holder", "CrateC", client_id)

	# 4. 건네기: 클라이언트 → 호스트 (호스트가 바로 옆에 있음)
	var client_player: Node3D = world.get_player(client_id)
	await _teleport(me, client_player.global_position + Vector3(1.0, 0, 0))
	await _ask(client_id, "give")
	await _wait(SETTLE_SEC)
	check_eq(crate_c.holder_peer, 1, "건네받음")
	await _ask(client_id, "holder", "CrateC", 1)

	# 5. 위조 요청
	await _ask(client_id, "forge")
	await _wait(SETTLE_SEC)
	check_eq(crate_a.holder_peer, 0, "먼 A 줍기 요청 무시")
	check_eq(crate_c.holder_peer, 1, "호스트가 든 C 는 그대로")
	check(rules.held_by(client_id) == null, "클라이언트는 여전히 빈손")

	# 6. 클라이언트가 B 를 든 채 나감 → 호스트에서 떨어짐
	await _ask(client_id, "grab", "CrateB")
	await _wait(SETTLE_SEC)
	check_eq(crate_b.holder_peer, client_id, "클라이언트가 B 를 다시 듦")
	var last_pos := client_player.global_position
	_do.rpc_id(client_id, "leave", "", 0)
	var left_id: int = await Net.player_left
	check_eq(left_id, client_id, "클라이언트가 나감")
	await get_tree().process_frame
	check_eq(crate_b.holder_peer, 0, "나간 사람이 든 물건은 떨어짐")
	check(rules.horizontal_distance(crate_b.ground_position, last_pos) < 1.5, "나간 자리 근처에 떨어짐")
	await Net.leave_session("테스트 종료")


func _ask(client_id: int, step: String, item := "", value := 0) -> bool:
	_reports.erase(step)
	_do.rpc_id(client_id, step, item, value)
	while not _reports.has(step):
		await get_tree().process_frame
	var report: Array = _reports[step]
	return check(report[0], "클라이언트 [%s %s]: %s" % [step, item, report[1]])


@rpc("any_peer", "reliable")
func _report(step: String, ok: bool, message: String) -> void:
	_reports[step] = [ok, message]


# ---------------------------------------------------------------- 클라이언트

func _run_client() -> void:
	Net.join_enet("127.0.0.1", port)
	await Net.session_started
	await Net.session_ended
	check_eq(get_tree().current_scene.scene_file_path, Net.MENU_SCENE, "나간 뒤 메뉴")


@rpc("authority", "reliable")
func _do(step: String, item_name: String, value: int) -> void:
	var world := get_tree().current_scene
	var ok := true
	var message := ""
	while world.get_local_player() == null:
		await get_tree().process_frame
	var me: Node3D = world.get_local_player()
	var rules: Node = world.carry_rules
	var item: Node3D = world.get_node_or_null("Props/" + item_name) if not item_name.is_empty() else null
	match step:
		"ready":
			message = "준비"
		"holder":
			ok = item.holder_peer == value
			message = "%s 든 사람 %d (기대 %d)" % [item_name, item.holder_peer, value]
		"grab":
			await _teleport(me, item.global_position + Vector3(0.8, 0, 0.6))
			rules.send_request(rules.ACT_PICKUP, item)
			message = "줍기 요청"
		"drop":
			rules.send_request(rules.ACT_DROP)
			await _wait(SETTLE_SEC)
			ok = rules.held_by(me.get_peer_id()) == null
			message = "내려놓음"
		"give":
			rules.send_request(rules.ACT_GIVE)
			message = "건네기 요청"
		"forge":
			var far: Node3D = world.get_node("Props/CrateA")
			rules.send_request(rules.ACT_PICKUP, far)  # 너무 멂
			rules.request.rpc_id(1, "teleport_item", "Props/CrateC")  # 없는 동작
			rules.request.rpc_id(1, rules.ACT_PICKUP, "../../root")  # 물건이 아닌 경로
			world.get_node("Props/CrateC").holder_peer = me.get_peer_id()  # 내 화면 값만 바꿈
			message = "위조 요청 보냄"
		"leave":
			Net.leave_session()
			return
		_:
			ok = false
			message = "모르는 단계"
	if not ok:
		fail("[%s %s] %s" % [step, item_name, message])
	_report.rpc_id(1, step, ok, message)


# ---------------------------------------------------------------- 공용

func _teleport(player: Node3D, pos: Vector3) -> void:
	player.teleport(Vector3(pos.x, 0.1, pos.z), 0.0)
	# 새 위치가 상대에게 동기화될 시간
	await _wait(0.3)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
