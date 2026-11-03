extends Node
## 빠른 확인 (개발·확인용, 사람 대표 요청): 기능 하나를 강아지 1~2마리로 바로 해 보고 메뉴로.
## 메인 메뉴의 "빠른 확인" 줄이 Engine 메타 "quick_check_feature" 에 기능 id 를 넣고 이 씬을 연다.
## 참을성·벽시계는 끄고, 손님이 처음부터 대기. 강아지를 다 돌려주면 "확인 끝! 새로 들어간 것: …".
##
## 스팀 출시 빌드에는 이 폴더가 통째로 빠진다 (export_presets.cfg "… Steam Release" 의 exclude_filter
## scenes/dev/*, scripts/dev/*). 메뉴는 이 씬이 없으면 버튼을 만들지 않는다. docs/dev/RELEASE_CHECKLIST.md
##
## 기능을 새로 넣으면 FEATURES 에 한 줄 추가하고, fp_shop.gd 가 quick_feature 로 그 기능이 바로 나오게 한다.

const SHOP_SCENE := preload("res://scenes/v4/fp_shop.tscn")
const FpSettle := preload("res://scripts/v4/fp_settle.gd")
## id, 메뉴 버튼, 강아지 수, 끝 화면의 "새로 들어간 것"
const FEATURES: Array[Dictionary] = [
	{"id": "day", "name": "하루 돌리기", "dogs": 2, "new": "손님 클릭으로 맡기기·돌려주기, 요금 + 팁"},
	{"id": "dryer", "name": "드라이기", "dogs": 1, "new": "헹군 뒤 드라이기로 말리기 (털 뽕·귀 펄럭), 수건 대신"},
]

var shop: Node3D
var feature: Dictionary


func _ready() -> void:
	feature = find(Engine.get_meta("quick_check_feature", "day"))
	shop = SHOP_SCENE.instantiate()
	shop.quick_dogs = feature.dogs
	shop.quick_feature = feature.id
	add_child(shop)
	shop.quick_finished.connect(_on_finished)


static func find(id: String) -> Dictionary:
	for item in FEATURES:
		if item.id == id:
			return item
	return FEATURES[0]


func _on_finished() -> void:
	var settle := FpSettle.new()
	settle.name = "QuickDone"
	shop._hud.get_parent().add_child(settle)
	settle.show_lines("확인 끝!", ["새로 들어간 것: %s" % feature.name, feature.new, "돈 %d (요금 %d + 팁 %d)" % [shop.money, shop.fees, shop.tips]], false)
