extends "res://scripts/sim/sim_dog_model.gd"
## 임시 강아지 (장난감 같은 앉은 강아지): 구·캡슐을 코드로 조립한다. 외부 파일·비용 없음.
## 진짜 그래픽(GLB)이 오면 scenes/art/sim/dog_model.tscn 을 그 모형으로 바꾸면 되고, 이 파일은 버린다.
##
## 살아 있는 느낌: 숨쉬기, 깜빡임, 기분에 따른 눈·귀·입·꼬리, 커서를 따라보는 머리,
## 물줄기가 얼굴로 오면 고개를 돌리고 눈을 질끈 감음(눈에 물 들어가기 전 신호), 몸 털기는 머리→꼬리 물결.
## 크기: 앉은 키 약 0.6 m, 길이 약 0.6 m. 바닥이 원점, 얼굴이 +Z.

const CREAM := Color(1, 1, 1)
## 귀·꼬리 끝 (털 색에 곱함)
const TAN := Color(0.78, 0.55, 0.36)
const DARK := Color(0.07, 0.05, 0.05)
const PINK := Color(1.0, 0.55, 0.6)

## 귀 기본 각도 (기분 0~2), 꼬리 흔들기 [속도, 폭, 처짐]
const EAR_TILT := [1.0, 0.55, 0.25]
const TAIL_WAG := [[2.5, 0.12, 0.9], [6.0, 0.35, 0.2], [13.0, 0.6, -0.15]]
## 눈 크기 (세로 비율)
const EYE_OPEN := [0.45, 0.85, 1.0]

var _chest: Node3D
var _head: Node3D
var _eyes: Array[Node3D] = []
var _ear_pivots: Array[Node3D] = []
var _front_legs: Array[Node3D] = []
var _tail_segments: Array[Node3D] = []
var _cheek_meshes: Array[Node3D] = []
var _mouth_mesh: Node3D
var _tongue: Node3D
var _fur_template: Material

var _blink_in := 2.0
var _blink := 0.0
var _squeeze := 0.0
var _look := Vector2.ZERO
var _watch_point: Variant = null
var _watch_spray := false
var _head_rest := Vector3.ZERO


func _ready() -> void:
	body_center = Vector3(0, 0.27, -0.03)
	face_radius = 0.1
	_build_parts()
	face_center = _face_point()
	super._ready()


## 머리 따라보기 (작업대가 매 프레임 부름): point = 커서가 닿은 곳(월드, 없으면 null), spraying = 물을 뿌리는 중
func watch(point: Variant, spraying: bool) -> void:
	_watch_point = to_local(point) if point != null else null
	_watch_spray = spraying


