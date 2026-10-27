# 그래픽 교체 명세서 / Art Slots

> 이 문서만 읽고 바로 그래픽을 만들 수 있게 쓴 명세입니다. **기본 납품물은 GLB (3D)** 이고, 원래 2D 인 것(아이콘·UI)만 PNG 입니다.
> This spec lets an outside artist (e.g. ChatGPT) deliver art from the repo alone. **Default deliverable is GLB (3D).** Only things that are 2D by nature (icons, UI) are PNG.

게임: "Paws & Bubbles / 멍냥 목욕탕" — 귀여운 장난감 같은 파스텔 3D, 고정 작업대 카메라. 스타일 기준 그림: `art/incoming/01_bath_scene_redraw.png`. 색표: `docs/art/ORDER_V3.md` 0장.

## 0. 모든 GLB 공통 규칙 / Rules for every GLB

| | 규칙 | Rule |
|---|---|---|
| 형식 | glTF 2.0 바이너리 `.glb`, 텍스처는 파일 안에 넣기 (PNG) | glTF 2.0 binary, textures embedded (PNG) |
| 단위 | 1 단위 = 1 m, Y 위 | 1 unit = 1 m, Y-up |
| 정면 | **−Z** 를 바라봄 (게임이 씬 안에서 180° 돌려 카메라 쪽 +Z 로 맞춤) | Model faces **−Z** (the game rotates it 180° inside the wrapper scene) |
| 원점(피벗) | 따로 적지 않으면 **바닥 가운데** | Unless stated: **bottom center** |
| 움직이는 부위 | 뼈대(armature) 대신 **따로 떨어진 오브젝트**로, 오브젝트 원점을 **관절 자리**에. 이름은 아래 표 그대로 (대소문자 구분, 영어) | Use **separate objects, not an armature**. Put each object's origin at its **joint**. Use the **exact names** below (case-sensitive) |
| 애니메이션 | **필요 없음.** 코드가 이름으로 부위를 찾아 움직임 | **Not needed.** Code animates parts found by name |
| 재질 | 색 텍스처(albedo)만. 노멀·빛 굽기(bake) 없이. 텍스처 1024² 이하 (강아지만 2048² 까지) | Albedo only, no normal maps or baked lighting. ≤1024² (dog ≤2048²) |
| 올리는 곳 | `art/incoming/<슬롯>/` 에 GLB + 미리보기 PNG 1장 → 개발팀이 연결 | Upload to `art/incoming/<slot>/` with one preview PNG; the dev team wires it in |

L/R(왼쪽·오른쪽)은 **캐릭터 자신의** 왼쪽·오른쪽입니다. / L/R = the character's own left/right.

## 1. 한눈에 / Overview

| 슬롯 Slot | 납품 Deliver | 들어가는 곳 Goes into | 지금 임시 모형 Current placeholder |
|---|---|---|---|
| `dog` 강아지 | `art/incoming/dog/dog.glb` | `scenes/art/sim/dog_model.tscn` | 구·캡슐 장난감 (`scripts/sim/toy_dog_model.gd`) |
| `owner` 주인 손님 | `art/incoming/owner/owner.glb` | `scenes/art/sim/owner_model.tscn` | 2등신 장난감 (`scripts/sim/toy_owner_model.gd`) |
| `tub` 목욕통·받침·도구걸이 | `art/incoming/tub/tub.glb` | `scenes/art/sim/tub_model.tscn` | 원기둥·상자 |
| `turntable` 회전판 | `art/incoming/turntable/turntable.glb` | `scenes/art/sim/turntable_model.tscn` | 원판 |
| `chair` 대기 의자 | `art/incoming/chair/chair.glb` | `scenes/art/sim/chair_model.tscn` | 상자 |
| `tiles` 바닥·벽 타일 | GLB 또는 텍스처 PNG | `scenes/art/tiles/floor_tile.tscn`, `wall_tile.tscn` | 단색 상자 |
| `tools` 도구 6개 (3D, **나중에 씀**) | `art/incoming/tools/<이름>.glb` | (아직 없음 — 지금은 2D 커서) | — |
| 2D (PNG 만) | `assets/ui/<이름>.png` | HUD·말풍선·간판 | 받은 그림 일부 연결됨 |

