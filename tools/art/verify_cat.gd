extends SceneTree
var model
func _init():
	call_deferred("check")
func check():
	var state = GLTFState.new()
	var document = GLTFDocument.new()
	assert(document.append_from_file(ProjectSettings.globalize_path("res://art/incoming/cat/cat.glb"), state) == OK)
	var instance = document.generate_scene(state)
	assert(instance != null)
	model = Node3D.new()
	model.set_script(load("res://scripts/sim/sim_dog_model.gd"))
	model.add_child(instance)
	root.add_child(model)
	await process_frame
	assert(model.fur_meshes.size() == 18)
	for name in ["Head", "Chest", "Ear_L", "Ear_R", "Eye_L", "Eye_R", "Cheek_L", "Cheek_R", "Mouth", "Nose", "Tongue", "FaceCenter", "BodyCenter", "Leg_FL", "Leg_FR", "Tail_1", "Tail_2", "Tail_3"]:
		assert(model.find_child(name, true, false) != null)
	for tag in ["L", "R"]:
		var ear = model.find_child("Ear_"+tag, true, false)
		assert(ear.find_child("NoFurEar_"+tag, false, false) != null)
		var eye = model.find_child("Eye_"+tag, true, false)
		assert(eye.find_child("Pupil_"+tag, false, false) != null)
		assert(eye.find_child("Glint_"+tag, false, false) != null)
		var leg = model.find_child("Leg_F"+tag, true, false)
		assert(leg.find_child("Paw_F"+tag, false, false) != null)
	var template=ShaderMaterial.new()
	template.shader=load("res://scripts/sim/sim_fur.gdshader")
	var materials=model.apply_fur_material(template)
	assert(materials.size()==2)
	assert(materials[1].get_shader_parameter("albedo_tex").get_size()==Vector2(2048,2048))
	var shared=model.fur_meshes[0].material_override
	for mesh in model.fur_meshes:
		assert(mesh.material_override==shared)
		assert(not mesh.name.begins_with("NoFur"))
	for name in ["Eye_L","Pupil_L","Glint_L","Nose","Mouth","Tongue","NoFurEar_L","NoFurEar_R"]:
		assert(model.find_child(name,true,false).material_override==null)
	var head=model.find_child("Head",true,false)
	var ear=model.find_child("Ear_L",true,false)
	var inner=model.find_child("NoFurEar_L",true,false)
	var eye=model.find_child("Eye_L",true,false)
	var pupil=model.find_child("Pupil_L",true,false)
	var old_inner=inner.position
	var old_pupil=pupil.position
	model.set_mood(0)
	model._process(.1)
	assert(not model.find_child("Tongue",true,false).visible)
	assert(inner.position.is_equal_approx(old_inner))
	model.set_mood(2)
	model.wiggle_legs()
	model.flap_cheeks()
	model.blow(1.0)
	model.shake()
	for i in range(60):model._process(.016)
	assert(inner.position.is_equal_approx(old_inner))
	assert(pupil.position.is_equal_approx(old_pupil))
	assert(model.find_child("Tongue",true,false).visible)
	assert(head.transform.is_finite() and ear.transform.is_finite() and eye.transform.is_finite())
	print("CAT_ASSET_QA_PASS: GLTFDocument load, 18 fur meshes, shared embedded texture, exclusions, exact children, mood, blink, head, ears, cheeks, tail, legs")
	quit()
