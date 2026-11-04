extends "res://tests/qa_test.gd"
## V4 아침 준비 시간 + 영업 팻말 + 가게 앞 마당 (GDD_V4 '가게 밖·택배', ART_SLOTS 4-3).
## 하루는 아침으로 시작: 시계 멈춤, 손님 안 옴. 문 옆 팻말을 클릭해 뒤집으면 영업 시작.
## 정문은 다가가면 열리고, 밖에는 마당 (보도블록·택배 매트·우편함·가로등·울타리). 울타리 너머 찻길로는 못 나감.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpOutside := preload("res://scripts/v4/fp_outside.gd")

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	for i in 3:
		await get_tree().physics_frame

	# 아침: 시계가 멈춰 있고 손님이 안 옴
	check(shop.morning, "1일차도 아침 준비로 시작")
	check(not shop.outside.sign_open, "팻말은 달 (닫힘)")
	await _wait(3.0)
	check_eq(shop.day_time, 0.0, "아침엔 시계가 안 감")
	check_eq(shop.guests.guests.size(), 0, "아침엔 손님이 안 옴")

	# 팻말: 바라보면 클릭 대상, 클릭(open_shop) 하면 해로 뒤집히고 영업
	var sign_pos: Vector3 = shop.outside.sign_body.global_position
	_look_from(Vector3(2.6, 0.05, sign_pos.z), sign_pos)
	await get_tree().physics_frame
	shop._update_aim()
	check(shop.hovered_sign, "팻말을 바라보면 클릭 대상")
	shop.open_shop()
	check(not shop.morning and shop.guests.open and shop.outside.sign_open, "팻말을 뒤집으면 영업 시작")
	await _wait(2.0)
	check(shop.day_time > 1.0, "영업 중엔 시계가 감 (%.1f s)" % shop.day_time)
	check(shop.guests.guests.size() >= 1, "첫 손님이 옴")
	check(absf(shop.outside.sign_plate.rotation.y - PI) < 0.01, "팻말이 반 바퀴 돎 (해 쪽)")

	# 정문: 멀리 있으면 닫힘, 다가가면 열림
	shop.player.global_position = Vector3(0, 0.05, 0.6)
	await _wait(0.6)
	check(shop.outside.door_open < 0.01, "멀리 있으면 문이 닫힘")
	shop.player.global_position = Vector3(3.2, 0.05, FpOutside.DOOR_Z)
	await _wait(0.6)
	check(shop.outside.door_open > 0.99, "다가가면 문이 열림")

	# 걸어서 밖으로: 정문을 지나 마당에 섬 (벽 구멍만 뚫려 있음)
	shop.player.global_position = Vector3(3.0, 0.05, FpOutside.DOOR_Z)
	await _walk(Vector3.RIGHT, 1.2)
	check(FpOutside.is_outside(shop.player.global_position), "정문으로 걸어 나감 (x = %.2f)" % shop.player.global_position.x)
	check(shop.player.global_position.y > -0.1 and shop.player.global_position.y < 0.3, "마당 바닥 위에 섬 (y = %.2f)" % shop.player.global_position.y)
	# 문이 아닌 벽으로는 못 나감
	shop.player.global_position = Vector3(3.0, 0.05, -1.0)
	await _walk(Vector3.RIGHT, 1.2)
	check(not FpOutside.is_outside(shop.player.global_position), "벽으로는 못 나감")
	# 마당 끝까지 걸어도 찻길로는 못 나감 (울타리 틈 자리도)
	shop.player.global_position = Vector3(7.5, 0.05, FpOutside.DOOR_Z)
	await _walk(Vector3.RIGHT, 2.5)
	check(shop.player.global_position.x < FpOutside.YARD_END_X + 0.2, "찻길로는 못 나감 (x = %.2f)" % shop.player.global_position.x)
	# 마당 물건
	for node_name in ["Paving", "Road", "DeliveryMat", "Mailbox", "StreetLamp", "Fence", "FlowerBed", "OpenSign"]:
		check(shop.outside.find_child(node_name, true, false) != null, "마당: %s" % node_name)
	check(shop.outside.mailbox_flag != null, "우편함 깃발 (택배가 오면 올라감)")

	# 하루 끝 → 팻말 달, 다음 날은 다시 아침
	shop.guests.open = false
	for guest in shop.guests.guests:
		guest.owner.queue_free()
	shop.guests.guests.clear()
	await _wait(0.3)
	check(shop.day_over, "손님이 없으면 정산")
	check(not shop.outside.sign_open, "영업이 끝나면 팻말은 달")
	shop.start_next_day()
	check(shop.morning and shop.day == 2 and shop.day_time == 0.0, "다음 날은 아침 준비부터")
	shop.free()

	# 빠른 확인: 보통은 바로 영업, [아침·가게 밖] 은 아침부터
	for feature in ["day", "morning"]:
		shop = SCENE.instantiate()
		shop.input_enabled = false
		shop.quick_dogs = 1
		shop.quick_feature = feature
		add_child(shop)
		await get_tree().physics_frame
		check_eq(shop.morning, feature == "morning", "빠른 확인 [%s] 아침 여부" % feature)
		shop.free()


func _look_from(from: Vector3, target: Vector3) -> void:
	shop.player.global_position = from
	shop.player.rotation = Vector3.ZERO
	shop.player.camera.rotation = Vector3.ZERO
	shop.player.camera.look_at(target)


## 플레이어를 그 방향으로 걷게 함 (물리로 움직여 벽·막이에 막힘)
func _walk(dir: Vector3, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		shop.player.velocity = dir * 3.0
		shop.player.move_and_slide()
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
