# 멍냥 목욕탕 V3 — ChatGPT 그래픽 요청문 (시제품 1)

작성: 기획팀 · 2026-10-26 (0.2: 2D 먼저, 무료 3D 경로) · 근거: [GDD_V3.md](../design/GDD_V3.md) 2장·8.1
V2 요청문 [CHATGPT_PROMPTS_V2.md](CHATGPT_PROMPTS_V2.md) 의 **색·스타일은 그대로** 쓰고, V3 에서 바뀌는 것만 적는다.

## 0. 받는 순서 (0.2) — **2D 로 확실히 되는 것부터**

ChatGPT 는 그림(2D)은 잘 만들고 3D 파일은 약하다. 그래서 사람 대표가 바로 만들 수 있는 2D 부터 받아서 시제품에 붙이고, 3D 는 아래 '무료 3D 경로'로 따로 만든다.

| 순서 | ID | 무엇 | 종류 | 게임에서 |
|---|---|---|---|---|
| 1 | V3-ART-00 | 작업대 시점 분위기 그림 | 2D | 모든 그림의 기준 + 목욕대 뒤 **배경 그림**으로 바로 씀 |
| 2 | V3-UI-01 | 도구 아이콘 4 · 요청 카드 · 기분 얼굴 · 동전 | 2D | 바로 붙임 |
| 3 | V3-UI-02 | 주인 말풍선 그림 (요청 아이콘들) | 2D | 바로 붙임 |
| 4 | V3-UI-03 | 가게 간판 / 로고 | 2D | 메뉴·가게 벽 |
| 5 | V3-ART-01 | 주인 6명 그림 (정면, 흰 배경) | 2D | 우선 **판자 그림(빌보드)** 으로 대기 의자에 세움 → 나중에 3D |
| 6 | V3-ART-02 | 강아지 **3D 변환용 그림** (정면·옆·뒤, 흰 배경) | 2D | 아래 무료 3D 경로의 입력 |
| 7 | V3-TEX-01 | 털 · 타일 · 나무 텍스처 | 2D | 임시 모형에 입혀서 상자 느낌을 줄임 |
| 8 | V3-PET-01 · STN-01 · TOOL-01~04 | 3D 모형 | 3D | ChatGPT 3D 가 되면 받고, 안 되면 무료 3D 경로 |

## 0-1. 무료 3D 경로 (그림 → 3D)

| 단계 | 도구 | 비용·라이선스 | 메모 |
|---|---|---|---|
| ① 그림 | ChatGPT (V3-ART-02 처럼 **흰 배경, 정면, 그림자 없이, 귀·꼬리가 몸에서 떨어져 보이게**) | 이미 쓰는 것 | 한 장에 한 물체 |
| ② 그림 → 3D | **TRELLIS** (Microsoft) | **MIT — 상업 사용 가능**, 무료. 일부 부속 코드는 라이선스가 다를 수 있음 → 받기 전에 확인 | 직접 돌리려면 NVIDIA GPU 24 GB 이상이 필요. 없으면 Hugging Face 공개 데모(무료, 대기열)에서 돌려 GLB 로 받음 — 데모 이용 조건은 받을 때 확인 |
| ② 대안 | **TripoSR** (Stability AI · Tripo) | **MIT — 상업 사용 가능**, 무료 | 결과가 TRELLIS 보다 거칠지만 더 작은 GPU 로 돌아감 |
| ③ 손질 | **Blender** | 무료 (GPL, 만든 모형은 우리 것) | 크기·기준점 맞추기, 삼각형 줄이기, **털 UV 를 겹치지 않게 다시 펼치기**(Smart UV Project), 귀·꼬리를 따로 떼어 코드로 흔들게 |
| 쓰지 않음 | Hunyuan3D 2.x (Tencent) | 라이선스가 **한국·EU·영국을 적용 지역에서 뺌** → 한국 스튜디오는 쓸 수 없음 | |
| 조건부 | Stable Fast 3D (Stability AI) | 커뮤니티 라이선스: 연 매출 100만 달러 미만이면 상업 무료, 넘으면 유료 계약 | 쓰려면 대표 확인 먼저 |
| 보류 (돈이 들 수 있음) | Meshy · Tripo 같은 웹 서비스 | 무료 등급의 상업 사용 조건을 확인하지 못함. 유료 플랜은 월 구독 (금액은 확인 못함) | CLAUDE.md 규칙대로 쓰지 않고 보류. 필요하면 대표에게 '무엇·얼마·왜' 먼저 |

