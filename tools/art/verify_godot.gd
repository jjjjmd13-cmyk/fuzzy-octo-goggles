extends SceneTree
## GLB acceptance check using the existing game animation/material hooks.
## godot --headless --path . --script tools/art/verify_godot.gd

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr(message)

func imported(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	check(error == OK, "GLB parse failed: " + path)
	if error != OK:
		return null
	return document.generate_scene(state)

func _verify() -> void:
	var imported_dog := imported("res://art/incoming/dog/dog.glb")
	if imported_dog == null:
		quit(1)
		return
	var dog := Node3D.new()
	dog.set_script(load("res://scripts/sim/sim_dog_model.gd"))
	imported_dog.rotation.y = PI
	dog.add_child(imported_dog)
	root.add_child(dog)
	var required := ["Head", "Chest", "Eye_L", "Eye_R", "Ear_L", "Ear_R", "Tail_1", "Tail_2", "Tail_3", "Leg_FL", "Leg_FR", "Mouth", "Tongue", "Nose"]
	for part in required:
		check(dog.find_child(part, true, false) != null, "Missing imported dog part: " + part)
	var fur_count: int = dog.get("fur_meshes").size()
	check(fur_count > 0, "No fur meshes found")
	var template := ShaderMaterial.new()
	template.shader = load("res://scripts/sim/sim_fur.gdshader")
	var applied: Array = dog.call("apply_fur_material", template)
	check(applied.size() == 2, "Expected one shared clean albedo shader copy")
	var shapes := dog.find_children("*", "CollisionShape3D", true, false)
	check(shapes.size() == fur_count, "Fur convex hit shape count mismatch")
	for name in ["Ear_L", "Ear_R"]:
		var mesh := dog.find_child(name, true, false) as MeshInstance3D
		var material := mesh.material_override as ShaderMaterial
		check(material != null and material.get_shader_parameter("albedo_tex") != null, "Ear albedo was lost")
	dog.call("set_mood", 0)
	dog.call("_process", 0.1)
	check(not (dog.find_child("Tongue", true, false) as Node3D).visible, "Tongue should hide when unhappy")
	dog.call("set_mood", 2)
	dog.call("wiggle_legs")
	dog.call("blow", 0.7)
	dog.call("watch", Vector3(0.2, 0.55, 0.4), false)
	dog.call("_process", 0.1)
	check((dog.find_child("Tongue", true, false) as Node3D).visible, "Tongue should show when happy")
	check(abs((dog.find_child("Leg_FL", true, false) as Node3D).rotation.x) > 0.01, "Shoulder did not animate")
	var owner := Node3D.new()
	owner.set_script(load("res://scripts/sim/sim_owner_model.gd"))
	var owner_glb := imported("res://art/incoming/owner/owner.glb")
	owner_glb.rotation.y = PI
	owner.add_child(owner_glb)
	root.add_child(owner)
	for part in ["Body", "Head", "Arm_L", "Arm_R", "Leg_L", "Leg_R"]:
		check(owner.find_child(part, true, false) != null, "Missing owner part: " + part)
	for i in range(6):
		owner.call("set_variant", i)
		var expected: Color = owner.get("SHIRTS")[i]
		var torso := owner.find_child("ShirtTorso", true, false) as MeshInstance3D
		check((torso.get_active_material(0) as BaseMaterial3D).albedo_color.is_equal_approx(expected), "Shirt variant failed: %d" % i)
		var cap := owner.find_child("CapCrown", true, false) as MeshInstance3D
		check((cap.get_active_material(0) as BaseMaterial3D).albedo_color.is_equal_approx(owner.get("HATS")[i]), "Hat variant failed: %d" % i)
	for slot in ["tub", "turntable", "chair", "tiles/floor", "tiles/wall"]:
		var path := "res://art/incoming/%s/%s.glb" % [slot, slot] if not slot.contains("/") else "res://art/incoming/%s.glb" % slot
		var asset := imported(path)
		check(asset != null, "Failed to load " + path)
		if asset != null:
			asset.free()
	print("ART_RUNTIME_CHECK: %s; fur meshes=%d; convex shapes=%d; owner colors=6" % ["PASS" if failures.is_empty() else "FAIL", fur_count, shapes.size()])
	dog.queue_free()
	owner.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
