extends "res://tests/qa_test.gd"
## 사람 속도로 씻으면 한 단계가 얼마나 걸리나 (대표·QA 요청: 한 단계 약 20초, 한 마리 약 2분).
##
## 사람 흉내: 강아지가 보이는 상자 안을 좌우 지그재그로 HAND_SPEED px/s 로 문지르고,
## TURN_EVERY 초마다 회전판을 TURN_STEP 도 돌린다. 시간은 시뮬레이션 시간(프레임 1/60초)으로 센다.
## 단계마다 걸린 시간을 찍고, STAGE_LIMIT 초 안에 끝나는지 확인한다.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const STEP := 1.0 / 60.0
const HAND_SPEED := 800.0
const ROW_GAP := 40.0
const HALF := Vector2(170, 110)
const TURN_EVERY := 2.0
const TURN_STEP := 60.0
## 이 흉내 손은 사람보다 덜 헤맨다 (QA 무작위 궤적은 약 2배 느림). 그래서 흉내 손 기준
## 한 단계 STAGE_LIMIT 초, 한 마리 DOG_LIMIT 초 안이면 사람은 한 단계 약 20초, 한 마리 약 2분.
const STAGE_LIMIT := 25.0
const DOG_LIMIT := 80.0

var world: Node
var station: WashStation


func run_test() -> void:
	time_limit_sec = 150.0
	get_tree().root.size = Vector2i(1280, 800)
	get_tree().current_scene = null
	Net.start_offline()
	await Net.session_started
	world = get_tree().current_scene
	station = world.station
	for i in 3:
		await get_tree().physics_frame
	station.temperature = 0.5
	var total := 0.0
	for stage in [WashStation.Stage.WET, WashStation.Stage.SOAP, WashStation.Stage.RINSE, WashStation.Stage.TOWEL, WashStation.Stage.DRY]:
		station.tool = WashStation.STAGE_TOOL[stage]
		var seconds: float = await _human_stage(stage)
		total += seconds
		print("단계 %s: %.1f 초" % [WashStation.STAGE_NAMES[stage], seconds])
		check(seconds <= STAGE_LIMIT, "%s 가 %d초 안에 끝남 (%.1f 초)" % [WashStation.STAGE_NAMES[stage], STAGE_LIMIT, seconds])
	print("한 마리 다섯 단계: %.0f 초" % total)
	check(total <= DOG_LIMIT, "한 마리 %d초 안 (%.0f 초)" % [DOG_LIMIT, total])
	check(total >= 30.0, "너무 빨리 끝나지 않음 (%.0f 초)" % total)
	await Net.leave_session()


## 단계가 끝날 때까지 사람처럼 문지르고, 걸린 시뮬레이션 시간을 돌려준다 (못 끝내면 큰 값).
func _human_stage(stage: int) -> float:
	if not check_eq(station.stage, stage, "단계 순서"):
		return 999.0
	var t := 0.0
	var turn_left := TURN_EVERY
	var pos := Vector2(-HALF.x, -HALF.y)
	var dir := 1.0
	while station.stage == stage and t < STAGE_LIMIT * 2.0:
		# 1초(시뮬레이션)마다 실제 프레임을 넘겨 진행 보고·단계 넘김이 일어나게 한다
		for frame in 60:
			pos.x += dir * HAND_SPEED * STEP
			if absf(pos.x) > HALF.x:
				pos.x = clampf(pos.x, -HALF.x, HALF.x)
				dir = -dir
				pos.y += ROW_GAP
				if pos.y > HALF.y:
					pos.y = -HALF.y
			var press: bool = station.tool == WashStation.Tool.SHAMPOO and station.dose <= 0.0
			station.operate(_center() + pos, true, press, STEP)
			t += STEP
			turn_left -= STEP
			if turn_left <= 0.0:
				turn_left = TURN_EVERY
				station.turn(TURN_STEP)
				await get_tree().physics_frame
				await get_tree().physics_frame
		await get_tree().create_timer(WashStation.REPORT_INTERVAL * 1.5).timeout
	return t if station.stage != stage else 999.0


func _center() -> Vector2:
	var model: Node3D = station.dog.model
	return world.camera.unproject_position(model.to_global(model.body_center))
