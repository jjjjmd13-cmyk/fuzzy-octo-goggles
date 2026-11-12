extends Node3D
## V4 1인칭 회색 상자 시제품 (사람 대표 플레이 뒤 방향 전환, 2026-10-30).
##
## 가게를 걸어다니며(WASD + 마우스) 선반의 3D 도구를 집고(클릭), 목욕통의 강아지에 대고
## 누르고 있으면 쓱쓱 바로 씻긴다. 원 그리기·고정 카메라·2D 커서 없음. 큰 붓·빠른 진행.
##   샤워기 = 적시기 + 거품 헹구기 / 샴푸 = 젖은 곳에 거품 (진흙이 지워짐) / 드라이기 = 젖은 곳 말리기 (털 뽕) / 빗 = 엉킨 털 풀기 / 가위 = 미용 (요청 손님)
## 다 되면 강아지가 펄쩍 + 꼬리 흔들기. 쓰는 동안 가끔 몸 털기(물 튀김).
## 방은 코드로 만드는 임시 상자. 강아지는 V3 의 WashDog(GLB·털 셰이더·칠하기 마스크)를 그대로 쓴다.
## V3 코드는 그대로 두고 이 씬만 새로 (scenes/v4/fp_shop.tscn).

const WashDog := preload("res://scripts/sim/wash_dog.gd")
const Sfx := preload("res://scripts/game/sfx.gd")
const FpToolView := preload("res://scripts/v4/fp_tool_view.gd")
const FpPlayer := preload("res://scripts/v4/fp_player.gd")
const FpGuests := preload("res://scripts/v4/fp_guests.gd")
const TUB_SCENE := preload("res://scenes/art/sim/tub_model.tscn")
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const FpSettle := preload("res://scripts/v4/fp_settle.gd")
const FpTangles := preload("res://scripts/v4/fp_tangles.gd")
const FpTrim := preload("res://scripts/v4/fp_trim.gd")
const V4Save := preload("res://scripts/v4/v4_save.gd")
const FpOutside := preload("res://scripts/v4/fp_outside.gd")
const FpParcels := preload("res://scripts/v4/fp_parcels.gd")
const FpDecor := preload("res://scripts/v4/fp_decor.gd")
const FpAnimals := preload("res://scripts/v4/fp_animals.gd")
const FpRegulars := preload("res://scripts/v4/fp_regulars.gd")
const FpAlbum := preload("res://scripts/v4/fp_album.gd")
const FpDays := preload("res://scripts/v4/fp_days.gd")
const FpEnding := preload("res://scripts/v4/fp_ending.gd")
const FpThanks := preload("res://scripts/v4/fp_thanks.gd")
const FpTrust := preload("res://scripts/v4/fp_trust.gd")
const FpAccessory := preload("res://scripts/v4/fp_accessory.gd")
const FpGuide := preload("res://scripts/v4/fp_guide.gd")
const Settings := preload("res://scripts/core/settings.gd")
## 액세서리 바구니 자리 (목욕통 오른쪽 옆 바닥 위 작은 받침)
const BASKET_POS := Vector3(0.95, 0.45, -2.3)
const ALBUM_BOOK := "res://assets/models/album/album_book.glb"
## 가게 물건: 이름, 상자 크기 (도구 단계 올리기는 "tool:<도구>")
const SUPPLIES := {
	"shampoo_bottle": {"name": "샴푸 1병", "size": "small"},
	"shampoo_big": {"name": "샴푸 큰 통", "size": "medium"},
	"brush_refill": {"name": "새 빗살", "size": "small"},
}

## 빠른 확인에서 강아지를 다 돌려줌 (개발용 scenes/dev/quick_check.tscn 이 끝 화면을 띄움)
signal quick_finished
## 하루를 닫음 (정산 판에서 [다음 날]·엔딩으로 넘어가기 직전, 산 것까지 끝난 뒤): 하루 결과 한 덩어리 (개발용 기록·테스트)
signal day_closed(summary: Dictionary)

const PICK_LAYER := 2
const DOG_LAYER := 16
## 손이 닿는 거리 (m)
const REACH := 2.4
## 강아지가 앉는 곳 (목욕통 위)
const DOG_SPOT := Vector3(0, 0.92, -1.6)
## 도구: 이름, 칠하는 채널, 색. 붓 크기·속도·완료 기준은 Tuning.data.v4_* (GDD_V4)
## 단계마다 처음 닿을 때 반응 하나: 적시기 다리 찰랑 / 거품 펄쩍 / 헹구기 몸 털기+물 튐 / 말리기 다리 찰랑
## 단계 차례 (사람 대표 피드백: 단계가 끝난 순간을 분명하게). 끝나면 소리 + 반짝 + 가운데 글자,
## 다음에 쓸 도구가 선반에서 살짝 빛난다. tool = 그 단계에 쓰는 도구
const STAGES: Array[Dictionary] = [
	{"id": "wet", "tool": "shower", "sound": "ding", "text": "적시기 끝! 샴푸로 거품 내요"},
	{"id": "scrub", "tool": "shampoo", "sound": "bubble_pop", "text": "거품 끝! 샤워기로 헹궈요"},
	{"id": "rinse", "tool": "shower", "sound": "squeak", "text": "뽀득! 헹굼 끝! 수건으로 톡톡 닦아요"},
	{"id": "towel", "tool": "towel", "sound": "press", "text": "수건 끝! 드라이기로 말려요"},
	{"id": "dry", "tool": "dryer", "sound": "poof", "text": "뽕! 드라이 끝! 빗으로 엉킨 털을 풀어요"},
	{"id": "brush", "tool": "brush", "sound": "squeak", "text": "빗질 끝! 반짝반짝 깨끗해졌어요"},
	# 미용은 요청 손님만 (요청이 없으면 이 단계를 건너뜀)
	{"id": "trim", "tool": "scissors", "sound": "clap", "text": "미용 끝! 모양이 남았어요"},
]
## 거품 공 크기 배수 (크고 하얗게), 스스로 빛나는 정도
const FOAM_SIZE := 2.4
const FOAM_GLOW := 0.45
## 헹구기: 물줄기 둘레의 거품만 (붓 반경 × 이 값 × 1.5), 거품 공이 0.15초쯤 대면 녹음.
## 예전엔 한 번 대면 몸 전체 거품이 사라져서 다 헹궜는지 알기 어려웠음 (사람 대표 피드백)
const RINSE_REACH := 0.7
const RINSE_SPEED := 14.0
## 헹굴 때 남은 거품 공이 이만큼 이하면 거품이 살짝 반짝임 (고리·원은 정신없어서 뺌, 사람 대표 피드백)
const FOAM_SPARKLE_BELOW := 3
## 단계 진행이 이만큼 넘으면 아직 안 된 곳을 털 위에서 반짝임
const BLINK_FROM := 0.5
const STAGE_REACTION := {"wet": "wiggle_legs", "scrub": "jump", "rinse": "shake", "towel": "wiggle_legs", "dry": "wiggle_legs", "brush": "jump", "trim": "wiggle_legs"}
## 빗이 닿는 거리 = 붓 반경 × 이 값 (뭉치 하나씩 겨냥하게 붓보다 좁게)
const BRUSH_REACH := 0.8
## 수건 톡 한 번에 마른 쪽으로도 칠하는 몫 (털이 덜 젖어 보임, 드라이가 조금 쉬워짐)
const TOWEL_DRY_SHARE := 0.3
## 가위·빗을 들면 가운데 점에서 이 거리(m) 안의 다발·뭉치를 겨눔
const TARGET_PICK := 0.12
## 임시 털색 (엉킨 뭉치는 이보다 진하게)
const FUR_COLOR := Color(0.96, 0.87, 0.7)
## 도구 5단계 이름 (GDD_V4 업그레이드 — 도구마다 5단계, TUNING_V4 3-2). 단계마다 속도 v4_tool_speed_mult5, 값 v4_tool_price5
const TOOL_LEVEL_NAMES := {
	"shower": ["작은 샤워기", "넓은 샤워기", "레인 샤워기", "마사지 샤워기", "무지개 샤워기"],
	"shampoo": ["샴푸병", "거품 펌프", "거품 스펀지", "거품 대포", "구름 대포"],
	"towel": ["수건", "두꺼운 수건", "극세사 수건", "흡수 장갑", "구름 타월"],
	"dryer": ["작은 드라이기", "큰 송풍 드라이기", "이중 날개 드라이기", "터보 드라이기", "회오리 드라이기"],
	"brush": ["일반 빗", "슬리커 브러시", "쌍빗", "전동 브러시", "반짝 전동 브러시"],
}
## 단계별 모형 파일 (docs/art/ART_SLOTS.md V4 손 도구 5단계, assets/models/tools/<이름>.glb).
## 없으면 그 아래 단계 중 있는 모형을 단계만큼 조금 키워 씀
const LEVEL_MODELS := {
	"shower": ["shower", "shower_wide", "shower_rain", "shower_massage", "shower_rainbow"],
	"shampoo": ["shampoo", "foam_pump", "foam_sponge", "foam_cannon", "foam_cloud"],
	"towel": ["towel", "towel_thick", "towel_microfiber", "towel_mitt", "towel_cloud"],
	"dryer": ["dryer", "dryer_big", "dryer_twin", "dryer_turbo", "dryer_tornado"],
	"brush": ["brush", "brush_slicker", "brush_twin", "brush_electric", "brush_sparkle"],
}
## 속도 배수 중 붓 크기로 가는 몫 (1.6배 빠른 도구 = 붓 1.15배)
const SIZE_SHARE := 0.25
## 최종 단계 도구는 붓이 이만큼 더 넓음 ("와" 단계)
const FINAL_RADIUS := 1.25
const TOOLS := {
	"shower": {"name": "샤워기", "channel": "wet", "color": Color(0.7, 0.8, 0.9)},
	"shampoo": {"name": "샴푸", "channel": "scrub", "color": Color(1.0, 0.6, 0.75)},
	"towel": {"name": "수건", "channel": "towel", "color": Color(1.0, 0.75, 0.8)},
	"dryer": {"name": "드라이기", "channel": "dry", "color": Color(0.95, 0.85, 0.9)},
	"brush": {"name": "빗", "channel": "brush", "color": Color(0.75, 0.55, 0.4)},
	"scissors": {"name": "가위", "channel": "trim", "color": Color(0.85, 0.85, 0.9)},
}

## false 면 마우스·키 입력을 읽지 않는다 (테스트가 using 등을 직접 넣음)
var input_enabled := true
## 지금 도구를 쓰는 중 (왼쪽 버튼을 누르고 있음)
var using := false
## 손에 든 도구 ("" = 빈손)
var held := ""
## 바라보는 집을 수 있는 도구 ("" = 없음)
var hovered := ""
## 바라보는 강아지 위 점 (없으면 null)
var aim_point: Variant = null
var done := false
## 목욕통에 강아지가 있음 (손님이 맡기기 전엔 비어 있음)
var has_dog := false
## 빠른 확인 (개발용, add_child 전에 정함): 강아지 수 (0 = 보통 하루). 참을성·벽시계 끔, 처음부터 손님이 대기
var quick_dogs := 0
## 빠른 확인으로 볼 기능 이름 ("day", 다음 기능들이 늘어남)
var quick_feature := ""
## 바라보는 손님 (주인 노드, 없으면 null)
var hovered_guest: Node3D = null
## 가운데 점이 영업 팻말을 가리킴
var hovered_sign := false
## 아침 준비 시간: 시계가 멈춰 있고 손님이 안 옴. 팻말을 뒤집으면 영업 시작 (GDD_V4 '아침 준비 시간')
var morning := false
var outside: FpOutside
var parcels_view: FpParcels
var decor_view: FpDecor
var _tub_view: Node3D
## 들고 있는 택배 상자 (parcels 의 한 Dictionary, 비면 안 듦)
var carried := {}
var _carried_view: Node3D
## 가운데 점이 가리키는 매트 위 상자
var hovered_box := {}
## 택배 수레 (시험용): 가졌나, 노드, 미는 중인가, 실린 상자들
var owns_cart := false
var cart: StaticBody3D
var pushing_cart := false
var cart_load: Array = []
var hovered_cart := false
## 상자 흔들기 (달그락): 좌우로 방향을 바꾼 횟수, 남은 시간
var _shake_flips := 0
var _shake_dir := 0.0
var _shake_left := 0.0
## 대기 강아지 킁킁 다음 검사까지 (s)
var _sniff_left := 3.0
## 목욕통의 동물 ("dog" / "cat") 과 동물 성격 ("" / ticklish / timid / dandy, GDD_V4 '고양이·동물 성격')
var animal := "dog"
var animal_trait := ""
## 기분 점수 (GDD_V4 '기분·반응'): 좋아함 +1 (각각 한 번, 최대 +3) · 싫어함 −1 (바닥 v4_mood_floor). 얼굴 4단계는 점수로
var mood_score := 0
var _likes := {}
## 좋아하는 곳 (턱 밑·귀 뒤·등·엉덩이 중 하나), 거기 머문 시간, 목욕대에 올린 시각
var fav_spot := ""
var _fav_time := 0.0
var _tub_start := 0.0
## 손님 사진첩 (GDD_V4 '손님 사진첩', 저장됨): 단골 id → {visits, best_mood, day, trim, wall, floor, fav_found}
var album: Dictionary = {}
var album_rewards_taken: Array = []
var regulars_met_order: Array = []
## 목욕통의 단골 id ("" = 단골 아님, 테스트·빠른 확인)
var regular := ""
## 18일 흐름 (GDD_V4 '18일 전체 흐름'): 엔딩을 봤나, 단체 사진에 선 단골 (저장됨)
var ending_seen := false
var group_photo: Array = []
## 오늘 정산 가게에서 산 것 [{id, price}] (하루 결과 기록)
var bought_today: Array = []
var _day_closed := false
## 엔딩 (감사의 날 FpThanks) 이 진행 중이면 그 노드
var _ending: Node
## 단골 신뢰 (GDD_V4 '단골 신뢰'): 목욕통 단골의 신뢰 단계 (0 낯가림 ~ 3 단짝, 단골 아니면 0)·도구 버릇 ("" / shower / dryer / towel)
var trust_tier := 0
var quirk := ""
## 버릇 상태: 샤워 무서움 (발부터 적셨나·샤워 시간), 드라이 (켜고 누른 시간·'가까이' 안에 있었나), 수건 (물었나·흔든 횟수)
var _quirk_feet := false
var _shower_time := 0.0
var _dryer_hold := 0.0
var _dryer_inside := false
var towel_bitten := false
## 이번 목욕에서 버릇을 넘었나 (돌려줄 때 사진첩 '처음 ~한 날')
var _quirk_overcome := false
## 액세서리 (GDD_V4 '액세서리'): 가진 것 (저장), 지금 동물이 쓴 것, 좋아하는 범주였나
var acc_owned: Array = []
var acc_on := ""
var _acc_liked := false
var _acc_basket: StaticBody3D
var _acc_menu: Control
var hovered_basket := false
## 처음 하는 사람 안내 (LAUNCH_PREP 2장): 한 번씩만, 본 것은 저장
var guide: FpGuide
var _towel_flips := 0
var _towel_dir := 0.0
var _card_title := "새 손님!"
var _album_view: Control
var _album_book: StaticBody3D
var hovered_book := false
var _flash := 0.0
## 오늘 가장 기뻐한 손님 (정산): 얼굴, 동물
var best_face := -1
var best_animal := ""
var _heart: Label3D
## 규칙마다 싫어함 수·마지막 시각 (같은 규칙 v4_dislike_cooldown 초에 한 번, 손님마다 최대)
var _rule_count := {}
var _rule_last := {}
## 고양이: 물이 닿기 시작했나·그 시각 (_t), 젖은 시간 검사를 했나
var _wet_started := false
var _wet_since := 0.0
var _wet_checked := false
## 간지럼쟁이: 아래쪽 한 곳에 머문 곳·시간
var _tickle_at: Variant = null
var _tickle_time := 0.0
## 한 번이라도 나온 고양이·성격 (처음이면 가운데 안내 카드, 저장됨)
var seen_animals: Array = []
var _card := ""
var _card_left := 0.0
## 머리 위 💢 (싫어함 표시)
var _anger: Label3D
## 지금 강아지는 샴푸 없이 씻음 (요금 v4_no_shampoo_price, 팁 0)
var no_shampoo := false
## 오늘 번 돈 = 요금 + 팁
var money := 0
var fees := 0
var tips := 0
## 하루 영업 (s): 문 연 뒤 지난 시간 / 영업 시간 (v4_day_minutes, 9시~6시)
var day_time := 0.0
var day_seconds := 0.0
var day_over := false
## 지금 강아지 주인 정보: 성격·들어온 시각 (팁 계산)
var _taken := {}
## 손동작: 이번 프레임 손(가운데 점이 가리키는 자리) 이 움직인 양 (월드, m). 단계마다 다른 손동작 판정에 씀
var hand_move := Vector3.ZERO
var _last_hand: Variant = null
## _process 가 광선으로 손 자리를 잰 프레임 (아니면 use_tool_at 에 온 점으로 잼: 테스트)
var _hand_tracked := false
var _huff_left := 0.0
var _final_left := 0.0
## 엉킨 털 뭉치 (강아지 모형의 자식, 새 강아지마다 새로)
var tangles: FpTangles
## 도구 단계 (0 = 기본). 정산 뒤 가게에서 사면 오름
var tool_level := {"shower": 0, "shampoo": 0, "towel": 0, "dryer": 0, "brush": 0}
## 며칠째 (가진 돈·도구는 다음 날로 이어짐, 저장은 아직 없음)
var day := 1
## 가위를 샀음 (다음 손님부터 미용 요청이 옴)
var owns_scissors := false
## 저장·이어하기에 들어가는 관리 값 (규칙은 다음 PR: 샴푸 소모·빗 닳음 TUNING_V4 3-5, 꾸미기 3-3, 택배 3-4)
var shampoo_left := 0.0
var brush_used := 0
var decor := {"owned": [], "placed": {}}
## 가게 앞에 도착했지만 아직 안 들인 상자 (V4Save.fresh 의 parcels 모양)
var parcels: Array = []
## 지금 강아지의 미용 요청 모양 ("" = 없음)
var trim_request := ""
## 미용 다발 (강아지 모형의 자식, 새 강아지마다 새로)
var trim: FpTrim
var _settle: Control
## 지금 단계 (STAGES 번호, 4 = 다 끝남)
var stage_index := 0
## 남은 거품이 반짝이는 중 (헹굴 때 몇 개 안 남았을 때)
var foam_sparkle := false
var dog: WashDog
var player: CharacterBody3D
var sfx: Node
## 대기 의자 손님들 (참을성)
var guests: FpGuests

