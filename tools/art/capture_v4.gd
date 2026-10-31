extends Node
## 실제 V4 뷰포트 촬영. 기존 게임 씬의 조준/사용/집기/반납을 구동한다.
## xvfb-run godot --path . --rendering-method gl_compatibility --fixed-fps 30 \
##   tools/art/capture_v4.tscn -- --output=/absolute/path
## --write-movie /tmp/v4.avi 를 더하면 손목 동작 연속 영상도 저장된다.
const SCENE := preload("res://scenes/v4/fp_shop.tscn")
var output := "res://docs/dev/screenshots/v4-glb"
var shop: Node3D

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	get_tree().root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_capture")

func _capture() -> void:
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.player.set_physics_process(false)
	shop.player.set_process_unhandled_input(false)
	shop.dog.setup(Tuning.data.mask_resolution, 0, 123456)
	shop.dog.show_mask()
	shop.player.position = Vector3(-1.25, 0.05, -0.8)
	shop.player.camera.look_at(shop._pickups.shampoo.global_position + Vector3(0, 0.12, 0))
	await _frames(30)
	await _save("01-shelf")
	shop.pick("shower")
	await _frames(25)
	shop.player.position = Vector3(0, 0.05, -0.05)
	shop.player.rotation = Vector3.ZERO
	shop.player.camera.look_at(shop.dog.global_position + Vector3(0, 0.19, 0))
	await _frames(20)
	shop.using = true
	await _frames(45)
	await _save("02-shower")
	shop.using = false
	await _frames(15)
	shop.pick("shampoo")
	await _frames(30)
	shop.using = true
	await _frames(40)
	await _save("03-shampoo")
	shop.using = false
	shop.pick("shower")
	await _frames(25)
	shop.using = true
	await _frames(40)
	shop.using = false
	shop.pick("towel")
	await _frames(25)
	shop.using = true
	await _frames(45)
	await _save("04-towel")
	shop.using = false
	await _frames(15)
	shop.drop()
	await _frames(5)
	await _save("05-return")
	await _frames(20)
	await _save("06-empty")
	print("V4_RUNTIME_CAPTURE_PASS")
	get_tree().quit()

func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(label + ".png")) != OK:
		push_error("V4 capture failed: " + label)
		get_tree().quit(1)
