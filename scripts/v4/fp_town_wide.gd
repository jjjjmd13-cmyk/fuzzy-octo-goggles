extends RefCounted
## V4 가게 밖 빈 곳 채우기 (대표 요청 2026-11-11 ⑥, 기획 ART_SLOTS 4-8 좌표): 양옆 이웃 2채 + 먼 배경 + 하늘 (산·구름 띠).
## 모두 배경이라 충돌 없음 (마당 끝 막이로 원래 못 감). 방 좌표 그대로 (원점 = 가게 방 바닥 가운데, 돌리지 않고 놓음).
## 그래픽 교체: `assets/models/outside/town_side_a.glb` · `town_side_b.glb` · `town_far.glb` 가 오면 그것 (FpOutside.model).
## 하늘 (먼 산·구름 띠) 은 코드 모형 (town_far.glb 에 산이 있으면 SKY_IN_FAR 로 끔).

## 양옆 이웃: 이름 → [건물 x 범위, z 범위, 높이, 벽 색, 지붕 색, 간판 색]. 정면 +X (찻길 쪽), 앞마당 x 4 ~ 9
const SIDES := {
	# 왼쪽 (−Z) 세탁소
	"town_side_a": [Vector2(-4.0, 4.2), Vector2(-8.5, -3.7), 3.5, Color(0.8, 0.93, 0.92), Color(0.45, 0.62, 0.78), Color(0.55, 0.8, 1.0)],
	# 오른쪽 (+Z) 문구점·책방 (손님 길 z ≈ 2.6 을 막지 않게 3.7 부터)
	"town_side_b": [Vector2(-4.0, 4.2), Vector2(3.7, 8.5), 3.8, Color(1.0, 0.9, 0.78), Color(0.78, 0.5, 0.42), Color(1.0, 0.75, 0.45)],
}
const SIDE_YARD_X := Vector2(4.2, 9.0)
## 먼 배경 (ART_SLOTS 4-8): 나무 띠 x, 먼 집 x, 언덕 x, 폭 z, 찻길 양 끝 z, 잔디 높이
const TREES_X := Vector2(20.0, 23.0)
const HOUSES_X := Vector2(25.0, 32.0)
const HILLS_X := Vector2(35.0, 45.0)
const FAR_Z := 40.0
const ROAD_END_Z := 14.0
const GRASS_Y := -0.25
## 하늘: 먼 산 (x 약 70 ~ 95) 과 구름 띠 (높이 약 16 ~ 26)
const SKY_IN_FAR := false
const GRASS := Color(0.62, 0.78, 0.55)


## 양옆 이웃 + 먼 배경 + 하늘을 만들어 outside 에 "TownWide" 로 붙임 (찻길 건너편 Town 과 따로)
static func build(outside: Node3D) -> Node3D:
	var town := Node3D.new()
	town.name = "TownWide"
	outside.add_child(town)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for side_name in SIDES:
		var art: Node3D = outside.model(side_name)
		if art == null:
			art = _side_placeholder(SIDES[side_name])
		art.name = side_name
		town.add_child(art)
	var far: Node3D = outside.model("town_far")
	if far == null:
		far = _far_placeholder(rng)
	far.name = "town_far"
	town.add_child(far)
	if not SKY_IN_FAR:
		var sky := _sky_placeholder(rng)
		sky.name = "SkyBand"
		town.add_child(sky)
	# 먼 것은 그림자를 안 드리움 (가볍게)
	for node in [far] + town.find_children("SkyBand", "", false, false):
		for mesh in (node as Node).find_children("*", "GeometryInstance3D", true, false):
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return town


