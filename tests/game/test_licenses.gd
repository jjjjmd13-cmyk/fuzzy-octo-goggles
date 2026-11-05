extends "res://tests/qa_test.gd"
## 엔딩 크레딧·라이선스 (기획 LAUNCH_PREP 5장): 크레딧은 확정 글 그대로, OFL·MIT 전문은 LICENSES.txt 로 빌드에 넣고 메뉴 [라이선스] 로 봄.

const MENU_SCENE := preload("res://scenes/menu/main_menu.tscn")
const FpEnding := preload("res://scripts/v4/fp_ending.gd")


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)

	# 크레딧 (만든 사람 이름은 정하는 중)
	check_eq(FpEnding.CREDITS.size(), 8, "크레딧 8줄")
	for part in ["Claude (Anthropic)", "ChatGPT (OpenAI)", "CC0", "SIL Open Font License 1.1", "Godot Engine (MIT"]:
		check(FpEnding.CREDITS.any(func(line: String) -> bool: return line.contains(part)), "크레딧에 %s" % part)
	check(not FpEnding.CREDITS.any(func(line: String) -> bool: return line.contains("박준우")), "실명은 넣지 않음 (사람 대표 결정)")

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
