extends Node3D
## 기계 (시제품: 욕조·드라이어). 손님을 넣으면 저절로 돌아가고, 다 되면 꺼낼 수 있다.
## 상태는 호스트가 정해 Sync 로 퍼진다. 겉모습은 자식 "Model", 진행 막대는 "Progress", 다 됨 표시는 "Done".

enum Kind { BATH, DRYER }

const Guest := preload("res://scripts/game/guest.gd")

@export var kind: Kind = Kind.BATH
@export var display_name := "욕조"

# --- Sync (호스트 → 모두)
## 안에 있는 손님 노드 이름 ("" = 비었음)
var occupant := ""
var time_left := 0.0
var done := false

@onready var slot: Node3D = $Slot
@onready var progress: Node3D = $Progress
@onready var done_mark: Node3D = $Done


func _ready() -> void:
	add_to_group("machines")


func duration() -> float:
	return Tuning.data.machine_bath_time if kind == Kind.BATH else Tuning.data.machine_dryer_time


func accepts(guest: Node) -> bool:
	if not occupant.is_empty():
		return false
	return guest.state == (Guest.State.MUDDY if kind == Kind.BATH else Guest.State.WET)


func is_running() -> bool:
	return not occupant.is_empty() and not done


func get_occupant() -> Node:
	return get_parent().get_parent().get_node("Guests").get_node_or_null(occupant) if not occupant.is_empty() else null


## 호스트 전용
func load_guest(guest: Node) -> void:
	occupant = guest.name
	time_left = duration()
	done = false
	guest.holder_peer = 0
	guest.machine = self
	guest.phase = Guest.Phase.IN_MACHINE
	guest.ground_position = slot.global_position
	guest.ground_yaw = slot.global_rotation.y
	if kind == Kind.BATH:
		guest.state = Guest.State.FOAM


## 호스트 전용: 손님을 꺼낸다 (들거나, 화나서 나가거나).
func release() -> Node:
	var guest := get_occupant()
	occupant = ""
	done = false
	time_left = 0.0
	if guest != null:
		guest.machine = null
	return guest


func _physics_process(delta: float) -> void:
	_update_visual()
	if not Net.is_host() or not is_running():
		return
	var guest := get_occupant()
	if guest == null:
		release()
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		done = true
		guest.state = Guest.State.WET if kind == Kind.BATH else Guest.State.DRY
		get_parent().get_parent().get_node("Shop").on_machine_done(self, guest)


func _update_visual() -> void:
	var running := is_running()
	progress.visible = running
	if running:
		progress.scale.x = maxf(1.0 - time_left / duration(), 0.02)
	done_mark.visible = done
