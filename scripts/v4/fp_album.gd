extends Control
## V4 손님 사진첩 화면 (GDD_V4 '손님 사진첩 — 사진첩 보기'). 정산 판 [사진첩] 버튼·카운터 위 사진첩 책에서 엶.
## 한 쪽 4칸 × 6쪽 = 24칸. 만난 단골은 기분 테두리(😣 회색 · 😐 흰색 · 😊 분홍 · 🤩 금색) 사진, 못 만난 단골은 '?' 실루엣.
## 사진은 PNG 로 저장하지 않고, 칸마다 작은 3D 무대(SubViewport)에서 그 단골 모형을 다시 그림 (저장은 정보만).
## 칸을 누르면 단골 카드: 이름 · 종 · 성격 · 좋아하는 곳 (찾았으면 그림) · 온 횟수 · 가장 좋은 기분.
## 그림: assets/ui/album/*.png (없으면 단색 상자).

signal closed

const FpRegulars := preload("res://scripts/v4/fp_regulars.gd")
const FpAnimals := preload("res://scripts/v4/fp_animals.gd")
const FpEnding := preload("res://scripts/v4/fp_ending.gd")
const UI_DIR := "res://assets/ui/album/%s.png"
const FRAMES := ["photo_frame_grey", "photo_frame_white", "photo_frame_pink", "photo_frame_gold"]
const FRAME_COLORS := [Color(0.7, 0.7, 0.72), Color(1, 1, 1), Color(1.0, 0.7, 0.82), Color(0.95, 0.8, 0.4)]
const MOOD_NAMES := ["😣 시무룩", "😐 보통", "😊 기쁨", "🤩 신남"]
const BROWN := Color(0.3, 0.22, 0.15)

var album: Dictionary = {}
## 엔딩 단체 사진에 선 단골 id (비면 마지막 쪽 없음). open 전에 정함
var group_photo: Array = []
var page := 0
var _grid: GridContainer
var _page_label: Label
var _card: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## 사진첩 열기 (album = 가게의 사진첩 Dictionary)
func open(data: Dictionary) -> void:
	album = data
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var paper := _texture("album_page")
	if paper != null:
		var style := StyleBoxTexture.new()
		style.texture = paper
		style.set_content_margin_all(48)
		panel.add_theme_stylebox_override("panel", style)
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(1.0, 0.97, 0.9)
		flat.set_corner_radius_all(18)
		flat.set_content_margin_all(36)
		panel.add_theme_stylebox_override("panel", flat)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "손님 사진첩 · 만난 단골 %d / %d" % [album.size(), FpRegulars.all().size()]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", BROWN)
	box.add_child(title)
	_grid = GridContainer.new()
	_grid.name = "Slots"
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 12)
	box.add_child(_grid)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var prev := _button(row, "◀")
	prev.name = "Prev"
	prev.pressed.connect(func() -> void: show_page(page - 1))
	_page_label = Label.new()
	_page_label.add_theme_color_override("font_color", BROWN)
	_page_label.add_theme_font_size_override("font_size", 20)
	row.add_child(_page_label)
	var next := _button(row, "▶")
	next.name = "Next"
	next.pressed.connect(func() -> void: show_page(page + 1))
	var close := _button(row, "닫기")
	close.name = "Close"
	close.pressed.connect(close_album)
	show_page(0)


func pages() -> int:
	return regular_pages() + (1 if not group_photo.is_empty() else 0)


func regular_pages() -> int:
	var per_page: int = Tuning.data.v4_album_page_slots
	return ceili(float(FpRegulars.all().size()) / per_page)


func show_page(index: int) -> void:
	page = clampi(index, 0, pages() - 1)
	for child in _grid.get_children():
		child.queue_free()
	_grid.columns = 2
	_page_label.text = "%d / %d 쪽" % [page + 1, pages()]
	# 마지막 쪽: 엔딩 단체 사진
	if page >= regular_pages():
		_grid.columns = 1
		var stage := FpEnding.make_group_stage(group_photo, Vector2(428, 380), false)
		stage.name = "GroupPhoto"
		_grid.add_child(stage)
		var caption := Label.new()
		caption.text = "반짝 목욕 축제 · 단체 사진 (%d마리)" % group_photo.size()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_color_override("font_color", BROWN)
		_grid.add_child(caption)
		return
	var per_page: int = Tuning.data.v4_album_page_slots
	var table := FpRegulars.all()
	for i in range(page * per_page, mini((page + 1) * per_page, table.size())):
		_grid.add_child(_slot(table[i]))
	_page_label.text = "%d / %d 쪽" % [page + 1, pages()]


func close_album() -> void:
	closed.emit()
	queue_free()


