extends "res://tests/qa_test.gd"
## 혼자 하기(오프라인 호스트)로 월드가 뜨고 내 플레이어가 생기는지,
## 나가기로 메뉴에 돌아오는지 확인.


func run_test() -> void:
	# Net 이 씬을 바꿀 때 이 노드는 남아 있어야 하므로 현재 씬에서 뺀다.
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	var world := get_tree().current_scene
	check(world != null and world.has_method("get_player"), "월드 씬이 열림")
	if world == null or not world.has_method("get_player"):
		return
	check(world.get_player(1) != null, "혼자 하기에서 플레이어 1이 생김")
	check(Net.is_host() and multiplayer.is_server(), "혼자 하기가 호스트")

	await Net.leave_session()
	check_eq(get_tree().current_scene.scene_file_path, Net.MENU_SCENE, "나간 뒤 메뉴")
