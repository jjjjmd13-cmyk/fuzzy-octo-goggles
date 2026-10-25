extends CanvasLayer
## 시제품 화면 표시. 모든 값은 동기화된 상태를 읽기만 한다 (판정은 호스트).

const HELP_TEXT := """[조작]
WASD 이동 · Shift 달리기 · 마우스 둘러보기
E 줍기 / (길게) 동료 부활
Q 등불 내려놓기 · R 등불 건네기
휠 위/아래 (또는 1/2) 등불 밝기
F 손등 켜기/끄기 · Esc 메뉴

[디버그 — 호스트만]
F5 기름 %d 으로 다시 시작 · F6 다시 시작
F7 나 쓰러지기 · F3 수치 보기 · F1 이 도움말"""

@onready var world: Node = get_parent()
@onready var vignette: ColorRect = $Vignette
@onready var status_label: Label = $Status
@onready var invite_button: Button = $InviteButton
@onready var prompt_label: Label = $Bottom/Prompt
@onready var revive_bar: ProgressBar = $Bottom/ReviveBar
@onready var oil_bar: ProgressBar = $Bottom/OilRow/OilBar
@onready var oil_label: Label = $Bottom/OilRow/OilLabel
@onready var light_label: Label = $Bottom/LightLabel
@onready var stamina_bar: ProgressBar = $Bottom/StaminaBar
@onready var center_label: Label = $CenterLabel
@onready var help_label: Label = $Help
@onready var debug_label: Label = $Debug
@onready var pause_menu: Control = $PauseMenu


func _ready() -> void:
	$PauseMenu/Box/Resume.pressed.connect(_set_paused.bind(false))
	$PauseMenu/Box/Leave.pressed.connect(Net.leave_session)
	invite_button.pressed.connect(Net.invite_friends)
	pause_menu.hide()
	debug_label.hide()
	help_label.text = HELP_TEXT % int(Tuning.data.proto_debug_oil_start)
	revive_bar.max_value = Tuning.data.down_revive_time


func is_paused() -> bool:
	return pause_menu.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		_set_paused(not pause_menu.visible)
	elif event.is_action_pressed("toggle_help"):
		help_label.visible = not help_label.visible
	elif event.is_action_pressed("toggle_debug"):
		debug_label.visible = not debug_label.visible
	elif event is InputEventMouseButton and event.pressed and not pause_menu.visible \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# 창을 오가다 마우스가 풀린 경우 (같은 PC 창 두 개) 게임 화면을 누르면 다시 잡는다.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_paused(paused: bool) -> void:
	# 온라인 게임이라 시간은 멈추지 않는다. 메뉴만 띄우고 마우스를 풀어 준다.
	pause_menu.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	var data: Resource = Tuning.data
	var expedition: Node = world.expedition
	var oil_tank: Node = world.oil_tank
	var lantern: Node3D = world.lantern
	var me: Node = world.get_local_player()

	status_label.text = "%s · 플레이어 %d / %d" % [Net.status_text, world.get_players().size(), Net.MAX_PLAYERS]
	invite_button.visible = Net.can_invite_friends()

	oil_bar.max_value = data.oil_max
	oil_bar.value = oil_tank.oil
	if oil_tank.has_oil():
		oil_label.text = "기름 %d / %d%s" % [ceili(oil_tank.oil), int(data.oil_max), "  부족!" if oil_tank.is_low() else ""]
	elif oil_tank.in_wick():
		oil_label.text = "기름 없음 — 심지 %d초" % ceili(oil_tank.wick_left)
	else:
		oil_label.text = "완전한 어둠!"
	oil_label.modulate = Color(1, 0.45, 0.35) if oil_tank.is_low() else Color.WHITE

	var light_text := "등불: %s %d m" % [lantern.level_name(), int(lantern.light_radius())] if oil_tank.has_oil() else "등불: 꺼짐"
	if lantern.holder_peer == 0:
		light_text += " (바닥)"
	elif me != null and lantern.holder_peer == me.get_peer_id():
		light_text += " (내가 듦)"
	if me != null:
		light_text += " · 손등 %s" % ("켬" if me.is_handlamp_lit() else ("꺼짐" if not me.handlamp_on else "—"))
	light_label.text = light_text

	if me == null:
		return
	vignette.material.set_shader_parameter("amount", me.dark / data.dark_max)
	stamina_bar.max_value = data.player_stamina
	stamina_bar.value = me.stamina
	stamina_bar.visible = me.stamina < data.player_stamina - 0.01
	_update_prompt(me)
	_update_center(me, expedition)
	if debug_label.visible:
		_update_debug(expedition)


func _update_prompt(me: Node) -> void:
	var action: Dictionary = world.interact_target(me)
	var text := ""
	match action.get("kind", ""):
		"revive":
			text = "E 길게: 부활" if action.lit else "등불 빛 안에서만 부활할 수 있습니다"
		"lantern":
			text = "E: 등불 줍기"
		"bottle":
			text = "E: 기름병 줍기 (+%d)" % int(Tuning.data.oil_bottle_amount)
	if text.is_empty() and world.lantern.holder_peer == me.get_peer_id():
		text = "Q 내려놓기 · R 건네기 · 휠 밝기"
	prompt_label.text = text

	# 부활 진행: 내가 쓰러졌으면 내 것, 아니면 내가 부활시키는 동료 것.
	var progress := 0.0
	if me.downed:
		progress = me.revive_progress
	elif action.get("kind", "") == "revive":
		progress = world.get_player(action.target).revive_progress
	revive_bar.visible = progress > 0.0
	revive_bar.value = progress


func _update_center(me: Node, expedition: Node) -> void:
	if expedition.phase == expedition.Phase.FAILED:
		center_label.text = "전원 쓰러짐 — 원정 실패\n%d초 뒤 다시 시작" % ceili(expedition.restart_in)
	elif me.knocked_out:
		center_label.text = "기절했습니다\n(이번 판에서는 다시 일어날 수 없습니다)"
	elif me.downed:
		center_label.text = "쓰러졌습니다 — %d초\n동료가 등불 빛 안에서 부활시켜야 합니다" % ceili(me.down_time_left)
	else:
		center_label.text = ""


func _update_debug(expedition: Node) -> void:
	var lines := PackedStringArray()
	lines.append("기름 %.2f · 심지 %.1f · 분당 소모 %.2f · 인원 %d" % [
		world.oil_tank.oil, world.oil_tank.wick_left, expedition.oil_drain_per_minute(), expedition.party_size])
	lines.append("추적자: %s (대상 %d)" % [world.stalker.state_name(), world.stalker.target_peer])
	for player in world.get_players():
		lines.append("P%s 어둠 %.0f%s%s" % [player.name, player.dark, " 쓰러짐" if player.downed else "", " 기절" if player.knocked_out else ""])
	debug_label.text = "\n".join(lines)
