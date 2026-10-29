extends "res://tests/qa_test.gd"
## 실제 게임/GuideOverlay를 렌더링한다. --headless 불가 (Xvfb + GL 가능).
## godot --path . --rendering-method gl_compatibility tools/art/capture_bath_hints.tscn -- --output=/abs/path
## 단계는 _advance()로 넘긴다. 마우스로 목욕을 완료하는 검사는 test_wash_flow/pace가 담당한다.

const UiArt := preload("res://scripts/game/ui_art.gd")
const SaveGame := preload("res://scripts/core/save_game.gd")
const NAMES := ["wet", "squeeze", "scrub", "rinse", "towel", "dry"]
const CARD := Rect2i(428, 72, 424, 180)
const MOTION := Rect2i(650, 108, 194, 102)
var output := "res://docs/dev/screenshots/bath-hints"


func run_test() -> void:
	time_limit_sec = 180.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	check_eq(DirAccess.make_dir_recursive_absolute(output.path_join("frames")), OK, "출력 폴더")
	get_tree().root.size = Vector2i(1280, 800)
	SaveGame.path = "user://capture_bath_hints.json"
	SaveGame.erase()
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	var world: Node = get_tree().current_scene
	world.input_enabled = false
	var station: Node = world.station
	while not station.is_washing():
		await get_tree().process_frame
	world.set_process(false)
	world.day.set_process(false)
	station.set_process(false)
	station.owner_model.go_sit(station.to_global(station.OWNER_CHAIR), station.global_position, 0.1)
	await get_tree().create_timer(0.2).timeout
	var guide: Control = world.hud.guide
	for stage in range(6):
		if stage > 0:
			# 촬영용으로 이전 단계 마스크를 채우고 다음 단계로 넘긴다.
			var previous_channel: String = station.STAGE_CHANNEL[stage - 1]
			if not previous_channel.is_empty():
				station.dog.mask.fill(previous_channel, 1.0)
			station._advance()
		if stage == 2:
			station.dose = 0.5
		# station의 진행을 멈췄으므로 평소 _process가 하는 도구 갱신을 호출.
		station._on_stage_changed()
		station.dog.show_mask()
		for i in 2:
			await get_tree().process_frame
		check_eq(guide.gesture_stage, stage, "실제 단계 안내 %d" % stage)
		check(UiArt.texture(guide.HINT_ART[stage]) != null, "PNG를 로드한 상태 %d" % stage)
		var first: Image
		for frame in range(12):
			await get_tree().create_timer(0.10).timeout
			var rendered := await _frame()
			if not check(rendered != null and not rendered.is_empty(), "실제 렌더 프레임"):
				return
			_save(rendered.get_region(CARD), "frames/%s_%02d.png" % [NAMES[stage], frame])
			if frame == 0:
				first = rendered.get_region(MOTION)
			if frame == 4:
				_save(rendered, "game_" + NAMES[stage] + ".png")
				var changed := _changed_pixels(first, rendered.get_region(MOTION))
				check(changed > 30, "PNG가 있어도 시범이 움직임 %s (%d pixels)" % [NAMES[stage], changed])
				print("MOTION_PIXELS %s %d" % [NAMES[stage], changed])
		check(guide.gesture_left > 0, "캡처 중 안내가 유지됨 %d" % stage)
		# PNG 하나를 찾지 못하는 경우도 같은 실제 렌더러로 검사.
		guide.set_process(false)
		var picture: Texture2D = UiArt.texture(guide.HINT_ART[stage])
		UiArt._cache[guide.HINT_ART[stage]] = null
		guide._gesture_t = 0.1
		guide.queue_redraw()
		var fallback_a := await _frame()
		# 수건은 0.4초 반복: 0.1/0.9는 같은 위상이므로 누름/뗌을 비교한다.
		guide._gesture_t = 0.3 if stage == 4 else 0.9
		guide.queue_redraw()
		var fallback_b := await _frame()
		var fallback_motion := Rect2i(562, 108, 160, 102)
		var changed := _changed_pixels(fallback_a.get_region(fallback_motion), fallback_b.get_region(fallback_motion))
		check(changed > 30, "PNG 누락 시 움직이는 대체 그림 %s" % NAMES[stage])
		print("FALLBACK_PIXELS %s %d" % [NAMES[stage], changed])
		if stage == 2:
			_save(fallback_b, "game_fallback_scrub.png")
		UiArt._cache[guide.HINT_ART[stage]] = picture
		guide.set_process(true)
	# 컴퓨터 자리에서는 카드가 안 그려지는지 렌더 결과로 비교.
	world.switch_seat()
	for i in 5:
		await get_tree().process_frame
	guide.set_process(false)
	guide.gesture_stage = 5
	guide.gesture_left = 4.5
	guide.queue_redraw()
	var hidden := await _frame()
	guide.gesture_stage = -1
	guide.queue_redraw()
	var no_gesture := await _frame()
	check_eq(_changed_pixels(hidden.get_region(CARD), no_gesture.get_region(CARD)), 0, "컴퓨터 자리에 안내가 그려지지 않음")
	SaveGame.erase()
	SaveGame.path = "user://slice_save.json"
	await Net.leave_session()
	print("BATH_HINT_CAPTURE_COMPLETE")


func _frame() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_tree().root.get_texture().get_image()


func _save(image: Image, name: String) -> void:
	check_eq(image.save_png(output.path_join(name)), OK, "PNG 저장 " + name)


## 반투명 판 뒤 배경의 미세한 변화는 제외하고 실제 도구/경로 이동을 판정.
func _changed_pixels(a: Image, b: Image) -> int:
	var changed := 0
	for y in a.get_height():
		for x in a.get_width():
			var delta := a.get_pixel(x, y) - b.get_pixel(x, y)
			if maxf(absf(delta.r), maxf(absf(delta.g), absf(delta.b))) > 0.15:
				changed += 1
	return changed
