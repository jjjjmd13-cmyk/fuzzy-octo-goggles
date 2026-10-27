extends Node3D
## 목욕대 강아지 모형의 약속 (그래픽 교체 지점, docs/art/ART_SLOTS.md "dog").
##
## 이 스크립트를 모형 씬(scenes/art/sim/dog_model.tscn) 루트에 붙이면, 받은 GLB 든 임시 장난감 강아지든
## 같은 방식으로 움직인다. 코드는 **노드 이름**으로 부위를 찾는다 (없는 부위는 그냥 안 움직임):
##
##   Head            목 위치가 피벗. 커서 따라보기·고개 돌리기·몸 털기
##   Chest           숨쉬기 (살짝 커졌다 작아짐)
##   Eye_L, Eye_R    눈 가운데가 피벗. 세로 크기로 깜빡임·찡그림
##   Ear_L, Ear_R    귀 뿌리가 피벗. 기분에 따라 처짐(Z 회전), 드라이어에 팔랑
##   Tail_1..Tail_3  꼬리 마디 (Tail_2 는 Tail_1 의 자식…). 뿌리가 피벗. 흔들기(Z)·처짐(X)
##   Leg_FL, Leg_FR  앞다리, 어깨가 피벗. 간지럼에 찰랑(X)
##   Cheek_L, Cheek_R 볼 (드라이어를 얼굴에 대면 펄럭)
##   Mouth, Tongue   입 (기분), 혀 (기분 좋을 때만 보임)
##   FaceCenter      (Marker3D, 선택) 눈 사이. 눈에 물 판정 중심. 없으면 Head 앞쪽
##   BodyCenter      (Marker3D, 선택) 몸 가운데. 칠하기 마스크 중심. 없으면 body_center
## L/R 은 강아지 자신의 왼쪽·오른쪽. 바닥이 원점, 얼굴이 +Z (GLB 는 정면 −Z 로 받아 씬에서 Y 로 180° 돌림).
##
## 털: 이름이 Eye·Pupil·Glint·Nose·Mouth·Tongue·Collar·NoFur 로 시작하지 않는 모든 메시가 털이다.
## 털 메시에는 털 셰이더(scripts/sim/sim_fur.gdshader)가 입혀지고 진흙·젖음·거품·뽀송은 셰이더가 그린다.
## 원래 재질의 albedo 텍스처가 있으면 털 색으로 그대로 쓴다.
## 마우스 판정 모양(HitBody, 충돌 층 16)은 털 메시의 볼록 껍질로 자동으로 만든다.

## 털이 아닌 부위 이름 앞부분
const NON_FUR := ["Eye", "Pupil", "Glint", "Nose", "Mouth", "Tongue", "Collar", "NoFur"]
## 귀 처짐 (기분 0~2, 라디안), 꼬리 흔들기 [속도, 폭, 처짐], 눈 크기 (세로 비율)
const EAR_TILT := [1.0, 0.55, 0.25]
const TAIL_WAG := [[2.5, 0.12, 0.9], [6.0, 0.35, 0.2], [13.0, 0.6, -0.15]]
const EYE_OPEN := [0.45, 0.85, 1.0]

@export var body_center := Vector3(0, 0.27, -0.03)
@export var face_center := Vector3(0, 0.55, 0.26)
@export var face_radius := 0.1
## 비워 두면 이름 규칙으로 찾는다
@export var fur_meshes: Array[MeshInstance3D] = []
@export var auto_hit_shapes := true

var _t := 0.0
var _leg_wiggle := 0.0
var _cheek_flap := 0.0
var _jump := 0.0
var _shake := 0.0
var _mood := 2
var _blow := 0.0
var _blink_in := 2.0
var _blink := 0.0
var _squeeze := 0.0
var _look := Vector2.ZERO
var _watch_point: Variant = null
var _watch_spray := false

var _head: Node3D
var _chest: Node3D
var _eyes: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _tail: Array[Node3D] = []
var _front_legs: Array[Node3D] = []
var _cheeks: Array[Node3D] = []
var _mouth: Node3D
var _tongue: Node3D
var _face_marker: Node3D
## 움직이는 부위의 처음 자세 (움직임은 여기에 더함)
var _rest := {}
var _rest_axes := {}
var _rest_positions := {}
## 털 메시 → 처음 자세에서 모형 기준 변환 (마스크·진흙을 부위에 붙이는 데 씀, 이슈 #44)
var _fur_rest := {}


func _ready() -> void:
	_find_parts()
	if fur_meshes.is_empty():
		_collect_fur(self)
	var to_model := global_transform.affine_inverse()
	for mesh in fur_meshes:
		if mesh != null:
			_fur_rest[mesh] = to_model * mesh.global_transform
	if auto_hit_shapes:
		_build_hit_shapes()


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


