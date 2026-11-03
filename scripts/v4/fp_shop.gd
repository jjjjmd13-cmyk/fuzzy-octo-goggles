extends Node3D
## V4 1인칭 회색 상자 시제품 (사람 대표 플레이 뒤 방향 전환, 2026-10-30).
##
## 가게를 걸어다니며(WASD + 마우스) 선반의 3D 도구를 집고(클릭), 목욕통의 강아지에 대고
## 누르고 있으면 쓱쓱 바로 씻긴다. 원 그리기·고정 카메라·2D 커서 없음. 큰 붓·빠른 진행.
##   샤워기 = 적시기 + 거품 헹구기 / 샴푸 = 젖은 곳에 거품 (진흙이 지워짐) / 수건 = 젖은 곳 말리기
## 다 되면 강아지가 펄쩍 + 꼬리 흔들기. 쓰는 동안 가끔 몸 털기(물 튀김).
## 방은 코드로 만드는 임시 상자. 강아지는 V3 의 WashDog(GLB·털 셰이더·칠하기 마스크)를 그대로 쓴다.
## V3 코드는 그대로 두고 이 씬만 새로 (scenes/v4/fp_shop.tscn).

const WashDog := preload("res://scripts/sim/wash_dog.gd")
const Sfx := preload("res://scripts/game/sfx.gd")
const FpToolView := preload("res://scripts/v4/fp_tool_view.gd")
const FpPlayer := preload("res://scripts/v4/fp_player.gd")
const FpGuests := preload("res://scripts/v4/fp_guests.gd")
const TUB_SCENE := preload("res://scenes/art/sim/tub_model.tscn")
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const FpSettle := preload("res://scripts/v4/fp_settle.gd")

## 빠른 확인에서 강아지를 다 돌려줌 (개발용 scenes/dev/quick_check.tscn 이 끝 화면을 띄움)
signal quick_finished

const PICK_LAYER := 2
const DOG_LAYER := 16
## 손이 닿는 거리 (m)
const REACH := 2.4
## 강아지가 앉는 곳 (목욕통 위)
const DOG_SPOT := Vector3(0, 0.92, -1.6)
## 도구: 이름, 칠하는 채널, 색. 붓 크기·속도·완료 기준은 Tuning.data.v4_* (GDD_V4)
## 단계마다 처음 닿을 때 반응 하나: 적시기 다리 찰랑 / 거품 펄쩍 / 헹구기 몸 털기+물 튐 / 말리기 다리 찰랑
## 단계 차례 (사람 대표 피드백: 단계가 끝난 순간을 분명하게). 끝나면 소리 + 반짝 + 가운데 글자,
## 다음에 쓸 도구가 선반에서 살짝 빛난다. tool = 그 단계에 쓰는 도구
const STAGES: Array[Dictionary] = [
	{"id": "wet", "tool": "shower", "sound": "ding", "text": "적시기 끝! 샴푸로 거품 내요"},
	{"id": "scrub", "tool": "shampoo", "sound": "bubble_pop", "text": "거품 끝! 샤워기로 헹궈요"},
	{"id": "rinse", "tool": "shower", "sound": "squeak", "text": "뽀득! 헹굼 끝! 수건으로 닦아요"},
	{"id": "dry", "tool": "dryer", "sound": "poof", "text": "뽕! 드라이 끝! 깨끗해졌어요"},
]
## 거품 공 크기 배수 (크고 하얗게), 스스로 빛나는 정도
const FOAM_SIZE := 2.4
const FOAM_GLOW := 0.45
## 헹구기: 물줄기 둘레의 거품만 (붓 반경 × 이 값 × 1.5), 거품 공이 0.15초쯤 대면 녹음.
## 예전엔 한 번 대면 몸 전체 거품이 사라져서 다 헹궜는지 알기 어려웠음 (사람 대표 피드백)
const RINSE_REACH := 0.7
const RINSE_SPEED := 14.0
## 헹굴 때 남은 거품 공이 이만큼 이하면 거품이 살짝 반짝임 (고리·원은 정신없어서 뺌, 사람 대표 피드백)
const FOAM_SPARKLE_BELOW := 3
## 단계 진행이 이만큼 넘으면 아직 안 된 곳을 털 위에서 반짝임
const BLINK_FROM := 0.5
const STAGE_REACTION := {"wet": "wiggle_legs", "scrub": "jump", "rinse": "shake", "dry": "wiggle_legs"}
const TOOLS := {
	"shower": {"name": "샤워기", "channel": "wet", "color": Color(0.7, 0.8, 0.9)},
	"shampoo": {"name": "샴푸", "channel": "scrub", "color": Color(1.0, 0.6, 0.75)},
	"dryer": {"name": "드라이기", "channel": "dry", "color": Color(0.95, 0.85, 0.9)},
}

