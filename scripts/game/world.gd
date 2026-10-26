extends Node3D
## 가게 월드 (멍냥 목욕탕 시제품 뼈대): 방 하나, 고정 카메라, 들 수 있는 물건.
##
## 호스트(혼자 하기 포함)가 플레이어를 스폰·제거하고 MultiplayerSpawner 가 복제한다.
## 스폰은 spawn_function + 스폰 데이터로 한다. 플레이어 노드의 권한은 조종하는
## 클라이언트에게 있어서 Synchronizer 의 "spawn" 속성은 서버가 보내 주지 않는다.
## 들기 규칙은 CarryRules, 화면은 HUD. 이 스크립트는 내 입력을 요청으로 바꾼다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var spawn_points: Node3D = $SpawnPoints
@onready var carry_rules: Node = $CarryRules
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	spawner.spawn_function = _create_player
	Net.player_joined.connect(_spawn_player)
	Net.player_left.connect(_remove_player)
	if Net.is_host():
		_spawn_player(1)
		for peer_id in multiplayer.get_peers():
			_spawn_player(peer_id)


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_paused():
		return
	var me := get_local_player()
	if me == null:
		return
	if event.is_action_pressed("interact"):
		# E: 빈손이면 가장 가까운 물건 들기, 들고 있으면 내려놓기 (오버쿡드식 한 버튼)
		if carry_rules.held_by(me.get_peer_id()) != null:
			carry_rules.send_request(carry_rules.ACT_DROP)
		else:
			var item: Node = carry_rules.pickup_candidate(me)
			if item != null:
				carry_rules.send_request(carry_rules.ACT_PICKUP, item)
	elif event.is_action_pressed("carry_drop"):
		carry_rules.send_request(carry_rules.ACT_DROP)
	elif event.is_action_pressed("carry_give"):
		carry_rules.send_request(carry_rules.ACT_GIVE)


func get_player(peer_id: int) -> Node3D:
	return players.get_node_or_null(str(peer_id))


func get_players() -> Array:
	return players.get_children()


func get_local_player() -> Node3D:
	return get_player(multiplayer.get_unique_id())


func get_spawn_marker(slot: int) -> Node3D:
	return spawn_points.get_child(slot % spawn_points.get_child_count())


func _spawn_player(peer_id: int) -> void:
	if not Net.is_host() or get_player(peer_id) != null:
		return
	var slot := _free_slot()
	var marker := get_spawn_marker(slot)
	spawner.spawn({"peer_id": peer_id, "slot": slot, "position": marker.position, "yaw": marker.rotation.y})


## 모든 피어에서 같은 스폰 데이터로 실행된다. 노드를 붙이는 건 MultiplayerSpawner 가 한다.
func _create_player(data: Dictionary) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(data.peer_id)
	player.slot = data.slot
	player.position = data.position
	player.rotation.y = data.get("yaw", 0.0)
	return player


## 나간 사람이 들고 있던 물건은 그 자리에 떨어진다.
func _remove_player(peer_id: int) -> void:
	if not Net.is_host():
		return
	var player := get_player(peer_id)
	if player == null:
		return
	var held: Node3D = carry_rules.held_by(peer_id)
	if held != null:
		carry_rules.drop(held, player)
	player.queue_free()


func _free_slot() -> int:
	var used := {}
	for player in players.get_children():
		used[player.slot] = true
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot
