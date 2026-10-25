extends "res://scripts/net/transports/transport.gd"
## 혼자 하기: 접속 없는 호스트. OfflineMultiplayerPeer 는 항상 서버(peer id 1)라서
## 멀티플레이와 똑같은 코드 경로로 게임이 돈다.


func get_display_name() -> String:
	return "오프라인"


func open_host() -> MultiplayerPeer:
	return OfflineMultiplayerPeer.new()
