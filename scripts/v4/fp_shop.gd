extends Node3D
## V4 1인칭 회색 상자 시제품 (사람 대표 플레이 뒤 방향 전환, 2026-10-30).
##
## 가게를 걸어다니며(WASD + 마우스) 선반의 3D 도구를 집고(클릭), 목욕통의 강아지에 대고
## 누르고 있으면 쓱쓱 바로 씻긴다. 원 그리기·고정 카메라·2D 커서 없음. 큰 붓·빠른 진행.
##   샤워기 = 적시기 + 거품 헹구기 / 샴푸 = 젖은 곳에 거품 (진흙이 지워짐) / 수건 = 젖은 곳 말리기
## 다 되면 강아지가 펄쩍 + 꼬리 흔들기. 쓰는 동안 가끔 몸 털기(물 튀김).
## 방은 코드로 만드는 임시 상자. 강아지는 V3 의 WashDog(GLB·털 셰이더·칠하기 마스크)를 그대로 쓴다.
## V3 코드는 그대로 두고 이 씬만 새로 (scenes/v4/fp_shop.tscn).

const WashDog := preload("res://scripts/sim/wash_dog.gd")
const Sfx := preload("res://scripts/game/sfx.gd")
const FpPlayer := preload("res://scripts/v4/fp_player.gd")
const FpGuests := preload("res://scripts/v4/fp_guests.gd")
const TUB_SCENE := preload("res://scenes/art/sim/tub_model.tscn")
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

const PICK_LAYER := 2
const DOG_LAYER := 16
## 손이 닿는 거리 (m)
const REACH := 2.4
## 강아지가 앉는 곳 (목욕통 위)
const DOG_SPOT := Vector3(0, 0.92, -1.6)
## 도구: 이름, 칠하는 채널, 색. 붓 크기·속도·완료 기준은 Tuning.data.v4_* (GDD_V4)
## 단계마다 처음 닿을 때 반응 하나: 적시기 다리 찰랑 / 거품 펄쩍 / 헹구기 몸 털기+물 튐 / 말리기 다리 찰랑
const STAGE_REACTION := {"wet": "wiggle_legs", "scrub": "jump", "rinse": "shake", "dry": "wiggle_legs"}
const TOOLS := {
	"shower": {"name": "샤워기", "channel": "wet", "color": Color(0.7, 0.8, 0.9)},
	"shampoo": {"name": "샴푸", "channel": "scrub", "color": Color(1.0, 0.6, 0.75)},
	"towel": {"name": "수건", "channel": "dry", "color": Color(0.95, 0.95, 0.85)},
}

## false 면 마우스·키 입력을 읽지 않는다 (테스트가 using 등을 직접 넣음)
var input_enabled := true
## 지금 도구를 쓰는 중 (왼쪽 버튼을 누르고 있음)
var using := false
## 손에 든 도구 ("" = 빈손)
var held := ""
## 바라보는 집을 수 있는 도구 ("" = 없음)
var hovered := ""
## 바라보는 강아지 위 점 (없으면 null)
var aim_point: Variant = null
var done := false
var dog: WashDog
var player: CharacterBody3D
var sfx: Node
## 대기 의자 손님들 (참을성)
var guests: FpGuests

var _pickups := {}
var _held_view: Node3D
var _rng := RandomNumberGenerator.new()
var _foam_carry := 0.0
var _reacted := {}
var _towel_tick := 0.0
var _hint := ""
var _hint_left := 0.0
var _hud: Control
var _dogs := 0


func _ready() -> void:
	_rng.randomize()
	_build_room()
	_build_shelf()
	sfx = Sfx.new()
	add_child(sfx)
	dog = WashDog.new()
	dog.name = "Dog"
	dog.position = DOG_SPOT
	dog.rotation.y = PI * 0.15
	add_child(dog)
	guests = FpGuests.new()
	guests.name = "Guests"
	add_child(guests)
	guests.guest_left.connect(_on_guest_left)
	_build_player()
	_build_hud()
	new_dog()


## 새 강아지 (진흙 무늬 무작위)
func new_dog() -> void:
	_dogs += 1
	dog.setup(Tuning.data.mask_resolution, _rng.randi_range(0, 2), _rng.randi())
	dog.show_mask()
	dog.react("set_mood", 1)
	done = false
	_reacted.clear()
	_show_hint("강아지를 씻겨 주세요: 샤워기 → 샴푸 → 샤워기로 헹구기 → 수건", 4.0)


