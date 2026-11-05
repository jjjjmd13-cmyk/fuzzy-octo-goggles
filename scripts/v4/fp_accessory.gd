extends RefCounted
## V4 액세서리 (GDD_V4 '액세서리', TUNING_V4 7-1, ART_SLOTS 4-5): 씻긴 뒤 돌려주기 전에 하나 씌우기.
## 범주 4 (리본·모자·스카프·꽃핀) × ★1·★2·★3 = 12개. 처음엔 분홍 리본.
## 그래픽: assets/models/accessory/<id>.glb (원점 = 붙는 자리), 바구니 acc_basket.glb. 없으면 임시 도형.
## 붙는 자리: 동물 모형에 Acc_Head (머리 꼭대기) · Acc_Neck (목) · Acc_Ear (오른쪽 귀 옆). 모형에 없으면 게임이 만듦.

const MODEL_DIR := "res://assets/models/accessory/%s.glb"
## 범주: 이름, 붙는 자리
const CATEGORIES := {
	"ribbon": {"name": "리본", "slot": "Acc_Head"},
	"hat": {"name": "모자", "slot": "Acc_Head"},
	"scarf": {"name": "스카프", "slot": "Acc_Neck"},
	"pin": {"name": "꽃핀", "slot": "Acc_Ear"},
}
const NAMES := {
	"ribbon_pink": "분홍 리본", "ribbon_polka": "물방울 리본", "ribbon_gold": "금빛 리본",
	"hat_party": "고깔모자", "hat_beret": "베레모", "hat_crown": "왕관",
	"scarf_mint": "민트 스카프", "scarf_bandana": "반다나", "scarf_cape": "망토",
	"pin_daisy": "데이지 핀", "pin_star": "별 핀", "pin_rainbow": "무지개 핀",
}
## 임시 도형 색 (★ 순서)
const COLORS := {
	"ribbon_pink": Color(1.0, 0.6, 0.75), "ribbon_polka": Color(0.55, 0.78, 1.0), "ribbon_gold": Color(1.0, 0.82, 0.3),
	"hat_party": Color(1.0, 0.55, 0.7), "hat_beret": Color(0.6, 0.45, 0.75), "hat_crown": Color(1.0, 0.85, 0.3),
	"scarf_mint": Color(0.6, 0.92, 0.8), "scarf_bandana": Color(0.95, 0.4, 0.4), "scarf_cape": Color(0.5, 0.55, 0.95),
	"pin_daisy": Color(1.0, 1.0, 0.95), "pin_star": Color(1.0, 0.9, 0.35), "pin_rainbow": Color(0.75, 0.6, 1.0),
}
## 고양이는 크기만 줄임 (ART_SLOTS 4-5)
const CAT_SCALE := 0.85


## 범주 id 목록 (v4_acc_categories 순서)
static func categories() -> Array:
	return Array(Tuning.data.v4_acc_categories)


## 범주의 ★1·★2·★3 물건 id
static func items_of(category: String) -> Array:
	return Array(Tuning.data.v4_acc_items.get(category, []))


static func all_items() -> Array:
	var out: Array = []
	for category in categories():
		out.append_array(items_of(category))
	return out


static func category_of(id: String) -> String:
	for category in categories():
		if items_of(category).has(id):
			return category
	return ""


static func stars_of(id: String) -> int:
	return items_of(category_of(id)).find(id) + 1


static func name_of(id: String) -> String:
	return NAMES.get(id, id)


static func price_of(id: String) -> int:
	var stars := stars_of(id)
	return Tuning.data.v4_acc_price[stars - 1] if stars > 0 else -1


## 동물 모형에 액세서리 하나 씌움 (같은 모형의 앞 것은 뺌). id "" = 벗기기. 붙인 노드를 돌려줌
static func wear(model: Node3D, id: String, is_cat: bool) -> Node3D:
	if model == null:
		return null
	for old in model.find_children("Accessory", "", true, false):
		old.get_parent().remove_child(old)
		old.queue_free()
	var category := category_of(id)
	if category.is_empty():
		return null
	var anchor := anchor_of(model, CATEGORIES[category].slot)
	var view := make_view(id)
	view.name = "Accessory"
	view.set_meta("acc", id)
	view.scale = Vector3.ONE * (CAT_SCALE if is_cat else 1.0)
	anchor.add_child(view)
	return view


## 붙는 자리 노드: 모형에 있으면 그것, 없으면 얼굴 점(face_center, 모형 정면 +Z) 기준으로 만들어
## 머리(Head)·몸(Chest) 노드에 붙임 (고개를 돌리면 같이 돎). 방향은 모형 기준
static func anchor_of(model: Node3D, slot: String) -> Node3D:
	var found := model.find_child(slot, true, false) as Node3D
	if found != null:
		return found
	var target := _slot_point(model, slot)
	var parent: Node3D = model.find_child("Chest" if slot == "Acc_Neck" else "Head", true, false) as Node3D
	if parent == null:
		parent = model
	var anchor := Node3D.new()
	anchor.name = slot
	parent.add_child(anchor)
	if anchor.is_inside_tree():
		anchor.global_transform = model.global_transform * Transform3D(Basis(), target)
	else:
		anchor.transform = parent.transform.affine_inverse() * Transform3D(Basis(), target) if parent != model else Transform3D(Basis(), target)
	return anchor


