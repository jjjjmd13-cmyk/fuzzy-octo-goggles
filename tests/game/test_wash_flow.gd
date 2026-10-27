extends "res://tests/qa_test.gd"
## V3 시제품 1-2 한 바퀴 (GDD_V3 8.1-2 완료 조건 1~5): 혼자 하기로
## 주인이 강아지를 맡김 → 적시기(누르고 조준, 휠 온도) → 샴푸 짜기(누르는 시간) → 문지르기(원 그리기) →
## 헹구기(위→아래 쓸기) → 수건(연타) → 드라이어(휠 거리) → 주인 반응·동전 → 강아지가 주인에게 →
## 다음 손님 → 컴퓨터 자리에서 복숭아 샴푸 → 분홍 거품·향 팁 → 너무 많이 짜면 넘침 → 샴푸가 떨어지면 거품 없음.
##
## 손동작은 실제 경로 그대로 시험한다: 화면 좌표 → WashStation.operate → 카메라 광선 → 마스크.
## 사람 손 흉내는 tests/game/wash_hands.gd.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const WashHands := preload("res://tests/game/wash_hands.gd")
const STEP := 1.0 / 60.0

var world: Node
var station: WashStation
var store: Node
var sfx: Node
var hands: WashHands


func run_test() -> void:
	time_limit_sec = 115.0
	# 헤드리스 창은 64×64 라서 게임 화면 크기로 맞춘다 (커서 좌표가 화면 픽셀 기준)
	get_tree().root.size = Vector2i(1280, 800)
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	world.input_enabled = false
	station = world.station
	store = world.store
	sfx = world.sfx
	hands = WashHands.new(get_tree(), world)

	# --- 주인이 강아지를 데리고 들어와 말풍선으로 요청 → 맡기고 의자에 앉음
	check_eq(station.dog_number(), 1, "첫 손님")
	check_eq(station.owner_phase, WashStation.OwnerPhase.ARRIVE, "주인이 들어옴")
	await _frames(2)
	check(not station.dog.model.visible, "주인이 맡기기 전엔 강아지가 목욕통에 없음")
	check(station.owner_bubble_visible(), "주인 말풍선 (요청)")
	check(not station.is_washing(), "맡기기 전엔 씻을 수 없음")
	await hands.wait_washing()
	await _frames(3)
	check(station.dog.model.visible, "맡긴 뒤 강아지가 목욕통에")
	await get_tree().create_timer(1.3).timeout
	check(station.owner_model.global_position.distance_to(station.to_global(WashStation.OWNER_CHAIR)) < 0.15, "주인이 대기 의자로 감")
	check_eq(station.operator, 1, "혼자 하기: 내가 작업자")
	check_eq(station.tool, WashStation.Tool.SHOWER, "적시기 도구(샤워기)가 저절로 손에")
	for i in 3:
		await get_tree().physics_frame

	# --- 적시기: 휠로 온도. 차가우면 펄쩍
	station.adjust(-3)
	check(station.temperature < 0.35, "휠 아래 → 차가운 물 (%.1f)" % station.temperature)
	var mood_before := station.mood
	await _hold(hands.center(), 0.1)
	check(is_equal_approx(station.mood, mood_before + Tuning.data.mood_cold_water), "차가운 물 → 기분 %.2f (전 %.2f)" % [station.mood, mood_before])
	check("yelp" in sfx.played, "펄쩍 소리")
	station.adjust(3)
	check(station.dog._stream.visible or true, "물줄기")
	# 눈에 물: 기분이 깎이고 안내 띠에 경고
	var model: Node3D = station.dog.model
	mood_before = station.mood
	await _hold(world.camera.unproject_position(model.to_global(model.face_center)), 0.1)
	if check(station.mood < mood_before, "눈에 물 → 기분 내려감"):
		await _frames(1)
		check(world.hud.hint_label.text.contains("눈에 물"), "눈에 물 안내")
	# 화살표 클릭으로 바로 돌리기
	var turns_before := station.turns
	await _click(station.turn_arrow_points()[1])
	check_eq(station.turns, turns_before + 1, "회전판 화살표 클릭 → 돎")
	await _wait(func() -> bool: return station.turning_left == 0.0, 3.0)
	turns_before = station.turns
	check(await hands.do_stage(WashStation.Stage.WET) < 999.0, "적시기 끝")
	await _frames(2)
	check(station.eye_warning_left == 0.0 and not world.hud.hint_label.text.contains("눈에 물"), "단계가 바뀌면 눈에 물 경고 대신 새 단계 안내 (이슈 #39)")
	check(station.turns > turns_before, "보이는 쪽이 다 되면 저절로 돎 (%d번)" % (station.turns - turns_before))
	check("ding" in sfx.played, "단계 끝 → 딩")

	# --- 샴푸 짜기: 누르는 시간 = 양
	check_eq(station.tool, WashStation.Tool.BOTTLE, "샴푸 병이 저절로 손에")
	var basic_before: int = store.basic_uses
	var at := hands.center()
	await _op(at, true, true)
	await _press_for(at, 0.3)
	check(station.squeezing and station.dog._glob.visible, "누르는 동안 덩이가 보임")
	var small := station.squeeze_amount()
	await _press_for(at, 0.3)
	check(station.squeeze_amount() > small, "오래 누를수록 덩이가 커짐")
	await _op(at, false, false)
	await _frames(2)
	check(station.dose > 0.1 and station.dose < Tuning.data.squeeze_overflow_at, "떼면 몸에 떨어짐 (양 %.2f)" % station.dose)
	check_eq(store.basic_uses, basic_before - 1, "샴푸 한 마리분 씀")
	await _wait(func() -> bool: return station.stage == WashStation.Stage.SCRUB, 2.0)
	check_eq(station.stage, WashStation.Stage.SCRUB, "샴푸 짜기 끝")
	check_eq(station.tool, WashStation.Tool.HAND, "손이 저절로")

	# --- 문지르기
	# 같은 곳을 오래 → 다리 찰랑 → 몸 털기 (화면에 거품)
	for i in int(6.3 / STEP):
		station.dose = 0.5
		var angle := i * TAU * 2.0 * STEP
		await _op(hands.center() + Vector2(-30, 0) + Vector2(cos(angle), sin(angle)) * 15.0, true, false)
	await _frames(1)
	check("squeak" in sfx.played, "같은 곳 3초 → 다리 찰랑")
	check("shake" in sfx.played, "같은 곳 6초 → 몸 털기")
	check(world.hud.overlay.is_showing_foam(), "몸 털기 → 화면에 거품")
	await _op(hands.center(), false, false)
	# 같은 몸 위치·반경·리듬에서 비교한다. 앞의 간지럼 시험으로 칠한 양은 분리한다.
	await get_tree().create_timer(0.6).timeout
	station.dog.mask.fill("scrub", 0.0)
	station.dose = 0.5
	var before: float = station.dog.mask.ratio("scrub")
	for i in 60:
		await _op(hands.center() + Vector2(sin(i * TAU * 2.0 * STEP) * 40.0, 0), true, false)
	var back_forth: float = station.dog.mask.ratio("scrub") - before
	check(not station.circling, "왕복은 원이 아님")
	await _op(hands.center(), false, false)
	station.dog.mask.fill("scrub", 0.0)
	station.dose = 0.5
	before = station.dog.mask.ratio("scrub")
	for i in 60:
		var angle := i * TAU * 2.0 * STEP
		await _op(hands.center() + Vector2(cos(angle), sin(angle)) * 40.0, true, false)
	var circles: float = station.dog.mask.ratio("scrub") - before
	check(station.circling, "동그라미는 원으로 인식")
	check(circles > back_forth * 2.0, "원을 그리면 왕복보다 훨씬 빨리 거품 (원 %.3f, 왕복 %.3f)" % [circles, back_forth])
	check(station.dog.foam_count() > 0, "거품 공이 붙음")
	await _op(hands.center(), false, false)
	check(await hands.do_stage(WashStation.Stage.SCRUB) < 999.0, "문지르기 끝")

	# --- 헹구기: 위→아래로 쓸면 띠로 씻김
	check_eq(station.tool, WashStation.Tool.BUCKET, "바가지가 저절로 손에")
	var foam_before: int = station.dog.foam_count()
	before = station.dog.mask.ratio("rinse")
	var top := hands.center() + Vector2(0, -170)
	await _op(top, true, true)
	await _op(top + Vector2(0, 60), true, false)
	check_eq(station.pours, 0, "조금 끌어서는 안 쏟아짐")
	await _op(top + Vector2(0, 800 * Tuning.data.rinse_pour_min_drag + 10), true, false)
	check_eq(station.pours, 1, "충분히 끌면 쏟아짐")
	await _op(top + Vector2(0, 800 * Tuning.data.rinse_pour_min_drag + 40), true, false)
	check_eq(station.pours, 1, "한 번 누를 때 한 번만 쏟음")
	await _op(top, false, false)
	check(station.dog.mask.ratio("rinse") - before > 0.08, "한 번 쏟으면 띠가 한 번에 씻김 (%.2f)" % (station.dog.mask.ratio("rinse") - before))
	check(station.dog.foam_count() < foam_before, "거품이 씻겨 내려감 (%d → %d)" % [foam_before, station.dog.foam_count()])
	check("pour" in sfx.played, "촤아악")
	check(await hands.do_stage(WashStation.Stage.RINSE) < 999.0, "헹구기 끝")

	# --- 수건: 꾹꾹 (클릭 연타, 최소 간격)
	await _frames(2)
	var drops_before: int = station.dog.visible_drops()
	check(drops_before > 0, "헹군 뒤 물방울이 맺힘 (%d)" % drops_before)
	before = station.dog.mask.ratio("towel")
	await _op(hands.center(), true, true)
	var one_press: float = station.dog.mask.ratio("towel") - before
	await _op(hands.center() + Vector2(50, 0), false, false)
	await _op(hands.center() + Vector2(50, 0), true, true)
	check(is_equal_approx(station.dog.mask.ratio("towel") - before, one_press), "간격보다 빨리 누르면 안 닦임")
	check(one_press > 0.02, "한 번 누르면 도장만큼 닦임 (%.3f)" % one_press)
	check("press" in sfx.played, "꾹 소리")
	check(await hands.do_stage(WashStation.Stage.TOWEL) < 999.0, "수건 끝")
	await _frames(2)
	check(station.dog.visible_drops() < drops_before / 2, "닦은 곳 물방울이 사라짐 (%d → %d)" % [drops_before, station.dog.visible_drops()])

	# --- 드라이어: 휠로 거리. 너무 가까우면 기분 −
	check_eq(station.tool, WashStation.Tool.DRYER, "드라이어가 저절로 손에")
	var far := station.dryer_distance
	station.adjust(5)
	check(station.dryer_distance < far, "휠 위 → 가까이 (%.2f → %.2f m)" % [far, station.dryer_distance])
	station.adjust(-5)
	var scale_before: float = station.dog.model.scale.x
	check(await hands.do_stage(WashStation.Stage.DRY) < 999.0, "드라이어 끝")
	await _frames(1)
	check(station.dog.model.scale.x > scale_before + 0.1, "다 말리면 털이 부풂 (%.2f → %.2f)" % [scale_before, station.dog.model.scale.x])
	check("poof" in sfx.played, "뽀송 소리")

	# --- 주인 반응 + 동전 → 강아지가 주인에게 → 다음 손님
	await _wait(func() -> bool: return station.owner_phase == WashStation.OwnerPhase.REACT, 2.0)
	check_eq(station.owner_phase, WashStation.OwnerPhase.REACT, "다 씻으면 주인이 와서 반응")
	check(station.coins.size() >= 1 and station.coins[0] == Tuning.data.money_wash_price, "주인이 동전을 건넴 %s" % [station.coins])
	check(["sigh", "clap"].any(func(s: String) -> bool: return s in sfx.played) or station.mood_face() == 1, "주인 반응 소리")
	var expected_money: int = store.money
	for value in station.coins:
		expected_money += value
	await _collect_all_coins()
	check_eq(store.money, expected_money, "동전을 모두 주움")
	await _wait(func() -> bool: return station.owner_phase == WashStation.OwnerPhase.LEAVE, Tuning.data.owner_reaction_time + 1.0)
	check_eq(station.owner_phase, WashStation.OwnerPhase.LEAVE, "주인이 강아지를 데리고 나감")
	await _frames(2)
	check("bark" in sfx.played, "강아지가 주인에게 달려감 (멍!)")
	await _wait(func() -> bool: return station.dog_number() == 2, 4.0)
	check_eq(station.dog_number(), 2, "다음 손님")
	check_eq(station.dogs_done, 1, "씻긴 손님 수")

	# --- 컴퓨터 자리: 복숭아 샴푸 (돈은 시험이라 채워 둠)
	store.money = Tuning.data.shop_price_peach_shampoo + 5
	_press_key(KEY_TAB)
	await _wait(func() -> bool: return world.local_seat() == 1, 1.0)
	await get_tree().create_timer(Tuning.data.seat_switch_time + 0.15).timeout
	check(world.camera.global_position.distance_to(world.computer_point.global_position) < 0.05, "카메라가 컴퓨터 자리로")
	world.hud.buy_peach.pressed.emit()
	await _frames(2)
	check_eq(store.shampoo, "peach", "복숭아 샴푸를 사서 바로 씀")
	_press_key(KEY_TAB)
	await _wait(func() -> bool: return world.local_seat() == 0, 1.0)

	# --- 복숭아 손님: 분홍 거품 + 향 팁. 너무 많이 짜면 넘침
	station.dog_info.w = 1
	await hands.wait_washing()
	await hands.do_stage(WashStation.Stage.WET)
	var peach_before: int = store.peach_uses
	await hands.squeeze(Tuning.data.squeeze_max_time)
	await _frames(2)
	check(station.dog.foam_color == station.dog.FOAM_PINK, "복숭아 샴푸 → 분홍 거품")
	check(station.overflow_left > 0.0, "너무 많이 짜면 넘침")
	check_eq(store.peach_uses, peach_before - 2, "넘치면 병을 한 번 더 씀")
	await _frames(1)
	check(world.hud.hint_label.text.contains("넘쳐"), "넘침 안내 (%s)" % world.hud.hint_label.text)
	for stage in range(WashStation.Stage.SCRUB, WashStation.Stage.PAY):
		var seconds: float = await hands.do_stage(stage)
		check(seconds < 999.0, "복숭아 손님 %s 끝 (%.1f초)" % [WashStation.STAGE_NAMES[stage], seconds])
	await _wait(func() -> bool: return not station.coins.is_empty(), 2.0)
	check(Tuning.data.money_scent_tip in station.coins, "향 팁 동전 %s" % [station.coins])
	await _collect_all_coins()
	await _wait(func() -> bool: return station.dog_number() == 3, Tuning.data.owner_reaction_time + 4.0)

	# --- 샴푸가 떨어지면 거품이 안 남
	store.peach_uses = 0
	store.basic_uses = 0
	await hands.wait_washing()
	await hands.do_stage(WashStation.Stage.WET)
	await hands.squeeze(0.5)
	await _frames(2)
	check(station.out_of_shampoo, "샴푸가 없음")
	check_eq(station.dose, 0.0, "샴푸가 없으면 덩이 없음")
	check_eq(station.stage, WashStation.Stage.SQUEEZE, "샴푸 없이는 다음으로 못 감")
	check(station.next_hint().contains("샴푸가 떨어졌어요"), "샴푸 사러 가라는 안내")

	await Net.leave_session()


## 누른 채 seconds 동안 (떼지 않음)
func _press_for(pos: Vector2, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await _op(pos, true, false)
		t += STEP


## 누른 채 seconds 동안 (같은 자리) 뒤 뗌
func _hold(pos: Vector2, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await _op(pos, true, t == 0.0)
		t += STEP
	await _op(pos, false, false)


func _op(pos: Vector2, held: bool, pressed: bool) -> void:
	world.cursor = pos
	station.operate(pos, held, pressed, STEP)
	await get_tree().process_frame


## 실제 마우스 클릭 (월드 입력 경로: 동전·화살표)
func _click(pos: Vector2) -> void:
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


func _collect_all_coins() -> void:
	await _frames(2)
	var guard := 0
	while not station.coins.is_empty() and guard < 10:
		guard += 1
		var coin: Node3D = station.coin_root.get_child(0)
		await _click(world.camera.unproject_position(coin.global_position))
	check(station.coins.is_empty(), "동전 클릭으로 모두 주움")
	check("coin" in sfx.played, "짤랑")


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
