extends Control
## 메인 메뉴: 이어하기 / 새로 하기(혼자). (친구와 하기(스팀)·개발용 IP 접속 줄은 숨김 — 1인용)
## 이어하기는 자동 저장(SaveGame)이 있고 3일차를 아직 안 끝냈을 때만 보인다 (MILESTONE_V3_SLICE 5장).
##
## 개발용 실행 옵션 (godot ... -- <옵션>):
##   --host [--port=N]               바로 ENet 호스트
##   --join=<IP> [--port=N]          바로 ENet 접속
##   --solo                          바로 혼자 하기

@onready var solo_button: Button = %SoloButton
@onready var steam_button: Button = %SteamButton
@onready var steam_note: Label = %SteamNote
@onready var address_edit: LineEdit = %AddressEdit
@onready var port_edit: LineEdit = %PortEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var quit_button: Button = %QuitButton
@onready var message_label: Label = %MessageLabel

const SaveGame := preload("res://scripts/core/save_game.gd")
const V4Save := preload("res://scripts/v4/v4_save.gd")
const UiArt := preload("res://scripts/game/ui_art.gd")

static var _autostart_done := false

## 이어하기 (저장이 있을 때만 보임)
const V4_SCENE := "res://scenes/v4/fp_shop.tscn"
## 빠른 확인 (개발용). 스팀 출시 빌드에는 dev 폴더가 빠져서 이 씬이 없고, 그러면 버튼도 안 만든다
const QUICK_SCENE := "res://scenes/dev/quick_check.tscn"
const QUICK_SCRIPT := "res://scripts/dev/quick_check.gd"
const LICENSES := "res://LICENSES.txt"
const Settings := preload("res://scripts/core/settings.gd")

var continue_button: Button
## 출시 빌드처럼 보기 (테스트·확인용, add_child 전에 정함): dev 폴더가 있어도 개발용 칸을 숨김
var release_preview := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hang_sign()
	solo_button.pressed.connect(_start_new)
	steam_button.pressed.connect(func() -> void:
		SaveGame.continue_requested = false
		Net.host_steam())
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.custom_minimum_size = Vector2(0, 52)
	solo_button.get_parent().add_child(continue_button)
	solo_button.get_parent().move_child(continue_button, solo_button.get_index())
	continue_button.pressed.connect(_continue)
	# V4 방향 시제품 (1인칭으로 걸어다니며 손에 든 도구로 씻기). V3 게임은 그대로 두고 새 씬으로 연다.
	var v4_button := Button.new()
	v4_button.name = "V4Button"
	v4_button.text = "V4 시제품 (1인칭)"
	v4_button.custom_minimum_size = Vector2(0, 52)
	solo_button.get_parent().add_child(v4_button)
	solo_button.get_parent().move_child(v4_button, solo_button.get_index() + 1)
	v4_button.pressed.connect(func() -> void: _open_v4(false))
	# V4 이어하기: V4 저장(user://v4_save.json)이 있을 때만, V4 시제품 버튼 바로 위
	var v4_continue := Button.new()
	v4_continue.name = "V4ContinueButton"
	v4_continue.custom_minimum_size = Vector2(0, 52)
	v4_continue.visible = V4Save.can_continue()
	v4_continue.text = "V4 이어하기 (%d일차부터)" % V4Save.continue_day() if v4_continue.visible else "V4 이어하기"
	solo_button.get_parent().add_child(v4_continue)
	solo_button.get_parent().move_child(v4_continue, v4_button.get_index())
	v4_continue.pressed.connect(func() -> void: _open_v4(true))
	_add_quick_check(v4_button)
	continue_button.visible = SaveGame.can_continue()
	if continue_button.visible:
		continue_button.text = "이어하기 (%d일차 아침부터)" % SaveGame.continue_day()
		solo_button.text = "새로 하기 (혼자)"
	host_button.pressed.connect(func() -> void: Net.host_enet(_port()))
	join_button.pressed.connect(func() -> void: Net.join_enet(address_edit.text.strip_edges(), _port()))
	quit_button.pressed.connect(get_tree().quit)
	# 라이선스 전문 (OFL·MIT 는 함께 배포해야 함, 기획 LAUNCH_PREP 5장): 끝내기 바로 위
	var license_button := Button.new()
	license_button.name = "LicenseButton"
	license_button.text = "라이선스"
	license_button.custom_minimum_size = Vector2(0, 40)
	quit_button.get_parent().add_child(license_button)
	quit_button.get_parent().move_child(license_button, quit_button.get_index())
	license_button.pressed.connect(show_licenses)
	port_edit.text = str(Net.DEFAULT_PORT)

	# 1인용 결정 (사람 대표, 2026-10-28): 친구와 하기·개발용 IP 접속 줄은 메뉴에서만 숨긴다.
	# 코드(Net·스팀 로비·ENet)는 그대로 두고, 개발용 실행 옵션 --host / --join 도 그대로 쓸 수 있다.
	for row in [steam_button, steam_note, $Center/Box/DevSeparator, $Center/Box/DevTitle, $Center/Box/DevRow, $Center/Box/DevButtons]:
		row.hide()
	steam_button.disabled = not SteamService.available
	steam_note.text = (
		"%s 님, 로비를 만든 뒤 게임 안에서 친구를 초대하세요" % SteamService.persona_name
		if SteamService.available
		else "스팀을 쓸 수 없음: %s" % SteamService.init_message
	)
	message_label.text = Net.last_end_reason
	_arrange_release_menu(v4_button, v4_continue, license_button)
	_autostart()


