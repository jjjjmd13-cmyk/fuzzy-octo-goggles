extends Node3D
## V4 대기 손님 (GDD_V4 0.2 "압박 = 대기 손님 참을성"). 문으로 들어와 대기 의자에 앉아 기다린다.
##
## 손님(주인)마다 성격 하나, 머리 위 표시로 처음부터 보인다:
##   급함 = 빨간 시계 / 보통 = 노란 시계 / 느긋 = 초록 잎 / 끝까지 = 컵 (안 떠남)
## 참을성이 줄면 시계 보기 → 발 구르기 → 표시 깜빡임. 다 되면 일어나 "다음에 올게요" 하고 끄덕, 문으로 나감.
## 목욕 중인 손님은 떠나지 않는다: take_next() 로 맨 앞 손님이 목욕통 옆으로 와서 강아지를 맡기면 대기열에서 빠진다.
## 주인·의자·안은 강아지는 V3 교체 씬을 그대로 쓴다. 위치는 모두 방(부모) 기준.

signal guest_left(kind: String)
signal guest_arrived
## 대기 강아지가 택배 상자 냄새를 맡음 (테스트·확인용)
signal sniffed(owner: Node3D)

const OWNER_SCENE := preload("res://scenes/art/sim/owner_model.tscn")
const CHAIR_SCENE := preload("res://scenes/art/sim/chair_model.tscn")
const DOG_SCENE := preload("res://scenes/art/sim/dog_model.tscn")
const FONT := preload("res://assets/fonts/pretendard/Pretendard-Bold.otf")
const KINDS: Array[String] = ["hurry", "normal", "relaxed", "forever"]
const TRIM_NAMES := {"bear": "곰돌이컷", "lion": "사자컷", "summer": "여름컷"}
const KIND_NAMES := {"hurry": "급함", "normal": "보통", "relaxed": "느긋", "forever": "끝까지"}
const DOOR := Vector3(3.5, 0, 2.6)
## 가게 밖 손님 길 (GDD_V4 '가게 밖'): 찻길 쪽 울타리 틈 → 정문 바로 밖 → 정문 (z ≈ 2.6 한 줄)
const STREET := Vector3(9.6, 0, 2.6)
const OUTSIDE_DOOR := Vector3(4.6, 0, 2.6)
## 이 x 보다 안쪽이면 가게 안 (참을성은 안에 들어와서부터)
const INSIDE_X := 3.9
const SEATS: Array[Vector3] = [Vector3(3.0, 0, -1.4), Vector3(3.0, 0, -0.5), Vector3(3.0, 0, 0.4)]
## 목욕 중인 강아지 주인이 서서 지켜보는 곳
const TUB_SIDE := Vector3(1.15, 0, -1.0)
const LOOK_AT := Vector3(0, 0, -1.6)
const WALK_SPEED := 1.4
const HELD_DOG_SCALE := 0.6
const HELD_ON_LAP := Vector3(0, 0.56, 0.1)
const HELD_STANDING := Vector3(0, 0.82, 0.26)
## 남은 참을성이 이 비율 아래면 표시 깜빡임
const BLINK_BELOW := 0.25
## 손님 클릭 판정 층 (fp_shop.PICK_LAYER 와 같음). 판정 모양에 meta "guest" = 주인 노드
const HIT_LAYER := 2

## 대기 의자의 손님 (앞이 먼저): {kind, patience(s, <0 = 안 떠남), waited, owner, icon}
var guests: Array[Dictionary] = []
## 목욕통 옆에서 지켜보는 지금 강아지 주인 (없으면 null)
var current: Variant = null
var served := 0
var left_count := 0
## 영업 중 (false 면 새 손님이 안 옴, 남은 손님은 그대로)
var open := true
## 빠른 확인 모드: 처음 줄(_opening) 손님만 오고, 아무도 떠나지 않음 (참을성 끔)
var quick := false
## 미용을 요청하는 손님 비율 (가위를 사면 가게가 v4_trim_request_ratio 로 올림, 0 = 요청 없음)
var trim_chance := 0.0
## 꾸미기 아늑함으로 늘어난 참을성 배수 (1 = 그대로)
var patience_mult := 1.0
## 요청 모양 목록 (fp_trim.gd SHAPES 의 id)
var trim_shapes: Array = ["bear", "lion", "summer"]

var _rng := RandomNumberGenerator.new()
var _opening: Array = []
## add_child 전에 정하면 v4_first_guests 대신 이 줄 (빠른 확인)
var opening_override: Variant = null
var _spawn_left := 0.0
## 가게를 연 뒤 지난 시간 (s)
var elapsed := 0.0
var _variant := 0
## 떠나는 손님: {owner, t}
var _leaving: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	_opening = Tuning.data.v4_first_guests.duplicate() if opening_override == null else opening_override
	_spawn_left = 1.0
	for i in SEATS.size():
		var chair := CHAIR_SCENE.instantiate() as Node3D
		chair.name = "Chair_%d" % (i + 1)
		add_child(chair)
		chair.position = SEATS[i]
		chair.rotation.y = atan2(LOOK_AT.x - SEATS[i].x, LOOK_AT.z - SEATS[i].z)
	# 정문 문짝은 가게 밖(fp_outside.gd)이 만듦 (다가가면 열리는 진짜 문)


