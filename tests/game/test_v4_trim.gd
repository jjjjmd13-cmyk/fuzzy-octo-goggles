extends "res://tests/qa_test.gd"
## V4 미용 (TUNING_V4 3-1, 3-1-1 실제로 자르기): 가위는 도구 가게에서 사야 선반에 나오고, 산 뒤엔 일부 손님이 모양(곰돌이컷 등)을
## 요청한다. 빗질 뒤 털이 길게 자라 있고, 누른 채 지나가면 안내선까지 쓱 잘림 (클릭은 조금만). 털 조각이 목욕통에 쌓였다가
## 돌려주면 사라짐. 안내선에 맞으면 똑같음 → 미용 요금 + 큰 팁. 오래 눌러 지나치게 자르면 기분 −1 만 (실패 없음).
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
	# 가위는 v4_scissors_from_day (4일차) 부터 가게에 (18일 흐름)
	shop.day = Tuning.data.v4_scissors_from_day
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

	# 요청 손님: 빗질 뒤 미용 단계 = 털이 길게 (1.0) 자라 있고 목표 모양 안내선 (하늘색 원판)
	_take_with_trim("bear")
	check_eq(shop.trim_request, "bear", "곰돌이컷 요청")
	_wash_to_trim()
	check_eq(shop.stage_tool(), "scissors", "빗질 뒤엔 가위")
	var trim: FpTrim = shop.trim
	check(trim.tufts.size() >= 40, "털 다발이 몸 전체에 (%d)" % trim.tufts.size())
	check(trim.tufts.all(func(t: Dictionary) -> bool: return is_equal_approx(t.len, 1.0)), "처음엔 모두 길이 1.0")
	var targets: Array = Tuning.data.v4_trim_targets.bear
	var head: Array = trim.tufts.filter(func(t: Dictionary) -> bool: return t.zone == "head")
	check(not head.is_empty() and head.all(func(t: Dictionary) -> bool: return is_equal_approx(t.target, targets[0])), "곰돌이컷 머리 목표 %.2f" % targets[0])
	check(head.all(func(t: Dictionary) -> bool: return (t.guide as Node3D).visible), "자를 곳엔 하늘색 안내 원판")
	check(trim.tufts.filter(func(t: Dictionary) -> bool: return t.zone == "tail").all(func(t: Dictionary) -> bool: return not (t.guide as Node3D).visible), "꼬리 (목표 1.0) 엔 안내 없음")
	check_eq(FpTrim.cut_zones("bear"), ["head", "body", "legs"], "요청 카드 분홍 부위 = 목표가 짧은 곳")
	shop.pick("scissors")

	# 클릭 한 번 (누른 첫 순간) = v4_trim_click_step 만큼만
	var one: Dictionary = head[0]
	var spot: Vector3 = (one.node as Node3D).global_position
	trim._idle = 1.0
	shop.use_tool_at(spot, 1.0 / 30.0)
	check(is_equal_approx(one.len, 1.0 - Tuning.data.v4_trim_click_step), "클릭 한 번 = %.2f 만큼 (%.3f)" % [Tuning.data.v4_trim_click_step, one.len])
	check(shop.sfx.played.has("snip"), "싹둑 소리")
	# 누른 채 지나가기 (다발 밖 → 안): 한 번에 v4_trim_pass_step 까지, 안내선에서 멈춤
	shop.use_tool_at(spot + Vector3(0.5, 0, 0), 1.0 / 30.0)
	var before: float = one.len
	for k in 6:
		shop.use_tool_at(spot, 1.0 / 30.0)
	check(is_equal_approx(before - one.len, Tuning.data.v4_trim_pass_step) or is_equal_approx(one.len, one.target), "한 번 지나가면 %.2f 까지 (%.3f → %.3f)" % [Tuning.data.v4_trim_pass_step, before, one.len])
	for k in 20:
		shop.use_tool_at(spot + Vector3(0.5, 0, 0), 1.0 / 30.0)
		shop.use_tool_at(spot, 1.0 / 30.0)
	check(is_equal_approx(one.len, one.target), "여러 번 지나가도 안내선에서 멈춤 (%.3f = %.2f)" % [one.len, one.target])
	await get_tree().create_timer(1.1).timeout
	check(trim.clippings.size() >= 3, "잘린 털 조각이 떨어짐 (%d)" % trim.clippings.size())
	var floor_y: float = shop.dog.model.global_position.y
	check(trim.clippings.all(func(c: Node3D) -> bool: return absf(c.global_position.y - floor_y) < 0.02), "털 조각은 목욕통 바닥에 쌓임")

	# 사람처럼 쓱쓱: 아직 자를 다발마다 지나가기 → 다 됐어요, 똑같음
	_sweep_all()
	check_eq(trim.wanted_left(), 0, "자를 곳이 다 안내선까지")
	check(shop.done, "다 됐어요! (미용 끝)")
	check(trim.match_score() >= Tuning.data.v4_trim_match_at[1], "안내선에 맞음 = 똑같음 (%.2f)" % trim.match_score())
	check_eq(trim.overcut_ratio(), 0.0, "안내선에서 멈추면 지나치게 자른 곳 없음")
	var pieces: Array = trim.clippings.duplicate()
	var money_before: int = shop.money
	var mood_before: int = shop.mood_score
	shop.next_guest()
	var trim_pay: int = Tuning.data.v4_price_trim + Tuning.data.v4_trim_match_tip[2]
	check(shop.money - money_before >= Tuning.data.v4_price_wash + trim_pay, "미용 요금 + 똑같음 팁 (+%d)" % (shop.money - money_before))
	check(trim.clippings.is_empty(), "돌려주면 털 조각이 쓱 사라짐")
	await get_tree().create_timer(0.5).timeout
	check(pieces.all(func(c: Variant) -> bool: return not is_instance_valid(c)), "털 조각 지워짐")
	check(shop.mood_score >= mood_before, "제대로 자르면 기분 그대로")

	# 지나치게 자르기: 같은 곳을 계속 누르고 있으면 안내선 아래로 → 기분 −1 (한 번만), 실패는 없음
	# (사자컷 몸 0.35 는 가장 짧게 0.3 과 가까워 지나치게 자를 수 없음 → 곰돌이컷으로)
	_take_with_trim("bear")
	_wash_to_trim()
	trim = shop.trim
	shop.pick("scissors")
	var mood_start: int = shop.mood_score
	for t in trim.tufts.duplicate():
		if t.target < 1.0:
			for k in 60:
				shop.use_tool_at((t.node as Node3D).global_position, 1.0 / 30.0)
	check(trim.overcut_ratio() > Tuning.data.v4_trim_overcut_mood_at, "오래 누르면 지나치게 짧아짐 (%.2f)" % trim.overcut_ratio())
	check(trim.tufts.all(func(t: Dictionary) -> bool: return t.len >= Tuning.data.v4_trim_len_min - 0.001), "가장 짧게 %.1f 아래로는 안 잘림" % Tuning.data.v4_trim_len_min)
	# (자르는 동안 좋아하는 곳 +1 이 겹칠 수 있어 싫어함 수로 봄)
	check_eq(shop._rule_count.get("trim_overcut", 0), 1, "지나치게 자르면 기분 −1 (한 번만)")
	check(shop.mood_score <= mood_start, "기분이 오르지 않음")
	check(shop.done, "지나치게 잘라도 미용은 끝 (실패 없음)")
	check(trim.match_score() < Tuning.data.v4_trim_match_at[0], "덜 비슷 (%.2f)" % trim.match_score())
	check_eq(shop.trim_tip(trim.match_score()), Tuning.data.v4_trim_match_tip[0], "안 비슷하면 모양 팁 없음")
	money_before = shop.money
	shop.next_guest()
	check(shop.money - money_before >= Tuning.data.v4_price_wash + Tuning.data.v4_price_trim, "미용 요금은 늘 받음")

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
	for channel in ["wet", "scrub", "rinse", "towel", "dry"]:
		shop.dog.mask.fill(channel, 1.0)
	shop.dog.clear_foam()
	shop._check_done()
	await_brush()


## 아직 자를 다발마다 사람처럼 쓱 지나가기 (밖 → 다발 → 밖, 여러 번)
func _sweep_all() -> void:
	for round in 6:
		for t in shop.trim.tufts.duplicate():
			if t.len <= t.target + Tuning.data.v4_trim_ok_band:
				continue
			var at: Vector3 = (t.node as Node3D).global_position
			shop.use_tool_at(at + Vector3(0.4, 0, 0), 1.0 / 30.0)
			for k in 5:
				shop.use_tool_at(at, 1.0 / 30.0)


func await_brush() -> void:
	shop.pick("brush")
	for pos in shop.tangles.world_positions():
		for k in 30:
			shop.use_tool_at(pos + Vector3(0, 0.05 - (k % 10) * 0.01, 0), 1.0 / 30.0)
