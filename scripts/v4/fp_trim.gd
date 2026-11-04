extends Node3D
## V4 미용 (요청 손님만): 빗질이 끝나면 몸 곳곳에 긴 털 다발이 보인다 (자를 곳은 분홍빛). 요청 모양에서 "자를 곳" 다발만
## 가위로 사각사각 자르면 털 조각이 떨어지고 모양이 남는다. 다른 곳을 자르면 모양이 덜 비슷해짐 (팁이 줄어듦).
## 강아지 모형(WashDog.model)의 자식. 다발 모양은 임시 털 덩어리 (그림이 오면 make_tuft 만 바꿈).

signal snipped(world_point: Vector3, wanted: bool)

const DOG_LAYER := 16
const TUFT_SIZE := 0.06
## 모양: 이름, 한 줄 설명, 자를 곳 (부위). 부위는 head 머리 / body 몸 / legs 다리 / tail 꼬리
const SHAPES := {
	"bear": {"name": "곰돌이컷", "about": "얼굴을 둥글게", "cut": ["head"]},
	"lion": {"name": "사자컷", "about": "몸은 짧게, 머리·꼬리는 남김", "cut": ["body", "legs"]},
	"summer": {"name": "여름컷", "about": "다 짧게, 다리만 보송", "cut": ["head", "body", "tail"]},
}
## 부위마다 다발을 놓을 방향 (모형 기준, 정면 +Z) 과 수
const ZONES := {
	"head": {"dir": Vector3(0, 0.75, 0.65), "count": 3},
	"body": {"dir": Vector3(0, 0.55, -0.85), "count": 4},
	# 다리는 앞에서 (아래에서 쏘면 배 밑에 붙어 위에서 안 보임)
	"legs": {"dir": Vector3(0, -0.3, 0.95), "count": 3},
	"tail": {"dir": Vector3(0, 0.1, -1.0), "count": 2},
}

## 요청 모양 ("" = 요청 없음)
var shape := ""

var _tufts: Array[MeshInstance3D] = []
var _left: PackedFloat32Array = []
var _wanted_total := 0
var _wanted_cut := 0
var _unwanted_cut := 0


