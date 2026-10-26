extends Node3D
## 플레이어 (V3 작업대 시점): 걸어 다니지 않고 작업대 자리(seat)에 앉아 일한다.
##
## 노드 이름 = 조종하는 피어 ID. 자리(seat)는 본인이 정하고 ClientSync 로 다른 피어에게 보낸다.
## 호스트는 자리를 보고 목욕대 작업자를 정한다 (WashStation._update_operator).
## 몸(모형)은 가게 한쪽 스폰 지점에 서 있는 표시용이다. 겉모습은 ModelPivot/Model 씬에만 있다.

enum Seat { BATH, COMPUTER }

const PLAYER_COLORS: Array[Color] = [
	Color(0.95, 0.55, 0.2), Color(0.3, 0.65, 0.95), Color(0.45, 0.85, 0.4), Color(0.9, 0.4, 0.75),
]

## 플레이어 번호(0부터, 빈 자리 순서). 호스트가 정해 스폰 데이터로 보낸다. 색 고르기에 쓴다.
@export var slot := 0:
	set(value):
		slot = value
		_apply_color()

# --- ClientSync (조종하는 피어가 씀)
var seat := Seat.BATH

@onready var model_pivot: Node3D = $ModelPivot


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	add_to_group("players")
	_apply_color()


func get_peer_id() -> int:
	return name.to_int()


func set_seat(value: int) -> void:
	if is_multiplayer_authority():
		seat = value as Seat


func _apply_color() -> void:
	if not is_node_ready():
		return
	var model := model_pivot.get_node_or_null("Model")
	if model != null and model.has_method("set_player_color"):
		model.set_player_color(PLAYER_COLORS[slot % PLAYER_COLORS.size()])
