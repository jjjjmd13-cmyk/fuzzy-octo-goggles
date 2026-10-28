extends Node
## 배경음악 (MILESTONE_V3_SLICE 6장): 영업 중에는 bgm_shop 을 반복, 영업이 끝나면 정산 곡 한 번.
## 곡은 assets/music/ (tools/make_music.py 로 합성, CC0 — assets/music/LICENSE.md). 같은 이름으로 바꿔 넣으면 교체.
## 헤드리스(테스트·CI)에서는 틀지 않고 무엇을 틀지만 기록한다 (sfx.gd 와 같은 이유).

const BGM := preload("res://assets/music/bgm_shop.wav")
const JINGLE := preload("res://assets/music/settle_jingle.wav")

## 지금 트는 곡: "bgm" / "jingle" / "" (테스트용)
var playing := ""
var day: Node

var _player: AudioStreamPlayer
var _silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
	var loop: AudioStreamWAV = BGM.duplicate()
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	_player.stream = loop
	add_child(_player)
	set_meta("loop", loop)


func _process(_delta: float) -> void:
	if day == null:
		return
	var want := ""
	if day.day > 0 and not day.closed and not day.morning:
		want = "bgm"
	elif day.closed and playing == "bgm":
		want = "jingle"
	elif playing == "jingle":
		want = "jingle"
	if want != playing:
		_play(want)


func _play(track: String) -> void:
	playing = track
	if _silent:
		return
	match track:
		"bgm":
			_player.stream = get_meta("loop")
			_player.play()
		"jingle":
			_player.stream = JINGLE
			_player.play()
		_:
			_player.stop()


func _exit_tree() -> void:
	if _player != null:
		_player.stop()
