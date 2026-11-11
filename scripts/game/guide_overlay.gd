extends Control
## 처음 하는 사람용 안내 (MILESTONE_V3_SLICE 7장). HUD 위에 그린다.
## - 1일차 첫 손님에서만: 단계가 바뀌면 그 단계 손동작 그림 1장 (움직이는 그림 + 한 줄)
## - 첫 정산 뒤: 컴퓨터 자리(쇼핑)로 가라는 화살표 (한 번 가면 사라짐)
## - F1: 조작 그림 한 장 (마우스 · 휠 · 키)
## 손동작 PNG + 기존 도구 아이콘으로 움직이는 시범. 그림이 빠지면 도형 시범은 유지한다.

const WashStation := preload("res://scripts/sim/wash_station.gd")
const UiArt := preload("res://scripts/game/ui_art.gd")
## 손동작 그림이 떠 있는 시간 (s)
const GESTURE_TIME := 4.5
const HINT_ART := ["hint_wet", "hint_squeeze", "hint_scrub", "hint_rinse", "hint_towel", "hint_dry"]
const TOOL_ART := ["tool_shower", "tool_bottle", "tool_hand", "tool_bucket", "tool_towel", "tool_dryer"]
const STAGE_NAMES := ["적시기", "샴푸 짜기", "문지르기", "헹구기", "수건", "드라이어"]
const MOTION_PERIOD := 1.6
const CAPTIONS := ["누른 채 몸 위를 쓸어요", "병을 누르고 있다가 떼요", "동그라미를 그려요!", "위에서 아래로 쭉 끌어요", "여러 번 꾹꾹 눌러요", "휠로 거리를 맞춰요"]
const INK := Color(0.15, 0.17, 0.22)
const PAPER := Color(1, 0.98, 0.92, 0.95)
const ACCENT := Color(0.98, 0.55, 0.35)

## 지금 보이는 손동작 그림의 단계 (-1 = 없음)와 남은 시간
var gesture_stage := -1
var gesture_left := 0.0
## 첫 정산 뒤 쇼핑 화살표
var shop_arrow := false
var shop_arrow_done := false
## F1 조작 그림
var help_visible := false

var _seen_stage := -1
var _seen_guest := -1
var _t := 0.0
## 각 단계가 시작할 때 0으로: 병을 떼는 순간이나 원의 중간부터 시작하지 않는다.
var _gesture_t := 0.0

@onready var hud: CanvasLayer = get_parent()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	var world: Node = hud.world
	var station: WashStation = world.station
	var day: Node = world.day
	# 1일차 첫 손님: 씻기는 동안 단계가 바뀔 때마다 (첫 단계 포함) 그 단계 손동작 그림
	var first_guest: bool = day.day == 1 and day.guest_number_today(station.dog_number()) == 1
	if station.dog_number() != _seen_guest:
		_seen_guest = station.dog_number()
		_seen_stage = -1
	if first_guest and station.is_washing() and station.stage != _seen_stage:
		_seen_stage = station.stage
		gesture_stage = station.stage
		gesture_left = GESTURE_TIME
		_gesture_t = 0.0
	_gesture_t += delta
	gesture_left = maxf(gesture_left - delta, 0.0)
	if gesture_left <= 0.0 or not station.is_washing():
		gesture_stage = -1
	# 첫 정산 뒤 한 번: 컴퓨터 자리로 (가면 끝)
	if day.closed and day.day == 1 and not shop_arrow_done:
		shop_arrow = true
	# 컴퓨터 자리에 가거나, 안 가고 다음 날 아침이 되면 끝 (이슈 #64)
	if shop_arrow and (world.local_seat() != 0 or day.morning or day.day != 1):
		shop_arrow = false
		shop_arrow_done = true
	queue_redraw()


func _draw() -> void:
	var screen := get_viewport_rect().size
	if gesture_stage >= 0 and hud.world.local_seat() == 0:
		_draw_gesture(gesture_stage, Vector2(screen.x / 2.0, 150.0))
	if shop_arrow:
		_draw_shop_arrow()
	if help_visible:
		_draw_help(screen)