## false 면 마우스·키 입력을 읽지 않는다 (테스트가 using 등을 직접 넣음)
var input_enabled := true
## 지금 도구를 쓰는 중 (왼쪽 버튼을 누르고 있음)
var using := false
## 손에 든 도구 ("" = 빈손)
var held := ""
## 바라보는 집을 수 있는 도구 ("" = 없음)
var hovered := ""
## 바라보는 강아지 위 점 (없으면 null)
var aim_point: Variant = null
var done := false
## 목욕통에 강아지가 있음 (손님이 맡기기 전엔 비어 있음)
var has_dog := false
## 빠른 확인 (개발용, add_child 전에 정함): 강아지 수 (0 = 보통 하루). 참을성·벽시계 끔, 처음부터 손님이 대기
var quick_dogs := 0
## 빠른 확인으로 볼 기능 이름 ("day", 다음 기능들이 늘어남)
var quick_feature := ""
## 바라보는 손님 (주인 노드, 없으면 null)
var hovered_guest: Node3D = null
## 오늘 번 돈 = 요금 + 팁
var money := 0
var fees := 0
var tips := 0
## 하루 영업 (s): 문 연 뒤 지난 시간 / 영업 시간 (v4_day_minutes, 9시~6시)
var day_time := 0.0
var day_seconds := 0.0
var day_over := false
## 지금 강아지 주인 정보: 성격·들어온 시각 (팁 계산)
var _taken := {}
var _settle: Control
## 지금 단계 (STAGES 번호, 4 = 다 끝남)
var stage_index := 0
## 남은 거품이 반짝이는 중 (헹굴 때 몇 개 안 남았을 때)
var foam_sparkle := false
var dog: WashDog
var player: CharacterBody3D
var sfx: Node
## 대기 의자 손님들 (참을성)
var guests: FpGuests

var _pickups := {}
var _held_view: FpToolView
var _returning_views: Array[FpToolView] = []
var _glow_materials := {}
var _rng := RandomNumberGenerator.new()
var _foam_carry := 0.0
var _reacted := {}
var _hint := ""
var _hint_left := 0.0
var _hud: Control
var _banner := ""
var _banner_left := 0.0
var _sparkle: CPUParticles3D
var _t := 0.0
var _dogs := 0


func _ready() -> void:
	_rng.randomize()
	_build_room()
	_build_shelf()
	sfx = Sfx.new()
	add_child(sfx)
	dog = WashDog.new()
	dog.name = "Dog"
	dog.position = DOG_SPOT
	dog.rotation.y = PI * 0.15
	dog.foam_glow = FOAM_GLOW
	add_child(dog)
	_build_stage_effects()
	guests = FpGuests.new()
	guests.name = "Guests"
	if quick_dogs > 0:
		guests.quick = true
		guests.opening_override = []
		for i in quick_dogs:
			guests.opening_override.append("normal")
	add_child(guests)
	guests.guest_left.connect(_on_guest_left)
	guests.guest_arrived.connect(_on_guest_arrived)
	_build_player()
	_build_hud()
	day_seconds = Tuning.data.v4_day_minutes * 60.0
	new_dog()
	_clear_tub()
	_show_hint("손님이 오면 다가가서 클릭: 강아지 맡기", 4.0)


