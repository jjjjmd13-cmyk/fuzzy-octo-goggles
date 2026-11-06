extends "res://tests/qa_test.gd"
## V4 택배 + 샴푸·빗 닳음 (GDD_V4 '택배 흐름', '샴푸·빗 닳음', TUNING_V4 3-4·3-5).
## 정산 판에서 산 것은 상자로 다음 날 아침 트럭이 매트에 내려놓음 → 들고 (느리게) 안에서 열면 제자리로.
## 거품 단계마다 샴푸가 줄고 (좋은 거품 도구는 덜), 없으면 거품 없이 요금 10·팁 0. 빗은 닳으면 느려짐 (부러지지 않음).

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpOutside := preload("res://scripts/v4/fp_outside.gd")

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
	shop.open_shop()

	# 샴푸: 거품 단계 하나 = 1마리분, 5단계 거품 도구는 0.5
	check_eq(shop.shampoo_left, 20.0, "처음 샴푸 20마리분")
	_wash_to("scrub")
	check_eq(shop.shampoo_left, 19.0, "한 마리 거품 = 1마리분")
	shop.set_tier("shampoo", 4)
	_wash_to("scrub")
	check_eq(shop.shampoo_left, 18.5, "5단계 거품 도구는 0.5마리분")
	shop.set_tier("shampoo", 0)
	shop.shampoo_left = 3.5
	_new_dog()
	shop.dog.mask.fill("wet", 1.0)
	shop.dog.mask.fill("scrub", 1.0)
	shop._check_done()
	check(shop._hint.contains("샴푸가 2마리분"), "3마리분 아래로 내려가는 순간 알림, 반 마리는 내려서 정수로 (QA #137, %s)" % shop._hint)
	check(shop._supply_lines()[0].contains("2마리분") and not shop._supply_lines()[0].contains("."), "정산 남은 샴푸도 정수 (QA #137)")
	# 빗 닳음: 수명을 넘어도 글자는 상한에서 멈춤 (QA #137)
	var used: int = shop.brush_used
	shop.brush_used = shop.brush_life() + 58
	check(shop._supply_lines().any(func(line: String) -> bool: return line.contains("%d / %d마리 (다 닳았어요)" % [shop.brush_life(), shop.brush_life()])), "빗 닳음 30 / 30 (다 닳았어요)")
	shop.brush_used = used
	shop.done = true
	shop.next_guest()
	# 샴푸 없음: 거품을 건너뛰고 씻김, 요금 10·팁 0
	shop.shampoo_left = 0.0
	_new_dog()
	check(shop.no_shampoo, "샴푸가 없으면 거품 없이")
	check(shop.dog.mask.ratio("scrub") >= 0.99, "거품 단계는 건너뜀")
	shop.done = true
	var before: int = shop.money
	shop.next_guest()
	check_eq(shop.money - before, Tuning.data.v4_no_shampoo_price, "샴푸 없이 씻기면 요금 %d, 팁 0" % Tuning.data.v4_no_shampoo_price)

	# 빗: 1단계 수명 30마리, 절반 지나면 느려져 다 닳으면 ×0.7, 4단계부터 안 닳음
	check_eq(shop.brush_life(), 30, "일반 빗 수명 30")
	check_eq(shop.brush_wear_mult(), 1.0, "새 빗은 그대로")
	shop.brush_used = 15
	check_eq(shop.brush_wear_mult(), 1.0, "절반까지는 그대로")
	shop.brush_used = 24
	check(is_equal_approx(shop.brush_wear_mult(), lerpf(0.7, 1.0, 0.4)), "절반 넘으면 천천히 느려짐 (%.2f)" % shop.brush_wear_mult())
	shop.brush_used = 40
	check(is_equal_approx(shop.brush_wear_mult(), 0.7), "다 닳으면 ×0.7 (부러지지 않음)")
	shop.brush_used = 0
	_wash_to("brush")
	check_eq(shop.brush_used, 1, "빗질 한 마리 = 1 닳음")
	shop.set_tier("brush", 3)
	check_eq(shop.brush_life(), 0, "전동 빗은 안 닳음")
	check_eq(shop.brush_wear_mult(), 1.0, "안 닳는 빗은 그대로")
	shop.set_tier("brush", 0)
	shop.brush_used = 20

	# 가게: 산 것은 상자 (내일 아침), 같은 도구 다음 단계는 주문까지 쳐서
	shop.money = 2000
	shop.shampoo_left = 4.0
	check(shop.order("shower"), "샤워기 주문")
	check_eq(shop.tool_name("shower"), shop.TOOL_LEVEL_NAMES.shower[0], "주문만 하면 아직 그대로")
	check_eq(shop.next_price("shower"), Tuning.data.v4_tool_price5[2], "다음 샤워기 값은 주문한 단계 다음")
	check(shop.order("shampoo_bottle") and shop.order("brush_refill"), "샴푸 1병·새 빗살 주문")
	check_eq(shop.next_price("brush_refill"), -1, "새 빗살은 한 번만")
	check_eq(shop.parcels.size(), 3, "상자 3개")
	shop.end_day()
	var lines: Array = shop._supply_lines()
	check(lines[0].begins_with("⚠") and lines[0].contains("4마리분"), "정산: 샴푸가 적으면 ⚠ (%s)" % lines[0])
	check(lines.any(func(line: String) -> bool: return line.contains("빗 닳음  20 / 30")), "정산: 빗 닳음")
	check(lines.any(func(line: String) -> bool: return line.contains("📦 3개")), "정산: 내일 아침 도착 3개")
	check(shop._settle.find_child("Store_shampoo_bottle", true, false) != null, "정산 가게에 샴푸 줄")

	# 다음 날 아침: 트럭이 와서 매트에 내려놓음
	shop.start_next_day()
	check(shop.parcels_view.delivering and shop.parcels_view.truck.visible, "아침에 트럭이 옴")
	check_eq(shop.parcels_view.box_nodes().size(), 0, "트럭이 서기 전엔 매트가 비어 있음")
	await _wait(Tuning.data.v4_truck_seconds + 0.5)
	check_eq(shop.parcels_view.box_nodes().size(), 3, "상자 3개가 매트에")
	check(shop.parcels.all(func(box: Dictionary) -> bool: return box.arrived), "모두 도착")
	check(is_equal_approx(shop.outside.mailbox_flag.rotation.x, -PI / 2.0), "우편함 깃발이 올라감")
	check(not shop.parcels_view.truck.visible, "트럭은 떠남")

	# 상자 들기: 바라보면 클릭 대상, 들면 도구는 못 집고 조금 느리게
	var node: StaticBody3D = shop.parcels_view.box_nodes()[0]
	var box: Dictionary = node.get_meta("box")
	shop.player.global_position = Vector3(5.0, 0.05, node.global_position.z + 1.4)
	shop.player.rotation = Vector3.ZERO
	shop.player.camera.rotation = Vector3.ZERO
	shop.player.camera.look_at(node.global_position + Vector3(0, 0.1, 0))
	await get_tree().physics_frame
	shop._update_aim()
	check(is_same(shop.hovered_box, box), "매트 위 상자를 바라보면 클릭 대상")
	shop.carry_box(box)
	check(is_same(shop.carried, box), "상자를 듦")
	check_eq(shop.parcels_view.box_nodes().size(), 2, "매트에서 떨어짐")
	shop.pick("shower")
	check_eq(shop.held, "", "상자를 들면 도구를 못 집음")
	check(not shop.open_box(), "밖에서는 못 엶")
	# 안으로 들어와서 열기
	shop.player.global_position = Vector3(1.0, 0.05, 1.0)
	var item: String = box.item
	check(shop.open_box(), "안에서 열기")
	check(shop.carried.is_empty() and is_equal_approx(shop.player.speed_mult, 1.0), "연 뒤엔 빈손·보통 걸음")
	check_eq(shop.parcels.size(), 2, "연 상자는 없어짐")
	# 나머지도 열기 → 효과 확인
	for rest in shop.parcels.duplicate():
		shop.player.global_position = Vector3(5.0, 0.05, 0.5)
		shop.carry_box(rest)
		shop.player.global_position = Vector3(1.0, 0.05, 1.0)
		shop.open_box()
	check_eq(shop.tool_name("shower"), shop.TOOL_LEVEL_NAMES.shower[1], "샤워기 상자 → 선반에 2단계 (%s)" % item)
	check_eq(shop.shampoo_left, 4.0 + Tuning.data.v4_shampoo_bottle, "샴푸 상자 → 20마리분 채움")
	check_eq(shop.brush_used, 0, "새 빗살 → 새 빗")
	check(is_equal_approx(shop.outside.mailbox_flag.rotation.x, 0.0), "매트가 비면 깃발 내려감")
	shop.free()

	# 빠른 확인 [택배·샴푸]: 아침, 상자 3개가 트럭으로
	shop = SCENE.instantiate()
	shop.input_enabled = false
	shop.quick_dogs = 1
	shop.quick_feature = "parcels"
	add_child(shop)
	await get_tree().physics_frame
	check(shop.morning and shop.parcels_view.delivering, "빠른 확인 [택배·샴푸]: 아침에 트럭")
	check_eq(shop.parcels.size(), 4, "상자 4개 (수레·샤워기·샴푸·가위)")
	check_eq(shop.shampoo_left, 2.0, "샴푸 2마리분")
	shop.free()


## 새 강아지를 받아 stage 단계까지 끝냄
func _wash_to(stage: String) -> void:
	_new_dog()
	var order := ["wet", "scrub", "rinse", "towel", "dry", "brush"]
	for id in order:
		match id:
			"rinse":
				shop.dog.clear_foam()
				shop.dog.mask.fill("rinse", 1.0)
			"brush":
				shop.tangles.clear()
			_:
				shop.dog.mask.fill(id, 1.0)
		shop._check_done()
		if id == stage:
			break
	shop.done = true
	shop.next_guest()


func _new_dog() -> void:
	shop.guests.spawn("forever")
	shop.next_guest()


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
