extends SceneTree
var base_path: String
func _init():
	base_path = ProjectSettings.globalize_path("res://")
	if OS.get_cmdline_user_args().size()>0:
		base_path=OS.get_cmdline_user_args()[0]
	call_deferred("check")
func load_prop(filename: String) -> Node3D:
	var state=GLTFState.new()
	var doc=GLTFDocument.new()
	assert(doc.append_from_file(base_path.path_join("art/incoming/album/"+filename),state)==OK)
	var node=doc.generate_scene(state)
	assert(node!=null)
	root.add_child(node)
	return node
func check():
	var book=load_prop("album_book.glb")
	var cover=book.find_child("Cover",true,false) as MeshInstance3D
	assert(cover!=null)
	assert(cover.global_position.is_equal_approx(Vector3(-.175,.052,0)))
	assert(cover.global_basis.y.is_equal_approx(Vector3(0,0,1)))
	var fixed_hinge=cover.global_position
	var free_point=cover.to_local(Vector3(.16,.056,0))
	var pages=book.find_child("Pages",true,false) as Node3D
	var pages_rest=pages.global_transform
	var paw=book.find_child("GoldPawPad",true,false) as Node3D
	assert(paw.get_parent()==cover)
	var paw_rest=paw.global_position
	cover.rotate_object_local(Vector3.UP,deg_to_rad(75))
	assert(cover.to_global(free_point).y>.36)
	assert(cover.global_position.is_equal_approx(fixed_hinge))
	assert(pages.global_transform.is_equal_approx(pages_rest))
	assert(not paw.global_position.is_equal_approx(paw_rest))
	var mat=cover.mesh.surface_get_material(0) as StandardMaterial3D
	assert(mat!=null and mat.normal_enabled==false)
	assert(mat.albedo_texture.get_size()==Vector2(512,32))
	var board=load_prop("photo_board.glb")
	for i in range(1,7):
		var slot=board.find_child("Slot_"+str(i),true,false) as Node3D
		assert(slot!=null and not slot is MeshInstance3D)
		assert(abs(slot.global_position.z+.029)<.00001)
		assert(slot.global_basis.z.is_equal_approx(Vector3(0,0,1)))
		for x in [-.1,.1]:
			for y in [-.1,.1]:
				var pt=slot.to_global(Vector3(x,y,0))
				assert(abs(pt.x)<.455 and abs(pt.y)<.305)
	var sizes={"album_page":Vector2i(1024,1280),"photo_unknown":Vector2i(512,512),"new_photo_badge":Vector2i(128,128)}
	for color in ["grey","white","pink","gold"]:sizes["photo_frame_"+color]=Vector2i(512,600)
	for spot in ["chin","ear_back","back","rump"]:sizes["fav_spot_"+spot]=Vector2i(128,128)
	for name in sizes:
		var image=Image.load_from_file(base_path.path_join("art/incoming/album_ui/"+name+".png"))
		assert(image!=null and image.get_size()==sizes[name])
		assert(image.get_pixel(0,0).a==0)
		if name.begins_with("photo_frame_"):
			assert(image.get_pixel(256,256).a==0 and image.get_pixel(256,500).a>.99)
	book.queue_free()
	board.queue_free()
	await process_frame
	print("ALBUM_ASSET_QA_PASS: both GLBs, embedded PNGs, Cover local-Y hinge opens upward, paw follows cover, pages stay, 6 empty tilted slots, 11 RGBA UI PNGs")
	quit()
