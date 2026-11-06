extends "res://tests/qa_test.gd"
## V4 18일 전체 흐름 (GDD_V4 '18일 전체 흐름', TUNING_V4 6장) + 18일 점검 도구 (이슈 #122, scripts/dev/fp_day_tools.gd):
## 날마다 손님 간격 · 급한 손님 2일차 · 가위 4일차 · 의자 4번째 9일차 · 18일차는 평소 영업
## → 정산 뒤 '감사의 날' 엔딩 (fp_thanks.gd: 저녁 → 단골 한마디 → 그때와 지금 → 단체 사진 → 별 3개 → 고마워요 → [계속 영업하기]) → 19일차 자유 영업.
## 점검 도구: 날 건너뛰기·돈 +1,000·하루 결과 기록.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpDays := preload("res://scripts/v4/fp_days.gd")
const FpRegulars := preload("res://scripts/v4/fp_regulars.gd")
const FpThanks := preload("res://scripts/v4/fp_thanks.gd")
const FpDayTools := preload("res://scripts/dev/fp_day_tools.gd")
const V4Save := preload("res://scripts/v4/v4_save.gd")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 90.0
	get_tree().root.size = Vector2i(1280, 800)

	# 규칙 표
	check_eq(FpDays.guest_every(1), 60.0, "1일차 손님 간격 60초")
	check_eq(FpDays.guest_every(7), 42.0, "7일차 42초")
	check_eq(FpDays.guest_every(18), 36.0, "18일차 36초")
	check_eq(FpDays.guest_every(25), float(Tuning.data.v4_free_play_guest_every), "자유 영업 간격")
	check(not FpDays.hurry_open(1) and FpDays.hurry_open(2), "급한 손님은 2일차부터")
	check(FpDays.seat_count(8) == 3 and FpDays.seat_count(9) == 4, "대기 의자 9일차부터 4개")
	for day in [1, 2, 3, 4, 5, 6, 7, 9, 19]:
		check(not FpDays.notice(day).is_empty(), "%d일차 아침 알림: %s" % [day, FpDays.notice(day)])
	for day in [8, 12, 13, 18]:
		check(FpDays.notice(day).is_empty(), "%d일차는 새 것 없음 (축제·초대장은 뺌)" % day)
	check(FpDays.is_last_day(18) and not FpDays.is_last_day(17), "18일차 = 마지막 날")
	# 별 3개: 금색 사진 12 · 5단계 도구 3 · 단짝 단골 6
	var six := {}
	for i in 6:
		six["r%d" % i] = {"best_mood": 2, "trust": 3}
	six["gold"] = {"best_mood": 3, "trust": 1}
	var stars := FpDays.stars(six, {"shower": 4, "dryer": 4, "brush": 4, "towel": 1})
	check(not stars[0].got and stars[1].got and stars[2].got, "별: 금색 1 ✗ · 5단계 3개 ✓ · 단짝 6 ✓")
	check(stars[2].name.contains("단짝 단골 6마리"), "별 이름 '단짝 단골 6마리'")
	six.erase("r0")
	check(not FpDays.stars(six, {})[2].got, "단짝 5마리면 ⭐3 아직")
	# 감사의 날: 들어오는 차례 (신뢰 낮은 → 높은, 마지막 짱구 → 나비 → 몽실), 최대 12쌍 (대표 단골은 늘)
	var many := {}
	for i in 14:
		many["d%02d" % i] = {"trust": i % 4, "trust_pts": i, "first": {"day": 1, "mood": 1}, "recent": {"day": 9, "mood": 2}}
	for id in ["mongsil", "nabi", "jjanggu"]:
		many[id] = {"trust": 0, "trust_pts": 0, "first": {"day": 2, "mood": 1}, "recent": {"day": 18, "mood": 3}}
	var order := FpThanks.visitor_order(many, Tuning.data.v4_thanks_visitors_max)
	check_eq(order.size(), Tuning.data.v4_thanks_visitors_max, "최대 12쌍")
	check_eq(order.slice(-3), ["jjanggu", "nabi", "mongsil"], "마지막 셋은 짱구 → 나비 → 몽실")
	var rising := true
	for i in range(1, order.size() - 3):
		rising = rising and int(many[order[i]].trust) >= int(many[order[i - 1]].trust)
	check(rising, "신뢰 낮은 단골부터")
	check(not order.has("d00"), "넘치면 신뢰 낮은 단골은 단체 사진에만")
	var pairs := FpThanks.photo_pairs(many, Tuning.data.v4_thanks_photo_pairs)
	check(pairs.size() == 5 and pairs.slice(0, 3) == ["jjanggu", "nabi", "mongsil"], "그때와 지금 5쌍: 대표 단골 3 + 신뢰 높은 2")
	check_eq(FpThanks.group_order(["kongi", "jjanggu", "bori", "mongsil"]), ["mongsil", "jjanggu", "kongi", "bori"], "단체 사진 앞줄은 대표 단골")
	check_eq(FpThanks.line_of("kongi", 2), FpThanks.COMMON_LINES[2], "다른 단골은 공통 대사")
	check(FpThanks.recent_caption(18, 18) == "오늘 18일차" and FpThanks.recent_caption(15, 18) == "최근 15일차", "그날 안 온 단골 사진은 '최근' (QA #137)")
	check_eq(FpThanks.line_of("mongsil", 3), FpRegulars.get_regular("mongsil").lines[3], "대표 단골은 자기 대사")

	var real_path := V4Save.path
	V4Save.path = "user://test_v4_days_save.json"
	V4Save.erase()
	V4Save.continue_requested = false
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	for i in 3:
		await get_tree().physics_frame
	var guests: Node3D = shop.guests
	check(shop._card_left > 0.0 and shop._card_title == "1일차 아침", "아침 알림 카드")

	# 급한 손님: 1일차 없음, 2일차부터 (연 뒤 v4_hurry_after 지나서)
	guests.elapsed = 1000.0
	var hurry := 0
	for i in 300:
		hurry += 1 if guests.roll_kind() == "hurry" else 0
	check_eq(hurry, 0, "1일차 급한 손님 없음")
	guests.day = 2
	for i in 300:
		hurry += 1 if guests.roll_kind() == "hurry" else 0
	check(hurry > 0, "2일차 급한 손님 (%d / 300)" % hurry)

	# 가위: 3일차 정산 가게엔 없음, 4일차부터
	shop.day = 3
	check(not shop.store_rows().any(func(row: Dictionary) -> bool: return row.id == "scissors"), "3일차 가게에 가위 없음")
	shop.day = 4
	check(shop.store_rows().any(func(row: Dictionary) -> bool: return row.id == "scissors"), "4일차 가게에 가위")

	# 9일차: 대기 의자 4개
	_set_day(8)
	check(not guests.get_node("Chair_4").visible, "8일차 의자 3개")
	_set_day(9)
	check(guests.get_node("Chair_4").visible and guests.seat_count == 4, "9일차 의자 4개")
	shop.open_shop()
	guests._opening.clear()
	guests._spawn_left = 1e9
	for i in 5:
		guests.spawn("normal")
	check_eq(guests.guests.size(), 4, "4명까지 기다림")
	_clear_guests()

	# 18일차는 평소 영업 (팁 배수·모자·마당 장식 없음)
	_set_day(17)
	var tip_17 := _wash_one("kongi")
	_set_day(18)
	var tip_18 := _wash_one("kongi")
	check_eq(tip_18, tip_17, "18일차 팁도 평소대로")
	check(guests.roll_kind() != "" and shop.outside.get_node_or_null("Festival") == null, "축제 장식 없음")
	_clear_guests()

	# 엔딩: 18일차 정산 → [다음 날] = 엔딩 (날은 그대로), 저장은 19일차
	var closed: Array = []
	shop.day_closed.connect(func(summary: Dictionary) -> void: closed.append(summary))
	shop.album["dubu"] = {"visits": 3, "best_mood": 3, "day": 5, "trim": "", "wall": "", "floor": "", "fav_found": true, "trust": 3, "trust_pts": 14, "first": {"day": 1, "mood": 1}, "recent": {"day": 18, "mood": 3}, "moments": [{"id": "trust_3", "day": 12}]}
	shop.regulars_met_order.append("dubu")
	shop.album["mongsil"] = {"visits": 6, "best_mood": 2, "day": 9, "trim": "", "wall": "", "floor": "", "fav_found": false, "trust": 2, "trust_pts": 8, "first": {"day": 5, "mood": 0}, "recent": {"day": 17, "mood": 2}, "moments": []}
	shop.regulars_met_order.append("mongsil")
	guests.open = false
	shop.end_day()
	shop.start_next_day()
	await get_tree().process_frame
	check_eq(closed.size(), 1, "하루를 닫음 (day_closed)")
	var thanks: Node = shop._ending
	check(thanks is FpThanks, "18일차 정산 뒤 감사의 날")
	check_eq(shop.day, 18, "엔딩 중엔 날 그대로")
	check(shop.ending_seen, "엔딩 봄")
	check_eq(shop.group_photo, FpThanks.group_order(shop.regulars_met_order), "단체 사진 = 만난 단골 (대표 단골 앞줄)")
	check_eq(shop.group_photo[0], "mongsil", "몽실이 앞줄")
	check_eq(V4Save.read().next_day, 19, "엔딩 뒤 이어하면 19일차")
	check(V4Save.read().ending_seen, "엔딩 본 것 저장")
	# 저녁: 걷기·클릭 잠금, 불빛 주황
	check_eq(thanks.phase, "evening", "저녁부터")
	check(not shop.input_enabled and not shop.player.is_physics_processing(), "걷기·도구 잠금")
	var sun: DirectionalLight3D = shop.get_children().filter(func(n: Node) -> bool: return n is DirectionalLight3D)[0]
	check(sun.light_color.r > sun.light_color.b + 0.3, "저녁 불빛 (주황)")
	# 클릭으로 넘기면 단골이 차례로 들어와 한마디
	thanks.skip()
	await get_tree().create_timer(0.2).timeout
	check_eq(thanks.phase, "visitors", "단골들이 들어옴")
	check_eq(thanks.visitors.slice(-2), ["dubu", "mongsil"], "신뢰 높은 두부 → 마지막은 대표 단골 몽실 (콩이는 앞)")
	check(thanks.get_node_or_null("Visitor_" + thanks.visitors[0]) != null, "주인과 단골이 한 쌍으로")
	# 두부 (단짝) 차례까지 넘기며 기다림
	var line: Label3D = null
	for i in 400:
		await get_tree().process_frame
		var dubu := thanks.get_node_or_null("Visitor_dubu")
		line = dubu.find_child("Line", true, false) as Label3D if dubu != null else null
		if line != null:
			break
		if i % 20 == 19:
			thanks.skip()
	check(line != null and line.text.contains(FpThanks.COMMON_LINES[3]), "단짝 단골 주인 한마디")
	check(thanks.get_children().any(func(n: Node) -> bool: return n.has_meta("belly")), "단짝은 내려와 배를 보여 줌")
	# 끝까지 넘기기 → 그때와 지금 → 단체 사진 → 별 → 버튼
	thanks.finish_now()
	for i in 20:
		await get_tree().process_frame
	var ending: Control = thanks.ending
	check(ending != null and ending.find_child("GroupPhoto", true, false) != null, "단체 사진 무대")
	check_eq(ending.step, 4, "별·고마워요·버튼까지")
	check_eq(ending.got_stars(), FpDays.stars(shop.album, shop.tool_level).filter(func(r: Dictionary) -> bool: return r.got).size(), "별 수")
	check(ending.find_child("*", true, false) != null and str(ending.CREDITS[0]).contains("Thanks for playing"), "고마워요 한 줄")
	(ending.find_child("Continue", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(thanks), "[계속 영업하기] → 엔딩 닫힘")
	check_eq(shop.day, 19, "19일차 자유 영업")
	check(shop.input_enabled and shop.player.is_physics_processing(), "걷기 다시")
	check(sun.light_color.r - sun.light_color.b < 0.3, "낮 불빛으로 되돌림")
	check_eq(closed.size(), 1, "엔딩 뒤 다음 날에 하루를 두 번 닫지 않음")
	# 사진첩 마지막 쪽 = 단체 사진
	shop.open_album()
	await get_tree().process_frame
	var album: Control = shop._album_view
	check_eq(album.pages(), album.regular_pages() + 1, "사진첩 마지막 쪽 하나 더")
	album.show_page(album.pages() - 1)
	check(album.find_child("GroupPhoto", true, false) != null, "마지막 쪽에 단체 사진")
	album.close_album()
	# 19일차 정산 뒤엔 엔딩 안 나옴
	shop.end_day()
	shop.start_next_day()
	check(not is_instance_valid(shop._ending) and shop.day == 20, "엔딩은 한 번만")

	# 점검 도구 (개발용)
	FpDayTools.log_path = "user://test_v4_day_log.csv"
	if FileAccess.file_exists(FpDayTools.log_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FpDayTools.log_path))
	var tools := FpDayTools.new()
	add_child(tools)
	tools.attach(shop)
	Engine.set_meta(FpDayTools.LOG_META, true)
	var money: int = shop.money
	tools.add_money()
	check_eq(shop.money, money + 1000, "돈 +1,000")
	# 아침에 건너뛰기 → 다음 날 아침, 저장됨, 기록 한 줄
	tools.skip_day(false)
	check(shop.day == 21 and shop.morning, "건너뛰기 → 21일차 아침")
	check_eq(V4Save.read().next_day, 21, "건너뛴 날도 자동 저장")
	check_eq(V4Save.read().money, shop.money, "저장된 돈")
	# 정산 판에서 산 것도 기록 (모두 받음 → 손님 수·요금)
	tools.skip_day(true)
	var lines := FileAccess.get_file_as_string(FpDayTools.log_path).strip_edges().split("\n")
	check_eq(lines.size(), 3, "기록: 열 이름 + 하루 한 줄씩")
	check_eq(lines[0], FpDayTools.COLUMNS, "첫 줄은 열 이름")
	var row := lines[2].split(",")
	check_eq(row.size(), 11, "11열")
	check_eq(row[0], "21", "day")
	check_eq(int(row[1]), floori(shop.day_seconds / FpDays.guest_every(21)), "모두 받음: served = 480 ÷ 간격")
	check(int(row[3]) > 0 and int(row[4]) > 0, "요금·팁 합")
	check_eq(int(row[7]), V4Save.read().money, "money_after = 저장된 돈")
	# 정산 판에서 사고 건너뛰기 → bought·upkeep
	_set_day(shop.day)
	shop.end_day()
	shop.order("shampoo_bottle")
	tools.skip_day(false)
	lines = FileAccess.get_file_as_string(FpDayTools.log_path).strip_edges().split("\n")
	row = lines[-1].split(",")
	check_eq(row[6], "shampoo_bottle", "bought")
	check_eq(int(row[5]), Tuning.data.v4_shampoo_bottle_price, "upkeep = 샴푸값")
	Engine.set_meta(FpDayTools.LOG_META, false)
	tools.queue_free()

	# 저장 모양: 엔딩 값
	var raw := V4Save.fresh()
	raw.ending_seen = true
	raw.group_photo = ["kongi", "nabi"]
	var back := V4Save.normalize(JSON.parse_string(JSON.stringify(raw)))
	check(back.ending_seen and back.group_photo == ["kongi", "nabi"], "엔딩 저장 되읽기")
	check(not V4Save.fresh().ending_seen, "새로 하기는 엔딩 안 봄")

	shop.free()
	V4Save.erase()
	V4Save.path = real_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FpDayTools.log_path))


func _set_day(day: int) -> void:
	shop.day = day
	shop.guests.day = day
	shop._apply_day()


## 단골 하나를 맡아 다 씻은 것으로 돌려줌 → 그 손님 팁
func _wash_one(id: String) -> int:
	shop.morning = false
	shop.guests.process_mode = Node.PROCESS_MODE_INHERIT
	shop.guests.open = true
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	shop.guests.quick_animals = [{"regular": id}]
	shop.guests.spawn("normal")
	shop.next_guest()
	shop.done = true
	var before: int = shop.tips
	shop.next_guest()
	return shop.tips - before


func _clear_guests() -> void:
	for guest in shop.guests.guests:
		(guest.owner as Node3D).queue_free()
	shop.guests.guests.clear()
