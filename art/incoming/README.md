# 받은 그림 (사람 대표 · ChatGPT)

지시서: [docs/art/ORDER_V3.md](../../docs/art/ORDER_V3.md)

| 파일 | 지시서 번호 | 쓰임 |
|---|---|---|
| `01_bath_scene_redraw.png` | 1 분위기 | 전체 스타일 기준. 배경·색·조명 참고 |
| `02_puppy_turnaround.png` | 2 강아지 앞·옆·뒤·위 | 3D 강아지 모양 기준 |
| `03_puppy_grooming_states.png` | 2-1 진흙·거품·젖음·뽀송 | 털 셰이더 상태 색 기준 |
| `04_puppy_expressions_3d.png` | 2-2 표정 3개 | 얼굴 표정 기준 |
| `05_bathtub_turnaround.png` | 3 목욕통 앞·옆·위 | 목욕통 모양 기준 |
| `06_grooming_tools_turnaround.png`, `07_yellow_glove_turnaround.png` | 4 도구, 4-1 손 | 3D 도구·손 기준 |
| `10_tool_icons_revised.png` (`08` 은 옛 버전) | 5-1 도구 아이콘 | → `assets/ui/tool_*.png` |
| `09_request_card_icons_check.png` | 5-2 카드·작은 아이콘·체크 | → `assets/ui/icon_*.png`, `check.png` (가로 카드는 안 씀) |
| `11_puppy_face_icons_coin.png` | 5-3 기분 얼굴·동전 | → `assets/ui/face_*.png`, `coin.png` |
| `12_shop_sign.png` | 5-4 간판 | → `assets/ui/sign.png` (가게 이름은 게임이 글자로 올림) |

`assets/ui/` 로 자르는 것은 `tools/cut_ui_art.py`. 이 폴더에는 `.gdignore` 가 있어 Godot 가 가져오지 않는다 (참고용 원본).
같은 그림의 `.webp` 사본 5장은 PNG 원본이 와서 지웠다.

참고: 목욕통 설계 그림은 받침대 위 의자형으로 나와서, 분위기 그림의 낮고 넓은 원형 욕조와 모양이 다르다. 화면 구성은 **분위기 그림을 우선**한다.