var _pickups := {}
var _held_view: FpToolView
var _returning_views: Array[FpToolView] = []
var _glow_materials := {}
var _rng := RandomNumberGenerator.new()
var _foam_carry := 0.0
var _reacted := {}
var _hint := ""
var _hint_left := 0.0
var _hud: Control
var _banner := ""
var _banner_left := 0.0
var _sparkle: CPUParticles3D
var _t := 0.0
var _dogs := 0


func _ready() -> void:
	_rng.randomize()
	_build_room()
	_build_shelf()
	sfx = Sfx.new()
	add_child(sfx)
	dog = WashDog.new()
	dog.name = "Dog"
	dog.position = DOG_SPOT
	dog.rotation.y = PI * 0.15
	dog.foam_glow = FOAM_GLOW
	add_child(dog)
	_build_stage_effects()
	guests = FpGuests.new()
	guests.name = "Guests"
	if quick_dogs > 0:
		guests.quick = true
		guests.opening_override = []
		for i in quick_dogs:
			guests.opening_override.append("normal")
	add_child(guests)
	guests.guest_left.connect(_on_guest_left)
	guests.guest_arrived.connect(_on_guest_arrived)
	_build_player()
	outside = FpOutside.new()
	outside.name = "Outside"
	add_child(outside)
	outside.watch = player
	outside.door_opened.connect(func() -> void: sfx.play("bell"))
	parcels_view = FpParcels.new()
	parcels_view.name = "Parcels"
	parcels_view.mat_center = FpOutside.MAT_POS
	add_child(parcels_view)
	parcels_view.delivered.connect(_on_delivered)
	decor_view = FpDecor.new()
	decor_view.name = "Decor"
	add_child(decor_view)
	decor_view.defaults = {"tub": [_tub_view], "shelf": [get_node("Shelf")]}
	for wall in ["WallBack", "WallFront", "WallLeft"]:
		decor_view.wall_meshes.append(get_node(wall).get_child(1) as MeshInstance3D)
	decor_view.floor_meshes.append(get_node("Floor").get_child(1) as MeshInstance3D)
	guests.album = album
	_build_hud()
	day_seconds = Tuning.data.v4_day_minutes * 60.0
	# 가위는 사기 전엔 선반에 없음
	if quick_feature == "trim":
		owns_scissors = true
	_set_pickup_available("scissors", owns_scissors)
	shampoo_left = float(Tuning.data.v4_shampoo_start)
	acc_owned = Array(Tuning.data.v4_acc_start).duplicate()
	if quick_feature == "accessory":
		acc_owned = FpAccessory.all_items()
	_place_acc_basket()
	if quick_feature == "save":
		_quick_save_round_trip()
	elif V4Save.continue_requested and quick_dogs == 0:
		V4Save.continue_requested = false
		var saved := V4Save.read()
		if not saved.is_empty():
			apply_state(saved)
	if quick_feature == "upgrade":
		# 빠른 확인 [도구 업그레이드]: 모든 도구를 가장 좋은 것으로 산 상태, 숫자 1~5 로 단계를 바꿔 봄
		set_all_tiers(Tuning.data.v4_tool_tiers - 1)
		_show_hint("최종 단계 도구예요. 숫자 1~5: 모든 도구 단계 바꾸기", 5.0)
	_apply_day()
	new_dog()
	_clear_tub()
	# 이미 매트에 도착한 상자 (이어하기)
	parcels_view.place(parcels.filter(func(box: Dictionary) -> bool: return box.get("arrived", true)))
	# 빠른 확인은 바로 영업 (단, [아침·가게 밖]·[택배] 는 아침부터)
	if quick_feature == "album":
		_quick_album()
	elif quick_feature == "trust":
		_quick_trust()
	elif quick_feature == "accessory":
		guests.quick_animals = [{"regular": "kongi"}, {"regular": "nabi"}]
	if quick_feature == "animals":
		# 빠른 확인 [고양이·성격]: 고양이 → 간지럼쟁이 → 겁쟁이 → 멋쟁이 고양이
		guests.quick_animals = [{"animal": "cat", "trait": ""}, {"animal": "dog", "trait": "ticklish"}, {"animal": "dog", "trait": "timid"}, {"animal": "cat", "trait": "dandy"}]
	if quick_feature == "parcels":
		_quick_parcels()
	elif quick_feature == "decor":
		_quick_decor(3)
	if quick_dogs == 0 or quick_feature in ["morning", "parcels"]:
		_start_morning()
	else:
		outside.set_sign(true, true)
		for box in parcels:
			if not box.get("arrived", true):
				box.arrived = true
				parcels_view.place([box])
	if quick_feature == "save" or day > 1:
		_show_hint(_continue_hint(), 6.0)
	elif not morning:
		_show_hint("손님이 오면 다가가서 클릭: 강아지 맡기", 4.0)


## 아침: 시계 멈춤, 손님 안 옴 (팻말은 달). 택배를 들이고 꾸미는 시간
func _start_morning() -> void:
	morning = true
	guests.open = false
	guests.process_mode = Node.PROCESS_MODE_DISABLED
	outside.set_sign(false, true)
	_show_hint("%d일차 아침 · 문 옆 팻말을 뒤집으면 영업 시작 (정문으로 밖에 나가 볼 수 있어요)" % day, 6.0)
	# 처음 안내: 걷기 → 팻말 (팻말 위 ▼, 영업을 시작하면 사라짐)
	if not guide.show_tip("walk"):
		guide.show_tip("sign", outside.sign_body, func() -> bool: return not morning)
	# 그날 새로 열리는 것 한 줄 (빠른 확인은 안 띄움)
	var news := FpDays.notice(day)
	if not news.is_empty() and quick_feature.is_empty() and quick_dogs == 0:
		_card = news
		_card_title = "%d일차 아침" % day
		_card_left = 8.0
	# 어제 주문한 상자: 트럭이 와서 매트에 내려놓음
	var coming := parcels.filter(func(box: Dictionary) -> bool: return not box.get("arrived", true))
	parcels_view.deliver(coming, Tuning.data.v4_truck_seconds)
	if not coming.is_empty():
		sfx.play("bell")


## 트럭이 상자를 내려놓음: 우편함 깃발, 안내, 저장 (도착했음)
func _on_delivered(count: int) -> void:
	outside.set_mailbox_flag(true)
	sfx.play("coin")
	_show_hint("빵빵! 택배 상자 %d개가 왔어요 (정문 밖 매트에서 들고 들어와 열어요)" % count, 5.0)
	var first_box: Array = parcels_view.box_nodes()
	if not first_box.is_empty():
		guide.show_tip("parcel", first_box[0], func() -> bool: return not carried.is_empty() or parcels_view.box_nodes().is_empty())
	if morning:
		save_game(day)


## 매트 위 상자를 두 손으로 듦 (도구는 내려놓음, 큰 상자는 느리게 걸음)
func carry_box(box: Dictionary) -> void:
	if not carried.is_empty():
		return
	var node := parcels_view.node_of(box)
	if node == null:
		return
	drop()
	parcels_view.take(node)
	node.queue_free()
	carried = box
	_carried_view = parcels_view.make_box_view(box.size)
	_carried_view.position = Vector3(0, -0.55, -0.7)
	player.camera.add_child(_carried_view)
	var speeds: PackedFloat32Array = Tuning.data.v4_box_carry_speed
	player.speed_mult = speeds[clampi(FpParcels.SIZES.find(box.size), 0, speeds.size() - 1)]
	sfx.play("press")
	if parcels_view.box_nodes().is_empty():
		outside.set_mailbox_flag(false)


## 들고 있는 상자 열기 (가게 안에서만): 물건이 제자리로 (도구 단계·샴푸·새 빗살·가위)
func open_box() -> bool:
	if carried.is_empty():
		return false
	if FpOutside.is_outside(player.global_position):
		_show_hint("가게 안에서 열어요", 1.5)
		return false
	var box := carried
	carried = {}
	var at := _carried_view.global_position
	_carried_view.queue_free()
	_carried_view = null
	player.speed_mult = 1.0
	_open_parcel(box, at)
	return true


## 상자 하나 열기: 물건이 제자리로 + 꽃가루 (★3 꾸미기·5단계 도구는 무지개) + 짜잔
func _open_parcel(box: Dictionary, at: Vector3) -> void:
	var name := item_name(box.item)
	apply_item(box.item)
	parcels.erase(box)
	var rainbow := false
	if box.item.begins_with("decor:"):
		rainbow = FpDecor.stars_of(box.item.trim_prefix("decor:")) == 3
	elif box.item.begins_with("tool:"):
		rainbow = is_final(box.item.trim_prefix("tool:"))
	_confetti(at, rainbow)
	sfx.play("tada")
	_banner = "짜잔! %s" % name
	_banner_left = 2.0
	if morning:
		save_game(day)