- 애니메이션: 강아지는 사람 뼈대가 아니라 무료 자동 리깅(Mixamo 등)이 맞지 않음 → **귀·꼬리·머리를 따로 떼어 코드로 흔드는 방식**(개발팀)으로 시작.
- 출처: [TRELLIS.2 모델 카드](https://huggingface.co/microsoft/TRELLIS.2-4B/blob/main/README.md), [TripoSR 발표](https://stability.ai/news/triposr-3d-generation), [Hunyuan3D-2 라이선스](https://huggingface.co/tencent/Hunyuan3D-2/blob/main/LICENSE), [Stable Fast 3D](https://huggingface.co/cocktailpeanut/sf3d)

## 1. V2 와 달라지는 점

| | V2 (쿼터뷰) | **V3 (작업대 시점)** |
|---|---|---|
| 카메라 | 멀리 위에서 | **목욕대 바로 앞, 강아지가 화면 가운데 크게** |
| 강아지 | 작게 보임, 2,500 삼각형 | **주인공 크기.** 6,000 삼각형, 텍스처 1024 |
| 중요한 것 | 위에서 본 실루엣 | **가까이서 본 얼굴 표정 · 털 덩어리 · 깨끗한 UV** |
| 도구 | 없음 | 화면에 크게 보이는 손 도구 4개 |

### 꼭 지킬 것: 강아지 UV (더러움 마스크 붓질용)

게임이 강아지 몸에 **더러움 마스크를 붓으로 칠한다** (GDD_V3 3.1). 그래서:
- 털 부분 UV 는 **한 장 안에 겹치지 않게** 펼친다. **좌우 대칭으로 UV 를 겹치면 안 됨** (한쪽을 칠하면 반대쪽도 칠해져 버림).
- UV 섬 사이 여백 4 px 이상 (1024 기준), 늘어남이 적게.
- 털(몸)과 얼굴(눈·코·입)은 **머티리얼 2개**로 나눔: 털 = 상태별 셰이더(젖음·뽀송)가 붙는 곳, 얼굴 = 표정이 바뀌는 곳.

## 2. 공통 머리말 (모든 요청 앞에)

V2 공통 머리말을 쓰되, 카메라 줄만 아래처럼 바꾼다.

```text
Style guide for every asset in this project (game: "Paws & Bubbles", a cozy pet grooming shop simulator played from a fixed close-up workstation camera):
- Look: "soft pastel toy bathhouse". Chunky rounded shapes, every edge rounded, toy proportions, simple flat hand-painted colors. Bright, cheerful, never scary or dark. No text or logos.
- Palette: floor mint cream #DFF5EC, walls butter yellow #FFF1C9, light wood #E8C9A0, equipment sky blue #8FD3F4 with cherry red #FF6B6B accents, UI pink #FF9EC4. Mud is chocolate brown #8B5E3C. Water drops #5BC0EB. Foam pure white.
- The camera is close: the pet fills the middle of the screen, so shapes must look good up close (soft, clean, no noisy detail).
- 3D files: GLB, 1 unit = 1 meter, Y-up, front faces -Z, pivot at bottom center, albedo texture only, no normal maps.
```

## 3. 요청 목록

**P0** = 시제품 1 에 필요 (전부 이 문서) · P1·P2 는 시제품 2 이후 따로.

| ID | 이름 | 우선 |
|---|---|---|
| V3-PET-01 | 강아지 (가까이 보는 주인공판) | **P0** |
| V3-STN-01 | 목욕대 (작업대 + 회전판 + 도구걸이) | **P0** |
| V3-TOOL-01 | 샤워기 (+ 온도 다이얼) | **P0** |
| V3-TOOL-02 | 샴푸 병 2종 (기본·복숭아) + 손 | **P0** |
| V3-TOOL-03 | 수건 | **P0** |
| V3-TOOL-04 | 드라이어 | **P0** |
| V3-UI-01 | 커서 도구 아이콘 4개 + 요청 카드 + 기분 얼굴 3개 | **P0** |
| V3-ART-00 | 작업대 시점 분위기 그림 | **P0** (가장 먼저 — 다른 요청의 기준) |

## 4. 요청문

### V3-ART-00 작업대 시점 분위기 그림 (먼저)
```text
Create a 16:9 concept illustration from the player's point of view standing at a cozy pet grooming bathtub workstation: a cute muddy cream-colored puppy sits on a round turntable inside a pastel sky-blue tub in the middle of the screen, a handheld shower head sprays water from the right, a shampoo bottle and towel hang on a small tool rack beside the tub, a blow dryer is clipped to the side. Butter-yellow tiled wall behind with a small window and a little computer screen on the wall to the left. Soft pastel toy style. Half of the puppy is still muddy, the other half is wet and darker with water drops, to show the cleaning in progress.
```

### V3-PET-01 강아지
```text
Create a 3D cute round toy puppy for a close-up camera, about 0.6 m long and 0.55 m tall (sitting pose is the main pose), cream fur #F5DEB3 with one floppy light-brown ear, big head, short legs, round fluffy tail. Max 6000 triangles, 1024x1024 texture.
Requirements:
1. Two materials only: FUR (whole body, ears, tail) and FACE (eyes, nose, mouth area).
2. FUR UVs must be fully unwrapped on one texture with NO overlapping and NO mirrored UV islands (the game paints a dirt mask on the fur, so every point of the fur needs its own unique UV spot). Keep 4 px padding between islands.
3. FACE: provide 3 expressions as 3 small face textures (or blend shapes): happy (smile, sparkly eyes), neutral (dot eyes, flat mouth), unhappy (squeezed eyes, wobbly mouth).
4. Simple skeleton: body, head, 2 ears, tail, 4 legs, so ears can flap, the tail can wag and the body can shake.
5. Pivot at bottom center, facing -Z.
Also give: a reference sheet (front, side, back, top), the UV layout image, and an image of the same puppy in 4 states: muddy (brown #8B5E3C patches), foamy (covered in white foam balls), wet (darker, flattened fur, blue water drops #5BC0EB), fluffy (puffed up to about 2x size like a cotton ball, brighter).
Animations needed later: sit idle, jump (cold water), leg kick (ticklish), full-body shake, cheeks flapping (dryer in face), happy wag.
```

### V3-STN-01 목욕대
```text
Create a 3D pet bathtub workstation seen from the front at close range: a round pastel sky-blue #8FD3F4 tub about 1.0 m wide and 0.9 m tall (rim height), with a separate round turntable inside it (0.7 m diameter, can rotate), a cherry red #FF6B6B drain plug, a small light-wood tool rack on the right side with 4 hooks, and a little hose holder. The front rim is low so the pet inside is fully visible from the camera. Max 4000 triangles, 1024 texture. The turntable must be a separate mesh with its pivot at its center.
```

### V3-TOOL-01 샤워기
```text
Create a 3D handheld shower head with a short flexible hose stub, toy-like and chunky, about 0.25 m long, sky blue with a white face plate with big round holes, plus a separate round temperature dial (blue on the left, green in the middle, red on the right, with a pointer knob as a separate mesh that can rotate). The water spray will be a particle effect in the game, do not model water. Max 1500 triangles. Pivot at the handle grip.
```

### V3-TOOL-02 샴푸 병 2종 + 손
```text
Create (1) two 3D squeeze shampoo bottles, about 0.2 m tall, rounded pump-free squeeze shape with a flip cap: BASIC is mint #B8E3D3 with a white bubble symbol, PEACH is soft pink #FFB6A3 with a simple peach shape symbol (no text). Max 800 triangles each. (2) A cute cartoon rubber-gloved hand (yellow glove, mitten-like, 4 fingers) in a "scrubbing" open-palm pose, used as the scrubbing cursor near the pet, about 0.15 m. Max 1500 triangles. Pivot at the palm center.
```

### V3-TOOL-03 수건
```text
Create a 3D soft folded bath towel in pastel pink #FF9EC4 with a white stripe, about 0.35 x 0.25 m, chunky rounded edges, plus a second "bunched up in hand" version used as the drying cursor. Max 800 triangles each.
```

### V3-TOOL-04 드라이어
```text
Create a 3D chunky toy-like handheld pet blow dryer, about 0.3 m long, sky blue #8FD3F4 body with a cherry red #FF6B6B button, round nozzle with a visible fan grill (fan blades as a separate mesh that can spin). Max 1500 triangles. Pivot at the handle grip.
```

### V3-UI-01 아이콘
```text
Create flat 2D game icons, transparent background, thick rounded shapes with a soft dark outline #3A3A4A, consistent style:
1. Four tool icons 128x128: shower head, shampoo bottle, towel, blow dryer.
2. A "request card" 512x320: a white rounded card with a paw print corner and 4 empty icon slots in a row, plus small 96x96 icons to put in the slots: bath tub with bubbles, comb, ribbon, peach (scent), and a green check mark to stamp over a finished slot.
3. Three mood faces 128x128 (simple puppy faces): happy, neutral, unhappy.
4. A shiny coin 96x96 with a paw print.
```

### V3-UI-02 주인 말풍선 그림
```text
Create flat 2D speech bubble icons for a cute pet grooming shop game, transparent background, thick rounded shapes with a soft dark outline #3A3A4A: a round white speech bubble (512x384) with room for 1-3 small icons, and 128x128 icons to place inside: bath with bubbles, peach (scent), cherry blossom (scent), lemon (scent), comb, scissors, red ribbon, blue ribbon. Also a "thank you" bubble with a heart, a "hmm" bubble with three dots, and a "sigh" bubble with a little cloud.
```

### V3-UI-03 가게 간판 / 로고
```text
Create a cute shop sign logo for a pet bathhouse named "Paws & Bubbles", 1024x512, transparent background: rounded wooden sign board in light wood #E8C9A0 with a bubbly hand-lettered title, a paw print and soap bubbles around it, pastel pink #FF9EC4 and sky blue #8FD3F4 accents. Also make a Korean version of the same sign with the title "멍냥 목욕탕".
```

### V3-ART-01 주인 6명
```text
Create 6 cute pet owner characters for a cozy shop game, each on a separate image, full body, front view, plain white background, no shadow: 2-head-tall toy proportions, simple dot eyes, rounded shapes, pastel clothes. Make them clearly different by hat and outfit color: (1) grandma with a knitted beanie, (2) office worker with a tie, (3) kid with a yellow raincoat, (4) sporty girl with a cap, (5) chef with an apron, (6) artist with a beret. Each holds out their hands as if passing a puppy. Same art style as the mood illustration.
```

### V3-ART-02 강아지 3D 변환용 그림
```text
Create a clean character reference image of the cute round cream puppy (same design as V3-PET-01) for converting into a 3D model: plain pure white background, no shadow, no ground, even soft lighting, the puppy sitting and facing the camera straight on, ears and tail clearly separated from the body (not overlapping the body outline), simple flat colors. Make 3 separate images: front view, side view, back view, same size and position.
```

### V3-TEX-01 텍스처
```text
Create seamless tileable 1024x1024 textures, flat hand-painted, no baked lighting: (1) short soft cream puppy fur #F5DEB3, (2) pastel mint bathroom wall tiles #DFF5EC with soft grout, (3) light wood planks #E8C9A0.
```

## 5. 검수 체크리스트

- [ ] V2 색·스타일과 맞음 (파스텔, 둥근 모양, 무섭지 않음)
- [ ] **강아지 털 UV 가 겹치지 않음, 좌우 대칭 겹침 없음** (마스크 붓질 시험: 한쪽 귀만 칠해 봄)
- [ ] 강아지 머티리얼 2개 (털 / 얼굴), 얼굴 표정 3개
- [ ] 회전판·다이얼 손잡이·드라이어 날개가 따로 움직이는 메시
- [ ] GLB, 1 = 1 m, Y 위, 정면 −Z, 삼각형 수 이하
- [ ] 가까이서 봐도 지저분한 잔무늬 없음
- [ ] 돈 드는 것 없음 (ChatGPT 사용 외 유료 에셋·서비스 금지)
