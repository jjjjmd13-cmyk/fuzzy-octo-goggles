extends SceneTree
## Asset-only acceptance. Game scripts/scenes are not changed.
const IDS := ["shower_massage", "shower_rainbow", "foam_sponge", "foam_cloud", "towel", "towel_thick", "towel_microfiber", "towel_mitt", "towel_cloud", "dryer_twin", "dryer_turbo", "dryer_tornado", "brush_twin", "brush_sparkle"]
const JOINTS := {"shower_massage": ["Dial"], "shower_rainbow": ["Ring"], "foam_cloud": ["Bubbles"], "dryer_twin": ["Fan_L", "Fan_R"], "dryer_turbo": ["Fan"], "dryer_tornado": ["Spiral"], "brush_sparkle": ["Head"]}
var failed := false

func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		printerr("TOOL_ASSET_FAIL: " + message)

func _verify() -> void:
	var view_script = load("res://scripts/v4/fp_tool_view.gd")
	for id in IDS:
		var path := "res://assets/models/tools/%s.glb" % id
		var scene := load(path) as PackedScene
		check(scene != null, id + " imported as PackedScene")
		if scene == null: continue
		var instance := scene.instantiate() as Node3D
		root.add_child(instance)
		check(instance.transform.is_equal_approx(Transform3D.IDENTITY), id + " root grip origin")
		var meshes := instance.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty(), id + " mesh data")
		for mesh in meshes:
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				check(material != null and material.albedo_texture != null, id + " embedded albedo")
				if material != null and material.albedo_texture != null:
					check(material.albedo_texture.get_width() == 128 and material.albedo_texture.get_height() == 128, id + " palette resolution")
		for part in JOINTS.get(id, []):
			var joint := instance.find_child(part, true, false) as Node3D
			check(joint != null, id + " moving mesh " + part)
			if joint == null: continue
			check(joint is MeshInstance3D, part + " contains actual moving geometry")
			var body := instance.find_child("Body", true, false) as Node3D
			var body_rest := body.transform
			var rest := joint.transform
			if part == "Bubbles": joint.position.y += 0.012
			else: joint.rotate_z(0.6)
			check(not rest.is_equal_approx(joint.transform), id + " joint can move independently")
			check(body.transform.is_equal_approx(body_rest), id + " joint does not move body")
			joint.transform = rest
		# The existing automatic asset slot must load the new GLB (no game code edit).
		var auto_model: Node3D = view_script.make_model(id)
		check(auto_model.scene_file_path == path, id + " automatic model slot")
		auto_model.free()
		instance.queue_free()
		print("TOOL_ASSET_CHECK: ", id)
	await process_frame
	print("TOOL_ASSETS_PASS" if not failed else "TOOL_ASSETS_FAIL")
	quit(1 if failed else 0)
