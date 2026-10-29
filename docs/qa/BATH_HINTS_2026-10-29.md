# 목욕 안내 PNG·애니메이션 실행 검사

2026-10-29, Godot **4.4.1.stable.official.49a5bc7b6**, Linux. 렌더링은 Xvfb + OpenGL Compatibility / Mesa 25.2.8 llvmpipe. Windows·Steam 실기는 실행하지 않았다.

## 실행한 검사

| 검사 | 결과와 범위 |
|---|---|
| 최종 헤드리스 임포트 | 종료 0, 오류 출력 없음 ([로그](bath-hints-2026-10-29/import.log)) |
| 기존 테스트 실행기 자체 검사 | 종료 0, `자체 검사 통과`. 의도적으로 실패하는 fixture를 잡는 검사이므로 로그 안의 fixture 오류는 예상 출력 ([로그](bath-hints-2026-10-29/runner_selftest.log)) |
| 1인용 게임 테스트 씬 | **14/14 통과**. 씬별 종료 0 + `QA_TEST_PASS` + 오류 패턴 없음. 아래 목록 참고 |
| 첫 손님 안내 회귀 | 6개 단계 전환·PNG 로드·512px·기존 도구 로드·시범 시간 초기화·4.5초 뒤 닫힘·같은 단계 재등장 없음·둘째 손님/2일차 첫 손님 미표시·쇼핑 화살표·F1 검사 ([최종 로그](bath-hints-2026-10-29/test_first_guide.log)) |
| 실제 렌더 검사 | PNG 6개 로드 상태에서 각 시범 영역의 시간차 프레임 비교 통과. PNG 누락을 캐시의 null로 재현했을 때 6개 대체 시범도 통과. 컴퓨터 자리에서 카드가 그려지지 않음 ([로그](bath-hints-2026-10-29/render.log)) |
| 파일 검사 | 신규 6개 모두 512×512 RGBA, 투명 픽셀 존재. 기존 UI PNG 18개는 base commit과 SHA-256 동일 |
| 시각 검수 | 실제 1280×800 화면 6장·카드 모음 확인: 글자 잘림/카드 겹침 없음, 가로세로 비율 유지. 72프레임 발췌 GIF 생성 |
| 소스 변경 공백 검사 | `git diff --check 7ffc568 HEAD -- scripts/ tests/ tools/ assets/` 통과. 원본 로그에 들어 있는 후행 공백은 변경하지 않았으며 패치 적용 시 공백 경고가 날 수 있다 |

초기 전체 임포트에서는 기존 GLB 7개의 Godot 4.4.1 headless 썸네일 오류가 나왔다. 저장소의 `filter_godot_441_import.py`가 버전과 정확한 오류 블록을 확인해 분리했다. 마지막 재임포트에서는 새 오류 없이 종료했다.

렌더 캡처 프로세스에는 V-Sync 미지원 경고와 종료 때 ObjectDB 인스턴스 경고가 남는다. 로그를 숨기지 않았다. 해당 종료 경고의 원인은 조사하지 않았으며, 14개 헤드리스 게임 테스트 로그에서는 이 경고가 나타나지 않았다. 렌더 검사의 통과는 카드 표시/움직임/누락 대체/자리 숨김 검사가 통과했다는 뜻이다.

## 움직임 픽셀 비교

판 뒤 배경의 미세한 변화를 제외하려고 RGB 채널 차이가 0.15보다 큰 픽셀만 세며, 30개 초과를 통과 기준으로 쓴다. PNG 상태는 실제 시간차 프레임, 누락 대체 상태는 고정한 두 시범 시점으로 비교한다. 수건은 같은 반복 위상을 피해서 누름/뗌 시점을 비교한다. 전체 화면의 강아지 움직임을 시범 움직임으로 오인하지 않도록 시범 영역만 비교한다.

| 단계 | PNG 있음: 변화 픽셀 | PNG 누락: 변화 픽셀 |
|---|---:|---:|
| 적시기 | 973 | 992 |
| 샴푸 짜기 | 1997 | 1200 |
| 문지르기 | 1259 | 1270 |
| 헹구기 | 1200 | 1152 |
| 수건 | 1420 | 1037 |
| 드라이어 | 180 | 80 |

## 14개 씬과 재현

`tests/test_{balance,offline_session,paint_mask,seeded_rng}.tscn`, `tests/game/test_{audio,day_loop,first_guide,guest_kinds,no_shampoo_days,retail_art,save_continue,settle_shop,wash_flow,wash_pace}.tscn`를 각각 별도 Godot 헤드리스 프로세스로 실행했다. [씬별 원본 로그와 results.json](bath-hints-2026-10-29/)을 보존했다. 목욕 조작 테스트의 흉내 손은 6단계를 약 57초에 완료했다.

```bash
# GODOT에 Godot 4.4.1 실행 파일 경로를 지정한다.
"$GODOT" --headless --path . --import
GODOT="$GODOT" tests/selftest.sh
# 각 위 목록 씬을 이 형식으로 실행하고 종료 코드/성공 문자열/오류 출력을 판정한다.
"$GODOT" --headless --path . res://tests/game/test_first_guide.tscn

# 실제 렌더 캡처: Linux에서는 같은 셸에서 Xvfb와 Godot를 실행한다.
Xvfb :94 -screen 0 1280x800x24 -nolisten local -nolisten unix -listen tcp -ac &
bath_display_pid=$!
trap 'kill "$bath_display_pid"' EXIT
sleep 1
DISPLAY=127.0.0.1:94 LIBGL_ALWAYS_SOFTWARE=1 "$GODOT" --path . \
  --rendering-method gl_compatibility --display-driver x11 --audio-driver Dummy \
  tools/art/capture_bath_hints.tscn -- --output=/tmp/bath-hint-captures
python3 tools/art/compose_bath_hints.py /tmp/bath-hint-captures
```

이번 로컬 검사에서는 `tests/net/` 씬과 GitHub 전체 CI 워크플로를 실행하지 않았다. 위 14개 통과를 전체 CI 통과로 보고하지 않는다. Windows·Steam·게임패드의 사람이 직접 하는 실기 검사는 미실행이다.
