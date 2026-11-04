# V4 5단계 도구 확장 — 14종 납품 (2026-11-04)

PR #85의 원본 제작 유틸리티와 같은 파스텔 장난감풍을 사용한 자체 제작 메시입니다. 기존 도구 11종과 합쳐 종류마다 5단계가 구성됩니다. 새 GLB 13개를 추가하고, 요청대로 기존 `towel.glb` 1개를 새로 제작했습니다. 게임 실행 코드·구매 가격·판정·진행·업그레이드 선택 코드는 변경하지 않았습니다.

## 단계별 자산 매핑

| 종류 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| 샤워기 | shower | shower_wide | shower_rain | shower_massage | shower_rainbow |
| 거품 | shampoo | foam_pump | foam_sponge | foam_cannon | foam_cloud |
| 수건 | towel | towel_thick | towel_microfiber | towel_mitt | towel_cloud |
| 드라이기 | dryer | dryer_big | dryer_twin | dryer_turbo | dryer_tornado |
| 빗 | brush | brush_slicker | brush_twin | brush_electric | brush_sparkle |

모두 `assets/models/tools/<이름>.glb`. 임포트 설정 sidecar는 이번 PR에 포함하지 않았습니다. 별도 설정이 없는 새 Godot 프로젝트에서도 14개 GLB의 텍스처·피벗·독립 부품 동작을 확인했습니다. 기존 자동 모델 로더가 14개 경로를 모두 인스턴스화하는 것은 검증했습니다. 5단계 구매/선택 시스템과 부품 애니메이션의 게임 내 연결은 별도 개발 작업입니다. GLB 안에는 키프레임을 넣지 않았습니다.

## 형식과 스타일

- glTF 2.0 바이너리, 미터, Y-up, 작동면 -Z. 루트는 변환 없는 손잡이 원점이며 수건·흡수 장갑은 손바닥 중심입니다.
- 모든 GLB에 정확한 sRGB 파스텔 색상 및 금색·무지개 팔레트의 **128×128 RGBA PNG 1장**을 내장했습니다. 외부 이미지 URI, 노멀/AO/발광/금속·거칠기 맵, 빛 굽기, 뼈대는 없습니다.
- 금속·진주·반짝임은 색과 모양으로 표현합니다. 금속도 metallic=0, 발광=0입니다. 두 투명 껍질은 같은 색 PNG의 알파만 사용하고 굴절/전송 효과는 사용하지 않습니다.
- 5단계는 진주색 바탕(브러시는 연분홍), 금색 장식, 무지개 포인트를 공유합니다. 샤워기·드라이기는 큰 머리, 거품 대포는 구름 포구와 날개, 수건은 구름 실루엣, 브러시는 투명 머리와 별·하트 장식으로 구별했습니다.
- 샤워기 별 분사구는 얕은 별 모양 색 메시, 수건 주름·극세사 결·바느질은 메시로 표현합니다. 물·거품·빛·바람 파티클은 포함하지 않습니다.

## 실제 GLB 검사값

| 파일 | 삼각형 | 실제 크기 X × Y × Z (m) |
|---|---:|---|
| shower_massage.glb | 1,240 | 0.1469 × 0.3000 × 0.0622 |
| shower_rainbow.glb | 2,856 | 0.1790 × 0.3500 × 0.0594 |
| foam_sponge.glb | 644 | 0.1500 × 0.1000 × 0.0589 |
| foam_cloud.glb | 2,936 | 0.2465 × 0.4036 × 0.4000 |
| towel.glb | 1,112 | 0.2500 × 0.1500 × 0.0413 |
| towel_thick.glb | 1,400 | 0.2800 × 0.1800 × 0.0610 |
| towel_microfiber.glb | 1,790 | 0.2800 × 0.1800 × 0.0574 |
| towel_mitt.glb | 940 | 0.1523 × 0.2000 × 0.0711 |
| towel_cloud.glb | 932 | 0.3000 × 0.1890 × 0.0645 |
| dryer_twin.glb | 1,820 | 0.2092 × 0.2534 × 0.4000 |
| dryer_turbo.glb | 2,054 | 0.1817 × 0.3035 × 0.4200 |
| dryer_tornado.glb | 2,596 | 0.1970 × 0.3274 × 0.4500 |
| brush_twin.glb | 2,252 | 0.0915 × 0.2200 × 0.0915 |
| brush_sparkle.glb | 2,464 | 0.1043 × 0.2500 × 0.0662 |

길이 축은 샤워기·빗은 Y, 드라이기·구름 대포는 Z, 수건·스펀지는 X입니다. 요청된 주 길이는 정확하게 맞췄고, 스펀지 전체 두께는 방울을 포함해 약 0.059m입니다. 사용자 지정 샤워기 길이(레인 0.32m, 마사지 0.30m)는 유지하고 4단계의 고리·다이얼로 상위 등급을 구분합니다.

