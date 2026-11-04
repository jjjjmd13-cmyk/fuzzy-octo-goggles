# 손님 사진첩 그래픽 납품

## 파일

3D 폴더 `art/incoming/album/`:

| 파일 | 설명 | 삼각형 |
|---|---|---:|
| album_book.glb | 분홍 표지·금색 발바닥·하늘색 리본의 닫힌 사진첩 | 794 / 800 |
| album_book_preview.png | 같은 GLB 재로드 렌더: 닫힘 + 표지 열림 | — |
| photo_board.glb | 밝은 원목 테두리·빈 코르크판·작은 꽃과 리본 | 910 / 1,000 |
| photo_board_preview.png | 같은 GLB 재로드 렌더 | — |

2D 폴더 `art/incoming/album_ui/`:

| 파일 | 픽셀 |
|---|---:|
| album_page.png | 1024×1280 |
| photo_frame_grey.png, photo_frame_white.png, photo_frame_pink.png, photo_frame_gold.png | 각 512×600 |
| photo_unknown.png | 512×512 |
| fav_spot_chin.png, fav_spot_ear_back.png, fav_spot_back.png, fav_spot_rump.png | 각 128×128 |
| new_photo_badge.png | 128×128 |

UI는 모두 RGBA PNG. 글자·숫자·로고·물음표 없음. 미지의 손님은 얼굴 없는 회색 강아지·고양이 실루엣, 좋아하는 부위는 하늘색 앉은 강아지 옆모습과 분홍 하트 한 개다. 분홍 프레임에는 하트 두 개, 금색에는 별과 반짝이를 넣었다. 사진첩 종이는 크림 종이 가장자리 바깥이 투명하며 2×2의 옅은 사진 자리와 모서리 발바닥 무늬를 포함한다.

모음 미리보기: `docs/art/screenshots/album_delivery_preview.png`. 체크무늬는 이 미리보기에서 투명 영역을 보여주기 위한 배경이며 납품 PNG에는 없다.

## 3D 좌표·재질

1단위=1m, Y-up, 정면 −Z, glTF 2.0 바이너리. 뼈대·스킨·애니메이션 없음. 각 GLB는 깨끗한 색상 PNG 한 장(512×32)을 파일 안에 포함한다. 노멀맵·AO·조명·그림자 굽기 없음. 미리보기의 조명과 바닥은 GLB에 포함하지 않았다.

색: 크림 #FFF1C9, 원목 #E8C9A0, 하늘색 #8FD3F4, 분홍 #FF9EC4, 민트 #B8E3D3, 체리 #FF6B6B, 금색 #EAC66D, 코르크 #D2AC7D. 모두 알베도 색상이며 금속/거칠기 텍스처 없이 거칠기 상수만 사용한다.

### album_book.glb

책을 카운터에 눕혀 놓는 자세. 루트 `AlbumBook` 원점은 바닥 가운데 (0,0,0). 표지 본체 약 X=0.35 / Y=0.06 / Z=0.28m. 장식과 끈 포함 약 0.35×0.0672×0.2858m.

움직이는 메시 이름은 **Cover**, 원점은 모델 기준 **(−0.175, 0.052, 0)**. 표지의 **로컬 Y축이 책등 방향(모델의 +Z)** 이다. 바닥에 눕힌 책과 Y축 경첩 회전을 함께 만족시키도록 Cover의 처음 회전은 X=90°이며 표지 메시를 이에 맞게 저장했다. 초기 회전을 0으로 초기화하지 않는다.

Godot에서는 처음 transform을 보존하고 로컬 Y축으로 연다:

```gdscript
var rest: Transform3D = cover.transform
# angle: 0 닫힘, 약 105도 열림. 매 프레임 rest에서 다시 계산.
cover.transform = rest
cover.rotate_object_local(Vector3.UP, angle)
```

금색 발바닥과 리본은 Cover의 자식이므로 함께 움직인다. BackCover, Pages, Spine, PageEdge…는 고정 부위다. 75° 회전 시 경첩이 제자리에 있고 자유 끝이 위로 올라가는지 최종 GLB와 Godot에서 모두 검수했다.

