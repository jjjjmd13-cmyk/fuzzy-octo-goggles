# 개발팀 상태

**지금 하는 일**: 이슈 #10 수정 PR (`dev/fix-full-lobby`) 검토 대기, 시제품 PR #12 검토 대기

**끝낸 일**:
- 이슈 #10: 방이 가득 차면 5번째가 곧바로 "방이 가득 찼습니다 (4/4)" 로 거절됨 (ENet·스팀 모두)
- Godot 4.4.1 3D 프로젝트 (Mobile 렌더러 + OpenGL 대체, 이유는 `docs/dev/foundation.md`)
- 네트워크 계층 `Net`: 혼자 하기(오프라인 호스트) / ENet / Steam 을 갈아 끼우는 구조. 스팀 애드온이 없거나 초기화 실패해도 정상 동작
- 메인 메뉴 (혼자 하기 / 친구와 하기 / 개발용 IP 접속), 일시 메뉴, 스팀 친구 초대 버튼
- 임시 캡슐 플레이어 3인칭 이동·점프·카메라(마우스·게임패드), 최대 4인 위치 동기화 (자동 테스트는 2인), 접속·퇴장, 호스트가 나가면 메뉴 복귀
- 그래픽 교체 지점: `scenes/art/player_model.tscn`
- 헤드리스 자동 테스트 3개 (아래)
- 시드 기반 결정론적 난수 유틸 `scripts/core/seeded_rng.gd` (등불 원정대 절차 생성 대비)
- 등불 원정대 조명 비용(등불 4개, Steam Deck) 방침을 `docs/dev/foundation.md` 에 정리

**자동 테스트 (QA 규칙 `docs/qa/TESTING.md` 를 따름)**:
```bash
GODOT=/path/to/Godot_v4.4.1-stable_linux.x86_64 tests/run_tests.sh
```
- `tests/test_offline_session.tscn`, `tests/net/test_enet_two_peers.tscn` (ENet 서버+클라이언트, 클라이언트는 별도 프로세스), `tests/test_seeded_rng.tscn`
- 네트워크 테스트는 UDP 포트 24611 사용, 약 5초.

**막힌 것**:
- 스팀 경로는 이 컨테이너에서 실행 확인 불가 (스팀 클라이언트 없음, codeberg.org 접속 막혀 GodotSteam 을 받을 수 없음). 스팀이 켜진 PC에서 `tools/fetch_godotsteam.sh` 후 확인 필요.

**다른 부서에 요청**:
- QA: 네트워크 테스트가 클라이언트를 별도 프로세스로 띄웁니다 (이유는 `docs/dev/foundation.md` "자동 테스트"). 규칙상 문제가 있으면 알려 주세요.
- 기획팀: Steam Deck 에서도 보이는 한글 글꼴(무료 라이선스, 예: Noto Sans KR) 결정 부탁. 들어오면 개발팀이 테마에 붙입니다.
- 대표: 스팀 친구 초대 실제 확인은 스팀이 켜진 PC 두 대(계정 두 개)가 필요합니다. 가능할 때 알려 주세요.