## 요청 모양으로 다발을 만든다. center 는 모형 기준 몸 중심
func spawn(shape_id: String, dog_model: Node3D, center: Vector3, rng: RandomNumberGenerator, color: Color) -> void:
	clear()
	shape = shape_id
	var space := dog_model.get_world_3d().direct_space_state
	var cut: Array = SHAPES[shape].cut
	for zone in ZONES:
		var placed := 0
		for attempt in ZONES[zone].count * 12:
			if placed >= ZONES[zone].count:
				break
			var base: Vector3 = ZONES[zone].dir
			var dir := (base + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.25, 0.25), rng.randf_range(-0.2, 0.2))).normalized()
			var query := PhysicsRayQueryParameters3D.create(dog_model.to_global(center + dir * 1.5), dog_model.to_global(center), DOG_LAYER)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				continue
			if _place(zone, to_local(hit.position), center, cut, color, rng):
				placed += 1
	# 강아지가 몸짓하는 중이면 어떤 부위는 광선이 빗나가 모자랄 수 있음 → 몸 전체에서 채우고 부위는 가까운 쪽으로
	var want := 0
	for zone in ZONES:
		want += ZONES[zone].count
	for attempt in want * 20:
		if _tufts.size() >= want:
			break
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
		var query := PhysicsRayQueryParameters3D.create(dog_model.to_global(center + dir * 1.5), dog_model.to_global(center), DOG_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var nearest := ""
		for zone in ZONES:
			if nearest.is_empty() or dir.dot(ZONES[zone].dir.normalized()) > dir.dot(ZONES[nearest].dir.normalized()):
				nearest = zone
		_place(nearest, to_local(hit.position), center, cut, color, rng)
	_wanted_total = 0
	for tuft in _tufts:
		if tuft.get_meta("wanted"):
			_wanted_total += 1


func clear() -> void:
	for tuft in _tufts:
		tuft.queue_free()
	_tufts.clear()
	_left.clear()
	shape = ""
	_wanted_total = 0
	_wanted_cut = 0
	_unwanted_cut = 0


## 아직 안 자른 "자를 곳" 다발 수
func wanted_left() -> int:
	return _wanted_total - _wanted_cut


func wanted_total() -> int:
	return _wanted_total


## 요청 모양과 비슷한 정도 (0~1): 자를 곳을 자른 비율에서 잘못 자른 만큼 뺌
func match_score() -> float:
	if _wanted_total == 0:
		return 1.0
	return clampf((float(_wanted_cut) - _unwanted_cut * 0.5) / _wanted_total, 0.0, 1.0)


## 가위를 world_point 에 댐: reach(m) 안 다발이 amount 만큼 줄고, 다 줄면 잘림. 자른 수
func snip(world_point: Vector3, reach: float, amount: float) -> int:
	var cut := 0
	for i in range(_tufts.size() - 1, -1, -1):
		var tuft := _tufts[i]
		if tuft.global_position.distance_to(world_point) > reach:
			continue
		_left[i] -= amount
		tuft.scale = Vector3(1.0, 0.3 + 0.7 * maxf(_left[i], 0.0), 1.0)
		if _left[i] <= 0.0:
			var wanted: bool = tuft.get_meta("wanted")
			if wanted:
				_wanted_cut += 1
			else:
				_unwanted_cut += 1
			snipped.emit(tuft.global_position, wanted)
			tuft.queue_free()
			_tufts.remove_at(i)
			_left.remove_at(i)
			cut += 1
	return cut


## 다발 월드 위치 (wanted: true = 자를 곳만, false = 남길 곳만)
func world_positions(wanted: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	for tuft in _tufts:
		if tuft.get_meta("wanted") == wanted:
			out.append(tuft.global_position)
	return out


## 임시 긴 털 다발: 털색 길쭉한 캡슐 몇 개 (몸 바깥으로 뻗음)
static func make_tuft(color: Color, rng: RandomNumberGenerator) -> MeshInstance3D:
	var root := MeshInstance3D.new()
	root.name = "Tuft"
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var strand := CapsuleMesh.new()
	strand.radius = TUFT_SIZE * 0.25
	strand.height = TUFT_SIZE * 1.6
	strand.radial_segments = 6
	strand.rings = 2
	strand.material = material
	for i in 4:
		var piece := MeshInstance3D.new()
		piece.mesh = strand
		piece.position = Vector3(rng.randf_range(-1, 1), 0.5, rng.randf_range(-1, 1)) * TUFT_SIZE * 0.5
		piece.rotation = Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		root.add_child(piece)
	return root


## 다발 하나 놓기 (다른 다발과 너무 가까우면 안 놓고 false)
func _place(zone: String, local: Vector3, center: Vector3, cut: Array, color: Color, rng: RandomNumberGenerator) -> bool:
	if _too_close(local):
		return false
	# 자를 곳은 요청 카드처럼 분홍빛, 남길 곳은 털색보다 조금 진하게 (흰 털 위에서도 보이게)
	var wanted: bool = zone in cut
	var tuft := make_tuft(color.lerp(Color(1.0, 0.55, 0.7), 0.5) if wanted else color.darkened(0.2), rng)
	add_child(tuft)
	tuft.position = local
	# 다발이 몸 바깥으로 뻗게 (+Y 를 몸 중심에서 나가는 쪽으로)
	tuft.quaternion = Quaternion(Vector3.UP, (local - center).normalized())
	tuft.set_meta("zone", zone)
	tuft.set_meta("wanted", wanted)
	_tufts.append(tuft)
	_left.append(1.0)
	return true


func _too_close(local: Vector3) -> bool:
	for tuft in _tufts:
		if tuft.position.distance_to(local) < TUFT_SIZE * 2.0:
			return true
	return false
