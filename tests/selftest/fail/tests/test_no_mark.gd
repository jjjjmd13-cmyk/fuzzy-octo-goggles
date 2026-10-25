extends Node
# 기대: 종료 코드 0 이지만 성공 문자열이 없음 → 실패


func _ready() -> void:
	get_tree().quit(0)
