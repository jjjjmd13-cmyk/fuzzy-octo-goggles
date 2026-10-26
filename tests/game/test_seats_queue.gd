extends "res://tests/qa_test.gd"
## 대기석 3자리 + 입구 밖 줄 3마리, 그 이상은 안 옴. 자리가 비면 줄 맨 앞이 들어와 앉음 (GDD_V2 4.2 완료 조건 2).
## 인원별 간격: 1인 30초 / 2인 20초 표를 쓰는지도 본다.

const Guest := preload("res://scripts/game/guest.gd")


func run_test() -> void:
	time_limit_sec = 60.0
	var data: Resource = Tuning.data.duplicate()
	data.party_first_guest_delay = PackedFloat32Array([0.1, 0.1, 0.1, 0.1])
	data.party_guest_interval = PackedFloat32Array([0.3, 0.3, 0.3, 0.3])
	Tuning.data = data
	check_eq(data.party_value(load("res://data/balance/bath_balance.tres").party_guest_interval, 1), 30.0, "1인 간격 30초")
	check_eq(data.party_value(load("res://data/balance/bath_balance.tres").party_guest_interval, 2), 20.0, "2인 간격 20초")
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	var world := get_tree().current_scene
	var guests := world.get_node("Guests")
	# 가장 먼 자리까지 약 9 m / 2 m/s
	await get_tree().create_timer(6.5).timeout
	check_eq(guests.get_child_count(), 6, "자리 3 + 줄 3 까지만 옴")
	var seated := guests.get_children().filter(func(g: Node) -> bool: return g.phase == Guest.Phase.SEATED)
	var queued := guests.get_children().filter(func(g: Node) -> bool: return g.phase == Guest.Phase.QUEUED)
	check_eq(seated.size(), 3, "3마리 앉음")
	check_eq(queued.size(), 3, "3마리 줄 섬")
	for guest in queued:
		check(guest.ground_position.z > 6.5, "줄은 입구 밖 (z=%.1f)" % guest.ground_position.z)
		check(not guest.can_be_picked(), "줄 선 손님은 아직 못 듦")

	# 앉은 손님 하나를 들면 줄 맨 앞이 그 자리로
	var me: Node3D = world.get_player(1)
	var first: Node3D = seated[0]
	world.carry_rules.pick_up(first, me)
	await get_tree().create_timer(6.5).timeout
	var seated_after := guests.get_children().filter(func(g: Node) -> bool: return g.phase == Guest.Phase.SEATED)
	check_eq(seated_after.size(), 3, "빈자리에 줄 맨 앞이 앉음")
	check_eq(guests.get_children().filter(func(g: Node) -> bool: return g.phase == Guest.Phase.QUEUED).size(), 3,
		"줄이 다시 3마리 (빈 줄 자리에 새 손님)")
	await Net.leave_session()
