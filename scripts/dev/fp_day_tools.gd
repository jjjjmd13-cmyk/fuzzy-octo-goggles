extends CanvasLayer
## 18일 점검 도구 (개발용, 이슈 #122 · 점검표 docs/design/PLAYTEST_V4_18DAYS.md). 빠른 확인 [18일 점검] 에서만 붙음.
## 스팀 출시 빌드에는 scripts/dev/* 가 통째로 빠지므로 이 도구도 없음.
##
##   F5  날 건너뛰기: 지금 날을 끝내고 다음 날 아침으로 (그날 손님은 받지 않은 것으로). 정산·자동 저장은 평소처럼
##   F6  날 건너뛰기 (모두 받음): 그날 올 손님(480초 ÷ 간격)을 모두 😊 로 받은 것으로 치고 넘어감 (요금·팁·사진첩·샴푸·빗)
##   F7  돈 +1,000
##   F8  하루 결과 기록 켜기·끄기: 하루를 닫을 때마다 user://v4_day_log.csv 에 한 줄
## 정산 판에서 F5·F6 = [다음 날] 과 같음 (산 것까지 기록됨).

const FpDays := preload("res://scripts/v4/fp_days.gd")
const FpRegulars := preload("res://scripts/v4/fp_regulars.gd")
const LOG_META := "v4_day_log"
const COLUMNS := "day,served,left,price_sum,tip_sum,upkeep,bought,money_after,regulars_met,trust_levels,gold_photos"

static var log_path := "user://v4_day_log.csv"

var shop: Node3D
var _label: Label
var _rng := RandomNumberGenerator.new()


## 가게에 붙임 (가게가 트리에 들어간 뒤)
func attach(target: Node3D) -> void:
	shop = target
	shop.day_closed.connect(_on_day_closed)
	_rng.randomize()
	layer = 5
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 300)
	panel.modulate = Color(1, 1, 1, 0.9)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	box.add_child(_label)
	for row in [["F5 날 건너뛰기", skip_day.bind(false)], ["F6 건너뛰기 (모두 받음)", skip_day.bind(true)], ["F7 돈 +1,000", add_money], ["F8 하루 기록 켜기/끄기", toggle_log]]:
		var button := Button.new()
		button.text = row[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(row[1])
		box.add_child(button)
	_refresh()


static func log_enabled() -> bool:
	return bool(Engine.get_meta(LOG_META, false))


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F5:
			skip_day(false)
		KEY_F6:
			skip_day(true)
		KEY_F7:
			add_money()
		KEY_F8:
			toggle_log()


## 날 건너뛰기. all_served = 그날 손님을 모두 받은 것으로
func skip_day(all_served := false) -> void:
	if shop == null or is_instance_valid(shop._ending):
		return
	if shop.day_over:
		shop.start_next_day()
		return
	_clear_floor()
	if all_served:
		simulate_served()
	shop.end_day()
	shop.start_next_day()


func add_money(amount := 1000) -> void:
	shop.money += amount
	# 정산 판이면 판도 새로, 저장도 (영업 중에는 저장하지 않음 — 정산 때 같이 저장됨)
	if shop.day_over and is_instance_valid(shop._settle):
		shop._show_settle()
		shop.save_game(shop.day + 1)
	_refresh()


func toggle_log() -> void:
	Engine.set_meta(LOG_META, not log_enabled())
	_refresh()


## 대기 손님·목욕통·택배 트럭을 정리 (손님은 떠나지 않은 것으로, 그날 셈에 안 들어감)
func _clear_floor() -> void:
	var guests: Node3D = shop.guests
	shop.parcels_view.finish_now()
	shop.morning = false
	guests.open = false
	for guest in guests.guests:
		(guest.owner as Node3D).queue_free()
	guests.guests.clear()
	if guests.current != null:
		(guests.current as Node3D).queue_free()
		guests.current = null
	shop._clear_tub()
	shop._taken = {}
	shop.regular = ""


## 그날 올 손님 수만큼 😊 로 받은 것으로: 요금 + 팁 (기분 😊 + 보통 손님 2분 안 빠른 팁, 축제 배수), 사진첩, 샴푸·빗
func simulate_served() -> int:
	var count := floori(shop.day_seconds / FpDays.guest_every(shop.day))
	var guests: Node3D = shop.guests
	var face := 2
	for i in count:
		var prefer: Array = []
		if FpDays.is_festival(shop.day):
			prefer = shop.album.keys().filter(func(key: String) -> bool: return int(shop.album[key].get("best_mood", -1)) < 3)
		var id := FpRegulars.pick(shop.day, i + 1, shop.album.keys(), guests.new_today, [], _rng, prefer)
		var regular := FpRegulars.get_regular(id)
		if not shop.album.has(id):
			guests.new_today += 1
		var fee: int = Tuning.data.v4_cat_price if regular.get("animal", "dog") == "cat" else Tuning.data.v4_price_wash
		var tip := roundi((Tuning.data.v4_tip_mood4[face] + shop.fast_tip("normal", 90.0)) * FpDays.tip_mult(shop.day))
		if shop.shampoo_left < 0.01:
			fee = Tuning.data.v4_no_shampoo_price
			tip = 0
		else:
			shop._use_shampoo()
		shop.fees += fee
		shop.tips += tip
		shop.money += fee + tip
		shop.brush_used += 1
		shop.regular = id
		shop.take_photo(face)
		guests.served += 1
	shop.regular = ""
	return count


## 하루 결과 한 줄 (열은 COLUMNS, bought 는 ; 로 이음, trust_levels 는 단골 신뢰가 들어오면 채움)
static func csv_line(summary: Dictionary) -> String:
	var bought: Array = summary.get("bought", [])
	var cells := [summary.day, summary.served, summary.left, summary.price_sum, summary.tip_sum, summary.upkeep, ";".join(bought), summary.money_after, summary.regulars_met, summary.get("trust_levels", "-"), summary.gold_photos]
	return ",".join(cells.map(func(cell: Variant) -> String: return str(cell)))


static func append_log(summary: Dictionary) -> void:
	var fresh := not FileAccess.file_exists(log_path)
	var file := FileAccess.open(log_path, FileAccess.WRITE if fresh else FileAccess.READ_WRITE)
	if file == null:
		push_warning("하루 기록 실패: %s" % log_path)
		return
	if fresh:
		file.store_line(COLUMNS)
	else:
		file.seek_end()
	file.store_line(csv_line(summary))


func _on_day_closed(summary: Dictionary) -> void:
	if log_enabled():
		append_log(summary)
	_refresh()


func _refresh() -> void:
	if _label != null:
		_label.text = "18일 점검 (개발용) · 기록 %s" % ("켜짐 → " + log_path if log_enabled() else "꺼짐")