## 다음 날: 오늘 센 것과 처음 줄을 새로 (시간 elapsed 도 0 부터, 급함은 다시 v4_hurry_after 뒤에)
func start_day() -> void:
	served = 0
	left_count = 0
	elapsed = 0.0
	open = true
	_opening = Tuning.data.v4_first_guests.duplicate()
	_spawn_left = 1.0


## 손님 한 명을 바로 들여보냄 (테스트·처음 줄). kind = "" 이면 비율대로 뽑음
## walk_in = true 면 찻길에서 마당을 지나 정문으로 걸어 들어옴 (영업 중 손님), false 면 정문 안쪽에서 바로 (테스트·빠른 확인)
func spawn(kind := "", walk_in := false) -> void:
	if guests.size() >= SEATS.size():
		return
	if kind.is_empty():
		kind = roll_kind()
	var owner := OWNER_SCENE.instantiate() as Node3D
	add_child(owner)
	owner.add_to_group("door_users")
	owner.position = STREET if walk_in else DOOR
	owner.set_variant(_variant % 6)
	_variant += 1
	var holder := Node3D.new()
	holder.name = "HeldDog"
	holder.scale = Vector3.ONE * HELD_DOG_SCALE
	owner.add_child(holder)
	var held := DOG_SCENE.instantiate() as Node3D
	held.set("auto_hit_shapes", false)
	holder.add_child(held)
	owner.holding = true
	var icon := _make_icon(kind)
	owner.add_child(icon)
	var trim := ""
	if trim_chance > 0.0 and _rng.randf() < trim_chance:
		trim = trim_shapes[_rng.randi() % trim_shapes.size()]
		_add_trim_label(owner, trim)
	_add_hit(owner)
	guests.append({"kind": kind, "patience": patience_of(kind), "waited": 0.0, "owner": owner, "icon": icon, "arrived": elapsed, "trim": trim})
	guest_arrived.emit()
	_seat_all()


## 성격 뽑기: v4_patience_mix (급함·보통·느긋·끝까지). 연 뒤 v4_hurry_after 초 동안은 급함 없음
func roll_kind() -> String:
	var weights: PackedFloat32Array = Tuning.data.v4_patience_mix.duplicate()
	if elapsed < Tuning.data.v4_hurry_after:
		weights[KINDS.find("hurry")] = 0.0
	var total := 0.0
	for w in weights:
		total += w
	var pick := _rng.randf() * total
	for i in KINDS.size():
		pick -= weights[i]
		if pick < 0.0:
			return KINDS[i]
	return "normal"


## 성격의 참을성 (s). 0 이하 = 안 떠남 (끝까지)
static func patience_of(kind: String) -> float:
	return float(Tuning.data.get("v4_patience_" + kind))


## 남은 참을성 비율 (1 = 막 옴, 0 = 떠남). 끝까지 손님은 늘 1
func remaining(index: int) -> float:
	var guest: Dictionary = guests[index]
	if guest.patience <= 0.0 or quick:
		return 1.0
	return clampf(1.0 - guest.waited / (guest.patience * patience_mult), 0.0, 1.0)


## 다 씻은 강아지를 주인에게 돌려줌: 주인은 박수치며 (say: "+45" 같은 글자) 나감
func return_current(say := "") -> void:
	served += 1
	if current != null:
		_send_home(current, 2, say)
		current = null


## 맨 앞 손님이 강아지를 맡김 (take 참고). 기다리는 손님이 없으면 {}
func take_next() -> Dictionary:
	if guests.is_empty():
		return {}
	return take(guests[0].owner)


## 대기 손님(owner)이 목욕통 옆으로 와서 강아지를 맡김.
## 돌려줌: {kind, remaining (맡길 때 남은 참을성 0~1), arrived (들어온 시각, elapsed 기준)}, 대기 손님이 아니면 {}
func take(owner: Node3D) -> Dictionary:
	var index := index_of(owner)
	# 아직 마당을 걸어오는 손님은 들어온 뒤에 받음
	if index < 0 or owner.position.x > INSIDE_X:
		return {}
	var left := remaining(index)
	var guest: Dictionary = guests[index]
	guests.remove_at(index)
	(guest.icon as Node3D).queue_free()
	owner.get_node("HeldDog").queue_free()
	owner.holding = false
	owner.go_wait(to_global(TUB_SIDE), to_global(LOOK_AT), owner.position.distance_to(TUB_SIDE) / WALK_SPEED, false)
	current = owner
	_seat_all()
	var label := owner.get_node_or_null("TrimLabel")
	if label != null:
		label.queue_free()
	return {"kind": guest.kind, "remaining": left, "arrived": guest.arrived, "trim": guest.trim}


