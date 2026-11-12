extends RefCounted
## V4 주인 손님 모형 고르기 (그래픽 #158 주인 4종, 기획 ORDER_V4_OWNER · ART_SLOTS 3-1).
## 손님마다 차례로 청년 · 할머니 · 아이 · 회사원 (모형 파일이 있는 것만, 하나도 없으면 예전 주인 owner_model.tscn).
## 씬: scenes/art/sim/owner_<종류>.tscn (스크립트 sim_owner_model.gd, standing_height = 모형 키 → 말풍선 높이).
## 안은 동물 자리는 모형마다 어깨 높이·팔 길이로 (sim_owner_model.held_point).

const KINDS := ["youth", "grandma", "kid", "worker"]
const SCENE_DIR := "res://scenes/art/sim/owner_%s.tscn"
const MODEL_DIR := "res://assets/models/owner/owner_%s.glb"
const FALLBACK := "res://scenes/art/sim/owner_model.tscn"


## 쓸 수 있는 주인 종류 (모형 파일이 있는 것)
static func kinds() -> Array:
	return KINDS.filter(func(kind: String) -> bool: return ResourceLoader.exists(MODEL_DIR % kind) and ResourceLoader.exists(SCENE_DIR % kind))


## index 번째 손님의 주인 모형 씬
static func scene(index: int) -> PackedScene:
	var available := kinds()
	if available.is_empty():
		return load(FALLBACK) as PackedScene
	return load(SCENE_DIR % available[index % available.size()]) as PackedScene


## 주인 모형의 안은 동물 자리 (모형에 held_point 가 없으면 예전 값)
static func held_point(owner: Node3D, sitting: bool) -> Vector3:
	if owner.has_method("held_point"):
		return owner.held_point(sitting)
	return Vector3(0, 0.56, 0.1) if sitting else Vector3(0, 0.82, 0.26)
