extends CanvasLayer
## 가게 화면 표시 (V3 시제품 1). 값은 동기화된 상태를 읽기만 한다 (판정은 호스트).
## 진행은 숫자·막대 대신 요청 카드의 ✓ 와 강아지 몸(남은 곳 반짝임)으로만 보여 준다 (완료 조건 8).
## 커서 모양·기분 얼굴·온도 다이얼·몸 털기 거품은 Overlay(hud_overlay.gd)가 그린다.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const HELP_TEXT := """[조작]
왼쪽 버튼(패드 RT) 도구 쓰기 · 오른쪽 드래그(오른쪽 스틱, A/D) 돌리기
1~4 / 휠(패드 ◀▶) 도구 · Q/E(패드 ▲▼) 물 온도
Shift(패드 B) 드라이어 가까이 · Tab(패드 LB) 자리 바꾸기
Esc 메뉴 · F1 이 도움말"""

@onready var world: Node = get_parent()
@onready var status_label: Label = $Status
@onready var invite_button: Button = $InviteButton
@onready var seat_button: Button = $SeatButton
@onready var card_title: Label = $Card/Box/Title
@onready var card_request: Label = $Card/Box/Request
@onready var card_steps: VBoxContainer = $Card/Box/Steps
@onready var money_label: Label = $Money
@onready var tool_bar: HBoxContainer = $ToolBar
@onready var hint_label: Label = $Hint
@onready var shop_panel: Control = $Shop
@onready var shop_info: Label = $Shop/Box/Info
@onready var buy_basic: Button = $Shop/Box/BuyBasic
@onready var buy_peach: Button = $Shop/Box/BuyPeach
@onready var use_basic: Button = $Shop/Box/Use/UseBasic
@onready var use_peach: Button = $Shop/Box/Use/UsePeach
@onready var overlay: Control = $Overlay
@onready var help_label: Label = $Help
@onready var pause_menu: Control = $PauseMenu

var _tool_buttons: Array[Button] = []
var _step_labels: Array[Label] = []


func _ready() -> void:
	$PauseMenu/Box/Resume.pressed.connect(_set_paused.bind(false))
	$PauseMenu/Box/Leave.pressed.connect(Net.leave_session)
	invite_button.pressed.connect(Net.invite_friends)
	seat_button.pressed.connect(func() -> void: world.switch_seat())
	buy_basic.pressed.connect(func() -> void: world.store.send_buy("basic"))
	buy_peach.pressed.connect(func() -> void: world.store.send_buy("peach"))
	use_basic.pressed.connect(func() -> void: world.store.send_select("basic"))
	use_peach.pressed.connect(func() -> void: world.store.send_select("peach"))
	pause_menu.hide()
	help_label.text = HELP_TEXT
	help_label.hide()
	for i in WashStation.TOOL_NAMES.size():
		var button := Button.new()
		button.text = "%d %s" % [i + 1, WashStation.TOOL_NAMES[i]]
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(124, 60)
		button.pressed.connect(func() -> void: world.select_tool(i))
		tool_bar.add_child(button)
		_tool_buttons.append(button)
	for i in WashStation.STAGE_NAMES.size():
		var label := Label.new()
		label.theme_type_variation = &"PromptLabel"
		card_steps.add_child(label)
		_step_labels.append(label)
	world.get_node("WashStation").screen_foam.connect(overlay.show_foam)


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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused or world.local_seat() != 0 else Input.MOUSE_MODE_HIDDEN


func _process(_delta: float) -> void:
	var station: WashStation = world.station
	var store: Node = world.store
	var at_bath: bool = world.local_seat() == 0
	status_label.text = "%s · 플레이어 %d / %d · F1 조작" % [Net.status_text, world.get_players().size(), Net.MAX_PLAYERS]
	invite_button.visible = Net.can_invite_friends()
	seat_button.text = "Tab: 컴퓨터 자리 →" if at_bath else "Tab: ← 목욕대"
	money_label.text = "돈 %d" % store.money

	card_title.text = "%d번째 손님" % maxi(station.dog_number(), 1)
	card_request.visible = station.wants_peach()
	for i in _step_labels.size():
		var done: bool = i < station.stage
		var current: bool = i == station.stage
		_step_labels[i].text = "%s %s" % ["✓" if done else ("▶" if current else "·"), WashStation.STAGE_NAMES[i]]
		_step_labels[i].modulate = Color(0.55, 1, 0.6) if done else (Color(1, 1, 1) if current else Color(0.7, 0.7, 0.7))

	tool_bar.visible = at_bath
	for i in _tool_buttons.size():
		_tool_buttons[i].button_pressed = i == station.tool
	var hint: String = station.next_hint() if at_bath else ""
	if at_bath and not station.is_operator() and station.stage < WashStation.Stage.PAY:
		hint = "다른 사람이 씻기는 중이에요 (구경 중)"
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()

	shop_panel.visible = not at_bath
	if shop_panel.visible:
		shop_info.text = "돈 %d · 기본 샴푸 %d마리분 · 복숭아 샴푸 %d마리분" % [store.money, store.basic_uses, store.peach_uses]
		buy_basic.text = "기본 샴푸 한 병 (%d마리) — %d" % [Tuning.data.tool_shampoo_uses_per_bottle, store.price("basic")]
		buy_peach.text = "복숭아 샴푸 한 병 (분홍 거품, 향 팁) — %d" % store.price("peach")
		buy_basic.disabled = not store.can_buy("basic")
		buy_peach.disabled = not store.can_buy("peach")
		use_basic.button_pressed = store.shampoo == "basic"
		use_peach.button_pressed = store.shampoo == "peach"
		use_peach.disabled = store.peach_uses <= 0 and store.shampoo != "peach"
