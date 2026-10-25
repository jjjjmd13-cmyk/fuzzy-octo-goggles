extends CharacterBody3D
## 플레이어 (1인칭, GDD 2장).
##
## 노드 이름 = 조종하는 피어 ID. 동기화는 두 갈래다:
## - ClientSync (권한: 조종하는 피어): 위치·시선·손등 켬/끔. 클라이언트 권한 이동.
## - HostSync (권한: 호스트): 쓰러짐·기절·어둠 게이지·부활 진행. 판정은 호스트만 한다 (GDD 12장).
## 겉모습은 ModelPivot/Model 씬(scenes/art/player_model.tscn)에만 있다. 내 화면에서는 숨긴다.

signal downed_changed(is_downed: bool)

const PLAYER_COLORS: Array[Color] = [
	Color(0.95, 0.55, 0.2), Color(0.3, 0.65, 0.95), Color(0.45, 0.85, 0.4), Color(0.9, 0.4, 0.75),
]
const EYE_HEIGHT := 1.6
const DOWNED_EYE_HEIGHT := 0.5

@export var acceleration := 30.0
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 3.0
@export var min_pitch_deg := -85.0
@export var max_pitch_deg := 85.0
@export var remote_smoothing := 15.0

## 플레이어 번호(0부터, 빈 자리 순서). 호스트가 정해 스폰 데이터로 보낸다. 색 고르기에 쓴다.
@export var slot := 0:
	set(value):
		slot = value
		_apply_color()

# --- ClientSync (조종하는 피어가 씀)
var net_position := Vector3.ZERO
var net_yaw := 0.0
var net_pitch := 0.0
## 손등 스위치. 실제로 켜지는지는 is_handlamp_lit() (등불을 들거나 쓰러지거나 기름이 없으면 꺼짐).
var handlamp_on := true

# --- HostSync (호스트가 씀)
var downed := false:
	set(value):
		if downed != value:
			downed = value
			downed_changed.emit(value)
var knocked_out := false
var down_time_left := 0.0
var dark := 0.0
var revive_progress := 0.0

var stamina := 0.0
var _stamina_rest := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var model_pivot: Node3D = $ModelPivot
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hand: Node3D = $Head/Hand
@onready var handlamp_light: OmniLight3D = $Head/Hand/HandlampLight
@onready var client_sync: MultiplayerSynchronizer = $ClientSync
@onready var host_sync: MultiplayerSynchronizer = $HostSync


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
	$HostSync.set_multiplayer_authority(1)


func _ready() -> void:
	add_to_group("players")
	_apply_color()
	stamina = Tuning.data.player_stamina
	net_position = position
	net_yaw = rotation.y
	var is_local := is_multiplayer_authority()
	camera.current = is_local
	model_pivot.visible = not is_local
	set_process_unhandled_input(is_local)
	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	handlamp_light.omni_range = Tuning.data.light_handlamp_radius * 1.3


func get_peer_id() -> int:
	return name.to_int()


func is_active() -> bool:
	return not downed and not knocked_out


## 손등이 실제로 빛을 내는가. 모든 피어가 같은 동기화 값으로 같은 답을 낸다.
func is_handlamp_lit() -> bool:
	var world := _world()
	if world == null or not handlamp_on or not is_active():
		return false
	return world.oil_tank.has_oil() and world.lantern.holder_peer != get_peer_id()


## 들고 있는 물건이 붙는 자리 (등불).
func get_hand_position() -> Vector3:
	return hand.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)
	elif event.is_action_pressed("handlamp_toggle"):
		handlamp_on = not handlamp_on


func _process(delta: float) -> void:
	handlamp_light.visible = is_handlamp_lit()
	var eye := DOWNED_EYE_HEIGHT if not is_active() else EYE_HEIGHT
	head.position.y = lerpf(head.position.y, eye, minf(delta * 8.0, 1.0))
	model_pivot.rotation.x = lerpf(model_pivot.rotation.x, -PI * 0.5 if not is_active() else 0.0, minf(delta * 8.0, 1.0))
	if not is_multiplayer_authority():
		var t := minf(delta * remote_smoothing, 1.0)
		position = position.lerp(net_position, t)
		rotation.y = lerp_angle(rotation.y, net_yaw, t)
		head.rotation.x = lerp_angle(head.rotation.x, net_pitch, t)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look != Vector2.ZERO:
		_look(-look.x * stick_sensitivity * delta, -look.y * stick_sensitivity * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := global_basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	direction = direction.normalized() * minf(input.length(), 1.0)
	var speed := _update_speed(delta, direction.length_squared() > 0.01)
	if knocked_out:
		speed = 0.0

	var target := direction * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	net_position = position
	net_yaw = rotation.y
	net_pitch = head.rotation.x


## 걷기/달리기/기어가기 속도와 스태미나 (TUNING 4장).
func _update_speed(delta: float, moving: bool) -> float:
	var data: Resource = Tuning.data
	if downed:
		return data.down_crawl_speed
	var running := moving and Input.is_action_pressed("run") and stamina > 0.0
	if running:
		stamina = maxf(stamina - delta, 0.0)
		_stamina_rest = 0.0
		return data.player_run_speed
	_stamina_rest += delta
	if _stamina_rest >= data.player_stamina_regen_delay:
		stamina = minf(stamina + data.player_stamina_regen_rate * delta, data.player_stamina)
	return data.player_walk_speed


func _look(yaw: float, pitch: float) -> void:
	rotate_y(yaw)
	head.rotation.x = clampf(head.rotation.x + pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


## 호스트가 다시 시작할 때 각 플레이어를 시작 자리로 보낸다 (위치 권한은 본인에게 있으므로 RPC).
@rpc("any_peer", "call_local", "reliable")
func teleport(pos: Vector3, yaw: float) -> void:
	if multiplayer.get_remote_sender_id() != 1 and multiplayer.get_remote_sender_id() != 0:
		return
	position = pos
	rotation.y = yaw
	velocity = Vector3.ZERO
	net_position = pos
	net_yaw = yaw
	stamina = Tuning.data.player_stamina


func _apply_color() -> void:
	if not is_node_ready():
		return
	var model := model_pivot.get_node_or_null("Model")
	if model != null and model.has_method("set_player_color"):
		model.set_player_color(PLAYER_COLORS[slot % PLAYER_COLORS.size()])


func _world() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null and scene.has_method("get_player") else null
