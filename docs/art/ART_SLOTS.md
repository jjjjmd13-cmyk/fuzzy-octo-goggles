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

### 2-1. `cat` 고양이 (V4: 3일차부터 / from day 3)

- **V4 요청문 (A 파스텔, 2026-11-04)**: [ORDER_V4_CAT.md](ORDER_V4_CAT.md) — 지금 `dog.glb` 의 실제 노드 이름·계층(`Torso`, `Head` 자식 `Eye_L`→`Pupil_L`·`Glint_L`, `Leg_FL`→`Paw_FL`, `Haunch_L`, `Paw_BL`, `Tail_1→2→3`, `FaceCenter`, `BodyCenter`)과 털 재질 이름 `FurCleanAlbedo` 를 그대로 옮김. 귀 안쪽 분홍 = `NoFurEar_L/R`.

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

### 4-1. `plant` 창가 화분 (꾸미기, 컴퓨터에서 80에 삼)

- **납품 / Deliver**: `assets/models/plant/plant.glb` → `scenes/art/sim/plant_model.tscn` (지금은 화분 + 잎 구 3개 임시 모형).
- **크기·원점**: 높이 약 0.8 m (게임이 0.6 배로 목욕대 받침 왼쪽 뒤 모서리에 올림), 원점 = 화분 바닥 가운데. 움직이는 부위 없음, 이름 자유. ~0.8 m tall, origin at pot bottom centre; no moving parts.

### 4-2. V4 가게 꾸미기 `decor` (2026-11-04)

1인칭 가게 방에 놓는 꾸미기 30개 (GDD_V4 '가게 꾸미기'). 요청문: [ORDER_V4_DECOR.md](ORDER_V4_DECOR.md).

- **가게 방**: 바닥 8 m (X) × 7 m (Z), 벽 높이 3 m. 원점 = 바닥 가운데 (y = 0). 뒷벽 z = −3.5 (목욕통이 뒷벽 쪽 (0, 0, −1.6)), 문 = 오른쪽 벽 (x = +4, z = +2.6), 대기 의자 = 오른쪽 벽 앞 x = 3.0, 도구 선반 = 왼쪽 (−2.2, 0, −0.8).
- **공통**: 0장 규칙 + 파스텔 장난감풍 (ORDER_V3 0장 색표), 원점 = 바닥 가운데 (벽에 거는 것은 **뒷면 가운데**, 매다는 것은 **맨 위 걸이**), 정면 −Z (게임이 자리에 맞게 돌림). 텍스처 1024² 이하. 글자 넣지 않음.
- **파일**: 3D = `assets/models/decor/<범주>_<이름>.glb`, 반복 텍스처 = `assets/textures/decor/<범주>_<이름>.png` (1024², 이어 붙여도 이음새 없음, 한 장 = 벽·바닥 **1 m × 1 m**). 받으면 `art/incoming/decor/` 에 올리고 개발팀이 옮김.

