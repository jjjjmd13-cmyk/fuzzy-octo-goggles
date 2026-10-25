extends Node
## test_lantern_sync 의 클라이언트 쪽 (그 테스트가 별도 프로세스로 띄움, 혼자 실행하지 않음).
## 노드 이름이 서버 쪽과 같아야 RPC 가 닿는다 (/root/LanternNetTest).
## 호스트가 묻는 단계마다 내 화면의 동기화 값을 확인해 _report 로 답한다.
## 끝까지 문제가 없고 호스트가 나간 뒤 메뉴로 돌아오면 종료 코드 0.

const TIMEOUT_SEC := 55.0

var _port := 0
var _failed := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			_port = arg.trim_prefix("--port=").to_int()
	get_tree().current_scene = null
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_finish.bind(false, "시간 초과"))
	Net.join_enet("127.0.0.1", _port)
	await Net.session_started
	await Net.session_ended
	_finish(not _failed, "확인 단계 실패")


@rpc("authority", "reliable")
func _check(step: String, expected: float, pos: Vector3) -> void:
	var world := get_tree().current_scene
	var me: Node = world.get_local_player() if world != null and world.has_method("get_local_player") else null
	var ok := false
	var message := ""
	if me == null:
		message = "내 플레이어가 아직 없음"
	else:
		match step:
			"ready":
				ok = true
				message = "준비"
			"oil":
				ok = is_equal_approx(world.oil_tank.oil, expected)
				message = "기름 %.4f (호스트 %.4f)" % [world.oil_tank.oil, expected]
			"lantern_holder":
				ok = world.lantern.holder_peer == int(expected)
				message = "등불 든 사람 %d" % world.lantern.holder_peer
			"downed":
				ok = me.downed == (expected > 0.5) and me.is_active() == (expected < 0.5)
				message = "쓰러짐 %s" % me.downed
			"grab_bottle":
				world.get_bottle(0).global_position = pos
				world.expedition.send_request(world.expedition.ACT_PICKUP_BOTTLE, 0)
				ok = true
				message = "줍기 요청 보냄"
			"wick":
				ok = world.oil_tank.oil == 0.0 and world.oil_tank.in_wick() and not world.lantern.is_big_light()
				message = "기름 %.3f 심지 %s" % [world.oil_tank.oil, world.oil_tank.in_wick()]
			_:
				message = "모르는 단계"
	if not ok:
		_failed = true
		print("QA_TEST_FAIL: 클라이언트 [%s]: %s" % [step, message])
	_report.rpc_id(1, step, ok, message)


@rpc("any_peer", "reliable")
func _report(_step: String, _ok: bool, _message: String) -> void:
	pass


func _finish(ok: bool, reason: String) -> void:
	if ok:
		print("클라이언트: 통과")
		get_tree().quit(0)
	else:
		print("QA_TEST_FAIL: 클라이언트: %s" % reason)
		get_tree().quit(1)
