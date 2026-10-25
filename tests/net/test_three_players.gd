extends "res://tests/qa_test.gd"
## NET-02: ENet 호스트 1 + 클라이언트 2 (실행기가 .roles 로 프로세스 3개를 띄움).
##
## 확인하는 것:
##   1. 모든 피어에서 플레이어 3명이 보이고, 각자 슬롯이 겹치지 않으며 그 슬롯의 스폰 지점에 있음
##   2. 클라이언트마다 자기 캐릭터의 권한이 자기에게 있음
##   3. 두 클라이언트가 모두 확인한 뒤 호스트가 나가면, 두 클라이언트 모두 메뉴로 돌아감

const PLAYER_COUNT := 3
const SPAWN_TOLERANCE := 0.5

var _ready_clients := {}


func run_test() -> void:
	# Net 이 씬을 바꿀 때 이 노드는 남아 있어야 하므로 현재 씬에서 뺀다.
	get_tree().current_scene = null
	if role == "server":
		await _run_server()
	else:
		await _run_client()


func _run_server() -> void:
	Net.host_enet(port)
	await Net.session_started
	report_ready()

	var world := await _wait_players()
	_check_players(world)
	while _ready_clients.size() < PLAYER_COUNT - 1:
		await get_tree().process_frame
	print("서버: 클라이언트 %s 확인 완료" % [_ready_clients.keys()])

	await Net.leave_session("테스트 종료")


func _run_client() -> void:
	Net.join_enet("127.0.0.1", port)
	await Net.session_started
	var my_id := multiplayer.get_unique_id()

	var world := await _wait_players()
	_check_players(world)
	var me: Node3D = world.get_player(my_id)
	check(me != null and me.is_multiplayer_authority(), "내 캐릭터 권한이 내게 있음")
	_report_seen_all.rpc_id(1)

	# 바로 끝내지 않고 호스트가 나갈 때까지 기다린다 (TESTING.md 주의 사항).
	var reason: String = await Net.session_ended
	var scene := get_tree().current_scene
	check(scene != null and scene.scene_file_path == Net.MENU_SCENE, "호스트가 나간 뒤 메뉴로 돌아감")
	print("클라이언트 %d: 호스트 퇴장 → 메뉴 (%s)" % [my_id, reason])


func _check_players(world: Node) -> void:
	var players: Array[Node] = world.get_node("Players").get_children()
	check_eq(players.size(), PLAYER_COUNT, "플레이어 수")
	var slots := {}
	for player in players:
		slots[player.slot] = true
		var expected: Vector3 = world.get_node("SpawnPoints").get_child(player.slot).position
		check(player.position.distance_to(expected) <= SPAWN_TOLERANCE,
			"플레이어 %s 가 슬롯 %d 스폰 지점에 있음 (위치 %s, 기대 %s)" % [player.name, player.slot, player.position, expected])
	check_eq(slots.size(), PLAYER_COUNT, "슬롯이 겹치지 않음")


## 월드에 플레이어가 PLAYER_COUNT 명 생길 때까지 기다린다 (시간 제한은 time_limit_sec).
func _wait_players() -> Node:
	while true:
		var world := get_tree().current_scene
		if world != null and world.has_node("Players") and world.get_node("Players").get_child_count() >= PLAYER_COUNT:
			return world
		await get_tree().process_frame
	return null


@rpc("any_peer", "reliable")
func _report_seen_all() -> void:
	_ready_clients[multiplayer.get_remote_sender_id()] = true
