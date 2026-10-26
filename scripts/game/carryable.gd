extends Node3D
## 들 수 있는 물건 공용 부품 (동물·비누·수건 등). 물건 씬의 루트에 붙인다.
##
## 누가 들고 있는지·바닥 위치는 호스트가 정하고 Sync(권한: 호스트)로 퍼진다.
## 들고 있으면 각 피어가 든 사람의 CarryPoint 에 붙여 그린다 (노드를 옮기지 않음).
## 들기·놓기·건네기 판정은 CarryRules(scripts/game/carry_rules.gd)가 한다.
## 겉모습은 자식 "Model" 씬만 바꾸면 된다. 바닥이 원점.

signal holder_changed(peer_id: int)

## 화면 안내에 쓰는 이름 ("E: <이름> 들기")
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


## 판정 위치 (바닥 높이). 들고 있으면 든 사람 발밑.
func floor_position() -> Vector3:
	var holder := _holder()
	return holder.global_position if holder != null else global_position


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