스크린샷(지금 모습): `docs/dev/screenshots/toy_dog_*.jpg`, `docs/dev/screenshots/station_owner.jpg`

---

## 2. `dog` 강아지 (가장 중요 / most important)

- **크기 Size**: 앉은 자세 기본, 앉은 키 약 0.6 m, 앞뒤 길이 약 0.6 m. Sitting pose, ~0.6 m tall, ~0.6 m long.
- **상한 Budget**: 삼각형 8,000 이하, 텍스처 2048² 1장 이하. ≤ 8,000 triangles, one ≤2048² texture.
- **참고 Reference**: `art/incoming/02_puppy_turnaround.png`(모양), `04_puppy_expressions_3d.png`(표정). 털 색 #F5DEB3, 한쪽 귀 연갈색.

**오브젝트 이름 (정확히) / Object names (exact)** — 원점은 관절 자리 / origin at the joint:

| 이름 Name | 원점 Origin | 코드가 하는 것 What code does |
|---|---|---|
| `Head` | 목 (머리와 몸이 만나는 곳) | 커서 따라보기, 물을 피해 고개 돌리기, 털기 |
| `Chest` | 가슴 가운데 | 숨쉬기 (살짝 커졌다 작아짐) |
| `Eye_L`, `Eye_R` | 눈 가운데 (Head 의 자식) | 깜빡임·찡그림 (세로로 납작하게) |
| `Ear_L`, `Ear_R` | 귀 뿌리 (Head 의 자식), 귀는 아래로 늘어진 모양 | 기분에 따라 처짐·쫑긋, 드라이어에 팔랑 |
| `Tail_1` → `Tail_2` → `Tail_3` | 각 마디의 뿌리. `Tail_2` 는 `Tail_1` 의 자식, `Tail_3` 은 `Tail_2` 의 자식 | 흔들기, 처짐 |
| `Leg_FL`, `Leg_FR` | 앞다리 어깨 | 간지럼에 찰랑 |
| `Cheek_L`, `Cheek_R` (선택) | 볼 가운데 | 드라이어에 볼 펄럭 |
| `Mouth` | 입 | 기분에 따라 크기 |
| `Tongue` | 혀 (따로 떨어진 오브젝트) | 기분 좋을 때만 보임 |
| `Nose` | 코 | — |
| `FaceCenter` (빈 오브젝트, 선택) | 두 눈 사이 | "눈에 물" 판정 중심 |
| `BodyCenter` (빈 오브젝트, 선택) | 몸통 가운데 | 더러움 칠하기 중심 |

그 밖의 오브젝트(몸통·엉덩이·뒷다리·발 등)는 이름 자유. Other objects may have any name.

**재질 / Materials**
- **털 = 이름이 `Eye`·`Pupil`·`Glint`·`Nose`·`Mouth`·`Tongue`·`Collar`·`NoFur` 로 시작하지 않는 모든 메시.** 털 메시는 게임의 털 셰이더로 바뀌고, 원래 재질의 albedo 텍스처는 털 색으로 그대로 쓰입니다. Fur = every mesh whose name does NOT start with those prefixes; fur meshes get the game's fur shader, which keeps your albedo texture as fur color.
- 털 텍스처는 **깨끗한 털 색만** (진흙·젖음·거품·뽀송 상태를 그리지 마세요). **진흙·젖음(진하고 반짝)·거품 공·물방울·뽀송(밝게 부풀기)은 셰이더와 코드가 만듭니다.** Paint clean fur only — the shader draws mud, wet, foam, drops and fluffy.
- 털 UV 는 겹치지 않게. 눈·코·혀는 각자 재질 (털 아님). Fur UVs must not overlap; eyes/nose/tongue keep their own materials.
- 마우스 판정은 털 오브젝트마다 볼록 껍질로 자동 생성 → 몸통이 크게 오목하면 2~3 조각으로 나눠 주세요. Hit shapes are convex hulls per fur object; split strongly concave parts into 2–3 pieces.

### 2-1. `cat` 고양이 (2일차부터 / from day 2)

