extends "res://tests/qa_test.gd"
## 처음 하는 사람용 안내 (MILESTONE_V3_SLICE 7장):
## 1일차 첫 손님에서만 단계마다 손동작 그림, 둘째 손님부터는 없음 / 첫 정산 뒤 쇼핑 화살표 한 번 /
## F1 조작 그림 / 메뉴 → 1일차까지 클릭 1번 (새로 하기).

const WashStation := preload("res://scripts/sim/wash_station.gd")
const SaveGame := preload("res://scripts/core/save_game.gd")
const UiArt := preload("res://scripts/game/ui_art.gd")

var world: Node
var station: WashStation


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	var data: Resource = Tuning.data
	data.slice_guests_per_day = PackedInt32Array([2, 2, 2])
	data.proto_owner_arrive_time = 0.4
	data.owner_reaction_time = 0.4
	data.proto_owner_leave_time = 0.4
	SaveGame.path = "user://test_guide_save.json"
	SaveGame.erase()

	# --- 메뉴에서 클릭 한 번으로 1일차
	get_tree().current_scene = null
	await Net.leave_session()
	await _frames(2)
	var menu: Node = get_tree().current_scene
	check(not menu.continue_button.visible, "저장이 없으면 이어하기 없음")
	menu.solo_button.pressed.emit()
	await Net.session_started
	world = get_tree().current_scene
	world.input_enabled = false
	station = world.station
	var guide: Control = world.hud.guide
	check_eq(world.day.day, 1, "클릭 한 번으로 1일차 영업 (설명 화면 없음)")

	# --- 첫 손님: 단계마다 손동작 그림
	await _wait(station.is_washing, 3.0)
	await _frames(2)
	check_eq(guide.gesture_stage, WashStation.Stage.WET, "첫 단계 손동작 그림 (적시기)")
	check_eq(guide.GESTURE_TIME, 4.5, "안내는 기존의 4.5초")
	# 실제 시간으로 닫힘/같은 단계에서 재등장하지 않음 검사.
	await get_tree().create_timer(4.6).timeout
	check_eq(guide.gesture_stage, -1, "4.5초 뒤 안내 종료")
	await _frames(3)
	check_eq(guide.gesture_stage, -1, "같은 단계에서 안내가 되살아나지 않음")
	for stage in range(6):
		if stage > 0:
			station._advance()
			await _frames(2)
			check_eq(guide.gesture_stage, stage, "단계가 바뀌면 새 그림 %d" % stage)
			check(guide._gesture_t < 0.5, "단계마다 시범이 처음부터 시작 %d" % stage)
		var picture: Texture2D = UiArt.texture(guide.HINT_ART[stage])
		if check(picture != null, "정식 손동작 PNG 로드 %d" % stage):
			check_eq(picture.get_size(), Vector2(512, 512), "512px PNG %d" % stage)
		check(UiArt.texture(guide.TOOL_ART[stage]) != null, "기존 도구 그림 재사용 %d" % stage)
	check(guide.CAPTIONS[WashStation.Stage.SQUEEZE].length() <= 20, "글자는 한 줄")
	await _finish_guest()
	# --- 둘째 손님: 그림 없음
	await _wait(station.is_washing, 4.0)
	await _frames(2)
	check_eq(guide.gesture_stage, -1, "둘째 손님부터는 손동작 그림 없음")
	await _finish_guest()

	# --- 첫 정산 뒤 쇼핑 화살표, 컴퓨터 자리에 한 번 가면 사라짐
	await _wait(func() -> bool: return world.day.closed, world.day.FAST_FORWARD_TIME + 3.0)
	await _frames(2)
	check(guide.shop_arrow, "첫 정산 뒤 쇼핑 화살표")
	world.hud.settle_shop_button.pressed.emit()
	await _wait(func() -> bool: return world.local_seat() == 1, 1.0)
	await _frames(2)
	check(not guide.shop_arrow and guide.shop_arrow_done, "컴퓨터 자리에 가면 화살표 끝")
	# 컴퓨터에 안 가고 다음 날로 넘어가도 화살표는 끝 (이슈 #64)
	guide.shop_arrow_done = false
	world.switch_seat()
	await _wait(func() -> bool: return world.local_seat() == 0, 1.0)
	await _frames(2)
	check(guide.shop_arrow, "(다시) 정산 화살표")
	world.day.send_next_day()
	await _frames(3)
	check(not guide.shop_arrow, "다음 날 아침이 되면 쇼핑 화살표 끔")
	world.day.send_open()
	await _wait(station.is_washing, 4.0)
	await _frames(2)
	check(world.day.day == 2 and station.is_washing() and world.day.guest_number_today(station.dog_number()) == 1, "2일차 첫 손님이 실제로 목욕 중")
	check_eq(guide.gesture_stage, -1, "2일차 첫 손님도 안내 없음")
	check_eq(world.hud.status_label.text, "F1: 조작 그림", "1인용: 플레이어 수 줄 없음")

	# --- F1 조작 그림
	var f1 := InputEventAction.new()
	f1.action = "toggle_help"
	f1.pressed = true
	world.hud._unhandled_input(f1)
	check(guide.help_visible, "F1 → 조작 그림")
	world.hud._unhandled_input(f1)
	check(not guide.help_visible, "F1 다시 → 닫힘")
	SaveGame.erase()
	SaveGame.path = "user://slice_save.json"


func _finish_guest() -> void:
	await _wait(station.is_washing, 3.0)
	while station.stage < WashStation.Stage.PAY:
		station._advance()
		await _frames(1)
	await _wait(func() -> bool: return not station.coins.is_empty(), 1.0)
	while not station.coins.is_empty():
		station.send_collect(0)
		await _frames(2)
	await _wait(func() -> bool: return station.owner_phase == WashStation.OwnerPhase.EMPTY, 3.0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(done: Callable, seconds: float) -> void:
	var left := seconds
	while not done.call() and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
