extends RefCounted
## V4 18일 전체 흐름 (GDD_V4 '18일 전체 흐름', TUNING_V4 6장): 날마다 손님 간격 · 새로 열리는 것 · 아침 알림 한 줄 ·
## 18일차 정산 뒤 감사의 날 엔딩 (fp_thanks.gd) · 엔딩 별 · 19일차부터 자유 영업. 규칙만 여기 (가게·손님이 물어봄), 장면은 fp_shop / fp_ending.

## 아침 알림 (그날 새로 열리는 것 한 줄). 없는 날은 ""
const NOTICES := {
	1: "첫날! 손님을 클릭해 맡고, 씻겨서 돌려주세요. 하루가 끝나면 도구·꾸미기 가게",
	2: "어제 산 것은 아침 택배로 와요 · 급한 손님이 오기 시작해요 · 간지럼쟁이 손님",
	3: "오늘부터 고양이 손님이 와요",
	4: "오늘 정산 가게에 가위가 들어와요 (사면 미용 요청 손님)",
	5: "겁쟁이 손님이 오기 시작해요",
	6: "소문이 났어요! 내일부터 손님이 조금 더 자주 와요",
	7: "멋쟁이 손님이 오기 시작해요",
	9: "대기 의자가 하나 늘었어요 (4개)",
}
const FREE_PLAY := "자유 영업 · 남은 도구·꾸미기·금색 사진을 모아 보세요"
## 엔딩 별 3개 이름 (v4_ending_stars 순서)
const STAR_NAMES := ["금색 사진 %d장", "5단계 도구 %d개", "단짝 단골 %d마리"]


## 그날 새 손님 간격 (s): 1~18일차 표, 그 뒤 자유 영업
static func guest_every(day: int) -> float:
	var table: PackedFloat32Array = Tuning.data.v4_guest_every_by_day
	if day >= 1 and day <= table.size():
		return table[day - 1]
	return Tuning.data.v4_free_play_guest_every


## 마지막 날 (정산 뒤 감사의 날 엔딩)
static func is_last_day(day: int) -> bool:
	return day == Tuning.data.v4_last_day


static func is_free_play(day: int) -> bool:
	return day > Tuning.data.v4_last_day


static func hurry_open(day: int) -> bool:
	return day >= Tuning.data.v4_hurry_from_day


static func scissors_open(day: int) -> bool:
	return day >= Tuning.data.v4_scissors_from_day


## 대기 의자 수 (9일차부터 4개)
static func seat_count(day: int) -> int:
	return 4 if day >= Tuning.data.v4_extra_seat_day else 3


## 아침 알림 한 줄 ("" = 새 것 없음)
static func notice(day: int) -> String:
	if day > Tuning.data.v4_last_day:
		return FREE_PLAY
	return NOTICES.get(day, "")


## 엔딩 별: 금색 사진 수 · 5단계 도구 수 · 단짝 단골 수 → [{name, value, need, got}]
static func stars(album: Dictionary, tool_level: Dictionary) -> Array:
	var gold := 0
	for id in album:
		if int(album[id].get("best_mood", -1)) == 3:
			gold += 1
	var top := 0
	for tool_id in tool_level:
		if int(tool_level[tool_id]) >= Tuning.data.v4_tool_tiers - 1:
			top += 1
	var best := 0
	for id in album:
		if int(album[id].get("trust", 0)) >= 3:
			best += 1
	var values := [gold, top, best]
	var need: PackedInt32Array = Tuning.data.v4_ending_stars
	var out := []
	for i in 3:
		out.append({"name": STAR_NAMES[i] % need[i], "value": values[i], "need": need[i], "got": values[i] >= need[i]})
	return out