## 종이 꽃가루 한 번 (rainbow = 무지개색)
func _confetti(at: Vector3, rainbow: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "Confetti"
	particles.set_meta("confetti", "rainbow" if rainbow else "plain")
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 60 if rainbow else 36
	particles.lifetime = 1.4
	particles.direction = Vector3.UP
	particles.spread = 55.0
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 2.2
	particles.gravity = Vector3(0, -2.5, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.06, 0.04)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 종이 조각이 늘 카메라를 보게 (위에서 내려다봐도 보임)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = material
	particles.mesh = mesh
	var ramp := Gradient.new()
	if rainbow:
		ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
		ramp.colors = PackedColorArray([Color(1, 0.35, 0.4), Color(1, 0.65, 0.3), Color(1, 0.95, 0.4), Color(0.45, 0.9, 0.5), Color(0.4, 0.7, 1.0), Color(0.75, 0.5, 1.0)])
	else:
		ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		ramp.colors = PackedColorArray([Color(1, 0.7, 0.8), Color(1, 0.95, 0.6), Color(0.7, 0.9, 1.0)])
	particles.color_initial_ramp = ramp
	add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


## 수레를 그 자리에 놓음 (처음 열었을 때·이어하기)
func _place_cart(at: Vector3) -> void:
	if cart == null:
		cart = parcels_view.make_cart()
		add_child(cart)
	cart.global_position = at
	cart.rotation.y = PI / 2.0


## 수레 밀기 시작 / 놓기 (Q)
func push_cart(on: bool) -> void:
	if cart == null or pushing_cart == on:
		return
	if on and not carried.is_empty():
		_show_hint("상자를 들고 있으면 수레를 못 밀어요", 1.5)
		return
	if on:
		drop()
	pushing_cart = on
	cart.collision_layer = 0 if on else 1 << (PICK_LAYER - 1)
	player.speed_mult = Tuning.data.v4_cart_speed if on else 1.0
	if on:
		_show_hint("수레: 매트 위 상자를 클릭해 싣기 · 가게 안에서 클릭 = 맨 위 상자 열기 · Q 놓기", 4.0)


## 수레에 실린 칸 (큰 상자 = 2칸)
func cart_used() -> int:
	var used := 0
	for box in cart_load:
		used += 2 if box.size == "large" else 1
	return used


## 매트 위 상자를 수레에 싣기 (칸이 모자라면 false)
func load_cart(box: Dictionary) -> bool:
	if not pushing_cart:
		return false
	var need := 2 if box.size == "large" else 1
	if cart_used() + need > Tuning.data.v4_cart_slots:
		_show_hint("수레가 꽉 찼어요 (%d칸)" % Tuning.data.v4_cart_slots, 1.5)
		return false
	var node := parcels_view.node_of(box)
	if node == null:
		return false
	parcels_view.take(node)
	node.queue_free()
	var view := parcels_view.make_box_view(box.size)
	view.name = "Loaded_%d" % cart_load.size()
	cart.get_node("Load").add_child(view)
	# 칸 순서대로 짐칸 앞에서 뒤로, 넘치면 위에 쌓음
	var slot := cart_used()
	view.position = Vector3(0, 0.3 * (slot / 3), -0.2 + 0.2 * (slot % 3))
	cart_load.append(box)
	sfx.play("press")
	if parcels_view.box_nodes().is_empty():
		outside.set_mailbox_flag(false)
	return true


## 수레 맨 위 상자 열기 (가게 안에서만)
func open_cart_box() -> bool:
	if not pushing_cart or cart_load.is_empty():
		return false
	if FpOutside.is_outside(player.global_position):
		_show_hint("가게 안에서 열어요", 1.5)
		return false
	var box: Dictionary = cart_load.pop_back()
	var load_node := cart.get_node("Load")
	var view := load_node.get_child(load_node.get_child_count() - 1) as Node3D
	var at := view.global_position
	load_node.remove_child(view)
	view.queue_free()
	_open_parcel(box, at)
	return true


## 상자를 들고 마우스를 좌우로 흔듦: 방향이 3번 바뀌면 달그락 + 무엇이 들었는지 안내
func shake_box(dx: float) -> void:
	if carried.is_empty() or absf(dx) < 3.0:
		return
	var dir := signf(dx)
	if dir != _shake_dir:
		_shake_dir = dir
		_shake_flips += 1
		_shake_left = 0.5
		if _carried_view != null:
			_carried_view.rotation.z = 0.12 * dir
	if _shake_flips >= 3:
		_shake_flips = 0
		sfx.play("rattle")
		_show_hint("달그락… %s 같아요" % item_name(carried.item), 2.0)


## 수건을 문 손님: 마우스를 좌우로 세 번 흔들면 놓음
func shake_towel(dx: float) -> void:
	if not towel_bitten or absf(dx) < 3.0:
		return
	var dir := signf(dx)
	if dir != _towel_dir:
		_towel_dir = dir
		_towel_flips += 1
	if _towel_flips >= 3:
		towel_bitten = false
		_towel_flips = 0
		_show_hint("놓았어요! 다시 톡톡", 1.2)


## 가게 안에 안 연 상자가 있으면 (들고 들어왔거나 수레에) 대기 강아지가 가끔 냄새를 맡음
func _update_sniff(delta: float) -> void:
	_sniff_left -= delta
	if _sniff_left > 0.0:
		return
	_sniff_left = 6.0
	var target: Variant = null
	if not carried.is_empty() and not FpOutside.is_outside(player.global_position):
		target = _carried_view.global_position
	elif cart != null and not cart_load.is_empty() and not FpOutside.is_outside(cart.global_position):
		target = cart.global_position
	if target == null:
		return
	for i in guests.guests.size():
		if _rng.randf() < Tuning.data.v4_box_sniff_chance:
			guests.sniff(i, target)


## 팻말을 해 쪽으로 뒤집음 → 영업 시작 (8분 시계가 감, 첫 손님이 곧 옴)
func open_shop() -> void:
	if not morning:
		return
	morning = false
	day_time = 0.0
	guests.process_mode = Node.PROCESS_MODE_INHERIT
	guests.open = true
	outside.set_sign(true)
	parcels_view.finish_now()
	sfx.play("bell")
	var left_outside := parcels_view.box_nodes().size()
	# 벌칙 없음: 상자는 매트에 그대로, 영업 중에도 가져와도 됨
	_show_hint("영업 시작! 손님이 와요" + (" (택배 상자 %d개가 아직 밖에 있어요)" % left_outside if left_outside > 0 else ""), 3.5)


## 지금 상태 → 저장 Dictionary (next_day = 이어하면 시작할 날)
func save_state(next_day: int) -> Dictionary:
	return {
		"next_day": next_day,
		"money": money,
		"tool_level": tool_level.duplicate(),
		"owns_scissors": owns_scissors,
		"owns_cart": owns_cart,
		"seen_animals": seen_animals.duplicate(),
		"album": album.duplicate(true),
		"album_rewards_taken": album_rewards_taken.duplicate(),
		"regulars_met_order": regulars_met_order.duplicate(),
		"shampoo_left": shampoo_left,
		"brush_used": brush_used,
		"decor": decor.duplicate(true),
		"parcels": parcels.duplicate(true),
		"acc_owned": acc_owned.duplicate(),
		"guide_seen": guide.seen.duplicate(),
		"ending_seen": ending_seen,
		"group_photo": group_photo.duplicate(),
	}


## 저장 Dictionary (V4Save.read / normalize 모양) → 가게에 적용: 그날 처음부터
func apply_state(data: Dictionary) -> void:
	day = data.next_day
	guests.day = day
	seen_animals = data.get("seen_animals", []).duplicate()
	# 사진첩은 같은 Dictionary 를 손님 쪽과 나눠 씀 (새로 만들지 않고 내용만 바꿈)
	album.clear()
	album.merge(data.get("album", {}).duplicate(true))
	album_rewards_taken = data.get("album_rewards_taken", []).duplicate()
	regulars_met_order = data.get("regulars_met_order", []).duplicate()
	money = data.money
	for tool_id in data.tool_level:
		if tool_level.has(tool_id) and tool_level[tool_id] != data.tool_level[tool_id]:
			set_tier(tool_id, data.tool_level[tool_id])
	owns_scissors = data.owns_scissors
	owns_cart = data.get("owns_cart", false)
	if owns_cart:
		_place_cart(Vector3(2.7, 0, 1.4))
	_set_pickup_available("scissors", owns_scissors)
	guests.trim_chance = Tuning.data.v4_trim_request_ratio if owns_scissors else 0.0
	acc_owned = data.get("acc_owned", Array(Tuning.data.v4_acc_start)).duplicate()
	guide.seen = data.get("guide_seen", []).duplicate()
	ending_seen = data.get("ending_seen", false)
	group_photo = data.get("group_photo", []).duplicate()
	shampoo_left = data.shampoo_left
	brush_used = data.brush_used
	decor = data.decor.duplicate(true)
	parcels = data.parcels.duplicate(true)
	_apply_decor()


## 저장 (빠른 확인에서는 안 함). 영업 중에는 부르지 않음
func save_game(next_day: int) -> bool:
	if quick_dogs > 0 or not quick_feature.is_empty():
		return false
	return V4Save.write(save_state(next_day))


## 이어할 때 한 줄: 날짜·돈·밖에 남은 택배 상자
func _continue_hint() -> String:
	var line := "%d일차 이어하기 · 돈 %d" % [day, money]
	var outside_count := parcels.filter(func(box: Dictionary) -> bool: return box.get("arrived", true)).size()
	if outside_count > 0:
		line += " · 밖에 택배 상자 %d개 (아직 안 들임)" % outside_count
	if morning:
		line += " · 문 옆 팻말을 뒤집으면 영업 시작"
	return line


## 빠른 확인 [꾸미기]: 30개를 다 가진 상태, 숫자 1 = 처음 모습, 2·3·4 = 모든 범주 ★1·★2·★3
func _quick_decor(level: int) -> void:
	for category in FpDecor.CATEGORIES:
		for item in FpDecor.CATEGORIES[category].items:
			if not decor.owned.has(item[0]):
				decor.owned.append(item[0])
		if level <= 0:
			decor.placed.erase(category)
		else:
			decor.placed[category] = FpDecor.CATEGORIES[category].items[mini(level, 3) - 1][0]
	_apply_decor()
	_show_hint("꾸미기 %s · 아늑함 ★%d (숫자 1 처음 · 2 ★1 · 3 ★2 · 4 ★3)" % ["처음 모습" if level <= 0 else "★%d" % mini(level, 3), FpDecor.coziness(decor.placed)], 4.0)


## 빠른 확인 [사진첩]: 단골 22마리를 만난 상태 (기분 섞임, 보상 20마리까지 받음), 남은 2마리 중 하나가 옴 → 23
func _quick_album() -> void:
	var table := FpRegulars.all()
	for i in 22:
		var id: String = table[i].id
		album[id] = {"visits": 1 + i % 4, "best_mood": i % 4, "day": 1 + i % 10, "trim": "", "wall": "", "floor": "", "fav_found": i % 3 == 0}
		regulars_met_order.append(id)
	album_rewards_taken = [5, 10, 15, 20]
	guests.quick_animals = [{"regular": table[22].id}]
	_apply_decor()


## 빠른 확인 [단골 신뢰]: 대표 단골 3마리 — 몽실 낯가림 (겁쟁이 + 샤워 무서움) → 나비 친함 (고양이 + 드라이 예민) → 짱구 단짝 (수건 놀이·배 보여 줌)
func _quick_trust() -> void:
	var at: PackedInt32Array = Tuning.data.v4_trust_at
	var setup := [["mongsil", 0], ["nabi", 2], ["jjanggu", 3]]
	guests.quick_animals = []
	for item in setup:
		var id: String = item[0]
		var tier: int = item[1]
		if tier > 0:
			var entry := FpTrust.empty_entry(1)
			entry.visits = tier * 2
			entry.best_mood = 2
			entry.trust = tier
			entry.trust_pts = at[tier - 1]
			entry.first = FpTrust.photo_info(1, 1, "", "", "")
			entry.recent = FpTrust.photo_info(3, 2, "", "", "")
			FpTrust.add_moment(entry, "first", 1)
			for t in range(1, tier + 1):
				FpTrust.add_moment(entry, "trust_%d" % t, 1 + t)
			album[id] = entry
			regulars_met_order.append(id)
		guests.quick_animals.append({"regular": id})


## 빠른 확인 [택배]: 어제 주문한 상자 3개 (샤워기 2단계·샴푸 1병·가위)가 아침 트럭으로 옴, 샴푸는 2마리분 남음
func _quick_parcels() -> void:
	money = 500
	shampoo_left = 2.0
	for id in ["cart", "shower", "shampoo_bottle", "scissors"]:
		money += next_price(id)
		order(id)


## 빠른 확인 [저장·이어하기]: 예시 상태를 따로 된 파일에 쓰고 다시 읽어서 적용 (진짜 저장 파일은 안 건드림)
func _quick_save_round_trip() -> void:
	var sample := V4Save.fresh()
	sample.next_day = 4
	sample.money = 620
	sample.tool_level = {"shower": 2, "shampoo": 1, "towel": 3, "dryer": 0, "brush": 4}
	sample.owns_scissors = true
	sample.shampoo_left = 7.5
	sample.brush_used = 12
	sample.parcels = [{"item": "shampoo_bottle", "kind": "shampoo", "size": "small"}, {"item": "plant_round", "kind": "decor", "size": "medium"}]
	var real_path := V4Save.path
	V4Save.path = "user://v4_quick_save.json"
	V4Save.write(sample)
	var loaded := V4Save.read()
	V4Save.erase()
	V4Save.path = real_path
	apply_state(loaded)


## 목욕통에 올 동물·성격을 정함 (모형은 다음 new_dog 에서). 기분·규칙 셈을 새로, 처음 나온 것이면 안내 카드
func _set_animal(kind: String, trait_id: String) -> void:
	animal = kind
	animal_trait = trait_id
	dog.model_scene = FpAnimals.scene_of(animal)
	mood_score = 0
	_likes.clear()
	fav_spot = Tuning.data.v4_fav_spots[_rng.randi() % Tuning.data.v4_fav_spots.size()]
	_fav_time = 0.0
	_tub_start = _t
	_rule_count.clear()
	_rule_last.clear()
	_wet_started = false
	_wet_since = 0.0
	_wet_checked = false
	_tickle_at = null
	_tickle_time = 0.0
	trust_tier = 0
	quirk = ""
	_quirk_feet = false
	_shower_time = 0.0
	_dryer_hold = 0.0
	_dryer_inside = false
	towel_bitten = false
	_towel_flips = 0
	_quirk_overcome = false
	var news: Array = []
	if animal == "cat" and not seen_animals.has("cat"):
		news.append(FpAnimals.CAT_INTRO % int(Tuning.data.v4_cat_price))
		seen_animals.append("cat")
	if FpAnimals.TRAITS.has(trait_id) and not seen_animals.has(trait_id):
		news.append(FpAnimals.TRAITS[trait_id].intro)
		seen_animals.append(trait_id)
	if not news.is_empty():
		_card = "\n".join(news)
		_card_title = "새 손님!"
		_card_left = 8.0


## 지금 싫어함 수 (기분 점수의 음수 쪽)
func dislikes() -> int:
	return maxi(-mood_score, 0)


## 싫어함 1: 짧은 반응 + 머리 위 💢. 같은 규칙은 쉬는 시간·최대가 있음 (넘으면 반응만). 씻기는 안 멈춤
func dislike(rule: String, max_count: int = -1, reaction := "") -> bool:
	if max_count < 0:
		max_count = Tuning.data.v4_dislike_max_per_rule
	# 신뢰: 익숙함부터 싫어함 사이가 길고, 단짝은 규칙마다 1번까지
	max_count = FpTrust.max_per_rule(trust_tier, max_count)
	if not reaction.is_empty():
		dog.react(reaction)
	if _t - _rule_last.get(rule, -999.0) < FpTrust.cooldown(trust_tier):
		return false
	_rule_last[rule] = _t
	if _rule_count.get(rule, 0) >= max_count:
		return false
	_rule_count[rule] = _rule_count.get(rule, 0) + 1
	mood_score = maxi(mood_score - 1, Tuning.data.v4_mood_floor)
	dog.react("set_mood", 0)
	sfx.play("huff")
	_show_anger()
	return true


## 돌려줄 때 자동 사진 (모든 기분): 단골마다 가장 좋은 한 장만, 처음이면 칸이 열림. 찰칵 + 화면 살짝 하얗게
func take_photo(mood: int) -> void:
	if regular.is_empty():
		return
	var is_new := not album.has(regular)
	var entry: Dictionary = album.get(regular, FpTrust.empty_entry(day))
	# 빠진 키 채움 (신뢰가 들어오기 전 저장)
	for key in FpTrust.empty_entry(day):
		if not entry.has(key):
			entry[key] = FpTrust.empty_entry(int(entry.get("day", day)))[key]
	entry.visits = int(entry.visits) + 1
	var fav_first: bool = _likes.has("fav") and not entry.fav_found
	entry.fav_found = entry.fav_found or _likes.has("fav")
	var info := FpTrust.photo_info(day, mood, trim_request, decor.placed.get("wall", ""), decor.placed.get("floor", ""))
	info["acc"] = acc_on
	var better := mood > int(entry.best_mood)
	if better:
		entry.best_mood = mood
		entry.day = day
		entry.trim = trim_request
		entry.wall = info.wall
		entry.floor = info.floor
		entry["acc"] = acc_on
	if is_new:
		entry.first = info
		entry.first_day = day
		FpTrust.add_moment(entry, "first", day)
	entry.recent = info
	entry.moods.append(mood)
	if entry.moods.size() > FpTrust.MOOD_LOG_MAX:
		entry.moods = entry.moods.slice(-FpTrust.MOOD_LOG_MAX)
	if mood == 3:
		FpTrust.add_moment(entry, "mood_3", day)
	if fav_first:
		FpTrust.add_moment(entry, "fav", day)
	if not trim_request.is_empty():
		FpTrust.add_moment(entry, "trim", day)
	if _acc_liked:
		entry["acc_found"] = true
		FpTrust.add_moment(entry, "acc_like", day)
	if _quirk_overcome and not quirk.is_empty():
		FpTrust.add_moment(entry, "quirk_" + quirk, day)
	# 신뢰: 점수는 줄 수 있어도 단계는 안 내려감
	entry.trust_pts = int(entry.trust_pts) + FpTrust.visit_points(mood, fav_first)
	var old_tier := int(entry.trust)
	entry.trust = maxi(old_tier, FpTrust.tier_of(int(entry.trust_pts)))
	for tier in range(old_tier + 1, int(entry.trust) + 1):
		FpTrust.add_moment(entry, "trust_%d" % tier, day)
	album[regular] = entry
	if is_new:
		regulars_met_order.append(regular)
	sfx.play("press")
	_flash = 0.35
	var name: String = FpRegulars.get_regular(regular).get("name", "")
	if is_new:
		guide.show_tip("photo")
	if int(entry.trust) > old_tier:
		_banner = "♥ %s 가 더 친해졌어요! (%s)" % [name, FpTrust.NAMES[int(entry.trust)]]
		_banner_left = 2.5
		sfx.play("tada")
		_heart_burst()
	elif is_new:
		_banner = "찰칵! %s 의 첫 사진 (만난 단골 %d / %d)" % [name, album.size(), FpRegulars.all().size()]
		_banner_left = 2.0
	elif better:
		_banner = "찰칵! %s 새 사진!" % name
		_banner_left = 1.5
	_check_album_rewards()


## 신뢰 단계가 오를 때 하트가 터짐 (주인 쪽, 분홍 하트 여러 개)
func _heart_burst() -> void:
	var at: Vector3 = guests.current.global_position + Vector3(0, 1.3, 0) if guests.current != null else dog.global_position + Vector3(0, 0.6, 0)
	for i in 6:
		var heart := Label3D.new()
		heart.text = "♥"
		heart.font_size = 64
		heart.outline_size = 10
		heart.modulate = Color(1.0, 0.45, 0.6)
		heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		heart.no_depth_test = true
		add_child(heart)
		heart.global_position = at
		var angle := TAU * i / 6.0
		var tween := heart.create_tween()
		tween.tween_property(heart, "global_position", at + Vector3(cos(angle) * 0.4, 0.3 + 0.2 * sin(angle), sin(angle) * 0.4), 0.8)
		tween.parallel().tween_property(heart, "modulate:a", 0.0, 0.8)
		tween.tween_callback(heart.queue_free)


## 만난 단골 수 보상 (5·10·15·20 마리 = 50·100·150·200 돈, 바로), 24마리 = 사진 게시판
func _check_album_rewards() -> void:
	var milestones: PackedInt32Array = Tuning.data.v4_album_milestones
	for i in milestones.size():
		if album.size() >= milestones[i] and not album_rewards_taken.has(milestones[i]):
			album_rewards_taken.append(milestones[i])
			var reward: int = Tuning.data.v4_album_rewards[i]
			money += reward
			sfx.play("coin")
			_show_hint("단골 %d마리를 만났어요! 보상 %d" % [milestones[i], reward], 3.0)
	var all_count := FpRegulars.all().size()
	if album.size() >= all_count and not album_rewards_taken.has(all_count):
		album_rewards_taken.append(all_count)
		decor.owned.append(FpDecor.PHOTO_BOARD)
		decor.placed["art"] = FpDecor.PHOTO_BOARD
		_apply_decor()
		_banner = "단골 24마리를 모두 만났어요! 사진 게시판이 벽에 걸렸어요"
		_banner_left = 3.0


## 사진 게시판에 붙일 사진: 금색 먼저, 그다음 분홍 (최대 v4_photo_board_slots)
func board_photos() -> Array:
	var photos := []
	for mood in [3, 2]:
		for id in regulars_met_order:
			if int(album.get(id, {}).get("best_mood", -1)) == mood:
				photos.append({"mood": mood, "regular": id})
	return photos.slice(0, Tuning.data.v4_photo_board_slots)


## 사진첩 화면 열기 (정산 판 버튼·사진첩 책)
func open_album() -> void:
	if is_instance_valid(_album_view):
		return
	_album_view = FpAlbum.new()
	_album_view.name = "Album"
	_album_view.group_photo = group_photo
	_hud.get_parent().add_child(_album_view)
	_album_view.open(album)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_album_view.closed.connect(func() -> void:
		if input_enabled and not day_over:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)


## 사진첩 책: 꾸미기 카운터가 있으면 그 위, 없으면 문 옆 작은 탁자 위 (album_book.glb, 없으면 분홍 상자)
func _place_album_book() -> void:
	if _album_book == null:
		_album_book = StaticBody3D.new()
		_album_book.name = "AlbumBook"
		_album_book.collision_layer = 1 << (PICK_LAYER - 1)
		_album_book.collision_mask = 0
		_album_book.set_meta("album_book", true)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.4, 0.15, 0.34)
		shape.shape = box
		shape.position.y = 0.07
		_album_book.add_child(shape)
		var view: Node3D = (load(ALBUM_BOOK) as PackedScene).instantiate() if ResourceLoader.exists(ALBUM_BOOK) else null
		if view == null:
			var mesh := MeshInstance3D.new()
			var cube := BoxMesh.new()
			cube.size = Vector3(0.35, 0.06, 0.28)
			mesh.mesh = cube
			mesh.position.y = 0.03
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(1.0, 0.62, 0.77)
			mesh.material_override = material
			view = mesh
		_album_book.add_child(view)
		add_child(_album_book)
		_box("AlbumTable", Vector3(3.45, 0.375, 1.55), Vector3(0.45, 0.75, 0.45), Color(0.9, 0.79, 0.63))
	var on_counter: bool = decor.placed.has("counter")
	_album_book.position = Vector3(2.0, 0.95, 3.05) if on_counter else Vector3(3.45, 0.75, 1.55)
	_album_book.rotation.y = PI / 2.0
	get_node("AlbumTable").visible = not on_counter


