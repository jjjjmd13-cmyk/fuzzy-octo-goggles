extends "res://tests/qa_test.gd"
## 칠하기 마스크 (GDD_V3 9장 "가장 큰 위험"): 방향 → 마스크 칠하기 → 칠한 비율.
## 실제 화면 커서 → 레이캐스트 → 칠하기는 game/test_wash_flow 에서 본다.

const PaintMask := preload("res://scripts/sim/paint_mask.gd")


func run_test() -> void:
	var mask := PaintMask.new(256)
	check_eq(mask.ratio("wet"), 0.0, "처음엔 0")

	# 한 점 칠하기: 붓 넓이 ≈ 구 표면에서 작은 원 (1 - cos r) / 2.
	# 비율은 배 밑(y < UNDERSIDE_Y)을 뺀 넓이로 나눈다.
	var angle := 0.3
	mask.paint("wet", Vector3.FORWARD, angle, 1.0)
	var reachable := (1.0 - PaintMask.UNDERSIDE_Y) / 2.0
	var expected_cap := (1.0 - cos(angle)) / 2.0 / reachable
	var got := mask.ratio("wet")
	check(got > expected_cap * 0.3 and got < expected_cap * 1.2, "붓 한 번 비율 %.4f (원 넓이 비율 %.4f 이하)" % [got, expected_cap])
	check(mask.value_at("wet", Vector3.FORWARD) > 0.9, "칠한 곳 가운데는 꽉 참")
	check_eq(mask.value_at("wet", Vector3.BACK), 0.0, "반대쪽은 그대로")

	# 같은 곳을 또 칠해도 넘치지 않음
	for i in 5:
		mask.paint("wet", Vector3.FORWARD, angle, 1.0)
	check(mask.ratio("wet") < expected_cap * 1.2, "같은 곳은 더 늘지 않음")

	# 극(위·아래)에서도 칠해짐
	mask.paint("scrub", Vector3.UP, 0.4, 1.0)
	check(mask.value_at("scrub", Vector3.UP) > 0.9, "위 극에서도 칠해짐")
	check(mask.ratio("scrub") > 0.0, "극 비율")

	# 온몸을 훑으면 90% 넘음 (비율이 넓이로 가중됨)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var strokes := 0
	while mask.ratio("dry") < 0.9 and strokes < 4000:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if d.length() < 0.01:
			continue
		mask.paint("dry", d, 0.25, 1.0)
		strokes += 1
	check(mask.ratio("dry") >= 0.9, "온몸을 훑으면 90%% 이상 (%d번)" % strokes)
	check(mask.ratio("dry") <= 1.0001, "100%% 를 넘지 않음")

	# 텍스처 반영
	mask.flush()
	var image: Image = mask.get_image()
	var uv: Vector2 = PaintMask.dir_to_uv(Vector3.FORWARD)
	var pixel := image.get_pixel(int(uv.x * 255), int(uv.y * 255))
	check(pixel.r > 0.9, "텍스처 R(젖음) 에 칠한 것이 올라감")

	# 무늬 3종
	for kind in 3:
		var pattern: PackedByteArray = mask.make_mud_pattern(kind, rng)
		var count := 0
		for b in pattern:
			if b > 0:
				count += 1
		check(count > 1000 and count < 256 * 256, "더러움 무늬 %d: 일부만 더러움 (%d)" % [kind, count])

	# 속도: 붓 한 번이 충분히 빠름 (60 프레임에 여러 번)
	var start := Time.get_ticks_usec()
	for i in 100:
		mask.paint("rinse", Vector3(rng.randf_range(-1, 1), 0.2, 1).normalized(), 0.12, 0.3)
	var per_stroke := (Time.get_ticks_usec() - start) / 100.0
	print("붓 한 번 %.0f µs" % per_stroke)
	check(per_stroke < 4000.0, "붓 한 번 4 ms 안 (%.0f µs)" % per_stroke)
