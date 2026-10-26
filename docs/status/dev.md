# 개발팀 상태

**지금 하는 일**: 임시 강아지 그래픽 개선 PR (`dev/dog-placeholder`) 검토 대기. 다음: 기획팀 손동작·조작 단순화 목표가 오면 다음 PR

**끝낸 일**:
- 임시 강아지를 상자에서 "장난감 강아지"로 (사람 대표 플레이 "몰입 안 됨"): 구·캡슐로 앉은 강아지(주둥이·코·만화 눈·늘어진 귀·관절 다리·세 마디 꼬리), 숨쉬기·깜빡임, 기분에 따라 눈·귀·혀·꼬리, 커서를 따라보는 머리, 샤워기가 얼굴로 오면 고개를 돌리고 눈을 감음, 털결·테두리 셰이더, 하늘색 둥근 통·노란 타일 벽·창문, 물보라. 스크린샷 `docs/dev/screenshots/toy_dog_*.jpg`
- V3 시제품 1 (손맛, 완료 조건 12개): 목욕대 작업대 시점·회전판, 도구 4개(샤워기·샴푸·수건·드라이어)와 도구 커서, 칠하기 마스크(방향 기반, 256²)·털 셰이더(진흙·젖음·뽀송·남은 곳 반짝임), 물 온도·기분 얼굴 3단계·간지럼·몸 털기, 동전 요금·팁, 컴퓨터 자리 샴푸 가게(기본·복숭아, 분홍 거품·향 팁), 작업자 한 사람만 칠하고 결과만 호스트로. 실행: `docs/dev/PROTOTYPE.md`
- #29 QA·대표 측정 반영: 붓 키움(샤워기 0.12→0.18 m, 손 0.10→0.15 m)·완료 0.9→0.85 (사람 흉내 손 기준 단계 9~19초, 한 마리 약 65초), 임시 강아지 눈이 머리 속에 묻혀 있던 것·볼 크기 버그 고침, 눈에 물 경고 띠·쿨타임 3초, 남은 곳 반짝 1.5초마다, 젖음 색 진하게, 수건 단계 물방울, 마우스 판정 모양을 털 메시에서 자동으로 만듦
- V2 코드(손님 걷기·들기·기계·웅덩이·대시) 삭제. 네트워크·메뉴·테마·수치 리소스·테스트·효과음 도구는 그대로 씀
- 멍냥 목욕탕 첫 시제품 (V2, #24), 협동 멀티플레이 기반 (Net, 오프라인·ENet·Steam, 메뉴, 테스트 체계), 이슈 #10

**자동 테스트**: `GODOT=/path/to/Godot_v4.4.1-stable_linux.x86_64 tests/run_tests.sh`
- 개발팀: `test_offline_session`, `test_seeded_rng`, `test_balance`(TUNING_V3 표를 직접 읽음), `test_paint_mask`, `game/test_wash_flow`, `game/test_wash_pace`(사람 흉내 손으로 단계 시간), `net/test_enet_two_peers`, `net/test_station_sync`(.roles)

**막힌 것**:
- 스팀 경로 실기 확인 불가 (컨테이너에 스팀 없음, codeberg.org 막힘). SteamMultiplayerPeer 포함 여부 **미확인**.

**다른 부서에 요청**:
- 기획팀: 대표 요청으로 TUNING_V3 의 `stage_complete_ratio` 0.85, `tool_shower_radius` 0.18, `tool_scrub_radius` 0.15, 7장 `proto_eye_cooldown` 3.0 과 새 키 `proto_blink_interval` 1.5·`proto_water_drops` 70 을 이 PR 에서 직접 고쳤습니다 (#30 과 병합하며 바꾼 기록 줄 추가). 확인만 부탁합니다.
- 기획팀(그래픽 요청문 V3): 강아지 GLB 는 정면 −Z 로 받아 `scenes/art/sim/dog_model.tscn` 안에서 180° 돌려 넣습니다 (#29 에서 동의). 마우스 판정 모양은 털 메시에서 자동으로 만들고, 얼굴 위치(`face_center`)는 개발팀이 맞춥니다.
- QA: V3 로 바뀌며 걷기가 없어져 `tests/net/test_enet_two_peers`·`enet_client_peer` 의 "앞으로 걸어서 위치 동기화" 확인을 "자리(seat) 바꾸기 동기화"로 바꿨습니다 (안 바꾸면 테스트가 깨짐). V2 테스트(`test_bath_flow`, `test_seats_queue`, `test_slip_dash`, `net/test_bath_sync`)는 기능과 함께 지웠습니다. TEST_PLAN 의 V2 항목 정리 부탁합니다.
- QA: 헤드리스에서는 효과음을 실제로 틀지 않고 기록만 합니다 (`sfx.gd`). 더미 오디오 드라이버에서 재생 중에 종료하면 "resources still in use" 오류가 찍혀 실행기가 실패로 봤습니다.
