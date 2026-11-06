extends "res://tests/qa_test.gd"
## V4 처음 하는 사람 안내 (기획 LAUNCH_PREP 2장): 그 일을 처음 할 때 한 번만, 한 줄 띠 + 대상 위 ▼.
## 걷기 → 손님 → 선반 샤워기 → 단계 손동작 → 주인에게 돌려주기 → 첫 사진 → 첫 정산 → 다음 날 팻말·택배. 본 것은 저장, 메뉴 [안내 끄기]·[안내 다시 보기], F1 조작 그림.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const MENU_SCENE := preload("res://scenes/menu/main_menu.tscn")
const V4Save := preload("res://scripts/v4/v4_save.gd")
const Settings := preload("res://scripts/core/settings.gd")
const FpGuide := preload("res://scripts/v4/fp_guide.gd")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 90.0
	get_tree().root.size = Vector2i(1280, 800)
	var real_save := V4Save.path
	var real_settings := Settings.path
	V4Save.path = "user://test_v4_guide_save.json"
	Settings.path = "user://test_v4_guide_settings.cfg"
	V4Save.erase()
	Settings.guide_enabled = true
	V4Save.continue_requested = false

	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	for i in 3:
		await get_tree().physics_frame
	var guide: FpGuide = shop.guide
	check(guide.enabled, "안내 켜짐")
	check_eq(guide.tip_key, "walk", "1일차 시작: 걸어서 손님을 맞아요")
	check(not guide.seen.has("sign"), "팻말 안내는 다음 아침")
	shop.open_shop()
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9

	# 첫 손님: 손님 위 ▼ → 맡기면 사라짐
	shop.guests.quick_animals = [{"regular": "kongi"}]
	shop.guests.spawn("forever")
	shop._on_guest_arrived()
	check_eq(guide.tip_key, "guest", "손님을 눌러 맡아요")
	check_eq(guide.markers(), 1, "손님 위 ▼")
	shop.next_guest()
	check_eq(guide.tip_key, "shelf", "선반에서 샤워기를 집어요")
	await get_tree().process_frame
	await get_tree().process_frame
	check_eq(guide.markers(), 1, "맡기면 손님 ▼ 은 사라지고 샤워기 위 ▼")
	shop.pick("shower")
	check_eq(guide.tip_key, "stage_wet", "샤워기를 집으면 적시기 손동작")
	await get_tree().process_frame
	await get_tree().process_frame
	check_eq(guide.markers(), 0, "집으면 ▼ 사라짐")
	# 단계마다 처음 한 번: 거품 (샴푸를 집을 때)
	shop.dog.mask.fill("wet", 1.0)
	shop._check_done()
	shop.pick("shampoo")
	check_eq(guide.tip_key, "stage_scrub", "거품 손동작")
	# 다 씻음 → 주인 위 ▼ → 돌려주면 첫 사진
	shop.done = false
	shop.stage_index = shop.STAGES.size()
	shop._check_done()
	check_eq(guide.tip_key, "give_back", "주인에게 돌려줘요")
	shop.next_guest()
	check_eq(guide.tip_key, "photo", "사진첩에 붙었어요!")
	# 같은 일 두 번째는 안내 없음
	shop.guests.quick_animals = [{"regular": "bori"}]
	shop.guests.spawn("forever")
	shop._on_guest_arrived()
	check_eq(guide.tip_key, "photo", "두 번째 손님엔 안내 없음")
	shop.next_guest()
	shop.done = true
	shop.next_guest()
	# 첫 정산 → [도구 가게]
	shop.guests.open = false
	shop.money = 300
	shop.end_day()
	check_eq(guide.tip_key, "settle", "번 돈으로 도구를 키워요")
	shop.order("shampoo_bottle")
	# 다음 날 아침: 팻말 ▼, 택배 ▼
	shop.start_next_day()
	check(guide.seen.has("sign"), "2일차 아침: 팻말을 뒤집으면 영업 시작")
	shop.parcels_view.finish_now()
	check_eq(guide.tip_key, "parcel", "택배가 왔어요! 들고 들어와요")
	check(guide.markers() >= 1, "팻말·상자 위 ▼")
	# F1
	shop.guide.toggle_help()
	check(guide.help_visible, "F1 조작 그림")
	shop.guide.toggle_help()
	# 본 안내는 저장 → 이어하면 다시 안 나옴
	shop.save_game(shop.day)
	var saved := V4Save.read()
	for key in ["walk", "guest", "shelf", "stage_wet", "stage_scrub", "give_back", "photo", "settle", "sign", "parcel"]:
		check(saved.guide_seen.has(key), "본 안내 저장: %s" % key)
	shop.free()
	V4Save.continue_requested = true
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	await get_tree().physics_frame
	check_eq(shop.guide.tip_key, "", "이어하면 본 안내는 안 나옴")
	shop.free()

	# 메뉴: [안내 끄기] → 새 가게는 안내 없음, [안내 다시 보기] → 본 것 지움
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	(menu.find_child("SettingsButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	var toggle := menu.find_child("GuideToggle", true, false) as Button
	check(toggle != null and toggle.text == "안내 끄기", "메뉴 [설정] 의 [안내 끄기]")
	toggle.pressed.emit()
	check(not Settings.guide_enabled and toggle.text == "안내 켜기", "안내 꺼짐")
	V4Save.continue_requested = false
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	await get_tree().physics_frame
	check(not shop.guide.enabled and shop.guide.tip_key == "", "끄면 안내 없음")
	shop.free()
	(menu.find_child("GuideReplay", true, false) as Button).pressed.emit()
	check(Settings.guide_enabled, "다시 보기 = 안내 켬")
	check(V4Save.read().guide_seen.is_empty(), "다시 보기 = 본 안내 지움")
	menu.queue_free()

	# 빠른 확인에는 안내 없음
	shop = SCENE.instantiate()
	shop.input_enabled = false
	shop.quick_dogs = 1
	shop.quick_feature = "day"
	add_child(shop)
	await get_tree().physics_frame
	check(not shop.guide.enabled, "빠른 확인엔 안내 없음")
	shop.free()

	V4Save.erase()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	V4Save.path = real_save
	Settings.path = real_settings
	Settings.guide_enabled = true
