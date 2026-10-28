extends CanvasLayer
## 가게 화면 표시 (V3 시제품 1). 값은 동기화된 상태를 읽기만 한다 (판정은 호스트).
## 진행은 숫자·막대 대신 요청 카드의 ✓ 와 강아지 몸(남은 곳 반짝임)으로만 보여 준다 (완료 조건 8).
## 커서 모양·기분 얼굴·온도 다이얼·몸 털기 거품은 Overlay(hud_overlay.gd)가 그린다.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const UiArt := preload("res://scripts/game/ui_art.gd")
const Store := preload("res://scripts/sim/store.gd")
const Settings := preload("res://scripts/core/settings.gd")
const GuideOverlay := preload("res://scripts/game/guide_overlay.gd")
const TOOL_ART := ["tool_shower", "tool_bottle", "tool_hand", "tool_bucket", "tool_towel", "tool_dryer"]

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
@onready var pause_menu: Control = $PauseMenu

var _tool_buttons: Array[Button] = []
var _step_labels: Array[Label] = []
var _step_checks: Array[TextureRect] = []
var _seen_phase := -1
var _card_home := Vector2.ZERO
## 정산 화면 (영업이 끝나면, 목욕대 자리) / 아침 화면 (다음 날 영업 전)
var settle_panel: PanelContainer
var settle_stats: Label
var settle_face: TextureRect
var settle_best: Label
## 남은 샴푸 N마리분 / 내일 손님 M명 (모자라면 빨강)
var settle_supply: Label
var settle_shop_button: Button
var next_day_button: Button
var settle_end_label: Label
## 3일차 정산 뒤 끝 화면 (3일 합계 + 다음에 열리는 것 잠긴 칸 → 메뉴로)
var end_button: Button
var end_panel: PanelContainer
var end_totals: Label
var end_menu_button: Button
var _show_end := false
var morning_panel: PanelContainer
var morning_title: Label
var morning_news: Label
var open_button: Button
## 컴퓨터 쇼핑 4칸 (산 업그레이드·꾸미기)
var buy_wide_shower: Button
var buy_plant: Button
## 컴퓨터 자리에서 영업이 끝났을 때 "다음 날"
var shop_next_day: Button
var _shop_effects := {}
var _menu_was_open := false
## 처음 하는 사람용 안내 (손동작 그림, 쇼핑 화살표, F1 조작 그림)
var guide: Control
## 음량 (Esc 메뉴): 효과음 / 음악
## Esc 메뉴: 영업 중에 나가면 오늘 것은 저장되지 않음 알림 (QA #57)
var leave_warning: Label
var sfx_slider: HSlider
var music_slider: HSlider


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
	# 장면 위에 바로 놓이므로 흰 글자 + 두꺼운 진한 파랑 테두리, 낱말 단위 줄바꿈 (QA #51)
	card_trait.add_theme_color_override("font_color", Color(1, 1, 1))
	card_trait.add_theme_color_override("font_outline_color", Color("1f3f66"))
	card_trait.add_theme_constant_override("outline_size", 10)
	card_trait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_trait.custom_minimum_size = Vector2(300, 0)
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
	guide = GuideOverlay.new()
	guide.name = "Guide"
	guide.theme = get_tree().root.theme
	# 맨 위 층: F1 조작 그림이 정산 판 위에, 안내 카드가 도구 커서 위에 보이게 (QA #61)
	add_child(guide)
	_build_volume_rows()
	_build_settle_panel()
	_build_morning_panel()
	_build_end_panel()
	_build_shop_grid()


func is_paused() -> bool:
	return pause_menu.visible


## 정산·아침 화면이 떠 있음 (목욕대 도구를 쓰지 않고 마우스 커서를 보여 줌)
func is_menu_open() -> bool:
	return settle_panel.visible or morning_panel.visible or end_panel.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		_set_paused(not pause_menu.visible)
	elif event.is_action_pressed("toggle_help"):
		guide.help_visible = not guide.help_visible


func _set_paused(paused: bool) -> void:
	# 온라인 게임이라 시간은 멈추지 않는다. 메뉴만 띄운다.
	pause_menu.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused or world.local_seat() != 0 else Input.MOUSE_MODE_HIDDEN


