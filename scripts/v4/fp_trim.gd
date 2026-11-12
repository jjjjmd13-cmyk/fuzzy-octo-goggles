extends Node3D
## V4 미용 = 실제로 자르기 (GDD_V4 '미용 — 실제로 자르기', TUNING_V4 3-1-1 제안값, 조작 시제품).
## 빗질이 끝나면 몸 곳곳에 털 다발이 길게 자라 있음 (길이 1.0). 요청 모양마다 부위별 목표 길이가 있고
## (곰돌이컷 머리 0.55 …), 목표 높이에 반투명 하늘색 안내 원판이 겹쳐 보임 = 목표 모양 껍질.
## 가위를 누른 채 털 위를 지나가면 닿는 다발이 안내선까지 쓱 잘림 (한 번 지나갈 때 최대 v4_trim_pass_step),
## 클릭 한 번 (누른 첫 순간) 은 v4_trim_click_step 만큼만. 안내선에 닿은 뒤에도 같은 곳을 v4_trim_overcut_after 넘게
## 누르고 있으면 안내선 아래로 더 짧아짐 (지나치게 자르기, 가장 짧게 v4_trim_len_min).
## 잘린 털 조각은 팔랑 떨어져 목욕통 바닥에 쌓이고 돌려줄 때 사라짐. 실패 없음: 맞은 정도는 팁, 지나치게 자르면 기분만 −1.
## 강아지 모형(WashDog.model)의 자식. 다발 모양은 임시 털 (그림이 오면 make_tuft 만 바꿈).

## 다발이 잘림 (털 조각·소리): 자리, 잘린 양
signal snipped(world_point: Vector3, amount: float)
## 다발이 안내선에 딱 맞음 (반짝)
signal matched(world_point: Vector3)
## 지나치게 자른 면적이 v4_trim_overcut_mood_at 을 넘음 (한 번만)
signal overcut

const DOG_LAYER := 16
## 길이 1.0 일 때 다발 길이 (m)
const TUFT_LEN := 0.09
const TUFT_WIDTH := 0.05
## 다발 사이 최소 거리 (m)
const SPACING := 0.045
## 얼굴 점 (눈·코) 둘레 이 안에는 다발을 안 놓음 (m)
const FACE_CLEAR := 0.1
## 모양: 이름, 한 줄 설명 (부위별 목표 길이는 Tuning v4_trim_targets [머리, 몸, 다리, 꼬리])
const SHAPES := {
	"bear": {"name": "곰돌이컷", "about": "얼굴 둘레를 동그랗게"},
	"lion": {"name": "사자컷", "about": "몸만 짧게, 머리·꼬리는 남김"},
	"summer": {"name": "여름컷", "about": "다 짧게, 다리만 보송"},
}
const ZONE_ORDER := ["head", "body", "legs", "tail"]
## 부위마다 다발을 놓을 방향 (모형 기준, 정면 +Z) 과 수
const ZONES := {
	"head": {"dir": Vector3(0, 0.75, 0.65), "count": 14},
	"body": {"dir": Vector3(0, 0.55, -0.85), "count": 22},
	# 다리는 앞에서 (아래에서 쏘면 배 밑에 붙어 위에서 안 보임)
	"legs": {"dir": Vector3(0, -0.3, 0.95), "count": 10},
	"tail": {"dir": Vector3(0, 0.1, -1.0), "count": 6},
}
## 개발 보정값: 자르는 빠르기 (길이/s), 누른 채 가만히 있을 때 '한 번 더 지나감' 으로 치는 간격 (s),
## 새로 누름으로 치는 쉰 시간 (s), 털 조각 하나가 떨어지는 잘린 양, 목욕통에 쌓이는 조각 최대 수
const CUT_SPEED := 2.0
const HOLD_REPASS := 0.4
const PRESS_GAP := 0.12
const SHED_EVERY := 0.08
const MAX_CLIPPINGS := 160
const GUIDE_COLOR := Color(0.55, 0.85, 1.0, 0.4)
const NEED_TINT := Color(1.0, 0.55, 0.7)

## 요청 모양 ("" = 요청 없음)
var shape := ""
## 다발마다: {node, hair, guide, zone, len, target, budget, hold, repass, shed, in_reach, was_ok}
var tufts: Array[Dictionary] = []
var clippings: Array[Node3D] = []
var _idle := 1.0
var _overcut_told := false
var _materials := {}


