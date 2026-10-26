extends Node
## 원정 규칙 (호스트 권한, GDD 5장·12장).
##
## 호스트만 판정한다: 공용 기름 소모, 어둠 게이지, 쓰러짐·기절·부활, 등불 줍기·건네기,
## 기름병 줍기, 전원 쓰러짐 → 다시 시작. 결과는 각 노드의 호스트 권한 Synchronizer 로 퍼진다.
## 클라이언트는 request() 로 "하고 싶다"만 보낸다. 같은 순간 두 요청이 와도 호스트가
## 차례로 처리하므로 기름병은 한 번만 더해진다 (QA LANT-11).

signal round_started
signal player_downed(peer_id: int)
signal player_revived(peer_id: int, reviver_id: int)

enum Phase { PLAYING, FAILED, SUCCEEDED }

## 요청 종류 (request 의 action).
const ACT_PICKUP_LANTERN := "pickup_lantern"
const ACT_DROP_LANTERN := "drop_lantern"
const ACT_GIVE_LANTERN := "give_lantern"
const ACT_LANTERN_LEVEL := "lantern_level"
const ACT_PICKUP_BOTTLE := "pickup_bottle"
const ACT_REVIVE_START := "revive_start"
const ACT_REVIVE_STOP := "revive_stop"
const ACT_DEBUG_RESTART := "debug_restart"
const ACT_DEBUG_DOWN_SELF := "debug_down_self"

# --- Sync (호스트 → 모두)
var phase: Phase = Phase.PLAYING
var restart_in := 0.0
var party_size := 1
## 이번 판 시작 기름 (디버그 F5 로 바꿀 수 있음).
var round_oil_start := 100.0

## 실행 인자 --oil-start=N 또는 디버그 키로 정한 시작 기름. 음수면 인원별 표를 따른다.
var oil_start_override := -1.0
## 테스트용: 기름이 시간에 따라 줄지 않게 한다.
var drain_enabled := true

var _oil_accum := 0.0
## 쓰러진 피어 → 부활시키는 피어
var _revivers := {}

@onready var world: Node = get_parent()
@onready var oil_tank: Node = world.get_node("OilTank")
@onready var lantern: Node3D = world.get_node("Lantern")


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oil-start="):
			oil_start_override = arg.trim_prefix("--oil-start=").to_float()


func is_host() -> bool:
	return Net.is_host()


## 빛 판정: 수평 거리 ≤ 반경 (TUNING 1장 아래 주석).
static func horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## 큰 등불(기름 있을 때) 반경 안인가. 추적자가 못 들어오는 곳.
func is_in_big_light(pos: Vector3) -> bool:
	return lantern.is_big_light() and horizontal_distance(pos, lantern.light_center()) <= lantern.light_radius()


## 손등·심지 같은 작은 빛 안인가 (큰 빛은 따로).
func is_in_small_light(pos: Vector3) -> bool:
	if oil_tank.in_wick() and horizontal_distance(pos, lantern.light_center()) <= lantern.light_radius():
		return true
	for player in world.get_players():
		if player.is_handlamp_lit() and horizontal_distance(pos, player.global_position) <= Tuning.data.light_handlamp_radius:
			return true
	return false


## 지금 켜진 손등 수 (기름 소모용).
func lit_handlamp_count() -> int:
	var count := 0
	for player in world.get_players():
		if player.is_handlamp_lit():
			count += 1
	return count


## 1분당 기름 소모 (인원별 배율 포함).
func oil_drain_per_minute() -> float:
	var data: Resource = Tuning.data
	var per_minute := 0.0
	if oil_tank.has_oil():
		per_minute = data.lantern_drain(lantern.effective_level()) + lit_handlamp_count() * data.light_handlamp_drain
	return per_minute * data.party_value(data.party_oil_drain_mult, party_size)


