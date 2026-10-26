# 협동 멀티플레이 기반 (개발팀)

어떤 장르가 정해져도 쓸 수 있는 기반. 혼자 하기 / 스팀 친구 협동 / 개발용 IP 접속을 같은 코드 경로로 돌린다.

## 폴더

| 경로 | 내용 |
|---|---|
| `project.godot` | 프로젝트 설정, 입력 맵, autoload (`SteamService`, `Net`) |
| `scenes/menu/` | 메인 메뉴 |
| `scenes/game/world.tscn` | 게임 월드 (가게 방, 목욕대 `WashStation`, 컴퓨터, 카메라, `Store`, 스폰 지점, `Players`, `PlayerSpawner`, HUD) |
| `scenes/player/player.tscn` | 플레이어 (V3: 걸어 다니지 않고 자리 `seat` 만 동기화). 겉모습은 `ModelPivot/Model` |
| `scenes/sim/`, `scripts/sim/` | V3 손맛 부품: 목욕대, 칠하기 마스크, 털 셰이더, 가게 돈·샴푸 |
| `scenes/art/` | **그래픽 교체 지점**. 외부 그래픽은 여기만 바꾼다 (아래 표) |
| `data/balance/sim_balance.tres` | **밸런스 수치 한 곳** (TUNING_V3.md 키 이름 그대로) |
| `ui/theme/main_theme.tres` | **글꼴·글자 크기 한 곳** (Pretendard, `assets/fonts/`) |
| `scripts/net/` | 네트워크 계층 (`network_manager.gd`, `steam_service.gd`, `transports/`) |
| `addons/` | 애드온 (GodotSteam 은 받는 스크립트로) |
| `scripts/core/` | 공용 유틸 (시드 난수) |
| `tests/` | 헤드리스 자동 테스트 (규칙은 QA 의 `docs/qa/TESTING.md`) |
| `tools/` | 보조 스크립트 |

## 렌더러: Mobile (+ OpenGL 대체)

`rendering/renderer/rendering_method="mobile"`, `rendering_device/fallback_to_opengl3=true`.

- **Forward+ 를 안 쓴 이유**: 클러스터 라이팅·SDFGI·볼류메트릭 안개처럼 무거운 기능 위주라 Steam Deck(800p, 15W APU)·저사양 노트북에서 프레임이 떨어진다. 임시 모형 + 외부 그래픽으로 가는 게임이라 그 기능이 필요할 일이 적다.
- **Mobile**: Vulkan 기반이라 Steam Deck(Linux/Proton 모두)에서 잘 돌고, 그림자·PBR 머티리얼·후처리(톤매핑, 글로우)는 그대로 쓸 수 있다. 오브젝트당 라이트 수 제한이 있지만 협동 게임 규모에서는 충분하다.
- **Compatibility(OpenGL 3) 를 기본으로 안 한 이유**: 3D 기능이 가장 적다. 대신 Vulkan 이 안 되는 오래된 PC를 위해 OpenGL 대체를 켜 두었다.
- 나중에 그래픽 방향상 Forward+ 가 꼭 필요하면 설정 한 줄만 바꾸면 된다 (씬·코드는 그대로).


## 네트워크 구조

```
메뉴/게임 코드 ──> Net (autoload, scripts/net/network_manager.gd)
                     │  신호: session_started / session_ended(reason) / player_joined / player_left / status_changed
                     │  multiplayer.multiplayer_peer 에 아래 중 하나를 붙임
                     ├─ OfflineTransport  → OfflineMultiplayerPeer   (혼자 하기)
                     ├─ EnetTransport     → ENetMultiplayerPeer      (개발용 IP 접속)
                     └─ SteamTransport    → SteamMultiplayerPeer     (스팀 로비 + 친구 초대)
월드 ── MultiplayerSpawner(PlayerSpawner) 로 플레이어 스폰/제거 복제
플레이어 ── MultiplayerSynchronizer 로 자리(seat) 동기화 (조종하는 피어 권한)
목욕대·가게 ── 호스트 권한 MultiplayerSynchronizer (StationSync, StoreSync) + 요청 RPC
```

