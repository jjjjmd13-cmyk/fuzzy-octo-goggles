extends Node3D
## 목욕대 작업대 (GDD_V3 3장, 시제품 1 "손맛").
##
## 강아지 한 마리를 적시기 → 거품 → 헹구기 → 수건 → 드라이어 순서로 씻고, 다 되면 동전으로 돈을 받는다.
## 권한 (완료 조건 11):
## - 단계·진행 비율·기분·동전·손님 정보는 호스트가 정하고 StationSync 로 보낸다 (혼자 하기 = 접속 없는 호스트).
## - 붓질(마스크)은 목욕대 자리의 "작업자" 한 사람 화면에서만 칠한다. 작업자는 진행 비율과
##   기분 변화·사건(펄쩍, 간지럼…)만 호스트에 보낸다. 다른 사람은 비율만 받아 셰이더에 넣는다.
## - 작업자 = 목욕대 자리에 먼저 앉은 사람 (호스트가 정함).
## 입력(마우스·패드)은 월드가 받아 operate() / turn() 을 부른다.

signal stage_completed(stage: int)
## 몸 털기: 화면에 거품이 튐 (목욕대 자리 사람에게)
signal screen_foam
signal dose_failed

enum Stage { WET, SOAP, RINSE, TOWEL, DRY, PAY }
enum Tool { SHOWER, SHAMPOO, TOWEL, DRYER }

const STAGE_CHANNEL := ["wet", "scrub", "rinse", "towel", "dry"]
const STAGE_TOOL := [Tool.SHOWER, Tool.SHAMPOO, Tool.SHOWER, Tool.TOWEL, Tool.DRYER]
const STAGE_NAMES := ["적시기", "거품", "헹구기", "수건", "드라이어"]
const TOOL_NAMES := ["샤워기", "샴푸", "수건", "드라이어"]
const REPORT_INTERVAL := 0.1
## 드라이어 거리 (m): 보통 / Shift 누르면 가까이
const DRYER_DISTANCE := 0.35
const DRYER_DISTANCE_CLOSE := 0.1
## 남은 곳 반짝임은 진행이 (완료 비율 - 이 값) 을 넘을 때 한 번
const BLINK_BEFORE := 0.1
const COIN_PICK_PIXELS := 48.0
const TABLE_TOP := 0.9
const COIN_FONT := preload("res://assets/fonts/pretendard/Pretendard-Bold.otf")

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

# --- 내 화면 (동기화하지 않음)
var tool := Tool.SHOWER
## 물 온도 다이얼 (0~1)
var temperature := 0.5
## 드라이어를 가까이 대는 중 (Shift)
var dryer_close := false
var camera: Camera3D
var store: Node
var sfx: Node
## 샴푸가 비어서 거품이 안 남 (안내용)
var out_of_shampoo := false
## 손에 남은 거품 양 (덩이)
var dose := 0.0
## 지금 도구를 쓰는 중이고 강아지에 닿았는가 (HUD·테스트용)
var hitting := false
var water_state := ""

@onready var turntable: Node3D = $Turntable
@onready var dog: Node3D = $Turntable/Dog
@onready var camera_point: Marker3D = $CameraPoint
@onready var coin_root: Node3D = $Coins

var _built_serial := -1
var _seen_stage := -1
var _was_operator := false
var _local_yaw := 0.0
var _report_left := 0.0
var _mood_delta := 0.0
var _last_hit: Variant = null
var _tickle_anchor: Variant = null
var _tickle_time := 0.0
var _tickled := false
var _cold_cooldown := 0.0
var _eye_cooldown := 0.0
var _cheek_cooldown := 0.0
var _towel_sound := 0.0
var _foam_carry := 0.0
var _blink_left := 0.0
## 다음 반짝까지 (거의 다 된 뒤 proto_blink_interval 마다 되풀이)
var _blink_wait := 0.0
## 눈에 물 안내를 보여 줄 남은 시간 (작업자 화면)
var eye_warning_left := 0.0
var _dose_pending := false
var _pending_squirt := Vector3.ZERO
var _dose_kind := ""
var _rng := RandomNumberGenerator.new()
var _drops_scattered := false
# 호스트만
var _dose_paid := false
var _host_dose_kind := ""
var _next_dog_left := -1.0


func _ready() -> void:
	_rng.randomize()
	camera_point.look_at($LookTarget.global_position)
	# 처음엔 비스듬히 (옆모습이 조금 보이게)
	_local_yaw = 0.6
	yaw = 0.6


## 호스트: 영업 시작 (첫 손님)
func reset() -> void:
	if not Net.is_host():
		return
	dogs_done = 0
	new_dog()


