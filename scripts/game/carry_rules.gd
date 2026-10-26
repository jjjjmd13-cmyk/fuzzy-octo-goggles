extends Node
## 들기·내려놓기 기본 규칙 (호스트 권한). 무엇을 할지(들기/기계에 넣기/보내기)는 Shop 이 정하고,
## 실제로 들고 놓는 것은 여기서 한다.
##
## 판정은 수평 거리 + 앞쪽 부채꼴(TUNING_V2 player_interact_range, proto_interact_half_angle).
## 거리는 화면에 그려진 위치가 아니라 각 플레이어가 마지막으로 보낸 위치(reported_position)로 잰다.

@onready var world: Node = get_parent()


## 수평 거리만 본다 (들고 있는 물건 높이와 상관없이).
static func horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func carryables() -> Array:
	return get_tree().get_nodes_in_group("carryables").filter(func(item: Node) -> bool: return world.is_ancestor_of(item))


## 이 피어가 들고 있는 물건 (없으면 null).
func held_by(peer_id: int) -> Node3D:
	for item in carryables():
		if item.holder_peer == peer_id:
			return item
	return null


## 플레이어 앞쪽 부채꼴 안에 있는가 (아주 가까우면 방향 상관없음).
func in_front(player: Node3D, pos: Vector3, max_range: float) -> bool:
	var from: Vector3 = player.reported_position()
	var distance := horizontal_distance(from, pos)
	if distance > max_range:
		return false
	if distance < 0.5:
		return true
	var to := Vector2(pos.x - from.x, pos.z - from.z).normalized()
	var facing := Vector2(-sin(player.net_yaw), -cos(player.net_yaw))
	return rad_to_deg(facing.angle_to(to)) <= Tuning.data.proto_interact_half_angle \
		and rad_to_deg(facing.angle_to(to)) >= -Tuning.data.proto_interact_half_angle


## 이 플레이어가 지금 집을 수 있는 가장 가까운 물건 (없으면 null). 화면 안내도 같은 판정을 쓴다.
func pickup_candidate(player: Node3D) -> Node3D:
	if held_by(player.get_peer_id()) != null:
		return null
	var best: Node3D = null
	var best_distance := INF
	var reach: float = Tuning.data.player_interact_range
	for item in carryables():
		if not item.can_be_picked():
			continue
		var pos: Vector3 = item.floor_position()
		if not in_front(player, pos, reach):
			continue
		var distance := horizontal_distance(player.reported_position(), pos)
		if distance < best_distance:
			best = item
			best_distance = distance
	return best


## 호스트 전용.
func pick_up(item: Node3D, player: Node3D) -> void:
	item.holder_peer = player.get_peer_id()
	item.on_picked(player.get_peer_id())


## 호스트 전용: 든 사람 앞 바닥에 내려놓는다. 플레이어가 나갈 때도 쓴다.
func drop(item: Node3D, player: Node3D) -> void:
	var yaw: float = player.net_yaw  # 조종하는 피어가 보낸 방향 (화면에 그려진 방향은 조금 늦음)
	var pos: Vector3 = player.reported_position() - Basis(Vector3.UP, yaw).z * Tuning.data.proto_drop_distance
	if world.has_method("clamp_to_floor"):
		pos = world.clamp_to_floor(pos)
	item.ground_position = Vector3(pos.x, 0.0, pos.z)
	item.ground_yaw = yaw
	item.holder_peer = 0
	item.on_dropped()
