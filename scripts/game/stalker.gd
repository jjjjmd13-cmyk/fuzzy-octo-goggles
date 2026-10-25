extends CharacterBody3D
## 그림자 추적자 (GDD 7.1). 호스트에서만 생각하고 움직인다.
## 클라이언트는 net_position·net_yaw·state 만 받아 부드럽게 따라 그린다 (stalker_sync_hz).
##
## 상태: 잠복 → 배회 → 추적 → 공격(준비 동작) → 후퇴.
## 큰 등불 반경 안으로는 들어가지 않는다 (다음 길 지점이 빛 안이면 멈춰 기다림).
## 겉모습은 scenes/art/stalker_model.tscn (set_state(이름) 으로 눈빛 등 연출).

signal state_changed(new_state: int)

enum State { IDLE, WANDER, STALK, ATTACK, FLEE }

const STATE_NAMES := ["idle", "wander", "stalk", "attack", "flee"]
const ARRIVE_DISTANCE := 0.6
const FLEE_PROBE_DISTANCE := 10.0

# --- Sync (호스트 → 모두)
var state: State = State.IDLE:
	set(value):
		if state != value:
			state = value
			_apply_state_visual()
			state_changed.emit(value)
var net_position := Vector3.ZERO
var net_yaw := 0.0
## 추적·공격 중인 피어 (디버그 표시용).
var target_peer := 0

var _state_time := 0.0
var _idle_duration := 3.0
var _think_accum := 0.0
var _lit_time := 0.0
var _low_interest_time := 0.0
var _windup_left := 0.0
var _speed := 0.0
var _rng := RandomNumberGenerator.new()
var _start_transform: Transform3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var sync: MultiplayerSynchronizer = $Sync
@onready var model: Node3D = $Model


func _ready() -> void:
	_start_transform = global_transform
	net_position = position
	sync.replication_interval = 1.0 / Tuning.data.stalker_sync_hz
	_rng.randomize()
	_apply_state_visual()
	_enter(State.IDLE)


func state_name() -> String:
	return STATE_NAMES[state]


## 호스트 전용: 처음 자리로.
func reset() -> void:
	global_transform = _start_transform
	velocity = Vector3.ZERO
	net_position = position
	net_yaw = rotation.y
	target_peer = 0
	_enter(State.IDLE)


func _physics_process(delta: float) -> void:
	if not Net.is_host():
		var t := minf(delta * 15.0, 1.0)
		position = position.lerp(net_position, t)
		rotation.y = lerp_angle(rotation.y, net_yaw, t)
		return
	var expedition: Node = _expedition()
	if expedition == null or expedition.phase != expedition.Phase.PLAYING:
		return
	var data: Resource = Tuning.data
	_state_time += delta
	_lit_time = _lit_time + delta if expedition.is_in_big_light(global_position) else 0.0

	# 빛을 맞으면 어느 상태든 후퇴 (후퇴 중 제외).
	if state != State.FLEE and _lit_time >= data.stalker_light_flee_time:
		_enter(State.FLEE)
	if state == State.ATTACK:
		_tick_attack(delta, expedition)

	_think_accum += delta
	if _think_accum >= 1.0 / data.stalker_think_hz:
		_think(_think_accum, expedition)
		_think_accum = 0.0

	_move(delta, expedition)
	net_position = position
	net_yaw = rotation.y


func _think(dt: float, expedition: Node) -> void:
	var data: Resource = Tuning.data
	match state:
		State.IDLE:
			if _try_start_stalk():
				return
			if _state_time >= _idle_duration:
				_enter(State.WANDER)
		State.WANDER:
			if _try_start_stalk():
				return
			if agent.is_navigation_finished() or _state_time > 20.0:
				_enter(State.IDLE)
		State.STALK:
			var target := _target()
			if target == null or not target.is_active():
				_enter(State.WANDER)
				return
			_low_interest_time = _low_interest_time + dt if target.dark < data.dark_stalk_release_threshold else 0.0
			if _low_interest_time >= data.stalker_lose_interest_time:
				_enter(State.WANDER)
				return
			agent.target_position = target.global_position
			if global_position.distance_to(target.global_position) <= data.stalker_attack_range \
					and not expedition.is_in_big_light(target.global_position):
				_enter(State.ATTACK)
		State.FLEE:
			if _state_time >= data.stalker_flee_duration:
				_enter(State.IDLE)


