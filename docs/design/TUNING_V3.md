# 수치표 V3 — 멍냥 목욕탕 (가게 운영 시뮬레이터판)

작성: 기획팀 · 2026-10-26 · 근거: [GDD_V3.md](GDD_V3.md)

- 리소스 하나: `res://data/balance/sim_balance.tres` (V2 `bath_balance.tres` 와 섞지 않음).
- 키 이름은 제안. 바꾸면 이 표도 같이 고침. **GDD_V3 와 다르면 이 표가 맞음.**
- **시제품** ✅ = GDD_V3 8장 첫 시제품에서 쓰는 값. 인원별 값은 `party_` 배열 `[1인, 2인, 3인, 4인]`.

## 1. 작업대 시점 (`seat_*`)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `seat_switch_time` | 0.4 | s | ✅ | 자리 옮길 때 카메라 이동 시간 |
| `seat_camera_fov` | 50 | ° | ✅ | 목욕대 자리 시야 (동물이 화면 가운데 크게) |
| `turntable_speed` | 180 | °/s | ✅ | 오른쪽 끌기 회전판 최대 속도 |
| `pad_cursor_speed` | 900 | px/s | ✅ | 패드 왼쪽 스틱 커서 속도 (1280×800 기준) |

## 2. 더러움 마스크 (`mask_*`, `stage_*`)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `mask_resolution` | 256 | px | ✅ | 동물 한 마리 마스크 크기 (256×256) — 개발팀이 성능 보고 조정 |
| `mask_patterns` | 3 | 종 | ✅ | 시제품 더러움 무늬 수 (정식판 8) |
| `stage_complete_ratio` | 0.85 | 비율 | ✅ | 칠한 비율이 이만큼이면 단계 끝 |
| `stage_remaining_blink` | 0.5 | s | ✅ | 마지막 15% 구역 반짝임 (단계가 85% 에 가까우면, `proto_blink_interval` 마다 되풀이) |
| `foam_ball_max` | 60 | 개 | ✅ | 몸에 붙는 거품 공 최대 |
| `foam_ball_per_scrub` | 3 | 개/s | ✅ | 문지르는 동안 늘어나는 속도 (마우스 속도 배율 곱함) |
| `wet_shader_amount` | 1.0 | 0~1 | ✅ | 젖음 셰이더 값 (진하고 반짝) |
| `fluff_shader_amount` | 1.0 | 0~1 | ✅ | 뽀송 셰이더 값 (부풀기, `tool_dryer_fluff_scale` 까지) |

