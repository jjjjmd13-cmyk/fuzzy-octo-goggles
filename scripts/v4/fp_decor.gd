extends Node3D
## V4 가게 꾸미기 (GDD_V4 '가게 꾸미기', ART_SLOTS 4-2, TUNING_V4 3-3): 10범주 × ★1·★2·★3 = 30개.
## 범주마다 자리 하나, 하나만 놓임 ("" = 처음 모습). 놓인 것의 ★ 합 = 아늑함 → 대기 손님 참을성 조금 길어짐.
##
## 그래픽: 3D = assets/models/decor/<id>.glb, 벽지·바닥 = assets/textures/decor/<id>.png (1 장 = 1 m × 1 m).
## 파일이 없으면 그 범주는 처음 모습 그대로 (산 것·놓인 것은 저장됨). 자리·방향은 PLACES 한 곳에서.

const MODEL_DIR := "res://assets/models/decor/%s.glb"
const TEXTURE_DIR := "res://assets/textures/decor/%s.png"
## 범주: 이름, 큰 것인가 (값·상자 크기), ★1·★2·★3 물건 [id, 이름]
const CATEGORIES := {
	"wall": {"name": "벽지", "big": true, "items": [["wall_stripe", "하늘 줄무늬"], ["wall_bubble", "비눗방울 무늬"], ["wall_paw", "발바닥 무늬"]]},
	"floor": {"name": "바닥", "big": true, "items": [["floor_wood", "원목 마루"], ["floor_check", "민트·흰 체크"], ["floor_star", "별 박힌 하늘 타일"]]},
	"tub": {"name": "목욕통", "big": true, "items": [["tub_wood", "원목 통"], ["tub_claw", "고양이 발 욕조"], ["tub_shell", "조개 욕조"]]},
	"shelf": {"name": "도구 선반", "big": true, "items": [["shelf_wood", "원목 선반"], ["shelf_basket", "바구니 선반"], ["shelf_cloud", "구름 선반"]]},
	"counter": {"name": "카운터", "big": true, "items": [["counter_wood", "원목 카운터"], ["counter_bone", "뼈다귀 카운터"], ["counter_cake", "케이크 카운터"]]},
	"sign": {"name": "간판", "big": false, "items": [["sign_board", "나무 판"], ["sign_paw", "발바닥 간판"], ["sign_rainbow", "무지개 테 간판"]]},
	"lamp": {"name": "조명", "big": false, "items": [["lamp_bulb", "둥근 전구"], ["lamp_bubble", "비눗방울 등"], ["lamp_cloud", "구름 등"]]},
	"plant": {"name": "화분", "big": false, "items": [["plant_round", "동글 화분"], ["plant_monstera", "몬스테라"], ["plant_lemon", "레몬 나무"]]},
	"rug": {"name": "러그", "big": false, "items": [["rug_circle", "하늘 동그라미"], ["rug_paw", "발바닥 러그"], ["rug_rainbow", "무지개 러그"]]},
	"art": {"name": "벽 장식", "big": false, "items": [["art_dog", "강아지 액자"], ["art_clock", "뼈다귀 시계"], ["art_bubble", "비눗방울 벽 장식"]]},
}
## 3D 물건 놓는 자리 (방 좌표)·방향 (Y 회전): 모형 정면 −Z 를 방 쪽으로
const PLACES := {
	# 뒷벽 목욕통 위 (원점 = 뒷면 가운데)
	"sign": {"pos": Vector3(0, 2.35, -3.39), "turn": PI},
	# 목욕통 위 천장 조명 고리 (원점 = 맨 위 걸이, FpCeiling.HOOK_POS · ART_SLOTS 4-8)
	"lamp": {"pos": Vector3(0, 3.0, -1.6), "turn": 0.0},
	# 문 안쪽 옆 앞벽 앞 (손님 쪽 −Z 가 방 안)
	"counter": {"pos": Vector3(2.0, 0, 3.05), "turn": 0.0},
	# 대기 의자 옆 (뒤쪽 끝)
	"plant": {"pos": Vector3(3.35, 0, -2.4), "turn": 0.0},
	# 문에서 목욕통 가는 길
	"rug": {"pos": Vector3(1.4, 0.0, 1.2), "turn": PI / 2.0},
	# 왼쪽 벽 (원점 = 뒷면 가운데, 정면이 +X)
	"art": {"pos": Vector3(-3.89, 1.7, 1.6), "turn": -PI / 2.0},
	# 목욕통·선반은 지금 자리 그대로. 목욕통 앞(낮은 테두리, −Z)을 플레이어 쪽(+Z)으로
	"tub": {"pos": Vector3(0, 0, -1.6), "turn": PI},
	"shelf": {"pos": Vector3(-2.2, 0, -0.8), "turn": -PI / 2.0},
}
## 카운터·화분은 걸어서 통과하지 않게 충돌 상자 (크기)
const BLOCKS := {"counter": Vector3(1.2, 0.95, 0.5), "plant": Vector3(0.45, 1.0, 0.45)}

