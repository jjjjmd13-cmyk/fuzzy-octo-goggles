extends "res://tests/qa_test.gd"
## 찻길 건너편 이웃 건물 6개 (대표 요청): 배경이라 충돌 없음 (못 감), 트럭 길 (x 9.7~11.5) 을 막지 않음,
## 납품 GLB 6종과 보도 경계 x=12를 실제 로더로 확인한다.

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
		check(outside.used_models.has(name), "%s GLB 사용" % name)
	check_eq(town.find_children("*", "CollisionShape3D", true, false).size(), 0, "충돌 없음 (배경)")
	check_eq(town.find_children("*", "CollisionObject3D", true, false).size(), 0, "충돌 몸체 없음")
	var road_edge := FpParcels.TRUCK_X + 0.9 + 0.5
	var street_props := town.get_node("town_street_props")
	var nearest := INF
	var nearest_object := INF
	var ground_count := 0
	for mesh in town.find_children("*", "MeshInstance3D", true, false):
		var view := mesh as MeshInstance3D
		var box: AABB = view.global_transform * view.get_aabb()
		nearest = minf(nearest, box.position.x)
		if street_props.is_ancestor_of(view) and view.name in ["Sidewalk", "Lawn"]:
			ground_count += 1
			check(box.position.x >= road_edge, "%s 바닥은 찻길 끝 x=%.2f부터 허용" % [view.name, road_edge])
		else:
			nearest_object = minf(nearest_object, box.position.x)
	check_eq(ground_count, 2, "보도와 잔디 바닥")
	check(nearest_object < INF and nearest_object > road_edge, "입체 소품은 찻길 바깥 (가장 가까운 x %.3f > %.2f)" % [nearest_object, road_edge])
	check(nearest > FpOutside.YARD_END_X + 1.5, "찻길 건너편")
	outside.free()
