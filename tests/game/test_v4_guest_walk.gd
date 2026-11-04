extends "res://tests/qa_test.gd"
## V4 손님 길 (GDD_V4 '가게 밖': 찻길 → 마당 → 정문으로 정해진 한 줄 길). 영업 중 손님은 울타리 틈에서 나타나
## 마당을 걸어 정문으로 들어와 의자에 앉음. 마당을 걷는 동안은 참을성이 안 줄고 아직 못 받음. 떠날 때도 정문으로 나가 찻길로.
## 벽을 뚫고 지나가지 않음 (오른쪽 벽 x = 4 는 정문 자리로만).

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpGuests := preload("res://scripts/v4/fp_guests.gd")

var shop: Node3D
var _through_wall := 0
var _watched: Node3D
var _last := Vector3.ZERO


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.guests._opening = ["normal"]
	for i in 3:
		await get_tree().physics_frame
	shop.open_shop()
	shop.guests._spawn_left = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	shop.guests._spawn_left = 1e9
	check_eq(shop.guests.guests.size(), 1, "영업을 열면 손님이 옴")
	var guest: Dictionary = shop.guests.guests[0]
	_watched = guest.owner
	_last = _watched.global_position
	check(_watched.global_position.x > 9.0, "울타리 틈(찻길 쪽)에서 나타남 (x = %.1f)" % _watched.global_position.x)

	# 마당을 걷는 동안: 참을성 그대로, 아직 못 받음, 손님이 가까이 오면 정문이 열림
	await _wait(2.0)
	check(_watched.global_position.x > FpGuests.INSIDE_X, "아직 마당 (x = %.1f)" % _watched.global_position.x)
	check_eq(guest.waited, 0.0, "마당을 걷는 동안 참을성 안 줄어듦")
	check(shop.guests.take(_watched).is_empty(), "마당의 손님은 아직 못 받음")
	var door_opened := false
	var t := 0.0
	while t < 10.0 and _watched.global_position.x > FpGuests.INSIDE_X:
		await get_tree().process_frame
		t += get_process_delta_time()
		if shop.outside.door_open > 0.5:
			door_opened = true
	check(door_opened, "손님이 정문을 지날 때 문이 열림")
	check(_watched.global_position.x < FpGuests.INSIDE_X, "정문으로 들어옴 (%.1f 초)" % t)
	await _wait(4.0)
	check(_watched.is_sitting(), "의자에 앉음")
	check(guest.waited > 1.0, "들어온 뒤부터 참을성이 줆 (%.1f s)" % guest.waited)
	check(not shop.guests.take(_watched).is_empty(), "들어온 손님은 받을 수 있음")

	# 돌려주면 정문으로 나가 찻길로 (벽 통과 없이)
	shop.has_dog = true
	shop.done = true
	shop.next_guest()
	var left := false
	t = 0.0
	while t < 15.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if not is_instance_valid(_watched):
			left = true
			break
		if _watched.global_position.x > 9.0:
			left = true
	check(left, "떠나는 손님은 찻길까지 걸어 나감")
	check_eq(_through_wall, 0, "오른쪽 벽은 정문 자리로만 지나감")


func _process(_delta: float) -> void:
	if _watched == null or not is_instance_valid(_watched):
		return
	var now := _watched.global_position
	# x = 4 (오른쪽 벽)을 건넌 프레임: 정문 폭 (z 2.0 ~ 3.2) 안이어야 함
	if (now.x - 4.0) * (_last.x - 4.0) < 0.0 and absf(lerpf(_last.z, now.z, 0.5) - 2.6) > 0.6:
		_through_wall += 1
	_last = now


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
