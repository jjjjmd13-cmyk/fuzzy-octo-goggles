# 출시 준비 (초안) — 멍냥 목욕탕 / Paws & Bubbles

작성: 기획팀 · 2026-11-04 · 판 0.1 (초안, 대표·사람 대표 검토용) · 근거: [GDD_V4.md](GDD_V4.md)

세 가지를 다룹니다: ① 영어 번역 범위 ② 처음 하는 사람 안내 흐름 ③ 스팀 상점 페이지 문구 (한국어·영어).
**돈이 드는 일** (스팀 등록비, 유료 번역·검수, 유료 트레일러 음악 등)은 이 문서에서 정하지 않습니다. 필요하면 대표에게 "무엇·얼마·왜·무료 대안" 으로 따로 올립니다.

---

## 1. 영어 번역 범위

### 번역하는 것

| 무엇 | 대략 개수 | 메모 |
|---|---|---|
| 메뉴·설정·저장 (이어하기·새로 하기·음량·조작 키) | 약 40 | |
| 영업 HUD (시계·돈·손님 수·손에 든 것·조작 줄) | 약 25 | |
| 단계 끝 글자 ("빗질 끝! 반짝반짝 깨끗해졌어요" 등) | 약 10 | |
| 처음 안내 한 줄 (2장) · F1 도움말 | 약 25 | 그림이 중심, 글자는 짧게 |
| 아침 알림 ("고양이 손님이 오기 시작했어요!" 등, 18일 흐름 표) | 약 20 | |
| 정산·가게 (도구·꾸미기·샴푸·수레 탭, 가격·설명) | 약 30 | |
| 도구 이름 25 (5종 × 5단계) + 가위 | 26 | |
| 꾸미기 이름 30 | 30 | |
| 가게 밖·택배 ("택배 상자 2개가 아직 밖에 있어요" 등) | 약 10 | |
| 주인 말 (돌려줄 때 4단계, 떠날 때, 샴푸 없음) | 약 20 | 주인마다 2~3개씩 바꿔 말하면 늘어남 |
| 성격·고양이 (이름·한 줄 설명·안내 카드) | 약 12 | |
| 단골 이름 24 + 사진첩 카드 글자 | 약 35 | 이름은 **뜻을 살려 새로 지음** (아래) |
| 축제·엔딩·크레딧 | 약 20 | |
| 스팀 업적 이름·설명 | 약 20 | 업적이 정해지면 |
| **합** | **약 350 줄** | 한 줄 평균 20자 안팎 → 짧음 |

### 번역하지 않는 것

- `docs/` 문서 (내부용, 한국어만).
- 그림 안 글자 — **그림에는 글자를 넣지 않는 규칙**이라 없음 (간판·사진첩 모두 게임이 글자를 올림).
- 효과음·배경음악 (말 없음).

### 방법 (개발팀과 맞출 것)

- 모든 문구는 **번역 키**로 (`MENU_CONTINUE`, `STAGE_DONE_BRUSH` …). 한 파일 `locale/strings.csv` (열: `key, ko, en`) — Godot 기본 CSV 번역 불러오기를 씀 (무료, 엔진 기본 기능).
- 기획팀이 **ko·en 두 열을 같이** 채움. 새 문구가 생기면 기획 문서에 키·한국어를 적고, 영어는 기획팀이 채움.
- 글꼴: Pretendard 는 라틴 글자도 들어 있어 영어에 그대로 씀 ([FONT.md](FONT.md)).
- 길이: 영어가 한국어보다 길어짐 (대략 1.3~1.6 배). **UI 칸은 영어 기준으로 넓게** — 개발팀이 영어로 한 번 화면 확인.
- 이름 짓기: 단골 이름은 소리 옮기기 말고 **뜻 옮기기** (예: 콩이 → Bean, 두부 → Tofu, 호떡 → Pancake, 보리 → Barley, 솜이 → Cotton, 쿠키 → Cookie, 라떼 → Latte, 몽실 → Puff, 별이 → Star, 나비 → Butterfly, 치즈 → Cheese, 모찌 → Mochi). 24개 전체 표는 문구 파일 만들 때 같이.
- 검수: 영어 원어민 검수는 **돈이 들 수 있음** → 출시 전 대표에게 올림. 무료 대안: 스팀 '다음 축제' 체험판·친구 플레이 테스트에서 영어 사용자 의견 받기.

---

## 2. 처음 하는 사람 안내 흐름

**원칙** (V3 수직 단면 7장·사람 대표 플레이에서 배운 것):
- **설명 화면 없이 바로 시작.** 메뉴 → 1일차까지 클릭 2번 이내.
- 안내는 **그 일을 처음 할 때 딱 한 번**, **그림 + 한 줄 이하**. 화면을 가리지 않고 (구석 또는 반투명), 하던 일을 멈추지 않음.
- 설정에 [안내 다시 보기] · [안내 끄기]. 막히면 **F1 = 조작 그림 한 장**.

