extends SceneTree
## Directly read staging GLBs, without installing them into runtime slots.
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	await process_frame
	for asset in ["shower", "dryer", "brush", "towel", "dog"]:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		state.set_handle_binary_image(GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED)
		var err := doc.append_from_file("res://art/incoming/style_b_test/test_b_%s.glb" % asset, state)
		if err != OK:
			push_error("STYLE_B_READ_FAIL " + asset)
			failed = true
			continue
		var scene := doc.generate_scene(state)
		root.add_child(scene)
		var meshes := state.get_meshes()
		var surfaces := 0
		for gltf_mesh in meshes:
			for surface in gltf_mesh.mesh.get_surface_count():
				var mat: StandardMaterial3D = gltf_mesh.mesh.get_surface_material(surface)
				if mat == null or mat.albedo_texture == null or mat.roughness_texture == null:
					failed = true
				if not "eye" in mat.resource_name and (not mat.normal_enabled or mat.normal_texture == null):
					failed = true
				surfaces += 1
		if asset == "dryer":
			var fan: Node3D = scene.find_child("Fan", true, false)
			if fan == null or not (fan.is_class("MeshInstance3D") or fan.is_class("ImporterMeshInstance3D")):
				failed = true
			else:
				var pivot := fan.position
				var body: Node3D = scene.find_child("Body", true, false)
				var initial := body.transform
				fan.rotate_z(PI / 3.0)
				if not fan.position.is_equal_approx(pivot) or body.transform != initial:
					failed = true
		print("STYLE_B_ENGINE ", asset, " meshes=", meshes.size(), " surfaces=", surfaces)
		scene.free()
	print("STYLE_B_ENGINE_PASS" if not failed else "STYLE_B_ENGINE_FAIL")
	await process_frame
	quit(1 if failed else 0)
