extends Node
## 가게 영업 규칙 (호스트 권한, GDD_V2 4장).
##
## 호스트만 정한다: 손님 등장·자리·줄, 기계에 넣고 꺼내기, 보내기, 화나서 나감, 웅덩이, 영업 시간, 별.
## 클라이언트는 Space 를 누르면 send_use() 로 "쓰기"만 보낸다. 무엇을 할지(들기/넣기/꺼내기/보내기/
## 내려놓기)는 호스트가 use_action() 으로 정한다. 화면 안내도 같은 함수를 써서 결과가 같다.
## 효과음은 호스트가 play_sfx.rpc() 로 모두에게 울린다.

enum Phase { OPEN, RESULTS }

const Guest := preload("res://scripts/game/guest.gd")
const GUEST_SCENE := preload("res://scenes/guests/dog.tscn")
const PUDDLE_SCENE := preload("res://scenes/game/puddle.tscn")
## 기계·출구 판정 거리 = 들기 거리 + 이만큼 (기계는 물건보다 크므로)
const MACHINE_REACH_BONUS := 0.8
const EXIT_REACH_BONUS := 1.0
const SPLASH_PUDDLES := 3

# --- Sync (호스트 → 모두)
var phase: Phase = Phase.OPEN
var time_left := 180.0
var delivered := 0
var angry := 0
var stars := 0
var party_size := 1
## 판이 새로 시작될 때마다 1 씩 오른다
var round_id := 0
## 이번 판에 누군가 손님을 처음 들었는가. 시작 안내는 시간 대신 이것으로 끈다 (QA 리뷰: 손님이 오기 전에 안내가 사라짐).
var first_pickup_done := false

# --- 호스트 전용
var _spawn_timer := 0.0
var _guest_counter := 0
var _puddle_counter := 0
var _seats: Array[String] = []
var _queue: Array[String] = []
var _puddles: Array[String] = []

@onready var world: Node = get_parent()
@onready var carry_rules: Node = world.get_node("CarryRules")
@onready var guests: Node3D = world.get_node("Guests")
@onready var puddles: Node3D = world.get_node("Puddles")


func _ready() -> void:
	world.get_node("GuestSpawner").spawn_function = _create_guest
	world.get_node("PuddleSpawner").spawn_function = _create_puddle


func is_open() -> bool:
	return phase == Phase.OPEN


func machines() -> Array:
	return get_tree().get_nodes_in_group("machines").filter(func(m: Node) -> bool: return world.is_ancestor_of(m))


# ---------------------------------------------------------------- Space 한 버튼

## 지금 Space 로 할 일 {kind, target}. 없으면 빈 딕셔너리. 호스트 판정과 화면 안내가 같이 쓴다.
## kind: deliver(보내기) / load(기계에 넣기) / drop(내려놓기) / unload(기계에서 꺼내기) / pickup(들기)
func use_action(player: Node3D) -> Dictionary:
	var reach: float = Tuning.data.player_interact_range
	var held: Node3D = carry_rules.held_by(player.get_peer_id())
	if held != null:
		if held.is_in_group("guests"):
			if held.state == Guest.State.DRY and carry_rules.in_front(player, _exit().global_position, reach + EXIT_REACH_BONUS):
				return {"kind": "deliver", "target": held}
			for machine in machines():
				if machine.accepts(held) and carry_rules.in_front(player, machine.global_position, reach + MACHINE_REACH_BONUS):
					return {"kind": "load", "target": machine}
		return {"kind": "drop", "target": held}
	for machine in machines():
		if machine.done and carry_rules.in_front(player, machine.global_position, reach + MACHINE_REACH_BONUS):
			return {"kind": "unload", "target": machine}
	var item: Node3D = carry_rules.pickup_candidate(player)
	return {"kind": "pickup", "target": item} if item != null else {}


