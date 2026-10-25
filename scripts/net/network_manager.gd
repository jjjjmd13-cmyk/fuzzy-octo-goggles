extends Node
## 네트워크 세션 관리 (autoload: Net).
##
## 전송 방식(오프라인 / ENet / Steam)을 갈아 끼워도 게임 코드는 이 노드의 신호와
## Godot 고수준 멀티플레이(MultiplayerSpawner/Synchronizer, RPC)만 본다.
## 혼자 하기도 OfflineMultiplayerPeer 를 쓰는 "접속 없는 호스트"라 같은 코드 경로를 탄다.
##
## 순서가 중요하다: 클라이언트는 월드 씬을 먼저 띄운 뒤 접속한다. 서버가 보내는
## 스폰 정보를 받을 MultiplayerSpawner 가 미리 있어야 하기 때문이다.
##
## 입장 확인: 접속은 SceneMultiplayer 인증 단계를 거친다. 호스트가 인원을 세어 "ok" 또는 "full" 을
## 보내고, 클라이언트는 "ok" 를 받아야 접속을 마친다. 방이 가득 차면 클라이언트는 곧바로
## 이유("방이 가득 찼습니다")와 함께 메뉴로 돌아간다 (이슈 #10, QA NET-03).

signal session_started
signal session_ended(reason: String)
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal status_changed(text: String)

enum Mode { NONE, OFFLINE, HOST, CLIENT }

const WORLD_SCENE := "res://scenes/game/world.tscn"
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const MAX_PLAYERS := 4
const DEFAULT_PORT := 24565
const CONNECT_TIMEOUT_SEC := 10.0
const AUTH_OK := "ok"
const AUTH_FULL := "full"

const OfflineTransport := preload("res://scripts/net/transports/offline_transport.gd")
const EnetTransport := preload("res://scripts/net/transports/enet_transport.gd")
const SteamTransport := preload("res://scripts/net/transports/steam_transport.gd")

var mode: Mode = Mode.NONE
var status_text := ""
## 마지막 세션이 끝난 이유. 메뉴가 열릴 때 보여 준다.
var last_end_reason := ""

