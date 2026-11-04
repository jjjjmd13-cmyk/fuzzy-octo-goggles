extends Node3D
## V4 가게 밖 (GDD_V4 '가게 밖·택배', ART_SLOTS 4-3): 오른쪽 벽 정문 + 가게 앞 마당 + 영업 팻말.
##
## - 정문: 오른쪽 벽(x = +4) 가운데에서 +2.6 m, 폭 1.2 × 높이 2.1 m 구멍. 문짝은 플레이어가 다가가면 저절로 열림 (딸랑).
##   문짝엔 충돌이 없음 (밀려나지 않게), 벽 구멍 둘레만 막힘.
## - 마당: x = 4 ~ 9, z = −3.5 ~ 3.5. 보도블록·택배 매트·우편함·가로등·울타리·화단, 울타리 너머 찻길 (못 나감).
## - 영업 팻말: 문 안쪽 벽에 걸림. 아침엔 달(닫힘), 클릭해서 뒤집으면 해(영업 중).
##
## 그래픽 교체: `assets/models/outside/<이름>.glb` 가 있으면 그 모형을 쓰고 없으면 임시 상자.
## 반복 바닥은 `assets/textures/outside/<이름>.png` (1 장 = 1 m × 1 m). 받은 파일을 그 이름으로 넣기만 하면 됨.

signal door_opened

const MODEL_DIR := "res://assets/models/outside/%s.glb"
const TEXTURE_DIR := "res://assets/textures/outside/%s.png"
const PICK_LAYER := 2
## 정문 (방 좌표)
const WALL_X := 4.0
const DOOR_Z := 2.6
const DOOR_WIDTH := 1.2
const DOOR_HEIGHT := 2.1
const WALL_HEIGHT := 3.0
const ROOM_HALF_Z := 3.5
## 마당 끝 (울타리 줄)과 찻길
const YARD_END_X := 9.0
const ROAD_X := 10.5
## 손님 길이 찻길로 이어지는 울타리 틈 (z 가운데, 폭)
const FENCE_GAP_WIDTH := 1.5
## 문이 열리기 시작하는 거리 (m)
const DOOR_OPEN_NEAR := 1.6
const DOOR_SPEED := 4.0
## 놓는 자리 (ART_SLOTS 4-3 제안)
const MAT_POS := Vector3(5.0, 0, 0.5)
const MAILBOX_POS := Vector3(8.4, 0, -2.6)
const LAMP_POS := Vector3(8.6, 0, 1.4)
## 팻말: 문 왼쪽(−Z 쪽) 안쪽 벽, 눈높이 조금 아래
const SIGN_POS := Vector3(3.86, 1.5, 1.7)

## 문이 열린 정도 0 (닫힘) ~ 1 (활짝)
var door_open := 0.0
## 팻말이 해(영업 중) 쪽인가
var sign_open := false
## 문이 열리는지 볼 대상 (플레이어). 없으면 문은 닫혀 있음
var watch: Node3D

var door_pivot: Node3D
var sign_body: StaticBody3D
var sign_plate: Node3D
var mailbox_flag: Node3D
## 그래픽 파일을 쓴 이름 (테스트·확인용)
var used_models: PackedStringArray = []

var _was_open := false
var _sign_turn := 0.0
var _sign_target := 0.0


func _ready() -> void:
	_build_wall()
	_build_door()
	_build_yard()
	_build_sign()


func _process(delta: float) -> void:
	var want := 0.0
	if watch != null and is_instance_valid(watch):
		var flat := Vector2(watch.global_position.x - WALL_X, watch.global_position.z - DOOR_Z)
		want = 1.0 if flat.length() < DOOR_OPEN_NEAR else 0.0
	door_open = move_toward(door_open, want, DOOR_SPEED * delta)
	door_pivot.rotation.y = -door_open * PI * 0.55
	if door_open > 0.05 and not _was_open:
		door_opened.emit()
	_was_open = door_open > 0.05
	# 팻말 뒤집기 (Y 축으로 반 바퀴)
	_sign_turn = move_toward(_sign_turn, _sign_target, PI * 2.5 * delta)
	sign_plate.rotation.y = _sign_turn


## 팻말을 해(true) / 달(false) 쪽으로. 연출은 반 바퀴 돎
func set_sign(open: bool, instant := false) -> void:
	sign_open = open
	_sign_target = PI if open else 0.0
	if instant:
		_sign_turn = _sign_target
		sign_plate.rotation.y = _sign_turn


