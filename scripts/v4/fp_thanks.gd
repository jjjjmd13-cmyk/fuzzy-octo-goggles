extends Node3D
## V4 엔딩 '감사의 날' (GDD_V4 '마지막 날 — 감사의 날', TUNING_V4 6장 v4_thanks_*). 18일차 정산의 [다음 날] 대신.
##   1. 저녁: 가게 불빛이 따뜻한 주황, 창밖 노을, 팻말은 달. 플레이어는 정문 안쪽에서 문을 봄 (걷기·도구 잠금, 둘러보기만).
##   2. 문 종 → 만난 단골이 주인과 한 쌍씩 들어와 한마디 (말풍선) → 목욕대 앞에 줄지어 섬.
##      신뢰 낮은 단골 → 높은 단골, 마지막은 짱구 → 나비 → 몽실. 최대 v4_thanks_visitors_max 쌍 (대표 단골은 늘).
##      동물은 신뢰 단계 인사 (단짝 = 품에서 내려와 깡충 + 배 보여 주기).
##   3. 그때와 지금: 첫 방문 ↔ 최근 사진 v4_thanks_photo_pairs 쌍 (대표 단골 + 신뢰 높은 단골), '처음 ~한 날' 하나씩.
##   4. 단체 사진 (만난 단골 전부, 대표 단골 앞줄) → 사진첩 마지막 쪽 → 별 3개 → 고마워요 한 줄 → [계속 영업하기] / [메뉴로] (fp_ending.gd).
## 클릭하면 지금 단계를 바로 넘김. 새 그래픽 없음 (단골·주인 모형 그대로, 불빛만 코드로).

signal finished(go_on: bool)

const FpRegulars := preload("res://scripts/v4/fp_regulars.gd")
const FpAnimals := preload("res://scripts/v4/fp_animals.gd")
const FpTrust := preload("res://scripts/v4/fp_trust.gd")
const FpAlbum := preload("res://scripts/v4/fp_album.gd")
const FpEnding := preload("res://scripts/v4/fp_ending.gd")
const FpDays := preload("res://scripts/v4/fp_days.gd")
const OWNER_SCENE := preload("res://scenes/art/sim/owner_model.tscn")
const FONT := preload("res://assets/fonts/pretendard/Pretendard-Bold.otf")
## 대표 단골이 들어오는 차례 (마지막 셋)
const STAR_ORDER := ["jjanggu", "nabi", "mongsil"]
## 다른 단골 주인 공통 대사 (신뢰 단계별)
const COMMON_LINES := ["오늘도 잘 씻겨 주셔서 고마워요.", "여기 오면 우리 애가 편해 보여요.", "이제 목욕 날을 기다려요. 고마워요!", "우리 애가 제일 좋아하는 사람이에요!"]
## 자리 (방 좌표): 플레이어 (정문 안쪽), 들어오는 곳, 한마디 하는 곳, 줄 서는 곳 (목욕대 앞 두 줄)
## 플레이어는 문에서 넉넉히 떨어져 (말하는 주인의 상체와 안긴 동물이 같이 보이게, QA #138)
const PLAYER_SPOT := Vector3(0.2, 0, 2.6)
## 카메라를 조금 내려다봄 (라디안)
const LOOK_DOWN := -0.14
const OUTSIDE := Vector3(4.6, 0, 2.6)
const DOOR := Vector3(3.5, 0, 2.6)
const SPEAK_SPOT := Vector3(2.55, 0, 2.6)
const LINE_START := Vector3(-2.1, 0, -0.4)
const LINE_STEP := 0.6
const LINE_PER_ROW := 8
const WALK_SPEED := 1.6
const HELD_STANDING := Vector3(0, 0.82, 0.26)

var shop: Node3D
## 들어온 단골 id (차례대로), 사진 쌍, 단체 사진 (대표 단골 앞)
var visitors: Array = []
var photo_ids: Array = []
var group: Array = []
## 단계: evening · visitors · photos · group · done
var phase := ""
## 기다리지 않고 끝까지 (테스트·클릭 여러 번)
var fast := false
var ending: Control
var _left := 0.0
var _overlay: Control
var _lights_saved := {}


