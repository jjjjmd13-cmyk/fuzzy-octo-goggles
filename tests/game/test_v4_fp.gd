extends "res://tests/qa_test.gd"
## V4 1인칭 시제품 (scenes/v4/fp_shop.tscn): 도구를 바라보면 집을 수 있고, 강아지에 대고
## 누르고 있으면 샤워기 → 샴푸 → 샤워기(헹굼) → 드라이기 → 빗 순서로 빨리 깨끗해지는지 본다.
## 입력은 끄고(input_enabled = false) 쓰는 함수를 직접 부른다. 1인용이라 동기화 검사는 없음.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const STEP := 1.0 / 30.0
## 게임에는 씻는 시간 제한이 없다 (GDD_V4 0.2). 이건 붓이 너무 작아지지 않았는지 보는 테스트 기준일 뿐
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
	# 손님이 맡기기 전엔 목욕통이 비어 있음 (저절로 오는 손님은 멈춤)
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	check(not shop.has_dog and not shop.dog.visible, "손님이 맡기기 전엔 목욕통이 비어 있음")
	shop.next_guest()
	check(not shop.has_dog, "기다리는 손님이 없으면 R 을 눌러도 비어 있음")
	shop.guests.spawn("forever")
	# 진흙 무늬·거품 자리를 매번 같게 (흉내 손이 도는 점과 맞물려 걸리는 시간이 들쭉날쭉하지 않게)
	shop._rng.seed = 11
	shop.next_guest()
	check(shop.has_dog and shop.dog.visible, "R: 손님이 강아지를 맡김")
	check(not shop._hint.contains("끝까지") and not shop._hint.contains("손님의 강아지"), "성격 글자 없음 (%s)" % shop._hint)

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

	check_eq(shop.stage_tool(), "shower", "처음 빛나는 도구는 샤워기")
	var t_wet := _sweep("shower", "wet")
	_check_stage(1, "적시기 끝", "shampoo")
	var t_scrub := _sweep("shampoo", "scrub")
	_check_stage(2, "거품 끝", "shower")
	check(shop.dog.foam_count() > 0, "샴푸하면 거품이 생김")
	# 헹구다가 거품이 몇 개 안 남으면 그 거품이 반짝 (고리 표시는 없음). 람다는 바깥 변수를 값으로 잡으므로 배열에 담음
	var seen := {"sparkle": 0, "wrong": 0}
	var t_rinse := _sweep_until("shower", func() -> bool:
		shop._update_leftovers()
		var foam: int = shop.dog.foam_count()
		if shop.foam_sparkle != (foam > 0 and foam <= shop.FOAM_SPARKLE_BELOW):
			seen.wrong += 1
		if shop.foam_sparkle:
			seen.sparkle += 1
		return foam == 0)
	check_eq(seen.wrong, 0, "남은 거품이 %d 개 이하일 때만 반짝" % shop.FOAM_SPARKLE_BELOW)
	check(seen.sparkle > 0, "헹굼 막바지에 남은 거품이 반짝 (%d 번)" % seen.sparkle)
	_check_stage(3, "헹굼 끝", "dryer")
	shop._update_leftovers()
	check(not shop.foam_sparkle, "다 헹구면 반짝임 끝")
	check(shop.find_children("FoamMark*", "", true, false).is_empty(), "남은 거품 고리 표시는 없음")
	check_eq(shop.dog.fluff, 0.0, "말리기 전엔 털이 안 부풂")
	var t_dry := _sweep("dryer", "dry")
	check(shop.dog.fluff >= 0.99, "다 말리면 털이 뽕 (%.2f)" % shop.dog.fluff)
	_check_stage(4, "드라이 끝", "brush")
	var lumps: int = shop.progress().tangles
	check_eq(lumps, Tuning.data.v4_tangles, "드라이 뒤 엉킨 털 뭉치가 다 보임")
	var t_brush := _sweep_until("brush", func() -> bool: return shop.progress().tangles == 0)
	_check_stage(5, "빗질 끝", "")
	print("V4 한 마리: 물 %.1f / 샴푸 %.1f / 헹굼 %.1f / 드라이 %.1f / 빗질 %.1f 초" % [t_wet, t_scrub, t_rinse, t_dry, t_brush])
	for pair in [["샤워기", t_wet], ["샴푸", t_scrub], ["헹굼", t_rinse], ["드라이기", t_dry], ["빗", t_brush]]:
		check(pair[1] <= TOOL_LIMIT_SEC, "%s 가 %.0f초 안 (%.1f 초)" % [pair[0], TOOL_LIMIT_SEC, pair[1]])
	check(shop.done, "다 씻으면 끝 (%s)" % str(shop.progress()))

	shop.drop()
	check_eq(shop.held, "", "Q: 내려놓기")
	await get_tree().create_timer(0.4).timeout
	check(shop._pickups["dryer"].visible, "반납 손목 동작 뒤 도구는 선반으로")
	shop.next_guest()
	check(not shop.has_dog and not shop.dog.visible, "R: 주인에게 돌려주면 목욕통이 빔")
	check_eq(shop.guests.served, 1, "씻긴 손님 1")
	shop.guests.spawn("normal")
	shop.next_guest()
	check(shop.has_dog and not shop.done and shop.progress().scrub < 0.5, "R: 다음 손님 강아지는 다시 더러움")


## 단계 끝 순간: 단계 번호·가운데 큰 글자·다음에 빛날 도구
func _check_stage(index: int, text: String, next_tool: String) -> void:
	check_eq(shop.stage_index, index, "%s: 단계 %d 로" % [text, index])
	check(shop._banner_left > 0.0 and shop._banner.begins_with(text) or shop._banner.contains(text), "가운데 글자 \"%s\" (%s)" % [text, shop._banner])
	check_eq(shop.stage_tool(), next_tool, "%s 뒤 빛나는 도구" % text)


## 도구를 집고 몸 위 점들을 차례로 훑는다. 채널이 다 차면 멈춤. 걸린 시간(초)
func _sweep(tool_id: String, channel: String) -> float:
	return _sweep_until(tool_id, func() -> bool: return shop.dog.mask.ratio(channel) >= Tuning.data.v4_done_ratio)


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