## 다 씻었으면 대기 의자 맨 앞 손님을 받는다 (지금 주인은 기뻐하며 나감)
func next_guest() -> void:
	if not done:
		_show_hint("다 씻기고 나서 R: 다음 손님", 1.5)
		return
	var kind := guests.call_next()
	new_dog()
	if kind.is_empty():
		_show_hint("기다리는 손님이 없어요. 곧 와요", 2.0)
	elif kind == "hurry":
		_show_hint("급한 손님을 제때 받았어요! (팁 +)", 2.5)
	else:
		_show_hint("%s 손님의 강아지예요" % FpGuests.KIND_NAMES[kind], 2.0)


func _on_guest_left(kind: String) -> void:
	_show_hint("%s 손님이 \"다음에 올게요\" 하고 떠났어요" % FpGuests.KIND_NAMES[kind], 2.5)
	sfx.play("bell")


## 진행 (0~1): 물·거품(진흙)·말리기, 남은 거품 수
func progress() -> Dictionary:
	return {"wet": dog.mask.ratio("wet"), "scrub": dog.mask.ratio("scrub"), "dry": dog.mask.ratio("dry"), "foam": dog.foam_count()}


func pick(tool_id: String) -> void:
	if held == tool_id:
		return
	drop()
	held = tool_id
	(_pickups[tool_id] as Node3D).visible = false
	_held_view = _make_tool_mesh(tool_id)
	_held_view.position = Vector3(0.26, -0.3, -0.55)
	_held_view.rotation = Vector3(0.3, -0.4, 0)
	player.camera.add_child(_held_view)
	sfx.play("press")


func drop() -> void:
	if held.is_empty():
		return
	(_pickups[held] as Node3D).visible = true
	held = ""
	if _held_view != null:
		_held_view.queue_free()
		_held_view = null
	_stop_effects()


## 든 도구를 강아지 위 point(월드)에 delta 초 동안 쓴다 (마우스를 누르고 있는 동안 매 프레임)
func use_tool_at(point: Vector3, delta: float) -> void:
	if held.is_empty() or done:
		return
	var dir := dog.dir_of(point)
	var wet_here := dog.mask.value_at("wet", dir)
	var radius := brush_radius(point)
	var stage := ""
	match held:
		"shower":
			stage = "wet"
			dog.paint("wet", point, radius, Tuning.data.v4_rate_shower * delta)
			if dog.foam_count() > 0:
				stage = "rinse"
				dog.rinse_foam(point, radius, delta * 40.0)
				dog.paint("rinse", point, radius, Tuning.data.v4_rate_shower * delta)
			dog.spray(point)
			dog.show_stream(_tool_tip(), point, Color(0.55, 0.85, 1.0))
			sfx.set_loop("shower", 0.8)
		"shampoo":
			if wet_here < 0.3:
				_show_hint("먼저 샤워기로 물을 뿌려요", 1.5)
				return
			stage = "scrub"
			dog.paint("scrub", point, radius, Tuning.data.v4_rate_shampoo * delta)
			_foam_carry += delta * 10.0
			while _foam_carry >= 1.0:
				_foam_carry -= 1.0
				dog.add_foam(point, 1, _rng, 1.4)
			sfx.set_loop("scrub", 0.8)
		"towel":
			stage = "dry"
			if dog.foam_count() > 0 and dog.mask.value_at("scrub", dir) > 0.5:
				_show_hint("거품을 샤워기로 먼저 헹궈요", 1.5)
			dog.paint("dry", point, radius, Tuning.data.v4_rate_towel * delta * clampf(wet_here + 0.2, 0.0, 1.0))
			_towel_tick -= delta
			if _towel_tick <= 0.0:
				_towel_tick = 0.35
				dog.press_effect(point)
				sfx.play("towel")
	# 반응: 씻는 동안 꼬리 흔들기 + 도구를 바라봄, 단계마다 처음 한 번 몸짓 (칠하기는 멈추지 않음)
	dog.react("set_mood", 2)
	if dog.model.has_method("watch"): dog.model.watch(point, true)
	if not _reacted.has(stage):
		_reacted[stage] = true
		dog.react(STAGE_REACTION[stage])
		if stage == "rinse":
			dog.splash()
			sfx.play("shake")
	_check_done()


## 붓 반경(m): 몸 겉면의 v4_brush_share 만큼 덮는 원 (구 위 원뿔 각 → 몸 중심에서의 거리)
func brush_radius(point: Vector3) -> float:
	var angle := acos(1.0 - 2.0 * Tuning.data.v4_brush_share)
	return angle * maxf(dog.dir_of(point).length(), 0.05)


func _check_done() -> void:
	var p := progress()
	var done_at: float = Tuning.data.v4_done_ratio
	if p.wet >= done_at and p.scrub >= done_at and p.dry >= done_at and p.foam == 0:
		done = true
		_stop_effects()
		dog.react("set_mood", 2)
		dog.react("jump")
		sfx.play("poof")
		sfx.play("clap")
		_show_hint("깨끗해졌어요! R: 다음 손님", 999.0)