## 칸 하나: 사진(3D 무대) + 기분 테두리 + 아래 띠에 이름·온 횟수. 못 만났으면 '?' 실루엣
func _slot(regular: Dictionary) -> Control:
	var entry: Dictionary = album.get(regular.id, {})
	var slot := Button.new()
	slot.name = "Slot_" + regular.id
	slot.custom_minimum_size = Vector2(205, 240)
	slot.flat = true
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(holder)
	# 사진 자리 (프레임 구멍 64..448 / 512 → 비율로)
	var hole := Rect2(Vector2(205, 240) * Vector2(64.0 / 512.0, 64.0 / 600.0), Vector2(205, 240) * Vector2(384.0 / 512.0, 384.0 / 600.0))
	if entry.is_empty():
		var unknown := TextureRect.new()
		unknown.texture = _texture("photo_unknown")
		unknown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		unknown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		unknown.position = hole.position
		unknown.size = hole.size
		unknown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(unknown)
		_frame(holder, 1, Vector2(205, 240))
		_caption(holder, "?", Vector2(205, 240))
		slot.disabled = true
		return slot
	var photo := _photo(regular, entry, hole.size)
	photo.position = hole.position
	holder.add_child(photo)
	_frame(holder, int(entry.best_mood), Vector2(205, 240))
	_caption(holder, "%s ×%d" % [regular.name, int(entry.visits)], Vector2(205, 240))
	slot.pressed.connect(func() -> void: show_card(regular.id))
	return slot


## 작은 3D 무대: 그 단골 모형 (털 색·크기), 기분 표정, 그때 벽지 색 배경
func _photo(regular: Dictionary, entry: Dictionary, size_px: Vector2) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.name = "Photo"
	container.stretch = true
	container.size = size_px
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(size_px)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(1.0, 0.95, 0.85) if entry.get("wall", "") == "" else Color(0.9, 0.95, 1.0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(1, 1, 1)
	environment.environment.ambient_light_energy = 0.6
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.7, 0.4, 0)
	viewport.add_child(light)
	var model := FpAnimals.scene_of(regular.animal).instantiate() as Node3D
	model.set("auto_hit_shapes", false)
	# 칸이 화면에 붙을 때 모형이 준비되므로 그때 털 색·표정을 입힘
	model.ready.connect(func() -> void:
		FpRegulars.dress(model, regular)
		if model.has_method("set_mood"):
			model.set_mood(FpAnimals.model_mood(int(entry.best_mood))), CONNECT_ONE_SHOT)
	viewport.add_child(model)
	var camera := Camera3D.new()
	camera.fov = 40.0
	# 칸이 아직 화면에 안 붙었을 때 만들어지므로 look_at_from_position (트리 밖에서도 됨)
	camera.look_at_from_position(Vector3(0, 0.38, 1.05) * float(regular.scale), Vector3(0, 0.28, 0) * float(regular.scale))
	viewport.add_child(camera)
	camera.current = true
	return container


func _frame(holder: Control, mood: int, size_px: Vector2) -> void:
	var texture := _texture(FRAMES[clampi(mood, 0, 3)])
	if texture != null:
		var frame := TextureRect.new()
		frame.name = "Frame"
		frame.texture = texture
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.size = size_px
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_meta("mood", mood)
		holder.add_child(frame)
	else:
		var border := ReferenceRect.new()
		border.name = "Frame"
		border.border_color = FRAME_COLORS[clampi(mood, 0, 3)]
		border.border_width = 8
		border.editor_only = false
		border.size = size_px
		border.set_meta("mood", mood)
		holder.add_child(border)


func _caption(holder: Control, text: String, size_px: Vector2) -> void:
	var label := Label.new()
	label.name = "Caption"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", BROWN)
	label.position = Vector2(0, size_px.y * 0.8)
	label.size = Vector2(size_px.x, size_px.y * 0.15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)


## 단골 카드 (칸을 누르면): 이름 · 종 · 성격 · 좋아하는 곳 · 온 횟수 · 가장 좋은 기분
func show_card(id: String) -> void:
	if is_instance_valid(_card):
		_card.queue_free()
	var regular := FpRegulars.get_regular(id)
	var entry: Dictionary = album.get(id, {})
	_card = PanelContainer.new()
	_card.name = "Card"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.98, 0.94)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(24)
	_card.add_theme_stylebox_override("panel", style)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_card.add_child(box)
	var trait_name: String = FpAnimals.TRAITS[regular.trait].name if FpAnimals.TRAITS.has(regular.trait) else "성격 없음"
	var fav: String = FpAnimals.FAV_NAMES.get(regular.fav, "") if entry.get("fav_found", false) else "?"
	for line in [regular.name, "%s · %s · 털 %s" % ["고양이" if regular.animal == "cat" else "강아지", trait_name, regular.color], "좋아하는 곳: %s" % fav, "온 횟수: %d" % int(entry.get("visits", 0)), "가장 좋은 기분: %s" % MOOD_NAMES[clampi(int(entry.get("best_mood", 0)), 0, 3)]]:
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 22 if line == regular.name else 18)
		label.add_theme_color_override("font_color", BROWN)
		box.add_child(label)
	if entry.get("fav_found", false):
		var picture := TextureRect.new()
		picture.name = "FavPicture"
		picture.texture = _texture("fav_spot_" + regular.fav)
		picture.custom_minimum_size = Vector2(96, 96)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(picture)
	var ok := _button(box, "닫기")
	ok.pressed.connect(func() -> void: _card.queue_free())
	_card.position = (get_viewport_rect().size - Vector2(360, 360)) / 2.0


func _texture(name_id: String) -> Texture2D:
	var path := UI_DIR % name_id
	return load(path) if ResourceLoader.exists(path) else null


func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(90, 44)
	button.add_theme_font_size_override("font_size", 20)
	parent.add_child(button)
	return button
