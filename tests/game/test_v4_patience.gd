extends "res://tests/qa_test.gd"
## V4 대기 손님 참을성 (GDD_V4 0.2): 성격마다 참을성이 다르고, 다 되면 "다음에 올게요" 하고 떠난다.
## 끝까지 손님은 안 떠나고, 목욕통으로 데려간 손님도 안 떠난다. 시간은 _process 를 직접 불러 빨리 돌린다.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")

var shop: Node3D
var guests: Node3D
var left_kinds: Array[String] = []


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	guests = shop.guests
	# 저절로 오는 손님은 멈추고 직접 들여보냄
	check_eq(guests._opening, Tuning.data.v4_first_guests, "처음 줄은 수치표대로")
	guests._opening.clear()
	guests._spawn_left = 1e9
	guests.guest_left.connect(func(kind: String) -> void: left_kinds.append(kind))
	await get_tree().process_frame

	check_eq(guests.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Chair")).size(), 3, "대기 의자 3개")
	for kind in ["hurry", "normal", "forever", "relaxed"]:
		guests.spawn(kind)
	check_eq(guests.guests.size(), 3, "의자가 다 차면 더 안 들어옴")
	for g in guests.guests:
		check(g.owner.get_node_or_null("PatienceIcon") != null, "%s 손님 머리 위 표시" % g.kind)
	check_eq(guests.patience_of("hurry"), Tuning.data.v4_patience_hurry, "급함 참을성")
	check(guests.patience_of("forever") <= 0.0, "끝까지 손님은 안 떠남 (0)")

	# 참을성의 85%: 급함은 아직 있음, 깜빡이는 구간 (남은 < 1/4)·발 구르기
	var hurry: float = Tuning.data.v4_patience_hurry
	_advance(hurry * 0.85)
	check_eq(guests.guests[0].kind, "hurry", "급함 손님 %.0f초엔 아직 기다림" % (hurry * 0.85))
	check_eq(guests.guests[0].owner.wait_level, 2, "참을성이 거의 다 되면 발 구르기")
	check(guests.guests[1].owner.wait_level <= 1, "보통 손님은 아직 느긋")
	# 참을성이 다 되면 급함이 떠나고 뒷사람이 앞으로
	_advance(hurry * 0.2)
	check_eq(left_kinds, ["hurry"] as Array[String], "급함 손님이 %.0f초에 떠남" % hurry)
	check_eq(guests.left_count, 1, "떠난 손님 수")
	check_eq(guests.guests.size(), 2, "남은 대기 손님 2명")
	check_eq(guests.guests[0].kind, "normal", "뒷사람이 앞자리로")
	check(guests._leaving.size() == 1, "떠나는 손님은 손 흔들고 문으로 걸어감")

	# 맨 앞(보통) 손님이 강아지를 맡김: 그 손님은 더 이상 안 떠남
	shop.next_guest()
	check(shop.has_dog, "R: 맨 앞 손님 강아지를 받음")
	check_eq(guests.guests.size(), 1, "맡긴 손님은 대기열에서 빠짐")
	check(guests.current != null, "맡긴 손님은 목욕통 옆에서 지켜봄")
	_advance(1000.0)
	check_eq(guests.guests.size(), 1, "끝까지 손님은 1000초가 지나도 기다림")
	check_eq(guests.guests[0].kind, "forever", "남은 손님은 끝까지 손님")
	check_eq(guests.left_count, 1, "목욕 중인 손님은 안 떠남")

	# 다 안 씻었으면 R 로 돌려주지 않음
	shop.next_guest()
	check(shop.has_dog and guests.served == 0, "다 씻기 전엔 돌려주지 않음")
	shop.done = true
	shop.next_guest()
	check_eq(guests.served, 1, "다 씻고 R: 주인에게 돌려줌")
	check(guests.current == null and not shop.has_dog, "주인이 데려가면 목욕통이 빔")
	check_eq(guests.guests.size(), 1, "돌려줄 때 다음 손님을 저절로 받지 않음")

	# 성격 비율: 연 지 얼마 안 됐을 땐 급함이 없고, v4_hurry_after 뒤엔 섞임
	guests.elapsed = 0.0
	var early := {}
	for i in 1000:
		var kind: String = guests.roll_kind()
		early[kind] = early.get(kind, 0) + 1
	check_eq(early.get("hurry", 0), 0, "처음 %.0f초 동안 급한 손님 없음" % Tuning.data.v4_hurry_after)
	guests.elapsed = Tuning.data.v4_hurry_after + 1.0
	var counts := {}
	for i in 2000:
		var kind: String = guests.roll_kind()
		counts[kind] = counts.get(kind, 0) + 1
	print("성격 2000번: ", counts)
	check(counts.get("forever", 0) > 120 and counts.get("forever", 0) < 300, "끝까지 약 10%")
	check(counts.get("normal", 0) > 780, "보통이 가장 많음 (약 45%)")
	check(counts.get("hurry", 0) > 280, "%.0f초 뒤엔 급함도 나옴 (약 20%%)" % Tuning.data.v4_hurry_after)


func _advance(seconds: float) -> void:
	var step := 0.5
	var t := 0.0
	while t < seconds - 0.001:
		guests._process(step)
		t += step
