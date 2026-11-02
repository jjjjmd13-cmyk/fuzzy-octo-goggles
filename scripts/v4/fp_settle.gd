extends Control
## V4 하루 영업 끝 정산 (받은 손님 · 떠난 손님 · 요금 · 팁 · 합계, TUNING_V4 3장). 다시 하기 / 메뉴로.
## 화면 전체를 살짝 어둡게 덮고 가운데 판 하나. 글꼴은 프로젝트 기본 테마 (한글).

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

## 정산 글 (테스트가 읽음)
var summary_text := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_result(served: int, left: int, fees: int, tips: int) -> void:
	show_lines("오늘 영업 끝!", [
		"받은 손님  %d" % served,
		"떠난 손님  %d" % left,
		"요금  %d" % fees,
		"팁  %d" % tips,
		"합계  %d" % (fees + tips),
	], true)


## 제목 + 줄들 + [다시 하기] [메뉴로] (again = false 면 메뉴로만)
func show_lines(title: String, lines: Array, again: bool) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.9)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_label(box, title, 40)
	for line in lines:
		_label(box, line, 28)
	summary_text = "\n".join(lines)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var menu := _button(row, "메뉴로")
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	if again:
		var retry := _button(row, "다시 하기")
		row.move_child(retry, 0)
		retry.pressed.connect(func() -> void: get_tree().reload_current_scene())
		retry.grab_focus()
	else:
		menu.grab_focus()


func _label(parent: Node, text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15))
	parent.add_child(label)


func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 56)
	button.add_theme_font_size_override("font_size", 24)
	parent.add_child(button)
	return button
