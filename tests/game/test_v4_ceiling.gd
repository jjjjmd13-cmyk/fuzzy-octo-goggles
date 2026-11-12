extends "res://tests/qa_test.gd"
## V4 가게 천장 (대표 요청 2026-11-11 ②): 방 전체를 덮는 밝은 천장 + 간단한 조명 기구.
## 교체 경로 assets/models/shop/ceiling.glb (방 좌표 그대로). 받은 그래픽이 있으면 그것, 임시 모형도 따로 확인. 그림자 없음.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpCeiling := preload("res://scripts/v4/fp_ceiling.gd")
const FpDecor := preload("res://scripts/v4/fp_decor.gd")


func run_test() -> void:
	time_limit_sec = 30.0
	var shop: Node3D = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	await get_tree().physics_frame
	var ceiling: Node3D = shop.ceiling
	check(ceiling != null and ceiling.is_inside_tree(), "가게에 천장이 있음")
	check(ceiling.global_position.is_zero_approx(), "모형 원점 = 방 바닥 가운데 (ART_SLOTS 4-8, 돌리지 않음)")
	check_eq(FpCeiling.MODEL_PATH, "res://assets/models/shop/ceiling.glb", "교체 경로")
	# 받은 그래픽이 있으면 그것 (임시 모형 대신), 없으면 임시 모형
	var delivered := ResourceLoader.exists(FpCeiling.MODEL_PATH)
	check((ceiling.get_node_or_null("Art") != null) == delivered and (ceiling.get_node_or_null("Panel") == null) == delivered, "ceiling.glb 가 있으면 그것을 씀 (있음: %s)" % delivered)
	# 지금 쓰는 천장 (받은 것 또는 임시): 방 전체를 덮음 (벽 안쪽 x −4 ~ 4, z −3.5 ~ 3.5), 머리 위, 용마루 ≈ 3.8, 그림자 없음
	var box := _box(ceiling, true)
	check(box.position.x <= -3.9 and box.end.x >= 3.9 and box.position.z <= -3.4 and box.end.z >= 3.4, "천장이 방 전체를 덮음 (%s)" % box)
	check(box.position.y >= 2.6, "천장은 머리 위 (가장 낮은 곳 %.2f m)" % box.position.y)
	check(absf(box.end.y - 3.8) < 0.15, "맞배지붕 용마루 y ≈ 3.8 (%.2f)" % box.end.y)
	var light := ceiling.get_node("CeilingLight") as OmniLight3D
	check(light != null and light.light_energy > 0.0, "천장 빛")
	check(light.global_position.y < 3.0 and absf(light.global_position.x) < 4.0 and absf(light.global_position.z) < 3.5, "빛은 방 안 천장 바로 아래")
	var decor_lamp: Vector3 = FpDecor.PLACES["lamp"].pos
	check(decor_lamp.is_equal_approx(FpCeiling.HOOK_POS) and FpCeiling.HOOK_POS.is_equal_approx(Vector3(0, 3.0, -1.6)), "꾸미기 조명은 천장 조명 고리 (0, 3, −1.6) 에 매달림")

	# 임시 모형 (그래픽이 빠지면 쓰는 것): 아랫면 3 m, 들보 3줄, 벽지보다 밝은 색, 조명 기구
	var holder := Node3D.new()
	add_child(holder)
	FpCeiling._build_placeholder(holder)
	var panel_view := holder.get_node("Panel") as MeshInstance3D
	check(is_equal_approx(panel_view.global_position.y - (panel_view.mesh as BoxMesh).size.y / 2.0, FpCeiling.HEIGHT) and is_equal_approx(FpCeiling.HEIGHT, 3.0), "임시 천장 아랫면 = 벽 높이 3 m")
	var placeholder_box := _box(holder, false)
	check(placeholder_box.position.x <= -3.9 and placeholder_box.end.x >= 3.9 and absf(placeholder_box.end.y - 3.8) < 0.15, "임시 천장도 방 전체 + 용마루 3.8 (%s)" % placeholder_box)
	check_eq(holder.find_children("Beam*", "", false, false).size(), 3, "임시 들보 3줄")
	var color: Color = (panel_view.material_override as StandardMaterial3D).albedo_color
	check(color.get_luminance() > Color(0.85, 0.78, 0.66).get_luminance(), "임시 천장은 벽지보다 밝은 색")
	var fixture := holder.get_node("Fixture") as Node3D
	check(fixture != null and fixture.global_position.distance_to(decor_lamp) > 1.0, "기본 조명 기구는 꾸미기 조명과 안 겹침")
	holder.free()
	shop.free()


## 메시 전체 상자 (세상 좌표). shadows = 그림자 안 드리움도 같이 봄
func _box(root: Node3D, shadows: bool) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local := mesh.get_aabb()
		for i in 8:
			var corner := mesh.global_transform * local.get_endpoint(i)
			box = AABB(corner, Vector3.ZERO) if first else box.expand(corner)
			first = false
		if shadows:
			check_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "천장은 그림자 안 드리움: %s" % mesh.name)
	return box
