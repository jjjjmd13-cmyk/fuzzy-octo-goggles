extends Control
## HUD 위에 직접 그리는 것: 도구 커서, 기분 얼굴(😊😐😣), 물 온도·드라이어 거리 다이얼, 회전판 화살표,
## 주인 말풍선, 몸 털기 거품, 벽시계(9시 → 6시, 바늘 + 12·3·6·9, 마감 칸 빨강)와 며칠째,
## 대기 손님 머리 위 남은 참을성 (줄어드는 원).
## 그림은 임시 도형. assets/ui/ 에 그림이 있으면 그 그림을 쓴다 (face_*, bubble, icon_*, tool_*).

const WashStation := preload("res://scripts/sim/wash_station.gd")
const UiArt := preload("res://scripts/game/ui_art.gd")
const FACE_POS := Vector2(150, 410)
const FACE_RADIUS := 44.0
const DIAL_RECT := Rect2(40, 490, 28, 200)
const FACE_ART := ["face_unhappy", "face_neutral", "face_happy"]
const TOOL_ART := ["tool_shower", "tool_bottle", "tool_hand", "tool_bucket", "tool_towel", "tool_dryer"]
const FACE_COLORS: Array[Color] = [Color(0.95, 0.45, 0.4), Color(0.95, 0.8, 0.35), Color(0.5, 0.9, 0.5)]

var _foam_left := 0.0
var _foam_spots: Array[Vector3] = []
var _time := 0.0
## 참을성 원은 요청 카드·도구걸이 밑 층에 그린다 (QA #50: 카드 글자를 덮지 않게). hud.gd 가 만들어 넣음
var patience_layer: Control

@onready var hud: CanvasLayer = get_parent()


## 몸 털기: 화면에 거품이 튄다 (proto_shake_screen_time 동안)
func show_foam() -> void:
	_foam_left = Tuning.data.proto_shake_screen_time
	_foam_spots.clear()
	var size := get_viewport_rect().size
	for i in 14:
		_foam_spots.append(Vector3(randf() * size.x, randf() * size.y, randf_range(30, 90)))


func is_showing_foam() -> bool:
	return _foam_left > 0.0


func _process(delta: float) -> void:
	_time += delta
	_foam_left = maxf(_foam_left - delta, 0.0)
	queue_redraw()
	if patience_layer != null:
		patience_layer.queue_redraw()


func _draw() -> void:
	var world: Node = hud.world
	var station: WashStation = world.station
	var at_bath: bool = world.local_seat() == 0
	_draw_face(station.mood_face())
	_draw_clock(world.day)
	_draw_trait(station)
	if at_bath and station.owner_bubble_visible():
		_draw_bubble(station)
	if at_bath and station.is_washing():
		if station.tool == WashStation.Tool.SHOWER:
			_draw_dial(station.temperature, station.temp_good())
		elif station.tool == WashStation.Tool.DRYER:
			_draw_distance(station)
		_draw_arrows(station)
	if _foam_left > 0.0:
		var alpha := clampf(_foam_left / Tuning.data.proto_shake_screen_time * 1.5, 0.0, 1.0)
		var color := Color(station.dog.foam_color, 0.85 * alpha)
		for spot in _foam_spots:
			draw_circle(Vector2(spot.x, spot.y), spot.z, color)
			draw_circle(Vector2(spot.x + spot.z * 0.6, spot.y - spot.z * 0.4), spot.z * 0.6, color)
	if at_bath and not hud.is_paused():
		_draw_cursor(station, world.cursor)


func _draw_face(level: int) -> void:
	var picture := UiArt.texture(FACE_ART[level])
	if picture != null:
		draw_texture_rect(picture, Rect2(FACE_POS - Vector2.ONE * FACE_RADIUS, Vector2.ONE * FACE_RADIUS * 2.0), false)
		return
	draw_circle(FACE_POS, FACE_RADIUS, FACE_COLORS[level])
	draw_arc(FACE_POS, FACE_RADIUS, 0, TAU, 48, Color.BLACK, 3.0)
	var eye_y := FACE_POS.y - 10
	if level == 0:
		# 😣 찡그린 눈
		for side in [-1, 1]:
			var c := Vector2(FACE_POS.x + side * 16, eye_y)
			draw_line(c + Vector2(-7, -5 * side), c + Vector2(7, 0), Color.BLACK, 3.0)
			draw_line(c + Vector2(7, 0), c + Vector2(-7, 5 * side), Color.BLACK, 3.0)
	else:
		draw_circle(Vector2(FACE_POS.x - 16, eye_y), 5, Color.BLACK)
		draw_circle(Vector2(FACE_POS.x + 16, eye_y), 5, Color.BLACK)
	var mouth := Vector2(FACE_POS.x, FACE_POS.y + 16)
	match level:
		2:
			draw_arc(mouth - Vector2(0, 8), 16, 0.2, PI - 0.2, 16, Color.BLACK, 3.0)
		1:
			draw_line(mouth - Vector2(14, 0), mouth + Vector2(14, 0), Color.BLACK, 3.0)
		_:
			draw_arc(mouth + Vector2(0, 12), 14, PI + 0.3, TAU - 0.3, 16, Color.BLACK, 3.0)


