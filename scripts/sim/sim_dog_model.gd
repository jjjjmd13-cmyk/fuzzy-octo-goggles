extends Node3D
## 임시 강아지 모형 (목욕대용). 그래픽 교체 약속:
## - 바닥이 원점, 얼굴이 +Z (카메라 쪽), 몸 중심(마스크 기준)은 body_center.
## - fur_meshes 에 털 메시를 넣으면 털 셰이더가 입혀진다 (부위가 나뉘어 있어도 됨).
## - 마우스 판정은 HitBody(StaticBody3D, 충돌 층 5 = 16) 의 모양으로 한다. 모형을 바꾸면 모양도 맞춰 준다.
## - 얼굴(눈) 판정: face_center 에서 face_radius 안 (모형 기준 좌표).
## - 반응 함수: set_mood(0~2), wiggle_legs(), flap_cheeks(), jump(), shake(). 없어도 게임은 돈다.

@export var body_center := Vector3(0, 0.32, 0)
@export var face_center := Vector3(0, 0.52, 0.5)
@export var face_radius := 0.12
@export var fur_meshes: Array[MeshInstance3D] = []
@export var legs: Array[Node3D] = []
@export var cheeks: Array[Node3D] = []
@export var mouth: Node3D
@export var ears: Array[Node3D] = []
@export var tail: Node3D

var _t := 0.0
var _leg_wiggle := 0.0
var _cheek_flap := 0.0
var _jump := 0.0
var _shake := 0.0
var _mood := 2


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
	for cheek in cheeks:
		cheek.scale = Vector3.ONE * (1.0 + sin(_t * 50.0) * 0.25 * signf(_cheek_flap))
	position.y = sin(_jump / 0.5 * PI) * 0.25 if _jump > 0.0 else 0.0
	rotation.z = sin(_t * 45.0) * 0.25 * _shake
	if mouth != null:
		# 😊 웃는 입(넓게) / 😐 / 😣 (작고 아래로)
		mouth.scale = [Vector3(0.6, 1.5, 1), Vector3(1, 1, 1), Vector3(1.4, 0.7, 1)][_mood]
		mouth.position.y = [0.445, 0.455, 0.465][_mood]
	for ear in ears:
		ear.rotation.z = [-0.9, -0.35, 0.25][_mood] * signf(ear.position.x)
	if tail != null:
		tail.rotation.y = sin(_t * [2.0, 6.0, 14.0][_mood]) * 0.6
