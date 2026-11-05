extends "res://tests/qa_test.gd"
## 라이선스 (사람 대표 결정): 만든 사람 목록 크레딧은 없고 엔딩 끝 고마워요 한 줄, OFL·MIT 전문은 LICENSES.txt 로 빌드에 넣고 메뉴 [라이선스] 로 봄.

const MENU_SCENE := preload("res://scenes/menu/main_menu.tscn")
const FpEnding := preload("res://scripts/v4/fp_ending.gd")


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)

	# 엔딩 끝: 고마워요 한 줄만 (만든 사람 목록 없음)
	check_eq(FpEnding.CREDITS, ["플레이해 주셔서 고마워요! / Thanks for playing!"], "엔딩 끝 한 줄")

	# LICENSES.txt: Pretendard OFL 전문 · Godot MIT 전문 · 서드파티
	var text := FileAccess.get_file_as_string("res://LICENSES.txt")
	check(text.contains("SIL OPEN FONT LICENSE Version 1.1") and text.contains("Kil Hyung-jin"), "Pretendard OFL 전문")
	check(text.contains("Permission is hereby granted, free of charge") and text.contains(Engine.get_version_info().string), "Godot MIT 전문 (지금 엔진 판)")
	check(text.contains("third-party components"), "Godot 서드파티 표시")
	# 출시 프리셋 4개 모두 LICENSES.txt 를 넣음
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	check_eq(presets.count("include_filter=\"LICENSES.txt\""), 4, "내보내기 프리셋 4개에 LICENSES.txt")

	# 메뉴 [라이선스] → 전문 창 → 닫기
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var button := menu.find_child("LicenseButton", true, false) as Button
	check(button != null, "메뉴에 [라이선스]")
	button.pressed.emit()
	await get_tree().process_frame
	var view := menu.get_node_or_null("Licenses")
	check(view != null and (view.find_child("Text", true, false) as TextEdit).text.contains("Pretendard"), "라이선스 창에 전문")
	(view.find_child("Close", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(menu.get_node_or_null("Licenses") == null, "닫기")
	menu.queue_free()
