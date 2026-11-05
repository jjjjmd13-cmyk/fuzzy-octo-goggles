extends "res://tests/qa_test.gd"
## V4 액세서리 (GDD_V4 '액세서리', TUNING_V4 7-1, ART_SLOTS 4-5): 범주 4 × ★1·★2·★3 = 12개, 처음엔 분홍 리본.
## 다 씻은 뒤 목욕통 옆 바구니 → 하나 씌움 (머리·목·귀 옆), 단골이 좋아하는 범주면 좋아함 +1 + "어머, 귀여워!",
## 사진·사진첩 카드에 남음, 정산 판 [액세서리] 탭에서 사면 내일 아침 작은 상자, 저장.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpAccessory := preload("res://scripts/v4/fp_accessory.gd")
const FpRegulars := preload("res://scripts/v4/fp_regulars.gd")
const FpTrust := preload("res://scripts/v4/fp_trust.gd")
const V4Save := preload("res://scripts/v4/v4_save.gd")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 90.0
	get_tree().root.size = Vector2i(1280, 800)

	# 목록·값
	check_eq(FpAccessory.all_items().size(), 12, "12개")
	check_eq(FpAccessory.categories(), ["ribbon", "hat", "scarf", "pin"], "범주 4")
	check(FpAccessory.price_of("hat_party") == 30 and FpAccessory.price_of("scarf_bandana") == 60 and FpAccessory.price_of("pin_rainbow") == 120, "값 30·60·120")
	check_eq(FpAccessory.category_of("ribbon_gold"), "ribbon", "범주 찾기")
	var cats := {}
	for r in FpRegulars.all():
		check(FpAccessory.CATEGORIES.has(r.get("acc", "")), "%s 좋아하는 범주 있음" % r.name)
		cats[r.acc] = cats.get(r.acc, 0) + 1
	check_eq(cats.size(), 4, "범주가 고르게 (4가지 모두)")
	check_eq(V4Save.fresh().acc_owned, ["ribbon_pink"], "처음엔 분홍 리본")

	var real_path := V4Save.path
	V4Save.path = "user://test_v4_accessory_save.json"
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	for i in 3:
		await get_tree().physics_frame
	shop.open_shop()
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	check(shop.get_node_or_null("AccBasket") != null, "목욕통 옆 바구니")
	check_eq(shop.acc_owned, ["ribbon_pink"], "가진 것: 분홍 리본")

	# 씻는 중엔 못 씌움, 다 씻으면 씌움
	_take("kongi")
	check(not shop.wear_acc("ribbon_pink"), "다 씻기 전엔 못 씌움")
	shop.open_acc_menu()
	check(not is_instance_valid(shop._acc_menu), "다 씻기 전엔 바구니가 안 열림")
	shop.done = true
	check(not shop.wear_acc("hat_crown"), "안 가진 것은 못 씌움")
	shop.open_acc_menu()
	var menu: Control = shop._acc_menu
	check(menu != null and menu.find_child("Acc_ribbon_pink", true, false) != null and menu.find_child("Acc_none", true, false) != null, "바구니: 가진 것 + 안 씌우기")
	var score: int = shop.mood_score
	(menu.find_child("Acc_ribbon_pink", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check(not is_instance_valid(menu), "고르면 닫힘")
	check_eq(shop.acc_on, "ribbon_pink", "씌움")
	var worn := shop.dog.model.find_child("Accessory", true, false) as Node3D
	check(worn != null and worn.get_meta("acc") == "ribbon_pink" and worn.get_parent().name == "Acc_Head", "머리 자리에 리본")
	check_eq(FpRegulars.get_regular("kongi").acc, "ribbon", "콩이는 리본을 좋아함")
	check(shop._likes.has("acc") and shop.mood_score == mini(score + 1, 3), "좋아하는 범주 → 좋아함 +1")
	# 바꿔 씌우면 앞 것은 빠짐
	shop.acc_owned.append("scarf_mint")
	shop.wear_acc("scarf_mint")
	check_eq(shop.dog.model.find_children("Accessory", "", true, false).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size(), 1, "한 번에 하나만")
	check_eq((shop.dog.model.find_child("Acc_Neck", true, false) as Node3D).get_child_count() > 0, true, "스카프는 목 자리")
	shop.wear_acc("ribbon_pink")
	shop.next_guest()
	var kongi: Dictionary = shop.album.kongi
	check_eq(kongi.acc, "ribbon_pink", "사진에 액세서리")
	check(kongi.acc_found, "좋아하는 액세서리를 찾음")
	check(FpTrust.has_moment(kongi, "acc_like"), "'처음 액세서리를 좋아한 날'")
	check_eq(kongi.recent.acc, "ribbon_pink", "최근 사진에도")
	check_eq(shop.acc_on, "", "돌려주면 다음 동물은 맨머리")

	# 안 좋아하는 범주: 벌 없음
	_take("bori")
	shop.done = true
	score = shop.mood_score
	shop.wear_acc("ribbon_pink")
	check(shop.mood_score == score and not shop._acc_liked, "다른 범주는 그냥 '좋아요' (벌 없음)")
	shop.next_guest()
	check(not shop.album.bori.get("acc_found", false), "좋아하는 범주는 아직 '?'")

	# 고양이는 0.85 배
	_take("nabi")
	shop.done = true
	shop.wear_acc("ribbon_pink")
	var cat_acc := shop.dog.model.find_child("Accessory", true, false) as Node3D
	check(cat_acc != null and is_equal_approx(cat_acc.scale.x, FpAccessory.CAT_SCALE), "고양이는 크기만 0.85")
	shop.next_guest()

	# 사진첩 카드
	shop.open_album()
	await get_tree().process_frame
	shop._album_view.show_card("kongi")
	await get_tree().process_frame
	var labels: Array = shop._album_view.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(labels.has("좋아하는 액세서리: 리본"), "카드: 좋아하는 액세서리")
	shop._album_view.show_card("bori")
	await get_tree().process_frame
	labels = shop._album_view.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(labels.has("좋아하는 액세서리: ?"), "못 찾았으면 '?'")
	shop._album_view.close_album()

	# 가게 탭: 사면 내일 아침 작은 상자 → 열면 가진 것에
	shop.money = 500
	shop.guests.open = false
	shop.end_day()
	var tab := shop._settle.find_child("Tab_acc", true, false) as Button
	check(tab != null, "정산 판 [액세서리] 탭")
	var buy := shop._settle.find_child("hat_party", true, false) as Button
	check(buy != null and not buy.disabled, "고깔모자 사기 버튼")
	buy.pressed.emit()
	await get_tree().process_frame
	check_eq(shop.money, 500 - 30, "30 냄")
	var box: Array = shop.parcels.filter(func(b: Dictionary) -> bool: return b.item == "acc:hat_party")
	check(box.size() == 1 and box[0].size == "small" and box[0].kind == "acc", "작은 택배 상자로")
	check_eq(shop.next_price("hat_party"), -1, "산 것은 다시 못 삼")
	check(shop.acc_rows()[1].items[0].state == "coming", "가게 줄: 오는 중")
	shop.apply_item("acc:hat_party")
	check(shop.acc_owned.has("hat_party"), "상자를 열면 가진 것에")

	# 저장
	shop.save_game(shop.day + 1)
	var saved := V4Save.read()
	check(saved.acc_owned.has("hat_party") and saved.acc_owned.has("ribbon_pink"), "가진 액세서리 저장")
	check(saved.album.kongi.acc == "ribbon_pink" and saved.album.kongi.acc_found, "사진 액세서리·찾음 저장")
	check_eq(V4Save.normalize({"version": 1}).acc_owned, ["ribbon_pink"], "옛 저장은 분홍 리본부터")
	shop.free()
	V4Save.erase()
	V4Save.path = real_path


func _take(id: String) -> void:
	shop.guests.quick_animals = [{"regular": id}]
	shop.guests.spawn("forever")
	shop.next_guest()
