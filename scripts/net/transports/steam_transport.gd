extends "res://scripts/net/transports/transport.gd"
## Steam 로비 + SteamMultiplayerPeer (GodotSteam).
##
## GodotSteam 은 선택 사항이라 이 스크립트는 Steam 클래스를 이름으로 직접 쓰지 않는다
## (애드온이 없으면 파싱 오류가 나기 때문). SteamService.steam 객체와
## ClassDB 로만 접근한다. open_client 의 address 는 로비 ID 문자열이다.

const LOBBY_TYPE_FRIENDS_ONLY := 1
const RESULT_OK := 1
const CHAT_ROOM_ENTER_RESPONSE_SUCCESS := 1
const CHAT_ROOM_ENTER_RESPONSE_FULL := 4
const STEP_TIMEOUT_SEC := 15.0
const VIRTUAL_PORT := 0

signal _step_done

var lobby_id := 0
var _max_players: int
var _peer: MultiplayerPeer
var _step_result: Array = []


func _init(max_players: int) -> void:
	_max_players = max_players


func get_display_name() -> String:
	return "Steam"


func open_host() -> MultiplayerPeer:
	if not _check_available():
		return null
	var steam: Object = SteamService.steam
	steam.connect("lobby_created", _on_lobby_created)
	steam.call("createLobby", LOBBY_TYPE_FRIENDS_ONLY, _max_players)
	await _wait_step()
	steam.disconnect("lobby_created", _on_lobby_created)
	if _step_result.is_empty():
		error_message = "스팀 로비 만들기 시간 초과"
		return null
	if _step_result[0] != RESULT_OK:
		error_message = "스팀 로비를 만들 수 없습니다 (결과 %d)" % _step_result[0]
		return null
	lobby_id = _step_result[1]
	steam.call("setLobbyJoinable", lobby_id, true)
	steam.call("setLobbyData", lobby_id, "name", "%s 의 게임" % SteamService.persona_name)

	_peer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = _peer.call("create_host", VIRTUAL_PORT)
	if err != OK:
		error_message = "스팀 호스트를 열 수 없습니다 (%s)" % error_string(err)
		close()
		return null
	return _peer


func open_client(address: String) -> MultiplayerPeer:
	if not _check_available():
		return null
	lobby_id = address.to_int()
	var steam: Object = SteamService.steam
	steam.connect("lobby_joined", _on_lobby_joined)
	steam.call("joinLobby", lobby_id)
	await _wait_step()
	steam.disconnect("lobby_joined", _on_lobby_joined)
	if _step_result.is_empty():
		error_message = "스팀 로비 참가 시간 초과"
		lobby_id = 0
		return null
	if _step_result[3] == CHAT_ROOM_ENTER_RESPONSE_FULL:
		error_message = "방이 가득 찼습니다 (%d/%d)" % [_max_players, _max_players]
		lobby_id = 0
		return null
	if _step_result[3] != CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		error_message = "스팀 로비에 들어갈 수 없습니다 (응답 %d)" % _step_result[3]
		lobby_id = 0
		return null
	var owner_id: int = steam.call("getLobbyOwner", lobby_id)

	_peer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: int = _peer.call("create_client", owner_id, VIRTUAL_PORT)
	if err != OK:
		error_message = "스팀 호스트에 접속할 수 없습니다 (%s)" % error_string(err)
		close()
		return null
	return _peer


func invite_friends() -> void:
	if lobby_id != 0 and SteamService.available:
		SteamService.steam.call("activateGameOverlayInviteDialog", lobby_id)


func close() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	if lobby_id != 0 and SteamService.available:
		SteamService.steam.call("leaveLobby", lobby_id)
	lobby_id = 0


func _check_available() -> bool:
	if not SteamService.available:
		error_message = "스팀을 쓸 수 없습니다: %s" % SteamService.init_message
		return false
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		error_message = "이 GodotSteam 빌드에는 SteamMultiplayerPeer 가 없습니다"
		return false
	return true


func _wait_step() -> void:
	_step_result = []
	var timer := (Engine.get_main_loop() as SceneTree).create_timer(STEP_TIMEOUT_SEC)
	timer.timeout.connect(_step_done.emit)
	await _step_done
	timer.timeout.disconnect(_step_done.emit)


func _on_lobby_created(connect_result: int, new_lobby_id: int) -> void:
	_step_result = [connect_result, new_lobby_id]
	_step_done.emit()


func _on_lobby_joined(joined_lobby_id: int, permissions: int, locked: bool, response: int) -> void:
	if joined_lobby_id != lobby_id:
		return
	_step_result = [joined_lobby_id, permissions, locked, response]
	_step_done.emit()
