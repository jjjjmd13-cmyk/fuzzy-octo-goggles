# 스팀 업적 목록 (초안) — 멍냥 목욕탕

작성: 기획팀 · 2026-11-05 · 판 0.1 · 근거: [GDD_V4.md](GDD_V4.md) (V4 핵심 기능 완료, main 38b277f 기준)

- **지금 있는 기능으로 확인할 수 있는 것만** (저장 파일 `user://v4_save.json` 의 값이나 그 순간의 일로 바로 판정). 새 기능·새 그래픽 필요 없음.
- 18일 안에 대부분 얻고, 몇 개는 엔딩 뒤 자유 영업까지 가야 얻는 정도. **놓치면 다시 못 얻는 업적은 없음** (자유 영업에서 언제든).
- 돈: 업적 자체는 무료. 단, **스팀에 실제로 등록하려면 앱 등록(등록비)이 먼저** — 돈이 드는 일이라 사람 대표 결정 뒤. 그 전까지 개발팀은 이름표(API 이름)로만 판정해 두고, GodotSteam 이 없거나 테스트 앱 ID 480 이면 아무것도 안 함 (480 은 다른 게임 업적이라 쓰지 않음).

## 목록 (15개)

| # | API 이름 | 한국어 이름 | 한국어 설명 (조건) | English name | English description | 판정 (코드) |
|---|---|---|---|---|---|---|
| 1 | `ACH_FIRST_BATH` | 첫 손님 | 손님 한 마리를 처음부터 끝까지 씻겨 돌려주기 | First Guest | Wash a guest from start to finish and hand them back | 첫 돌려주기 |
| 2 | `ACH_FIRST_PARCEL` | 택배 왔어요! | 택배 상자를 처음 열기 | Special Delivery | Open your first delivery box | 첫 상자 열기 |
| 3 | `ACH_FIRST_FAV` | 여기가 좋아? | 손님이 좋아하는 곳을 처음 찾기 | Right There! | Find a guest's favorite spot for the first time | 첫 좋아하는 곳 |
| 4 | `ACH_FIRST_THRILLED` | 신났다! | 손님을 처음으로 🤩 신나게 돌려주기 | Over the Moon | Send a guest home thrilled for the first time | 첫 🤩 |
| 5 | `ACH_FIRST_CAT` | 냥! | 고양이 손님을 처음 씻기기 | Meow! | Wash your first cat | 첫 고양이 돌려주기 |
| 6 | `ACH_FIRST_TRIM` | 꼭 그 모양으로 | 미용 요청을 처음으로 '똑같음' 으로 끝내기 | Just Like the Picture | Finish a trim request with a perfect match | 미용 모양 '똑같음' |
| 7 | `ACH_FIRST_QUIRK` | 이제 안 무서워 | 도구 버릇이 있는 단골이 처음으로 그 도구를 편하게 끝냄 (사진첩 기록 `quirk_shower`·`quirk_dryer`·`quirk_towel` 중 처음 하나) | Not Scared Anymore | Help a regular get through their tool quirk without fuss | 버릇 넘은 날 기록 |
| 8 | `ACH_FIRST_BESTIE` | 첫 단짝 | 단골 하나와 단짝 되기 | First Best Friend | Become best friends with a regular | 신뢰 단계 3 하나 |
| 9 | `ACH_BESTIE_6` | 우리 동네 인기 가게 | 단짝 단골 6마리 (엔딩 ⭐3 과 같음) | Neighborhood Favorite | Become best friends with 6 regulars | 신뢰 단계 3 이 6 |
| 10 | `ACH_MONGSIL` | 몽실이의 용기 | 몽실이와 단짝 되기 | Brave Little Puff | Become best friends with Puff | 몽실 신뢰 단계 3 |
| 11 | `ACH_ALBUM_ALL` | 모두 만났어요 | 단골 24마리를 모두 만나기 | Everyone's Here | Meet all 24 regulars | 사진첩 24칸 |
| 12 | `ACH_GOLD_12` | 반짝반짝 사진첩 | 금색 사진 12장 (엔딩 ⭐1 과 같음) | Golden Memories | Collect 12 golden photos | 🤩 사진 12 |
| 13 | `ACH_ALL_TIER5` | 최고의 도구 | 도구 5개를 모두 5단계까지 | Top of the Line | Upgrade all five tools to their final tier | 도구 5개 단계 4 (5단계) |
| 14 | `ACH_COZY_20` | 아늑한 우리 가게 | 놓인 꾸미기 아늑함 ★20 | Cozy Corner | Reach 20 coziness stars in your shop | 아늑함 합 20 |
| 15 | `ACH_THANKS` | 고마워요 | 18일째 '감사의 날' 을 보기 | Thank You | See the Day of Thanks on day 18 | 엔딩 본 뒤 (`ending_seen`) |

- 이름·설명은 번역 키로 (`ACH_*_NAME`, `ACH_*_DESC`) — 스팀웍스에는 한국어·영어 두 언어로 넣음.
- 영어 이름의 단골은 번역 이름 표대로 (몽실 → Puff).
- 숨김 업적 없음 (모두 처음부터 보임). 단, 10번은 몽실이를 만나기 전엔 설명이 스포일러가 될 수 있어 **숨김으로 해도 됨** (사람 대표 선택).

## 더 넣을 수 있는 것 (나중, 지금은 안 넣음)

| API 이름 | 한국어 | 조건 | 왜 나중 |
|---|---|---|---|
| `ACH_ENDING_3STARS` | 별 세 개 | 엔딩 별 3개 모두 | 별 조건과 겹침 (9·12번 + 도구 3개) |
| `ACH_GOLD_ALL` | 모두가 웃었어요 | 금색 사진 24장 | 자유 영업이 길어야 함 — 플레이 기록을 보고 정함 |
| `ACH_ALL_DECOR` | 꾸미기 수집가 | 꾸미기 30개 모두 삼 | 돈 곡선을 보고 정함 |
| `ACH_ALL_ACC` | 멋쟁이 옷장 | 액세서리 12개 모두 | 같음 |

## 그림 (나중)

- 스팀 업적 아이콘은 **64 × 64** (얻은 것 / 아직 못 얻은 것 두 장, 못 얻은 것은 흑백). 그래픽은 ChatGPT 몫 — 앱 등록이 정해지면 요청문을 따로 씀 (지금은 안 씀).

## 개발팀에 부탁 (앱 ID 가 나온 뒤)

- 판정은 한 곳에서 (예: `scripts/v4/fp_achievements.gd`), 위 '판정' 칸의 순간에 `unlock("ACH_…")`. GodotSteam 이 없으면 저장 파일에만 적어 두고, 나중에 스팀이 붙으면 처음 켤 때 한 번에 올림.
- 이미 얻은 업적은 다시 부르지 않음.
