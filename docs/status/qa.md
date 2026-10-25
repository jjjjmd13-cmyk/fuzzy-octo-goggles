# QA 상태

**지금 하는 일**: 테스트 체계와 CI (`qa/ci`) PR 검토 대기. 다음: 개발팀 `dev/foundation` PR 이 올라오면 그 브랜치에서 CI·테스트 돌려 보기

**끝낸 일**:
- CI (`.github/workflows/ci.yml`): Godot 4.4.1 헤드리스(캐시) → 실행기 자체 검사 → 프로젝트 임포트·테스트 씬 실행. `project.godot` 없으면 건너뜀
- 테스트 실행기 `tests/run_tests.sh`, 테스트 기본 스크립트 `tests/qa_test.gd`, 실행기 자체 검사 `tests/selftest.sh`
- 테스트 규칙 `docs/qa/TESTING.md` (파일 이름 `tests/**/test_*.tscn`, 성공 문자열 `QA_TEST_PASS`, 종료 코드 0)
- 테스트 계획 `docs/qa/TEST_PLAN.md` (혼자/접속/늦게 들어오기/나가기/지연·손실/스팀 초대 수동 체크리스트/저사양·Steam Deck)
- 버그 이슈 템플릿 `.github/ISSUE_TEMPLATE/bug.md`
- 라벨 `기획`·`개발`·`QA`·`버그`: 도구로 직접 만들 수 없어 `.github/workflows/labels.yml` 로 만듦 (이 PR 이 `main` 에 병합되면 자동 실행)

**막힌 것**: 없음

**다른 부서에 요청**:
- 개발팀: 테스트 씬은 `docs/qa/TESTING.md` 규칙을 따라 주세요. 자동 테스트에 필요한 기능 목록은 `docs/qa/TEST_PLAN.md` 맨 아래 "개발팀에 필요한 것" (기반 코드가 올라오면 이슈로 구체화)
