extends "res://tests/qa_test.gd"
## V3 시제품 1 (손맛) 한 바퀴: 혼자 하기로 강아지를 적시고 → 거품 → 헹구기 → 수건 → 드라이어 →
## 동전 줍기 → 컴퓨터 자리에서 복숭아 샴푸 사기 → 분홍 거품·향 팁 → 샴푸가 떨어지면 거품이 안 남.
##
## 붓질은 실제 경로 그대로 시험한다: 화면 좌표 → 카메라 광선 → 강아지 충돌 모양 → 마스크 칠하기 → 비율.
## (WashStation.operate 는 월드가 매 프레임 마우스 위치로 부르는 함수다.)

const WashStation := preload("res://scripts/sim/wash_station.gd")
const STEP := 1.0 / 30.0
const GRID := 22.0
const SPAN := 230.0

var world: Node
var station: WashStation
var store: Node
var sfx: Node


func run_test() -> void:
	time_limit_sec = 170.0
	# 헤드리스 창은 64×64 라서 게임 화면 크기로 맞춘다 (커서 격자가 화면 픽셀 기준)
	get_tree().root.size = Vector2i(1280, 800)
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	station = world.station
	store = world.store
	sfx = world.sfx
	for i in 3:
		await get_tree().physics_frame
	check_eq(station.dog_number(), 1, "첫 손님")
	check_eq(station.operator, 1, "혼자 하기: 내가 작업자")
	check_eq(station.stage, WashStation.Stage.WET, "적시기부터")
	check(station.dog.ray_hit(world.camera, _dog_screen()) != null, "화면 가운데 강아지에 마우스가 닿음")
	check(world.camera.fov == Tuning.data.seat_camera_fov, "목욕대 시야 seat_camera_fov")

	# --- 1. 적시기 + 차가운 물
	station.temperature = 0.1
	station.tool = WashStation.Tool.SHOWER
	var mood_before := station.mood
	station.operate(_dog_screen(), true, true, STEP)
	await _frames(2)
	check(is_equal_approx(station.mood, mood_before + Tuning.data.mood_cold_water), "차가운 물 → 기분 %.2f (전 %.2f)" % [station.mood, mood_before])
	check("yelp" in sfx.played, "차가운 물 → 펄쩍 소리")
	station.temperature = 0.5
	# 눈에 물: 기분이 깎이고 안내 띠에 경고
	var model: Node3D = station.dog.model
	var eye_screen: Vector2 = world.camera.unproject_position(model.to_global(model.face_center))
	station.turn(-rad_to_deg(station.turntable.rotation.y))
	await get_tree().physics_frame
	await get_tree().physics_frame
	eye_screen = world.camera.unproject_position(model.to_global(model.face_center))
	mood_before = station.mood
	station.operate(eye_screen, true, false, STEP)
	await _frames(2)
	check(station.mood < mood_before, "눈에 물 → 기분 내려감")
	check(world.hud.hint_label.text.contains("눈에 물"), "눈에 물 안내")
	check(await _wash_stage(WashStation.Stage.WET), "적시기 끝")
	check("ding" in sfx.played, "단계 끝 → 딩")

	# --- 2. 거품: 병 클릭 = 한 덩이, 같은 곳 문지르기 → 다리 찰랑(3초) → 몸 털기(6초) + 화면 거품
	station.tool = WashStation.Tool.SHAMPOO
	var basic_before: int = store.basic_uses
	station.operate(_dog_screen(), true, true, STEP)
	await _frames(1)
	check(station.dose > 0.0, "병 클릭 → 거품 덩이")
	check_eq(store.basic_uses, basic_before - 1, "샴푸 한 마리분 씀")
	var tickle_at := _dog_screen() + Vector2(-60, -10)
	for i in int(6.3 / STEP):
		station.dose = 1.0
		station.operate(tickle_at + Vector2(4.0 * (i % 2), 0), true, false, STEP)
	await _frames(1)
	check("squeak" in sfx.played, "같은 곳 3초 → 다리 찰랑")
	check("shake" in sfx.played, "같은 곳 6초 → 몸 털기")
	check(world.hud.overlay.is_showing_foam(), "몸 털기 → 화면에 거품")
	check(station.dog.foam_count() > 0, "문지르면 거품 공이 붙음")
	check(await _wash_stage(WashStation.Stage.SOAP), "거품 끝")
	var seen: Variant = station.dog.ray_hit(world.camera, _dog_screen())
	check(seen != null and station.dog.mask.mud_at(station.dog.dir_of(seen)) < 0.1, "문지른 곳 진흙이 지워짐")

	# --- 3. 헹구기: 거품 공이 줄어듦
	var foam_before: int = station.dog.foam_count()
	station.tool = WashStation.Tool.SHOWER
	check(await _wash_stage(WashStation.Stage.RINSE), "헹구기 끝")
	check(station.dog.foam_count() < foam_before, "헹구면 거품 공이 줄어듦 (%d → %d)" % [foam_before, station.dog.foam_count()])

	# --- 4·5. 수건 → 드라이어 (뽀송 = 커짐)
	await _frames(2)
	var drops_before: int = station.dog.visible_drops()
	check(drops_before > 0, "헹군 뒤 물방울이 맺힘 (%d)" % drops_before)
	station.tool = WashStation.Tool.TOWEL
	check(await _wash_stage(WashStation.Stage.TOWEL), "수건 끝")
	await _frames(2)
	check(station.dog.visible_drops() < drops_before / 2, "수건으로 닦은 곳 물방울이 사라짐 (%d → %d)" % [drops_before, station.dog.visible_drops()])
	station.tool = WashStation.Tool.DRYER
	var scale_before: float = station.dog.model.scale.x
	check(await _wash_stage(WashStation.Stage.DRY), "드라이어 끝")
	await _frames(1)
	check(station.dog.model.scale.x > scale_before + 0.1, "다 말리면 털이 부풂 (%.2f → %.2f)" % [scale_before, station.dog.model.scale.x])
	check("poof" in sfx.played, "뽀송 소리")

	# --- 6. 돈: 동전 클릭 (요금 + 기분 팁)
	check_eq(station.stage, WashStation.Stage.PAY, "다 씻으면 계산")
	check(station.coins.size() >= 1 and station.coins[0] == Tuning.data.money_wash_price, "요금 동전 %s" % [station.coins])
	var expected_money: int = store.money
	for value in station.coins:
		expected_money += value
	await _collect_all_coins()
	check_eq(store.money, expected_money, "동전을 모두 주움")
	check("coin" in sfx.played, "짤랑")
	await _wait(func() -> bool: return station.dog_number() == 2, 3.0)
	check_eq(station.dog_number(), 2, "다음 손님이 옴")
	check_eq(station.dogs_done, 1, "씻긴 손님 수")

	# --- 7. 컴퓨터 자리: 복숭아 샴푸 사기 (돈은 시험이라 채워 둠)
	store.money = Tuning.data.shop_price_peach_shampoo + 5
	_press_key(KEY_TAB)
	await _wait(func() -> bool: return world.local_seat() == 1, 1.0)
	check_eq(world.local_seat(), 1, "Tab → 컴퓨터 자리")
	await get_tree().create_timer(Tuning.data.seat_switch_time + 0.15).timeout
	check(world.camera.global_position.distance_to(world.computer_point.global_position) < 0.05, "카메라가 컴퓨터 자리로 옮겨 감")
	check(world.hud.shop_panel.visible, "컴퓨터 화면에 가게")
	world.hud.buy_peach.pressed.emit()
	await _frames(2)
	check_eq(store.money, 5, "복숭아 샴푸 값 %d" % Tuning.data.shop_price_peach_shampoo)
	check_eq(store.peach_uses, Tuning.data.tool_shampoo_uses_per_bottle, "복숭아 샴푸 한 병")
	check_eq(store.shampoo, "peach", "산 샴푸를 바로 씀")
	_press_key(KEY_TAB)
	await _wait(func() -> bool: return world.local_seat() == 0, 1.0)

	# --- 8. 복숭아 손님: 분홍 거품 + 향 팁
	station.dog_info.w = 1
	station.tool = WashStation.Tool.SHOWER
	await _wash_stage(WashStation.Stage.WET)
	station.tool = WashStation.Tool.SHAMPOO
	station.operate(_dog_screen(), true, true, STEP)
	await _frames(1)
	check(station.dog.foam_color == station.dog.FOAM_PINK, "복숭아 샴푸 → 분홍 거품")
	check(station.used_peach, "복숭아 샴푸를 씀")
	await _wash_stage(WashStation.Stage.SOAP)
	station.tool = WashStation.Tool.SHOWER
	await _wash_stage(WashStation.Stage.RINSE)
	station.tool = WashStation.Tool.TOWEL
	await _wash_stage(WashStation.Stage.TOWEL)
	station.tool = WashStation.Tool.DRYER
	await _wash_stage(WashStation.Stage.DRY)
	check_eq(station.dog.visible_drops(), 0, "다 말리면 물방울 없음")
	check(Tuning.data.money_scent_tip in station.coins, "향 팁 동전 %s" % [station.coins])
	await _collect_all_coins()
	await _wait(func() -> bool: return station.dog_number() == 3, 3.0)

	# --- 9. 샴푸가 떨어지면 거품이 안 남
	store.peach_uses = 0
	store.basic_uses = 0
	station.tool = WashStation.Tool.SHOWER
	await _wash_stage(WashStation.Stage.WET)
	station.tool = WashStation.Tool.SHAMPOO
	station.operate(_dog_screen(), true, true, STEP)
	await _frames(1)
	check(station.out_of_shampoo, "샴푸가 없음")
	check_eq(station.dose, 0.0, "샴푸가 없으면 거품 덩이 없음")
	await _sweep(1)
	check_eq(station.dog.mask.ratio("scrub"), 0.0, "샴푸 없이 문질러도 거품이 안 남")
	check(station.next_hint().contains("샴푸가 떨어졌어요"), "샴푸 사러 가라는 안내")

	await Net.leave_session()


