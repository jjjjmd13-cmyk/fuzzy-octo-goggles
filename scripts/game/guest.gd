extends "res://scripts/game/carryable.gd"
## 손님 (시제품: 강아지). 호스트만 생각하고 움직인다. 위치는 Carryable 의 ground_position 으로 퍼진다.
##
## 상태(모양): 진흙 → 거품(욕조 안) → 젖음 → 뽀송. 젖었을 때 바닥에 놓이면 털고 도망간다 (GDD_V2 3.2).
## 하트(기다림): 들려 있거나 기계가 돌아가는 동안은 줄지 않는다. 다 비면 "흥!" 하고 나간다.
## 겉모습은 자식 "Model" (scenes/art/guests/dog_model.tscn) 의 set_guest_state(이름) 로 바뀐다.

enum State { MUDDY, FOAM, WET, DRY }
enum Phase { ENTERING, QUEUED, SEATED, FREE, SHAKING, ESCAPING, IN_MACHINE, ANGRY }

const STATE_NAMES := ["muddy", "foam", "wet", "dry"]

# --- Sync (호스트 → 모두)
var state: State = State.MUDDY:
	set(value):
		state = value
		_apply_model()
var phase: Phase = Phase.ENTERING
## 남은 기다림 (초). 하트 = ceil(patience / guest_heart_time)
var patience := 60.0

# --- 호스트 전용
var walk_target := Vector3.ZERO
var machine: Node = null
var _timer := 0.0
var _turn_timer := 0.0
var _avoid_cooldown := 0.0
var _puddle_timer := 0.0
var _escape_dir := Vector3.FORWARD
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	super()
	add_to_group("guests")
	_rng.randomize()
	_apply_model()


## 손님 머리 위에 보여 줄 남은 단계.
func remaining_steps() -> PackedStringArray:
	match state:
		State.MUDDY, State.FOAM:
			return PackedStringArray(["bath", "dryer"])
		State.WET:
			return PackedStringArray(["dryer"])
	return PackedStringArray()


func hearts_left() -> int:
	return clampi(ceili(patience / Tuning.data.guest_heart_time), 0, Tuning.data.guest_hearts)


func can_be_picked() -> bool:
	return not is_held() and phase != Phase.IN_MACHINE and phase != Phase.ANGRY and phase != Phase.QUEUED


func on_picked(_peer_id: int) -> void:
	phase = Phase.FREE
	_shop().on_guest_picked(self)


## 젖었으면 몸을 털고 도망, 아니면 그 자리에 앉아 있는다.
func on_dropped() -> void:
	if state == State.WET:
		phase = Phase.SHAKING
		_timer = Tuning.data.escape_shake_time
		_shop().on_guest_shake(self)
	else:
		phase = Phase.FREE


## 호스트: 기다림이 줄어드는가.
func _patience_running() -> bool:
	if is_held() or phase == Phase.ANGRY:
		return false
	if phase == Phase.IN_MACHINE and machine != null and machine.is_running() and Tuning.data.guest_patience_pause_in_machine:
		return false
	return true


func _physics_process(delta: float) -> void:
	if not Net.is_host() or not _shop().is_open():
		return
	var data: Resource = Tuning.data
	if _patience_running():
		var mult: float = data.machine_done_wait_heart_mult if phase == Phase.IN_MACHINE else 1.0
		patience = maxf(patience - delta * mult, 0.0)
		if patience <= 0.0:
			_shop().on_guest_angry(self)
			return
	if is_held():
		return
	match phase:
		Phase.ENTERING, Phase.QUEUED:
			_walk_to(walk_target, data.guest_walk_speed, delta)
			if phase == Phase.ENTERING and CarryRulesMath.hdist(ground_position, walk_target) < 0.05:
				phase = Phase.SEATED
				ground_yaw = 0.0
		Phase.SHAKING:
			_timer -= delta
			if _timer <= 0.0:
				phase = Phase.ESCAPING
				_turn(_random_dir())
		Phase.ESCAPING:
			_escape(delta)
		Phase.ANGRY:
			_walk_to(walk_target, data.guest_walk_speed * 1.5, delta)


func _walk_to(target: Vector3, speed: float, delta: float) -> void:
	var to := target - ground_position
	to.y = 0.0
	if to.length() < 0.001:
		return
	var step := minf(speed * delta, to.length())
	ground_position += to.normalized() * step
	ground_yaw = atan2(-to.x, -to.z)


## 도망 (TUNING_V2 2.1): 일정 간격·벽에서 방향 바꾸기, 가까운 플레이어 반대로 꺾기, 웅덩이 남기기.
func _escape(delta: float) -> void:
	var data: Resource = Tuning.data
	var world := get_parent().get_parent()
	_turn_timer -= delta
	_avoid_cooldown -= delta
	_puddle_timer -= delta
	if _turn_timer <= 0.0:
		_turn(_random_dir())
	if _avoid_cooldown <= 0.0:
		for player in world.get_players():
			var away: Vector3 = ground_position - player.reported_position()
			away.y = 0.0
			if away.length() < data.escape_avoid_player_range:
				_turn(away.normalized() if away.length() > 0.01 else _random_dir())
				_avoid_cooldown = 1.0
				break
	var next: Vector3 = ground_position + _escape_dir * data.escape_speed * delta
	var clamped: Vector3 = world.clamp_to_floor(next)
	if not clamped.is_equal_approx(next) or world.is_blocked(clamped):
		# 벽이나 기계에 닿음 → 방 가운데 쪽으로 무작위 방향, 이번 걸음은 멈춤
		var inward: Vector3 = Vector3.ZERO - ground_position
		inward.y = 0.0
		_turn((inward.normalized() + _random_dir() * 0.8).normalized())
		next = ground_position if world.is_blocked(clamped) else clamped
	ground_position = next
	ground_yaw = atan2(-_escape_dir.x, -_escape_dir.z)
	if _puddle_timer <= 0.0:
		_puddle_timer = data.escape_puddle_interval
		_shop().spawn_puddle(ground_position)


func _turn(dir: Vector3) -> void:
	_escape_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	_turn_timer = Tuning.data.escape_turn_interval


func _random_dir() -> Vector3:
	var angle := _rng.randf() * TAU
	return Vector3(sin(angle), 0.0, cos(angle))


func _apply_model() -> void:
	if not is_node_ready():
		return
	var model := get_node_or_null("Model")
	if model != null and model.has_method("set_guest_state"):
		model.set_guest_state(STATE_NAMES[state])


func _shop() -> Node:
	return get_parent().get_parent().get_node("Shop")


## 거리 계산 (CarryRules 와 같은 수평 거리)
class CarryRulesMath:
	static func hdist(a: Vector3, b: Vector3) -> float:
		return Vector2(a.x - b.x, a.z - b.z).length()
