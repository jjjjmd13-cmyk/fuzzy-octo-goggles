# 그림 넣을 자리 (교체 지점 표)

MILESTONE_V3_SLICE 8장. 그래픽(ChatGPT 납품)은 **아래 파일 이름 그대로** 넣으면 코드를 바꾸지 않고 바로 쓰입니다.
없으면 지금 임시 그림(코드로 그린 도형·임시 모형)으로 그대로 동작합니다.
그래픽 주문서는 대표 세션 문서 `docs/art/ORDER_V3.md`, 3D 납품 규칙(노드 이름·원점·재질)은 `docs/art/ART_SLOTS.md`, 2D 자세한 크기는 `assets/ui/README.md` 를 따릅니다.

상태: ✅ 받은 그림이 연결됨 · ⬜ 아직 없음 (임시로 동작)

## 2D (`assets/ui/<이름>.png`, 읽는 곳 `scripts/game/ui_art.gd` 의 `UiArt.texture(이름)`)

| 자리 | 파일 | 보이는 곳 | 읽는 코드 | 없을 때 | 상태 |
|---|---|---|---|---|---|
| 도구 아이콘 6 | `tool_shower` `tool_bottle` `tool_hand` `tool_bucket` `tool_towel` `tool_dryer` | 도구걸이·커서·요청 카드 줄 | `hud.gd`, `hud_overlay.gd` | 글자 버튼·도형 커서 | ✅ |
| 넓은 샤워기 아이콘 | `tool_shower_wide` | 넓은 샤워기를 산 뒤 샤워기 커서 | `hud_overlay.gd` | 보통 샤워기 그림을 크게 + 넓이 원 | ⬜ |
| 요청 카드 | `card_vertical` | 왼쪽 위 6줄 요청 카드 바탕 | `hud.gd` | 기본 판 | ✅ |
| 끝 도장 | `check` | 요청 카드 줄 끝 | `hud.gd` | ✓ 글자 | ✅ |
| 말풍선 + 아이콘 | `bubble`, `icon_bath` `icon_peach` `icon_drop` | 주인 머리 위 요청 | `hud_overlay.gd` | 흰 네모·도형 | ✅ |
| 기분 얼굴 3 | `face_unhappy` `face_neutral` `face_happy` | 왼쪽 기분 얼굴, 정산의 가장 기뻐한 손님 | `hud_overlay.gd`, `hud.gd` | 도형 얼굴 | ✅ |
| 동전 | `coin` | 위 가운데 돈 | `hud.gd` | "돈 N" 글자 | ✅ |
| 가게 간판 | `sign` | **메뉴 제목 뒤** + 목욕대 뒤 벽 (가운데 빈칸에 "멍냥 목욕탕" 글자) | `main_menu.gd`, `wash_station.gd` | 글자 제목만 / 벽에 없음 | ✅ |
| 목욕대 뒤 배경 그림 | `bath_backdrop` | 목욕대 뒤 벽 전체 | `wash_station.gd` | 타일 벽·창문 | ✅ |
| 성격 그림 2 | `trait_ticklish` `trait_timid` | 요청 카드 오른쪽 위 모서리 | `hud_overlay.gd` | 깃털·물방울 도형 | ⬜ |
| 벽시계 판 | `clock` | 위 가운데 돈 옆 (바늘은 게임이 그림) | `hud_overlay.gd` | 도형 시계 | ⬜ |
| 손동작 그림 6 | `hint_wet` `hint_squeeze` `hint_scrub` `hint_rinse` `hint_towel` `hint_dry` | 1일차 첫 손님 단계 안내 | `guide_overlay.gd` | 움직이는 도형 | ⬜ |
| 조작 그림 | `help_controls` | F1 | `guide_overlay.gd` | 도형 마우스 + 글자 | ⬜ |
| 주인 판자 그림 6 | `owner_0` ~ `owner_5` | 주인 (3D 대신 판자처럼) | `sim_owner_model.gd` | 3D 주인 모형 (GLB 가 있으면 GLB 가 먼저) | ⬜ (3D 로 대신함) |

## 3D (교체 씬 한 곳씩, GLB 를 이 씬 안에 넣음)

| 자리 | 교체 씬 | 지금 | 상태 |
|---|---|---|---|
| 강아지 | `scenes/art/sim/dog_model.tscn` | `assets/models/dog/dog.glb` | ✅ |
| 고양이 | `scenes/art/sim/cat_model.tscn` | 임시 장난감 모형 (`toy_cat_model.gd`) | ⬜ |
| 주인 (6가지 색) | `scenes/art/sim/owner_model.tscn` | `assets/models/owner/owner.glb` | ✅ |
| 목욕통 | `scenes/art/sim/tub_model.tscn` | `assets/models/tub/` | ✅ |
| 회전판 | `scenes/art/sim/turntable_model.tscn` | `assets/models/turntable/` | ✅ |
| 의자 (목욕대 옆·대기 의자 3) | `scenes/art/sim/chair_model.tscn` | `assets/models/chair/` | ✅ |
| 바닥·벽 타일 | `scenes/art/tiles/floor_tile.tscn`, `wall_tile.tscn` | `assets/models/tiles/` | ✅ |
| 꾸미기 화분 | `scenes/art/sim/plant_model.tscn` | 임시 (화분 + 잎 구) | ⬜ |

## 소리·음악 (같은 이름으로 바꿔 넣으면 교체)

| 자리 | 파일 | 지금 |
|---|---|---|
| 효과음 | `assets/sfx/<이름>.wav` (`scripts/game/sfx.gd` 목록) | `tools/make_sfx.py` 로 만든 임시 소리 |
| 음악 | `assets/music/bgm_shop.wav`, `settle_jingle.wav` | `tools/make_music.py` 로 합성 (CC0) |
