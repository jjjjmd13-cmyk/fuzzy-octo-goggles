extends "res://tests/qa_test.gd"
## V4 하루 흐름: 손님을 클릭하면 강아지를 맡기고, 다 씻은 뒤 주인을 클릭하면 돌려주고 요금 + 팁을 받는다.
## 기분 팁 + 빠른 팁 (들어와서 돌려받기까지 빠를수록, 급한 손님은 2배),  6시가 지나면 새 손님이 안 오며, 남은 손님까지 보내면 정산.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")

var shop: Node3D
var guests: Node3D


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	guests = shop.guests
	guests._opening.clear()
	guests._spawn_left = 1e9
	for i in 3:
		await get_tree().physics_frame
	# 아침 준비 시간 (팻말을 뒤집기 전엔 시계가 안 감)
	check(shop.morning, "하루는 아침 준비로 시작")
	shop.open_shop()
	check(is_equal_approx(shop.day_seconds, Tuning.data.v4_day_minutes * 60.0), "하루 영업 = v4_day_minutes")
	check_eq(shop.clock_text(), "오전 9:00", "문 열 때 시계")

	# 대기 손님을 바라보면 클릭 대상이 됨
	guests.spawn("hurry")
	var first: Node3D = guests.guests[0].owner
	await get_tree().physics_frame
	shop.player.global_position = Vector3(1.6, 0.05, first.global_position.z)
	shop.player.rotation = Vector3.ZERO
	shop.player.camera.rotation = Vector3.ZERO
	shop.player.camera.look_at(first.global_position + Vector3(0, 0.7, 0))
	await get_tree().physics_frame
	shop._update_aim()
	check(shop.hovered_guest == first, "손님을 바라보면 클릭 대상")
	guests.spawn("forever")

	# 클릭: 강아지 맡기 → 목욕통에
	shop.interact_guest(first)
	check(shop.has_dog, "손님 클릭: 강아지가 목욕통으로")
	check(guests.current == first, "맡긴 손님은 목욕통 옆에서 기다림")
	shop.interact_guest(guests.guests[0].owner)
	check_eq(guests.guests.size(), 1, "목욕통이 차 있으면 다음 손님은 못 맡김")
	shop.interact_guest(first)
	check_eq(shop.money, 0, "다 씻기 전엔 돌려주지 않음")

	# 다 씻고 주인 클릭: 요금 + 팁 (급한 손님을 바로 받아서 팁이 큼)
	shop.done = true
	shop.interact_guest(first)
	var fee: int = Tuning.data.v4_price_wash
	check(not shop.has_dog and guests.current == null, "돌려주면 목욕통이 비고 주인이 떠남")
	check_eq(shop.fees, fee, "요금")
	var fast: int = Tuning.data.v4_tip_fast[0]
	check_eq(shop.tips, Tuning.data.v4_tip_mood[2] + roundi(fast * Tuning.data.v4_tip_fast_hurry_mult), "급한 손님을 바로 돌려주면 기분 팁 + 빠른 팁 ×2")
	check_eq(shop.money, shop.fees + shop.tips, "돈 = 요금 + 팁")
	check(first.get_node_or_null("GuestHit") == null, "떠나는 주인은 더 클릭 안 됨")

	# 팁 계산: 늦게 받을수록 작음, 끝까지 손님은 적음
	var times: PackedFloat32Array = Tuning.data.v4_fast_times
	check_eq(shop.fast_tip("normal", times[0] - 1.0), Tuning.data.v4_tip_fast[0], "%.0f초 안 = 빠른 팁 최대" % times[0])
	check_eq(shop.fast_tip("normal", times[1] - 1.0), Tuning.data.v4_tip_fast[1], "%.0f초 안 = 빠른 팁 중간" % times[1])
	check_eq(shop.fast_tip("normal", times[1] + 1.0), Tuning.data.v4_tip_fast[2], "그 뒤 = 빠른 팁 없음")
	check(shop.fast_tip("hurry", 10.0) > shop.fast_tip("normal", 10.0), "급한 손님은 빠른 팁 배수")

	# 6시: 새 손님 안 옴, 남은 손님(끝까지)을 씻겨 보내면 정산
	shop.day_time = shop.day_seconds - 0.1
	shop._update_day(0.2)
	check(not guests.open, "6시가 지나면 영업 끝")
	check_eq(shop.clock_text(), "오후 6:00", "6시")
	guests._spawn_left = 0.0
	guests._process(0.1)
	check_eq(guests.guests.size(), 1, "영업 끝 뒤엔 새 손님 안 옴")
	check(not shop.day_over, "남은 손님이 있으면 아직 정산 안 함")
	shop.next_guest()
	shop.done = true
	shop.next_guest()
	shop._update_day(0.1)
	check(shop.day_over, "남은 손님까지 보내면 정산")
	var settle: Control = shop._settle
	check(settle != null and settle.is_inside_tree(), "정산 화면")
	if settle != null:
		check(settle.summary_text.contains("받은 손님  2"), "정산: 받은 손님 (%s)" % settle.summary_text)
		check(settle.summary_text.contains("오늘  %d" % (shop.fees + shop.tips)), "정산: 오늘 번 돈")
		check(settle.summary_text.contains("가진 돈  %d" % shop.money), "정산: 가진 돈")
	shop.interact_guest(null)
	check_eq(shop.money, shop.fees + shop.tips, "정산 뒤엔 손님 클릭 없음")