## 좋아함 +1 (규칙마다 한 번, 점수 최대 +3): ♥ 뿅 + 꼬리 붕붕
func like(rule: String) -> bool:
	if _likes.has(rule):
		return false
	_likes[rule] = true
	mood_score = mini(mood_score + 1, 3)
	dog.react("set_mood", 2)
	dog.react("wiggle_legs")
	sfx.play("ding")
	_show_heart()
	return true


## 지금 얼굴 (0 😣 · 1 😐 · 2 😊 · 3 🤩)
func face() -> int:
	return FpAnimals.face_of(mood_score)


func _show_heart() -> void:
	if _heart == null:
		_heart = Label3D.new()
		_heart.name = "Heart"
		_heart.text = "♥"
		_heart.font_size = 72
		_heart.outline_size = 12
		_heart.modulate = Color(1.0, 0.45, 0.6)
		_heart.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_heart.no_depth_test = true
		add_child(_heart)
	_heart.global_position = dog.model.to_global(dog._body_center()) + Vector3(0.12, 0.6, 0)
	_heart.visible = true
	_heart.set_meta("left", 0.8)


## 거품·빗질 때 좋아하는 곳: 0.5초 머물면 좋아함, 가까울수록 꼬리가 빨리 (따뜻해요 놀이). 가까운 정도 0~1 을 돌려줌
func _check_fav(tool_id: String, local: Vector3, delta: float) -> float:
	if fav_spot.is_empty() or not (tool_id == "shampoo" or tool_id == "brush"):
		return 0.0
	var face_center: Vector3 = dog.model.get("face_center") if dog.model.get("face_center") != null else Vector3(0, 0.5, 0.25)
	var spot := FpAnimals.fav_point(fav_spot, dog._body_center(), face_center)
	var distance := local.distance_to(spot)
	if distance <= Tuning.data.v4_fav_radius:
		_fav_time += delta
		if _fav_time >= Tuning.data.v4_fav_time and like("fav"):
			_show_hint("♥ %s 를 좋아해요!" % FpAnimals.FAV_NAMES.get(fav_spot, ""), 1.5)
	else:
		_fav_time = 0.0
	return clampf(1.0 - distance / FpTrust.fav_hint_radius(trust_tier), 0.0, 1.0)


func _show_anger() -> void:
	if _anger == null:
		_anger = Label3D.new()
		_anger.name = "Anger"
		_anger.text = "💢"
		_anger.font_size = 64
		_anger.outline_size = 12
		_anger.modulate = Color(1.0, 0.3, 0.3)
		_anger.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_anger.no_depth_test = true
		add_child(_anger)
	_anger.global_position = dog.model.to_global(dog._body_center()) + Vector3(0, 0.55, 0)
	_anger.visible = true
	_anger.set_meta("left", 0.5)


## 고양이·성격 규칙 (도구를 대는 동안). point = 겨눈 곳
func _check_animal_rules(tool_id: String, point: Vector3, delta: float) -> void:
	var local := dog.to_model(point)
	var face: Vector3 = dog.model.get("face_center") if dog.model.get("face_center") != null else Vector3(0, 0.5, 0.25)
	if animal == "cat" and tool_id == "shower":
		if not _wet_started:
			_wet_started = true
			_wet_since = _t
		# 머리 (목 위) 에 물: 한 손님에 v4_cat_head_water_max 번, 그 뒤엔 "냥!" 만
		if local.y >= face.y - 0.1:
			if not FpTrust.cat_head_counts(trust_tier):
				# 친함부터: 머리에 물은 반응만 (싫어함 아님)
				dog.react("shake")
			elif dislike("cat_head", Tuning.data.v4_cat_head_water_max, "shake"):
				_show_hint("냥! (머리에 물은 싫어요)", 1.5)
	if animal_trait == "timid" and (tool_id == "shower" or tool_id == "dryer"):
		if local.distance_to(face) <= FpTrust.timid_radius(trust_tier):
			if dislike("timid_face", -1, "flap_cheeks"):
				_show_hint("부르르… (얼굴은 무서워요)", 1.5)
	if animal_trait == "ticklish" and (tool_id == "shampoo" or tool_id == "towel"):
		_tickle(point, local, delta)
	# 단짝: 배를 보여 줌 → 배 문지르기 = 좋아함 +1 (한 번)
	if trust_tier >= 3 and (tool_id == "shampoo" or tool_id == "brush") and local.y < dog._body_center().y - 0.04:
		if like("belly"):
			_show_hint("배를 보여 줘요! 쓱쓱 ♥", 1.5)
	if quirk == "shower" and tool_id == "shower":
		_shower_quirk(local, delta)
	elif quirk == "dryer" and tool_id == "dryer":
		_dryer_quirk(point, delta)


## 샤워 무서움: 낯가림·익숙함 = 발부터 적셔야 함 (발 → 몸 순서면 괜찮음), 친함 = 처음 v4_quirk_shower_safe 초만 조심, 단짝 = 물줄기를 톡톡 놀이
func _shower_quirk(local: Vector3, delta: float) -> void:
	_shower_time += delta
	if trust_tier >= 3:
		if like("quirk_play"):
			_show_hint("앞발로 물줄기를 톡톡! ♥", 1.5)
		return
	var feet := local.y < dog._body_center().y - 0.12
	if feet:
		_quirk_feet = true
	if feet or _quirk_feet and trust_tier < 2:
		return
	if trust_tier >= 2 and _shower_time > Tuning.data.v4_quirk_shower_safe:
		return
	if dislike("shower_fear", -1, "shake"):
		_show_hint("무서워요… 발부터 살살 적셔 주세요", 1.8)


## 드라이 소리 예민: 켠 채 v4_quirk_dryer_near 안으로 너무 빨리 들어오면 싫어함, 단짝 = 바람에 눈 감고 골골 (좋아함, 한 번)
func _dryer_quirk(point: Vector3, delta: float) -> void:
	_dryer_hold += delta
	var near: bool = player.camera.global_position.distance_to(point) < Tuning.data.v4_quirk_dryer_near
	if trust_tier >= 3:
		if like("quirk_play"):
			_show_hint("바람에 눈을 감고 골골… ♥", 1.5)
		return
	if near and not _dryer_inside and _dryer_hold < FpTrust.dryer_approach(trust_tier):
		if dislike("dryer_noise", -1, "flap_cheeks"):
			_show_hint("귀가 납작… 멀리서 켜고 천천히 다가가요", 1.8)
	_dryer_inside = near


## 간지럼쟁이: 몸 아래쪽 (배·발) 한 곳에 v4_ticklish_time 초 넘게 머물면 싫어함
func _tickle(point: Vector3, local: Vector3, delta: float) -> void:
	var center := dog._body_center()
	if local.y > center.y - 0.04:
		_tickle_at = null
		_tickle_time = 0.0
		return
	if _tickle_at == null or (_tickle_at as Vector3).distance_to(point) > Tuning.data.v4_ticklish_radius:
		_tickle_at = point
		_tickle_time = 0.0
	_tickle_time += delta
	if _tickle_time > FpTrust.ticklish_time(trust_tier):
		_tickle_time = 0.0
		if trust_tier >= 3:
			# 단짝 간지럼쟁이: 킥킥 웃으며 좋아함
			if like("belly"):
				_show_hint("킥킥! 간지러워도 좋아요 ♥", 1.5)
			return
		if dislike("tickle", -1, "wiggle_legs"):
			_show_hint("킥킥! (배·발은 짧게)", 1.5)


## 새 강아지 (진흙 무늬 무작위)
func new_dog() -> void:
	_dogs += 1
	dog.setup(Tuning.data.mask_resolution, _rng.randi_range(0, 2), _rng.randi())
	dog.show_mask()
	dog.react("set_mood", 1)
	done = false
	stage_index = 0
	_banner_left = 0.0
	_reacted.clear()
	has_dog = true
	dog.visible = true
	tangles = FpTangles.new()
	tangles.name = "Tangles"
	dog.model.add_child(tangles)
	tangles.untangled.connect(_on_untangled)
	trim = FpTrim.new()
	trim.name = "Trim"
	dog.model.add_child(trim)
	trim.snipped.connect(_on_snipped)
	trim_request = _taken.get("trim", "") if quick_feature != "trim" else "bear"
	acc_on = ""
	_acc_liked = false
	_show_hint("%s를 씻겨 주세요: 샤워기 → 샴푸 → 샤워기로 헹구기 → 수건 → 드라이기 → 빗" % ("고양이" if animal == "cat" else "강아지"), 4.0)
	_start_quick_stage()


## 빠른 확인: 그 기능의 단계부터 바로 시작 (앞 단계는 이미 끝난 강아지)
func _start_quick_stage() -> void:
	if quick_feature == "accessory":
		# 빠른 확인 [액세서리]: 다 씻은 동물로 바로
		for channel in ["wet", "scrub", "rinse", "towel", "dry"]:
			if dog.mask.CHANNELS.has(channel):
				dog.mask.fill(channel, 1.0)
		dog.clear_foam()
		dog.fluff = 1.0
		stage_index = STAGES.size()
		done = true
		_show_hint("다 씻었어요! 목욕통 오른쪽 옆 바구니를 클릭해 액세서리를 씌워 봐요", 6.0)
		return
	var start: String = {"foam": "scrub", "towel": "towel", "dryer": "dry", "brush": "brush", "trim": "trim"}.get(quick_feature, "")
	if start.is_empty():
		return
	for i in STAGES.size():
		if STAGES[i].id == start:
			break
		var channel: String = STAGES[i].id
		if dog.mask.CHANNELS.has(channel):
			dog.mask.fill(channel, 1.0)
		_reacted[channel] = true
		stage_index = i + 1
		if channel == "dry":
			dog.fluff = 1.0
			_spawn_tangles()
		elif channel == "brush":
			tangles.clear()
	if start == "trim":
		_spawn_trim()
	_show_hint("%s 집어서 바로 해 봐요" % TOOLS[stage_tool()].name, 4.0)


## 목욕통 비우기 (주인이 데려갔거나 아직 아무도 안 맡김)
func _clear_tub() -> void:
	has_dog = false
	acc_on = ""
	_acc_liked = false
	dog.visible = false
	dog.clear_foam()
	_stop_effects()
	done = false


## 손님 클릭: 대기 손님이면 강아지를 맡기고, 목욕통 옆 주인이면 다 씻은 강아지를 돌려준다
func interact_guest(owner: Node3D) -> void:
	if day_over or owner == null:
		return
	if owner == guests.current:
		if done:
			give_back()
		else:
			_show_hint("다 씻기고 나서 주인을 클릭해 돌려줘요", 1.5)
		return
	if has_dog:
		_show_hint("목욕통이 비면 받을 수 있어요", 1.5)
		return
	_taken = guests.take(owner)
	if not _taken.is_empty():
		_set_animal(_taken.get("animal", "dog"), _taken.get("trait", ""))
		new_dog()
		regular = _taken.get("regular", "")
		if not regular.is_empty():
			var info := FpRegulars.get_regular(regular)
			FpRegulars.dress(dog.model, info)
			# 단골의 좋아하는 곳은 늘 같은 곳 (두 번째 방문부터 기억해서 찾는 재미)
			fav_spot = info.fav
			guests.current.set_meta("regular", regular)
			trust_tier = int(album.get(regular, {}).get("trust", 0))
			quirk = info.get("quirk", "")
		if quick_feature == "mood":
			# 빠른 확인 [기분·반응]: 좋아하는 곳을 알려 줌 (진짜 게임은 글자 없이 꼬리로만)
			_show_hint("이번 손님이 좋아하는 곳: %s (거품·빗질 때 0.5초) · 30초 안에 다 씻으면 🤩" % FpAnimals.FAV_NAMES.get(fav_spot, ""), 8.0)
		elif day == 1 and guests.served == 0 and _card_left <= 0.0 and quick_dogs == 0:
			_show_hint("강아지가 좋아하는 곳을 찾아 보세요 ♥ (거품·빗질 때, 가까우면 꼬리가 빨라져요)", 5.0)
		# 처음 안내: 선반의 샤워기 (집으면 사라짐) → 그다음 적시기 손동작
		if not guide.show_tip("shelf", _pickups.get("shower"), func() -> bool: return held == "shower"):
			guide.show_tip("stage_wet")
		# 샴푸가 없으면 거품 단계를 건너뛰고 씻김 (막지 않음, 요금이 거의 없음 — 사람 대표 결정)
		no_shampoo = shampoo_left < 0.01
		if no_shampoo:
			dog.mask.fill("scrub", 1.0)
			_show_hint("샴푸가 없어요! 거품 없이 씻어요 (요금 %d, 팁 없음)" % Tuning.data.v4_no_shampoo_price, 4.0)


## 다 씻은 강아지를 주인에게: 요금 + 기분 팁 + 빠른 팁 (TUNING_V4 3장), 주인은 기뻐하며 떠남
func give_back() -> void:
	var base: int = Tuning.data.v4_cat_price if animal == "cat" else Tuning.data.v4_price_wash
	var fee: int = base
	# 기분 점수 → 얼굴 4단계 (😣 0 · 😐 5 · 😊 15 · 🤩 25 팁), 요금은 기분과 상관없이
	var face := face()
	var tip: int = Tuning.data.v4_tip_mood4[face] + fast_tip(_taken.get("kind", "normal"), guests.elapsed - _taken.get("arrived", guests.elapsed))
	if not trim_request.is_empty():
		fee += Tuning.data.v4_price_trim
		tip += trim_tip(trim.match_score())
	var say: String = "+%d · " + FpAnimals.FACE_SAY[face]
	# 대표 단골: 주인 한마디가 신뢰 단계마다 (기분이 나쁘면 보통 한마디)
	var star_lines: Array = FpRegulars.get_regular(regular).get("lines", []) if not regular.is_empty() else []
	if face >= 1 and star_lines.size() > trust_tier:
		say = "+%d · " + str(star_lines[trust_tier]).replace("%", "%%")
	if _acc_liked:
		say = "+%d · 어머, 귀여워!"
	if face > best_face:
		best_face = face
		best_animal = animal
	if face == 3:
		_final_sparkle(dog.model.to_global(dog._body_center()), false)
	if no_shampoo:
		fee += Tuning.data.v4_no_shampoo_price - base
		tip = 0
		say = "+%d · 샴푸 냄새가 안 나요…"
		no_shampoo = false
	fees += fee
	tips += tip
	money += fee + tip
	take_photo(face)
	guests.return_current(say % (fee + tip), mini(face, 2))
	sfx.play("coin")
	_clear_tub()
	_taken = {}
	_show_hint("%s 요금 %d + 팁 %d" % [FpAnimals.FACE_ICON[face], fee, tip], 2.5)


## 빠른 서비스 팁: 손님이 들어온 뒤 돌려받기까지 걸린 시간(s)으로. 급한 손님은 배수
static func fast_tip(kind: String, seconds: float) -> int:
	var times: PackedFloat32Array = Tuning.data.v4_fast_times
	var tips_by_time: PackedInt32Array = Tuning.data.v4_tip_fast
	var tip := tips_by_time[times.size()]
	for i in times.size():
		if seconds <= times[i]:
			tip = tips_by_time[i]
			break
	return roundi(tip * (Tuning.data.v4_tip_fast_hurry_mult if kind == "hurry" else 1.0))


## 테스트·키 없이: 목욕통에 강아지가 있으면 그 주인, 없으면 맨 앞 손님과 상호작용
func next_guest() -> void:
	if has_dog:
		interact_guest(guests.current)
	elif not guests.guests.is_empty():
		interact_guest(guests.guests[0].owner)


## 시계 (9:00 ~ 18:00)
func clock_text() -> String:
	var minutes := 9 * 60 + int(minf(day_time / day_seconds, 1.0) * 9 * 60)
	var hour := minutes / 60
	return "%s %d:%02d" % ["오전" if hour < 12 else "오후", hour if hour <= 12 else hour - 12, minutes % 60]


func _update_day(delta: float) -> void:
	if day_over or morning:
		return
	if quick_dogs > 0:
		if guests.served >= quick_dogs:
			day_over = true
			_stop_effects()
			using = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			quick_finished.emit()
		return
	day_time += delta
	if guests.open and day_time >= day_seconds:
		guests.open = false
		_show_hint("6시, 영업 끝! 남은 손님만 씻겨요", 3.0)
	if not guests.open and not has_dog and guests.guests.is_empty() and guests.current == null:
		end_day()


## 영업 끝 → 정산 (씻긴·떠난·번 돈)
func end_day() -> void:
	day_over = true
	outside.set_sign(false)
	_stop_effects()
	using = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_settle = FpSettle.new()
	_settle.name = "Settle"
	_hud.get_parent().add_child(_settle)
	_settle.buy_requested.connect(func(tool_id: String) -> void:
		if order(tool_id):
			save_game(day + 1)
		_show_settle())
	_settle.place_requested.connect(func(id: String) -> void:
		if place_decor(id):
			save_game(day + 1)
		_show_settle())
	_settle.album_requested.connect(open_album)
	_settle.next_day_requested.connect(start_next_day)
	_show_settle()
	if guide.show_tip("settle"):
		var tab := _settle.find_child("Tab_tools", true, false) as Control
		if tab != null:
			var pulse := tab.create_tween().set_loops(6)
			pulse.tween_property(tab, "modulate", Color(1.3, 1.1, 0.7), 0.4)
			pulse.tween_property(tab, "modulate", Color.WHITE, 0.4)
	sfx.play("clap")
	save_game(day + 1)


