extends "res://tests/qa_test.gd"
## 도구 소리 (대표 요청 2026-11-11 ⑦, 사람 대표 의견 "삑삑 기계음 같고, 너무 시끄럽고, 다 비슷하다"):
## ① 삑 소리가 아님 (한 높이로 울리는 음이 아니라 잡음을 거른 소리 — 자기상관 최대값이 낮음)
## ② 음량 기준: 도구 소리 꼭대기 ≤ TOOL_PEAK_DB dBFS, 안내음 (딩·딸랑·짤랑) 꼭대기보다 BELOW_CUES dB 이상 작게,
##    이어지는 소리 평균 (RMS) 은 배경음악보다 BELOW_MUSIC dB 이상 작게
## ③ 시작·끝이 부드러움 (한 번 소리는 0 에서 시작·끝, 이어지는 소리는 이음매 없음 + 켜고 끌 때 서서히)
## ④ 도구마다 확실히 다름 (높낮이 (영점 교차) · 출렁임 (크기 변화) 특징이 서로 떨어져 있음)
## ⑤ 도구 단계마다 살짝 다른 높이

const Sfx := preload("res://scripts/game/sfx.gd")
const FpShop := preload("res://scripts/v4/fp_shop.gd")
const TOOL_PEAK_DB := -12.0
const BELOW_CUES := 6.0
const BELOW_MUSIC := 6.0
const LOOPS := ["shower", "foam", "dryer", "brush"]
const SHOTS := ["towel", "press", "snip", "squirt", "pour", "bubble_pop"]
## 서로 확실히 달라야 하는 여섯 (물 쏴아 / 거품 뽀글 / 수건 / 드라이기 웅 / 빗 슥슥 / 가위 싹둑)
const DISTINCT := ["shower", "foam", "towel", "dryer", "brush", "snip"]
const CUES := ["ding", "bell", "coin"]
## 도구 소리 표본 빠르기 (tools/make_tool_sfx.py)
const RATE := 44100


func run_test() -> void:
	time_limit_sec = 60.0
	var cue_peak := INF
	for cue in CUES:
		cue_peak = minf(cue_peak, _peak_db(_samples(cue)))
	var music := _samples("", "res://assets/music/bgm_shop.wav")
	var music_rms := _rms_db(music)
	var features := {}
	for name in LOOPS + SHOTS:
		var data := _samples(name)
		check(data.size() > 100, "%s 소리 파일" % name)
		var peak := _peak_db(data)
		check(peak <= TOOL_PEAK_DB, "%s 꼭대기 %.1f dBFS ≤ %.0f" % [name, peak, TOOL_PEAK_DB])
		check(peak <= cue_peak - BELOW_CUES, "%s 는 안내음보다 %.0f dB 이상 작게 (%.1f / 안내음 %.1f)" % [name, BELOW_CUES, peak, cue_peak])
		if name != "bubble_pop":
			# 거품 한 방울 '뽁' 은 아주 짧은 미끄럼 음이라 빼고 모두
			var tonal := _tonality(data)
			check(tonal < 0.6, "%s 는 삑 소리가 아님 (한 높이로 울림 %.2f < 0.6)" % [name, tonal])
		if name in LOOPS:
			var rms := _rms_db(data)
			check(rms <= music_rms - BELOW_MUSIC, "%s 이어지는 소리 평균 %.1f dB 는 배경음악 (%.1f) 보다 작게" % [name, rms, music_rms])
			check(absf(data[0] - data[data.size() - 1]) < 0.05, "%s 이음매 없음 (처음·끝 %.3f / %.3f)" % [name, data[0], data[data.size() - 1]])
		else:
			check(absf(data[0]) < 0.01 and absf(data[data.size() - 1]) < 0.01, "%s 는 0 에서 시작해 0 으로 끝남 (부드럽게)" % name)
		features[name] = _features(data)
	# 도구마다 다름: 두 특징 (영점 교차 = 높낮이, 크기 변화 = 출렁임) 중 하나라도 확실히 떨어져 있음
	for i in DISTINCT.size():
		for k in range(i + 1, DISTINCT.size()):
			var a: Vector2 = features[DISTINCT[i]]
			var b: Vector2 = features[DISTINCT[k]]
			var apart := absf(log(a.x / b.x)) > 0.12 or absf(a.y - b.y) > 0.25
			check(apart, "%s 와 %s 는 다르게 들림 (높낮이 %.0f / %.0f, 출렁임 %.2f / %.2f)" % [DISTINCT[i], DISTINCT[k], a.x, b.x, a.y, b.y])

	# 켜고 끌 때 서서히 (헤드리스는 소리 없이 크기만 계산)
	var sfx := Sfx.new()
	add_child(sfx)
	await get_tree().process_frame
	sfx.set_loop("shower", 0.8)
	sfx._process(0.03)
	check(sfx.loop_level("shower") > 0.0 and sfx.loop_level("shower") < 0.5, "켤 때 서서히 커짐 (%.2f)" % sfx.loop_level("shower"))
	for i in 10:
		sfx._process(0.03)
	check(is_equal_approx(sfx.loop_level("shower"), 0.8), "다 켜지면 0.8 (%.2f)" % sfx.loop_level("shower"))
	sfx.set_loop("shower", 0.0)
	sfx._process(0.05)
	check(sfx.loop_level("shower") > 0.5, "끌 때 서서히 작아짐 (%.2f)" % sfx.loop_level("shower"))
	for i in 20:
		sfx._process(0.03)
	check(is_zero_approx(sfx.loop_level("shower")), "다 작아지면 0")
	sfx.free()

	# 도구 단계마다 살짝 다른 높이 (5단계)
	for tool_id in ["shower", "shampoo", "dryer", "brush"]:
		var low: float = FpShop.tool_pitch(tool_id, 0)
		var high: float = FpShop.tool_pitch(tool_id, 4)
		check(is_equal_approx(low, 1.0) and absf(high - 1.0) > 0.08 and absf(high - 1.0) < 0.25, "%s 단계마다 살짝 다른 높이 (1단계 %.2f → 5단계 %.2f)" % [tool_id, low, high])


