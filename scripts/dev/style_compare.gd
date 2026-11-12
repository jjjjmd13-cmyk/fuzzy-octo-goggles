extends Node3D
## 빠른 확인 [그림체 비교] (개발 전용, 대표 요청 2026-11-11 ⑧, 기획 ART_SLOTS 10 · ORDER_STYLE_REAL_TEST):
## 지금 파스텔 모형과 실사풍 시험 모형 (art/incoming/style_real_test/real_*.glb) 을 같은 빛·같은 크기로 나란히 놓고 봄.
## 실사풍 파일이 아직 없으면 그 자리에 "아직 없음". 출시 빌드에는 안 들어감 (scripts/dev · scenes/dev 제외).
## art/incoming 은 .gdignore 라 Godot 가 미리 가져오지 않음 → 실행 중에 GLTFDocument 로 읽음.
## 조작: 1·2·3 = 강아지·목욕통·빵집, ←→ (또는 A·D) 돌기, ↑↓ (또는 W·S·휠) 가까이·멀리, Esc = 메뉴로.

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const FONT := preload("res://assets/fonts/pretendard/Pretendard-Bold.otf")
## 실사풍 시험 파일이 있는 곳 (테스트는 다른 곳으로 바꿔 씀)
var real_dir := "res://art/incoming/style_real_test"
## 비교 줄: 이름, 파스텔 (지금 게임 씬·모형), 실사풍 파일 이름, 정면이 카메라 (+Z) 를 보게 돌리는 각 [파스텔, 실사풍].
## 실사풍 GLB 는 지금 dog.glb·tub.glb·town_bakery.glb 와 같은 방향으로 옴 (강아지·목욕통 정면 −Z → 반 바퀴, 빵집 정면 −X → 1/4 바퀴)
const PAIRS: Array[Dictionary] = [
	{"id": "dog", "name": "강아지", "pastel": "res://scenes/art/sim/dog_model.tscn", "real": "real_dog.glb", "turn": [0.0, PI]},
	{"id": "tub", "name": "목욕통", "pastel": "res://scenes/art/sim/tub_model.tscn", "real": "real_tub.glb", "turn": [0.0, PI]},
	{"id": "bakery", "name": "빵집", "pastel": "res://assets/models/outside/town_bakery.glb", "real": "real_bakery.glb", "turn": [PI / 2.0, PI / 2.0]},
]
## 두 모형 사이 거리 = 큰 쪽 폭 × 이만큼
const GAP := 1.35

## 비교 줄마다 {root, pastel, real, missing, size}
var pairs: Array[Dictionary] = []
var current := 0
var camera: Camera3D
var _yaw := 0.4
var _distance := 1.0
var _hud: Label


func _ready() -> void:
	_build_stage()
	for i in PAIRS.size():
		pairs.append(_build_pair(PAIRS[i], i))
	show_pair(0)


## i 번째 비교 줄만 보이고 카메라를 맞춤
func show_pair(i: int) -> void:
	current = clampi(i, 0, pairs.size() - 1)
	for k in pairs.size():
		(pairs[k].root as Node3D).visible = k == current
	_distance = pairs[current].size * 2.8
	_update_camera()
	var info: Dictionary = PAIRS[current]
	_hud.text = "그림체 비교 — %s   (왼쪽 파스텔 · 오른쪽 실사풍%s)\n1 강아지 · 2 목욕통 · 3 빵집   ←→ 돌기 · ↑↓ 가까이/멀리 · Esc 메뉴" % [info.name, " — 아직 없음" if pairs[current].missing else ""]


## 실사풍 파일이 없는 줄 수
func missing_count() -> int:
	return pairs.filter(func(p: Dictionary) -> bool: return p.missing).size()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_1, KEY_2, KEY_3:
				show_pair((event as InputEventKey).keycode - KEY_1)
			KEY_LEFT, KEY_A:
				_yaw -= 0.2
			KEY_RIGHT, KEY_D:
				_yaw += 0.2
			KEY_UP, KEY_W:
				_distance *= 0.9
			KEY_DOWN, KEY_S:
				_distance *= 1.1
			KEY_ESCAPE:
				get_tree().change_scene_to_file(MENU_SCENE)
				return
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		var wheel := (event as InputEventMouseButton).button_index
		if wheel == MOUSE_BUTTON_WHEEL_UP:
			_distance *= 0.9
		elif wheel == MOUSE_BUTTON_WHEEL_DOWN:
			_distance *= 1.1
		_update_camera()