| 언제 (처음 한 번) | 무엇이 보이나 | 글자 (한 줄) |
|---|---|---|
| 1일차 시작 | 화면 아래 WASD·마우스 그림 | "걸어서 손님을 맞아요" |
| 첫 손님이 의자에 앉음 | 손님 위에 손가락 그림 깜빡 | "손님을 눌러 맡아요" |
| 강아지가 목욕대에 | 선반의 샤워기가 반짝 | "선반에서 샤워기를 집어요" |
| 각 단계 처음 (적시기·거품·헹굼·수건·드라이·빗질) | 손동작 그림 1장 (누른 채 쓸기 / 짧게 비비기 / 위→아래 / 톡톡 / 다가가기 / 뭉치에 쓱) | 단계마다 한 줄 |
| 다 씻음 | 주인 위에 손가락 그림 | "주인에게 돌려줘요" |
| 1일차 첫 손님 거품 단계 | 꼬리 그림 + ♥ | "강아지가 좋아하는 곳을 찾아 보세요 ♥" |
| 첫 정산 | 돈 숫자가 올라가는 연출, [가게] 버튼 반짝 | "번 돈으로 도구를 키워요" |
| 2일차 아침 (첫 택배) | 정문 쪽 화살표 → 매트의 상자 반짝 | "택배가 왔어요! 들고 들어와요" |
| 2일차 아침 (팻말) | 팻말 반짝 | "팻말을 뒤집으면 영업 시작" |
| 새 고양이·성격이 처음 나옴 | 가운데 안내 카드 (그림 + 한 줄, 클릭하면 닫힘) | 예: "🪶 간지럼쟁이: 배·발은 짧게" |
| 샴푸 3마리분 남음 | 말풍선 + 병 눈금 깜빡 | "샴푸가 3마리분 남았어요" |
| 첫 사진 | 사진 카드가 사진첩 쪽으로 날아감 | "사진첩에 붙었어요!" |

- 1일차 손님은 **느긋 1명으로 시작** (`v4_first_guests`), 급한 손님은 2일차부터 → 처음에 놓치는 손님이 없게.
- QA 첫 플레이 조건 (V3 수직 단면 9장과 같음): 깨끗한 설치에서 '처음 하는 사람' 시점으로 1~3일차 → **막힘 0, 헷갈린 곳은 기록**.

---

## 3. 스팀 상점 페이지 문구

> 상점 페이지 등록(스팀웍스 가입·앱 등록비)은 **돈이 드는 일**이라 사람 대표가 정함. 아래는 그때 붙여 넣을 문구 초안.

### 3-1. 이름

- 한국어: **멍냥 목욕탕**
- 영어: **Paws & Bubbles**

### 3-2. 짧은 설명 (상점 맨 위, 300자 이내)

**한국어**
> 강아지·고양이 손님을 내 손으로 직접 씻겨 주는 1인칭 동물 목욕 가게! 샤워기로 적시고, 거품을 비비고, 수건으로 톡톡, 드라이기로 뽀송하게. 번 돈으로 도구를 키우고 가게를 꾸미며, 이름 있는 단골 24마리의 반짝이는 사진을 모아 보세요.

**English**
> Run a cozy first-person pet bath shop and wash every puppy and kitten by hand! Spray, lather, pat dry and blow-dry them fluffy. Upgrade your tools, decorate your shop, and fill your photo album with 24 adorable regulars.

### 3-3. 긴 설명 (상점 '이 게임에 대하여')

**한국어**

> **내 손으로 씻기는 작은 목욕 가게**
> 동네 골목의 작은 동물 목욕탕. 손님이 강아지를 안고 들어오면, 직접 걸어가 맡고, 목욕대에 올려 처음부터 끝까지 내 손으로 씻겨 줍니다.
>
> **단계마다 다른 손맛**
> 샤워기로 쏴아 적시고, 짧게 비벼 거품을 내고, 위에서 아래로 헹구고, 수건으로 톡톡, 드라이기를 가까이 대 뽕! 마지막은 빗질로 엉킨 털을 쓱. 시간 제한은 없어요 — 빠를수록 좋을 뿐.
>
> **도구를 키우고, 가게를 꾸미고**
> 하루가 끝나면 번 돈으로 더 좋은 도구를 삽니다. 도구마다 5단계, 마지막 단계는 무지개 샤워기와 구름 대포. 벽지·바닥·목욕통·화분까지 30가지 꾸미기로 나만의 가게를 만드세요. 산 물건은 다음 날 아침 택배로 도착해요.
>
> **손님마다 다른 성격**
> 물을 싫어하는 고양이, 배를 만지면 다리를 찰랑거리는 간지럼쟁이, 얼굴에 물이 닿으면 눈을 꼭 감는 겁쟁이. 좋아하는 곳을 찾아 주면 신나서 꼬리를 붕붕!
>
> **단골 24마리의 사진첩**
> 콩이, 두부, 나비… 다시 찾아오는 단골들의 가장 행복한 순간을 사진으로 모아요. 18일째, 동네 목욕 축제에서 모두를 만나요.