## 새 강아지 (진흙 무늬 무작위)
func new_dog() -> void:
	_dogs += 1
	dog.setup(Tuning.data.mask_resolution, _rng.randi_range(0, 2), _rng.randi())
	dog.show_mask()
	dog.react("set_mood", 1)
	done = false
	stage_index = 0
	_banner_left = 0.0
	_reacted.clear()
	has_dog = true
	dog.visible = true
	_show_hint("강아지를 씻겨 주세요: 샤워기 → 샴푸 → 샤워기로 헹구기 → 드라이기", 4.0)
	_start_quick_stage()


## 빠른 확인: 그 기능의 단계부터 바로 시작 (앞 단계는 이미 끝난 강아지)
func _start_quick_stage() -> void:
	var start: String = {"dryer": "dry"}.get(quick_feature, "")
	if start.is_empty():
		return
	for i in STAGES.size():
		if STAGES[i].id == start:
			break
		var channel: String = STAGES[i].id
		dog.mask.fill(channel, 1.0)
		_reacted[channel] = true
		stage_index = i + 1
	_show_hint("%s 집어서 바로 해 봐요" % TOOLS[stage_tool()].name, 4.0)


## 목욕통 비우기 (주인이 데려갔거나 아직 아무도 안 맡김)
func _clear_tub() -> void:
	has_dog = false
	dog.visible = false
	dog.clear_foam()
	_stop_effects()
	done = false


## 손님 클릭: 대기 손님이면 강아지를 맡기고, 목욕통 옆 주인이면 다 씻은 강아지를 돌려준다
func interact_guest(owner: Node3D) -> void:
	if day_over or owner == null:
		return
	if owner == guests.current:
		if done:
			give_back()
		else:
			_show_hint("다 씻기고 나서 주인을 클릭해 돌려줘요", 1.5)
		return
	if has_dog:
		_show_hint("목욕통이 비면 받을 수 있어요", 1.5)
		return
	_taken = guests.take(owner)
	if not _taken.is_empty():
		new_dog()


## 다 씻은 강아지를 주인에게: 요금 + 기분 팁 + 빠른 팁 (TUNING_V4 3장), 주인은 기뻐하며 떠남
func give_back() -> void:
	var fee: int = Tuning.data.v4_price_wash
	# 기분: V4 에는 아직 벌점이 없어서 다 씻으면 😊
	var tip: int = Tuning.data.v4_tip_mood[2] + fast_tip(_taken.get("kind", "normal"), guests.elapsed - _taken.get("arrived", guests.elapsed))
	fees += fee
	tips += tip
	money += fee + tip
	guests.return_current("+%d" % (fee + tip))
	sfx.play("coin")
	_clear_tub()
	_taken = {}
	_show_hint("요금 %d + 팁 %d" % [fee, tip], 2.5)


## 빠른 서비스 팁: 손님이 들어온 뒤 돌려받기까지 걸린 시간(s)으로. 급한 손님은 배수
static func fast_tip(kind: String, seconds: float) -> int:
	var times: PackedFloat32Array = Tuning.data.v4_fast_times
	var tips_by_time: PackedInt32Array = Tuning.data.v4_tip_fast
	var tip := tips_by_time[times.size()]
	for i in times.size():
		if seconds <= times[i]:
			tip = tips_by_time[i]
			break
	return roundi(tip * (Tuning.data.v4_tip_fast_hurry_mult if kind == "hurry" else 1.0))


## 테스트·키 없이: 목욕통에 강아지가 있으면 그 주인, 없으면 맨 앞 손님과 상호작용
func next_guest() -> void:
	if has_dog:
		interact_guest(guests.current)
	elif not guests.guests.is_empty():
		interact_guest(guests.guests[0].owner)


## 시계 (9:00 ~ 18:00)
func clock_text() -> String:
	var minutes := 9 * 60 + int(minf(day_time / day_seconds, 1.0) * 9 * 60)
	var hour := minutes / 60
	return "%s %d:%02d" % ["오전" if hour < 12 else "오후", hour if hour <= 12 else hour - 12, minutes % 60]


