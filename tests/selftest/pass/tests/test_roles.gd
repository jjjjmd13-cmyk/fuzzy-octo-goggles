extends "res://tests/qa_test.gd"
# 기대: 호스트·손님 두 프로세스가 ENet 으로 붙고 둘 다 통과


func run_test() -> void:
	var peer := ENetMultiplayerPeer.new()
	if role == "host":
		check_eq(peer.create_server(port), OK, "서버 열기")
		multiplayer.multiplayer_peer = peer
		report_ready()
		var id: int = await multiplayer.peer_connected
		check(id > 1, "손님 접속")
		# 호스트가 끝나면 손님 쪽에 server_disconnected 가 간다.
	else:
		check_eq(peer.create_client("127.0.0.1", port), OK, "접속 시작")
		multiplayer.multiplayer_peer = peer
		await multiplayer.connected_to_server
		check(multiplayer.get_unique_id() > 1, "내 ID")
		# 바로 끝내면 호스트가 접속을 다 받기 전에 끊길 수 있어, 호스트가 끊을 때까지 기다린다.
		await multiplayer.server_disconnected