## 마당(정문 밖)에 있는가
static func is_outside(point: Vector3) -> bool:
	return point.x > WALL_X


## 그 이름의 그래픽 모형 (없으면 null)
func model(model_name: String) -> Node3D:
	var path := MODEL_DIR % model_name
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	used_models.append(model_name)
	return scene.instantiate() as Node3D


func _build_wall() -> void:
	# 오른쪽 벽: 문 구멍만 비우고 세 토막 (문 앞쪽 −Z, 문 뒤쪽 +Z, 문 위)
	var door_min := DOOR_Z - DOOR_WIDTH / 2.0
	var door_max := DOOR_Z + DOOR_WIDTH / 2.0
	var color := Color(0.8, 0.72, 0.6)
	_box("WallRight_A", Vector3(WALL_X, WALL_HEIGHT / 2.0, (-ROOM_HALF_Z + door_min) / 2.0), Vector3(0.2, WALL_HEIGHT, door_min + ROOM_HALF_Z), color)
	_box("WallRight_B", Vector3(WALL_X, WALL_HEIGHT / 2.0, (door_max + ROOM_HALF_Z) / 2.0), Vector3(0.2, WALL_HEIGHT, ROOM_HALF_Z - door_max), color)
	_box("WallRight_Top", Vector3(WALL_X, (DOOR_HEIGHT + WALL_HEIGHT) / 2.0, DOOR_Z), Vector3(0.2, WALL_HEIGHT - DOOR_HEIGHT, DOOR_WIDTH), color)
	# 바깥 벽 그림: shop_front.glb (바깥쪽 −Z 를 +X 로, 문 구멍이 +Z 쪽 2.6 m 에 오게) 또는 임시 차양·창문·간판
	var front := model("shop_front")
	if front != null:
		front.name = "ShopFront"
		front.position = Vector3(WALL_X + 0.11, 0, 0)
		front.rotation.y = -PI / 2.0
		add_child(front)
	else:
		_box("Awning", Vector3(WALL_X + 0.6, 2.7, 0), Vector3(1.0, 0.12, 2.0 * ROOM_HALF_Z), Color(1.0, 0.72, 0.78), false)
		for z in [-2.0, -0.2]:
			_box("Window", Vector3(WALL_X + 0.11, 1.5, z), Vector3(0.02, 0.9, 1.2), Color(0.7, 0.88, 1.0), false)
	var sign := model("sign_outside")
	if sign == null:
		sign = _mesh_box(Vector3(0.1, 0.6, 2.0), Color(1.0, 0.95, 0.8))
	sign.name = "SignOutside"
	sign.position = Vector3(WALL_X + 0.16, 2.35, DOOR_Z)
	if used_models.has("sign_outside"):
		sign.rotation.y = -PI / 2.0
	add_child(sign)


func _build_door() -> void:
	# 경첩 = 문 구멍의 −Z 쪽 끝, 바깥쪽으로 열림
	door_pivot = Node3D.new()
	door_pivot.name = "DoorPivot"
	door_pivot.position = Vector3(WALL_X, 0, DOOR_Z - DOOR_WIDTH / 2.0)
	add_child(door_pivot)
	var leaf := _mesh_box(Vector3(0.06, DOOR_HEIGHT - 0.05, DOOR_WIDTH - 0.04), Color(0.55, 0.38, 0.25))
	leaf.name = "Door"
	leaf.position = Vector3(0, DOOR_HEIGHT / 2.0, DOOR_WIDTH / 2.0)
	door_pivot.add_child(leaf)


