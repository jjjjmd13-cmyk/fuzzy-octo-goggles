extends Control
## HUD 위에 직접 그리는 것: 도구 커서, 기분 얼굴(😊😐😣), 물 온도 다이얼, 몸 털기 거품.
## 그림은 임시 도형. 그래픽이 오면 이 파일의 _draw_* 만 바꾼다.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const FACE_POS := Vector2(150, 360)
const FACE_RADIUS := 44.0
const DIAL_RECT := Rect2(40, 430, 28, 220)
const FACE_COLORS: Array[Color] = [Color(0.95, 0.45, 0.4), Color(0.95, 0.8, 0.35), Color(0.5, 0.9, 0.5)]

var _foam_left := 0.0
var _foam_spots: Array[Vector3] = []
var _time := 0.0

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


func _draw() -> void:
	var world: Node = hud.world
	var station: WashStation = world.station
	var at_bath: bool = world.local_seat() == 0
	_draw_face(station.mood_face())
	if at_bath and station.tool == WashStation.Tool.SHOWER:
		_draw_dial(station.temperature)
	if _foam_left > 0.0:
		var alpha := clampf(_foam_left / Tuning.data.proto_shake_screen_time * 1.5, 0.0, 1.0)
		var color := Color(station.dog.foam_color, 0.85 * alpha)
		for spot in _foam_spots:
			draw_circle(Vector2(spot.x, spot.y), spot.z, color)
			draw_circle(Vector2(spot.x + spot.z * 0.6, spot.y - spot.z * 0.4), spot.z * 0.6, color)
	if at_bath and not hud.is_paused():
		_draw_cursor(station, world.cursor)


func _draw_face(level: int) -> void:
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


func _draw_dial(temperature: float) -> void:
	var good: PackedFloat32Array = Tuning.data.tool_shower_temp_good
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
	draw_string(font, Vector2(DIAL_RECT.position.x - 8, DIAL_RECT.position.y - 10), "물 온도 Q/E", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)


func _draw_cursor(station: WashStation, pos: Vector2) -> void:
	var outline := Color(0, 0, 0, 0.8)
	match station.tool:
		WashStation.Tool.SHOWER:
			var water := Color(0.4, 0.6, 1.0).lerp(Color(1.0, 0.45, 0.35), station.temperature)
			draw_circle(pos + Vector2(14, -14), 16, Color(0.75, 0.78, 0.82))
			draw_arc(pos + Vector2(14, -14), 16, 0, TAU, 24, outline, 2.0)
			for i in 5:
				var a := 0.6 + i * 0.22
				var drop := pos + Vector2(cos(a + PI), sin(a + PI)).rotated(PI) * (6 + fmod(_time * 60.0 + i * 7, 18))
				draw_circle(drop, 3, water)
		WashStation.Tool.SHAMPOO:
			if station.dose <= 0.0:
				# 병 (누르면 짜짐)
				var bottle := Color(1, 0.6, 0.78) if world_store_peach() else Color(0.95, 0.95, 1)
				draw_rect(Rect2(pos + Vector2(-10, -8), Vector2(20, 34)), bottle)
				draw_rect(Rect2(pos + Vector2(-10, -8), Vector2(20, 34)), outline, false, 2.0)
				draw_rect(Rect2(pos + Vector2(-4, -18), Vector2(8, 10)), Color(0.3, 0.3, 0.35))
			else:
				# 손 (문지르기)
				draw_circle(pos, 16, Color(1, 0.82, 0.68))
				for i in 4:
					draw_rect(Rect2(pos + Vector2(-14 + i * 8, -32), Vector2(6, 18)), Color(1, 0.82, 0.68))
				draw_arc(pos, 16, 0, TAU, 24, outline, 2.0)
		WashStation.Tool.TOWEL:
			draw_rect(Rect2(pos - Vector2(18, 14), Vector2(36, 28)), Color(0.98, 0.9, 0.55))
			for i in 3:
				draw_line(pos + Vector2(-18, -6 + i * 7), pos + Vector2(18, -6 + i * 7), Color(0.9, 0.6, 0.3), 2.0)
			draw_rect(Rect2(pos - Vector2(18, 14), Vector2(36, 28)), outline, false, 2.0)
		WashStation.Tool.DRYER:
			draw_rect(Rect2(pos + Vector2(4, -10), Vector2(34, 20)), Color(0.9, 0.5, 0.65))
			draw_rect(Rect2(pos + Vector2(24, 8), Vector2(10, 22)), Color(0.75, 0.4, 0.55))
			draw_rect(Rect2(pos + Vector2(4, -10), Vector2(34, 20)), outline, false, 2.0)
			var reach := 10.0 if station.dryer_close else 22.0
			draw_arc(pos, reach, 0, TAU, 24, Color(1, 1, 1, 0.8), 2.0)
	draw_circle(pos, 3, Color.WHITE)
	if station.hitting:
		draw_arc(pos, 8, 0, TAU, 16, Color(1, 1, 0.5, 0.9), 2.0)


func world_store_peach() -> bool:
	return hud.world.store.shampoo == "peach"
