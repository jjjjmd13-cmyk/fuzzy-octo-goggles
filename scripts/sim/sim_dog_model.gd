extends Node3D
## 임시 강아지 모형 (목욕대용). 그래픽 교체 약속:
## - 바닥이 원점, 얼굴이 +Z (카메라 쪽), 몸 중심(마스크 기준)은 body_center.
## - fur_meshes 에 털 메시를 넣으면 털 셰이더가 입혀진다 (부위가 나뉘어 있어도 됨).
## - 마우스 판정은 HitBody(StaticBody3D, 충돌 층 16) 로 한다. auto_hit_shapes 가 켜져 있으면 시작할 때
##   fur_meshes 마다 볼록 껍질 모양을 만들어 붙이므로 모형을 바꿔도 따로 맞출 필요가 없다.
## - 얼굴(눈) 판정: face_center 에서 face_radius 안 (모형 기준 좌표).
## - 반응 함수: set_mood(0~2), wiggle_legs(), flap_cheeks(), jump(), shake(). 없어도 게임은 돈다.

@export var body_center := Vector3(0, 0.32, 0)
@export var face_center := Vector3(0, 0.545, 0.5)
@export var face_radius := 0.1
@export var fur_meshes: Array[MeshInstance3D] = []
@export var legs: Array[Node3D] = []
@export var cheeks: Array[Node3D] = []
@export var mouth: Node3D
@export var ears: Array[Node3D] = []
@export var tail: Node3D
@export var auto_hit_shapes := true

var _t := 0.0
var _leg_wiggle := 0.0
var _cheek_flap := 0.0
var _jump := 0.0
var _shake := 0.0
var _mood := 2
var _mouth_rest := Vector3.ZERO
var _cheek_rest: Array[Vector3] = []


func _ready() -> void:
	if mouth != null:
		_mouth_rest = mouth.position
	for cheek in cheeks:
		_cheek_rest.append(cheek.scale)
	if auto_hit_shapes:
		_build_hit_shapes()


## 털 메시마다 볼록 껍질 충돌 모양 (모형 기준 좌표로 구워 넣음, 크기·비율 그대로).
func _build_hit_shapes() -> void:
	var body := get_node_or_null("HitBody") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "HitBody"
		body.collision_layer = 16
		body.collision_mask = 0
		add_child(body)
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var to_model := global_transform.affine_inverse()
	for mesh in fur_meshes:
		if mesh == null or mesh.mesh == null:
			continue
		var hull := mesh.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		var xform := to_model * mesh.global_transform
		var points := PackedVector3Array()
		for point in hull.points:
			points.append(xform * point)
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)


func apply_fur_material(material: Material) -> void:
	for mesh in fur_meshes:
		mesh.material_override = material


func set_mood(level: int) -> void:
	_mood = level


func wiggle_legs() -> void:
	_leg_wiggle = 1.0


func flap_cheeks() -> void:
	_cheek_flap = 0.4


func jump() -> void:
	_jump = 0.5


func shake() -> void:
	_shake = 1.0


func _process(delta: float) -> void:
	_t += delta
	_leg_wiggle = maxf(_leg_wiggle - delta, 0.0)
	_cheek_flap = maxf(_cheek_flap - delta, 0.0)
	_jump = maxf(_jump - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)
	for i in legs.size():
		legs[i].rotation.x = sin(_t * 30.0 + i) * 0.5 * _leg_wiggle
	for i in cheeks.size():
		cheeks[i].scale = _cheek_rest[i] * (1.0 + sin(_t * 50.0) * 0.25 * signf(_cheek_flap))
	position.y = sin(_jump / 0.5 * PI) * 0.25 if _jump > 0.0 else 0.0
	rotation.z = sin(_t * 45.0) * 0.25 * _shake
	if mouth != null:
		# 😊 웃는 입(넓게) / 😐 / 😣 (작고 아래로)
		mouth.scale = [Vector3(0.6, 1.5, 1), Vector3(1, 1, 1), Vector3(1.4, 0.7, 1)][_mood]
		mouth.position = _mouth_rest + Vector3(0, [-0.01, 0.0, 0.01][_mood], 0)
	for ear in ears:
		ear.rotation.z = [-0.9, -0.35, 0.25][_mood] * signf(ear.position.x)
	if tail != null:
		tail.rotation.y = sin(_t * [2.0, 6.0, 14.0][_mood]) * 0.6