### photo_board.glb

루트 `PhotoBoard` 원점은 **뒷면 가운데 (0,0,0)**. 테두리 본체 1.0×0.7m, 두께 0.04m. 앞면은 −Z. 꽃·리본 돌출을 포함한 최대 두께 약 0.0533m. 사진은 붙이지 않았다.

사진 평면은 각 빈 오브젝트의 로컬 XY에 중심을 맞추고 0.2×0.2m로 배치한다. 정면 노멀은 −Z로 향하게 한다. 슬롯의 처음 기울기를 유지한다. 사진 중심 Z=−0.029m로 코르크 앞면보다 2mm 앞에 있어 겹침을 피한다.

| 빈 오브젝트 | 중심 X,Y,Z (m) | 로컬 Z 기울기 |
|---|---|---:|
| Slot_1 | −0.30, +0.14, −0.029 | −4° |
| Slot_2 | 0, +0.14, −0.029 | +3° |
| Slot_3 | +0.30, +0.14, −0.029 | −2° |
| Slot_4 | −0.30, −0.14, −0.029 | +3° |
| Slot_5 | 0, −0.14, −0.029 | −3° |
| Slot_6 | +0.30, −0.14, −0.029 | +4° |

6개 사진의 회전된 네 모서리가 모두 코르크 안에 있고, 서로 겹치지 않는지 검수했다.

## UI 배치

폴라로이드 4종의 외곽은 동일한 **(24,24)~(488,576)**, 사진 구멍은 모두 동일한 **Rect2(64,64,384,384)** 이다. 이 정사각형의 알파는 완전히 0이다. 게임 사진을 뒤에 놓고 그 위에 프레임 PNG를 그리면 된다. 아래쪽 128px 띠에는 게임이 이름·상태를 올릴 수 있다. 생성한 프레임의 가장자리와 장식을 9-slice로 정렬했으므로 색상을 바꿔도 사진 위치는 유지된다.

페이지는 사진과 프레임을 위에 올릴 종이 바탕이다. 하트의 분홍색 중심 좌표와 각 PNG의 정확한 크기·알파 검수는 `ALBUM_VALIDATION.json`에 기록했다.

## 제작·재현

3D는 원본 절차 메시를 직접 제작했다. 2D 11종은 내장 이미지 생성 도구로 제작했으며 정확한 크기·알파 정리·프레임 9-slice 정렬만 준비 스크립트로 처리했다. 유료 외부 서비스나 다운로드한 모델·이미지는 사용하지 않았다. 생성 프롬프트 묶음은 `ALBUM_IMAGE_PROMPTS.md`에 기록했다. 최종 PNG 자체가 2D 납품 원본이다.

```bash
blender -b --factory-startup --python tools/art/build_album.py
blender -b --factory-startup --python tools/art/render_album.py
python tools/art/compose_album.py
python tools/art/validate_album.py
NODE_PATH=/path/to/node_modules node tools/art/validate_gltf.cjs art/incoming/album/album_book.glb art/incoming/album/photo_board.glb
godot --headless --path . --script res://tools/art/verify_album.gd
```

검수: 실제 GLB의 치수·삼각형·내장 PNG·Cover 원점/로컬 축/움직임·빈 슬롯/사진 모서리, UI 11종의 크기·알파·공통 투명 구멍·하트 한 개/중심 구분. 미리보기는 최종 GLB를 재로드한 렌더다. 게임의 앨범 저장·획득·클릭 UI 로직은 이 그래픽 납품 범위에 포함하지 않는다.

최종 검수 결과: Khronos glTF 오류 0·경고 0, Godot 4.4.1 자산 확인 PASS, 기존 게임 전체 회귀 검사 **35개 통과 / 0개 실패**. 게시판 빈 슬롯 6개에 대한 glTF 정보 수준 안내는 요청한 빈 노드이므로 정상이다.
