# 수치표 (밸런스 리소스 초기값)

작성: 기획팀 · 2026-10-25 (갱신 2026-10-26) · 근거: [GDD.md](GDD.md) 5~8장, 10장

GDD 의 수치는 장마다 흩어져 있어서, 개발팀이 리소스(`.tres`)로 바로 옮길 수 있게 **키 이름·단위·초기값**으로 한 곳에 모았습니다.
**GDD 와 이 표가 다르면 이 표가 맞습니다** (수치를 고칠 때는 이 표를 먼저 고치고 GDD 를 따라 고침).

- 키 이름은 제안입니다 (`snake_case`). 개발팀이 바꿔도 되지만 바꾸면 이 표도 같이 고쳐 주세요.
- 단위: 거리 m, 시간 초(s), 속도 m/s, 기름 '단위'(최대 100).
- **시제품** 열 ✅ = GDD 13장 시제품에서 바로 쓰는 값. 나머지는 단계 2 이후.
- 리소스 위치 제안: `res://data/balance/balance.tres` (스크립트 `BalanceData extends Resource`) **하나** (시제품에서 실제로 이렇게 만듦). 인원별 표도 같은 파일에 `party_` 배열로 (7장).

---

## 1. 등불·빛 (`light_*`)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `light_lantern_radius_low` | 3.0 | m | ✅ | 큰 등불 낮춤 반경 |
| `light_lantern_radius_normal` | 5.0 | m | ✅ | 큰 등불 보통 반경 (기본 단계) |
| `light_lantern_radius_high` | 8.0 | m | ✅ | 큰 등불 키움 반경 |
| `light_lantern_drain_low` | 2.0 | 기름/분 | ✅ | |
| `light_lantern_drain_normal` | 4.0 | 기름/분 | ✅ | |
| `light_lantern_drain_high` | 8.0 | 기름/분 | ✅ | |
| `light_lantern_default_level` | 1 | 0/1/2 | ✅ | 0=낮춤, 1=보통, 2=키움 |
| `light_handlamp_radius` | 2.0 | m | ✅ | 손등 반경 |
| `light_handlamp_drain` | 0.5 | 기름/분 | ✅ | 켰을 때만, 1개당 |
| `light_wick_radius` | 1.5 | m | ✅ | 기름 0 뒤 '심지' 빛 |
| `light_wick_duration` | 60.0 | s | ✅ | |
| `light_low_oil_threshold` | 20.0 | 기름 | ✅ | 이하면 깜빡임 + 최대 단계 '보통' 제한 |
| `light_flash_radius` | 12.0 | m | | 섬광 (등불지기) |
| `light_flash_duration` | 2.0 | s | | |
| `light_flash_cost` | 10.0 | 기름 | | |
| `light_flash_cooldown` | 20.0 | s | | 팀 공유 |
| `light_keeper_drain_mult` | 0.75 | 배 | | 등불지기가 들 때 큰 등불 소모 |
| `light_placed_lamp_radius` | 4.0 | m | | 설치 램프 |
| `light_placed_lamp_duration` | 90.0 | s | | |
| `light_placed_lamp_cost` | 15.0 | 기름 | | |
| `light_placed_lamp_per_floor` | 2 | 회 | | 만능 대원은 `solo_placed_lamp_per_floor` |
| `light_oil_well_radius` | 3.0 | m | | 기름 샘 방 |
| `light_start_room_radius` | 4.0 | m | | 시작방(엘리베이터) |
| `light_shard_radius` | 2.0 | m | | 빛의 파편을 들고 있을 때 |

> 빛 판정: 플레이어 위치와 빛 위치의 **수평 거리 ≤ 반경** 이고, **빛에서 플레이어까지 벽에 가리지 않으면** '빛 안' (GDD 5.1, 2026-10-26 추가). 레이캐스트 1개면 충분 (판정은 호스트 10 Hz). 추적자의 '빛 안으로 못 들어감'도 같은 판정.

