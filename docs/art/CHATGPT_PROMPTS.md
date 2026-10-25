# 등불 원정대 — ChatGPT 그래픽 요청문

작성: 기획팀 · 2026-10-25 · 근거: [GDD.md](../design/GDD.md)

이 문서는 ChatGPT에 그래픽을 요청할 때 그대로 붙여 넣을 문장을 모은 것입니다.
**순서**: ① 스타일 가이드를 먼저 정함 → ② 공통 머리말을 모든 요청 앞에 붙임 → ③ 우선순위 순서대로 요청.

---

## 1. 받는 방법과 주의

ChatGPT가 주는 결과물은 세 종류로 나눠 요청합니다.

| 종류 | 받는 것 | 쓰는 곳 |
|---|---|---|
| **컨셉 그림** | PNG 그림 (분위기, 정면·옆·위 도면) | 스타일 맞추기, 3D 모형을 만들 때 기준 |
| **텍스처** | PNG, 이음새 없이 반복(타일링)되는 정사각 그림 | 바닥·벽·나무·금속 재질 |
| **3D 모형** | GLB (안 되면 OBJ) | 게임에 바로 넣는 모형 |

- ChatGPT의 3D 파일 생성은 결과가 들쭉날쭉할 수 있습니다. **3D 요청에는 늘 정면·옆 도면 그림도 같이** 받아 두어, 안 되면 그 도면을 보고 Blender 등에서 단순 모형으로 다시 만듭니다.
- 받은 모형은 **크기를 꼭 확인**합니다 (2장 규격). 맞지 않으면 기획팀이 "규격 불일치"로 다시 요청하거나 개발팀에 가져올 때 맞춰 달라고 이슈로 적습니다.
- 받은 파일 목록과 상태는 `docs/art/ASSETS.md`(받기 시작하면 만듦)에 적습니다. 파일 이름은 이 문서의 **ID**(예: `ENV-01_floor_stone.glb`)를 씁니다.
- 게임에 넣는 위치·교체 방식은 개발팀이 정합니다 (CLAUDE.md: 모델·텍스처는 한 곳에서 교체). 기획팀은 ID만 맞춰 넘깁니다.

---

## 2. 스타일 가이드

### 2.1 한 줄 스타일

**"어둠 속의 따뜻한 장난감 디오라마"** — 단순한 로우폴리 형태, 큰 덩어리, 손으로 칠한 듯한 단순한 색. 사실적이지 않음. 공포보다 '으스스하지만 귀여운' 쪽.

### 2.2 색

| 쓰임 | 이름 | 색 |
|---|---|---|
| 배경 어둠 | 밤잉크 | `#14161F` |
| 돌 (1층) | 차가운 돌 | `#4A4E5A` / 밝은 면 `#6B7080` |
| 벽돌·거리 (2층) | 바랜 벽돌 | `#6A4E44` / 밝은 면 `#8C6A5A` |
| 나무 | 낡은 나무 | `#5C4632` |
| 금속 | 녹슨 놋쇠 | `#8A7344` |
| 이끼 (포인트) | 푸른 이끼 | `#3E6B5C` |
| **등불 빛** | 등불 주황 | `#FFB347` |
| 기름 | 호박색 | `#E08A2E` |
| 유물 | 옛 금 | `#D9B44A` |
| 괴물 몸 | 그림자 | `#0B0B12` |
| 괴물 눈·빛 | 차가운 하늘색 | `#9FE8FF` |

- 규칙: **따뜻한 색(주황·금)은 빛·유물·기름에만**, 차가운 색(하늘색)은 괴물에만. 그래야 어둠 속에서 무엇이 중요한지 한눈에 보입니다.
- 환경은 채도 낮게, 빛 받는 물건만 채도 높게.

### 2.3 형태

