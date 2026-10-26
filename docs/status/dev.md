# 개발팀 상태

**지금 하는 일**: 멍냥 목욕탕 첫 시제품 PR (`dev/bathhouse-prototype`, #22 위에 쌓음) 검토 대기

**끝낸 일**:
- 멍냥 목욕탕 첫 시제품 (GDD_V2 4장 완료 조건 10개): 강아지 손님·대기석·줄, 욕조·드라이어, 하트, 젖으면 도망·웅덩이·미끄러짐, 출구, 영업 3분·결과·별, Space 한 버튼 + 대시, 효과음 7개(코드로 만든 임시 소리). 실행: `docs/dev/PROTOTYPE.md`
- 멍냥 목욕탕 뼈대: 등불 원정대 코드 삭제(보관 브랜치 `archive/lanternfall-prototype`), 위에서 비스듬히 보는 3인칭 플레이어 + 고정 카메라, 들기·내려놓기·건네기 공용 부품 `Carryable`, 밝은 가게 방 하나
- 이슈 #10: 방이 가득 차면 5번째가 곧바로 "방이 가득 찼습니다 (4/4)" 로 거절됨
- 협동 멀티플레이 기반 (Net, 오프라인·ENet·Steam, 메뉴, 테스트 체계)

**자동 테스트**: `GODOT=/path/to/Godot_v4.4.1-stable_linux.x86_64 tests/run_tests.sh`
- 개발팀: `test_offline_session`, `test_seeded_rng`, `test_balance`, `game/test_bath_flow`, `game/test_seats_queue`, `game/test_slip_dash`, `net/test_enet_two_peers`, `net/test_bath_sync`(.roles)

**막힌 것**:
- 스팀 경로 실기 확인 불가 (컨테이너에 스팀 없음, codeberg.org 막힘). SteamMultiplayerPeer 포함 여부 **미확인** — `tools/fetch_godotsteam.sh` 가 받은 뒤 검사해 출력함.

**다른 부서에 요청**:
- QA: 등불 원정대를 지우면서 `tests/net/test_host_authority`(LANT-13·40)를 지웠습니다. 위조(클라이언트 화면 조작) 무시는 `tests/net/test_bath_sync` 5번에 있습니다. TEST_PLAN 의 LANT 항목 정리 부탁합니다.
- QA: `export_presets.cfg` 의 실행 파일 이름(`Lanternfall.exe`)은 Windows 빌드 CI(`build.yml`)가 쓰고 있어 그대로 두었습니다. 이름을 바꿀 때 같이 바꿔 주세요 (제품 이름만 PawsAndBubbles 로 바꿈).
- 기획팀: TUNING_V2 에 개발팀 임시 키 3개(`proto_drop_distance` 0.9 m, `proto_interact_half_angle` 70°, `proto_slip_immunity` 0.4 s) 반영 부탁. 시작 안내는 QA 리뷰대로 첫 손님을 들 때까지 보이게 바꿔서 `intro_text_time` 은 지금 안 씁니다 (키를 지울지 정해 주세요). 시작 안내 문구의 🛁💨 는 글꼴에 그림 문자가 없어 "목욕·말리기" 글자로 바꿔 썼습니다 (그림 아이콘을 받으면 교체).
