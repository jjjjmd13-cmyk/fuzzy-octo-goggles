extends "res://scripts/net/transports/transport.gd"
## ENet (UDP). 개발·로컬 테스트용. 같은 PC에서 창 두 개로 127.0.0.1 접속 가능.

var _port: int
var _max_players: int
var _peer: ENetMultiplayerPeer


func _init(port: int, max_players: int) -> void:
	_port = port
	_max_players = max_players


func get_display_name() -> String:
	return "ENet"


func open_host() -> MultiplayerPeer:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(_port, _max_players - 1)
	if err != OK:
		error_message = "포트 %d 를 열 수 없습니다 (%s)" % [_port, error_string(err)]
		_peer = null
		return null
	return _peer


func open_client(address: String) -> MultiplayerPeer:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, _port)
	if err != OK:
		error_message = "%s:%d 에 접속할 수 없습니다 (%s)" % [address, _port, error_string(err)]
		_peer = null
		return null
	return _peer


func close() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
