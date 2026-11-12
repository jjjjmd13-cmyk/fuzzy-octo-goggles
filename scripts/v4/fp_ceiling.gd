extends RefCounted
## V4 가게 천장 + 지붕 (대표 요청 2026-11-11 ②, ART_SLOTS 4-8): 천장판 + 들보 3줄 + 벽 둘레 나무 띠 + 간단한 천장 조명 + 맞배지붕 (임시 모형).
## 그래픽 교체: `assets/models/shop/ceiling.glb` 가 있으면 그것 하나로 (천장 아래면 + 지붕 위면, 조명 기구 포함).
##   방 좌표 그대로 (원점 = 가게 방 바닥 가운데, 돌리지 않고 놓음). 천장 아래면 y = 3.0, x −4.1 ~ 4.1, z −3.6 ~ 3.6,
##   조명 고리 (0, 3.0, −1.6) = 꾸미기 조명이 매달리는 곳, 맞배지붕 용마루 y ≈ 3.8.
##   빛 자리: 모형 안에 `Bulb` (빈 오브젝트 가능) 가 있으면 거기, 없으면 FIXTURE_POS.
## 천장·지붕은 그림자를 드리우지 않음 (해가 비스듬히 들던 방 밝기 그대로). 손이 안 닿는 높이라 충돌 없음.

const MODEL_PATH := "res://assets/models/shop/ceiling.glb"
const HEIGHT := 3.0
const HALF := Vector2(4.1, 3.6)
const THICKNESS := 0.12
## 벽지 (기본 베이지 0.85, 0.78, 0.66) 보다 밝은 크림색 + 나무 들보·띠
const CEILING_COLOR := Color(0.98, 0.95, 0.89)
const PANEL_GLOW := 0.9
## 받은 ceiling.glb 재질의 스스로 빛남 (아랫면이 회색으로 안 보이게)
const GLB_GLOW := 0.2
const WOOD_COLOR := Color(0.78, 0.62, 0.45)
const ROOF_COLOR := Color(0.85, 0.5, 0.42)
## 들보 3줄 (X 방향으로 길게, 이 z 자리). 가운데 줄이 조명 고리를 지남
const BEAM_Z: Array[float] = [-1.6, 0.4, 2.4]
const BEAM_SIZE := Vector2(0.16, 0.12)
const TRIM_SIZE := Vector2(0.1, 0.08)
## 꾸미기 조명이 매달리는 고리 (FpDecor PLACES.lamp 와 같은 자리)
const HOOK_POS := Vector3(0, 3.0, -1.6)
## 기본 조명 기구 (천장에 붙은 둥근 등): 문에서 목욕통 가는 길 위, 들보 사이
const FIXTURE_POS := Vector3(0.6, 3.0, 1.4)
const FIXTURE_RADIUS := 0.22
const LIGHT_ENERGY := 0.25
const LIGHT_RANGE := 4.5
## 맞배지붕: 용마루는 X 방향 (박공이 찻길 쪽 +X 를 봄)
const RIDGE_Y := 3.8
const ROOF_OVERHANG := 0.3