## 2. 기름 (`oil_*`)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `oil_max` | 100.0 | 기름 | ✅ | 캠프 강화 시 `oil_max_upgraded` |
| `oil_max_upgraded` | 130.0 | 기름 | | 큰 기름통 |
| `oil_start` | 100.0 | 기름 | ✅ | `party_oil_start`(7장)가 있으면 그 값 우선 |
| `oil_bottle_amount` | 15.0 | 기름 | ✅ | 줍는 기름병 (시제품: 방에 1~2개 둠) |
| `oil_well_amount` | 25.0 | 기름 | | 샘당 1회 |
| `oil_shop_bottle_limit` | 3 | 병 | | 원정당 |
| `oil_revive_cost` | 5.0 | 기름 | ✅ | |
| `oil_tick_interval` | 0.5 | s | ✅ | 호스트가 기름을 깎고 클라이언트에 보내는 주기 |

## 3. 어둠 게이지 (`dark_*`)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `dark_max` | 100.0 | | ✅ | |
| `dark_gain_unlit` | 5.0 | /s | ✅ | 어떤 빛에도 없음 |
| `dark_gain_handlamp_only` | 1.0 | /s | ✅ | 손등(2 m) 안에만 있음 |
| `dark_decay_lit` | 10.0 | /s | ✅ | 큰 등불·설치 램프·샘·시작방 안 (감소량) |
| `dark_scout_gain_mult` | 0.5 | 배 | | 정찰꾼 |
| `dark_no_oil_gain_mult` | 2.0 | 배 | ✅ | 심지까지 꺼진 완전한 어둠 |
| `dark_stalk_threshold` | 30.0 | | ✅ | 이상이면 추적 후보 |
| `dark_stalk_release_threshold` | 30.0 | | ✅ | 이 미만이 `stalker_lose_interest_time` 지속되면 포기 |
| `dark_full_hunt` | 100.0 | | ✅ | 같은 층 추적자가 거리 무시하고 옴 |

## 4. 플레이어·쓰러짐 (`player_*`, `down_*`)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `player_walk_speed` | 4.0 | m/s | ✅ | |
| `player_run_speed` | 6.0 | m/s | ✅ | |
| `player_stamina` | 5.0 | s | ✅ | 달리기 최대 시간 |
| `player_stamina_regen_delay` | 3.0 | s | ✅ | 쉬고 나서 회복 시작 |
| `player_stamina_regen_rate` | 1.0 | s/s | ✅ | 1초에 1초분 회복 |
| `player_carry_slots` | 2 | 칸 | | 직업 없음 기준 |
| `player_heavy_carry_pair_speed` | 3.0 | m/s | | 무거운 유물 2인 운반 |
| `player_trap_disarm_time` | 8.0 | s | | 직업 없음 |
| `down_duration` | 30.0 | s | ✅ | 이 안에 부활 못 하면 기절 |
| `down_crawl_speed` | 1.0 | m/s | ✅ | |
| `down_revive_time` | 3.0 | s | ✅ | 큰 등불 반경 안에서 상호작용 유지 |
| `down_revive_health` | 0.5 | 비율 | ✅ | 시제품은 체력 없음 → 무시 가능 |
| `solo_last_ember_delay` | 5.0 | s | | 마지막 불씨 자동 부활 |
| `solo_last_ember_cost` | 15.0 | 기름 | | |
| `solo_last_ember_count` | 1 | 회 | | |

## 5. 그림자 추적자 (`stalker_*`)

