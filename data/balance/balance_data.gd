extends Resource
## 밸런스 수치 (멍냥 목욕탕). 기획팀은 data/balance/balance.tres 값만 고친다.
## 키 이름은 기획팀 수치표(TUNING)가 나오면 그쪽에 맞춘다. 인원별 표는 [1인, 2인, 3인, 4인] 배열.

@export_group("플레이어")
@export var player_walk_speed := 4.0
@export var player_run_speed := 6.0
## 달리기 최대 시간 (s)
@export var player_stamina := 3.0
@export var player_stamina_regen_delay := 1.0
## 1초에 회복하는 달리기 시간 (s/s)
@export var player_stamina_regen_rate := 1.5

@export_group("들기")
## 물건을 집을 수 있는 거리 (m, 수평)
@export var carry_pickup_range := 1.6
## 건네기: 이 거리 안의 가장 가까운 빈손 동료에게 (m)
@export var carry_give_range := 2.5
## 물건을 들고 있을 때 이동 속도 배율
@export var carry_speed_mult := 0.85
## 내려놓을 때 몸 앞으로 놓는 거리 (m)
@export var carry_drop_distance := 0.9


func party_value(table: PackedFloat32Array, party_size: int) -> float:
	return table[clampi(party_size, 1, table.size()) - 1]
