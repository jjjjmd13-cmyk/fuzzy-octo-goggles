extends Node
## 하루 영업 (MILESTONE_V3_SLICE 1장): 벽시계, 차례로 오는 주인 손님, 대기 의자·문밖 줄, 기다리다 떠남, 6시 마감.
##
## 권한: 호스트가 시계·손님 도착·대기열을 정하고 DaySync 로 보낸다. 다른 사람은 읽기만 한다.
## 목욕대가 비면 대기열 맨 앞 손님을 WashStation.take_guest() 로 보낸다.
## 손님 번호(id)는 첫날부터 끝날까지 하나씩 늘어난다 (목욕대의 강아지 번호와 같음).

signal day_ended

const WashStation := preload("res://scripts/sim/wash_station.gd")
## 손님을 일찍 다 받으면 벽시계를 6시까지 빠르게 돌리는 시간 (s)
const FAST_FORWARD_TIME := 1.5

# --- DaySync (호스트가 씀)
## 며칠째 (1부터)
var day := 0
## 영업을 시작한 뒤 지난 시간 (s). 영업 시간이 끝나면 멈춤
var clock := 0.0
## 오늘 들어온 손님 수 / 씻겨 보낸 손님 / 기다리다 떠난 손님 / 번 돈 (요금 + 팁)
var arrived := 0
var served := 0
var walked_out := 0
var earned := 0
## 오늘 첫 손님 번호 (요청 카드 "N번째 손님" 용)
var first_guest := 1
## 대기열 (앞에서부터): 손님 번호 · 주인 모양 · 기다리기 시작한 시각 (clock)
var queue_ids := PackedInt32Array()
var queue_variants := PackedInt32Array()
var queue_since := PackedFloat32Array()
## 오늘 영업이 끝났음 (6시가 지났거나 손님이 다 왔고, 목욕대·대기열이 빔)
var closed := false
## 오늘 손님을 다 받아 벽시계를 6시까지 빠르게 돌리는 중
var closing := false

var station: WashStation
var sfx: Node

# 호스트만
var _next_id := 1
var _idle_time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## 호스트: 그날 영업 시작
func start_day(number: int) -> void:
	if not Net.is_host():
		return
	day = number
	clock = 0.0
	arrived = 0
	served = 0
	walked_out = 0
	earned = 0
	first_guest = _next_id
	queue_ids = PackedInt32Array()
	queue_variants = PackedInt32Array()
	queue_since = PackedFloat32Array()
	closed = false
	closing = false
	_idle_time = 0.0
	# 첫 손님은 바로 (이슈 #40: 시작하자마자 할 일이 있게)
	_arrive()


func open_seconds() -> float:
	return Tuning.data.day_open_minutes_real * 60.0


func guests_today() -> int:
	var counts: PackedInt32Array = Tuning.data.slice_guests_per_day
	if counts.is_empty():
		return 0
	return counts[clampi(day - 1, 0, counts.size() - 1)]


## 벽시계 (9시 → 18시)
func hour() -> float:
	return 9.0 + 9.0 * clampf(clock / maxf(open_seconds(), 0.01), 0.0, 1.0)


func is_open() -> bool:
	return clock < open_seconds()


## i 번째(0부터) 손님이 오는 시각
func arrival_time(index: int) -> float:
	return index * open_seconds() * Tuning.data.proto_guest_spacing / maxf(guests_today(), 1)


## 대기열에서 기다린 비율 (0~1, 1 이면 떠남)
func patience_ratio(index: int) -> float:
	return clampf((clock - queue_since[index]) / maxf(Tuning.data.slice_owner_patience, 0.01), 0.0, 1.0)


## 오늘 몇 번째 손님인가 (1부터)
func guest_number_today(guest_id: int) -> int:
	return guest_id - first_guest + 1


