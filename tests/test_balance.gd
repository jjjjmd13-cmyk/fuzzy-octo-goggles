extends "res://tests/qa_test.gd"
## 밸런스 리소스가 한 파일에서 읽히고, 모든 수치가 들어 있는지 (GDD 10장 방식 유지).


func run_test() -> void:
	var data: Resource = load("res://data/balance/balance.tres")
	if not check(data != null, "balance.tres 를 읽음"):
		return
	check_eq(Tuning.data.resource_path, data.resource_path, "Tuning 이 같은 파일을 씀")
	var script_defaults: Resource = data.get_script().new()
	for property in data.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var value: Variant = data.get(property.name)
		check(value != null, "%s 값이 있음" % property.name)
		if value is float or value is int:
			check(value > 0, "%s 는 양수 (%s)" % [property.name, value])
	check(script_defaults != null, "기본값으로 만들 수 있음")
	check(data.carry_speed_mult <= 1.0, "들고 있으면 같거나 느려짐")
	check(data.player_run_speed > data.player_walk_speed, "달리기가 걷기보다 빠름")
