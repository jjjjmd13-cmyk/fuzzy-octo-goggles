extends "res://tests/qa_test.gd"
## 기본 연출 (MILESTONE_V3_SLICE 6장): 효과음·음악 버스, 영업 중 배경음악 → 영업이 끝나면 정산 곡,
## 음량 설정(효과음/음악, Esc 메뉴, 저장), 단계마다 효과음, 드라이어 털 날림.
## 헤드리스라 실제로 소리는 나지 않고, 무엇을 틀었는지와 버스 값만 본다.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const Settings := preload("res://scripts/core/settings.gd")

var world: Node


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	Settings.path = "user://test_settings.cfg"
	Tuning.data.slice_guests_per_day = PackedInt32Array([1, 1, 1])
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	world.input_enabled = false
	var station: WashStation = world.station
	var sfx: Node = world.sfx

	# --- 버스와 효과음 목록
	check(AudioServer.get_bus_index("SFX") > 0 and AudioServer.get_bus_index("Music") > 0, "효과음·음악 버스")
	for sound in ["ding", "coin", "bell", "clap", "sigh", "squirt", "pour", "press", "bark", "poof"]:
		check(sfx.SOUNDS.has(sound), "효과음 %s" % sound)
	for loop in ["shower", "scrub", "dryer"]:
		check(sfx.LOOPS.has(loop), "이어지는 소리 %s" % loop)
	var players := sfx.find_children("*", "AudioStreamPlayer", false, false)
	check(players.all(func(p: AudioStreamPlayer) -> bool: return p.bus == &"SFX"), "효과음은 SFX 버스")

	# --- 음악: 영업 중 배경음악 → 영업이 끝나면 정산 곡
	await _frames(3)
	check_eq(world.music.playing, "bgm", "영업 중 배경음악")
	await _wait(station.is_washing, 4.0)
	# 드라이어 털 날림
	station.dog.blow_fur(station.dog.model.to_global(station.dog.model.body_center), 1.0)
	check(station.dog._fur.emitting, "드라이어에 털이 날림")
	station.dog.stop_spray()
	while station.stage < WashStation.Stage.PAY:
		station._advance()
		await _frames(1)
	check("poof" in sfx.played and "ding" in sfx.played, "단계 끝 소리 (딩·뽀옹)")
	await _wait(func() -> bool: return not station.coins.is_empty(), 1.0)
	while not station.coins.is_empty():
		station.send_collect(0)
		await _frames(2)
	check("coin" in sfx.played, "동전 짤랑")
	await _wait(func() -> bool: return world.day.closed, 10.0)
	await _frames(2)
	check_eq(world.music.playing, "jingle", "영업이 끝나면 정산 곡")

	# --- 음량 설정: Esc 메뉴 막대 → 버스에 바로, 파일에 저장
	var hud: CanvasLayer = world.hud
	check(hud.sfx_slider != null and hud.music_slider != null, "Esc 메뉴에 효과음·음악 음량")
	hud.sfx_slider.value = 0.5
	hud.music_slider.value = 0.0
	await _frames(1)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var music_bus := AudioServer.get_bus_index("Music")
	check(is_equal_approx(AudioServer.get_bus_volume_db(sfx_bus), linear_to_db(0.5)), "효과음 음량 적용")
	check(AudioServer.is_bus_mute(music_bus), "음악 0 = 끔")
	var config := ConfigFile.new()
	check(config.load(Settings.path) == OK and is_equal_approx(float(config.get_value("audio", "sfx")), 0.5), "음량이 저장됨")
	Settings.set_volumes(0.8, 0.6)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = "user://settings.cfg"


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wait(done: Callable, seconds: float) -> void:
	var left := seconds
	while not done.call() and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
