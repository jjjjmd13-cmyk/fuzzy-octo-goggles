extends Node
## 가게 돈과 샴푸 병 (GDD_V3 5장 시제품 범위: 기본 샴푸, 복숭아 샴푸).
##
## 값은 호스트가 정하고 StoreSync 로 모두에게 보낸다. 다른 사람은 send_* 로 요청만 한다.
## 샴푸 한 병 = tool_shampoo_uses_per_bottle 마리. 시작할 때 기본 샴푸 한 병이 있다.

signal bought(kind: String)

const KINDS := ["basic", "peach"]
const NAMES := {"basic": "기본 샴푸", "peach": "복숭아 샴푸"}

# --- StoreSync (호스트가 씀)
var money := 0
var basic_uses := 0
var peach_uses := 0
## 지금 쓰는 샴푸
var shampoo := "basic"


func reset() -> void:
	if not Net.is_host():
		return
	money = Tuning.data.shop_start_money
	basic_uses = Tuning.data.tool_shampoo_uses_per_bottle
	peach_uses = 0
	shampoo = "basic"


func price(kind: String) -> int:
	return Tuning.data.shop_price_peach_shampoo if kind == "peach" else Tuning.data.shop_price_basic_shampoo


func uses(kind: String) -> int:
	return peach_uses if kind == "peach" else basic_uses


func can_buy(kind: String) -> bool:
	return money >= price(kind)


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
