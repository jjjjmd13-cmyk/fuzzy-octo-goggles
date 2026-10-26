extends Node3D
## 목욕대 작업대 (GDD_V3 3장, 시제품 1-2 "단계마다 다른 손동작").
##
## 주인이 강아지를 데리고 와서 맡기면, 적시기 → 샴푸 짜기 → 문지르기 → 헹구기 → 수건 → 드라이어 순서로
## 씻기고, 주인이 반응하며 동전을 건네면 강아지가 주인에게 달려간다.
## 단계마다 손동작이 다르다 (3.1): 누르고 조준 / 누르는 시간 / 원 그리기 / 쓸어내리기 / 연타 / 휠 거리.
## 마우스 하나로 끝난다 (2장): 다음 도구가 저절로 손에 들리고, 보이는 쪽이 다 되면 강아지가 저절로 돈다.
##
## 권한:
## - 단계·진행 비율·기분·동전·손님·주인 단계는 호스트가 정하고 StationSync 로 보낸다 (혼자 하기 = 접속 없는 호스트).
## - 붓질(마스크)은 목욕대 자리의 "작업자" 한 사람 화면에서만 칠한다. 작업자는 진행 비율과
##   기분 변화·사건(펄쩍, 간지럼…)만 호스트에 보낸다. 다른 사람은 비율만 받아 셰이더에 넣는다.
## - 작업자 = 목욕대 자리에 먼저 앉은 사람 (호스트가 정함).
## 입력(마우스·패드)은 월드가 받아 operate() / adjust() / turn_step() 을 부른다.

signal stage_completed(stage: int)
## 몸 털기: 화면에 거품이 튐 (목욕대 자리 사람에게)
signal screen_foam
signal dose_failed

enum Stage { WET, SQUEEZE, SCRUB, RINSE, TOWEL, DRY, PAY }
enum Tool { SHOWER, BOTTLE, HAND, BUCKET, TOWEL, DRYER }
enum OwnerPhase { ARRIVE, WAIT, REACT, LEAVE }

## 단계별 마스크 채널 (샴푸 짜기는 마스크 없음)
const STAGE_CHANNEL := ["wet", "", "scrub", "rinse", "towel", "dry"]
const STAGE_TOOL := [Tool.SHOWER, Tool.BOTTLE, Tool.HAND, Tool.BUCKET, Tool.TOWEL, Tool.DRYER]
const STAGE_NAMES := ["적시기", "샴푸 짜기", "문지르기", "헹구기", "수건", "드라이어"]
const TOOL_NAMES := ["샤워기", "샴푸", "손", "바가지", "수건", "드라이어"]
const REPORT_INTERVAL := 0.1
## 남은 곳 반짝임은 진행이 (완료 비율 - 이 값) 을 넘으면 되풀이
const BLINK_BEFORE := 0.1
const COIN_PICK_PIXELS := 48.0
const TABLE_TOP := 0.9
const COIN_FONT := preload("res://assets/fonts/pretendard/Pretendard-Bold.otf")
const UiArt := preload("res://scripts/game/ui_art.gd")
## 원 그리기 판정에 쓰는 최근 손 궤적 길이 (s)
const STROKE_WINDOW := 0.7
## 이보다 작게 그리면 원으로 안 침 (px, 손떨림)
const CIRCLE_MIN_RADIUS := 10.0
## 보이는 쪽 판정에 쓰는 몸 방향 표본 수
const VISIBLE_SAMPLES := 500
## 주인 위치 (작업대 기준): 문 / 목욕통 옆 / 대기 의자
const OWNER_DOOR := Vector3(1.9, 0, 1.2)
const OWNER_FRONT := Vector3(1.05, 0, -0.2)
const OWNER_CHAIR := Vector3(0.95, 0, -0.78)
## 주인 말풍선이 대기 중에 보이는 시간 (s)
const BUBBLE_WAIT_TIME := 3.0

# --- StationSync (호스트가 씀)
## 손님 번호, 진흙 무늬, 무늬 시드, 복숭아 향 요청(0/1). 한 값으로 묶어 한꺼번에 도착하게 한다.
var dog_info := Vector4i(0, 0, 0, 0)
var stage := Stage.WET
## 지금 단계 진행 (0~1)
var ratio := 0.0
var mood := 0.7
var operator := 0
var yaw := 0.0
## 받을 동전 (값)
var coins := PackedInt32Array()
var used_peach := false
var dogs_done := 0
var owner_phase := OwnerPhase.ARRIVE
var owner_variant := 0

# --- 내 화면 (동기화하지 않음)
## 손에 든 도구 (단계가 바뀌면 저절로 바뀜, 도구걸이 클릭으로 직접 바꿀 수도 있음)
var tool := Tool.SHOWER
## 물 온도 (0~1, 휠)
var temperature := 0.5
## 드라이어 거리 (m, 휠)
var dryer_distance := 0.32
var camera: Camera3D
var store: Node
var sfx: Node
## 샴푸가 비어서 거품이 안 남 (안내용)
var out_of_shampoo := false
## 손에 남은 거품 양 (문지를 수 있는 몸 비율)
var dose := 0.0
## 샴푸 병을 누르고 있는 시간 (s) / 지금 짜는 중
var squeeze_time := 0.0
var squeezing := false
## 방금 너무 많이 짜서 넘쳤음 (안내용, 남은 시간)
var overflow_left := 0.0
## 원을 그리는 중인가 (문지르기, HUD·테스트용)
var circling := false
## 바가지를 쏟은 횟수 (이번 손님)
var pours := 0
## 지금 도구를 쓰는 중이고 강아지에 닿았는가 (HUD·테스트용)
var hitting := false
var water_state := ""
## 눈에 물 안내를 보여 줄 남은 시간 (작업자 화면)
var eye_warning_left := 0.0
## 회전판이 저절로 도는 중 (남은 각도, 라디안)
var turning_left := 0.0
## 이번 손님에서 돈 횟수 (저절로 + 화살표, 테스트·HUD용)
var turns := 0

@onready var turntable: Node3D = $Turntable
@onready var dog: Node3D = $Turntable/Dog
@onready var camera_point: Marker3D = $CameraPoint
@onready var coin_root: Node3D = $Coins
@onready var owner_model: Node3D = $Owner