- **강아지와 같은 약속** — 노드 이름·원점·털/비털 메시·깨끗한 털 색 규칙이 모두 2장과 같습니다. Same contract as the dog (section 2).
- **크기 Size**: 앉은 키 약 0.5 m, 강아지보다 조금 작고 날씬하게. 귀는 **위로 선 삼각형** (안쪽 분홍은 `NoFur…` 이름의 따로 된 메시), 꼬리는 길고 가늘게 (`Tail_1→2→3`, 위로 감아 올림). ~0.5 m sitting; upright pointed ears; long thin tail.
- **납품 / Deliver**: `assets/models/cat/cat.glb` → `scenes/art/sim/cat_model.tscn` (지금은 임시 모형 `scripts/sim/toy_cat_model.gd`).
- **털 색**: 회색 단색이면 충분 (줄무늬는 텍스처로 그려도 됨, 상태는 그리지 않기). Plain grey is fine.

## 3. `owner` 주인 손님

- **크기 Size**: 서 있는 키 약 1.55 m, 2등신 장난감 비율, 팔은 아래로. ~1.55 m tall, chunky toy proportions, arms down.
- **상한 Budget**: 삼각형 4,000 이하, 텍스처 1024² 이하.
- **6명 / 6 variants**: GLB 하나. 재질 이름이 **`Shirt`** 와 **`Hat`** 인 부분을 게임이 6가지 색으로 바꿉니다 (흰색·밝은 단색으로 두기). 다른 재질은 그대로. One GLB; surfaces whose material is named `Shirt` / `Hat` are recolored by the game.

| 이름 Name | 원점 Origin | 코드가 하는 것 |
|---|---|---|
| `Body` | 바닥 가운데 (몸 전체를 담는 부모) | 걸을 때 통통, 앉기, 한숨에 움츠림 |
| `Head` | 목 | 끄덕, 고개 숙임 |
| `Arm_L`, `Arm_R` | 어깨 | 강아지 안고 오기, 박수, 걷기 |
| `Leg_L`, `Leg_R` | 엉덩이 | 걷기, 의자에 앉기 (코드가 다리를 앞으로 굽힘) |
| `Knee_L`, `Knee_R` (선택) | 무릎 (`Leg_L`/`Leg_R` 의 자식, 아래로 정강이·발) | 앉을 때 무릎을 90° 굽히고 정강이 길이를 맞춰 발바닥을 바닥에 붙임. 없으면 다리 전체를 굽힘 |

말은 하지 않음 — 머리 위 말풍선은 게임이 그립니다.

## 4. `tub` 목욕통 · `turntable` 회전판 · `chair` 의자

| 슬롯 | 크기·원점 Size & origin | 오브젝트 이름 Names |
|---|---|---|
| `tub` | 받침 윗면 높이 0.9 m, 받침 1.6 × 1.1 m. 원점 바닥 가운데. **낮고 넓은 원형 욕조** (안쪽 바닥 y≈0.9, 테두리는 그 위 약 0.16 m, 반지름 약 0.6 m) — 앞(카메라 쪽) 테두리가 낮아 안이 다 보이게. 의자형 설계 그림(05)보다 **분위기 그림(01)을 우선** | `Stand`(받침), `Tub`(욕조), `Plug`(빨간 마개), `ToolRack`(도구걸이, 오른쪽) |
| `turntable` | 지름 약 1.0 m, 두께 0.04 m. **원점 = 원판 가운데** (윗면이 y = +0.02). 코드가 이 원점을 축으로 돌림 | `Plate` |
| `chair` | 앉는 면 높이 0.4 m, 폭 0.45 m. 원점 바닥 가운데, 정면 −Z | 자유 |

삼각형: 목욕통 4,000 · 회전판 800 · 의자 1,500 이하. 참고: `art/incoming/05_bathtub_turnaround.png`, `01_bath_scene_redraw.png`.

## 5. `tiles` 바닥·벽 타일

- 바닥 2 × 2 m (윗면 y = 0), 벽 2 × 2 m · 두께 0.3 m (아랫변 가운데가 원점, 방 안쪽이 +Z). 벽은 2단으로 쌓아 4 m.
- GLB 또는 **이어 붙여도 이음새가 안 보이는 PNG 텍스처** (`art/incoming/tiles/floor.png`, `wall.png`, 1024²). 색: 바닥 민트 #DFF5EC, 벽 버터 노랑 #FFF1C9.