## 대기열에서 몇 번째인지 (없으면 -1)
func index_of(owner: Node3D) -> int:
	for i in guests.size():
		if guests[i].owner == owner:
			return i
	return -1


func _process(delta: float) -> void:
	elapsed += delta
	_spawn_left -= delta
	if _spawn_left <= 0.0 and open:
		if not _opening.is_empty():
			spawn(_opening.pop_front(), not quick)
			_spawn_left = 2.5 if not _opening.is_empty() else Tuning.data.v4_guest_every
		elif not quick:
			spawn("", true)
			_spawn_left = Tuning.data.v4_guest_every
	var camera := get_viewport().get_camera_3d()
	var i := 0
	while i < guests.size():
		var guest: Dictionary = guests[i]
		var owner: Node3D = guest.owner
		# 마당을 걸어오는 동안은 참을성이 안 줄고, 들어온 때부터 빠른 팁 시간을 셈
		if owner.position.x > INSIDE_X:
			guest.arrived = elapsed
			i += 1
			continue
		guest.waited += delta
		var left := remaining(i)
		if left <= 0.0:
			guests.remove_at(i)
			left_count += 1
			(guest.icon as Node3D).queue_free()
			_send_home(owner, 1, "다음에 올게요")
			guest_left.emit(guest.kind)
			_seat_all()
			continue
		# 몸짓: 시계 보기 → 발 구르기 (일어섬은 떠날 때)
		owner.wait_level = 0 if left > 0.5 else (1 if left > BLINK_BELOW else 2)
		var held := owner.get_node_or_null("HeldDog") as Node3D
		if held != null:
			held.position = HELD_ON_LAP if owner.is_sitting() else HELD_STANDING
		var icon: Node3D = guest.icon
		icon.position.y = owner.height + 0.38
		icon.visible = left > BLINK_BELOW or fmod(guest.waited, 0.5) < 0.3
		icon.scale = Vector3.ONE * (1.0 + (0.15 * sin(guest.waited * 12.0) if left <= BLINK_BELOW else 0.0))
		if camera != null:
			var to_camera := camera.global_position - icon.global_position
			icon.global_rotation = Vector3(0, atan2(to_camera.x, to_camera.z), 0)
		i += 1
	for item in _leaving.duplicate():
		item.t += delta
		if item.t >= 0.9 and not item.walking:
			item.walking = true
			var owner: Node3D = item.owner
			# 정문으로 나가 마당을 지나 찻길로
			var length := owner.position.distance_to(DOOR) + DOOR.distance_to(OUTSIDE_DOOR) + OUTSIDE_DOOR.distance_to(STREET)
			item.leave_time = length / WALK_SPEED
			owner.leave(to_global(STREET), item.leave_time, [to_global(DOOR), to_global(OUTSIDE_DOOR)])
		elif item.t > 0.9 + item.get("leave_time", 6.0) + 0.3:
			(item.owner as Node3D).queue_free()
			_leaving.erase(item)


## 대기 손님 강아지가 안 연 택배 상자 쪽으로 고개를 돌리고 킁킁 (참을성에는 영향 없음, GDD_V4 재미 포인트)
func sniff(index: int, target: Vector3) -> void:
	if index < 0 or index >= guests.size():
		return
	var owner: Node3D = guests[index].owner
	var held := owner.get_node_or_null("HeldDog") as Node3D
	if held == null or held.has_meta("sniffing"):
		return
	held.set_meta("sniffing", true)
	var dog := held.get_child(0) as Node3D
	var flat := target - held.global_position
	var turn := atan2(flat.x, flat.z) - owner.global_rotation.y
	var label := Label3D.new()
	label.name = "Sniff"
	label.text = "킁킁"
	label.font = FONT
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.7, 0)
	held.add_child(label)
	var tween := create_tween()
	tween.tween_property(dog, "rotation:y", turn, 0.3)
	tween.tween_interval(1.4)
	tween.tween_property(dog, "rotation:y", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
		if is_instance_valid(held):
			held.remove_meta("sniffing"))
	sniffed.emit(owner)


## 일어나 반응(1 끄덕 / 2 박수)하고 문으로
func _send_home(owner: Node3D, mood_level: int, say := "") -> void:
	owner.wait_level = 0
	owner.come_react(owner.global_position, mood_level)
	# 떠나는 손님은 바로 클릭이 안 되게 (queue_free 는 프레임 끝까지 남으므로 먼저 떼어 냄)
	var hit := owner.get_node_or_null("GuestHit")
	if hit != null:
		owner.remove_child(hit)
		hit.queue_free()
	if not say.is_empty():
		var label := Label3D.new()
		label.text = say
		label.font = FONT
		label.font_size = 44
		label.outline_size = 12
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position.y = owner.height + 0.4
		owner.add_child(label)
	_leaving.append({"owner": owner, "t": 0.0, "walking": false})


