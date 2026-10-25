# 개발팀 상태

**지금 하는 일**: 협동 멀티플레이 기반 PR (`dev/foundation`) 검토 대기

**끝낸 일**:
- Godot 4.4.1 3D 프로젝트 (Mobile 렌더러 + OpenGL 대체, 이유는 `docs/dev/foundation.md`)
- 네트워크 계층 `Net`: 혼자 하기(오프라인 호스트) / ENet / Steam 을 갈아 끼우는 구조. 스팀 애드온이 없거나 초기화 실패해도 정상 동작
- 메인 메뉴 (혼자 하기 / 친구와 하기 / 개발용 IP 접속), 일시 메뉴, 스팀 친구 초대 버튼
- 임시 캡슐 플레이어 3인칭 이동·점프·카메라(마우스·게임패드), 2~4인 위치 동기화, 접속·퇴장, 호스트가 나가면 메뉴 복귀
- 그래픽 교체 지점: `scenes/art/player_model.tscn`
- 헤드리스 자동 테스트 (혼자 하기 1개, ENet 서버+클라이언트 1개)

**자동 테스트 실행 (QA·CI용)**:
```bash
GODOT=/path/to/Godot_v4.4.1-stable_linux.x86_64 tests/run_tests.sh
```
- 프로젝트 임포트(`--headless --import`) → 혼자 하기 테스트 → ENet 서버 1 + 클라이언트 1 (별도 프로세스) 순서로 돈다.
- 성공하면 `OFFLINE_TEST_OK`, `NET_TEST_SERVER_OK`, `NET_TEST_CLIENT_OK`, 마지막에 `ALL_TESTS_PASSED` 출력, 종료 코드 0. 실패하면 로그를 출력하고 1.
- UDP 포트 24600 사용 (`NET_TEST_PORT` 로 변경). 로그 폴더는 `LOG_DIR` (기본: 임시 폴더). 전체 약 10초.
- 하나씩: `godot --headless --path . res://tests/offline_test.tscn`, `godot --headless --path . res://tests/net_sync_test.tscn -- --role=server|client --port=N`

**막힌 것**:
- 스팀 경로는 이 컨테이너에서 실행 확인 불가 (스팀 클라이언트 없음, codeberg.org 접속 막혀 GodotSteam 을 받을 수 없음). 스팀이 켜진 PC에서 `tools/fetch_godotsteam.sh` 후 확인 필요.

**다른 부서에 요청**:
- QA: `tests/run_tests.sh` 를 CI(GitHub Actions)에 붙여 주세요. Godot 4.4.1 받는 방법은 CLAUDE.md 와 같습니다.
- 기획팀: Steam Deck 에서도 보이는 한글 글꼴(무료 라이선스, 예: Noto Sans KR) 결정 부탁. 들어오면 개발팀이 테마에 붙입니다.
- 대표: 스팀 친구 초대 실제 확인은 스팀이 켜진 PC 두 대(계정 두 개)가 필요합니다. 가능할 때 알려 주세요.
