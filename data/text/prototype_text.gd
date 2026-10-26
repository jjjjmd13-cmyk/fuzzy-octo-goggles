extends Resource
## 시제품 화면 문구 (기획팀이 data/text/prototype_text.tres 만 고친다).
## %s, %d 가 들어 있는 문구는 그 자리에 숫자·이름이 들어가므로 개수와 순서를 그대로 둔다.

@export var intro_title := "등불 원정대 — 시제품"
@export_multiline var intro_body := ""
## 판이 시작될 때 안내를 보여 주는 시간 (초)
@export var intro_seconds := 12.0
@export var need_lantern_hint := ""
## %s = 단계 이름(낮춤/보통/키움), %d = 반경 m
@export var level_notice := ""
@export var stalked_warning := ""
@export var attack_warning := ""
## %d = 다시 시작까지 남은 초
@export var success_message := ""
## %d = 다시 시작까지 남은 초
@export var fail_message := ""
