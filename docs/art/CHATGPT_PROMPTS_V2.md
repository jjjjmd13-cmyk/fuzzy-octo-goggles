# 멍냥 목욕탕 — ChatGPT 그래픽 요청문

작성: 기획팀 · 2026-10-26 · 근거: [GDD_V2.md](../design/GDD_V2.md)
(등불 원정대용 [CHATGPT_PROMPTS.md](CHATGPT_PROMPTS.md) 는 기록으로 남겨 둠. 파일·좌표 규칙은 같은 방식)

**순서**: ① 스타일 가이드 → ② 공통 머리말을 모든 요청 앞에 붙임 → ③ **P0(시제품에 필요) 먼저**.

---

## 1. 받는 방법

| 종류 | 받는 것 | 쓰는 곳 |
|---|---|---|
| 컨셉 그림 | PNG (분위기, 정면·옆·위 도면) | 스타일 맞추기, 3D 모형 기준 |
| 텍스처 | PNG, 이음새 없는 정사각 | 바닥·벽 타일 |
| 3D 모형 | GLB (안 되면 OBJ) | 게임에 바로 넣음 |
| 2D 아이콘 | PNG, 투명 배경 | 말풍선 그림, 하트, 별 |

- ChatGPT 3D 생성은 결과가 들쭉날쭉 → **3D 요청에는 늘 정면·옆 도면 그림도 같이** 받아 두고, 안 되면 도면을 보고 단순 모형으로 다시 만듦.
- 받은 파일은 이 문서의 **ID** 로 이름 붙임 (`PET-01_dog.glb`). 목록·상태는 `docs/art/ASSETS_V2.md` (받기 시작하면 만듦).
- **돈 드는 것 없음**: ChatGPT 사용 외에 유료 에셋·서비스를 쓰지 않음. 소리도 CC0 무료만 (GDD_V2 4.1).

---

## 2. 스타일 가이드

### 2.1 한 줄 스타일

**"말랑한 파스텔 장난감 목욕탕"** — 동글동글한 큰 덩어리, 밝은 파스텔, 단순한 색면. 모서리는 전부 둥글게. 무섭거나 어두운 요소 없음.

### 2.2 색

| 쓰임 | 이름 | 색 |
|---|---|---|
| 바닥 타일 | 민트 크림 | `#DFF5EC` / 줄눈 `#B8E3D3` |
| 벽 | 버터 노랑 | `#FFF1C9` |
| 나무 (가구) | 밝은 원목 | `#E8C9A0` |
| 기계 몸체 | 하늘 파랑 | `#8FD3F4` |
| 기계 포인트 | 체리 빨강 | `#FF6B6B` |
| 거품 | 흰 거품 | `#FFFFFF` + 연한 무지개 반사 |
| **진흙 상태** | 초코 진흙 | `#8B5E3C` |
| **젖음 상태** | 원래 털색보다 30% 진하게 + 물방울 `#5BC0EB` | |
| **뽀송 상태** | 원래 털색보다 15% 밝게 | |
| UI 강조 | 딸기 우유 | `#FF9EC4` |
| 하트 | 하트 빨강 | `#FF5A7A` |
| 별 | 별 노랑 | `#FFD23F` |

- 규칙: **배경(바닥·벽)은 연하게, 동물·기계는 진하게** → 위에서 내려다볼 때 할 일이 바로 눈에 띔.
- 동물 상태 색은 위 3단계를 꼭 지킴 (진흙 = 갈색, 젖음 = 진함+물방울, 뽀송 = 밝고 부풂).

### 2.3 형태

- 큰 머리·짧은 다리의 **2등신 장난감 비율**. 눈은 까만 점 두 개 + 하이라이트 하나. 입은 작은 선.
- 위에서 비스듬히 내려다보는 카메라 → **위에서 봤을 때 실루엣**으로 동물 종류를 알 수 있어야 함 (귀 모양·꼬리가 중요).
- 가는 장식·글자 금지. 기계는 큰 버튼·큰 손잡이.

### 2.4 폴리곤·텍스처

| 종류 | 삼각형 (최대) | 텍스처 |
|---|---|---|
| 바닥·벽 조각 | 300 | 공용 512×512 |
| 소품 | 800 | 512×512 |
| 기계 | 2,000 | 512×512 |
| 동물 | 2,500 | 512×512 (상태별 색은 머티리얼 색으로 바꾸므로 텍스처 1장) |
| 직원 캐릭터 | 2,500 | 512×512 |

- 머티리얼은 모형 하나에 **1개**. 동물은 **털 부분을 한 머티리얼**로 (상태별 색을 코드에서 바꾸기 위해).
- 노멀맵 없음. 단색에 가까운 손칠 텍스처.

### 2.5 파일·좌표 (모든 3D 공통)

- **GLB**, 1 = 1 m, Y 위, 정면 −Z.
- 기준점: 바닥·벽 조각은 바닥면 모서리, 나머지는 바닥면 가운데.
- 가게 바닥은 **2 m 격자** (타일 2.0 × 2.0 m, 벽 높이 2.5 m, 두께 0.2 m). 시제품 방 = 8 × 6 타일 (16 × 12 m).