var _built_serial := -1
var _seen_stage := -1
var _seen_owner_phase := -1
var _owner_phase_time := 0.0
var _was_operator := false
var _local_yaw := 0.0
var _report_left := 0.0
var _mood_delta := 0.0
var _last_hit: Variant = null
var _aim: Variant = null
var _was_held := false
var _press_pos := Vector2.ZERO
var _poured := false
var _stroke: Array[Vector3] = []
var _stroke_time := 0.0
var _press_cooldown := 0.0
var _tickle_anchor: Variant = null
var _tickle_time := 0.0
var _tickled := false
var _cold_cooldown := 0.0
var _eye_cooldown := 0.0
var _cheek_cooldown := 0.0
var _foam_carry := 0.0
var _blink_left := 0.0
var _blink_wait := 0.0
var _dose_pending := false
var _squeeze_paid := false
var _squeeze_point := Vector3.ZERO
var _squeeze_done := false
var _turn_speed := 0.0
var _turn_check := 0.0
var _look_owner_in := 4.0
var _look_owner_left := 0.0
var _samples := PackedVector3Array()
var _rng := RandomNumberGenerator.new()
var _drops_scattered := false
# 호스트만
var _dose_paid := false
var _host_dose_kind := ""
var _owner_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	camera_point.look_at($LookTarget.global_position)
	# 처음엔 비스듬히 (옆모습이 조금 보이게)
	_local_yaw = 0.6
	yaw = 0.6
	# 목욕대 뒤 배경 그림이 있으면 타일 벽 대신 쓴다 (assets/ui/bath_backdrop.png)
	var backdrop := UiArt.texture("bath_backdrop")
	if backdrop != null:
		var wall_material := StandardMaterial3D.new()
		wall_material.albedo_texture = backdrop
		$Wall.material_override = wall_material
		$Wall/Window.visible = false
	# 가게 간판 그림이 있으면 뒤 벽에 건다 (assets/ui/sign.png)
	var sign_picture := UiArt.texture("sign")
	if sign_picture != null:
		var sign_material := StandardMaterial3D.new()
		sign_material.albedo_texture = sign_picture
		sign_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		$Sign.material_override = sign_material
		$Sign.visible = true
		# 간판 가운데 빈칸에 가게 이름을 글자로 (그림에는 글자가 없음)
		var shop_name := Label3D.new()
		shop_name.text = "멍냥 목욕탕"
		shop_name.font = COIN_FONT
		shop_name.font_size = 96
		shop_name.pixel_size = 0.0016
		shop_name.outline_size = 18
		shop_name.modulate = Color(1, 1, 1)
		shop_name.outline_modulate = Color(0.85, 0.35, 0.5)
		shop_name.position = Vector3(0.08, 0, 0.01)
		$Sign.add_child(shop_name)
	# 보이는 쪽 판정용 몸 방향 표본 (피보나치 구, 배 밑 제외)
	var golden := PI * (3.0 - sqrt(5.0))
	for i in VISIBLE_SAMPLES:
		var y := 1.0 - (i + 0.5) / VISIBLE_SAMPLES * 2.0
		if y < -0.6:
			continue
		var r := sqrt(1.0 - y * y)
		_samples.append(Vector3(cos(golden * i) * r, y, sin(golden * i) * r))


## 호스트: 영업 시작 (첫 손님)
func reset() -> void:
	if not Net.is_host():
		return
	dogs_done = 0
	new_dog()


## 호스트: 다음 손님 (주인이 강아지를 데리고 들어옴).
func new_dog() -> void:
	if not Net.is_host():
		return
	var data: Resource = Tuning.data
	var pattern := _rng.randi_range(0, maxi(data.mask_patterns, 1) - 1)
	var peach := 1 if _rng.randf() < data.proto_peach_request_chance else 0
	dog_info = Vector4i(dog_info.x + 1, pattern, _rng.randi() & 0x3fffffff, peach)
	stage = Stage.WET
	ratio = 0.0
	mood = data.mood_start
	coins = PackedInt32Array()
	used_peach = false
	_dose_paid = false
	_host_dose_kind = ""
	owner_variant = _rng.randi_range(0, maxi(data.owner_variants, 1) - 1)
	owner_phase = OwnerPhase.ARRIVE
	_owner_timer = data.proto_owner_arrive_time


func wants_peach() -> bool:
	return dog_info.w == 1


func dog_number() -> int:
	return dog_info.x


func is_operator() -> bool:
	return operator != 0 and operator == multiplayer.get_unique_id()


## 손으로 씻는 중인가 (주인이 맡긴 뒤, 계산 전)
func is_washing() -> bool:
	return owner_phase == OwnerPhase.WAIT and stage < Stage.PAY


func stage_tool() -> int:
	return STAGE_TOOL[stage] if stage < Stage.PAY else -1


func mood_face() -> int:
	return Tuning.data.mood_face(mood)


## 단계별 진행 (0~1). 끝난 단계는 1.
func stage_ratio(index: int) -> float:
	if index < stage:
		return 1.0
	return ratio if index == stage else 0.0


## 주인 말풍선을 보여 줄 때인가 (들어올 때 + 맡긴 직후 잠깐)
func owner_bubble_visible() -> bool:
	return owner_phase == OwnerPhase.ARRIVE or (owner_phase == OwnerPhase.WAIT and _owner_phase_time < BUBBLE_WAIT_TIME)


