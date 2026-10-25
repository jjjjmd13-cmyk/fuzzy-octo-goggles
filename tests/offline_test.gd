extends Node
## 헤드리스 테스트: 혼자 하기(오프라인 호스트)로 월드가 뜨고 내 플레이어가 생기는지,
## 나가기로 메뉴에 돌아오는지 확인. 성공하면 OFFLINE_TEST_OK.


func _ready() -> void:
	get_tree().current_scene = null
	get_tree().create_timer(15.0).timeout.connect(_finish.bind(false, "시간 초과"))
	Net.start_offline()
	await Net.session_started
	var world := get_tree().current_scene
	if world == null or not world.has_method("get_player") or world.get_player(1) == null:
		_finish(false, "혼자 하기에서 플레이어 1이 없음")
		return
	if not Net.is_host() or not multiplayer.is_server():
		_finish(false, "혼자 하기가 호스트가 아님")
		return
	await Net.leave_session()
	if get_tree().current_scene.scene_file_path != Net.MENU_SCENE:
		_finish(false, "나간 뒤 메뉴가 아님")
		return
	_finish(true, "")


func _finish(ok: bool, reason: String) -> void:
	if ok:
		print("OFFLINE_TEST_OK")
		get_tree().quit(0)
	else:
		printerr("OFFLINE_TEST_FAIL: %s" % reason)
		get_tree().quit(1)
