extends Node3D
## V4 빗질: 드라이로 털이 뽕 부풀면 몸 곳곳에 엉킨 털 뭉치가 보인다. 빗을 대고 쓸면 뭉치가 줄어들다
## 쓱 풀리며 반짝. 뭉치를 다 풀면 빗질 끝. 강아지 모형(WashDog.model)의 자식이라 강아지와 함께 움직인다.
## 뭉치 모양은 임시 털 덩어리 (진짜 그림이 오면 make_clump 만 바꾸면 됨).

signal untangled(world_point: Vector3)

## 강아지 판정 층 (WashDog.HIT_LAYER)
const DOG_LAYER := 16
const CLUMP_SIZE := 0.07

## 뭉치마다 남은 양 (1 → 0)
var _clumps: Array[MeshInstance3D] = []
var _left: PackedFloat32Array = []
var _total := 0


## 몸 겉면 count 군데에 뭉치를 만든다 (배 밑 제외). center 는 모형 기준 몸 중심
func spawn(dog_model: Node3D, center: Vector3, count: int, rng: RandomNumberGenerator, color: Color) -> void:
	clear()
	var space := dog_model.get_world_3d().direct_space_state
	# 앞쪽 시도에서는 서로 떨어뜨리고, 자리가 모자라면 뒤쪽 시도에서는 붙어도 놓음 (늘 count 개)
	for attempt in count * 16:
		if _clumps.size() >= count:
			break
		var spread := attempt < count * 10
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
		var query := PhysicsRayQueryParameters3D.create(dog_model.to_global(center + dir * 1.5), dog_model.to_global(center), DOG_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var local: Vector3 = to_local(hit.position)
		if spread and _too_close(local):
			continue
		var clump := make_clump(color, rng)
		add_child(clump)
		clump.position = local
		_clumps.append(clump)
		_left.append(1.0)
	_total = _clumps.size()


func clear() -> void:
	for clump in _clumps:
		clump.queue_free()
	_clumps.clear()
	_left.clear()
	_total = 0


## 남은 뭉치 수
func count() -> int:
	return _clumps.size()


## 푼 비율 (0~1, 뭉치가 없으면 1)
func ratio() -> float:
	return 1.0 - float(_clumps.size()) / _total if _total > 0 else 1.0


## 빗을 world_point 에 delta 초 동안 댐: reach(m) 안 뭉치가 rate×delta 만큼 줄고, 다 줄면 풀림. 푼 수
func brush(world_point: Vector3, reach: float, amount: float) -> int:
	var removed := 0
	for i in range(_clumps.size() - 1, -1, -1):
		var clump := _clumps[i]
		if clump.global_position.distance_to(world_point) > reach:
			continue
		_left[i] -= amount
		clump.scale = Vector3.ONE * (0.4 + 0.6 * maxf(_left[i], 0.0))
		if _left[i] <= 0.0:
			untangled.emit(clump.global_position)
			clump.queue_free()
			_clumps.remove_at(i)
			_left.remove_at(i)
			removed += 1
	return removed


## 뭉치 월드 위치 (테스트·화면)
func world_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for clump in _clumps:
		out.append(clump.global_position)
	return out


## 임시 엉킨 털 뭉치: 털색보다 진한 울퉁불퉁 공 (작은 공 몇 개)
static func make_clump(color: Color, rng: RandomNumberGenerator) -> MeshInstance3D:
	var root := MeshInstance3D.new()
	root.name = "Clump"
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.45)
	material.roughness = 1.0
	var ball := SphereMesh.new()
	ball.radius = CLUMP_SIZE * 0.6
	ball.height = CLUMP_SIZE * 1.2
	ball.radial_segments = 8
	ball.rings = 4
	ball.material = material
	root.mesh = ball
	for i in 4:
		var bump := MeshInstance3D.new()
		bump.mesh = ball
		bump.scale = Vector3.ONE * rng.randf_range(0.5, 0.8)
		bump.position = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1), rng.randf_range(-1, 1)) * CLUMP_SIZE * 0.5
		root.add_child(bump)
	return root


func _too_close(local: Vector3) -> bool:
	for clump in _clumps:
		if clump.position.distance_to(local) < CLUMP_SIZE * 2.2:
			return true
	return false