## 엔딩 시작 (가게가 트리에 붙인 뒤)
func play(target: Node3D) -> void:
	shop = target
	var album: Dictionary = shop.album
	visitors = visitor_order(album, Tuning.data.v4_thanks_visitors_max)
	photo_ids = photo_pairs(album, Tuning.data.v4_thanks_photo_pairs)
	group = group_order(shop.regulars_met_order)
	_run()


## 들어와서 한마디 하는 단골 (차례대로): 대표 단골은 늘, 나머지는 신뢰 높은 순으로 max 까지 → 신뢰 낮은 단골부터, 마지막 짱구 → 나비 → 몽실
static func visitor_order(album: Dictionary, max_count: int) -> Array:
	var stars: Array = STAR_ORDER.filter(func(id: String) -> bool: return album.has(id))
	var others: Array = album.keys().filter(func(id: String) -> bool: return not STAR_ORDER.has(id))
	others.sort_custom(func(a: String, b: String) -> bool: return _rank(album, a) > _rank(album, b))
	others = others.slice(0, maxi(max_count - stars.size(), 0))
	others.reverse()
	return others + stars


## '그때와 지금' 사진: 대표 단골 + 신뢰 높은 단골 (첫·최근 사진이 있는 단골만), count 쌍
static func photo_pairs(album: Dictionary, count: int) -> Array:
	var has_photos := func(id: String) -> bool: return not album[id].get("first", {}).is_empty() and not album[id].get("recent", {}).is_empty()
	var out: Array = STAR_ORDER.filter(func(id: String) -> bool: return album.has(id) and has_photos.call(id))
	var others: Array = album.keys().filter(func(id: String) -> bool: return not STAR_ORDER.has(id) and has_photos.call(id))
	others.sort_custom(func(a: String, b: String) -> bool: return _rank(album, a) > _rank(album, b))
	return (out + others).slice(0, count)


## 단체 사진 줄: 대표 단골이 앞줄 (몽실 · 나비 · 짱구), 나머지는 만난 순서
static func group_order(met_order: Array) -> Array:
	var front: Array = ["mongsil", "nabi", "jjanggu"].filter(func(id: String) -> bool: return met_order.has(id))
	return front + met_order.filter(func(id: String) -> bool: return not front.has(id))


## 주인 한마디: 대표 단골은 자기 대사 (그 단계 줄), 나머지는 공통 대사
static func line_of(id: String, tier: int) -> String:
	var lines: Array = FpRegulars.get_regular(id).get("lines", [])
	if lines.size() > tier:
		return lines[tier]
	return COMMON_LINES[clampi(tier, 0, 3)]


static func _rank(album: Dictionary, id: String) -> int:
	return int(album[id].get("trust", 0)) * 1000 + int(album[id].get("trust_pts", 0))


## 클릭: 지금 기다림을 바로 넘김
func skip() -> void:
	_left = 0.0


## 끝까지 바로 (테스트)
func finish_now() -> void:
	fast = true
	_left = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and phase != "group":
		skip()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)


func _wait(seconds: float) -> void:
	_left = 0.0 if fast else seconds
	await get_tree().process_frame
	while _left > 0.0 and not fast:
		await get_tree().process_frame


