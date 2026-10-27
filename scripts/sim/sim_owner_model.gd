extends Node3D
## 주인 손님 모형의 약속 (그래픽 교체 지점, docs/art/ART_SLOTS.md "owner"). GDD_V3 3.5.
##
## 이 스크립트를 주인 모형 씬(scenes/art/sim/owner_model.tscn) 루트에 붙이면, 받은 GLB 든 임시 장난감이든
## 같은 방식으로 움직인다. 코드는 **노드 이름**으로 부위를 찾는다 (없는 부위는 안 움직임):
##   Body            몸 전체 (걸을 때 통통, 앉으면 높이 맞춤, 한숨에 살짝 움츠림)
##   Head            목이 피벗 (끄덕, 고개 숙임)
##   Arm_L, Arm_R    어깨가 피벗 (안고 오기·박수·걸을 때 흔들기)
##   Leg_L, Leg_R    엉덩이가 피벗 (걷기·앉기)
## L/R 은 주인 자신의 왼쪽(+X)·오른쪽. 바닥이 원점, 정면 +Z (GLB 는 정면 −Z 로 받아 씬에서 180°).
## 6명 색: 재질 이름이 "Shirt"·"Hat" 인 표면을 set_variant 가 SHIRTS·HATS 색으로 바꾼다.
## 2D 판자 그림: assets/ui/owner_<번호>.png 가 있으면 몸 대신 그 그림을 세운다.
## 작업대가 부르는 함수: set_variant(i), enter(문, 목욕통 옆, 시간), go_sit(의자, 바라볼 곳, 시간),
##   come_react(목욕통 옆, 기분 0~2), leave(문, 시간). height = 머리 꼭대기 (말풍선 자리).

const UiArt := preload("res://scripts/game/ui_art.gd")
const SHIRTS: Array[Color] = [
	Color(1.0, 0.62, 0.77), Color(0.56, 0.83, 0.96), Color(0.72, 0.89, 0.83),
	Color(1.0, 0.85, 0.45), Color(0.8, 0.7, 1.0), Color(1.0, 0.55, 0.45),
]
const HATS: Array[Color] = [
	Color(1.0, 0.42, 0.42), Color(0.35, 0.55, 0.85), Color(0.95, 0.95, 0.95),
	Color(0.55, 0.4, 0.3), Color(0.4, 0.75, 0.5), Color(0.98, 0.84, 0.5),
]

## 기본 키와 앉는 자리 높이. height는 현재 머리 위 말풍선 위치에 쓰는 높이.
@export var standing_height := 1.12
@export var seat_height := 0.4
@export var hip_clearance := 0.055
var height := 1.12
## 기다림 몸짓 (대기열): 0 가만히 / 1 시계 보기 / 2 발 구르기 / 3 시무룩
var wait_level := 0
## 강아지를 안고 있음 (대기 손님: 손님인 줄 알아보게)
var holding := false

var _body: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _knee_scales: Array[float] = []
var _seated_body_offset := 0.02
## 재질 이름 → 색을 바꿀 표면 목록 [메시, 표면 번호]
var _recolor := {"Shirt": [], "Hat": []}
var _board: Sprite3D
var _hearts: CPUParticles3D
var _rest := {}
var _rest_axes := {}
var _rest_positions := {}

## 걸어갈 남은 구간 [목표, 시간]
var _segments: Array = []
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
	_body = find_child("Body", true, false) as Node3D
	_head = find_child("Head", true, false) as Node3D
	for tag in ["L", "R"]:
		var arm := find_child("Arm_" + tag, true, false) as Node3D
		if arm != null:
			_arms.append(arm)
		var leg := find_child("Leg_" + tag, true, false) as Node3D
		if leg != null:
			_legs.append(leg)
		var knee := find_child("Knee_" + tag, true, false) as Node3D
		if knee != null:
			_knees.append(knee)
	for node in [_body, _head] + _arms + _legs + _knees:
		if node != null:
			_rest[node] = node.transform
			_rest_axes[node] = global_basis.inverse() * node.global_basis
			_rest_positions[node] = to_local(node.global_position)
	height = standing_height
	_fit_seated_pose()
	_find_recolor(self)
	_add_effects()