## 공격 준비 동작 (stalker_attack_windup). 준비 중 대상이 빛 안으로 들어가면 후퇴.
func _tick_attack(delta: float, expedition: Node) -> void:
	var target := _target()
	if target == null or not target.is_active():
		_enter(State.WANDER)
		return
	if expedition.is_in_big_light(target.global_position):
		_enter(State.FLEE)
		return
	_windup_left -= delta
	if _windup_left > 0.0:
		return
	if global_position.distance_to(target.global_position) <= Tuning.data.stalker_attack_range * 1.5:
		expedition.down_player(target)
		_enter(State.FLEE)
	else:
		_enter(State.STALK)


## 추적 후보: 어둠 게이지 dark_stalk_threshold 이상 + 감지 거리 안 (게이지 dark_full_hunt 면 거리 무시).
## 여럿이면 게이지가 가장 높은 사람.
func _find_candidate() -> Node:
	var data: Resource = Tuning.data
	var best: Node = null
	for player in _world().get_players():
		if not player.is_active() or player.dark < data.dark_stalk_threshold:
			continue
		var in_range: bool = global_position.distance_to(player.global_position) <= data.stalker_detect_range
		if not in_range and player.dark < data.dark_full_hunt:
			continue
		if best == null or player.dark > best.dark:
			best = player
	return best


func _try_start_stalk() -> bool:
	var candidate := _find_candidate()
	if candidate == null:
		return false
	target_peer = candidate.get_peer_id()
	_enter(State.STALK)
	return true


func _enter(new_state: State) -> void:
	var data: Resource = Tuning.data
	_state_time = 0.0
	_low_interest_time = 0.0
	match new_state:
		State.IDLE:
			_speed = 0.0
			target_peer = 0
			_idle_duration = _rng.randf_range(data.stalker_idle_time_min, data.stalker_idle_time_max)
		State.WANDER:
			_speed = data.stalker_wander_speed
			target_peer = 0
			agent.target_position = _random_nav_point()
		State.STALK:
			_speed = data.stalker_stalk_speed
		State.ATTACK:
			_speed = 0.0
			_windup_left = data.stalker_attack_windup
		State.FLEE:
			_speed = data.stalker_flee_speed
			agent.target_position = _flee_point()
	state = new_state


func _move(delta: float, expedition: Node) -> void:
	var data: Resource = Tuning.data
	var speed: float = _speed * data.party_value(data.party_stalker_speed_mult, expedition.party_size)
	if expedition.oil_tank.is_dark():
		speed *= data.stalker_no_oil_speed_mult
	var horizontal := Vector3.ZERO
	if speed > 0.0 and not agent.is_navigation_finished():
		var next := agent.get_next_path_position()
		var to_next := next - global_position
		to_next.y = 0.0
		# 빛 경계에서 멈춤: 다음 길 지점이 큰 빛 안이면 기다린다 (후퇴는 예외).
		var blocked: bool = state != State.FLEE and expedition.is_in_big_light(next)
		if to_next.length() > 0.05 and not blocked:
			horizontal = to_next.normalized() * speed
	if state == State.STALK or state == State.ATTACK:
		var target := _target()
		if target != null:
			_face(target.global_position, delta)
	elif horizontal.length() > 0.1:
		_face(global_position + horizontal, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()


func _face(point: Vector3, delta: float) -> void:
	var dir := point - global_position
	if Vector2(dir.x, dir.z).length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(delta * 8.0, 1.0))


func _random_nav_point() -> Vector3:
	var map := get_world_3d().navigation_map
	var point := NavigationServer3D.map_get_random_point(map, agent.navigation_layers, false)
	return point if point != Vector3.ZERO else global_position


## 빛(없으면 대상) 반대쪽으로.
func _flee_point() -> Vector3:
	var expedition: Node = _expedition()
	var from: Vector3 = expedition.lantern.light_center() if expedition.lantern.is_big_light() else global_position - global_basis.z
	var target := _target()
	if not expedition.lantern.is_big_light() and target != null:
		from = target.global_position
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.1:
		away = global_basis.z
	var probe := global_position + away.normalized() * FLEE_PROBE_DISTANCE
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, probe)


func _target() -> Node:
	return _world().get_player(target_peer) if target_peer != 0 else null


func _apply_state_visual() -> void:
	if is_node_ready() and model.has_method("set_state"):
		model.set_state(STATE_NAMES[state])


func _world() -> Node:
	return get_parent()


func _expedition() -> Node:
	return get_parent().get_node_or_null("Expedition")