## good = 이 손님의 '좋음' 범위 (고양이·겁쟁이는 좁음)
func _draw_dial(temperature: float, good: PackedFloat32Array) -> void:
	draw_rect(DIAL_RECT, Color(0.1, 0.1, 0.15, 0.8))
	# 아래 = 차가움(파랑), 위 = 뜨거움(빨강), 가운데 초록 = 좋음
	var bottom := DIAL_RECT.end.y
	var height := DIAL_RECT.size.y
	draw_rect(Rect2(DIAL_RECT.position.x, bottom - height * good[0], DIAL_RECT.size.x, height * good[0]), Color(0.3, 0.55, 1.0, 0.8))
	draw_rect(Rect2(DIAL_RECT.position.x, bottom - height * good[1], DIAL_RECT.size.x, height * (good[1] - good[0])), Color(0.4, 0.9, 0.5, 0.8))
	draw_rect(Rect2(DIAL_RECT.position.x, DIAL_RECT.position.y, DIAL_RECT.size.x, height * (1.0 - good[1])), Color(1.0, 0.4, 0.3, 0.8))
	var y := bottom - height * temperature
	draw_rect(Rect2(DIAL_RECT.position.x - 8, y - 4, DIAL_RECT.size.x + 16, 8), Color.WHITE)
	var font := get_theme_default_font()
	draw_string(font, Vector2(DIAL_RECT.position.x - 8, DIAL_RECT.position.y - 10), "물 온도 (휠)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)


## 주인 머리 위 말풍선: 목욕 + (복숭아 향)
func _draw_bubble(station: WashStation) -> void:
	var camera: Camera3D = hud.world.camera
	var point: Vector3 = station.owner_bubble_point()
	if camera.is_position_behind(point):
		return
	var center := camera.unproject_position(point)
	var wants := station.wants_peach()
	var size := Vector2(150 if wants else 90, 80)
	var rect := Rect2(center - size / 2.0, size)
	var bubble := UiArt.texture("bubble")
	if bubble != null:
		draw_texture_rect(bubble, rect.grow(10), false)
	else:
		draw_rect(rect, Color(1, 1, 1, 0.95))
		draw_rect(rect, Color(0.2, 0.2, 0.3), false, 3.0)
		draw_colored_polygon(PackedVector2Array([rect.position + Vector2(size.x * 0.4, size.y), rect.position + Vector2(size.x * 0.55, size.y), center + Vector2(-5, size.y * 0.5 + 22)]), Color(1, 1, 1, 0.95))
	var slot := Vector2(rect.position.x + 45, center.y)
	_draw_icon("icon_bath", slot, 30.0, func(c: Vector2) -> void:
		# 임시 욕조 그림: 파란 반원 + 거품
		draw_rect(Rect2(c + Vector2(-26, -4), Vector2(52, 22)), Color(0.56, 0.83, 0.96))
		for k in 4:
			draw_circle(c + Vector2(-18 + k * 12, -8 - (k % 2) * 6), 8, Color(1, 1, 1))
			draw_arc(c + Vector2(-18 + k * 12, -8 - (k % 2) * 6), 8, 0, TAU, 12, Color(0.6, 0.7, 0.8), 1.5))
	if wants:
		_draw_icon("icon_peach", slot + Vector2(60, 0), 26.0, func(c: Vector2) -> void:
			draw_circle(c, 22, Color(1.0, 0.7, 0.6))
			draw_circle(c + Vector2(-6, -6), 8, Color(1.0, 0.82, 0.75))
			draw_colored_polygon(PackedVector2Array([c + Vector2(2, -20), c + Vector2(18, -30), c + Vector2(10, -16)]), Color(0.4, 0.75, 0.4)))


## 벽시계: 돈 표시 오른쪽. 짧은 바늘 = 시, 긴 바늘 = 분. 6시가 지나면 테두리가 빨개짐
func _draw_clock(day: Node) -> void:
	if day.day <= 0:
		return
	var center := Vector2(get_viewport_rect().size.x / 2.0 + 150.0, 36.0)
	var radius := 26.0
	var face := UiArt.texture("clock")
	if face != null:
		draw_texture_rect(face, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
	else:
		draw_circle(center, radius, Color(1, 0.98, 0.92))
		for k in 12:
			var dir := Vector2.from_angle(k * TAU / 12.0)
			draw_line(center + dir * (radius - 6.0), center + dir * (radius - 2.0), Color(0.3, 0.3, 0.35), 2.0)
	# 마감 칸: 5시 → 6시를 빨갛게 (6시에 문 닫음)
	var wedge := PackedVector2Array([center])
	for k in 9:
		wedge.append(center + _clock_dir(5.0 + k / 8.0) * (radius - 3.0))
	draw_colored_polygon(wedge, Color(0.95, 0.4, 0.35, 0.45))
	var number_font := get_theme_default_font()
	for hour_mark in [12, 3, 6, 9]:
		var at := center + _clock_dir(hour_mark) * (radius - 10.0)
		var text := str(hour_mark)
		var text_size := number_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_string(number_font, at + Vector2(-text_size.x / 2.0, text_size.y / 2.0 - 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.3, 0.35))
	draw_arc(center, radius, 0, TAU, 40, Color(0.9, 0.3, 0.3) if not day.is_open() else Color(0.25, 0.25, 0.3), 3.0)
	var hour: float = day.hour()
	var hour_dir := _clock_dir(hour)
	var minute_dir := Vector2.from_angle(fmod(hour, 1.0) * TAU - PI / 2.0)
	draw_line(center, center + hour_dir * radius * 0.5, Color(0.15, 0.15, 0.2), 4.0)
	draw_line(center, center + minute_dir * radius * 0.8, Color(0.15, 0.15, 0.2), 2.5)
	draw_circle(center, 3.0, Color(0.15, 0.15, 0.2))
	var font := get_theme_default_font()
	draw_string_outline(font, center + Vector2(radius + 10.0, 8.0), "%d일차" % day.day, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0.1, 0.1, 0.15))
	draw_string(font, center + Vector2(radius + 10.0, 8.0), "%d일차" % day.day, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1))



