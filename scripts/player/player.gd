extends CharacterBody3D
## 플레이어 (3인칭 이동·점프·카메라).
##
## 노드 이름 = 조종하는 피어 ID. 각 플레이어는 자기 캐릭터의 권한을 갖고 직접 움직이며
## MultiplayerSynchronizer 가 위치·방향을 다른 피어에게 보낸다 (협동 게임이라
## 클라이언트 권한 이동으로 단순하게 감). 겉모습은 ModelPivot/Model 씬
## (scenes/art/player_model.tscn) 에만 있다.

const PLAYER_COLORS: Array[Color] = [
	Color(0.95, 0.55, 0.2), Color(0.3, 0.65, 0.95), Color(0.45, 0.85, 0.4), Color(0.9, 0.4, 0.75),
]

@export var move_speed := 5.0
@export var acceleration := 30.0
@export var jump_velocity := 4.8
@export var turn_speed := 12.0
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 3.0
@export var min_pitch_deg := -70.0
@export var max_pitch_deg := 35.0

## 플레이어 번호(0부터, 빈 자리 순서). 호스트가 정해 스폰 데이터로 보낸다. 색 고르기에 쓴다.
@export var slot := 0:
	set(value):
		slot = value
		_apply_color()

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var model_pivot: Node3D = $ModelPivot
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	_apply_color()
	var is_local := is_multiplayer_authority()
	camera.current = is_local
	spring_arm.add_excluded_object(get_rid())
	set_physics_process(is_local)
	set_process_unhandled_input(is_local)
	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)


func _physics_process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_rotate_camera(-look.x * stick_sensitivity * delta, -look.y * stick_sensitivity * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := camera_pivot.global_basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	direction = direction.normalized() * minf(input.length(), 1.0)

	var target := direction * move_speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	if direction.length_squared() > 0.01:
		var yaw := atan2(-direction.x, -direction.z)
		model_pivot.rotation.y = lerp_angle(model_pivot.rotation.y, yaw, minf(turn_speed * delta, 1.0))


func _rotate_camera(yaw: float, pitch: float) -> void:
	camera_pivot.rotate_y(yaw)
	spring_arm.rotation.x = clampf(
		spring_arm.rotation.x + pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg)
	)


func _apply_color() -> void:
	if not is_node_ready():
		return
	var model := model_pivot.get_node_or_null("Model")
	if model != null and model.has_method("set_player_color"):
		model.set_player_color(PLAYER_COLORS[slot % PLAYER_COLORS.size()])