| 키 | 값 | 단위 | 시제품 | 설명 |
|---|---|---|---|---|
| `stalker_think_hz` | 10 | Hz | ✅ | 판단 주기 (호스트) |
| `stalker_sync_hz` | 20 | Hz | ✅ | 위치 동기화 |
| `stalker_idle_time_min` | 3.0 | s | ✅ | |
| `stalker_idle_time_max` | 8.0 | s | ✅ | |
| `stalker_wander_speed` | 2.5 | m/s | ✅ | |
| `stalker_stalk_speed` | 3.5 | m/s | ✅ | |
| `stalker_flee_speed` | 5.0 | m/s | ✅ | |
| `stalker_detect_range` | 20.0 | m | ✅ | 추적 후보를 찾는 거리 |
| `stalker_attack_range` | 1.5 | m | ✅ | |
| `stalker_attack_windup` | 0.8 | s | ✅ | 준비 동작 (반응할 틈) |
| `stalker_light_flee_time` | 0.5 | s | ✅ | 빛에 이만큼 걸치면 후퇴 |
| `stalker_flee_duration` | 4.0 | s | ✅ | |
| `stalker_flash_flee_duration` | 8.0 | s | | 섬광 맞았을 때 |
| `stalker_lose_interest_time` | 5.0 | s | ✅ | |
| `stalker_no_oil_speed_mult` | 1.5 | 배 | ✅ | 완전한 어둠일 때 |
| `stalker_ignores_handlamp` | true | bool | ✅ | 손등 빛은 무시하고 들어옴 |
| `stalker_blocks_players` | true | bool | ✅ | 추적자 몸이 플레이어를 막음 (통과 못 함) — 2026-10-26 추가 |
| `stalker_touch_attack` | true | bool | ✅ | 빛 밖에서 닿으면 상태와 상관없이 바로 공격 준비 — 2026-10-26 추가 |
| `stalker_relic_noise` | true | bool | ✅ | 유물을 들면 가장 가까운 추적자가 그 위치로 추적 속도로 옴 (GDD 5.4) — 2026-10-26 추가 |

## 6. 기름 도둑 (`leech_*`) — 시제품 제외

| 키 | 값 | 단위 | 설명 |
|---|---|---|---|
| `leech_detect_light_range` | 15.0 | m | 큰 빛을 알아채는 거리 |
| `leech_detect_bottle_range` | 10.0 | m | 바닥 기름병 |
| `leech_detect_shard_range` | 25.0 | m | 빛의 파편을 든 사람 (GDD 11.1 "15 m 밖에서도") |
| `leech_speed` | 3.0 | m/s | |
| `leech_edge_offset` | 0.5 | m | 빛 반경 + 이 값에 붙음 |
| `leech_drain_rate` | 1.0 | 기름/s | 무리 하나당 |
| `leech_steal_time` | 2.0 | s | 기름병 없애기 |
| `leech_flee_duration` | 6.0 | s | |
| `leech_swarm_size_min` | 3 | 마리 | 모형 수 (연출) |
| `leech_swarm_size_max` | 5 | 마리 | |

## 7. 인원별 조절 (`party_*`)

같은 `balance.tres` 안에 **`party_` 로 시작하는 배열**로 둔다. 순서는 `[1인, 2인, 3인, 4인]` (`PackedFloat32Array`, 개수 값도 실수로 넣고 쓸 때 정수로 바꿈).
**시제품** 열 ✅ = 시제품 `balance.tres` 에 이미 있는 키. 나머지는 생성기·기름 도둑을 만들 때 이 이름으로 추가.

| 키 | 1인 | 2인 | 3인 | 4인 | 시제품 |
|---|---|---|---|---|---|
| `party_oil_start` | 90 | 100 | 100 | 100 | ✅ |
| `party_oil_drain_mult` (모든 빛) | 0.7 | 1.0 | 1.0 | 1.0 | ✅ |
| `party_stalker_speed_mult` | 0.85 | 1.0 | 1.0 | 1.05 | ✅ |
| `party_rooms_per_floor` | 8 | 10 | 11 | 12 | |
| `party_oil_bottles_per_floor` | 2 | 2 | 3 | 3 | |
| `party_stalkers_floor1` | 1 | 1 | 2 | 2 | |
| `party_stalkers_floor2` | 1 | 2 | 2 | 3 | |
| `party_leech_swarms_floor1` | 1 | 2 | 2 | 3 | |
| `party_leech_swarms_floor2` | 2 | 2 | 3 | 4 | |
| `party_relics_light_per_floor` | 3 | 3 | 4 | 5 | |
| `party_relics_heavy_per_floor` | 1 | 1 | 2 | 2 | |