## 호스트: 다음 손님을 올린다.
func new_dog() -> void:
	if not Net.is_host():
		return
	var pattern := _rng.randi_range(0, maxi(Tuning.data.mask_patterns, 1) - 1)
	var peach := 1 if _rng.randf() < Tuning.data.proto_peach_request_chance else 0
	dog_info = Vector4i(dog_info.x + 1, pattern, _rng.randi() & 0x3fffffff, peach)
	stage = Stage.WET
	ratio = 0.0
	mood = Tuning.data.mood_start
	coins = PackedInt32Array()
	used_peach = false
	_dose_paid = false
	_host_dose_kind = ""
	_next_dog_left = -1.0


func wants_peach() -> bool:
	return dog_info.w == 1


func dog_number() -> int:
	return dog_info.x


func is_operator() -> bool:
	return operator != 0 and operator == multiplayer.get_unique_id()


func stage_tool() -> int:
	return STAGE_TOOL[stage] if stage < Stage.PAY else -1


func mood_face() -> int:
	return Tuning.data.mood_face(mood)


## 단계별 진행 (0~1). 끝난 단계는 1.
func stage_ratio(index: int) -> float:
	if index < stage:
		return 1.0
	return ratio if index == stage else 0.0


## 다음에 할 일 (노란 안내)
func next_hint() -> String:
	if stage == Stage.PAY:
		return "동전을 눌러 돈을 받으세요" if not coins.is_empty() else "다음 손님이 와요"
	var need: int = stage_tool()
	if stage == Stage.SOAP and out_of_shampoo:
		return "샴푸가 떨어졌어요! Tab 으로 컴퓨터 자리에 가서 사세요"
	if tool != need:
		return "%s 차례: %d 번(%s)을 고르세요" % [STAGE_NAMES[stage], need + 1, TOOL_NAMES[need]]
	match stage:
		Stage.WET:
			return "왼쪽 버튼을 누른 채 몸 전체를 적시세요 (오른쪽 드래그로 돌리기)"
		Stage.SOAP:
			return "병을 눌러 샴푸를 짜고, 누른 채 빠르게 문지르세요" if dose <= 0.0 else "누른 채 빠르게 문질러 거품을 내세요"
		Stage.RINSE:
			return "거품이 남지 않게 헹구세요"
		Stage.TOWEL:
			return "수건으로 물기를 닦으세요"
		_:
			return "드라이어로 말리세요 (Shift = 가까이, 너무 가까우면 싫어해요)"


func turn(degrees: float) -> void:
	if is_operator():
		_local_yaw = wrapf(_local_yaw + deg_to_rad(degrees), -PI, PI)
		_send_yaw.rpc_id(1, _local_yaw)


## 작업자: 이번 프레임 도구 사용. held = 쓰는 버튼을 누르고 있음, pressed = 이번에 막 누름.
func operate(screen_pos: Vector2, held: bool, pressed: bool, delta: float) -> void:
	hitting = false
	water_state = ""
	if not is_operator() or dog.model == null or stage == Stage.PAY:
		_stop_loops()
		_last_hit = null
		return
	var aim: Variant = dog.ray_hit(camera, screen_pos)
	var hit: Variant = aim if held else null
	hitting = hit != null
	# 강아지가 커서를 따라본다. 샤워기 물줄기가 얼굴로 오면 고개를 돌리고 눈을 감는다 (눈에 물 들어가기 전 신호)
	if dog.model.has_method("watch"):
		dog.model.watch(aim, tool == Tool.SHOWER and held)
	if tool == Tool.SHOWER and hit != null:
		dog.spray(hit)
	else:
		dog.stop_spray()
	_cold_cooldown = maxf(_cold_cooldown - delta, 0.0)
	_eye_cooldown = maxf(_eye_cooldown - delta, 0.0)
	_cheek_cooldown = maxf(_cheek_cooldown - delta, 0.0)
	var speed := 0.0
	if hit != null and _last_hit != null and delta > 0.0:
		speed = (hit as Vector3).distance_to(_last_hit) / delta
	_last_hit = hit

	match tool:
		Tool.SHOWER:
			_use_shower(hit, held, delta)
		Tool.SHAMPOO:
			_use_shampoo(hit, pressed, speed, delta)
		Tool.TOWEL:
			_use_towel(hit, speed, delta)
		Tool.DRYER:
			_use_dryer(hit, held, delta)
	if tool != Tool.SHAMPOO or hit == null:
		_tickle_anchor = null
		_tickle_time = 0.0
	if not (tool == Tool.SHOWER and stage == Stage.WET and hit != null):
		dog.stop_drip()
	if tool != Tool.SHOWER or not held:
		sfx.set_loop("shower", 0.0)
	if tool != Tool.SHAMPOO or hit == null:
		sfx.set_loop("scrub", 0.0)
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