func _process(_delta: float) -> void:
	var station: WashStation = world.station
	var store: Node = world.store
	var at_bath: bool = world.local_seat() == 0
	# 1인용: "혼자 하기 · 플레이어 1 / 4" 는 보이지 않고 F1 안내만 (이슈 #64)
	status_label.text = "F1: 조작 그림"
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
	if day.closed or day.morning:
		hint = ""
	hint_label.add_theme_color_override("font_color", Color(1, 0.5, 0.45) if warning else Color(1, 0.92, 0.55))
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()

	# 영업 중(정산·아침이 아님)에 나가면 오늘 것은 저장되지 않는다
	leave_warning.visible = pause_menu.visible and not day.closed and not day.morning
	_update_settle(day, at_bath)
	_update_morning(day)
	shop_panel.visible = not at_bath and not day.morning
	if shop_panel.visible:
		shop_info.text = "돈 %d · 기본 샴푸 %d마리분 · 복숭아 샴푸 %d마리분" % [store.money, store.basic_uses, store.peach_uses]
		for kind: String in _shop_effects:
			var button: Button = _shop_effects[kind]
			button.disabled = not store.can_buy(kind)
			button.text = "샀어요 ✓" if store.owns(kind) else "사기 — %d" % store.price(kind)
		use_basic.button_pressed = store.shampoo == "basic"
		use_peach.button_pressed = store.shampoo == "peach"
		use_peach.disabled = store.peach_uses <= 0 and store.shampoo != "peach"
		shop_next_day.visible = day.closed and not day.is_last_day()
	# 정산·아침 화면이 뜨면 목욕대 자리에서도 마우스 커서를 보여 준다
	var menu_open := is_menu_open()
	if menu_open != _menu_was_open:
		_menu_was_open = menu_open
		if at_bath and not is_paused():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_HIDDEN


## 정산 화면: 씻긴 손님 · 떠난 손님 · 번 돈(요금 + 팁) · 오늘 가장 기뻐한 손님 얼굴 → 쇼핑 / 다음 날
func _update_settle(day: Node, at_bath: bool) -> void:
	end_panel.visible = _show_end and day.closed and day.is_last_day()
	if end_panel.visible:
		end_totals.text = "3일 동안 씻긴 손님 %d명 · 번 돈 %d" % [day.total_served, day.total_earned]
	settle_panel.visible = day.closed and at_bath and not end_panel.visible
	if not settle_panel.visible:
		return
	settle_panel.get_node("Box/Title").text = "%d일차 정산" % day.day
	settle_stats.text = "씻긴 손님 %d명 · 기다리다 떠난 손님 %d명\n번 돈 %d (요금 %d + 팁 %d)" % [day.served, day.walked_out, day.earned, day.earned - day.tips, day.tips]
	var best: Vector2 = day.best_guest
	settle_face.visible = best.x >= 0.0
	settle_best.visible = best.x >= 0.0
	if best.x >= 0.0:
		settle_face.texture = UiArt.texture(["face_unhappy", "face_neutral", "face_happy"][Tuning.data.mood_face(best.x)])
		settle_best.text = "오늘 가장 기뻐한 손님 (%s)" % WashStation.SPECIES_NAMES[int(best.y)]
	var store: Node = world.store
	var shampoo_left: int = store.basic_uses + store.peach_uses
	var tomorrow: int = day.guests_on(day.day + 1)
	settle_supply.visible = not day.is_last_day()
	var short := shampoo_left < tomorrow
	settle_supply.text = "남은 샴푸 %d마리분 / 내일 손님 %d명%s" % [shampoo_left, tomorrow, "\n모자라요! 컴퓨터에서 샴푸를 사 두세요 (없으면 물로만 씻어요)" if short else ""]
	settle_supply.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if short else Color(0.75, 1, 0.75))
	next_day_button.visible = not day.is_last_day()
	settle_end_label.visible = day.is_last_day()
	end_button.visible = day.is_last_day()


## 아침 화면: 오늘 새로 열린 것 → 영업 시작
func _update_morning(day: Node) -> void:
	morning_panel.visible = day.morning
	if day.morning:
		morning_title.text = "%d일차 아침" % day.day
		morning_news.text = day.morning_news(day.day)


