extends Node3D
## 가게 월드 (멍냥 목욕탕 첫 시제품, GDD_V2 4장): 방 하나, 고정 카메라, 욕조·드라이어, 손님.
##
## 호스트(혼자 하기 포함)가 플레이어를 스폰·제거하고 MultiplayerSpawner 가 복제한다.
## 스폰은 spawn_function + 스폰 데이터로 한다. 플레이어 노드의 권한은 조종하는
## 클라이언트에게 있어서 Synchronizer 의 "spawn" 속성은 서버가 보내 주지 않는다.
## 영업 규칙은 Shop, 들기·내려놓기는 CarryRules, 화면은 HUD. 이 스크립트는 내 입력을 요청으로 바꾼다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
## 방 안쪽 바닥 (벽 두께 + 몸 반지름을 뺀 범위, m). 방은 16 × 12 m.
const FLOOR_HALF := Vector2(7.3, 5.3)
## 기계 주변에서 손님이 피하는 여유 (m)
const MACHINE_MARGIN := Vector2(1.1, 0.85)

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var spawn_points: Node3D = $SpawnPoints
@onready var carry_rules: Node = $CarryRules
@onready var shop: Node = $Shop
@onready var sfx: Node = $Sfx
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	spawner.spawn_function = _create_player
	Net.player_joined.connect(_spawn_player)
	Net.player_left.connect(_remove_player)
	if Net.is_host():
		_spawn_player(1)
		for peer_id in multiplayer.get_peers():
			_spawn_player(peer_id)
		shop.reset_round()


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_paused():
		return
	var me := get_local_player()
	if me == null:
		return
	if event.is_action_pressed("interact") and shop.is_open():
		# Space 하나로 들기·내려놓기·기계에 넣기·꺼내기·보내기 (무엇을 할지는 호스트가 정함)
		shop.send_use()


func get_player(peer_id: int) -> Node3D:
	return players.get_node_or_null(str(peer_id))


func get_players() -> Array:
	return players.get_children()


func get_local_player() -> Node3D:
	return get_player(multiplayer.get_unique_id())


## 방 안쪽 바닥으로 자른 위치.
func clamp_to_floor(pos: Vector3) -> Vector3:
	return Vector3(clampf(pos.x, -FLOOR_HALF.x, FLOOR_HALF.x), pos.y, clampf(pos.z, -FLOOR_HALF.y, FLOOR_HALF.y))


## 기계가 놓인 자리인가 (도망가는 손님이 기계를 뚫고 지나가지 않게).
func is_blocked(pos: Vector3) -> bool:
	for machine in shop.machines():
		var offset: Vector3 = pos - machine.global_position
		if absf(offset.x) < MACHINE_MARGIN.x and absf(offset.z) < MACHINE_MARGIN.y:
			return true
	return false


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
