extends Node3D
## 들 수 있는 물건 공용 부품 (동물·비누·수건 등). 물건 씬의 루트에 붙인다.
##
## 누가 들고 있는지·바닥 위치는 호스트가 정하고 Sync(권한: 호스트)로 퍼진다.
## 들고 있으면 각 피어가 든 사람의 CarryPoint 에 붙여 그린다 (노드를 옮기지 않음).
## 들기·놓기 판정은 CarryRules(scripts/game/carry_rules.gd)가 한다.
## 손님처럼 스스로 움직이는 물건은 호스트가 ground_position 을 계속 바꾸면 모두에게 따라 그려진다.
## 겉모습은 자식 "Model" 씬만 바꾸면 된다. 바닥이 원점.

signal holder_changed(peer_id: int)

## 화면 안내에 쓰는 이름 ("Space: <이름> 들기")
@export var display_name := "물건"

# --- Sync (호스트 → 모두)
## 들고 있는 피어 ID, 0 = 바닥에 있음
var holder_peer := 0:
	set(value):
		if holder_peer != value:
			holder_peer = value
			holder_changed.emit(value)
var ground_position := Vector3.ZERO
var ground_yaw := 0.0


func _ready() -> void:
	add_to_group("carryables")
	ground_position = position
	ground_yaw = rotation.y


func is_held() -> bool:
	return holder_peer != 0


## 지금 들 수 있는가 (상속해서 바꾼다. 예: 기계 안의 손님은 못 듦).
func can_be_picked() -> bool:
	return not is_held()


## 호스트 전용 알림: 누가 들었다 / 내려놓았다.
func on_picked(_peer_id: int) -> void:
	pass


func on_dropped() -> void:
	pass


## 판정 위치 (바닥 높이). 들고 있으면 든 사람 발밑, 아니면 호스트가 정한 바닥 위치.
func floor_position() -> Vector3:
	var holder := _holder()
	return holder.global_position if holder != null else ground_position


func _process(delta: float) -> void:
	var holder := _holder()
	if holder != null:
		global_transform = holder.get_carry_transform()
	else:
		var t := minf(delta * 15.0, 1.0)
		position = position.lerp(ground_position, t)
		rotation = Vector3(0, lerp_angle(rotation.y, ground_yaw, t), 0)


func _holder() -> Node3D:
	if holder_peer == 0:
		return null
	var world := get_tree().current_scene
	return world.get_player(holder_peer) if world != null and world.has_method("get_player") else null