- 모서리를 살짝 깎은(베벨) 큰 덩어리. 가는 장식·글자·작은 무늬 금지.
- 비율은 약간 과장 (등불·유물은 실제보다 1.2배 크게, 손으로 쉽게 알아보게).
- 실루엣으로 구분: 어둠 속에서 윤곽만 봐도 무엇인지 알 수 있어야 함.

### 2.4 폴리곤·텍스처 규격

| 종류 | 삼각형 수 (최대) | 텍스처 |
|---|---|---|
| 던전 조각 (바닥·벽·문) | 300 | 공용 타일링 텍스처 (512×512) |
| 소품 (상자·기름병·함정) | 800 | 512×512 |
| 유물 | 1,500 | 512×512 |
| 1인칭 손·등불 | 3,000 | 1024×1024 |
| 동료 캐릭터 | 3,000 | 1024×1024 |
| 괴물 | 2,500 | 1024×1024 |

- 머티리얼은 모형 하나에 **1개** (빛을 내는 부분이 있으면 발광 1개 추가 허용).
- 노멀맵 없어도 됨. 기본 색(알베도) 텍스처 + 단순 음영이면 충분.

### 2.5 파일·좌표 규격 (모든 3D 요청 공통)

- 형식: **GLB**, 단위 **1 = 1 m**, **Y축 위**, 정면은 **−Z 방향**.
- 기준점(피벗): 던전 조각은 **바닥면 한쪽 모서리**(2.6 참고), 소품·캐릭터·괴물은 **바닥면 가운데**.
- 크기 0.5 m 단위로 딱 떨어지게 (소품 제외).

### 2.6 던전 조각 격자 규격 (가장 중요)

모든 던전 조각은 **2 m 격자**에 맞아야 합니다. 생성기가 조각을 이어 붙이므로 크기가 조금만 달라도 틈이 생깁니다.

| 규격 | 값 |
|---|---|
| 격자 1칸 | 2 m × 2 m |
| 바닥 타일 | 2.0 × 2.0 m, 두께 0.2 m (윗면이 Y=0, 아래로 0.2) |
| 벽 조각 | 폭 2.0 m × 높이 2.0 m × 두께 0.25 m. 2단 쌓아 천장 4 m |
| 벽 위치 | 칸 경계선 위에 두께 가운데가 오도록 (경계선에서 앞뒤로 0.125 m) |
| 문틀 | 폭 2.0 m × 높이 4.0 m (벽 2단 자리), 구멍 폭 1.4 m × 높이 2.4 m |
| 기둥 | 0.5 × 0.5 m, 높이 4.0 m, 칸 모서리에 |
| 천장 | 바닥 타일과 같은 크기, Y=4.0 |
| 이음새 | 조각 끝은 **평평하게 잘라** 옆 조각과 맞닿게. 끝에 튀어나온 장식 금지. 타일링 텍스처는 가장자리가 이어지게 |

---

## 3. 공통 머리말 (모든 요청 앞에 붙이기)

ChatGPT에는 영어로 요청하는 것이 결과가 안정적이라 요청문은 영어로 씁니다.

```text
Style guide for every asset in this project (game: "Lanternfall", a co-op dungeon exploration game played in the dark):
- Look: "warm toy diorama in the dark". Low-poly, chunky shapes with slightly bevelled edges, simple hand-painted colors, no photorealism, no small details, no text or logos.
- Spooky but cute, not gory.
- Palette: background ink #14161F, cold stone #4A4E5A (light face #6B7080), faded brick #6A4E44, old wood #5C4632, rusty brass #8A7344, teal moss accent #3E6B5C. Warm colors (lantern orange #FFB347, oil amber #E08A2E, old gold #D9B44A) are ONLY for light sources, oil and treasure. Cold cyan #9FE8FF is ONLY for monsters' eyes.
- 3D files: GLB, 1 unit = 1 meter, Y-up, front faces -Z, one material per model (plus one emissive material if it glows), albedo texture only, no normal maps.
- Readable silhouette: the object must be recognizable from its outline alone.
```

