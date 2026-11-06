extends "res://tests/qa_test.gd"
## 출시용 메뉴 첫 화면 (대표 결정, QA #139): V4 하나 — [이어하기] (저장이 있을 때) · [새로 시작] · [설정] · [라이선스] · [끝내기].
## V3·개발용 버튼은 출시 빌드에서 안 보임 (개발 빌드에선 아래 '개발용' 칸). 새로 시작은 저장이 있으면 한 번 물어봄.

const MENU_SCENE := preload("res://scenes/menu/main_menu.tscn")
const V4Save := preload("res://scripts/v4/v4_save.gd")
const Settings := preload("res://scripts/core/settings.gd")


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	var real_save := V4Save.path
	var real_settings := Settings.path
	V4Save.path = "user://test_release_menu_save.json"
	Settings.path = "user://test_release_menu_settings.cfg"
	V4Save.erase()

	# 저장 없음 · 출시 빌드처럼: 보이는 버튼은 새로 시작·설정·라이선스·끝내기
	var menu := MENU_SCENE.instantiate()
	menu.release_preview = true
	add_child(menu)
	await get_tree().process_frame
	check_eq(_visible_buttons(menu), ["새로 시작", "설정", "라이선스", "끝내기"], "출시 첫 화면 (저장 없음)")
	check(not menu.solo_button.visible and menu.find_child("V3Title", true, false) == null, "V3 [혼자 하기] 숨김")
	var quick := menu.find_child("QuickCheckRow", true, false) as Control
	check(quick == null or not quick.visible, "빠른 확인 줄 숨김")
	# 설정: 효과음·음악
	(menu.find_child("SettingsButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var panel := menu.get_node_or_null("SettingsPanel")
	check(panel != null and panel.find_child("Sfx", true, false) != null and panel.find_child("Music", true, false) != null, "설정: 효과음·음악")
	(panel.find_child("Music", true, false) as HSlider).value = 0.3
	check(is_equal_approx(Settings.music_volume, 0.3), "음악 크기 바뀜")
	(panel.find_child("Close", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(menu.get_node_or_null("SettingsPanel") == null, "설정 닫기")
	menu.free()

	# 저장 있음: [이어하기 (N일차부터)] 가 맨 위, 새로 시작은 한 번 물어봄
	var data := V4Save.fresh()
	data.next_day = 5
	V4Save.write(data)
	menu = MENU_SCENE.instantiate()
	menu.release_preview = true
	add_child(menu)
	await get_tree().process_frame
	check_eq(_visible_buttons(menu), ["이어하기 (5일차부터)", "새로 시작", "설정", "라이선스", "끝내기"], "출시 첫 화면 (저장 있음)")
	menu.start_new_v4()
	await get_tree().process_frame
	var dialog := menu.get_node_or_null("NewConfirm") as ConfirmationDialog
	check(dialog != null and dialog.dialog_text.contains("5일차"), "새로 시작: 저장이 지워진다고 물어봄")
	dialog.canceled.emit()
	check(V4Save.exists(), "돌아가기면 저장 그대로")
	menu.free()

	# 개발 빌드: 아래쪽 개발용 칸에 빠른 확인·V3
	menu = MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu.find_child("V3Title", true, false) != null and menu.solo_button.visible, "개발 빌드: V3 버튼은 개발용 칸에")
	var box: Node = menu.solo_button.get_parent()
	check(menu.solo_button.get_index() > (menu.find_child("QuitButton", true, false) as Node).get_index(), "개발용 칸은 끝내기 아래")
	menu.free()

	V4Save.erase()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	V4Save.path = real_save
	Settings.path = real_settings


func _visible_buttons(menu: Node) -> Array:
	var box: Node = menu.solo_button.get_parent()
	var out := []
	for child in box.get_children():
		if child is Button and (child as Button).visible:
			out.append((child as Button).text)
	return out
