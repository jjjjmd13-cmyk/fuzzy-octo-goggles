# 스팀 출시 체크리스트 (개발팀)

출시 빌드를 만들 때마다 위에서부터 확인한다. 지금은 시작 줄만 있음 — 출시에 가까워지면 늘린다.

## 내보내기

- [ ] **"Windows Steam Release" / "Linux Steam Release" 프리셋으로 내보냄** (`export_presets.cfg`). 테스트 빌드용 "Windows Desktop" / "Linux" 프리셋이 아님.
- [ ] **dev 폴더 제외 확인**: 두 출시 프리셋의 `exclude_filter` 에 `scenes/dev/*, scripts/dev/*` 가 있음. 내보낸 .pck 를 열어 `scenes/dev`·`scripts/dev` 가 없는지 본다 (빠른 확인 모드는 출시 버전에 **아예 없어야** 함, 사람 대표 결정 2026-11-02). 메인 메뉴는 `scenes/dev/quick_check.tscn` 이 없으면 "빠른 확인" 줄을 만들지 않는다.
- [ ] `tests/*`, `tools/*`, `docs/*` 도 빠졌는지.

## 스팀

- [ ] 스팀 앱 ID 가 테스트 480 이 아닌 실제 값인지 (CLAUDE.md: 앱 ID 가 나오기 전엔 480).