func _process(delta: float) -> void:
	_hint_left = maxf(_hint_left - delta, 0.0)
	if input_enabled:
		using = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_update_aim()
	for tool_id in _pickups:
		_set_glow(_pickups[tool_id], tool_id == hovered)
	if using and aim_point != null and not held.is_empty():
		use_tool_at(aim_point, delta)
		if _held_view != null:
			_held_view.position.y = -0.3 + sin(Time.get_ticks_msec() * 0.03) * 0.01
	else:
		_stop_effects()
		if not done:
			dog.react("set_mood", 1)
		if dog.model.has_method("watch"): dog.model.watch(null, false)
	_hud.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not hovered.is_empty():
			pick(hovered)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				drop()
			KEY_R:
				next_guest()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_tree().change_scene_to_file(MENU_SCENE)


## 가운데 점이 가리키는 것: 집을 도구 / 강아지
func _update_aim() -> void:
	hovered = ""
	aim_point = null
	var ray: Array[Vector3] = player.aim_ray(REACH)
	var query := PhysicsRayQueryParameters3D.create(ray[0], ray[1], (1 << (PICK_LAYER - 1)) | DOG_LAYER)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	if collider.has_meta("tool"):
		hovered = collider.get_meta("tool")
	elif collider is CollisionObject3D and (collider as CollisionObject3D).collision_layer & DOG_LAYER:
		aim_point = hit.position


func _tool_tip() -> Vector3:
	if _held_view != null:
		return _held_view.to_global(Vector3(0, 0.12, -0.12))
	return player.camera.global_position


func _stop_effects() -> void:
	if sfx == null or dog == null or dog.model == null:
		return
	sfx.set_loop("shower", 0.0)
	sfx.set_loop("scrub", 0.0)
	dog.stop_spray()
	dog.hide_stream()


func _show_hint(text: String, seconds: float) -> void:
	_hint = text
	_hint_left = seconds


# --- 방·선반·플레이어 (임시 상자)

func _build_room() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.75, 0.85, 0.9)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.9, 0.9, 0.95)
	environment.environment.ambient_light_energy = 0.25
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.4, -1.0)
	lamp.omni_range = 5.0
	lamp.light_energy = 0.25
	add_child(lamp)
	_box("Floor", Vector3(0, -0.1, 0), Vector3(8, 0.2, 7), Color(0.45, 0.58, 0.6))
	_box("WallBack", Vector3(0, 1.5, -3.5), Vector3(8, 3, 0.2), Color(0.85, 0.78, 0.66))
	_box("WallFront", Vector3(0, 1.5, 3.5), Vector3(8, 3, 0.2), Color(0.85, 0.78, 0.66))
	_box("WallLeft", Vector3(-4, 1.5, 0), Vector3(0.2, 3, 7), Color(0.8, 0.72, 0.6))
	_box("WallRight", Vector3(4, 1.5, 0), Vector3(0.2, 3, 7), Color(0.8, 0.72, 0.6))
	var tub := TUB_SCENE.instantiate() as Node3D
	tub.position = Vector3(DOG_SPOT.x, 0, DOG_SPOT.z)
	add_child(tub)
	# 목욕대 받침 충돌 (걸어서 통과하지 않게)
	_box("TubBlock", Vector3(DOG_SPOT.x, 0.45, DOG_SPOT.z), Vector3(1.6, 0.9, 1.1), Color(0, 0, 0, 0), false)


func _build_shelf() -> void:
	_box("Shelf", Vector3(-2.2, 0.45, -0.8), Vector3(0.6, 0.9, 1.8), Color(0.72, 0.55, 0.38))
	var z := -1.4
	for tool_id in TOOLS:
		var pickup := StaticBody3D.new()
		pickup.name = "Pickup_" + tool_id
		pickup.collision_layer = 1 << (PICK_LAYER - 1)
		pickup.collision_mask = 0
		pickup.set_meta("tool", tool_id)
		pickup.position = Vector3(-2.2, 0.9, z)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 0.35, 0.3)
		shape.shape = box
		shape.position.y = 0.17
		pickup.add_child(shape)
		var view := _make_tool_mesh(tool_id)
		view.position.y = 0.08
		pickup.add_child(view)
		add_child(pickup)
		_pickups[tool_id] = pickup
		z += 0.6


func _build_player() -> void:
	player = FpPlayer.new()
	player.name = "Player"
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	body.shape = capsule
	body.position.y = 0.8
	player.add_child(body)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position.y = FpPlayer.EYE_HEIGHT
	camera.fov = 70.0
	camera.current = true
	player.add_child(camera)
	player.position = Vector3(0, 0.05, 0.6)
	add_child(player)


