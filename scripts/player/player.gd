extends CharacterBody3D
## 플레이어 (위에서 비스듬히 보는 3인칭, 오버쿡드식).
##
## 노드 이름 = 조종하는 피어 ID. 각자 자기 캐릭터의 권한을 갖고 직접 움직이며 ClientSync 가
## 위치·방향을 다른 피어에게 보낸다. 카메라는 플레이어가 아니라 월드의 고정 카메라 하나이고,
## 이동 방향은 그 카메라 기준이다 (화면 위 = 앞).
## 겉모습은 ModelPivot/Model 씬(scenes/art/player_model.tscn)에만 있다.
## 든 물건은 CarryPoint 에 붙는다 (Carryable 이 따라 그림).
## 대시(Shift)와 물웅덩이 미끄러짐도 여기서 한다. 웅덩이는 호스트가 만들지만, 이동 권한이
## 본인에게 있으므로 미끄러짐은 각자 자기 캐릭터에서 판정한다.

signal slipped

const DASH_TIME := 0.15

const PLAYER_COLORS: Array[Color] = [
	Color(0.95, 0.55, 0.2), Color(0.3, 0.65, 0.95), Color(0.45, 0.85, 0.4), Color(0.9, 0.4, 0.75),
]

@export var acceleration := 40.0
@export var turn_speed := 14.0
@export var remote_smoothing := 15.0

## 플레이어 번호(0부터, 빈 자리 순서). 호스트가 정해 스폰 데이터로 보낸다. 색 고르기에 쓴다.
@export var slot := 0:
	set(value):
		slot = value
		_apply_color()

# --- ClientSync (조종하는 피어가 씀)
var net_position := Vector3.ZERO
var net_yaw := 0.0

var dash_cooldown_left := 0.0
var _dash_left := 0.0
var _dash_dir := Vector3.FORWARD
## 미끄러지는 중이면 남은 시간 (그동안 조작 불가)
var slide_left := 0.0
var _slide_velocity := Vector3.ZERO
var _slip_immunity := 0.0
## 대시·미끄러짐이 막 끝났으면 true → 그 프레임에 바로 입력 속도로 바꾼다 (관성으로 더 가지 않게)
var _burst_ended := false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var model_pivot: Node3D = $ModelPivot
@onready var carry_point: Node3D = $CarryPoint


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	add_to_group("players")
	_apply_color()
	net_position = position
	net_yaw = rotation.y


func get_peer_id() -> int:
	return name.to_int()


## 판정용 위치: 조종하는 피어가 마지막으로 보낸 위치. 다른 피어 화면의 캐릭터는 부드럽게
## 따라가느라 조금 늦으므로, 호스트의 거리 판정은 이 값을 쓴다.
func reported_position() -> Vector3:
	return position if is_multiplayer_authority() else net_position


## 든 물건이 놓이는 자리.
func get_carry_transform() -> Transform3D:
	return carry_point.global_transform


func is_carrying() -> bool:
	var world := _world()
	return world != null and world.carry_rules.held_by(get_peer_id()) != null


func _process(delta: float) -> void:
	if is_multiplayer_authority():
		return
	var t := minf(delta * remote_smoothing, 1.0)
	position = position.lerp(net_position, t)
	rotation.y = lerp_angle(rotation.y, net_yaw, t)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var data: Resource = Tuning.data
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _camera_yaw_basis() * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	direction = direction.normalized() * minf(input.length(), 1.0)
	dash_cooldown_left = maxf(dash_cooldown_left - delta, 0.0)
	_slip_immunity = maxf(_slip_immunity - delta, 0.0)

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if slide_left > 0.0:
		# 미끄러지는 중: 조작 불가, 정해진 속도로 주욱
		slide_left -= delta
		horizontal = _slide_velocity
		if slide_left <= 0.0:
			_slip_immunity = data.proto_slip_immunity
			_burst_ended = true
	elif _dash_left > 0.0:
		_dash_left -= delta
		horizontal = _dash_dir * (data.player_dash_distance / DASH_TIME)
		_burst_ended = _dash_left <= 0.0
	else:
		if Input.is_action_just_pressed("dash") and dash_cooldown_left <= 0.0:
			_dash_dir = direction.normalized() if direction.length_squared() > 0.01 else -global_basis.z
			_dash_left = DASH_TIME
			dash_cooldown_left = data.player_dash_cooldown
		var speed: float = data.player_carry_speed if is_carrying() else data.player_walk_speed
		if _burst_ended:
			# 대시·미끄러짐이 끝나면 남은 빠른 속도를 버린다 (안 그러면 정해진 거리보다 더 감)
			horizontal = direction * speed
			_burst_ended = false
		else:
			horizontal = horizontal.move_toward(direction * speed, acceleration * delta)
		if direction.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(turn_speed * delta, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	_check_puddles()
	net_position = position
	net_yaw = rotation.y


## 물웅덩이를 밟으면 진행 방향으로 puddle_slide_distance 만큼 puddle_slide_time 동안 미끄러진다.
## 들고 있던 것은 그대로 (TUNING_V2 2.2).
func _check_puddles() -> void:
	if slide_left > 0.0 or _slip_immunity > 0.0:
		return
	var moving := Vector3(velocity.x, 0.0, velocity.z)
	if moving.length() < 0.5:
		return
	for puddle in get_tree().get_nodes_in_group("puddles"):
		var offset: Vector3 = puddle.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= puddle.radius():
			start_slide(moving.normalized())
			return


func start_slide(direction: Vector3) -> void:
	var data: Resource = Tuning.data
	slide_left = data.puddle_slide_time
	_slide_velocity = direction * (data.puddle_slide_distance / data.puddle_slide_time)
	_dash_left = 0.0
	slipped.emit()
	var world := _world()
	if world != null:
		world.get_node("Sfx").play("slip")


## 월드 카메라의 수평 방향 (카메라가 없으면 -Z 가 앞).
func _camera_yaw_basis() -> Basis:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Basis.IDENTITY
	var forward := -camera.global_basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		return Basis.IDENTITY
	return Basis(Vector3.UP, atan2(-forward.x, -forward.z))


## 호스트가 다시 시작할 때 시작 자리로 보낸다 (위치 권한은 본인에게 있으므로 RPC).
@rpc("any_peer", "call_local", "reliable")
func teleport(pos: Vector3, yaw: float) -> void:
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0:
		return
	position = pos
	rotation.y = yaw
	velocity = Vector3.ZERO
	slide_left = 0.0
	_dash_left = 0.0
	net_position = pos
	net_yaw = yaw


func _apply_color() -> void:
	if not is_node_ready():
		return
	var model := model_pivot.get_node_or_null("Model")
	if model != null and model.has_method("set_player_color"):
		model.set_player_color(PLAYER_COLORS[slot % PLAYER_COLORS.size()])


func _world() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null and scene.has_method("get_player") else null