| 범주 (파일 앞부분) | 크기·원점 | 삼각형 | ★1 / ★2 / ★3 | 움직이는 부위 |
|---|---|---|---|---|
| `wall` 벽지 (PNG) | 1 m × 1 m 반복 | — | `wall_stripe` / `wall_bubble` / `wall_paw` | — |
| `floor` 바닥 (PNG) | 1 m × 1 m 반복 | — | `floor_wood` / `floor_check` / `floor_star` | — |
| `tub` 목욕통 | 4장 `tub` 와 **같은 크기·높이** (받침 윗면 0.9 m, 1.6 × 1.1 m, 안쪽 바닥 y ≈ 0.9) | 4,000 | `tub_wood` / `tub_claw` / `tub_shell` | `Stand`, `Tub` (이름 같게. `Plug` 는 있으면) |
| `shelf` 도구 선반 | 길이 1.8 m (X) × 깊이 0.6 m × **윗면 0.9 m, 평평** (도구 5개가 위에 놓임) | 3,000 | `shelf_wood` / `shelf_basket` / `shelf_cloud` | — |
| `counter` 카운터 | 약 1.2 × 0.5 m, 높이 0.95 m | 3,000 | `counter_wood` / `counter_bone` / `counter_cake` | — |
| `sign` 간판 (벽, 목욕통 위) | 약 1.6 × 0.5 m, 두께 0.08 m. 원점 = 뒷면 가운데. 가운데에 글자 넣을 빈 판 | 1,500 | `sign_board` / `sign_paw` / `sign_rainbow` | — |
| `lamp` 조명 (천장에 매닮) | 전체 길이 약 0.7 m, 갓 지름 약 0.4 m. 원점 = 맨 위 걸이 | 1,500 | `lamp_bulb` / `lamp_bubble` / `lamp_cloud` | `Bulb` (빈 오브젝트 가능, 게임이 여기에 빛을 둠) |
| `plant` 화분 | 높이 약 0.6 / 0.9 / 1.3 m | 2,000 | `plant_round` / `plant_monstera` / `plant_lemon` | — |
| `rug` 러그 | 약 1.6 × 1.0 m, 두께 0.01~0.02 m (걸려 넘어지지 않게 납작) | 500 | `rug_circle` / `rug_paw` / `rug_rainbow` | — |
| `art` 벽 장식 | 약 0.6 × 0.5 m, 두께 0.05 m. 원점 = 뒷면 가운데 | 1,500 | `art_dog` / `art_clock` / `art_bubble` | 시계만 `Hand_H`, `Hand_M` (원점 = 시계 가운데, Z 축으로 돎) |

- 처음 모습(지금 임시 벽·바닥·목욕통·선반)은 그대로 '기본'. 카운터·간판·조명·화분·러그·벽 장식은 처음엔 없음.
- 놓는 자리는 개발팀이 정함 (제안: 간판 = 뒷벽 목욕통 위 · 조명 = 목욕통 위 천장 · 카운터 = 문 옆 · 러그 = 문에서 목욕통 가는 길 · 화분 = 대기 의자 옆 · 벽 장식 = 왼쪽 벽).

### 4-3. V4 가게 밖·택배 `outside` (2026-11-04)

정문(오른쪽 벽 x = +4, 문 가운데 z = +2.6) 밖 **마당** 약 5 m × 7 m (x = 4 ~ 9, z = −3.5 ~ 3.5) 와 택배 (GDD_V4 '가게 밖·택배'). 요청문: [ORDER_V4_OUTSIDE.md](ORDER_V4_OUTSIDE.md).

- **공통**: 0장 규칙 + 파스텔 장난감풍 (A, ORDER_V3 0장 색표), 원점 = 바닥 가운데 (따로 적은 것 빼고), 정면 −Z, 텍스처 1024² 이하, 글자 넣지 않음.
- **파일**: `assets/models/outside/<이름>.glb`, 반복 텍스처 `assets/textures/outside/<이름>.png` (1024², 한 장 = 1 m × 1 m, 이음새 없음). 받으면 `art/incoming/outside/`.

