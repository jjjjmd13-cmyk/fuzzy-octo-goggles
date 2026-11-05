extends Control
## V4 하루 영업 끝 정산 (받은·떠난 손님, 요금 + 팁, 가진 돈) + 도구 가게 + [다음 날]. 빠른 확인 끝 화면도 show_lines 로.
## 화면 전체를 살짝 어둡게 덮고 가운데 판 하나. 글꼴은 프로젝트 기본 테마 (한글).

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

signal buy_requested(tool_id: String)
## 꾸미기: 산 것을 놓음 ("default:<범주>" = 처음 모습으로)
signal place_requested(id: String)
signal next_day_requested
## 손님 사진첩 열기 (정산 판 [사진첩] 버튼)
signal album_requested

## 지금 보이는 탭 ("tools" 도구 가게 / "decor" 꾸미기). 다시 그려도 그대로
var tab := "tools"

## 정산 글 (테스트가 읽음)
var summary_text := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## 제목 + 줄들 + [다시 하기] [메뉴로] (again = false 면 메뉴로만)
func show_lines(title: String, lines: Array, again: bool, line_size := 28) -> void:
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
	box.add_theme_constant_override("separation", 14 if line_size >= 28 else 8)
	panel.add_child(box)
	_label(box, title, 40 if line_size >= 28 else 34)
	for line in lines:
		_label(box, line, line_size)
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


## 하루 끝 + 가게: 줄들, [도구 가게] [꾸미기] 탭, 도구마다 [다음 단계 값] 버튼 (돈이 모자라면 꺼짐), [다음 날] [메뉴로].
## 사면 buy_requested → 부른 쪽이 다시 이 함수로 새로 그림
## decor = {"title": 아늑함 한 줄, "rows": 범주마다 {category, name, default_placed, items: [{id, name, stars, price, state, can_buy}]}}
## (비면 꾸미기 탭 없음). state: "buy" 사기 / "owned" 산 것 (놓기) / "placed" 놓임 / "coming" 택배로 오는 중
func show_day_end(title: String, lines: Array, store: Array, decor := {}) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	# 줄이 많아도 가게까지 한 화면에 (720p)
	show_lines(title, lines, false, 22)
	var outer := find_child("Lines", true, false) as VBoxContainer
	var buttons := outer.get_child(outer.get_child_count() - 1)
	# 탭: [도구 가게] [꾸미기]
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	outer.add_child(tabs)
	outer.move_child(tabs, buttons.get_index())
	for pair in [["tools", "도구 가게"], ["decor", "꾸미기"]]:
		if pair[0] == "decor" and decor.is_empty():
			continue
		var tab_button := _button(tabs, pair[1])
		tab_button.name = "Tab_" + pair[0]
		tab_button.toggle_mode = true
		tab_button.button_pressed = tab == pair[0]
		tab_button.custom_minimum_size = Vector2(160, 44)
		var id: String = pair[0]
		tab_button.pressed.connect(func() -> void:
			tab = id
			_show_tab())
	# 도구·가게 물건 줄도 두 줄로 (720p 한 화면에 [다음 날] 까지 보이게)
	var box := GridContainer.new()
	box.name = "ToolsBox"
	box.columns = 2
	box.add_theme_constant_override("h_separation", 28)
	box.add_theme_constant_override("v_separation", 8)
	outer.add_child(box)
	outer.move_child(box, buttons.get_index())
	if not decor.is_empty():
		var decor_box := _decor_box(decor)
		outer.add_child(decor_box)
		outer.move_child(decor_box, buttons.get_index())
	for item in store:
		var row := HBoxContainer.new()
		row.name = "Store_" + item.id
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = "%s → %s" % [item.name, item.next] if item.price >= 0 else "%s (최고)" % item.name
		label.custom_minimum_size = Vector2(300, 0)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15))
		row.add_child(label)
		if item.price >= 0:
			var buy := _button(row, "%d 사기" % item.price)
			buy.name = "Buy"
			buy.custom_minimum_size = Vector2(110, 36)
			buy.add_theme_font_size_override("font_size", 16)
			buy.disabled = not item.can_buy
			var id: String = item.id
			buy.pressed.connect(func() -> void: buy_requested.emit(id))
		box.add_child(row)
	_show_tab()
	var album := _button(buttons, "사진첩")
	album.name = "Album"
	album.pressed.connect(func() -> void: album_requested.emit())
	var next := _button(buttons, "다음 날")
	next.name = "NextDay"
	buttons.move_child(next, 0)
	next.pressed.connect(func() -> void: next_day_requested.emit())
	next.grab_focus()


func _show_tab() -> void:
	if not find_child("DecorBox", true, false):
		tab = "tools"
	for pair in [["tools", "ToolsBox"], ["decor", "DecorBox"]]:
		var section := find_child(pair[1], true, false) as Control
		if section != null:
			section.visible = tab == pair[0]
		var tab_button := find_child("Tab_" + pair[0], true, false) as Button
		if tab_button != null:
			tab_button.set_pressed_no_signal(tab == pair[0])


## 꾸미기 탭: 아늑함 한 줄 + 범주마다 한 줄 [처음] [★1] [★2] [★3]
func _decor_box(decor: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "DecorBox"
	box.add_theme_constant_override("separation", 6)
	_label(box, decor.title, 20)
	# 10범주를 두 줄로 (한 화면에 다 보이게)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for row_data in decor.rows:
		var row := HBoxContainer.new()
		row.name = "Decor_" + row_data.category
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = row_data.name
		label.custom_minimum_size = Vector2(80, 0)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15))
		row.add_child(label)
		var first := _small_button(row, "처음" if not row_data.default_placed else "✔ 처음")
		first.name = "Default"
		first.disabled = row_data.default_placed
		var category: String = row_data.category
		first.pressed.connect(func() -> void: place_requested.emit("default:" + category))
		for item in row_data.items:
			var text := "%s %s" % ["★".repeat(item.stars), item.name]
			match item.state:
				"buy":
					text += " %d" % item.price
				"placed":
					text = "✔ " + text
				"coming":
					text += " 📦"
			var button := _small_button(row, text)
			button.name = item.id
			button.disabled = item.state == "placed" or item.state == "coming" or (item.state == "buy" and not item.can_buy)
			var id: String = item.id
			if item.state == "buy":
				button.pressed.connect(func() -> void: buy_requested.emit(id))
			else:
				button.pressed.connect(func() -> void: place_requested.emit(id))
		grid.add_child(row)
	return box


func _small_button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 32)
	button.add_theme_font_size_override("font_size", 14)
	parent.add_child(button)
	return button


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