func _update_day(delta: float) -> void:
	if day_over:
		return
	if quick_dogs > 0:
		if guests.served >= quick_dogs:
			day_over = true
			_stop_effects()
			using = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			quick_finished.emit()
		return
	day_time += delta
	if guests.open and day_time >= day_seconds:
		guests.open = false
		_show_hint("6시, 영업 끝! 남은 손님만 씻겨요", 3.0)
	if not guests.open and not has_dog and guests.guests.is_empty() and guests.current == null:
		end_day()


## 영업 끝 → 정산 (씻긴·떠난·번 돈)
func end_day() -> void:
	day_over = true
	_stop_effects()
	using = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_settle = FpSettle.new()
	_settle.name = "Settle"
	_hud.get_parent().add_child(_settle)
	_settle.show_result(guests.served, guests.left_count, fees, tips)
	sfx.play("clap")


func _on_guest_left(_kind: String) -> void:
	_show_hint("손님이 \"다음에 올게요\" 하고 떠났어요", 2.5)
	sfx.play("bell")


## 진행 (0~1): 물·거품(진흙)·말리기, 남은 거품 수
func progress() -> Dictionary:
	return {"wet": dog.mask.ratio("wet"), "scrub": dog.mask.ratio("scrub"), "dry": dog.mask.ratio("dry"), "foam": dog.foam_count()}


func pick(tool_id: String) -> void:
	if not TOOLS.has(tool_id) or held == tool_id:
		return
	drop()
	# 빠르게 Q→같은 도구를 집어도 이전 반납 콜백이 선반을 다시 보이지 않게 한다.
	for view in _returning_views.duplicate():
		if view.tool_id == tool_id:
			_returning_views.erase(view)
			view.queue_free()
	held = tool_id
	_set_pickup_available(tool_id, false)
	_held_view = FpToolView.new()
	_held_view.setup(tool_id, FpToolView.RETURN_SECONDS if not _returning_views.is_empty() else 0.0)
	player.camera.add_child(_held_view)
	sfx.play("press")


func drop() -> void:
	if held.is_empty():
		return
	var previous := held
	held = ""
	if _held_view != null:
		_held_view.begin_return()
		_returning_views.append(_held_view)
		_held_view = null
	else:
		_set_pickup_available(previous, true)
	_stop_effects()


func _set_pickup_available(tool_id: String, available: bool) -> void:
	var pickup := _pickups[tool_id] as StaticBody3D
	pickup.visible = available
	# 숨긴 StaticBody 도 광선을 가로막으므로 선반에 없는 동안 충돌도 끈다.
	pickup.collision_layer = (1 << (PICK_LAYER - 1)) if available else 0


func _update_tool_views(delta: float, active: bool) -> void:
	if _held_view != null:
		_held_view.update_motion(delta, active)
	for view in _returning_views.duplicate():
		if view.update_motion(delta, false):
			if held != view.tool_id:
				_set_pickup_available(view.tool_id, true)
			_returning_views.erase(view)
			view.queue_free()


