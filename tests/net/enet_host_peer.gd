extends Node
## test_host_crash 의 호스트 쪽 (그 테스트가 별도 프로세스로 띄우고 강제 종료함, 혼자 실행하지 않음).
## 호스트를 열고 기다리기만 한다. 부모가 죽지 못했을 때를 대비해 스스로 시간 제한으로 끝난다.

const TIMEOUT_SEC := 60.0


func _ready() -> void:
	var port := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	get_tree().current_scene = null
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_finish.bind(false, "시간 초과 (강제 종료되지 않음)"))
	if port <= 0:
		_finish(false, "--port=N 필요")
		return
	Net.host_enet(port)
	await Net.session_started
	print("호스트: 열림 (포트 %d)" % port)


func _finish(ok: bool, reason: String) -> void:
	if not ok:
		print("QA_TEST_FAIL: 호스트: %s" % reason)
	get_tree().quit(0 if ok else 1)
