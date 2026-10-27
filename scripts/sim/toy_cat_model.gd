extends "res://scripts/sim/sim_dog_model.gd"
## 임시 고양이 (장난감 같은 앉은 고양이): 구·캡슐·원뿔을 코드로 조립한다. 외부 파일·비용 없음.
## 강아지와 같은 노드 이름 약속(Head, Ear_L, Tail_1 …)을 써서 sim_dog_model.gd 가 그대로 움직인다.
## 진짜 모형(GLB)이 오면 scenes/art/sim/cat_model.tscn 을 그 모형으로 바꾸고 이 파일은 버린다 (docs/art/ART_SLOTS.md).
## 크기: 앉은 키 약 0.5 m. 바닥이 원점, 얼굴이 +Z. 회색 줄무늬 없는 단색 (털 색에 곱하는 tint).

const GREY := Color(0.66, 0.66, 0.72)
const PINK_EAR := Color(0.95, 0.72, 0.75)
const DARK := Color(0.07, 0.05, 0.05)
const PINK := Color(1.0, 0.55, 0.6)
const EYE_GREEN := Color(0.45, 0.75, 0.35)

var _fur_template: Material


func _ready() -> void:
	_build_parts()
	super._ready()


func _build_parts() -> void:
	_fur_template = StandardMaterial3D.new()
	_fur(self, "Hips", _sphere(0.13), Vector3(0, 0.13, -0.1), Vector3(1.05, 0.95, 1.1))
	var chest := _pivot(self, "Chest", Vector3(0, 0.23, 0.04))
	_fur(chest, "ChestFur", _sphere(0.105), Vector3.ZERO, Vector3(1, 1.2, 1))
	_marker(self, "BodyCenter", Vector3(0, 0.21, -0.03))

	# 머리: 둥근 얼굴, 짧은 주둥이
	var head := _pivot(self, "Head", Vector3(0, 0.32, 0.07))
	_fur(head, "HeadFur", _sphere(0.12), Vector3(0, 0.09, 0.02), Vector3(1.1, 0.95, 1))
	_fur(head, "Muzzle", _sphere(0.045), Vector3(0, 0.05, 0.11), Vector3(1.3, 0.8, 0.8))
	_marker(head, "FaceCenter", Vector3(0, 0.1, 0.12))
	_solid(head, "Nose", _sphere(0.014), Vector3(0, 0.068, 0.145), Vector3(1.3, 0.8, 1), PINK, 0.3)
	_solid(head, "Mouth", _box(Vector3(0.03, 0.006, 0.008)), Vector3(0, 0.035, 0.138), Vector3.ONE, DARK, 0.8)
	_solid(head, "Tongue", _sphere(0.014), Vector3(0, 0.028, 0.134), Vector3(1, 0.5, 1), PINK, 0.5)
	for side in [1, -1]:
		var tag := "L" if side == 1 else "R"
		var eye := _pivot(head, "Eye_" + tag, Vector3(side * 0.052, 0.11, 0.1))
		_solid(eye, "EyeIris", _sphere(0.03), Vector3.ZERO, Vector3(1, 1, 0.5), EYE_GREEN, 0.15)
		_solid(eye, "Pupil", _sphere(0.016), Vector3(0, 0, 0.012), Vector3(0.55, 1, 0.5), DARK, 0.1)
		_solid(eye, "Glint", _sphere(0.007), Vector3(-0.008 * side, 0.01, 0.018), Vector3.ONE, Color(1, 1, 1), 0.1)
		# 귀: 위로 선 삼각뿔 (안쪽 분홍)
		var ear := _pivot(head, "Ear_" + tag, Vector3(side * 0.07, 0.18, 0.0))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.045
		cone.height = 0.09
		cone.radial_segments = 12
		var ear_fur := _fur(ear, "EarFur", cone, Vector3(0, 0.04, 0), Vector3(1, 1, 0.55))
		ear_fur.rotation.z = -side * 0.25
		var inner := _solid(ear, "NoFurEarInner", cone, Vector3(0, 0.035, 0.012), Vector3(0.6, 0.8, 0.2), PINK_EAR, 0.6)
		inner.rotation.z = -side * 0.25

	# 다리: 가는 앞다리, 앉은 뒷다리
	for side in [1, -1]:
		var leg := _pivot(self, "Leg_F" + ("L" if side == 1 else "R"), Vector3(side * 0.055, 0.21, 0.08))
		_fur(leg, "LegFur", _capsule(0.03, 0.22), Vector3(0, -0.1, 0), Vector3.ONE)
		_fur(leg, "Paw", _sphere(0.035), Vector3(0, -0.2, 0.02), Vector3(1, 0.6, 1.2))
		_fur(self, "Haunch", _sphere(0.085), Vector3(side * 0.09, 0.09, -0.07), Vector3(0.8, 1, 1.2))
		_fur(self, "BackPaw", _sphere(0.035), Vector3(side * 0.09, 0.02, 0.04), Vector3(1, 0.6, 1.4))

	# 꼬리: 길고 가는 세 마디 (뒤로 감아 올라감)
	var parent: Node3D = self
	var at := Vector3(0, 0.08, -0.22)
	for i in range(1, 4):
		var segment := _pivot(parent, "Tail_%d" % i, at)
		if i == 1:
			segment.rotation.x = -1.2
		else:
			segment.rotation.x = 0.35
		_fur(segment, "TailFur", _capsule(0.022, 0.14), Vector3(0, 0.06, 0), Vector3.ONE)
		parent = segment
		at = Vector3(0, 0.12, 0)
	_fur(parent, "TailTip", _sphere(0.024), Vector3(0, 0.13, 0), Vector3.ONE)


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


## 털 부위 (털 셰이더가 입혀짐). 고양이 털 색은 tint 로 회색
func _fur(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3, scale_value: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	instance.material_override = _fur_template
	instance.set_instance_shader_parameter("tint", GREY)
	parent.add_child(instance)
	return instance


## 털이 아닌 부위 (눈·코·혀·귀 안쪽): 젖지 않음
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
