extends "res://tests/qa_test.gd"
## Check production scenes, +Z game-facing animation axes, seated feet and shader/UI wiring.
const DOG := preload("res://scenes/art/sim/dog_model.tscn")
const OWNER := preload("res://scenes/art/sim/owner_model.tscn")

func run_test() -> void:
	get_tree().root.size = Vector2i(1280, 800)
	get_tree().current_scene = null
	var dog := DOG.instantiate()
	add_child(dog)
	dog.set_process(false)
	check(dog.get_script().resource_path.ends_with("sim_dog_model.gd"), "Production dog uses GLB animation hook")
	check(dog.get_node("Art").scene_file_path.begins_with("res://assets/models/dog/"), "Production dog has imported GLB")
	var head := dog.find_child("Head", true, false) as Node3D
	var nose := dog.find_child("Nose", true, false) as Node3D
	var neutral_y := nose.global_position.y
	check(nose.global_position.z > head.global_position.z, "GLB -Z front is wrapped to game +Z")
	dog.watch(Vector3(0, 0.8, 0.4), false)
	dog.call("_process", 1.0)
	check(nose.global_position.y > neutral_y + 0.02, "Looking above raises imported head rather than lowering it")
	dog.watch(Vector3(0.7, 0.5, 0.4), false)
	dog.call("_process", 1.0)
	check(nose.global_position.x > head.global_position.x + 0.04, "Looking right turns imported head right")

	var animated_cheek: Node3D = dog.find_child("Cheek_L", true, false)
	var cheek_rest := animated_cheek.transform
	dog.flap_cheeks()
	dog.call("_process", 0.02)
	check(not animated_cheek.transform.is_equal_approx(cheek_rest), "Dryer response moves separate cheek")

	var owner := OWNER.instantiate()
	add_child(owner)
	owner.set_process(false)
	check(is_equal_approx(owner.height, 1.55), "Owner height is 1.55 m without scene scale")
	for i in range(6):
		owner.set_variant(i)
		var torso := owner.find_child("ShirtTorso", true, false) as MeshInstance3D
		var cap := owner.find_child("CapCrown", true, false) as MeshInstance3D
		check((torso.get_active_material(0) as BaseMaterial3D).albedo_color.is_equal_approx(owner.SHIRTS[i]), "Shirt variant %d" % i)
		check((cap.get_active_material(0) as BaseMaterial3D).albedo_color.is_equal_approx(owner.HATS[i]), "Hat variant %d" % i)
	owner.go_sit(Vector3(1.42, 0, -0.65), Vector3.ZERO, 0.01)
	owner.call("_process", 0.02)
	owner.call("_process", 0.5)
	for tag in ["L", "R"]:
		var hip := owner.find_child("Leg_" + tag, true, false) as Node3D
		var knee := owner.find_child("Knee_" + tag, true, false) as MeshInstance3D
		check(absf(hip.global_position.y - 0.455) < 0.005, "Hip is seated above 0.4 m cushion")
		check(absf(lowest_y(knee)) < 0.01, "Seated foot touches floor: " + tag)
	check(owner.height < 1.3, "Seated speech bubble follows the lowered body")
	owner.come_react(Vector3(1.2, 0, 0.1), 1)
	owner.call("_process", 1.0)
	owner.call("_process", 0.02)
	check(absf(owner.height - 1.55) < 0.01, "Standing height restores after sitting")
	for tag in ["L", "R"]:
		check(absf(lowest_y(owner.find_child("Knee_" + tag, true, false))) < 0.01, "Standing foot returns to floor")
	dog.queue_free()
	owner.queue_free()
	await get_tree().process_frame

	Net.start_offline()
	await Net.session_started
	var world := get_tree().current_scene
	world.input_enabled = false
	while world.station.dog.model == null:
		await get_tree().process_frame
	var model: Node3D = world.station.dog.model
	check_eq(model.scene_file_path, "res://scenes/art/sim/dog_model.tscn", "World uses production dog wrapper")
	check_eq(model.get("fur_meshes").size(), 18, "All 18 imported fur pieces found")
	check_eq(model.find_children("*", "CollisionShape3D", true, false).size(), 18, "18 convex hit shapes attached")
	check_eq(model.get("_cheeks").size(), 2, "Both cheek joints found by animation script")
	for tag in ["L", "R"]:
		var cheek := model.find_child("Cheek_" + tag, true, false) as MeshInstance3D
		check(cheek != null and cheek.get_parent().name == "Head", "Separate cheek is parented to Head: " + tag)
		check(cheek.material_override is ShaderMaterial, "Cheek gets game fur shader: " + tag)
		var ear := model.find_child("Ear_" + tag, true, false) as MeshInstance3D
		var shader := ear.material_override as ShaderMaterial
		check(shader != null and shader.get_shader_parameter("albedo_tex") != null, "Fur shader keeps imported ear albedo")
		var eye := model.find_child("Eye_" + tag, true, false) as MeshInstance3D
		check(eye.material_override == null, "Eye does not get fur shader")
	# 이슈 #44: 진흙·마스크는 처음 자세 위치로 찾으므로 머리가 움직여도 부위에 붙어 있다
	var head_fur: MeshInstance3D = null
	var head_node := model.find_child("Head", true, false) as Node3D
	for mesh: MeshInstance3D in model.get("fur_meshes"):
		if (mesh == head_node or head_node.is_ancestor_of(mesh)) and not mesh.name.begins_with("Ear"):
			head_fur = mesh
			break
	if check(head_fur != null, "Head has a fur mesh"):
		var vertex: Vector3 = head_fur.get_aabb().get_center() + head_fur.get_aabb().size * 0.4
		var start := _rest_lookup(head_fur, vertex)
		var posed_before: Vector3 = model.global_transform.affine_inverse() * head_fur.global_transform * vertex
		check(start.distance_to(posed_before) < 0.03, "Mask lookup starts at the head's place on the body")
		model.watch(model.to_global(Vector3(0.8, 0.2, 0.4)), false)
		for i in 30:
			await get_tree().process_frame
		var posed_after: Vector3 = model.global_transform.affine_inverse() * head_fur.global_transform * vertex
		check(posed_before.distance_to(posed_after) > 0.01, "Head actually turned (%.3f m)" % posed_before.distance_to(posed_after))
		check(_rest_lookup(head_fur, vertex).distance_to(start) < 0.0001, "Fur mask lookup stays on the head while it turns")
	# 걷다가 몸을 돌리면 회전을 다시 짜면서 크기에 아주 작은 오차가 생긴다 (0.9999999)
	check(world.station.owner_model.scale.is_equal_approx(Vector3.ONE), "Owner keeps metre scale (%s)" % world.station.owner_model.scale)
	check(world.hud.card_title.get_theme_font("font").has_char(0xD55C), "HUD font renders Korean")
	check(world.hud.card_title.get_theme_font_size("font_size") >= 22, "HUD uses shared readable theme")
	await Net.leave_session()

## 셰이더와 같은 식: 처음 자세 행렬(instance uniform 세 줄)로 정점 → 모형 기준 위치
func _rest_lookup(mesh: MeshInstance3D, vertex: Vector3) -> Vector3:
	var v := Vector4(vertex.x, vertex.y, vertex.z, 1.0)
	var rows: Array[Vector4] = []
	for row in ["rest_row_x", "rest_row_y", "rest_row_z"]:
		rows.append(mesh.get_instance_shader_parameter(row))
	return Vector3(rows[0].dot(v), rows[1].dot(v), rows[2].dot(v))


func lowest_y(mesh: MeshInstance3D) -> float:
	var box := mesh.get_aabb()
	var low := INF
	for i in 8:
		var corner := box.position + Vector3(box.size.x if i & 1 else 0.0, box.size.y if i & 2 else 0.0, box.size.z if i & 4 else 0.0)
		low = minf(low, (mesh.global_transform * corner).y)
	return low
