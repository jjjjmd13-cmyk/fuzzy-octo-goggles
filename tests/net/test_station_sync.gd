extends "res://tests/qa_test.gd"
## V3 시제품 1 완료 조건 11: 목욕대 권한·동기화 (ENet 호스트 1 + 클라이언트 1, .roles).
##
##   1. 둘 다 목욕대 자리 → 먼저 있던 호스트가 작업자. 호스트가 적시기를 끝내면 클라이언트도 거품 단계를 봄.
##      클라이언트 화면의 마스크는 칠해지지 않고(비율만 받음) 셰이더는 비율 값을 씀.
##   2. 클라이언트가 컴퓨터 자리에서 산 샴푸가 호스트에 반영됨 (돈·병은 호스트 권한).
##   3. 호스트가 컴퓨터 자리로 옮기면 클라이언트가 작업자가 되고, 지금까지 진행으로 마스크를 채운 뒤
##      이어서 문지른 결과(비율)가 호스트에 도착함.
##   4. 호스트가 나가면 클라이언트는 메뉴로.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const STEP := 1.0 / 30.0

var _flags := {}


func run_test() -> void:
	get_tree().root.size = Vector2i(1280, 800)
	get_tree().current_scene = null
	if role == "server":
		await _run_server()
	else:
		await _run_client()


func _run_server() -> void:
	Net.host_enet(port)
	await Net.session_started
	report_ready()
	var client_id: int = await Net.player_joined
	var world := get_tree().current_scene
	var station: WashStation = world.station
	await _until(func() -> bool: return world.get_player(client_id) != null)
	for i in 3:
		await get_tree().physics_frame
	check_eq(station.operator, 1, "둘 다 목욕대: 호스트가 작업자")

	station.temperature = 0.5
	station.tool = WashStation.Tool.SHOWER
	while station.stage == WashStation.Stage.WET:
		await _sweep(world, station)
		await get_tree().create_timer(0.25).timeout
	print("서버: 적시기 끝")
	await _until(func() -> bool: return _flags.has("saw_soap"))

	world.store.money = 100
	await _until(func() -> bool: return world.store.basic_uses == Tuning.data.tool_shampoo_uses_per_bottle * 2)
	check_eq(world.store.money, 100 - Tuning.data.shop_price_basic_shampoo, "클라이언트가 산 샴푸 값이 호스트 돈에서 빠짐")

	world.get_local_player().set_seat(1)
	await _until(func() -> bool: return station.operator == client_id)
	print("서버: 작업자가 클라이언트 %d 로 바뀜" % client_id)
	await _until(func() -> bool: return station.ratio > 0.05)
	check_eq(station.stage, WashStation.Stage.SOAP, "클라이언트가 문지른 진행이 호스트에 옴")
	check_eq(world.store.basic_uses, Tuning.data.tool_shampoo_uses_per_bottle * 2 - 1, "클라이언트의 병 클릭도 호스트 병에서 씀")
	check(station.dog.mask.ratio("scrub") == 0.0, "작업자가 아닌 호스트 마스크는 칠해지지 않음")
	await _until(func() -> bool: return _flags.has("client_done"))
	await Net.leave_session("테스트 종료")


func _run_client() -> void:
	Net.join_enet("127.0.0.1", port)
	await Net.session_started
	var world := get_tree().current_scene
	await _until(func() -> bool: return world.get_node("Players").get_child_count() == 2 and world.station.dog.model != null)
	var station: WashStation = world.station
	await _until(func() -> bool: return station.operator == 1)
	check(not station.is_operator(), "클라이언트는 구경 (작업자 아님)")

	await _until(func() -> bool: return station.stage == WashStation.Stage.SOAP)
	await _frames(3)
	check_eq(station.dog.mask.ratio("wet"), 0.0, "구경하는 쪽 마스크는 칠하지 않음")
	check(station.dog.material.get_shader_parameter("use_global"), "구경하는 쪽 셰이더는 진행 비율을 씀")
	_flag.rpc_id(1, "saw_soap")

	# 컴퓨터 자리에서 샴푸 사기
	world.switch_seat()
	await _until(func() -> bool: return world.store.money >= 100)
	world.store.send_buy("basic")
	await _until(func() -> bool: return world.store.money == 100 - Tuning.data.shop_price_basic_shampoo)
	world.switch_seat()

	await _until(func() -> bool: return station.is_operator())
	await _frames(2)
	check(station.dog.mask.ratio("wet") >= Tuning.data.stage_complete_ratio, "작업자가 되면 끝난 단계로 마스크를 채움")
	for i in 3:
		await get_tree().physics_frame
	station.tool = WashStation.Tool.SHAMPOO
	await _sweep(world, station)
	check(station.dog.mask.ratio("scrub") > 0.05, "클라이언트 화면에서 문지름 (%.3f)" % station.dog.mask.ratio("scrub"))
	await get_tree().create_timer(0.3).timeout
	_flag.rpc_id(1, "client_done")

	var reason: String = await Net.session_ended
	check_eq(get_tree().current_scene.scene_file_path, Net.MENU_SCENE, "호스트가 나간 뒤 메뉴 (%s)" % reason)


## 회전판을 돌리며 화면 격자를 훑는다 (test_wash_flow 와 같은 방식, 더 성기게).
func _sweep(world: Node, station: WashStation) -> void:
	for turn in 8:
		station.turn(45.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var model: Node3D = station.dog.model
		var center: Vector2 = world.camera.unproject_position(model.to_global(model.body_center))
		var y := -230.0
		while y <= 230.0:
			var x := -230.0
			while x <= 230.0:
				var press: bool = station.tool == WashStation.Tool.SHAMPOO and station.dose <= 0.0
				station.operate(center + Vector2(x, y), true, press, STEP)
				if press:
					# 병 클릭 결과는 호스트를 거쳐 돌아온다
					await get_tree().process_frame
				x += 24.0
			y += 24.0
		await get_tree().process_frame


func _until(done: Callable) -> void:
	while not done.call():
		await get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


@rpc("any_peer", "reliable")
func _flag(name: String) -> void:
	_flags[name] = true
