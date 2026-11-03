extends "res://tests/qa_test.gd"
## PR #71 의 다중 surface GLB, 손목 피벗, 반납/빠른 교체 회귀 검사.
const SCENE := preload("res://scenes/v4/fp_shop.tscn")
var shop: Node3D

func run_test() -> void:
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.player.set_physics_process(false)
	await get_tree().physics_frame
	check_eq(shop.TOOLS.keys(), ["shower", "shampoo", "dryer", "brush", "scissors"], "V4 도구: 샤워기·샴푸·드라이기·빗·가위 (수건은 기본 순서에서 빠짐)")
	check(ResourceLoader.exists("res://assets/models/tools/dryer.glb"), "드라이어 자산 보존")
	for id in shop.TOOLS:
		# 아직 그림이 없는 도구(빗)는 임시 모형이라 건너뜀. assets/models/tools/<id>.glb 가 오면 저절로 검사됨
		if not ResourceLoader.exists("res://assets/models/tools/%s.glb" % id):
			continue
		var pickup: StaticBody3D = shop._pickups[id]
		var mats: Array = shop._glow_materials[id]
		check(mats.size() >= 2, "%s 다중 surface 재질 유지" % id)
		var color: Color = mats[0].albedo_color
		shop._set_glow(pickup, true)
		for mat in mats:
			check(mat.emission_enabled, "%s 모든 surface 강조" % id)
		shop.pick(id)
		check_eq(pickup.collision_layer, 0, "집은 도구는 ray 에서도 제외")
		var view: Node3D = shop._held_view
		check_eq(view.model.scene_file_path, "res://assets/models/tools/%s.glb" % id, "실제 GLB 사용")
		for wrist in [view.right_wrist, view.left_wrist]:
			var hand: MeshInstance3D = wrist.get_child(0)
			check_eq(hand.position, Vector3.ZERO, "메시 원점이 손목에 놓임")
			check(hand.mesh != null, "노란 장갑 실제 메시")
		var meshes: Array[Node] = view.model.find_children("*", "MeshInstance3D", true, false)
		if view.model is MeshInstance3D: meshes.append(view.model)
		for mesh in meshes:
			for surface in mesh.mesh.get_surface_count():
				var mat: StandardMaterial3D = mesh.get_active_material(surface)
				check(not mat.emission_enabled, "선반 강조가 손/공유 자산으로 번지지 않음")
		shop._set_glow(pickup, false)
		check_eq(mats[0].albedo_color, color, "강조 해제 후 원래 색")
		# 렌더러 없이도 시간에 따른 실제 변환과 복귀를 검증한다.
		shop.set_process(false)
		view.update_motion(0.4, false)
		view.update_motion(0.6, false)
		var rest: Transform3D = view.transform
		var wrist_rest: Transform3D = view.right_wrist.transform
		view.update_motion(0.2, true)
		check(not view.transform.is_equal_approx(rest), "도구 사용 시 위치 모션")
		check(not view.right_wrist.transform.is_equal_approx(wrist_rest), "실제 손목 피벗에서 회전")
		check_eq(view.model.get_parent(), view.right_wrist, "도구가 손목을 따라 움직임")
		for i in 30: view.update_motion(1.0 / 30.0, false)
		check(view.transform.is_equal_approx(rest), "사용 중지 시 중립 위치 복귀")
		check(view.tip_position().is_equal_approx(view.model.to_global(view.tip_offset())), "GLB 분사구·바람구멍 위치 추적")
		shop.drop()
		check_eq(shop.held, "", "Q 즉시 사용 해제")
		check(not pickup.visible, "반납 중 도구 복제 없음")
		shop._update_tool_views(0.4, false)
		check(pickup.visible and pickup.collision_layer != 0, "반납 완료 후 표시/선택 복구")
	# Q→재선택→다른 도구 연속 교체 중 오래된 반납이 현재 도구를 되살리지 않음.
	shop.pick("shower")
	shop.drop()
	shop.pick("shower")
	shop.pick("shampoo")
	check(not shop._held_view.visible, "교체 중 이전 양손이 내려간 뒤 새 양손 표시")
	shop.pick("dryer")
	shop._update_tool_views(0.5, false)
	check_eq(shop.held, "dryer", "빠른 교체 후 마지막 도구 유지")
	check(shop._pickups.shower.visible and shop._pickups.shampoo.visible, "이전 도구 모두 반환")
	check(not shop._pickups.dryer.visible, "현재 든 드라이기 중복 생성 없음")
	check_eq(shop._returning_views.size(), 0, "반납 뷰 누적 없음")
	shop.pick("comb")
	check_eq(shop.held, "dryer", "미등록 도구가 든 도구를 대체하지 않음")