## 머리 따라보기 (작업대가 매 프레임 부름): point = 커서가 닿은 곳(월드, 없으면 null), spraying = 물을 뿌리는 중
func watch(point: Variant, spraying: bool) -> void:
	_watch_point = to_local(point) if point != null else null
	_watch_spray = spraying


## 드라이어 바람 (바람이 닿는 동안 부름): 가까울수록(closeness 1) 귀·꼬리가 세게 날림
func blow(closeness: float) -> void:
	_blow = maxf(_blow, 0.3 + closeness * 0.7)


## 털 메시에 털 셰이더를 입힌다. 원래 albedo 텍스처가 있는 메시는 그 텍스처를 쓰는 사본을 만든다.
## 만든 재질 목록을 돌려준다 (작업대가 매 프레임 값을 넣음).
func apply_fur_material(template: ShaderMaterial) -> Array[ShaderMaterial]:
	var by_texture := {}
	var materials: Array[ShaderMaterial] = [template]
	for mesh in fur_meshes:
		var texture := _albedo_texture(mesh)
		var material := template
		if texture != null:
			if not by_texture.has(texture):
				var copy := template.duplicate() as ShaderMaterial
				copy.set_shader_parameter("albedo_tex", texture)
				copy.set_shader_parameter("use_albedo_tex", true)
				by_texture[texture] = copy
				materials.append(copy)
			material = by_texture[texture]
		mesh.material_override = material
		# 셰이더가 마스크를 처음 자세 위치로 찾게 한다: 머리·다리가 움직여도 무늬가 부위에 붙어 있음.
		# 클릭 판정 모양도 처음 자세로 구워져 있어서 칠하는 곳과 보이는 곳이 같다.
		var rest: Transform3D = _fur_rest.get(mesh, Transform3D.IDENTITY)
		mesh.set_instance_shader_parameter("rest_row_x", Vector4(rest.basis.x.x, rest.basis.y.x, rest.basis.z.x, rest.origin.x))
		mesh.set_instance_shader_parameter("rest_row_y", Vector4(rest.basis.x.y, rest.basis.y.y, rest.basis.z.y, rest.origin.y))
		mesh.set_instance_shader_parameter("rest_row_z", Vector4(rest.basis.x.z, rest.basis.y.z, rest.basis.z.z, rest.origin.z))
	return materials


func _process(delta: float) -> void:
	_t += delta
	_blow = maxf(_blow - delta * 3.0, 0.0)
	_leg_wiggle = maxf(_leg_wiggle - delta, 0.0)
	_cheek_flap = maxf(_cheek_flap - delta, 0.0)
	_jump = maxf(_jump - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)

	# 숨쉬기
	if _chest != null:
		_pose(_chest, Vector3.ZERO, 1.0 + sin(_t * PI) * 0.025)

	# 머리: 커서를 따라보다가, 물줄기가 얼굴 가까이 오면 반대로 고개를 돌리고 눈을 감는다
	var target := Vector2.ZERO
	var flinch := false
	if _watch_point != null and _head != null:
		var local: Vector3 = _watch_point
		var from_head: Vector3 = local - (_rest_positions[_head] + Vector3(0, 0.1, 0))
		target = Vector2(clampf(atan2(from_head.x, from_head.z), -0.6, 0.6), clampf(-atan2(from_head.y, Vector2(from_head.x, from_head.z).length()), -0.4, 0.4))
		flinch = _watch_spray and local.distance_to(face_center) < face_radius * 2.2
		if flinch:
			target = Vector2(-signf(from_head.x + 0.001) * 0.7, -0.35)
	_squeeze = move_toward(_squeeze, 1.0 if flinch else 0.0, delta * 8.0)
	_look = _look.lerp(target, minf(delta * (10.0 if flinch else 4.0), 1.0))
	if _head != null:
		_pose(_head, Vector3(_look.y, _look.x, sin(_t * 40.0 - 1.0) * 0.4 * _shake))
	face_center = _face_point()

	# 깜빡임 (눈을 감으면 세로로 납작)
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = 0.14
		_blink_in = randf_range(2.0, 5.0)
	_blink = maxf(_blink - delta, 0.0)
	var open: float = EYE_OPEN[_mood]
	if _blink > 0.0 or _squeeze > 0.5:
		open = 0.08
	for eye in _eyes:
		eye.scale.y = lerpf(eye.scale.y, _rest_of(eye).basis.get_scale().y * open, minf(delta * 25.0, 1.0))

	# 귀: 기분이 나쁘면 처지고, 드라이어·볼 펄럭이면 팔랑. 바깥쪽으로 처지도록 귀의 좌우에 따라 부호
	for i in _ears.size():
		var side := signf((_rest_positions[_ears[i]] as Vector3).x + 0.0001)
		var flutter := sin(_t * 45.0 + i) * (0.35 * signf(_cheek_flap) + 0.45 * _blow)
		_pose(_ears[i], Vector3(sin(_t * 30.0 + i) * 0.3 * _shake, 0, side * (EAR_TILT[_mood] + flutter)))

	for cheek in _cheeks:
		_pose(cheek, Vector3.ZERO, 1.0 + sin(_t * 50.0) * 0.25 * signf(_cheek_flap))

	# 입·혀: 기분 좋으면 혀를 내밈
	if _tongue != null:
		_tongue.visible = _mood == 2 and _squeeze < 0.5
	if _mouth != null:
		_pose(_mouth, Vector3.ZERO, 1.0, Vector3(1.0 if _mood > 0 else 0.6, 1, 1))

	# 꼬리: 기분에 따라 흔드는 속도·폭, 나쁘면 아래로 처짐. 마디마다 조금 늦게 따라와 휘어진다
	var wag: Array = TAIL_WAG[_mood]
	for i in _tail.size():
		var swing: float = sin(_t * wag[0] - i * 0.7) * wag[1] + sin(_t * 40.0 - 2.0 - i) * (0.5 * _shake + 0.25 * _blow)
		_pose(_tail[i], Vector3(wag[2] * (0.5 if i == 0 else 0.3), 0, swing))

	# 앞다리 찰랑
	for i in _front_legs.size():
		_pose(_front_legs[i], Vector3(sin(_t * 30.0 + i * PI) * 0.5 * _leg_wiggle, 0, 0))

	# 펄쩍·몸 털기 (머리→꼬리 물결은 위에서 위상차로)
	position.y = sin(_jump / 0.5 * PI) * 0.25 if _jump > 0.0 else 0.0
	rotation.z = sin(_t * 40.0) * 0.35 * _shake * 0.6