## Esc 메뉴에 음량 막대 두 개 (효과음 / 음악). 바꾸면 바로 적용·저장 (Settings)
func _build_volume_rows() -> void:
	Settings.ensure_loaded()
	var box: VBoxContainer = $PauseMenu/Box
	leave_warning = Label.new()
	leave_warning.text = "오늘 영업은 저장되지 않아요 (아침부터 다시)"
	leave_warning.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
	leave_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(leave_warning)
	box.move_child(leave_warning, $PauseMenu/Box/Leave.get_index())
	sfx_slider = _volume_row(box, "효과음", Settings.sfx_volume)
	music_slider = _volume_row(box, "음악", Settings.music_volume)
	var changed := func(_value: float) -> void: Settings.set_volumes(sfx_slider.value, music_slider.value)
	sfx_slider.value_changed.connect(changed)
	music_slider.value_changed.connect(changed)


func _volume_row(box: VBoxContainer, title: String, value: float) -> HSlider:
	var row := HBoxContainer.new()
	box.add_child(row)
	box.move_child(row, $PauseMenu/Box/Leave.get_index())
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 32)
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	return slider


## 끝 화면을 열며 축하: 색종이가 쏟아지고 박수·딩 (QA #57)
func _open_end() -> void:
	_show_end = true
	var confetti := CPUParticles2D.new()
	confetti.name = "Confetti"
	confetti.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0, -20.0)
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(get_viewport().get_visible_rect().size.x / 2.0, 10.0)
	confetti.amount = 160
	confetti.lifetime = 3.5
	confetti.one_shot = true
	confetti.explosiveness = 0.7
	confetti.direction = Vector2.DOWN
	confetti.spread = 30.0
	confetti.gravity = Vector2(0, 220)
	confetti.initial_velocity_min = 80.0
	confetti.initial_velocity_max = 220.0
	confetti.angular_velocity_min = -360.0
	confetti.angular_velocity_max = 360.0
	confetti.scale_amount_min = 6.0
	confetti.scale_amount_max = 10.0
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	colors.colors = PackedColorArray([Color("ff7aa8"), Color("ffd45c"), Color("7ad7ff"), Color("8ce99a"), Color("c792ea")])
	confetti.color_initial_ramp = colors
	add_child(confetti)
	confetti.emitting = true
	world.sfx.play("clap")
	world.sfx.play("ding")


func _build_settle_panel() -> void:
	settle_panel = _center_panel("Settle", "정산")
	var box: VBoxContainer = settle_panel.get_node("Box")
	settle_stats = Label.new()
	settle_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(settle_stats)
	settle_supply = Label.new()
	settle_supply.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(settle_supply)
	var best_row := HBoxContainer.new()
	best_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(best_row)
	settle_face = TextureRect.new()
	settle_face.custom_minimum_size = Vector2(64, 64)
	settle_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	settle_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	best_row.add_child(settle_face)
	settle_best = Label.new()
	best_row.add_child(settle_best)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	settle_shop_button = _menu_button(buttons, "컴퓨터에서 쇼핑하기")
	settle_shop_button.pressed.connect(func() -> void: world.switch_seat())
	next_day_button = _menu_button(buttons, "다음 날 →")
	next_day_button.pressed.connect(func() -> void: world.day.send_next_day())
	settle_end_label = Label.new()
	settle_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settle_end_label.text = "오늘이 마지막 날이에요"
	box.add_child(settle_end_label)
	end_button = _menu_button(buttons, "끝 →")
	end_button.pressed.connect(_open_end)


