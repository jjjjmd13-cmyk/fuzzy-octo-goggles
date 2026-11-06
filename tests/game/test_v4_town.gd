extends "res://tests/qa_test.gd"
## 찻길 건너편 이웃 건물 6개 (대표 요청): 배경이라 충돌 없음 (못 감), 트럭 길 (x 9.7~11.5) 을 막지 않음,
## art 파일 (assets/models/outside/town_*.glb) 이 오면 이름 그대로 바뀜.

const FpOutside := preload("res://scripts/v4/fp_outside.gd")
const FpParcels := preload("res://scripts/v4/fp_parcels.gd")


func run_test() -> void:
	var outside := FpOutside.new()
	add_child(outside)
	await get_tree().process_frame
	var town := outside.get_node_or_null("Town")
	check(town != null, "이웃 건물 노드")
	for name in ["town_bakery", "town_flower", "town_cafe", "town_house_a", "town_house_b", "town_street_props"]:
		check(town.get_node_or_null(name) != null, "%s 자리" % name)
	check_eq(town.find_children("*", "CollisionShape3D", true, false).size(), 0, "충돌 없음 (배경)")
	check_eq(town.find_children("*", "CollisionObject3D", true, false).size(), 0, "충돌 몸체 없음")
	var truck_max := FpParcels.TRUCK_X + 0.9
	var nearest := 1e9
	for mesh in town.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
		nearest = minf(nearest, box.position.x)
	check(nearest > truck_max + 0.5, "트럭 길을 막지 않음 (가장 가까운 x %.2f > %.2f)" % [nearest, truck_max + 0.5])
	check(nearest > FpOutside.YARD_END_X + 1.5, "찻길 건너편")
	outside.free()
