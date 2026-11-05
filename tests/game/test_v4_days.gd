extends "res://tests/qa_test.gd"
## V4 18일 전체 흐름 (GDD_V4 '18일 전체 흐름', TUNING_V4 6장) + 18일 점검 도구 (이슈 #122, scripts/dev/fp_day_tools.gd):
## 날마다 손님 간격 · 급한 손님 2일차 · 가위 4일차 · 의자 4번째 9일차 · 초대장 12일차 · 18일차 축제 (끝까지·금색 없는 단골 먼저·팁 ×1.5·모자·마당 장식)
## → 정산 뒤 엔딩 (단체 사진·별 3개·크레딧·[계속 영업하기]) → 19일차 자유 영업. 점검 도구: 날 건너뛰기·돈 +1,000·하루 결과 기록.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpDays := preload("res://scripts/v4/fp_days.gd")
const FpRegulars := preload("res://scripts/v4/fp_regulars.gd")
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
	for day in [1, 2, 3, 4, 5, 6, 7, 9, 12, 13, 18, 19]:
		check(not FpDays.notice(day).is_empty(), "%d일차 아침 알림: %s" % [day, FpDays.notice(day)])
	check(FpDays.notice(8).is_empty(), "8일차는 새 것 없음")
	check(FpDays.notice(13).contains("5일"), "축제까지 남은 날")
	check(not FpDays.invite_open(11) and FpDays.invite_open(12) and FpDays.invite_open(18) and not FpDays.invite_open(19), "초대장 12~18일차")
	check_eq(FpDays.tip_mult(18), 1.5, "축제 팁 ×1.5")
	var stars := FpDays.stars({"a": {"best_mood": 3}, "b": {"best_mood": 2}}, {"shower": 4, "dryer": 4, "brush": 4, "towel": 1}, 21)
	check(not stars[0].got and stars[1].got and stars[2].got, "별: 금색 1 (12 필요) ✗ · 5단계 3개 ✓ · 아늑함 21 ✓")
	# 축제 날 뽑기: prefer (금색 없는 단골) 먼저
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 10:
		check_eq(FpRegulars.pick(18, i + 1, ["kongi", "bori", "dubu"], 0, [], rng, ["bori"]), "bori", "축제: 금색 없는 단골 먼저")

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

	# 12일차: 우편함 초대장
	_set_day(12)
	check(shop.outside.get_node_or_null("Invite") != null, "12일차 우편함 초대장")
	check(shop.outside.get_node_or_null("Festival") == null, "축제 장식은 아직")

	# 17일차 팁 (비교용) → 18일차 축제
	_set_day(17)
	var tip_17 := _wash_one("kongi")
	_set_day(18)
	check(shop.outside.get_node_or_null("Festival") != null, "18일차 마당 풍선·깃발")
	check(shop.outside.get_node("Invite/InviteLabel").text.contains("오늘"), "초대장 '오늘!'")
	check(guests.festival, "축제 손님")
	check_eq(guests.roll_kind(), "forever", "축제: 모두 끝까지 (안 떠남)")
	var tip_18 := _wash_one("kongi")
	check_eq(tip_18, roundi(tip_17 * 1.5), "축제 팁 ×1.5 (%d → %d)" % [tip_17, tip_18])
	guests.quick_animals = [{"regular": "bori"}]
	guests.spawn()
	check(guests.guests[-1].owner.find_child("FestivalHat", true, false) != null, "주인 축제 모자")
	check_eq(guests.guests[-1].kind, "forever", "축제 손님은 끝까지")
	_clear_guests()

	# 엔딩: 18일차 정산 → [다음 날] = 엔딩 (날은 그대로), 저장은 19일차
	var closed: Array = []
	shop.day_closed.connect(func(summary: Dictionary) -> void: closed.append(summary))
	shop.album["dubu"] = {"visits": 3, "best_mood": 3, "day": 5, "trim": "", "wall": "", "floor": "", "fav_found": true}
	shop.regulars_met_order.append("dubu")
	guests.open = false
	shop.end_day()
	shop.start_next_day()
	await get_tree().process_frame
	check_eq(closed.size(), 1, "하루를 닫음 (day_closed)")
	check(is_instance_valid(shop._ending), "18일차 정산 뒤 엔딩")
	check_eq(shop.day, 18, "엔딩 중엔 날 그대로")
	check(shop.ending_seen, "엔딩 봄")
	check_eq(shop.group_photo, shop.regulars_met_order, "단체 사진 = 만난 단골")
	check_eq(V4Save.read().next_day, 19, "엔딩 뒤 이어하면 19일차")
	check(V4Save.read().ending_seen, "엔딩 본 것 저장")
	var ending: Control = shop._ending
	check(ending.find_child("GroupPhoto", true, false) != null, "단체 사진 무대")
	ending.finish_now()
	check_eq(ending.step, 4, "별·크레딧·버튼까지")
	check_eq(ending.got_stars(), FpDays.stars(shop.album, shop.tool_level, 0).filter(func(r: Dictionary) -> bool: return r.got).size(), "별 수")
	(ending.find_child("Continue", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(not is_instance_valid(ending), "[계속 영업하기] → 엔딩 닫힘")
	check_eq(shop.day, 19, "19일차 자유 영업")
	check_eq(closed.size(), 1, "엔딩 뒤 다음 날에 하루를 두 번 닫지 않음")
	check(shop.outside.get_node_or_null("Festival") == null and not guests.festival, "축제는 그날만")
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