## 도구 소리 높이: 단계마다 살짝 다르게 (샤워기·거품·빗은 조금 밝게, 드라이기는 조금 낮고 힘차게)
const TOOL_PITCH_STEP := {"shower": 0.035, "shampoo": 0.04, "dryer": -0.03, "brush": 0.035}


static func tool_pitch(tool_id: String, level: int) -> float:
	return 1.0 + TOOL_PITCH_STEP.get(tool_id, 0.0) * level


## 도구 단계별 칠하는 속도 배수
func speed_mult(tool_id: String) -> float:
	var mults: PackedFloat32Array = Tuning.data.v4_tool_speed_mult5
	return mults[mini(tool_level.get(tool_id, 0), mults.size() - 1)]


## 최종 단계 ("와" 단계): 효과를 크게
func is_final(tool_id: String) -> bool:
	return TOOL_LEVEL_NAMES.has(tool_id) and tool_level[tool_id] >= Tuning.data.v4_tool_tiers - 1


## 도구 단계별 붓·모형 크기 배수
func size_mult(tool_id: String) -> float:
	return 1.0 + (speed_mult(tool_id) - 1.0) * SIZE_SHARE


## 지금 단계 모형 이름: 그 단계 GLB 가 있으면 그것, 없으면 기본 도구
func model_id(tool_id: String) -> String:
	if not LEVEL_MODELS.has(tool_id):
		return tool_id
	for level in range(tool_level[tool_id], 0, -1):
		var id: String = LEVEL_MODELS[tool_id][level]
		if ResourceLoader.exists("res://assets/models/tools/%s.glb" % id):
			return id
	return tool_id


## 그 단계 그림이 없어 아래 단계 모형을 쓸 때만, 모자란 단계만큼 크기로 보여 줌
func model_scale(tool_id: String) -> float:
	if not LEVEL_MODELS.has(tool_id):
		return 1.0
	var shown: int = LEVEL_MODELS[tool_id].find(model_id(tool_id))
	return 1.0 + 0.08 * (tool_level[tool_id] - shown)


func tool_name(tool_id: String) -> String:
	if not TOOL_LEVEL_NAMES.has(tool_id):
		return TOOLS[tool_id].name
	return TOOL_LEVEL_NAMES[tool_id][tool_level[tool_id]]


## 다음 단계 값 (더 없으면 -1). 주문해 둔(아직 안 연) 상자 단계까지 친 다음 단계. 가게 물건(샴푸·새 빗살)도
func next_price(tool_id: String) -> int:
	if not FpAccessory.category_of(tool_id).is_empty():
		return -1 if acc_owned.has(tool_id) or _ordered("acc:" + tool_id) > 0 else FpAccessory.price_of(tool_id)
	if not FpDecor.category_of(tool_id).is_empty():
		return -1 if decor.owned.has(tool_id) or _ordered("decor:" + tool_id) > 0 else FpDecor.price_of(tool_id)
	match tool_id:
		"cart":
			return -1 if owns_cart or _ordered("cart") > 0 else Tuning.data.v4_cart_price
		"scissors":
			return -1 if owns_scissors or _ordered("scissors") > 0 else Tuning.data.v4_price_scissors
		"shampoo_bottle":
			return Tuning.data.v4_shampoo_bottle_price
		"shampoo_big":
			return Tuning.data.v4_shampoo_big_price
		"brush_refill":
			var refill: int = Tuning.data.v4_brush_refill_price5[tool_level.brush]
			return refill if refill > 0 and brush_used > 0 and _ordered("brush_refill") + _ordered("tool:brush") == 0 else -1
	var prices: PackedInt32Array = Tuning.data.v4_tool_price5
	var next: int = ordered_level(tool_id) + 1
	return prices[next] if next < prices.size() and next < Tuning.data.v4_tool_tiers else -1


## 주문까지 친 도구 단계 (지금 단계 + 안 연 단계 상자 수)
func ordered_level(tool_id: String) -> int:
	return tool_level[tool_id] + _ordered("tool:" + tool_id)


func _ordered(item: String) -> int:
	return parcels.filter(func(box: Dictionary) -> bool: return box.item == item).size()


## 가게 줄 id → 상자 속 물건 id (꾸미기 = "decor:<id>")
static func item_of(store_id: String) -> String:
	if not FpAccessory.category_of(store_id).is_empty():
		return "acc:" + store_id
	if not FpDecor.category_of(store_id).is_empty():
		return "decor:" + store_id
	return store_id if store_id in ["scissors", "cart"] or SUPPLIES.has(store_id) else "tool:" + store_id


func item_name(item: String) -> String:
	if item.begins_with("acc:"):
		return FpAccessory.name_of(item.trim_prefix("acc:"))
	if item.begins_with("decor:"):
		return FpDecor.name_of(item.trim_prefix("decor:"))
	if item.begins_with("tool:"):
		var tool_id := item.trim_prefix("tool:")
		return TOOL_LEVEL_NAMES[tool_id][mini(tool_level[tool_id] + 1, Tuning.data.v4_tool_tiers - 1)]
	if item == "scissors":
		return "가위"
	if item == "cart":
		return "택배 수레"
	return SUPPLIES[item].name if SUPPLIES.has(item) else item


## 바로 사서 바로 씀 (빠른 확인·테스트). 정산 판의 가게는 order (택배)
func buy(tool_id: String) -> bool:
	var price := next_price(tool_id)
	if price < 0 or money < price:
		return false
	money -= price
	apply_item(item_of(tool_id))
	sfx.play("coin")
	return true


## 정산 판 가게에서 주문: 돈을 내고 다음 날 아침 택배로 옴 (GDD_V4 '택배 흐름')
func order(store_id: String) -> bool:
	var price := next_price(store_id)
	if price < 0 or money < price:
		return false
	money -= price
	bought_today.append({"id": store_id, "price": price})
	var item := item_of(store_id)
	var kind := "tool"
	var size := "small"
	if item == "cart":
		size = "large"
	elif item.begins_with("decor:"):
		kind = "decor"
		size = FpDecor.box_size_of(store_id)
	elif item.begins_with("acc:"):
		kind = "acc"
	elif SUPPLIES.has(item):
		kind = "shampoo" if item.begins_with("shampoo") else "brush_refill"
		size = SUPPLIES[item].size
	parcels.append({"item": item, "kind": kind, "size": size, "arrived": false})
	sfx.play("coin")
	return true


## 상자 속 물건을 제자리에 (도구 단계 하나 올림·가위·샴푸 채움·새 빗살)
func apply_item(item: String) -> void:
	if item.begins_with("acc:"):
		var acc_id := item.trim_prefix("acc:")
		if not acc_owned.has(acc_id):
			acc_owned.append(acc_id)
		return
	if item.begins_with("decor:"):
		var id := item.trim_prefix("decor:")
		if not decor.owned.has(id):
			decor.owned.append(id)
		place_decor(id)
		return
	if item.begins_with("tool:"):
		var tool_id := item.trim_prefix("tool:")
		set_tier(tool_id, tool_level[tool_id] + 1)
		if tool_id == "brush":
			brush_used = 0
		return
	match item:
		"cart":
			owns_cart = true
			_place_cart(Vector3(2.7, 0, 1.4))
		"scissors":
			owns_scissors = true
			guests.trim_chance = Tuning.data.v4_trim_request_ratio
			_set_pickup_available("scissors", true)
		"shampoo_bottle":
			shampoo_left += Tuning.data.v4_shampoo_bottle
		"shampoo_big":
			shampoo_left += Tuning.data.v4_shampoo_big
		"brush_refill":
			brush_used = 0


## 꾸미기 놓기: 산 물건 id (그 범주 자리에, 하나만) 또는 "default:<범주>" (처음 모습). 산 적 없는 것은 false
func place_decor(id: String) -> bool:
	if id.begins_with("default:"):
		decor.placed.erase(id.trim_prefix("default:"))
	elif decor.owned.has(id):
		decor.placed[FpDecor.category_of(id)] = id
	else:
		return false
	_apply_decor()
	return true


## 놓인 꾸미기를 방에 보이고, 아늑함으로 대기 참을성을 늘림
func _apply_decor() -> void:
	decor_view.board_photos = board_photos()
	decor_view.apply(decor.placed)
	_place_album_book()
	guests.patience_mult = FpDecor.patience_mult(decor.placed)


## 정산 판 꾸미기 탭 내용
func decor_rows() -> Dictionary:
	var stars := FpDecor.coziness(decor.placed)
	var rows := []
	for category in FpDecor.CATEGORIES:
		var items := []
		for i in 3:
			var id: String = FpDecor.CATEGORIES[category].items[i][0]
			var state := "buy"
			if decor.placed.get(category, "") == id:
				state = "placed"
			elif decor.owned.has(id):
				state = "owned"
			elif _ordered("decor:" + id) > 0:
				state = "coming"
			items.append({"id": id, "name": FpDecor.CATEGORIES[category].items[i][1], "stars": i + 1, "price": FpDecor.price_of(id), "state": state, "can_buy": money >= FpDecor.price_of(id)})
		rows.append({"category": category, "name": FpDecor.CATEGORIES[category].name, "default_placed": not decor.placed.has(category), "items": items})
	return {"title": "아늑함 ★%d — 손님이 %d%% 더 기다려 줘요 (산 것은 내일 아침 택배, 산 것끼리는 공짜로 바꿔 끼움)" % [stars, roundi((FpDecor.patience_mult(decor.placed) - 1.0) * 100.0)], "rows": rows}


## 정산 판 [액세서리] 탭: 범주마다 ★1·★2·★3 (state: buy / owned / coming)
func acc_rows() -> Array:
	var rows := []
	for category in FpAccessory.categories():
		var items := []
		for id in FpAccessory.items_of(category):
			var state := "buy"
			if acc_owned.has(id):
				state = "owned"
			elif _ordered("acc:" + id) > 0:
				state = "coming"
			items.append({"id": id, "name": FpAccessory.name_of(id), "stars": FpAccessory.stars_of(id), "price": FpAccessory.price_of(id), "state": state, "can_buy": money >= FpAccessory.price_of(id)})
		rows.append({"category": category, "name": FpAccessory.CATEGORIES[category].name, "items": items})
	return rows


## 액세서리 씌우기 (다 씻은 뒤, 돌려주기 전). id "" = 벗기기. 단골이 좋아하는 범주면 좋아함 +1 (기분 상한 안) + 뽐내기
func wear_acc(id: String) -> bool:
	if not has_dog or not done:
		return false
	if not id.is_empty() and not acc_owned.has(id):
		return false
	acc_on = id
	FpAccessory.wear(dog.model, id, animal == "cat")
	if id.is_empty():
		return true
	sfx.play("press")
	var fav_acc: String = FpRegulars.get_regular(regular).get("acc", "") if not regular.is_empty() else ""
	if not fav_acc.is_empty() and FpAccessory.category_of(id) == fav_acc:
		_acc_liked = true
		for i in Tuning.data.v4_acc_like_bonus:
			like("acc" if i == 0 else "acc_%d" % i)
		dog.react("jump")
		_show_hint("어머, 귀여워! %s 를 좋아해요 ♥" % FpAccessory.CATEGORIES[fav_acc].name, 2.0)
	else:
		_acc_liked = false
		dog.react("wiggle_legs")
		_show_hint("%s 좋아요!" % FpAccessory.name_of(id), 1.5)
	return true


## 액세서리 바구니 (acc_basket.glb, 없으면 임시 바구니): 목욕통 오른쪽 옆
func _place_acc_basket() -> void:
	_acc_basket = StaticBody3D.new()
	_acc_basket.name = "AccBasket"
	_acc_basket.collision_layer = 1 << (PICK_LAYER - 1)
	_acc_basket.collision_mask = 0
	_acc_basket.set_meta("acc_basket", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.3, 0.3)
	shape.shape = box
	shape.position.y = 0.0
	_acc_basket.add_child(shape)
	var view: Node3D = null
	if ResourceLoader.exists(FpAccessory.MODEL_DIR % "acc_basket"):
		view = (load(FpAccessory.MODEL_DIR % "acc_basket") as PackedScene).instantiate() as Node3D
	else:
		view = Node3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.35, 0.15, 0.25)
		var basket := MeshInstance3D.new()
		basket.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.85, 0.68, 0.45)
		basket.material_override = material
		view.add_child(basket)
		for i in 3:
			var ball := FpAccessory.make_view(["ribbon_pink", "hat_party", "pin_daisy"][i])
			ball.position = Vector3(-0.1 + 0.1 * i, 0.08, 0)
			view.add_child(ball)
		# 받침 다리
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.3, 0.38, 0.2)
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.position.y = -0.27
		var leg_material := StandardMaterial3D.new()
		leg_material.albedo_color = Color(0.95, 0.92, 0.85)
		leg.material_override = leg_material
		view.add_child(leg)
	view.name = "View"
	_acc_basket.add_child(view)
	_acc_basket.position = BASKET_POS
	add_child(_acc_basket)


## 바구니 클릭: 다 씻은 동물이 있으면 가진 액세서리가 둥글게 펼쳐짐
func open_acc_menu() -> void:
	if not has_dog or not done:
		_show_hint("다 씻은 뒤에 액세서리를 하나 씌워 줄 수 있어요", 1.5)
		return
	if is_instance_valid(_acc_menu):
		return
	_acc_menu = Control.new()
	_acc_menu.name = "AccMenu"
	_acc_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.get_parent().add_child(_acc_menu)
	var center := _hud.get_viewport_rect().size / 2.0
	var count := acc_owned.size()
	var radius := 120.0 + 10.0 * count
	for i in count:
		var id: String = acc_owned[i]
		var button := Button.new()
		button.name = "Acc_" + id
		button.text = "%s\n%s" % [FpAccessory.CATEGORIES[FpAccessory.category_of(id)].name, FpAccessory.name_of(id)]
		button.custom_minimum_size = Vector2(120, 56)
		button.add_theme_font_size_override("font_size", 16)
		var angle := -PI / 2.0 + TAU * i / maxf(count, 1)
		button.position = center + Vector2(cos(angle), sin(angle)) * radius - Vector2(60, 28)
		button.pressed.connect(func() -> void: _choose_acc(id))
		_acc_menu.add_child(button)
	var none := Button.new()
	none.name = "Acc_none"
	none.text = "안 씌우기" if acc_on.is_empty() else "벗기기"
	none.custom_minimum_size = Vector2(120, 56)
	none.position = center - Vector2(60, 28)
	none.pressed.connect(func() -> void: _choose_acc(""))
	_acc_menu.add_child(none)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _choose_acc(id: String) -> void:
	wear_acc(id)
	if is_instance_valid(_acc_menu):
		_acc_menu.queue_free()
	_acc_menu = null
	if input_enabled and not day_over:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 빗 수명 (마리, 0 = 안 닳음)
func brush_life() -> int:
	return Tuning.data.v4_brush_life5[tool_level.brush]


## 빗 닳음 → 빗질 속도 배수: 남은 수명이 v4_brush_worn_from 아래로 가면 v4_brush_worn_mult 까지 천천히
func brush_wear_mult() -> float:
	var life := brush_life()
	if life <= 0:
		return 1.0
	var left := 1.0 - minf(float(brush_used) / life, 1.0)
	var from: float = Tuning.data.v4_brush_worn_from
	if left >= from:
		return 1.0
	return lerpf(Tuning.data.v4_brush_worn_mult, 1.0, left / from)


## 도구 단계를 바로 정함 (가게·빠른 확인): 선반 모형을 그 단계 모형으로, 손에 들고 있으면 다시 집음
func set_tier(tool_id: String, level: int) -> void:
	tool_level[tool_id] = clampi(level, 0, Tuning.data.v4_tool_tiers - 1)
	if held == tool_id:
		drop()
	var pickup: Node3D = _pickups[tool_id]
	var old := pickup.get_node_or_null("View") as Node3D
	var view := _make_tool_mesh(model_id(tool_id))
	if old != null:
		view.position = old.position
		view.rotate_y(PI / 2.0)
		# 바로 지움 (queue_free 로 한 프레임 남기면 더미 렌더러에서 "material is null" 오류가 남)
		old.free()
	view.name = "View"
	view.scale *= model_scale(tool_id)
	pickup.add_child(view)
	_cache_glow_materials(tool_id, view)


## 모든 도구를 같은 단계로 (빠른 확인)
func set_all_tiers(level: int) -> void:
	for tool_id in TOOL_LEVEL_NAMES:
		set_tier(tool_id, level)
	if level < Tuning.data.v4_tool_tiers:
		_show_hint("모든 도구 %d단계" % (level + 1), 2.0)