## 이웃 한 채: 건물 (벽 + 지붕 + 찻길 쪽 문·창·간판) + 앞 보도 + 앞마당 잔디 + 마당 끝 낮은 울타리
static func _side_placeholder(info: Array) -> Node3D:
	var root := Node3D.new()
	var xs: Vector2 = info[0]
	var zs: Vector2 = info[1]
	var height: float = info[2]
	var center := Vector3((xs.x + xs.y) / 2.0, 0, (zs.x + zs.y) / 2.0)
	var size := Vector3(xs.y - xs.x, height, zs.y - zs.x)
	_add(root, _box(size, info[3]), center + Vector3(0, height / 2.0, 0), "Building")
	# 지붕: 앞 (찻길 쪽) 으로만 조금 나옴 (옆은 가게 지붕·벽과 겹치지 않게 기획 범위 안)
	_add(root, _box(Vector3(size.x + 0.3, 0.3, size.z), info[4]), center + Vector3(0.15, height + 0.15, 0), "Roof")
	var front := xs.y + 0.02
	_add(root, _box(Vector3(0.05, 2.0, 1.0), Color(0.55, 0.4, 0.3)), Vector3(front, 1.0, center.z - 0.9), "Door")
	_add(root, _box(Vector3(0.05, 1.0, 1.4), Color(0.75, 0.9, 1.0)), Vector3(front, 1.4, center.z + 1.0), "Window")
	_add(root, _box(Vector3(0.08, 0.5, 2.6), info[5]), Vector3(front + 0.02, height - 0.55, center.z), "Sign")
	# 앞 보도 (가게 앞 보도와 같은 높이) + 앞마당 잔디 + 마당 끝 울타리
	_add(root, _box(Vector3(1.0, 0.04, size.z), Color(0.82, 0.78, 0.72)), Vector3(xs.y + 0.5, 0.0, center.z), "Walk")
	var yard_len := SIDE_YARD_X.y - SIDE_YARD_X.x - 1.0
	_add(root, _box(Vector3(yard_len, 0.03, size.z), GRASS.lightened(0.05)), Vector3(xs.y + 1.0 + yard_len / 2.0, -0.005, center.z), "Yard")
	_add(root, _box(Vector3(0.06, 0.6, size.z), Color(1, 1, 1)), Vector3(SIDE_YARD_X.y, 0.3, center.z), "Fence")
	return root