func set_variant(index: int) -> void:
	_paint("Shirt", SHIRTS[index % SHIRTS.size()])
	_paint("Hat", HATS[index % HATS.size()])
	var picture := UiArt.texture("owner_%d" % index)
	_board.texture = picture
	_board.visible = picture != null
	if _body != null:
		_body.visible = picture == null


## 강아지를 안고 문(또는 대기 의자)에서 목욕통 옆으로. via = 들르는 곳 (목욕통을 돌아가기)
func enter(door: Vector3, front: Vector3, duration: float, via: Array = []) -> void:
	global_position = door
	wait_level = 0
	_walk(front, duration, "carry", via)
	_react = -1


## 대기 의자로 가서 앉아 목욕통 쪽을 봄
func go_sit(chair: Vector3, look: Vector3, duration: float) -> void:
	_walk(chair, duration, "sit")
	_face_target = look
	_react = -1


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


## 대기열 자리로 (의자면 앉고, 문밖 줄이면 서서 기다림)
func go_wait(spot: Vector3, look: Vector3, duration: float, seated: bool) -> void:
	_walk(spot, duration, "sit" if seated else "stand")
	_face_target = look
	_react = -1


## 걷기: via 를 차례로 들러 target 까지 duration 동안 (거리에 따라 나눔)
func _walk(target: Vector3, duration: float, end_pose: String, via: Array = []) -> void:
	var points: Array = via + [target]
	var lengths: Array[float] = []
	var total := 0.0
	var at := global_position
	for point: Vector3 in points:
		lengths.append(at.distance_to(point))
		total += lengths[-1]
		at = point
	_segments.clear()
	for i in points.size():
		_segments.append([points[i], maxf(duration, 0.01) * (lengths[i] / total if total > 0.001 else 1.0 / points.size())])
	_pose = end_pose
	_move_left = 0.0
	_next_segment()


func _next_segment() -> void:
	var segment: Array = _segments.pop_front()
	_from = global_position
	_to = segment[0]
	_move_time = maxf(segment[1], 0.01)
	_move_left = _move_time


func _process(delta: float) -> void:
	_t += delta
	if _move_left <= 0.0 and not _segments.is_empty():
		_next_segment()
	var moving := _move_left > 0.0 or not _segments.is_empty()
	if _move_left > 0.0:
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
	# 걸을 때 통통, 앉으면 높이 맞춤, 한숨이면 살짝 움츠림
	if _body != null:
		var squash := 1.0 - minf(_react_time, 0.6) * 0.08 if _react == 0 else (0.95 if wait_level == 3 else 1.0)
		_set_pose(_body, Vector3.ZERO, Vector3(0, (absf(sin(_t * 10.0)) * 0.04 if moving else 0.0) + (_seated_body_offset if sitting else 0.0), 0), Vector3(1, squash, 1))
	height = standing_height * (_body.scale.y if _body != null else 1.0) + (_seated_body_offset if sitting else 0.0)
	if _hearts != null:
		_hearts.position.y = height
	var jointed := _knees.size() == _legs.size() and not _knees.is_empty()
	for i in _legs.size():
		var bend := -PI / 2.0 if jointed else -1.3
		# 발 구르기: 한쪽 다리를 빠르게 까딱
		var tap := sin(_t * 16.0) * 0.12 if wait_level == 2 and i == 0 and not moving else 0.0
		_set_pose(_legs[i], Vector3((bend if sitting else sin(_t * 10.0 + i * PI) * 0.5 * float(moving)) + tap, 0, 0))
		if jointed:
			_set_pose(_knees[i], Vector3(PI / 2.0 if sitting else 0.0, 0, 0), Vector3.ZERO, Vector3(1, _knee_scales[i] if sitting else 1.0, 1))
	# 팔: 안고 올 때 앞으로, 반응 때 박수
	_react_time += delta
	for i in _arms.size():
		var side := signf((_rest_positions[_arms[i]] as Vector3).x + 0.0001)
		var swing := Vector3(sin(_t * 10.0 + i * PI) * 0.4 * float(moving), 0, side * 0.15)
		if _pose == "carry":
			swing = Vector3(-1.2, 0, 0)
		elif _react == 2:
			swing = Vector3(-1.3, 0, side * (0.25 + absf(sin(_react_time * 12.0)) * 0.35))
		elif wait_level == 1 and i == 0 and _watch_glance():
			# 시계 보기: 손목을 눈앞으로 (강아지는 다른 팔로 안음)
			swing = Vector3(-1.5, 0, -side * 0.5)
		elif holding and _react < 0:
			# 안은 강아지를 받침 (시무룩하면 팔이 처짐)
			swing = Vector3((-0.6 if wait_level == 3 else -0.9) if sitting else -1.2, 0, side * 0.1)
		elif _react == 0 or wait_level == 3:
			swing = Vector3(0, 0, side * 0.05)
		_set_pose(_arms[i], swing)
	# 머리: 끄덕 / 한숨(고개 숙임) / 가만히 숨쉬기
	if _head != null:
		var nod := sin(_t * 1.5) * 0.03
		if _react == 1:
			nod = absf(sin(_react_time * 6.0)) * 0.35 if _react_time < 1.6 else 0.0
		elif _react == 0:
			nod = minf(_react_time * 1.5, 0.45)
		elif wait_level == 3:
			nod = 0.45
		elif wait_level == 1 and _watch_glance():
			nod = 0.3
		_set_pose(_head, Vector3(nod, 0, 0))


