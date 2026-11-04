extends "res://tests/qa_test.gd"
## V4 도구 업그레이드 (TUNING_V4 3-1): 하루가 끝나면 정산 판 아래 도구 가게에서 다음 단계 도구를 사고
## [다음 날] 로 이어 감. 도구마다 5단계 (TUNING_V4 3-2), 산 도구는 칠하는 속도가 v4_tool_speed_mult5 배, 붓도 조금 커짐. 돈·도구는 다음 날로.

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
	check_eq(shop.next_price("shower"), Tuning.data.v4_tool_price5[1], "다음 샤워기 값")
	check_eq(shop.next_price("towel"), Tuning.data.v4_tool_price5[1], "수건도 업그레이드")
	check(not shop.buy("shower"), "돈이 모자라면 못 삼")

	# 속도: 같은 시간 같은 곳에 댈 때 넓은 샤워기가 더 많이 적심
	var slow := _wet_after(0.4)
	shop.money = 1000
	check(shop.buy("shower"), "샤워기 사기")
	check_eq(shop.money, 1000 - Tuning.data.v4_tool_price5[1], "값만큼 돈이 줆")
	check_eq(shop.tool_name("shower"), "넓은 샤워기", "넓은 샤워기")
	if ResourceLoader.exists("res://assets/models/tools/shower_wide.glb"):
		check_eq(shop.model_id("shower"), "shower_wide", "넓은 샤워기 그림")
	else:
		check(shop._pickups.shower.get_node("View").scale.x > 1.0, "그림이 오기 전엔 선반 샤워기가 조금 커짐")
	var fast := _wet_after(0.4)
	check(fast > slow * 1.15, "넓은 샤워기가 더 빨리 적심 (%.2f → %.2f)" % [slow, fast])
	shop.money = 99999
	for i in 3:
		check(shop.buy("shower"), "샤워기 %d단계" % (i + 3))
	check_eq(shop.tool_name("shower"), "무지개 샤워기", "5단계 = 무지개 샤워기")
	check(shop.is_final("shower"), "최종 단계")
	check_eq(shop.next_price("shower"), -1, "더 살 것 없음")
	check(not shop.buy("shower"), "최고 단계에선 못 삼")
	for tool_id in ["shampoo", "towel", "dryer", "brush"]:
		shop.set_tier(tool_id, 4)
		check_eq(shop.model_id(tool_id), shop.LEVEL_MODELS[tool_id][4], "%s 5단계 그림 (%s)" % [tool_id, shop.tool_name(tool_id)])
		shop.set_tier(tool_id, 0)
	# 도구 보정 표 (FpToolView.MODEL_FIX): 대포·드라이기 출구(-Z)가 화면 안쪽을 보고, 표의 크기가 들어감
	for pair in [["shampoo", 3], ["shampoo", 4], ["dryer", 1], ["dryer", 2], ["dryer", 3], ["dryer", 4]]:
		shop.set_tier(pair[0], pair[1])
		shop.pick(pair[0])
		var view: Node3D = shop._held_view
		var model_name: String = shop.model_id(pair[0])
		var outlet: Vector3 = -view.model.global_basis.z.normalized()
		var look: Vector3 = -shop.player.camera.global_basis.z
		check(outlet.dot(look) > 0.0, "%s 출구가 화면 안쪽을 봄 (%.2f)" % [model_name, outlet.dot(look)])
		var fix: Dictionary = view.MODEL_FIX.get(model_name, {"scale": 1.0})
		check(is_equal_approx(view.model.global_basis.get_scale().x / shop.player.camera.global_basis.get_scale().x, fix.scale), "%s 보정 크기 %.2f" % [model_name, fix.scale])
		shop.drop()
		shop.set_tier(pair[0], 0)
	# 최종 단계 샤워기는 붓이 더 넓어 한 번에 더 많이 적심
	var final := _wet_after(0.4)
	check(final > fast * 1.3, "무지개 샤워기가 훨씬 빨리 (%.2f → %.2f)" % [fast, final])

	# 하루 끝: 정산 판 + 가게 → 사기 → 다음 날 (돈·도구 이어짐)
	shop.money = Tuning.data.v4_tool_price5[1]
	shop.fees = 40
	shop.end_day()
	var settle: Control = shop._settle
	var buy_foam := settle.find_child("Store_shampoo", true, false).find_child("Buy", true, false) as Button
	check(buy_foam != null and not buy_foam.disabled, "가게: 거품 펌프 살 수 있음")
	var buy_brush := settle.find_child("Store_brush", true, false).find_child("Buy", true, false) as Button
	check(buy_brush != null and buy_brush.disabled == (shop.money < Tuning.data.v4_tool_price5[1]), "돈이 모자란 도구는 버튼 꺼짐")
	buy_foam.pressed.emit()
	await get_tree().process_frame
	# 산 도구는 택배로 다음 날 아침에 옴
	check_eq(shop.tool_name("shampoo"), "샴푸병", "산 도구는 아직 안 옴 (택배)")
	check_eq(shop.parcels.size(), 1, "주문한 상자 1개")
	check_eq(shop.money, 0, "가진 돈에서 뺌")
	var store_brush: Node = shop._settle.find_child("Store_brush", true, false)
	check(store_brush != null and (store_brush.find_child("Buy", true, false) as Button).disabled, "산 뒤 가게가 새로 그려짐 (돈 0 → 다 꺼짐)")
	(shop._settle.find_child("NextDay", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	check_eq(shop.day, 2, "다음 날")
	check(shop.morning and not shop.guests.open, "다음 날은 아침 준비부터")
	# 아침 트럭 → 매트 → 들고 안에서 열기
	shop.parcels_view.finish_now()
	check_eq(shop.parcels_view.box_nodes().size(), 1, "트럭이 상자를 매트에 내려놓음")
	shop.carry_box(shop.parcels[0])
	check(shop.open_box(), "가게 안에서 상자 열기")
	check_eq(shop.tool_name("shampoo"), "거품 펌프", "상자를 열면 산 도구가 선반에")
	shop.open_shop()
	check(not shop.day_over and shop.guests.open, "다시 영업")
	check(shop._settle == null, "정산 판 닫힘")
	check_eq(shop.fees, 0, "오늘 번 돈은 새로")
	check_eq(shop.tool_name("shampoo"), "거품 펌프", "도구는 이어짐")
	check_eq(shop.tool_name("shower"), "무지개 샤워기", "도구는 이어짐 (샤워기)")
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
