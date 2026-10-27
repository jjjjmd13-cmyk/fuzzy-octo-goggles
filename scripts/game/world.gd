extends Node3D
## 가게 월드 (멍냥 목욕탕 V3 시제품 1, 손맛): 목욕대 자리와 컴퓨터 자리 두 곳.
##
## 호스트(혼자 하기 포함)가 플레이어를 스폰·제거하고 MultiplayerSpawner 가 복제한다.
## 스폰은 spawn_function + 스폰 데이터로 한다. 플레이어 노드의 권한은 조종하는
## 클라이언트에게 있어서 Synchronizer 의 "spawn" 속성은 서버가 보내 주지 않는다.
## 씻기 규칙은 WashStation, 하루 영업(시계·손님·대기열)은 Day, 돈·샴푸는 Store, 화면은 HUD. 이 스크립트는 내 입력과 카메라를 맡는다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const Player := preload("res://scripts/player/player.gd")
const WashStation := preload("res://scripts/sim/wash_station.gd")
## 회전판 화살표를 누를 수 있는 거리 (px)
const ARROW_PICK_PIXELS := 40.0

## 내 커서 (화면 좌표). 마우스를 움직이면 마우스 위치, 패드면 왼쪽 스틱으로 움직인다.
var cursor := Vector2(640, 400)

## false 면 내 입력으로 목욕대를 움직이지 않는다 (테스트가 손동작을 직접 넣을 때)
var input_enabled := true

var _pressed := false
var _seat_shown := -1

@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $PlayerSpawner
@onready var spawn_points: Node3D = $SpawnPoints
@onready var station: WashStation = $WashStation
@onready var store: Node = $Store
@onready var day: Node = $Day
@onready var sfx: Node = $Sfx
@onready var hud: CanvasLayer = $HUD
@onready var camera: Camera3D = $Camera
@onready var computer_point: Marker3D = $Computer/CameraPoint


func _ready() -> void:
	spawner.spawn_function = _create_player
	Net.player_joined.connect(_spawn_player)
	Net.player_left.connect(_remove_player)
	computer_point.look_at($Computer/LookTarget.global_position)
	station.camera = camera
	station.store = store
	station.sfx = sfx
	station.day = day
	station.waiting_area.day = day
	day.station = station
	day.sfx = sfx
	day.store = store
	camera.fov = Tuning.data.seat_camera_fov
	camera.global_transform = station.camera_point.global_transform
	cursor = get_viewport().get_visible_rect().size / 2.0
	if Net.is_host():
		_spawn_player(1)
		for peer_id in multiplayer.get_peers():
			_spawn_player(peer_id)
		store.reset()
		station.reset()
		day.start_day(1)


func get_player(peer_id: int) -> Node3D:
	return players.get_node_or_null(str(peer_id))


func get_players() -> Array:
	return players.get_children()


func get_local_player() -> Node3D:
	return get_player(multiplayer.get_unique_id())


## 내 자리 (플레이어가 아직 없으면 목욕대)
func local_seat() -> int:
	var me := get_local_player()
	return me.seat if me != null else Player.Seat.BATH


func switch_seat() -> void:
	var me := get_local_player()
	if me != null:
		me.set_seat(Player.Seat.COMPUTER if me.seat == Player.Seat.BATH else Player.Seat.BATH)


## 도구걸이 클릭으로 직접 바꾸기 (보통은 단계마다 저절로 바뀜)
func select_tool(index: int) -> void:
	station.tool = posmod(index, WashStation.TOOL_NAMES.size()) as WashStation.Tool


## 이 화면 위치가 회전판 화살표면 -1(왼쪽)/+1(오른쪽), 아니면 0
func arrow_at(pos: Vector2) -> int:
	var points := station.turn_arrow_points()
	for i in points.size():
		if points[i].distance_to(pos) <= ARROW_PICK_PIXELS:
			return -1 if i == 0 else 1
	return 0


func get_spawn_marker(slot: int) -> Node3D:
	return spawn_points.get_child(slot % spawn_points.get_child_count())


func _unhandled_input(event: InputEvent) -> void:
	if hud.is_paused() or hud.is_menu_open():
		return
	if event is InputEventMouseMotion:
		cursor = event.position
		return
	if event is InputEventMouseButton and event.pressed:
		cursor = event.position
	if event.is_action_pressed("switch_seat"):
		switch_seat()
	elif local_seat() != Player.Seat.BATH:
		return
	elif event.is_action_pressed("use_tool"):
		# 마우스 하나: 동전 → 회전판 화살표 → 도구 쓰기 순서로 본다
		var coin := station.coin_at(cursor)
		var arrow := arrow_at(cursor)
		if coin >= 0:
			station.send_collect(coin)
		elif arrow != 0:
			station.turn_step(arrow)
		else:
			_pressed = true
	elif event.is_action_pressed("amount_up"):
		station.adjust(1)
	elif event.is_action_pressed("amount_down"):
		station.adjust(-1)


func _process(delta: float) -> void:
	var data: Resource = Tuning.data
	var seat := local_seat()
	if seat != _seat_shown:
		_show_seat(seat)
	var at_bath: bool = seat == Player.Seat.BATH and not hud.is_paused() and not hud.is_menu_open()
	if at_bath:
		var stick := Input.get_vector("cursor_left", "cursor_right", "cursor_up", "cursor_down")
		if stick.length_squared() > 0.0:
			cursor = (cursor + stick * data.pad_cursor_speed * delta).clamp(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var held: bool = at_bath and Input.is_action_pressed("use_tool") and not _arrow_or_coin_held()
	if input_enabled:
		station.operate(cursor, held, _pressed and at_bath, delta)
	_pressed = false


## 동전·화살표를 누른 채면 도구를 쓰지 않는다
func _arrow_or_coin_held() -> bool:
	return station.coin_at(cursor) >= 0 or arrow_at(cursor) != 0


## 자리 바꾸기: 카메라가 seat_switch_time 동안 옮겨 간다 (완료 조건 1).
func _show_seat(seat: int) -> void:
	var first := _seat_shown < 0
	_seat_shown = seat
	var target: Transform3D = station.camera_point.global_transform if seat == Player.Seat.BATH else computer_point.global_transform
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if seat == Player.Seat.BATH else Input.MOUSE_MODE_VISIBLE
	if first:
		camera.global_transform = target
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_transform", target, Tuning.data.seat_switch_time)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