## 끝 화면: 3일 합계, 다음에 열리는 것(잠긴 칸, GDD_V3 6장 "남은 것이 보이게"), 메뉴로
func _build_end_panel() -> void:
	end_panel = _center_panel("End", "체험판은 여기까지! 고마워요")
	end_panel.custom_minimum_size = Vector2(720, 420)
	var box: VBoxContainer = end_panel.get_node("Box")
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	(box.get_node("Title") as Label).add_theme_font_size_override("font_size", 40)
	end_totals = Label.new()
	end_totals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(end_totals)
	var next_title := Label.new()
	next_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_title.text = "다음에 열리는 것"
	box.add_child(next_title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for upcoming in ["목욕대 2대째", "빗질", "새 동물 ?"]:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(150, 90)
		cell.modulate = Color(1, 1, 1, 0.6)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = "잠김\n%s" % upcoming
		cell.add_child(label)
		row.add_child(cell)
	end_menu_button = _menu_button(box, "메뉴로")
	end_menu_button.pressed.connect(func() -> void: Net.leave_session())


func _build_morning_panel() -> void:
	morning_panel = _center_panel("Morning", "아침")
	var box: VBoxContainer = morning_panel.get_node("Box")
	morning_title = box.get_node("Title")
	morning_news = Label.new()
	morning_news.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(morning_news)
	open_button = _menu_button(box, "영업 시작!")
	open_button.pressed.connect(func() -> void: world.day.send_open())


## 컴퓨터 쇼핑: 화면 하나, 탭 없이 4칸 (샴푸 2 · 도구 업그레이드 1 · 꾸미기 1)
func _build_shop_grid() -> void:
	var box: VBoxContainer = $Shop/Box
	$Shop/Box/Title.text = "가게 컴퓨터 — 쇼핑"
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	box.move_child(grid, buy_basic.get_index())
	buy_wide_shower = Button.new()
	buy_wide_shower.pressed.connect(func() -> void: world.store.send_buy("wide_shower"))
	buy_plant = Button.new()
	buy_plant.pressed.connect(func() -> void: world.store.send_buy("plant"))
	var uses: int = Tuning.data.tool_shampoo_uses_per_bottle
	var cells := [
		["basic", buy_basic, "%d마리분. 다 쓰면 거품이 안 나요" % uses],
		["peach", buy_peach, "%d마리분 · 분홍 거품 · 복숭아 손님 팁 +" % uses],
		["wide_shower", buy_wide_shower, "도구: 적시기·헹구기가 %.1f배 넓게" % Tuning.data.slice_wide_shower_mult],
		["plant", buy_plant, "꾸미기: 기다리는 손님이 더 오래 참아요"],
	]
	for cell: Array in cells:
		var kind: String = cell[0]
		var button: Button = cell[1]
		var cell_box := VBoxContainer.new()
		cell_box.custom_minimum_size = Vector2(280, 0)
		grid.add_child(cell_box)
		var name_label := Label.new()
		name_label.theme_type_variation = &"PromptLabel"
		name_label.text = Store.NAMES[kind]
		cell_box.add_child(name_label)
		var effect := Label.new()
		effect.text = cell[2]
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.add_theme_font_size_override("font_size", 20)
		cell_box.add_child(effect)
		if button.get_parent() != null:
			button.get_parent().remove_child(button)
		button.focus_mode = Control.FOCUS_NONE
		cell_box.add_child(button)
		_shop_effects[kind] = button
	# 판을 불투명하게 크게: 3D 모니터를 다 덮어 테두리가 비스듬히 삐져나오지 않게 (QA #54)
	var screen := StyleBoxFlat.new()
	screen.bg_color = Color(0.11, 0.15, 0.21, 0.98)
	screen.border_color = Color(0.04, 0.04, 0.06)
	screen.set_border_width_all(8)
	screen.set_corner_radius_all(14)
	screen.set_content_margin_all(22)
	$Shop.add_theme_stylebox_override("panel", screen)
	$Shop.custom_minimum_size = Vector2(760, 470)
	shop_next_day = _menu_button(box, "다음 날 →")
	shop_next_day.pressed.connect(func() -> void: world.day.send_next_day())


## 화면 가운데 판 (정산·아침): Box/Title 이 있는 PanelContainer
func _center_panel(panel_name: String, title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.theme = get_tree().root.theme
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title_label := Label.new()
	title_label.name = "Title"
	title_label.theme_type_variation = &"PromptLabel"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = title
	box.add_child(title_label)
	add_child(panel)
	move_child(panel, overlay.get_index())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.hide()
	return panel


func _menu_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(200, 52)
	parent.add_child(button)
	return button


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
