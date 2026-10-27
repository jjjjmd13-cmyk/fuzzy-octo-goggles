# 3D 아트 납품 · 2026-10-27

현재 명세: [ART_SLOTS.md](ART_SLOTS.md). 완료 순서: dog → owner → tub → turntable → chair → tiles.

## 납품 파일

| 슬롯 | GLB | 삼각형 | 실제 전체 치수 X × Y × Z (m) |
|---|---|---:|---|
| `dog` | [dog.glb](../../art/incoming/dog/dog.glb) | 7,486 | 0.529 × 0.601 × 0.568 |
| `owner` | [owner.glb](../../art/incoming/owner/owner.glb) | 3,844 | 0.712 × 1.550 × 0.570 |
| `tub` | [tub.glb](../../art/incoming/tub/tub.glb) | 3,532 | 1.600 × 1.320 × 1.240 |
| `turntable` | [turntable.glb](../../art/incoming/turntable/turntable.glb) | 512 | 1.000 × 0.040 × 1.000 |
| `chair` | [chair.glb](../../art/incoming/chair/chair.glb) | 1,406 | 0.451 × 0.685 × 0.417 |
| `tiles/floor` | [floor.glb](../../art/incoming/tiles/floor.glb) | 3,020 | 2.000 × 0.060 × 2.000 |
| `tiles/wall` | [wall.glb](../../art/incoming/tiles/wall.glb) | 3,020 | 2.000 × 2.000 × 0.300 |

각 슬롯 폴더에 `<slot>_preview.png` 한 장씩 있다. 강아지는 같은 GLB의 3/4·정면·후면을 한 장에 담았다. 타일은 바닥·벽을 한 장에 담았다.

- [강아지 미리보기](../../art/incoming/dog/dog_preview.png)
- [전체 에셋 미리보기](slots_overview.png): 위쪽 dog · owner · tub, 아래쪽 turntable · chair · tiles.
- [조합 렌더](slots_scene_preview.png): 납품 GLB를 임시 렌더 장면에 조합한 이미지. 게임 실행 화면은 아니다.
- [제작 출처·이용 기록](ASSET_PROVENANCE.md): 외부 모델·텍스처 사용 없음.

## 명세 확인

- glTF 2.0 GLB, 1 단위 = 1m, Y-up. 캐릭터 정면 −Z. 전체 모델의 기본 원점은 바닥 중심, 회전판만 중앙.
- 뼈대·스킨·애니메이션 없음. 움직이는 오브젝트의 정점 위치를 관절 피벗 기준으로 저장하고 오브젝트 변환은 회전 0·크기 1로 내보냄.
- 강아지 필수 이름 14개 모두 대소문자까지 일치. `Eye_L/R`, `Ear_L/R`는 `Head`의 자식. `Tail_1 → Tail_2 → Tail_3`. 코·입·혀도 머리를 따라감. `FaceCenter`, `BodyCenter`, `Cheek_L/R`도 포함.
- 캐릭터 자신의 왼쪽은 원본 −Z 정면 기준 −X. 갈색 귀는 `Ear_L`. 색은 #F5DEB3 / 밝은 크림 / 연갈색이며, 상태 효과나 조명은 알베도에 넣지 않음.
- 강아지 알베도: 내장 PNG 1024² 한 장. 모든 털 삼각형에 독립된 여백 있는 UV 섬을 배정하고 기하학적 교집합으로 겹침 0을 확인. 눈·코·혀는 별도 비털 재질. 마우스 판정은 게임이 털 메시별로 생성.
- 주인: 높이 1.55m, 약 2등신. `Body` 아래 목·양어깨·양엉덩이 피벗. `Shirt`, `Hat`은 흰색 재질이며 색상 변경 가능.
- 욕조: `Stand`, `Tub`, `Plug`, `ToolRack`. 받침 1.6 × 1.1m, 윗면 y=0.9. 반지름 0.62m의 열린 원형 통, 안쪽 바닥 y=0.906, 뒤 테두리 y=1.06 / 앞 테두리 약 0.99. 앞쪽 −Z에서 보았을 때 도구걸이는 오른쪽. 받침과 바닥의 동일 평면 겹침을 피하도록 안쪽 바닥을 6mm 높임.
- 회전판: `Plate` 한 오브젝트, 원점 (0,0,0), 지름 1m, 두께 0.04m, 윗면 y=+0.02. 발바닥은 내장 512² 알베도에만 있고 돌출 geometry 없음.
- 의자: 폭 약 0.45m, 앉는 면 y≈0.4m, 등받이는 +Z.
- 타일: 바닥 2 × 2m, 윗면 y=0. 벽 2 × 2m, 두께 0.3m, 아랫변 중앙이 원점, 방 안쪽 +Z. 벽은 y를 2m씩 올려 쌓을 수 있고 타일 간격은 반복 시 맞물림.

## 검수 결과

| 검수 | 결과 |
|---|---|
| 파일 구조·수치·피벗·재질·UV | GLB 7개 PASS — [수치 기록](VALIDATION_SLOTS.json) |
| Khronos glTF Validator 2.0.0-dev.3.10 | 7개 모두 오류 0 / 경고 0 — [기록](VALIDATION_GLTF.json). 강아지의 선택 마커 두 개는 정보 수준 `NODE_EMPTY`로만 표시됨 |
| Godot 4.4.1 실제 GLB 파싱·장면 생성 | 7개 성공 |
| 기존 강아지 스크립트 | 필수 부위 발견, 털 메시 18개 / 볼록 클릭 판정 18개, 텍스처 유지, 혀 표시 전환·다리 관절 움직임 확인 |
| 기존 주인 스크립트 | 필수 부위 발견, Shirt 색상 6개 전환 확인 |
| 기존 테스트 묶음 `tests/run_tests.sh` | 통과 13 / 실패 0 |
| 시각 확인 | 실제 GLB 재임포트 후 렌더. 털의 부피·광택·오염 등 최종 상태 표현은 게임 셰이더 연결 후 결정됨 |

재현 절차는 [tools/art/README.md](../../tools/art/README.md)에 있다. 프로덕션 씬·게임 스크립트는 이 납품에서 수정하지 않았다. 개발팀이 `ART_SLOTS.md` 8장의 래퍼와 경로로 연결하면 된다.

## 파일 무결성 (SHA-256)

- `art/incoming/chair/chair.glb`: `1be461e56ffac5bf7703a4b634399a06ac47860ef8254e48f8dac1662d9eebbf`
- `art/incoming/dog/dog.glb`: `edd9be7fbb98d38cd7d012ee8eeb724c2c8b42610c11684a1fc30ca83545d41e`
- `art/incoming/owner/owner.glb`: `e68a1252b4c1b91abed231ed5fce2e3a1242735db4685aecddbf743c94fb5165`
- `art/incoming/tiles/floor.glb`: `a4851b82c41b63c942388b656c75e9bacd5e7659fef4960143e69c87ca9745c9`
- `art/incoming/tiles/wall.glb`: `f4fec0880ab8f4b78012d34adb376613382abc9822c66345e219bce1329d329a`
- `art/incoming/tub/tub.glb`: `8c9e08e00f958e13b395f20382d609579ce0479df2efb63472f3ea1112e1c9c6`
- `art/incoming/turntable/turntable.glb`: `f944791ec87da9091c54b94753db84770cab20735197f5d27fd4238268484236`