- 전송 방식은 `MultiplayerPeer` 를 만들어 주는 일만 한다 (`transports/transport.gd` 인터페이스: `open_host()`, `open_client(address)`, `close()`). 새 방식(예: 다른 릴레이)은 이 파일 하나만 추가하면 된다.
- **혼자 하기 = 오프라인 호스트**: `OfflineMultiplayerPeer` 는 항상 서버(ID 1)라서 `multiplayer.is_server()`, RPC, 스포너가 멀티와 똑같이 동작한다. 게임플레이 코드는 "호스트인가" (`Net.is_host()`) 만 보면 된다.
- **권한**: 호스트가 게임 상태의 주인이다. 스폰·제거, 손님·단계·기분·돈·샴푸는 호스트가 결정하고 클라이언트에 알린다 (호스트 권한 Synchronizer 또는 RPC). 클라이언트는 "샴푸를 사고 싶다", "동전을 줍겠다" 같은 요청만 보낸다. 예외 둘: 자기 자리(seat)는 각자 자기 캐릭터 권한이고, 목욕대 **붓질은 작업자 한 사람 화면에서만** 하고 결과(진행 비율·기분 변화·사건)만 호스트에 보낸다 (아래 "목욕대"). 협동 게임이라 치트 방지보다 조작감을 택했다. 게임플레이 코드는 `Net.is_host()` 로 판정 여부를 가른다 (혼자 하기도 호스트).
- **시드 난수** (`scripts/core/seeded_rng.gd`): 호스트가 `new_session_seed()` 로 시드를 정해 클라이언트에 보내면, 모든 피어가 `make(seed, "dungeon")` 처럼 흐름 이름별 RNG 로 같은 던전을 만든다. 결정론이 필요한 곳에서 전역 `randi()` 금지. 시드를 세션에 실어 보내는 부분은 첫 시제품에서 넣는다.
- **스폰**: `PlayerSpawner.spawn_function` 에 스폰 데이터 `{peer_id, slot, position}` 를 넘긴다. 캐릭터 권한이 클라이언트에 있으면 Synchronizer 의 "spawn" 속성을 서버가 보내지 않아서(실제로 클라이언트 쪽 내 캐릭터가 원점에 생기는 문제를 테스트에서 확인), 시작 상태는 스폰 데이터로 보낸다.
- **순서**: 클라이언트는 월드 씬을 먼저 띄운 뒤 접속한다 (서버가 보내는 스폰을 받을 스포너가 있어야 함). 그래서 `Net` 이 `change_scene_to_file`(한 프레임 늦음) 대신 직접 씬을 바꾼다.
- **접속·퇴장**: 클라이언트가 나가면 호스트가 그 캐릭터를 지운다. 호스트가 나가거나 연결이 끊기면 클라이언트는 이유와 함께 메뉴로 돌아간다. 접속 시간 초과 10초.
- 최대 4명 (`Net.MAX_PLAYERS`).

## 스팀 (GodotSteam)

- `SteamService` 가 시작할 때 `Engine.has_singleton("Steam")` 로 애드온을 확인하고 `steamInitEx()` 로 초기화한다. 앱 ID 는 480 (환경 변수 `SteamAppId`, 스팀에서 실행하면 스팀 값 우선).
- 애드온이 없거나, 스팀이 꺼져 있거나, 초기화에 실패하면 `SteamService.available = false` 이고 메뉴의 "친구와 하기"만 꺼진다. 게임 코드는 `Steam` 이름을 직접 쓰지 않는다 (애드온이 없으면 GDScript 파싱 오류가 나기 때문). `--no-steam` 실행 옵션으로 강제로 끌 수 있다.
- 호스트: 친구 공개 로비 생성 → `SteamMultiplayerPeer.create_host(0)` → 게임 안 "친구 초대" 버튼이 스팀 오버레이 초대 창을 연다.
- 참가: 스팀 초대 수락(`join_requested`) 또는 실행 인자 `+connect_lobby <로비ID>` → 로비 참가 → 로비 주인에게 `create_client(owner, 0)`.

### 애드온 바이너리는 저장소에 넣지 않고 받는 스크립트로 둔다

`tools/fetch_godotsteam.sh` (Codeberg 릴리스에서 Godot 4.4 용 GDExtension zip 을 골라 `addons/godotsteam/` 에 푼다).

- 바이너리(Windows/Linux/macOS 용 라이브러리 + Steamworks 재배포 파일)가 수십 MB 라 git 기록이 계속 무거워진다. 버전을 바꿀 때마다 쌓인다.
- 게임은 애드온 없이도 돌도록 만들었으므로, 대부분의 작업(기획 확인, QA 의 헤드리스 테스트, CI)에는 애드온이 필요 없다.
- 버전은 스크립트의 `GODOTSTEAM_TAG` / `GODOTSTEAM_URL` 로 고정할 수 있다. 첫 실제 스팀 테스트 때 쓴 태그를 이 문서에 적어 고정할 것.
- 출시 빌드(내보내기)를 만드는 사람/CI 만 받으면 된다.

