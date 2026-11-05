extends RefCounted
## V4 고양이·동물 성격 (GDD_V4 '고양이·동물 성격', TUNING_V4 4장).
## 손님마다 동물(dog·cat)과 동물 성격("" 없음 · ticklish 간지럼쟁이 · timid 겁쟁이 · dandy 멋쟁이)을 뽑고,
## 그 이름·한 줄·표시 색을 한 곳에 둔다. 씻기 중 '싫어함' 판정은 fp_shop.gd.
##
## 고양이 그래픽: assets/models/cat/cat.glb 가 있으면 그걸 (dog_model.tscn 과 같은 방식: sim_dog_model.gd + GLB, 180° 돌림),
## 없으면 V3 임시 고양이 scenes/art/sim/cat_model.tscn (toy_cat_model.gd). 노드 약속은 강아지와 같음 (ART_SLOTS 2-1).

const CAT_GLB := "res://assets/models/cat/cat.glb"
const CAT_TOY := "res://scenes/art/sim/cat_model.tscn"
const DOG_SCENE := "res://scenes/art/sim/dog_model.tscn"
const MODEL_SCRIPT := "res://scripts/sim/sim_dog_model.gd"

## 동물 성격: 이름, 목욕대 위 한 줄, 처음 나올 때 안내, 표시 색
const TRAITS := {
	"ticklish": {"name": "간지럼쟁이", "line": "배·발은 짧게 (한 곳에 오래 머물지 않기)", "intro": "간지럼쟁이: 거품·수건 때 배·발에 오래 머물면 싫어해요. 아래쪽은 쓱 지나가요!", "color": Color(1.0, 0.95, 0.75)},
	"timid": {"name": "겁쟁이", "line": "얼굴에 물·바람 피하기", "intro": "겁쟁이: 얼굴(눈 근처)에 샤워 물이나 드라이 바람이 닿으면 싫어해요.", "color": Color(0.55, 0.78, 1.0)},
	"dandy": {"name": "멋쟁이", "line": "빗질을 끝까지 하면 싫어함 하나 지워 줌", "intro": "멋쟁이: 빗질을 끝까지 해 주면 기분이 좋아져요 (싫어함 하나를 지워 줘요). 미용 요청도 조금 잦아요.", "color": Color(1.0, 0.85, 0.3)},
}
const CAT_LINE := "고양이: 머리에 물 조심 · 빨리 말리기 (%d초 안)"
const CAT_INTRO := "고양이 손님! 머리에 물이 닿거나, 젖어 있는 시간이 길면 싫어해요. 요금은 %d."

static var _cat_scene: PackedScene


## 그날 nth 번째(1부터) 손님의 동물·성격. 새로 열린 날의 v4_new_guest_slot 번째 손님은 꼭 그것
static func roll(day: int, nth: int, rng: RandomNumberGenerator) -> Dictionary:
	var slot: int = Tuning.data.v4_new_guest_slot
	var animal := "dog"
	var cat_day: int = Tuning.data.v4_cat_from_day
	if day >= cat_day:
		if day == cat_day and nth == slot:
			animal = "cat"
		elif rng.randf() < Tuning.data.v4_cat_chance:
			animal = "cat"
	var trait_id := ""
	var ids: Array = Tuning.data.v4_trait_ids
	var days: PackedInt32Array = Tuning.data.v4_trait_from_day
	var open: Array = []
	for i in ids.size():
		if day >= days[i]:
			open.append(ids[i])
			# 그 성격이 열린 날의 slot 번째 손님은 꼭 그 성격 (고양이가 열린 날과 겹치면 고양이가 그 성격을 가짐)
			if day == days[i] and nth == slot:
				trait_id = ids[i]
	if trait_id.is_empty() and not open.is_empty() and rng.randf() < Tuning.data.v4_trait_chance:
		trait_id = open[rng.randi() % open.size()]
	return {"animal": animal, "trait": trait_id}


## 동물 모형 장면 (고양이는 cat.glb 가 오면 자동으로 그것)
static func scene_of(animal: String) -> PackedScene:
	if animal != "cat":
		return load(DOG_SCENE)
	if _cat_scene != null:
		return _cat_scene
	if ResourceLoader.exists(CAT_GLB):
		var root := Node3D.new()
		root.name = "CatModel"
		root.set_script(load(MODEL_SCRIPT))
		# 고양이 GLB 혀는 입 안에 있음 → 기분 좋을 때 이만큼 내밂 (CAT_DELIVERY.md)
		root.set("tongue_out_offset", Vector3(0, -0.027, -0.050))
		var art := (load(CAT_GLB) as PackedScene).instantiate() as Node3D
		art.name = "Art"
		art.rotation.y = PI
		root.add_child(art)
		art.owner = root
		_cat_scene = PackedScene.new()
		_cat_scene.pack(root)
		root.free()
	else:
		_cat_scene = load(CAT_TOY)
	return _cat_scene


## 목욕대 위 왼쪽 위 한 줄 (고양이·성격이 없으면 "")
static func line_of(animal: String, trait_id: String) -> String:
	var parts: Array = []
	if animal == "cat":
		parts.append(CAT_LINE % int(Tuning.data.v4_cat_wet_limit))
	if TRAITS.has(trait_id):
		parts.append("%s: %s" % [TRAITS[trait_id].name, TRAITS[trait_id].line])
	return " · ".join(parts)


## 싫어함 수 → 얼굴 (2 😊 / 1 😐 / 0 😣, v4_tip_mood 순서)
static func face_of(dislikes: int) -> int:
	var at: PackedInt32Array = Tuning.data.v4_dislike_mood_at
	if dislikes >= at[1]:
		return 0
	if dislikes >= at[0]:
		return 1
	return 2


## 머리 위 성격 표시 (임시 도형: 깃털 = 길쭉한 흰 잎, 물방울 = 파란 방울, 반짝 = 노란 별)
static func make_icon(trait_id: String) -> Node3D:
	var icon := Node3D.new()
	icon.name = "TraitIcon"
	if not TRAITS.has(trait_id):
		return icon
	var mesh := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = TRAITS[trait_id].color
	material.emission_enabled = true
	material.emission = TRAITS[trait_id].color
	material.emission_energy_multiplier = 0.3
	match trait_id:
		"ticklish":
			var leaf := SphereMesh.new()
			leaf.radius = 0.05
			leaf.height = 0.1
			mesh.mesh = leaf
			mesh.scale = Vector3(0.6, 2.0, 0.3)
			mesh.rotation.z = 0.5
		"timid":
			var drop := SphereMesh.new()
			drop.radius = 0.06
			drop.height = 0.12
			mesh.mesh = drop
			mesh.scale = Vector3(0.8, 1.2, 0.8)
		_:
			var star := BoxMesh.new()
			star.size = Vector3(0.09, 0.09, 0.03)
			mesh.mesh = star
			mesh.rotation.z = PI / 4.0
	mesh.material_override = material
	icon.add_child(mesh)
	return icon
