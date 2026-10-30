extends Node3D
## V4 대기 손님 (GDD_V4 0.2 "압박 = 대기 손님 참을성"). 문으로 들어와 대기 의자에 앉아 기다린다.
##
## 손님(주인)마다 성격 하나, 머리 위 표시로 처음부터 보인다:
##   급함 = 빨간 시계 / 보통 = 노란 시계 / 느긋 = 초록 잎 / 끝까지 = 컵 (안 떠남)
## 참을성이 줄면 시계 보기 → 발 구르기 → 표시 깜빡임. 다 되면 일어나 "다음에 올게요" 하고 끄덕, 문으로 나감.
## 목욕 중인 손님은 떠나지 않는다: call_next() 로 맨 앞 손님을 목욕통 옆으로 데려오면 대기열에서 빠진다.
## 주인·의자·안은 강아지는 V3 교체 씬을 그대로 쓴다. 위치는 모두 방(부모) 기준.

signal guest_left(kind: String)

const OWNER_SCENE := preload("res://scenes/art/sim/owner_model.tscn")
const CHAIR_SCENE := preload("res://scenes/art/sim/chair_model.tscn")
const DOG_SCENE := preload("res://scenes/art/sim/dog_model.tscn")
const FONT := preload("res://assets/fonts/pretendard/Pretendard-Bold.otf")
const KINDS: Array[String] = ["urgent", "normal", "relaxed", "endless"]
const KIND_NAMES := {"urgent": "급함", "normal": "보통", "relaxed": "느긋", "endless": "끝까지"}
const DOOR := Vector3(3.5, 0, 2.6)
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

## 대기 의자의 손님 (앞이 먼저): {kind, patience(s, <0 = 안 떠남), waited, owner, icon}
var guests: Array[Dictionary] = []
## 목욕통 옆에서 지켜보는 지금 강아지 주인 (없으면 null)
var current: Variant = null
var served := 0
var left_count := 0

var _rng := RandomNumberGenerator.new()
var _opening: Array = []
var _spawn_left := 0.0
var _variant := 0
## 떠나는 손님: {owner, t}
var _leaving: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	_opening = Tuning.data.v4_first_guests.duplicate()
	_spawn_left = 1.0
	for i in SEATS.size():
		var chair := CHAIR_SCENE.instantiate() as Node3D
		chair.name = "Chair_%d" % (i + 1)
		add_child(chair)
		chair.position = SEATS[i]
		chair.rotation.y = atan2(LOOK_AT.x - SEATS[i].x, LOOK_AT.z - SEATS[i].z)
	var door := MeshInstance3D.new()
	door.name = "Door"
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 2.0, 0.9)
	door.mesh = box
	door.position = Vector3(3.88, 1.0, DOOR.z)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.38, 0.25)
	door.material_override = material
	add_child(door)


## 손님 한 명을 바로 들여보냄 (테스트·처음 줄). kind = "" 이면 비율대로 뽑음
func spawn(kind := "") -> void:
	if guests.size() >= SEATS.size():
		return
	if kind.is_empty():
		kind = roll_kind()
	var owner := OWNER_SCENE.instantiate() as Node3D
	add_child(owner)
	owner.position = DOOR
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
	guests.append({"kind": kind, "patience": patience_of(kind), "waited": 0.0, "owner": owner, "icon": icon})
	_seat_all()


## 성격 뽑기: v4_guest_weights (급함·보통·느긋·끝까지)
func roll_kind() -> String:
	var weights: PackedFloat32Array = Tuning.data.v4_guest_weights
	var total := 0.0
	for w in weights:
		total += w
	var pick := _rng.randf() * total
	for i in KINDS.size():
		pick -= weights[i]
		if pick < 0.0:
			return KINDS[i]
	return "normal"


static func patience_of(kind: String) -> float:
	match kind:
		"urgent":
			return Tuning.data.v4_patience_urgent
		"normal":
			return Tuning.data.v4_patience_normal
		"relaxed":
			return Tuning.data.v4_patience_relaxed
	return -1.0


## 남은 참을성 비율 (1 = 막 옴, 0 = 떠남). 끝까지 손님은 늘 1
func remaining(index: int) -> float:
	var guest: Dictionary = guests[index]
	if guest.patience < 0.0:
		return 1.0
	return clampf(1.0 - guest.waited / guest.patience, 0.0, 1.0)


## 다 씻었을 때 부름: 맨 앞 손님을 목욕통 옆으로 (지금 주인은 기뻐하며 나감). 데려온 손님 성격, 없으면 ""
func call_next() -> String:
	# 다 씻은 강아지 한 마리 (처음 강아지는 주인 없이 시작)
	served += 1
	if current != null:
		_send_home(current, 2)
		current = null
	if guests.is_empty():
		return ""
	var guest: Dictionary = guests.pop_front()
	var owner: Node3D = guest.owner
	(guest.icon as Node3D).queue_free()
	owner.get_node("HeldDog").queue_free()
	owner.holding = false
	owner.go_wait(to_global(TUB_SIDE), to_global(LOOK_AT), owner.position.distance_to(TUB_SIDE) / WALK_SPEED, false)
	current = owner
	_seat_all()
	return guest.kind


func _process(delta: float) -> void:
	_spawn_left -= delta
	if _spawn_left <= 0.0:
		if not _opening.is_empty():
			spawn(_opening.pop_front())
			_spawn_left = 2.5
		else:
			spawn()
			_spawn_left = Tuning.data.v4_guest_every
	var camera := get_viewport().get_camera_3d()
	var i := 0
	while i < guests.size():
		var guest: Dictionary = guests[i]
		var owner: Node3D = guest.owner
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
			owner.leave(to_global(DOOR), owner.position.distance_to(DOOR) / WALK_SPEED)
		elif item.t > 0.9 + 6.0:
			(item.owner as Node3D).queue_free()
			_leaving.erase(item)


## 일어나 반응(1 끄덕 / 2 박수)하고 문으로
func _send_home(owner: Node3D, mood_level: int, say := "") -> void:
	owner.wait_level = 0
	owner.come_react(owner.global_position, mood_level)
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


func _seat_all() -> void:
	for i in guests.size():
		var owner: Node3D = guests[i].owner
		var seat := SEATS[i]
		owner.go_wait(to_global(seat), to_global(LOOK_AT), maxf(owner.position.distance_to(seat), 0.3) / WALK_SPEED, true)


# --- 머리 위 표시 (임시 모형: 진짜 그림이 오면 교체)

func _make_icon(kind: String) -> Node3D:
	var icon := Node3D.new()
	icon.name = "PatienceIcon"
	match kind:
		"urgent", "normal":
			var rim := Color(0.95, 0.25, 0.25) if kind == "urgent" else Color(1.0, 0.8, 0.2)
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
		"endless":
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
