extends Node3D
## 목욕대 회전판 위의 강아지 한 마리 (보이는 것 담당).
##
## 칠하기 마스크(PaintMask), 털 셰이더, 몸에 붙는 거품 공, 뽀송 부풀기, 물방울을 맡는다.
## 규칙(단계·기분·돈)은 WashStation 이 정하고, 이 노드는 시키는 대로 그린다.
## 모형은 model_scene 한 곳에서 바꾼다 (scenes/art/sim/dog_model.tscn 약속 참고).
## 좌표: "모형 기준" = 모형 노드 기준 좌표 (회전판이 돌고 털이 부풀어도 몸에 붙어 있음).

const PaintMask := preload("res://scripts/sim/paint_mask.gd")
const FUR_SHADER := preload("res://scripts/sim/sim_fur.gdshader")
const HIT_LAYER := 16
## 마스크 채널 → 셰이더 마스크 색 성분 (towel 은 텍스처에 없음)
const GLOBAL_COMPONENT := {"wet": 0, "scrub": 1, "rinse": 2, "dry": 3}
## tool_dryer_fluff_scale(털 크기 배수) 중 모형 크기로 보여 주는 몫. 2배를 다 키우면 화면을 덮는다.
const FLUFF_VISUAL_SHARE := 0.3
const FOAM_WHITE := Color(1, 1, 1)
const FOAM_PINK := Color(1, 0.62, 0.78)
## 샴푸 없이 물로만: 투명한 물방울 거품
const FOAM_WATER := Color(0.75, 0.88, 1.0)

@export var model_scene: PackedScene = preload("res://scenes/art/sim/dog_model.tscn")

## 샤워기 물방울: 날아가는 시간 (초), 중력, 노즐 구멍 수·반지름 (m), 퍼짐 (도) — 개발 보정값
const STREAM_FLIGHT := 0.22
const STREAM_GRAVITY := Vector3(0, -6.0, 0)
const STREAM_HOLES := 7
const STREAM_HOLE_RADIUS := 0.012
const STREAM_SPREAD := 2.5

var mask: PaintMask
var model: Node3D
var material: ShaderMaterial
## 털 재질 전부 (모형 메시마다 albedo 텍스처가 다르면 여러 개). 값은 모두에 같이 넣는다.
var materials: Array[ShaderMaterial] = []
## 0 = 젖음/보통, 1 = 다 말라 뽀송
var fluff := 0.0
var foam_color := FOAM_WHITE
## 거품이 스스로 빛나는 정도 (0 = 보통 재질). V4 는 남은 거품이 눈에 확 띄게 조금 켠다
var foam_glow := 0.0

## 거품 공: 모형 기준 위치와 크기 (0 이 되면 사라짐)
var _foam_pos := PackedVector3Array()
var _foam_size := PackedFloat32Array()
var _foam_mesh: MultiMeshInstance3D
var _foam_material: StandardMaterial3D
## 물방울 (헹군 뒤): 모형 기준 위치와 몸 중심에서 본 방향. 수건·드라이어로 닦은 곳부터 사라진다.
var _drop_pos := PackedVector3Array()
var _drop_dir := PackedVector3Array()
var _drop_mesh: MultiMeshInstance3D
var _drips: CPUParticles3D
var _splash: CPUParticles3D
var _spray: CPUParticles3D
var _pour: CPUParticles3D
var _press: CPUParticles3D
## 드라이어 바람에 털이 날림 (크림색 작은 털 뭉치, 위로 흩어짐)
var _fur: CPUParticles3D
## 샤워기 물줄기: 노즐 구멍 여러 개에서 물방울 입자가 포물선으로 날아가 맞는 곳에서 사라짐 (긴 막대 대신)
var _stream: CPUParticles3D
## 맞는 곳에서 털을 타고 흘러내리는 물 (젖는 자국)
var _runoff: CPUParticles3D
## 드라이기 바람: 옅은 줄무늬 입자 (막대 없음)
var _wind: CPUParticles3D
## 겨눔 표시: 맞는 곳에 작은 원 하나
var _aim: Node3D
var _glob: MeshInstance3D


