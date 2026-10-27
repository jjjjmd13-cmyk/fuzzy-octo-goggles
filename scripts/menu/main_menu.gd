extends Control
## 메인 메뉴: 이어하기 / 새로 하기(혼자) / 친구와 하기(스팀) / 개발용 IP 접속.
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

static var _autostart_done := false

## 이어하기 (저장이 있을 때만 보임)
var continue_button: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	continue_button.visible = SaveGame.can_continue()
	if continue_button.visible:
		continue_button.text = "이어하기 (%d일차 아침부터)" % SaveGame.continue_day()
		solo_button.text = "새로 하기 (혼자)"
	host_button.pressed.connect(func() -> void: Net.host_enet(_port()))
	join_button.pressed.connect(func() -> void: Net.join_enet(address_edit.text.strip_edges(), _port()))
	quit_button.pressed.connect(get_tree().quit)
	port_edit.text = str(Net.DEFAULT_PORT)

	steam_button.disabled = not SteamService.available
	steam_note.text = (
		"%s 님, 로비를 만든 뒤 게임 안에서 친구를 초대하세요" % SteamService.persona_name
		if SteamService.available
		else "스팀을 쓸 수 없음: %s" % SteamService.init_message
	)
	message_label.text = Net.last_end_reason
	(continue_button if continue_button.visible else solo_button).grab_focus()
	_autostart()


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