| 이름 | 무엇 | 크기·원점 | 삼각형 | 움직이는 부위 |
|---|---|---|---|---|
| `shop_front` | 가게 바깥 벽 (차양·창문 2·문틀) | 길이 7 m × 높이 3 m, 두께 0.2 m, 위에 차양. 문 구멍 폭 1.2 × 높이 2.1 m (벽 가운데에서 +2.6 m 쪽). 원점 = 벽 아랫변 가운데, 바깥쪽이 −Z | 5,000 | `Door` (문짝, 원점 = 경첩, Y 축으로 열림), `Bell` (문 종, 원점 = 매단 곳) |
| `sign_outside` | 바깥 간판 (문 위) | 2.0 × 0.6 m, 두께 0.1 m. 원점 = 뒷면 가운데. 가운데 빈 판 (글자는 게임이) | 1,500 | — |
| `open_sign` | 영업 팻말 (문 안쪽에 걺) | 0.35 × 0.25 m. 원점 = 걸이. 앞 = 해 그림, 뒤 = 달 그림 | 500 | `Plate` (원점 = 걸이 아래, Y 축으로 뒤집힘) |
| `paving` (PNG) | 마당 보도블록 | 1 m × 1 m 반복 | — | — |
| `road` (PNG) | 찻길 | 1 m × 1 m 반복 (가운데 줄 없는 아스팔트, 줄은 `road_line`) | — | — |
| `road_line` (PNG) | 찻길 가운데 점선 | 1 m × 1 m 반복, 점선이 가운데 세로 | — | — |
| `box_small` | 작은 상자 | 0.3 × 0.25 × 0.25 m | 500 | `Lid_L`, `Lid_R` (뚜껑 날개, 원점 = 접히는 선) |
| `box_medium` | 중간 상자 | 0.5 × 0.4 × 0.4 m | 500 | 같음 |
| `box_large` | 큰 상자 | 0.9 × 0.6 × 0.6 m | 500 | 같음 |
| `truck` | 작은 배달 트럭 | 약 3.5 × 1.8 × 2.0 m (길이·폭·높이), 앞이 −Z | 6,000 | `Wheel_FL`, `Wheel_FR`, `Wheel_BL`, `Wheel_BR` (원점 = 바퀴 축, X 축으로 돎), `Door_Back` (원점 = 위 경첩, X 축으로 열림) |
| `cart` | 택배 수레 | 0.9 × 0.6 m, 짐칸 높이 0.3 m, 손잡이 높이 1.0 m (손잡이가 +Z 쪽, 미는 쪽이 −Z) | 2,000 | `Wheel_L`, `Wheel_R` (원점 = 바퀴 축) |
| `mailbox` | 우편함 | 높이 1.2 m | 1,000 | `Flag` (원점 = 깃발 축, X 축으로 올라감) |
| `street_lamp` | 가로등 | 높이 3.0 m | 1,500 | `Bulb` (빛 자리, 빈 오브젝트 가능) |
| `fence` | 낮은 울타리 한 칸 | 길이 2.0 m × 높이 0.8 m (이어서 놓음) | 800 | — |
| `flower_bed` | 화단 한 칸 | 2.0 × 0.6 × 0.4 m (이어서 놓음) | 2,000 | — |
| `delivery_mat` | 택배 매트 | 1.6 × 1.0 m, 두께 0.02 m | 300 | — |

- 놓는 자리 (제안, 개발팀이 정함): 택배 매트 (5.0, 0, 0.5) · 우편함 (8.4, 0, −2.6) · 가로등 (8.6, 0, 1.4) · 울타리·화단 x ≈ 9 줄 (손님 길 z ≈ 2.6 자리에 찻길로 이어지는 틈 1.5 m) · 트럭은 울타리 밖 찻길 x ≈ 10.5.

### 4-4. V4 손님 사진첩 3D (2026-11-04)

GDD_V4 '손님 사진첩'. 0장 규칙 + A 파스텔, 원점 바닥 가운데 (벽 것은 뒷면 가운데), 정면 −Z. `assets/models/album/<이름>.glb`.

| 이름 | 무엇 | 크기·원점 | 삼각형 | 움직이는 부위 |
|---|---|---|---|---|
| `album_book` | 카운터 위 사진첩 책 (닫힌 모습) | 약 0.35 × 0.28 × 0.06 m, 원점 = 책 바닥 가운데. 분홍 천 표지 + 금색 발바닥 장식, 앞에 작은 리본 끈 | 800 | `Cover` (앞표지, 원점 = 책등 쪽 경첩, Y 축으로 열림) |
| `photo_board` | 사진 게시판 (24마리 보상, 벽 장식 자리) | 약 1.0 × 0.7 m, 두께 0.04 m, 원점 = 뒷면 가운데. 원목 테 코르크판 + 위에 작은 꽃 리본 | 1,000 | `Slot_1` ~ `Slot_6` (빈 오브젝트, 사진 붙는 자리 가운데. 사진 크기 0.2 × 0.2 m) |

- 단골 24마리는 **새 3D 모형 없음** (강아지·고양이 모형에 털 색·크기·목걸이 색만 코드로).

### 4-5. V4 액세서리 `accessory` (2026-11-05)

씻긴 뒤 강아지·고양이에게 씌우는 것 (GDD_V4 '액세서리'). 0장 규칙 + A 파스텔, 정면 −Z (동물 얼굴 쪽), 1u = 1m. `assets/models/accessory/<이름>.glb`.