func _ready() -> void:
	_drips = _make_particles(Color(0.45, 0.32, 0.18), 0.02, false)
	_splash = _make_particles(Color(0.55, 0.8, 1.0), 0.03, true)
	_spray = _make_particles(Color(0.36, 0.75, 0.92), 0.012, false)
	_spray.amount = 40
	_spray.lifetime = 0.35
	_spray.direction = Vector3.UP
	_spray.spread = 80.0
	_spray.initial_velocity_min = 0.6
	_spray.initial_velocity_max = 1.4
	_pour = _make_particles(Color(0.36, 0.75, 0.92), 0.02, true)
	_pour.amount = 60
	_pour.direction = Vector3.DOWN
	_pour.spread = 15.0
	_pour.lifetime = 0.7
	_press = _make_particles(Color(0.36, 0.75, 0.92), 0.012, true)
	_press.amount = 10
	_press.direction = Vector3.DOWN
	_press.initial_velocity_min = 0.2
	_press.initial_velocity_max = 0.6
	_fur = _make_particles(Color(0.98, 0.92, 0.8), 0.008, false)
	_fur.amount = 30
	_fur.lifetime = 0.9
	_fur.direction = Vector3.UP
	_fur.spread = 60.0
	_fur.initial_velocity_min = 0.3
	_fur.initial_velocity_max = 0.9
	_fur.gravity = Vector3(0, -0.6, 0)
	_stream = _make_stream()
	_runoff = _make_particles(Color(0.42, 0.72, 0.95), 0.007, false)
	_runoff.amount = 20
	_runoff.lifetime = 0.5
	_runoff.direction = Vector3.DOWN
	_runoff.spread = 25.0
	_runoff.initial_velocity_min = 0.05
	_runoff.initial_velocity_max = 0.25
	_runoff.gravity = Vector3(0, -2.0, 0)
	_runoff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_runoff.emission_sphere_radius = 0.03
	_wind = _make_wind()
	_aim = _make_aim()
	# 짜는 중인 샴푸 덩이
	_glob = MeshInstance3D.new()
	var blob := SphereMesh.new()
	blob.radius = 0.5
	blob.height = 1.0
	_glob.mesh = blob
	var glob_material := StandardMaterial3D.new()
	glob_material.albedo_color = Color(1, 1, 1)
	glob_material.roughness = 0.3
	_glob.material_override = glob_material
	_glob.visible = false
	add_child(_glob)


## 새 손님. pattern = 진흙 무늬 종류, seed 는 무늬 위치 (모든 피어에서 같은 모양이 나옴).
func setup(resolution: int, pattern: int, seed_value: int) -> void:
	if model != null:
		model.queue_free()
	model = model_scene.instantiate()
	add_child(model)
	mask = PaintMask.new(resolution)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	mask.set_mud_pattern(mask.make_mud_pattern(pattern, rng))
	material = ShaderMaterial.new()
	material.shader = FUR_SHADER
	material.set_shader_parameter("mask", mask.texture)
	material.set_shader_parameter("mud", mask.mud_texture)
	material.set_shader_parameter("center", _body_center())
	material.set_shader_parameter("wet_amount", Tuning.data.wet_shader_amount)
	materials = [material]
	if model.has_method("apply_fur_material"):
		materials = model.apply_fur_material(material)
	fluff = 0.0
	foam_color = FOAM_WHITE
	_foam_pos.clear()
	_foam_size.clear()
	_foam_mesh = MultiMeshInstance3D.new()
	_foam_mesh.multimesh = MultiMesh.new()
	_foam_mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_foam_mesh.multimesh.use_colors = true
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 8
	ball.rings = 4
	var foam_material := StandardMaterial3D.new()
	foam_material.vertex_color_use_as_albedo = true
	foam_material.roughness = 0.4
	_foam_material = foam_material
	set_foam_glow(foam_glow)
	ball.material = foam_material
	_foam_mesh.multimesh.mesh = ball
	model.add_child(_foam_mesh)
	_update_foam_mesh()
	_drop_pos.clear()
	_drop_dir.clear()
	_drop_mesh = MultiMeshInstance3D.new()
	_drop_mesh.multimesh = MultiMesh.new()
	_drop_mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var drop := SphereMesh.new()
	drop.radius = 0.016
	drop.height = 0.04
	drop.radial_segments = 6
	drop.rings = 3
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.36, 0.75, 0.92)
	water.roughness = 0.1
	water.metallic_specular = 0.9
	drop.material = water
	_drop_mesh.multimesh.mesh = drop
	model.add_child(_drop_mesh)


