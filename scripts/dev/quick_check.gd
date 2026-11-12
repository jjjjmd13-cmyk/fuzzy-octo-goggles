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
const V4Save := preload("res://scripts/v4/v4_save.gd")
const FpDayTools := preload("res://scripts/dev/fp_day_tools.gd")
const StyleCompare := preload("res://scripts/dev/style_compare.gd")
## id, 메뉴 버튼, 강아지 수, 끝 화면의 "새로 들어간 것"
const FEATURES: Array[Dictionary] = [
	{"id": "day", "name": "하루 돌리기", "dogs": 2, "new": "손님 클릭으로 맡기기·돌려주기, 요금 + 팁"},
	{"id": "foam", "name": "거품·헹굼", "dogs": 1, "new": "거품은 좌우로 비비기 (몽글몽글 번짐), 헹굼은 위 → 아래로 쓸어내리기"},
	{"id": "towel", "name": "수건", "dogs": 1, "new": "헹굼 뒤 수건으로 톡톡 두드리기 (클릭할 때마다 꾹, 물방울 뚝뚝)"},
	{"id": "dryer", "name": "드라이기", "dogs": 1, "new": "헹군 뒤 드라이기로 말리기 (털 뽕·귀 펄럭)"},
	{"id": "brush", "name": "빗질", "dogs": 1, "new": "드라이 뒤 빗으로 엉킨 털 뭉치 풀기 (쓱 풀리며 반짝)"},
	{"id": "upgrade", "name": "도구 업그레이드", "dogs": 1, "new": "도구 5단계: 최종 단계(무지개 샤워기·구름 대포·구름 타월·회오리 드라이기·반짝 전동 브러시)로 시작, 숫자 1~5 로 모든 도구 단계를 바꿔 봄"},
	{"id": "trim", "name": "미용", "dogs": 1, "new": "미용 요청 손님 (곰돌이컷): 빗질 뒤 가위로 자를 곳만 사각사각, 비슷할수록 팁"},
	{"id": "morning", "name": "아침·가게 밖", "dogs": 1, "new": "아침 준비 시간 (시계 멈춤, 손님 없음) → 정문으로 나가 가게 앞 마당 (보도블록·택배 매트·우편함·가로등·울타리·화단, 찻길은 못 나감) → 문 옆 팻말을 뒤집으면 영업 시작"},
	{"id": "parcels", "name": "택배·샴푸", "dogs": 1, "new": "어제 주문한 상자 4개(택배 수레·샤워기 2단계·샴푸 1병·가위)를 아침 트럭이 매트에 내려놓음 → 정문 밖에서 상자를 두 손으로 들고 (좌우로 흔들면 달그락) 들어와 클릭해서 열기 (꽃가루 + 짜잔, 물건이 제자리로). 수레 상자를 열면 수레가 나옴: 클릭해서 밀고 매트 상자를 클릭해 싣고, 안에서 클릭하면 맨 위 상자 열기 (Q 놓기). 손님이 기다릴 때 안 연 상자를 들고 들어오면 강아지가 킁킁. 샴푸는 2마리분만 남아 있어 쓰면 줄고, 다 떨어지면 거품 없이 요금 10. 팻말을 뒤집으면 영업"},
	{"id": "decor", "name": "꾸미기", "dogs": 1, "new": "꾸미기 30개를 다 가진 상태 (모든 범주 ★3 로 시작): 벽지·바닥·목욕통·도구 선반·카운터·간판·조명·화분·러그·벽 장식. 숫자 1 = 처음 모습, 2·3·4 = 모든 범주 ★1·★2·★3 로 바꿔 보기. 하루 끝 정산 판의 [꾸미기] 탭에서 산 것끼리 바꿔 끼움"},
	{"id": "animals", "name": "고양이·성격", "dogs": 4, "new": "고양이 (머리에 물 → 냥!, 오래 젖어 있으면 싫어함, 요금 55) → 간지럼쟁이 강아지 (거품·수건 때 배·발에 오래 머물면 킥킥) → 겁쟁이 강아지 (얼굴에 물·바람이면 부르르) → 멋쟁이 고양이 (빗질을 끝까지 하면 싫어함 하나 지워 줌). 싫어함은 머리 위 💢 와 왼쪽 위 빨간 점, 돌려줄 때 얼굴·팁. 처음 나온 것은 가운데 안내 카드"},
	{"id": "mood", "name": "기분·반응", "dogs": 2, "new": "기분 점수: 좋아하는 곳(턱 밑·귀 뒤·등·엉덩이 중 하나, 거품·빗질 때 0.5초 → ♥, 가까울수록 꼬리가 빨라짐) + 30초 안에 다 씻으면 🤩 (팁 25, 반짝 + 와, 반짝반짝해!). 120초 넘게 걸리면 시무룩. 빠른 확인에서만 좋아하는 곳 이름을 알려 줌"},
	{"id": "album", "name": "사진첩", "dogs": 1, "new": "손님이 이름 있는 단골 24마리 (털 색·크기 다름, 주인 머리 위 이름표 \"콩이 ×3\"). 돌려줄 때 찰칵 + 사진 (기분 테두리). 단골 22마리를 만난 상태로 시작 → 23번째 단골을 씻겨 돌려주면 새 칸. 문 옆 작은 탁자(꾸미기 카운터가 있으면 그 위)의 사진첩 책을 클릭해서 보기 (6쪽, 칸을 누르면 단골 카드)"},
	{"id": "trust", "name": "단골 신뢰", "dogs": 3, "new": "단골마다 신뢰 4단계 (낯가림·익숙함·친함·단짝, 이름표 하트). 몽실 (낯가림, 겁쟁이 + 샤워 무서움: 발부터 적시기) → 나비 (친함 고양이 + 드라이 예민: 멀리서 켜고 천천히, 머리에 물·젖은 시간이 쉬워짐) → 짱구 (단짝: 품에서 깡충, 수건 줄다리기·배 문지르기 = 좋아함). 돌려주면 신뢰 점수가 오르고 단계가 오르면 하트가 터짐. 사진첩 카드에 첫 방문 ↔ 최근 사진, '처음 ~한 날'"},
	{"id": "accessory", "name": "액세서리", "dogs": 2, "new": "12개를 다 가진 상태. 다 씻은 동물로 바로 시작 → 목욕통 오른쪽 옆 바구니를 클릭하면 가진 것이 둥글게 펼쳐짐 → 하나 고르면 머리(리본·모자)·목(스카프)·귀 옆(꽃핀)에 씌워짐. 콩이는 리본, 나비는 꽃핀을 좋아함 (맞으면 뽐내며 좋아함 +1, \"어머, 귀여워!\"). 돌려주면 사진에 찍히고 사진첩 카드에 '좋아하는 액세서리'. 정산 판 [액세서리] 탭에서 사기 (내일 아침 작은 상자)"},
	{"id": "days", "name": "18일 점검", "dogs": 0, "new": "진짜 하루 흐름 (저장·이어하기 그대로, 저장이 있으면 이어서) + 점검 도구: F5 날 건너뛰기 · F6 건너뛰기(모두 받음) · F7 돈 +1,000 · F8 하루 결과 기록 (user://v4_day_log.csv)"},
	{"id": "style", "name": "그림체 비교", "dogs": 0, "new": "파스텔 모형 (지금) 과 실사풍 시험 모형 (art/incoming/style_real_test/real_dog·real_tub·real_bakery.glb) 을 같은 빛에 나란히. 파일이 없으면 \"아직 없음\". 1·2·3 강아지·목욕통·빵집, ←→ 돌기, ↑↓ 가까이, Esc 메뉴"},
	{"id": "save", "name": "저장·이어하기", "dogs": 1, "new": "예시 저장(4일차·돈 620·도구 단계 섞임·가위·샴푸 7.5마리분·빗 12마리·택배 상자 2개)을 파일에 쓰고 다시 읽어서 시작. 선반 도구 모양·오른쪽 위 날짜·돈이 그대로인지 봄 (진짜 저장 파일은 안 건드림)"},
]

var shop: Node3D
var feature: Dictionary


func _ready() -> void:
	feature = find(Engine.get_meta("quick_check_feature", "day"))
	if feature.id == "style":
		# 그림체 비교: 가게 대신 비교 화면
		var compare := StyleCompare.new()
		compare.name = "StyleCompare"
		add_child(compare)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	shop = SHOP_SCENE.instantiate()
	if feature.id == "days":
		# 18일 점검: 보통 게임 그대로 (저장됨), 점검 도구만 위에
		V4Save.continue_requested = V4Save.can_continue()
		add_child(shop)
		var tools := FpDayTools.new()
		tools.name = "DayTools"
		add_child(tools)
		tools.attach(shop)
		return
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