- **붙는 자리**: 게임이 동물 모형 씬에 빈 노드 `Acc_Head` (머리 꼭대기), `Acc_Neck` (목 둘레 가운데), `Acc_Ear` (오른쪽 귀 옆) 를 둠 → 액세서리 **원점을 그 자리에** 맞춰 만듦. 크기는 **강아지 기준** (머리 폭 약 0.24 m, 목 둘레 지름 약 0.16 m), 고양이는 게임이 0.85 배.
- 삼각형 각 800 이하, 텍스처 512² 이하. 움직이는 부위 없음 (리본 끝이 흔들리는 건 게임이).

| 범주 | 원점 (붙는 자리) | 크기 | ★1 / ★2 / ★3 |
|---|---|---|---|
| 리본 `ribbon_*` | 리본 매듭 아래 가운데 → `Acc_Head` | 폭 약 0.10 m | `ribbon_pink` (처음) / `ribbon_polka` / `ribbon_gold` |
| 모자 `hat_*` | 모자 바닥 가운데 → `Acc_Head` | 바닥 지름 약 0.10~0.14 m, 높이 0.06~0.12 m | `hat_party` / `hat_beret` / `hat_crown` |
| 스카프 `scarf_*` | 고리 가운데 → `Acc_Neck` (안쪽 지름 약 0.16 m, 앞에 매듭이 −Z) | 고리 + 늘어진 끝 약 0.08 m | `scarf_mint` / `scarf_bandana` / `scarf_cape` |
| 꽃핀 `pin_*` | 핀이 꽂히는 점 → `Acc_Ear` | 약 0.05 m | `pin_daisy` / `pin_star` / `pin_rainbow` |
| 바구니 `acc_basket` | 바닥 가운데 (목욕대 옆에 놓임) | 약 0.35 × 0.25 × 0.15 m | 한 개 |

### 4-6. V4 축제 (18일차) `festival` (2026-11-05)

GDD_V4 '마지막 날 — 반짝 목욕 축제'. 0장 규칙 + A 파스텔. 개발팀 #125 의 교체 경로 그대로 — 파일이 들어오면 **코드 수정 없이** 임시 도형 대신 쓰임. 요청문: [ORDER_V4_FESTIVAL.md](ORDER_V4_FESTIVAL.md).

| 파일 | 무엇 | 원점·크기 | 삼각형 | 움직이는 부위 |
|---|---|---|---|---|
| `assets/models/outside/festival_yard.glb` | 축제 마당 장식 한 덩어리 (풍선 묶음 3곳 + 삼각 깃발 줄 + 작은 꽃 아치) | **원점 = 가게 방 바닥 가운데** (4-3 의 방 좌표 그대로, 돌리지 않고 놓음). 풍선: 정문 양옆 (4.5, 0, 1.6)·(4.5, 0, 3.2), 우편함 옆 (7.8, 0, −2.4), 높이 1.5~1.9 m. 깃발 줄: 가게 벽 위 (4.2, 2.6, 1.2) → 마당 끝 (8.7, 2.6, 1.2), 가운데가 약 0.35 m 처짐. 손님 길 (z ≈ 2.6) 과 문 (높이 2.1 m) 을 막지 않게 | 4,000 | — (흔들림은 게임이) |
| `assets/models/outside/festival_hat.glb` | 주인 축제 고깔모자 | **원점 = 모자 바닥 가운데** (게임이 주인 `Head` 위 0.2 m 에 붙임). 바닥 지름 약 0.18 m, 높이 약 0.2 m | 600 | — |
| `assets/models/outside/invite_letter.glb` | 우편함에 꽂힌 축제 초대장 봉투 | **원점 = 봉투 가운데**. 약 0.22 × 0.14 m, 두께 0.02 m (두께 방향이 Z). 게임이 우편함 입구 위에 놓고 위에 글자("축제 초대장" / "축제 오늘!") 를 띄움 → 봉투에 글자 없음 | 300 | — |

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

### 6-1. V4 손 도구 — 업그레이드·미용 (2026-11-03)