## 호스트 전용: 새 판 시작. 기름·등불·기름병·쓰러짐·위치를 처음으로.
func reset_round(oil_start := -1.0) -> void:
	if not is_host():
		return
	var data: Resource = Tuning.data
	var players: Array = world.get_players()
	party_size = maxi(players.size(), 1)
	if oil_start >= 0.0:
		round_oil_start = oil_start
	elif oil_start_override >= 0.0:
		round_oil_start = oil_start_override
	else:
		round_oil_start = data.party_value(data.party_oil_start, party_size)
	oil_tank.reset(round_oil_start)
	_oil_accum = 0.0
	lantern.holder_peer = 0
	lantern.level = data.light_lantern_default_level
	lantern.ground_position = world.get_node("LanternStart").global_position
	for bottle in get_tree().get_nodes_in_group("oil_bottles"):
		bottle.taken = false
	_revivers.clear()
	for player in players:
		_set_down(player, false)
		player.dark = 0.0
		var marker: Node3D = world.get_spawn_marker(player.slot)
		player.teleport.rpc_id(player.get_peer_id(), marker.global_position, marker.global_rotation.y)
	world.get_node("Stalker").reset()
	phase = Phase.PLAYING
	restart_in = 0.0
	round_started.emit()


## 호스트 전용: 쓰러뜨림 (추적자 공격, 디버그).
func down_player(player: Node) -> void:
	if not is_host() or player == null or not player.is_active():
		return
	_set_down(player, true)
	player_downed.emit(player.get_peer_id())


func _set_down(player: Node, is_down: bool) -> void:
	player.downed = is_down
	player.knocked_out = false
	player.revive_progress = 0.0
	player.down_time_left = Tuning.data.down_duration if is_down else 0.0
	_revivers.erase(player.get_peer_id())
	if is_down and lantern.holder_peer == player.get_peer_id():
		_drop_lantern(player)


func _physics_process(delta: float) -> void:
	if not is_host():
		return
	var players: Array = world.get_players()
	if phase != Phase.PLAYING:
		restart_in -= delta
		if restart_in <= 0.0:
			reset_round()
		return
	_tick_oil(delta)
	for player in players:
		_tick_dark(player, delta)
		_tick_down(player, delta)
	_tick_revives(delta)
	if lantern.holder_peer != 0 and world.get_player(lantern.holder_peer) == null:
		lantern.holder_peer = 0  # 든 사람이 나감 → 마지막 자리에 떨어짐
	if not players.is_empty() and players.all(func(p: Node) -> bool: return not p.is_active()):
		phase = Phase.FAILED
		restart_in = Tuning.data.proto_fail_restart_delay
	elif _all_active_at_exit(players):
		phase = Phase.SUCCEEDED
		restart_in = Tuning.data.proto_fail_restart_delay


## 임시 목표: 쓰러지지 않은 플레이어가 모두 출구(방 C 끝) 가까이에 오면 원정 성공.
func _all_active_at_exit(players: Array) -> bool:
	var exit_pos: Vector3 = world.get_node("Exit").global_position
	var active := players.filter(func(p: Node) -> bool: return p.is_active())
	return not active.is_empty() and active.all(
		func(p: Node) -> bool: return horizontal_distance(p.global_position, exit_pos) <= Tuning.data.proto_exit_radius)


func _tick_oil(delta: float) -> void:
	_oil_accum += delta
	var interval: float = Tuning.data.oil_tick_interval
	while _oil_accum >= interval:
		_oil_accum -= interval
		if not drain_enabled:
			continue
		if oil_tank.has_oil():
			oil_tank.consume(oil_drain_per_minute() / 60.0 * interval)
		elif oil_tank.wick_left > 0.0:
			oil_tank.wick_left = maxf(oil_tank.wick_left - interval, 0.0)


## 어둠 게이지 (GDD 5.4, TUNING 3장).
func _tick_dark(player: Node, delta: float) -> void:
	var data: Resource = Tuning.data
	var pos: Vector3 = player.global_position
	var rate: float
	if is_in_big_light(pos):
		rate = -data.dark_decay_lit
	elif is_in_small_light(pos):
		rate = data.dark_gain_handlamp_only
	else:
		rate = data.dark_gain_unlit
	if rate > 0.0 and oil_tank.is_dark():
		rate *= data.dark_no_oil_gain_mult
	player.dark = clampf(player.dark + rate * delta, 0.0, data.dark_max)


