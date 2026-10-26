# 개발팀 상태

**지금 하는 일**: 첫 플레이 테스트 피드백 수정 PR (`dev/playtest1-fixes`) 검토 대기. 기획팀 목표·안내 문구 받으면 `data/text/prototype_text.tres` 에 반영

**끝낸 일**:
- 첫 플레이 테스트(혼자 하기) 피드백 수정: 휠 밝기 안내·큰 알림, 추적자 몸 충돌·닿으면 공격·플레이어 쪽 배회, 쫓김 경고, 시작 안내, 임시 출구·원정 성공 화면, 기름 분당 소모 표시 (`tests/game/test_playtest1`)
- 이슈 #10: 방이 가득 차면 5번째가 곧바로 "방이 가득 찼습니다 (4/4)" 로 거절됨 (ENet·스팀 모두)
- 협동 멀티플레이 기반 (PR #4, 병합됨)
- GDD 13장 첫 시제품 (PR #12, 병합됨. `docs/dev/PROTOTYPE.md` 에 실행 방법)
  - 손으로 배치한 방 3개 (2 m 타일, 문 연결), 1인칭 이동·달리기·스태미나
  - 큰 등불 줍기·내려놓기·건네기·밝기 3단계, 손등, 공용 기름(호스트 권한) + 심지 60초
  - 어둠 게이지(호스트 계산), 그림자 추적자 상태 기계 전체 (호스트 AI, 길찾기, 20 Hz 동기화)
  - 쓰러짐 30초 → 등불 빛 안에서 3초 부활, 전원 쓰러짐 → 실패 → 다시 시작
  - 수치 리소스 하나 `data/balance/balance.tres` (TUNING.md 키 이름 그대로)
  - 디버그 키: F5 기름 30 으로 다시 시작 (플레이 테스트 2판째), F6 다시 시작, F7 쓰러지기, F3 수치
  - 글꼴: Pretendard 1.3.9 원본 4종 + OFL 라이선스, 테마 한 곳 (`ui/theme/main_theme.tres`)
  - Windows·Linux 내보내기 설정 (`export_presets.cfg`), 컨테이너에서 실제 내보내기·실행 확인

**자동 테스트 (QA 규칙 `docs/qa/TESTING.md`)**: `GODOT=/path/to/Godot_v4.4.1-stable_linux.x86_64 tests/run_tests.sh` → 7개
- 기반: `test_offline_session`, `net/test_enet_two_peers`, `test_seeded_rng`
- 시제품: `test_balance`, `game/test_lantern_oil`, `game/test_stalker`, `net/test_lantern_sync`
- 네트워크 테스트는 클라이언트를 별도 프로세스로 띄움, UDP 포트 24611·24612 사용. 전체 약 40초.

**막힌 것**:
- 스팀 경로 실기 확인 불가 (컨테이너에 스팀 없음, codeberg.org 막힘). SteamMultiplayerPeer 포함 여부 **미확인** — `tools/fetch_godotsteam.sh` 가 받은 뒤 검사해 출력함.

**다른 부서에 요청**:
- 기획팀: 목표·안내 문구를 `data/text/prototype_text.tres` 형식으로 주세요 (지금은 개발팀 임시 문구). TUNING.md 에 새 시제품 키 3개(`proto_exit_radius` 2 m, `proto_stalker_wander_toward_player` 0.6, `proto_stalker_contact_range` 0.9 m) 반영 부탁.
- 기획팀: "혼자 하기 첫 판 2분 안에 추적" — GDD 5.4 규칙상 빛 안에 있으면 어둠 게이지가 안 올라 '추적' 상태는 되지 않습니다. 지금은 추적자가 빛 가장자리까지 와서 기다리게 했습니다(7~31초 안에 나타남, 측정). 빛 안 사람도 쫓게 할지는 규칙 결정이 필요합니다.
- 기획팀: `docs/dev/PROTOTYPE.md` 9장 "시제품에서 정한 것"(심지 빛 취급, 기름 5 미만 부활, 혼자일 때 쓰러짐 = 실패 등) 확인 부탁.
- 기획팀: 소리(기름 부족 경고음, 추적자 공격 준비 소리) 에셋/방향이 정해지면 붙이겠습니다. 지금은 눈 빛·붉은 빛으로만 알림.
- QA: TEST_PLAN LANT-10·11·12·20·21 을 자동 테스트로 넣었습니다 (`tests/net/test_lantern_sync`). LANT-22(두 명이 동시에 부활)는 3인 테스트가 필요해 아직.
