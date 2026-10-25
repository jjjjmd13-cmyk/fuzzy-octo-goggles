extends "res://tests/qa_test.gd"
# 기대: check 실패 → 종료 코드 1


func run_test() -> void:
	check_eq(1 + 1, 3, "일부러 틀린 덧셈")
