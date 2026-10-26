extends CanvasLayer
## 가게 화면 표시. 값은 동기화된 상태를 읽기만 한다 (판정은 호스트).

const INTRO_TEXT := "더러운 손님을 씻기고(목욕) 말려서(말리기) 출구로! 젖은 손님은 도망가요."
const HELP_TEXT := """[조작]
WASD 이동 · Shift 대시
Space 들기 / 내려놓기 / 기계에 넣기 / 꺼내기 / 보내기
Esc 메뉴 · F1 이 도움말"""
const ACTION_TEXT := {
	"pickup": "Space: %s 들기",
	"drop": "Space: 내려놓기",
	"load": "Space: %s에 넣기",
	"unload": "Space: %s에서 꺼내기",
	"deliver": "Space: 손님 보내기",
}

@onready var world: Node = get_parent()
@onready var status_label: Label = $Status
@onready var invite_button: Button = $InviteButton
@onready var clock_label: Label = $TopPanel/Top/Clock
@onready var score_label: Label = $TopPanel/Top/Score
@onready var intro_panel: Control = $IntroPanel
@onready var intro_label: Label = $IntroPanel/Intro
@onready var hint_label: Label = $Bottom/Hint
@onready var prompt_label: Label = $Bottom/Prompt
@onready var help_label: Label = $Help
@onready var results: Control = $Results
@onready var results_label: Label = $Results/Box/Text
@onready var stars_label: Label = $Results/Box/Stars
@onready var pause_menu: Control = $PauseMenu



func _ready() -> void:
	$PauseMenu/Box/Resume.pressed.connect(_set_paused.bind(false))
	$PauseMenu/Box/Leave.pressed.connect(Net.leave_session)
	invite_button.pressed.connect(Net.invite_friends)
	pause_menu.hide()
	results.hide()
	help_label.text = HELP_TEXT
	help_label.hide()
	intro_label.text = INTRO_TEXT


func is_paused() -> bool:
	return pause_menu.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		_set_paused(not pause_menu.visible)
	elif event.is_action_pressed("toggle_help"):
		help_label.visible = not help_label.visible
	elif results.visible and not is_paused() and event.is_pressed() and not event.is_echo() \
			and (event is InputEventKey or event is InputEventJoypadButton):
		# 결과 화면: 아무 키로 다시 시작
		world.shop.send_restart()
		get_viewport().set_input_as_handled()


func _set_paused(paused: bool) -> void:
	# 온라인 게임이라 시간은 멈추지 않는다. 메뉴만 띄운다.
	pause_menu.visible = paused


func _process(_delta: float) -> void:
	var shop: Node = world.shop
	status_label.text = "%s · 플레이어 %d / %d · F1 조작" % [Net.status_text, world.get_players().size(), Net.MAX_PLAYERS]
	invite_button.visible = Net.can_invite_friends()

	# 시작 안내는 누군가 손님을 처음 들 때까지 (시간으로 끄지 않음)
	intro_panel.visible = shop.is_open() and not shop.first_pickup_done

	var seconds := ceili(shop.time_left)
	clock_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	score_label.text = "보낸 손님 %d · 화나서 나감 %d" % [shop.delivered, shop.angry]

	results.visible = shop.phase == shop.Phase.RESULTS
	if results.visible:
		results_label.text = "영업 끝!\n\n보낸 손님  %d\n화나서 나간 손님  %d" % [shop.delivered, shop.angry]
		stars_label.text = "★".repeat(shop.stars) + "☆".repeat(3 - shop.stars)

	var me: Node = world.get_local_player()
	var playing: bool = me != null and shop.is_open()
	prompt_label.text = _prompt(me) if playing else ""
	hint_label.text = shop.next_step_hint(me) if playing else ""
	prompt_label.visible = not prompt_label.text.is_empty()
	hint_label.visible = not hint_label.text.is_empty()


func _prompt(me: Node) -> String:
	var action: Dictionary = world.shop.use_action(me)
	var kind: String = action.get("kind", "")
	if kind.is_empty():
		return ""
	var text: String = ACTION_TEXT[kind]
	return text % action.target.display_name if text.contains("%s") else text
