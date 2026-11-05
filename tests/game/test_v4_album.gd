extends "res://tests/qa_test.gd"
## V4 손님 사진첩 (GDD_V4 '손님 사진첩', TUNING_V4 5장): 이름 있는 단골 24마리, 처음 보는 단골은 하루 1~2마리 (1일차 4),
## 돌려줄 때 자동 사진 (기분 테두리, 단골마다 가장 좋은 한 장), 만난 수 보상 5·10·15·20 = 50·100·150·200, 24 = 사진 게시판.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpRegulars := preload("res://scripts/v4/fp_regulars.gd")
const V4Save := preload("res://scripts/v4/v4_save.gd")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 90.0
	get_tree().root.size = Vector2i(1280, 800)

	# 단골 표
	var table := FpRegulars.all()
	check_eq(table.size(), Tuning.data.v4_regulars_dog + Tuning.data.v4_regulars_cat, "단골 24마리")
	check_eq(table.filter(func(r: Dictionary) -> bool: return r.animal == "cat").size(), Tuning.data.v4_regulars_cat, "고양이 8")
	var ids := {}
	for r in table:
		ids[r.id] = true
		var scale_ok := Array(Tuning.data.v4_regular_scales).any(func(v: float) -> bool: return is_equal_approx(v, float(r.scale)))
		check(FpRegulars.COLORS.has(r.color) and Tuning.data.v4_fav_spots.has(r.fav) and scale_ok, "단골 %s: 털 색·좋아하는 곳·크기" % r.name)
	check_eq(ids.size(), 24, "id 가 겹치지 않음")
	check(not FpRegulars.is_open(FpRegulars.get_regular("nabi"), 2) and FpRegulars.is_open(FpRegulars.get_regular("nabi"), 3), "고양이 단골은 3일차부터")
	check(not FpRegulars.is_open(FpRegulars.get_regular("byeoli"), 6) and FpRegulars.is_open(FpRegulars.get_regular("byeoli"), 7), "멋쟁이 단골은 7일차부터")

	# 뽑기: 1일차 처음 4마리 = 콩이·보리·두부·호떡, 열린 날 2번째 손님, 하루 처음 보는 단골 수
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var met: Array = []
	for nth in range(1, 5):
		met.append(FpRegulars.pick(1, nth, met, nth - 1, [], rng))
	check_eq(met, Array(Tuning.data.v4_first_day_regulars), "1일차 처음 4마리")
	check(met.has(FpRegulars.pick(1, 5, met, 4, [], rng)), "그 뒤엔 만난 단골이 다시 옴")
	check_eq(FpRegulars.get_regular(FpRegulars.pick(2, 2, met, 0, [], rng)).trait, "ticklish", "2일차 2번째 손님 = 간지럼쟁이 단골")
	check_eq(FpRegulars.get_regular(FpRegulars.pick(3, 2, met, 0, [], rng)).animal, "cat", "3일차 2번째 손님 = 고양이 단골")
	check(FpRegulars.new_quota(5) == 2 and FpRegulars.new_quota(9) == 1, "처음 보는 단골: 2~8일차 2, 9일차부터 1")
	# 18일 흉내 (하루 9명): 14일차 무렵에 24마리 모두
	var seen: Array = []
	var all_met_day := 0
	for day in range(1, 19):
		var new_today := 0
		for nth in range(1, 10):
			var id := FpRegulars.pick(day, nth, seen, new_today, [], rng)
			if not seen.has(id):
				seen.append(id)
				new_today += 1
		check(new_today <= FpRegulars.new_quota(day) + 1, "%d일차 처음 보는 단골 %d (하루 몫 %d)" % [day, new_today, FpRegulars.new_quota(day)])
		if seen.size() == 24 and all_met_day == 0:
			all_met_day = day
	check(all_met_day >= 12 and all_met_day <= 16, "약 14일차에 24마리 모두 만남 (%d일차)" % all_met_day)

	var real_path := V4Save.path
	V4Save.path = "user://test_v4_album_save.json"
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	for i in 3:
		await get_tree().physics_frame
	shop.open_shop()

	# 단골이 옴: 털 색·크기, 좋아하는 곳은 늘 같은 곳, 돌려주면 찰칵 → 사진첩 첫 칸
	_take("dubu")
	var dubu := FpRegulars.get_regular("dubu")
	check_eq(shop.regular, "dubu", "목욕통에 두부")
	check(is_equal_approx(shop.dog.model.scale.x, float(dubu.scale)), "단골 크기 %.1f" % dubu.scale)
	check_eq(shop.fav_spot, dubu.fav, "단골의 좋아하는 곳은 늘 같음")
	_finish_and_return()
	check(shop.album.has("dubu"), "돌려주면 사진첩에 칸이 열림")
	check_eq(shop.album.dubu.visits, 1, "온 횟수 1")
	var first_mood: int = shop.album.dubu.best_mood
	check_eq(shop.regulars_met_order, ["dubu"], "만난 순서")
	check(shop._flash > 0.0, "찰칵 (화면 살짝 하얗게)")
	# 두 번째 방문: 이름표 ×2, 더 좋은 기분이면 사진이 바뀜
	shop.guests.quick_animals = [{"regular": "dubu"}]
	shop.guests.spawn("forever")
	var tag := shop.guests.guests[-1].owner.get_node_or_null("NameTag") as Label3D
	check(tag != null and tag.text.begins_with("두부 ×2"), "주인 머리 위 이름표 (%s, 신뢰 하트는 test_v4_trust)" % (tag.text if tag != null else "없음"))
	shop.next_guest()
	shop.like("x")
	shop.like("y")
	shop.like("z")
	shop._likes["fav"] = true
	_finish_and_return()
	check_eq(shop.album.dubu.visits, 2, "온 횟수 2")
	check(shop.album.dubu.best_mood >= first_mood and shop.album.dubu.best_mood == 3, "더 좋은 기분 → 새 사진 (🤩)")
	check(shop.album.dubu.fav_found, "좋아하는 곳을 찾음 → 카드에 그림")
	# 더 나쁜 기분이면 사진은 그대로
	_take("dubu")
	for i in 4:
		shop._t += 3.0
		shop.dislike("bad_%d" % i)
	_finish_and_return()
	check_eq(shop.album.dubu.best_mood, 3, "나쁜 기분은 사진을 안 바꿈")
	check_eq(shop.album.dubu.visits, 3, "온 횟수는 늘 +1")

	# 보상: 5마리 → 50
	for id in ["kongi", "bori", "hotteok"]:
		shop.album[id] = {"visits": 1, "best_mood": 2, "day": 1, "trim": "", "wall": "", "floor": "", "fav_found": false}
		shop.regulars_met_order.append(id)
	var money: int = shop.money
	_take("somi")
	_finish_and_return()
	check(shop.album_rewards_taken.has(5), "단골 5마리 → 보상")
	check(shop.money - money >= Tuning.data.v4_album_rewards[0] + Tuning.data.v4_price_wash, "보상 %d 바로 받음" % Tuning.data.v4_album_rewards[0])
	# 24마리 → 사진 게시판 (벽 장식 자리, 금색 사진 먼저)
	for r in table:
		if not shop.album.has(r.id) and r.id != "kkoma":
			shop.album[r.id] = {"visits": 1, "best_mood": 2, "day": 9, "trim": "", "wall": "", "floor": "", "fav_found": false}
			shop.regulars_met_order.append(r.id)
	shop.album_rewards_taken = [5, 10, 15, 20]
	_take("kkoma")
	_finish_and_return()
	check_eq(shop.album.size(), 24, "24마리 모두")
	check_eq(shop.decor.placed.get("art"), "photo_board", "사진 게시판이 벽에")
	var board: Node = shop.decor_view.nodes.get("art")
	check(board != null and board.find_children("Photo", "MeshInstance3D", true, false).size() == Tuning.data.v4_photo_board_slots, "게시판에 사진 6장")
	check_eq(shop.board_photos()[0].regular, "dubu", "금색 사진(두부)이 먼저")

	# 사진첩 화면: 정산 판 [사진첩] → 한 쪽 4칸, 칸 → 단골 카드
	shop.end_day()
	var album_button := shop._settle.find_child("Album", true, false) as Button
	check(album_button != null, "정산 판에 [사진첩]")
	album_button.pressed.emit()
	await get_tree().process_frame
	var view: Control = shop._album_view
	check(view != null and view.find_child("Slots", true, false).get_child_count() == Tuning.data.v4_album_page_slots, "한 쪽 4칸")
	check_eq(view.pages(), 6, "6쪽")
	view.show_card("dubu")
	check(view.find_child("FavPicture", true, false) != null, "단골 카드: 좋아하는 곳 그림")
	view.close_album()
	await get_tree().process_frame
	check(not is_instance_valid(view), "닫기")

	# 저장 → 이어하기
	shop.save_game(2)
	var saved := V4Save.read()
	check_eq(saved.album.size(), 24, "사진첩 저장 (정보만)")
	check_eq(saved.album.dubu.best_mood, 3, "가장 좋은 기분 저장")
	check(saved.album_rewards_taken.has(24), "받은 보상 저장")
	shop.free()
	V4Save.continue_requested = true
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	await get_tree().physics_frame
	check_eq(shop.album.size(), 24, "이어하면 사진첩 그대로")
	check(shop.guests.album == shop.album, "손님 쪽도 같은 사진첩 (이름표·처음 보는 단골)")
	shop.free()
	V4Save.erase()
	V4Save.path = real_path


func _take(id: String) -> void:
	shop.guests.quick_animals = [{"regular": id}]
	shop.guests.spawn("forever")
	shop.next_guest()


func _finish_and_return() -> void:
	shop.done = true
	shop.next_guest()