func _tick_down(player: Node, delta: float) -> void:
	if not player.downed or player.knocked_out:
		return
	player.down_time_left = maxf(player.down_time_left - delta, 0.0)
	if player.down_time_left <= 0.0:
		player.knocked_out = true
		player.revive_progress = 0.0
		_revivers.erase(player.get_peer_id())


## 부활: 동료가 가까이에서 상호작용을 유지하고, 쓰러진 사람이 큰 등불 반경 안에 있어야 한다.
func _tick_revives(delta: float) -> void:
	for target_id in _revivers.keys():
		var target: Node = world.get_player(target_id)
		var reviver: Node = world.get_player(_revivers[target_id])
		if not _can_revive(reviver, target):
			if target != null:
				target.revive_progress = 0.0
			_revivers.erase(target_id)
			continue
		target.revive_progress += delta
		if target.revive_progress >= Tuning.data.down_revive_time:
			oil_tank.consume(Tuning.data.oil_revive_cost)
			_set_down(target, false)
			player_revived.emit(target_id, reviver.get_peer_id())


func _can_revive(reviver: Node, target: Node) -> bool:
	return (
		reviver != null and target != null and reviver != target and reviver.is_active()
		and target.downed and not target.knocked_out
		and reviver.global_position.distance_to(target.global_position) <= Tuning.data.proto_interact_range
		and is_in_big_light(target.global_position)
	)


## 클라이언트·호스트 공용 입구. 호스트는 바로 처리하고, 클라이언트는 호스트로 보낸다.
func send_request(action: String, arg: int = 0) -> void:
	if is_host():
		_handle_request(multiplayer.get_unique_id(), action, arg)
	else:
		request.rpc_id(1, action, arg)


@rpc("any_peer", "reliable")
func request(action: String, arg: int) -> void:
	if is_host():
		_handle_request(multiplayer.get_remote_sender_id(), action, arg)


func _handle_request(sender: int, action: String, arg: int) -> void:
	var player: Node = world.get_player(sender)
	if player == null:
		return
	if action == ACT_DEBUG_RESTART:
		if sender == 1:
			reset_round(float(arg) if arg >= 0 else -1.0)
		return
	if phase != Phase.PLAYING:
		return
	var data: Resource = Tuning.data
	match action:
		ACT_DEBUG_DOWN_SELF:
			down_player(player)
		ACT_REVIVE_STOP:
			for target_id in _revivers.keys():
				if _revivers[target_id] == sender:
					var target: Node = world.get_player(target_id)
					if target != null:
						target.revive_progress = 0.0
					_revivers.erase(target_id)
	if not player.is_active():
		return
	match action:
		ACT_PICKUP_LANTERN:
			if lantern.holder_peer == 0 and horizontal_distance(player.global_position, lantern.ground_position) <= data.proto_interact_range:
				lantern.holder_peer = sender
		ACT_DROP_LANTERN:
			if lantern.holder_peer == sender:
				_drop_lantern(player)
		ACT_GIVE_LANTERN:
			if lantern.holder_peer == sender:
				var other: Node = world.nearest_player(player.global_position, data.proto_give_range, player)
				if other != null:
					lantern.holder_peer = other.get_peer_id()
		ACT_LANTERN_LEVEL:
			if lantern.holder_peer == sender:
				var max_level := 1 if oil_tank.is_low() else 2
				lantern.level = clampi(lantern.level + signi(arg), 0, max_level)
		ACT_PICKUP_BOTTLE:
			var bottle: Node3D = world.get_bottle(arg)
			if bottle != null and not bottle.taken and player.global_position.distance_to(bottle.global_position) <= data.proto_interact_range:
				bottle.taken = true
				oil_tank.add(data.oil_bottle_amount)
		ACT_REVIVE_START:
			var target: Node = world.get_player(arg)
			if target != null and not _revivers.has(arg) and _can_revive(player, target):
				_revivers[arg] = sender


func _drop_lantern(player: Node3D) -> void:
	var forward := -player.global_basis.z
	forward.y = 0.0
	var pos := player.global_position + forward.normalized() * 0.6 if forward.length() > 0.01 else player.global_position
	lantern.ground_position = Vector3(pos.x, player.global_position.y, pos.z)
	lantern.holder_peer = 0
