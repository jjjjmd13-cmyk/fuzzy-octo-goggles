extends Node
## 가게 돈과 컴퓨터 쇼핑 (MILESTONE_V3_SLICE 4장): 기본 샴푸, 복숭아 샴푸, 넓은 샤워기(도구 업그레이드 1),
## 창가 화분(꾸미기 1). 샤워기·화분은 한 번만 산다.
##
## 값은 호스트가 정하고 StoreSync 로 모두에게 보낸다. 다른 사람은 send_* 로 요청만 한다.
## 샴푸 한 병 = tool_shampoo_uses_per_bottle 마리. 시작할 때 기본 샴푸 한 병이 있다.

signal bought(kind: String)

const KINDS := ["basic", "peach", "wide_shower", "plant"]
const NAMES := {"basic": "기본 샴푸", "peach": "복숭아 샴푸", "wide_shower": "넓은 샤워기", "plant": "창가 화분"}
## 한 번만 사는 것 (업그레이드·꾸미기)
const ONCE := ["wide_shower", "plant"]

# --- StoreSync (호스트가 씀)
var money := 0
var basic_uses := 0
var peach_uses := 0
## 지금 쓰는 샴푸
var shampoo := "basic"
## 산 업그레이드·꾸미기
var wide_shower := false
var plant := false


func reset() -> void:
	if not Net.is_host():
		return
	money = Tuning.data.shop_start_money
	basic_uses = Tuning.data.tool_shampoo_uses_per_bottle
	peach_uses = 0
	shampoo = "basic"
	wide_shower = false
	plant = false


## 저장할 값 (SaveGame)
func to_save() -> Dictionary:
	return {"money": money, "basic_uses": basic_uses, "peach_uses": peach_uses, "shampoo": shampoo, "wide_shower": wide_shower, "plant": plant}


## 호스트: 저장에서 되살림
func load_save(data: Dictionary) -> void:
	if not Net.is_host():
		return
	money = int(data.get("money", 0))
	basic_uses = int(data.get("basic_uses", 0))
	peach_uses = int(data.get("peach_uses", 0))
	shampoo = str(data.get("shampoo", "basic"))
	wide_shower = bool(data.get("wide_shower", false))
	plant = bool(data.get("plant", false))


func price(kind: String) -> int:
	var data: Resource = Tuning.data
	match kind:
		"peach":
			return data.shop_price_peach_shampoo
		"wide_shower":
			return data.slice_price_wide_shower
		"plant":
			return data.slice_price_plant
	return data.shop_price_basic_shampoo


## 업그레이드·꾸미기를 이미 샀는가
func owns(kind: String) -> bool:
	return (kind == "wide_shower" and wide_shower) or (kind == "plant" and plant)


func uses(kind: String) -> int:
	return peach_uses if kind == "peach" else basic_uses


func can_buy(kind: String) -> bool:
	return money >= price(kind) and not owns(kind)


## 호스트: 지금 샴푸를 한 마리분 쓴다. 비었으면 "".
func use_shampoo() -> String:
	if uses(shampoo) <= 0:
		return ""
	if shampoo == "peach":
		peach_uses -= 1
	else:
		basic_uses -= 1
	return shampoo


## 호스트: 돈을 더한다 (동전 줍기).
func add_money(amount: int) -> void:
	money += amount


func send_buy(kind: String) -> void:
	_request_buy.rpc_id(1, kind)


func send_select(kind: String) -> void:
	_request_select.rpc_id(1, kind)


@rpc("any_peer", "call_local", "reliable")
func _request_buy(kind: String) -> void:
	if not Net.is_host() or not kind in KINDS or not can_buy(kind):
		return
	money -= price(kind)
	match kind:
		"wide_shower":
			wide_shower = true
		"plant":
			plant = true
		_:
			if kind == "peach":
				peach_uses += Tuning.data.tool_shampoo_uses_per_bottle
			else:
				basic_uses += Tuning.data.tool_shampoo_uses_per_bottle
			# 산 샴푸를 바로 쓴다 (새 향을 사면 바로 보고 싶으니까)
			shampoo = kind
	_bought.rpc(kind)


@rpc("any_peer", "call_local", "reliable")
func _request_select(kind: String) -> void:
	if Net.is_host() and kind in KINDS:
		shampoo = kind


@rpc("authority", "call_local", "reliable")
func _bought(kind: String) -> void:
	bought.emit(kind)