func _run() -> void:
	# 1. 저녁: 걷기·도구 잠금, 정문 안쪽에서 문을 봄
	phase = "evening"
	shop.input_enabled = false
	shop.player.set_physics_process(false)
	shop.player.global_position = shop.to_global(PLAYER_SPOT)
	shop.player.rotation.y = -PI / 2.0
	shop.player.camera.rotation.x = LOOK_DOWN
	shop.player.set("_pitch", LOOK_DOWN)
	shop.outside.set_sign(false)
	# 낮 안내·시계는 숨김 (끝나면 다시)
	shop._card_left = 0.0
	shop._hint_left = 0.0
	shop._banner_left = 0.0
	shop._hud.visible = false
	_evening(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_text("그날 저녁…")
	await _wait(2.0)
	_clear_overlay()
	# 2. 단골들이 고마움을 전하러 옴
	phase = "visitors"
	for i in visitors.size():
		await _visit(visitors[i], i)
	# 3. 그때와 지금
	phase = "photos"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for id in photo_ids:
		_show_pair(id)
		await _wait(Tuning.data.v4_thanks_photo_seconds)
	_clear_overlay()
	# 4. 단체 사진 → 별 → 고마워요 → [계속 영업하기] / [메뉴로]
	phase = "group"
	shop.sfx.play("press")
	ending = FpEnding.new()
	ending.name = "Ending"
	shop._hud.get_parent().add_child(ending)
	ending.play(group, FpDays.stars(shop.album, shop.tool_level), shop.sfx)
	if fast:
		ending.finish_now()
	ending.continue_requested.connect(func() -> void: _finish(true))
	ending.menu_requested.connect(func() -> void: _finish(false))


func _finish(go_on: bool) -> void:
	phase = "done"
	if is_instance_valid(ending):
		ending.queue_free()
	_clear_overlay()
	_evening(false)
	shop._hud.visible = true
	shop.player.set_physics_process(true)
	shop.input_enabled = true
	finished.emit(go_on)
	queue_free()


## 저녁 불빛 (켜기·되돌리기): 해는 낮고 주황, 하늘은 노을, 방 조명은 따뜻하게
func _evening(on: bool) -> void:
	for child in shop.get_children():
		if child is WorldEnvironment:
			var environment: Environment = (child as WorldEnvironment).environment
			if on:
				_lights_saved["bg"] = environment.background_color
				_lights_saved["ambient"] = environment.ambient_light_color
				environment.background_color = Color(0.93, 0.62, 0.5)
				environment.ambient_light_color = Color(1.0, 0.86, 0.72)
			elif _lights_saved.has("bg"):
				environment.background_color = _lights_saved.bg
				environment.ambient_light_color = _lights_saved.ambient
		elif child is DirectionalLight3D:
			var sun := child as DirectionalLight3D
			if on:
				_lights_saved["sun"] = [sun.light_color, sun.light_energy]
				sun.light_color = Color(1.0, 0.7, 0.45)
				sun.light_energy = 0.3
			elif _lights_saved.has("sun"):
				sun.light_color = _lights_saved.sun[0]
				sun.light_energy = _lights_saved.sun[1]
		elif child is OmniLight3D:
			var lamp := child as OmniLight3D
			var key := "lamp_%d" % lamp.get_instance_id()
			if on:
				_lights_saved[key] = [lamp.light_color, lamp.light_energy]
				lamp.light_color = Color(1.0, 0.85, 0.65)
				lamp.light_energy = lamp.light_energy * 1.3
			elif _lights_saved.has(key):
				lamp.light_color = _lights_saved[key][0]
				lamp.light_energy = _lights_saved[key][1]


## 한 쌍: 문 종 → 들어와 한마디 (단짝은 내려와 깡충 + 배) → 줄 서는 곳으로
func _visit(id: String, index: int) -> void:
	var regular := FpRegulars.get_regular(id)
	var tier := int(shop.album.get(id, {}).get("trust", 0))
	shop.sfx.play("bell")
	var owner := OWNER_SCENE.instantiate() as Node3D
	owner.name = "Visitor_" + id
	add_child(owner)
	owner.add_to_group("door_users")
	owner.set_variant(index % 6)
	var holder := Node3D.new()
	holder.name = "HeldDog"
	holder.scale = Vector3.ONE * 0.6
	holder.position = HELD_STANDING
	owner.add_child(holder)
	var held := FpAnimals.scene_of(regular.animal).instantiate() as Node3D
	held.set("auto_hit_shapes", false)
	holder.add_child(held)
	FpRegulars.dress(held, regular)
	owner.holding = true
	var walk := 0.05 if fast else OUTSIDE.distance_to(SPEAK_SPOT) / WALK_SPEED
	owner.global_position = to_global(OUTSIDE)
	owner.go_wait(to_global(SPEAK_SPOT), to_global(PLAYER_SPOT), walk, false, [to_global(DOOR)])
	await _wait(walk)
	# 한마디 + 신뢰 인사
	var bubble := Label3D.new()
	bubble.name = "Line"
	bubble.text = "%s · %s\n%s" % [regular.name, FpTrust.NAMES[tier], line_of(id, tier)]
	bubble.font = FONT
	bubble.font_size = 32
	bubble.outline_size = 8
	bubble.pixel_size = 0.0036
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.position.y = owner.height + 0.3
	owner.add_child(bubble)
	shop.guests._greet(held, tier)
	if tier >= 3:
		# 단짝: 품에서 내려와 나에게 깡충 → 배를 보여 줌
		holder.remove_child(held)
		add_child(held)
		held.scale = Vector3.ONE * float(regular.scale)
		held.position = SPEAK_SPOT.lerp(PLAYER_SPOT, 0.2)
		held.rotation.y = -PI / 2.0
		if not fast:
			var hop := held.create_tween()
			hop.tween_property(held, "position:y", 0.25, 0.18).set_ease(Tween.EASE_OUT)
			hop.tween_property(held, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN)
			hop.tween_property(held, "rotation:z", 1.3, 0.3)
		else:
			held.rotation.z = 1.3
		held.set_meta("belly", true)
	await _wait(Tuning.data.v4_thanks_line_seconds)
	bubble.queue_free()
	if held.get_parent() != holder:
		held.get_parent().remove_child(held)
		holder.add_child(held)
		held.position = Vector3.ZERO
		held.rotation = Vector3.ZERO
		held.scale = Vector3.ONE * float(regular.scale)
	# 목욕대 앞 줄로
	var spot := LINE_START + Vector3((index % LINE_PER_ROW) * LINE_STEP, 0, (index / LINE_PER_ROW) * 0.8)
	var to_line := 0.05 if fast else SPEAK_SPOT.distance_to(spot) / WALK_SPEED
	owner.go_wait(to_global(spot), to_global(PLAYER_SPOT), to_line, false)
	# 앞 손님이 옆으로 비킨 뒤에 다음 손님 (가리지 않게, QA #138)
	await _wait(minf(to_line, 1.5))


## '그때와 지금' 카드: 첫 방문 ↔ 최근 사진 + '처음 ~한 날' 하나
func _show_pair(id: String) -> void:
	_clear_overlay()
	var regular := FpRegulars.get_regular(id)
	var entry: Dictionary = shop.album[id]
	_overlay = PanelContainer.new()
	_overlay.name = "ThenNow"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.9, 0.96)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	_overlay.add_theme_stylebox_override("panel", style)
	shop._hud.get_parent().add_child(_overlay)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay.add_child(box)
	box.add_child(_label("%s · 그때와 지금" % regular.name, 26))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	for item in [["첫 방문 %d일차" % int(entry.first.day), entry.first], ["오늘 %d일차" % int(entry.recent.day), entry.recent]]:
		var column := VBoxContainer.new()
		row.add_child(column)
		var photo := FpAlbum.make_photo(regular, {"best_mood": item[1].get("mood", 2), "wall": item[1].get("wall", ""), "acc": item[1].get("acc", "")}, Vector2(220, 220))
		photo.custom_minimum_size = Vector2(220, 220)
		column.add_child(photo)
		column.add_child(_label(item[0], 18))
	var moments: Array = entry.get("moments", [])
	if not moments.is_empty():
		var best: Dictionary = moments[-1]
		box.add_child(_label("♥ %d일차 %s" % [int(best.day), FpTrust.MOMENTS.get(best.id, best.id)], 18))
	_overlay.position = (shop._hud.get_viewport_rect().size - _overlay.get_combined_minimum_size()) / 2.0


func _show_text(text: String) -> void:
	_clear_overlay()
	var label := _label(text, 40)
	label.name = "EveningText"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.position.y = 120
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.15))
	_overlay = label
	shop._hud.get_parent().add_child(label)
	label.position.x = (shop._hud.get_viewport_rect().size.x - label.get_combined_minimum_size().x) / 2.0


func _clear_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.3, 0.22, 0.15))
	return label