var _transport: RefCounted = null
var _connected := false
## 세션을 새로 시작하거나 끝낼 때마다 올린다. 진행 중이던 비동기 흐름이 낡았는지 확인용.
var _serial := 0
## 호스트: 입장을 허락했지만 아직 접속이 끝나지 않은 피어 (동시에 여럿이 들어올 때 인원 계산용).
var _admitting := {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var scene_multiplayer := multiplayer as SceneMultiplayer
	scene_multiplayer.auth_callback = _on_auth_data
	scene_multiplayer.peer_authenticating.connect(_on_peer_authenticating)
	scene_multiplayer.peer_authentication_failed.connect(func(peer_id: int) -> void: _admitting.erase(peer_id))
	SteamService.lobby_join_requested.connect(join_steam)


func is_in_session() -> bool:
	return mode != Mode.NONE


## 게임 상태의 주인인가 (혼자 하기 포함). 게임플레이 판정은 여기서 한다.
func is_host() -> bool:
	return mode == Mode.OFFLINE or mode == Mode.HOST


func is_connected_to_session() -> bool:
	return is_host() or _connected


func get_transport_name() -> String:
	return _transport.get_display_name() if _transport != null else ""


func can_invite_friends() -> bool:
	return is_host() and _transport != null and _transport.has_method("invite_friends")


func invite_friends() -> void:
	if can_invite_friends():
		_transport.invite_friends()


func start_offline() -> void:
	_host(OfflineTransport.new(), Mode.OFFLINE)


func host_enet(port: int = DEFAULT_PORT) -> void:
	_host(EnetTransport.new(port, MAX_PLAYERS), Mode.HOST)


func join_enet(address: String, port: int = DEFAULT_PORT) -> void:
	_join(EnetTransport.new(port, MAX_PLAYERS), address)


func host_steam() -> void:
	_host(SteamTransport.new(MAX_PLAYERS), Mode.HOST)


func join_steam(lobby_id: int) -> void:
	_join(SteamTransport.new(MAX_PLAYERS), str(lobby_id))


## 세션을 끝내고 메뉴로 돌아간다. reason 이 있으면 메뉴에 보여 준다.
func leave_session(reason: String = "") -> void:
	_serial += 1
	_reset_connection()
	last_end_reason = reason
	_set_status(reason)
	await _switch_scene(MENU_SCENE)
	session_ended.emit(reason)


func _host(transport: RefCounted, host_mode: Mode) -> void:
	var serial := _begin(transport)
	_set_status("%s 세션을 여는 중..." % transport.get_display_name())
	var peer: MultiplayerPeer = await transport.open_host()
	if serial != _serial:
		return
	if peer == null:
		_fail(transport.error_message)
		return
	mode = host_mode
	# 피어를 먼저 붙이고 월드를 띄운다. 그 사이 들어온 클라이언트는 월드가 _ready 에서
	# multiplayer.get_peers() 로 챙긴다.
	multiplayer.multiplayer_peer = peer
	await _switch_scene(WORLD_SCENE)
	if serial != _serial:
		return
	_set_status("%s 호스트" % transport.get_display_name() if host_mode == Mode.HOST else "혼자 하기")
	session_started.emit()


func _join(transport: RefCounted, address: String) -> void:
	var serial := _begin(transport)
	mode = Mode.CLIENT
	_set_status("%s 접속 중..." % transport.get_display_name())
	await _switch_scene(WORLD_SCENE)
	if serial != _serial:
		return
	var peer: MultiplayerPeer = await transport.open_client(address)
	if serial != _serial:
		return
	if peer == null:
		_fail(transport.error_message)
		return
	multiplayer.multiplayer_peer = peer
	get_tree().create_timer(CONNECT_TIMEOUT_SEC).timeout.connect(_on_connect_timeout.bind(serial))


func _begin(transport: RefCounted) -> int:
	_serial += 1
	_reset_connection()
	_transport = transport
	return _serial


func _reset_connection() -> void:
	if _transport != null:
		_transport.close()
		_transport = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode = Mode.NONE
	_connected = false
	_admitting.clear()


func _fail(reason: String) -> void:
	push_warning("세션 실패: %s" % reason)
	# 멀티플레이 poll 도중(신호 콜백 안)에 피어를 바꾸지 않도록 미룬다.
	leave_session.call_deferred(reason)


func _set_status(text: String) -> void:
	status_text = text
	status_changed.emit(text)


## 현재 씬을 바로 바꾼다. change_scene_to_file 은 다음 프레임까지 미뤄지므로
## "월드가 준비된 뒤 접속" 순서를 지키려고 직접 바꾼다.
func _switch_scene(path: String) -> void:
	await get_tree().process_frame
	var tree := get_tree()
	var old := tree.current_scene
	if old != null:
		tree.root.remove_child(old)
		old.queue_free()
	var scene: Node = load(path).instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene


## 호스트: 새 접속이 인증 단계에 들어옴 → 인원을 세어 입장 결과를 보낸다.
## 가득 찼으면 "full" 만 보내고 완료하지 않는다. 클라이언트가 받자마자 나가고,
## 혹시 남아 있으면 SceneMultiplayer.auth_timeout(기본 3초)이 끊는다.
func _on_peer_authenticating(peer_id: int) -> void:
	if not is_host():
		return
	var scene_multiplayer := multiplayer as SceneMultiplayer
	if multiplayer.get_peers().size() + _admitting.size() >= MAX_PLAYERS - 1:
		scene_multiplayer.send_auth(peer_id, AUTH_FULL.to_utf8_buffer())
		return
	_admitting[peer_id] = true
	scene_multiplayer.send_auth(peer_id, AUTH_OK.to_utf8_buffer())
	scene_multiplayer.complete_auth(peer_id)


## 클라이언트: 호스트가 보낸 입장 결과.
func _on_auth_data(peer_id: int, data: PackedByteArray) -> void:
	if is_host() or peer_id != 1:
		return
	if data.get_string_from_utf8() == AUTH_FULL:
		_fail("방이 가득 찼습니다 (%d/%d)" % [MAX_PLAYERS, MAX_PLAYERS])
	else:
		(multiplayer as SceneMultiplayer).complete_auth(peer_id)


func _on_peer_connected(peer_id: int) -> void:
	_admitting.erase(peer_id)
	if is_host():
		player_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_admitting.erase(peer_id)
	player_left.emit(peer_id)


func _on_connected_to_server() -> void:
	_connected = true
	_set_status("%s 접속됨 (내 ID %d)" % [get_transport_name(), multiplayer.get_unique_id()])
	session_started.emit()


func _on_connect_timeout(serial: int) -> void:
	if serial == _serial and mode == Mode.CLIENT and not _connected:
		_fail("접속 시간 초과")


func _on_connection_failed() -> void:
	if mode == Mode.CLIENT:
		_fail("접속 실패")


func _on_server_disconnected() -> void:
	if mode == Mode.CLIENT:
		leave_session.call_deferred("호스트와 연결이 끊겼습니다")