던전 조각 요청에는 아래도 붙입니다.

```text
Modular dungeon kit rules (very important):
- Everything snaps to a 2 m x 2 m grid.
- Floor tile: exactly 2.0 x 2.0 m, 0.2 m thick, top surface at Y=0. Pivot at the corner (0,0,0), tile spans X 0..2 and Z 0..2.
- Wall piece: exactly 2.0 m wide, 2.0 m tall, 0.25 m thick, centered on the grid line (Z from -0.125 to +0.125). Pivot at bottom-left corner on the grid line. Two pieces stack to a 4 m ceiling.
- Edges must be cut flat so neighbouring pieces meet with no gaps; no decoration sticking out past the edges.
- Textures must tile seamlessly.
- Max 300 triangles per piece.
```

---

## 4. 요청 목록 (우선순위)

- **P0** = 데모에 꼭 필요 (먼저 받기)
- **P1** = 데모 품질을 올림 (P0 다음)
- **P2** = 데모 이후 / 있으면 좋음

| ID | 이름 | 종류 | 우선 |
|---|---|---|---|
| ART-00 | 분위기 키 아트 | 컨셉 | **P0** |
| TEX-01 | 차가운 돌 바닥 | 텍스처 | **P0** |
| TEX-02 | 차가운 돌 벽 | 텍스처 | **P0** |
| ENV-01 | 돌 바닥 타일 | 3D | **P0** |
| ENV-02 | 돌 벽 조각 | 3D | **P0** |
| ENV-03 | 문틀 + 문 | 3D | **P0** |
| ENV-04 | 기둥 | 3D | **P0** |
| ENV-05 | 엘리베이터 | 3D | **P0** |
| PRP-01 | 큰 등불 | 3D | **P0** |
| PRP-02 | 기름병 | 3D | **P0** |
| CHR-01 | 1인칭 손 + 손등 | 3D | **P0** |
| CHR-02 | 원정대원 (동료 모습) | 3D | **P0** |
| MON-01 | 그림자 추적자 | 3D | **P0** |
| MON-02 | 기름 도둑 | 3D | **P0** |
| REL-01~06 | 유물 6종 | 3D | **P0** |
| PRP-03 | 나무 상자 | 3D | P1 |
| PRP-04 | 곰덫 | 3D | P1 |
| PRP-05 | 무너지는 바닥 타일 | 3D | P1 |
| PRP-06 | 설치 램프 | 3D | P1 |
| PRP-07 | 기름 샘 | 3D | P1 |
| PRP-08 | 계단 (아래층으로) | 3D | P1 |
| PRP-09 | 빛의 파편 제단 | 3D | P1 |
| TEX-03 | 바랜 벽돌 (2층) | 텍스처 | P1 |
| ENV-06 | 2층 무너진 거리 조각 세트 | 3D | P1 |
| CHR-03 | 직업 표시 장비 4종 | 3D | P1 |
| UI-01 | 아이콘 세트 | 2D | P1 |
| ENV-07 | 잔해·부서진 벽 변형 | 3D | P2 |
| CMP-01 | 캠프 (상점·텐트) | 3D | P2 |
| ART-01 | 스팀 캡슐 이미지 | 2D | P2 |

---

## 5. 요청문

각 요청은 **공통 머리말 + (던전 조각이면 격자 규칙) + 아래 문장** 순서로 붙입니다.

### ART-00 분위기 키 아트 (P0)
```text
Create a wide concept painting (16:9) of 3 small explorers in a pitch-dark stone underground hall. One holds a large brass lantern casting a warm orange circle of light about 8 meters wide; the others hold tiny hand lamps. At the edge of the light, tall shadow creatures with cold cyan eyes wait in the darkness, and a cluster of small glowing leech-like bugs crawls on the wall near the light edge. Show the low-poly toy diorama style from the style guide. This image will be the reference for all other assets.
```

