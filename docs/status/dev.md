# 개발팀 상태

**지금 하는 일**: 멍냥 목욕탕 ① 등불 코드 삭제 + 쿼터뷰 플레이어 + 들기 부품(`dev/bathhouse-carry`) 검토 대기. 다음 ② 동물·기계 (기획팀 GDD_V2 목표 받은 뒤)

**끝낸 일**:
- 멍냥 목욕탕 뼈대: 등불 원정대 코드 삭제(보관 브랜치 `archive/lanternfall-prototype`), 위에서 비스듬히 보는 3인칭 플레이어 + 고정 카메라, 들기·내려놓기·건네기 공용 부품 `Carryable`, 밝은 가게 방 하나
- 이슈 #10: 방이 가득 차면 5번째가 곧바로 "방이 가득 찼습니다 (4/4)" 로 거절됨
- 협동 멀티플레이 기반 (Net, 오프라인·ENet·Steam, 메뉴, 테스트 체계)

**자동 테스트**: `GODOT=/path/to/Godot_v4.4.1-stable_linux.x86_64 tests/run_tests.sh`
- 개발팀: `test_offline_session`, `test_seeded_rng`, `test_balance`, `game/test_carry`, `net/test_enet_two_peers`, `net/test_carry_sync`(.roles)

**막힌 것**:
- 스팀 경로 실기 확인 불가 (컨테이너에 스팀 없음, codeberg.org 막힘). SteamMultiplayerPeer 포함 여부 **미확인** — `tools/fetch_godotsteam.sh` 가 받은 뒤 검사해 출력함.

**다른 부서에 요청**:
- QA: 등불 원정대를 지우면서 `tests/net/test_host_authority`(LANT-13·40, 등불·추적자 시험)를 지웠습니다. 같은 성격(위조 요청 무시)을 들기로 옮긴 시험이 `tests/net/test_carry_sync` 5번입니다. TEST_PLAN 의 LANT 항목 정리 부탁합니다.
- QA: `export_presets.cfg` 의 실행 파일 이름(`Lanternfall.exe`)은 Windows 빌드 CI(`build.yml`)가 쓰고 있어 그대로 두었습니다. 이름을 바꿀 때 같이 바꿔 주세요 (제품 이름만 PawsAndBubbles 로 바꿈).
- 기획팀: 새 수치 키(`carry_pickup_range` 1.6 m, `carry_give_range` 2.5 m, `carry_speed_mult` 0.85, `carry_drop_distance` 0.9 m, 달리기 3초)를 TUNING_V2 에 넣어 주세요. 임시 값입니다.