## 다음에 할 일 (노란 안내)
func next_hint() -> String:
	match owner_phase:
		OwnerPhase.ARRIVE:
			return "손님이 왔어요! 주인이 강아지를 맡겨요"
		OwnerPhase.REACT, OwnerPhase.LEAVE:
			return "주인이 건넨 동전을 눌러 받으세요" if not coins.is_empty() else "고마워요! 다음 손님이 와요"
	if stage == Stage.PAY:
		return "동전을 눌러 받으세요"
	if out_of_shampoo and (stage == Stage.SQUEEZE or stage == Stage.SCRUB):
		return "샴푸가 떨어졌어요! Tab 으로 컴퓨터 자리에 가서 사세요"
	if overflow_left > 0.0:
		return "앗, 너무 많이 짰어요! 거품이 넘쳐 샴푸를 더 썼어요"
	if turning_left != 0.0:
		return "강아지를 돌리는 중…"
	match tool:
		Tool.SHOWER:
			return "누르는 동안 물이 나와요. 몸 전체를 적시세요 (휠 = 물 온도, 초록이 좋아요)"
		Tool.BOTTLE:
			return "병을 누르고 있으면 샴푸가 나와요. 적당히 짜고 떼세요 (너무 많으면 넘쳐요)"
		Tool.HAND:
			return "동그랗게 원을 그리며 문지르세요! 빠를수록 거품이 커져요" if circling or dose > 0.0 else "샴푸를 다 썼어요. 병을 눌러 더 짜세요"
		Tool.BUCKET:
			return "바가지: 위에서 아래로 쭉 끌어내려 물을 쏟으세요"
		Tool.TOWEL:
			return "수건으로 물방울을 꾹꾹 눌러 닦으세요 (여러 번 클릭)"
		_:
			return "드라이어로 말리세요 (휠 = 거리, 가까울수록 빠르지만 너무 가까우면 싫어해요)"


## 휠 한 칸 (+1 = 위로): 그 단계의 '양' (물 온도, 드라이어 거리)
func adjust(steps: int) -> void:
	var data: Resource = Tuning.data
	match tool:
		Tool.SHOWER:
			temperature = clampf(temperature + steps * data.proto_temp_wheel_step, 0.0, 1.0)
		Tool.DRYER:
			var range_m: PackedFloat32Array = data.dryer_distance_range
			dryer_distance = clampf(dryer_distance - steps * data.dryer_wheel_step, range_m[0], range_m[1])


## 회전판 바로 돌리기 (시험·패드용)
func turn(degrees: float) -> void:
	if is_operator():
		_local_yaw = wrapf(_local_yaw + deg_to_rad(degrees), -PI, PI)
		_send_yaw.rpc_id(1, _local_yaw)


## 회전판 화살표 / 저절로 돌기: 한 번에 proto_turn_step 도를 auto_turn_time 동안 (direction = ±1)
func turn_step(direction: int) -> void:
	if not is_operator() or turning_left != 0.0:
		return
	var data: Resource = Tuning.data
	turning_left = deg_to_rad(data.proto_turn_step) * signf(direction)
	turns += 1
	_turn_speed = absf(turning_left) / maxf(data.auto_turn_time, 0.01)


## 작업자: 이번 프레임 도구 사용. held = 쓰는 버튼을 누르고 있음, pressed = 이번에 막 누름.
func operate(screen_pos: Vector2, held: bool, pressed: bool, delta: float) -> void:
	hitting = false
	water_state = ""
	var released := _was_held and not held
	_was_held = held
	if not is_operator() or dog.model == null or not is_washing() or turning_left != 0.0:
		_stop_loops()
		_last_hit = null
		_aim = null
		if released and squeezing:
			_release_squeeze()
		return
	var aim: Variant = dog.ray_hit(camera, screen_pos)
	_aim = aim
	var hit: Variant = aim if held else null
	hitting = hit != null
	_cold_cooldown = maxf(_cold_cooldown - delta, 0.0)
	_eye_cooldown = maxf(_eye_cooldown - delta, 0.0)
	_cheek_cooldown = maxf(_cheek_cooldown - delta, 0.0)
	_press_cooldown = maxf(_press_cooldown - delta, 0.0)
	var speed := 0.0
	if hit != null and _last_hit != null and delta > 0.0:
		speed = (hit as Vector3).distance_to(_last_hit) / delta
	_last_hit = hit
	if pressed:
		_press_pos = screen_pos
		_poured = false

	var spraying := false
	match tool:
		Tool.SHOWER:
			spraying = held
			_use_shower(screen_pos, hit, held, delta)
		Tool.BOTTLE:
			_use_bottle(aim, held, pressed, released, delta)
		Tool.HAND:
			_use_hand(screen_pos, held, hit, speed, delta)
		Tool.BUCKET:
			spraying = _use_bucket(screen_pos, held)
		Tool.TOWEL:
			_use_towel(hit, pressed)
		Tool.DRYER:
			_use_dryer(hit, held, delta)
	# 강아지가 커서를 따라본다. 물이 얼굴로 오면 고개를 돌리고 눈을 감는다 (눈에 물 들어가기 전 신호)
	if dog.model.has_method("watch"):
		dog.model.watch(aim, spraying)
	if tool != Tool.HAND or hit == null:
		_tickle_anchor = null
		_tickle_time = 0.0
		sfx.set_loop("scrub", 0.0)
	if not (tool == Tool.SHOWER and stage == Stage.WET and hit != null):
		dog.stop_drip()
	if tool != Tool.SHOWER or not held:
		sfx.set_loop("shower", 0.0)
		dog.stop_spray()
		dog.hide_stream()
	if tool != Tool.DRYER or not held:
		sfx.set_loop("dryer", 0.0)


## 동전이 이 화면 위치에 있으면 그 번호, 없으면 -1.
func coin_at(screen_pos: Vector2) -> int:
	if camera == null:
		return -1
	for i in coin_root.get_child_count():
		var coin: Node3D = coin_root.get_child(i)
		if camera.is_position_behind(coin.global_position):
			continue
		if camera.unproject_position(coin.global_position).distance_to(screen_pos) <= COIN_PICK_PIXELS:
			return i
	return -1


func send_collect(index: int) -> void:
	_request_collect.rpc_id(1, dog_info.x, index)


## 회전판 가장자리 화살표 위치 (화면 좌표, 왼쪽·오른쪽)
func turn_arrow_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	if camera == null:
		return points
	for side in [-1.0, 1.0]:
		points.append(camera.unproject_position(to_global(Vector3(side * 0.5, TABLE_TOP + 0.08, 0.32))))
	return points


## 주인 머리 위 (말풍선 자리, 월드 좌표)
func owner_bubble_point() -> Vector3:
	var height: Variant = owner_model.get("height")
	return owner_model.global_position + Vector3(0, (height if height != null else 1.0) * owner_model.scale.y + 0.2, 0)