## 손동작 그림 카드: 위에 움직이는 그림, 아래 한 줄
func _draw_gesture(stage: int, center: Vector2) -> void:
	if stage < 0 or stage >= HINT_ART.size():
		return
	var fade := clampf(gesture_left / 0.4, 0.0, 1.0)
	var rect := Rect2(center - Vector2(210, 76), Vector2(420, 176))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(PAPER, PAPER.a * fade)
	panel.border_color = Color(INK, fade)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(14)
	draw_style_box(panel, rect)
	var font := get_theme_default_font()
	# 완성된 도구 그림은 다시 그리지 않고 같은 텍스처를 쓴다.
	var tool := UiArt.texture(TOOL_ART[stage])
	if tool != null:
		_draw_fitted(tool, Rect2(rect.position + Vector2(14, 8), Vector2(28, 28)), fade)
	draw_string(font, rect.position + Vector2(50, 28), "%d/6  %s" % [stage + 1, STAGE_NAMES[stage]], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(INK, fade))
	var picture := UiArt.texture(HINT_ART[stage])
	var art := center + Vector2(-102, 8)
	if picture != null:
		_draw_fitted(picture, Rect2(art - Vector2(54, 54), Vector2(108, 108)), fade)
		draw_line(center + Vector2(-10, -32), center + Vector2(-10, 49), Color(INK, 0.12 * fade), 1.0)
	# PNG 유무와 독립: 입력 방법을 항상 움직이는 그림으로 보여 준다.
	_draw_motion(stage, center + Vector2(88 if picture != null else 0, 8), fade)
	var text: String = CAPTIONS[stage]
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(font, Vector2(center.x - size.x / 2.0, rect.end.y - 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, fade))
	# 남은 시간 표시. 4.5초 뒤 닫히는 조건은 그대로다.
	draw_line(rect.position + Vector2(14, rect.size.y - 6), rect.position + Vector2(14 + (rect.size.x - 28) * clampf(gesture_left / GESTURE_TIME, 0, 1), rect.size.y - 6), Color(ACCENT, fade), 3.0)


## 길쭉한 기존 도구 아이콘도 가로세로 비율을 유지한다.
func _draw_fitted(texture: Texture2D, box: Rect2, fade: float) -> void:
	var size := texture.get_size()
	var fit := minf(box.size.x / size.x, box.size.y / size.y)
	var scaled := size * fit
	draw_texture_rect(texture, Rect2(box.get_center() - scaled / 2.0, scaled), false, Color(1, 1, 1, fade))


## 단계별 움직이는 손동작 (도형)
func _draw_motion(stage: int, at: Vector2, fade: float) -> void:
	var ink := Color(INK, fade)
	var accent := Color(ACCENT, fade)
	var phase := fmod(_gesture_t, MOTION_PERIOD) / MOTION_PERIOD
	match stage:
		WashStation.Stage.WET:
			# 누른 채 지그재그로 쓸기
			var points := PackedVector2Array()
			for k in 5:
				points.append(at + Vector2(-60 + k * 30, -16 if k % 2 == 0 else 16))
			draw_polyline(points, Color(ink, 0.4 * fade), 3.0)
			var seg := phase * 4.0
			var i := mini(int(seg), 3)
			_draw_pointer(points[i].lerp(points[i + 1], seg - i), true, fade, stage)
		WashStation.Stage.SQUEEZE:
			# 누르는 동안 막대가 차오름 → 뗌
			var fill := clampf(phase / 0.7, 0.0, 1.0)
			draw_rect(Rect2(at + Vector2(-70, 20), Vector2(140, 12)), Color(ink, 0.25 * fade))
			draw_rect(Rect2(at + Vector2(-70, 20), Vector2(140 * fill, 12)), accent)
			_draw_pointer(at + Vector2(0, -12 - (12.0 if phase >= 0.7 else 0.0)), phase < 0.7, fade, stage)
		WashStation.Stage.SCRUB:
			# 동그라미
			draw_arc(at, 30, 0, TAU, 32, Color(ink, 0.4 * fade), 3.0)
			draw_colored_polygon(PackedVector2Array([at + Vector2(30, -6), at + Vector2(38, 6), at + Vector2(22, 6)]), Color(ink, 0.4 * fade))
			_draw_pointer(at + Vector2.from_angle(phase * TAU) * 30.0, true, fade, stage)
		WashStation.Stage.RINSE:
			# 위 → 아래로 끌기
			draw_line(at + Vector2(0, -36), at + Vector2(0, 30), Color(ink, 0.4 * fade), 3.0)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-9, 26), at + Vector2(9, 26), at + Vector2(0, 40)]), Color(ink, 0.4 * fade))
			_draw_pointer(at + Vector2(0, lerpf(-36, 30, phase)), true, fade, stage)
		WashStation.Stage.TOWEL:
			# 꾹꾹 연타: 누를 때마다 둥근 물결
			var tap := fmod(_gesture_t, 0.4) / 0.4
			draw_arc(at, 10 + tap * 26, 0, TAU, 24, Color(accent, (1.0 - tap) * fade), 3.0)
			_draw_pointer(at + Vector2(0, -8.0 if tap >= 0.4 else 0.0), tap < 0.4, fade, stage)
		_:
			# 휠: 마우스 그림의 휠이 위·아래로
			draw_rect(Rect2(at + Vector2(-22, -36), Vector2(44, 66)), Color(1, 1, 1, fade))
			draw_rect(Rect2(at + Vector2(-22, -36), Vector2(44, 66)), ink, false, 3.0)
			var wheel_y := sin(_gesture_t * TAU / MOTION_PERIOD) * 6.0
			draw_rect(Rect2(at + Vector2(-5, -26 + wheel_y), Vector2(10, 16)), accent)
			# 실제 wheel_step: 위로 = 가까이, 아래로 = 멀리.
			draw_string(get_theme_default_font(), at + Vector2(30, -8), "▲ 가까이", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
			draw_string(get_theme_default_font(), at + Vector2(30, 16), "▼ 멀리", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)


## 손가락 커서 (pressed 면 누른 표시)
func _draw_pointer(at: Vector2, pressed: bool, fade: float, stage: int) -> void:
	if pressed:
		draw_circle(at, 20.0, Color(ACCENT, 0.16 * fade))
		draw_arc(at, 20.0, 0, TAU, 20, Color(ACCENT, fade), 2.0)
	var picture := UiArt.texture(TOOL_ART[stage])
	if picture != null:
		var extent := 30.0 if pressed else 36.0
		_draw_fitted(picture, Rect2(at - Vector2.ONE * extent / 2.0, Vector2.ONE * extent), fade)
	else:
		draw_circle(at, 11.0, Color(1, 0.85, 0.7, fade))
		draw_arc(at, 11.0, 0, TAU, 20, Color(INK, fade), 2.0)


## 정산 화면의 "컴퓨터에서 쇼핑하기" (없으면 오른쪽 위 자리 버튼)를 가리키는 깜빡이는 화살표
func _draw_shop_arrow() -> void:
	var target: Control = hud.settle_shop_button if hud.settle_panel.visible else hud.seat_button
	if not target.is_visible_in_tree():
		return
	var rect := target.get_global_rect()
	var tip := Vector2(rect.get_center().x, rect.end.y + 6.0)
	var bob := sin(_t * 6.0) * 6.0
	var color := Color(ACCENT, 0.6 + 0.4 * absf(sin(_t * 4.0)))
	draw_rect(rect.grow(4.0), color, false, 4.0)
	var base := tip + Vector2(0, 46 + bob)
	draw_line(base, tip + Vector2(0, 14 + bob), color, 8.0)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(0, bob), tip + Vector2(-16, 20 + bob), tip + Vector2(16, 20 + bob)]), color)
	var font := get_theme_default_font()
	draw_string_outline(font, base + Vector2(-110, 30), "샴푸·도구는 컴퓨터에서 사요", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, INK)
	draw_string(font, base + Vector2(-110, 30), "샴푸·도구는 컴퓨터에서 사요", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))