## 정산 판 아래 가게 줄: 도구마다 다음 단계 이름·값, 가위, 샴푸, 새 빗살 (산 것은 다음 날 아침 택배)
func store_rows() -> Array:
	var rows := []
	for tool_id in TOOL_LEVEL_NAMES:
		var price := next_price(tool_id)
		var level := ordered_level(tool_id)
		rows.append({"id": tool_id, "name": TOOL_LEVEL_NAMES[tool_id][level], "next": TOOL_LEVEL_NAMES[tool_id][level + 1] if price >= 0 else "", "price": price, "can_buy": price >= 0 and money >= price})
	if next_price("cart") >= 0:
		rows.append({"id": "cart", "name": "수레 없음", "next": "택배 수레 (상자 3칸, 시험용)", "price": next_price("cart"), "can_buy": money >= next_price("cart")})
	if next_price("scissors") >= 0 and FpDays.scissors_open(day):
		var scissors := next_price("scissors")
		rows.append({"id": "scissors", "name": "가위 없음", "next": "가위 (미용 요청 손님)", "price": scissors, "can_buy": money >= scissors})
	for id in ["shampoo_bottle", "shampoo_big"]:
		var amount: int = Tuning.data.v4_shampoo_bottle if id == "shampoo_bottle" else Tuning.data.v4_shampoo_big
		rows.append({"id": id, "name": SUPPLIES[id].name, "next": "%d마리분 채움" % amount, "price": next_price(id), "can_buy": money >= next_price(id)})
	if next_price("brush_refill") >= 0:
		rows.append({"id": "brush_refill", "name": "빗 닳음 %d/%d" % [mini(brush_used, brush_life()), brush_life()], "next": "새 빗살", "price": next_price("brush_refill"), "can_buy": money >= next_price("brush_refill")})
	return rows


## 정산 뒤 "다음 날": 가진 돈·도구는 그대로, 시계·손님·오늘 번 돈은 새로
func start_next_day() -> void:
	if not _day_closed:
		_close_day()
	# 18일차 정산 뒤 = 엔딩 (한 번만). [계속 영업하기] 로 19일차 자유 영업
	if FpDays.is_last_day(day) and not ending_seen:
		play_ending()
		return
	if is_instance_valid(_settle):
		_settle.queue_free()
	_settle = null
	_day_closed = false
	bought_today = []
	day += 1
	day_time = 0.0
	day_over = false
	fees = 0
	tips = 0
	guests.day = day
	best_face = -1
	best_animal = ""
	guests.start_day()
	_apply_day()
	_clear_tub()
	_start_morning()
	save_game(day)
	if input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## 날마다 바뀌는 가게 (18일 흐름): 대기 의자 수
func _apply_day() -> void:
	guests.set_seats(FpDays.seat_count(day))


## 하루 결과 (정산 뒤, 산 것까지): 기록·테스트용 한 덩어리
func day_summary() -> Dictionary:
	var upkeep := 0
	var bought := []
	for row in bought_today:
		bought.append(row.id)
		if SUPPLIES.has(row.id):
			upkeep += int(row.price)
	var gold := 0
	for id in album:
		if int(album[id].get("best_mood", -1)) == 3:
			gold += 1
	return {"day": day, "served": guests.served, "left": guests.left_count, "price_sum": fees, "tip_sum": tips, "upkeep": upkeep, "bought": bought, "money_after": money, "regulars_met": album.size(), "trust_levels": "/".join(FpTrust.tier_counts(album).map(func(n: int) -> String: return str(n))), "gold_photos": gold}


func _close_day() -> void:
	_day_closed = true
	day_closed.emit(day_summary())


## 엔딩 '감사의 날' (18일차 정산 뒤, fp_thanks.gd): 저녁 → 단골들이 고마움을 전하러 옴 → 그때와 지금 → 단체 사진 (사진첩 마지막 쪽) →
## 별 3개 → 고마워요 → [계속 영업하기] (19일차 자유 영업) / [메뉴로]. 엔딩은 한 번만 (저장 ending_seen)
func play_ending() -> void:
	if is_instance_valid(_ending):
		return
	ending_seen = true
	group_photo = FpThanks.group_order(regulars_met_order)
	save_game(day + 1)
	if is_instance_valid(_settle):
		_settle.queue_free()
	_settle = null
	_clear_tub()
	var thanks := FpThanks.new()
	thanks.name = "Thanks"
	_ending = thanks
	add_child(thanks)
	thanks.finished.connect(func(go_on: bool) -> void:
		_ending = null
		if go_on:
			start_next_day()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file(MENU_SCENE))
	thanks.play(self)


func _show_settle() -> void:
	_settle.show_day_end("%d일차 영업 끝!" % day, [
		"받은 손님  %d · 떠난 손님  %d" % [guests.served, guests.left_count],
		"요금  %d + 팁  %d = 오늘  %d" % [fees, tips, fees + tips],
		"가진 돈  %d" % money,
	] + _supply_lines(), store_rows(), decor_rows(), acc_rows())


## 정산 판: 남은 샴푸 (적으면 ⚠, 없으면 ⛔), 빗 닳음, 내일 아침 올 택배
func _supply_lines() -> Array:
	var lines := []
	var mark := ""
	if shampoo_left < 0.01:
		mark = "⛔ "
	elif shampoo_left <= Tuning.data.v4_shampoo_warn_at:
		mark = "⚠ "
	lines.append("%s남은 샴푸  %s마리분" % [mark, _amount(shampoo_left)])
	if brush_life() > 0:
		# 수명을 넘어도 글자는 상한에서 멈춤 (QA #137)
		var worn_out := brush_used >= brush_life()
		lines.append("빗 닳음  %d / %d마리%s" % [mini(brush_used, brush_life()), brush_life(), " (다 닳았어요)" if worn_out else (" (느려졌어요)" if brush_wear_mult() < 1.0 else "")])
	if best_face >= 0:
		lines.append("오늘 가장 기뻐한 손님  %s %s" % [FpAnimals.FACE_ICON[best_face], "고양이" if best_animal == "cat" else "강아지"])
	var coming := parcels.filter(func(box: Dictionary) -> bool: return not box.get("arrived", true)).size()
	if coming > 0:
		lines.append("내일 아침 도착 📦 %d개" % coming)
	return lines


func _on_guest_left(_kind: String) -> void:
	_show_hint("손님이 \"다음에 올게요\" 하고 떠났어요", 2.5)
	sfx.play("bell")


## 진행 (0~1): 물·거품(진흙)·말리기, 남은 거품 수
func progress() -> Dictionary:
	return {"wet": dog.mask.ratio("wet"), "scrub": dog.mask.ratio("scrub"), "towel": dog.mask.ratio("towel"), "dry": dog.mask.ratio("dry"), "foam": dog.foam_count(), "brush": tangles.ratio() if is_instance_valid(tangles) else 0.0, "tangles": tangles.count() if is_instance_valid(tangles) else 0, "trim_left": trim.wanted_left() if is_instance_valid(trim) else 0}


func pick(tool_id: String) -> void:
	if not TOOLS.has(tool_id) or held == tool_id:
		return
	if has_dog and not done and stage_index < STAGES.size() and STAGES[stage_index].tool == tool_id:
		guide.show_tip("stage_" + STAGES[stage_index].id)
	if not carried.is_empty():
		_show_hint("상자를 먼저 열어요 (가게 안에서 클릭)", 1.5)
		return
	if pushing_cart:
		push_cart(false)
	drop()
	# 빠르게 Q→같은 도구를 집어도 이전 반납 콜백이 선반을 다시 보이지 않게 한다.
	for view in _returning_views.duplicate():
		if view.tool_id == tool_id:
			_returning_views.erase(view)
			view.queue_free()
	held = tool_id
	_set_pickup_available(tool_id, false)
	_held_view = FpToolView.new()
	_held_view.setup(tool_id, FpToolView.RETURN_SECONDS if not _returning_views.is_empty() else 0.0, model_id(tool_id))
	player.camera.add_child(_held_view)
	_held_view.model.scale *= model_scale(tool_id)
	sfx.play("press")


func drop() -> void:
	if held.is_empty():
		return
	var previous := held
	held = ""
	if _held_view != null:
		_held_view.begin_return()
		_returning_views.append(_held_view)
		_held_view = null
	else:
		_set_pickup_available(previous, true)
	_stop_effects()


func _set_pickup_available(tool_id: String, available: bool) -> void:
	var pickup := _pickups[tool_id] as StaticBody3D
	pickup.visible = available
	# 숨긴 StaticBody 도 광선을 가로막으므로 선반에 없는 동안 충돌도 끈다.
	pickup.collision_layer = (1 << (PICK_LAYER - 1)) if available else 0


func _update_tool_views(delta: float, active: bool) -> void:
	if _held_view != null:
		_held_view.update_motion(delta, active)
	for view in _returning_views.duplicate():
		if view.update_motion(delta, false):
			if held != view.tool_id:
				_set_pickup_available(view.tool_id, true)
			_returning_views.erase(view)
			view.queue_free()


## 든 도구를 강아지 위 point(월드)에 delta 초 동안 쓴다 (마우스를 누르고 있는 동안 매 프레임)
func use_tool_at(point: Vector3, delta: float) -> void:
	# 수건은 누르고 있기가 아니라 클릭마다 톡 (tap_at)
	if held == "towel":
		return
	if held.is_empty() or done:
		return
	var dir := dog.dir_of(point)
	var wet_here := dog.mask.value_at("wet", dir)
	if not _hand_tracked:
		_track_hand(point)
	var fav_near := 0.0
	if has_dog:
		_check_animal_rules(held, point, delta)
		fav_near = _check_fav(held, dog.to_model(point), delta)
	var radius := brush_radius(point) * size_mult(held) * (FINAL_RADIUS if is_final(held) else 1.0)
	var speed := speed_mult(held)
	var stage := ""
	# 씻는 동안 표정은 지금 기분 점수대로, 좋아하는 곳에 가까우면 꼬리가 빨리 (기분 좋은 표정)
	var mood := FpAnimals.model_mood(face())
	if fav_near > 0.5:
		mood = 2
	match held:
		"shower":
			stage = "wet"
			dog.paint("wet", point, radius, Tuning.data.v4_rate_shower * speed * delta)
			if dog.foam_count() > 0:
				stage = "rinse"
				# 헹굼: 위 → 아래로 쓸어내리면 빨리 (거품이 덩어리째 주르륵)
				var down := clampf(-hand_move.y / maxf(delta, 0.001) / Tuning.data.v4_rinse_down_speed, 0.0, 1.0)
				var rinse_mult := lerpf(Tuning.data.v4_gesture_mult[0], Tuning.data.v4_gesture_mult[1], down)
				dog.rinse_foam(point, radius * RINSE_REACH * (1.0 + 0.3 * down), delta * RINSE_SPEED * speed * rinse_mult)
				dog.paint("rinse", point, radius, Tuning.data.v4_rate_shower * speed * delta)
			dog.spray(point)
			dog.show_stream(_tool_tip(), point, Color.from_hsv(fmod(_t * 0.6, 1.0), 0.65, 1.0) if is_final("shower") else Color(0.55, 0.85, 1.0), size_mult("shower") * (FINAL_RADIUS if is_final("shower") else 1.0), is_final("shower"))
			sfx.set_loop("shower", 0.8, tool_pitch("shower", tool_level.shower))
		"shampoo":
			if wet_here < 0.3:
				_show_hint("먼저 샤워기로 물을 뿌려요", 1.5)
				return
			stage = "scrub"
			# 거품: 한 곳에서 좌우로 작게 비비면 (v4_foam_rub_speed 이상) 거품이 커지며 옆으로 번짐
			var rub := clampf(hand_move.length() / maxf(delta, 0.001) / Tuning.data.v4_foam_rub_speed, 0.0, 1.0)
			var rub_mult := lerpf(Tuning.data.v4_gesture_mult[0], Tuning.data.v4_gesture_mult[1], rub)
			dog.paint("scrub", point, radius * (1.0 + 0.25 * rub), Tuning.data.v4_rate_shampoo * speed * rub_mult * delta)
			_foam_carry += delta * 10.0 * speed * rub_mult
			while _foam_carry >= 1.0:
				_foam_carry -= 1.0
				dog.add_foam(point, 1, _rng, FOAM_SIZE * size_mult("shampoo") * (1.0 + 0.4 * rub) * (1.4 if is_final("shampoo") else 1.0))
			sfx.set_loop("foam", 0.8, tool_pitch("shampoo", tool_level.shampoo))
		"brush":
			if stage_index < STAGES.size() and STAGES[stage_index].id != "brush":
				_show_hint("드라이기로 다 말린 뒤에 빗어요", 1.5)
				return
			stage = "brush"
			# 빗질: 뭉치에 대고 쓸기. 쓸어간 거리 / (한 번 길이 × 필요한 번수), 위 → 아래(털 방향)면 번수가 하나 적음.
			# 대고만 있어도 아주 천천히는 풀림 (서툴러도 진행)
			var moved := hand_move.length()
			var strokes: PackedInt32Array = Tuning.data.v4_brush_strokes
			var needed: int = strokes[1] if hand_move.y < -moved * 0.5 else strokes[0]
			var amount: float = maxf(Tuning.data.v4_brush_hold_rate * delta, moved / (Tuning.data.v4_brush_stroke_len * needed))
			tangles.brush(point, radius * BRUSH_REACH, amount * speed * brush_wear_mult())
			if is_final("brush"):
				_final_sparkle(point)
			sfx.set_loop("brush", 0.6, tool_pitch("brush", tool_level.brush))
		"scissors":
			if trim_request.is_empty():
				_show_hint("미용을 요청한 손님 강아지만 잘라요", 1.5)
				return
			if stage_index < STAGES.size() and STAGES[stage_index].id != "trim":
				_show_hint("빗질까지 끝난 뒤에 잘라요", 1.5)
				return
			stage = "trim"
			trim.snip(point, radius * BRUSH_REACH, Tuning.data.v4_rate_trim * speed * delta)
		"dryer":
			# 따뜻한 바람: 젖은 곳일수록 빨리 마르고, 마를수록 털이 뽕 부풀고 귀가 펄럭
			stage = "dry"
			if dog.foam_count() > 0 and dog.mask.value_at("scrub", dir) > 0.5:
				_show_hint("거품을 샤워기로 먼저 헹궈요", 1.5)
			# 드라이: 다가가면 빠르고 털이 크게 날림, 물러서면 느림, 너무 붙으면 찡그림 (그래도 마름)
			var near: PackedFloat32Array = Tuning.data.v4_dryer_near
			var distance: float = player.camera.global_position.distance_to(point)
			var closeness := clampf((near[1] - distance) / (near[1] - near[0]), 0.0, 1.0)
			var dry_mult := lerpf(Tuning.data.v4_dryer_mult[0], Tuning.data.v4_dryer_mult[1], closeness)
			dog.paint("dry", point, radius, Tuning.data.v4_rate_dryer * speed * dry_mult * delta * clampf(wet_here + 0.2, 0.0, 1.0))
			dog.fluff = clampf(dog.mask.ratio("dry") / Tuning.data.v4_done_ratio, 0.0, 1.0)
			if dog.model.has_method("blow"):
				dog.model.blow(1.0 if is_final("dryer") else closeness)
			if is_final("dryer"):
				_final_sparkle(point)
			if distance < near[0]:
				mood = 0
				if _huff_left <= 0.0:
					_huff_left = 1.5
					sfx.play("huff")
					_show_hint("너무 가까워요! 조금 물러서요", 1.2)
			# 바람: 막대 없이 옅은 줄무늬 + 닿는 곳 털이 날리고 흔들림
			dog.show_wind(_tool_tip(), point, 1.0 if is_final("dryer") else closeness)
			dog.blow_fur(point, closeness)
			sfx.set_loop("dryer", 0.8, tool_pitch("dryer", tool_level.dryer))
	# 반응: 씻는 동안 꼬리 흔들기 + 도구를 바라봄, 단계마다 처음 한 번 몸짓 (칠하기는 멈추지 않음)
	dog.react("set_mood", mood)
	if dog.model.has_method("watch"): dog.model.watch(point, true)
	if not _reacted.has(stage):
		_reacted[stage] = true
		dog.react(STAGE_REACTION[stage])
		if stage == "rinse":
			dog.splash()
			sfx.play("shake")
	_check_done()


## 최종 단계 반짝이 (자주 터지지 않게 0.15초에 한 번, now 면 바로)
func _final_sparkle(point: Vector3, now := false) -> void:
	if _final_left > 0.0 and not now:
		return
	_final_left = 0.15
	_sparkle.global_position = point
	_sparkle.restart()
	_sparkle.emitting = true


## 손 자리를 받아 이번 프레임 움직임(hand_move)을 잼. null 이면 손을 뗀 것
func _track_hand(hand: Variant) -> void:
	hand_move = (hand - _last_hand) if hand != null and _last_hand != null else Vector3.ZERO
	_last_hand = hand