## 처음 자세에 회전(오일러)·크기를 더한다
func _pose(node: Node3D, euler: Vector3, scale_mult: float = 1.0, axis_scale: Vector3 = Vector3.ONE) -> void:
	var rest: Transform3D = _rest_of(node)
	var axes: Basis = _rest_axes[node]
	var local_rotation := axes.inverse() * Basis.from_euler(euler) * axes
	node.transform = Transform3D(rest.basis * local_rotation * Basis.from_scale(axis_scale * scale_mult), rest.origin)


func _rest_of(node: Node3D) -> Transform3D:
	if not _rest.has(node):
		_rest[node] = node.transform
	return _rest[node]


func _face_point() -> Vector3:
	if _face_marker != null:
		return to_local(_face_marker.global_position)
	if _head != null:
		return _head.transform * Vector3(0, 0.13, 0.17)
	return face_center


func _find_parts() -> void:
	_head = _part("Head")
	_chest = _part("Chest")
	_mouth = _part("Mouth")
	_tongue = _part("Tongue")
	_face_marker = _part("FaceCenter")
	var body_marker := _part("BodyCenter")
	if body_marker != null:
		body_center = to_local(body_marker.global_position)
	_eyes.clear()
	_ears.clear()
	_cheeks.clear()
	_front_legs.clear()
	_tail.clear()
	for side in ["L", "R"]:
		for list_name in ["Eye", "Ear", "Cheek"]:
			var node := _part("%s_%s" % [list_name, side])
			if node != null:
				{"Eye": _eyes, "Ear": _ears, "Cheek": _cheeks}[list_name].append(node)
		var leg := _part("Leg_F" + side)
		if leg != null:
			_front_legs.append(leg)
	for i in range(1, 6):
		var segment := _part("Tail_%d" % i)
		if segment == null:
			break
		_tail.append(segment)
	for node in [_head, _chest, _mouth] + _eyes + _ears + _cheeks + _front_legs + _tail:
		if node != null:
			_rest_of(node)
			_rest_axes[node] = global_basis.inverse() * node.global_basis
			_rest_positions[node] = to_local(node.global_position)


func _part(part_name: String) -> Node3D:
	return find_child(part_name, true, false) as Node3D


func _collect_fur(node: Node) -> void:
	for child in node.get_children():
		if child.name == "HitBody":
			continue
		if child is MeshInstance3D and not _is_non_fur(child.name):
			fur_meshes.append(child)
		_collect_fur(child)


func _is_non_fur(node_name: String) -> bool:
	for prefix in NON_FUR:
		if node_name.begins_with(prefix):
			return true
	return false


func _albedo_texture(mesh: MeshInstance3D) -> Texture2D:
	var source: Material = mesh.material_override
	if source == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		source = mesh.get_active_material(0)
	if source is BaseMaterial3D:
		return (source as BaseMaterial3D).albedo_texture
	return null


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
