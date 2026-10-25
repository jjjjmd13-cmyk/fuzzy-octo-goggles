extends Node3D
## 시제품 월드 (GDD 13장): 손으로 배치한 방 3개, 큰 등불 1개, 기름병, 그림자 추적자 1마리.
##
## 호스트(혼자 하기 포함)가 플레이어를 스폰·제거하고 MultiplayerSpawner 가 복제한다.
## 스폰은 spawn_function + 스폰 데이터로 한다. 플레이어 노드의 권한은 조종하는
## 클라이언트에게 있어서 Synchronizer 의 "spawn" 속성은 서버가 보내 주지 않는다.
## 게임 규칙은 Expedition 노드, 화면은 HUD 가 맡는다. 이 스크립트는 내 입력을 요청으로 바꾼다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var spawn_points: Node3D = $SpawnPoints
@onready var expedition: Node = $Expedition
@onready var oil_tank: Node = $OilTank
@onready var lantern: Node3D = $Lantern
@onready var stalker: CharacterBody3D = $Stalker
@onready var bottles: Node3D = $Bottles
@onready var hud: CanvasLayer = $HUD
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	spawner.spawn_function = _create_player
	Net.player_joined.connect(_spawn_player)
	Net.player_left.connect(_remove_player)

	if Net.is_host():
		# 추적자 길찾기는 호스트만 하므로 길 그물(navmesh)도 호스트에서만 굽는다.
		nav_region.bake_navigation_mesh(false)
		_spawn_player(1)
		for peer_id in multiplayer.get_peers():
			_spawn_player(peer_id)
		expedition.reset_round()


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_paused():
		return
	var me := get_local_player()
	if me == null:
		return
	if event.is_action_pressed("interact"):
		_interact(me)
	elif event.is_action_released("interact"):
		expedition.send_request(expedition.ACT_REVIVE_STOP)
	elif event.is_action_pressed("lantern_drop"):
		expedition.send_request(expedition.ACT_DROP_LANTERN)
	elif event.is_action_pressed("lantern_give"):
		expedition.send_request(expedition.ACT_GIVE_LANTERN)
	elif event.is_action_pressed("lantern_brighter"):
		expedition.send_request(expedition.ACT_LANTERN_LEVEL, 1)
	elif event.is_action_pressed("lantern_dimmer"):
		expedition.send_request(expedition.ACT_LANTERN_LEVEL, -1)
	elif event.is_action_pressed("debug_restart_low_oil"):
		expedition.send_request(expedition.ACT_DEBUG_RESTART, int(Tuning.data.proto_debug_oil_start))
	elif event.is_action_pressed("debug_restart"):
		expedition.send_request(expedition.ACT_DEBUG_RESTART, -1)
	elif event.is_action_pressed("debug_down_self"):
		expedition.send_request(expedition.ACT_DEBUG_DOWN_SELF)


## E 를 눌렀을 때 할 일. HUD 안내 문구와 같은 순서: 부활 → 등불 줍기 → 기름병.
func _interact(me: Node) -> void:
	var action := interact_target(me)
	match action.get("kind", ""):
		"revive":
			expedition.send_request(expedition.ACT_REVIVE_START, action.target)
		"lantern":
			expedition.send_request(expedition.ACT_PICKUP_LANTERN)
		"bottle":
			expedition.send_request(expedition.ACT_PICKUP_BOTTLE, action.target)


## 지금 E 로 할 수 있는 일 {kind, target}. 없으면 빈 딕셔너리.
func interact_target(me: Node) -> Dictionary:
	if not me.is_active():
		return {}
	var reach: float = Tuning.data.proto_interact_range
	var downed := nearest_player(me.global_position, reach, me, true)
	if downed != null:
		return {"kind": "revive", "target": downed.get_peer_id(), "lit": expedition.is_in_big_light(downed.global_position)}
	if lantern.holder_peer == 0 and expedition.horizontal_distance(me.global_position, lantern.ground_position) <= reach:
		return {"kind": "lantern"}
	for i in bottles.get_child_count():
		var bottle: Node3D = bottles.get_child(i)
		if not bottle.taken and me.global_position.distance_to(bottle.global_position) <= reach:
			return {"kind": "bottle", "target": i}
	return {}


func get_player(peer_id: int) -> Node3D:
	return players.get_node_or_null(str(peer_id))


func get_players() -> Array:
	return players.get_children()


func get_local_player() -> Node3D:
	return get_player(multiplayer.get_unique_id())


func get_bottle(index: int) -> Node3D:
	return bottles.get_child(index) if index >= 0 and index < bottles.get_child_count() else null


func get_spawn_marker(slot: int) -> Node3D:
	return spawn_points.get_child(slot % spawn_points.get_child_count())


## range 안의 가장 가까운 다른 플레이어. downed_only 면 부활시킬 수 있는(쓰러짐, 기절 아님) 사람만.
func nearest_player(pos: Vector3, max_range: float, exclude: Node, downed_only := false) -> Node3D:
	var best: Node3D = null
	var best_distance := max_range
	for player in get_players():
		if player == exclude:
			continue
		if downed_only and (not player.downed or player.knocked_out):
			continue
		if not downed_only and not player.is_active():
			continue
		var distance := pos.distance_to(player.global_position)
		if distance <= best_distance:
			best = player
			best_distance = distance
	return best


func _spawn_player(peer_id: int) -> void:
	if not Net.is_host() or get_player(peer_id) != null:
		return
	var slot := _free_slot()
	var marker := get_spawn_marker(slot)
	spawner.spawn({"peer_id": peer_id, "slot": slot, "position": marker.position, "yaw": marker.rotation.y})
	# 시제품은 로비가 없으므로 동료가 들어오면 그 인원 수치(TUNING 7장)로 판을 다시 시작한다.
	if peer_id != 1 and is_node_ready():
		expedition.reset_round()


## 모든 피어에서 같은 스폰 데이터로 실행된다. 노드를 붙이는 건 MultiplayerSpawner 가 한다.
func _create_player(data: Dictionary) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(data.peer_id)
	player.slot = data.slot
	player.position = data.position
	player.rotation.y = data.get("yaw", 0.0)
	return player


func _remove_player(peer_id: int) -> void:
	if not Net.is_host():
		return
	var player := get_player(peer_id)
	if player == null:
		return
	if lantern.holder_peer == peer_id:
		lantern.ground_position = player.global_position
		lantern.holder_peer = 0
	player.queue_free()


func _free_slot() -> int:
	var used := {}
	for player in players.get_children():
		used[player.slot] = true
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot
