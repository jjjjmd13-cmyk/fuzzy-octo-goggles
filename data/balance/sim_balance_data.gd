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
@export var tool_shower_radius := 0.24
@export var tool_shower_rate := 1.2
## 온도 다이얼 '좋음' 범위 [최소, 최대] (0~1)
@export var tool_shower_temp_good := PackedFloat32Array([0.35, 0.7])
@export var tool_shampoo_dose := 1
@export var tool_shampoo_uses_per_bottle := 8
@export var tool_scrub_radius := 0.2
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

@export_group("두 번째 반복 (TUNING_V3 8장)")
## 단계별 목표 시간: 적시기·샴푸 짜기·문지르기·헹구기·수건·드라이어 (s)
@export var stage_target_seconds := PackedFloat32Array([12, 3, 15, 10, 10, 15])
## 샴푸 병을 이만큼 누르면 덩이 최대 (s)
@export var squeeze_max_time := 1.5
## 최대 덩이로 문지를 수 있는 몸 비율
@export var squeeze_coverage_max := 0.6
## 이보다 많이 짜면 거품이 흘러내리고 병 사용 횟수 1 더 씀 (비율)
@export var squeeze_overflow_at := 0.4
## 원 그리기로 인정하는 최소 누적 각도 (°)
@export var scrub_circle_min_angle := 270.0
## 원이 아닌 왕복 문지르기의 거품 속도 배율
@export var scrub_back_forth_rate := 0.2
## 위→아래로 이만큼(화면 높이 비율) 끌어야 바가지가 쏟아짐
@export var rinse_pour_min_drag := 0.25
## 한 번 쏟을 때 씻기는 띠 폭 (m)
@export var rinse_pour_band_width := 0.3
## 수건 한 번 누를 때 닦이는 반경 (m)
@export var towel_press_area := 0.12
## 수건 연타 최소 간격 (s)
@export var towel_press_cooldown := 0.12
## 드라이어 거리 범위 (m)
@export var dryer_distance_range := PackedFloat32Array([0.08, 0.5])
## 드라이어 휠 한 칸 (m)
@export var dryer_wheel_step := 0.04
## 보이는 쪽이 이만큼 되면 강아지가 저절로 돎
@export var auto_turn_visible_ratio := 0.85
## 저절로 도는 시간 (s)
@export var auto_turn_time := 1.2
## 주인 모양 수
@export var owner_variants := 6
## 끝나고 주인 반응 연출 길이 (s)
@export var owner_reaction_time := 2.5
## 강아지가 주인 쪽을 보는 간격 (s, 무작위)
@export var dog_look_owner_interval := PackedFloat32Array([3, 6])

@export_group("두 번째 반복 임시 값 (개발팀)")
## 주인이 강아지를 안고 들어와 내려놓기까지 (s)
@export var proto_owner_arrive_time := 2.5
## 강아지가 주인에게 달려가고 주인이 나가기까지 (s)
@export var proto_owner_leave_time := 1.5
## 물 온도 휠 한 칸
@export var proto_temp_wheel_step := 0.1
## 드라이어 처음 거리 (m)
@export var proto_dryer_start_distance := 0.32
## 저절로·화살표로 한 번에 도는 각도 (°)
@export var proto_turn_step := 90.0

## 손님이 문밖에 줄을 서기 전까지 차례로 도착하는 간격 = 영업 시간 × 이 값 / 그날 손님 수
@export var proto_guest_spacing := 0.85

@export_group("수직 단면 (TUNING_V3 6·9장)")
## 영업 9시~6시 = 실제 이 분 (벽시계)
@export var day_open_minutes_real := 8.0
@export var slice_days := 3
## 1·2·3일차 손님 수
@export var slice_guests_per_day := PackedInt32Array([4, 5, 6])
## 대기 의자 수 (꽉 차면 문밖에 줄)
@export var slice_queue_seats := 3
## 기다리기 시작해서 떠나기까지 (s)
@export var slice_owner_patience := 150.0
## 고양이 요금 (강아지는 money_wash_price)
@export var slice_cat_price := 45
## 고양이 / 겁쟁이 물 온도 '좋음' 범위 (0~1)
@export var slice_cat_temp_good := PackedFloat32Array([0.45, 0.6])
@export var slice_timid_temp_good := PackedFloat32Array([0.5, 0.6])
## 넓은 샤워기 (도구 업그레이드): 값, 적시기 샤워기·헹구기 바가지 띠 배수
@export var slice_price_wide_shower := 150
@export var slice_wide_shower_mult := 1.5
## 창가 화분 (꾸미기): 값, 대기 손님 참을성 배수
@export var slice_price_plant := 80
@export var slice_plant_patience_mult := 1.2

@export_group("수직 단면 임시 값 (개발팀)")
## 2일차부터 손님이 고양이일 비율
@export var proto_cat_chance := 0.4
## 성격이 열린 날 손님이 성격을 가질 비율
@export var proto_trait_chance := 0.5
## 고양이: 젖어 있는 동안 (적시기 ~ 수건) 초당 기분
@export var proto_cat_wet_mood := -0.0012
## 고양이: 바가지를 머리에 쏟으면 기분
@export var proto_cat_pour_head_mood := -0.06
## 고양이: 머리에 바가지 벌점은 한 손님에 이만큼만 (그 뒤엔 부르르 반응만)
@export var proto_cat_pour_head_max := 1
## 겁쟁이: 눈에 물 벌점 배수
@export var proto_timid_eye_mult := 2.0
## 간지럼쟁이: 배·발을 이만큼 문지르면 다리 찰랑 (s) + 기분
@export var proto_ticklish_time := 0.6
@export var proto_ticklish_mood := -0.03
## 간지럼쟁이: 찰랑 벌점 사이 최소 시간 (s), 한 손님 간지럼 벌점 합계 최대
@export var proto_ticklish_cooldown := 2.0
@export var proto_ticklish_mood_cap := 0.1
## 샴푸가 떨어져 물로만 씻으면 기분 (진행은 막히지 않음)
@export var proto_no_shampoo_mood := -0.25


@export_group("V4 1인칭 시제품 (GDD_V4 0.2)")
## 단계 완료 기준: 칠한 비율 (씻는 시간 제한은 없음, 빨리 할수록 좋을 뿐)
@export var v4_done_ratio := 0.8
## 붓 크기: 한 번에 칠하는 몸 겉면 비율 (0.2 = 몸의 약 1/5)
@export var v4_brush_share := 0.2
## 도구를 대고 있는 동안 초당 칠하는 양 (붓 가운데 기준, 1 = 한 번에 다 참)
@export var v4_rate_shower := 2.5
@export var v4_rate_shampoo := 2.2
@export var v4_rate_dryer := 2.0
## 단계마다 손동작 (TUNING_V4 3-2, GDD_V4 손동작 다시 정리): 서툴러도 진행, 잘 맞으면 빨라짐
## 거품: 이 속도(m/s) 이상으로 비비면 거품이 커짐 / 빗질: 뭉치 풀리는 쓸기 수 [아무 방향, 털 방향(위→아래)]
@export var v4_foam_rub_speed := 0.3
@export var v4_brush_strokes := PackedInt32Array([3, 2])
## (개발 임시값) 손동작 배수 [서툴 때, 잘 맞을 때] — 거품 비비기·헹굼 쓸어내리기
@export var v4_gesture_mult := PackedFloat32Array([0.6, 1.8])
## (개발 임시값) 헹굼: 이 속도(m/s) 로 아래로 쓸면 가장 빠름
@export var v4_rinse_down_speed := 0.3
## (개발 임시값) 빗질: 쓸기 한 번 길이 (m), 대고만 있을 때 초당 풀리는 양
@export var v4_brush_stroke_len := 0.08
@export var v4_brush_hold_rate := 0.25
## (개발 임시값) 드라이: [너무 붙음(찡그림), 이보다 멀면 가장 느림] (m, 눈에서 겨눈 점까지), 속도 배수 [멀 때, 가까울 때]
@export var v4_dryer_near := PackedFloat32Array([0.35, 1.6])
@export var v4_dryer_mult := PackedFloat32Array([0.5, 1.8])
## 수건 톡 한 번에 닦이는 양 (TUNING_V4 3-2, 기본 수건 2~4초 = 약 10번)
@export var v4_rate_towel_tap := 0.25
## 빗질: 드라이가 끝나면 보이는 엉킨 털 뭉치 수, 뭉치 하나를 푸는 속도 (/s, 1 이면 1초 대면 풀림)
@export var v4_tangles := 6
@export var v4_rate_brush := 2.5
## 미용 (TUNING_V4 3-1): 가위 값, 미용 추가 요금, 가위를 산 뒤 요청 손님 비율, 모양 팁 [안 비슷 / 비슷 / 똑같음]
@export var v4_price_scissors := 250
@export var v4_price_trim := 40
@export var v4_trim_request_ratio := 0.25
@export var v4_trim_match_tip := PackedInt32Array([0, 10, 25])
## 모양 비슷함 기준 [비슷함, 똑같음] (0~1, 자를 곳을 자른 비율 − 잘못 자른 수×0.5/자를 곳 수), 다발 자르는 속도 (/s)
@export var v4_trim_match_at := PackedFloat32Array([0.7, 0.95])
@export var v4_rate_trim := 3.0

## 대기 손님 참을성 (s, TUNING_V4 2장): 대기 의자에서 이만큼 기다리면 "다음에 올게요" 하고 떠남
@export var v4_patience_hurry := 60.0
@export var v4_patience_normal := 150.0
@export var v4_patience_relaxed := 300.0
## 끝까지 손님 (0 = 안 떠남)
@export var v4_patience_forever := 0.0
## 성격 나올 비율: 급함·보통·느긋·끝까지
@export var v4_patience_mix := PackedFloat32Array([0.2, 0.45, 0.25, 0.1])
## 시제품을 켜자마자 오는 손님 (느긋한 1명으로 차분히 시작, 사람 대표 피드백). 그 뒤로는 v4_guest_every 마다 비율대로
@export var v4_first_guests: Array[String] = ["relaxed"]
## 새 손님이 오는 간격 (s, 대기 의자 3개가 다 차면 안 옴, 개발 임시값)
@export var v4_guest_every := 45.0
## 가게를 연 뒤 이 시간(s) 동안은 급한 손님이 안 나옴
@export var v4_hurry_after := 120.0
## 시제품 2 하루 (TUNING_V4 3장): 목욕 요금, 기분 팁 [😣, 😐, 😊]
@export var v4_price_wash := 40
@export var v4_tip_mood := PackedInt32Array([0, 5, 15])
## 빠른 서비스 팁: 손님이 들어온 뒤 돌려받기까지 v4_fast_times[0] 초 안 / [1] 초 안 / 그 뒤
@export var v4_tip_fast := PackedInt32Array([15, 5, 0])
@export var v4_fast_times := PackedFloat32Array([60, 120])
## 급한 손님은 빠른 팁 배수
@export var v4_tip_fast_hurry_mult := 2.0
## 하루 영업 (분, 9시~6시)
@export var v4_day_minutes := 8.0
## 도구 키우기 (TUNING_V4 3-2): 샤워기·거품·수건·드라이·빗 모두 5단계, 단계별 칠하는 속도 배수 (붓도 조금 커짐), 값 (0 = 처음부터 있음)
@export var v4_tool_tiers := 5
@export var v4_tool_speed_mult5 := PackedFloat32Array([1.0, 1.3, 1.6, 2.0, 2.6])
@export var v4_tool_price5 := PackedInt32Array([0, 120, 250, 450, 800])
## 샴푸·빗 닳음 (TUNING_V4 3-5): 처음 가진 샴푸 (마리분). 저장·이어하기에서 처음 값으로 씀, 소모 규칙은 다음 PR
@export var v4_shampoo_start := 20
@export var v4_shampoo_bottle := 20
@export var v4_shampoo_bottle_price := 80
@export var v4_shampoo_big := 50
@export var v4_shampoo_big_price := 180
## 거품 도구 단계별 한 마리에 쓰는 샴푸 (마리분)
@export var v4_shampoo_use5 := PackedFloat32Array([1.0, 1.0, 0.75, 0.75, 0.5])
## 샴푸 없이 씻긴 요금 (팁 0)
@export var v4_no_shampoo_price := 10
@export var v4_shampoo_warn_at := 5
@export var v4_shampoo_alert_at := 3
## 빗 단계별 수명 (마리, 0 = 안 닳음), 남은 수명이 이 비율 아래면 느려지기 시작, 수명 0 일 때 빗질 속도
@export var v4_brush_life5 := PackedInt32Array([30, 60, 120, 0, 0])
@export var v4_brush_worn_from := 0.5
@export var v4_brush_worn_mult := 0.7
## 새 빗살 값 (0 = 가게에 안 보임)
@export var v4_brush_refill_price5 := PackedInt32Array([20, 30, 50, 0, 0])
## 가게 꾸미기 (TUNING_V4 3-3): 값 [★1, ★2, ★3] (작은 것·큰 것), 아늑함 ★, ★ 하나당 참을성 배수, 최대
@export var v4_decor_price_small := PackedInt32Array([40, 100, 200])
@export var v4_decor_price_big := PackedInt32Array([80, 180, 350])
@export var v4_decor_points := PackedInt32Array([1, 2, 3])
@export var v4_decor_patience_per_point := 0.01
@export var v4_decor_patience_max := 0.3
## 가게 밖·택배 (TUNING_V4 3-4): 아침 시작 뒤 트럭이 와서 떠나기까지 (s), 상자를 들고 걷는 속도 [작은, 중간, 큰]
@export var v4_truck_seconds := 4.0
@export var v4_box_carry_speed := PackedFloat32Array([1.0, 0.9, 0.75])

## 기분 0~1 → 얼굴 단계 0(😣) / 1(😐) / 2(😊)
func mood_face(mood: float) -> int:
	if mood >= 0.66:
		return 2
	if mood >= 0.33:
		return 1
	return 0
