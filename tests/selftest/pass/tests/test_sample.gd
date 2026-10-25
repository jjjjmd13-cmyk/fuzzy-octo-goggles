extends "res://tests/qa_test.gd"


func run_test() -> void:
	check_eq(1 + 1, 2, "덧셈")
	await get_tree().process_frame
	check(get_tree() != null, "트리 있음")