1인칭에서 **손에 들고 화면 오른쪽 아래에 보이는** 도구입니다. `assets/models/tools/<이름>.glb` 로 들어오면 **코드 수정 없이** 바뀝니다 (`art/incoming/tools/` 에 올리면 개발팀이 옮김).

공통: 원점 = **손잡이 쥐는 곳**, 도구 끝이 **−Z**, 1 단위 = 1 m, **파스텔 장난감풍** (V2·V3 색표), **삼각형 3,000 이하**, 텍스처 1024² 이하.

| 이름 | 무엇 | 크기 | 업그레이드 느낌 | 움직이는 부위 (선택) |
|---|---|---|---|---|
| `brush.glb` | 일반 빗 (기본) | 길이 약 0.2 m | 나무 손잡이 + 굵은 빗살 | — |
| `brush_slicker.glb` | 슬리커 브러시 (2단계) | 약 0.2 m | 네모난 머리에 가는 철사 빗살 촘촘히 | — |
| `brush_electric.glb` | 전동 브러시 (3단계) | 약 0.22 m | 둥근 회전 머리 + 버튼, 반짝이는 색 | `Head` (원점 = 회전축 가운데, Z 축으로 돎) |
| `shower_wide.glb` | 넓은 샤워기 (2단계) | 약 0.28 m | 기본보다 넓은 둥근 판 | — |
| `shower_rain.glb` | 레인 샤워기 (3단계) | 약 0.32 m | 크고 납작한 원판에 구멍 많이 | — |
| `foam_pump.glb` | 거품 펌프 (2단계) | 높이 약 0.22 m | 위에 누르는 펌프 머리 | `Pump` (원점 = 눌리는 축, Y 로 눌림) |
| `foam_cannon.glb` | 거품 대포 (3단계) | 길이 약 0.35 m | 장난감 물총 모양, 큰 통 | — |
| `dryer_big.glb` | 큰 송풍 드라이기 (2단계) | 길이 약 0.4 m | 기본보다 큰 통, 넓은 입구 | `Fan` (기본 드라이어와 같은 규칙) |
| `scissors.glb` | 미용 가위 | 길이 약 0.18 m | 둥근 손잡이 고리, 끝이 뭉툭 (무섭지 않게) | `Blade_L`, `Blade_R` (원점 = 나사 자리, Y 축으로 벌어짐) |

- 이름이 다르거나 움직이는 부위가 없어도 **들고 쓰는 건 됨** (부위가 있으면 코드가 움직임).
- 요청문: [ORDER_V4_TOOLS.md](ORDER_V4_TOOLS.md).

### 6-2. V4 도구 5단계 — 아직 없는 것 (2026-11-04)

GDD_V4 '업그레이드 — 도구마다 5단계' 표 기준. 6-1 과 같은 규칙 (원점 = 쥐는 곳, 끝 −Z, 1u = 1m, 파스텔 장난감풍, 삼각형 3,000 이하, 텍스처 1024² 이하). `assets/models/tools/<이름>.glb`.

| 단계 | 샤워기 | 거품 | 수건 | 드라이 | 빗 |
|---|---|---|---|---|---|
| 1 | `shower` ✔ | `shampoo` ✔ | `towel` (**다시**: 손에 쥔 모양) | `dryer` ✔ | `brush` ✔ |
| 2 | `shower_wide` ✔ | `foam_pump` ✔ | `towel_thick` 새로 | `dryer_big` ✔ | `brush_slicker` ✔ |
| 3 | `shower_rain` ✔ | `foam_sponge` 새로 | `towel_microfiber` 새로 | `dryer_twin` 새로 | `brush_twin` 새로 |
| 4 | `shower_massage` 새로 | `foam_cannon` ✔ | `towel_mitt` 새로 | `dryer_turbo` 새로 | `brush_electric` ✔ |
| 5 ("와") | `shower_rainbow` 새로 | `foam_cloud` 새로 | `towel_cloud` 새로 | `dryer_tornado` 새로 | `brush_sparkle` 새로 |

