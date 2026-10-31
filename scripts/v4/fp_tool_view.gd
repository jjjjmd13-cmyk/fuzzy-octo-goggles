extends Node3D
## PR #71 정적 메시 어댑터. 관절/손가락 변형 없이 손목 원점만 움직인다.
## 목욕 판정/입력은 fp_shop 에 남기고, 이 노드는 시각 연출만 담당한다.

const MODELS := {
	"shower": preload("res://assets/models/tools/shower.glb"),
	"shampoo": preload("res://assets/models/tools/shampoo.glb"),
	"towel": preload("res://assets/models/tools/towel.glb"),
}
# 드라이어는 assets/models/tools/dryer.glb 에 보존. V4 도구 목록에는 넣지 않는다.
const HANDS := preload("res://assets/models/hands/hands.glb")
const PICK_SECONDS := 0.42
const RETURN_SECONDS := 0.28

var tool_id := ""
var model: Node3D
var right_wrist: Node3D
var left_wrist: Node3D
var _rest := Vector3.ZERO
var _age := 0.0
var _pick_delay := 0.0
var _phase := 0.0
var _use_blend := 0.0
var _returning := false
var _return_from := Transform3D.IDENTITY
var _return_elapsed := 0.0
var _right_rest := Transform3D.IDENTITY
var _left_rest := Transform3D.IDENTITY


static func make_model(id: String) -> Node3D:
	return (MODELS[id] as PackedScene).instantiate() as Node3D


func setup(id: String, pick_delay := 0.0) -> void:
	_pick_delay = pick_delay
	tool_id = id
	name = "Held_" + id
	model = make_model(id)
	model.name = "ToolModel"
	add_child(model)
	# GLB Hand_L/R 의 손목 원점을 재사용하고 배치용 ±0.105m 를 제거한다.
	var source := HANDS.instantiate()
	for side in ["R", "L"]:
		var mesh := source.find_child("Hand_" + side, true, false) as Node3D
		assert(mesh != null, "hands.glb requires wrist-origin Hand_" + side)
		var wrist := Node3D.new()
		wrist.name = "Wrist_" + side
		add_child(wrist)
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		wrist.add_child(mesh)
		mesh.position = Vector3.ZERO
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if side == "R": right_wrist = wrist
		else: left_wrist = wrist
	source.free()
	_rest = Vector3(0.25, -0.25, -0.55)
	# 열린 손바닥으로 아래를 받침. 정적 손가락을 손잡이 속에 억지로 넣지 않는다.
	right_wrist.position = Vector3(0.015, -0.077, 0.065)
	right_wrist.rotation = Vector3(0.12, 0.15, -0.15)
	left_wrist.position = Vector3(-0.47, -0.07, 0.03)
	left_wrist.rotation = Vector3(0.15, -0.25, 0.12)
	if id == "shampoo":
		model.rotation.y = PI # 발바닥 라벨이 사용자에게 보이게
		right_wrist.position.y = -0.095
	elif id == "towel":
		_rest = Vector3(0.10, -0.30, -0.57)
		right_wrist.position = Vector3(0.12, -0.028, 0.075)
		left_wrist.position = Vector3(-0.12, -0.028, 0.075)
		right_wrist.rotation = Vector3(0.0, 0.15, -0.10)
		left_wrist.rotation = Vector3(0.0, -0.15, 0.10)
	_right_rest = right_wrist.transform
	_left_rest = left_wrist.transform
	# 도구를 손목의 자식으로 옮기되 기존 쥐는 자세를 보존한다.
	# 이후 회전 중심은 도구 중심이 아닌 실제 손목이다.
	var grip_transform := model.transform
	remove_child(model)
	right_wrist.add_child(model)
	model.transform = _right_rest.affine_inverse() * grip_transform
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D: meshes.append(model)
	for mesh in meshes:
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = _rest + Vector3(0.06, -0.40, 0.10)
	update_motion(0.0, false)


func is_returning() -> bool:
	return _returning


func begin_return() -> void:
	_returning = true
	_return_from = transform
	_return_elapsed = 0.0 if visible else RETURN_SECONDS


## true 면 선반에 돌려 놓고 이 뷰를 지워도 됨. 호출자가 수명·선반을 관리한다.
func update_motion(delta: float, active: bool) -> bool:
	if not _returning and _pick_delay > 0.0:
		_pick_delay = maxf(0.0, _pick_delay - delta)
		visible = false
		return false
	visible = true
	_age += delta
	if _returning:
		_return_elapsed += delta
		var t := smoothstep(0.0, 1.0, _return_elapsed / RETURN_SECONDS)
		position = _return_from.origin.lerp(_rest + Vector3(0.08, -0.48, 0.12), t)
		quaternion = _return_from.basis.get_rotation_quaternion().slerp(Quaternion.from_euler(Vector3(0.55, -0.15, 0.22)), t)
		return _return_elapsed >= RETURN_SECONDS
	_use_blend = move_toward(_use_blend, 1.0 if active else 0.0, delta * 7.0)
	_phase += delta * (10.0 if tool_id == "towel" else 6.0)
	var lift := smoothstep(0.0, 1.0, _age / PICK_SECONDS)
	var offset := Vector3.ZERO
	var angles := Vector3.ZERO
	match tool_id:
		"shower":
			offset = Vector3(sin(_phase) * 0.012, 0.025 + cos(_phase) * 0.007, -0.035) * _use_blend
			angles = Vector3(-0.18, sin(_phase) * 0.025, -0.08) * _use_blend
		"shampoo":
			offset = Vector3(-0.035, 0.02 + sin(_phase) * 0.009, -0.04) * _use_blend
			angles = Vector3(-0.85, -0.12, -0.18) * _use_blend
		"towel":
			offset = Vector3(sin(_phase) * 0.07, 0.035, -0.07) * _use_blend
			angles = Vector3(-0.12, 0.0, sin(_phase) * 0.08) * _use_blend
	# 집기: 화면 아래에서 손목을 돌리며 올리고 부드럽게 멈춘다.
	position = _rest + Vector3(0.06, -0.40, 0.10) * (1.0 - lift) + offset
	rotation = Vector3(0.45, -0.2, 0.18) * (1.0 - lift)
	right_wrist.transform = _right_rest
	right_wrist.rotation += angles
	left_wrist.transform = _left_rest
	if tool_id == "towel":
		left_wrist.transform = right_wrist.transform * _right_rest.affine_inverse() * _left_rest
	# 수건은 양손이 같은 천을 받치고, 한손 도구는 보조 손의 흔들림을 작게 한다.
	if tool_id != "towel":
		left_wrist.position -= offset * 0.8
		left_wrist.rotation.z += sin(_phase * 0.5) * 0.025 * _use_blend
	return false


func tip_position() -> Vector3:
	# 샤워기 GLB 의 실제 분사구 중심 (손목 모션을 그대로 따라감).
	return model.to_global(Vector3(0.0, 0.093, -0.028))
