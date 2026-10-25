extends "res://tests/qa_test.gd"
# 기대: 호스트가 QA_TEST_READY 를 찍지 않음 → 실행기가 준비 대기 시간 초과로 실패


func run_test() -> void:
	await get_tree().create_timer(60.0).timeout
