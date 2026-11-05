extends RefCounted
## V4 단골 신뢰 (GDD_V4 '단골 신뢰 — 정이 드는 손님', TUNING_V4 7장): 단골마다 신뢰 점수 → 4단계 (낯가림·익숙함·친함·단짝).
## 단계는 내려가지 않음. 단계가 오를수록 성격·도구 버릇 규칙이 쉬워지고, 단짝은 놀이로 바뀜.
## 규칙 숫자만 여기 (가게가 물어봄). 사진첩 기록 모양도 여기서 만듦 (저장 album 단골 칸).

const NAMES := ["낯가림", "익숙함", "친함", "단짝"]
## 이름표·카드에 붙는 하트 (단계 수만큼)
const HEARTS := ["", "♥", "♥♥", "♥♥♥"]
## 도구 버릇: 이름, 처음 안내 (목욕대 왼쪽 위 한 줄), 넘은 날 기록
const QUIRKS := {
	"shower": {"name": "샤워 무서움", "line": "샤워 무서움: 발부터 적셔 주세요", "moment": "처음으로 무서워하지 않고 적신 날"},
	"dryer": {"name": "드라이 소리 예민", "line": "드라이 예민: 멀리서 켜고 천천히 다가가요", "moment": "처음으로 드라이를 끝까지 편하게 한 날"},
	"towel": {"name": "수건 무는 손님", "line": "수건을 물면 마우스를 좌우로 살살", "moment": "처음으로 수건 놀이를 한 날"},
}
## '처음 ~한 날' 기록 이름 (id → 글)
const MOMENTS := {
	"first": "처음 온 날",
	"mood_3": "처음 🤩 신난 날",
	"fav": "처음 좋아하는 곳을 찾은 날",
	"trust_1": "익숙해진 날",
	"trust_2": "친해진 날",
	"trust_3": "단짝이 된 날",
	"trim": "처음 미용한 날",
	"quirk_shower": "처음으로 무서워하지 않고 적신 날",
	"quirk_dryer": "처음으로 드라이를 끝까지 편하게 한 날",
	"quirk_towel": "처음으로 수건 놀이를 한 날",
	"acc_like": "처음 액세서리를 좋아한 날",
}
## 방문 기분 기록은 최근 이만큼만 (저장이 끝없이 커지지 않게)
const MOOD_LOG_MAX := 60


## 점수 → 단계 0~3
static func tier_of(points: int) -> int:
	var at: PackedInt32Array = Tuning.data.v4_trust_at
	var tier := 0
	for i in at.size():
		if points >= at[i]:
			tier = i + 1
	return tier


## 한 번 방문의 신뢰 점수: 왔음 + 돌려줄 때 기분 + 처음 좋아하는 곳 찾음
static func visit_points(face: int, fav_first: bool) -> int:
	var mood: PackedInt32Array = Tuning.data.v4_trust_mood
	return Tuning.data.v4_trust_visit + mood[clampi(face, 0, mood.size() - 1)] + (Tuning.data.v4_trust_fav_first if fav_first else 0)


## 같은 규칙 싫어함 사이 시간 (s): 낯가림 2, 익숙함부터 3
static func cooldown(tier: int) -> float:
	var times: PackedFloat32Array = Tuning.data.v4_trust_cooldown
	return times[0] if tier <= 0 else times[1]


## 규칙마다 싫어함 최대: 단짝이면 v4_trust_best_max (1)
static func max_per_rule(tier: int, normal: int) -> int:
	return mini(normal, Tuning.data.v4_trust_best_max) if tier >= 3 else normal


## 친함부터 성격이 한 단계 쉬워짐
static func ticklish_time(tier: int) -> float:
	return Tuning.data.v4_trust_ticklish_time if tier >= 2 else Tuning.data.v4_ticklish_time


static func timid_radius(tier: int) -> float:
	return Tuning.data.v4_trust_timid_radius if tier >= 2 else Tuning.data.v4_timid_face_radius


static func cat_wet_limit(tier: int) -> float:
	return Tuning.data.v4_trust_cat_wet_limit if tier >= 2 else Tuning.data.v4_cat_wet_limit


## 친함부터 고양이 머리에 물은 싫어함이 아님 (반응만)
static func cat_head_counts(tier: int) -> bool:
	return tier < 2


## 익숙함부터 좋아하는 곳 힌트(꼬리)가 넓어짐
static func fav_hint_radius(tier: int) -> float:
	return Tuning.data.v4_fav_hint_radius * (1.5 if tier >= 1 else 1.0)


## 드라이 예민: 켠 뒤 '가까이' 안으로 이 시간보다 빨리 오면 싫어함
static func dryer_approach(tier: int) -> float:
	var times: PackedFloat32Array = Tuning.data.v4_quirk_dryer_approach
	return times[1] if tier >= 2 else times[0]


## 수건 무는 손님: 톡 한 번에 물 확률 (단짝은 0, 놀이)
static func towel_bite_chance(tier: int) -> float:
	if tier >= 3:
		return 0.0
	var chances: PackedFloat32Array = Tuning.data.v4_quirk_towel_bite_chance
	return chances[1] if tier >= 2 else chances[0]


## 사진 한 장 정보 (첫 방문·최근 사진)
static func photo_info(day: int, mood: int, trim: String, wall: String, floor: String) -> Dictionary:
	return {"day": day, "mood": mood, "trim": trim, "wall": wall, "floor": floor}


## 사진첩 단골 칸의 빈 모양 (빠진 키는 이걸로 채움)
static func empty_entry(day: int) -> Dictionary:
	return {"visits": 0, "best_mood": -1, "day": day, "trim": "", "wall": "", "floor": "", "fav_found": false,
		"trust": 0, "trust_pts": 0, "first_day": day, "first": {}, "recent": {}, "moments": [], "moods": []}


## 그 기록이 있나
static func has_moment(entry: Dictionary, id: String) -> bool:
	for moment in entry.get("moments", []):
		if moment.get("id", "") == id:
			return true
	return false


## '처음 ~한 날' 하나 더함 (이미 있으면 그대로). 새로 더했으면 true
static func add_moment(entry: Dictionary, id: String, day: int) -> bool:
	if has_moment(entry, id):
		return false
	if not entry.has("moments"):
		entry["moments"] = []
	entry.moments.append({"id": id, "day": day})
	return true


## 단계별 단골 수 [낯가림, 익숙함, 친함, 단짝] (하루 결과 기록)
static func tier_counts(album: Dictionary) -> Array:
	var counts := [0, 0, 0, 0]
	for id in album:
		counts[clampi(int(album[id].get("trust", 0)), 0, 3)] += 1
	return counts
