extends "res://scripts/sim/sim_owner_model.gd"
## 임시 주인 (2등신 장난감 사람): 구·캡슐을 코드로 조립한다. 외부 파일·비용 없음.
## 움직임·색 바꾸기는 sim_owner_model.gd 가 노드 이름(Body, Head, Arm_L …)과 재질 이름(Shirt, Hat)으로 한다.
## 이 파일은 그 이름대로 부위를 만들기만 한다. 진짜 모형(GLB)이 오면 owner_model.tscn 을 바꾸고 이 파일은 버린다.

const SKIN := Color(1.0, 0.86, 0.74)
const DARK := Color(0.1, 0.08, 0.08)


func _ready() -> void:
	_build()
	super._ready()


func _build() -> void:
	var shirt := _flat(SHIRTS[0])
	shirt.resource_name = "Shirt"
	shirt.roughness = 0.8
	var hat := _flat(HATS[0])
	hat.resource_name = "Hat"
	var skin := _flat(SKIN)
	var pants := _flat(Color(0.35, 0.4, 0.55))
	var body := _pivot(self, "Body", Vector3.ZERO)
	_mesh(body, _capsule(0.17, 0.5), Vector3(0, 0.5, 0), shirt)
	for side in [1, -1]:
		var tag := "L" if side == 1 else "R"
		var leg := _pivot(body, "Leg_" + tag, Vector3(side * 0.08, 0.3, 0))
		_mesh(leg, _capsule(0.065, 0.32), Vector3(0, -0.14, 0), pants)
		var arm := _pivot(body, "Arm_" + tag, Vector3(side * 0.19, 0.66, 0))
		_mesh(arm, _capsule(0.05, 0.3), Vector3(0, -0.12, 0.0), shirt)
		_mesh(arm, _sphere(0.055), Vector3(0, -0.27, 0), skin)
	var head := _pivot(body, "Head", Vector3(0, 0.78, 0))
	_mesh(head, _sphere(0.19), Vector3(0, 0.15, 0), skin)
	for side in [-1, 1]:
		_mesh(head, _sphere(0.02), Vector3(side * 0.065, 0.17, 0.175), _flat(DARK))
		_mesh(head, _sphere(0.03), Vector3(side * 0.11, 0.1, 0.15), _flat(Color(1.0, 0.65, 0.65)))
	_mesh(head, _box(Vector3(0.06, 0.012, 0.01)), Vector3(0, 0.09, 0.185), _flat(DARK))
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.13
	hat_mesh.bottom_radius = 0.2
	hat_mesh.height = 0.12
	_mesh(head, hat_mesh, Vector3(0, 0.3, 0), hat)


func _pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = pivot_name
	node.position = pos
	parent.add_child(node)
	return node


## 재질은 메시 표면에 둔다 (색 바꾸기가 재질 이름으로 표면을 찾음)
func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	(mesh as PrimitiveMesh).material = material
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
	return instance


func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _capsule(radius: float, mesh_height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = mesh_height
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