### TEX-01 차가운 돌 바닥 (P0)
```text
Create a seamless tileable square texture, 512x512, top-down view of chunky stone floor slabs for a low-poly game. 2x2 large slabs per tile (the texture covers 2 m x 2 m). Cold stone #4A4E5A with lighter #6B7080 edges, subtle cracks, a few teal moss #3E6B5C spots. Flat hand-painted look, no strong baked lighting, edges must tile seamlessly in both directions.
```

### TEX-02 차가운 돌 벽 (P0)
```text
Create a seamless tileable square texture, 512x512, front view of a rough stone block wall for a low-poly game. The texture covers 2 m wide x 2 m tall, about 4 rows of large blocks. Same palette as the floor. Flat hand-painted look, no baked lighting, seamless in both directions.
```

### ENV-01 돌 바닥 타일 (P0)
```text
Create a 3D model: one modular stone floor tile following the modular kit rules (2.0 x 2.0 m, 0.2 m thick, pivot at corner). Slightly uneven top with 4 bevelled slabs. Use the stone floor texture style. Also give me a top view and a side view image with the dimensions labeled.
```

### ENV-02 돌 벽 조각 (P0)
```text
Create a 3D model: one modular stone wall piece following the modular kit rules (2.0 m wide, 2.0 m tall, 0.25 m thick). Both faces are stone blocks. Flat cut ends so pieces line up side by side and stack vertically. Also give me a front and side view image with dimensions labeled.
```

### ENV-03 문틀 + 문 (P0)
```text
Create a 3D model of a modular stone door frame for the 2 m grid: total 2.0 m wide, 4.0 m tall, 0.25 m thick (replaces two stacked wall pieces), with an opening 1.4 m wide and 2.4 m tall, centered at the bottom. Separately, create a heavy wooden door with brass bands that fits the opening (1.4 x 2.4 m, 0.1 m thick), pivot at the hinge side bottom. Provide two GLB files and a front view image with dimensions.
```

### ENV-04 기둥 (P0)
```text
Create a 3D model of a square stone pillar, 0.5 x 0.5 m, 4.0 m tall, pivot at the bottom center, to be placed at grid corners. Simple bevelled blocks, a slightly wider base and top. Max 300 triangles.
```

### ENV-05 엘리베이터 (P0)
```text
Create a 3D model of an old mine-style cage elevator that fits exactly inside a 4 x 4 m area (2x2 grid tiles) and is 4 m tall: wooden floor platform, rusty brass #8A7344 cage bars, a hanging warm lamp (emissive #FFB347) on top. Open on the -Z side. Pivot at the bottom center. Max 1500 triangles.
```

### PRP-01 큰 등불 (P0)
```text
Create a 3D model of a large hand-held brass oil lantern, about 0.5 m tall including the handle (slightly oversized for readability). Chunky brass frame #8A7344, glass panels, a glowing flame inside (separate emissive material #FFB347), a visible amber oil tank #E08A2E at the bottom. Pivot at the handle top (where the hand holds it). Max 800 triangles. Also give a front and side image.
```

### PRP-02 기름병 (P0)
```text
Create a 3D model of a small round glass oil bottle with a cork, about 0.3 m tall, filled with glowing amber oil (emissive #E08A2E, soft). Must be readable in darkness from 10 m. Pivot at bottom center. Max 400 triangles.
```

### CHR-01 1인칭 손 + 손등 (P0)
```text
Create a first-person viewmodel for a game: a pair of gloved hands in thick explorer gloves (brown leather) seen from the player's eyes, the left hand holding a small hand lamp (palm-sized brass lamp with a tiny emissive flame #FFB347). Also provide a version where both hands hold the large lantern from PRP-01. Simple rig-friendly shapes (separate fingers not needed: mitten-like). Max 3000 triangles. Provide a reference image from the first-person camera angle.
```

