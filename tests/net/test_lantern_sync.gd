extends "res://tests/qa_test.gd"
## 2인(ENet) 공용 기름·쓰러짐·부활 동기화 (QA TEST_PLAN LANT-10·11·12·20·21, GDD 13장 완료 조건 4·6).
##
## 이 프로세스가 호스트, lantern_client_peer.tscn 이 클라이언트(별도 프로세스).
## 단계마다 호스트가 상태를 만들고 _check.rpc_id 로 클라이언트에 "네 화면에서 이 값이 맞는지" 묻는다.
## 클라이언트는 결과를 _report.rpc_id(1, ...) 로 돌려준다.

const PORT := 24612
const CLIENT_SCENE := "res://tests/net/lantern_client_peer.tscn"
const SETTLE_SEC := 0.6

var world: Node
var expedition: Node
var oil: Node
var lantern: Node3D
var host_player: Node
var client_player: Node
var _client_pid := -1
var _client_id := 0
var _reports := {}


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().current_scene = null
	Net.host_enet(PORT)
	await Net.session_started
	_client_pid = OS.create_process(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"), CLIENT_SCENE, "--", "--port=%d" % PORT,
	])
	if not check(_client_pid > 0, "클라이언트 프로세스 실행"):
		return
	Net.player_joined.connect(func(id: int) -> void: _client_id = id)
	while _client_id == 0:
		if not _client_alive():
			return
		await get_tree().process_frame
	world = get_tree().current_scene
	expedition = world.expedition
	oil = world.oil_tank
	lantern = world.lantern
	host_player = world.get_player(1)
	while world.get_player(_client_id) == null:
		await get_tree().process_frame
	client_player = world.get_player(_client_id)
	world.stalker.set_physics_process(false)  # 추적자는 test_stalker 에서 본다
	if not await _ask("ready", 0.0):
		return
	check_eq(expedition.party_size, 2, "동료가 들어오면 2인 수치로 다시 시작")
	check_eq(expedition.round_oil_start, 100.0, "2인 시작 기름 100")

	# --- LANT-10: 기름이 두 화면에서 똑같이 줄어듦
	await _wait(2.0)
	expedition.drain_enabled = false
	await _wait(SETTLE_SEC)
	check(oil.oil < 100.0, "기름이 줄었음 (%.3f)" % oil.oil)
	await _ask("oil", oil.oil)

	# --- 등불: 호스트가 줍고 클라이언트 옆으로 감 → 클라이언트 화면에도 '호스트가 듦'
	host_player.teleport(lantern.ground_position + Vector3(0, 0.1, 1), 0.0)
	await _wait(0.1)
	expedition.send_request(expedition.ACT_PICKUP_LANTERN)
	check_eq(lantern.holder_peer, 1, "호스트가 등불 주움")
	host_player.teleport(client_player.global_position + Vector3(-1.0, 0.1, 0), 0.0)
	await _wait(SETTLE_SEC)
	await _ask("lantern_holder", 1.0)

	# --- LANT-20: 쓰러짐이 양쪽에 같게
	expedition.down_player(client_player)
	await _wait(SETTLE_SEC)
	await _ask("downed", 1.0)

	# --- LANT-21: 등불 빛 안에서 3초 → 부활, 기름 5 한 번만
	var before: float = oil.oil
	expedition.send_request(expedition.ACT_REVIVE_START, _client_id)
	expedition.send_request(expedition.ACT_REVIVE_START, _client_id)  # 두 번 눌러도 한 번
	await _wait(Tuning.data.down_revive_time + 0.3)
	check(not client_player.downed, "3초 뒤 부활")
	check(is_equal_approx(oil.oil, maxf(before - Tuning.data.oil_revive_cost, 0.0)), "부활 기름 5 한 번만 (%.3f → %.3f)" % [before, oil.oil])
	await _wait(SETTLE_SEC)
	await _ask("downed", 0.0)
	await _ask("oil", oil.oil)

	# --- LANT-11: 두 사람이 같은 기름병을 거의 동시에 → 한 번만 더해짐
	oil.oil = 50.0
	var bottle_pos: Vector3 = (host_player.global_position + client_player.global_position) * 0.5
	world.get_bottle(0).global_position = bottle_pos
	await _ask("grab_bottle", 0.0, bottle_pos)  # 클라이언트가 같은 자리로 옮기고 줍기 요청을 보냄
	expedition.send_request(expedition.ACT_PICKUP_BOTTLE, 0)
	await _wait(SETTLE_SEC)
	check_eq(oil.oil, 50.0 + Tuning.data.oil_bottle_amount, "기름병 한 번만 더해짐")
	await _ask("oil", oil.oil)

	# --- LANT-12: 기름 0 → 모두 심지 상태, 0 아래로 안 내려감
	expedition.drain_enabled = true
	oil.oil = 0.01
	await _wait(1.0)
	expedition.drain_enabled = false
	check_eq(oil.oil, 0.0, "0 아래로 안 내려감")
	await _wait(SETTLE_SEC)
	await _ask("wick", 1.0)

	await Net.leave_session("테스트 종료")
	while OS.is_process_running(_client_pid):
		await get_tree().process_frame
	check_eq(OS.get_process_exit_code(_client_pid), 0, "클라이언트 쪽 검사 결과(종료 코드)")


## 클라이언트에 확인을 부탁하고 답을 기다린다.
func _ask(step: String, expected: float, pos := Vector3.ZERO) -> bool:
	_reports.erase(step)
	_check.rpc_id(_client_id, step, expected, pos)
	while not _reports.has(step):
		if not _client_alive():
			return false
		await get_tree().process_frame
	var report: Array = _reports[step]
	return check(report[0], "클라이언트 확인 [%s]: %s" % [step, report[1]])


@rpc("authority", "reliable")
func _check(_step: String, _expected: float, _pos: Vector3) -> void:
	pass  # 클라이언트 쪽 스크립트가 구현


@rpc("any_peer", "reliable")
func _report(step: String, ok: bool, message: String) -> void:
	_reports[step] = [ok, message]


func _client_alive() -> bool:
	if OS.is_process_running(_client_pid):
		return true
	fail("클라이언트가 먼저 끝남 (종료 코드 %d)" % OS.get_process_exit_code(_client_pid))
	return false


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, true).timeout


func _exit_tree() -> void:
	if _client_pid > 0 and OS.is_process_running(_client_pid):
		OS.kill(_client_pid)
