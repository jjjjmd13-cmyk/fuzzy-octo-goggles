extends "res://tests/qa_test.gd"
## V4 샤워기 물줄기·드라이기 바람 (대표 요청 2026-11-11 '긴 봉 고치기'):
## 샤워기 = 여러 가닥 물방울 입자가 포물선으로 날아가 맞는 곳에 닿음 + 튀는 물보라 + 흘러내림 (긴 막대 없음).
## 드라이기 = 막대 없이 옅은 바람 줄무늬 + 털 날림·흔들림. 5단계 차이 (넓은 물줄기·무지개) 유지. 겨눔 표시 = 닿는 곳 작은 원.

const SCENE := preload("res://scenes/v4/fp_shop.tscn")
const WashDog := preload("res://scripts/sim/wash_dog.gd")
const STEP := 1.0 / 30.0

var shop: Node3D
var spot: Vector3


func run_test() -> void:
	time_limit_sec = 60.0
	get_tree().root.size = Vector2i(1280, 800)
	shop = SCENE.instantiate()
	shop.input_enabled = false
	add_child(shop)
	shop.guests._opening.clear()
	shop.guests._spawn_left = 1e9
	shop.player.set_physics_process(false)
	for i in 3:
		await get_tree().physics_frame
	shop.guests.spawn("forever")
	shop.next_guest()
	shop.drop()
	spot = shop.dog.model.to_global(shop.dog._body_center() + Vector3(0.0, 0.1, 0.25))
	var eye := spot + Vector3(0, 0, 1.0)
	shop.player.global_position = Vector3(eye.x, eye.y - shop.player.EYE_HEIGHT, eye.z)
	await get_tree().physics_frame
	var dog: WashDog = shop.dog

	# 긴 막대(원기둥) 는 어디에도 없음
	for mesh in dog.find_children("*", "MeshInstance3D", true, false):
		check(not ((mesh as MeshInstance3D).mesh is CylinderMesh), "긴 물줄기 막대 없음: %s" % mesh.name)

	# 샤워기: 여러 가닥 물방울
	shop.pick("shower")
	shop._track_hand(null)
	for i in 5:
		shop.use_tool_at(spot, STEP)
	var stream: CPUParticles3D = dog._stream
	check(stream.emitting, "샤워기를 쓰면 물방울 입자가 나옴")
	check(stream.mesh is CapsuleMesh and (stream.mesh as CapsuleMesh).height < 0.05, "물방울 하나는 작은 방울 (막대 아님)")
	check_eq(stream.emission_points.size(), WashDog.STREAM_HOLES, "노즐 구멍 여러 개 = 여러 가닥")
	check(stream.particle_flag_align_y, "방울이 날아가는 방향으로 늘어짐")
	# 포물선: 노즐에서 나간 방울이 STREAM_FLIGHT 초 뒤 겨눈 곳에 닿음 (중력으로 휘어짐)
	var from: Vector3 = shop._tool_tip()
	var velocity := WashDog.stream_velocity(from, spot)
	var t := WashDog.STREAM_FLIGHT
	var landed := from + velocity * t + 0.5 * WashDog.STREAM_GRAVITY * t * t
	check(landed.distance_to(spot) < 0.005, "방울이 겨눈 곳에 떨어짐 (%.3f m)" % landed.distance_to(spot))
	var mid := from + velocity * t * 0.5 + 0.5 * WashDog.STREAM_GRAVITY * t * t * 0.25
	check(mid.y > from.lerp(spot, 0.5).y + 0.01, "가운데가 위로 볼록한 포물선 (%.3f m)" % (mid.y - from.lerp(spot, 0.5).y))
	check(is_equal_approx(stream.lifetime, WashDog.STREAM_FLIGHT), "닿는 곳에서 방울이 사라짐")
	check(dog._spray.emitting, "맞는 곳에 튀는 물보라")
	check(dog._runoff.emitting and dog._runoff.global_position.distance_to(spot) < 0.01, "맞는 곳에서 물이 흘러내림 (젖는 자국)")
	check(dog.mask.value_at("wet", dog.to_model(spot)) > 0.0, "맞는 곳 털이 젖음")
	check(dog._aim.visible and dog._aim.global_position.distance_to(spot) < 0.02, "겨눔 표시 = 닿는 곳 작은 원")
	var ring := (dog._aim.get_child(0) as MeshInstance3D).mesh as TorusMesh
	check(ring.outer_radius <= 0.03, "겨눔 원은 작음 (%.3f m)" % ring.outer_radius)
	check(not dog._wind.emitting, "샤워기엔 바람 줄무늬 없음")

	# 단계 차이: 마지막 단계 = 넓은 물줄기 + 무지개
	var base_spread := stream.spread
	var base_hole: float = stream.emission_points[1].length()
	var base_hue_range := stream.hue_variation_max - stream.hue_variation_min
	shop.set_tier("shower", Tuning.data.v4_tool_tiers - 1)
	shop.pick("shower")
	var colors := []
	for i in 10:
		shop.use_tool_at(spot, STEP)
		shop._t += 0.3
		colors.append(stream.color)
	check(base_hue_range == 0.0, "기본 단계는 한 색")
	check(stream.spread > base_spread and stream.emission_points[1].length() > base_hole, "마지막 단계 = 넓은 물줄기")
	check(not (colors[0] as Color).is_equal_approx(colors[5]) and stream.hue_variation_max - stream.hue_variation_min >= 0.9, "마지막 단계 = 방울마다 무지개 물")

	# 드라이기: 막대 없이 바람 줄무늬 + 털 날림·흔들림
	shop.pick("dryer")
	for i in 5:
		shop.use_tool_at(spot, STEP)
	check(not stream.emitting, "드라이기엔 물방울 없음")
	check(dog._wind.emitting, "드라이기 바람 줄무늬 입자")
	check(dog._wind.color.a <= 0.45, "바람은 옅음 (%.2f)" % dog._wind.color.a)
	check(dog._fur.emitting, "바람 닿는 곳 털이 날림")
	check(float(dog.model.get("_blow")) > 0.0, "털이 바람에 흔들림")
	check(dog._aim.visible, "드라이기도 닿는 곳 작은 원")

	# 도구를 내려놓으면 다 꺼짐
	shop._stop_effects()
	check(not stream.emitting and not dog._wind.emitting and not dog._runoff.emitting and not dog._aim.visible, "내려놓으면 물·바람·원 꺼짐")
	shop.free()
