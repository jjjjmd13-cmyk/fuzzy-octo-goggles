extends "res://tests/qa_test.gd"
## 목욕통마다 동물 둘레가 다 닿는지 (대표 요청 2026-11-11 ③, 조개 욕조 뚜껑이 등을 가림):
## 처음 목욕통 + 꾸미기 목욕통 3종 (원목·고양이 발·조개) 마다, 사람처럼 동물 둘레 12 방향에서 1.2 m 떨어져 눈높이로
## 몸 가운데와 등 쪽을 바라볼 때, 가운데 점 광선이 목욕통 모형 (보이는 메시 그대로) 보다 동물에 먼저 닿는지 본다.
## 강아지·고양이 둘 다.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpTubFix := preload("res://scripts/v4/fp_tub_fix.gd")
## 목욕통 모형 판정 층 (시험용, 게임에서 안 씀)
const OCCLUDER_LAYER := 1 << 19
const DIRECTIONS := 12
const STAND := 1.2

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 90.0
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	shop.player.set_physics_process(false)
	for i in 3:
		await get_tree().physics_frame
	var eye_y: float = shop.player.global_position.y + shop.player.EYE_HEIGHT
	for tub_id in ["", "tub_wood", "tub_claw", "tub_shell"]:
		shop.decor_view.show_item("tub", tub_id)
		var tub: Node3D = shop.decor_view.nodes.get("tub", shop._tub_view)
		for animal in ["dog", "cat"]:
			if shop.has_dog:
				shop.done = true
				shop.next_guest()
			shop.guests.quick_animals = [{"animal": animal, "trait": ""}]
			shop.guests.spawn("forever")
			shop.next_guest()
			shop.drop()
			for i in 3:
				await get_tree().physics_frame
			var occluders := _occluders(tub)
			await get_tree().physics_frame
			var center: Vector3 = shop.dog.model.to_global(shop.dog._body_center())
			var blocked := []
			for i in DIRECTIONS:
				var angle := TAU * i / DIRECTIONS
				var dir := Vector3(sin(angle), 0, cos(angle))
				var eye := Vector3(center.x, eye_y, center.z) + dir * STAND
				# 몸 가운데 · 등 쪽 (가운데보다 조금 위)
				for target in [center, center + Vector3(0, 0.1, 0)]:
					if not _sees_animal(eye, target):
						blocked.append("%d° %s" % [roundi(rad_to_deg(angle)), "등" if target != center else "몸"])
			check(blocked.is_empty(), "%s · %s: 둘레 %d 방향 모두 닿음 (가림 %s)" % [tub_id if not tub_id.is_empty() else "처음 목욕통", animal, DIRECTIONS, blocked])
			for body in occluders:
				body.free()
	# 조개 욕조 보정표: 뚜껑 (뒤쪽 높은 부채) 을 낮춤
	check(FpTubFix.FIX.has("tub_shell"), "조개 욕조 보정표")
	shop.decor_view.show_item("tub", "tub_shell")
	var shell: Node3D = shop.decor_view.nodes["tub"]
	var top := -INF
	for node in shell.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		top = maxf(top, box.end.y)
	check(top < 1.3, "조개 뚜껑을 낮춤 (가장 높은 곳 %.2f m, 원래 1.5)" % top)
	shop.free()


## 목욕통 보이는 메시마다 같은 모양 판정을 만든 것 (시험용 층)
func _occluders(tub: Node3D) -> Array[Node]:
	var out: Array[Node] = []
	for node in tub.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var body := StaticBody3D.new()
		body.collision_layer = OCCLUDER_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(shape)
		shop.add_child(body)
		body.global_transform = mesh.global_transform
		out.append(body)
	return out


## 눈에서 target 쪽 광선이 목욕통보다 동물에 먼저 닿는지
func _sees_animal(eye: Vector3, target: Vector3) -> bool:
	var to := eye + (target - eye).normalized() * 3.0
	var query := PhysicsRayQueryParameters3D.create(eye, to, OCCLUDER_LAYER | shop.DOG_LAYER)
	query.hit_back_faces = true
	var hit := shop.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.collider as CollisionObject3D).collision_layer & shop.DOG_LAYER != 0
