extends Node
## 효과음. 파일은 assets/sfx/<이름>.wav — 같은 이름으로 바꿔 넣으면 교체된다.
## 지금 소리는 tools/make_sfx.py 로 만든 임시 소리 (외부 파일 없음).
## 계속 나는 소리(샤워기·문지르기·드라이어)는 set_loop(이름, 크기) 로 켜고 끈다. 크기 0 = 끔.

const SOUNDS := {
	"ding": preload("res://assets/sfx/ding.wav"),  # 단계 끝
	"poof": preload("res://assets/sfx/poof.wav"),  # 뽀송 (다 말림)
	"splat": preload("res://assets/sfx/splat.wav"),  # 진흙 강아지 올라옴
	"drip": preload("res://assets/sfx/drip.wav"),  # 진흙 물 흘러내림
	"bubble_pop": preload("res://assets/sfx/bubble_pop.wav"),  # 샴푸 짜기
	"squeak": preload("res://assets/sfx/squeak.wav"),  # 뽀득 (헹구기 끝)
	"towel": preload("res://assets/sfx/towel.wav"),  # 북북
	"coin": preload("res://assets/sfx/coin.wav"),  # 짤랑
	"yelp": preload("res://assets/sfx/yelp.wav"),  # 차가운 물에 펄쩍
	"shake": preload("res://assets/sfx/shake.wav"),  # 몸 털기
	"huff": preload("res://assets/sfx/huff.wav"),  # 기분 나쁨 (눈에 물, 드라이어 뜨거움)
	"squirt": preload("res://assets/sfx/squirt.wav"),  # 샴푸 병 짜기
	"pour": preload("res://assets/sfx/pour.wav"),  # 바가지 물 쏟기
	"press": preload("res://assets/sfx/press.wav"),  # 수건 꾹
	"clap": preload("res://assets/sfx/clap.wav"),  # 주인 박수 (😊)
	"sigh": preload("res://assets/sfx/sigh.wav"),  # 주인 한숨 (😣)
	"whine": preload("res://assets/sfx/whine.wav"),  # 강아지가 주인을 보며 낑낑
	"bark": preload("res://assets/sfx/bark.wav"),  # 주인에게 달려감
}
const LOOPS := {
	"shower": preload("res://assets/sfx/shower.wav"),  # 쏴아
	"scrub": preload("res://assets/sfx/scrub.wav"),  # 뽀글뽀글 (손 빠르기에 따라 크게)
	"dryer": preload("res://assets/sfx/dryer.wav"),  # 위잉
}

## 테스트·디버그용: 지금까지 울린 한 번짜리 소리 이름 (순서대로)
var played: PackedStringArray = []
## 반복 소리 이름 → 지금 크기 (0~1)
var loop_volume := {}

var _players: Array[AudioStreamPlayer] = []
var _loops := {}
## 헤드리스(테스트·CI)에서는 소리를 실제로 틀지 않고 기록만 한다. 소리 장치가 없는 더미 드라이버에서
## 재생 중에 끝내면 재생 객체가 남았다는 오류가 찍혀 테스트가 실패로 보이기 때문이다.
var _silent := DisplayServer.get_name() == "headless"


func _ready() -> void:
	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for sound in LOOPS:
		var stream: AudioStreamWAV = LOOPS[sound].duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		var player := AudioStreamPlayer.new()
		player.stream = stream
		add_child(player)
		_loops[sound] = player
		loop_volume[sound] = 0.0


func play(sound: String) -> void:
	if not SOUNDS.has(sound):
		push_warning("모르는 효과음: %s" % sound)
		return
	played.append(sound)
	if _silent:
		return
	for player in _players:
		if not player.playing:
			player.stream = SOUNDS[sound]
			player.play()
			return
	_players[0].stream = SOUNDS[sound]
	_players[0].play()


func set_loop(sound: String, volume: float) -> void:
	var player: AudioStreamPlayer = _loops[sound]
	loop_volume[sound] = volume
	if _silent:
		return
	if volume <= 0.01:
		if player.playing:
			player.stop()
		return
	player.volume_db = linear_to_db(clampf(volume, 0.05, 1.0))
	if not player.playing:
		player.play()


## 씬을 나갈 때 울리던 소리를 멈춘다 (안 멈추면 종료 때 재생 객체가 남았다는 오류가 찍힘).
func _exit_tree() -> void:
	for player in get_children():
		(player as AudioStreamPlayer).stop()
		(player as AudioStreamPlayer).stream = null