## [안내 다시 보기]: V4 저장의 본 안내를 지우고 안내를 켬 (다음에 할 때 처음처럼)
func replay_guide() -> void:
	Settings.set_guide_enabled(true)
	var saved := V4Save.read()
	if not saved.is_empty():
		saved.guide_seen = []
		V4Save.write(saved)


## 출시용 첫 화면 (대표 결정, QA #139): V4 하나 — [이어하기] (저장이 있을 때) · [새로 시작] · [설정] · [라이선스] · [끝내기].
## V3 [혼자 하기]·개발용 버튼은 출시 빌드에서 안 보임 (코드는 그대로). dev 폴더가 있는 개발 빌드에서만
## 아래쪽 "개발용" 칸에 빠른 확인 줄과 V3 버튼을 둠 (출시 프리셋은 scripts/dev·scenes/dev 를 뺌).
func _arrange_release_menu(v4_new: Button, v4_continue: Button, license_button: Button) -> void:
	var box := solo_button.get_parent()
	var dev := ResourceLoader.exists(QUICK_SCENE) and not release_preview
	v4_new.text = "새로 시작"
	v4_continue.text = "이어하기 (%d일차부터)" % V4Save.continue_day() if v4_continue.visible else "이어하기"
	# 새로 시작: 저장이 있으면 한 번 물어봄 (저장된 날이 지워짐)
	for connection in v4_new.pressed.get_connections():
		v4_new.pressed.disconnect(connection.callable)
	v4_new.pressed.connect(start_new_v4)
	var settings_button := Button.new()
	settings_button.name = "SettingsButton"
	settings_button.text = "설정"
	settings_button.custom_minimum_size = Vector2(0, 44)
	settings_button.pressed.connect(show_settings)
	box.add_child(settings_button)
	quit_button.text = "끝내기"
	quit_button.custom_minimum_size = Vector2(0, 44)
	license_button.custom_minimum_size = Vector2(0, 44)
	$Center/Box/Credits.hide()
	# 차례: 제목 → 이어하기 → 새로 시작 → 설정 → 라이선스 → 끝내기 → (개발용)
	# 간판 그림이 있으면 제목은 Sign 안으로 들어가 있음 (_hang_sign)
	var heading: Node = box.get_node_or_null("Sign") if box.get_node_or_null("Sign") != null else box.get_node_or_null("Title")
	var order: Array = [heading, v4_continue, v4_new, settings_button, license_button, quit_button, message_label].filter(func(node: Variant) -> bool: return node != null)
	for i in order.size():
		box.move_child(order[i], i)
	var dev_nodes: Array = [box.get_node_or_null("QuickCheckTitle"), box.get_node_or_null("QuickCheckRow")]
	if dev:
		var v3_title := Label.new()
		v3_title.name = "V3Title"
		v3_title.text = "개발용: V3 (2D 손님 줄)"
		v3_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(v3_title)
		dev_nodes += [v3_title, continue_button, solo_button]
	else:
		solo_button.hide()
		continue_button.hide()
		for node in dev_nodes:
			if node != null:
				node.hide()
	for node in dev_nodes:
		if node != null:
			box.move_child(node, box.get_child_count() - 1)
	(v4_continue if v4_continue.visible else v4_new).grab_focus()


