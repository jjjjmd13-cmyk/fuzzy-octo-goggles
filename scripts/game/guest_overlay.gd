extends Control
## 손님 머리 위 말풍선: 남은 단계(목욕·말리기)와 하트 (GDD_V2 3.1). 숫자는 안 보인다.
## 3D 위치를 화면에 투영해서 그린다. 하트는 마지막 하나가 깜빡이고, 화나면 "흥!".

const STEP_STYLE := {
	"bath": ["목욕", Color(0.35, 0.65, 1.0)],
	"dryer": ["말리기", Color(1.0, 0.6, 0.25)],
}
const HEART_COLOR := Color(1.0, 0.35, 0.45)
const HEART_EMPTY := Color(0.25, 0.25, 0.3, 0.6)
const HEAD_HEIGHT := 1.35
const PILL_WIDTH := 76.0
const PILL_STEP := 80.0

var _blink := 0.0


func _process(delta: float) -> void:
	_blink += delta
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	var world := get_parent().get_parent()
	if camera == null or not world.has_node("Guests"):
		return
	var font := get_theme_default_font()
	for guest in world.get_node("Guests").get_children():
		var head: Vector3 = guest.global_position + Vector3(0, HEAD_HEIGHT * guest.get_node("Model").scale.y, 0)
		if camera.is_position_behind(head):
			continue
		var at := camera.unproject_position(head)
		if guest.phase == guest.Phase.ANGRY:
			_draw_text_box(font, at, "흥!", Color(0.95, 0.25, 0.25))
			continue
		var steps: PackedStringArray = guest.remaining_steps()
		var x := at.x - (steps.size() * PILL_STEP) * 0.5
		for step in steps:
			var style: Array = STEP_STYLE[step]
			draw_rect(Rect2(x, at.y - 46, PILL_WIDTH, 26), style[1])
			draw_string(font, Vector2(x, at.y - 27), style[0], HORIZONTAL_ALIGNMENT_CENTER, PILL_WIDTH, 18, Color.WHITE)
			x += PILL_STEP
		if steps.is_empty():
			_draw_text_box(font, at + Vector2(0, -20), "출구로!", Color(0.3, 0.75, 0.4))
		var hearts: int = guest.hearts_left()
		var total: int = Tuning.data.guest_hearts
		for i in total:
			var filled := i < hearts
			if filled and i == hearts - 1 and hearts == 1 and Tuning.data.guest_heart_blink_last and fmod(_blink, 0.5) < 0.25:
				filled = false
			_draw_heart(at + Vector2((i - (total - 1) * 0.5) * 22, -6), 9, HEART_COLOR if filled else HEART_EMPTY)


func _draw_text_box(font: Font, at: Vector2, text: String, color: Color) -> void:
	draw_rect(Rect2(at.x - 40, at.y - 30, 80, 28), color)
	draw_string(font, Vector2(at.x - 40, at.y - 9), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 20, Color.WHITE)


func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	draw_circle(center + Vector2(-size * 0.5, -size * 0.3), size * 0.55, color)
	draw_circle(center + Vector2(size * 0.5, -size * 0.3), size * 0.55, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 1.02, -size * 0.1), center + Vector2(size * 1.02, -size * 0.1), center + Vector2(0, size * 1.0),
	]), color)