func _build_yard() -> void:
	var yard_len := YARD_END_X - WALL_X
	_floor("Paving", "paving", Vector3((WALL_X + YARD_END_X) / 2.0, -0.1, 0), Vector3(yard_len + 0.4, 0.2, 2.0 * ROOM_HALF_Z), Color(0.66, 0.6, 0.56))
	_floor("Road", "road", Vector3(ROAD_X + 0.6, -0.12, 0), Vector3(3.6, 0.2, 2.0 * ROOM_HALF_Z + 6.0), Color(0.42, 0.44, 0.48))
	# 마당 둘레: 앞뒤(z) 낮은 벽 모양 울타리, 끝(x)은 울타리 + 화단 (손님 길 자리에 틈), 너머로는 못 나감
	var gap_min := DOOR_Z - FENCE_GAP_WIDTH / 2.0
	var gap_max := DOOR_Z + FENCE_GAP_WIDTH / 2.0
	_fence_run(Vector3(YARD_END_X, 0, -ROOM_HALF_Z), Vector3(YARD_END_X, 0, gap_min), Vector3.FORWARD)
	_fence_run(Vector3(YARD_END_X, 0, gap_max), Vector3(YARD_END_X, 0, ROOM_HALF_Z), Vector3.FORWARD)
	_fence_run(Vector3(WALL_X + 0.1, 0, -ROOM_HALF_Z), Vector3(YARD_END_X, 0, -ROOM_HALF_Z), Vector3.RIGHT)
	_fence_run(Vector3(WALL_X + 0.1, 0, ROOM_HALF_Z), Vector3(YARD_END_X, 0, ROOM_HALF_Z), Vector3.RIGHT)
	# 보이지 않는 막이: 울타리 틈으로도 찻길에 못 나감
	_box("YardEnd", Vector3(YARD_END_X + 0.15, 1.0, 0), Vector3(0.1, 2.0, 2.0 * ROOM_HALF_Z), Color(0, 0, 0, 0), false, false)
	_box("YardBack", Vector3((WALL_X + YARD_END_X) / 2.0, 1.0, -ROOM_HALF_Z - 0.05), Vector3(yard_len, 2.0, 0.1), Color(0, 0, 0, 0), false, false)
	_box("YardFront", Vector3((WALL_X + YARD_END_X) / 2.0, 1.0, ROOM_HALF_Z + 0.05), Vector3(yard_len, 2.0, 0.1), Color(0, 0, 0, 0), false, false)
	# 화단: 끝 울타리 안쪽 (틈 자리 빼고)
	for z in [-2.4, -0.6, 1.0]:
		if absf(z - DOOR_Z) < FENCE_GAP_WIDTH:
			continue
		var bed := model("flower_bed")
		if bed == null:
			bed = _mesh_box(Vector3(0.6, 0.4, 1.4), Color(0.62, 0.85, 0.55))
			bed.position.y = 0.2
			var holder := Node3D.new()
			holder.add_child(bed)
			bed = holder
		else:
			bed.rotation.y = PI / 2.0
		bed.name = "FlowerBed"
		bed.position = Vector3(YARD_END_X - 0.45, 0, z)
		add_child(bed)
	# 택배 매트·우편함·가로등
	var mat := model("delivery_mat")
	if mat == null:
		mat = _mesh_box(Vector3(1.0, 0.02, 1.6), Color(0.62, 0.45, 0.35))
		mat.position = MAT_POS + Vector3(0, 0.01, 0)
	else:
		mat.position = MAT_POS
		mat.rotation.y = PI / 2.0
	mat.name = "DeliveryMat"
	add_child(mat)
	var mailbox := model("mailbox")
	if mailbox == null:
		mailbox = Node3D.new()
		var post := _mesh_box(Vector3(0.1, 0.9, 0.1), Color(0.95, 0.95, 0.95))
		post.position.y = 0.45
		mailbox.add_child(post)
		var box := _mesh_box(Vector3(0.3, 0.3, 0.45), Color(0.55, 0.75, 1.0))
		box.position.y = 1.05
		mailbox.add_child(box)
		var flag := Node3D.new()
		flag.name = "Flag"
		flag.position = Vector3(0.17, 1.05, 0.1)
		var cloth := _mesh_box(Vector3(0.02, 0.25, 0.04), Color(1.0, 0.45, 0.5))
		cloth.position.y = 0.12
		flag.add_child(cloth)
		mailbox.add_child(flag)
	mailbox.name = "Mailbox"
	mailbox.position = MAILBOX_POS
	add_child(mailbox)
	mailbox_flag = mailbox.find_child("Flag", true, false) as Node3D
	set_mailbox_flag(false)
	var lamp := model("street_lamp")
	if lamp == null:
		lamp = Node3D.new()
		var pole := _mesh_box(Vector3(0.12, 3.0, 0.12), Color(0.45, 0.5, 0.6))
		pole.position.y = 1.5
		lamp.add_child(pole)
		var head := _mesh_box(Vector3(0.35, 0.25, 0.35), Color(1.0, 0.95, 0.7))
		head.position.y = 3.0
		lamp.add_child(head)
	lamp.name = "StreetLamp"
	lamp.position = LAMP_POS
	add_child(lamp)
	var light := OmniLight3D.new()
	light.name = "LampLight"
	light.position = LAMP_POS + Vector3(0, 2.8, 0)
	light.omni_range = 4.0
	light.light_energy = 0.3
	add_child(light)
	# 바깥 해 (방 안 조명과 따로, 마당이 어둡지 않게)
	var sky := OmniLight3D.new()
	sky.name = "YardLight"
	sky.position = Vector3((WALL_X + YARD_END_X) / 2.0, 3.5, 0)
	sky.omni_range = 7.0
	sky.light_energy = 0.15
	add_child(sky)


