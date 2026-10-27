# 3D 아트 납품 · 두 번째 그래픽 방향

2026-10-27 사용자 요청: **Dooms Hair Salon / Onigiri Shop Simulator처럼 보이는 그래픽**. 게임 방식의 복제나 협동 확정 요청으로 처리하지 않았다. 협동 가능성은 열려 있으며 이번 변경은 그래픽 파일에 한정한다.

기존 장난감 버전에서 형태·비율·재질을 바꾼 **1차 수정본**이다. 원본 모델에 실제 변경을 적용했고, 미리보기는 새 GLB를 다시 불러와 렌더했다. 현재 게임에 연결된 화면이나 AI로 생성한 완성 예상도가 아니다.

## 파일

| 슬롯 | GLB | 삼각형 | X × Y × Z (m) |
|---|---|---:|---|
| `dog` | [dog.glb](../../art/incoming/dog/dog.glb) | 7,692 | 0.364 × 0.601 × 0.558 |
| `owner` | [owner.glb](../../art/incoming/owner/owner.glb) | 3,844 | 0.540 × 1.550 × 0.269 |
| `tub` | [tub.glb](../../art/incoming/tub/tub.glb) | 3,908 | 1.600 × 1.291 × 1.240 |
| `turntable` | [turntable.glb](../../art/incoming/turntable/turntable.glb) | 480 | 1.000 × 0.040 × 1.000 |
| `chair` | [chair.glb](../../art/incoming/chair/chair.glb) | 1,384 | 0.450 × 0.748 × 0.420 |
| `tiles/floor` | [floor.glb](../../art/incoming/tiles/floor.glb) | 3,020 | 2.000 × 0.055 × 2.000 |
| `tiles/wall` | [wall.glb](../../art/incoming/tiles/wall.glb) | 3,020 | 2.000 × 2.000 × 0.300 |

- [기존/수정 비교](style_comparison_v2.png): 왼쪽 기존, 오른쪽 수정.
- [현재 전체 에셋](slots_overview.png): dog · owner · tub / turntable · chair · tiles 순서.
- [현재 매장 조합 렌더](slots_scene_preview.png): 같은 GLB들과 바닥·벽 타일 모듈을 반복 배치한 검토 장면.
- [강아지 사선·정면·후면](../../art/incoming/dog/dog_preview.png).
- 각 슬롯 폴더에는 여전히 미리보기 PNG 한 장씩만 납품한다. 기존 이미지는 Git 이력과 [기존 전체 사진](reference_history/slots_overview_v1.png)에 남아 있다.

## 바뀐 부분

- 강아지: 눈·머리의 과장된 비율 축소, 연속된 볼·주둥이·턱 메시, 가는 앞다리와 발목. 머리는 목, 눈은 눈 가운데, 귀는 귀 뿌리, 다리는 어깨, 꼬리는 각 마디 뿌리가 피벗이다.
- 깨끗한 털 색은 1024² PNG 한 장에 들어 있다. 작은 색소 차이로만 털결을 표현했다. `DIFFUSE`의 **COLOR만** 알베도로 옮겼으며 DIRECT·INDIRECT·AO·노멀·오염·거품·젖음은 텍스처에 포함하지 않았다. 상태 효과는 계속 게임 셰이더가 담당한다.
- 주인: 작은 머리와 길어진 몸·팔다리의 비율. **기존 2등신 스타일은 이번 그래픽 요청에 맞춰 변경**했다. 키 1.55m, 필수 이름·관절·흰색 `Shirt`·`Hat` 및 6가지 색 변경은 유지한다.
- 욕조: 얇은 스테인리스 프레임, 조절 발, 단단한 상판, 광택이 다른 법랑 내·외부, 작은 배수 마개, 금속 도구걸이.
- 회전판: 장식 발바닥 대신 고무 상판과 금속 테두리. 지름 1m·두께 0.04m·중심 피벗·윗면 +0.02m 유지.
- 의자: 얇은 금속 다리와 채도를 낮춘 비닐 좌판·등판. 폭 0.45m, 앉는 면 0.4m 유지.
- 타일: 실제 모듈 간격을 따르는 줄눈과 작은 색 차이. 바닥·벽 2×2m, 바닥 윗면 0, 벽 두께 0.3m·방 안쪽 +Z 유지.
- 단색 이외의 재질 차이는 PBR의 거칠기·금속성 **상수**로 표현한다. 추가 맵은 사용하지 않는다.