# --- 손동작 6개

## ③ 적시기: 누르는 동안 물줄기가 나오고 커서가 조준점. 휠 = 온도.
func _use_shower(screen_pos: Vector2, hit: Variant, held: bool, delta: float) -> void:
	var data: Resource = Tuning.data
	sfx.set_loop("shower", 0.8 if held else 0.0)
	if not held:
		return
	var nozzle := camera.global_position + camera.global_basis * Vector3(0.35, -0.25, -0.6)
	var target: Vector3 = hit if hit != null else camera.project_position(screen_pos, 1.6)
	dog.show_stream(nozzle, target, _water_color())
	if hit == null:
		dog.stop_spray()
		return
	dog.spray(hit)
	var good: PackedFloat32Array = data.tool_shower_temp_good
	if temperature < good[0]:
		water_state = "cold"
		if _cold_cooldown <= 0.0:
			_cold_cooldown = data.proto_cold_cooldown
			_report_event.rpc_id(1, dog_info.x, "cold")
	elif temperature > good[1]:
		water_state = "hot"
		_mood_delta += data.mood_hot_water * delta
	else:
		water_state = "good"
		_mood_delta += data.mood_good_water * delta
	if dog.is_face(hit):
		_eye_hit()
	if stage == Stage.WET:
		dog.paint("wet", hit, data.tool_shower_radius, data.tool_shower_rate * delta)
		if dog.mask.mud_at(dog.dir_of(hit)) > 0.2:
			dog.drip(hit)
		else:
			dog.stop_drip()
	else:
		# 다른 단계에 물을 뿌리면 거품만 씻겨 나간다
		dog.rinse_foam(hit, data.tool_shower_radius, delta * 4.0)


## 물 색: 차가우면 파랑, 좋으면 연한 하늘색, 뜨거우면 빨강
func _water_color() -> Color:
	var good: PackedFloat32Array = Tuning.data.tool_shower_temp_good
	if temperature < good[0]:
		return Color(0.3, 0.45, 1.0)
	if temperature > good[1]:
		return Color(1.0, 0.45, 0.35)
	return Color(0.55, 0.85, 1.0)


## ④-1 샴푸 짜기: 누르고 있는 시간 = 짜는 양. 병이 찌그러지고 덩이가 커지다가, 떼면 몸에 떨어진다.
func _use_bottle(aim: Variant, held: bool, pressed: bool, released: bool, delta: float) -> void:
	var data: Resource = Tuning.data
	if pressed and aim != null and not squeezing:
		squeezing = true
		squeeze_time = 0.0
		_squeeze_point = aim
		if not _squeeze_paid and not _dose_pending:
			# 이번 손님 처음 짤 때 병에서 한 마리분을 쓴다 (호스트가 확인)
			_dose_pending = true
			_request_dose.rpc_id(1, dog_info.x, 1)
		sfx.play("squirt")
	if squeezing and held:
		squeeze_time = minf(squeeze_time + delta, data.squeeze_max_time)
		if aim != null:
			_squeeze_point = aim
		dog.show_glob(_squeeze_point, squeeze_amount() / maxf(data.squeeze_coverage_max, 0.01))
	if released and squeezing:
		_release_squeeze()


## 지금 짠 양 (문지를 수 있는 몸 비율)
func squeeze_amount() -> float:
	var data: Resource = Tuning.data
	return clampf(squeeze_time / maxf(data.squeeze_max_time, 0.01), 0.0, 1.0) * data.squeeze_coverage_max


func _release_squeeze() -> void:
	var data: Resource = Tuning.data
	squeezing = false
	dog.hide_glob()
	if out_of_shampoo:
		return
	var amount := squeeze_amount()
	if amount < 0.02:
		return
	dose += amount
	dog.add_foam(_squeeze_point, 3 + int(amount * 20.0), _rng)
	sfx.play("bubble_pop")
	if amount > data.squeeze_overflow_at:
		# 너무 많이 짰다: 거품이 흘러내리고 병을 한 번 더 쓴다
		overflow_left = 2.5
		dog.overflow_foam(_squeeze_point, _rng)
		_request_dose.rpc_id(1, dog_info.x, 2)
	_squeeze_done = true
	# 다 짰으면 손으로 바꿔 든다
	tool = Tool.HAND


## ④-2 문지르기: 원 그리기. 최근 궤적이 scrub_circle_min_angle 이상 돌았으면 원,
## 아니면(왕복) 거품이 scrub_back_forth_rate 배로만 는다. 빠를수록 빨리 크게.
func _use_hand(screen_pos: Vector2, held: bool, hit: Variant, speed: float, delta: float) -> void:
	var data: Resource = Tuning.data
	_stroke_time += delta
	if not held:
		_stroke.clear()
		circling = false
		return
	# 원 판정은 커서 궤적으로 (원이 몸 가장자리를 살짝 벗어나도 이어지게)
	_stroke.append(Vector3(screen_pos.x, screen_pos.y, _stroke_time))
	while not _stroke.is_empty() and _stroke[0].z < _stroke_time - STROKE_WINDOW:
		_stroke.pop_front()
	circling = _stroke_angle() >= deg_to_rad(data.scrub_circle_min_angle)
	if hit == null:
		return
	if dog.is_face(hit):
		_eye_hit()
	if stage != Stage.SCRUB:
		return
	if dose <= 0.0:
		sfx.set_loop("scrub", 0.0)
		# 샴푸가 떨어지면 병을 다시 든다 (마우스 하나로 계속)
		if not out_of_shampoo:
			tool = Tool.BOTTLE
		return
	var multiplier: float = 1.0 if circling else data.scrub_back_forth_rate
	var rate := minf(data.tool_scrub_rate_per_speed * speed, data.tool_scrub_rate_max) * multiplier
	sfx.set_loop("scrub", clampf(rate / data.tool_scrub_rate_max, 0.0, 1.0))
	if rate <= 0.0:
		return
	var added: float = dog.paint("scrub", hit, data.tool_scrub_radius, rate * delta)
	dose = maxf(dose - added, 0.0)
	_foam_carry += data.foam_ball_per_scrub * minf(speed, 3.0) * multiplier * delta
	if _foam_carry >= 1.0:
		dog.add_foam(hit, int(_foam_carry), _rng, 1.0 + minf(speed, 2.0) * 0.4)
		_foam_carry -= int(_foam_carry)
	_update_tickle(hit, delta)


