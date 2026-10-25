extends RefCounted
## 전송 방식 공통 인터페이스.
##
## 전송 방식은 MultiplayerPeer 를 만들어 돌려주는 일만 한다. 그 뒤의 동기화는
## 전부 Godot 고수준 멀티플레이(MultiplayerSpawner/Synchronizer, RPC)가 맡는다.
## open_host / open_client 는 코루틴일 수 있으므로 호출하는 쪽은 항상 await 한다.
## 실패하면 null 을 돌려주고 error_message 에 사람이 읽을 이유를 남긴다.

var error_message := ""


func get_display_name() -> String:
	return "?"


func open_host() -> MultiplayerPeer:
	error_message = "이 전송 방식은 호스트를 지원하지 않습니다"
	return null


func open_client(_address: String) -> MultiplayerPeer:
	error_message = "이 전송 방식은 접속을 지원하지 않습니다"
	return null


func close() -> void:
	pass
