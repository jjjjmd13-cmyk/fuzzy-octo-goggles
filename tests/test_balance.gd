extends "res://tests/qa_test.gd"
## 수치 리소스가 TUNING_V3.md 시제품(✅) 값과 같은지 (V3 시제품 1 완료 조건 12).
## 표를 직접 읽어서 비교하므로, 기획팀이 표를 바꾸면 리소스도 같이 바꿔야 통과한다.

const TUNING_DOC := "res://docs/design/TUNING_V3.md"
const BALANCE := "res://data/balance/sim_balance.tres"


func run_test() -> void:
	var data: Resource = load(BALANCE)
	if not check(data != null, "sim_balance.tres 를 읽음"):
		return
	check_eq(Tuning.data.resource_path, data.resource_path, "Tuning 이 같은 파일을 씀")
	var rows := _prototype_rows()
	check(rows.size() >= 40, "TUNING_V3 ✅ 줄을 읽음 (%d개)" % rows.size())
	for key in rows:
		if not check(key in data, "리소스에 %s 가 있음" % key):
			continue
		var expected: Variant = rows[key]
		var actual: Variant = data.get(key)
		if expected is Array:
			check(_same_array(actual, expected), "%s (기대: %s, 실제: %s)" % [key, expected, actual])
		else:
			check(is_equal_approx(float(actual), expected), "%s (기대: %s, 실제: %s)" % [key, expected, actual])
	# 기분 얼굴 경계 (😊 ≥ 0.66 > 😐 ≥ 0.33 > 😣)
	check_eq(data.mood_face(0.7), 2, "기분 0.7 = 😊")
	check_eq(data.mood_face(0.5), 1, "기분 0.5 = 😐")
	check_eq(data.mood_face(0.2), 0, "기분 0.2 = 😣")


## 표에서 4번째 칸이 ✅ 인 줄: 키 → 값 (숫자 또는 숫자 배열)
func _prototype_rows() -> Dictionary:
	var rows := {}
	var text := FileAccess.get_file_as_string(TUNING_DOC)
	for line in text.split("\n"):
		var cells := line.split("|")
		if cells.size() < 6 or cells[4].strip_edges() != "✅":
			continue
		var key := cells[1].strip_edges().trim_prefix("`").trim_suffix("`")
		var value := cells[2].strip_edges().replace("−", "-").replace("+", "")
		if value.begins_with("["):
			var items := []
			for item in value.trim_prefix("[").trim_suffix("]").split(","):
				items.append(item.strip_edges().to_float())
			rows[key] = items
		else:
			rows[key] = value.to_float()
	return rows


func _same_array(actual: Variant, expected: Array) -> bool:
	if not (actual is PackedFloat32Array or actual is PackedInt32Array or actual is Array):
		return false
	if actual.size() != expected.size():
		return false
	for i in expected.size():
		if not is_equal_approx(float(actual[i]), expected[i]):
			return false
	return true