**SteamMultiplayerPeer 포함 여부: 미확인.** GodotSteam GDExtension 배포판에 따라 `SteamMultiplayerPeer` 가 빠져 있을 수 있다 (대표 전달). 코드는 `ClassDB.class_exists("SteamMultiplayerPeer")` 로 검사해서, 없으면 "이 GodotSteam 빌드에는 SteamMultiplayerPeer 가 없습니다" 로 실패하고 메뉴로 돌아간다. `tools/fetch_godotsteam.sh` 가 받은 뒤 바이너리 안에 이 클래스 이름이 있는지 검사해서 결과를 출력한다. 없으면 MultiplayerPeer 가 포함된 GodotSteam 빌드를 찾거나, Steam 네트워킹을 직접 감싼 전송 방식을 개발팀이 만든다 (그때 대표와 상의).

**아직 확인 못 한 것**: 이 클라우드 컨테이너에서는 codeberg.org 와 godotengine.org 접속이 막혀 있어서 받는 스크립트를 실제로 돌려 보지 못했다. 스팀 경로(`SteamTransport`)도 스팀 클라이언트가 없어 실행해 보지 못했다. GodotSteam 버전에 따라 `steamInitEx` 인자나 `SteamMultiplayerPeer` 함수 이름이 다를 수 있어서 기본 인자만 쓰도록 짰다. 스팀이 켜진 PC에서 첫 확인이 필요하다.

## 그래픽 교체 지점

외부 그래픽은 아래 씬만 바꾸면 된다. 충돌·판정은 전부 게임 씬 쪽이라 그래픽과 상관없다.
공통 약속: 루트는 `Node3D`, 바닥이 원점, 앞이 -Z.

| 씬 | 무엇 | 약속 |
|---|---|---|
| `scenes/art/player_model.tscn` | 동료 몸 (내 화면에서는 숨김) | 키 약 1.8 m. 색을 받으려면 루트에 `set_player_color(color)` |
| `scenes/art/sim/dog_model.tscn` | 목욕대 강아지 | **얼굴이 +Z(카메라 쪽)**, 바닥이 원점. ChatGPT GLB(정면 −Z)는 이 씬 안에서 Y 로 180° 돌려 넣는다. 루트 스크립트 `sim_dog_model.gd` 의 `body_center`·`face_center`·`fur_meshes` 를 맞추고, 마우스 판정 모양 `HitBody`(충돌 층 16)를 모형에 맞게 고친다. UV 는 상관없음 (마스크가 방향으로 칠함) |
| `scripts/sim/sim_fur.gdshader` | 털 (더러움·젖음·뽀송) | 텍스처를 쓰려면 `fur_color` 대신 albedo 텍스처 uniform 을 추가 |
| `scenes/sim/wash_station.tscn` | 목욕대·회전판·도구걸이 (임시 상자) | 회전판은 `Turntable` 노드, 강아지는 `Turntable/Dog` |
| `assets/sfx/*.wav` | 효과음 11개 + 반복 소리 3개 (`scripts/game/sfx.gd`) | 같은 파일 이름으로 교체 |
| `scenes/art/tiles/floor_tile.tscn` | 바닥 타일 2×2 m | 윗면이 y=0 |
| `scenes/art/tiles/wall_tile.tscn` | 벽 타일 2×2 m, 두께 0.3 m | 아랫변 가운데가 원점, 두께 방향이 +Z(방 안쪽). 2단으로 쌓아 4 m |
| `scenes/art/tiles/ceiling_tile.tscn` | 천장 타일 2×2 m | 아랫면이 y=0 (4 m 높이에 놓임) |

방은 `scripts/level/room_builder.gd` 가 타일을 늘어놓아 만든다 (크기·문 방향만 지정).

## 조작

V3 작업대 시점: 걸어 다니지 않고 자리(목욕대·컴퓨터)에 앉아 마우스로 일한다. 카메라는 월드의 `Camera` 하나이고, 자리를 바꾸면 그 자리 `CameraPoint` 로 `seat_switch_time` 동안 옮겨 간다.
마우스 입력은 `world.gd` 가 받아 `WashStation.operate(커서, 누름, 막 누름, delta)` 를 부른다 (패드는 왼쪽 스틱이 커서를 움직임).

조작표는 [PROTOTYPE.md](PROTOTYPE.md) 2장.

## 목욕대 (`WashStation`, V3 시제품 1)