## 든 도구를 강아지 위 point(월드)에 delta 초 동안 쓴다 (마우스를 누르고 있는 동안 매 프레임)
func use_tool_at(point: Vector3, delta: float) -> void:
	if held.is_empty() or done:
		return
	var dir := dog.dir_of(point)
	var wet_here := dog.mask.value_at("wet", dir)
	var radius := brush_radius(point)
	var stage := ""
	match held:
		"shower":
			stage = "wet"
			dog.paint("wet", point, radius, Tuning.data.v4_rate_shower * delta)
			if dog.foam_count() > 0:
				stage = "rinse"
				dog.rinse_foam(point, radius * RINSE_REACH, delta * RINSE_SPEED)
				dog.paint("rinse", point, radius, Tuning.data.v4_rate_shower * delta)
			dog.spray(point)
			dog.show_stream(_tool_tip(), point, Color(0.55, 0.85, 1.0))
			sfx.set_loop("shower", 0.8)
		"shampoo":
			if wet_here < 0.3:
				_show_hint("먼저 샤워기로 물을 뿌려요", 1.5)
				return
			stage = "scrub"
			dog.paint("scrub", point, radius, Tuning.data.v4_rate_shampoo * delta)
			_foam_carry += delta * 10.0
			while _foam_carry >= 1.0:
				_foam_carry -= 1.0
				dog.add_foam(point, 1, _rng, FOAM_SIZE)
			sfx.set_loop("scrub", 0.8)
		"dryer":
			# 따뜻한 바람: 젖은 곳일수록 빨리 마르고, 마를수록 털이 뽕 부풀고 귀가 펄럭
			stage = "dry"
			if dog.foam_count() > 0 and dog.mask.value_at("scrub", dir) > 0.5:
				_show_hint("거품을 샤워기로 먼저 헹궈요", 1.5)
			dog.paint("dry", point, radius, Tuning.data.v4_rate_dryer * delta * clampf(wet_here + 0.2, 0.0, 1.0))
			dog.fluff = clampf(dog.mask.ratio("dry") / Tuning.data.v4_done_ratio, 0.0, 1.0)
			if dog.model.has_method("blow"):
				dog.model.blow(1.0)
			dog.show_stream(_tool_tip(), point, Color(1.0, 0.93, 0.8))
			sfx.set_loop("dryer", 0.8)
	# 반응: 씻는 동안 꼬리 흔들기 + 도구를 바라봄, 단계마다 처음 한 번 몸짓 (칠하기는 멈추지 않음)
	dog.react("set_mood", 2)
	if dog.model.has_method("watch"): dog.model.watch(point, true)
	if not _reacted.has(stage):
		_reacted[stage] = true
		dog.react(STAGE_REACTION[stage])
		if stage == "rinse":
			dog.splash()
			sfx.play("shake")
	_check_done()


## 붓 반경(m): 몸 겉면의 v4_brush_share 만큼 덮는 원 (구 위 원뿔 각 → 몸 중심에서의 거리)
func brush_radius(point: Vector3) -> float:
	var angle := acos(1.0 - 2.0 * Tuning.data.v4_brush_share)
	return angle * maxf(dog.dir_of(point).length(), 0.05)


## 단계가 끝났는지 차례로 본다 (앞 단계가 끝나야 다음 단계 끝을 알림)
func _check_done() -> void:
	var p := progress()
	while stage_index < STAGES.size() and _stage_met(STAGES[stage_index].id, p):
		_finish_stage(STAGES[stage_index])
		stage_index += 1
	if stage_index >= STAGES.size() and not done:
		done = true
		_stop_effects()
		dog.react("set_mood", 2)
		dog.react("jump")
		sfx.play("clap")
		_show_hint("주인을 클릭해서 돌려줘요", 999.0)


func _stage_met(id: String, p: Dictionary) -> bool:
	var done_at: float = Tuning.data.v4_done_ratio
	match id:
		"wet":
			return p.wet >= done_at
		"scrub":
			return p.scrub >= done_at
		"rinse":
			return p.foam == 0
	return p.dry >= done_at


## 단계 끝: 소리 + 반짝 파티클 + 가운데 큰 글자 (다음 도구 빛남은 _process)
func _finish_stage(stage: Dictionary) -> void:
	sfx.play(stage.sound)
	sfx.play("ding")
	_sparkle.global_position = dog.model.to_global(dog._body_center())
	_sparkle.restart()
	_sparkle.emitting = true
	_banner = stage.text
	_banner_left = 2.0
	dog.set_blink(0.0, stage.id)


## 지금 단계에 쓸 도구 ("" = 다 끝남)
func stage_tool() -> String:
	return STAGES[stage_index].tool if stage_index < STAGES.size() else ""


func _process(delta: float) -> void:
	_hint_left = maxf(_hint_left - delta, 0.0)
	_banner_left = maxf(_banner_left - delta, 0.0)
	_t += delta
	_update_day(delta)
	if input_enabled and not day_over:
		using = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_update_aim()
	# 바라보는 도구는 빛나고, 지금 단계에 쓸 도구는 손에 없으면 선반에서 깜빡깜빡 빛남
	var next := stage_tool()
	for tool_id in _pickups:
		_set_glow(_pickups[tool_id], tool_id == hovered or (tool_id == next and held != next and fmod(_t, 0.8) < 0.5))
	_update_leftovers()
	var active := has_dog and using and aim_point != null and not held.is_empty() and not done
	_update_tool_views(delta, active)
	if active:
		use_tool_at(aim_point, delta)
	else:
		_stop_effects()
		if not done:
			dog.react("set_mood", 1)
		if dog.model.has_method("watch"): dog.model.watch(null, false)
	_hud.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not hovered.is_empty():
			pick(hovered)
		elif hovered_guest != null:
			interact_guest(hovered_guest)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				drop()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_tree().change_scene_to_file(MENU_SCENE)


