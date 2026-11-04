extends "res://tests/qa_test.gd"
## V4 고양이·동물 성격 (GDD_V4 '고양이·동물 성격', TUNING_V4 4장).
## 고양이는 3일차부터 (그날 2번째 손님은 꼭), 성격은 2·5·7일차부터 (그날 2번째 손님은 꼭 그 성격).
## 규칙을 어기면 싫어함 1 (💢, 같은 규칙 2초에 한 번·최대 2번), 돌려줄 때 0 😊 · 1~2 😐 · 3+ 😣 → 기분 팁.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpAnimals := preload("res://scripts/v4/fp_animals.gd")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# 뽑기: 열리는 날·그날 2번째 손님
	var day1 := true
	for i in 50:
		var a := FpAnimals.roll(1, i + 1, rng)
		day1 = day1 and a.animal == "dog" and a.trait == ""
	check(day1, "1일차는 강아지만, 성격 없음")
	check_eq(FpAnimals.roll(2, 2, rng).trait, "ticklish", "2일차 2번째 손님 = 간지럼쟁이")
	check_eq(FpAnimals.roll(3, 2, rng).animal, "cat", "3일차 2번째 손님 = 고양이")
	check_eq(FpAnimals.roll(5, 2, rng).trait, "timid", "5일차 2번째 손님 = 겁쟁이")
	check_eq(FpAnimals.roll(7, 2, rng).trait, "dandy", "7일차 2번째 손님 = 멋쟁이")
	var cats := 0
	var traits := 0
	for i in 1000:
		var a := FpAnimals.roll(10, 5, rng)
		cats += 1 if a.animal == "cat" else 0
		traits += 1 if a.trait != "" else 0
	check(cats > 240 and cats < 360, "그 뒤 고양이 약 30%% (%d / 1000)" % cats)
	check(traits > 340 and traits < 460, "그 뒤 성격 약 40%% (%d / 1000)" % traits)
	# 고양이 그래픽: cat.glb 가 있으면 그걸로
	var cat_model := FpAnimals.scene_of("cat").instantiate() as Node3D
	check(cat_model.find_child("Head", true, false) != null and cat_model.find_child("FaceCenter", true, false) != null, "고양이 모형 (Head·FaceCenter 노드)")
	if ResourceLoader.exists(FpAnimals.CAT_GLB):
		check(cat_model.get_node_or_null("Art") != null, "cat.glb 를 씀")
		# 혀: 입 안에 숨어 있다가 기분 좋으면 내밂 (CAT_DELIVERY.md, visible 만으로는 안 보임)
		add_child(cat_model)
		var tongue := cat_model.find_child("Tongue", true, false) as Node3D
		var rest := tongue.position
		cat_model.set_mood(2)
		await get_tree().create_timer(0.6).timeout
		check(tongue.visible and tongue.position.distance_to(rest) > 0.04, "기분 좋은 고양이는 혀를 내밂 (%.3f m)" % tongue.position.distance_to(rest))
		cat_model.set_mood(0)
		await get_tree().create_timer(0.6).timeout
		check(tongue.position.distance_to(rest) < 0.005, "기분이 나쁘면 혀를 넣음")
	cat_model.free()

	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	for i in 3:
		await get_tree().physics_frame
	shop.open_shop()

	# 성격 없는 강아지: 늘 😊, 요금 40
	_take("dog", "")
	check(shop.animal == "dog" and shop.animal_trait == "", "보통 강아지")
	var money: int = shop.money
	_finish_and_return()
	check_eq(shop.money - money, Tuning.data.v4_price_wash + Tuning.data.v4_tip_mood[2] + shop.fast_tip("forever", 0.0), "보통 강아지: 요금 40 + 😊 팁 + 빠른 팁")

	# 고양이: 머리에 물 → 싫어함 1 (한 손님에 1번만, 그 뒤엔 냥! 만), 첫 고양이는 안내 카드
	_take("cat", "")
	check_eq(shop.animal, "cat", "고양이 손님")
	check(shop.dog.model.find_child("Head", true, false) != null, "목욕통에 고양이 모형")
	check(shop._card_left > 0.0 and shop._card.contains("고양이"), "처음 나온 고양이는 안내 카드")
	check(shop.seen_animals.has("cat"), "본 것으로 저장")
	shop.pick("shower")
	var head := _face()
	shop.use_tool_at(head, 1.0 / 30.0)
	check_eq(shop.dislikes(), 1, "머리에 물 → 싫어함 1")
	shop._t += 3.0
	shop.use_tool_at(head, 1.0 / 30.0)
	check_eq(shop.dislikes(), 1, "머리 물 싫어함은 한 손님에 1번만")
	check(shop._anger != null and shop._anger.visible, "머리 위 💢")
	# 젖어 있는 시간 40초 넘김 → 수건 끝에 싫어함 1
	shop._wet_since = shop._t - Tuning.data.v4_cat_wet_limit - 1.0
	_fill_to("towel")
	check_eq(shop.dislikes(), 2, "오래 젖어 있으면 싫어함 1 (수건 끝에)")
	_fill_to("dry")
	check_eq(shop.tangles.count(), Tuning.data.v4_cat_tangles, "고양이 빗질 뭉치 %d" % Tuning.data.v4_cat_tangles)
	money = shop.money
	_finish_and_return()
	check_eq(shop.money - money, Tuning.data.v4_cat_price + Tuning.data.v4_tip_mood[1] + shop.fast_tip("forever", 0.0), "고양이: 요금 55 + 싫어함 2 → 😐 팁 + 빠른 팁")

	# 간지럼쟁이: 거품 때 배·발 한 곳에 0.6초 넘게 → 싫어함, 등은 괜찮음
	_take("dog", "ticklish")
	_fill_to("wet")
	shop.pick("shampoo")
	var back: Vector3 = shop.dog.model.to_global(shop.dog._body_center() + Vector3(0, 0.15, -0.05))
	for i in 30:
		shop.use_tool_at(back, 1.0 / 30.0)
	check_eq(shop.dislikes(), 0, "간지럼쟁이: 등은 오래 문질러도 괜찮음")
	var belly: Vector3 = shop.dog.model.to_global(shop.dog._body_center() + Vector3(0, -0.15, 0.08))
	for i in 25:
		shop.use_tool_at(belly, 1.0 / 30.0)
	check_eq(shop.dislikes(), 1, "간지럼쟁이: 배 한 곳에 0.6초 넘게 → 싫어함")
	check(shop._draw_animal_line().contains("간지럼쟁이"), "왼쪽 위 칸에 성격 한 줄")
	_finish_and_return()

	# 겁쟁이: 얼굴에 물 → 싫어함, 같은 규칙은 2초에 한 번, 최대 2번
	_take("dog", "timid")
	shop.pick("shower")
	for i in 5:
		shop.use_tool_at(_face(), 1.0 / 30.0)
	check_eq(shop.dislikes(), 1, "겁쟁이: 얼굴에 물 → 싫어함 (2초에 한 번)")
	for i in 4:
		shop._t += 2.5
		shop.use_tool_at(_face(), 1.0 / 30.0)
	check_eq(shop.dislikes(), 2, "같은 규칙은 한 손님에 최대 2번")
	money = shop.money
	_finish_and_return()
	check_eq(shop.money - money, Tuning.data.v4_price_wash + Tuning.data.v4_tip_mood[1] + shop.fast_tip("forever", 0.0), "싫어함 2 → 😐 팁")

	# 멋쟁이: 빗질을 끝까지 하면 싫어함 하나를 지움
	_take("dog", "dandy")
	shop.dislike("test")
	check_eq(shop.dislikes(), 1, "싫어함 1")
	_fill_to("brush")
	check_eq(shop.dislikes(), 0, "멋쟁이: 빗질 끝 → 싫어함 지움")
	_finish_and_return()
	check(shop.save_state(2).seen_animals.has("dandy"), "본 성격 저장")
	shop.free()

	# 빠른 확인 [고양이·성격]: 고양이 → 간지럼 → 겁쟁이 → 멋쟁이 고양이
	shop = SCENE.instantiate()
	shop.input_enabled = false
	shop.quick_dogs = 4
	shop.quick_feature = "animals"
	add_child(shop)
	await get_tree().physics_frame
	check_eq(shop.guests.quick_animals.size(), 4, "빠른 확인 [고양이·성격]: 4마리")
	shop.free()


func _take(kind: String, trait_id: String) -> void:
	shop.guests.quick_animals = [{"animal": kind, "trait": trait_id}]
	shop.guests.spawn("forever")
	shop.next_guest()


func _face() -> Vector3:
	var face: Vector3 = shop.dog.model.get("face_center")
	return shop.dog.model.to_global(face)


## 단계를 차례로 채움 (stage 까지)
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
