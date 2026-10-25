extends Node
## 스팀 초기화와 콜백 처리 (autoload: SteamService).
##
## GodotSteam 애드온이 없거나, 스팀 클라이언트가 꺼져 있거나, 초기화에 실패해도
## 게임은 그대로 돈다. available 이 false 면 스팀 기능만 꺼진다.
## Steam 싱글톤은 이름으로 직접 쓰지 않는다 (애드온이 없을 때 스크립트 파싱 오류 방지).

signal lobby_join_requested(lobby_id: int)

## 스팀 앱 ID가 나오기 전까지는 테스트 앱 ID 480 (Spacewar).
const APP_ID := 480

var steam: Object = null
var available := false
var init_message := "초기화 전"
var steam_id := 0
var persona_name := ""


func _ready() -> void:
	if "--no-steam" in OS.get_cmdline_user_args():
		init_message = "--no-steam 옵션으로 꺼짐"
		return
	if not Engine.has_singleton("Steam"):
		init_message = "GodotSteam 애드온이 설치되지 않음 (tools/fetch_godotsteam.sh)"
		return

	# steam_appid.txt 대신 환경 변수로 앱 ID 지정. 스팀에서 실행하면 스팀이 덮어쓴다.
	if OS.get_environment("SteamAppId").is_empty():
		OS.set_environment("SteamAppId", str(APP_ID))
		OS.set_environment("SteamGameId", str(APP_ID))

	var candidate: Object = Engine.get_singleton("Steam")
	var result: Variant = candidate.call("steamInitEx")
	var ok := false
	if result is Dictionary:
		ok = result.get("status", -1) == 0
		init_message = str(result.get("verbal", result))
	else:
		ok = bool(result)
		init_message = "steamInitEx 결과 %s" % str(result)
	if not ok:
		push_warning("스팀 초기화 실패, 스팀 없이 진행: %s" % init_message)
		return

	steam = candidate
	available = true
	init_message = "OK"
	steam_id = steam.call("getSteamID")
	persona_name = steam.call("getPersonaName")
	steam.connect("join_requested", _on_join_requested)
	print("스팀 초기화 완료: %s (%d)" % [persona_name, steam_id])
	_check_launch_lobby.call_deferred()


func _process(_delta: float) -> void:
	if available:
		steam.call("run_callbacks")


## 게임이 꺼진 상태에서 친구 초대를 수락하면 스팀이 "+connect_lobby <id>" 를 붙여 실행한다.
func _check_launch_lobby() -> void:
	var args := OS.get_cmdline_args()
	var i := args.find("+connect_lobby")
	if i >= 0 and i + 1 < args.size():
		lobby_join_requested.emit(args[i + 1].to_int())


func _on_join_requested(lobby_id: int, _friend_id: int) -> void:
	lobby_join_requested.emit(lobby_id)
