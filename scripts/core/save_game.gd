extends RefCounted
## 수직 단면 자동 저장 (MILESTONE_V3_SLICE 5장): 돈 · 날짜 · 산 물건 · 남은 샴푸 · 3일 합계.
##
## 저장은 호스트(혼자 하기 포함)만, 영업 중에는 하지 않는다:
## 영업이 끝날 때(정산), 정산·아침에 물건을 살 때, "다음 날" 을 누를 때.
## 이어하기는 저장된 날의 다음 날 아침 화면에서 시작한다. 3일차를 끝낸 저장은 이어하기가 없다 (끝까지 했음).
## 파일: user://slice_save.json (JSON 한 덩어리, 버전 번호 포함). 테스트는 path 를 바꿔 쓴다.

const VERSION := 1

static var path := "user://slice_save.json"
## 메뉴에서 "이어하기" 를 눌렀음 (월드가 시작할 때 한 번 읽고 지움)
static var continue_requested := false


static func exists() -> bool:
	return FileAccess.file_exists(path)


## 저장된 내용. 없거나 깨졌거나 버전이 다르면 빈 Dictionary
static func read() -> Dictionary:
	if not exists():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int((parsed as Dictionary).get("version", 0)) != VERSION:
		return {}
	return parsed


static func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("저장 실패: %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


static func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## 이어할 수 있는가 (저장이 있고 3일차를 아직 안 끝냄)
static func can_continue() -> bool:
	var data := read()
	return not data.is_empty() and not bool(data.get("finished", false))


## 이어하면 시작할 날 (메뉴 버튼 글자용)
static func continue_day() -> int:
	return int(read().get("next_day", 1))