func _process(delta: float) -> void:
	_idle += delta


## 요청 모양으로 다발을 만든다. center 는 모형 기준 몸 중심
func spawn(shape_id: String, dog_model: Node3D, center: Vector3, rng: RandomNumberGenerator, color: Color) -> void:
	clear()
	shape = shape_id
	_make_materials(color)
	var space := dog_model.get_world_3d().direct_space_state
	var placed := {}
	for zone in ZONES:
		placed[zone] = 0
		for attempt in ZONES[zone].count * 12:
			if placed[zone] >= ZONES[zone].count:
				break
			var base: Vector3 = ZONES[zone].dir
			var dir := (base + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.25, 0.25))).normalized()
			if _cast_and_place(space, dog_model, center, dir, zone, rng):
				placed[zone] += 1
	# 강아지가 몸짓하는 중이면 어떤 부위는 광선이 빗나가 모자랄 수 있음 → 모자란 부위마다 더 넓게 다시 쏴서 채움
	for attempt in 400:
		var short := ""
		for zone in ZONES:
			var need: int = ZONES[zone].count - placed[zone]
			if need > 0 and (short.is_empty() or need > ZONES[short].count - placed[short]):
				short = zone
		if short.is_empty():
			break
		var base: Vector3 = ZONES[short].dir
		var spread := 0.6 + 0.6 * minf(1.0, attempt / 80.0)
		var dir := (base + Vector3(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread) * 0.6, rng.randf_range(-spread, spread) * 0.6)).normalized()
		if _cast_and_place(space, dog_model, center, dir, short, rng):
			placed[short] += 1


func clear() -> void:
	for tuft in tufts:
		(tuft.node as Node).queue_free()
	tufts.clear()
	shape = ""
	_overcut_told = false
	sweep_clippings()


## 목욕통에 쌓인 털 조각이 쓱 사라짐 (돌려줄 때)
func sweep_clippings() -> void:
	for piece in clippings:
		if is_instance_valid(piece):
			var tween := piece.create_tween()
			tween.tween_property(piece, "scale", Vector3.ZERO, 0.3)
			tween.tween_callback(piece.queue_free)
	clippings.clear()


## 모양의 부위별 목표 길이 [머리, 몸, 다리, 꼬리]
static func targets_of(shape_id: String) -> Array:
	return Array(Tuning.data.v4_trim_targets.get(shape_id, [1.0, 1.0, 1.0, 1.0]))


## 모양에서 자를 부위 (목표가 1.0 보다 짧은 곳, 요청 카드에 분홍)
static func cut_zones(shape_id: String) -> Array:
	var targets := targets_of(shape_id)
	var out := []
	for i in ZONE_ORDER.size():
		if float(targets[i]) < 1.0:
			out.append(ZONE_ORDER[i])
	return out


## 가위를 world_point 에 대고 delta 초 (누르고 있는 동안 매 프레임). speed = 도구 속도 배수. 잘린 양 합
func cut(world_point: Vector3, delta: float, speed := 1.0) -> float:
	var radius: float = Tuning.data.v4_trim_radius
	var new_press := _idle > PRESS_GAP
	_idle = 0.0
	var total := 0.0
	var len_min: float = Tuning.data.v4_trim_len_min
	for tuft in tufts:
		var node := tuft.node as Node3D
		var near := node.global_position.distance_to(world_point) <= radius
		if not near:
			tuft.in_reach = false
			continue
		var step := 0.0
		# 새로 누름 = 사각 한 번 (클릭 한 번만큼 바로), 지나가다 들어옴 = 한 번 지나가는 만큼 (안내선에서 멈춤)
		if new_press:
			tuft.budget = 0.0
			tuft.repass = 0.0
			tuft.hold = 0.0
			step = clampf(tuft.len - tuft.target, 0.0, Tuning.data.v4_trim_click_step)
		elif not tuft.in_reach:
			tuft.budget = Tuning.data.v4_trim_pass_step
			tuft.repass = 0.0
			tuft.hold = 0.0
		tuft.in_reach = true
		tuft.repass += delta
		if tuft.repass >= HOLD_REPASS:
			tuft.repass = 0.0
			tuft.budget = Tuning.data.v4_trim_pass_step
		if new_press:
			pass
		elif tuft.len > tuft.target + 0.001:
			tuft.hold = 0.0
			step = minf(minf(CUT_SPEED * speed * delta, tuft.budget), tuft.len - tuft.target)
			tuft.budget -= step
		else:
			# 안내선에 닿은 뒤 계속 누르고 있으면 조금씩 더 짧아짐
			tuft.hold += delta
			if tuft.hold > Tuning.data.v4_trim_overcut_after:
				step = minf(Tuning.data.v4_trim_overcut_step / 0.5 * delta, tuft.len - len_min)
		if step <= 0.0:
			continue
		tuft.len -= step
		tuft.shed += step
		total += step
		_update_view(tuft)
		var tip := node.to_global(Vector3(0, tuft.len * TUFT_LEN, 0))
		if tuft.shed >= SHED_EVERY:
			tuft.shed = 0.0
			_drop_clipping(tip, node)
		var ok := is_ok(tuft)
		if ok and not tuft.was_ok:
			matched.emit(tip)
		tuft.was_ok = ok
	if total > 0.0:
		snipped.emit(world_point, total)
	if not _overcut_told and overcut_ratio() > Tuning.data.v4_trim_overcut_mood_at:
		_overcut_told = true
		overcut.emit()
	return total


