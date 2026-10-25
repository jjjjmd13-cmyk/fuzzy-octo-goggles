extends Node
## UI 테마 적용 (autoload: UiTheme). 글꼴·글자 크기는 ui/theme/main_theme.tres 한 곳에서 바꾼다.
##
## 프로젝트 설정(gui/theme/custom) 대신 실행 때 루트 창에 붙인다. 프로젝트 설정으로 두면
## 처음 임포트할 때 글꼴보다 테마를 먼저 읽어 오류가 찍히기 때문이다 (QA CI 가 실패로 봄).

const THEME_PATH := "res://ui/theme/main_theme.tres"


func _ready() -> void:
	get_tree().root.theme = load(THEME_PATH)