## 임시 도구 모형 (진짜 그림이 오면 교체: docs/art/ART_SLOTS.md 의 도구 3D)
func _make_tool_mesh(tool_id: String) -> Node3D:
	var root := Node3D.new()
	var color: Color = TOOLS[tool_id].color
	match tool_id:
		"shower":
			_mesh(root, _cylinder(0.025, 0.25), Vector3(0, 0.05, 0.05), Vector3(-0.9, 0, 0), color)
			_mesh(root, _cylinder(0.06, 0.04), Vector3(0, 0.12, -0.1), Vector3(-0.4, 0, 0), Color(0.85, 0.9, 0.95))
		"shampoo":
			_mesh(root, _cylinder(0.05, 0.18), Vector3(0, 0.09, 0), Vector3.ZERO, color)
			_mesh(root, _cylinder(0.02, 0.05), Vector3(0, 0.2, 0), Vector3.ZERO, Color(1, 1, 1))
		"towel":
			var box := BoxMesh.new()
			box.size = Vector3(0.22, 0.06, 0.16)
			_mesh(root, box, Vector3(0, 0.03, 0), Vector3.ZERO, color)
	return root


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	parent.add_child(instance)


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


## 바라보는 도구는 밝게 빛남
func _set_glow(pickup: Node3D, on: bool) -> void:
	for child in pickup.find_children("*", "MeshInstance3D", true, false):
		var material := (child as MeshInstance3D).material_override as StandardMaterial3D
		material.emission_enabled = on
		material.emission = Color(1, 0.9, 0.5)
		material.emission_energy_multiplier = 0.6


func _box(box_name: String, pos: Vector3, size: Vector3, color: Color, visible_mesh := true) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if visible_mesh:
		var mesh := BoxMesh.new()
		mesh.size = size
		var view := MeshInstance3D.new()
		view.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		view.material_override = material
		body.add_child(view)
	add_child(body)


# --- 화면 (가운데 점, 바라보는 것, 진행, 조작)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = get_tree().root.theme
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)


func _draw_hud() -> void:
	var size := _hud.get_viewport_rect().size
	var center := size / 2.0
	var font := _hud.get_theme_default_font()
	# 가운데 점 (도구를 쓸 수 있는 곳이면 노랑)
	var ready_to_use := aim_point != null and not held.is_empty()
	_hud.draw_circle(center, 5.0, Color(0, 0, 0, 0.6))
	_hud.draw_circle(center, 3.0, Color(1, 0.85, 0.3) if ready_to_use or not hovered.is_empty() else Color(1, 1, 1))
	var under := ""
	if not hovered.is_empty():
		under = "클릭: %s 집기" % TOOLS[hovered].name
	elif aim_point != null and held.is_empty():
		under = "선반에서 도구를 집어요"
	elif ready_to_use and not using:
		under = "누르고 있으면 %s" % {"shower": "물이 나와요", "shampoo": "거품이 나요", "towel": "닦아요"}[held]
	_text(font, center + Vector2(0, 40), under, 22, true)
	# 진행
	var p := progress()
	var rows := [["물", p.wet], ["거품 (진흙)", p.scrub], ["말리기", p.dry]]
	for i in rows.size():
		var y := 30.0 + i * 34.0
		_hud.draw_rect(Rect2(20, y, 220, 22), Color(0, 0, 0, 0.5))
		_hud.draw_rect(Rect2(20, y, 220 * clampf(rows[i][1] / Tuning.data.v4_done_ratio, 0.0, 1.0), 22), Color(0.5, 0.85, 0.55) if rows[i][1] >= Tuning.data.v4_done_ratio else Color(0.45, 0.7, 1.0))
		_text(font, Vector2(250, y + 18), rows[i][0], 18, false)
	if p.foam > 0:
		_text(font, Vector2(20, 30 + 3 * 34 + 18), "남은 거품 %d (샤워기로 헹구기)" % p.foam, 18, false)
	_text(font, Vector2(size.x - 20, 48), "기다리는 손님 %d · 씻긴 %d · 떠난 %d" % [guests.guests.size(), guests.served, guests.left_count], 20, false, true)
	_text(font, Vector2(size.x - 20, size.y - 60), "손: %s" % (TOOLS[held].name if not held.is_empty() else "빈손"), 22, false, true)
	_text(font, Vector2(20, size.y - 20), "WASD 걷기 · 마우스 보기 · 클릭 집기/쓰기(누르고 있기) · Q 내려놓기 · R 다음 손님 · Esc 메뉴", 16, false)
	if _hint_left > 0.0:
		_text(font, Vector2(center.x, 120), _hint, 26, true)


func _text(font: Font, at: Vector2, text: String, font_size: int, centered: bool, right := false) -> void:
	if text.is_empty():
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := at - Vector2(width / 2.0 if centered else (width if right else 0.0), 0)
	_hud.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.8))
	_hud.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))
