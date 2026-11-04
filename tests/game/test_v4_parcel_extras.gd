extends "res://tests/qa_test.gd"
## V4 택배 자잘한 것 (GDD_V4 '귀찮지 않게 — 수레', '재미 포인트', TUNING_V4 3-4):
## 수레 (시험용, 150) 는 첫 택배로 옴 → 열면 수레가 나오고 밀면서 매트 상자를 싣고 (3칸, 큰 상자 2칸) 안에서 맨 위 상자를 엶.
## 상자를 들고 좌우로 흔들면 달그락 + 무엇이 들었는지. 안 연 상자가 가게 안에 있으면 대기 강아지가 킁킁.
## 상자를 열면 꽃가루 + 짜잔 (★3 꾸미기·5단계 도구는 무지개).

const SCENE := preload("res://scenes/v4/fp_shop.tscn")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	for i in 3:
		await get_tree().physics_frame

	# 가게: 수레 150, 큰 상자로 내일 아침
	check(shop.store_rows().any(func(r: Dictionary) -> bool: return r.id == "cart" and r.price == Tuning.data.v4_cart_price), "가게에 수레 (%d)" % Tuning.data.v4_cart_price)
	shop.money = 2000
	check(shop.order("cart"), "수레 주문")
	check_eq(shop.parcels[-1].size, "large", "수레는 큰 상자")
	check(shop.order("shampoo_bottle") and shop.order("shampoo_big") and shop.order("shower"), "다른 상자 3개 주문")
	shop.end_day()
	shop.start_next_day()
	shop.parcels_view.finish_now()
	check_eq(shop.parcels_view.box_nodes().size(), 4, "상자 4개가 매트에")

	# 수레 상자: 들고 흔들면 달그락 + 안내, 안에서 열면 꽃가루 + 수레
	var cart_box: Dictionary = shop.parcels.filter(func(b: Dictionary) -> bool: return b.item == "cart")[0]
	shop.carry_box(cart_box)
	for dx in [10.0, -10.0, 10.0]:
		shop.shake_box(dx)
	check(shop._hint.contains("달그락") and shop._hint.contains("택배 수레"), "흔들면 달그락 + 무엇이 들었는지 (%s)" % shop._hint)
	shop.player.global_position = Vector3(1.0, 0.05, 1.0)
	check(shop.open_box(), "수레 상자 열기")
	check(shop.owns_cart and shop.cart != null, "수레가 나옴")
	var confetti := shop.get_children().filter(func(n: Node) -> bool: return n.has_meta("confetti"))
	check(not confetti.is_empty() and (confetti[-1] as CPUParticles3D).emitting and (confetti[-1] as CPUParticles3D).amount == 36, "열면 꽃가루 (보통)")

	# 수레 밀기: 느려지고, 매트 상자를 싣고 (작은 2 + 중간 1 = 3칸 꽉), 안에서 맨 위부터 엶
	shop.push_cart(true)
	check(shop.pushing_cart and is_equal_approx(shop.player.speed_mult, Tuning.data.v4_cart_speed), "수레를 밀면 조금 느리게")
	shop.player.global_position = Vector3(5.0, 0.05, 2.0)
	# process_frame 신호는 노드들의 _process 앞이라 두 프레임
	await get_tree().process_frame
	await get_tree().process_frame
	check(shop.cart.global_position.distance_to(shop.player.global_position) < 1.2, "수레가 플레이어 앞에 따라옴")
	var on_mat: Array = shop.parcels.duplicate()
	for box in on_mat:
		shop.load_cart(box)
	check_eq(shop.cart_used(), 3, "3칸 꽉 참")
	check_eq(shop.cart_load.size(), 3, "상자 3개 실림")
	check(not shop.open_cart_box(), "밖에서는 못 엶")
	shop.player.global_position = Vector3(1.0, 0.05, 1.0)
	await get_tree().process_frame
	var before: float = shop.shampoo_left
	while not shop.cart_load.is_empty():
		check(shop.open_cart_box(), "수레 맨 위 상자 열기")
	check_eq(shop.shampoo_left, before + Tuning.data.v4_shampoo_bottle + Tuning.data.v4_shampoo_big, "샴푸 1병·큰 통이 채워짐")
	check_eq(shop.tool_name("shower"), shop.TOOL_LEVEL_NAMES.shower[1], "샤워기 2단계")
	shop.push_cart(false)
	check(not shop.pushing_cart and is_equal_approx(shop.player.speed_mult, 1.0), "Q 로 수레 놓기")
	check(shop.store_rows().all(func(r: Dictionary) -> bool: return r.id != "cart"), "수레는 한 번만")

	# 무지개 꽃가루: 5단계 도구
	shop.set_tier("dryer", 3)
	shop.money = 2000
	check(shop.order("dryer"), "회오리 드라이기 주문")
	var box: Dictionary = shop.parcels[-1]
	box.arrived = true
	shop.parcels_view.place([box])
	shop.carry_box(box)
	shop.open_box()
	var last := shop.get_children().filter(func(n: Node) -> bool: return n.has_meta("confetti"))
	check(not last.is_empty() and (last[-1] as CPUParticles3D).amount == 60 and last[-1].get_meta("confetti") == "rainbow", "5단계 도구는 무지개 꽃가루 (더 많이)")

	# 킁킁: 안 연 상자를 들고 들어오면 대기 강아지가 냄새를 맡음
	shop.open_shop()
	shop.guests.spawn("normal")
	await _wait(0.5)
	shop.money = 500
	shop.order("shampoo_bottle")
	var sniff_box: Dictionary = shop.parcels[-1]
	sniff_box.arrived = true
	shop.parcels_view.place([sniff_box])
	shop.carry_box(sniff_box)
	shop.player.global_position = Vector3(1.0, 0.05, 0.0)
	var sniffed := []
	shop.guests.sniffed.connect(func(owner: Node3D) -> void: sniffed.append(owner))
	var chance: float = Tuning.data.v4_box_sniff_chance
	Tuning.data.v4_box_sniff_chance = 1.0
	shop._sniff_left = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	Tuning.data.v4_box_sniff_chance = chance
	check_eq(sniffed.size(), 1, "대기 강아지가 상자 냄새를 맡음")
	var held: Node3D = shop.guests.guests[0].owner.get_node("HeldDog")
	check(held.get_node_or_null("Sniff") != null, "머리 위에 킁킁")
	check_eq(shop.guests.guests[0].waited < 1.0, true, "참을성에는 영향 없음")

	# 저장: 수레를 가졌는지
	check(shop.save_state(2).owns_cart, "수레는 저장됨")


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