---

## 3. 공통 머리말 (모든 요청 앞에 붙이기)

```text
Style guide for every asset in this project (game: "Paws & Bubbles", a cute co-op pet grooming game seen from a top-down angled camera):
- Look: "soft pastel toy bathhouse". Chunky rounded shapes, every edge rounded, 2-head-tall toy proportions for characters, simple flat hand-painted colors. Bright, cheerful, never scary or dark. No text or logos.
- Palette: floor mint cream #DFF5EC (grout #B8E3D3), walls butter yellow #FFF1C9, light wood #E8C9A0, machines sky blue #8FD3F4 with cherry red #FF6B6B accents, UI pink #FF9EC4, heart #FF5A7A, star #FFD23F.
- Must read clearly from a top-down 45-degree camera: recognizable silhouette from above.
- 3D files: GLB, 1 unit = 1 meter, Y-up, front faces -Z, pivot at bottom center, one material per model, albedo texture only, no normal maps.
```

바닥·벽 조각 요청에는 아래도 붙임.

```text
Modular room kit rules: everything snaps to a 2 m x 2 m grid. Floor tile exactly 2.0 x 2.0 m, 0.1 m thick, top surface at Y=0, pivot at corner (spans X 0..2, Z 0..2). Wall piece exactly 2.0 m wide, 2.5 m tall, 0.2 m thick, centered on the grid line, pivot at bottom-left corner on the grid line. Flat-cut edges, no gaps, seamless tiling textures. Max 300 triangles per piece.
```

동물 요청에는 아래도 붙임.

```text
Pet rules: cute round toy animal, big head, short legs, two black dot eyes with one highlight, tiny mouth line. The fur must be ONE separate material so the game can recolor it for "muddy / wet / fluffy" states. Neutral standing pose, pivot at feet center, facing -Z. Max 2500 triangles. Also give front, side and top views. Animations needed later: idle, walk, run (escaping), shake (shaking off water), sit, being carried (dangling).
```

---

## 4. 요청 목록 (우선순위)

- **P0** = 첫 시제품에 필요 (GDD_V2 4장) — 먼저
- **P1** = 지역 1 전체 (데모)
- **P2** = 지역 2 이후 / 마케팅

| ID | 이름 | 종류 | 우선 |
|---|---|---|---|
| ART-00 | 분위기 키 아트 | 컨셉 | **P0** |
| PET-01 | 강아지 (+ 상태 4) | 3D | **P0** |
| MAC-01 | 욕조 | 3D | **P0** |
| MAC-02 | 드라이어 | 3D | **P0** |
| ENV-01 | 바닥 타일 + 텍스처 | 3D·텍스처 | **P0** |
| ENV-02 | 벽 조각 | 3D | **P0** |
| ENV-03 | 입구 문 + 출구 문 | 3D | **P0** |
| ENV-04 | 대기석 의자 | 3D | **P0** |
| CHR-01 | 직원 캐릭터 | 3D | **P0** |
| FX-01 | 물웅덩이 | 텍스처(데칼) | **P0** |
| UI-01 | 말풍선 아이콘 (🛁 💨) + 하트 + 별 | 2D | **P0** |
| PET-02 | 고양이 | 3D | P1 |
| PET-03 | 오리 | 3D | P1 |
| PET-04 | 털뭉치 개 (대목날) | 3D | P1 |
| MAC-03 | 빗질대 | 3D | P1 |
| MAC-04 | 리본대 + 리본 | 3D | P1 |
| DEC-01 | 가게 꾸미기 세트 1 (간판·화분·러그·직원 모자 3) | 3D | P1 |
| UI-02 | 말풍선 아이콘 추가 (🪮 🎀), 결과 화면 | 2D | P1 |
| PET-05 | 대형견 | 3D | P2 |
| PET-06 | 꽃게 | 3D | P2 |
| MAC-05 | 털기 기계 (모래) | 3D | P2 |
| ENV-10 | 바닷가 지점 세트 | 3D | P2 |
| ENV-20 | 목욕 버스 내부 세트 | 3D | P2 |
| ART-01 | 스팀 캡슐 이미지 | 2D | P2 |

---

## 5. 요청문 (P0)

각 요청 = **공통 머리말 + (해당 규칙) + 아래 문장**.

### ART-00 분위기 키 아트
```text
Create a wide concept illustration (16:9) of a tiny cozy pet bathhouse seen from a top-down 45-degree angle, like a dollhouse with the roof removed. Four little staff characters in pastel aprons are rushing around: one is washing a muddy puppy in a bubbly bathtub, one holds a blow dryer over a fluffed-up puppy, and one is chasing a soaking-wet puppy that is running away and leaving small water puddles, while another slips on a puddle. Guests wait on chairs with heart icons above their heads. Bright, cheerful, soft pastel toy style from the style guide. This image will be the reference for all other assets.
```

