extends CanvasLayer
## 가게 화면 표시 (V3 시제품 1). 값은 동기화된 상태를 읽기만 한다 (판정은 호스트).
## 진행은 숫자·막대 대신 요청 카드의 ✓ 와 강아지 몸(남은 곳 반짝임)으로만 보여 준다 (완료 조건 8).
## 커서 모양·기분 얼굴·온도 다이얼·몸 털기 거품은 Overlay(hud_overlay.gd)가 그린다.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const UiArt := preload("res://scripts/game/ui_art.gd")
const TOOL_ART := ["tool_shower", "tool_bottle", "tool_hand", "tool_bucket", "tool_towel", "tool_dryer"]
const HELP_TEXT := """[조작 — 마우스 하나로]
왼쪽 버튼(패드 RT) 도구 쓰기 — 단계마다 쓰는 법이 달라요
휠(패드 오른쪽 스틱 ▲▼) 물 온도 · 드라이어 거리
도구는 저절로 바뀌어요 (오른쪽 아래 도구걸이로 직접 바꿀 수도)
강아지는 저절로 돌아요 (회전판 양쪽 화살표로 바로 돌리기)
Tab(패드 LB·RB) 자리 바꾸기 · Esc 메뉴 · F1 이 도움말"""

@onready var world: Node = get_parent()
@onready var status_label: Label = $Status
@onready var invite_button: Button = $InviteButton
@onready var seat_button: Button = $SeatButton
@onready var card_title: Label = $Card/Box/Title
@onready var card_request: Label = $Card/Box/Request
## 성격 한 줄 (요청 카드). 성격 그림은 Overlay 가 카드 오른쪽 위 구석에 그림
var card_trait: Label
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
var _step_checks: Array[TextureRect] = []
var _seen_phase := -1
var _card_home := Vector2.ZERO
## 영업 끝 알림 (정산 화면이 생기기 전까지)
var _closed_panel: PanelContainer
var _closed_label: Label


