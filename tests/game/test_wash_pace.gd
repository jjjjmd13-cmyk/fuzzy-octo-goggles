extends "res://tests/qa_test.gd"
## 사람 속도로 씻으면 단계마다 얼마나 걸리나 (GDD_V3 8.1-2 완료 조건 3, TUNING_V3 stage_target_seconds).
##
## 사람 흉내 손(tests/game/wash_hands.gd)이 단계마다 그 단계 손동작을 한다:
## 지그재그로 누른 채 훑기(적시기·드라이어) / 병 0.7초 누르기 / 동그라미(초당 2바퀴) / 위→아래 쓸기 / 0.13초마다 꾹.
## 저절로 도는 시간도 사람 시간에 넣는다. 단계마다 목표의 TOLERANCE 배 안에 끝나는지 본다.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const WashHands := preload("res://tests/game/wash_hands.gd")
## 흉내 손은 사람보다 덜 헤매고 덜 서툴다. 목표의 이 배 안이면 사람은 목표 근처로 본다.
const TOLERANCE_LOW := 0.4
const TOLERANCE_HIGH := 1.5

var world: Node
var station: WashStation


func run_test() -> void:
	time_limit_sec = 170.0
	get_tree().root.size = Vector2i(1280, 800)
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	world.input_enabled = false
	station = world.station
	var hands := WashHands.new(get_tree(), world)
	await hands.wait_washing()
	for i in 3:
		await get_tree().physics_frame
	station.temperature = 0.5
	var targets: PackedFloat32Array = Tuning.data.stage_target_seconds
	var total := 0.0
	for stage in range(WashStation.Stage.WET, WashStation.Stage.PAY):
		if not check_eq(station.stage, stage, "단계 순서"):
			break
		check_eq(station.tool, WashStation.STAGE_TOOL[stage], "%s 도구가 저절로 손에" % WashStation.STAGE_NAMES[stage])
		var seconds: float = await hands.do_stage(stage)
		total += seconds
		print("단계 %s: %.1f 초 (목표 %.0f)" % [WashStation.STAGE_NAMES[stage], seconds, targets[stage]])
		check(seconds <= targets[stage] * TOLERANCE_HIGH, "%s 가 목표의 %.1f배 안 (%.1f 초, 목표 %.0f)" % [WashStation.STAGE_NAMES[stage], TOLERANCE_HIGH, seconds, targets[stage]])
		# 샴푸 짜기는 누르는 시간(흉내 손 0.7초)이 곧 걸린 시간이라 아래쪽은 보지 않는다
		check(stage == WashStation.Stage.SQUEEZE or seconds >= targets[stage] * TOLERANCE_LOW, "%s 가 너무 빨리 끝나지 않음 (%.1f 초, 목표 %.0f)" % [WashStation.STAGE_NAMES[stage], seconds, targets[stage]])
	var target_total := 0.0
	for t in targets:
		target_total += t
	print("한 마리 여섯 단계: %.0f 초 (목표 %.0f)" % [total, target_total])
	await Net.leave_session()