func _process(delta: float) -> void:
	_t += delta
	_leg_wiggle = maxf(_leg_wiggle - delta, 0.0)
	_cheek_flap = maxf(_cheek_flap - delta, 0.0)
	_jump = maxf(_jump - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)

	# 숨쉬기
	_chest.scale = Vector3(1, 1.15, 1) * (1.0 + sin(_t * PI) * 0.025)

	# 머리: 커서를 따라보다가, 물줄기가 얼굴 가까이 오면 반대로 고개를 돌리고 눈을 감는다
	var target := Vector2.ZERO
	var flinch := false
	if _watch_point != null:
		var local: Vector3 = _watch_point
		var from_head := local - (_head.position + Vector3(0, 0.1, 0))
		target = Vector2(clampf(atan2(from_head.x, from_head.z), -0.6, 0.6), clampf(-atan2(from_head.y, Vector2(from_head.x, from_head.z).length()), -0.4, 0.4))
		flinch = _watch_spray and local.distance_to(_face_point()) < face_radius * 2.2
		if flinch:
			target = Vector2(-signf(from_head.x + 0.001) * 0.7, -0.35)
	_squeeze = move_toward(_squeeze, 1.0 if flinch else 0.0, delta * 8.0)
	_look = _look.lerp(target, minf(delta * (10.0 if flinch else 4.0), 1.0))
	var shake_wave := sin(_t * 40.0) * 0.35 * _shake
	_head.rotation = Vector3(_look.y, _look.x, sin(_t * 40.0 - 1.0) * 0.4 * _shake)
	_head.position = _head_rest
	face_center = _face_point()

	# 깜빡임
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = 0.14
		_blink_in = randf_range(2.0, 5.0)
	_blink = maxf(_blink - delta, 0.0)
	var open: float = EYE_OPEN[_mood]
	if _blink > 0.0 or _squeeze > 0.5:
		open = 0.08
	for eye in _eyes:
		eye.scale.y = lerpf(eye.scale.y, open, minf(delta * 25.0, 1.0))

	# 귀: 기분이 나쁘면 처지고, 드라이어·볼 펄럭이면 팔랑
	for i in _ear_pivots.size():
		var side := -1.0 if i == 0 else 1.0
		var flutter := sin(_t * 45.0 + i) * 0.35 * signf(_cheek_flap)
		_ear_pivots[i].rotation.z = side * (EAR_TILT[_mood] + flutter)
		_ear_pivots[i].rotation.x = -0.2 + sin(_t * 30.0 + i) * 0.3 * _shake

	# 볼
	for cheek in _cheek_meshes:
		cheek.scale = Vector3.ONE * (1.0 + sin(_t * 50.0) * 0.25 * signf(_cheek_flap))

	# 입·혀: 기분 좋으면 혀를 내밈
	_tongue.visible = _mood == 2 and _squeeze < 0.5
	_mouth_mesh.rotation.z = 0.0
	_mouth_mesh.scale = Vector3(1.0 if _mood > 0 else 0.6, 1, 1)

	# 꼬리: 기분에 따라 흔드는 속도·폭, 나쁘면 아래로 처짐. 마디마다 조금 늦게 따라와 휘어진다
	var wag: Array = TAIL_WAG[_mood]
	for i in _tail_segments.size():
		var segment := _tail_segments[i]
		segment.rotation.z = sin(_t * wag[0] - i * 0.7) * wag[1] + sin(_t * 40.0 - 2.0 - i) * 0.5 * _shake
		segment.rotation.x = wag[2] * (0.5 if i == 0 else 0.3) + (-0.9 if i == 0 else 0.0)

	# 앞다리 찰랑
	for i in _front_legs.size():
		_front_legs[i].rotation.x = sin(_t * 30.0 + i * PI) * 0.5 * _leg_wiggle

	# 펄쩍·몸 털기 (머리→꼬리 물결은 위에서 위상차로)
	position.y = sin(_jump / 0.5 * PI) * 0.25 if _jump > 0.0 else 0.0
	rotation.z = shake_wave * 0.6


func _face_point() -> Vector3:
	return _head.transform * Vector3(0, 0.13, 0.17) if _head != null else face_center