## 유지한 기술 약속

미터·Y-up·−Z 정면, 바닥 원점(회전판은 중앙), 뼈대와 애니메이션 없음. 강아지 필수 이름 14개 및 `Head` 자식 눈·귀, `Tail_1 → Tail_2 → Tail_3` 계층을 유지한다. 털 UV에 겹침이 없으며 눈·코·입·혀는 비털 재질로 분리했다. 털 상태와 클릭 판정은 기존 게임 코드가 담당한다.

주인 비율 변경에 따른 개발팀 연결 항목: 실제 키 1.55m와 엉덩이 관절 높이에 맞춰 말풍선 높이·앉는 자세의 루트 높이를 확인해야 한다. 기존 스크립트의 이름 찾기·색상·관절 회전은 검사했으며, 의자에 앉았을 때의 접지는 연결 씬에서 보정할 항목이다.

현재 스타일과 원점 값: [ART_DIRECTION.json](ART_DIRECTION.json), [RETAIL_JOINTS.json](RETAIL_JOINTS.json).

## 검수

- GLB 7개: 파일 구조·치수·부위·피벗·노멀·비퇴화 삼각형·재질 맵·털 UV 무겹침 검사 PASS. [수치 기록](VALIDATION_SLOTS.json).
- Khronos glTF Validator: 7개 모두 오류 0 / 경고 0. [원본 기록](VALIDATION_GLTF.json).
- Godot 4.4.1: 7개 GLB 직접 파싱 및 기존 스크립트 호환 PASS. 털 메시 16개 / 볼록 클릭 판정 16개, 혀 표시와 다리 관절 움직임, Shirt/Hat 6개 색상 변경 확인.
- 기존 게임 테스트 묶음은 첫 납품 때 13개 모두 통과했다. 이번 변경은 모델과 렌더·검수 도구에 한정되며, 현재 모델에 대해서는 위 전용 호환 검사를 다시 실행했다.
- 미리보기 6장 모두 PNG 디코딩 및 시각 확인. 모델의 최종 게임 조명·털 표현은 개발팀 연결 후 확인해야 한다.

제작·권리 기록: [ASSET_PROVENANCE.md](ASSET_PROVENANCE.md). 외부 게임의 모델·텍스처·스크린샷 픽셀은 납품 파일에 포함하지 않았다. 생성 원본: `tools/art/build_retail_slots.py` (기존 `build_slots.py`는 공통 메시 함수와 v1 기록).

## SHA-256

- `art/incoming/chair/chair.glb`: `0a4ccc965398f9b5105fb2b39bf6d43fc3f60f807c6a7752d36cca997dd81c9f`
- `art/incoming/dog/dog.glb`: `0cbfda1bcff6796f46bcd790ade14d5cbf2577770cd8b6c14e556b1324468f91`
- `art/incoming/owner/owner.glb`: `cbaf72ba9b19e52e20bbc1f5cd05f7e87d9ce0dc7586b3d5fdfb00d0b090fcf1`
- `art/incoming/tiles/floor.glb`: `52af0c6608163f540ee12599eecee007aedc000a42a3e05b48c692f0358e4f91`
- `art/incoming/tiles/wall.glb`: `75e46ab28ede92377242d79270b36cccc54e601a1069690a212286c4d61122db`
- `art/incoming/tub/tub.glb`: `438c1e1f75258ee61c7622d2f907629ac1b1298acc20cb7973e02d7669b49186`
- `art/incoming/turntable/turntable.glb`: `e4a26c492f97a90f8aa46407a3e0282b3dad009e6d8715d21162f295495fbe3a`
