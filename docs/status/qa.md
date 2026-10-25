# QA 상태

**지금 하는 일**:
- 여러 프로세스 테스트 규칙 정리 (PR #7): `.roles` 방식 + 테스트가 직접 자식 프로세스를 띄우는 방식(개발팀 `test_enet_two_peers`)의 규칙
- TEST_PLAN 난입(늦게 들어오기) 우선순위 조정 (GDD 데모 범위에서 빠짐)
- 다음: 기반 위에 빠진 자동 테스트 추가 — 클라이언트 퇴장(LEAVE-01), 호스트 강제 종료(LEAVE-04), 3~4인·5번째 거절(NET-02/03), 서버 없이 접속 시간 초과

**끝낸 일**:
- 개발팀 PR #4 리뷰: CI 초록불·테스트 3개 실제 실행 확인, 일부러 고장 낸 코드 2가지를 테스트가 잡는지 확인 (병합됨)
- 스팀 실기 수동 테스트 한 장 정리 `docs/qa/STEAM_MANUAL_TEST.md` (PC 2대·계정 2개, 빌드 받기부터 결과표까지)
- CI (`.github/workflows/ci.yml`): Godot 4.4.1 헤드리스(캐시) → 실행기 자체 검사 → 프로젝트 임포트·테스트 씬 실행. `project.godot` 없으면 건너뜀
- 테스트 실행기 `tests/run_tests.sh`, 테스트 기본 스크립트 `tests/qa_test.gd`, 실행기 자체 검사 `tests/selftest.sh`
- 테스트 규칙 `docs/qa/TESTING.md` (파일 이름 `tests/**/test_*.tscn`, 성공 문자열 `QA_TEST_PASS`, 종료 코드 0)
- 테스트 계획 `docs/qa/TEST_PLAN.md` (혼자/접속/늦게 들어오기/나가기/지연·손실/스팀 초대 수동 체크리스트/저사양·Steam Deck, 등불 원정대 전용)
- 버그 이슈 템플릿 `.github/ISSUE_TEMPLATE/bug.md`, 라벨 `기획`·`개발`·`QA`·`버그` (`.github/workflows/labels.yml`)

**막힌 것**: 없음

**다른 부서에 요청**:
- 개발팀: 테스트 씬은 `docs/qa/TESTING.md` 규칙을 따라 주세요. 자동 테스트에 필요한 기능 목록은 `docs/qa/TEST_PLAN.md` 맨 아래 "개발팀에 필요한 것"
