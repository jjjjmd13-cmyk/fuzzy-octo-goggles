extends Node3D
## 큰 등불 (팀에 1개, GDD 5.1). 누가 들고 있는지·밝기 단계·바닥 위치는 호스트가 정한다.
## 들고 있으면 각 피어가 그 플레이어의 손 위치에 붙여 그린다 (노드를 옮기지 않음).
## 바닥의 빛 원(Ring)이 게임 판정 반경 그대로다 (수평 거리 ≤ 반경 = 빛 안).

const LEVEL_NAMES := ["낮춤", "보통", "키움"]

## 들고 있는 피어 ID, 0 = 바닥에 있음.
var holder_peer := 0
var level := 1
var ground_position := Vector3.ZERO

var _flicker := 1.0
var _flicker_timer := 0.0

@onready var light: OmniLight3D = $Light
@onready var ring: MeshInstance3D = $Ring
@onready var model: Node3D = $Model


func _ready() -> void:
	ground_position = position
	# 불빛이 모형 안에 있으므로 모형이 자기 그림자를 바닥에 크게 드리우지 않게 한다 (모형을 바꿔도 적용).
	for mesh in model.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func is_big_light() -> bool:
	return _oil().has_oil()


## 낮은 기름(light_low_oil_threshold 이하)에서는 최대 '보통'.
func effective_level() -> int:
	return mini(level, 1) if _oil().is_low() else level


## 지금 빛 반경. 기름이 있으면 단계 반경, 심지 시간이면 심지 반경, 완전한 어둠이면 0.
func light_radius() -> float:
	var oil_tank := _oil()
	if oil_tank.has_oil():
		return Tuning.data.lantern_radius(effective_level())
	if oil_tank.in_wick():
		return Tuning.data.light_wick_radius
	return 0.0


## 빛 판정 중심 (바닥 높이). 들고 있으면 든 사람 발밑.
func light_center() -> Vector3:
	var holder := _holder()
	return holder.global_position if holder != null else ground_position


func level_name() -> String:
	return LEVEL_NAMES[effective_level()]


func _process(delta: float) -> void:
	var holder := _holder()
	if holder != null:
		global_position = holder.get_hand_position()
	else:
		position = position.lerp(ground_position, minf(delta * 15.0, 1.0))
	model.visible = holder == null or not holder.is_multiplayer_authority()

	var radius := light_radius()
	light.visible = radius > 0.0
	light.omni_range = radius * 1.25
	light.light_energy = (0.5 if _oil().in_wick() else 1.6) * _update_flicker(delta)
	var center := light_center()
	ring.visible = radius > 0.0
	ring.global_position = Vector3(center.x, ground_position.y + 0.04, center.z)
	ring.scale = Vector3(maxf(radius, 0.01), 1.0, maxf(radius, 0.01))


## 기름이 적으면 깜빡인다 (GDD 5.3).
func _update_flicker(delta: float) -> float:
	if not _oil().is_low() or not _oil().has_oil():
		return 1.0
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_timer = randf_range(0.05, 0.3)
		_flicker = 0.35 if randf() < 0.25 else randf_range(0.8, 1.0)
	return _flicker


func _holder() -> Node3D:
	if holder_peer == 0:
		return null
	var world := get_tree().current_scene
	return world.get_player(holder_peer) if world != null and world.has_method("get_player") else null


func _oil() -> Node:
	return get_parent().get_node("OilTank")