## 요청 카드 오른쪽 위 구석: 성격 그림 (간지럼쟁이 = 깃털, 겁쟁이 = 물방울).
## 그림이 있으면 assets/ui/trait_ticklish.png · trait_timid.png, 없으면 도형
func _draw_trait(station: WashStation) -> void:
	var card: Control = hud.get_node("Card")
	var trait_index := station.personality()
	if not card.visible or trait_index == WashStation.Personality.NONE:
		return
	var rect := card.get_global_rect()
	# 카드 오른쪽 위 모서리에 반쯤 걸쳐서 (제목 글자를 덮지 않게, QA #51)
	var center := Vector2(rect.end.x + 2.0, rect.position.y + 6.0)
	draw_circle(center, 20.0, Color(1, 1, 1, 0.9))
	draw_arc(center, 20.0, 0, TAU, 24, Color(0.3, 0.35, 0.45), 2.0)
	if trait_index == WashStation.Personality.TICKLISH:
		_draw_icon("trait_ticklish", center, 16.0, func(c: Vector2) -> void:
			# 깃털: 비스듬한 잎 모양 + 대
			var points := PackedVector2Array()
			for k in 13:
				var t := k / 12.0 * TAU
				points.append(c + Vector2(cos(t) * 6.0, sin(t) * 14.0).rotated(0.6))
			draw_colored_polygon(points, Color(0.55, 0.75, 0.95))
			draw_line(c + Vector2(-9, 12), c + Vector2(8, -11), Color(0.3, 0.4, 0.6), 2.0))
	else:
		_draw_icon("trait_timid", center, 16.0, func(c: Vector2) -> void:
			# 물방울: 아래 원 + 위 뾰족
			draw_circle(c + Vector2(0, 4), 9.0, Color(0.35, 0.65, 1.0))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 1), c + Vector2(0, -14), c + Vector2(8, 1)]), Color(0.35, 0.65, 1.0)))


## 시계판에서 그 시각(시)의 방향 (12시 = 위)
func _clock_dir(hour: float) -> Vector2:
	return Vector2.from_angle(fmod(hour, 12.0) / 12.0 * TAU - PI / 2.0)