## 범주 → 지금 놓인 3D 노드
var nodes := {}
## 처음 모습 노드 (꾸미기가 놓이면 숨김): 범주 → Array[Node3D]
var defaults := {}
## 벽지·바닥을 바를 메시 (처음 재질은 _original 에 보관)
var wall_meshes: Array[MeshInstance3D] = []
var floor_meshes: Array[MeshInstance3D] = []
var _original := {}
var _clock_hands: Array[Node3D] = []


## 사진 게시판 (단골 24마리 보상, 벽 장식 자리, 팔지 않음): 모형 경로·사진 테두리
const PHOTO_BOARD := "photo_board"
const PHOTO_BOARD_MODEL := "res://assets/models/album/photo_board.glb"
const FRAME_DIR := "res://assets/ui/album/%s.png"
## 사진 게시판에 붙일 사진 [{mood, regular}] (가게가 정함, 금색 먼저 그다음 분홍)
var board_photos: Array = []


## 물건 id → 범주
static func category_of(id: String) -> String:
	if id == PHOTO_BOARD:
		return "art"
	for category in CATEGORIES:
		for item in CATEGORIES[category].items:
			if item[0] == id:
				return category
	return ""


## 물건 id → ★ (1~3, 모르면 0)
static func stars_of(id: String) -> int:
	var category := category_of(id)
	if category.is_empty():
		return 0
	for i in 3:
		if CATEGORIES[category].items[i][0] == id:
			return i + 1
	return 0


static func name_of(id: String) -> String:
	var category := category_of(id)
	if category.is_empty():
		return id
	return CATEGORIES[category].items[stars_of(id) - 1][1]


static func price_of(id: String) -> int:
	var category := category_of(id)
	if category.is_empty():
		return -1
	var prices: PackedInt32Array = Tuning.data.v4_decor_price_big if CATEGORIES[category].big else Tuning.data.v4_decor_price_small
	return prices[stars_of(id) - 1]


## 상자 크기 (GDD_V4: 작은 = 벽 장식, 중간 = 화분·조명·간판·러그, 큰 = 목욕통·선반·카운터·벽지·바닥)
static func box_size_of(id: String) -> String:
	var category := category_of(id)
	if category == "art":
		return "small"
	return "large" if CATEGORIES.get(category, {}).get("big", false) else "medium"


## 놓인 것의 아늑함 ★ 합
static func coziness(placed: Dictionary) -> int:
	var total := 0
	var points: PackedInt32Array = Tuning.data.v4_decor_points
	for category in placed:
		var stars := stars_of(placed[category])
		if stars > 0:
			total += points[stars - 1]
	return total


## 아늑함 → 대기 참을성 배수 (1 + ★ × 0.01, 최대 1.3)
static func patience_mult(placed: Dictionary) -> float:
	return 1.0 + minf(coziness(placed) * Tuning.data.v4_decor_patience_per_point, Tuning.data.v4_decor_patience_max)


func _process(_delta: float) -> void:
	# 뼈다귀 시계: 가게 시계 따라 바늘이 돎 (Z 축)
	if _clock_hands.is_empty():
		return
	var shop := get_parent()
	var t: float = shop.day_time / maxf(shop.day_seconds, 1.0) * 9.0 + 9.0 if shop != null and "day_time" in shop else 9.0
	for hand in _clock_hands:
		if is_instance_valid(hand):
			hand.rotation.z = -TAU * (fmod(t, 12.0) / 12.0 if hand.name == "Hand_H" else fmod(t, 1.0))


