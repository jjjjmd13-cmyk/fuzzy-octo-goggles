extends "res://tests/qa_test.gd"
## V4 도구 업그레이드 (TUNING_V4 3-1): 하루가 끝나면 정산 판 아래 도구 가게에서 다음 단계 도구를 사고
## [다음 날] 로 이어 감. 산 도구는 칠하는 속도가 v4_tool_speed_mult 배, 붓도 조금 커짐. 돈·도구는 다음 날로.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")

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

	check_eq(shop.tool_name("shower"), "작은 샤워기", "처음엔 기본 도구")
	check_eq(shop.next_price("shower"), Tuning.data.v4_price_shower[1], "다음 샤워기 값")
	check_eq(shop.next_price("dryer"), Tuning.data.v4_price_dryer[1], "다음 드라이기 값")
	check(not shop.buy("shower"), "돈이 모자라면 못 삼")

	# 속도: 같은 시간 같은 곳에 댈 때 넓은 샤워기가 더 많이 적심
	var slow := _wet_after(0.4)
	shop.money = 1000
	check(shop.buy("shower"), "샤워기 사기")
	check_eq(shop.money, 1000 - Tuning.data.v4_price_shower[1], "값만큼 돈이 줆")
	check_eq(shop.tool_name("shower"), "넓은 샤워기", "넓은 샤워기")
	if ResourceLoader.exists("res://assets/models/tools/shower_wide.glb"):
		check_eq(shop.model_id("shower"), "shower_wide", "넓은 샤워기 그림")
	else:
		check(shop._pickups.shower.get_node("View").scale.x > 1.0, "그림이 오기 전엔 선반 샤워기가 조금 커짐")
	var fast := _wet_after(0.4)
	check(fast > slow * 1.3, "넓은 샤워기가 더 빨리 적심 (%.2f → %.2f)" % [slow, fast])
	check(shop.buy("shower"), "레인 샤워기까지")
	check_eq(shop.next_price("shower"), -1, "더 살 것 없음")
	check(not shop.buy("shower"), "최고 단계에선 못 삼")
	check(shop.buy("dryer") and shop.next_price("dryer") == -1, "드라이기는 2단계까지")

	# 하루 끝: 정산 판 + 가게 → 사기 → 다음 날 (돈·도구 이어짐)
	shop.money = Tuning.data.v4_price_foam[1]
	shop.fees = 40
	shop.end_day()
	var settle: Control = shop._settle
	var buy_foam := settle.find_child("Store_shampoo", true, false).find_child("Buy", true, false) as Button
	check(buy_foam != null and not buy_foam.disabled, "가게: 거품 펌프 살 수 있음")
	var buy_brush := settle.find_child("Store_brush", true, false).find_child("Buy", true, false) as Button
	check(buy_brush != null and buy_brush.disabled == (shop.money < Tuning.data.v4_price_brush[1]), "돈이 모자란 도구는 버튼 꺼짐")
	buy_foam.pressed.emit()
	await get_tree().process_frame
	check_eq(shop.tool_name("shampoo"), "거품 펌프", "가게에서 산 도구")
	check_eq(shop.money, 0, "가진 돈에서 뺌")
	var store_brush: Node = shop._settle.find_child("Store_brush", true, false)
	check(store_brush != null and (store_brush.find_child("Buy", true, false) as Button).disabled, "산 뒤 가게가 새로 그려짐 (돈 0 → 다 꺼짐)")
	(shop._settle.find_child("NextDay", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check_eq(shop.day, 2, "다음 날")
	check(not shop.day_over and shop.guests.open, "다시 영업")
	check(shop._settle == null, "정산 판 닫힘")
	check_eq(shop.fees, 0, "오늘 번 돈은 새로")
	check_eq(shop.tool_name("shampoo"), "거품 펌프", "도구는 이어짐")
	check_eq(shop.tool_name("shower"), "레인 샤워기", "도구는 이어짐 (샤워기)")
	check(shop.clock_text() == "오전 9:00", "시계도 처음부터")


## 새 강아지 등 한 곳에 샤워기를 seconds 초 대고 난 뒤 적신 비율
func _wet_after(seconds: float) -> float:
	shop.guests.spawn("forever")
	shop.next_guest()
	shop.pick("shower")
	var point: Vector3 = shop.dog.model.to_global(shop.dog._body_center() + Vector3(0, 0.25, 0.1))
	var t := 0.0
	while t < seconds:
		shop.use_tool_at(point, 1.0 / 30.0)
		t += 1.0 / 30.0
	var wet: float = shop.dog.mask.ratio("wet")
	shop.done = true
	shop.next_guest()
	shop.drop()
	return wet