- `scripts/sim/paint_mask.gd`: 몸 칠하기 마스크. 모형 UV 대신 **몸 중심에서 본 방향(위경도)** 을 좌표로 쓴다 (256×256). 채널 wet/scrub/rinse/towel/dry, 칠하는 순간 넓이 가중 비율을 같이 갱신 (붓 한 번 약 60~90 µs). 배 밑(방향 y < −0.6)은 작업대에서 손이 안 닿아 비율 계산에서 뺀다.
- `scripts/sim/wash_dog.gd`: 회전판 위 강아지 (마스크·털 셰이더·거품 공 MultiMesh·뽀송 부풀기·물방울). 마우스 → 카메라 광선 → `HitBody` → 모형 기준 좌표 → 마스크.
- `scripts/sim/wash_station.gd`: 단계(적시기→거품→헹구기→수건→드라이어→계산), 도구 4개, 물 온도, 기분, 간지럼·몸 털기, 동전.
  - **작업자** = 목욕대 자리에 먼저 앉은 사람 (호스트가 `operator` 로 정함). 작업자만 마스크를 칠하고 0.1초마다 `_report_progress(단계, 비율, 기분 변화)` 를, 사건(차가운 물·눈·간지럼·몸 털기·볼)은 `_report_event` 를 호스트에 보낸다.
  - 호스트가 비율이 `stage_complete_ratio` 를 넘으면 단계를 넘기고, 다 끝나면 동전(요금·기분 팁·향 팁)을 놓는다. 동전 줍기·샴푸 짜기(병에서 한 마리분 쓰기)는 요청 RPC.
  - 구경하는 사람 화면은 마스크 대신 단계별 비율을 셰이더 `global_mask` 로 받는다. 작업자가 바뀌면 새 작업자가 지금까지의 비율로 마스크를 채우고 이어서 칠한다.
- `scripts/sim/store.gd`: 돈, 기본·복숭아 샴푸 남은 마리 수, 지금 쓰는 샴푸 (호스트 권한, `send_buy`/`send_select` 요청).
- 화면: `scripts/game/hud.gd` (요청 카드 ✓, 도구 막대, 돈, 컴퓨터 가게 창), `scripts/game/hud_overlay.gd` (도구 커서, 기분 얼굴, 온도 다이얼, 화면 거품).
- 수치는 `data/balance/sim_balance.tres` (TUNING_V3).

## 같은 PC에서 창 두 개로 테스트

```bash
godot --path . -- --host            # 창 1: ENet 호스트 (포트 24565)
godot --path . -- --join=127.0.0.1  # 창 2: 접속
# --port=N 으로 포트 변경, --solo 로 바로 혼자 하기
```
메뉴의 "개발용: IP로 접속" 칸으로도 같은 일을 할 수 있다.

## 자동 테스트

`tests/run_tests.sh` (QA 실행기) 가 `tests/**/test_*.tscn` 을 하나씩 돌린다.

| 테스트 | 확인하는 것 |
|---|---|
| `tests/test_offline_session.tscn` | 혼자 하기 → 월드·플레이어 1 생성, 나가기 → 메뉴 |
| `tests/net/test_enet_two_peers.tscn` | ENet 서버 1 + 클라이언트 1: 스폰 위치, 양방향 자리(seat) 동기화, 호스트 퇴장 시 클라이언트 메뉴 복귀 |
| `tests/test_seeded_rng.tscn` | 시드 난수 결정론, 흐름 분리, 고정값 |
| `tests/test_balance.tscn` | sim_balance.tres 가 TUNING_V3.md 의 ✅ 줄과 같음 (표를 직접 읽음) |
| `tests/test_paint_mask.tscn` | 칠하기 마스크: 붓 넓이·넘치지 않음·극·90% 채우기·텍스처·더러움 무늬 3종·속도 |
| `tests/game/test_wash_flow.tscn` | 혼자: 화면 좌표로 실제 칠하기 → 5단계 → 동전 → 컴퓨터 자리에서 복숭아 샴푸 → 분홍 거품·향 팁 → 샴푸가 떨어지면 거품 없음. 차가운 물·간지럼·몸 털기·소리 |
| `tests/net/test_station_sync.tscn` | 2인(.roles): 작업자만 칠함, 구경 쪽은 비율만, 클라이언트 샴푸 구매, 작업자 바뀜 → 이어서 칠하기 |

네트워크 테스트는 TESTING.md 의 "한 프로세스에 피어 여러 개" 대신 **클라이언트를 별도 Godot 프로세스**(`tests/net/enet_client_peer.tscn`, `OS.create_process`)로 띄운다.
`Net` 은 루트 MultiplayerAPI 와 씬 전환을 그대로 쓰기 때문에, 실제 게임과 같은 경로로 시험하려는 것이다. 클라이언트 출력은 같은 로그에 찍히고, 클라이언트 실패는 `QA_TEST_FAIL` 줄과 종료 코드로 서버 쪽 테스트 실패가 된다. 포트는 테스트마다 다름 (24611, 24612).

## 알려진 한계 / 다음 할 일

- 다른 플레이어 위치는 받은 값 쪽으로 부드럽게 따라가는 단순 보간만 한다 (지연 보정 없음).
- 글꼴은 Pretendard 원본(OFL)만 넣었다. FONT.md 의 Noto Sans CJK 대체 글꼴은 아직 없다 (파일이 커서 스팀 닉네임을 표시할 때 같이 넣음).
- 메뉴 문자열은 아직 한국어 하드코딩. 영어 지원 때 번역 키로 옮긴다.
