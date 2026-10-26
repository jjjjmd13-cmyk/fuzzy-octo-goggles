extends "res://scripts/sim/sim_dog_model.gd"
## 임시 강아지 (장난감 같은 앉은 강아지): 구·캡슐을 코드로 조립한다. 외부 파일·비용 없음.
## 움직임은 모두 sim_dog_model.gd 가 노드 이름(Head, Ear_L, Tail_1 …)으로 한다. 이 파일은 그 이름대로
## 부위를 만들기만 한다. 진짜 모형(GLB)이 오면 scenes/art/sim/dog_model.tscn 을 그 모형으로 바꾸고 이 파일은 버린다.
## 크기: 앉은 키 약 0.6 m, 길이 약 0.6 m. 바닥이 원점, 얼굴이 +Z. L/R 은 강아지 자신의 왼쪽(+X)·오른쪽(−X).

## 갈색 귀 (털 색에 곱함)
const TAN := Color(0.78, 0.55, 0.36)
const DARK := Color(0.07, 0.05, 0.05)
const PINK := Color(1.0, 0.55, 0.6)

var _fur_template: Material


func _ready() -> void:
	_build_parts()
	super._ready()


func _build_parts() -> void:
	_fur_template = StandardMaterial3D.new()
	_part_mesh(self, "Hips", _sphere(0.16), Vector3(0, 0.16, -0.13), Vector3(1.1, 0.95, 1.05))
	var chest := _pivot(self, "Chest", Vector3(0, 0.29, 0.05))
	_part_mesh(chest, "ChestFur", _sphere(0.14), Vector3.ZERO, Vector3(1, 1.15, 1))
	_part_between(self, "Belly", 0.13, Vector3(0, 0.19, -0.11), Vector3(0, 0.28, 0.04))
	_marker(self, "BodyCenter", Vector3(0, 0.27, -0.03))

	# 머리 (목 위치가 피벗)
	var head := _pivot(self, "Head", Vector3(0, 0.40, 0.09))
	_part_mesh(head, "HeadFur", _sphere(0.15), Vector3(0, 0.11, 0.04), Vector3.ONE)
	_part_mesh(head, "Snout", _sphere(0.075), Vector3(0, 0.07, 0.15), Vector3(1, 0.8, 1.15))
	_marker(head, "FaceCenter", Vector3(0, 0.13, 0.17))
	_solid(head, "Nose", _sphere(0.028), Vector3(0, 0.10, 0.235), Vector3(1.2, 0.9, 1), DARK, 0.3)
	_solid(head, "Mouth", _box(Vector3(0.05, 0.008, 0.01)), Vector3(0, 0.035, 0.222), Vector3.ONE, DARK, 0.8)
	_solid(head, "Tongue", _sphere(0.022), Vector3(0, 0.022, 0.215), Vector3(1, 0.55, 1), PINK, 0.5)
	for side in [1, -1]:
		var tag := "L" if side == 1 else "R"
		var cheek := _pivot(head, "Cheek_" + tag, Vector3(side * 0.065, 0.05, 0.13))
		_part_mesh(cheek, "CheekFur", _sphere(0.05), Vector3.ZERO, Vector3.ONE)
		# 만화 눈: 큰 검은 눈 + 반짝 점 두 개
		var eye := _pivot(head, "Eye_" + tag, Vector3(side * 0.068, 0.15, 0.14))
		_solid(eye, "Pupil", _sphere(0.036), Vector3.ZERO, Vector3(0.9, 1, 0.55), DARK, 0.15)
		_solid(eye, "Glint", _sphere(0.011), Vector3(-0.011 * side, 0.013, 0.02), Vector3.ONE, Color(1, 1, 1), 0.1)
		_solid(eye, "Glint2", _sphere(0.005), Vector3(0.008 * side, -0.01, 0.021), Vector3.ONE, Color(1, 1, 1), 0.1)
		var ear := _pivot(head, "Ear_" + tag, Vector3(side * 0.1, 0.22, 0.01))
		var ear_mesh := _part_mesh(ear, "EarFur", _capsule(0.036, 0.17), Vector3(0, -0.06, 0), Vector3(1, 1, 0.45))
		# 받은 그림(art/incoming/02·04)처럼 화면에서 왼쪽 귀(강아지의 오른쪽)만 갈색
		if side == -1:
			ear_mesh.set_instance_shader_parameter("tint", TAN)

	# 다리: 앞다리는 곧게, 뒷다리는 앉은 허벅지
	for side in [1, -1]:
		var leg := _pivot(self, "Leg_F" + ("L" if side == 1 else "R"), Vector3(side * 0.08, 0.27, 0.11))
		_part_mesh(leg, "LegFur", _capsule(0.045, 0.27), Vector3(0, -0.13, 0), Vector3.ONE)
		_part_mesh(leg, "Paw", _sphere(0.05), Vector3(0, -0.245, 0.03), Vector3(1, 0.6, 1.3))
		_part_mesh(self, "Haunch", _sphere(0.1), Vector3(side * 0.12, 0.12, -0.09), Vector3(0.8, 1, 1.2))
		_part_mesh(self, "BackPaw", _sphere(0.05), Vector3(side * 0.12, 0.03, 0.04), Vector3(1, 0.6, 1.4))

	# 꼬리: 세 마디 + 끝 털뭉치 (첫 마디가 뒤로 비스듬히 서 있음)
	var parent: Node3D = self
	var at := Vector3(0, 0.15, -0.28)
	for i in range(1, 4):
		var segment := _pivot(parent, "Tail_%d" % i, at)
		if i == 1:
			segment.rotation.x = -0.9
		_part_mesh(segment, "TailFur", _capsule(0.03, 0.11), Vector3(0, 0.045, 0), Vector3.ONE)
		parent = segment
		at = Vector3(0, 0.09, 0)
	_part_mesh(parent, "TailTip", _sphere(0.05), Vector3(0, 0.1, 0), Vector3.ONE)


func _pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = pivot_name
	node.position = pos
	parent.add_child(node)
	return node


func _marker(parent: Node3D, marker_name: String, pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = pos
	parent.add_child(marker)


## 털 부위 (털 셰이더가 입혀짐)
func _part_mesh(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3, scale_value: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	instance.material_override = _fur_template
	parent.add_child(instance)
	return instance


## 두 점 사이를 잇는 털 캡슐
func _part_between(parent: Node3D, part_name: String, radius: float, a: Vector3, b: Vector3) -> MeshInstance3D:
	var instance := _part_mesh(parent, part_name, _capsule(radius, a.distance_to(b) + radius * 2.0), (a + b) / 2.0, Vector3.ONE)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.RIGHT).normalized()
	instance.basis = Basis(side.cross(up), up, side)
	return instance


## 털이 아닌 부위 (눈·코·혀): 젖지 않음
func _solid(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3, scale_value: Vector3, color: Color, roughness: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 6
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
