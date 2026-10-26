# 개발팀 상태

**지금 하는 일**: V3 시제품 1 (손맛) PR (`dev/sim-prototype1`) 검토 대기

**끝낸 일**:
- V3 시제품 1 (손맛, 완료 조건 12개): 목욕대 작업대 시점·회전판, 도구 4개(샤워기·샴푸·수건·드라이어)와 도구 커서, 칠하기 마스크(방향 기반, 256²)·털 셰이더(진흙·젖음·뽀송·남은 곳 반짝임), 물 온도·기분 얼굴 3단계·간지럼·몸 털기, 동전 요금·팁, 컴퓨터 자리 샴푸 가게(기본·복숭아, 분홍 거품·향 팁), 작업자 한 사람만 칠하고 결과만 호스트로. 실행: `docs/dev/PROTOTYPE.md`
- V2 코드(손님 걷기·들기·기계·웅덩이·대시) 삭제. 네트워크·메뉴·테마·수치 리소스·테스트·효과음 도구는 그대로 씀
- 멍냥 목욕탕 첫 시제품 (V2, #24), 협동 멀티플레이 기반 (Net, 오프라인·ENet·Steam, 메뉴, 테스트 체계), 이슈 #10

**자동 테스트**: `GODOT=/path/to/Godot_v4.4.1-stable_linux.x86_64 tests/run_tests.sh`
- 개발팀: `test_offline_session`, `test_seeded_rng`, `test_balance`(TUNING_V3 표를 직접 읽음), `test_paint_mask`, `game/test_wash_flow`, `net/test_enet_two_peers`, `net/test_station_sync`(.roles)

**막힌 것**:
- 스팀 경로 실기 확인 불가 (컨테이너에 스팀 없음, codeberg.org 막힘). SteamMultiplayerPeer 포함 여부 **미확인**.

**다른 부서에 요청**:
- 기획팀: TUNING_V3 에 개발팀 임시 키 8개 반영 부탁 (값·뜻은 `docs/dev/PROTOTYPE.md` 7장): `proto_dose_coverage` 0.25, `proto_cold_cooldown` 2, `proto_eye_cooldown` 1, `proto_tickle_radius` 0.15, `proto_dryer_near` 0.15, `proto_shake_screen_time` 1.5, `proto_peach_request_chance` 0.34, `proto_next_dog_delay` 1. 설명란에 있던 값은 키로 뺀 것뿐입니다.
- 기획팀: 시제품에서 정한 것 확인 부탁 (PROTOTYPE.md 8장) — 카드 다섯 줄(수건·드라이어 따로), 드라이어 거리(보통 0.35 m / Shift 0.1 m), 뽀송 모형 크기는 1.3배까지만(2배는 화면을 덮음), 배 밑은 진행 비율에서 뺌.
- 기획팀(그래픽 요청문 V3): 요청문은 GLB 정면 −Z 인데 게임의 강아지 씬 약속은 얼굴 +Z(카메라 쪽)입니다. GLB 는 그대로 받고 `scenes/art/sim/dog_model.tscn` 안에서 180° 돌려 넣을 테니 요청문은 바꾸지 않아도 됩니다. 강아지 모형이 오면 마우스 판정 모양(`HitBody`)과 얼굴 위치를 개발팀이 맞춥니다.
- QA: V3 로 바뀌며 걷기가 없어져 `tests/net/test_enet_two_peers`·`enet_client_peer` 의 "앞으로 걸어서 위치 동기화" 확인을 "자리(seat) 바꾸기 동기화"로 바꿨습니다 (안 바꾸면 테스트가 깨짐). V2 테스트(`test_bath_flow`, `test_seats_queue`, `test_slip_dash`, `net/test_bath_sync`)는 기능과 함께 지웠습니다. TEST_PLAN 의 V2 항목 정리 부탁합니다.
- QA: 헤드리스에서는 효과음을 실제로 틀지 않고 기록만 합니다 (`sfx.gd`). 더미 오디오 드라이버에서 재생 중에 종료하면 "resources still in use" 오류가 찍혀 실행기가 실패로 봤습니다.
