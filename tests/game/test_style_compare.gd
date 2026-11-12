extends "res://tests/qa_test.gd"
## 빠른 확인 [그림체 비교] (개발 전용, 대표 요청 2026-11-11 ⑧): 파스텔 모형과 실사풍 시험 모형 (art/incoming/style_real_test/real_*.glb)
## 을 나란히. 파일이 없으면 "아직 없음", 있으면 실행 중에 읽어서 같은 바닥에 나란히. 출시 빌드에는 안 들어감.

const StyleCompare := preload("res://scripts/dev/style_compare.gd")
const QuickCheck := preload("res://scripts/dev/quick_check.gd")
const QUICK_SCENE := "res://scenes/dev/quick_check.tscn"
const TEST_DIR := "user://style_real_test_copy"


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)

	# 실사풍 파일이 아직 없음 → 줄마다 "아직 없음"
	var compare: Node3D = StyleCompare.new()
	compare.real_dir = "user://no_such_style_dir"
	add_child(compare)
	await get_tree().process_frame
	check_eq(compare.pairs.size(), 3, "강아지·목욕통·빵집 세 줄")
	check_eq(compare.missing_count(), 3, "파일이 없으면 셋 다 '아직 없음'")
	for pair in compare.pairs:
		check((pair.root as Node).get_node_or_null("Missing") != null, "%s: 아직 없음 표시" % (pair.root as Node).name)
		check((pair.pastel as Node).find_children("*", "MeshInstance3D", true, false).size() > 0, "%s: 파스텔 모형" % (pair.root as Node).name)
	compare.free()

	# 실사풍 파일이 있으면 (시험용으로 지금 모형 GLB 를 그 이름으로 복사) 실행 중에 읽어서 나란히
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for copy in [["res://assets/models/dog/dog.glb", "real_dog.glb"], ["res://assets/models/tub/tub.glb", "real_tub.glb"], ["res://assets/models/outside/town_bakery.glb", "real_bakery.glb"]]:
		check_eq(DirAccess.copy_absolute(ProjectSettings.globalize_path(copy[0]), ProjectSettings.globalize_path(TEST_DIR.path_join(copy[1]))), OK, "시험 파일 %s" % copy[1])
	compare = StyleCompare.new()
	compare.real_dir = TEST_DIR
	add_child(compare)
	await get_tree().process_frame
	check_eq(compare.missing_count(), 0, "파일이 있으면 '아직 없음' 없음")
	for pair in compare.pairs:
		var pastel := pair.pastel as Node3D
		var real := pair.real as Node3D
		check(real != null and real.find_children("*", "MeshInstance3D", true, false).size() > 0, "%s: 실사풍 모형을 읽음" % (pair.root as Node).name)
		var left := _box(pastel)
		var right := _box(real)
		check(left.get_center().x < 0.0 and right.get_center().x > 0.0 and left.end.x < right.position.x, "%s: 왼쪽 파스텔 · 오른쪽 실사풍, 안 겹침" % (pair.root as Node).name)
		check(absf(left.position.y) < 0.01 and absf(right.position.y) < 0.01, "%s: 둘 다 같은 바닥 (%.3f / %.3f)" % [(pair.root as Node).name, left.position.y, right.position.y])
	compare.show_pair(2)
	check(not (compare.pairs[0].root as Node3D).visible and (compare.pairs[2].root as Node3D).visible, "3 = 빵집만")
	var eye: Vector3 = compare.camera.global_position
	check(eye.distance_to(Vector3.ZERO) > compare.pairs[2].size, "빵집이 화면에 들어오게 물러섬")
	compare.free()
	for name in ["real_dog.glb", "real_tub.glb", "real_bakery.glb"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR.path_join(name)))

	# 빠른 확인 메뉴 줄 + 그 씬에는 가게 대신 비교 화면
	check(QuickCheck.FEATURES.any(func(f: Dictionary) -> bool: return f.id == "style" and f.name == "그림체 비교"), "빠른 확인 [그림체 비교]")
	Engine.set_meta("quick_check_feature", "style")
	var quick: Node = load(QUICK_SCENE).instantiate()
	add_child(quick)
	await get_tree().process_frame
	check(quick.find_child("StyleCompare", true, false) != null and quick.shop == null, "가게 대신 그림체 비교 화면")
	quick.free()
	Engine.set_meta("quick_check_feature", "day")


## 모형 메시 전체 상자 (세상 좌표)
func _box(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out