## 안내선 ± v4_trim_ok_band 안이면 맞음
func is_ok(tuft: Dictionary) -> bool:
	return absf(tuft.len - tuft.target) <= Tuning.data.v4_trim_ok_band


## 아직 자를 다발 수 (안내선보다 v4_trim_ok_band 넘게 긴 곳) — 0 이면 "다 됐어요!"
func wanted_left() -> int:
	return tufts.filter(func(t: Dictionary) -> bool: return t.len > t.target + Tuning.data.v4_trim_ok_band).size()


## 처음에 자를 곳이었던 다발 수 (목표가 1.0 보다 짧은 다발)
func wanted_total() -> int:
	return tufts.filter(func(t: Dictionary) -> bool: return t.target < 1.0 - Tuning.data.v4_trim_ok_band).size()


## 맞은 정도 (0~1) = 안내선 ± ok_band 안에 든 다발 비율 (다발 하나 = 같은 털 면적)
func match_score() -> float:
	if tufts.is_empty():
		return 1.0
	return float(tufts.filter(func(t: Dictionary) -> bool: return is_ok(t)).size()) / tufts.size()


## 지나치게 자른 비율 = 안내선보다 v4_trim_overcut_band 넘게 짧은 다발 비율
func overcut_ratio() -> float:
	if tufts.is_empty():
		return 0.0
	return float(tufts.filter(func(t: Dictionary) -> bool: return t.len < t.target - Tuning.data.v4_trim_overcut_band).size()) / tufts.size()