## 가운데 점이 가리키는 것: 집을 도구 / 강아지
func _update_aim() -> void:
	hovered = ""
	hovered_guest = null
	aim_point = null
	var ray: Array[Vector3] = player.aim_ray(REACH)
	var query := PhysicsRayQueryParameters3D.create(ray[0], ray[1], (1 << (PICK_LAYER - 1)) | DOG_LAYER)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	if collider.has_meta("tool"):
		hovered = collider.get_meta("tool")
	elif collider.has_meta("guest"):
		hovered_guest = collider.get_meta("guest")
	elif has_dog and collider is CollisionObject3D and (collider as CollisionObject3D).collision_layer & DOG_LAYER:
		aim_point = hit.position


func _tool_tip() -> Vector3:
	if _held_view != null:
		return _held_view.tip_position()
	return player.camera.global_position


func _stop_effects() -> void:
	if sfx == null or dog == null or dog.model == null:
		return
	sfx.set_loop("shower", 0.0)
	sfx.set_loop("scrub", 0.0)
	sfx.set_loop("dryer", 0.0)
	dog.stop_spray()
	dog.hide_stream()


## 남은 곳 보이기: 단계가 반쯤 되면 털 위 안 된 곳이 반짝, 헹굴 때 거품이 몇 개 안 남으면 그 거품이 반짝
func _update_leftovers() -> void:
	var stage_id: String = STAGES[stage_index].id if stage_index < STAGES.size() else ""
	var p := progress()
	var ratio: float = p.get(stage_id, 0.0) if stage_id != "rinse" else 1.0
	dog.set_blink((0.5 + 0.5 * sin(_t * 5.0)) if stage_id != "" and stage_id != "rinse" and ratio >= BLINK_FROM else 0.0, stage_id if stage_id != "" else "wet")
	foam_sparkle = stage_id == "rinse" and p.foam > 0 and p.foam <= FOAM_SPARKLE_BELOW
	dog.set_foam_glow(FOAM_GLOW + (0.5 + 0.5 * sin(_t * 8.0)) * 1.2 if foam_sparkle else FOAM_GLOW)


func _build_stage_effects() -> void:
	_sparkle = CPUParticles3D.new()
	_sparkle.name = "StageSparkle"
	_sparkle.emitting = false
	_sparkle.one_shot = true
	_sparkle.amount = 40
	_sparkle.lifetime = 0.9
	_sparkle.explosiveness = 1.0
	_sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparkle.emission_sphere_radius = 0.3
	_sparkle.direction = Vector3.UP
	_sparkle.spread = 180.0
	_sparkle.initial_velocity_min = 0.6
	_sparkle.initial_velocity_max = 1.6
	_sparkle.gravity = Vector3(0, -1.0, 0)
	_sparkle.scale_amount_min = 0.6
	_sparkle.scale_amount_max = 1.2
	var star := SphereMesh.new()
	star.radius = 0.02
	star.height = 0.04
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.95, 0.55)
	star.material = material
	_sparkle.mesh = star
	add_child(_sparkle)


func _on_guest_arrived() -> void:
	sfx.play("bell")
	if _hint_left <= 0.0:
		_show_hint("손님이 왔어요 (오른쪽 대기 의자)", 2.0)


func _show_hint(text: String, seconds: float) -> void:
	_hint = text
	_hint_left = seconds


# --- 방·선반·플레이어 (임시 상자)

