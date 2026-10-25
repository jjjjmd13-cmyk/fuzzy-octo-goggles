# 게임 UI 글꼴 결정

작성: 기획팀 · 2026-10-25 · 요청: 개발팀 (대표 전달)

## 결정

| 쓰임 | 글꼴 | 라이선스 |
|---|---|---|
| **본문·UI 전체 (한/영)** | **Pretendard** (1.3.9) | SIL OFL 1.1 |
| 대체(fallback) — 스팀 닉네임 등 한/영 밖 글자 | **Noto Sans CJK** (+ 필요하면 Noto Sans) | SIL OFL 1.1 |
| 제목·로고 | 정하지 않음 — 로고는 그래픽으로 받음 (`docs/art/` 에서 따로 요청) | — |

## 근거

### 라이선스 (상업 출시 가능)

- **Pretendard** — SIL Open Font License 1.1. 상업적 사용·수정·재배포 가능, 글꼴 파일만 따로 파는 것은 금지. 게임에 넣어 파는 것은 허용 (OFL 허용 조건 1: 글꼴 단독 판매만 금지, 소프트웨어와 함께 번들·재배포·판매는 가능).
  - 저장소: https://github.com/orioncactus/pretendard
  - 라이선스 전문: https://github.com/orioncactus/pretendard/blob/main/LICENSE
  - **주의: 예약 글꼴 이름(Reserved Font Name) `Pretendard`** 가 있음. 파일을 **고치면(서브셋 포함)** 고친 판에는 `Pretendard` 이름을 쓸 수 없음 → 아래 '개발팀 규칙' 참고.
- **Noto Sans CJK** — SIL Open Font License 1.1, 예약 글꼴 이름 없음.
  - 저장소: https://github.com/notofonts/noto-cjk
  - 라이선스 전문: https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE
- OFL 원문: https://openfontlicense.org

### 읽기 좋은 정도 (Steam Deck 1280×800)

- Pretendard 는 화면용으로 만든 고딕(산세리프). 한글 글자 폭·높이가 고르고, 영문은 Inter 기반이라 **한/영이 섞여도 굵기·높이가 맞음** → 한 글꼴로 두 언어를 처리.
- 굵기 9단계 (가변 글꼴 포함) → 어두운 화면 위 흰 글자에 Medium/SemiBold 를 써서 획이 뭉개지지 않게 할 수 있음.
- 어두운 배경에 글자를 올리는 게임이라 명조(세리프)·손글씨체는 작은 크기에서 획이 사라져 제외.

## UI 글자 크기 기준 (1280×800 기준)

| 쓰임 | 크기(px) | 굵기 |
|---|---|---|
| 작은 설명·도움말 | **최소 18** | Regular |
| 본문·메뉴 | 22~24 | Medium |
| 상호작용 안내 ("E 줍기") | 26 | SemiBold |
| 제목 | 36~48 | Bold |

- Steam Deck 화면(7인치)에서 18px 미만은 읽기 어려움 → **18px 이 최소**. 해상도가 커지면 같은 비율로 키움.
- 어두운 배경 위 글자에는 1~2px 어두운 외곽선(`outline_size`)을 넣어 빛 반경 위에서도 읽히게.
- 영어가 한국어보다 길어지므로 버튼·칸은 한국어 기준 **1.4배** 폭을 잡음.

## 개발팀 요청 (파일 추가는 개발팀이)

1. Pretendard 1.3.9 릴리스에서 **OTF 또는 TTF 원본을 고치지 않은 채로** 프로젝트에 넣어 주세요 (가변 글꼴 1개 또는 Regular·Medium·SemiBold·Bold 4개).
   - 직접 서브셋(글자 줄이기)·이름 변경·병합을 하면 OFL '수정판'이 되어 `Pretendard` 이름을 쓸 수 없습니다. 파일 크기 문제로 서브셋이 필요하면 먼저 기획팀/대표에게 알려 주세요 (새 이름으로 바꾸는 절차가 필요).
   - 한글 전체 11,172자가 들어 있는 원본을 써야 스팀 닉네임·채팅의 드문 글자가 깨지지 않습니다.
2. **라이선스 파일을 글꼴 옆에 같이** 넣고(`LICENSE` / `OFL.txt`), 게임 크레딧(또는 '오픈소스 라이선스' 화면)에 글꼴 이름과 라이선스를 표시해 주세요.
3. Godot `Theme` 하나에 기본 글꼴로 지정해 모든 UI가 따라가게 하고, Noto Sans CJK 를 **fallback** 으로 등록해 주세요 (`FontFile.fallbacks`). 일본어·중국어 닉네임이 □ 로 나오지 않게.
4. 3D 공간 글자(`Label3D`)를 쓰면 MSDF 렌더링을 켜 주세요 (멀리서 봐도 번지지 않음).
5. 글꼴 경로도 그래픽처럼 **한 곳에서 교체** 가능하게 (Theme 리소스 하나).