## 소리 파일 (원본 WAV, 가져오기 압축 전) → -1 ~ 1 표본 (16비트, 스테레오면 왼쪽)
func _samples(name: String, path := "") -> PackedFloat32Array:
	var bytes := FileAccess.get_file_as_bytes(path if not path.is_empty() else "res://assets/sfx/%s.wav" % name)
	var out := PackedFloat32Array()
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return out
	var channels := 1
	var bits := 16
	var at := 12
	while at + 8 <= bytes.size():
		var id := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		if id == "fmt ":
			channels = bytes.decode_u16(at + 10)
			bits = bytes.decode_u16(at + 22)
		elif id == "data":
			if bits != 16:
				return out
			var step := 2 * channels
			var count := mini(size, bytes.size() - at - 8) / step
			out.resize(count)
			for i in count:
				out[i] = bytes.decode_s16(at + 8 + i * step) / 32768.0
			return out
		at += 8 + size + (size % 2)
	return out


func _peak_db(data: PackedFloat32Array) -> float:
	var peak := 0.0
	for v in data:
		peak = maxf(peak, absf(v))
	return linear_to_db(maxf(peak, 1e-6))


func _rms_db(data: PackedFloat32Array) -> float:
	var total := 0.0
	for v in data:
		total += v * v
	return linear_to_db(sqrt(total / maxf(data.size(), 1)))


## 한 높이로 울리는 정도: 가운데 4096 표본의 자기상관 최대값 (지연 20~400, 순수 음 ≈ 1, 잡음 ≈ 0)
func _tonality(data: PackedFloat32Array) -> float:
	var n := mini(4096, data.size() - 400)
	var start := maxi((data.size() - n - 400) / 2, 0)
	var best := 0.0
	for lag in range(20, 400, 2):
		var dot := 0.0
		var e1 := 0.0
		var e2 := 0.0
		for i in range(start, start + n):
			var x: float = data[i]
			var y: float = data[i + lag]
			dot += x * y
			e1 += x * x
			e2 += y * y
		best = maxf(best, dot / sqrt(maxf(e1 * e2, 1e-12)))
	return best


## 특징: (영점 교차 수 / 초, 20 ms 크기의 변화 정도 = 표준편차 / 평균)
func _features(data: PackedFloat32Array) -> Vector2:
	var crossings := 0
	for i in range(1, data.size()):
		if (data[i - 1] < 0.0) != (data[i] < 0.0):
			crossings += 1
	var seconds := data.size() / float(RATE)
	var frame := 882
	var levels: Array[float] = []
	for start in range(0, data.size() - frame, frame):
		var total := 0.0
		for i in range(start, start + frame):
			total += data[i] * data[i]
		levels.append(sqrt(total / frame))
	var mean := 0.0
	for v in levels:
		mean += v
	mean /= maxf(levels.size(), 1)
	var spread := 0.0
	for v in levels:
		spread += (v - mean) * (v - mean)
	spread = sqrt(spread / maxf(levels.size(), 1))
	return Vector2(crossings / seconds, spread / maxf(mean, 1e-6))
