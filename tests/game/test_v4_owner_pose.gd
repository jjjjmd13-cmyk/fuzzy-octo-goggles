extends "res://tests/qa_test.gd"
## 주인 걸음 자세 (대표 요청 2026-11-11 ⑤, 사람 대표 의견 "팔을 앞으로 뻗은 좀비 같다"):
## 동물을 안고 있을 때만 팔을 굽혀 감싸고 (손이 안은 동물 아래·가슴 앞에서 모임), 빈손이면 팔을 내리고 걸을 때 앞뒤로 흔듦.
## 새 주인 모형 (ORDER_V4_OWNER) 의 Forearm_L/R (팔꿈치) 가 있으면 팔꿈치를 굽혀 감쌈.

const OWNER_SCENE := preload("res://scenes/art/sim/owner_model.tscn")
const OwnerModel := preload("res://scripts/sim/sim_owner_model.gd")
const FpGuests := preload("res://scripts/v4/fp_guests.gd")
## 지금 owner.glb 팔 길이 (어깨 → 손끝, m)
const ARM_LEN := 0.52


func run_test() -> void:
	time_limit_sec = 30.0
	var owner: Node3D = OWNER_SCENE.instantiate()
	add_child(owner)
	await get_tree().process_frame
	var arms: Array[Node3D] = [owner.find_child("Arm_L", true, false), owner.find_child("Arm_R", true, false)]
	var shoulder_y: float = owner.to_local(arms[0].global_position).y

	# 빈손으로 서 있기: 팔이 아래로
	owner.holding = false
	owner.go_wait(Vector3.ZERO, Vector3(0, 0, 5), 0.01, false)
	for i in 5:
		await get_tree().process_frame
	for arm in arms:
		var hand := _hand(owner, arm)
		check(hand.y < shoulder_y - ARM_LEN * 0.9 and absf(hand.z) < 0.1, "빈손으로 서면 팔이 아래로 (손 %s)" % hand)

	# 빈손으로 걷기: 팔을 내린 채 앞뒤로 흔듦 (양팔이 엇갈림), 앞으로 뻗지 않음
	owner.leave(Vector3(0, 0, 6), 3.0)
	var zs := [[], []]
	var opposite := 0
	for i in 60:
		await get_tree().process_frame
		var hands := [_hand(owner, arms[0]), _hand(owner, arms[1])]
		for k in 2:
			zs[k].append(hands[k].z)
			check(hands[k].y < shoulder_y - ARM_LEN * 0.8, "빈손 걷기: 손이 허리 아래 (%.2f)" % hands[k].y)
		if hands[0].z * hands[1].z < 0.0:
			opposite += 1
	for k in 2:
		check(zs[k].min() < -0.08 and zs[k].max() > 0.08, "빈손 걷기: 팔을 앞뒤로 흔듦 (%.2f ~ %.2f)" % [zs[k].min(), zs[k].max()])
	check(opposite > 40, "양팔이 엇갈려 흔들림 (%d / 60)" % opposite)

	# 안고 걷기: 팔을 굽혀 가슴 앞에서 감쌈 (손이 안은 동물 아래, 좀비처럼 곧게 뻗지 않음)
	owner.holding = true
	owner.enter(Vector3.ZERO, Vector3(0, 0, 6), 3.0)
	for i in 30:
		await get_tree().process_frame
		for arm in arms:
			var hand := _hand(owner, arm)
			var held: Vector3 = FpGuests.HELD_STANDING
			check(hand.z > 0.12 and hand.z < held.z + 0.12, "안고 걷기: 손이 가슴 앞 (z %.2f)" % hand.z)
			check(hand.y < held.y and hand.y > held.y - 0.25, "안고 걷기: 손이 안은 동물 바로 아래 (y %.2f, 동물 %.2f)" % [hand.y, held.y])
			check(absf(hand.x) < 0.12, "안고 걷기: 양손이 가운데로 모임 (x %.2f)" % hand.x)
			check(hand.y < shoulder_y - 0.3, "좀비처럼 앞으로 뻗지 않음 (손 높이 %.2f, 어깨 %.2f)" % [hand.y, shoulder_y])
	owner.free()

	# 팔꿈치가 있는 모형 (새 주인 Forearm_L/R): 안을 때 팔꿈치를 굽힘, 빈손이면 거의 폄
	var jointed := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	jointed.add_child(body)
	var forearms: Array[Node3D] = []
	for tag in ["L", "R"]:
		var arm := Node3D.new()
		arm.name = "Arm_" + tag
		arm.position = Vector3(0.16 if tag == "L" else -0.16, 1.2, 0)
		body.add_child(arm)
		var forearm := Node3D.new()
		forearm.name = "Forearm_" + tag
		forearm.position = Vector3(0, -0.27, 0)
		arm.add_child(forearm)
		forearms.append(forearm)
	jointed.set_script(OwnerModel)
	add_child(jointed)
	await get_tree().process_frame
	jointed.holding = false
	await get_tree().process_frame
	for forearm in forearms:
		check(absf(forearm.rotation.x) < 0.3, "빈손: 팔꿈치 거의 폄 (%.2f)" % forearm.rotation.x)
	jointed.holding = true
	await get_tree().process_frame
	for forearm in forearms:
		var tip := jointed.to_local(forearm.to_global(Vector3(0, -0.25, 0)))
		check(absf(forearm.rotation.x) > 0.8, "안을 때 팔꿈치를 굽힘 (%.2f)" % forearm.rotation.x)
		check(tip.z > 0.15 and absf(tip.x) < 0.14, "안을 때 손이 가슴 앞 가운데 (%s)" % tip)
	jointed.free()


## 팔 끝 (손) 자리, 주인 기준 (정면 +Z)
func _hand(owner: Node3D, arm: Node3D) -> Vector3:
	return owner.to_local(arm.to_global(Vector3(0, -ARM_LEN, 0)))
