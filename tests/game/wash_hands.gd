extends RefCounted
## 사람 손 흉내 (테스트 도우미): 목욕대 단계마다 다른 손동작을 화면 좌표로 한다.
## 실제 경로 그대로: 커서 위치 → WashStation.operate(누름, 막 누름) → 카메라 광선 → 마스크.
## 시간은 시뮬레이션 시간(프레임 STEP)으로 센다. 1초마다 실제 프레임을 넘겨 진행 보고·단계 넘김·저절로 돌기가 일어나게 한다.
##
##   var hands := WashHands.new(tree, world)
##   var seconds := await hands.do_stage(station.stage)

const WashStation := preload("res://scripts/sim/wash_station.gd")
const STEP := 1.0 / 60.0
## 손 속도 (px/s), 지그재그 줄 간격
const HAND_SPEED := 800.0
const ROW_GAP := 40.0
## 강아지가 보이는 상자 (몸 중심 기준 반폭, px)
const HALF := Vector2(150, 130)
## 원 그리기: 반지름 px, 초당 바퀴
const CIRCLE_RADIUS := 40.0
const CIRCLE_TURNS := 2.0
## 동그라미를 그리며 옮겨 가는 속도 (px/s)
const DRIFT_SPEED := 120.0

var tree: SceneTree
var world: Node
var station: WashStation
## 이번 단계에 쓴 시뮬레이션 시간
var elapsed := 0.0
## 시간 상한 (s): 넘으면 그만둔다
var limit := 60.0

var _since_sync := 0.0


func _init(scene_tree: SceneTree, world_node: Node) -> void:
	tree = scene_tree
	world = world_node
	station = world.station


## 지금 단계를 그 단계 손동작으로 끝까지 한다. 걸린 시뮬레이션 시간 (끝내지 못하면 999).
func do_stage(stage: int) -> float:
	# 앞 단계 끝을 호스트가 아직 안 넘겼으면 잠깐 기다린다 (진행 보고 간격)
	var wait := 0.0
	while station.stage < stage and wait < 2.0:
		await tree.process_frame
		wait += tree.root.get_process_delta_time()
	elapsed = 0.0
	_since_sync = 0.0
	match stage:
		WashStation.Stage.WET, WashStation.Stage.DRY:
			await _zigzag_hold(stage)
		WashStation.Stage.SQUEEZE:
			await squeeze(0.7)
		WashStation.Stage.SCRUB:
			await _circles(stage)
		WashStation.Stage.RINSE:
			await _pours(stage)
		WashStation.Stage.TOWEL:
			await _taps(stage)
	await _sync()
	return elapsed if station.stage != stage else 999.0


## 주인이 강아지를 맡길 때까지 기다린다
func wait_washing() -> void:
	while not station.is_washing() and station.stage < WashStation.Stage.PAY:
		await tree.process_frame


## 샴푸 병을 seconds 동안 누르고 뗀다 (강아지 몸 가운데)
func squeeze(seconds: float) -> void:
	station.tool = WashStation.Tool.BOTTLE
	var at := center()
	await _op(at, true, true)
	var t := 0.0
	while t < seconds:
		await _op(at, true, false)
		t += STEP
	await _op(at, false, false)


func center() -> Vector2:
	var model: Node3D = station.dog.model
	return world.camera.unproject_position(model.to_global(model.body_center))


## 적시기·드라이어: 누른 채 지그재그로 훑기
func _zigzag_hold(stage: int) -> void:
	var pos := -HALF
	var dir := 1.0
	while station.stage == stage and elapsed < limit:
		pos.x += dir * HAND_SPEED * STEP
		if absf(pos.x) > HALF.x:
			pos.x = clampf(pos.x, -HALF.x, HALF.x)
			dir = -dir
			pos.y += ROW_GAP
			if pos.y > HALF.y:
				pos.y = -HALF.y
		await _op(center() + pos, true, false)


## 문지르기: 동그라미를 그리며 몸 위를 천천히 지그재그로 옮겨 간다. 샴푸가 떨어지면(병을 다시 듦) 조금 더 짠다.
func _circles(stage: int) -> void:
	var drift := -HALF + Vector2.ONE * CIRCLE_RADIUS
	var dir := 1.0
	var angle := 0.0
	while station.stage == stage and elapsed < limit:
		if station.tool == WashStation.Tool.BOTTLE:
			await squeeze(0.6)
			continue
		angle += TAU * CIRCLE_TURNS * STEP
		drift.x += dir * DRIFT_SPEED * STEP
		if absf(drift.x) > HALF.x - CIRCLE_RADIUS:
			drift.x = clampf(drift.x, -HALF.x + CIRCLE_RADIUS, HALF.x - CIRCLE_RADIUS)
			dir = -dir
			drift.y += CIRCLE_RADIUS * 1.5
			if drift.y > HALF.y - CIRCLE_RADIUS:
				drift.y = -HALF.y + CIRCLE_RADIUS
		await _op(center() + drift + Vector2(cos(angle), sin(angle)) * CIRCLE_RADIUS, true, false)


## 헹구기: 위에서 아래로 쓸어내리기를 여러 x 자리에서
func _pours(stage: int) -> void:
	var height: float = world.get_viewport().get_visible_rect().size.y
	var xs := [-70.0, 0.0, 70.0, -35.0, 35.0]
	var i := 0
	while station.stage == stage and elapsed < limit:
		var x: float = xs[i % xs.size()]
		i += 1
		var start := center() + Vector2(x, -HALF.y - 40)
		await _op(start, true, true)
		var drag: float = height * (Tuning.data.rinse_pour_min_drag + 0.05)
		var t := 0.0
		while t < 0.4:
			t += STEP
			await _op(start + Vector2(0, drag * t / 0.4), true, false)
		await _op(start + Vector2(0, drag), false, false)
		# 다음 쓸기 전 손을 올리는 시간
		for k in 12:
			await _op(start, false, false)


## 수건: 몸 위 여러 곳을 꾹꾹 (클릭 간격 0.13초)
func _taps(stage: int) -> void:
	var spots: Array[Vector2] = []
	var y := -HALF.y + 20
	while y <= HALF.y - 20:
		var x := -HALF.x + 20
		while x <= HALF.x - 20:
			spots.append(Vector2(x, y))
			x += 45
		y += 45
	var i := 0
	while station.stage == stage and elapsed < limit:
		var at: Vector2 = center() + spots[i % spots.size()]
		i += 1
		await _op(at, true, true)
		for k in 7:
			await _op(at, k < 2, false)


## 한 프레임 손 움직임. 1초마다 실제 프레임을 넘기고, 저절로 도는 동안은 기다린다.
func _op(pos: Vector2, held: bool, pressed: bool) -> void:
	world.cursor = pos
	station.operate(pos, held, pressed, STEP)
	elapsed += STEP
	_since_sync += STEP
	if _since_sync >= 1.0 or station.turning_left != 0.0:
		_since_sync = 0.0
		await _sync()


func _sync() -> void:
	await tree.create_timer(WashStation.REPORT_INTERVAL * 1.5).timeout
	# 저절로 도는 동안은 손을 멈추고 기다린다 (그 시간도 사람 시간에 넣음)
	while station.turning_left != 0.0:
		elapsed += tree.root.get_process_delta_time()
		await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame
