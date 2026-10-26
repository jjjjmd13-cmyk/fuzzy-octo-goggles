extends Resource
## 밸런스 수치 (GDD 10장, docs/design/TUNING.md).
##
## 기획팀은 data/balance/balance.tres 값만 고친다. 키 이름은 TUNING.md 와 같다.
## 인원별 표(TUNING.md 7장)는 party_ 로 시작하는 배열이며 [1인, 2인, 3인, 4인] 순서다.
## "proto_" 키는 TUNING.md 에 아직 없는 시제품용 값이다 (기획팀이 표에 옮길 것).

@export_group("등불·빛")
@export var light_lantern_radius_low := 5.0
@export var light_lantern_radius_normal := 8.0
@export var light_lantern_radius_high := 12.0
## 기름/분
@export var light_lantern_drain_low := 2.0
@export var light_lantern_drain_normal := 4.0
@export var light_lantern_drain_high := 8.0
## 0=낮춤, 1=보통, 2=키움
@export_range(0, 2) var light_lantern_default_level := 1
@export var light_handlamp_radius := 3.0
## 기름/분, 켠 손등 1개당
@export var light_handlamp_drain := 0.5
@export var light_wick_radius := 2.0
@export var light_wick_duration := 60.0
@export var light_low_oil_threshold := 20.0

@export_group("기름")
@export var oil_max := 100.0
## 인원별 표(party_oil_start)가 우선한다.
@export var oil_start := 100.0
@export var oil_bottle_amount := 15.0
@export var oil_revive_cost := 5.0
@export var oil_tick_interval := 0.5

@export_group("어둠 게이지")
@export var dark_max := 100.0
@export var dark_gain_unlit := 4.0
@export var dark_gain_handlamp_only := 1.0
@export var dark_decay_lit := 10.0
@export var dark_no_oil_gain_mult := 2.0
@export var dark_stalk_threshold := 30.0
@export var dark_stalk_release_threshold := 30.0
@export var dark_full_hunt := 100.0

@export_group("플레이어·쓰러짐")
@export var player_walk_speed := 4.0
@export var player_run_speed := 6.0
@export var player_stamina := 5.0
@export var player_stamina_regen_delay := 3.0
@export var player_stamina_regen_rate := 1.0
@export var down_duration := 30.0
@export var down_crawl_speed := 1.0
@export var down_revive_time := 3.0

@export_group("그림자 추적자")
@export var stalker_think_hz := 10
@export var stalker_sync_hz := 20
@export var stalker_idle_time_min := 3.0
@export var stalker_idle_time_max := 8.0
@export var stalker_wander_speed := 2.5
@export var stalker_stalk_speed := 3.5
@export var stalker_flee_speed := 5.0
@export var stalker_detect_range := 20.0
@export var stalker_attack_range := 1.5
@export var stalker_attack_windup := 0.8
@export var stalker_light_flee_time := 0.5
@export var stalker_flee_duration := 4.0
@export var stalker_lose_interest_time := 5.0
@export var stalker_no_oil_speed_mult := 1.5
@export var stalker_ignores_handlamp := true

@export_group("인원별 [1인, 2인, 3인, 4인]")
@export var party_oil_start := PackedFloat32Array([90, 100, 100, 100])
@export var party_oil_drain_mult := PackedFloat32Array([0.7, 1.0, 1.0, 1.0])
@export var party_stalker_speed_mult := PackedFloat32Array([0.85, 1.0, 1.0, 1.05])

@export_group("시제품 전용 (TUNING.md 에 아직 없음)")
## 등불·기름병 줍기, 부활 상호작용 거리 (m)
@export var proto_interact_range := 2.0
## 등불 건네기: 이 거리 안의 가장 가까운 동료에게 (m)
@export var proto_give_range := 3.0
## 전원 쓰러짐 뒤 다시 시작까지 (s)
@export var proto_fail_restart_delay := 5.0
## 임시 목표(출구) 도착 판정 반경 (m)
@export var proto_exit_radius := 2.0
## 추적자가 배회할 때 플레이어 쪽(빛 가장자리 바깥)으로 갈 확률 0~1. 0 이면 방 안 아무 곳.
@export var proto_stalker_wander_toward_player := 0.6
## 이 거리(수평, m) 안에서 어둠 속 플레이어와 몸이 닿으면 바로 공격 준비
@export var proto_stalker_contact_range := 0.9
## 디버그 키(F5)로 다시 시작할 때의 시작 기름 (PLAYTEST_PROTOTYPE.md 2판째)
@export var proto_debug_oil_start := 30.0


func lantern_radius(level: int) -> float:
	return [light_lantern_radius_low, light_lantern_radius_normal, light_lantern_radius_high][clampi(level, 0, 2)]


## 기름/분
func lantern_drain(level: int) -> float:
	return [light_lantern_drain_low, light_lantern_drain_normal, light_lantern_drain_high][clampi(level, 0, 2)]


func party_value(table: PackedFloat32Array, party_size: int) -> float:
	return table[clampi(party_size, 1, table.size()) - 1]
