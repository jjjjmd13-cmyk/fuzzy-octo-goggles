extends Node3D
## 임시 주인 (2등신 장난감 사람, GDD_V3 3.5): 구·캡슐을 코드로 조립한다. 외부 파일·비용 없음.
## 모자·옷 색만 다른 6종 (set_variant). 말은 하지 않고 몸짓만.
##
## 그래픽 교체: assets/ui/owner_<번호>.png 가 있으면 도형 대신 그 그림을 판자처럼 세워 보인다 (카메라를 향함).
## 진짜 3D 모형이 오면 scenes/art/sim/owner_model.tscn 을 바꾸고 아래 함수 이름만 맞추면 된다:
##   set_variant(i), enter(문, 목욕통 옆, 시간), go_sit(의자, 바라볼 곳, 시간), come_react(목욕통 옆, 기분 0~2), leave(문, 시간)
##   height (머리 꼭대기 높이, 말풍선 자리)

const UiArt := preload("res://scripts/game/ui_art.gd")
const SHIRTS: Array[Color] = [
	Color(1.0, 0.62, 0.77), Color(0.56, 0.83, 0.96), Color(0.72, 0.89, 0.83),
	Color(1.0, 0.85, 0.45), Color(0.8, 0.7, 1.0), Color(1.0, 0.55, 0.45),
]
const HATS: Array[Color] = [
	Color(1.0, 0.42, 0.42), Color(0.35, 0.55, 0.85), Color(0.95, 0.95, 0.95),
	Color(0.55, 0.4, 0.3), Color(0.4, 0.75, 0.5), Color(0.98, 0.84, 0.5),
]
const SKIN := Color(1.0, 0.86, 0.74)
const DARK := Color(0.1, 0.08, 0.08)

## 머리 꼭대기 높이 (m)
var height := 1.12

var _body: Node3D
var _head: Node3D
var _hat: MeshInstance3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _shirt_mat := StandardMaterial3D.new()
var _hat_mat := StandardMaterial3D.new()
var _board: Sprite3D
var _hearts: CPUParticles3D

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _move_time := 0.0
var _move_left := 0.0
var _face_target: Variant = null
var _pose := "stand"
var _react := -1
var _react_time := 0.0
var _t := 0.0


func _ready() -> void:
	_build()


func set_variant(index: int) -> void:
	_shirt_mat.albedo_color = SHIRTS[index % SHIRTS.size()]
	_hat_mat.albedo_color = HATS[index % HATS.size()]
	_hat.scale = [Vector3(1, 1, 1), Vector3(1.1, 0.6, 1.1), Vector3(0.9, 1.4, 0.9)][index % 3]
	var picture := UiArt.texture("owner_%d" % index)
	_board.texture = picture
	_board.visible = picture != null
	_body.visible = picture == null


## 강아지를 안고 문에서 목욕통 옆으로
func enter(door: Vector3, front: Vector3, duration: float) -> void:
	global_position = door
	_walk(front, duration, "carry")
	_react = -1


## 대기 의자로 가서 앉아 목욕통 쪽을 봄
func go_sit(chair: Vector3, look: Vector3, duration: float) -> void:
	_walk(chair, duration, "sit")
	_face_target = look


## 목욕통 옆으로 와서 반응 (기분 0 한숨 / 1 끄덕 / 2 하트·박수)
func come_react(front: Vector3, mood_level: int) -> void:
	_walk(front, 0.6, "stand")
	_react = mood_level
	_react_time = 0.0
	if mood_level == 2:
		_hearts.restart()
		_hearts.emitting = true


func leave(door: Vector3, duration: float) -> void:
	_react = -1
	_face_target = null
	_walk(door, duration, "walk")


func _walk(target: Vector3, duration: float, end_pose: String) -> void:
	_from = global_position
	_to = target
	_move_time = maxf(duration, 0.01)
	_move_left = _move_time
	_pose = end_pose


