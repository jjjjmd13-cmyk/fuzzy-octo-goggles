extends CanvasLayer
## 가게 화면 표시. 값은 동기화된 상태를 읽기만 한다 (판정은 호스트).

const HELP_TEXT := """[조작]
WASD 이동 · Shift 달리기
E 들기 / 내려놓기 · R 건네기 (가까운 빈손 동료에게)
Esc 메뉴 · F1 이 도움말"""

@onready var world: Node = get_parent()
@onready var status_label: Label = $Status
@onready var invite_button: Button = $InviteButton
@onready var prompt_label: Label = $Bottom/Prompt
@onready var stamina_bar: ProgressBar = $Bottom/StaminaBar
@onready var help_label: Label = $Help
@onready var pause_menu: Control = $PauseMenu


func _ready() -> void:
	$PauseMenu/Box/Resume.pressed.connect(_set_paused.bind(false))
	$PauseMenu/Box/Leave.pressed.connect(Net.leave_session)
	invite_button.pressed.connect(Net.invite_friends)
	pause_menu.hide()
	help_label.text = HELP_TEXT


func is_paused() -> bool:
	return pause_menu.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		_set_paused(not pause_menu.visible)
	elif event.is_action_pressed("toggle_help"):
		help_label.visible = not help_label.visible


func _set_paused(paused: bool) -> void:
	# 온라인 게임이라 시간은 멈추지 않는다. 메뉴만 띄운다.
	pause_menu.visible = paused


func _process(_delta: float) -> void:
	status_label.text = "%s · 플레이어 %d / %d · F1 조작" % [Net.status_text, world.get_players().size(), Net.MAX_PLAYERS]
	invite_button.visible = Net.can_invite_friends()
	var me: Node = world.get_local_player()
	if me == null:
		return
	var data: Resource = Tuning.data
	stamina_bar.max_value = data.player_stamina
	stamina_bar.value = me.stamina
	stamina_bar.visible = me.stamina < data.player_stamina - 0.01
	prompt_label.text = _prompt(me)


func _prompt(me: Node) -> String:
	var rules: Node = world.carry_rules
	var held: Node = rules.held_by(me.get_peer_id())
	if held != null:
		var text := "E: %s 내려놓기" % held.display_name
		if rules.give_target(me) != null:
			text += " · R: 건네기"
		return text
	var item: Node = rules.pickup_candidate(me)
	return "E: %s 들기" % item.display_name if item != null else ""
