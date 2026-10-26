extends Resource
## 멍냥 목욕탕 밸런스 수치 (docs/design/TUNING_V2.md 키 이름 그대로).
## 기획팀은 data/balance/bath_balance.tres 값만 고친다.
## 인원별 표는 party_ 배열 [1인, 2인, 3인, 4인].
## "proto_" 키는 TUNING_V2 에 아직 없는 개발팀 임시 값이다.

@export_group("플레이어")
@export var player_walk_speed := 4.5
## 동물을 들고 있을 때
@export var player_carry_speed := 4.0
@export var player_dash_distance := 2.5
@export var player_dash_cooldown := 0.8
## 들기·넣기 거리 (앞쪽 부채꼴)
@export var player_interact_range := 1.2
## 플레이어끼리 부딪힐 때 밀림 정도 (시제품은 막기만 하고 밀지는 않음)
@export var player_push_strength := 1.0

@export_group("손님")
@export var guest_hearts := 3
## 하트 하나가 비는 시간 (s)
@export var guest_heart_time := 20.0
@export var guest_heart_blink_last := true
@export var guest_patience_pause_in_machine := true
@export var guest_angry_leave_time := 1.5
@export var guest_seats := 3
@export var guest_queue_max := 3
@export var guest_walk_speed := 2.0

@export_group("젖은 손님 도망")
@export var escape_shake_time := 0.5
@export var escape_shake_splash_radius := 1.5
@export var escape_speed := 3.5
@export var escape_turn_interval := 2.0
@export var escape_avoid_player_range := 2.0
@export var escape_puddle_interval := 0.6

@export_group("물웅덩이")
@export var puddle_radius := 0.6
@export var puddle_lifetime := 12.0
@export var puddle_max := 20
@export var puddle_slide_distance := 2.5
@export var puddle_slide_time := 0.6
@export var puddle_affects_guests := false

@export_group("기계")
@export var machine_bath_time := 4.0
@export var machine_dryer_time := 3.0
@export var machine_done_wait_heart_mult := 1.0
@export var machine_auto_eject_solo := false

@export_group("영업")
@export var shop_duration := 180.0
@export var party_guest_interval := PackedFloat32Array([30, 20, 15, 12])
@export var party_first_guest_delay := PackedFloat32Array([3, 3, 3, 3])
@export var party_star1_guests := PackedFloat32Array([3, 5, 6, 8])
@export var party_star2_guests := PackedFloat32Array([5, 7, 9, 12])
@export var party_star3_guests := PackedFloat32Array([6, 9, 12, 15])

@export_group("결과")
@export var result_star3_requires_no_angry := true
## 0 = 아무 키를 누를 때까지 결과 화면
@export var result_show_time := 0.0
@export var intro_text_time := 3.0

@export_group("개발팀 임시 (TUNING_V2 에 없음)")
## 내려놓을 때 몸 앞으로 놓는 거리 (m)
@export var proto_drop_distance := 0.9
## 앞쪽 부채꼴 반각 (도). 이 각도 밖의 물건은 들 수 없다.
@export var proto_interact_half_angle := 70.0
## 미끄러진 뒤 다시 미끄러지지 않는 시간 (s)
@export var proto_slip_immunity := 0.4


func party_value(table: PackedFloat32Array, party_size: int) -> float:
	return table[clampi(party_size, 1, table.size()) - 1]


func heart_patience() -> float:
	return guest_hearts * guest_heart_time