func _update_camera() -> void:
	var size: float = pairs[current].size
	var target := Vector3(0, size * 0.35, 0)
	var eye := target + Vector3(sin(_yaw), 0.35, cos(_yaw)).normalized() * _distance
	camera.look_at_from_position(eye, target)


## 같은 빛·바닥·하늘 (가게와 비슷한 밝기)
func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.82, 0.86, 0.9)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.9, 0.9, 0.95)
	environment.environment.ambient_light_energy = 0.25
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.58, 0.6)
	floor_mesh.material_override = material
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(20, 16)
	_hud.add_theme_font_override("font", FONT)
	_hud.add_theme_font_size_override("font_size", 20)
	_hud.add_theme_color_override("font_color", Color(0.2, 0.18, 0.15))
	layer.add_child(_hud)


## 한 줄: 왼쪽 파스텔, 오른쪽 실사풍 (없으면 "아직 없음" 판), 둘 다 바닥 가운데에 맞춤
func _build_pair(info: Dictionary, index: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Pair_" + info.id
	add_child(root)
	var pastel := _turned(_instance(info.pastel), info.turn[0])
	var real := _load_real(real_dir.path_join(info.real))
	if real != null:
		real = _turned(real, info.turn[1])
	var missing := real == null
	var size := maxf(_extent(pastel), _extent(real) if real != null else 0.0)
	size = maxf(size, 0.3)
	var gap := size * GAP / 2.0
	_place(root, pastel, Vector3(-gap, 0, 0), "Pastel")
	_tag(root, "파스텔 (지금)", Vector3(-gap, _height(pastel) + size * 0.12, 0), size)
	if real != null:
		_place(root, real, Vector3(gap, 0, 0), "Real")
		_tag(root, "실사풍", Vector3(gap, _height(real) + size * 0.12, 0), size)
	else:
		_tag(root, "실사풍: 아직 없음\n(%s)" % info.real, Vector3(gap, size * 0.4, 0), size, "Missing")
	return {"root": root, "pastel": pastel, "real": real, "missing": missing, "size": size}


## 모형을 감싸서 Y 로 돌림 (정면이 카메라 쪽)
func _turned(model: Node3D, angle: float) -> Node3D:
	var holder := Node3D.new()
	model.rotation.y += angle
	holder.add_child(model)
	return holder


func _instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return Node3D.new()
	return (load(path) as PackedScene).instantiate() as Node3D


## 가져오지 않은 GLB 를 실행 중에 읽음 (없거나 못 읽으면 null)
func _load_real(path: String) -> Node3D:
	var file := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(file):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(file, state) != OK:
		return null
	return document.generate_scene(state) as Node3D


## 모형을 놓되 바닥 가운데가 at 에 오게 (모형 원점이 어디든)
func _place(root: Node3D, model: Node3D, at: Vector3, node_name: String) -> void:
	model.name = node_name
	root.add_child(model)
	var box := _box(model)
	model.position = at - Vector3(box.get_center().x, box.position.y, box.get_center().z)


func _tag(root: Node3D, text: String, at: Vector3, size: float, node_name := "Tag") -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.font = FONT
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = size * 0.0012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	label.modulate = Color(0.25, 0.2, 0.15) if node_name != "Missing" else Color(0.75, 0.3, 0.3)
	root.add_child(label)


func _extent(model: Node3D) -> float:
	var box := _box(model)
	return maxf(box.size.x, maxf(box.size.y, box.size.z))


func _height(model: Node3D) -> float:
	return _box(model).size.y


## 모형 안 메시 전체 상자 (모형 기준, 트리 밖에서도 됨)
func _box(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var to_model := Transform3D()
		var walk: Node = mesh
		while walk != null and walk != model:
			if walk is Node3D:
				to_model = (walk as Node3D).transform * to_model
			walk = walk.get_parent()
		var box := to_model * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