## 우편함 깃발 (택배가 오면 올라감)
func set_mailbox_flag(up: bool) -> void:
	if mailbox_flag != null:
		mailbox_flag.rotation.x = 0.0 if up else -PI / 2.0


func _build_sign() -> void:
	sign_body = StaticBody3D.new()
	sign_body.name = "OpenSign"
	sign_body.collision_layer = 1 << (PICK_LAYER - 1)
	sign_body.collision_mask = 0
	sign_body.set_meta("sign", true)
	sign_body.position = SIGN_POS
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.12, 0.35, 0.45)
	shape.shape = box
	sign_body.add_child(shape)
	add_child(sign_body)
	var art := model("open_sign")
	if art != null:
		# 정면 −Z 를 방 안쪽(−X)으로
		art.rotation.y = PI / 2.0
		sign_body.add_child(art)
		sign_plate = art.find_child("Plate", true, false) as Node3D
	if sign_plate == null:
		# 임시: 끈 + 판 (앞 = 해 노랑, 뒤 = 달 파랑). 판 원점은 걸이 아래
		sign_plate = Node3D.new()
		sign_plate.name = "Plate"
		sign_body.add_child(sign_plate)
		var board := _mesh_box(Vector3(0.03, 0.25, 0.35), Color(1.0, 0.97, 0.9))
		board.position.y = -0.05
		sign_plate.add_child(board)
		var moon := _mesh_disc(0.08, Color(0.55, 0.65, 1.0))
		moon.name = "Moon"
		moon.position = Vector3(-0.02, -0.05, 0)
		sign_plate.add_child(moon)
		var sun := _mesh_disc(0.08, Color(1.0, 0.8, 0.25))
		sun.name = "Sun"
		sun.position = Vector3(0.02, -0.05, 0)
		sign_plate.add_child(sun)
	set_sign(false, true)


## 울타리 한 줄 (fence.glb 는 길이 2 m 한 칸, 이어서 놓음)
func _fence_run(from: Vector3, to: Vector3, axis: Vector3) -> void:
	var length := from.distance_to(to)
	var count := maxi(1, ceili(length / 2.0 - 0.05))
	var step := length / count
	var dir := (to - from).normalized()
	for i in count:
		var center := from + dir * step * (i + 0.5)
		var piece := model("fence")
		if piece == null:
			var size := Vector3(step, 0.8, 0.08) if axis == Vector3.RIGHT else Vector3(0.08, 0.8, step)
			piece = _mesh_box(size, Color(0.92, 0.82, 0.66))
			piece.position.y = 0.4
			var holder := Node3D.new()
			holder.add_child(piece)
			piece = holder
		elif axis == Vector3.FORWARD:
			piece.rotation.y = PI / 2.0
		piece.name = "Fence"
		piece.position = center
		add_child(piece)
		var size := Vector3(step, 0.8, 0.1) if axis == Vector3.RIGHT else Vector3(0.1, 0.8, step)
		_box("FenceBlock", center + Vector3(0, 0.4, 0), size, Color(0, 0, 0, 0), false, false)


## 반복 바닥: 텍스처가 있으면 1 m 마다 한 장, 없으면 단색
func _floor(node_name: String, texture_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	_box(node_name, pos, size, color)
	var view := get_node(node_name).get_child(1) as MeshInstance3D
	var path := TEXTURE_DIR % texture_name
	if ResourceLoader.exists(path):
		var material := view.material_override as StandardMaterial3D
		material.albedo_color = Color.WHITE
		material.albedo_texture = load(path)
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE
		used_models.append(texture_name)


func _box(box_name: String, pos: Vector3, size: Vector3, color: Color, solid := true, visible_mesh := true) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	if solid or not visible_mesh:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
	else:
		# 보기만 (충돌 없음) 이어도 _floor 가 child(1) 을 찾으니 자리만 채움
		body.add_child(Node3D.new())
	if visible_mesh:
		var view := _mesh_box(size, color)
		body.add_child(view)
	add_child(body)


func _mesh_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var view := MeshInstance3D.new()
	view.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	view.material_override = material
	return view


## 팻말 그림용 납작한 원 (X 축을 향함)
func _mesh_disc(radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.01
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.rotation.z = PI / 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	view.material_override = material
	return view
