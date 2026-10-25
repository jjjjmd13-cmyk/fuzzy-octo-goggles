extends "res://tests/qa_test.gd"
# 기대: 실행 중 스크립트 오류 → 성공 문자열이 나와도 실패


func run_test() -> void:
	var n: Node = null
	n.queue_free()