## 대기 손님 머리 위: 남은 참을성이 줄어드는 원 (초록 → 노랑 → 빨강). HUD 에 가려진 손님도 알아보게.
## patience_layer 의 draw 에서 부른다 (그 층에 그림)
func draw_patience() -> void:
	var world: Node = hud.world
	if world.local_seat() != 0:
		return
	var day: Node = world.day
	var station: WashStation = world.station
	var layer := patience_layer
	var camera: Camera3D = world.camera
	var screen := layer.get_viewport_rect().size
	var ids: PackedInt32Array = day.queue_ids
	for i in ids.size():
		var owner: Node3D = station.waiting_area.owners.get(ids[i])
		if owner == null:
			continue
		var top: Vector3 = owner.global_position + Vector3(0, float(owner.get("height")) + 0.06, 0)
		if camera.is_position_behind(top):
			continue
		# 화면 끝에서 잘리지 않게 안쪽으로
		var center := camera.unproject_position(top).clamp(Vector2(18, 18), screen - Vector2(18, 18))
		# 꽉 찬 원은 처음·끝 점이 겹쳐 다각형이 깨지므로 조금 덜 채움
		var left := minf(1.0 - float(day.patience_ratio(i)), 0.999)
		var color := Color(0.4, 0.85, 0.45).lerp(Color(0.98, 0.8, 0.3), clampf((0.6 - left) / 0.3, 0.0, 1.0))
		if left < 0.3:
			color = Color(0.95, 0.4, 0.35)
		layer.draw_circle(center, 14.0, Color(1, 1, 1, 0.85))
		if left > 0.0:
			var pie := PackedVector2Array([center])
			var steps := maxi(int(left * 24.0), 1)
			for k in steps + 1:
				pie.append(center + Vector2.from_angle(-PI / 2.0 + TAU * left * k / steps) * 11.0)
			layer.draw_colored_polygon(pie, color)
		layer.draw_arc(center, 14.0, 0, TAU, 24, Color(0.25, 0.25, 0.3), 2.0)


## 그림(assets/ui/<name>.png)이 있으면 그 그림, 없으면 fallback 으로 그린다
func _draw_icon(art: String, center: Vector2, radius: float, fallback: Callable) -> void:
	var picture := UiArt.texture(art)
	if picture != null:
		draw_texture_rect(picture, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
	else:
		fallback.call(center)


## 드라이어 거리: 가까움(위) ↔ 멂(아래), 빨간 칸 = 너무 가까움
func _draw_distance(station: WashStation) -> void:
	var data: Resource = Tuning.data
	var range_m: PackedFloat32Array = data.dryer_distance_range
	draw_rect(DIAL_RECT, Color(0.1, 0.1, 0.15, 0.8))
	var near := inverse_lerp(range_m[0], range_m[1], data.proto_dryer_near)
	draw_rect(Rect2(DIAL_RECT.position, Vector2(DIAL_RECT.size.x, DIAL_RECT.size.y * near)), Color(1.0, 0.4, 0.3, 0.8))
	draw_rect(Rect2(DIAL_RECT.position + Vector2(0, DIAL_RECT.size.y * near), Vector2(DIAL_RECT.size.x, DIAL_RECT.size.y * (1.0 - near))), Color(0.56, 0.83, 0.96, 0.8))
	var y := DIAL_RECT.position.y + DIAL_RECT.size.y * inverse_lerp(range_m[0], range_m[1], station.dryer_distance)
	draw_rect(Rect2(DIAL_RECT.position.x - 8, y - 4, DIAL_RECT.size.x + 16, 8), Color.WHITE)
	draw_rect(Rect2(DIAL_RECT.position.x - 8, y - 4, DIAL_RECT.size.x + 16, 8), Color.BLACK, false, 1.5)
	var font := get_theme_default_font()
	draw_string(font, Vector2(DIAL_RECT.position.x - 8, DIAL_RECT.position.y - 10), "거리 (휠)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)


## 회전판 가장자리 화살표 (누르면 바로 돌림)
func _draw_arrows(station: WashStation) -> void:
	var points := station.turn_arrow_points()
	for i in points.size():
		var c := points[i]
		var side := -1.0 if i == 0 else 1.0
		var color := Color(1, 1, 1, 0.9) if station.turning_left == 0.0 else Color(1, 1, 1, 0.35)
		draw_circle(c, 22, Color(0.2, 0.25, 0.35, 0.55))
		draw_arc(c, 14, PI * 0.15, PI * 1.35, 16, color, 4.0)
		var tip := c + Vector2(side * 14, 4)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -9), tip + Vector2(side * 9, 4), tip + Vector2(-side * 6, 6)]), color)


