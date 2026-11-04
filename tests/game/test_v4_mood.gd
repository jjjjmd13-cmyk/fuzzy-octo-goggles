extends "res://tests/qa_test.gd"
## V4 기분·반응 (GDD_V4 '기분·반응', TUNING_V4 4-1): 기분 점수 = 좋아함 +1 (좋아하는 곳·30초 안·성격 맞춤, 각각 한 번, 최대 +3)
## − 싫어함 (규칙·120초 넘음, 바닥 −4). 얼굴 4단계 😣 −3↓ · 😐 −2~−1 · 😊 0~1 · 🤩 2↑ → 팁 0·5·15·25. 시간에 비례하는 벌점 없음.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpAnimals := preload("res://scripts/v4/fp_animals.gd")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	var faces := []
	for score in [-4, -3, -2, -1, 0, 1, 2, 3]:
		faces.append(FpAnimals.face_of(score))
	check_eq(faces, [0, 0, 1, 1, 2, 2, 3, 3], "점수 → 얼굴 (😣 −3↓ · 😐 −2~−1 · 😊 0~1 · 🤩 2↑)")

	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	for i in 3:
		await get_tree().physics_frame
	shop.open_shop()

	# 좋아함은 규칙마다 한 번, 최대 +3 / 싫어함 바닥 −4
	_take("dog", "")
	check(not shop.fav_spot.is_empty() and Tuning.data.v4_fav_spots.has(shop.fav_spot), "좋아하는 곳 하나 (%s)" % shop.fav_spot)
	check(shop.like("a") and not shop.like("a"), "같은 좋아함은 한 번만")
	shop.like("b")
	shop.like("c")
	shop.like("d")
	check_eq(shop.mood_score, 3, "좋아함 최대 +3")
	for i in 10:
		shop._t += 3.0
		shop.dislike("rule_%d" % i)
	check_eq(shop.mood_score, Tuning.data.v4_mood_floor, "바닥 −4")
	_finish_and_return()

	# 좋아하는 곳: 거품 때 0.5초 머물면 ♥ +1, 가까울수록 꼬리 (가까운 정도 > 0)
	_take("dog", "")
	shop.fav_spot = "back"
	_fill_to("wet")
	shop.pick("shampoo")
	var face_center: Vector3 = shop.dog.model.get("face_center")
	var spot: Vector3 = shop.dog.model.to_global(FpAnimals.fav_point("back", shop.dog._body_center(), face_center))
	var far: Vector3 = shop.dog.model.to_global(FpAnimals.fav_point("chin", shop.dog._body_center(), face_center))
	check(shop._check_fav("shampoo", shop.dog.to_model(spot), 0.0) > shop._check_fav("shampoo", shop.dog.to_model(far), 0.0), "좋아하는 곳에 가까울수록 꼬리 신호가 큼")
	shop._fav_time = 0.0
	for i in 20:
		shop.use_tool_at(spot, 1.0 / 30.0)
	check(shop._likes.has("fav"), "좋아하는 곳 0.5초 → 좋아함")
	check(shop._heart != null and shop._heart.visible, "머리 위 ♥")
	# 30초 안에 다 씻으면 +1 → 🤩 → 팁 25
	_fill_to("brush")
	check(shop._likes.has("fast"), "30초 안에 다 씻음 → 좋아함")
	check_eq(shop.face(), 3, "좋아하는 곳 + 빠름 = 🤩")
	var money: int = shop.money
	_finish_and_return()
	check_eq(shop.money - money, Tuning.data.v4_price_wash + Tuning.data.v4_tip_mood4[3] + shop.fast_tip("forever", 0.0), "🤩 팁 25")

	# 너무 오래 (120초 넘게): 싫어함 한 번만
	_take("dog", "")
	shop._tub_start = shop._t - Tuning.data.v4_mood_slow - 1.0
	for i in 3:
		await get_tree().process_frame
		shop._t += 3.0
	check_eq(shop.mood_score, -1, "120초 넘게 → 싫어함 한 번만")
	shop._tub_start = shop._t - 100.0
	_fill_to("brush")
	check(not shop._likes.has("fast"), "오래 걸리면 빠름 좋아함 없음")
	check_eq(shop.face(), 1, "😐")
	_finish_and_return()

	# 성격 맞춤: 성격 손님을 싫어함 0 으로 끝내면 +1
	_take("dog", "timid")
	_fill_to("brush")
	check(shop._likes.has("trait_clean"), "겁쟁이를 싫어함 없이 끝냄 → 좋아함")
	_finish_and_return()
	# 멋쟁이: 빗질 +1 (성격 맞춤과 겹치지 않음)
	_take("dog", "dandy")
	shop._tub_start = shop._t - 100.0
	_fill_to("brush")
	check(shop._likes.has("dandy") and not shop._likes.has("trait_clean"), "멋쟁이는 빗질 +1 만 (겹치지 않음)")
	_finish_and_return()

	# 정산: 오늘 가장 기뻐한 손님
	shop.end_day()
	var lines: Array = shop._supply_lines()
	check(lines.any(func(line: String) -> bool: return line.contains("가장 기뻐한 손님") and line.contains("🤩")), "정산: 오늘 가장 기뻐한 손님 🤩")
	shop.free()


func _take(kind: String, trait_id: String) -> void:
	shop.guests.quick_animals = [{"animal": kind, "trait": trait_id}]
	shop.guests.spawn("forever")
	shop.next_guest()


func _fill_to(stage: String) -> void:
	for id in ["wet", "scrub", "rinse", "towel", "dry", "brush"]:
		match id:
			"rinse":
				shop.dog.clear_foam()
				shop.dog.mask.fill("rinse", 1.0)
			"brush":
				shop.tangles.clear()
			_:
				shop.dog.mask.fill(id, 1.0)
		shop._check_done()
		if id == stage:
			return


func _finish_and_return() -> void:
	shop.done = true
	shop.next_guest()
