extends "res://tests/qa_test.gd"
## 호스트 권한 (TEST_PLAN LANT-13, LANT-40). 호스트 1 + 클라이언트 1 (.roles).
##
## LANT-13: 클라이언트가 보낸 규칙 밖 요청·로컬 조작은 호스트의 공용 기름·등불·기름병·단계를 바꾸지 못한다.
##          (같은 통로로 보낸 정상 요청 하나는 처리되는지 같이 봐서, 요청이 아예 안 닿은 것과 구분한다.)
## LANT-40: 그림자 추적자는 호스트에서만 생각한다. 클라이언트의 추적자는 호스트가 보낸 위치·상태만 따라간다.
##
## 호스트가 단계마다 _ask 로 클라이언트에 할 일을 시키고, 클라이언트는 _report 로 결과를 돌려준다.

const Stalker := preload("res://scripts/game/stalker.gd")
const SETTLE_SEC := 0.6
const STALKER_TOLERANCE := 0.3

var _reports := {}


func run_test() -> void:
	# Net 이 씬을 바꿀 때 이 노드는 남아 있어야 하므로 현재 씬에서 뺀다.
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
	var expedition: Node = world.expedition
	var oil: Node = world.oil_tank
	var lantern: Node3D = world.lantern
	var stalker: CharacterBody3D = world.stalker
	var client_player: Node = world.get_player(client_id)
	# 값이 저절로 바뀌지 않게: 기름 소모와 추적자 AI 를 멈춘다 (호스트 쪽).
	expedition.drain_enabled = false
	stalker.set_physics_process(false)
	if not await _ask(client_id, "ready"):
		return
	await _wait(SETTLE_SEC)

	# --- LANT-13
	oil.oil = 50.0
	lantern.holder_peer = 0
	var level_before: int = lantern.level
	var round_oil_before: float = expedition.round_oil_start
	var bottle: Node3D = world.get_bottle(0)
	bottle.global_position = client_player.global_position + Vector3(30, 0, 0)  # 클라이언트에게서 멀리
	await _wait(SETTLE_SEC)
	if not await _ask(client_id, "forge"):
		return
	await _wait(SETTLE_SEC)
	check(client_player.downed, "같은 통로의 정상 요청(디버그 쓰러짐)은 처리됨 → 위조 요청도 호스트에 닿았음")
	check_eq(oil.oil, 50.0, "위조 요청 뒤 호스트 기름 그대로")
	check_eq(lantern.level, level_before, "등불을 안 든 클라이언트의 밝기 요청 무시")
	check_eq(lantern.holder_peer, 0, "등불 주인 그대로")
	check(not bottle.taken, "먼 기름병 줍기 요청 무시")
	check_eq(expedition.round_oil_start, round_oil_before, "클라이언트의 디버그 다시 시작 무시")
	check_eq(expedition.phase, expedition.Phase.PLAYING, "단계 그대로")
	# 호스트가 값을 바꾸면 클라이언트의 로컬 조작값은 덮어써진다.
	oil.oil = 42.0
	await _wait(SETTLE_SEC)
	await _ask(client_id, "oil", 42.0)

	# --- LANT-40
	var target_pos: Vector3 = stalker.position + Vector3(2, 0, 1)
	stalker.position = target_pos
	stalker.net_position = target_pos
	stalker.state = Stalker.State.STALK
	await _wait(SETTLE_SEC)
	await _ask(client_id, "stalker", 0.0, target_pos)
	check(stalker.position.distance_to(target_pos) < 0.01, "호스트 추적자 위치 그대로")

	await Net.leave_session("테스트 종료")


func _ask(client_id: int, step: String, value := 0.0, pos := Vector3.ZERO) -> bool:
	_reports.erase(step)
	_do.rpc_id(client_id, step, value, pos)
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
func _do(step: String, value: float, pos: Vector3) -> void:
	var world := get_tree().current_scene
	var ok := true
	var message := ""
	match step:
		"ready":
			while world.get_local_player() == null:
				await get_tree().process_frame
			message = "준비"
		"forge":
			var expedition: Node = world.expedition
			world.oil_tank.oil = 1.0  # 내 화면의 값만 바꿈
			expedition.send_request(expedition.ACT_DEBUG_RESTART, 999)
			expedition.send_request(expedition.ACT_PICKUP_BOTTLE, 0)
			expedition.send_request(expedition.ACT_LANTERN_LEVEL, 1)
			expedition.request.rpc_id(1, "set_oil", 100)  # 없는 동작
			# 정상 요청은 마지막에: 쓰러지면 그 뒤 요청은 "활동 중 아님"으로 걸러져 시험이 안 되므로.
			expedition.send_request(expedition.ACT_DEBUG_DOWN_SELF)
			message = "위조 요청 보냄"
		"oil":
			ok = is_equal_approx(world.oil_tank.oil, value)
			message = "기름 %.3f (호스트 %.3f)" % [world.oil_tank.oil, value]
		"stalker":
			var stalker: CharacterBody3D = world.stalker
			var near := stalker.position.distance_to(pos) < STALKER_TOLERANCE
			ok = near and stalker.state == Stalker.State.STALK
			message = "받은 위치 %s 상태 %s" % [stalker.position, stalker.state_name()]
			if ok:
				# 내 화면에서 위치를 흐트러뜨려도, 내 쪽 AI 가 움직이지 않고 호스트 값으로 돌아가야 한다.
				stalker.position = pos + Vector3(10, 0, 0)
				await get_tree().create_timer(1.5).timeout
				near = stalker.position.distance_to(pos) < STALKER_TOLERANCE
				ok = near and stalker.state == Stalker.State.STALK
				message = "흐트러뜨린 뒤 위치 %s (호스트 %s) 상태 %s" % [stalker.position, pos, stalker.state_name()]
		_:
			ok = false
			message = "모르는 단계"
	if not ok:
		fail("[%s] %s" % [step, message])
	_report.rpc_id(1, step, ok, message)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