## Space 로 할 일이 없을 때 보여 줄 "다음에 할 일" (처음 하는 사람용). 없으면 "".
func next_step_hint(player: Node3D) -> String:
	var held: Node3D = carry_rules.held_by(player.get_peer_id())
	if held != null and held.is_in_group("guests"):
		match held.state:
			Guest.State.MUDDY:
				return "목욕(파랑 욕조)으로 데려가세요"
			Guest.State.WET:
				return "말리기(주황 드라이어)로!"
			Guest.State.DRY:
				return "출구(초록 문)로!"
		return ""
	for machine in machines():
		if machine.done:
			return "%s에서 다 된 손님을 꺼내세요" % machine.display_name
	var waiting := false
	for guest in guests.get_children():
		if guest.phase == Guest.Phase.ESCAPING or guest.phase == Guest.Phase.SHAKING:
			return "도망가는 강아지를 쫓아가서 Space 로 잡으세요"
		if guest.phase == Guest.Phase.SEATED or guest.phase == Guest.Phase.FREE:
			waiting = true
	return "대기석의 강아지에게 가서 Space" if waiting else ""


func send_use() -> void:
	if Net.is_host():
		_do_use(multiplayer.get_unique_id())
	else:
		request_use.rpc_id(1)


@rpc("any_peer", "reliable")
func request_use() -> void:
	if Net.is_host():
		_do_use(multiplayer.get_remote_sender_id())


func _do_use(sender: int) -> void:
	var player: Node3D = world.get_player(sender)
	if player == null or not is_open():
		return
	var action := use_action(player)
	match action.get("kind", ""):
		"deliver":
			var guest: Node3D = action.target
			guest.holder_peer = 0
			delivered += 1
			play_sfx.rpc("ding")
			guest.queue_free()
		"load":
			action.target.load_guest(carry_rules.held_by(sender))
		"drop":
			carry_rules.drop(action.target, player)
		"unload":
			carry_rules.pick_up(action.target.release(), player)
		"pickup":
			carry_rules.pick_up(action.target, player)


# ---------------------------------------------------------------- 영업

## 호스트 전용: 새 판. 손님·웅덩이를 치우고 시간·점수를 처음으로.
func reset_round() -> void:
	if not Net.is_host():
		return
	for guest in guests.get_children():
		guest.queue_free()
	for puddle in puddles.get_children():
		puddle.queue_free()
	for machine in machines():
		machine.release()
	var data: Resource = Tuning.data
	party_size = maxi(world.get_players().size(), 1)
	_seats.clear()
	for i in data.guest_seats:
		_seats.append("")
	_queue.clear()
	_puddles.clear()
	time_left = data.shop_duration
	delivered = 0
	angry = 0
	stars = 0
	_spawn_timer = data.party_value(data.party_first_guest_delay, party_size)
	for player in world.get_players():
		var marker: Node3D = world.get_spawn_marker(player.slot)
		player.teleport.rpc_id(player.get_peer_id(), marker.global_position, marker.global_rotation.y)
	phase = Phase.OPEN
	first_pickup_done = false
	round_id += 1


@rpc("any_peer", "reliable")
func request_restart() -> void:
	if Net.is_host() and phase == Phase.RESULTS:
		reset_round()


func send_restart() -> void:
	if Net.is_host():
		request_restart()
	else:
		request_restart.rpc_id(1)


func _physics_process(delta: float) -> void:
	if not Net.is_host() or not is_open():
		return
	var data: Resource = Tuning.data
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_finish()
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		# 인원은 지금 있는 사람 수로 (중간에 들어오면 간격이 바로 바뀜)
		party_size = maxi(world.get_players().size(), 1)
		_spawn_timer = data.party_value(data.party_guest_interval, party_size)
		_spawn_guest()


func _finish() -> void:
	var data: Resource = Tuning.data
	stars = 0
	if delivered >= data.party_value(data.party_star1_guests, party_size):
		stars = 1
	if delivered >= data.party_value(data.party_star2_guests, party_size):
		stars = 2
	if delivered >= data.party_value(data.party_star3_guests, party_size) \
			and (angry == 0 or not data.result_star3_requires_no_angry):
		stars = 3
	phase = Phase.RESULTS


# ---------------------------------------------------------------- 손님

func _spawn_guest() -> void:
	var seat := _seats.find("")
	if seat < 0 and _queue.size() >= Tuning.data.guest_queue_max:
		return  # 자리도 줄도 꽉 참 → 이번 손님은 안 옴
	_guest_counter += 1
	var guest_name := "Guest%d" % _guest_counter
	world.get_node("GuestSpawner").spawn({"name": guest_name, "position": _entry().global_position})
	var guest: Node3D = guests.get_node(guest_name)
	guest.patience = Tuning.data.heart_patience()
	if seat >= 0:
		_seat(guest, seat)
	else:
		_queue.append(guest_name)
		guest.phase = Guest.Phase.QUEUED
		_update_queue_targets()
	play_sfx.rpc("splat")


