extends "res://tests/qa_test.gd"
## 시드 난수 유틸이 결정론적인지 확인.

const SeededRng := preload("res://scripts/core/seeded_rng.gd")


func run_test() -> void:
	check_eq(_sequence(12345, "dungeon"), _sequence(12345, "dungeon"), "같은 시드·흐름 → 같은 수열")
	check(_sequence(12345, "dungeon") != _sequence(12345, "loot"), "흐름이 다르면 수열이 다름")
	check(_sequence(12345, "dungeon") != _sequence(12346, "dungeon"), "시드가 다르면 수열이 다름")
	# 고정값: 이 값이 바뀌면 저장된 시드/리플레이가 깨진다. 의도한 변경일 때만 갱신.
	check_eq(SeededRng.derive_seed(12345, "dungeon"), 5331757065167570164, "derive_seed 고정값")


func _sequence(base_seed: int, stream: String) -> Array:
	var rng := SeededRng.make(base_seed, stream)
	var values := []
	for i in 8:
		values.append(rng.randi())
	return values
