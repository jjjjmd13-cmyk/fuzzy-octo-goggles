extends Node3D
## 대기 의자 (MILESTONE_V3_SLICE 1장): 목욕대가 차 있을 때 온 주인 손님이 앉아 기다리는 곳.
## 의자가 꽉 차면 문밖에 서서 줄을 선다. 기다림은 몸짓으로 보인다 (시계 보기 → 발 구르기 → 시무룩).
## 남은 참을성은 HUD 가 머리 위에 그린다. 대기 손님은 강아지를 안고 있다 (손님인 줄 알아보게).
##
## 대기열은 ShopDay(호스트)가 정하고 동기화한다. 이 스크립트는 그걸 읽어 주인 모형을 놓기만 한다 (화면 전용).
## 위치는 모두 목욕대(부모) 기준. 의자 모형은 목욕대 옆 의자와 같은 교체 씬(chair_model.tscn).

const OWNER_SCENE := preload("res://scenes/art/sim/owner_model.tscn")
const CHAIR_SCENE := preload("res://scenes/art/sim/chair_model.tscn")
const DOG_SCENE := preload("res://scenes/art/sim/dog_model.tscn")
## 안은 강아지 크기와 자리 (주인 기준: 앉으면 무릎 위, 서면 가슴 앞)
const HELD_DOG_SCALE := 0.7
const HELD_ON_LAP := Vector3(0, 0.5, 0.22)
const HELD_STANDING := Vector3(0, 0.82, 0.26)
## 대기 의자 (앞에서부터). 의자 수는 slice_queue_seats 만큼 앞에서부터 씀
## (화면 왼쪽 HUD 에 덜 가리게 안쪽·뒤쪽으로, QA #45 리뷰)
const SEATS: Array[Vector3] = [Vector3(-1.08, 0, -0.78), Vector3(-1.46, 0, -0.78), Vector3(-1.84, 0, -0.78), Vector3(-2.22, 0, -0.78)]
## 의자가 꽉 차면 서서 기다리는 곳 (문 쪽으로 늘어섬)
const LINE_START := Vector3(-2.2, 0, 0.0)
const LINE_STEP := Vector3(-0.15, 0, 0.45)
## 왼쪽 문 (대기 손님이 들어오고 떠나는 곳)
const DOOR := Vector3(-2.9, 0, 1.3)
## 대기 의자에서 목욕통 옆으로 갈 때 목욕통 뒤로 돌아가는 길
const AROUND_TUB: Array[Vector3] = [Vector3(-0.9, 0, -0.85), Vector3(0.9, 0, -0.85)]
const WALK_SPEED := 1.4
## 대기열에서 빠진 손님이 목욕대로 갔는지 볼 시간 (두 동기화가 다른 프레임에 올 수 있음)
const HANDOFF_GRACE := 0.5

## 손님 번호 → 주인 모형
var owners := {}
var day: Node

@onready var station: Node3D = get_parent()

## 손님 번호 → 대기열에서 빠진 뒤 지난 시간
var _gone := {}
## 손님 번호 → 지금 가 있는 자리 번호
var _spot := {}


func _ready() -> void:
	# 의자 방향은 목욕대 옆 의자(Chair)와 같은 방식으로: 앉은 사람이 목욕통을 보게
	var side_chair := station.get_node_or_null("Chair") as Node3D
	var offset := 0.0
	if side_chair != null:
		offset = side_chair.rotation.y - _yaw_to(side_chair.position, Vector3.ZERO)
	for i in mini(Tuning.data.slice_queue_seats, SEATS.size()):
		var chair := CHAIR_SCENE.instantiate() as Node3D
		chair.name = "Chair_%d" % (i + 1)
		add_child(chair)
		chair.position = SEATS[i]
		chair.rotation.y = _yaw_to(SEATS[i], Vector3.ZERO) + offset


## 대기열 index 번째 자리 (목욕대 기준)
func spot_position(index: int) -> Vector3:
	var seats := mini(Tuning.data.slice_queue_seats, SEATS.size())
	if index < seats:
		return SEATS[index]
	return LINE_START + LINE_STEP * (index - seats)


func is_seat(index: int) -> bool:
	return index < mini(Tuning.data.slice_queue_seats, SEATS.size())


## 대기 의자 첫 자리에서 목욕통 옆으로 가는 길 (WashStation 이 씀)
func path_to_tub() -> Array:
	return AROUND_TUB.duplicate()


func _process(delta: float) -> void:
	if day == null:
		return
	var ids: PackedInt32Array = day.queue_ids
	for i in ids.size():
		var guest := ids[i]
		_gone.erase(guest)
		var owner: Node3D = owners.get(guest)
		if owner == null:
			owner = OWNER_SCENE.instantiate()
			add_child(owner)
			owner.global_position = station.to_global(DOOR)
			if i < day.queue_variants.size():
				owner.set_variant(day.queue_variants[i])
			owners[guest] = owner
			# 강아지 모형은 뛰기 때문에 스스로 높이를 바꾼다. 받침 노드에 넣어 받침을 옮긴다
			var holder := Node3D.new()
			holder.name = "HeldDog"
			holder.scale = Vector3.ONE * HELD_DOG_SCALE
			owner.add_child(holder)
			var held := DOG_SCENE.instantiate() as Node3D
			# 안은 강아지는 보이기만 한다 (클릭 판정 모양 없음)
			held.set("auto_hit_shapes", false)
			holder.add_child(held)
			owner.holding = true
		if _spot.get(guest, -1) != i:
			_spot[guest] = i
			var target := station.to_global(spot_position(i))
			owner.go_wait(target, station.global_position, owner.global_position.distance_to(target) / WALK_SPEED, is_seat(i))
		owner.wait_level = _wait_level(day.patience_ratio(i))
		var held_dog := owner.get_node_or_null("HeldDog") as Node3D
		if held_dog != null:
			held_dog.position = HELD_ON_LAP if owner.is_sitting() else HELD_STANDING
	# 대기열에서 빠진 손님: 목욕대로 갔으면 (목욕대 주인 모형이 이어받음) 지우고, 아니면 문으로 나감
	for guest in owners.keys():
		if guest in ids:
			continue
		var owner: Node3D = owners[guest]
		if station.dog_number() == guest:
			_drop(guest)
			continue
		var gone: float = _gone.get(guest, 0.0)
		_gone[guest] = gone + delta
		if gone == 0.0:
			continue
		if gone < HANDOFF_GRACE and gone + delta >= HANDOFF_GRACE:
			var door := station.to_global(DOOR)
			owner.leave(door, owner.global_position.distance_to(door) / WALK_SPEED)
		elif gone > HANDOFF_GRACE + 4.0:
			_drop(guest)


func _drop(guest: int) -> void:
	var owner: Node3D = owners[guest]
	owners.erase(guest)
	_gone.erase(guest)
	_spot.erase(guest)
	owner.queue_free()


## 기다린 비율 → 몸짓 (0 가만히 / 1 시계 보기 / 2 발 구르기 / 3 시무룩)
static func _wait_level(ratio: float) -> int:
	if ratio >= 0.85:
		return 3
	if ratio >= 0.65:
		return 2
	if ratio >= 0.4:
		return 1
	return 0


static func _yaw_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z)