## 먼 배경: 넓은 잔디 판 + 찻길 양 끝 막는 생울타리·나무 + 나무 띠 + 먼 집 + 낮은 언덕
static func _far_placeholder(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	_add(root, _box(Vector3(HILLS_X.y + 15.0, 0.1, FAR_Z * 2.0), GRASS), Vector3((HILLS_X.y - 15.0) / 2.0, GRASS_Y - 0.05, 0), "Grass")
	# 찻길 양 끝: 길 옆 모퉁이 나무 덤불 (길 위는 비움, 택배 트럭이 지나감)
	for sign_z in [-1.0, 1.0]:
		for x in [8.2, 13.2]:
			_add(root, _box(Vector3(2.4, 1.1, 1.6), GRASS.darkened(0.25)), Vector3(x, 0.45, sign_z * (ROAD_END_Z + 1.0)), "RoadEnd")
			_add(root, _tree(rng, 1.0), Vector3(x, 0, sign_z * (ROAD_END_Z + 2.4)), "RoadEndTree")
	# 나무 띠
	var z := -FAR_Z
	while z <= FAR_Z:
		_add(root, _tree(rng, rng.randf_range(1.0, 1.6)), Vector3(rng.randf_range(TREES_X.x, TREES_X.y), GRASS_Y, z), "Tree")
		z += rng.randf_range(2.2, 3.4)
	# 먼 집 (지붕 색 여러 가지)
	z = -FAR_Z + 3.0
	while z <= FAR_Z - 3.0:
		var house := Node3D.new()
		var size := Vector3(rng.randf_range(3.0, 5.0), rng.randf_range(3.0, 6.0), rng.randf_range(3.5, 5.5))
		var wall := Color.from_hsv(rng.randf(), 0.15, 0.97)
		_add(house, _box(size, wall), Vector3(0, size.y / 2.0, 0), "Wall")
		_add(house, _box(Vector3(size.x + 0.4, 0.5, size.z + 0.4), Color.from_hsv(rng.randf(), 0.45, 0.75)), Vector3(0, size.y + 0.25, 0), "Roof")
		_add(root, house, Vector3(rng.randf_range(HOUSES_X.x + 2.0, HOUSES_X.y - 2.0), GRASS_Y, z), "House")
		z += rng.randf_range(6.0, 9.0)
	# 낮은 언덕 (납작한 공)
	for i in 5:
		var hill := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var radius := rng.randf_range(9.0, 13.0)
		mesh.radius = radius
		mesh.height = radius * 2.0
		hill.mesh = mesh
		hill.material_override = _material(GRASS.darkened(rng.randf_range(0.05, 0.2)))
		hill.scale = Vector3(1.0, rng.randf_range(0.35, 0.55), 1.4)
		_add(root, hill, Vector3(rng.randf_range(HILLS_X.x + 4.0, HILLS_X.y - 2.0), GRASS_Y - 1.0, -FAR_Z + 8.0 + i * 16.0 + rng.randf_range(-3.0, 3.0)), "Hill")
	return root


## 하늘: 먼 산 (푸르스름한 원뿔) + 구름 띠 (납작한 흰 공 무리)
static func _sky_placeholder(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	for i in 7:
		var mountain := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = rng.randf_range(18.0, 28.0)
		cone.height = rng.randf_range(16.0, 26.0)
		cone.radial_segments = 10
		mountain.mesh = cone
		mountain.material_override = _material(Color(0.62, 0.72, 0.84).lerp(Color(0.8, 0.86, 0.92), rng.randf()))
		_add(root, mountain, Vector3(rng.randf_range(75.0, 95.0), cone.height / 2.0 - 2.0, -60.0 + i * 20.0 + rng.randf_range(-5.0, 5.0)), "Mountain")
	var cloud_material := _material(Color(1, 1, 1))
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 10:
		var cloud := Node3D.new()
		for k in 4:
			var puff := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = rng.randf_range(2.0, 3.5)
			ball.height = ball.radius * 2.0
			puff.mesh = ball
			puff.material_override = cloud_material
			puff.position = Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(-0.5, 0.5), k * 3.0 - 4.5)
			puff.scale = Vector3(0.8, 0.45, 1.0)
			cloud.add_child(puff)
		_add(root, cloud, Vector3(rng.randf_range(55.0, 85.0), rng.randf_range(16.0, 26.0), -70.0 + i * 15.0 + rng.randf_range(-4.0, 4.0)), "Cloud")
	return root


## 임시 나무: 줄기 + 둥근 잎 두 덩이
static func _tree(rng: RandomNumberGenerator, scale: float) -> Node3D:
	var root := Node3D.new()
	var trunk := MeshInstance3D.new()
	var stem := CylinderMesh.new()
	stem.top_radius = 0.12
	stem.bottom_radius = 0.16
	stem.height = 1.6
	trunk.mesh = stem
	trunk.material_override = _material(Color(0.55, 0.4, 0.28))
	trunk.position.y = 0.8
	root.add_child(trunk)
	for k in 2:
		var crown := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.9 - k * 0.2
		ball.height = ball.radius * 2.0
		crown.mesh = ball
		crown.material_override = _material(Color(0.45, 0.68, 0.42).lightened(rng.randf_range(0.0, 0.15)))
		crown.position = Vector3(rng.randf_range(-0.2, 0.2), 2.0 + k * 0.7, rng.randf_range(-0.2, 0.2))
		root.add_child(crown)
	root.scale = Vector3.ONE * scale
	return root


static func _add(parent: Node3D, node: Node3D, at: Vector3, node_name: String) -> void:
	node.name = node_name
	parent.add_child(node, true)
	node.position = at


static func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.material_override = _material(color)
	return view


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
