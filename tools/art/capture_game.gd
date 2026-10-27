extends Node
## Actual Godot 4.4.1 runtime captures; requires a display/rendering backend.
## godot --path . tools/art/capture_game.tscn -- --output=/absolute/path

var output := "res://docs/dev/screenshots/retail"
var world: Node
var station: Node

var tree: SceneTree
var finished := false

func _ready() -> void:
	tree = get_tree()
	tree.current_scene = null
	tree.create_timer(90.0).timeout.connect(func():
		if not finished:
			push_error("Runtime capture timed out")
			tree.quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	tree.root.size = Vector2i(1280, 800)
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	Net.start_offline()
	await Net.session_started
	world = tree.current_scene
	world.input_enabled = false
	station = world.station
	while station.dog.model == null or not station.is_washing():
		await tree.process_frame
	world.set_process(false)
	station.set_process(false)
	station.dog_info = Vector4i(1, 0, 123456, 0)
	station.dog.setup(Tuning.data.mask_resolution, 0, 123456)
	station.dog.model.visible = true
	await tree.physics_frame
	await tree.physics_frame
	station.owner_model.go_sit(station.to_global(station.OWNER_CHAIR), station.global_position, 0.1)
	await tree.create_timer(0.2).timeout
	station.dog.show_mask()
	station.dog.set_blink(0.0, "wet")
	station.mood = 0.8
	station.owner_phase = station.OwnerPhase.WAIT
	station.stage = station.Stage.WET
	station.ratio = 0.0
	station.tool = station.Tool.SHOWER
	await _save("game_dirty")
	station.dog.mask.fill("scrub", 1.0)
	station.dog.mask.fill("wet", 1.0)
	station.stage = station.Stage.SCRUB
	station.tool = station.Tool.HAND
	station.ratio = 0.4
	var random := RandomNumberGenerator.new()
	random.seed = 123456
	for point in [Vector3(-0.06, 0.25, 0.12), Vector3(0.06, 0.25, 0.12), Vector3(0, 0.34, 0.10), Vector3(-0.08, 0.42, 0.14), Vector3(0.08, 0.42, 0.14)]:
		station.dog.add_foam(station.dog.model.to_global(point), 4, random)
	await _save("game_foam")
	station.dog.clear_foam()
	station.dog.mask.fill("rinse", 1.0)
	station.dog.scatter_drops(28, 123456)
	station.stage = station.Stage.TOWEL
	station.tool = station.Tool.TOWEL
	station.ratio = 0.0
	await _save("game_wet")
	station.dog.mask.fill("dry", 1.0)
	station.dog.show_drop_count(0)
	station.dog.fluff = 1.0
	station.stage = station.Stage.PAY
	station.ratio = 1.0
	station.owner_phase = station.OwnerPhase.REACT
	station.owner_model.come_react(station.to_global(station.OWNER_FRONT), 2)
	await tree.create_timer(0.7).timeout
	await _save("game_clean")
	# A separate QA camera verifies chair/feet contact. The normal captures use the game camera.
	station.owner_model.go_sit(station.to_global(station.OWNER_CHAIR), station.global_position, 0.1)
	await tree.create_timer(0.2).timeout
	world.hud.visible = false
	world.camera.position = station.to_global(station.OWNER_CHAIR + Vector3(1.0, 0.95, 1.3))
	world.camera.look_at(station.to_global(station.OWNER_CHAIR + Vector3(0, 0.55, 0)))
	await _save("owner_seated_qa")
	await Net.leave_session()
	print("RUNTIME_CAPTURE_PASS")
	finished = true
	tree.quit()

func _save(name: String) -> void:
	for i in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("No rendered viewport image: " + name)
		tree.quit(1)
		return
	var path := output.path_join(name + ".png")
	var error := image.save_png(path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		push_error("Cannot save rendered viewport: " + name)
		tree.quit(1)
	print("Saved runtime frame: ", name)