## 화면 좌표 → 몸에 닿은 곳 (월드 좌표). 안 닿으면 null.
func ray_hit(camera: Camera3D, screen_pos: Vector2) -> Variant:
	if model == null or camera == null:
		return null
	var from := camera.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen_pos) * 10.0, HIT_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else null


func to_model(world_point: Vector3) -> Vector3:
	return model.global_transform.affine_inverse() * world_point


## 몸 중심에서 본 방향 (마스크 좌표의 기준)
func dir_of(world_point: Vector3) -> Vector3:
	return to_model(world_point) - _body_center()


## 붓 반경(m) → 마스크 붓 각도. 몸 중심에서 먼 곳일수록 작은 각도.
func brush_angle(radius: float, world_point: Vector3) -> float:
	return clampf(radius / maxf(dir_of(world_point).length(), 0.05), 0.02, 1.2)


func paint(channel: String, world_point: Vector3, radius: float, amount: float) -> float:
	return mask.paint(channel, dir_of(world_point), brush_angle(radius, world_point), amount)


func is_face(world_point: Vector3) -> bool:
	var center: Vector3 = model.get("face_center") if model.get("face_center") != null else Vector3(0, 0.5, 0.5)
	var radius: float = model.get("face_radius") if model.get("face_radius") != null else 0.12
	return to_model(world_point).distance_to(center) <= radius


func react(method: String, arg: Variant = null) -> void:
	if model != null and model.has_method(method):
		if arg == null:
			model.call(method)
		else:
			model.call(method, arg)


## 거품 공을 붙인다 (모형 기준 위치 근처, 몸 바깥쪽으로 조금 띄움).
func add_foam(world_point: Vector3, count: int, rng: RandomNumberGenerator, size_scale: float = 1.0) -> void:
	var local := to_model(world_point)
	var outward := (local - _body_center()).normalized()
	for i in count:
		if _foam_pos.size() >= Tuning.data.foam_ball_max:
			# 꽉 차면 가장 오래된 것을 옮겨 온다 (어디를 문질렀는지 보이게)
			_foam_pos.remove_at(0)
			_foam_size.remove_at(0)
		var jitter := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.05
		_foam_pos.append(local + outward * 0.02 + jitter)
		_foam_size.append(rng.randf_range(0.018, 0.03) * size_scale)
	_update_foam_mesh()


## 물줄기 근처 거품을 줄인다. 다 없어진 공 수를 돌려준다.
func rinse_foam(world_point: Vector3, radius: float, amount: float) -> int:
	var local := to_model(world_point)
	var removed := 0
	for i in range(_foam_pos.size() - 1, -1, -1):
		if _foam_pos[i].distance_to(local) <= radius * 1.5:
			_foam_size[i] -= amount * 0.03
			if _foam_size[i] <= 0.005:
				_foam_pos.remove_at(i)
				_foam_size.remove_at(i)
				removed += 1
	_update_foam_mesh()
	return removed