func _use_shower(hit: Variant, held: bool, delta: float) -> void:
	var data: Resource = Tuning.data
	sfx.set_loop("shower", 0.8 if held else 0.0)
	if hit == null:
		return
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
	match stage:
		Stage.WET:
			dog.paint("wet", hit, data.tool_shower_radius, data.tool_shower_rate * delta)
			if dog.mask.mud_at(dog.dir_of(hit)) > 0.2:
				dog.drip(hit)
			else:
				dog.stop_drip()
		Stage.RINSE:
			dog.paint("rinse", hit, data.tool_shower_radius, data.tool_rinse_rate * delta)
			if dog.rinse_foam(hit, data.tool_shower_radius, data.tool_rinse_rate * delta * 4.0) > 0:
				sfx.play("bubble_pop")
		_:
			# 거품 단계에 물을 뿌리면 거품만 씻겨 나간다
			dog.rinse_foam(hit, data.tool_shower_radius, data.tool_rinse_rate * delta * 4.0)


func _use_shampoo(hit: Variant, pressed: bool, speed: float, delta: float) -> void:
	var data: Resource = Tuning.data
	if hit == null:
		return
	if pressed and stage == Stage.SOAP and not _dose_pending:
		# 병 클릭 = 거품 한 덩이 (처음 짤 때 병에서 한 마리분을 씀)
		_dose_pending = true
		_pending_squirt = hit
		_request_dose.rpc_id(1, dog_info.x)
	if dog.is_face(hit):
		_eye_hit()
	if stage != Stage.SOAP or dose <= 0.0:
		sfx.set_loop("scrub", 0.0)
		return
	var rate := minf(data.tool_scrub_rate_per_speed * speed, data.tool_scrub_rate_max)
	sfx.set_loop("scrub", clampf(rate / data.tool_scrub_rate_max, 0.0, 1.0))
	if rate <= 0.0:
		return
	var added: float = dog.paint("scrub", hit, data.tool_scrub_radius, rate * delta)
	dose = maxf(dose - added / maxf(data.proto_dose_coverage, 0.01), 0.0)
	_foam_carry += data.foam_ball_per_scrub * minf(speed, 3.0) * delta
	if _foam_carry >= 1.0:
		dog.add_foam(hit, int(_foam_carry), _rng)
		_foam_carry -= int(_foam_carry)
	_update_tickle(hit, delta)


func _use_towel(hit: Variant, speed: float, delta: float) -> void:
	var data: Resource = Tuning.data
	if hit == null or stage != Stage.TOWEL:
		return
	dog.paint("towel", hit, data.tool_scrub_radius * 1.5, data.tool_towel_rate * delta)
	_towel_sound -= delta
	if speed > 0.2 and _towel_sound <= 0.0:
		_towel_sound = 0.35
		sfx.play("towel")


func _use_dryer(hit: Variant, held: bool, delta: float) -> void:
	var data: Resource = Tuning.data
	sfx.set_loop("dryer", 0.7 if held else 0.0)
	if hit == null:
		return
	var distance := DRYER_DISTANCE_CLOSE if dryer_close else DRYER_DISTANCE
	if distance > data.tool_dryer_range:
		return
	if dog.is_face(hit) and _cheek_cooldown <= 0.0:
		_cheek_cooldown = 0.5
		_report_event.rpc_id(1, dog_info.x, "cheek")
	if distance <= data.proto_dryer_near:
		water_state = "too_close"
		_mood_delta += data.mood_dryer_too_close * delta
	if stage != Stage.DRY:
		return
	var t := inverse_lerp(data.proto_dryer_near, data.tool_dryer_range, distance)
	var rate: float = lerpf(data.tool_dryer_rate_near, data.tool_dryer_rate_far, clampf(t, 0.0, 1.0))
	# 바람은 멀수록 넓게 퍼진다
	dog.paint("dry", hit, data.tool_shower_radius * (1.0 + distance * 2.0), rate * delta)


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
			dog.mask.fill(STAGE_CHANNEL[i], stage_ratio(i))
	if not me_operator and _was_operator:
		_stop_loops()
	_was_operator = me_operator
	turntable.rotation.y = _local_yaw if me_operator else lerp_angle(turntable.rotation.y, yaw, minf(delta * 15.0, 1.0))

	if stage != _seen_stage:
		_on_stage_changed()
	dog.react("set_mood", mood_face())

	if me_operator:
		dog.show_mask()
		_update_operator_progress(delta)
	else:
		var ratios := {}
		for i in STAGE_CHANNEL.size():
			ratios[STAGE_CHANNEL[i]] = stage_ratio(i)
		dog.show_ratios(ratios)
		dog.set_blink(0.0, "wet")
		dog.fluff = clampf(stage_ratio(Stage.DRY) / Tuning.data.stage_complete_ratio, 0.0, 1.0)
	_update_drops()
	_update_coins()
	if Net.is_host():
		_host_process(delta)