## 최근 궤적이 무게중심을 몇 라디안 돌았나 (한 방향으로 돈 만큼, 왕복은 서로 지워짐)
func _stroke_angle() -> float:
	if _stroke.size() < 6:
		return 0.0
	var center := Vector2.ZERO
	for p in _stroke:
		center += Vector2(p.x, p.y)
	center /= _stroke.size()
	var total := 0.0
	var radius := 0.0
	var previous := Vector2(_stroke[0].x, _stroke[0].y) - center
	for i in range(1, _stroke.size()):
		var current := Vector2(_stroke[i].x, _stroke[i].y) - center
		radius += current.length()
		# 가운데를 가로지르는 직선(왕복)은 반 바퀴씩 튀므로 세지 않는다
		var turn_step := previous.angle_to(current)
		if current.length() >= CIRCLE_MIN_RADIUS * 0.5 and previous.length() >= CIRCLE_MIN_RADIUS * 0.5 and absf(turn_step) < 1.5:
			total += turn_step
		previous = current
	if radius / (_stroke.size() - 1) < CIRCLE_MIN_RADIUS:
		return 0.0
	return absf(total)


## ⑤ 헹구기: 바가지를 누른 채 위→아래로 rinse_pour_min_drag 만큼 끌면 쏟아진다 (누를 때마다 한 번).
## 그 자리 세로 띠(rinse_pour_band_width)의 거품이 한 번에 씻긴다. 쏟는 중이면 true.
func _use_bucket(screen_pos: Vector2, held: bool) -> bool:
	var data: Resource = Tuning.data
	if not held or _poured:
		return false
	var height := get_viewport().get_visible_rect().size.y
	if screen_pos.y - _press_pos.y < data.rinse_pour_min_drag * height:
		return false
	_poured = true
	pours += 1
	sfx.play("pour")
	_pour_band(screen_pos.x)
	return true


func _pour_band(screen_x: float) -> void:
	var data: Resource = Tuning.data
	var model: Node3D = dog.model
	var center: Vector3 = model.to_global(model.body_center)
	# 띠 폭을 화면 픽셀로 (강아지 깊이에서)
	var half := absf(camera.unproject_position(center + camera.global_basis.x * data.rinse_pour_band_width * 0.5).x - camera.unproject_position(center).x)
	var top := camera.unproject_position(center + Vector3(0, 0.45, 0)).y
	var bottom := camera.unproject_position(center - Vector3(0, 0.35, 0)).y
	var head_hit := false
	var hits: Array[Vector3] = []
	var y := top
	while y <= bottom:
		var x := screen_x - half
		while x <= screen_x + half:
			var hit: Variant = dog.ray_hit(camera, Vector2(x, y))
			if hit != null:
				dog.paint("rinse", hit, 0.06, 1.0)
				dog.rinse_foam(hit, 0.08, 10.0)
				hits.append(hit)
				head_hit = head_hit or dog.is_face(hit)
			x += 8.0
		y += 8.0
	dog.pour_effect(hits)
	if head_hit:
		# 머리 위로 쏟으면 눈을 꼭 감고 부르르 (벌점은 없음)
		_report_event.rpc_id(1, dog_info.x, "pour_head")


## ⑥-1 수건: 클릭할 때마다 꾹 (towel_press_area 도장, 최소 간격 towel_press_cooldown).
func _use_towel(hit: Variant, pressed: bool) -> void:
	var data: Resource = Tuning.data
	if not pressed or hit == null or _press_cooldown > 0.0:
		return
	_press_cooldown = data.towel_press_cooldown
	dog.paint("towel", hit, data.towel_press_area, 1.0)
	dog.press_effect(hit)
	sfx.play("press")
	if dog.dir_of(hit).normalized().y < -0.3:
		# 배를 꾹 누르면 "킁"
		sfx.play("squeak")


## ⑥-2 드라이어: 커서로 방향, 휠로 거리. 가까울수록 빠르고 털이 세게 날린다.
func _use_dryer(hit: Variant, held: bool, delta: float) -> void:
	var data: Resource = Tuning.data
	var range_m: PackedFloat32Array = data.dryer_distance_range
	var closeness := 1.0 - inverse_lerp(range_m[0], range_m[1], dryer_distance)
	sfx.set_loop("dryer", (0.5 + closeness * 0.5) if held else 0.0)
	if hit == null:
		return
	if dog.model.has_method("blow"):
		dog.model.blow(closeness)
	if dog.is_face(hit) and _cheek_cooldown <= 0.0:
		_cheek_cooldown = 0.5
		_report_event.rpc_id(1, dog_info.x, "cheek")
	if dryer_distance < data.proto_dryer_near:
		water_state = "too_close"
		_mood_delta += data.mood_dryer_too_close * delta
	if stage != Stage.DRY:
		return
	var t := inverse_lerp(data.proto_dryer_near, range_m[1], dryer_distance)
	var rate: float = lerpf(data.tool_dryer_rate_near, data.tool_dryer_rate_far, clampf(t, 0.0, 1.0))
	# 바람 부채꼴: 멀수록 넓게
	dog.paint("dry", hit, data.tool_shower_radius * (0.8 + dryer_distance * 2.5), rate * delta)


func _eye_hit() -> void:
	if _eye_cooldown > 0.0:
		return
	_eye_cooldown = Tuning.data.proto_eye_cooldown
	eye_warning_left = 3.0
	_report_event.rpc_id(1, dog_info.x, "eye")


