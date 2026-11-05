extends SceneTree
## LICENSES.txt 만들기 (출시 빌드에 넣는 라이선스 전문, 기획 LAUNCH_PREP 5장).
## Godot 엔진 MIT 전문·저작권 표시·포함된 서드파티 라이선스는 지금 쓰는 Godot 에서 그대로 읽어 옴 (Engine.get_license_text 등),
## Pretendard OFL 은 assets/fonts/pretendard/LICENSE.txt 그대로. 엔진·글꼴을 바꾸면 다시 돌린다:
##   godot --headless --script tools/make_licenses.gd

const OUT := "res://LICENSES.txt"
const RULE := "\n================================================================\n"


func _init() -> void:
	var parts: PackedStringArray = []
	parts.append("멍냥 목욕탕 (Paws & Bubbles) — 라이선스 / Licenses\n\n이 게임에 들어간 외부 소프트웨어·글꼴의 라이선스 전문입니다.\nThis file lists the full license texts of third-party software and fonts in this game.\n\n- 그래픽 / Art: ChatGPT (OpenAI) 로 만든 이 게임 전용 그림 (외부 에셋 없음)\n- 음악·효과음 / Music & sound: 코드로 직접 만듦, CC0 1.0 (assets/music/LICENSE.md)\n- 글꼴 / Font: Pretendard — SIL Open Font License 1.1 (아래)\n- 엔진 / Engine: Godot Engine — MIT License (아래)")
	parts.append("Pretendard — SIL Open Font License 1.1\n\n" + FileAccess.get_file_as_string("res://assets/fonts/pretendard/LICENSE.txt").strip_edges())
	var version: Dictionary = Engine.get_version_info()
	parts.append("Godot Engine %s — MIT License\n\nThis game uses Godot Engine, available under the following license:\n\n%s" % [version.string, Engine.get_license_text().strip_edges()])
	var third: PackedStringArray = ["Godot Engine — third-party components (COPYRIGHT)\n"]
	for info in Engine.get_copyright_info():
		third.append("- %s" % info.name)
		for part in info.parts:
			third.append("  Files: %s" % ", ".join(part.files))
			for line in part.copyright:
				third.append("  Copyright: %s" % line)
			third.append("  License: %s" % part.license)
	parts.append("\n".join(third))
	var licenses: Dictionary = Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for name in names:
		parts.append("License: %s\n\n%s" % [name, str(licenses[name]).strip_edges()])
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(RULE.join(parts) + "\n")
	file.close()
	print("LICENSES.txt: %d bytes" % FileAccess.get_file_as_bytes(OUT).size())
	quit()