## 3. 도구 (`tool_*`)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `tool_shower_radius` | 0.18 | m | ✅ | 물줄기가 닿는 반경 (마스크 붓 크기로 바꿔 씀) |
| `tool_shower_rate` | 1.2 | /s | ✅ | 붓이 한 자리에 머물 때 칠해지는 속도 (약 0.8초면 꽉 참) |
| `tool_shower_temp_good` | [0.35, 0.7] | 0~1 | ✅ | 다이얼에서 '좋음' 범위 |
| `tool_shampoo_dose` | 1 | 덩이 | ✅ | 병 클릭 한 번 = 거품 덩이 1 (몸의 약 1/4 을 문지를 수 있는 양) |
| `tool_shampoo_uses_per_bottle` | 8 | 마리 | ✅ | 한 병으로 씻는 손님 수 |
| `tool_scrub_radius` | 0.15 | m | ✅ | 손으로 문지르는 반경 |
| `tool_scrub_rate_per_speed` | 0.9 | /(m/s) | ✅ | 마우스를 빨리 움직일수록 거품이 빨리 (초당 진행 = 이 값 × 손 속도) |
| `tool_scrub_rate_max` | 1.5 | /s | ✅ | 진행 최대 |
| `tool_rinse_rate` | 1.0 | /s | ✅ | 헹구기 (샤워기 같은 판정) |
| `tool_towel_rate` | 1.0 | /s | ✅ | 수건 |
| `tool_dryer_range` | 0.5 | m | ✅ | 바람이 닿는 거리 |
| `tool_dryer_rate_near` | 1.2 | /s | ✅ | 0.15 m 이내 (너무 가까우면 기분 −) |
| `tool_dryer_rate_far` | 0.4 | /s | ✅ | 0.5 m |
| `tool_dryer_fluff_scale` | 2.0 | 배 | ✅ | 다 말리면 털 부풀기 목표값. 시제품은 모형 전체를 키우면 화면을 덮어서 이 값의 30% (1.3배)까지만 모형 크기로 씀 — 그래픽이 오면 셰이더로 털만 2배 (PR #29) |

**한 마리 목표 시간 (시제품)**: 적시기 약 25초 + 거품 약 35초 + 헹구기 약 25초 + 말리기 약 35초 ≈ **2분**. (90% 칠하기 + 돌리기·도구 바꾸기 시간. 플레이 테스트 Q3 보고 조정)

## 4. 기분 (`mood_*`)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `mood_start` | 0.7 | 0~1 | ✅ | 시작 기분 (😊 ≥ 0.66 > 😐 ≥ 0.33 > 😣) |
| `mood_cold_water` | −0.15 | /회 | ✅ | 차가운 물에 펄쩍 (한 번, 쿨타임 2초) |
| `mood_hot_water` | −0.05 | /s | ✅ | |
| `mood_good_water` | +0.02 | /s | ✅ | |
| `mood_eye_hit` | −0.1 | /회 | ✅ | 눈에 물·거품 |
| `mood_dryer_too_close` | −0.05 | /s | ✅ | `proto_dryer_near` 이내. 시제품의 Shift(0.1 m)는 빠르지만 이 감소가 붙음 (의도한 선택) |
| `tickle_time` | 3.0 | s | ✅ | 같은 곳(반경 0.15 m)을 이만큼 문지르면 다리 찰랑 |
| `shake_time` | 6.0 | s | ✅ | 이만큼이면 몸 털기 (거품이 화면에, 1.5초) |
| `escape_mood_threshold` | 0.1 | | | 이 밑이면 뛰어내리려 함 (다음 반복) |

## 5. 돈 (`money_*`, `shop_*`)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `money_wash_price` | 30 | 원(게임 돈) | ✅ | 목욕 요금 |
| `money_tip_by_mood` | [0, 5, 15] | | ✅ | 😣 / 😐 / 😊 |
| `money_scent_tip` | 10 | | ✅ | 요청한 향 샴푸를 썼을 때 (시제품: 복숭아 요청 손님이 3마리 중 1마리) |
| `shop_price_basic_shampoo` | 20 | | ✅ | 기본 샴푸 (8마리분). 시작할 때 1병 있음 |
| `shop_price_peach_shampoo` | 60 | | ✅ | 복숭아 샴푸 (8마리분, 분홍 거품) |
| `shop_start_money` | 0 | | ✅ | |

시제품 흐름: 2마리 씻기면 (30+15)×2 = 90 → 복숭아 샴푸(60) 살 수 있음 → 약 **4~5분 안에 첫 쇼핑**.

## 6. 하루·가게 (정식판, 시제품 아님)

| 키 | 값 | 설명 |
|---|---|---|
| `day_open_minutes_real` | 8 | 영업 9시~6시 = 실제 8분 |
| `day_total_minutes` | 10 | 준비 + 영업 + 정산·쇼핑 |
| `party_customers_per_day` | [5, 8, 11, 14] | 하루 손님 (혼자 약 1.6분/마리 업그레이드 뒤 기준) |
| `shop_level_max` | 8 | Lv8 = 펫 쇼 대회 |
| `days_to_first_clear` | 18 (혼자) / 15 (4인) | 목표값. 레벨 경험치 곡선으로 맞춤 |

## 7. 시제품 전용 (`proto_*`) — 개발팀이 정한 값 (PR #29, 기획팀 동의)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `proto_dose_coverage` | 0.25 | 비율 | ✅ | 거품 한 덩이로 문지를 수 있는 몸 비율 |
| `proto_cold_cooldown` | 2.0 | s | ✅ | 차가운 물 펄쩍 쿨타임 |
| `proto_eye_cooldown` | 3.0 | s | ✅ | 눈에 물·거품 쿨타임 (처음 1초 → QA 측정에서 너무 가혹해 3초) |
| `proto_tickle_radius` | 0.15 | m | ✅ | 간지럼 판정의 '같은 곳' 반경 |
| `proto_dryer_near` | 0.15 | m | ✅ | 드라이어 '너무 가까움' 거리 (보통 0.35 m, Shift 0.1 m) |
| `proto_shake_screen_time` | 1.5 | s | ✅ | 몸 털기 때 화면에 거품이 보이는 시간 |
| `proto_peach_request_chance` | 0.34 | 비율 | ✅ | 복숭아 향을 요청하는 손님 비율 (3마리 중 1마리) |
| `proto_next_dog_delay` | 1.0 | s | ✅ | 동전을 다 주운 뒤 다음 손님까지 |
| `proto_blink_interval` | 1.5 | s | ✅ | 거의 다 됐을 때 남은 곳 반짝임을 되풀이하는 간격 |
| `proto_water_drops` | 70 | 개 | ✅ | 헹군 뒤 몸에 맺히는 물방울 수 |

시제품에서 정한 규칙 (PR #29 PROTOTYPE.md 8장, 기획팀 동의): 요청 카드는 다섯 줄(적시기·거품·헹구기·수건·드라이어), 샤워기는 적시기·헹구기 단계에서만 칠함, 배 밑(몸 표면 약 20%)은 진행 비율에서 뺌, 기분 팁은 계산 때 얼굴로.

## 8. 시제품 1 두 번째 반복 (GDD_V3 8.1-2) — 새 키 초안

> **'시제품' 칸을 ✅ 로 하지 않았음**: `test_balance` 가 ✅ 줄을 리소스와 대조하므로, 개발팀이 리소스에 넣을 때 ✅ 로 바꾸고 값을 확정해 주세요.

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `stage_target_seconds` | [12, 3, 15, 10, 10, 15] | s | 1-2 | 단계별 목표 시간: 적시기·샴푸 짜기·문지르기·헹구기·수건·드라이어 (합 약 65초). 붓 크기·속도는 이 시간에 맞춰 개발팀이 조정 |
| `squeeze_max_time` | 1.5 | s | 1-2 | 샴푸 병을 이만큼 누르면 덩이 최대 |
| `squeeze_coverage_max` | 0.6 | 비율 | 1-2 | 최대 덩이로 문지를 수 있는 몸 비율 (0.3 이면 적당, 넘으면 넘쳐 흐름 = 샴푸 낭비) |
| `squeeze_overflow_at` | 0.4 | 비율 | 1-2 | 이보다 많이 짜면 거품이 흘러내리고 병 사용 횟수 1 더 씀 |
| `scrub_circle_min_angle` | 270 | ° | 1-2 | 원 그리기로 인정하는 최소 누적 각도 (한 바퀴 조금 안 됨) |
| `scrub_back_forth_rate` | 0.2 | 배 | 1-2 | 원이 아닌 왕복 문지르기의 거품 속도 배율 (거의 안 큼) |
| `rinse_pour_min_drag` | 0.25 | 화면 높이 비율 | 1-2 | 위→아래로 이만큼 끌어야 바가지가 쏟아짐 |
| `rinse_pour_band_width` | 0.3 | m | 1-2 | 한 번 쏟을 때 씻기는 띠 폭 (3~4번에 끝) |
| `towel_press_area` | 0.12 | m | 1-2 | 한 번 꾹 누를 때 닦이는 반경 |
| `towel_press_cooldown` | 0.12 | s | 1-2 | 연타 최소 간격 (초당 약 8번까지) |
| `dryer_distance_range` | [0.08, 0.5] | m | 1-2 | 휠로 바꾸는 거리 범위 (0.15 m 밑은 기분 −, `proto_dryer_near`) |
| `dryer_wheel_step` | 0.04 | m | 1-2 | 휠 한 칸 |
| `auto_turn_visible_ratio` | 0.85 | 비율 | 1-2 | 보이는 쪽이 이만큼 되면 강아지가 저절로 돎 |
| `auto_turn_time` | 1.2 | s | 1-2 | 도는 시간 |
| `owner_variants` | 6 | 종 | 1-2 | 주인 모양 (모자·옷 색) |
| `owner_reaction_time` | 2.5 | s | 1-2 | 끝나고 주인 반응 연출 길이 |
| `dog_look_owner_interval` | [3, 6] | s | 1-2 | 강아지가 주인 쪽을 보는 간격 (무작위) |

## 9. 수직 단면 (`slice_*`) — 초안 ([MILESTONE_V3_SLICE.md](MILESTONE_V3_SLICE.md))

> 8장처럼 ✅ 없이 초안. 개발팀이 리소스에 넣을 때 ✅ 로.

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `slice_days` | 3 | 일 | 단면 | |
| `slice_guests_per_day` | [4, 5, 6] | 명 | 단면 | 1·2·3일차 |
| `slice_queue_seats` | 3 | 자리 | 단면 | 대기 의자 |
| `slice_owner_patience` | 150 | s | 단면 | 의자에 앉아서 떠나기까지 (창가 화분 있으면 ×1.2) |
| `slice_cat_price` | 45 | 돈 | 단면 | 고양이 요금 (강아지 `money_wash_price` 30) |
| `slice_cat_temp_good` | [0.45, 0.6] | 0~1 | 단면 | 고양이 온도 '좋음' 범위 |
| `slice_timid_temp_good` | [0.5, 0.6] | 0~1 | 단면 | 겁쟁이 온도 '좋음' 범위 |
| `slice_price_wide_shower` | 150 | 돈 | 단면 | 넓은 샤워기 |
| `slice_wide_shower_mult` | 1.5 | 배 | 단면 | 적시기·헹구기 붓 반경 |
| `slice_price_plant` | 80 | 돈 | 단면 | 창가 화분 |
| `slice_plant_patience_mult` | 1.2 | 배 | 단면 | |

## 바꾼 기록

| 날짜 | 키 | 전 → 후 | 이유 |
|---|---|---|---|
| 2026-10-26 | (최초 작성) | — | GDD_V3 0.1 |
| 2026-10-26 | 1·2장 | 1인칭·부위 12개 → 작업대 시점 `seat_*`·더러움 마스크 `mask_*`·`stage_complete_ratio` 0.9 | 개발팀 제안 + 대표 의견 (GDD_V3 0.2) |
| 2026-10-26 | 7장 `proto_*` 8개, `tool_dryer_fluff_scale`·`mood_dryer_too_close` 설명 | (새로) / 값은 그대로 | 시제품 1 PR #29 |
| 2026-10-26 | 2·3장 | `stage_complete_ratio` 0.9 → 0.85, `tool_shower_radius` 0.12 → 0.18, `tool_scrub_radius` 0.10 → 0.15 (한 단계 약 20초. QA #29 측정: 적시기 90초에 86%) | 대표 요청, 개발팀 측정 (`tests/game/test_wash_pace`) |
| 2026-10-26 | `proto_eye_cooldown`, 7장 새 키 | 1.0 → 3.0, `proto_blink_interval` 1.5·`proto_water_drops` 70 (새로) | QA #29 측정 (눈 벌점이 너무 잦음), 대표 요청 (남은 곳 반짝 되풀이, 수건 물방울) |
| 2026-10-26 | 8장 (새로, 초안) | — | 플레이 테스트 3: 단계마다 다른 손동작·한 손 조작·주인 손님 (GDD_V3 0.3) |
| 2026-10-26 | 9장 `slice_*` (새로, 초안) | — | 수직 단면 범위 (MILESTONE_V3_SLICE) |