## 같은 곳(proto_tickle_radius)을 tickle_time 문지르면 다리 찰랑, shake_time 이면 몸 털기.
func _update_tickle(hit: Vector3, delta: float) -> void:
	var data: Resource = Tuning.data
	var local: Vector3 = dog.to_model(hit)
	if _tickle_anchor == null or (_tickle_anchor as Vector3).distance_to(local) > data.proto_tickle_radius:
		_tickle_anchor = local
		_tickle_time = 0.0
		_tickled = false
	_tickle_time += delta
	if not _tickled and _tickle_time >= data.tickle_time:
		_tickled = true
		_report_event.rpc_id(1, dog_info.x, "tickle")
	if _tickle_time >= data.shake_time:
		_tickle_time = 0.0
		_tickled = false
		_report_event.rpc_id(1, dog_info.x, "shake")


func _stop_loops() -> void:
	if sfx == null:
		return
	for sound in ["shower", "scrub", "dryer"]:
		sfx.set_loop(sound, 0.0)
	if dog.model != null:
		dog.stop_drip()
		dog.stop_spray()
		dog.hide_stream()


# --- 매 프레임

func _process(delta: float) -> void:
	if dog_info.x != _built_serial:
		_build_dog()
	if dog.model == null:
		return
	var me_operator := is_operator()
	if me_operator and not _was_operator:
		# 작업자가 되면 지금까지의 진행으로 마스크를 채우고 시작한다 (이전 작업자가 나간 경우)
		_local_yaw = yaw
		for i in range(Stage.WET, mini(stage + 1, Stage.PAY)):
			if not STAGE_CHANNEL[i].is_empty():
				dog.mask.fill(STAGE_CHANNEL[i], stage_ratio(i))
	if not me_operator and _was_operator:
		_stop_loops()
	_was_operator = me_operator
	if me_operator and turning_left != 0.0:
		var step := minf(_turn_speed * delta, absf(turning_left)) * signf(turning_left)
		turning_left = 0.0 if absf(turning_left - step) < 0.0001 else turning_left - step
		_local_yaw = wrapf(_local_yaw + step, -PI, PI)
		_send_yaw.rpc_id(1, _local_yaw)
	turntable.rotation.y = _local_yaw if me_operator else lerp_angle(turntable.rotation.y, yaw, minf(delta * 15.0, 1.0))
	overflow_left = maxf(overflow_left - delta, 0.0)

	if stage != _seen_stage:
		_on_stage_changed()
	if owner_phase != _seen_owner_phase:
		_on_owner_phase_changed()
	_owner_phase_time += delta
	dog.react("set_mood", mood_face())
	_update_look(delta)
	_update_dog_presence()

	if me_operator:
		dog.show_mask()
		_update_operator_progress(delta)
	else:
		var ratios := {}
		for i in STAGE_CHANNEL.size():
			if not STAGE_CHANNEL[i].is_empty():
				ratios[STAGE_CHANNEL[i]] = stage_ratio(i)
		dog.show_ratios(ratios)
		dog.set_blink(0.0, "wet")
		dog.fluff = clampf(stage_ratio(Stage.DRY) / Tuning.data.stage_complete_ratio, 0.0, 1.0)
	_update_drops()
	_update_coins()
	if Net.is_host():
		_host_process(delta)


## 지금 단계 진행 (작업자 화면 기준)
func _current_progress() -> float:
	if stage >= Stage.PAY:
		return 0.0
	if stage == Stage.SQUEEZE:
		return 1.0 if _squeeze_done else 0.0
	return dog.mask.ratio(STAGE_CHANNEL[stage])


func _update_operator_progress(delta: float) -> void:
	var data: Resource = Tuning.data
	var current := _current_progress()
	dog.fluff = clampf(dog.mask.ratio("dry") / data.stage_complete_ratio, 0.0, 1.0) if stage >= Stage.DRY else 0.0
	var channel: String = STAGE_CHANNEL[mini(stage, Stage.DRY)]
	# 거의 다 됐으면 남은 곳을 반짝 (proto_blink_interval 마다 되풀이)
	_blink_wait -= delta
	if not channel.is_empty() and is_washing() and current >= data.stage_complete_ratio - BLINK_BEFORE and _blink_wait <= 0.0:
		_blink_wait = data.proto_blink_interval
		_blink_left = data.stage_remaining_blink
	_blink_left = maxf(_blink_left - delta, 0.0)
	eye_warning_left = maxf(eye_warning_left - delta, 0.0)
	var blink := 0.0
	if _blink_left > 0.0:
		blink = sin(_blink_left / data.stage_remaining_blink * PI)
	dog.set_blink(blink, channel if not channel.is_empty() else "towel")
	# 보이는 쪽이 auto_turn_visible_ratio 만큼 되면 저절로 돈다
	_turn_check -= delta
	if _turn_check <= 0.0 and is_washing() and not channel.is_empty() and turning_left == 0.0 and current < data.stage_complete_ratio:
		_turn_check = 0.25
		if _visible_done(channel) >= data.auto_turn_visible_ratio:
			turn_step(1)
			_turn_check = data.auto_turn_time + 0.5
	_report_left -= delta
	if _report_left <= 0.0 and stage < Stage.PAY and is_washing():
		_report_left = REPORT_INTERVAL
		_report_progress.rpc_id(1, dog_info.x, stage, current, _mood_delta)
		_mood_delta = 0.0


## 카메라 쪽을 보는 몸 표면 중 다 된 비율
func _visible_done(channel: String) -> float:
	var model: Node3D = dog.model
	var to_camera: Vector3 = (model.global_transform.affine_inverse() * camera.global_position) - model.body_center
	to_camera = to_camera.normalized()
	var seen := 0
	var done := 0
	for dir in _samples:
		if dir.dot(to_camera) < 0.25:
			continue
		seen += 1
		if dog.mask.value_at(channel, dir) >= 0.5:
			done += 1
	return float(done) / seen if seen > 0 else 1.0


func _on_stage_changed() -> void:
	_seen_stage = stage
	# 단계가 바뀌면 새 단계 안내가 먼저 보이게 눈에 물 경고를 지운다 (이슈 #39)
	eye_warning_left = 0.0
	_blink_left = 0.0
	_blink_wait = 0.0
	_dose_pending = false
	_tickle_anchor = null
	_tickle_time = 0.0
	_stroke.clear()
	_turn_check = 0.5
	if stage < Stage.PAY:
		# 다음 단계 도구가 저절로 손에 들린다
		tool = STAGE_TOOL[stage]
	if stage == Stage.SCRUB and dose <= 0.0 and not out_of_shampoo:
		tool = Tool.BOTTLE
	if stage == Stage.TOWEL:
		# 헹구기가 끝나면 남은 거품은 물에 씻겨 내려간다
		dog.clear_foam()
	if stage == Stage.PAY:
		_stop_loops()