## 천장을 만들어 parent 에 붙이고 돌려줌 (이름 "Ceiling", 조명은 "CeilingLight")
static func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Ceiling"
	parent.add_child(root)
	var light_at := FIXTURE_POS
	if ResourceLoader.exists(MODEL_PATH):
		var art := (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
		art.name = "Art"
		root.add_child(art)
		var bulb := art.find_child("Bulb", true, false) as Node3D
		if bulb != null:
			light_at = art.transform * _local_to(art, bulb)
		_brighten(art)
	else:
		_build_placeholder(root)
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.name = "CeilingLight"
	light.position = light_at + Vector3(0, -0.15, 0)
	light.light_color = Color(1.0, 0.93, 0.8)
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	root.add_child(light)
	return root


## 받은 천장도 아랫면이 해를 못 받아 어둡게 보여서, 재질마다 자기 색으로 살짝 스스로 빛나게 (개발 보정, 파일은 그대로)
static func _brighten(art: Node3D) -> void:
	for node in art.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(i) as StandardMaterial3D
			if original == null:
				continue
			var material := original.duplicate() as StandardMaterial3D
			material.emission_enabled = true
			material.emission = original.albedo_color
			material.emission_texture = original.albedo_texture
			material.emission_energy_multiplier = GLB_GLOW
			mesh.set_surface_override_material(i, material)


## node 의 자리 (ancestor 기준)
static func _local_to(ancestor: Node3D, node: Node3D) -> Vector3:
	var at := Transform3D()
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			at = (current as Node3D).transform * at
		current = current.get_parent()
	return at.origin


static func _build_placeholder(root: Node3D) -> void:
	var panel := _mesh(_box(Vector3(HALF.x * 2.0, THICKNESS, HALF.y * 2.0)), CEILING_COLOR)
	panel.name = "Panel"
	# 아랫면은 해가 안 닿아 회색으로 보여서, 벽지보다 밝은 크림색으로 보이게 살짝 스스로 빛남
	var cream := panel.material_override as StandardMaterial3D
	cream.emission_enabled = true
	cream.emission = CEILING_COLOR
	cream.emission_energy_multiplier = PANEL_GLOW
	panel.position = Vector3(0, HEIGHT + THICKNESS / 2.0, 0)
	root.add_child(panel)
	for i in BEAM_Z.size():
		var z := BEAM_Z[i]
		var beam := _mesh(_box(Vector3(HALF.x * 2.0, BEAM_SIZE.y, BEAM_SIZE.x)), WOOD_COLOR)
		beam.name = "Beam%d" % (i + 1)
		beam.position = Vector3(0, HEIGHT - BEAM_SIZE.y / 2.0, z)
		root.add_child(beam)
	# 벽 둘레 나무 띠 (뒤·앞·왼쪽·오른쪽, 벽 안쪽 면 x ±3.9, z ±3.4 에 붙음)
	var trim_index := 0
	for side in [[Vector3(0, 0, -3.4 + TRIM_SIZE.x / 2.0), Vector3(7.8, 0, TRIM_SIZE.x)], [Vector3(0, 0, 3.4 - TRIM_SIZE.x / 2.0), Vector3(7.8, 0, TRIM_SIZE.x)],
			[Vector3(-3.9 + TRIM_SIZE.x / 2.0, 0, 0), Vector3(TRIM_SIZE.x, 0, 6.8)], [Vector3(3.9 - TRIM_SIZE.x / 2.0, 0, 0), Vector3(TRIM_SIZE.x, 0, 6.8)]]:
		var size: Vector3 = side[1]
		size.y = TRIM_SIZE.y
		var trim := _mesh(_box(size), WOOD_COLOR)
		trim_index += 1
		trim.name = "Trim%d" % trim_index
		trim.position = side[0] + Vector3(0, HEIGHT - TRIM_SIZE.y / 2.0, 0)
		root.add_child(trim)
	# 조명 고리 (작은 나무 원판, 꾸미기 조명이 여기에 매달림)
	var hook_mesh := CylinderMesh.new()
	hook_mesh.top_radius = 0.06
	hook_mesh.bottom_radius = 0.06
	hook_mesh.height = 0.03
	var hook := _mesh(hook_mesh, WOOD_COLOR.darkened(0.2))
	hook.name = "Hook"
	hook.position = HOOK_POS + Vector3(0, -BEAM_SIZE.y - 0.015, 0)
	root.add_child(hook)
	# 기본 조명 기구: 나무 받침 + 우윳빛 반구 갓 (스스로 빛남)
	var fixture := Node3D.new()
	fixture.name = "Fixture"
	fixture.position = FIXTURE_POS
	root.add_child(fixture)
	var base := CylinderMesh.new()
	base.top_radius = FIXTURE_RADIUS + 0.03
	base.bottom_radius = FIXTURE_RADIUS + 0.03
	base.height = 0.03
	var base_view := _mesh(base, WOOD_COLOR)
	base_view.position.y = -0.015
	fixture.add_child(base_view)
	var dome := SphereMesh.new()
	dome.radius = FIXTURE_RADIUS
	dome.height = FIXTURE_RADIUS
	dome.is_hemisphere = true
	var dome_view := _mesh(dome, Color(1.0, 0.98, 0.92))
	# 반구는 위가 둥글어서 뒤집어 아래로 볼록하게
	dome_view.rotation.x = PI
	dome_view.position.y = -0.03
	var glow := dome_view.material_override as StandardMaterial3D
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.92, 0.75)
	glow.emission_energy_multiplier = 0.9
	fixture.add_child(dome_view)
	# 맞배지붕: 양쪽 비탈 판 2장 (용마루 X 방향) + 박공 벽 (앞·뒤 삼각형 대신 낮은 상자)
	var top := HEIGHT + THICKNESS
	var run := HALF.y + ROOF_OVERHANG
	var rise := RIDGE_Y - top
	var slope_len := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)
	for sign_z: float in [-1.0, 1.0]:
		var slab := _mesh(_box(Vector3(HALF.x * 2.0 + ROOF_OVERHANG * 2.0, 0.1, slope_len)), ROOF_COLOR)
		slab.name = "RoofBack" if sign_z < 0.0 else "RoofFront"
		slab.position = Vector3(0, top + rise / 2.0, sign_z * run / 2.0)
		slab.rotation.x = angle * sign_z
		root.add_child(slab)
	for sign_x: float in [-1.0, 1.0]:
		var gable := MeshInstance3D.new()
		gable.name = "GableLeft" if sign_x < 0.0 else "GableStreet"
		var prism := PrismMesh.new()
		prism.size = Vector3(HALF.y * 2.0, rise, 0.1)
		gable.mesh = prism
		var gable_material := StandardMaterial3D.new()
		gable_material.albedo_color = Color(0.92, 0.86, 0.76)
		gable.material_override = gable_material
		gable.position = Vector3(sign_x * (HALF.x - 0.05), top + rise / 2.0, 0)
		gable.rotation.y = PI / 2.0
		root.add_child(gable)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _mesh(mesh: Mesh, color: Color) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	view.material_override = material
	return view