func _draw_cursor(station: WashStation, pos: Vector2) -> void:
	var outline := Color(0, 0, 0, 0.8)
	var picture := UiArt.texture(TOOL_ART[station.tool])
	if picture != null and station.tool != WashStation.Tool.BOTTLE:
		draw_texture_rect(picture, Rect2(pos + Vector2(-8, -56), Vector2(56, 56)), false)
	else:
		match station.tool:
			WashStation.Tool.SHOWER:
				var water := Color(0.4, 0.6, 1.0).lerp(Color(1.0, 0.45, 0.35), station.temperature)
				draw_circle(pos + Vector2(26, -26), 16, Color(0.75, 0.78, 0.82))
				draw_arc(pos + Vector2(26, -26), 16, 0, TAU, 24, outline, 2.0)
				draw_circle(pos + Vector2(26, -26), 7, water)
			WashStation.Tool.BOTTLE:
				# 누르는 동안 병이 찌그러진다
				var squash := 0.0
				if station.squeezing:
					squash = clampf(station.squeeze_time / Tuning.data.squeeze_max_time, 0.0, 1.0)
				var width := 22.0 * (1.0 - squash * 0.45)
				var bottle := Color(1, 0.6, 0.78) if world_store_peach() else Color(0.72, 0.89, 0.83)
				var body := Rect2(pos + Vector2(-width / 2.0, -46), Vector2(width, 34))
				if picture != null:
					draw_texture_rect(picture, Rect2(pos + Vector2(-width, -64), Vector2(width * 2.0, 52)), false)
				else:
					draw_rect(body, bottle)
					draw_rect(body, outline, false, 2.0)
					draw_rect(Rect2(pos + Vector2(-4, -12), Vector2(8, 8)), Color(0.3, 0.3, 0.35))
			WashStation.Tool.HAND:
				var glove := Color(1.0, 0.85, 0.3)
				draw_circle(pos, 16, glove)
				for i in 4:
					draw_rect(Rect2(pos + Vector2(-14 + i * 8, -32), Vector2(6, 18)), glove)
				draw_arc(pos, 16, 0, TAU, 24, outline, 2.0)
				if station.circling:
					draw_arc(pos, 30, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)
			WashStation.Tool.BUCKET:
				draw_colored_polygon(PackedVector2Array([pos + Vector2(-22, -40), pos + Vector2(22, -40), pos + Vector2(15, -10), pos + Vector2(-15, -10)]), Color(0.56, 0.83, 0.96))
				draw_polyline(PackedVector2Array([pos + Vector2(-22, -40), pos + Vector2(22, -40), pos + Vector2(15, -10), pos + Vector2(-15, -10), pos + Vector2(-22, -40)]), outline, 2.0)
				draw_line(pos + Vector2(0, -6), pos + Vector2(0, 30), Color(1, 1, 1, 0.6), 2.0)
				draw_colored_polygon(PackedVector2Array([pos + Vector2(-6, 24), pos + Vector2(6, 24), pos + Vector2(0, 36)]), Color(1, 1, 1, 0.6))
			WashStation.Tool.TOWEL:
				draw_rect(Rect2(pos - Vector2(20, 16), Vector2(40, 32)), Color(1.0, 0.62, 0.77))
				draw_line(pos + Vector2(-20, 4), pos + Vector2(20, 4), Color(1, 1, 1), 3.0)
				draw_rect(Rect2(pos - Vector2(20, 16), Vector2(40, 32)), outline, false, 2.0)
			WashStation.Tool.DRYER:
				draw_rect(Rect2(pos + Vector2(4, -10), Vector2(34, 20)), Color(0.56, 0.83, 0.96))
				draw_rect(Rect2(pos + Vector2(24, 8), Vector2(10, 22)), Color(1.0, 0.42, 0.42))
				draw_rect(Rect2(pos + Vector2(4, -10), Vector2(34, 20)), outline, false, 2.0)
	if station.tool == WashStation.Tool.DRYER:
		# 바람이 닿는 넓이 (가까울수록 좁고 셈)
		var range_m: PackedFloat32Array = Tuning.data.dryer_distance_range
		var reach := lerpf(10.0, 34.0, inverse_lerp(range_m[0], range_m[1], station.dryer_distance))
		draw_arc(pos, reach, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)
	draw_circle(pos, 3, Color.WHITE)
	if station.hitting:
		draw_arc(pos, 8, 0, TAU, 16, Color(1, 1, 0.5, 0.9), 2.0)


func world_store_peach() -> bool:
	return hud.world.store.shampoo == "peach"
