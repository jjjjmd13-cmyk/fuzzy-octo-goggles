extends "res://tests/qa_test.gd"
## V4 단골 신뢰 (GDD_V4 '단골 신뢰', TUNING_V4 7장): 신뢰 점수 → 4단계 (내려가지 않음), 단계마다 쉬워지는 규칙,
## 도구 버릇 3가지 (샤워 무서움·드라이 예민·수건 무는 손님), 대표 단골 3마리, 사진첩 관계 기록·저장.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpTrust := preload("res://scripts/v4/fp_trust.gd")
const FpRegulars := preload("res://scripts/v4/fp_regulars.gd")
const FpAlbum := preload("res://scripts/v4/fp_album.gd")
const V4Save := preload("res://scripts/v4/v4_save.gd")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 90.0
	get_tree().root.size = Vector2i(1280, 800)

	# 규칙 숫자
	check_eq([FpTrust.tier_of(0), FpTrust.tier_of(1), FpTrust.tier_of(2), FpTrust.tier_of(6), FpTrust.tier_of(12), FpTrust.tier_of(40)], [0, 0, 1, 2, 3, 3], "점수 → 단계 (2 익숙함 · 6 친함 · 12 단짝)")
	check_eq(FpTrust.visit_points(3, true), 4, "🤩 + 처음 좋아하는 곳 = 1 + 2 + 1")
	check_eq(FpTrust.visit_points(1, false), 1, "😐 = 왔음 1")
	check_eq(FpTrust.visit_points(0, false), 0, "😣 = 1 − 1")
	check(FpTrust.cooldown(0) == 2.0 and FpTrust.cooldown(1) == 3.0, "싫어함 사이 2 → 3초")
	check(FpTrust.max_per_rule(3, 2) == 1 and FpTrust.max_per_rule(2, 2) == 2, "단짝은 규칙마다 1번")
	check(FpTrust.ticklish_time(1) == 0.6 and FpTrust.ticklish_time(2) == 0.9, "친함부터 간지럼 0.9초")
	check(is_equal_approx(FpTrust.timid_radius(2), 0.08) and FpTrust.cat_wet_limit(2) == 55.0, "친함부터 겁쟁이·고양이 쉬움")
	check(FpTrust.towel_bite_chance(3) == 0.0, "단짝은 수건을 안 묾 (놀이)")

	# 단골 표: 버릇마다 3마리, 대표 단골 3마리
	var quirks := {}
	for r in FpRegulars.all():
		if not str(r.get("quirk", "")).is_empty():
			quirks[r.quirk] = quirks.get(r.quirk, 0) + 1
	check_eq(quirks, {"shower": 3, "dryer": 3, "towel": 3}, "도구 버릇 9마리 (버릇마다 3)")
	for id in Tuning.data.v4_first_day_regulars:
		check(str(FpRegulars.get_regular(id).get("quirk", "")).is_empty(), "1일차 단골 %s 은 버릇 없음" % id)
	for id in ["mongsil", "nabi", "jjanggu"]:
		var r := FpRegulars.get_regular(id)
		check(r.get("star", false) and r.get("lines", []).size() == 4, "%s 대표 단골, 주인 한마디 4줄" % r.name)
	check_eq([FpRegulars.get_regular("mongsil").quirk, FpRegulars.get_regular("nabi").quirk, FpRegulars.get_regular("jjanggu").quirk], ["shower", "dryer", "towel"], "몽실 샤워 · 나비 드라이 · 짱구 수건")
	# 대표 단골이 오는 날: 짱구 2일차 · 나비 3일차 · 몽실 5일차
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var first4: Array = Array(Tuning.data.v4_first_day_regulars)
	check_eq(FpRegulars.pick(2, 4, first4, 1, [], rng), "jjanggu", "2일차 새 단골 = 짱구")
	check_eq(FpRegulars.pick(3, 2, first4 + ["jjanggu"], 0, [], rng), "nabi", "3일차 고양이 = 나비")
	check_eq(FpRegulars.pick(5, 2, first4 + ["jjanggu", "nabi"], 0, [], rng), "mongsil", "5일차 겁쟁이 = 몽실")
	# 다시 오는 단골: 대표 단골은 2배
	var met := ["kongi", "bori", "dubu", "hotteok", "jjanggu"]
	var count := 0
	for i in 3000:
		if FpRegulars.pick(10, 7, met, 9, [], rng) == "jjanggu":
			count += 1
	check(count > 820 and count < 1180, "대표 단골 2배 무게 (%d / 3000, 약 1000)" % count)

	var real_path := V4Save.path
	V4Save.path = "user://test_v4_trust_save.json"
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	for i in 3:
		await get_tree().physics_frame
	shop.open_shop()
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9

	# 방문 → 신뢰 점수·단계, '처음 ~한 날', 첫·최근 사진, 방문 기분 기록
	_take("kongi")
	check_eq(shop.trust_tier, 0, "처음은 낯가림")
	check(shop.animal_line().contains("낯가림"), "목욕대 위 한 줄에 신뢰 (%s)" % shop.animal_line())
	shop.fav_spot = ""
	_finish_and_return()
	var kongi: Dictionary = shop.album.kongi
	check_eq(kongi.trust_pts, 2, "😊 방문 = 2점")
	check_eq(kongi.trust, 1, "익숙함")
	check(FpTrust.has_moment(kongi, "first") and FpTrust.has_moment(kongi, "trust_1"), "처음 온 날 · 익숙해진 날")
	check(shop._banner.contains("친해졌어요"), "단계가 오르면 '더 친해졌어요!'")
	check(not kongi.first.is_empty() and kongi.recent.day == shop.day, "첫·최근 사진")
	check_eq(kongi.moods, [2], "방문마다 기분 기록")
	# 이름표 하트
	shop.guests.quick_animals = [{"regular": "kongi"}]
	shop.guests.spawn("forever")
	var tag := shop.guests.guests[-1].owner.get_node("NameTag") as Label3D
	check_eq(tag.text, "콩이 ×2 ♥", "이름표에 신뢰 하트")
	shop.next_guest()
	check_eq(shop.trust_tier, 1, "목욕통 신뢰 = 사진첩 단계")
	_wow()
	_finish_and_return()
	_take("kongi")
	_wow()
	_finish_and_return()
	check_eq(shop.album.kongi.trust, 2, "🤩 두 번 → 친함 (%d점)" % shop.album.kongi.trust_pts)
	check(FpTrust.has_moment(shop.album.kongi, "mood_3"), "처음 🤩 기록")
	# 😣 → 점수는 줄어도 단계는 그대로
	var pts: int = shop.album.kongi.trust_pts
	_take("kongi")
	for i in 4:
		shop._t += 5.0
		shop.dislike("bad_%d" % i)
	_finish_and_return()
	check_eq(shop.album.kongi.trust_pts, pts, "😣 방문 = 0점 (왔음 +1 · 😣 −1)")
	check_eq(shop.album.kongi.trust, 2, "단계는 내려가지 않음")

	# 단계별 쉬워짐: 싫어함 사이·단짝 최대·고양이 머리 물
	_take("bori")
	shop.trust_tier = 0
	check(shop.dislike("same"), "낯가림 싫어함")
	shop._t += 2.5
	check(shop.dislike("same"), "낯가림: 2초 뒤 다시")
	shop.trust_tier = 1
	shop._t += 2.5
	check(not shop.dislike("same"), "익숙함: 3초 안엔 다시 안 함")
	shop.trust_tier = 3
	shop._t += 5.0
	check(shop.dislike("best"), "단짝 싫어함 1번")
	shop._t += 5.0
	check(not shop.dislike("best"), "단짝은 규칙마다 1번까지")
	# 단짝: 배 문지르기 = 좋아함
	var belly: Vector3 = shop.dog.model.to_global(shop.dog._body_center() + Vector3(0, -0.12, 0.05))
	var score: int = shop.mood_score
	shop._check_animal_rules("shampoo", belly, 0.1)
	check(shop._likes.has("belly") and shop.mood_score == score + 1, "단짝: 배 문지르기 = 좋아함 +1")
	_finish_and_return()

	# 샤워 무서움 (몽실): 낯가림은 발부터, 친함은 처음 2초만, 단짝은 놀이
	_take("mongsil")
	check_eq(shop.quirk, "shower", "몽실 샤워 무서움")
	check(shop.animal_line().contains("발부터"), "목욕대 위 버릇 한 줄")
	var center: Vector3 = shop.dog._body_center()
	var dislikes_before: int = shop._rule_count.get("shower_fear", 0)
	shop._shower_quirk(center + Vector3(0, 0.1, 0), 0.1)
	check_eq(shop._rule_count.get("shower_fear", 0), dislikes_before + 1, "등부터 적시면 싫어함")
	shop._t += 5.0
	shop._shower_quirk(center + Vector3(0, -0.2, 0), 0.1)
	shop._shower_quirk(center + Vector3(0, 0.1, 0), 0.1)
	check_eq(shop._rule_count.get("shower_fear", 0), dislikes_before + 1, "발 → 몸 순서면 괜찮음")
	shop._set_animal("dog", "timid")
	shop.quirk = "shower"
	shop.trust_tier = 2
	shop._shower_quirk(center + Vector3(0, 0.1, 0), 0.5)
	check_eq(shop._rule_count.get("shower_fear", 0), 1, "친함: 처음 2초엔 조심")
	shop._shower_quirk(center, 2.0)
	shop._t += 5.0
	shop._shower_quirk(center + Vector3(0, 0.1, 0), 0.1)
	check_eq(shop._rule_count.get("shower_fear", 0), 1, "친함: 2초 뒤엔 괜찮음")
	shop.trust_tier = 3
	shop._shower_quirk(center + Vector3(0, 0.1, 0), 0.1)
	check(shop._likes.has("quirk_play"), "단짝: 물줄기 톡톡 놀이 = 좋아함")
	shop.done = true
	shop.next_guest()

	# 드라이 예민 (나비): 켜자마자 가까이 = 싫어함, 천천히는 괜찮음
	_take("nabi")
	check_eq(shop.quirk, "dryer", "나비 드라이 예민")
	var camera: Camera3D = shop.player.camera
	var near_point := camera.global_position - camera.global_basis.z * 0.2
	shop._dryer_quirk(near_point, 0.2)
	check_eq(shop._rule_count.get("dryer_noise", 0), 1, "켜자마자 0.3 m 안 = 싫어함")
	shop._dryer_hold = 0.0
	shop._dryer_inside = false
	shop._t += 5.0
	var far_point := camera.global_position - camera.global_basis.z * 0.8
	shop._dryer_quirk(far_point, 1.2)
	shop._dryer_quirk(near_point, 0.1)
	check_eq(shop._rule_count.get("dryer_noise", 0), 1, "멀리서 켜고 천천히 다가가면 괜찮음")
	# 친함: 고양이 머리 물은 싫어함 아님
	shop.trust_tier = 2
	var face: Vector3 = shop.dog.model.get("face_center") if shop.dog.model.get("face_center") != null else Vector3(0, 0.5, 0.25)
	shop._check_animal_rules("shower", shop.dog.model.to_global(face + Vector3(0, 0.05, 0)), 0.1)
	check_eq(shop._rule_count.get("cat_head", 0), 0, "친함 고양이: 머리에 물은 반응만")
	shop.done = true
	shop.next_guest()

	# 수건 무는 손님 (짱구): 물면 톡이 안 되고, 좌우로 흔들면 놓음. 단짝은 줄다리기 놀이
	_take("jjanggu")
	check_eq(shop.quirk, "towel", "짱구 수건 무는 손님")
	shop.stage_index = shop.STAGES.map(func(st: Dictionary) -> String: return st.id).find("towel")
	shop.pick("towel")
	shop.towel_bitten = true
	var towel_before: float = shop.dog.mask.ratio("towel")
	shop.tap_at(shop.dog.model.to_global(shop.dog._body_center() + Vector3(0, 0.1, 0)))
	check_eq(shop.dog.mask.ratio("towel"), towel_before, "물고 있으면 톡이 안 됨")
	for dx in [10.0, -10.0, 10.0]:
		shop.shake_towel(dx)
	check(not shop.towel_bitten, "좌우로 흔들면 놓음")
	shop.trust_tier = 3
	shop.tap_at(shop.dog.model.to_global(shop.dog._body_center() + Vector3(0, 0.1, 0)))
	check(shop._likes.has("quirk_play") and shop._quirk_overcome, "단짝: 수건 줄다리기 놀이")
	shop.done = true
	shop.next_guest()
	check(FpTrust.has_moment(shop.album.jjanggu, "quirk_towel"), "'처음으로 수건 놀이를 한 날'")

	# 사진첩 카드: 신뢰·버릇·첫/최근 사진·'처음 ~한 날'
	shop.open_album()
	await get_tree().process_frame
	var view: Control = shop._album_view
	view.show_card("kongi")
	await get_tree().process_frame
	check(view.find_child("FirstRecent", true, false) != null, "카드: 첫 방문 ↔ 최근 사진")
	var moments := view.find_child("Moments", true, false) as Label
	check(moments != null and moments.text.contains("친해진 날"), "카드: '처음 ~한 날'")
	view.close_album()

	# 하루 결과 기록의 trust_levels, 저장 되읽기
	check_eq(shop.day_summary().trust_levels, "%d/%d/%d/%d" % FpTrust.tier_counts(shop.album), "trust_levels = 낯가림/익숙함/친함/단짝")
	shop.end_day()
	var saved := V4Save.read()
	check_eq(saved.album.kongi.trust, 2, "신뢰 단계 저장")
	check_eq(saved.album.kongi.trust_pts, shop.album.kongi.trust_pts, "신뢰 점수 저장")
	check_eq(saved.album.kongi.moods.size(), 4, "방문 기분 기록 저장")
	check(FpTrust.has_moment(saved.album.kongi, "trust_2"), "'처음 ~한 날' 저장")
	check_eq(saved.album.kongi.first.day, shop.album.kongi.first.day, "첫 방문 사진 저장")
	var old := V4Save.normalize({"version": 1, "album": {"kongi": {"visits": 3, "best_mood": 2, "day": 2}}})
	check(old.album.kongi.trust == 0 and old.album.kongi.moments.is_empty() and old.album.kongi.first.is_empty(), "신뢰 전 저장도 읽힘")
	shop.free()
	V4Save.erase()
	V4Save.path = real_path


func _take(id: String) -> void:
	shop.guests.quick_animals = [{"regular": id}]
	shop.guests.spawn("forever")
	shop.next_guest()


func _wow() -> void:
	for rule in ["a", "b", "c"]:
		shop.like(rule)


func _finish_and_return() -> void:
	shop.done = true
	shop.next_guest()