func _update_operator_progress(delta: float) -> void:
	var data: Resource = Tuning.data
	var current := 0.0
	if stage < Stage.PAY:
		current = dog.mask.ratio(STAGE_CHANNEL[stage])
	dog.fluff = clampf(dog.mask.ratio("dry") / data.stage_complete_ratio, 0.0, 1.0) if stage >= Stage.DRY else 0.0
	# 거의 다 됐으면 남은 곳을 반짝 (proto_blink_interval 마다 되풀이)
	_blink_wait -= delta
	if stage < Stage.PAY and current >= data.stage_complete_ratio - BLINK_BEFORE and _blink_wait <= 0.0:
		_blink_wait = data.proto_blink_interval
		_blink_left = data.stage_remaining_blink
	_blink_left = maxf(_blink_left - delta, 0.0)
	eye_warning_left = maxf(eye_warning_left - delta, 0.0)
	var blink := 0.0
	if _blink_left > 0.0:
		blink = sin(_blink_left / data.stage_remaining_blink * PI)
	dog.set_blink(blink, STAGE_CHANNEL[mini(stage, Stage.DRY)])
	_report_left -= delta
	if _report_left <= 0.0 and stage < Stage.PAY:
		_report_left = REPORT_INTERVAL
		_report_progress.rpc_id(1, dog_info.x, stage, current, _mood_delta)
		_mood_delta = 0.0


func _on_stage_changed() -> void:
	_seen_stage = stage
	_blink_left = 0.0
	_blink_wait = 0.0
	# 호스트가 다른 단계라 답하지 않은 샴푸 요청이 있으면 풀어 준다
	_dose_pending = false
	_tickle_anchor = null
	_tickle_time = 0.0
	if stage == Stage.TOWEL:
		# 헹구기가 끝나면 남은 거품은 물에 씻겨 내려간다
		dog.clear_foam()
	if stage == Stage.PAY:
		_stop_loops()


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
	_seen_stage = -1
	_blink_left = 0.0
	_blink_wait = 0.0
	eye_warning_left = 0.0
	dose = 0.0
	_dose_pending = false
	out_of_shampoo = false
	_last_hit = null
	_mood_delta = 0.0
	_was_operator = false
	if _built_serial > 0 and sfx != null:
		sfx.play("splat")


func _update_coins() -> void:
	while coin_root.get_child_count() > coins.size():
		var last := coin_root.get_child(coin_root.get_child_count() - 1)
		coin_root.remove_child(last)
		last.queue_free()
	while coin_root.get_child_count() < coins.size():
		coin_root.add_child(_make_coin())
	for i in coins.size():
		var coin: Node3D = coin_root.get_child(i)
		coin.position = Vector3(0.45 + (i - (coins.size() - 1) / 2.0) * 0.16, TABLE_TOP + 0.1, 0.38)
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
	if stage == Stage.PAY and coins.is_empty():
		if _next_dog_left < 0.0:
			_next_dog_left = Tuning.data.proto_next_dog_delay
		_next_dog_left -= delta
		if _next_dog_left <= 0.0:
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


## 다 씻었다: 요금 + 기분 팁 + 향 팁을 동전으로 (숫자 대신 동전, 완료 조건 9·10)
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
	if at_stage != stage or stage == Stage.PAY:
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
		"tickle", "shake", "cheek":
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
		"shake":
			dog.react("shake")
			sfx.play("shake")
			screen_foam.emit()
		"cheek":
			dog.react("flap_cheeks")


@rpc("authority", "call_local", "reliable")
func _stage_done(done: int) -> void:
	sfx.play("poof" if done == Stage.DRY else "ding")
	stage_completed.emit(done)


@rpc("any_peer", "call_local", "reliable")
func _request_dose(serial: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not Net.is_host() or sender != operator or serial != dog_info.x or stage != Stage.SOAP:
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
		dose_failed.emit()
		return
	_dose_kind = kind
	dose = minf(dose + Tuning.data.tool_shampoo_dose, Tuning.data.tool_shampoo_dose * 2.0)
	dog.set_foam_color(dog.FOAM_PINK if kind == "peach" else dog.FOAM_WHITE)
	dog.add_foam(_pending_squirt, 4, _rng)
	sfx.play("bubble_pop")


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
