@tool
extends Node3D
## 손으로 배치하는 방 하나 (GDD 9.1 격자: 타일 2 m, 천장 4 m, 문 = 벽 가운데 타일 1개).
##
## 방 노드를 월드에 놓고 크기·문 방향만 고르면 바닥·벽·천장과 충돌을 만든다.
## 겉모습은 scenes/art/tiles/ 의 타일 씬만 쓰므로, 그래픽은 그 씬들만 바꾸면 된다.
## 방의 원점 = 방 바닥 가운데. 북쪽 = -Z.
## 만든 노드는 씬 파일에 저장되지 않는다 (owner 없음).

const TILE := 2.0
const WALL_HEIGHT := 4.0
const WALL_THICKNESS := 0.3
## 문 타일 위치: 벽 타일 중 이 번호 (6타일 벽이면 3번 = 가운데 오른쪽). 이웃한 방과 같은 자리에 맞물린다.
const DOOR_TILE_INDEX := 3

const FLOOR_TILE := preload("res://scenes/art/tiles/floor_tile.tscn")
const WALL_TILE := preload("res://scenes/art/tiles/wall_tile.tscn")
const CEILING_TILE := preload("res://scenes/art/tiles/ceiling_tile.tscn")

@export var size_tiles := Vector2i(6, 6):
	set(value):
		size_tiles = value
		_queue_rebuild()
@export var door_north := false:
	set(value):
		door_north = value
		_queue_rebuild()
@export var door_south := false:
	set(value):
		door_south = value
		_queue_rebuild()
@export var door_east := false:
	set(value):
		door_east = value
		_queue_rebuild()
@export var door_west := false:
	set(value):
		door_west = value
		_queue_rebuild()
@export var build_ceiling := true:
	set(value):
		build_ceiling = value
		_queue_rebuild()
## false 면 남쪽(+Z, 카메라 쪽) 벽 타일을 그리지 않는다. 충돌은 남는다 (위에서 비스듬히 보는 카메라용).
@export var south_wall_visible := true:
	set(value):
		south_wall_visible = value
		_queue_rebuild()

var _generated: Node3D
var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if _generated != null:
		_generated.free()
	_generated = Node3D.new()
	_generated.name = "Generated"
	add_child(_generated)

	var half := Vector2(size_tiles) * TILE * 0.5
	var body := StaticBody3D.new()
	body.name = "Collision"
	_generated.add_child(body)

	for ty in size_tiles.y:
		for tx in size_tiles.x:
			var pos := Vector3(-half.x + (tx + 0.5) * TILE, 0, -half.y + (ty + 0.5) * TILE)
			_add_tile(FLOOR_TILE, pos, 0.0)
			if build_ceiling:
				_add_tile(CEILING_TILE, pos + Vector3(0, WALL_HEIGHT, 0), 0.0)
	_add_box(body, Vector3(0, -0.5, 0), Vector3(half.x * 2, 1, half.y * 2))

	# 벽: 각 변의 바깥선(방 경계)에 바깥 면을 맞추고 안쪽으로 두께만큼 들어온다.
	_build_side(body, Vector3(-half.x, 0, -half.y), Vector3.RIGHT, Vector3.BACK, size_tiles.x, door_north)
	_build_side(body, Vector3(half.x, 0, half.y), Vector3.LEFT, Vector3.FORWARD, size_tiles.x, door_south, south_wall_visible)
	_build_side(body, Vector3(half.x, 0, -half.y), Vector3.BACK, Vector3.LEFT, size_tiles.y, door_east)
	_build_side(body, Vector3(-half.x, 0, half.y), Vector3.FORWARD, Vector3.RIGHT, size_tiles.y, door_west)


## start: 그 변의 시작 모서리, along: 타일이 늘어서는 방향, inward: 방 안쪽 방향.
## 문 번호는 늘어서는 방향과 상관없이 북→남, 서→동 기준으로 센다 (이웃 방과 맞물리게).
func _build_side(body: StaticBody3D, start: Vector3, along: Vector3, inward: Vector3, count: int, has_door: bool, visible_tiles := true) -> void:
	var door_index := -1
	if has_door:
		var reversed := along == Vector3.LEFT or along == Vector3.FORWARD
		door_index = count - 1 - DOOR_TILE_INDEX if reversed else DOOR_TILE_INDEX
	var yaw := atan2(inward.x, inward.z)
	var inset := inward * WALL_THICKNESS * 0.5
	var run_start := 0
	for i in count + 1:
		var is_door := i == door_index
		if i < count:
			var center := start + along * ((i + 0.5) * TILE) + inset
			if visible_tiles:
				_add_tile(WALL_TILE, center + Vector3(0, TILE, 0), yaw)
				if not is_door:
					_add_tile(WALL_TILE, center, yaw)
			else:
				# 문 위 가로대 충돌
				_add_box(body, center + Vector3(0, TILE * 1.5, 0), _box_size(along, TILE))
		if i == count or is_door:
			var length := (i - run_start) * TILE
			if length > 0.0:
				var mid := start + along * ((run_start * TILE) + length * 0.5) + inset
				_add_box(body, mid + Vector3(0, WALL_HEIGHT * 0.5, 0), _box_size(along, length, WALL_HEIGHT))
			run_start = i + 1


func _box_size(along: Vector3, length: float, height: float = TILE) -> Vector3:
	if absf(along.x) > 0.5:
		return Vector3(length, height, WALL_THICKNESS)
	return Vector3(WALL_THICKNESS, height, length)


func _add_tile(scene: PackedScene, pos: Vector3, yaw: float) -> void:
	var tile: Node3D = scene.instantiate()
	tile.position = pos
	tile.rotation.y = yaw
	_generated.add_child(tile)


func _add_box(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)