## 의자에 앉아 있음 (걷는 중이 아님)
func is_sitting() -> bool:
	return _pose == "sit" and _move_left <= 0.0 and _segments.is_empty()


## 시계 보기는 4초마다 1.5초씩
func _watch_glance() -> bool:
	return fmod(_t, 4.0) < 1.5


func _set_pose(node: Node3D, euler: Vector3, offset: Vector3 = Vector3.ZERO, scale_value: Vector3 = Vector3.ONE) -> void:
	var rest: Transform3D = _rest[node]
	var axes: Basis = _rest_axes[node]
	var local_rotation := axes.inverse() * Basis.from_euler(euler) * axes
	node.transform = Transform3D(rest.basis * local_rotation * Basis.from_scale(scale_value), rest.origin + offset)


## 무릎이 있는 GLB는 실제 관절/발바닥 길이로 의자에 맞춘다. 이전 모형은 기존 자세 유지.
func _fit_seated_pose() -> void:
	if _knees.size() != _legs.size() or _knees.is_empty():
		return
	var hips := 0.0
	for leg in _legs:
		hips += (_rest_positions[leg] as Vector3).y
	hips /= _legs.size()
	_seated_body_offset = seat_height + hip_clearance - hips
	for i in _knees.size():
		var knee := _knees[i]
		var hip: Vector3 = _rest_positions[_legs[i]]
		var neutral: Vector3 = _rest_positions[knee]
		var seated := hip + Vector3(0, _seated_body_offset, 0) + Basis(Vector3.RIGHT, -PI / 2.0) * (neutral - hip)
		var length := neutral.y
		if knee is MeshInstance3D:
			length = -(knee as MeshInstance3D).get_aabb().position.y
		_knee_scales.append(seated.y / maxf(length, 0.01))


## 재질 이름이 Shirt·Hat 인 표면을 찾아 둔다 (GLB 는 재질 이름, 임시 모형은 resource_name)
func _find_recolor(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			for surface in child.mesh.get_surface_count():
				var material: Material = child.get_active_material(surface)
				if material != null and _recolor.has(material.resource_name):
					_recolor[material.resource_name].append([child, surface])
		_find_recolor(child)


func _paint(material_name: String, color: Color) -> void:
	for entry in _recolor[material_name]:
		var mesh: MeshInstance3D = entry[0]
		var source: Material = mesh.get_active_material(entry[1])
		if source is BaseMaterial3D:
			var copy := source.duplicate() as BaseMaterial3D
			copy.resource_name = material_name
			copy.albedo_color = color
			mesh.set_surface_override_material(entry[1], copy)


func _add_effects() -> void:
	# 2D 판자 그림 (assets/ui/owner_<번호>.png 가 있을 때)
	_board = Sprite3D.new()
	_board.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_board.position = Vector3(0, 0.55, 0)
	_board.pixel_size = 0.0022
	_board.visible = false
	add_child(_board)
	# 😊 반응 때 떠오르는 하트
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
	var pink := StandardMaterial3D.new()
	pink.albedo_color = Color(1.0, 0.4, 0.6)
	heart.material = pink
	_hearts.mesh = heart
	add_child(_hearts)