### CHR-02 원정대원 (P0)
```text
Create a 3D character for a low-poly co-op game: a small, stocky explorer about 1.7 m tall (pivot at feet center, facing -Z), toy-like proportions (big head with a round miner helmet, short legs), thick coat with many pouches, no face details except two simple eyes. The coat color must be easy to recolor (one solid area) because 4 players use different colors. Neutral T-pose. Max 3000 triangles. Animations needed later: idle, walk, run, carry (both arms forward), crawl (downed). Provide front, side and back views.
```

### MON-01 그림자 추적자 (P0)
```text
Create a 3D monster: a tall thin shadow creature about 2.4 m tall, hunched, long arms reaching to the knees, body pure dark #0B0B12 with a slightly smoky ragged silhouette (done with geometry, not particles), two big glowing cyan eyes (emissive #9FE8FF). Spooky but not gory, no mouth or teeth. Pivot at feet center, facing -Z. Max 2500 triangles. Animations needed later: idle, crawl-walk, lunge (0.8 s wind-up then grab), flinch-back from light. Provide front and side views.
```

### MON-02 기름 도둑 (P0)
```text
Create a 3D model of a small leech-like bug about 0.3 m long, round segmented body, dark #0B0B12 with a glowing amber belly (emissive #E08A2E, as if full of stolen oil) and tiny cyan eyes #9FE8FF. It will be used in groups of 3-5 crawling on floors and walls. Pivot at belly center. Max 500 triangles. Animation needed later: crawl wiggle, burn-and-flee.
```

### REL-01~06 유물 6종 (P0)
한 번에 하나씩 요청합니다 (같은 대화에서 이어서 요청하면 스타일이 잘 맞음).
```text
Create a 3D treasure item for the game, pivot at bottom center, max 1500 triangles, old gold #D9B44A as the main accent so it shines warm in lantern light. Slightly oversized for readability.
```
뒤에 붙일 설명:
| ID | 붙일 문장 | 크기 |
|---|---|---|
| REL-01 | `A golden candlestick with three arms.` | 0.5 m 높이 (가벼움) |
| REL-02 | `A crystal eyeball on a small brass stand, the crystal faintly glowing cyan-white.` | 0.3 m (가벼움) |
| REL-03 | `A ring of three big silver keys.` | 0.25 m (가벼움) |
| REL-04 | `A heavy stone statue head with a calm face and a gold crown, needs two people to carry.` | 0.9 m (무거움) |
| REL-05 | `A heavy wind-up music box made of wood and gold, with a large key on the side.` | 0.8 × 0.6 m (무거움) |
| REL-06 | `"Shard of Light": a big crystal shard glowing warm orange #FFB347 from inside, set in a brass cradle with two handles.` | 1.0 m (무거움, 목표) |

### PRP-03 나무 상자 (P1)
```text
Create a 3D wooden crate with brass corners, 1.0 x 1.0 x 1.0 m (half a grid tile), lid as a separate part so it can open. Pivot at bottom center. Max 400 triangles.
```

### PRP-04 곰덫 (P1)
```text
Create a 3D bear trap, 0.8 m wide, open state and closed state as two separate GLB files, rusty brass. Must be visible on a dark floor: add small light-grey teeth highlights. Pivot at center. Max 600 triangles.
```

### PRP-05 무너지는 바닥 타일 (P1)
```text
Create a variant of the stone floor tile (ENV-01, same exact 2.0 x 2.0 x 0.2 m size and pivot) with visible deep cracks across it, plus a second version broken into 5 separate chunks for a falling animation.
```

### PRP-06 설치 램프 (P1)
```text
Create a 3D standing oil lamp on a short tripod, 1.0 m tall, brass, with an emissive flame #FFB347. Pivot at bottom center. Max 600 triangles.
```

