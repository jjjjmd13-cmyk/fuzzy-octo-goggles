extends RefCounted
## V4 단골 손님 24마리 (GDD_V4 '손님 사진첩', TUNING_V4 5장). 표는 data/v4/regulars.json (저장에는 id 만).
## 동물 손님은 이 단골 중에서 옴: 처음 보는 단골은 하루 1~2마리씩 (1일차 4마리), 나머지는 이미 만난 단골이 다시 옴.
## 단골은 자기 종(고양이 3일차)·성격(간지럼 2 · 겁쟁이 5 · 멋쟁이 7일차)이 열린 뒤에만 나옴.
## 겉모습은 강아지·고양이 모형 하나에 털 색 곱하기(tint) + 크기 + 목걸이 색만 (새 3D 모형 없음).

const DATA := "res://data/v4/regulars.json"
## 털 색 이름 → 털 셰이더 tint (털 색에 곱함, 1 = 모형 그대로)
const COLORS := {
	"크림": Color(1.0, 1.0, 1.0),
	"흰색": Color(1.08, 1.08, 1.12),
	"갈색": Color(0.72, 0.52, 0.36),
	"살구": Color(1.0, 0.8, 0.62),
	"검정": Color(0.3, 0.27, 0.27),
	"초코": Color(0.52, 0.36, 0.26),
	"회색": Color(0.74, 0.74, 0.78),
}

static var _table: Array = []


## 단골 표 [{id, name, animal, color, trait, scale, fav, collar}]
static func all() -> Array:
	if _table.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_table = (parsed as Dictionary).regulars if parsed is Dictionary else []
	return _table


static func get_regular(id: String) -> Dictionary:
	for regular in all():
		if regular.id == id:
			return regular
	return {}


## 그날 열린 단골인가 (종·성격이 열린 날부터)
static func is_open(regular: Dictionary, day: int) -> bool:
	if regular.animal == "cat" and day < Tuning.data.v4_cat_from_day:
		return false
	if not regular.trait.is_empty():
		var index: int = Array(Tuning.data.v4_trait_ids).find(regular.trait)
		if index >= 0 and day < Tuning.data.v4_trait_from_day[index]:
			return false
	return true


## 그날 섞이는 처음 보는 단골 수 (1일차는 v4_first_day_regulars)
static func new_quota(day: int) -> int:
	if day <= 1:
		return Tuning.data.v4_first_day_regulars.size()
	var per_day: PackedInt32Array = Tuning.data.v4_new_regulars_per_day
	return per_day[0] if day < Tuning.data.v4_new_regulars_switch_day else per_day[1]


## 그날 nth 번째 손님(1부터)으로 올 단골 id. met = 이미 만난 id, new_today = 오늘 이미 온 처음 보는 단골 수,
## busy = 지금 줄·목욕통에 있는 id (같은 단골이 두 번 동시에 오지 않게), prefer = 먼저 올 단골 (축제 날: 금색 사진이 없는 단골)
static func pick(day: int, nth: int, met: Array, new_today: int, busy: Array, rng: RandomNumberGenerator, prefer: Array = []) -> String:
	var open := all().filter(func(r: Dictionary) -> bool: return is_open(r, day) and not busy.has(r.id))
	var first := open.filter(func(r: Dictionary) -> bool: return prefer.has(r.id))
	if not first.is_empty():
		return first[rng.randi() % first.size()].id
	var unmet := open.filter(func(r: Dictionary) -> bool: return not met.has(r.id))
	var slot: int = Tuning.data.v4_new_guest_slot
	# 1일차: 처음 4마리는 정해진 단골 (콩이·보리·두부·호떡)
	if day <= 1:
		for id in Tuning.data.v4_first_day_regulars:
			if not met.has(id) and not busy.has(id):
				return id
	# 고양이·성격이 새로 열린 날의 2번째 손님은 꼭 그것 (못 만난 단골 먼저)
	if nth == slot:
		var opening := _opening_today(day)
		if not opening.is_empty():
			var fits := open.filter(func(r: Dictionary) -> bool: return _matches(r, opening))
			var fits_new := fits.filter(func(r: Dictionary) -> bool: return not met.has(r.id))
			if not fits_new.is_empty():
				return fits_new[rng.randi() % fits_new.size()].id
			if not fits.is_empty():
				return fits[rng.randi() % fits.size()].id
	# 처음 보는 단골: 하루 몫이 남았고 2·4번째 손님일 때
	if new_today < new_quota(day) and not unmet.is_empty() and (nth == slot or nth == slot * 2 or day <= 1):
		return unmet[rng.randi() % unmet.size()].id
	var seen := open.filter(func(r: Dictionary) -> bool: return met.has(r.id))
	if not seen.is_empty():
		return seen[rng.randi() % seen.size()].id
	if not unmet.is_empty():
		return unmet[rng.randi() % unmet.size()].id
	# 모두 바쁨: 아무나 (같은 단골이 겹칠 수 있음)
	var any := all().filter(func(r: Dictionary) -> bool: return is_open(r, day))
	return any[rng.randi() % any.size()].id if not any.is_empty() else "kongi"


## 그날 새로 열리는 것: "cat" 또는 성격 id ("" = 없음). 고양이가 먼저
static func _opening_today(day: int) -> String:
	if day == Tuning.data.v4_cat_from_day:
		return "cat"
	var days: PackedInt32Array = Tuning.data.v4_trait_from_day
	for i in days.size():
		if day == days[i]:
			return Tuning.data.v4_trait_ids[i]
	return ""


static func _matches(regular: Dictionary, opening: String) -> bool:
	if opening == "cat":
		return regular.animal == "cat"
	return regular.trait == opening


## 단골 겉모습을 모형에 입힘: 크기, 털 색 (털 셰이더 tint), 목걸이 색 (Collar 로 시작하는 메시가 있으면)
static func dress(model: Node3D, regular: Dictionary) -> void:
	if model == null or regular.is_empty():
		return
	model.scale = Vector3.ONE * float(regular.scale)
	var tint: Color = COLORS.get(regular.color, Color.WHITE)
	var fur: Variant = model.get("fur_meshes")
	if fur is Array:
		for mesh in fur:
			if not is_instance_valid(mesh):
				continue
			var view := mesh as MeshInstance3D
			var active := view.get_active_material(0)
			if active is ShaderMaterial:
				# 목욕통: 털 셰이더의 tint
				view.set_instance_shader_parameter("tint", tint)
			elif active is StandardMaterial3D:
				# 주인 품 (털 셰이더 없음): 원래 재질 색에 곱함
				var copy := (active as StandardMaterial3D).duplicate() as StandardMaterial3D
				copy.albedo_color = copy.albedo_color * tint
				view.material_override = copy
	for node in model.find_children("Collar*", "MeshInstance3D", true, false):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(regular.collar)
		(node as MeshInstance3D).material_override = material
