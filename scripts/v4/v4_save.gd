extends RefCounted
## V4 저장·이어하기 (사람 대표 순서 2): 가진 돈 · 날짜 · 도구 단계 · 가위 · 남은 샴푸 · 빗 닳음 · 꾸미기 ·
## 도착했지만 아직 안 들인 택배 상자.
##
## 영업 중에는 저장하지 않는다. 저장하는 때: 하루가 끝나 정산 판이 뜰 때, 정산 판에서 살 때, [다음 날] 을 누를 때.
## 이어하기는 저장된 "다음에 시작할 날" 의 처음부터 (영업 중에 끈 날은 그날 처음부터 다시).
## 빠른 확인(개발용)은 저장하지 않는다.
## 파일: user://v4_save.json (JSON 한 덩어리, 버전 번호 포함). V3 저장(user://slice_save.json)과 따로. 테스트는 path 를 바꿔 쓴다.
##
## 샴푸 소모·빗 닳음·꾸미기·택배(GDD_V4 '가게 밖·택배', '샴푸·빗 닳음', '가게 꾸미기')는 각자의 PR 에서 규칙이 들어온다.
## 이 저장은 그 값들의 자리를 먼저 만들어 두어, 나중 PR 이 저장 형식을 바꾸지 않고 값만 채우게 한다.

const VERSION := 1

static var path := "user://v4_save.json"
## 메뉴에서 "V4 이어하기" 를 눌렀음 (가게가 시작할 때 한 번 읽고 지움)
static var continue_requested := false


## 처음 시작할 때의 값 (새로 하기). 저장 파일에 빠진 키도 이 값으로 채운다
static func fresh() -> Dictionary:
	return {
		"next_day": 1,
		"money": 0,
		"tool_level": {"shower": 0, "shampoo": 0, "towel": 0, "dryer": 0, "brush": 0},
		"owns_scissors": false,
		# 남은 샴푸 (마리분). 거품 도구 단계가 높으면 0.75·0.5 마리분씩 써서 소수
		"shampoo_left": float(Tuning.data.v4_shampoo_start),
		# 지금 빗으로 빗질한 마리 수 (새 빗살을 끼우면 0)
		"brush_used": 0,
		# 꾸미기: 산 물건 id 목록, 범주별로 놓인 물건 id (없으면 처음 것)
		"decor": {"owned": [], "placed": {}},
		# 안 연 택배 상자. 하나 = {"item": 물건 id, "kind": tool|decor|shampoo|brush_refill, "size": small|medium|large,
		# "arrived": 매트에 도착했나 (false = 어제 주문, 다음 아침 트럭으로 옴)}
		"parcels": [],
	}


static func exists() -> bool:
	return FileAccess.file_exists(path)


## 저장된 내용 (빠진 키는 처음 값으로 채움). 없거나 깨졌거나 버전이 다르면 빈 Dictionary
static func read() -> Dictionary:
	if not exists():
		return {}
	# JSON.parse_string 은 깨진 파일에서 오류 줄을 찍으므로, 조용한 JSON.parse 로 읽음
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary or int((parsed as Dictionary).get("version", 0)) != VERSION:
		return {}
	return normalize(parsed)


## JSON 으로 읽은 값의 모양을 맞춤 (숫자는 JSON 에서 모두 float 로 오므로 int 로, 모르는 도구·빠진 키는 처음 값)
static func normalize(raw: Dictionary) -> Dictionary:
	var data := fresh()
	data.next_day = maxi(1, int(raw.get("next_day", 1)))
	data.money = maxi(0, int(raw.get("money", 0)))
	var levels: Variant = raw.get("tool_level", {})
	if levels is Dictionary:
		for tool_id in data.tool_level:
			data.tool_level[tool_id] = clampi(int(levels.get(tool_id, 0)), 0, Tuning.data.v4_tool_tiers - 1)
	data.owns_scissors = bool(raw.get("owns_scissors", false))
	data.shampoo_left = maxf(0.0, float(raw.get("shampoo_left", data.shampoo_left)))
	data.brush_used = maxi(0, int(raw.get("brush_used", 0)))
	var decor: Variant = raw.get("decor", {})
	if decor is Dictionary:
		var owned: Variant = decor.get("owned", [])
		if owned is Array:
			for id in owned:
				data.decor.owned.append(str(id))
		var placed: Variant = decor.get("placed", {})
		if placed is Dictionary:
			for category in placed:
				data.decor.placed[str(category)] = str(placed[category])
	var parcels: Variant = raw.get("parcels", [])
	if parcels is Array:
		for box in parcels:
			if box is Dictionary and box.has("item"):
				data.parcels.append({"item": str(box.item), "kind": str(box.get("kind", "tool")), "size": str(box.get("size", "small")), "arrived": bool(box.get("arrived", true))})
	return data


static func write(data: Dictionary) -> bool:
	var out := data.duplicate(true)
	out["version"] = VERSION
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("저장 실패: %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(out, "\t"))
	return true


static func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func can_continue() -> bool:
	return not read().is_empty()


## 이어하면 시작할 날 (메뉴 버튼 글자용)
static func continue_day() -> int:
	return int(read().get("next_day", 1))