## 범주별로 놓인 물건을 보여 줌 (placed 에 없는 범주는 처음 모습)
func apply(placed: Dictionary) -> void:
	for category in CATEGORIES:
		show_item(category, placed.get(category, ""))


## 한 범주를 id 로 (빈 문자열 = 처음 모습)
func show_item(category: String, id: String) -> void:
	if category == "wall" or category == "floor":
		_paint(wall_meshes if category == "wall" else floor_meshes, id)
		return
	if nodes.has(category) and is_instance_valid(nodes[category]):
		nodes[category].free()
	nodes.erase(category)
	if category == "art":
		_clock_hands.clear()
	var model: Node3D = null
	var path := PHOTO_BOARD_MODEL if id == PHOTO_BOARD else MODEL_DIR % id
	if not id.is_empty() and ResourceLoader.exists(path):
		model = (load(path) as PackedScene).instantiate() as Node3D
	for node in defaults.get(category, []):
		if is_instance_valid(node):
			node.visible = model == null
	if model == null:
		return
	var holder := StaticBody3D.new()
	holder.name = "Decor_" + category
	holder.set_meta("decor", id)
	var place: Dictionary = PLACES[category]
	holder.position = place.pos
	holder.rotation.y = place.turn
	if BLOCKS.has(category):
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = BLOCKS[category]
		shape.shape = box
		shape.position.y = box.size.y / 2.0
		holder.add_child(shape)
	else:
		holder.collision_layer = 0
	holder.add_child(model)
	add_child(holder)
	nodes[category] = holder
	if category == "lamp":
		var light := OmniLight3D.new()
		light.name = "LampLight"
		light.omni_range = 4.5
		light.light_energy = 0.45
		light.light_color = Color(1.0, 0.93, 0.8)
		var bulb := model.find_child("Bulb", true, false) as Node3D
		if bulb != null:
			bulb.add_child(light)
		else:
			light.position.y = -0.55
			holder.add_child(light)
	elif category == "art" and id == PHOTO_BOARD:
		_pin_photos(model)
	elif category == "art":
		for hand_name in ["Hand_H", "Hand_M"]:
			var hand := model.find_child(hand_name, true, false) as Node3D
			if hand != null:
				_clock_hands.append(hand)


## 사진 게시판 Slot_1~6 에 사진 (기분 테두리 그림, 0.2 × 0.2 m, 정면 −Z)
func _pin_photos(board: Node3D) -> void:
	for i in mini(board_photos.size(), Tuning.data.v4_photo_board_slots):
		var slot := board.find_child("Slot_%d" % (i + 1), true, false) as Node3D
		if slot == null:
			continue
		var quad := MeshInstance3D.new()
		quad.name = "Photo"
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.2, 0.234)
		quad.mesh = mesh
		var material := StandardMaterial3D.new()
		var frames := ["photo_frame_grey", "photo_frame_white", "photo_frame_pink", "photo_frame_gold"]
		var path := FRAME_DIR % frames[clampi(int(board_photos[i].mood), 0, 3)]
		if ResourceLoader.exists(path):
			material.albedo_texture = load(path)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material_override = material
		# QuadMesh 정면은 +Z → 게시판 정면(−Z)으로
		quad.rotation.y = PI
		quad.set_meta("regular", board_photos[i].regular)
		slot.add_child(quad)


## 벽지·바닥: 반복 텍스처 (1 m 마다 한 장, 월드 기준) 또는 처음 재질
func _paint(meshes: Array[MeshInstance3D], id: String) -> void:
	var path := TEXTURE_DIR % id
	var texture: Texture2D = load(path) if not id.is_empty() and ResourceLoader.exists(path) else null
	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue
		if not _original.has(mesh):
			_original[mesh] = mesh.material_override
		if texture == null:
			mesh.material_override = _original[mesh]
			continue
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.albedo_color = Color(0.85, 0.85, 0.85)
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.set_meta("decor", id)
		mesh.material_override = material