### PET-01 강아지 (+ 상태 4)
```text
Create a 3D cute round puppy (about 0.6 m long, 0.5 m tall including head) following the pet rules. Fur base color warm cream #F5DEB3 with one floppy brown ear. Then show how the same model looks in 4 states (we will recolor the fur material and add simple extra meshes): (1) muddy: brown #8B5E3C patches all over, (2) bubbles: covered in white foam blobs, only the head visible, (3) wet: fur flattened and darker, blue #5BC0EB water drops, (4) fluffy: fur puffed up to about 1.6x size like a cotton ball, brighter. Provide the GLB of the base puppy, plus separate small GLB meshes for "foam blobs" and "water drops" that can be attached, and a reference sheet image of all 4 states from the top-down camera angle.
```

### MAC-01 욕조
```text
Create a 3D bathtub machine for a pet grooming shop, fits in a 2 x 2 m grid tile, 0.9 m tall. Rounded clawfoot tub, sky blue #8FD3F4 body with cherry red #FF6B6B faucet and one big round button, white foam inside (foam as a separate mesh that can be shown or hidden). Must clearly read as "bath" from a top-down camera. Max 2000 triangles. Also give front and top views.
```

### MAC-02 드라이어
```text
Create a 3D pet blow-dryer station that fits in a 2 x 2 m grid tile, 1.6 m tall: a round cushion platform where a pet sits, and a big friendly hood dryer on an arm above it (like a hair-salon dryer but toy-like), sky blue #8FD3F4 with cherry red #FF6B6B accents. The hood is a separate part so it can wobble while working. Max 2000 triangles. Also give front and top views.
```

### ENV-01 바닥 타일 + 텍스처
```text
Create (1) a seamless tileable 512x512 texture of large square bathhouse floor tiles, mint cream #DFF5EC with soft grout lines #B8E3D3, 4 tiles per texture (covers 2 m x 2 m), flat hand-painted, no baked lighting; (2) a 3D floor tile following the modular room kit rules using that texture.
```

### ENV-02 벽 조각
```text
Create a 3D modular wall piece following the modular room kit rules (2.0 m wide, 2.5 m tall, 0.2 m thick), butter yellow #FFF1C9 with a light wood #E8C9A0 baseboard and a thin pink #FF9EC4 tile stripe at 1 m height. Also a second version with a round window. Flat-cut ends.
```

### ENV-03 입구 문 + 출구 문
```text
Create two 3D door pieces that replace one wall piece (2.0 m wide, 2.5 m tall, 0.2 m thick), each with a 1.4 m wide x 2.0 m tall opening: (1) ENTRANCE door frame with a small awning and a paw-print shape on top, light wood; (2) EXIT door frame with a heart shape on top and a little pastel pink #FF9EC4 welcome mat in front (mat as a separate mesh 1.4 x 0.8 m). Max 800 triangles each.
```

### ENV-04 대기석 의자
```text
Create a 3D waiting bench for pets: a short round cushioned stool about 0.6 m wide and 0.4 m tall, light wood legs, pastel cushion (cushion as its own material so we can recolor it). Max 500 triangles.
```

### CHR-01 직원 캐릭터
```text
Create a 3D cute staff character about 1.2 m tall (pivot at feet center, facing -Z), 2-head-tall toy proportions, round head with a small bandana, simple dot eyes, rubber gloves and an apron. The apron must be ONE separate material so 4 players can have different colors. Neutral A-pose. Max 2500 triangles. Animations needed later: idle, walk, dash, carry (arms up holding a pet), slip (falling on puddle), wave. Provide front, side and top views.
```

### FX-01 물웅덩이
```text
Create a top-down 512x512 PNG texture with transparent background of a small cartoon water puddle: light blue #5BC0EB with a white highlight and a few tiny bubbles, soft rounded blob shape, for use as a floor decal. Also give 2 more shape variations.
```

### UI-01 아이콘
```text
Create a set of flat 2D game icons, 128x128 each, transparent background, thick rounded shapes with a soft dark outline #3A3A4A: (1) bathtub with bubbles, (2) blow dryer with wind lines, (3) heart full #FF5A7A, (4) heart empty (outline only), (5) star full #FFD23F, (6) star empty, (7) speech bubble frame (white, rounded) that can hold 1-4 small icons, (8) angry "hmph!" puff cloud, (9) check mark. Consistent stroke width and style.
```

---

## 6. 요청문 (P1·P2) — 시제품 뒤에 자세히

P1·P2 는 시제품 결과(스타일이 맞는지)를 보고 같은 형식으로 채움. 동물은 모두 "Pet rules" 를 붙이고, 기계는 2 × 2 m 칸 안, 꾸미기 소품은 800 삼각형 이하.

## 7. 검수 체크리스트

- [ ] 색이 2.2 를 지킴 (바닥·벽 연하게, 동물·기계 진하게)
- [ ] 위에서 비스듬히 봤을 때 무엇인지 바로 알 수 있음
- [ ] 동물 털이 머티리얼 하나로 분리됨 (상태별 색 바꾸기)
- [ ] 직원 앞치마가 머티리얼 하나 (플레이어 색)
- [ ] GLB, 1 = 1 m, Y 위, 정면 −Z, 기준점 맞음, 삼각형 수 이하
- [ ] 바닥·벽은 2 m 격자에 딱 맞고 이음새 없음
- [ ] 무섭거나 어두운 느낌 없음