## 6. `tools` 도구 3D (나중에 씀 / later)

지금은 2D 커서로 그리고 있습니다. 3D 도구를 받으면 커서 자리에 손에 든 모습으로 띄울 예정입니다. 원점 = **손잡이 잡는 곳**, 정면 −Z (도구 끝이 −Z).

| 이름 | 크기 | 움직이는 부위 |
|---|---|---|
| `shower.glb` 샤워기 | 길이 약 0.25 m | — (물줄기는 게임이 그림) |
| `bottle_basic.glb`, `bottle_peach.glb` 샴푸 병 | 높이 약 0.2 m | — (찌그러짐은 코드가 크기로) |
| `glove.glb` 장갑 손 (문지르기) | 약 0.15 m | — |
| `bucket.glb` 바가지 | 지름 약 0.2 m | — (기울기는 코드) |
| `towel.glb` 수건 | 접은 크기 약 0.25 × 0.15 m | — |
| `dryer.glb` 드라이어 | 길이 약 0.3 m | `Fan` (날개, 원점 = 날개 축 가운데, Z 축으로 돎) |

참고: `art/incoming/06_grooming_tools_turnaround.png`, `07_yellow_glove_turnaround.png`.

## 7. 2D 그림 (PNG 만 / PNG only)

원래 2D 인 것만 PNG 입니다. 이름·크기·쓰는 곳 표는 **`assets/ui/README.md`** 에 있습니다 (도구 아이콘 6, 세로 요청 카드, ✓ 도장, 기분 얼굴 3, 동전, 말풍선, 요청 아이콘, 가게 간판, 목욕대 뒤 배경 그림, 주인 판자 그림).
- 투명 배경 PNG. 한 장에 여러 개를 그려도 됩니다 (개발팀이 `tools/cut_ui_art.py` 로 자름).
- 글자를 넣지 마세요 (가게 이름 등은 게임이 글자로 올림 — 한/영 번역).
- **아직 필요한 것 / Still needed**: `tool_hand`(장갑 손 아이콘), `tool_bucket`(바가지 아이콘), `card_vertical`(세로로 긴 요청 카드, 6줄), `bubble`(말풍선), `bath_backdrop`(목욕대 뒤 배경 그림 4:3).

## 8. 개발팀이 연결하는 법 (참고 / how we wire it)

- GLB 를 `art/incoming/<슬롯>/` 에서 `assets/models/<슬롯>/` 으로 옮기고, `scenes/art/sim/<슬롯>_model.tscn` 안에서 GLB 를 Y 로 180° 돌려 자식으로 넣습니다.
- 강아지: 씬 루트에 `scripts/sim/sim_dog_model.gd` 를 붙이면 위 이름으로 부위를 찾아 움직이고, 털 셰이더·마우스 판정을 자동으로 붙입니다. 주인: `scripts/sim/sim_owner_model.gd`.
- 이름이 다르거나 원점이 어긋나면 그 부위만 안 움직입니다 (게임이 멈추지는 않음). 개발팀이 씬에서 이름을 고쳐 맞출 수도 있습니다.


## 9. 2026-10-27 사용자 그래픽 방향 변경

사용자가 **Dooms Hair Salon / Onigiri Shop Simulator의 그래픽**을 참고하도록 지시했다. 현재 납품물은 위 0·2장의 좌표·크기·부위 이름·관절 피벗·계층·예산·깨끗한 알베도 규칙을 유지하면서 형태와 재질을 수정한 1차 버전이다. 주인의 2등신 비율과 과도하게 둥근 가구 모서리, 파스텔 장난감의 표면감은 이번 시각 방향에 맞춰 성인에 가까운 비율·실제 가구 두께·차분한 표면으로 변경했다. `Shirt`·`Hat`의 흰색과 6개 색 변경은 유지한다.

현재 납품 기준과 검수 결과는 `docs/art/DELIVERY_SLOTS.md`, 시각 변경 목록은 `ART_DIRECTION.json`에 있다. 협동 여부는 이번 그래픽 수정으로 확정하지 않는다.