func _on_owner_phase_changed() -> void:
	_seen_owner_phase = owner_phase
	_owner_phase_time = 0.0
	var data: Resource = Tuning.data
	if owner_model.has_method("set_variant"):
		owner_model.set_variant(owner_variant)
	match owner_phase:
		OwnerPhase.ARRIVE:
			_owner_call("enter", [to_global(OWNER_DOOR), to_global(OWNER_FRONT), data.proto_owner_arrive_time * 0.75])
		OwnerPhase.WAIT:
			_owner_call("go_sit", [to_global(OWNER_CHAIR), to_global(Vector3.ZERO), 1.0])
		OwnerPhase.REACT:
			_owner_call("come_react", [to_global(OWNER_FRONT), mood_face()])
			sfx.play(["sigh", "ding", "clap"][mood_face()])
		OwnerPhase.LEAVE:
			_owner_call("leave", [to_global(OWNER_DOOR), data.proto_owner_leave_time])
			sfx.play("bark")
			dog.react("jump")


func _owner_call(method: String, args: Array) -> void:
	if owner_model.has_method(method):
		owner_model.callv(method, args)


## 강아지가 보이는가: 주인이 내려놓기 전·데려간 뒤에는 안 보임. 떠날 때는 주인에게 달려감.
func _update_dog_presence() -> void:
	var data: Resource = Tuning.data
	match owner_phase:
		OwnerPhase.ARRIVE:
			var placed: bool = _owner_phase_time >= data.proto_owner_arrive_time * 0.8
			if placed and not dog.model.visible:
				dog.react("jump")
			dog.model.visible = placed
			dog.position = Vector3(0, 0.02, 0)
		OwnerPhase.LEAVE:
			var t: float = clampf(_owner_phase_time / (data.proto_owner_leave_time * 0.5), 0.0, 1.0)
			var target := turntable.to_local(owner_model.global_position) * Vector3(1, 0, 1)
			dog.position = Vector3(0, 0.02, 0).lerp(target, t) + Vector3(0, sin(t * PI) * 0.3, 0)
			dog.model.visible = t < 1.0
		_:
			dog.model.visible = true
			dog.position = Vector3(0, 0.02, 0)


## 강아지 시선: 작업자가 겨누는 곳이 없으면 가끔 주인 쪽을 본다 (기분이 나쁘면 낑낑).
func _update_look(delta: float) -> void:
	if not dog.model.has_method("watch"):
		return
	var data: Resource = Tuning.data
	_look_owner_in -= delta
	if _look_owner_in <= 0.0 and owner_phase == OwnerPhase.WAIT:
		var interval: PackedFloat32Array = data.dog_look_owner_interval
		_look_owner_in = _rng.randf_range(interval[0], interval[1])
		_look_owner_left = 1.3
		if mood_face() == 0:
			sfx.play("whine")
	_look_owner_left = maxf(_look_owner_left - delta, 0.0)
	if _look_owner_left > 0.0 and (not is_operator() or _aim == null or not _was_held):
		dog.model.watch(owner_model.global_position + Vector3(0, 0.8, 0), false)
	elif not is_operator():
		dog.model.watch(null, false)


## 헹구기가 끝나면 몸에 물방울이 맺히고, 수건·드라이어로 닦은 곳부터 사라진다 (물방울 수 = 남은 물기).
func _update_drops() -> void:
	if stage < Stage.TOWEL:
		return
	if dog.drop_total() == 0 and stage < Stage.PAY and not _drops_scattered:
		_drops_scattered = true
		dog.scatter_drops(Tuning.data.proto_water_drops, dog_info.z)
	if stage == Stage.PAY:
		dog.show_drop_count(0)
	elif is_operator():
		var mask = dog.mask
		dog.show_drops_where(func(dir: Vector3) -> bool:
			return mask.value_at("towel", dir) < 0.5 and mask.value_at("dry", dir) < 0.5)
	else:
		var left := (1.0 - stage_ratio(Stage.TOWEL)) * 0.6 + (1.0 - stage_ratio(Stage.DRY)) * 0.4
		dog.show_drop_count(roundi(dog.drop_total() * left))


func _build_dog() -> void:
	_built_serial = dog_info.x
	_drops_scattered = false
	dog.setup(Tuning.data.mask_resolution, dog_info.y, dog_info.z)
	dog.model.visible = false
	_seen_stage = -1
	_seen_owner_phase = -1
	_blink_left = 0.0
	_blink_wait = 0.0
	eye_warning_left = 0.0
	dose = 0.0
	squeezing = false
	squeeze_time = 0.0
	_squeeze_paid = false
	_squeeze_done = false
	_dose_pending = false
	out_of_shampoo = false
	overflow_left = 0.0
	pours = 0
	_last_hit = null
	_mood_delta = 0.0
	_was_operator = false
	turning_left = 0.0
	dryer_distance = Tuning.data.proto_dryer_start_distance
	turns = 0
	if _built_serial > 0 and sfx != null:
		sfx.play("splat")


func _update_coins() -> void:
	while coin_root.get_child_count() > coins.size():
		var last := coin_root.get_child(coin_root.get_child_count() - 1)
		coin_root.remove_child(last)
		last.queue_free()
	while coin_root.get_child_count() < coins.size():
		coin_root.add_child(_make_coin())
	# 주인이 목욕통 앞 가장자리에 동전을 놓아 준다
	for i in coins.size():
		var coin: Node3D = coin_root.get_child(i)
		coin.position = Vector3(0.45 + (i - (coins.size() - 1) / 2.0) * 0.16, TABLE_TOP + 0.1, 0.42)
		coin.rotation.y += 0.05
		var label: Label3D = coin.get_node("Value")
		label.text = str(coins[i])


