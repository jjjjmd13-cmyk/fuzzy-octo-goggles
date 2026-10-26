extends Node
## 효과음 (GDD_V2 4장 완료 조건 10). 파일은 assets/sfx/<이름>.wav — 같은 이름으로 바꿔 넣으면 교체된다.
## 지금 소리는 tools/make_sfx.py 로 만든 임시 소리 (외부 파일 없음).

const SOUNDS := {
	"splat": preload("res://assets/sfx/splat.wav"),  # 철퍽: 진흙 손님 도착
	"bubble_pop": preload("res://assets/sfx/bubble_pop.wav"),  # 뽀글 → 펑: 욕조 끝
	"drip": preload("res://assets/sfx/drip.wav"),  # 뚝뚝: 젖은 손님이 몸을 털 때
	"poof": preload("res://assets/sfx/poof.wav"),  # 뽀옹: 드라이어 끝, 털이 부풂
	"ding": preload("res://assets/sfx/ding.wav"),  # 띵: 손님 보냄
	"huff": preload("res://assets/sfx/huff.wav"),  # 흥: 화나서 나감
	"slip": preload("res://assets/sfx/slip.wav"),  # 미끄러짐
}

## 테스트·디버그용: 지금까지 울린 소리 이름 (순서대로)
var played: PackedStringArray = []

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(sound: String) -> void:
	if not SOUNDS.has(sound):
		push_warning("모르는 효과음: %s" % sound)
		return
	played.append(sound)
	for player in _players:
		if not player.playing:
			player.stream = SOUNDS[sound]
			player.play()
			return
	_players[0].stream = SOUNDS[sound]
	_players[0].play()