## 수건 톡: 클릭 한 번마다 그 자리를 꾹 눌러 닦음 (누르고만 있으면 안 닦임, GDD_V4 손동작 다시 정리).
## 한 번에 v4_rate_towel_tap 만큼, 물방울이 뚝뚝 + 털이 덜 젖어 보이게 마른 쪽으로도 조금
func tap_at(point: Vector3) -> void:
	if not has_dog or done or held != "towel":
		return
	if stage_index < STAGES.size() and STAGES[stage_index].id != "towel":
		_show_hint("헹굼까지 끝난 뒤에 수건으로 톡톡 닦아요", 1.5)
		return
	if quirk == "towel":
		# 수건 무는 손님: 물고 있으면 톡이 안 됨 (마우스를 좌우로 살살 흔들면 놓음, 벌점 없음). 단짝은 줄다리기 놀이
		if trust_tier >= 3:
			if like("quirk_play"):
				_quirk_overcome = true
				dog.react("wiggle_legs")
				_show_hint("수건 줄다리기 놀이! 꼬리 붕붕 ♥", 1.5)
		elif towel_bitten:
			_show_hint("수건을 물었어요! 마우스를 좌우로 살살 흔들어요", 1.5)
			return
		elif _rng.randf() < FpTrust.towel_bite_chance(trust_tier):
			towel_bitten = true
			_towel_flips = 0
			dog.react("shake")
			_show_hint("앙! 수건을 물었어요 (마우스를 좌우로 살살)", 1.8)
			return
	if animal_trait == "ticklish":
		# 톡 한 번 = 한 곳에 0.3초 머문 셈
		_tickle(point, dog.to_model(point), 0.3)
	var radius := brush_radius(point) * size_mult("towel")
	var amount: float = Tuning.data.v4_rate_towel_tap * speed_mult("towel")
	dog.paint("towel", point, radius, amount)
	dog.paint("dry", point, radius, amount * TOWEL_DRY_SHARE)
	dog.press_effect(point)
	if is_final("towel"):
		_final_sparkle(point, true)
	sfx.play("towel")
	if _held_view != null:
		_held_view.tap()
	dog.react("set_mood", 2)
	if not _reacted.has("towel"):
		_reacted["towel"] = true
		dog.react(STAGE_REACTION["towel"])
	_check_done()


## 붓 반경(m): 몸 겉면의 v4_brush_share 만큼 덮는 원 (구 위 원뿔 각 → 몸 중심에서의 거리)
func brush_radius(point: Vector3) -> float:
	var angle := acos(1.0 - 2.0 * Tuning.data.v4_brush_share)
	return angle * maxf(dog.dir_of(point).length(), 0.05)


## 단계가 끝났는지 차례로 본다 (앞 단계가 끝나야 다음 단계 끝을 알림)
func _check_done() -> void:
	var p := progress()
	while stage_index < STAGES.size():
		var id: String = STAGES[stage_index].id
		if id == "trim" and trim_request.is_empty():
			stage_index += 1
			continue
		if not _stage_met(id, p):
			break
		_finish_stage(STAGES[stage_index])
		stage_index += 1
		# 단계가 끝나며 바뀐 것 (드라이 끝 → 엉킨 뭉치) 을 다시 읽음
		p = progress()
	if stage_index >= STAGES.size() and not done:
		done = true
		_stop_effects()
		# 처음 안내: 목욕통 옆 주인 위 ▼ (돌려주면 사라짐)
		if has_dog and guests.current != null:
			guide.show_tip("give_back", guests.current, func() -> bool: return not has_dog)
		if has_dog:
			if _t - _tub_start <= Tuning.data.v4_mood_fast:
				like("fast")
			# 성격 맞춤: 성격 손님을 싫어함 0 으로 끝냄 (멋쟁이는 빗질 +1 로 이미 셈)
			if animal_trait != "" and animal_trait != "dandy" and _rule_count.is_empty():
				like("trait_clean")
		dog.react("set_mood", FpAnimals.model_mood(face()))
		dog.react("jump")
		sfx.play("clap")
		_show_hint("주인을 클릭해서 돌려줘요", 999.0)


func _stage_met(id: String, p: Dictionary) -> bool:
	var done_at: float = Tuning.data.v4_done_ratio
	match id:
		"wet":
			return p.wet >= done_at
		"scrub":
			return p.scrub >= done_at
		"rinse":
			return p.foam == 0
		"towel":
			return p.towel >= done_at
		"dry":
			return p.dry >= done_at
		"trim":
			return p.trim_left == 0
	# 빗질: 엉킨 뭉치를 다 풂
	return p.tangles == 0


## 단계 끝: 소리 + 반짝 파티클 + 가운데 큰 글자 (다음 도구 빛남은 _process)
func _finish_stage(stage: Dictionary) -> void:
	sfx.play(stage.sound)
	sfx.play("ding")
	_sparkle.global_position = dog.model.to_global(dog._body_center())
	_sparkle.restart()
	_sparkle.emitting = true
	_banner = stage.text
	_banner_left = 2.0
	dog.set_blink(0.0, stage.id)
	if stage.id == "scrub" and not no_shampoo:
		_use_shampoo()
	elif stage.id == "brush" and brush_life() > 0:
		brush_used += 1
	if stage.id == "towel" and animal == "cat" and not _wet_checked:
		_wet_checked = true
		var wet_limit := FpTrust.cat_wet_limit(trust_tier)
		if _wet_started and _t - _wet_since > wet_limit:
			if dislike("cat_wet", 1, "shake"):
				_show_hint("냥… 너무 오래 젖어 있었어요 (%d초 넘음)" % int(wet_limit), 2.5)
	if stage.id == "brush" and animal_trait == "dandy":
		# 멋쟁이: 빗질을 끝까지 → +1 (싫어함 하나를 지우는 셈) + 뽐내기. 성격 맞춤 +1 과 겹치지 않음
		like("dandy")
		dog.react("jump")
		_banner = "반짝! 멋쟁이가 뽐내요"
	# 버릇을 넘음: 그 단계를 싫어함 없이 끝냄 → 사진첩 '처음 ~한 날' (돌려줄 때 기록)
	if quirk == "shower" and stage.id == "wet" and _rule_count.get("shower_fear", 0) == 0:
		_quirk_overcome = true
	if quirk == "dryer" and stage.id == "dry" and _rule_count.get("dryer_noise", 0) == 0:
		_quirk_overcome = true
	# 처음 안내: 다음 단계 손동작 (도구가 손에 있으면 바로, 없으면 집을 때)
	if stage_index + 1 < STAGES.size() and STAGES[stage_index + 1].tool == held:
		guide.show_tip("stage_" + STAGES[stage_index + 1].id)
	if stage.id == "dry":
		_spawn_tangles()
	elif stage.id == "brush" and not trim_request.is_empty():
		_spawn_trim()
		_banner = "빗질 끝! 이제 가위로 %s" % FpTrim.SHAPES[trim_request].name


## 거품 단계 하나 = 샴푸 한 마리분 (거품 도구 단계가 높으면 덜 씀). 3마리분 남는 순간 한 번 알림
func _use_shampoo() -> void:
	var before := shampoo_left
	var uses: PackedFloat32Array = Tuning.data.v4_shampoo_use5
	shampoo_left = maxf(0.0, shampoo_left - uses[tool_level.shampoo])
	var alert: float = Tuning.data.v4_shampoo_alert_at
	if before > alert and shampoo_left <= alert:
		_show_hint("샴푸가 %s마리분 남았어요 (하루 끝 가게에서 사요)" % _amount(shampoo_left), 4.0)


## 남은 샴푸 글자: 마리분은 정수로 (반 마리는 내림, QA #137)
static func _amount(value: float) -> String:
	return str(floori(value + 0.001))


## 드라이가 끝나면 엉킨 털 뭉치가 보임
func _spawn_tangles() -> void:
	tangles.spawn(dog.model, dog._body_center(), Tuning.data.v4_cat_tangles if animal == "cat" else Tuning.data.v4_tangles, _rng, FUR_COLOR)


## 미용 다발을 만듦 (빗질이 끝나면, 요청 손님만)
func _spawn_trim() -> void:
	trim.spawn(trim_request, dog.model, dog._body_center(), _rng, FUR_COLOR)


## 다발 하나가 사각 잘림: 털 조각이 떨어짐 (작은 반짝), 잘못 자른 곳이면 한숨
func _on_snipped(world_point: Vector3, wanted: bool) -> void:
	_sparkle.global_position = world_point
	_sparkle.restart()
	_sparkle.emitting = true
	sfx.play("press")
	if not wanted:
		_show_hint("앗, 남길 곳을 잘랐어요 (모양이 덜 비슷해져요)", 1.5)


## 미용 팁: 요청 모양과 비슷한 정도 (v4_trim_match_at 넘으면 비슷함 / 똑같음)
func trim_tip(score: float) -> int:
	var at: PackedFloat32Array = Tuning.data.v4_trim_match_at
	var tip_table: PackedInt32Array = Tuning.data.v4_trim_match_tip
	if score >= at[1]:
		return tip_table[2]
	if score >= at[0]:
		return tip_table[1]
	return tip_table[0]


## 뭉치 하나가 쓱 풀림: 작은 반짝 + 소리
func _on_untangled(world_point: Vector3) -> void:
	_sparkle.global_position = world_point
	_sparkle.restart()
	_sparkle.emitting = true
	sfx.play("squeak")


## 지금 단계에 쓸 도구 ("" = 다 끝남)
func stage_tool() -> String:
	return STAGES[stage_index].tool if stage_index < STAGES.size() else ""


func _process(delta: float) -> void:
	_hint_left = maxf(_hint_left - delta, 0.0)
	_banner_left = maxf(_banner_left - delta, 0.0)
	_t += delta
	_update_day(delta)
	_update_sniff(delta)
	_card_left = maxf(_card_left - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	if has_dog and not done and _t - _tub_start > Tuning.data.v4_mood_slow:
		dislike("slow", 1)
	if _heart != null and _heart.visible:
		var heart_left: float = _heart.get_meta("left", 0.0) - delta
		_heart.set_meta("left", heart_left)
		_heart.visible = heart_left > 0.0
	if _anger != null and _anger.visible:
		var left: float = _anger.get_meta("left", 0.0) - delta
		_anger.set_meta("left", left)
		_anger.visible = left > 0.0
	_shake_left = maxf(_shake_left - delta, 0.0)
	if _shake_left <= 0.0:
		_shake_flips = 0
		if _carried_view != null:
			_carried_view.rotation.z = move_toward(_carried_view.rotation.z, 0.0, delta)
	if pushing_cart and cart != null:
		# 수레는 플레이어 앞 0.9 m, 손잡이(+Z)가 플레이어 쪽
		var forward := -player.global_basis.z
		forward.y = 0.0
		cart.global_position = player.global_position + forward.normalized() * 0.9
		cart.global_position.y = 0.0
		cart.rotation.y = player.rotation.y
	if input_enabled and not day_over:
		using = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_update_aim()
	# 바라보는 도구는 빛나고, 지금 단계에 쓸 도구는 손에 없으면 선반에서 깜빡깜빡 빛남
	var next := stage_tool()
	for tool_id in _pickups:
		_set_glow(_pickups[tool_id], tool_id == hovered or (tool_id == next and held != next and fmod(_t, 0.8) < 0.5))
	_update_leftovers()
	var active := has_dog and using and aim_point != null and not held.is_empty() and not done
	_update_tool_views(delta, active)
	_huff_left = maxf(_huff_left - delta, 0.0)
	_final_left = maxf(_final_left - delta, 0.0)
	if active:
		# 손 자리 = 가운데 점 광선 위, 겨눈 점까지의 거리 (다발에 겨눔이 붙어도 손을 흔든 만큼 움직임)
		var ray: Array[Vector3] = player.aim_ray(1.0)
		_track_hand(ray[0] + (ray[1] - ray[0]).normalized() * ray[0].distance_to(aim_point))
		_hand_tracked = true
		use_tool_at(aim_point, delta)
		_hand_tracked = false
	else:
		_track_hand(null)
		_stop_effects()
		_dryer_hold = 0.0
		_dryer_inside = false
		if not done and has_dog:
			dog.react("set_mood", mini(FpAnimals.model_mood(face()), 1))
		if dog.model.has_method("watch"): dog.model.watch(null, false)
	_hud.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _card_left > 0.0:
			_card_left = 0.0
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not carried.is_empty():
			open_box()
		elif pushing_cart:
			if not hovered_box.is_empty():
				load_cart(hovered_box)
			else:
				open_cart_box()
		elif hovered_cart:
			push_cart(true)
		elif hovered_book:
			open_album()
		elif hovered_basket:
			open_acc_menu()
		elif not hovered_box.is_empty():
			carry_box(hovered_box)
		elif not hovered.is_empty():
			pick(hovered)
		elif hovered_guest != null:
			interact_guest(hovered_guest)
		elif hovered_sign:
			open_shop()
		elif held == "towel" and aim_point != null:
			tap_at(aim_point)
	elif event is InputEventMouseMotion and not carried.is_empty():
		shake_box((event as InputEventMouseMotion).relative.x)
	elif event is InputEventMouseMotion and towel_bitten:
		shake_towel((event as InputEventMouseMotion).relative.x)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_Q:
				if pushing_cart:
					push_cart(false)
				else:
					drop()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				# 빠른 확인 [도구 업그레이드]: 모든 도구를 그 단계로 (5단계를 다 보기)
				if quick_feature == "upgrade":
					set_all_tiers(event.physical_keycode - KEY_1)
				elif quick_feature == "decor":
					_quick_decor(event.physical_keycode - KEY_1)
			KEY_F1:
				guide.toggle_help()
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_tree().change_scene_to_file(MENU_SCENE)


## 가운데 점이 가리키는 것: 집을 도구 / 강아지
func _update_aim() -> void:
	hovered = ""
	hovered_guest = null
	hovered_sign = false
	hovered_box = {}
	hovered_cart = false
	hovered_book = false
	hovered_basket = false
	aim_point = null
	var ray: Array[Vector3] = player.aim_ray(REACH)
	var query := PhysicsRayQueryParameters3D.create(ray[0], ray[1], (1 << (PICK_LAYER - 1)) | DOG_LAYER)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# 씻는 중 (도구를 들고 아직 안 끝남) 이면 목욕통 옆 주인 몸이 가운데 점을 가려도 강아지를 겨눔
	if not hit.is_empty() and hit.collider.has_meta("guest") and has_dog and not done and not held.is_empty():
		query.exclude = [player.get_rid(), hit.rid]
		hit = get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = hit.collider if not hit.is_empty() else null
	if collider != null and collider.has_meta("tool"):
		hovered = collider.get_meta("tool")
		return
	if collider != null and collider.has_meta("guest"):
		hovered_guest = collider.get_meta("guest")
		return
	if collider != null and collider.has_meta("sign"):
		hovered_sign = true
		return
	if collider != null and collider.has_meta("box"):
		hovered_box = collider.get_meta("box")
		return
	if collider != null and collider.has_meta("cart"):
		hovered_cart = true
		return
	if collider != null and collider.has_meta("album_book"):
		hovered_book = true
		return
	if collider != null and collider.has_meta("acc_basket"):
		hovered_basket = true
		return
	# 가위·빗: 가운데 점 둘레의 다발·뭉치를 바로 겨눔 (몸 겉면 판정이 다른 부위에 먼저 닿거나
	# 강아지가 고개를 돌려도 바라보는 다발이 잘리게, 사람 대표 플레이 버그)
	var target: Variant = _target_on_ray(ray[0], ray[1])
	if target != null:
		aim_point = target
	elif has_dog and collider is CollisionObject3D and (collider as CollisionObject3D).collision_layer & DOG_LAYER:
		aim_point = hit.position


## 가위면 미용 다발, 빗이면 엉킨 뭉치 중 광선에서 TARGET_PICK 안에 있는 가장 가까운 것 (없으면 null)
func _target_on_ray(from: Vector3, to: Vector3) -> Variant:
	if not has_dog or done:
		return null
	var points := PackedVector3Array()
	if held == "scissors" and is_instance_valid(trim):
		points = trim.world_positions(true) + trim.world_positions(false)
	elif held == "brush" and is_instance_valid(tangles):
		points = tangles.world_positions()
	var best: Variant = null
	var best_distance := TARGET_PICK
	for point in points:
		var on_ray := Geometry3D.get_closest_point_to_segment(point, from, to)
		var distance := on_ray.distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = point
	return best


func _tool_tip() -> Vector3:
	if _held_view != null:
		return _held_view.tip_position()
	return player.camera.global_position


func _stop_effects() -> void:
	if sfx == null or dog == null or dog.model == null:
		return
	sfx.set_loop("shower", 0.0)
	sfx.set_loop("foam", 0.0)
	sfx.set_loop("brush", 0.0)
	sfx.set_loop("dryer", 0.0)
	dog.stop_spray()
	dog.hide_stream()


## 남은 곳 보이기: 단계가 반쯤 되면 털 위 안 된 곳이 반짝, 헹굴 때 거품이 몇 개 안 남으면 그 거품이 반짝
func _update_leftovers() -> void:
	var stage_id: String = STAGES[stage_index].id if stage_index < STAGES.size() else ""
	var p := progress()
	var ratio: float = p.get(stage_id, 0.0) if stage_id != "rinse" else 1.0
	dog.set_blink((0.5 + 0.5 * sin(_t * 5.0)) if stage_id != "" and stage_id != "rinse" and ratio >= BLINK_FROM else 0.0, stage_id if stage_id != "" else "wet")
	foam_sparkle = stage_id == "rinse" and p.foam > 0 and p.foam <= FOAM_SPARKLE_BELOW
	dog.set_foam_glow(FOAM_GLOW + (0.5 + 0.5 * sin(_t * 8.0)) * 1.2 if foam_sparkle else FOAM_GLOW)


func _build_stage_effects() -> void:
	_sparkle = CPUParticles3D.new()
	_sparkle.name = "StageSparkle"
	_sparkle.emitting = false
	_sparkle.one_shot = true
	_sparkle.amount = 40
	_sparkle.lifetime = 0.9
	_sparkle.explosiveness = 1.0
	_sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparkle.emission_sphere_radius = 0.3
	_sparkle.direction = Vector3.UP
	_sparkle.spread = 180.0
	_sparkle.initial_velocity_min = 0.6
	_sparkle.initial_velocity_max = 1.6
	_sparkle.gravity = Vector3(0, -1.0, 0)
	_sparkle.scale_amount_min = 0.6
	_sparkle.scale_amount_max = 1.2
	var star := SphereMesh.new()
	star.radius = 0.02
	star.height = 0.04
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.95, 0.55)
	star.material = material
	_sparkle.mesh = star
	add_child(_sparkle)


