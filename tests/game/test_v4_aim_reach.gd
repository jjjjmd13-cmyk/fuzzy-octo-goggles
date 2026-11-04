extends "res://tests/qa_test.gd"
## 사람 대표 플레이 버그: 분홍 다발 중 누르고 있어도 안 잘리는 곳이 있었음.
## 사람처럼 강아지 둘레에 서서 다발을 가운데 점으로 바라보고 누르고 있으면, 모든 다발이 잘리는지 본다.
## (모양 3가지 × 여러 번, 엉킨 털 뭉치도 같은 방식으로)

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const STEP := 1.0 / 30.0

var shop: Node3D


func run_test() -> void:
	time_limit_sec = 120.0
	get_tree().root.size = Vector2i(1280, 800)
	shop = SCENE.instantiate()
	shop.input_enabled = false
	shop.quick_dogs = 99
	shop.quick_feature = "trim"
	add_child(shop)
	# 시험 중엔 걷기·중력 끔 (자리를 직접 옮김)
	shop.player.set_physics_process(false)
	for i in 3:
		await get_tree().physics_frame
	for round in 6:
		var shape: String = ["bear", "lion", "summer"][round % 3]
		shop.guests.spawn("forever")
		shop.next_guest()
		shop.trim_request = shape
		shop._spawn_trim()
		await get_tree().physics_frame
		shop.pick("scissors")
		var total: int = shop.trim.wanted_total()
		for pos in shop.trim.world_positions(true):
			await _aim_and_hold(pos)
		check_eq(shop.trim.wanted_left(), 0, "%s %d번째: 자를 곳 %d 다발이 모두 잘림" % [shop.FpTrim.SHAPES[shape].name, round + 1, total])
		shop.done = true
		shop.next_guest()

	# 빗질 뭉치도 같은 방식으로
	shop.quick_feature = "brush"
	for round in 3:
		shop.guests.spawn("forever")
		shop.next_guest()
		await get_tree().physics_frame
		shop.pick("brush")
		var lumps: int = shop.tangles.count()
		for pos in shop.tangles.world_positions():
			await _aim_and_hold(pos)
		check_eq(shop.tangles.count(), 0, "빗질 %d번째: 뭉치 %d 개가 모두 풀림" % [round + 1, lumps])
		shop.done = true
		shop.next_guest()


## 목표 쪽에서 강아지를 보는 자리(몸 중심에서 1.2 m, 눈높이)에 서서 목표를 바라보고 1초 누름
func _aim_and_hold(target: Vector3) -> void:
	var center: Vector3 = shop.dog.model.to_global(shop.dog._body_center())
	var side := Vector3(target.x - center.x, 0, target.z - center.z)
	if side.length() < 0.05:
		side = Vector3(0, 0, 1)
	var stand := center + side.normalized() * 1.2
	shop.player.global_position = Vector3(stand.x, 0.0, stand.z)
	shop.player.rotation = Vector3.ZERO
	shop.player.camera.rotation = Vector3.ZERO
	await get_tree().physics_frame
	shop.player.camera.look_at(target)
	shop.using = true
	for i in 30:
		# 사람처럼 가운데 점을 목표에 계속 맞춤
		shop.player.camera.look_at(target)
		shop._process(STEP)
		await get_tree().physics_frame
	shop.using = false
	shop._process(STEP)