## 몸 겉면에 물방울을 뿌린다 (모든 피어에서 같은 시드로 같은 자리). 배 밑에는 안 붙인다.
func scatter_drops(count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_drop_pos.clear()
	_drop_dir.clear()
	var center := _body_center()
	var space := get_world_3d().direct_space_state
	for i in count * 3:
		if _drop_pos.size() >= count:
			break
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
		var query := PhysicsRayQueryParameters3D.create(model.to_global(center + dir * 1.5), model.to_global(center), HIT_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var local := to_model(hit.position)
		_drop_pos.append(local + (local - center).normalized() * 0.008)
		_drop_dir.append(local - center)
	show_drops_where(func(_dir: Vector3) -> bool: return true)


func drop_total() -> int:
	return _drop_pos.size()


func visible_drops() -> int:
	return _drop_mesh.multimesh.visible_instance_count if _drop_mesh != null else 0


## 작업자 화면: 조건(방향 → 보임)에 맞는 물방울만 보인다.
func show_drops_where(visible: Callable) -> void:
	if _drop_mesh == null:
		return
	var multimesh := _drop_mesh.multimesh
	var shown := 0
	multimesh.instance_count = _drop_pos.size()
	for i in _drop_pos.size():
		if visible.call(_drop_dir[i]):
			multimesh.set_instance_transform(shown, Transform3D(Basis(), _drop_pos[i]))
			shown += 1
	multimesh.visible_instance_count = shown


## 구경하는 화면: 앞에서부터 n 개만 보인다.
func show_drop_count(count: int) -> void:
	var left := [count]
	show_drops_where(func(_dir: Vector3) -> bool:
		left[0] -= 1
		return left[0] >= 0)


func foam_count() -> int:
	return _foam_pos.size()


## 거품 발광 세기 (0 = 끔). 반짝이게 하려면 매 프레임 바꿔 부른다
func set_foam_glow(energy: float) -> void:
	if _foam_material == null:
		return
	_foam_material.emission_enabled = energy > 0.0
	_foam_material.emission = Color(1, 1, 1)
	_foam_material.emission_energy_multiplier = energy


## 남은 거품 공들의 월드 위치
func foam_world_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for local in _foam_pos:
		out.append(model.to_global(local))
	return out


func clear_foam() -> void:
	_foam_pos.clear()
	_foam_size.clear()
	_update_foam_mesh()


func set_foam_color(color: Color) -> void:
	foam_color = color
	_update_foam_mesh()


## 샤워기 물줄기를 from(노즐) → to(맞는 곳) 로 보인다 (색 = 물 온도). width = 도구 단계 굵기 배수 (넓은 물줄기),
## rainbow = 마지막 단계: 방울마다 무지개 색
## 물방울은 중력을 받아 포물선으로 날아가 STREAM_FLIGHT 초 뒤 맞는 곳에 닿음 (거기서 사라지고 물보라·흘러내림)
func show_stream(from: Vector3, to: Vector3, color: Color, width := 1.0, rainbow := false) -> void:
	if from.distance_to(to) < 0.01:
		return
	var velocity := stream_velocity(from, to)
	_stream.global_position = from
	_stream.direction = velocity.normalized()
	_stream.initial_velocity_min = velocity.length() * 0.97
	_stream.initial_velocity_max = velocity.length() * 1.03
	_stream.emission_points = _nozzle_holes(velocity.normalized(), STREAM_HOLE_RADIUS * width)
	_stream.spread = STREAM_SPREAD * width
	_stream.color = Color(color, 0.7)
	_stream.hue_variation_min = -0.5 if rainbow else 0.0
	_stream.hue_variation_max = 0.5 if rainbow else 0.0
	_stream.emitting = true
	_runoff.global_position = to
	_runoff.emitting = true
	_show_aim(to, from)


## 드라이기 바람: from → to 로 옅은 줄무늬가 흘러감. strength 0~1 (가까울수록 진하고 빠름)
func show_wind(from: Vector3, to: Vector3, strength: float) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var speed := lerpf(1.6, 3.0, strength)
	_wind.global_position = from
	_wind.direction = (to - from) / length
	_wind.initial_velocity_min = speed * 0.9
	_wind.initial_velocity_max = speed * 1.1
	_wind.lifetime = length / speed
	_wind.color = Color(0.8, 0.9, 1.0, lerpf(0.2, 0.4, strength))
	_wind.emitting = true
	_show_aim(to, from)


func hide_stream() -> void:
	for particles in [_stream, _runoff, _wind]:
		if particles != null:
			(particles as CPUParticles3D).emitting = false
	if _aim != null:
		_aim.visible = false


## 물방울 첫 속도: STREAM_FLIGHT 초 뒤 중력을 받으며 to 에 닿게 (포물선)
static func stream_velocity(from: Vector3, to: Vector3) -> Vector3:
	return (to - from) / STREAM_FLIGHT - 0.5 * STREAM_GRAVITY * STREAM_FLIGHT


## 노즐 구멍 (물줄기 방향에 수직인 작은 원 위 여러 점) → 여러 가닥
func _nozzle_holes(forward: Vector3, radius: float) -> PackedVector3Array:
	var side := forward.cross(Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(forward).normalized()
	var holes := PackedVector3Array([Vector3.ZERO])
	for i in STREAM_HOLES - 1:
		var angle := TAU * i / float(STREAM_HOLES - 1)
		holes.append((side * cos(angle) + up * sin(angle)) * radius)
	return holes


func _show_aim(at: Vector3, toward: Vector3) -> void:
	_aim.visible = true
	_aim.global_position = at
	if not at.is_equal_approx(toward):
		var look := (toward - at).normalized()
		_aim.look_at(toward, Vector3.UP if absf(look.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD)
		_aim.global_position = at + look * 0.01


func _make_stream() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "ShowerStream"
	# 강아지·회전판이 돌아도 물줄기 방향은 세상 기준
	particles.top_level = true
	particles.emitting = false
	particles.local_coords = false
	particles.amount = 140
	particles.lifetime = STREAM_FLIGHT
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	particles.gravity = STREAM_GRAVITY
	particles.particle_flag_align_y = true
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.2
	var drop := CapsuleMesh.new()
	drop.radius = 0.0045
	drop.height = 0.028
	drop.radial_segments = 6
	drop.rings = 1
	var water := StandardMaterial3D.new()
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.vertex_color_use_as_albedo = true
	water.albedo_color = Color(1, 1, 1, 1)
	water.emission_enabled = true
	water.emission = Color(0.25, 0.5, 0.75)
	water.emission_energy_multiplier = 0.35
	water.roughness = 0.1
	drop.material = water
	particles.mesh = drop
	add_child(particles)
	return particles


func _make_wind() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "DryerWind"
	particles.top_level = true
	particles.emitting = false
	particles.local_coords = false
	particles.amount = 40
	particles.lifetime = 0.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.03
	particles.spread = 9.0
	particles.gravity = Vector3.ZERO
	particles.particle_flag_align_y = true
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.3
	var streak := CapsuleMesh.new()
	streak.radius = 0.0035
	streak.height = 0.12
	streak.radial_segments = 4
	streak.rings = 1
	var air := StandardMaterial3D.new()
	air.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	air.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	air.vertex_color_use_as_albedo = true
	streak.material = air
	particles.mesh = streak
	add_child(particles)
	return particles


func _make_aim() -> Node3D:
	var root := Node3D.new()
	root.name = "AimRing"
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.018
	torus.outer_radius = 0.024
	torus.rings = 16
	torus.ring_segments = 4
	ring.mesh = torus
	# 고리 면이 노즐 쪽(−Z)을 보게
	ring.rotation.x = PI / 2.0
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 1, 1, 0.55)
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	root.visible = false
	add_child(root)
	return root


## 짜는 중인 샴푸 덩이 (amount = 0~1, 클수록 큼)
func show_glob(world_point: Vector3, amount: float) -> void:
	_glob.visible = true
	_glob.global_position = world_point + Vector3(0, 0.03 + amount * 0.04, 0)
	_glob.scale = Vector3.ONE * (0.02 + amount * 0.09)
	(_glob.material_override as StandardMaterial3D).albedo_color = foam_color


func hide_glob() -> void:
	if _glob != null:
		_glob.visible = false


## 너무 많이 짜서 거품이 흘러내림 (아래로 거품 줄)
func overflow_foam(world_point: Vector3, rng: RandomNumberGenerator) -> void:
	for i in 6:
		add_foam(world_point - Vector3(0, i * 0.04, 0), 2, rng, 1.3)


## 바가지 물이 쏟아짐 (띠 위 여러 곳)
func pour_effect(points: Array[Vector3]) -> void:
	if points.is_empty():
		return
	var top := points[0]
	for p in points:
		if p.y > top.y:
			top = p
	_pour.global_position = top + Vector3(0, 0.15, 0)
	_pour.restart()
	_pour.emitting = true


## 수건으로 꾹 눌러 물이 짜임
func press_effect(world_point: Vector3) -> void:
	_press.global_position = world_point
	_press.restart()
	_press.emitting = true


## 진흙 물이 흘러내림 (적시는 곳에 진흙이 있을 때)
func drip(world_point: Vector3) -> void:
	_drips.global_position = world_point
	_drips.emitting = true


func stop_drip() -> void:
	_drips.emitting = false


## 샤워기 물이 몸에 맞아 튀는 물보라
func spray(world_point: Vector3) -> void:
	_spray.global_position = world_point
	_spray.emitting = true


func stop_spray() -> void:
	if _spray != null:
		_spray.emitting = false
	if _fur != null:
		_fur.emitting = false


## 드라이어: 바람이 닿는 곳에서 털이 날림 (closeness 0~1, 가까울수록 많이)
func blow_fur(world_point: Vector3, closeness: float) -> void:
	_fur.global_position = world_point
	_fur.speed_scale = 0.6 + closeness * 0.8
	_fur.emitting = true


## 차가운 물에 펄쩍: 물이 튄다
func splash() -> void:
	_splash.global_position = model.global_position + Vector3(0, 0.4, 0)
	_splash.restart()
	_splash.emitting = true


## 다른 사람 화면: 마스크 대신 진행 비율 (채널 → 0~1) 만으로 그린다.
func show_ratios(ratios: Dictionary) -> void:
	var value := Vector4.ZERO
	for channel in ratios:
		if GLOBAL_COMPONENT.has(channel):
			value[GLOBAL_COMPONENT[channel]] = ratios[channel]
	_set_param("use_global", true)
	_set_param("global_mask", value)


func show_mask() -> void:
	_set_param("use_global", false)


## 남은 곳 반짝임 (0~1). channel 이 텍스처에 없으면 (수건) 반짝이지 않음.
func set_blink(value: float, channel: String) -> void:
	_set_param("blink", value if GLOBAL_COMPONENT.has(channel) else 0.0)
	_set_param("blink_channel", GLOBAL_COMPONENT.get(channel, 0))


func _process(_delta: float) -> void:
	if model == null:
		return
	var grow: float = (Tuning.data.tool_dryer_fluff_scale - 1.0) * FLUFF_VISUAL_SHARE * Tuning.data.fluff_shader_amount
	model.scale = Vector3.ONE * (1.0 + grow * fluff)
	mask.flush()


func _set_param(param: String, value: Variant) -> void:
	for fur in materials:
		fur.set_shader_parameter(param, value)


func _body_center() -> Vector3:
	var center: Variant = model.get("body_center") if model != null else null
	return center if center != null else Vector3(0, 0.3, 0)


func _update_foam_mesh() -> void:
	if _foam_mesh == null:
		return
	var multimesh := _foam_mesh.multimesh
	multimesh.instance_count = _foam_pos.size()
	for i in _foam_pos.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * _foam_size[i] * 2.0), _foam_pos[i]))
		multimesh.set_instance_color(i, foam_color)


func _make_particles(color: Color, size: float, one_shot: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = one_shot
	particles.amount = 24 if one_shot else 16
	particles.lifetime = 0.6
	particles.explosiveness = 0.9 if one_shot else 0.0
	particles.direction = Vector3.UP if one_shot else Vector3.DOWN
	particles.spread = 70.0 if one_shot else 15.0
	particles.initial_velocity_min = 1.0 if one_shot else 0.2
	particles.initial_velocity_max = 2.0 if one_shot else 0.5
	particles.gravity = Vector3(0, -6, 0)
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var droplet := StandardMaterial3D.new()
	droplet.albedo_color = color
	mesh.material = droplet
	particles.mesh = mesh
	add_child(particles)
	return particles