func _build_room() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.75, 0.85, 0.9)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.9, 0.9, 0.95)
	environment.environment.ambient_light_energy = 0.25
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.4, -1.0)
	lamp.omni_range = 5.0
	lamp.light_energy = 0.25
	add_child(lamp)
	_box("Floor", Vector3(0, -0.1, 0), Vector3(8, 0.2, 7), Color(0.45, 0.58, 0.6))
	_box("WallBack", Vector3(0, 1.5, -3.5), Vector3(8, 3, 0.2), Color(0.85, 0.78, 0.66))
	_box("WallFront", Vector3(0, 1.5, 3.5), Vector3(8, 3, 0.2), Color(0.85, 0.78, 0.66))
	_box("WallLeft", Vector3(-4, 1.5, 0), Vector3(0.2, 3, 7), Color(0.8, 0.72, 0.6))
	_box("WallRight", Vector3(4, 1.5, 0), Vector3(0.2, 3, 7), Color(0.8, 0.72, 0.6))
	var tub := TUB_SCENE.instantiate() as Node3D
	tub.position = Vector3(DOG_SPOT.x, 0, DOG_SPOT.z)
	add_child(tub)
	# 목욕대 받침 충돌 (걸어서 통과하지 않게)
	_box("TubBlock", Vector3(DOG_SPOT.x, 0.45, DOG_SPOT.z), Vector3(1.6, 0.9, 1.1), Color(0, 0, 0, 0), false)


func _build_shelf() -> void:
	_box("Shelf", Vector3(-2.2, 0.45, -0.8), Vector3(0.6, 0.9, 1.8), Color(0.72, 0.55, 0.38))
	var z := -1.4
	for tool_id in TOOLS:
		var pickup := StaticBody3D.new()
		pickup.name = "Pickup_" + tool_id
		pickup.collision_layer = 1 << (PICK_LAYER - 1)
		pickup.collision_mask = 0
		pickup.set_meta("tool", tool_id)
		pickup.position = Vector3(-2.2, 0.9, z)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 0.35, 0.3)
		shape.shape = box
		shape.position.y = 0.17
		pickup.add_child(shape)
		var view := _make_tool_mesh(tool_id)
		# GLB 는 쥐는 곳이 원점: 각 메시 최저점을 선반 위에 맞춘다.
		view.position.y = {"shower": 0.130, "shampoo": 0.074, "dryer": 0.056}[tool_id]
		view.rotation.y = PI / 2.0 # -Z 앞면을 선반 바깥(+X)으로
		pickup.add_child(view)
		_cache_glow_materials(tool_id, view)
		add_child(pickup)
		_pickups[tool_id] = pickup
		z += 0.6


func _build_player() -> void:
	player = FpPlayer.new()
	player.name = "Player"
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	body.shape = capsule
	body.position.y = 0.8
	player.add_child(body)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position.y = FpPlayer.EYE_HEIGHT
	camera.fov = 70.0
	camera.current = true
	player.add_child(camera)
	player.position = Vector3(0, 0.05, 0.6)
	add_child(player)


## 자산 경로와 손목 연출은 FpToolView 한 곳에서 교체한다.
func _make_tool_mesh(tool_id: String) -> Node3D:
	return FpToolView.make_model(tool_id)


## GLB 는 material_override 가 아니라 여러 surface 재질을 사용한다.
## 인스턴스마다 복제하여 선반 강조가 손에 든 도구/원본 자산에 번지지 않게 한다.
func _cache_glow_materials(tool_id: String, view: Node3D) -> void:
	var materials: Array[StandardMaterial3D] = []
	var meshes: Array[Node] = view.find_children("*", "MeshInstance3D", true, false)
	if view is MeshInstance3D:
		meshes.append(view)
	for node in meshes:
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material := original.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(surface, material)
			material.emission = Color(1.0, 0.9, 0.5)
			material.emission_energy_multiplier = 0.6
			materials.append(material)
	_glow_materials[tool_id] = materials


## 바라보는 선반 도구의 원래 파스텔 색·라벨을 보존하며 강조한다.
func _set_glow(pickup: Node3D, on: bool) -> void:
	var tool_id: String = pickup.get_meta("tool")
	for material in _glow_materials[tool_id]:
		material.emission_enabled = on and pickup.visible