## [새로 시작]: 저장이 있으면 "N일차 저장이 지워져요" 확인 → 지우고 1일차부터
func start_new_v4() -> void:
	if not V4Save.can_continue():
		_open_v4(false)
		return
	if has_node("NewConfirm"):
		return
	var dialog := ConfirmationDialog.new()
	dialog.name = "NewConfirm"
	dialog.title = "새로 시작"
	dialog.dialog_text = "저장된 %d일차가 지워져요. 새로 시작할까요?" % V4Save.continue_day()
	dialog.ok_button_text = "새로 시작"
	dialog.cancel_button_text = "돌아가기"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		V4Save.erase()
		_open_v4(false))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


func _open_v4(go_on: bool) -> void:
	V4Save.continue_requested = go_on
	get_tree().change_scene_to_file(V4_SCENE)


## [설정]: 효과음·음악 크기 (user://settings.cfg). 닫기로 메뉴
func show_settings() -> void:
	if has_node("SettingsPanel"):
		return
	Settings.ensure_loaded()
	var layer := CanvasLayer.new()
	layer.name = "SettingsPanel"
	layer.layer = 10
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Rows"
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "설정"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var sliders := {}
	for row in [["Sfx", "효과음", Settings.sfx_volume], ["Music", "음악", Settings.music_volume]]:
		var line := HBoxContainer.new()
		var label := Label.new()
		label.text = row[1]
		label.custom_minimum_size = Vector2(90, 0)
		line.add_child(label)
		var slider := HSlider.new()
		slider.name = row[0]
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = row[2]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(slider)
		box.add_child(line)
		sliders[row[0]] = slider
	for key in sliders:
		(sliders[key] as HSlider).value_changed.connect(func(_value: float) -> void:
			Settings.set_volumes(sliders.Sfx.value, sliders.Music.value))
	# 처음 하는 사람 안내 (V4, LAUNCH_PREP 2장): 켜기·끄기, 다시 보기 (V4 저장의 본 안내를 지움)
	var guide_row := HBoxContainer.new()
	guide_row.name = "GuideRow"
	guide_row.alignment = BoxContainer.ALIGNMENT_CENTER
	guide_row.add_theme_constant_override("separation", 8)
	box.add_child(guide_row)
	var guide_toggle := Button.new()
	guide_toggle.name = "GuideToggle"
	guide_toggle.custom_minimum_size = Vector2(0, 40)
	guide_toggle.text = "안내 끄기" if Settings.guide_enabled else "안내 켜기"
	guide_toggle.pressed.connect(func() -> void:
		Settings.set_guide_enabled(not Settings.guide_enabled)
		guide_toggle.text = "안내 끄기" if Settings.guide_enabled else "안내 켜기")
	guide_row.add_child(guide_toggle)
	var guide_replay := Button.new()
	guide_replay.name = "GuideReplay"
	guide_replay.custom_minimum_size = Vector2(0, 40)
	guide_replay.text = "안내 다시 보기"
	guide_replay.pressed.connect(func() -> void:
		replay_guide()
		guide_replay.text = "안내 다시 보기 ✔")
	guide_row.add_child(guide_replay)
	var close := Button.new()
	close.name = "Close"
	close.text = "닫기"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(layer.queue_free)
	box.add_child(close)
	close.grab_focus()


