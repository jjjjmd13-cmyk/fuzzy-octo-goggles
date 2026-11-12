extends "res://tests/qa_test.gd"
## 가게 밖 빈 곳 채우기 (대표 요청 2026-11-11 ⑥, ART_SLOTS 4-8): 양옆 이웃 2채 (세탁소 −Z · 문구점 +Z) + 먼 배경
## (나무 띠·먼 집·언덕·잔디·찻길 양 끝) + 하늘 (먼 산·구름 띠). 배경이라 충돌 없음, 손님 길·트럭 길을 막지 않음,
## 교체 경로 town_side_a/b.glb · town_far.glb.

const FpOutside := preload("res://scripts/v4/fp_outside.gd")
const FpTownWide := preload("res://scripts/v4/fp_town_wide.gd")
const FpParcels := preload("res://scripts/v4/fp_parcels.gd")
const FpGuests := preload("res://scripts/v4/fp_guests.gd")


func run_test() -> void:
	var outside := FpOutside.new()
	add_child(outside)
	await get_tree().process_frame
	var wide := outside.get_node_or_null("TownWide") as Node3D
	check(wide != null, "양옆·먼 배경 노드")
	for name in ["town_side_a", "town_side_b", "town_far", "SkyBand"]:
		check(wide.get_node_or_null(name) != null, "%s 자리" % name)
	check_eq(FpOutside.MODEL_DIR % "town_side_a", "res://assets/models/outside/town_side_a.glb", "교체 경로")
	check_eq(wide.find_children("*", "CollisionShape3D", true, false).size(), 0, "충돌 없음 (배경)")
	check_eq(wide.find_children("*", "CollisionObject3D", true, false).size(), 0, "충돌 몸체 없음")

	# 양옆 이웃: 기획 좌표 안 (건물 x −4 ~ 4.2, 앞마당 ~ 9), 가게 방 (z ±3.6) 과 손님 길 (z 2.6) 을 안 막음
	var a := _box(wide.get_node("town_side_a"))
	var b := _box(wide.get_node("town_side_b"))
	check(a.position.x >= -4.05 and a.end.x <= 9.05 and a.position.z >= -8.55 and a.end.z <= -3.65, "세탁소 (−Z) 자리 %s" % a)
	check(b.position.x >= -4.05 and b.end.x <= 9.05 and b.position.z >= 3.65 and b.end.z <= 8.55, "문구점 (+Z) 자리 %s" % b)
	check(b.position.z > FpGuests.STREET.z + 0.6, "손님 길 (z %.1f) 을 안 막음" % FpGuests.STREET.z)
	var building_a := _box(wide.get_node("town_side_a/Building"))
	check(is_equal_approx(building_a.size.y, 3.5) and is_equal_approx(building_a.end.x, 4.2), "세탁소 높이 3.5 · 정면 x 4.2")

	# 먼 배경: 나무 띠 x 20~23, 먼 집 x 25~32, 언덕 x 35~45 (가운데), 폭 z ±40, 잔디 y −0.25
	var far: Node3D = wide.get_node("town_far")
	for child in far.get_children():
		var node := child as Node3D
		var at := node.position
		if node.name.begins_with("Tree"):
			check(at.x >= 20.0 and at.x <= 23.0 and absf(at.z) <= 40.0, "나무 띠 자리 %s" % at)
		elif node.name.begins_with("House"):
			check(at.x >= 25.0 and at.x <= 32.0, "먼 집 자리 %s" % at)
		elif node.name.begins_with("Hill"):
			check(at.x >= 35.0 and at.x <= 45.0, "언덕 자리 %s" % at)
		elif node.name.begins_with("RoadEnd"):
			# 찻길 양 끝 (z ±14 너머) 길 옆: 택배 트럭 길 (x 9.7 ~ 11.5) 위는 비움
			var box := _box(node)
			check(absf(at.z) >= FpTownWide.ROAD_END_Z and (box.end.x < FpParcels.TRUCK_X - 0.9 or box.position.x > FpParcels.TRUCK_X + 0.9), "찻길 끝 덤불은 트럭 길 밖 %s" % box)
	check(far.find_children("Tree*", "", false, false).size() >= 20, "나무 띠 (%d 그루)" % far.find_children("Tree*", "", false, false).size())
	var grass := _box(far.get_node("Grass"))
	check(is_equal_approx(grass.end.y, FpTownWide.GRASS_Y) and grass.end.x >= 45.0 and grass.position.z <= -40.0 and grass.end.z >= 40.0, "잔디 판 y −0.25 (%s)" % grass)

	# 하늘: 먼 산·구름 띠는 먼 배경보다 멀리, 그림자 안 드리움
	var sky := _box(wide.get_node("SkyBand"))
	check(sky.position.x > 45.0, "먼 산·구름은 언덕 너머 (x %.1f ~)" % sky.position.x)
	check(wide.get_node("SkyBand").find_children("Cloud*", "", false, false).size() >= 6, "구름 띠")
	for mesh in far.find_children("*", "GeometryInstance3D", true, false):
		check_eq((mesh as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "먼 배경은 그림자 없음")
		break
	outside.free()


## 노드 아래 메시 전체 상자 (방 좌표)
func _box(node: Node) -> AABB:
	var out := AABB()
	var first := true
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for mesh in meshes:
		var view := mesh as MeshInstance3D
		var box: AABB = view.global_transform * view.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