func _box(box_name: String, pos: Vector3, size: Vector3, color: Color, visible_mesh := true) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if visible_mesh:
		var mesh := BoxMesh.new()
		mesh.size = size
		var view := MeshInstance3D.new()
		view.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		view.material_override = material
		body.add_child(view)
	add_child(body)


# --- 화면 (가운데 점, 바라보는 것, 진행, 조작)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = get_tree().root.theme
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)


func _draw_hud() -> void:
	var size := _hud.get_viewport_rect().size
	var center := size / 2.0
	var font := _hud.get_theme_default_font()
	# 가운데 점 (도구를 쓸 수 있는 곳이면 노랑)
	var ready_to_use := aim_point != null and not held.is_empty()
	_hud.draw_circle(center, 5.0, Color(0, 0, 0, 0.6))
	_hud.draw_circle(center, 3.0, Color(1, 0.85, 0.3) if ready_to_use or not hovered.is_empty() or hovered_guest != null else Color(1, 1, 1))
	var under := ""
	if not hovered.is_empty():
		under = "클릭: %s 집기" % TOOLS[hovered].name
	elif hovered_guest != null:
		if hovered_guest == guests.current:
			under = "클릭: 강아지 돌려주기" if done else "다 씻으면 돌려줘요"
		else:
			under = "목욕통이 비면 받아요" if has_dog else "클릭: 강아지 맡기"
	elif aim_point != null and held.is_empty():
		under = "선반에서 도구를 집어요"
	elif ready_to_use and not using:
		under = "누르고 있으면 %s" % {"shower": "물이 나와요", "shampoo": "거품이 나요", "dryer": "바람이 나와요"}[held]
	_text(font, center + Vector2(0, 40), under, 22, true)
	# 진행 (목욕통에 강아지가 있을 때만)
	var p := progress()
	var rows := [["물", p.wet], ["거품 (진흙)", p.scrub], ["말리기", p.dry]] if has_dog else []
	for i in rows.size():
		var y := 30.0 + i * 34.0
		_hud.draw_rect(Rect2(20, y, 220, 22), Color(0, 0, 0, 0.5))
		_hud.draw_rect(Rect2(20, y, 220 * clampf(rows[i][1] / Tuning.data.v4_done_ratio, 0.0, 1.0), 22), Color(0.5, 0.85, 0.55) if rows[i][1] >= Tuning.data.v4_done_ratio else Color(0.45, 0.7, 1.0))
		_text(font, Vector2(250, y + 18), rows[i][0], 18, false)
	if has_dog and p.foam > 0:
		_text(font, Vector2(20, 30 + 3 * 34 + 18), "남은 거품 %d (샤워기로 헹구기)" % p.foam, 18, false)
	if quick_dogs > 0:
		_text(font, Vector2(size.x - 20, 40), "빠른 확인 · 강아지 %d / %d" % [guests.served, quick_dogs], 26, false, true)
	else:
		_text(font, Vector2(size.x - 20, 40), "%s%s" % [clock_text(), "" if guests.open else " · 영업 끝"], 26, false, true)
	_text(font, Vector2(size.x - 20, 74), "돈 %d" % money, 26, false, true)
	_text(font, Vector2(size.x - 20, 104), "기다리는 손님 %d · 씻긴 %d · 떠난 %d" % [guests.guests.size(), guests.served, guests.left_count], 18, false, true)
	_text(font, Vector2(size.x - 20, size.y - 60), "손: %s" % (TOOLS[held].name if not held.is_empty() else "빈손"), 22, false, true)
	_text(font, Vector2(20, size.y - 20), "WASD 걷기 · 마우스 보기 · 클릭 집기/쓰기(누르고 있기) · Q 내려놓기 · 손님 클릭 맡기기/돌려주기 · Esc 메뉴", 16, false)
	if _hint_left > 0.0:
		_text(font, Vector2(center.x, 120), _hint, 26, true)
	if _banner_left > 0.0:
		_text(font, center + Vector2(0, -90), _banner, 44, true)


func _text(font: Font, at: Vector2, text: String, font_size: int, centered: bool, right := false) -> void:
	if text.is_empty():
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := at - Vector2(width / 2.0 if centered else (width if right else 0.0), 0)
	_hud.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.8))
	_hud.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))
