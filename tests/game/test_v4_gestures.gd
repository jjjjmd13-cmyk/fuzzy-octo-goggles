extends "res://tests/qa_test.gd"
## V4 단계마다 다른 손동작 (GDD_V4 손동작 다시 정리, TUNING_V4 3-2). 서툴러도 진행은 되고, 맞으면 빨라짐.
## 거품: 좌우로 비비기 / 헹굼: 위 → 아래로 쓸어내리기 / 빗질: 뭉치에 쓸기 (털 방향이면 한 번 덜) / 드라이: 거리

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const STEP := 1.0 / 30.0

var shop: Node3D
var spot: Vector3


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	shop.player.set_physics_process(false)
	for i in 3:
		await get_tree().physics_frame

	# 거품: 같은 1초, 가만히 vs 좌우로 비비기
	_new_dog(["wet"])
	shop.pick("shampoo")
	_hold(spot, 30)
	var still: float = shop.dog.mask.ratio("scrub")
	_new_dog(["wet"])
	shop.pick("shampoo")
	for i in 30:
		shop.use_tool_at(spot + Vector3(0.02 if i % 2 == 0 else -0.02, 0, 0), STEP)
	var rubbed: float = shop.dog.mask.ratio("scrub")
	check(still > 0.0, "가만히 대도 거품은 조금 남 (%.3f, 서툴러도 진행)" % still)
	check(rubbed > still * 1.5, "좌우로 비비면 거품이 빨리 (%.3f → %.3f)" % [still, rubbed])

	# 헹굼: 같은 0.1초, 아래 → 위 vs 위 → 아래
	var removed := []
	for down in [false, true]:
		_new_dog(["wet", "scrub"])
		for k in 12:
			shop.dog.add_foam(spot + Vector3(0, 0.1 - k * 0.02, 0), 1, shop._rng, 2.4)
		var foam_before: int = shop.dog.foam_count()
		shop.pick("shower")
		# 거품 12개 위를 0.1 초 (3 프레임) 만 쓸고 몇 개 씻겼는지 (다 씻기기 전에 비교)
		for i in 3:
			var y := 0.03 - i * 0.03 if down else -0.03 + i * 0.03
			shop.use_tool_at(spot + Vector3(0, y, 0), STEP)
		removed.append(foam_before - shop.dog.foam_count())
	check(removed[1] > removed[0], "위 → 아래로 쓸어내리면 거품이 더 빨리 씻김 (%d → %d 개)" % removed)

	# 빗질: 대고만 1초 → 안 풀림 / 털 방향 2번 → 풀림 / 옆으로 2번 → 아직 / 옆으로 3번 → 풀림
	_new_dog(["wet", "scrub", "rinse", "towel", "dry"])
	shop.pick("brush")
	# 빗이 닿는 거리(약 0.3 m)가 뭉치 사이(약 0.2 m)보다 넓어서, 뭉치가 여럿이면 옆 뭉치도 같이 풀려 개수가 흔들림 → 하나씩만 둠
	var clump := _one_clump()
	_hold(clump, 30)
	check_eq(shop.tangles.count(), 1, "대고만 1초로는 안 풀림 (천천히 진행)")
	_strokes(clump, Vector3(0, -0.01, 0), 2)
	check_eq(shop.tangles.count(), 0, "털 방향(위 → 아래) 2번 쓸면 풀림")
	# 뭉치가 다 풀리면 빗질이 끝나므로 새 강아지로
	_new_dog(["wet", "scrub", "rinse", "towel", "dry"])
	shop.pick("brush")
	clump = _one_clump()
	_strokes(clump, Vector3(0.01, 0, 0), 2)
	check_eq(shop.tangles.count(), 1, "옆으로 2번은 아직")
	_strokes(clump, Vector3(0.01, 0, 0), 1)
	check_eq(shop.tangles.count(), 0, "옆으로 3번이면 풀림")

	# 드라이: 같은 0.5초, 멀리 vs 가까이 / 너무 붙으면 찡그림
	var dried := []
	for distance in [2.0, 0.6]:
		_new_dog(["wet", "scrub", "rinse", "towel"])
		_stand_at(spot, distance)
		shop.pick("dryer")
		_hold(spot, 15)
		dried.append(shop.dog.mask.ratio("dry"))
	check(dried[1] > dried[0] * 2.0, "가까이 대면 훨씬 빨리 마름 (%.3f → %.3f)" % dried)
	_new_dog(["wet", "scrub", "rinse", "towel"])
	_stand_at(spot, 0.25)
	shop.pick("dryer")
	_hold(spot, 10)
	check(shop._hint.contains("너무 가까워요"), "너무 붙으면 찡그림 (%s)" % shop._hint)
	check(shop.dog.mask.ratio("dry") > 0.0, "그래도 마름")


## 새 강아지, 앞 단계들은 채워 둠
func _new_dog(filled: Array) -> void:
	if shop.has_dog:
		shop.done = true
		shop.next_guest()
	shop.guests.spawn("forever")
	shop.next_guest()
	shop.drop()
	for channel in filled:
		shop.dog.mask.fill(channel, 1.0)
	shop.dog.clear_foam()
	shop._check_done()
	spot = shop.dog.model.to_global(shop.dog._body_center() + Vector3(0.0, 0.1, 0.25))
	_stand_at(spot, 1.2)


## 눈이 point 에서 distance 만큼 떨어진 앞쪽에 서게
func _stand_at(point: Vector3, distance: float) -> void:
	var eye := point + Vector3(0, 0, 1).normalized() * distance
	shop.player.global_position = Vector3(eye.x, eye.y - shop.player.EYE_HEIGHT, eye.z)


func _hold(point: Vector3, frames: int) -> void:
	shop._track_hand(null)
	for i in frames:
		shop.use_tool_at(point, STEP)


## point 에서 step 방향으로 9 프레임 쓸고 손을 뗌, times 번
## 뭉치를 하나만 다시 놓고 그 위치 (몸 앞·위쪽, 손이 닿는 곳)
func _one_clump() -> Vector3:
	shop.tangles.spawn(shop.dog.model, shop.dog._body_center(), 1, shop._rng, Color.WHITE)
	return shop.tangles.world_positions()[0]


func _strokes(point: Vector3, step: Vector3, times: int) -> void:
	for t in times:
		shop._track_hand(null)
		for i in 10:
			shop.use_tool_at(point - step * 4.5 + step * i, STEP)
	shop._track_hand(null)