func _process(delta: float) -> void:
	_t += delta
	var moving := _move_left > 0.0
	if moving:
		_move_left = maxf(_move_left - delta, 0.0)
		var k := 1.0 - _move_left / _move_time
		global_position = _from.lerp(_to, smoothstep(0.0, 1.0, k))
		var flat := (_to - _from) * Vector3(1, 0, 1)
		if flat.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), minf(delta * 10.0, 1.0))
	elif _face_target != null:
		var look: Vector3 = (_face_target - global_position) * Vector3(1, 0, 1)
		if look.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), minf(delta * 6.0, 1.0))
	var sitting := _pose == "sit" and not moving
	# 걸을 때 통통, 앉으면 낮게
	_body.position.y = (absf(sin(_t * 10.0)) * 0.04 if moving else 0.0) + (0.02 if sitting else 0.0)
	for i in _legs.size():
		_legs[i].rotation.x = (-1.3 if sitting else sin(_t * 10.0 + i * PI) * 0.5 * float(moving))
	# 팔: 안고 올 때 앞으로, 반응 때 박수
	_react_time += delta
	for i in _arms.size():
		var side := -1.0 if i == 0 else 1.0
		var arm := _arms[i]
		arm.rotation = Vector3.ZERO
		if _pose == "carry":
			arm.rotation.x = -1.2
		elif _react == 2:
			arm.rotation.x = -1.3
			arm.rotation.z = side * (0.25 + absf(sin(_react_time * 12.0)) * 0.35)
		elif _react == 0:
			arm.rotation.z = side * 0.05
		else:
			arm.rotation.x = sin(_t * 10.0 + i * PI) * 0.4 * float(moving)
			arm.rotation.z = side * 0.15
	# 머리: 끄덕 / 한숨(고개 숙임) / 가만히 숨쉬기
	match _react:
		1:
			_head.rotation.x = absf(sin(_react_time * 6.0)) * 0.35 if _react_time < 1.6 else 0.0
		0:
			_head.rotation.x = minf(_react_time * 1.5, 0.45)
			_body.scale.y = 1.0 - minf(_react_time, 0.6) * 0.08
		_:
			_head.rotation.x = sin(_t * 1.5) * 0.03
			_body.scale.y = 1.0


func _build() -> void:
	_shirt_mat.albedo_color = SHIRTS[0]
	_shirt_mat.roughness = 0.8
	_hat_mat.albedo_color = HATS[0]
	var skin := StandardMaterial3D.new()
	skin.albedo_color = SKIN
	var pants := StandardMaterial3D.new()
	pants.albedo_color = Color(0.35, 0.4, 0.55)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_mesh(_body, _capsule(0.17, 0.5), Vector3(0, 0.5, 0), _shirt_mat)
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.08, 0.3, 0)
		_body.add_child(leg)
		_mesh(leg, _capsule(0.065, 0.32), Vector3(0, -0.14, 0), pants)
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.19, 0.66, 0)
		_body.add_child(arm)
		_mesh(arm, _capsule(0.05, 0.3), Vector3(0, -0.12, 0.0), _shirt_mat)
		_mesh(arm, _sphere(0.055), Vector3(0, -0.27, 0), skin)
		_arms.append(arm)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.78, 0)
	_body.add_child(_head)
	_mesh(_head, _sphere(0.19), Vector3(0, 0.15, 0), skin)
	for side in [-1, 1]:
		_mesh(_head, _sphere(0.02), Vector3(side * 0.065, 0.17, 0.175), _flat(DARK))
		_mesh(_head, _sphere(0.03), Vector3(side * 0.11, 0.1, 0.15), _flat(Color(1.0, 0.65, 0.65)))
	_mesh(_head, _box(Vector3(0.06, 0.012, 0.01)), Vector3(0, 0.09, 0.185), _flat(DARK))
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.13
	hat_mesh.bottom_radius = 0.2
	hat_mesh.height = 0.12
	_hat = _mesh(_head, hat_mesh, Vector3(0, 0.3, 0), _hat_mat)
	# 2D 판자 그림 (assets/ui/owner_<번호>.png 가 있을 때)
	_board = Sprite3D.new()
	_board.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_board.position = Vector3(0, 0.55, 0)
	_board.pixel_size = 0.0022
	_board.visible = false
	add_child(_board)
	_hearts = CPUParticles3D.new()
	_hearts.emitting = false
	_hearts.one_shot = true
	_hearts.amount = 10
	_hearts.lifetime = 1.4
	_hearts.explosiveness = 0.6
	_hearts.direction = Vector3.UP
	_hearts.spread = 35.0
	_hearts.gravity = Vector3(0, 0.3, 0)
	_hearts.initial_velocity_min = 0.3
	_hearts.initial_velocity_max = 0.6
	_hearts.position = Vector3(0, height, 0)
	var heart := SphereMesh.new()
	heart.radius = 0.03
	heart.height = 0.06
	heart.material = _flat(Color(1.0, 0.4, 0.6))
	_hearts.mesh = heart
	add_child(_hearts)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
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
