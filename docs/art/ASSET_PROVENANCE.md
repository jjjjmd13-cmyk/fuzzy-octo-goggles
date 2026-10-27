# 3D 납품물 · 출처 및 이용 기록

제작일: 2026-10-27 (한국 시간)

## 제작·출처

- 작업 대상: `art/incoming/dog`, `owner`, `tub`, `turntable`, `chair`, `tiles`.
- 모든 메시와 단색 알베도는 이 작업에서 새로 생성했다. 외부 무료/유료 모델, 텍스처, 폰트, 소재 라이브러리를 복제하거나 포함하지 않았다.
- 제작자 표기: ChatGPT / Codex (이 저장소 소유자의 요청으로 제작).
- 모델 생성 원본: `tools/art/build_slots.py`. 납품한 GLB를 다시 불러와 렌더링하는 원본: `tools/art/render_slots.py`.
- Blender 4.5.3 LTS를 제작·렌더 도구로 사용했다. Blender는 GPL 프로그램이며, 모델 납품 파일에 Blender 프로그램 코드를 포함하지 않는다. Blender 배포 라이선스를 GLB의 라이선스로 잘못 표기하지 않았다.
- 미리보기의 조명·그림자는 렌더 장면에만 있다. GLB의 알베도에 굽지 않았다.

## 저장소에서 제공받은 참고 자료

| 자료 | 원본 링크 | 적용 범위 |
|---|---|---|
| 현재 3D 명세 | https://github.com/jjjjmd13-cmyk/fuzzy-octo-goggles/blob/main/docs/art/ART_SLOTS.md | 좌표, 크기, 예산, 이름, 피벗, 납품 경로 |
| 분위기 그림 | https://github.com/jjjjmd13-cmyk/fuzzy-octo-goggles/blob/main/art/incoming/01_bath_scene_redraw.png | 파스텔 색, 둥근 장난감 형태, 낮은 원형 욕조 |
| 강아지 설계 그림 | https://github.com/jjjjmd13-cmyk/fuzzy-octo-goggles/blob/main/art/incoming/02_puppy_turnaround.png | 큰 머리, 짧은 주둥이, 늘어진 귀, 앉은 자세 |
| 강아지 표정 | https://github.com/jjjjmd13-cmyk/fuzzy-octo-goggles/blob/main/art/incoming/04_puppy_expressions_3d.png | 눈·코·웃는 입과 분리된 혀 |
| 공통 색표 | https://github.com/jjjjmd13-cmyk/fuzzy-octo-goggles/blob/main/docs/art/ORDER_V3.md | 민트·버터 노랑·나무·하늘색·빨강·분홍 |

참고 그림은 사용자가 자신의 저장소에서 지정한 자료다. 원본 그림의 별도 저작권 양도·라이선스 문서는 저장소에서 확인하지 못했으므로 CC0 등으로 재분류하지 않았다. 이미지 픽셀을 메시 텍스처로 추출하거나 재배포하지 않았다. 강아지의 갈색 귀는 이미지의 시점별 혼동보다 현재 명세의 “캐릭터 자신의 왼쪽”을 기준으로 정했다. `ORDER_V3.md`의 과거 PNG 전용 안내보다 현재 `ART_SLOTS.md`와 사용자의 GLB 지시를 우선했다.

## 외부 에셋 라이선스 점검

현재 포함한 외부 에셋: **없음**. 따라서 제3자 에셋에 따른 구매비, 로열티, 저작자 표시, 동일조건변경허락, 비상업 제한은 추가되지 않았다. 별도의 저작권 보유나 저작권 등록 가능성을 보증하는 문서는 아니다.

이후 외부 무료 에셋을 추가할 때는 **에셋별로** 아래 내용을 확인하고, 실제 사용한 버전의 라이선스 원문도 함께 남긴다. 무료 다운로드라는 이유만으로 상업 이용이 허용된 것으로 처리하지 않는다.

| 필수 기록 | 확인 내용 |
|---|---|
| 원본·제작자 | 정식 배포 URL, 에셋명, 제작자, 다운로드 날짜·버전 |
| 라이선스 | 원문 URL 및 사본, 정확한 라이선스명·버전 |
| 이용 범위 | 상업 이용, 수정, 게임 내 배포, 소스 저장소 내 재배포 허용 여부 |
| 의무 | 출처 표기 문구·위치, 라이선스 동봉, 동일조건 의무 |
| 제외 사유 | NC·ND·Editorial-only 또는 이용 범위가 불명확한 항목은 적용 전 보류 |


## 2026-10-27 그래픽 방향 수정

사용자는 게임 방식이 아닌 **그래픽**을 Dooms Hair Salon / Onigiri Shop Simulator처럼 바꾸고 싶다고 명확히 했다. 이번 수정은 참고 게임의 실제 화면에서 가구 비율·표면 재질·실내 조명이라는 시각 요소를 분석해 직접 재제작한 것이다.

| 시각 참고 | 정식 출처 | 납품물에 포함한 원본 데이터 |
|---|---|---|
| Dooms Hair Salon, 개발사 Slimebox의 Steam 화면 | https://store.steampowered.com/app/3398870/Dooms_Hair_Salon/ | 없음 |
| Onigiri Shop Simulator, 개발사 Yagni Lab의 Steam 화면 | https://store.steampowered.com/app/3915140/Onigiri_Shop_Simulator/ | 없음 |

이 게임들의 스크린샷을 무료 에셋이나 CC0 자료로 취급하지 않았다. 화면은 분석에만 사용하고 게임 원본 이미지·모델·텍스처·UI·로고는 재배포하거나 추출하지 않았다. `style_refs/`에 받은 분석용 화면은 이 저장소의 커밋 대상이 아니다.

수정된 모든 메시와 털 색소 텍스처도 직접 제작했다. 외부 무료·유료 에셋을 추가하지 않았으며 추가 구매·로열티·에셋 라이선스는 발생하지 않았다. 거칠기·금속성은 상수이고, 내장 털 텍스처에는 색 정보만 있다. `DIFFUSE COLOR` 처리에 조명·AO를 포함하지 않았으므로 빛을 굽는 텍스처가 아니다.

## 실제 게임 연결 및 실행 사진

`assets/models/`는 직접 제작한 GLB 원본과 바이트가 같은 복사본이다 (`RUNTIME_MANIFEST.json`). 게임 실행 사진은 저장소의 기존 UI·간판·아이콘·Pretendard 폰트를 포함한다. 이번 작업에서 이 기존 자산의 권리 상태를 새로 지정하지 않았다. Pretendard 라이선스는 `assets/fonts/pretendard/LICENSE.txt`에 유지되며, 실행 사진 모음의 한글 캡션도 이 폰트를 사용한다. 외부 모델·텍스처·유료 서비스는 추가하지 않았다.
