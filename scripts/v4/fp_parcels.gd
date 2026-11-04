extends Node3D
## V4 택배 (GDD_V4 '택배 흐름'): 아침이 되면 작은 트럭이 찻길에 서서 상자를 택배 매트에 내려놓고 빵빵 떠남.
## 상자는 클릭해서 두 손으로 들고 (한 번에 하나), 가게 안에서 클릭하면 열림 (여는 효과는 fp_shop.open_box).
##
## 상자 하나 = fp_shop.parcels 의 Dictionary {"item", "kind", "size", "arrived"} 와 짝인 StaticBody3D (메타 "box").
## 그래픽: assets/models/outside/box_<small|medium|large>.glb, truck.glb (없으면 임시 상자). 뚜껑 Lid_L·Lid_R, 바퀴 Wheel_*.

signal delivered(count: int)

const PICK_LAYER := 2
const MODEL_DIR := "res://assets/models/outside/%s.glb"
const SIZES := ["small", "medium", "large"]
## 상자 크기 (ART_SLOTS 4-3): 가로 × 높이 × 깊이
const BOX_SIZE := {"small": Vector3(0.3, 0.25, 0.25), "medium": Vector3(0.5, 0.4, 0.4), "large": Vector3(0.9, 0.6, 0.6)}
## 매트 위 놓는 자리 (매트 가운데 기준, 매트는 z 로 1.6 m)
const MAT_SLOTS: Array[Vector3] = [Vector3(0, 0, -0.5), Vector3(0, 0, 0.0), Vector3(0, 0, 0.5), Vector3(0.25, 0, -0.25), Vector3(0.25, 0, 0.25)]
## 트럭: 찻길 x, 들어오는 곳·서는 곳·나가는 곳 z
const TRUCK_X := 10.6
const TRUCK_FROM_Z := -14.0
const TRUCK_STOP_Z := 0.5
const TRUCK_TO_Z := 16.0

var mat_center := Vector3(5.0, 0, 0.5)
## 트럭이 오는 중 (상자는 아직 매트에 없음)
var delivering := false
var truck: Node3D
var _pending: Array = []
var _boxes: Array[StaticBody3D] = []
var _tween: Tween


func _ready() -> void:
	truck = _model("truck")
	if truck == null:
		truck = Node3D.new()
		var body := _mesh_box(Vector3(1.8, 1.6, 3.5), Color(0.95, 0.95, 0.92))
		body.position.y = 1.1
		truck.add_child(body)
		var cab := _mesh_box(Vector3(1.8, 1.2, 1.0), Color(0.55, 0.78, 0.95))
		cab.position = Vector3(0, 0.9, -2.1)
		truck.add_child(cab)
	truck.name = "Truck"
	# 앞(−Z)을 달리는 쪽(+Z)으로
	truck.rotation.y = PI
	truck.visible = false
	add_child(truck)


## 상자들을 매트에 바로 놓음 (이미 도착한 것, 저장에서 이어하기)
func place(boxes: Array) -> void:
	for box in boxes:
		_add_box(box)


## 트럭이 와서 상자들을 내려놓음 (seconds 동안: 오기 · 내리기 · 떠나기). 끝나면 delivered
func deliver(boxes: Array, seconds: float) -> void:
	if boxes.is_empty():
		return
	_pending = boxes.duplicate()
	delivering = true
	truck.visible = true
	truck.position = Vector3(TRUCK_X, 0, TRUCK_FROM_Z)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(truck, "position:z", TRUCK_STOP_Z, seconds * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_interval(seconds * 0.3)
	_tween.tween_callback(_unload)
	_tween.tween_property(truck, "position:z", TRUCK_TO_Z, seconds * 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(func() -> void: truck.visible = false)


## 기다리지 않고 바로 (테스트·빠른 확인)
func finish_now() -> void:
	if _tween != null:
		_tween.kill()
	if delivering:
		_unload()
	truck.visible = false


func _unload() -> void:
	if not delivering:
		return
	delivering = false
	for box in _pending:
		box.arrived = true
		_add_box(box)
	var count := _pending.size()
	_pending.clear()
	delivered.emit(count)


## 상자 노드 (그 Dictionary 짝). 없으면 null
func node_of(box: Dictionary) -> StaticBody3D:
	for node in _boxes:
		if is_instance_valid(node) and is_same(node.get_meta("box"), box):
			return node
	return null


func box_nodes() -> Array[StaticBody3D]:
	return _boxes


## 들 때: 매트에서 떼어 냄 (노드는 그대로 돌려줌, 손에 붙이는 건 가게가)
func take(node: StaticBody3D) -> void:
	_boxes.erase(node)
	node.collision_layer = 0
	remove_child(node)


## 택배 수레 (시험용): cart.glb (손잡이 +Z, 미는 쪽 −Z) 또는 임시 짐칸. 메타 "cart", 클릭하면 밀기
func make_cart() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Cart"
	body.collision_layer = 1 << (PICK_LAYER - 1)
	body.collision_mask = 0
	body.set_meta("cart", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.0, 0.75)
	shape.shape = box
	shape.position.y = 0.5
	body.add_child(shape)
	var view := _model("cart")
	if view == null:
		view = Node3D.new()
		var bed := _mesh_box(Vector3(0.9, 0.06, 0.6), Color(0.55, 0.78, 0.95))
		bed.position.y = 0.27
		view.add_child(bed)
		var handle := _mesh_box(Vector3(0.6, 0.05, 0.05), Color(1.0, 0.7, 0.8))
		handle.position = Vector3(0, 1.0, 0.35)
		view.add_child(handle)
	view.name = "View"
	body.add_child(view)
	# 짐을 싣는 자리 (짐칸 바닥)
	var load_point := Node3D.new()
	load_point.name = "Load"
	load_point.position.y = 0.3
	body.add_child(load_point)
	return body


## 상자 모형 (들고 다닐 때도 씀)
func make_box_view(size: String) -> Node3D:
	var view := _model("box_" + size)
	if view == null:
		var dims: Vector3 = BOX_SIZE[size]
		view = Node3D.new()
		var body := _mesh_box(dims, Color(0.82, 0.64, 0.45))
		body.position.y = dims.y / 2.0
		view.add_child(body)
		var tape := _mesh_box(Vector3(dims.x + 0.005, 0.01, 0.06), Color(0.55, 0.78, 0.95))
		tape.position.y = dims.y
		view.add_child(tape)
	view.name = "View"
	return view


func _add_box(box: Dictionary) -> void:
	var size: String = box.get("size", "small")
	var dims: Vector3 = BOX_SIZE.get(size, BOX_SIZE.small)
	var body := StaticBody3D.new()
	body.name = "Box"
	body.collision_layer = 1 << (PICK_LAYER - 1)
	body.collision_mask = 0
	body.set_meta("box", box)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = dims
	shape.shape = box_shape
	shape.position.y = dims.y / 2.0
	body.add_child(shape)
	body.add_child(make_box_view(size))
	# 매트 자리: 앞에서부터, 넘치면 위에 쌓음
	var index := _boxes.size()
	var slot := MAT_SLOTS[index % MAT_SLOTS.size()]
	var stack := index / MAT_SLOTS.size()
	body.position = mat_center + slot + Vector3(0, 0.02 + stack * 0.62, 0)
	body.rotation.y = PI / 2.0
	add_child(body)
	_boxes.append(body)


func _model(model_name: String) -> Node3D:
	var path := MODEL_DIR % model_name
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func _mesh_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	view.material_override = material
	return view
