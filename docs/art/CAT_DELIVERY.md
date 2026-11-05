# 고양이 손님 그래픽 납품

납품: `art/incoming/cat/cat.glb`, `art/incoming/cat/cat_preview.png`.
미리보기는 납품 GLB를 다시 불러와 렌더한 정면·오른쪽 옆·뒤 3면이다.
모든 메시·색상은 직접 제작했으며 외부 3D 에셋·사진·AI 이미지·유료 서비스는 사용하지 않았다. 미리보기의 DejaVu Sans는 표기용 폰트이며 GLB에 포함하지 않았다.

## 형식과 모양

- glTF 2.0 바이너리. 1단위=1m, Y-up, 정면 −Z. 루트 `Cat`은 (0,0,0), 회전 0, 크기 1.
- L=−X, R=+X. 기존 `art/incoming/dog/dog.glb`와 같은 방향·이름·관절 계약.
- 높이 약 0.50m, 폭 약 0.314m, 앞뒤 약 0.472m. 앞발·뒷발 아랫면 Y=0. 원점은 앉은 자세 바닥의 좌우 중심.
- 총 7,788삼각형, 메시 29개, 털 메시 18개. 뼈대·스킨·애니메이션 없음.
- 연회색 바탕, 옅은 이마 줄무늬 3줄, 흰 가슴과 발, 분홍 코·귀 안쪽. 큰 둥근 머리, 큰 눈, 작은 웃는 입, 직립 귀, 위로 감긴 가는 3마디 꼬리.

## 계층과 관절

관절의 **모델 기준 월드 좌표**는 `CAT_JOINTS.json`에 기록했다. 자식 노드의 로컬 위치와 혼동하지 않는다. 모든 부위는 독립 메시이며 각 오브젝트의 원점은 지정 관절이다.

| 부모 | 직접 자식 |
|---|---|
| Cat | Torso, Chest, Head, Leg_FL, Leg_FR, Haunch_L, Haunch_R, Paw_BL, Paw_BR, Tail_1, BodyCenter |
| Head | Ear_L, Ear_R, Eye_L, Eye_R, Cheek_L, Cheek_R, Mouth, Nose, Tongue, FaceCenter |
| Ear_L / Ear_R | NoFurEar_L / NoFurEar_R |
| Eye_L / Eye_R | Pupil_L, Glint_L / Pupil_R, Glint_R |
| Leg_FL / Leg_FR | Paw_FL / Paw_FR |
| Tail_1 | Tail_2 |
| Tail_2 | Tail_3 |

Head=목, Ear=귀 뿌리, Eye=눈 중심, Cheek=볼 중심, Leg=어깨, Haunch=엉덩이 관절, Tail=각 마디 시작. Chest/Torso/BodyCenter=각 몸통 중심, FaceCenter=두 눈 사이의 얼굴 표면. 귀 안쪽은 해당 귀를, 눈동자·반짝이는 해당 눈을, 앞발은 해당 앞다리를 따른다.

## 재질과 UV

털은 모두 하나의 `FurCleanAlbedo` 재질을 공유하고, 이 재질만 내장 `Cat_Clean_Albedo` PNG 한 장(2048×2048, sRGB)을 사용한다. PNG에는 #C9CDD6, #ADB5C3, #FFFDF9의 깨끗한 털 색만 존재한다. 진흙·젖음·거품·물방울·뽀송·조명·AO·노멀은 구워 넣지 않았다.

각 털 부위는 서로 다른 아틀라스 구역을 사용한다. 구역 안에서도 UV를 펼쳐 겹침을 없앴고 색상 패딩을 넣었다. 최종 GLB 바이트의 모든 털 UV 삼각형을 기하학적으로 교차 검사한다. Eye, Pupil, Glint, Nose, Mouth, Tongue, NoFurEar는 각각 별도 색 재질을 사용한다. `NoFurEar_`는 기존 NON_FUR 이름 규칙으로 자동 제외된다.

## 게임 연결

기존 강아지와 같이 모형을 감싼 게임 노드에서 Y축 180° 회전하면 게임의 +Z 정면에 맞는다. GLB 자체는 −Z 정면을 유지한다. 원래 재질을 유지한 채 기존 `apply_fur_material()`을 적용하면 18개 털 메시가 같은 내장 털 텍스처를 사용한다.

**혀**: 요청대로 기본 혀는 실제로 입 안에 있다. 메시를 삭제하거나 크기를 0으로 만들지 않았다. 현재 `sim_dog_model.gd`는 기분에 따라 `Tongue.visible`만 토글하므로, 이 파일 그대로는 혀가 밖으로 나오지 않는다. 행복할 때 혀를 내밀려면 머리 기준 로컬 위치를 중립 위치에서 `Vector3(0, -0.027, -0.050)` 방향으로 보간하고, 중립에서는 원래 위치로 돌린다. 이는 GLB의 −Z 정면 좌표 기준이며 래퍼의 Y축 회전 후에도 로컬 좌표로 적용한다. 이번 납품은 그래픽이며 게임 실행 코드는 변경하지 않았다.

## 재현과 검수

```bash
blender -b --factory-startup --python tools/art/build_cat.py
blender -b --factory-startup --python tools/art/render_cat.py
python tools/art/compose_cat.py
python tools/art/validate_cat.py
NODE_PATH=/path/to/node_modules node tools/art/validate_gltf.cjs art/incoming/cat/cat.glb
godot --headless --path . --script res://tools/art/verify_cat.gd
blender -b --factory-startup --python tools/art/check_cat_occlusion.py
```

`CAT_VALIDATION.json`은 실제 GLB의 SHA-256, 치수, 삼각형 수, 이름·부모·원점, 깨끗한 PNG 색상, 전역 UV 교차 결과를 담는다. Blender 미리보기는 게임 조명·화면의 스크린샷이 아니다. 게임 내 고양이 손님 등록·성격·가격·등장 로직 연결은 포함하지 않는다.

검수 결과: 최종 파일 기준 Khronos 오류 0·경고 0, 전역 털 UV 겹침 0. Godot 4.4.1의 별도 프로젝트 및 원본 프로젝트에서 같은 GLB를 읽고 털 18개·공용 내장 텍스처·NON_FUR 제외·계층·기분/부위 동작을 확인했다. 중립 혀는 258개 전방 시선 광선에서 모두 입에 가려진다. `FaceCenter`와 `BodyCenter`는 의도된 빈 노드이므로 glTF의 정보 수준 안내 2건은 정상이다.

기존 게임 전체 회귀 검사(`tests/run_tests.sh`, Godot 4.4.1): **35개 통과 / 0개 실패**. 고양이 손님 등장 로직을 새로 연결한 결과는 아니며, 기존 게임이 이번 그래픽 추가로 깨지지 않는지 확인한 결과다.