## 붙는 점 (모형 기준): 머리(Head) 메시 상자에서 — 머리 꼭대기 가운데 · 오른쪽 위 귀 옆 · 머리 아래 목.
## 머리 메시를 못 찾으면 얼굴 점에서 어림
static func _slot_point(model: Node3D, slot: String) -> Vector3:
	var head := model.find_child("Head", true, false) as Node3D
	var box := AABB()
	var found := false
	if head != null and model.is_inside_tree():
		for mesh in head.find_children("*", "MeshInstance3D", true, false):
			var view := mesh as MeshInstance3D
			if view.mesh == null or view.name.begins_with("Acc"):
				continue
			var local := view.get_aabb()
			for i in 8:
				var corner := model.to_local(view.global_transform * local.get_endpoint(i))
				box = box.expand(corner) if found else AABB(corner, Vector3.ZERO)
				found = true
	if not found:
		var face: Vector3 = model.get("face_center") if model.get("face_center") != null else Vector3(0, 0.55, 0.26)
		box = AABB(face + Vector3(-0.15, -0.2, -0.25), Vector3(0.3, 0.2, 0.28))
	var mid := box.get_center()
	match slot:
		"Acc_Head":
			return Vector3(mid.x, box.end.y - 0.015, mid.z - 0.02)
		"Acc_Ear":
			return Vector3(box.end.x - 0.05, box.end.y - 0.05, mid.z - 0.02)
		_:
			return Vector3(mid.x, box.position.y + 0.01, mid.z - 0.04)


## 액세서리 모형 (GLB 가 있으면 그것, 없으면 임시 도형)
static func make_view(id: String) -> Node3D:
	var path := MODEL_DIR % id
	if ResourceLoader.exists(path):
		var glb := Node3D.new()
		var art := (load(path) as PackedScene).instantiate() as Node3D
		# GLB 정면은 −Z (ART_SLOTS 4-5), 동물 모형 정면은 +Z
		art.rotation.y = PI
		glb.add_child(art)
		return glb
	var root := Node3D.new()
	var color: Color = COLORS.get(id, Color.WHITE)
	match category_of(id):
		"ribbon":
			# 매듭 + 양쪽 고리
			root.add_child(_part(_sphere(0.018), Vector3(0, 0.02, 0), color))
			for side in [-1.0, 1.0]:
				var loop := _part(_sphere(0.03), Vector3(side * 0.035, 0.025, 0), color)
				loop.scale = Vector3(1.2, 0.8, 0.5)
				root.add_child(loop)
		"hat":
			if id == "hat_crown":
				var band := CylinderMesh.new()
				band.top_radius = 0.055
				band.bottom_radius = 0.05
				band.height = 0.05
				root.add_child(_part(band, Vector3(0, 0.025, 0), color))
			elif id == "hat_beret":
				var cap := _part(_sphere(0.065), Vector3(0, 0.02, 0), color)
				cap.scale = Vector3(1.0, 0.45, 1.0)
				root.add_child(cap)
			else:
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.05
				cone.height = 0.11
				root.add_child(_part(cone, Vector3(0, 0.055, 0), color))
				root.add_child(_part(_sphere(0.015), Vector3(0, 0.115, 0), Color(1, 1, 0.9)))
		"scarf":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.09
			ring.outer_radius = 0.115
			root.add_child(_part(ring, Vector3.ZERO, color))
			var tail := BoxMesh.new()
			tail.size = Vector3(0.05, 0.08, 0.012) if id != "scarf_cape" else Vector3(0.16, 0.14, 0.01)
			# 매듭 끝은 앞(+Z, 턱 밑), 망토는 등 뒤(−Z)
			root.add_child(_part(tail, Vector3(0, -0.05, 0.1) if id != "scarf_cape" else Vector3(0, -0.07, -0.11), color))
		_:
			# 꽃핀: 가운데 + 꽃잎 5 (귀 옆에서 바깥(+X)을 봄)
			root.add_child(_part(_sphere(0.016), Vector3.ZERO, Color(1.0, 0.85, 0.3) if id != "pin_star" else color))
			for i in 5:
				var angle := TAU * i / 5.0
				var petal_color: Color = Color.from_hsv(float(i) / 5.0, 0.45, 1.0) if id == "pin_rainbow" else color
				root.add_child(_part(_sphere(0.016), Vector3(0, sin(angle) * 0.028, cos(angle) * 0.028), petal_color))
	return root


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


static func _part(mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	view.material_override = material
	return view
