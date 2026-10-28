extends RefCounted
## 음량 설정 (MILESTONE_V3_SLICE 6장): 효과음 / 음악, 0~1. user://settings.cfg 에 저장하고
## 오디오 버스(default_bus_layout.tres 의 SFX·Music)에 바로 적용한다.

static var path := "user://settings.cfg"
static var sfx_volume := 0.8
static var music_volume := 0.6
static var _loaded := false


## 처음 한 번 파일에서 읽고 버스에 적용
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(path) == OK:
		sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
		music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
	apply()


static func set_volumes(sfx: float, music: float) -> void:
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	apply()
	var config := ConfigFile.new()
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "music", music_volume)
	config.save(path)


static func apply() -> void:
	_set_bus("SFX", sfx_volume)
	_set_bus("Music", music_volume)


static func _set_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))