## 미용 요청 손님: 머리 위 표시 위에 "미용: 곰돌이컷"
func _add_trim_label(owner: Node3D, trim: String) -> void:
	var label := Label3D.new()
	label.name = "TrimLabel"
	label.text = "미용: %s" % TRIM_NAMES.get(trim, trim)
	label.font = FONT
	label.font_size = 36
	label.outline_size = 10
	label.modulate = Color(1.0, 0.75, 0.85)
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 1.75
	owner.add_child(label)


## 클릭 판정 모양 (앉아도 서도 몸을 덮는 캡슐)
func _add_hit(owner: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "GuestHit"
	body.collision_layer = HIT_LAYER
	body.collision_mask = 0
	body.set_meta("guest", owner)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.3
	shape.shape = capsule
	shape.position.y = 0.65
	body.add_child(shape)
	owner.add_child(body)


func _seat_all() -> void:
	for i in guests.size():
		var owner: Node3D = guests[i].owner
		var seat := SEATS[i]
		# 아직 밖이면 정문을 지나서 (벽을 뚫지 않게)
		var via: Array = []
		var length := owner.position.distance_to(seat)
		if owner.position.x > INSIDE_X:
			via = [to_global(OUTSIDE_DOOR), to_global(DOOR)] if owner.position.x > OUTSIDE_DOOR.x else [to_global(DOOR)]
			length = owner.position.distance_to(DOOR) + DOOR.distance_to(seat)
		owner.go_wait(to_global(seat), to_global(LOOK_AT), maxf(length, 0.3) / WALK_SPEED, true, via)


# --- 머리 위 표시 (임시 모형: 진짜 그림이 오면 교체)

func _make_icon(kind: String) -> Node3D:
	var icon := Node3D.new()
	icon.name = "PatienceIcon"
	match kind:
		"hurry", "normal":
			var rim := Color(0.95, 0.25, 0.25) if kind == "hurry" else Color(1.0, 0.8, 0.2)
			_part(icon, _disc(0.14), Vector3.ZERO, rim)
			_part(icon, _disc(0.11), Vector3(0, 0, 0.012), Color(1, 1, 1))
			_part(icon, _bar(Vector3(0.016, 0.085, 0.01)), Vector3(0, 0.035, 0.024), Color(0.15, 0.15, 0.2))
			var hand := _part(icon, _bar(Vector3(0.016, 0.06, 0.01)), Vector3(0.022, -0.012, 0.024), Color(0.15, 0.15, 0.2))
			hand.rotation.z = PI * 0.62
			# 귀 두 개 (자명종)
			_part(icon, _disc(0.04), Vector3(-0.1, 0.12, 0), rim)
			_part(icon, _disc(0.04), Vector3(0.1, 0.12, 0), rim)
		"relaxed":
			var leaf := _part(icon, _sphere(), Vector3.ZERO, Color(0.35, 0.8, 0.4))
			leaf.scale = Vector3(0.07, 0.12, 0.025)
			leaf.rotation.z = -0.5
			var stem := _part(icon, _bar(Vector3(0.015, 0.09, 0.015)), Vector3(-0.05, -0.1, 0), Color(0.25, 0.55, 0.3))
			stem.rotation.z = -0.5
		"forever":
			var cup := CylinderMesh.new()
			cup.top_radius = 0.08
			cup.bottom_radius = 0.065
			cup.height = 0.14
			_part(icon, cup, Vector3.ZERO, Color(0.97, 0.95, 0.9))
			var coffee := CylinderMesh.new()
			coffee.top_radius = 0.07
			coffee.bottom_radius = 0.07
			coffee.height = 0.01
			_part(icon, coffee, Vector3(0, 0.066, 0), Color(0.45, 0.28, 0.18))
			var handle := TorusMesh.new()
			handle.inner_radius = 0.03
			handle.outer_radius = 0.045
			var ring := _part(icon, handle, Vector3(0.09, 0.0, 0), Color(0.97, 0.95, 0.9))
			ring.rotation.x = PI / 2.0
	return icon


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## 카메라 쪽(+Z)을 보는 납작한 원
func _disc(radius: float) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	var holder := ArrayMesh.new()
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var turn := Basis(Vector3.RIGHT, PI / 2.0)
	for i in verts.size():
		verts[i] = turn * verts[i]
		normals[i] = turn * normals[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	holder.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return holder


func _bar(size: Vector3) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _sphere() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	return mesh