### PRP-07 기름 샘 (P1)
```text
Create a 3D stone basin well filled with glowing amber oil (emissive #E08A2E), fits within 2 x 2 m (one grid tile), 1.0 m tall, with a small brass ladle hanging on it. Pivot at the corner like a floor tile (spans X 0..2, Z 0..2). Max 1000 triangles.
```

### PRP-08 계단 (P1)
```text
Create a 3D stone staircase going down, modular kit rules: footprint exactly 2 x 4 m (1x2 grid tiles), descending 4 m into darkness, flat cut edges. Pivot at the top corner like a floor tile. Max 600 triangles.
```

### PRP-09 빛의 파편 제단 (P1)
```text
Create a 3D stone altar that fits in 4 x 4 m (2x2 tiles), 1.2 m tall, with an empty brass cradle on top where REL-06 sits. Engraved simple sun shapes (geometry only, no fine details). Pivot at bottom center. Max 1500 triangles.
```

### TEX-03 바랜 벽돌 (P1)
```text
Create two seamless tileable 512x512 textures for floor 2 "collapsed street": (1) faded brick wall #6A4E44 / #8C6A5A, 2 m x 2 m coverage, (2) broken cobblestone floor with the same palette. Flat hand-painted, no baked lighting.
```

### ENV-06 2층 거리 조각 세트 (P1)
```text
Using the faded brick textures, create a modular kit for an underground ruined street following the modular kit rules: (1) cobblestone floor tile 2x2 m, (2) brick wall piece 2x2 m, (3) house facade wall piece 2x2 m with a boarded-up window, (4) door frame with the same sizes as ENV-03, (5) broken street lamp post 3.5 m tall (pivot at bottom center). One GLB per piece.
```

### CHR-03 직업 표시 장비 (P1)
```text
Create 4 small attachable items for the explorer character (CHR-02), each readable from behind and in silhouette: (1) Lantern Keeper: a tall brass chimney-like hat lamp, (2) Scout: a long scarf and a bag of glowing chalk, (3) Porter: a huge backpack frame with ropes, (4) Engineer: a tool belt and big goggles. Max 600 triangles each, same palette, pivot at the attach point.
```

### UI-01 아이콘 세트 (P1)
```text
Create a set of flat 2D game UI icons, 128x128 each, transparent background, thick simple shapes, warm orange #FFB347 on transparent with a dark #14161F outline: oil drop, lantern (3 versions: low / normal / high brightness), flash, hand lamp on/off, chalk mark, backpack slot, heavy-item (two hands), lock, key, trap, downed player, revive. Consistent stroke width.
```

### ENV-07 잔해 변형 (P2)
```text
Create 3 variants of the stone wall piece (ENV-02, identical size and pivot): cracked, partially collapsed with a hole, with moss and roots. Plus 3 small rubble piles (under 1 m) as decoration.
```

### CMP-01 캠프 (P2)
```text
Create a small surface camp at the elevator top: a canvas tent, a wooden shop stall with oil bottles on shelves, a notice board, and a campfire, all in the same toy diorama style, separate GLB per object.
```

### ART-01 스팀 캡슐 이미지 (P2)
```text
Create Steam store capsule art (920x430): a lantern's warm circle of light in the middle of total darkness, 4 small explorers inside the light, shadow creatures with cyan eyes all around the edge. Leave clear empty space on the left for the game logo. Same style as the key art.
```

---

## 6. 검수 체크리스트 (받은 뒤 기획팀이 확인)

- [ ] 색이 2.2 규칙을 지킴 (따뜻한 색은 빛·기름·유물에만)
- [ ] 삼각형 수가 2.4 이하
- [ ] GLB, 1 = 1 m, Y 위, 정면 −Z, 기준점 위치 맞음
- [ ] 던전 조각: 2 m 격자에 딱 맞음, 두 개 붙였을 때 틈 없음, 텍스처 이음새 없음
- [ ] 어두운 화면(빛 반경 8 m 밖)에서 실루엣으로 알아볼 수 있음
- [ ] 파일 이름이 ID로 시작
