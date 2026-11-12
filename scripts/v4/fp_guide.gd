extends Control
## V4 처음 하는 사람 안내 (기획 LAUNCH_PREP 2장): 그 일을 처음 할 때 딱 한 번, 그림 + 한 줄.
## 화면 아래 가운데 작은 띠 (가리지 않음, 하던 일은 안 멈춤) + 필요하면 3D 화살표 (▼) 가 대상 위에서 통통.
## 본 안내는 저장 (guide_seen). 메뉴 [안내 끄기] (user://settings.cfg [guide] off), [안내 다시 보기] = 본 것 지우기.
## F1 = 조작 그림 한 장. 그림: assets/ui/guide/<키>.png · help_controls.png 가 있으면 그 그림 (없으면 임시 도형).

const UiArt := preload("res://scripts/game/ui_art.gd")
const FONT := preload("res://assets/fonts/pretendard/Pretendard-Bold.otf")
const TIP_SECONDS := 5.0
const MARKER_SECONDS := 15.0
## 안내 키 → 한 줄 (LAUNCH_PREP 2장 표)
const LINES := {
	"walk": "걸어서 손님을 맞아요 (WASD 걷기 · 마우스 보기 · F1 조작 그림)",
	"sign": "팻말을 뒤집으면 영업 시작",
	"guest": "손님을 눌러 맡아요",
	"shelf": "선반에서 샤워기를 집어요",
	"stage_wet": "누른 채 몸 위를 쓱쓱 — 물을 뿌려요",
	"stage_scrub": "좌우로 짧게 비비면 거품이 몽글몽글",
	"stage_rinse": "위에서 아래로 쓸어내리며 헹궈요",
	"stage_towel": "클릭할 때마다 톡톡 두드려요",
	"stage_dry": "가까이 다가가면 빨리 말라요",
	"stage_brush": "엉킨 뭉치에 쓱 빗어요",
	"stage_trim": "누른 채 분홍빛 털 위를 쓱 — 하늘색 선까지 잘려요",
	"give_back": "주인에게 돌려줘요",
	"settle": "번 돈으로 도구를 키워요 ([도구 가게])",
	"parcel": "택배가 왔어요! 들고 들어와요",
	"photo": "사진첩에 붙었어요! (문 옆 사진첩 책)",
}
## 띠 왼쪽 작은 그림 (임시 도형 글자)
const ICONS := {"walk": "W", "sign": "☾", "guest": "▼", "shelf": "▼", "give_back": "▼", "settle": "$", "parcel": "▣", "photo": "▤"}
const HELP_LINES := ["WASD 걷기 · 마우스 보기", "클릭: 집기 · 손님 맡기기/돌려주기 · 상자 들기 · 팻말 뒤집기", "누르고 있기: 도구 쓰기 (수건은 클릭마다 톡톡)", "Q: 도구·수레 내려놓기", "Esc: 메뉴로 · F1: 이 그림 닫기"]
const INK := Color(0.3, 0.22, 0.15)

## 본 안내 키 (저장됨)
var seen: Array = []
## 꺼져 있으면 아무것도 안 띄움 (빠른 확인도)
var enabled := true
## 지금 띠: 키, 글자, 남은 시간
var tip_key := ""
var tip_text := ""
var tip_left := 0.0
var help_visible := false
var _markers: Array = []
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 처음이면 띠를 띄우고 (target 이 있으면 그 위에 ▼, until 이 참이 되거나 MARKER_SECONDS 뒤 사라짐) true
func show_tip(key: String, target: Node3D = null, until: Callable = Callable()) -> bool:
	if not enabled or seen.has(key):
		return false
	seen.append(key)
	tip_key = key
	tip_text = LINES.get(key, key)
	tip_left = TIP_SECONDS
	if target != null and is_instance_valid(target):
		_add_marker(target, until)
	queue_redraw()
	return true


func toggle_help() -> void:
	help_visible = not help_visible
	queue_redraw()


func _add_marker(target: Node3D, until: Callable) -> void:
	var marker := Label3D.new()
	marker.name = "GuideMarker"
	marker.text = "▼"
	marker.font = FONT
	marker.font_size = 64
	marker.outline_size = 14
	marker.modulate = Color(1.0, 0.55, 0.35)
	marker.pixel_size = 0.004
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	target.add_child(marker)
	var height: float = float(target.get("height")) + 1.0 if target.get("height") != null else 0.45
	marker.position.y = height
	_markers.append({"node": marker, "until": until, "left": MARKER_SECONDS, "base": height})


func markers() -> int:
	return _markers.filter(func(m: Dictionary) -> bool: return is_instance_valid(m.get("node"))).size()


func _process(delta: float) -> void:
	_t += delta
	if tip_left > 0.0:
		tip_left = maxf(tip_left - delta, 0.0)
		queue_redraw()
	for marker in _markers.duplicate():
		# 대상 (손님 등) 이 먼저 사라지면 표시도 같이 사라짐: 타입 없이 받아 살아 있는지 먼저 봄
		var alive: bool = is_instance_valid(marker.node)
		marker.left -= delta
		var done: bool = not alive or marker.left <= 0.0 or (marker.until.is_valid() and marker.until.call())
		if done:
			if alive:
				(marker.node as Node).queue_free()
			_markers.erase(marker)
			continue
		var node: Label3D = marker.node
		node.position.y = marker.base + 0.06 * sin(_t * 6.0)


func _draw() -> void:
	var size := get_viewport_rect().size
	if tip_left > 0.0 and not tip_text.is_empty():
		var width := FONT.get_string_size(tip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 90.0
		var rect := Rect2(Vector2((size.x - width) / 2.0, size.y - 120.0), Vector2(width, 48))
		var alpha := clampf(tip_left / 0.4, 0.0, 1.0)
		draw_rect(rect, Color(1.0, 0.97, 0.9, 0.9 * alpha))
		var icon := UiArt.texture("guide/" + tip_key)
		if icon != null:
			draw_texture_rect(icon, Rect2(rect.position + Vector2(8, 6), Vector2(36, 36)), false, Color(1, 1, 1, alpha))
		else:
			draw_circle(rect.position + Vector2(28, 24), 16.0, Color(1.0, 0.6, 0.4, alpha))
			draw_string(FONT, rect.position + Vector2(19, 31), ICONS.get(tip_key, "!"), HORIZONTAL_ALIGNMENT_CENTER, 18, 18, Color(1, 1, 1, alpha))
		draw_string(FONT, rect.position + Vector2(56, 32), tip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(INK, alpha))
	if help_visible:
		var picture := UiArt.texture("help_controls")
		var box := Rect2(size / 2.0 - Vector2(330, 150), Vector2(660, 300))
		if picture != null:
			draw_texture_rect(picture, box, false)
		else:
			draw_rect(box, Color(1.0, 0.97, 0.9, 0.95))
			draw_string(FONT, box.position + Vector2(24, 44), "조작", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)
			for i in HELP_LINES.size():
				draw_string(FONT, box.position + Vector2(24, 92 + 40 * i), HELP_LINES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