func _on_guest_arrived() -> void:
	sfx.play("bell")
	if not guide.seen.has("guest") and not guests.guests.is_empty():
		var owner: Node3D = guests.guests[-1].owner
		guide.show_tip("guest", owner, func() -> bool: return has_dog or not is_instance_valid(owner))
	if _hint_left <= 0.0:
		_show_hint("손님이 왔어요 (오른쪽 대기 의자)", 2.0)


func _show_hint(text: String, seconds: float) -> void:
	_hint = text
	_hint_left = seconds


# --- 방·선반·플레이어 (임시 상자)

func _build_room() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.75, 0.85, 0.9)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.9, 0.9, 0.95)
	environment.environment.ambient_light_energy = 0.25
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.4, -1.0)
	lamp.omni_range = 5.0
	lamp.light_energy = 0.25
	add_child(lamp)
	_box("Floor", Vector3(0, -0.1, 0), Vector3(8, 0.2, 7), Color(0.45, 0.58, 0.6))
	_box("WallBack", Vector3(0, 1.5, -3.5), Vector3(8, 3, 0.2), Color(0.85, 0.78, 0.66))
	_box("WallFront", Vector3(0, 1.5, 3.5), Vector3(8, 3, 0.2), Color(0.85, 0.78, 0.66))
	_box("WallLeft", Vector3(-4, 1.5, 0), Vector3(0.2, 3, 7), Color(0.8, 0.72, 0.6))
	# 오른쪽 벽(정문)과 가게 앞 마당은 FpOutside
	var tub := TUB_SCENE.instantiate() as Node3D
	_tub_view = tub
	tub.position = Vector3(DOG_SPOT.x, 0, DOG_SPOT.z)
	add_child(tub)
	# 목욕대 받침 충돌 (걸어서 통과하지 않게)
	_box("TubBlock", Vector3(DOG_SPOT.x, 0.45, DOG_SPOT.z), Vector3(1.6, 0.9, 1.1), Color(0, 0, 0, 0), false)


func _build_shelf() -> void:
	_box("Shelf", Vector3(-2.2, 0.45, -0.8), Vector3(0.6, 0.9, 1.8), Color(0.72, 0.55, 0.38))
	var z := -1.6
	for tool_id in TOOLS:
		var pickup := StaticBody3D.new()
		pickup.name = "Pickup_" + tool_id
		pickup.collision_layer = 1 << (PICK_LAYER - 1)
		pickup.collision_mask = 0
		pickup.set_meta("tool", tool_id)
		pickup.position = Vector3(-2.2, 0.9, z)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.3, 0.35, 0.3)
		shape.shape = box
		shape.position.y = 0.17
		pickup.add_child(shape)
		var view := _make_tool_mesh(tool_id)
		# GLB 는 쥐는 곳이 원점: 각 메시 최저점을 선반 위에 맞춘다.
		view.position.y = {"shower": 0.130, "shampoo": 0.074, "towel": 0.002, "dryer": 0.056, "brush": 0.02, "scissors": 0.01}[tool_id]
		view.rotate_y(PI / 2.0) # -Z 앞면을 선반 바깥(+X)으로 (보정 회전은 그대로)
		view.name = "View"
		pickup.add_child(view)
		_cache_glow_materials(tool_id, view)
		add_child(pickup)
		_pickups[tool_id] = pickup
		z += 0.33


func _build_player() -> void:
	player = FpPlayer.new()
	player.name = "Player"
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	body.shape = capsule
	body.position.y = 0.8
	player.add_child(body)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position.y = FpPlayer.EYE_HEIGHT
	camera.fov = 70.0
	camera.current = true
	player.add_child(camera)
	player.position = Vector3(0, 0.05, 0.6)
	add_child(player)


## 자산 경로와 손목 연출은 FpToolView 한 곳에서 교체한다.
func _make_tool_mesh(tool_id: String) -> Node3D:
	return FpToolView.make_model(tool_id)


## GLB 는 material_override 가 아니라 여러 surface 재질을 사용한다.
## 인스턴스마다 복제하여 선반 강조가 손에 든 도구/원본 자산에 번지지 않게 한다.
func _cache_glow_materials(tool_id: String, view: Node3D) -> void:
	var materials: Array[StandardMaterial3D] = []
	var meshes: Array[Node] = view.find_children("*", "MeshInstance3D", true, false)
	if view is MeshInstance3D:
		meshes.append(view)
	for node in meshes:
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material := original.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(surface, material)
			material.emission = Color(1.0, 0.9, 0.5)
			material.emission_energy_multiplier = 0.6
			materials.append(material)
	_glow_materials[tool_id] = materials


## 바라보는 선반 도구의 원래 파스텔 색·라벨을 보존하며 강조한다.
func _set_glow(pickup: Node3D, on: bool) -> void:
	var tool_id: String = pickup.get_meta("tool")
	for material in _glow_materials[tool_id]:
		material.emission_enabled = on and pickup.visible


func _box(box_name: String, pos: Vector3, size: Vector3, color: Color, visible_mesh := true) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if visible_mesh:
		var mesh := BoxMesh.new()
		mesh.size = size
		var view := MeshInstance3D.new()
		view.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		view.material_override = material
		body.add_child(view)
	add_child(body)


# --- 화면 (가운데 점, 바라보는 것, 진행, 조작)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = get_tree().root.theme
	_hud.draw.connect(_draw_hud)
	layer.add_child(_hud)
	Settings.ensure_loaded()
	guide = FpGuide.new()
	guide.name = "Guide"
	guide.enabled = Settings.guide_enabled and quick_dogs == 0 and quick_feature.is_empty()
	layer.add_child(guide)


func _draw_hud() -> void:
	var size := _hud.get_viewport_rect().size
	var center := size / 2.0
	var font := _hud.get_theme_default_font()
	# 가운데 점 (도구를 쓸 수 있는 곳이면 노랑)
	var ready_to_use := aim_point != null and not held.is_empty()
	_hud.draw_circle(center, 5.0, Color(0, 0, 0, 0.6))
	_hud.draw_circle(center, 3.0, Color(1, 0.85, 0.3) if ready_to_use or not hovered.is_empty() or hovered_guest != null or hovered_sign or not hovered_box.is_empty() else Color(1, 1, 1))
	var under := ""
	if not carried.is_empty():
		under = "가게 밖에서는 못 열어요 · 안으로 들고 가요" if FpOutside.is_outside(player.global_position) else "클릭: 상자 열기"
	elif pushing_cart:
		if not hovered_box.is_empty():
			under = "클릭: 수레에 싣기 (%d/%d칸)" % [cart_used(), Tuning.data.v4_cart_slots]
		elif not cart_load.is_empty():
			under = "가게 밖에서는 못 열어요" if FpOutside.is_outside(player.global_position) else "클릭: 맨 위 상자 열기 · Q 수레 놓기"
		else:
			under = "수레 (Q 놓기)"
	elif hovered_cart:
		under = "클릭: 수레 밀기"
	elif hovered_basket:
		under = "클릭: 액세서리 바구니 (다 씻은 뒤 하나 씌우기, 가진 것 %d개)" % acc_owned.size()
	elif hovered_book:
		under = "클릭: 손님 사진첩 (만난 단골 %d / %d)" % [album.size(), FpRegulars.all().size()]
	elif not hovered_box.is_empty():
		under = "클릭: 택배 상자 들기 (들고 좌우로 흔들면 달그락)"
	elif not hovered.is_empty():
		under = "클릭: %s 집기" % TOOLS[hovered].name
	elif hovered_sign:
		under = "클릭: 팻말 뒤집기 (영업 시작)" if morning else ("영업 중" if guests.open else "오늘 영업 끝")
	elif hovered_guest != null:
		if hovered_guest == guests.current:
			under = ("클릭: %s 돌려주기" % ("고양이" if animal == "cat" else "강아지")) if done else "다 씻으면 돌려줘요"
		else:
			under = "목욕통이 비면 받아요" if has_dog else "클릭: 강아지 맡기"
	elif aim_point != null and held.is_empty():
		under = "선반에서 도구를 집어요"
	elif ready_to_use and held == "towel":
		under = "클릭할 때마다 톡톡 닦아요"
	elif ready_to_use and not using:
		under = "누르고 있으면 %s" % {"shower": "물이 나와요 (헹굴 땐 위→아래로)", "shampoo": "거품 (좌우로 비비면 몽글몽글)", "towel": "", "dryer": "바람 (가까이 가면 빨라요)", "brush": "빗어요 (뭉치에 위→아래로 쓱쓱)", "scissors": "사각사각 잘라요"}[held]
	_text(font, center + Vector2(0, 40), under, 22, true)
	# 진행 (목욕통에 강아지가 있을 때만)
	var p := progress()
	var rows := [["물", p.wet], ["거품 (진흙)", p.scrub], ["수건 (톡톡)", p.towel], ["말리기", p.dry], ["빗질 (엉킨 털 %d)" % p.tangles, p.brush * Tuning.data.v4_done_ratio]] if has_dog else []
	if has_dog and not trim_request.is_empty():
		var total: int = maxi(trim.wanted_total(), 1)
		rows.append(["미용 (자를 곳 %d)" % p.trim_left, (1.0 - float(p.trim_left) / total) * Tuning.data.v4_done_ratio if trim.wanted_total() > 0 else 0.0])
		_draw_trim_card(font, Vector2(20, 30 + 7 * 34))
	for i in rows.size():
		var y := 30.0 + i * 34.0
		_hud.draw_rect(Rect2(20, y, 220, 22), Color(0, 0, 0, 0.5))
		_hud.draw_rect(Rect2(20, y, 220 * clampf(rows[i][1] / Tuning.data.v4_done_ratio, 0.0, 1.0), 22), Color(0.5, 0.85, 0.55) if rows[i][1] >= Tuning.data.v4_done_ratio else Color(0.45, 0.7, 1.0))
		_text(font, Vector2(250, y + 18), rows[i][0], 18, false)
	if has_dog and p.foam > 0:
		_text(font, Vector2(20, 30 + 5 * 34 + 18), "남은 거품 %d (샤워기로 헹구기)" % p.foam, 18, false)
	if _flash > 0.0:
		_hud.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash * 1.6))
	_draw_animal_box(font)
	if _card_left > 0.0 and not _card.is_empty():
		_draw_card(font, size)
	if quick_dogs > 0:
		_text(font, Vector2(size.x - 20, 40), "빠른 확인 · 강아지 %d / %d" % [guests.served, quick_dogs], 26, false, true)
	else:
		var day_name := "%d일차%s" % [day, " · 자유 영업" if FpDays.is_free_play(day) else ""]
		_text(font, Vector2(size.x - 20, 40), ("%s · 아침 준비" % day_name) if morning else "%s · %s%s" % [day_name, clock_text(), "" if guests.open else " · 영업 끝"], 26, false, true)
	_text(font, Vector2(size.x - 20, 74), "돈 %d" % money, 26, false, true)
	_text(font, Vector2(size.x - 20, 104), "기다리는 손님 %d · 씻긴 %d · 떠난 %d" % [guests.guests.size(), guests.served, guests.left_count], 18, false, true)
	_text(font, Vector2(size.x - 20, size.y - 60), "손: %s" % (tool_name(held) if not held.is_empty() else "빈손"), 22, false, true)
	_text(font, Vector2(20, size.y - 20), "WASD 걷기 · 마우스 보기 · 클릭 집기/쓰기(누르고 있기) · Q 내려놓기 · 손님 클릭 맡기기/돌려주기 · Esc 메뉴", 16, false)
	if _hint_left > 0.0:
		_text(font, Vector2(center.x, 120), _hint, 26, true)
	if _banner_left > 0.0:
		_text(font, center + Vector2(0, -90), _banner, 44, true)


## 미용 요청 카드: 모양 이름 + 한 줄 + 강아지 옆모습 (자를 곳은 분홍, 남길 곳은 털색). 임시 그림
## 목욕대 위 고양이·성격 칸의 한 줄 (테스트도 읽음)
func _draw_animal_line() -> String:
	return animal_line() if has_dog else ""


## 목욕대 위 한 줄: 고양이·성격 + 신뢰 단계 + 도구 버릇
func animal_line() -> String:
	var parts: Array = []
	var line := FpAnimals.line_of(animal, animal_trait)
	if not line.is_empty():
		parts.append(line)
	if not regular.is_empty():
		parts.append("%s %s" % [FpTrust.NAMES[trust_tier], FpTrust.HEARTS[trust_tier]])
	if FpTrust.QUIRKS.has(quirk) and trust_tier < 3:
		parts.append(FpTrust.QUIRKS[quirk].line)
	return " · ".join(parts).strip_edges()


## 목욕대 위 고양이·성격 칸 (진행 막대 오른쪽): 색 점 + 한 줄 + 싫어한 횟수 점
func _draw_animal_box(font: Font) -> void:
	if not has_dog:
		return
	var line := animal_line()
	if line.is_empty():
		return
	var at := Vector2(420, 26)
	var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 56 + 18 * dislikes()
	_hud.draw_rect(Rect2(at, Vector2(width, 32)), Color(0, 0, 0, 0.5))
	var color: Color = FpAnimals.TRAITS[animal_trait].color if FpAnimals.TRAITS.has(animal_trait) else Color(0.75, 0.75, 0.8)
	_hud.draw_circle(at + Vector2(16, 16), 8.0, color)
	_text(font, at + Vector2(32, 22), line, 18, false)
	# 싫어한 횟수 (빨간 점)
	for i in dislikes():
		_hud.draw_circle(at + Vector2(width - 14 - 18 * i, 16), 6.0, Color(1.0, 0.35, 0.35))


## 처음 나온 고양이·성격 안내 카드 (가운데, 몇 초 뒤 닫힘)
func _draw_card(font: Font, size: Vector2) -> void:
	var lines: PackedStringArray = _card.split("\n")
	var height := 40.0 + 34.0 * lines.size()
	var rect := Rect2(Vector2(size.x / 2.0 - 380, size.y * 0.28), Vector2(760, height))
	_hud.draw_rect(rect, Color(1.0, 0.97, 0.9, 0.95))
	_text(font, Vector2(size.x / 2.0, rect.position.y + 26), _card_title, 22, true)
	for i in lines.size():
		_hud.draw_string(font, Vector2(rect.position.x + 24, rect.position.y + 58 + 34 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 712, 18, Color(0.3, 0.22, 0.15))


func _draw_trim_card(font: Font, at: Vector2) -> void:
	var shape: Dictionary = FpTrim.SHAPES[trim_request]
	_hud.draw_rect(Rect2(at, Vector2(250, 150)), Color(0, 0, 0, 0.5))
	_text(font, at + Vector2(12, 26), "미용 요청: %s" % shape.name, 20, false)
	_text(font, at + Vector2(12, 50), shape.about, 15, false)
	var cut: Array = shape.cut
	var base := at + Vector2(70, 105)
	var paint := func(zone: String) -> Color: return Color(1.0, 0.55, 0.7) if zone in cut else Color(0.96, 0.87, 0.7)
	_hud.draw_circle(base + Vector2(-38, -6), 9, paint.call("tail"))
	for x in [-18, 22]:
		_hud.draw_rect(Rect2(base + Vector2(x, 10), Vector2(10, 26)), paint.call("legs"))
	_hud.draw_circle(base, 30, paint.call("body"))
	_hud.draw_circle(base + Vector2(38, -26), 20, paint.call("head"))
	_text(font, at + Vector2(150, 100), "분홍 = 자를 곳", 14, false)


func _text(font: Font, at: Vector2, text: String, font_size: int, centered: bool, right := false) -> void:
	if text.is_empty():
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := at - Vector2(width / 2.0 if centered else (width if right else 0.0), 0)
	_hud.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.8))
	_hud.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))
