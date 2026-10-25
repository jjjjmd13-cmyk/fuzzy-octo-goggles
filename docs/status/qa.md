# QA 상태

**지금 하는 일**: 개발팀 PR #4(`dev/foundation`) 리뷰 — 개발팀이 main 을 합쳐 푸시하면 CI·테스트 규칙·자동 항목(혼자 하기, 2인 접속, 호스트 퇴장) 확인

**끝낸 일**:
- TEST_PLAN 난입 우선순위 조정: GDD 데모 범위(로비에서만 참가, 원정 중 참가·재접속 없음)에 맞춰 JOIN-01~04·LANT-30~33 을 '데모 이후'로, 대신 원정 중 참가 거절(JOIN-05)·끊긴 플레이어 쓰러짐 처리(LEAVE-07)·STEAM-16 추가
- 스팀 실기 수동 테스트 한 장 정리 `docs/qa/STEAM_MANUAL_TEST.md` (PC 2대·계정 2개, 빌드 받기부터 결과표까지)
- PR #2 테스트 체계와 CI 병합, 라벨 4개 생성 완료
- CI (`.github/workflows/ci.yml`): Godot 4.4.1 헤드리스(캐시) → 실행기 자체 검사 → 프로젝트 임포트·테스트 씬 실행. `project.godot` 없으면 건너뜀
- 테스트 실행기 `tests/run_tests.sh`, 테스트 기본 스크립트 `tests/qa_test.gd`, 실행기 자체 검사 `tests/selftest.sh`
- 테스트 규칙 `docs/qa/TESTING.md` (파일 이름 `tests/**/test_*.tscn`, 성공 문자열 `QA_TEST_PASS`, 종료 코드 0)
- 테스트 계획 `docs/qa/TEST_PLAN.md` (혼자/접속/늦게 들어오기/나가기/지연·손실/스팀 초대 수동 체크리스트/저사양·Steam Deck, 등불 원정대 전용: 시드 던전·공용 기름·쓰러짐/부활·늦게 들어오기·괴물·어두운 화면)
- 버그 이슈 템플릿 `.github/ISSUE_TEMPLATE/bug.md`
- 라벨 `기획`·`개발`·`QA`·`버그`: 도구로 직접 만들 수 없어 `.github/workflows/labels.yml` 로 만듦 (병합 후 실행되어 만들어짐)

**막힌 것**: 없음

**다른 부서에 요청**:
- 개발팀: 테스트 씬은 `docs/qa/TESTING.md` 규칙을 따라 주세요. 자동 테스트에 필요한 기능 목록은 `docs/qa/TEST_PLAN.md` 맨 아래 "개발팀에 필요한 것" (기반 코드가 올라오면 이슈로 구체화)
