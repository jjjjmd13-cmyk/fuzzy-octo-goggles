extends Control
## V4 하루 영업 끝 정산 (받은·떠난 손님, 요금 + 팁, 가진 돈) + 도구 가게 + [다음 날]. 빠른 확인 끝 화면도 show_lines 로.
## 화면 전체를 살짝 어둡게 덮고 가운데 판 하나. 글꼴은 프로젝트 기본 테마 (한글).

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

signal buy_requested(tool_id: String)
signal next_day_requested

## 정산 글 (테스트가 읽음)
var summary_text := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


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
	box.name = "Lines"
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


## 하루 끝 + 가게: 줄들, 도구마다 [다음 단계 값] 버튼 (돈이 모자라면 꺼짐), [다음 날] [메뉴로].
## 사면 buy_requested → 부른 쪽이 다시 이 함수로 새로 그림
func show_day_end(title: String, lines: Array, store: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	show_lines(title, lines, false)
	var box := find_child("Lines", true, false) as VBoxContainer
	var buttons := box.get_child(box.get_child_count() - 1)
	var store_title := Label.new()
	store_title.text = "도구 가게"
	store_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	store_title.add_theme_font_size_override("font_size", 26)
	store_title.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15))
	box.add_child(store_title)
	box.move_child(store_title, buttons.get_index())
	for item in store:
		var row := HBoxContainer.new()
		row.name = "Store_" + item.id
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = "%s → %s" % [item.name, item.next] if item.price >= 0 else "%s (최고)" % item.name
		label.custom_minimum_size = Vector2(340, 0)
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15))
		row.add_child(label)
		if item.price >= 0:
			var buy := _button(row, "%d 사기" % item.price)
			buy.name = "Buy"
			buy.custom_minimum_size = Vector2(130, 40)
			buy.add_theme_font_size_override("font_size", 18)
			buy.disabled = not item.can_buy
			var id: String = item.id
			buy.pressed.connect(func() -> void: buy_requested.emit(id))
		box.add_child(row)
		box.move_child(row, buttons.get_index())
	var next := _button(buttons, "다음 날")
	next.name = "NextDay"
	buttons.move_child(next, 0)
	next.pressed.connect(func() -> void: next_day_requested.emit())
	next.grab_focus()


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
