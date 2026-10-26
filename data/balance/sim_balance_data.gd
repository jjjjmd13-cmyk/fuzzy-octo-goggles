extends Resource
## 멍냥 목욕탕 V3 (가게 운영 시뮬레이터) 수치. docs/design/TUNING_V3.md 키 이름 그대로.
## 기획팀은 data/balance/sim_balance.tres 값만 고친다. "proto_" 키는 TUNING_V3 에 없는 개발팀 임시 값.

@export_group("작업대 시점")
@export var seat_switch_time := 0.4
@export var seat_camera_fov := 50.0
## 오른쪽 끌기 회전판 최대 속도 (°/s)
@export var turntable_speed := 180.0
## 패드 왼쪽 스틱 커서 속도 (px/s, 1280×800 기준)
@export var pad_cursor_speed := 900.0

@export_group("더러움 마스크")
@export var mask_resolution := 256
@export var mask_patterns := 3
@export var stage_complete_ratio := 0.85
@export var stage_remaining_blink := 0.5
@export var foam_ball_max := 60
## 문지르는 동안 늘어나는 거품 공 (개/s, 손 속도 배율 곱함)
@export var foam_ball_per_scrub := 3.0
@export var wet_shader_amount := 1.0
@export var fluff_shader_amount := 1.0

@export_group("도구")
@export var tool_shower_radius := 0.18
@export var tool_shower_rate := 1.2
## 온도 다이얼 '좋음' 범위 [최소, 최대] (0~1)
@export var tool_shower_temp_good := PackedFloat32Array([0.35, 0.7])
@export var tool_shampoo_dose := 1
@export var tool_shampoo_uses_per_bottle := 8
@export var tool_scrub_radius := 0.15
## 초당 진행 = 이 값 × 손 속도 (m/s)
@export var tool_scrub_rate_per_speed := 0.9
@export var tool_scrub_rate_max := 1.5
@export var tool_rinse_rate := 1.0
@export var tool_towel_rate := 1.0
@export var tool_dryer_range := 0.5
@export var tool_dryer_rate_near := 1.2
@export var tool_dryer_rate_far := 0.4
@export var tool_dryer_fluff_scale := 2.0

@export_group("기분")
@export var mood_start := 0.7
@export var mood_cold_water := -0.15
@export var mood_hot_water := -0.05
@export var mood_good_water := 0.02
@export var mood_eye_hit := -0.1
@export var mood_dryer_too_close := -0.05
@export var tickle_time := 3.0
@export var shake_time := 6.0

@export_group("돈")
@export var money_wash_price := 30
## [😣, 😐, 😊]
@export var money_tip_by_mood := PackedInt32Array([0, 5, 15])
@export var money_scent_tip := 10
@export var shop_price_basic_shampoo := 20
@export var shop_price_peach_shampoo := 60
@export var shop_start_money := 0

@export_group("개발팀 임시 (TUNING_V3 에 없음)")
## 거품 덩이 하나로 문지를 수 있는 몸의 비율 (GDD: 약 1/4)
@export var proto_dose_coverage := 0.25
## 차가운 물 펄쩍 쿨타임 (s) — TUNING_V3 mood_cold_water 설명의 "쿨타임 2초"
@export var proto_cold_cooldown := 2.0
## 눈에 물·거품 쿨타임 (s)
@export var proto_eye_cooldown := 3.0
## 같은 곳으로 보는 반경 (m) — TUNING_V3 tickle_time 설명의 "반경 0.15 m"
@export var proto_tickle_radius := 0.15
## 드라이어 '너무 가까움' 거리 (m) — TUNING_V3 tool_dryer_rate_near 설명의 "0.15 m"
@export var proto_dryer_near := 0.15
## 몸 털기 때 화면 거품 시간 (s) — TUNING_V3 shake_time 설명의 "1.5초"
@export var proto_shake_screen_time := 1.5
## 복숭아 향을 원하는 손님 비율 — TUNING_V3 money_scent_tip 설명의 "3마리 중 1마리"
@export var proto_peach_request_chance := 0.34
## 끝난 뒤 다음 강아지가 오기까지 (s, 동전을 다 주운 뒤)
@export var proto_next_dog_delay := 1.0
## 거의 다 됐을 때(완료 비율 − 0.1 이상) 남은 곳 반짝임을 이 간격으로 되풀이 (s)
@export var proto_blink_interval := 1.5
## 헹구기가 끝나면 몸에 붙는 물방울 수 (수건·드라이어로 닦은 곳부터 사라짐)
@export var proto_water_drops := 70


## 기분 0~1 → 얼굴 단계 0(😣) / 1(😐) / 2(😊)
func mood_face(mood: float) -> int:
	if mood >= 0.66:
		return 2
	if mood >= 0.33:
		return 1
	return 0
