extends Node3D
## 게임 월드. 호스트(혼자 하기 포함)가 플레이어를 스폰·제거하고,
## MultiplayerSpawner 가 그 결과를 클라이언트에 복제한다.
##
## 스폰은 spawn_function + 스폰 데이터로 한다. 플레이어 노드의 권한은 조종하는
## 클라이언트에게 있어서, MultiplayerSynchronizer 의 "spawn" 속성은 서버가 보내 주지
## 않는다 (클라이언트 쪽 내 캐릭터가 원점에 생김). 시작 위치·슬롯은 스폰 데이터로 보낸다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var spawn_points: Node3D = $SpawnPoints
@onready var status_label: Label = $HUD/Status
@onready var invite_button: Button = $HUD/InviteButton
@onready var pause_menu: Control = $HUD/PauseMenu


func _ready() -> void:
	spawner.spawn_function = _create_player
	Net.player_joined.connect(_spawn_player)
	Net.player_left.connect(_remove_player)
	Net.status_changed.connect(_on_status_changed)
	Net.session_started.connect(_refresh_hud)
	players.child_entered_tree.connect(_refresh_hud.unbind(1))
	players.child_exiting_tree.connect(_refresh_hud.unbind(1))
	$HUD/PauseMenu/Box/Resume.pressed.connect(_set_paused.bind(false))
	$HUD/PauseMenu/Box/Leave.pressed.connect(Net.leave_session)
	invite_button.pressed.connect(Net.invite_friends)
	pause_menu.hide()

	if Net.is_host():
		_spawn_player(1)
		for peer_id in multiplayer.get_peers():
			_spawn_player(peer_id)
	_on_status_changed(Net.status_text)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		_set_paused(not pause_menu.visible)


func get_player(peer_id: int) -> Node3D:
	return players.get_node_or_null(str(peer_id))


func _spawn_player(peer_id: int) -> void:
	if not Net.is_host() or get_player(peer_id) != null:
		return
	var slot := _free_slot()
	var marker := spawn_points.get_child(slot % spawn_points.get_child_count()) as Node3D
	spawner.spawn({"peer_id": peer_id, "slot": slot, "position": marker.position})


## 모든 피어에서 같은 스폰 데이터로 실행된다. 노드를 붙이는 건 MultiplayerSpawner 가 한다.
func _create_player(data: Dictionary) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(data.peer_id)
	player.slot = data.slot
	player.position = data.position
	return player


func _remove_player(peer_id: int) -> void:
	if not Net.is_host():
		return
	var player := get_player(peer_id)
	if player != null:
		player.queue_free()


func _free_slot() -> int:
	var used := {}
	for player in players.get_children():
		used[player.slot] = true
	var slot := 0
	while used.has(slot):
		slot += 1
	return slot


func _set_paused(paused: bool) -> void:
	# 온라인 게임이라 시간은 멈추지 않는다. 메뉴만 띄우고 마우스를 풀어 준다.
	pause_menu.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _on_status_changed(_text: String) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	if not is_node_ready():
		return
	status_label.text = "%s\n플레이어 %d / %d" % [Net.status_text, players.get_child_count(), Net.MAX_PLAYERS]
	invite_button.visible = Net.can_invite_friends()
