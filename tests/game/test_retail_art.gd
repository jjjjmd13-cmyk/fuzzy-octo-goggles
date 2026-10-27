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
	check_eq(model.get("fur_meshes").size(), 16, "All 16 imported fur pieces found")
	check_eq(model.find_children("*", "CollisionShape3D", true, false).size(), 16, "16 convex hit shapes attached")
	for tag in ["L", "R"]:
		var ear := model.find_child("Ear_" + tag, true, false) as MeshInstance3D
		var shader := ear.material_override as ShaderMaterial
		check(shader != null and shader.get_shader_parameter("albedo_tex") != null, "Fur shader keeps imported ear albedo")
		var eye := model.find_child("Eye_" + tag, true, false) as MeshInstance3D
		check(eye.material_override == null, "Eye does not get fur shader")
	check_eq(world.station.owner_model.scale, Vector3.ONE, "Owner keeps metre scale")
	check(world.hud.card_title.get_theme_font("font").has_char(0xD55C), "HUD font renders Korean")
	check(world.hud.card_title.get_theme_font_size("font_size") >= 22, "HUD uses shared readable theme")
	await Net.leave_session()

func lowest_y(mesh: MeshInstance3D) -> float:
	var box := mesh.get_aabb()
	var low := INF
	for i in 8:
		var corner := box.position + Vector3(box.size.x if i & 1 else 0.0, box.size.y if i & 2 else 0.0, box.size.z if i & 4 else 0.0)
		low = minf(low, (mesh.global_transform * corner).y)
	return low
