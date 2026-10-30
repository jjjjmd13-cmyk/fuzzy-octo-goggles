extends "res://tests/qa_test.gd"
## V4 1인칭 시제품 (scenes/v4/fp_shop.tscn): 도구를 바라보면 집을 수 있고, 강아지에 대고
## 누르고 있으면 샤워기 → 샴푸 → 샤워기(헹굼) → 수건 순서로 빨리 깨끗해지는지 본다.
## 입력은 끄고(input_enabled = false) 쓰는 함수를 직접 부른다. 1인용이라 동기화 검사는 없음.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const STEP := 1.0 / 30.0
## 도구 하나로 한 바퀴 훑는 데 이 시간(초) 안이어야 "짧고 시원하게"
const TOOL_LIMIT_SEC := 25.0

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 90.0
	get_tree().root.size = Vector2i(1280, 800)
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	for i in 3:
		await get_tree().physics_frame

	# 조준: 선반의 샤워기를 바라보면 hovered 가 된다
	var pickup: Node3D = shop._pickups["shower"]
	shop.player.global_position = Vector3(-1.4, 0.05, pickup.global_position.z)
	shop.player.look_at(Vector3(pickup.global_position.x, shop.player.global_position.y, pickup.global_position.z))
	shop.player.camera.look_at(pickup.global_position + Vector3(0, 0.17, 0))
	await get_tree().physics_frame
	shop._update_aim()
	check_eq(shop.hovered, "shower", "샤워기를 바라보면 집을 수 있음")

	# 강아지를 바라보면 강아지 위 점이 잡힌다
	shop.player.global_position = Vector3(0, 0.05, 0.2)
	shop.player.rotation = Vector3.ZERO
	shop.player.camera.rotation = Vector3.ZERO
	shop.player.camera.look_at(shop.dog.global_position + Vector3(0, 0.15, 0))
	await get_tree().physics_frame
	shop._update_aim()
	check(shop.aim_point != null, "강아지를 바라보면 조준점이 잡힘")

	var points := _surface_points()
	check(points.size() > 40, "강아지 몸 위 점 (%d 개)" % points.size())

	# 젖지 않은 곳에는 샴푸가 안 묻는다
	shop.pick("shampoo")
	check_eq(shop.held, "shampoo", "샴푸 집기")
	check(not shop._pickups["shampoo"].visible, "집은 도구는 선반에서 사라짐")
	shop.use_tool_at(points[0], 0.5)
	check_eq(shop.dog.foam_count(), 0, "마른 털에는 거품이 안 생김")

	var t_wet := _sweep("shower", "wet")
	var t_scrub := _sweep("shampoo", "scrub")
	check(shop.dog.foam_count() > 0, "샴푸하면 거품이 생김")
	var t_rinse := _sweep_until("shower", func() -> bool: return shop.dog.foam_count() == 0)
	var t_dry := _sweep("towel", "dry")
	print("V4 한 마리: 물 %.1f / 샴푸 %.1f / 헹굼 %.1f / 수건 %.1f 초" % [t_wet, t_scrub, t_rinse, t_dry])
	for pair in [["샤워기", t_wet], ["샴푸", t_scrub], ["헹굼", t_rinse], ["수건", t_dry]]:
		check(pair[1] <= TOOL_LIMIT_SEC, "%s 가 %.0f초 안 (%.1f 초)" % [pair[0], TOOL_LIMIT_SEC, pair[1]])
	check(shop.done, "다 씻으면 끝 (%s)" % str(shop.progress()))

	shop.drop()
	check_eq(shop.held, "", "Q: 내려놓기")
	await get_tree().create_timer(0.4).timeout
	check(shop._pickups["towel"].visible, "반납 손목 동작 뒤 도구는 선반으로")
	shop.new_dog()
	check(not shop.done and shop.progress().scrub < 0.5, "R: 새 강아지는 다시 더러움")


## 도구를 집고 몸 위 점들을 차례로 훑는다. 채널이 다 차면 멈춤. 걸린 시간(초)
func _sweep(tool_id: String, channel: String) -> float:
	return _sweep_until(tool_id, func() -> bool: return shop.dog.mask.ratio(channel) >= shop.DONE_AT)


func _sweep_until(tool_id: String, finished: Callable) -> float:
	shop.pick(tool_id)
	var points := _surface_points()
	var seconds := 0.0
	var i := 0
	while not finished.call() and seconds < TOOL_LIMIT_SEC * 2.0:
		# 한 점에 0.1초씩 머무르며 쓱쓱
		for k in 3:
			shop.use_tool_at(points[i % points.size()], STEP)
			seconds += STEP
		i += 1
	return seconds


## 몸 바깥에서 중심으로 광선을 쏴서 강아지 겉면 점들을 모은다 (사람이 몸을 둘러보며 대는 곳)
func _surface_points() -> Array[Vector3]:
	var dog = shop.dog
	var center: Vector3 = dog._body_center()
	var space: PhysicsDirectSpaceState3D = shop.get_world_3d().direct_space_state
	var out: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 160:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		var query := PhysicsRayQueryParameters3D.create(dog.model.to_global(center + dir * 1.5), dog.model.to_global(center), shop.DOG_LAYER)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			out.append(hit.position)
	return out