## 움직이는 메시와 피벗

| 파일 | 실제 메시 이름 | 피벗 X, Y, Z (m) | 예정 동작 |
|---|---|---|---|
| shower_massage.glb | Dial | 0.000000, -0.005102, -0.024490 | Z축 회전 |
| shower_rainbow.glb | Ring | 0.000000, 0.103072, -0.010105 | Z축 회전 |
| foam_cloud.glb | Bubbles | 0.000000, 0.242154, -0.027270 | 통 중심에서 독립 부유 |
| dryer_twin.glb | Fan_L | -0.052293, 0.115649, -0.247388 | Z축 회전 |
| dryer_twin.glb | Fan_R | 0.052293, 0.115649, -0.247388 | Z축 회전 |
| dryer_turbo.glb | Fan | 0.000000, 0.122793, -0.262558 | Z축 회전 |
| dryer_tornado.glb | Spiral | 0.000000, 0.130263, -0.277303 | Z축 회전 |
| brush_sparkle.glb | Head | 0.000000, 0.090284, -0.008025 | Z축 회전 |

모든 움직이는 부품은 루트 아래의 독립 메시입니다. 전동 머리·팬·다이얼·테는 축 중앙, 비눗방울 묶음은 통 중심을 원점으로 사용합니다. Godot 검사에서는 회전/부유 후 Body 변환이 그대로인지도 확인했습니다.

## 미리보기 및 원본

- `art/incoming/special_tools/<이름>.png`: 파일당 정면과 옆면이 보이는 640×640 Blender 렌더 14장. GLB를 내보낸 동일한 메시로 렌더하고 공유용 PNG 팔레트 인코딩으로 저장했습니다. 배경·촬영 조명은 GLB에 들어 있지 않습니다.
- `overview.jpg`: 전체 14종 모음. `special_set.jpg`: 마지막 단계 5종 모음.
- `tools/art/build_v4_special_tools.py`: 재생성 소스. PR #85의 `build_v4_tool_upgrades.py`, `build_slots.py` 유틸리티를 재사용하며 이전 파일은 수정하지 않았습니다.
- 색/UV는 원본 GLB의 각 버텍스가 올바른 팔레트 칸을 가리키는지 바이트 검사합니다. 초기 검수에서 발견한 큐브/수제 메시의 UV 레이어 이름 차이를 새 제작 소스 안에서 해결했습니다.

## 검증

- `artifact_validation.json`: 14개 모두 PASS. 실제 인덱스·삼각형 면적·법선·UV·색상·PNG·원점·길이·피벗 검사. 모든 파일 3,000삼각형 이하.
- `khronos_validation.json`: 최종 14개 모두 오류 0 / 경고 0.
- `verification_summary.json`: Godot 4.4.1 headless에서 14개 PackedScene 임포트, 128px 내장 텍스처, 실제 관절 메시 및 독립 모션, 기존 `make_model()` 경로 호출 모두 PASS.
- 최초 headless 임포트에는 Godot 4.4.1의 dummy renderer 썸네일 진단 `Parameter "t" is null` / `texture_storage.h:107`이 34회 발생했습니다(기존 모델 포함). PackedScene 저장·실행은 성공했습니다. 내부 경로가 담긴 원본 로그는 PR에서 제외하고, 진단 수와 실행 결과를 검증 요약에 기록합니다.
- 전체 게임 회귀 테스트: **28개 통과 / 0개 실패**. 테스트·게임 실행 코드는 수정하지 않았습니다.
- Windows/Steam Deck 실기, 실제 플레이 조작감, GPU 렌더러에서 투명 오브젝트 정렬, 게임 내 물·바람·별 효과와 부품 애니메이션 연결은 미검증입니다. 미리보기는 Blender 렌더입니다.

## 재현

```bash
blender -b --factory-startup --python tools/art/build_v4_special_tools.py
python tools/art/validate_v4_special_tools.py
python tools/art/compose_v4_special_tools.py
# gltf-validator npm 패키지를 설치한 환경에서:
node tools/art/validate_v4_special_tools.cjs "$PWD"
godot --headless --path . --editor --import
godot --headless --path . --script res://tools/art/verify_v4_special_tools.gd
GODOT=godot bash tests/run_tests.sh .
```

## 출처

메시·색 팔레트·장식·투명 쉘은 이 요청을 위해 코드로 직접 제작했습니다. 외부 메시·텍스처·생성 이미지는 사용하지 않았습니다. 미리보기 글꼴은 저장소에 이미 포함된 Pretendard(OFL)입니다.
