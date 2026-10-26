extends Node
## 들기·놓기·건네기 규칙 (호스트 권한).
##
## 클라이언트는 send_request() 로 "하고 싶다"만 보낸다. 호스트가 거리·빈손 여부를 보고 판정해
## Carryable.holder_peer 를 바꾸면 모든 피어에 퍼진다. 같은 물건을 두 사람이 동시에 집으려 해도
## 호스트가 차례로 처리하므로 한 사람만 든다. 물건은 월드 기준 경로(문자열)로 가리킨다.

const ACT_PICKUP := "pickup"
const ACT_DROP := "drop"
const ACT_GIVE := "give"

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


## 이 플레이어가 지금 집을 수 있는 가장 가까운 물건 (없으면 null). HUD 안내도 같은 판정을 쓴다.
func pickup_candidate(player: Node3D) -> Node3D:
	if held_by(player.get_peer_id()) != null:
		return null
	var best: Node3D = null
	var best_distance: float = Tuning.data.carry_pickup_range
	for item in carryables():
		if item.is_held():
			continue
		var distance := horizontal_distance(player.reported_position(), item.global_position)
		if distance <= best_distance:
			best = item
			best_distance = distance
	return best


## 건네받을 동료: give_range 안의 가장 가까운 빈손 플레이어.
func give_target(player: Node3D) -> Node3D:
	var best: Node3D = null
	var best_distance: float = Tuning.data.carry_give_range
	for other in world.get_players():
		if other == player or held_by(other.get_peer_id()) != null:
			continue
		var distance := horizontal_distance(player.reported_position(), other.reported_position())
		if distance <= best_distance:
			best = other
			best_distance = distance
	return best


## 클라이언트·호스트 공용 입구. 호스트는 바로 처리하고, 클라이언트는 호스트로 보낸다.
func send_request(action: String, item: Node = null) -> void:
	var item_path := String(world.get_path_to(item)) if item != null else ""
	if Net.is_host():
		_handle(multiplayer.get_unique_id(), action, item_path)
	else:
		request.rpc_id(1, action, item_path)


@rpc("any_peer", "reliable")
func request(action: String, item_path: String) -> void:
	if Net.is_host():
		_handle(multiplayer.get_remote_sender_id(), action, item_path)


func _handle(sender: int, action: String, item_path: String) -> void:
	var player: Node3D = world.get_player(sender)
	if player == null:
		return
	var held := held_by(sender)
	match action:
		ACT_PICKUP:
			var item := _find_item(item_path)
			if item == null or item.is_held() or held != null:
				return
			if horizontal_distance(player.reported_position(), item.global_position) <= Tuning.data.carry_pickup_range:
				item.holder_peer = sender
		ACT_DROP:
			if held != null:
				drop(held, player)
		ACT_GIVE:
			var other := give_target(player)
			if held != null and other != null:
				held.holder_peer = other.get_peer_id()


## 호스트 전용: 든 사람 앞 바닥에 내려놓는다. 플레이어가 나갈 때도 쓴다.
func drop(item: Node3D, player: Node3D) -> void:
	var yaw: float = player.net_yaw  # 조종하는 피어가 보낸 방향 (화면에 그려진 방향은 조금 늦음)
	var forward := -Basis(Vector3.UP, yaw).z
	var pos: Vector3 = player.reported_position()
	var floor_y := pos.y
	if forward.length() > 0.01:
		pos += forward.normalized() * Tuning.data.carry_drop_distance
	item.ground_position = Vector3(pos.x, floor_y, pos.z)
	item.ground_yaw = yaw
	item.holder_peer = 0


func _find_item(item_path: String) -> Node3D:
	if item_path.is_empty():
		return null
	var item := world.get_node_or_null(NodePath(item_path))
	return item if item != null and item.is_in_group("carryables") else null