func _create_guest(data: Dictionary) -> Node:
	var guest := GUEST_SCENE.instantiate()
	guest.name = data.name
	guest.position = data.position
	return guest


func _seat(guest: Node3D, seat: int) -> void:
	_seats[seat] = guest.name
	guest.phase = Guest.Phase.ENTERING
	guest.walk_target = world.get_node("Seats").get_child(seat).global_position


func _update_queue_targets() -> void:
	var spots: Node = world.get_node("QueueSpots")
	for i in _queue.size():
		var guest: Node3D = guests.get_node_or_null(_queue[i])
		if guest != null:
			guest.walk_target = spots.get_child(mini(i, spots.get_child_count() - 1)).global_position


## 자리가 비면 줄 맨 앞 손님이 앉으러 들어온다.
func _free_seat_of(guest: Node) -> void:
	var seat := _seats.find(String(guest.name))
	if seat >= 0:
		_seats[seat] = ""
	_queue.erase(String(guest.name))
	while _seats.has("") and not _queue.is_empty():
		var next: Node3D = guests.get_node_or_null(_queue.pop_front())
		if next != null:
			_seat(next, _seats.find(""))
	_update_queue_targets()


func on_guest_picked(guest: Node) -> void:
	first_pickup_done = true
	_free_seat_of(guest)


func on_guest_shake(guest: Node3D) -> void:
	play_sfx.rpc("drip")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var radius: float = Tuning.data.escape_shake_splash_radius
	for i in SPLASH_PUDDLES:
		var angle := rng.randf() * TAU
		var r := rng.randf_range(0.4, radius)
		spawn_puddle(guest.ground_position + Vector3(sin(angle) * r, 0, cos(angle) * r))


func on_guest_angry(guest: Node3D) -> void:
	if guest.machine != null:
		guest.machine.release()
	if guest.is_held():
		guest.holder_peer = 0
	_free_seat_of(guest)
	guest.phase = Guest.Phase.ANGRY
	guest.walk_target = _entry().global_position
	angry += 1
	play_sfx.rpc("huff")
	get_tree().create_timer(Tuning.data.guest_angry_leave_time).timeout.connect(
		func() -> void:
			if is_instance_valid(guest):
				guest.queue_free())


func on_machine_done(machine: Node, guest: Node3D) -> void:
	play_sfx.rpc("bubble_pop" if machine.kind == machine.Kind.BATH else "poof")
	if Tuning.data.machine_auto_eject_solo and party_size == 1:
		machine.release()
		guest.ground_position = world.clamp_to_floor(machine.global_position + machine.global_basis.z * 1.2)
		guest.on_dropped()


# ---------------------------------------------------------------- 웅덩이

func spawn_puddle(pos: Vector3) -> void:
	_puddles = _puddles.filter(func(n: String) -> bool: return puddles.has_node(n))
	while _puddles.size() >= Tuning.data.puddle_max:
		var oldest := puddles.get_node_or_null(_puddles.pop_front())
		if oldest != null:
			oldest.queue_free()
	_puddle_counter += 1
	var puddle_name := "Puddle%d" % _puddle_counter
	var floor_pos: Vector3 = world.clamp_to_floor(pos)
	world.get_node("PuddleSpawner").spawn({"name": puddle_name, "position": Vector3(floor_pos.x, 0.01, floor_pos.z)})
	_puddles.append(puddle_name)


func _create_puddle(data: Dictionary) -> Node:
	var puddle := PUDDLE_SCENE.instantiate()
	puddle.name = data.name
	puddle.position = data.position
	return puddle


# ---------------------------------------------------------------- 공용

@rpc("authority", "call_local", "reliable")
func play_sfx(sound: String) -> void:
	world.get_node("Sfx").play(sound)


func _entry() -> Node3D:
	return world.get_node("Entry")


func _exit() -> Node3D:
	return world.get_node("Exit")