✔ = 이미 있음 (PR #85 등). 새로 필요한 것 **14개** — 크기·움직이는 부위는 [ORDER_V4_TOOLS.md](ORDER_V4_TOOLS.md) 2차 요청문.

## 7. 2D 그림 (PNG 만 / PNG only)

원래 2D 인 것만 PNG 입니다. 이름·크기·쓰는 곳 표는 **`assets/ui/README.md`** 에 있습니다 (도구 아이콘 6, 세로 요청 카드, ✓ 도장, 기분 얼굴 3, 동전, 말풍선, 요청 아이콘, 가게 간판, 목욕대 뒤 배경 그림, 주인 판자 그림).
- 투명 배경 PNG. 한 장에 여러 개를 그려도 됩니다 (개발팀이 `tools/cut_ui_art.py` 로 자름).
- 글자를 넣지 마세요 (가게 이름 등은 게임이 글자로 올림 — 한/영 번역).
- **아직 필요한 것 / Still needed**: `tool_hand`(장갑 손 아이콘), `tool_bucket`(바가지 아이콘), `card_vertical`(세로로 긴 요청 카드, 6줄), `bubble`(말풍선), `bath_backdrop`(목욕대 뒤 배경 그림 4:3).

### 7-1. V4 손님 사진첩 2D (2026-11-04)

`assets/ui/album/<이름>.png`, 투명 배경, 글자 없음 (이름·숫자는 게임이 올림). A 파스텔 색표.

| 이름 | 무엇 | 크기 |
|---|---|---|
| `album_page` | 펼친 사진첩 한 쪽 바탕 (크림색 종이, 모서리에 작은 발바닥) | 1024 × 1280 |
| `photo_frame_grey` · `_white` · `_pink` · `_gold` | 사진 테두리 4종 (😣 회색 · 😐 흰색 · 😊 분홍 하트 · 🤩 금색 반짝). 가운데 정사각 투명 구멍 | 512 × 600 (폴라로이드처럼 아래가 넓게) |
| `photo_unknown` | 아직 못 만난 손님 '?' 실루엣 (강아지·고양이 겹친 회색 그림자) | 512 × 512 |
| `fav_spot_chin` · `_ear_back` · `_back` · `_rump` | 좋아하는 곳 작은 그림 (몸 실루엣에 하트 하나) | 128 × 128 |
| `new_photo_badge` | "새 사진!" 반짝 별 스티커 (글자 없이 별 모양만) | 128 × 128 |

## 8. 개발팀이 연결하는 법 (참고 / how we wire it)

- GLB 를 `art/incoming/<슬롯>/` 에서 `assets/models/<슬롯>/` 으로 옮기고, `scenes/art/sim/<슬롯>_model.tscn` 안에서 GLB 를 Y 로 180° 돌려 자식으로 넣습니다.
- 강아지: 씬 루트에 `scripts/sim/sim_dog_model.gd` 를 붙이면 위 이름으로 부위를 찾아 움직이고, 털 셰이더·마우스 판정을 자동으로 붙입니다. 주인: `scripts/sim/sim_owner_model.gd`.
- 이름이 다르거나 원점이 어긋나면 그 부위만 안 움직입니다 (게임이 멈추지는 않음). 개발팀이 씬에서 이름을 고쳐 맞출 수도 있습니다.


## 9. 2026-10-27 사용자 그래픽 방향 변경

사용자가 **Dooms Hair Salon / Onigiri Shop Simulator의 그래픽**을 참고하도록 지시했다. 현재 납품물은 위 0·2장의 좌표·크기·부위 이름·관절 피벗·계층·예산·깨끗한 알베도 규칙을 유지하면서 형태와 재질을 수정한 1차 버전이다. 주인의 2등신 비율과 과도하게 둥근 가구 모서리, 파스텔 장난감의 표면감은 이번 시각 방향에 맞춰 성인에 가까운 비율·실제 가구 두께·차분한 표면으로 변경했다. `Shirt`·`Hat`의 흰색과 6개 색 변경은 유지한다.

현재 납품 기준과 검수 결과는 `docs/art/DELIVERY_SLOTS.md`, 시각 변경 목록은 `ART_DIRECTION.json`에 있다. 협동 여부는 이번 그래픽 수정으로 확정하지 않는다.
