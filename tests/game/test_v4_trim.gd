extends "res://tests/qa_test.gd"
## V4 미용 (TUNING_V4 3-1): 가위는 도구 가게에서 사야 선반에 나오고, 산 뒤엔 일부 손님이 모양(곰돌이컷 등)을
## 요청한다. 빗질 뒤 "자를 곳" 다발만 자르면 똑같음 → 미용 요금 + 큰 팁, 남길 곳까지 자르면 팁이 줄어든다.
## 요청이 없는 손님은 미용 단계를 건너뛴다.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpTrim := preload("res://scripts/v4/fp_trim.gd")

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

	# 가위: 사기 전엔 선반에 없고, 가게 줄에 있음
	check(not shop._pickups.scissors.visible, "가위는 사기 전엔 선반에 없음")
	var rows: Array = shop.store_rows()
	check(rows.any(func(r: Dictionary) -> bool: return r.id == "scissors" and r.price == Tuning.data.v4_price_scissors), "가게에 가위 (%d)" % Tuning.data.v4_price_scissors)
	shop.money = Tuning.data.v4_price_scissors
	check(shop.buy("scissors"), "가위 사기")
	check(shop.owns_scissors and shop._pickups.scissors.visible, "산 뒤엔 선반에 가위")
	check(not shop.store_rows().any(func(r: Dictionary) -> bool: return r.id == "scissors"), "가위는 한 번만")
	check(is_equal_approx(shop.guests.trim_chance, Tuning.data.v4_trim_request_ratio), "산 뒤엔 미용 요청 손님이 옴")

	# 요청 비율
	var asked := 0
	for i in 400:
		shop.guests.spawn()
		if shop.guests.guests[-1].trim != "":
			asked += 1
		shop.guests.guests[-1].owner.queue_free()
		shop.guests.guests.pop_back()
	check(asked > 60 and asked < 140, "약 1/4 이 미용 요청 (%d / 400)" % asked)

	# 요청 손님: 빗질 뒤 미용 단계, 자를 곳만 자르면 똑같음
	_take_with_trim("bear")
	check_eq(shop.trim_request, "bear", "곰돌이컷 요청")
	_wash_to_trim()
	check_eq(shop.stage_tool(), "scissors", "빗질 뒤엔 가위")
	var wanted: PackedVector3Array = shop.trim.world_positions(true)
	var keep: PackedVector3Array = shop.trim.world_positions(false)
	check(wanted.size() >= 2 and keep.size() >= 4, "자를 곳 %d · 남길 곳 %d 다발" % [wanted.size(), keep.size()])
	shop.pick("scissors")
	for pos in wanted:
		for k in 15:
			shop.use_tool_at(pos, 1.0 / 30.0)
	check(shop.done, "자를 곳을 다 자르면 끝")
	check_eq(shop.trim.match_score(), 1.0, "남길 곳을 안 자르면 똑같음")
	var before: int = shop.money
	shop.next_guest()
	var trim_pay: int = Tuning.data.v4_price_trim + Tuning.data.v4_trim_match_tip[2]
	check(shop.money - before >= Tuning.data.v4_price_wash + trim_pay, "미용 요금 + 똑같음 팁 (+%d)" % (shop.money - before))

	# 남길 곳까지 자르면 덜 비슷 → 팁 작음
	_take_with_trim("bear")
	_wash_to_trim()
	shop.pick("scissors")
	for pos in shop.trim.world_positions(false):
		for k in 15:
			shop.use_tool_at(pos, 1.0 / 30.0)
	for pos in shop.trim.world_positions(true):
		for k in 15:
			shop.use_tool_at(pos, 1.0 / 30.0)
	check(shop.done, "자를 곳을 다 자르면 끝 (남길 곳을 잘랐어도)")
	check(shop.trim.match_score() < Tuning.data.v4_trim_match_at[0], "남길 곳까지 자르면 안 비슷 (%.2f)" % shop.trim.match_score())
	check_eq(shop.trim_tip(shop.trim.match_score()), Tuning.data.v4_trim_match_tip[0], "안 비슷하면 모양 팁 없음")
	shop.next_guest()

	# 요청 없는 손님: 빗질 끝이 곧 끝
	_take_with_trim("")
	_wash_to_trim()
	check(shop.done, "요청이 없으면 미용 단계 없이 끝")


## 대기 손님 하나를 만들어 미용 요청을 정하고 맡김
func _take_with_trim(shape: String) -> void:
	shop.guests.spawn("forever")
	shop.guests.guests[-1].trim = shape
	shop.next_guest()


## 적시기~빗질까지 채워서 미용 단계 앞으로 (빠른 확인과 같은 방식)
func _wash_to_trim() -> void:
	for channel in ["wet", "scrub", "rinse", "dry"]:
		shop.dog.mask.fill(channel, 1.0)
	shop.dog.clear_foam()
	shop._check_done()
	await_brush()


func await_brush() -> void:
	shop.pick("brush")
	for pos in shop.tangles.world_positions():
		for k in 15:
			shop.use_tool_at(pos, 1.0 / 30.0)