> `party_oil_start` 가 있으면 2장 `oil_start` 보다 우선한다.

## 8. 실패 패널티 (`penalty_*`)

| 키 | 값 | 설명 |
|---|---|---|
| `penalty_lose_carried_relics` | true | 원정 실패 시 들고 있던 유물 잃음 |
| `penalty_run_income_keep_ratio` | 0.0 | 실패한 판 수입 중 남기는 비율. **보류: 첫 테스트 후 결정** (GDD 15장, [PLAYTEST_PROTOTYPE.md](PLAYTEST_PROTOTYPE.md) Q9) |

> 시제품에는 정산이 없으므로 '전원 쓰러짐 → 실패 화면 + 다시 시작'만 있으면 됩니다.

## 9. 시제품 전용 (`proto_*`)

시제품에서 개발팀이 추가한 키 (PR #12) + 시제품 2차 키 (2026-10-26, GDD 13.1). 단계 2에서 정식 키로 옮기거나 없앤다.

| 키 | 값 | 단위 | 설명 | 단계 2 |
|---|---|---|---|---|
| `proto_interact_range` | 2.0 | m | 줍기·부활 상호작용 거리 | 정식 키 `player_interact_range` 로 |
| `proto_give_range` | 3.0 | m | 등불 건네기 거리 | 정식 키 `player_give_range` 로 |
| `proto_fail_restart_delay` | 5.0 | s | 원정 실패 뒤 다시 시작까지 | 없앰 (정산·캠프 화면으로 바뀜) |
| `proto_debug_oil_start` | **50.0** | 기름 | F5 디버그 키의 시작 기름 (플레이 테스트 2판째). 2026-10-26: 30 → 50 (기본 판이 이미 짧아져서) | 디버그 전용으로 유지 |
| `proto_party_drain_scale` | **[6, 4, 3.5, 3]** | 배 (1~4인) | **시제품 기름 소모 배율.** 모든 빛의 분당 소모에 곱함 (섬광·설치 비용·부활 비용은 안 곱함). 방 3개짜리 판을 5~8분으로 맞추려는 값 — 아래 계산 | 없앰 (층 크기가 커지면 1.0) |
| `proto_relic_count` | 2 | 개 | 목표 유물 수 (GDD 13.1) | 정식 목표 규칙으로 |
| `proto_relic_carry_speed` | 2.5 | m/s | 유물을 든 사람 이동 속도 (달리기 불가) | 직업별 값으로 (GDD 6장) |
| `proto_altar_range` | 2.0 | m | 제단에 올려놓는 거리 | 정식 키로 |
| `proto_success_restart_delay` | 5.0 | s | 원정 성공 화면 뒤 다시 시작 | 없앰 |
| `proto_stalker_reveal_time` | 90.0 | s | 판 시작 뒤 이 시간까지 추적자가 한 번도 '추적'을 안 했으면, 가장 가까운 플레이어 쪽으로 배회해 빛 경계에서 눈을 보여 줌 (존재를 알리기) | 플레이 테스트 보고 결정 |
| `proto_intro_duration` | 8.0 | s | 시작 안내 문구 표시 시간 (아무 키로 닫힘) | 튜토리얼로 |
| `proto_hint_duration` | 3.0 | s | 상황 힌트 표시 시간 | 정식 키로 |

---

## 시제품 기준 계산 (확인용, 2026-10-26)

목표: 한 판 **5~8분** (GDD 13.1). 기름 100 + 병 2개(15씩 = 30).

| 인원 | 쓰는 빛 (보통) | 분당 소모 = 기본 × `party_oil_drain_mult` × `proto_party_drain_scale` | 병 안 주움 | 병 2개 다 |
|---|---|---|---|---|
| 1인 | 큰 등불 4 (등불을 내려놓고 손등을 켜면 +0.5 → 1분에 2.1 더 씀) | 4 × 0.7 × 6 = **16.8** | 약 6.0분 | 약 7.7분 |
| 2인 | 큰 등불 4 + 손등 0.5 | 4.5 × 1.0 × 4 = **18** | 약 5.6분 | 약 7.2분 |
| 3인 | 4 + 0.5 × 2 = 5 | 5 × 3.5 = **17.5** | 약 5.7분 | 약 7.4분 |
| 4인 | 4 + 0.5 × 3 = 5.5 | 5.5 × 3 = **16.5** | 약 6.1분 | 약 7.9분 |

- 내내 '낮춤'(분당 절반)이면 2배 가까이 버티지만 반경 3 m 라 위험. 내내 '키움'(2배)이면 3~4분.
- 기름 0 뒤 심지 60초 + 완전한 어둠 → 사실상 이때가 끝.
- 기름 20 이하 경고: 혼자 기준 남은 시간 약 1분 10초.

**혼자 하기에서 2분 안에 추적자를 만나는 이유**
1. 방 B 유물은 시작 방 바로 옆 (걸어서 20초). 처음 1분 안에 들게 됨 → 들자마자 소리로 추적자가 옴 (`stalker_relic_noise`).
2. 유물을 들면 등불을 못 드니 빛 밖에서 2.5 m/s 로 걷게 됨. `dark_gain_unlit` 5/s → **6초 만에 30** (추적 후보). B 구석에서 제단까지 약 22 m = 9초.
3. 추적자 속도 3.5 × 0.85 = 3.0 m/s > 유물 든 사람 2.5 m/s → 등불을 길목에 미리 놓아 두지 않으면 따라잡힘. 유물을 내려놓고(Q) 달리면(6 m/s) 도망 가능 — 이게 고민거리.
4. 그래도 안 만났으면 90초에 추적자가 스스로 다가와 눈을 보여 줌 (`proto_stalker_reveal_time`).

## 바꾼 기록

| 날짜 | 키 | 전 → 후 | 이유 |
|---|---|---|---|
| 2026-10-25 | (최초 작성) | — | GDD 0.1 값 정리 |
| 2026-10-25 | 7장 인원별 키 | `oil_start` 등 → `party_oil_start` 등, 별도 파일 → `balance.tres` 안 배열 | 시제품 구현(PR #12)에 맞춤 |
| 2026-10-25 | 9장 `proto_*` 4개 | (새로) | 시제품 구현(PR #12) |
| 2026-10-26 | 큰 등불 반경 | 5/8/12 → **3/5/8** m | 플레이 테스트 1: 12 m 방이 늘 다 밝아 단계 차이를 못 느낌 |
| 2026-10-26 | 손등·심지·섬광·설치 램프·샘·시작방 반경 | 3→2, 2→1.5, 16→12, 5→4, 4→3, 6→4 m | 큰 등불 반경과 비율 맞춤 |
| 2026-10-26 | `dark_gain_unlit` | 4 → 5 /s | 혼자서도 2분 안에 추적 (빛 밖 6초면 후보) |
| 2026-10-26 | 빛 판정 | 벽 무시 → 벽에 가리면 빛 밖 | 옆방까지 밝아지는 문제 |
| 2026-10-26 | `stalker_blocks_players`·`stalker_touch_attack`·`stalker_relic_noise` | (새로) | "괴물을 통과해도 상관없다 / 언제 쫓아오는지 모르겠다" |
| 2026-10-26 | `proto_party_drain_scale` 외 시제품 2차 키 8개, `proto_debug_oil_start` 30 → 50 | (새로) | 플레이 테스트 1: 기름이 안 떨어짐(혼자 약 35분), 목표 없음 |