## 라이선스 전문 창 (res://LICENSES.txt, tools/make_licenses.gd 가 만듦). 닫기로 메뉴
func show_licenses() -> void:
	if has_node("Licenses"):
		return
	var layer := CanvasLayer.new()
	layer.name = "Licenses"
	layer.layer = 10
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_top = 40
	panel.offset_right = -60
	panel.offset_bottom = -40
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var text := TextEdit.new()
	text.name = "Text"
	text.editable = false
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.text = FileAccess.get_file_as_string(LICENSES) if FileAccess.file_exists(LICENSES) else "LICENSES.txt 가 없어요"
	box.add_child(text)
	var close := Button.new()
	close.name = "Close"
	close.text = "닫기"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(layer.queue_free)
	box.add_child(close)
	close.grab_focus()


## 빠른 확인 줄: 기능마다 버튼 하나 (강아지 1~2마리로 그 기능이 바로 나옴). dev 씬이 없으면 아무것도 안 만듦
func _add_quick_check(after: Control) -> void:
	if not ResourceLoader.exists(QUICK_SCENE) or not ResourceLoader.exists(QUICK_SCRIPT):
		return
	var features: Array = (load(QUICK_SCRIPT) as GDScript).get_script_constant_map().get("FEATURES", [])
	var box := after.get_parent()
	var title := Label.new()
	title.name = "QuickCheckTitle"
	title.text = "빠른 확인 (개발용)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.move_child(title, after.get_index() + 1)
	var row := HFlowContainer.new()
	row.name = "QuickCheckRow"
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	box.add_child(row)
	box.move_child(row, title.get_index() + 1)
	for feature in features:
		var button := Button.new()
		button.name = "Quick_" + feature.id
		button.text = feature.name
		button.custom_minimum_size = Vector2(0, 40)
		var id: String = feature.id
		button.pressed.connect(func() -> void:
			Engine.set_meta("quick_check_feature", id)
			get_tree().change_scene_to_file(QUICK_SCENE))
		row.add_child(button)


## 가게 간판 그림 (assets/ui/sign.png, 가게 벽과 같은 그림)이 있으면 제목 뒤에 건다. 글자는 그림 위에.
func _hang_sign() -> void:
	var picture := UiArt.texture("sign")
	var title := $Center/Box/Title as Label
	if picture == null:
		return
	var sign := TextureRect.new()
	sign.name = "Sign"
	sign.texture = picture
	sign.custom_minimum_size = Vector2(460, 130)
	sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sign.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var box := title.get_parent()
	box.add_child(sign)
	box.move_child(sign, title.get_index())
	title.reparent(sign, false)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 그림 왼쪽의 강아지를 비켜 가운데 빈칸에
	title.offset_left = 110
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_color_override("font_outline_color", Color(0.85, 0.35, 0.5))
	title.add_theme_constant_override("outline_size", 12)


func _start_new() -> void:
	SaveGame.continue_requested = false
	Net.start_offline()


func _continue() -> void:
	SaveGame.continue_requested = true
	Net.start_offline()


func _port() -> int:
	var port := port_edit.text.to_int()
	return port if port > 0 and port < 65536 else Net.DEFAULT_PORT


func _autostart() -> void:
	if _autostart_done:
		return
	_autostart_done = true
	var args := OS.get_cmdline_user_args()
	var port := Net.DEFAULT_PORT
	for arg in args:
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
	for arg in args:
		if arg == "--host":
			Net.host_enet(port)
		elif arg.begins_with("--join="):
			Net.join_enet(arg.trim_prefix("--join="), port)
		elif arg == "--solo":
			Net.start_offline()