func _process(delta: float) -> void:
	if not Net.is_host() or day == 0 or closed:
		return
	if closing:
		# 일찍 끝난 날: 벽시계를 6시까지 빠르게 돌리고 "영업 끝" (기획팀 제안)
		clock = minf(clock + open_seconds() / FAST_FORWARD_TIME * delta, open_seconds())
		if not is_open():
			closed = true
			_day_closed.rpc()
		return
	clock = minf(clock + delta, open_seconds())
	var idle := station.owner_phase == WashStation.OwnerPhase.EMPTY
	# 너무 오래 기다린 손님은 떠남
	var i := 0
	while i < queue_ids.size():
		if patience_ratio(i) >= 1.0:
			_remove_from_queue(i)
			walked_out += 1
			_walked_out.rpc()
		else:
			i += 1
	# 새 손님: 정해진 시각이 되었거나, 목욕대가 비고 기다리는 손님도 없으면 조금 뒤 앞당겨
	_idle_time = _idle_time + delta if idle and queue_ids.is_empty() else 0.0
	if arrived < guests_today() and is_open():
		if clock >= arrival_time(arrived) or _idle_time >= Tuning.data.proto_next_dog_delay:
			_arrive()
			idle = station.owner_phase == WashStation.OwnerPhase.EMPTY
	# 목욕대가 비면 대기열 맨 앞 손님이 강아지를 맡김
	if idle and not queue_ids.is_empty():
		var guest := queue_ids[0]
		var variant := queue_variants[0]
		_remove_from_queue(0)
		station.take_guest(guest, variant, true)
		idle = false
	if idle and queue_ids.is_empty() and (arrived >= guests_today() or not is_open()):
		if is_open():
			closing = true
		else:
			closed = true
			_day_closed.rpc()


## 호스트: 목욕대가 손님 한 명을 다 씻겨 돈을 받음 (WashStation._pay)
func guest_paid(total: int) -> void:
	if not Net.is_host():
		return
	served += 1
	earned += total


func _arrive() -> void:
	var guest := _next_id
	_next_id += 1
	arrived += 1
	_idle_time = 0.0
	var variant := _pick_variant()
	_guest_arrived.rpc()
	if station.owner_phase == WashStation.OwnerPhase.EMPTY and queue_ids.is_empty():
		station.take_guest(guest, variant, false)
		return
	var ids := queue_ids.duplicate()
	var variants := queue_variants.duplicate()
	var since := queue_since.duplicate()
	ids.append(guest)
	variants.append(variant)
	since.append(clock)
	queue_ids = ids
	queue_variants = variants
	queue_since = since


## 주인 모양: 지금 가게에 있는 손님(목욕대·대기열)과 겹치지 않게 고른다 (다 쓰였으면 아무거나)
func _pick_variant() -> int:
	var used := {}
	if station.owner_phase != WashStation.OwnerPhase.EMPTY:
		used[station.owner_variant] = true
	for variant in queue_variants:
		used[variant] = true
	var free: Array[int] = []
	for variant in maxi(Tuning.data.owner_variants, 1):
		if not used.has(variant):
			free.append(variant)
	if free.is_empty():
		return _rng.randi_range(0, maxi(Tuning.data.owner_variants, 1) - 1)
	return free[_rng.randi_range(0, free.size() - 1)]


## 배열을 새로 만들어 넣는다 (같은 배열을 고치면 동기화가 바뀐 줄 모름)
func _remove_from_queue(index: int) -> void:
	var ids := queue_ids.duplicate()
	var variants := queue_variants.duplicate()
	var since := queue_since.duplicate()
	ids.remove_at(index)
	variants.remove_at(index)
	since.remove_at(index)
	queue_ids = ids
	queue_variants = variants
	queue_since = since


@rpc("authority", "call_local", "reliable")
func _guest_arrived() -> void:
	if sfx != null:
		sfx.play("bell")


@rpc("authority", "call_local", "reliable")
func _walked_out() -> void:
	if sfx != null:
		sfx.play("sigh")


@rpc("authority", "call_local", "reliable")
func _day_closed() -> void:
	day_ended.emit()
	if sfx != null:
		sfx.play("ding")