func _build_parts() -> void:
	_fur_template = StandardMaterial3D.new()
	var hips := _part(self, "Hips", _sphere(0.16), Vector3(0, 0.16, -0.13), Vector3(1.1, 0.95, 1.05))
	_chest = Node3D.new()
	_chest.name = "Chest"
	_chest.position = Vector3(0, 0.29, 0.05)
	add_child(_chest)
	_part(_chest, "ChestFur", _sphere(0.14), Vector3.ZERO, Vector3.ONE)
	_part_between(self, "Belly", 0.13, Vector3(0, 0.19, -0.11), Vector3(0, 0.28, 0.04))

	# 머리 (목 위치가 피벗)
	_head = Node3D.new()
	_head.name = "HeadPivot"
	_head.position = Vector3(0, 0.40, 0.09)
	_head_rest = _head.position
	add_child(_head)
	_part(_head, "Head", _sphere(0.15), Vector3(0, 0.11, 0.04), Vector3.ONE)
	_part(_head, "Snout", _sphere(0.075), Vector3(0, 0.07, 0.15), Vector3(1, 0.8, 1.15))
	for side in [-1, 1]:
		_cheek_meshes.append(_part(_head, "Cheek", _sphere(0.05), Vector3(side * 0.065, 0.05, 0.13), Vector3.ONE))
	_solid(_head, "Nose", _sphere(0.028), Vector3(0, 0.10, 0.235), Vector3(1.2, 0.9, 1), DARK, 0.3)
	_mouth_mesh = _solid(_head, "Mouth", _box(Vector3(0.05, 0.008, 0.01)), Vector3(0, 0.035, 0.222), Vector3.ONE, DARK, 0.8)
	_tongue = _solid(_head, "Tongue", _sphere(0.022), Vector3(0, 0.022, 0.215), Vector3(1, 0.55, 1), PINK, 0.5)
	for side in [-1, 1]:
		var eye := Node3D.new()
		eye.name = "Eye"
		eye.position = Vector3(side * 0.068, 0.15, 0.14)
		_head.add_child(eye)
		# 만화 눈: 큰 검은 눈 + 반짝 점 두 개
		_solid(eye, "Pupil", _sphere(0.036), Vector3.ZERO, Vector3(0.9, 1, 0.55), DARK, 0.15)
		_solid(eye, "Glint", _sphere(0.011), Vector3(0.011 * side, 0.013, 0.02), Vector3.ONE, Color(1, 1, 1), 0.1)
		_solid(eye, "Glint2", _sphere(0.005), Vector3(-0.008 * side, -0.01, 0.021), Vector3.ONE, Color(1, 1, 1), 0.1)
		_eyes.append(eye)
		var ear := Node3D.new()
		ear.name = "EarPivot"
		ear.position = Vector3(side * 0.1, 0.22, 0.01)
		_head.add_child(ear)
		var ear_mesh := _part(ear, "Ear", _capsule(0.036, 0.17), Vector3(0, -0.06, 0), Vector3(1, 1, 0.45))
		ear_mesh.set_instance_shader_parameter("tint", TAN)
		_ear_pivots.append(ear)

	# 다리: 앞다리는 곧게, 뒷다리는 앉은 허벅지
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "FrontLeg"
		leg.position = Vector3(side * 0.08, 0.27, 0.11)
		add_child(leg)
		_part(leg, "Leg", _capsule(0.045, 0.27), Vector3(0, -0.13, 0), Vector3.ONE)
		_part(leg, "Paw", _sphere(0.05), Vector3(0, -0.245, 0.03), Vector3(1, 0.6, 1.3))
		_front_legs.append(leg)
		_part(self, "Haunch", _sphere(0.1), Vector3(side * 0.12, 0.12, -0.09), Vector3(0.8, 1, 1.2))
		_part(self, "BackPaw", _sphere(0.05), Vector3(side * 0.12, 0.03, 0.04), Vector3(1, 0.6, 1.4))

	# 꼬리: 세 마디 + 끝 털뭉치
	var parent: Node3D = self
	var at := Vector3(0, 0.15, -0.28)
	for i in 3:
		var segment := Node3D.new()
		segment.name = "Tail%d" % i
		segment.position = at
		parent.add_child(segment)
		_part(segment, "TailFur", _capsule(0.03, 0.11), Vector3(0, 0.045, 0), Vector3.ONE)
		_tail_segments.append(segment)
		parent = segment
		at = Vector3(0, 0.09, 0)
	var tip := _part(parent, "TailTip", _sphere(0.045), Vector3(0, 0.1, 0), Vector3.ONE)
	tip.set_instance_shader_parameter("tint", TAN)
	tail = _tail_segments[0]
	if hips == null:
		push_warning("강아지 모형을 만들지 못함")


## 털 부위 (털 셰이더가 입혀짐)
func _part(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3, scale_value: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	instance.material_override = _fur_template
	parent.add_child(instance)
	fur_meshes.append(instance)
	return instance


## 두 점 사이를 잇는 털 캡슐
func _part_between(parent: Node3D, part_name: String, radius: float, a: Vector3, b: Vector3) -> MeshInstance3D:
	var instance := _part(parent, part_name, _capsule(radius, a.distance_to(b) + radius * 2.0), (a + b) / 2.0, Vector3.ONE)
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