## 다발 월드 위치 (wanted: true = 아직 자를 곳만, false = 나머지)
func world_positions(wanted: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	var band: float = Tuning.data.v4_trim_ok_band
	for tuft in tufts:
		if (tuft.len > tuft.target + band) == wanted:
			out.append((tuft.node as Node3D).global_position)
	return out


## 임시 털 다발: 털색 가는 캡슐 4가닥 (원점 = 털 겉면, +Y 로 TUFT_LEN 만큼 뻗음)
static func make_tuft(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Hair"
	var strand := CapsuleMesh.new()
	strand.radius = TUFT_WIDTH * 0.11
	strand.height = TUFT_LEN
	strand.radial_segments = 6
	strand.rings = 2
	for i in 4:
		var piece := MeshInstance3D.new()
		piece.mesh = strand
		piece.position = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * TUFT_WIDTH * 0.3 + Vector3(0, TUFT_LEN * 0.5, 0)
		piece.rotation = Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
		root.add_child(piece)
	return root


func _make_materials(color: Color) -> void:
	for key in ["fur", "need", "short"]:
		var material := StandardMaterial3D.new()
		material.roughness = 1.0
		material.albedo_color = {"fur": color, "need": color.lerp(NEED_TINT, 0.3), "short": color.darkened(0.25)}[key]
		_materials[key] = material
	var guide := StandardMaterial3D.new()
	guide.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guide.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guide.albedo_color = GUIDE_COLOR
	guide.no_depth_test = false
	_materials["guide"] = guide


## 모형 바깥에서 몸 중심 쪽으로 광선을 쏴 닿은 곳에 다발 하나 놓기 (빗나가거나 너무 가까우면 false)
func _cast_and_place(space: PhysicsDirectSpaceState3D, dog_model: Node3D, center: Vector3, dir: Vector3, zone: String, rng: RandomNumberGenerator) -> bool:
	var query := PhysicsRayQueryParameters3D.create(dog_model.to_global(center + dir * 1.5), dog_model.to_global(center), DOG_LAYER)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var local := to_local(hit.position)
	# 눈·코 (얼굴 앞) 에는 다발을 안 놓음
	var face: Variant = dog_model.get("face_center")
	if face != null and dog_model.to_local(hit.position).distance_to(face) < FACE_CLEAR:
		return false
	for tuft in tufts:
		if (tuft.node as Node3D).position.distance_to(local) < SPACING:
			return false
	var node := Node3D.new()
	node.name = "Tuft"
	add_child(node)
	node.position = local
	# 다발이 몸 바깥으로 뻗게 (+Y 를 몸 중심에서 나가는 쪽으로)
	node.quaternion = Quaternion(Vector3.UP, (local - center).normalized())
	var hair := make_tuft(rng)
	node.add_child(hair)
	var target: float = targets_of(shape)[ZONE_ORDER.find(zone)]
	# 목표 모양 껍질: 목표 길이 높이의 반투명 하늘색 원판 (자를 곳만)
	var guide := MeshInstance3D.new()
	guide.name = "Guide"
	var disc := CylinderMesh.new()
	disc.top_radius = TUFT_WIDTH * 0.7
	disc.bottom_radius = TUFT_WIDTH * 0.7
	disc.height = 0.003
	disc.radial_segments = 12
	disc.rings = 1
	guide.mesh = disc
	guide.material_override = _materials.guide
	guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	guide.position.y = target * TUFT_LEN
	guide.visible = target < 1.0
	node.add_child(guide)
	var tuft := {"node": node, "hair": hair, "guide": guide, "zone": zone, "len": 1.0, "target": target, "budget": 0.0, "hold": 0.0, "repass": 0.0, "shed": 0.0, "in_reach": false, "was_ok": false}
	tuft.was_ok = is_ok(tuft)
	tufts.append(tuft)
	_update_view(tuft)
	return true


## 다발 길이·색: 아직 자를 곳 = 분홍빛, 맞음 = 털색 (안내 원판 숨김), 지나치게 짧음 = 조금 진하게
func _update_view(tuft: Dictionary) -> void:
	var hair := tuft.hair as Node3D
	hair.scale = Vector3(1.0, maxf(tuft.len, 0.05), 1.0)
	var band: float = Tuning.data.v4_trim_ok_band
	var key := "need" if tuft.len > tuft.target + band else ("short" if tuft.len < tuft.target - Tuning.data.v4_trim_overcut_band else "fur")
	for piece in hair.get_children():
		(piece as MeshInstance3D).material_override = _materials[key]
	(tuft.guide as Node3D).visible = tuft.target < 1.0 and key == "need"


## 잘린 털 조각 하나가 팔랑 떨어져 목욕통 바닥에 쌓임 (모형 원점 높이 = 목욕통 안 바닥)
func _drop_clipping(at: Vector3, tuft_node: Node3D) -> void:
	var piece := MeshInstance3D.new()
	piece.name = "Clipping"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.006, 0.03, 0.006)
	piece.mesh = mesh
	piece.material_override = _materials.fur
	piece.top_level = true
	add_child(piece)
	piece.global_position = at
	var model := get_parent() as Node3D
	var floor_y := (model.global_position.y if model != null else at.y - 0.3) + 0.004
	var drift := Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12)) + (at - tuft_node.global_position).normalized() * 0.08
	drift.y = 0.0
	var land := Vector3(at.x, floor_y, at.z) + drift
	var tween := piece.create_tween().set_parallel(true)
	var fall := clampf((at.y - floor_y) * 1.4, 0.3, 1.0)
	tween.tween_property(piece, "global_position", land, fall).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(piece, "rotation", Vector3(PI / 2.0, randf() * TAU, randf_range(-0.4, 0.4)), fall)
	clippings.append(piece)
	if clippings.size() > MAX_CLIPPINGS:
		var old: Node3D = clippings.pop_front()
		if is_instance_valid(old):
			old.queue_free()