func _ready() -> void:
	# CanvasLayer의 자식 Control은 Window 테마를 자동 상속하지 않으므로 명시한다.
	for child in get_children():
		if child is Control:
			child.theme = get_tree().root.theme
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
		button.text = WashStation.TOOL_NAMES[i]
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(96, 60)
		# 도구 아이콘 그림이 있으면 (assets/ui/tool_*.png) 글자 위에 붙인다
		var icon := UiArt.texture(TOOL_ART[i])
		if icon != null:
			button.icon = icon
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.custom_minimum_size = Vector2(96, 96)
		button.pressed.connect(func() -> void: world.select_tool(i))
		tool_bar.add_child(button)
		_tool_buttons.append(button)
	# 요청 카드 한 줄 = [단계 도구 그림] 단계 이름 [✓ 도장]. 그림이 없으면 글자 기호(▶ · ✓)
	var check_picture := UiArt.texture("check")
	var any_tool_art := TOOL_ART.any(func(art: String) -> bool: return UiArt.texture(art) != null)
	for i in WashStation.STAGE_NAMES.size():
		var row := HBoxContainer.new()
		card_steps.add_child(row)
		# 도구 그림 칸 (그림이 없는 도구는 빈칸으로 줄을 맞춤)
		if any_tool_art:
			var icon := TextureRect.new()
			icon.texture = UiArt.texture(TOOL_ART[WashStation.STAGE_TOOL[i]])
			icon.custom_minimum_size = Vector2(30, 30)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
		var label := Label.new()
		label.theme_type_variation = &"PromptLabel"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		_step_labels.append(label)
		var check := TextureRect.new()
		check.texture = check_picture
		check.custom_minimum_size = Vector2(30, 30) if check_picture != null else Vector2.ZERO
		check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(check)
		_step_checks.append(check)
	# 동전 그림 (assets/ui/coin.png) 을 돈 글자 왼쪽에
	var coin_picture := UiArt.texture("coin")
	if coin_picture != null:
		var coin := TextureRect.new()
		coin.texture = coin_picture
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.position = Vector2(14, 6)
		coin.size = Vector2(36, 36)
		money_label.add_child(coin)
	# 세로 요청 카드 바탕 그림 (assets/ui/card_vertical.png)
	var card_picture := UiArt.texture("card_vertical")
	if card_picture != null:
		var style := StyleBoxTexture.new()
		style.texture = card_picture
		style.content_margin_left = 24
		style.content_margin_top = 12
		style.content_margin_right = 24
		style.content_margin_bottom = 20
		$Card.add_theme_stylebox_override("panel", style)
		card_title.add_theme_font_size_override("font_size", 22)
		for label: Label in [card_title, card_request] + _step_labels:
			label.add_theme_color_override("font_color", Color("253b40"))
			label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	world.get_node("WashStation").screen_foam.connect(overlay.show_foam)
	_card_home = $Card.position
	# 성격 한 줄은 카드 바로 아래에 (세로 카드 그림의 6칸 줄을 밀지 않게)
	card_trait = Label.new()
	card_trait.name = "Trait"
	card_trait.theme = get_tree().root.theme
	card_trait.theme_type_variation = &"PromptLabel"
	card_trait.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	card_trait.add_theme_color_override("font_outline_color", Color(0.1, 0.15, 0.25))
	card_trait.add_theme_constant_override("outline_size", 8)
	add_child(card_trait)
	move_child(card_trait, overlay.get_index())
	# 대기 손님 참을성 원: HUD 맨 밑 층 (요청 카드·도구걸이가 그 위)
	var patience_layer := Control.new()
	patience_layer.name = "PatienceLayer"
	patience_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patience_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(patience_layer)
	move_child(patience_layer, 0)
	overlay.patience_layer = patience_layer
	patience_layer.draw.connect(overlay.draw_patience)
	_closed_panel = PanelContainer.new()
	_closed_panel.theme = get_tree().root.theme
	_closed_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_closed_label = Label.new()
	_closed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_closed_panel.add_child(_closed_label)
	add_child(_closed_panel)
	move_child(_closed_panel, overlay.get_index())
	_closed_panel.hide()


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
	# 동전 그림이 있으면 그림 + 숫자, 없으면 "돈 N"
	money_label.text = ("      %d" if money_label.get_child_count() > 0 else "돈 %d") % store.money

	var day: Node = world.day
	# 요청 카드: 주인이 맡기는 순간 말풍선에서 날아와 걸림 (접수). 손님이 없거나 들어오는 중엔 안 보임
	var phase: int = station.owner_phase
	$Card.visible = phase != WashStation.OwnerPhase.EMPTY and phase != WashStation.OwnerPhase.ARRIVE
	if phase != _seen_phase:
		if phase == WashStation.OwnerPhase.WAIT and _seen_phase == WashStation.OwnerPhase.ARRIVE:
			_fly_card_in(station)
		_seen_phase = phase
	card_title.text = "%d번째 손님" % maxi(day.guest_number_today(station.dog_number()), 1)
	card_request.visible = station.wants_peach()
	if station.is_cat():
		card_title.text += " · 고양이"
	var trait_index: int = station.personality()
	card_trait.visible = trait_index != WashStation.Personality.NONE and $Card.visible
	card_trait.position = Vector2($Card.position.x + 8.0, $Card.position.y + $Card.size.y * $Card.scale.y + 4.0)
	card_trait.text = "%s — %s" % [WashStation.PERSONALITY_NAMES[trait_index], WashStation.PERSONALITY_TIPS[trait_index]]
	for i in _step_labels.size():
		var done: bool = i < station.stage
		var current: bool = i == station.stage
		var has_check_picture: bool = _step_checks[i].texture != null
		_step_labels[i].text = "%s %s" % [("" if has_check_picture else "✓") if done else ("▶" if current else "·"), WashStation.STAGE_NAMES[i]]
		_step_checks[i].visible = done and has_check_picture
		if UiArt.texture("card_vertical") != null:
			_step_labels[i].modulate = Color.WHITE
			_step_labels[i].add_theme_color_override("font_color", Color("227451") if done else (Color("213b43") if current else Color("65777a")))
		else:
			_step_labels[i].modulate = Color(0.55, 1, 0.6) if done else (Color(1, 1, 1) if current else Color(0.7, 0.7, 0.7))

	tool_bar.visible = at_bath and station.is_washing()
	for i in _tool_buttons.size():
		_tool_buttons[i].button_pressed = i == station.tool
	var hint: String = station.next_hint() if at_bath else ""
	if at_bath and phase == WashStation.OwnerPhase.EMPTY and day.closing:
		hint = "오늘 손님을 다 받았어요! 가게 문을 닫아요"
	elif at_bath and phase == WashStation.OwnerPhase.EMPTY and not day.is_open():
		hint = "6시! 오늘 영업이 끝나 가요"
	if at_bath and not station.is_operator() and station.stage < WashStation.Stage.PAY:
		hint = "다른 사람이 씻기는 중이에요 (구경 중)"
	var warning: bool = at_bath and station.eye_warning_left > 0.0 and station.overflow_left <= 0.0
	if warning:
		hint = "앗, 눈에 물이 들어갔어요! 얼굴(눈)은 피해서 씻어 주세요"
	hint_label.add_theme_color_override("font_color", Color(1, 0.5, 0.45) if warning else Color(1, 0.92, 0.55))
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()

	_closed_panel.visible = day.closed
	if day.closed:
		_closed_label.text = "%d일차 영업 끝!\n씻긴 손님 %d명 · 기다리다 떠난 손님 %d명\n번 돈 %d" % [day.day, day.served, day.walked_out, day.earned]
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


## 접수: 요청 카드가 주인 말풍선 자리에서 작게 시작해 왼쪽 위 자리로 날아가 걸린다
func _fly_card_in(station: WashStation) -> void:
	var card: Control = $Card
	var camera: Camera3D = world.camera
	var point: Vector3 = station.owner_bubble_point()
	if camera.is_position_behind(point):
		return
	card.position = camera.unproject_position(point)
	card.scale = Vector2.ONE * 0.3
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", _card_home, 0.45)
	tween.tween_property(card, "scale", Vector2.ONE, 0.45)