func _make_coin() -> Node3D:
	var coin := Node3D.new()
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.06
	cylinder.bottom_radius = 0.06
	cylinder.height = 0.015
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.2)
	gold.metallic = 0.7
	gold.roughness = 0.3
	cylinder.material = gold
	mesh.mesh = cylinder
	mesh.rotation.x = PI / 2.0
	coin.add_child(mesh)
	var label := Label3D.new()
	label.name = "Value"
	label.position = Vector3(0, 0.1, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0015
	label.font_size = 40
	label.outline_size = 12
	label.no_depth_test = true
	label.font = COIN_FONT
	coin.add_child(label)
	return coin


# --- 호스트

func _host_process(delta: float) -> void:
	_update_operator()
	var data: Resource = Tuning.data
	_owner_timer -= delta
	match owner_phase:
		OwnerPhase.ARRIVE:
			if _owner_timer <= 0.0:
				owner_phase = OwnerPhase.WAIT
		OwnerPhase.WAIT:
			if stage == Stage.PAY:
				owner_phase = OwnerPhase.REACT
				_owner_timer = data.owner_reaction_time
		OwnerPhase.REACT:
			if _owner_timer <= 0.0 and coins.is_empty():
				owner_phase = OwnerPhase.LEAVE
				_owner_timer = data.proto_owner_leave_time
		OwnerPhase.LEAVE:
			if _owner_timer <= 0.0:
				new_dog()


## 작업자: 지금 작업자가 목욕대 자리에 있으면 그대로, 아니면 목욕대 자리의 첫 사람 (슬롯 순).
func _update_operator() -> void:
	var candidate := 0
	var best_slot := 1 << 30
	for player in get_tree().get_nodes_in_group("players"):
		if player.seat != 0:
			continue
		if player.get_peer_id() == operator:
			return
		if player.slot < best_slot:
			best_slot = player.slot
			candidate = player.get_peer_id()
	operator = candidate


func _advance() -> void:
	var done := stage
	stage = (stage + 1) as Stage
	ratio = 0.0
	if stage == Stage.PAY:
		_pay()
	_stage_done.rpc(done)


## 다 씻었다: 요금 + 기분 팁 + 향 팁을 동전으로. 주인이 반응하며 건넨다.
func _pay() -> void:
	var data: Resource = Tuning.data
	var values := PackedInt32Array([data.money_wash_price])
	var tip: int = data.money_tip_by_mood[mood_face()]
	if tip > 0:
		values.append(tip)
	if wants_peach() and used_peach:
		values.append(data.money_scent_tip)
	coins = values
	dogs_done += 1


@rpc("any_peer", "call_local", "reliable")
func _report_progress(serial: int, at_stage: int, value: float, mood_change: float) -> void:
	if not Net.is_host() or multiplayer.get_remote_sender_id() != operator or serial != dog_info.x:
		return
	mood = clampf(mood + mood_change, 0.0, 1.0)
	if at_stage != stage or not is_washing():
		return
	ratio = clampf(value, 0.0, 1.0)
	if ratio >= Tuning.data.stage_complete_ratio:
		_advance()


@rpc("any_peer", "call_local", "reliable")
func _report_event(serial: int, kind: String) -> void:
	if not Net.is_host() or multiplayer.get_remote_sender_id() != operator or serial != dog_info.x:
		return
	var data: Resource = Tuning.data
	match kind:
		"cold":
			mood += data.mood_cold_water
		"eye":
			mood += data.mood_eye_hit
		"tickle", "shake", "cheek", "pour_head":
			pass
		_:
			return
	mood = clampf(mood, 0.0, 1.0)
	_play_event.rpc(kind)


@rpc("authority", "call_local", "reliable")
func _play_event(kind: String) -> void:
	match kind:
		"cold":
			dog.react("jump")
			dog.splash()
			sfx.play("yelp")
		"eye":
			sfx.play("huff")
		"tickle":
			dog.react("wiggle_legs")
			sfx.play("squeak")
		"shake", "pour_head":
			dog.react("shake")
			sfx.play("shake")
			if kind == "shake":
				screen_foam.emit()
		"cheek":
			dog.react("flap_cheeks")


@rpc("authority", "call_local", "reliable")
func _stage_done(done: int) -> void:
	sfx.play("poof" if done == Stage.DRY else "ding")
	stage_completed.emit(done)


## 샴푸 병 사용: uses = 1 (이번 손님 처음 짤 때) 또는 2 (넘쳐서 한 번 더)
@rpc("any_peer", "call_local", "reliable")
func _request_dose(serial: int, uses: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not Net.is_host() or sender != operator or serial != dog_info.x:
		return
	if uses == 2:
		# 넘침: 남아 있으면 한 번 더 쓴다 (없으면 그냥 넘어감)
		store.use_shampoo()
		return
	if not _dose_paid:
		var kind: String = store.use_shampoo()
		if kind.is_empty():
			_dose_result.rpc_id(sender, false, "")
			return
		_dose_paid = true
		_host_dose_kind = kind
		used_peach = kind == "peach"
	_dose_result.rpc_id(sender, true, _host_dose_kind)


@rpc("authority", "call_local", "reliable")
func _dose_result(ok: bool, kind: String) -> void:
	_dose_pending = false
	out_of_shampoo = not ok
	if not ok:
		squeezing = false
		dose = 0.0
		_squeeze_done = false
		dog.hide_glob()
		dose_failed.emit()
		return
	_squeeze_paid = true
	dog.set_foam_color(dog.FOAM_PINK if kind == "peach" else dog.FOAM_WHITE)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _send_yaw(value: float) -> void:
	if Net.is_host() and multiplayer.get_remote_sender_id() == operator:
		yaw = value


@rpc("any_peer", "call_local", "reliable")
func _request_collect(serial: int, index: int) -> void:
	if not Net.is_host() or serial != dog_info.x or index < 0 or index >= coins.size():
		return
	store.add_money(coins[index])
	var left := coins.duplicate()
	left.remove_at(index)
	coins = left
	_coin_collected.rpc()


@rpc("authority", "call_local", "reliable")
func _coin_collected() -> void:
	sfx.play("coin")
