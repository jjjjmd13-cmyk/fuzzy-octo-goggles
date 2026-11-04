extends "res://tests/qa_test.gd"
## V4 가게 꾸미기 (GDD_V4 '가게 꾸미기', TUNING_V4 3-3): 10범주 × ★1·★2·★3. 정산 판 [꾸미기] 탭에서 사면 내일 아침 택배,
## 열면 그 범주 자리에 놓임 (하나만). 산 것끼리·처음 모습으로 공짜로 바꿈. 놓인 것의 ★ 합(아늑함)만큼 대기 참을성 +1% (최대 +30%).

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpDecor := preload("res://scripts/v4/fp_decor.gd")
const V4Save := preload("res://scripts/v4/v4_save.gd")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	var real_path := V4Save.path
	V4Save.path = "user://test_v4_decor_save.json"

	# 목록: 10범주 × 3 = 30, 값·★·상자 크기
	var count := 0
	for category in FpDecor.CATEGORIES:
		count += FpDecor.CATEGORIES[category].items.size()
	check_eq(count, 30, "꾸미기 30개")
	check_eq(FpDecor.price_of("plant_round"), Tuning.data.v4_decor_price_small[0], "작은 것 ★1 값")
	check_eq(FpDecor.price_of("tub_shell"), Tuning.data.v4_decor_price_big[2], "큰 것 ★3 값")
	check_eq(FpDecor.box_size_of("art_dog"), "small", "벽 장식 = 작은 상자")
	check_eq(FpDecor.box_size_of("rug_paw"), "medium", "러그 = 중간 상자")
	check_eq(FpDecor.box_size_of("wall_paw"), "large", "벽지 = 큰 상자")
	for category in FpDecor.CATEGORIES:
		for item in FpDecor.CATEGORIES[category].items:
			var model := FpDecor.MODEL_DIR % item[0]
			var texture := FpDecor.TEXTURE_DIR % item[0]
			check(ResourceLoader.exists(model) or ResourceLoader.exists(texture), "그래픽 파일 있음: %s" % item[0])

	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	for i in 3:
		await get_tree().physics_frame
	check_eq(shop.guests.patience_mult, 1.0, "처음엔 아늑함 0")
	check(shop._tub_view.visible and shop.decor_view.nodes.is_empty(), "처음 모습")

	# 주문 → 내일 아침 상자 → 들고 안에서 열면 놓임
	shop.money = 1000
	check(shop.order("plant_round"), "동글 화분 주문")
	check_eq(shop.parcels[-1], {"item": "decor:plant_round", "kind": "decor", "size": "medium", "arrived": false}, "중간 상자로 옴")
	check_eq(shop.next_price("plant_round"), -1, "주문한 것은 또 못 삼")
	var rows: Dictionary = shop.decor_rows()
	var plant_row: Dictionary = rows.rows.filter(func(row: Dictionary) -> bool: return row.category == "plant")[0]
	check_eq(plant_row.items[0].state, "coming", "꾸미기 탭: 오는 중 📦")
	shop.end_day()
	check(shop._settle.find_child("DecorBox", true, false) != null, "정산 판에 꾸미기 탭")
	shop.start_next_day()
	shop.parcels_view.finish_now()
	shop.carry_box(shop.parcels[0])
	shop.player.global_position = Vector3(0, 0.05, 1.0)
	check(shop.open_box(), "상자 열기")
	check(shop.decor.owned.has("plant_round") and shop.decor.placed.get("plant") == "plant_round", "열면 산 것·놓인 것")
	check(shop.decor_view.nodes.has("plant"), "화분이 대기 의자 옆에")
	check(is_equal_approx(shop.guests.patience_mult, 1.0 + Tuning.data.v4_decor_patience_per_point), "아늑함 ★1 → 참을성 +1%")

	# 목욕통·벽지 (바로 사기): 처음 것은 숨고 새 것이 보임
	shop.money = 5000
	check(shop.buy("tub_shell") and shop.buy("wall_paw") and shop.buy("tub_wood"), "조개 욕조·발바닥 벽지·원목 통 사기")
	check_eq(shop.decor.placed.tub, "tub_wood", "한 범주엔 하나만 (마지막에 산 것)")
	check(not shop._tub_view.visible, "처음 목욕통은 숨음")
	check_eq(shop.decor_view.nodes.tub.get_meta("decor"), "tub_wood", "새 목욕통")
	var wall_mesh: MeshInstance3D = shop.decor_view.wall_meshes[0]
	check(wall_mesh.material_override.has_meta("decor") and wall_mesh.material_override.get_meta("decor") == "wall_paw", "벽지가 발바닥 무늬로")
	# 산 것끼리 공짜로 바꾸기 / 처음 모습으로
	var money: int = shop.money
	check(shop.place_decor("tub_shell"), "조개 욕조로 바꿔 끼움")
	check_eq(shop.decor_view.nodes.tub.get_meta("decor"), "tub_shell", "바뀐 목욕통")
	check_eq(shop.money, money, "바꿔 끼우기는 공짜")
	check(not shop.place_decor("tub_claw"), "안 산 것은 못 놓음")
	check(shop.place_decor("default:tub") and shop._tub_view.visible and not shop.decor_view.nodes.has("tub"), "처음 목욕통으로 되돌림")
	check(shop.place_decor("default:wall") and not wall_mesh.material_override.has_meta("decor"), "처음 벽으로 되돌림")
	# 정산 판에서 놓기 (버튼 신호)
	shop.end_day()
	shop._settle.place_requested.emit("wall_paw")
	check_eq(shop.decor.placed.get("wall"), "wall_paw", "정산 판 꾸미기 탭에서 놓기")
	check_eq(V4Save.read().decor.placed.get("wall"), "wall_paw", "놓으면 저장")

	# 아늑함 최대: 모두 ★3 = ★30 → +30%, 손님이 그만큼 더 기다림
	shop._quick_decor(3)
	check_eq(FpDecor.coziness(shop.decor.placed), 30, "모두 ★3 = 아늑함 ★30")
	check(is_equal_approx(shop.guests.patience_mult, 1.0 + Tuning.data.v4_decor_patience_max), "참을성 +30% (최대)")
	shop.guests.spawn("normal")
	shop.guests.guests[-1].waited = Tuning.data.v4_patience_normal
	check(shop.guests.remaining(shop.guests.guests.size() - 1) > 0.2, "보통 손님 150초가 지나도 아직 기다림")

	# 저장 → 이어하기: 놓인 꾸미기가 그대로 보임
	var state: Dictionary = shop.save_state(3)
	shop.free()
	V4Save.write(state)
	V4Save.continue_requested = true
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	await get_tree().physics_frame
	check_eq(shop.decor.placed.size(), 10, "이어하면 10범주 모두 놓임")
	check_eq(shop.decor_view.nodes.size(), 8, "3D 꾸미기 8개 (벽지·바닥은 텍스처)")
	check(not shop._tub_view.visible, "이어하면 조개 욕조")
	shop.free()

	V4Save.erase()
	V4Save.path = real_path