## F1 조작 그림 한 장: 마우스 (왼쪽 버튼 = 도구, 휠 = 온도·거리) + 키
func _draw_help(screen: Vector2) -> void:
	var rect := Rect2(screen / 2.0 - Vector2(380, 190), Vector2(760, 380))
	draw_rect(rect, PAPER)
	draw_rect(rect, INK, false, 4.0)
	var picture := UiArt.texture("help_controls")
	var font := get_theme_default_font()
	draw_string(font, rect.position + Vector2(24, 40), "조작 — 마우스 하나로", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
	if picture != null:
		draw_texture_rect(picture, Rect2(rect.position + Vector2(20, 56), rect.size - Vector2(40, 76)), false)
		return
	# 마우스
	var mouse := rect.position + Vector2(130, 200)
	draw_rect(Rect2(mouse - Vector2(55, 90), Vector2(110, 170)), Color(1, 1, 1))
	draw_rect(Rect2(mouse - Vector2(55, 90), Vector2(110, 170)), INK, false, 4.0)
	draw_line(mouse + Vector2(0, -90), mouse + Vector2(0, -20), INK, 3.0)
	draw_line(mouse + Vector2(-55, -20), mouse + Vector2(55, -20), INK, 3.0)
	draw_rect(Rect2(mouse + Vector2(-53, -88), Vector2(52, 66)), Color(ACCENT, 0.8))
	draw_rect(Rect2(mouse + Vector2(-7, -72), Vector2(14, 30)), Color(0.4, 0.65, 1.0))
	# 설명
	var lines := [
		[Color(ACCENT), "왼쪽 버튼 (패드 RT): 도구 쓰기 (누르기·끌기·연타)"],
		[Color(0.4, 0.65, 1.0), "휠 (오른쪽 스틱): 물 온도 · 드라이어 거리"],
		[INK, "도구 바꾸기·강아지 돌리기는 저절로"],
		[INK, "Tab (LB·RB): 컴퓨터 자리 (쇼핑)"],
		[INK, "Esc: 메뉴 · 음량 / F1: 이 그림 닫기"],
	]
	for i in lines.size():
		var y := rect.position.y + 110 + i * 48
		draw_circle(Vector2(rect.position.x + 250, y - 7), 8.0, lines[i][0])
		draw_string(font, Vector2(rect.position.x + 268, y), lines[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
