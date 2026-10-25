extends Node
## QA 테스트 씬의 기본 스크립트.
##
## 테스트 씬(tests/**/test_*.tscn)의 루트 노드 스크립트가 이 파일을 상속하고
## run_test() 를 덮어쓴다. run_test() 안에서 await 를 써도 된다.
## 규칙 전체는 docs/qa/TESTING.md 참고.
##
##   extends "res://tests/qa_test.gd"
##
##   func run_test() -> void:
##       check_eq(1 + 1, 2, "덧셈")
##       await get_tree().process_frame

const PASS_MARK := "QA_TEST_PASS"
const FAIL_MARK := "QA_TEST_FAIL"

## 이 시간(초) 안에 끝나지 않으면 실패로 끝낸다.
@export var time_limit_sec := 30.0

var _failures: PackedStringArray = []
var _finished := false


func _ready() -> void:
	get_tree().create_timer(time_limit_sec).timeout.connect(_on_time_limit)
	await run_test()
	finish()


## 테스트 본문. 상속한 스크립트에서 덮어쓴다.
func run_test() -> void:
	pass


func check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		printerr("%s: %s" % [FAIL_MARK, message])
	return condition


func check_eq(actual: Variant, expected: Variant, message: String) -> bool:
	return check(actual == expected, "%s (기대: %s, 실제: %s)" % [message, expected, actual])


func fail(message: String) -> void:
	check(false, message)


## 테스트를 끝낸다. run_test() 가 끝나면 자동으로 불린다.
func finish() -> void:
	if _finished:
		return
	_finished = true
	if _failures.is_empty():
		print(PASS_MARK)
		get_tree().quit(0)
	else:
		print("%s: 실패 %d개" % [FAIL_MARK, _failures.size()])
		get_tree().quit(1)


func _on_time_limit() -> void:
	if not _finished:
		fail("시간 초과 (%s초)" % time_limit_sec)
		finish()