## 단계가 끝날 때까지 회전판을 돌려 가며 강아지 위를 훑는다. 끝나면 true.
func _wash_stage(target: int) -> bool:
	for pass_index in 10:
		if station.stage != target:
			print("단계 %d: %d 바퀴" % [target, pass_index])
			return true
		await _sweep(1)
		await get_tree().create_timer(WashStation.REPORT_INTERVAL * 2.0).timeout
	print("단계 %d 진행 %.3f" % [target, station.dog.mask.ratio(WashStation.STAGE_CHANNEL[target])])
	return station.stage != target


## 회전판을 한 바퀴(45도씩) 돌리며 화면 격자를 지그재그로 문지른다.
func _sweep(turns: int) -> void:
	for turn in 8 * turns:
		station.turn(45.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var center := _dog_screen()
		var row := 0
		var y := -SPAN
		while y <= SPAN:
			var x := -SPAN
			while x <= SPAN:
				var pos := center + Vector2(x if row % 2 == 0 else -x, y)
				var press: bool = station.tool == WashStation.Tool.SHAMPOO and station.dose <= 0.0
				station.operate(pos, true, press, STEP)
				x += GRID
			y += GRID
			row += 1


func _dog_screen() -> Vector2:
	var model: Node3D = station.dog.model
	return world.camera.unproject_position(model.to_global(model.body_center))


func _collect_all_coins() -> void:
	await _frames(2)
	var guard := 0
	while not station.coins.is_empty() and guard < 10:
		guard += 1
		var coin: Node3D = station.coin_root.get_child(0)
		var pos: Vector2 = world.camera.unproject_position(coin.global_position)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = pos
		click.global_position = pos
		Input.parse_input_event(click)
		await _frames(2)
		var release := click.duplicate()
		release.pressed = false
		Input.parse_input_event(release)
		await _frames(2)
	check(station.coins.is_empty(), "동전 클릭으로 모두 주움")


func _press_key(keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	Input.parse_input_event(key)
	var up := key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(done: Callable, seconds: float) -> void:
	var left := seconds
	while not done.call() and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
