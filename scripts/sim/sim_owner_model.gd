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

## 머리 꼭대기 높이 (m)
var height := 1.12

var _body: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
## 재질 이름 → 색을 바꿀 표면 목록 [메시, 표면 번호]
var _recolor := {"Shirt": [], "Hat": []}
var _board: Sprite3D
var _hearts: CPUParticles3D
var _rest := {}

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
	for node in [_body, _head] + _arms + _legs:
		if node != null:
			_rest[node] = node.transform
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
	# 걸을 때 통통, 앉으면 높이 맞춤, 한숨이면 살짝 움츠림
	if _body != null:
		var squash := 1.0 - minf(_react_time, 0.6) * 0.08 if _react == 0 else 1.0
		_set_pose(_body, Vector3.ZERO, Vector3(0, (absf(sin(_t * 10.0)) * 0.04 if moving else 0.0) + (0.02 if sitting else 0.0), 0), Vector3(1, squash, 1))
	for i in _legs.size():
		_set_pose(_legs[i], Vector3(-1.3 if sitting else sin(_t * 10.0 + i * PI) * 0.5 * float(moving), 0, 0))
	# 팔: 안고 올 때 앞으로, 반응 때 박수
	_react_time += delta
	for i in _arms.size():
		var side := signf(_rest[_arms[i]].origin.x + 0.0001)
		var swing := Vector3(sin(_t * 10.0 + i * PI) * 0.4 * float(moving), 0, side * 0.15)
		if _pose == "carry":
			swing = Vector3(-1.2, 0, 0)
		elif _react == 2:
			swing = Vector3(-1.3, 0, side * (0.25 + absf(sin(_react_time * 12.0)) * 0.35))
		elif _react == 0:
			swing = Vector3(0, 0, side * 0.05)
		_set_pose(_arms[i], swing)
	# 머리: 끄덕 / 한숨(고개 숙임) / 가만히 숨쉬기
	if _head != null:
		var nod := sin(_t * 1.5) * 0.03
		if _react == 1:
			nod = absf(sin(_react_time * 6.0)) * 0.35 if _react_time < 1.6 else 0.0
		elif _react == 0:
			nod = minf(_react_time * 1.5, 0.45)
		_set_pose(_head, Vector3(nod, 0, 0))


func _set_pose(node: Node3D, euler: Vector3, offset: Vector3 = Vector3.ZERO, scale_value: Vector3 = Vector3.ONE) -> void:
	var rest: Transform3D = _rest[node]
	node.transform = Transform3D(rest.basis * Basis.from_euler(euler) * Basis.from_scale(scale_value), rest.origin + offset)


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