**English**

> **A tiny bath shop, washed by your own hands**
> In a quiet little street sits a cozy pet bath shop. Owners walk in with their pups — you greet them, carry their pet to the tub, and wash them yourself from start to finish.
>
> **Every step feels different**
> Spray them wet, rub up a rich lather, rinse from top to bottom, pat them dry with a towel, and blow-dry them into a fluffy cloud. Finish with a brush to sweep out every tangle. No timers — faster is just better.
>
> **Upgrade your tools, decorate your shop**
> At the end of each day, spend your earnings on better tools. Each tool has five tiers, all the way up to the Rainbow Shower and the Cloud Cannon. Make the shop your own with 30 decorations — wallpaper, floors, tubs, plants and more. Everything you buy arrives by delivery the next morning.
>
> **Every guest has a personality**
> Cats who don't love water, ticklish pups who kick when you scrub their tummy, timid ones who squeeze their eyes shut. Find their favorite scratching spot and watch their tail go wild!
>
> **An album of 24 regulars**
> Bean, Tofu, Butterfly… Collect the happiest moment of every regular who comes back. On day 18, meet them all at the neighborhood Bath Festival.

### 3-4. 특징 (짧은 목록)

| 한국어 | English |
|---|---|
| 1인칭으로 걸어 다니며 손님을 맞는 내 가게 | Walk around your own first-person shop |
| 단계마다 다른 손동작 6가지 | Six hands-on washing steps, each with its own feel |
| 도구 5종 × 5단계 업그레이드 | 5 tools × 5 upgrade tiers |
| 꾸미기 30가지, 아침마다 택배 도착 | 30 decorations, delivered every morning |
| 강아지·고양이, 성격 3가지 | Dogs, cats and three personalities |
| 단골 24마리 사진첩 | A photo album of 24 regulars |
| 약 3시간 이야기 + 엔딩 뒤 자유 영업 | About 3 hours to the ending, then free play |
| 혼자 하는 느긋한 게임, 실패 없음 | Relaxed single-player, no fail states |
| 한국어·영어 | Korean & English |

### 3-5. 태그 제안 (스팀 태그 20개 안에서 고름)

Cozy · Simulation · Cute · First-Person · Animals · Relaxing · Management · Singleplayer · Casual · Wholesome · Family Friendly · Colorful · 3D · Cats · Dogs · Short

### 3-6. 스크린샷 · 트레일러 (찍을 것 목록)

| # | 장면 | 왜 |
|---|---|---|
| 1 | 거품 범벅 강아지를 손으로 비비는 1인칭 화면 | 게임의 핵심이 한눈에 |
| 2 | 드라이 뒤 뽀송하게 부푼 강아지 + 반짝 | "귀엽다" |
| 3 | 가게 전체 (꾸민 가게, 의자에 기다리는 손님들) | 가게 키우기 |
| 4 | 5단계 도구 (무지개 샤워기·구름 대포) 쓰는 순간 | 업그레이드 "와" |
| 5 | 아침 마당에 택배 상자 + 트럭 | 밖·택배 |
| 6 | 사진첩 한 쪽 (금색 테두리 사진들) | 수집 |
| 7 | 고양이가 "냥!" 하는 순간 | 성격 |

- 트레일러 30초 콘티: 문 종 딸랑 → 강아지 안고 오는 주인 → 적시기·거품·헹굼 빠른 컷 → 몸 털기(물 튐) → 뽕! → 주인 품으로 폴짝 → 가게가 꾸며지는 빠른 컷 → 사진첩 넘기기 → 제목.
- 트레일러 음악: 게임에 쓰는 CC0 곡 또는 직접 합성한 곡만 (유료 곡 금지).

### 3-7. 시스템 요구사항 (초안, 개발팀이 빌드로 확인)

| | 최소 | 권장 |
|---|---|---|
| OS | Windows 10 64비트 | Windows 10/11 64비트 |
| 프로세서 | 2코어 2 GHz | 4코어 3 GHz |
| 메모리 | 4 GB | 8 GB |
| 그래픽 | Vulkan 또는 OpenGL 3.3 지원 내장 그래픽 | GTX 1050 급 |
| 저장 공간 | 1 GB | 1 GB |

- Linux·Steam Deck: CLAUDE.md 고정 조건대로 대응 목표 (Deck 조작은 패드 매핑 확인 필요 → 개발팀).

---

## 4. 남은 결정 (대표·사람 대표)

1. 스팀 앱 등록 시점 (등록비 — 돈이 드는 일).
2. 가격대 (참고: 비슷한 아늑한 시뮬 3시간 분량은 보통 저가대) — 사람 대표 결정.
3. 영어 원어민 검수를 할지 (돈이 들 수 있음, 무료 대안: 체험판 의견).
4. 체험판(데모) 낼지 — 낸다면 1~3일차 (고양이까지).
