extends Control
## V4 엔딩 장면 (GDD_V4 '마지막 날 — 반짝 목욕 축제', 정산 뒤 1분 안):
##   1. 마당에 그동안 씻긴 단골들이 주인과 함께 모임 (만난 단골만) → 2. "찰칵" 단체 사진 (사진첩 마지막 쪽) →
##   3. 별 3개 (모두 '모은 것', 실패 없음) → 4. 짧은 크레딧 → [계속 영업하기] / [메뉴로].
## 단체 사진은 사진첩처럼 PNG 가 아니라 작은 3D 무대(SubViewport)로 다시 그림 (make_group_stage, 사진첩도 씀).
## 그림: assets/ui/album/ending_*.png 가 오면 배경 (없으면 단색).

signal continue_requested
signal menu_requested

const FpRegulars := preload("res://scripts/v4/fp_regulars.gd")
const FpAnimals := preload("res://scripts/v4/fp_animals.gd")
const OWNER_SCENE := preload("res://scenes/art/sim/owner_model.tscn")
const BROWN := Color(0.3, 0.22, 0.15)
## 엔딩 끝 한 줄 (사람 대표 결정: 만든 사람 목록 크레딧은 없음). 라이선스 전문은 메뉴 [라이선스] (LICENSES.txt)
const CREDITS := ["플레이해 주셔서 고마워요! / Thanks for playing!"]
## 한 줄에 서는 단골 수 (단체 사진)
const ROW := 8

## 단계: 0 모임 · 1 찰칵 · 2 별 · 3 크레딧 · 4 버튼
var step := 0
var stars: Array = []
var group: Array = []
var _box: VBoxContainer
var _flash: ColorRect
var _stars_label: Label
var _credits: Label
var _buttons: HBoxContainer
var _title: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## 엔딩 시작: ids = 만난 단골 (만난 순서), star_rows = FpDays.stars, sfx = 찰칵·박수 (없어도 됨)
func play(ids: Array, star_rows: Array, sfx: Node = null) -> void:
	group = ids.duplicate()
	stars = star_rows
	var shade := ColorRect.new()
	shade.color = Color(1.0, 0.96, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	center.add_child(_box)
	_title = _label("반짝 목욕 축제 끝! 그동안 씻긴 단골들이 모였어요", 32)
	_box.add_child(_title)
	var stage := make_group_stage(group, Vector2(900, 340), true)
	stage.name = "GroupPhoto"
	_box.add_child(stage)
	_stars_label = _label("", 30)
	_stars_label.visible = false
	_box.add_child(_stars_label)
	_credits = _label("\n".join(CREDITS), 24)
	_credits.visible = false
	_box.add_child(_credits)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 24)
	_buttons.visible = false
	_box.add_child(_buttons)
	var keep := _button("계속 영업하기")
	keep.name = "Continue"
	keep.pressed.connect(func() -> void: continue_requested.emit())
	var menu := _button("메뉴로")
	menu.name = "Menu"
	menu.pressed.connect(func() -> void: menu_requested.emit())
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_tween = create_tween()
	_tween.tween_interval(2.5)
	_tween.tween_callback(func() -> void:
		_snap()
		if sfx != null:
			sfx.play("press"))
	_tween.tween_property(_flash, "color:a", 0.0, 0.5).from(0.9)
	_tween.tween_interval(1.5)
	_tween.tween_callback(func() -> void:
		_show_stars()
		if sfx != null:
			sfx.play("clap"))
	_tween.tween_interval(3.0)
	_tween.tween_callback(_show_credits)
	_tween.tween_interval(3.0)
	_tween.tween_callback(_show_buttons)


## 기다리지 않고 마지막 단계까지 (테스트·클릭으로 넘기기)
func finish_now() -> void:
	if _tween != null:
		_tween.kill()
	_flash.color.a = 0.0
	_snap()
	_show_stars()
	_show_credits()
	_show_buttons()


func got_stars() -> int:
	return stars.filter(func(row: Dictionary) -> bool: return row.got).size()


func _gui_input(event: InputEvent) -> void:
	# 클릭하면 끝까지 넘김 (버튼이 나온 뒤엔 버튼만)
	if step < 4 and event is InputEventMouseButton and event.pressed:
		finish_now()


func _snap() -> void:
	step = maxi(step, 1)
	_title.text = "찰칵! 단체 사진이 사진첩 마지막 쪽에 붙었어요"


func _show_stars() -> void:
	step = maxi(step, 2)
	var parts := []
	for row in stars:
		parts.append("%s %s" % ["★" if row.got else "☆", row.name])
	_stars_label.text = "   ".join(parts)
	_stars_label.visible = true


func _show_credits() -> void:
	step = maxi(step, 3)
	_credits.visible = true


func _show_buttons() -> void:
	step = 4
	_buttons.visible = true


## 단체 사진 무대: 마당(보도블록·하늘) 위에 단골들이 줄지어 서고 (한 줄 ROW 마리, 뒷줄일수록 높게), 맨 뒤에 주인들.
## live = true 면 계속 그림 (엔딩), false 면 한 번만 (사진첩)
static func make_group_stage(ids: Array, size_px: Vector2, live: bool) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = size_px
	container.size = size_px
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(size_px)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE
	container.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.72, 0.87, 1.0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(1, 1, 1)
	environment.environment.ambient_light_energy = 0.6
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, 0.3, 0)
	viewport.add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 8)
	ground.mesh = plane
	var paving := StandardMaterial3D.new()
	paving.albedo_color = Color(0.78, 0.72, 0.66)
	ground.material_override = paving
	viewport.add_child(ground)
	var count := maxi(ids.size(), 1)
	var rows := ceili(float(count) / ROW)
	var width := minf(count, ROW) * 0.55
	for i in ids.size():
		var regular := FpRegulars.get_regular(ids[i])
		if regular.is_empty():
			continue
		var row := i / ROW
		var col := i % ROW
		var in_row := mini(ROW, ids.size() - row * ROW)
		var model := FpAnimals.scene_of(regular.animal).instantiate() as Node3D
		model.set("auto_hit_shapes", false)
		model.ready.connect(func() -> void:
			FpRegulars.dress(model, regular)
			if model.has_method("set_mood"):
				model.set_mood(2), CONNECT_ONE_SHOT)
		# 뒷줄일수록 조금 높게 (계단에 선 것처럼)
		model.position = Vector3((col - (in_row - 1) / 2.0) * 0.55, row * 0.3, -row * 0.55)
		viewport.add_child(model)
	# 주인들: 맨 뒷줄 뒤에 (단골 수만큼, 최대 한 줄)
	var owners := mini(ids.size(), ROW)
	for i in owners:
		var owner := OWNER_SCENE.instantiate() as Node3D
		owner.position = Vector3((i - (owners - 1) / 2.0) * 0.6, rows * 0.3 - 0.3, -rows * 0.55 - 0.2)
		var variant := i % 6
		owner.ready.connect(func() -> void: owner.set_variant(variant), CONNECT_ONE_SHOT)
		viewport.add_child(owner)
	var camera := Camera3D.new()
	camera.fov = 40.0
	var back := rows * 0.55 + 0.2
	var distance := maxf(width, 1.6) * 0.62 + 0.9
	camera.look_at_from_position(Vector3(0, 1.0 + rows * 0.2, distance), Vector3(0, 0.45 + rows * 0.15, -back / 2.0))
	viewport.add_child(camera)
	camera.current = true
	return container


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", BROWN)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 56)
	button.add_theme_font_size_override("font_size", 24)
	_buttons.add_child(button)
	return button
