extends "res://tests/qa_test.gd"
# 기대: run_test() 첫 줄에서 바꾼 시간 제한(2초)이 적용되어 실패


func run_test() -> void:
	time_limit_sec = 2.0
	await get_tree().create_timer(5.0).timeout
