extends "res://tests/qa_test.gd"
## 주인 걸음 자세 (대표 요청 2026-11-11 ⑤, 사람 대표 의견 "팔을 앞으로 뻗은 좀비 같다"):
## 동물을 안고 있을 때만 팔을 굽혀 감싸고 (손이 안은 동물 아래·가슴 앞에서 모임), 빈손이면 팔을 내리고 걸을 때 앞뒤로 흔듦.
## 새 주인 모형 (ORDER_V4_OWNER) 의 Forearm_L/R (팔꿈치) 가 있으면 팔꿈치를 굽혀 감쌈.

const OWNER_SCENE := preload("res://scenes/art/sim/owner_model.tscn")
const OwnerModel := preload("res://scripts/sim/sim_owner_model.gd")
const FpOwners := preload("res://scripts/v4/fp_owners.gd")


func run_test() -> void:
	time_limit_sec = 60.0
	# 예전 주인 + 주인 4종 (#158, 팔꿈치 있음)
	var scenes := [OWNER_SCENE]
	for kind in FpOwners.kinds():
		scenes.append(load(FpOwners.SCENE_DIR % kind))
	check(scenes.size() == 5, "주인 4종 모형 연결 (%d)" % (scenes.size() - 1))
	for scene in scenes:
		await _check_owner(scene)
	# 손님마다 차례로 다른 주인
	check(FpOwners.scene(0) != FpOwners.scene(1), "손님마다 다른 주인 모형")
	await _check_jointed()


func _check_owner(scene: PackedScene) -> void:
	var owner: Node3D = scene.instantiate()
	add_child(owner)
	await get_tree().process_frame
	var label := (scene.resource_path as String).get_file()
	var shoulder_y: float = owner.shoulder_y
	var arm: float = owner.arm_length
	var height: float = owner.standing_height
	check(shoulder_y > height * 0.5 and shoulder_y < height and arm > 0.2 and arm < height * 0.45, "%s: 어깨 %.2f · 팔 %.2f (키 %.2f)" % [label, shoulder_y, arm, height])

	# 빈손으로 서 있기: 팔이 아래로
	owner.holding = false
	owner.go_wait(Vector3.ZERO, Vector3(0, 0, 5), 0.01, false)
	for i in 5:
		await get_tree().process_frame
	for i in 2:
		var hand := owner.to_local(owner.hand_point(i))
		check(hand.y < shoulder_y - arm * 0.85 and absf(hand.z) < arm * 0.25, "%s: 빈손으로 서면 팔이 아래로 (손 %s)" % [label, hand])

	# 빈손으로 걷기: 팔을 내린 채 앞뒤로 흔듦 (양팔이 엇갈림), 앞으로 뻗지 않음
	owner.leave(Vector3(0, 0, 6), 3.0)
	var zs := [[], []]
	var opposite := 0
	var low := true
	for i in 60:
		await get_tree().process_frame
		var hands := [owner.to_local(owner.hand_point(0)), owner.to_local(owner.hand_point(1))]
		for k in 2:
			zs[k].append(hands[k].z)
			low = low and hands[k].y < shoulder_y - arm * 0.65
		if hands[0].z * hands[1].z < 0.0:
			opposite += 1
	check(low, "%s: 빈손 걷기: 손이 허리 아래" % label)
	for k in 2:
		check(zs[k].min() < -arm * 0.15 and zs[k].max() > arm * 0.15, "%s: 빈손 걷기: 팔을 앞뒤로 흔듦 (%.2f ~ %.2f)" % [label, zs[k].min(), zs[k].max()])
	check(opposite > 40, "%s: 양팔이 엇갈려 흔들림 (%d / 60)" % [label, opposite])

	# 안고 걷기: 팔을 굽혀 가슴 앞에서 감쌈 (손이 안은 동물 아래, 좀비처럼 곧게 뻗지 않음)
	owner.holding = true
	owner.enter(Vector3.ZERO, Vector3(0, 0, 6), 3.0)
	var held: Vector3 = FpOwners.held_point(owner, false)
	var bad := []
	for i in 30:
		await get_tree().process_frame
		for k in 2:
			var hand := owner.to_local(owner.hand_point(k))
			if not (hand.z > held.z * 0.4 and hand.z < held.z + arm * 0.3):
				bad.append("앞 z %.2f" % hand.z)
			if not (hand.y < held.y + 0.03 and hand.y > held.y - arm * 0.5):
				bad.append("높이 y %.2f (동물 %.2f)" % [hand.y, held.y])
			if not (absf(hand.x) < 0.13):
				bad.append("가운데 x %.2f" % hand.x)
	check(bad.is_empty(), "%s: 안고 걷기: 손이 가슴 앞, 안은 동물 바로 아래 가운데 %s" % [label, bad.slice(0, 3)])
	check(held.y < shoulder_y - 0.1 and held.y > height * 0.3, "%s: 안는 자리 높이 %.2f (키 %.2f)" % [label, held.y, height])
	owner.free()


## 팔꿈치 (Forearm_L/R) 만 있는 가장 단순한 모형: 안을 때 팔꿈치를 굽힘, 빈손이면 거의 폄
func _check_jointed() -> void:
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
		check(absf(forearm.rotation.x) > 0.5, "안을 때 팔꿈치를 굽힘 (%.2f)" % forearm.rotation.x)
		check(tip.z > 0.15 and absf(tip.x) < 0.14, "안을 때 손이 가슴 앞 가운데 (%s)" % tip)
	jointed.free()


