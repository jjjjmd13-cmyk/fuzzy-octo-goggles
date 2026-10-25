# 협동 멀티플레이 기반 (개발팀)

어떤 장르가 정해져도 쓸 수 있는 기반. 혼자 하기 / 스팀 친구 협동 / 개발용 IP 접속을 같은 코드 경로로 돌린다.

## 폴더

| 경로 | 내용 |
|---|---|
| `project.godot` | 프로젝트 설정, 입력 맵, autoload (`SteamService`, `Net`) |
| `scenes/menu/` | 메인 메뉴 |
| `scenes/game/world.tscn` | 게임 월드 (지면, 스폰 지점, `Players`, `PlayerSpawner`, HUD) |
| `scenes/player/player.tscn` | 플레이어 (충돌, 카메라, 동기화). 겉모습은 없음 |
| `scenes/art/` | **그래픽 교체 지점**. 외부 그래픽은 여기만 바꾼다 |
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

### 등불 원정대(어두운 던전)에서의 조명 비용

빛이 거의 없는 던전에서 플레이어 등불 4개가 주 광원이라 동적 광원이 가장 큰 비용이다.

- Mobile 렌더러는 **메시 하나에 닿는 라이트가 옴니 8개 + 스포트 8개까지**다 (Forward+ 는 클러스터 방식이라 이 제한이 없음).
  등불 4개 + 방의 고정 광원 몇 개는 이 안에 든다. 대신 **바닥·벽을 방 단위 메시로 나눠야** 한 메시에 광원이 몰리지 않는다 (절차 생성 시 방/타일 조각 단위로 만들면 자연히 됨).
- 가장 비싼 건 **옴니 라이트 그림자**(큐브맵)다. 4개 모두 그림자를 켜면 Steam Deck 에서 부담이 크다. 처음 방침:
  자기 등불만 그림자, 다른 플레이어 등불은 그림자 없이 (또는 설정에서 고르게). 그림자 아틀라스는 작게(2048), `distance_fade` 로 먼 광원은 끈다.
- 어둠 연출은 비싼 볼류메트릭 안개 대신 환경 안개 + 낮은 주변광으로 한다. SDFGI/VoxelGI 같은 실시간 GI 는 쓰지 않는다 (Mobile 에서는 지원도 안 됨). 필요하면 LightmapGI(구운 조명)는 정적 방에만.
- **아직 Steam Deck 실측 전**이다. 첫 시제품(어두운 방 + 등불 2~4개)에서 Deck 프레임을 재서 이 방침을 확정한다.

## 네트워크 구조

```
메뉴/게임 코드 ──> Net (autoload, scripts/net/network_manager.gd)
                     │  신호: session_started / session_ended(reason) / player_joined / player_left / status_changed
                     │  multiplayer.multiplayer_peer 에 아래 중 하나를 붙임
                     ├─ OfflineTransport  → OfflineMultiplayerPeer   (혼자 하기)
                     ├─ EnetTransport     → ENetMultiplayerPeer      (개발용 IP 접속)
                     └─ SteamTransport    → SteamMultiplayerPeer     (스팀 로비 + 친구 초대)
월드 ── MultiplayerSpawner(PlayerSpawner) 로 플레이어 스폰/제거 복제
플레이어 ── MultiplayerSynchronizer 로 위치·방향 동기화
```

- 전송 방식은 `MultiplayerPeer` 를 만들어 주는 일만 한다 (`transports/transport.gd` 인터페이스: `open_host()`, `open_client(address)`, `close()`). 새 방식(예: 다른 릴레이)은 이 파일 하나만 추가하면 된다.
- **혼자 하기 = 오프라인 호스트**: `OfflineMultiplayerPeer` 는 항상 서버(ID 1)라서 `multiplayer.is_server()`, RPC, 스포너가 멀티와 똑같이 동작한다. 게임플레이 코드는 "호스트인가" (`Net.is_host()`) 만 보면 된다.
- **권한**: 호스트가 게임 상태의 주인이다. 스폰·제거와 앞으로 넣을 괴물 AI, 공용 자원(등불 기름), 문·함정 상태는 호스트가 결정하고 클라이언트에 알린다 (호스트 권한 Synchronizer 또는 RPC). 클라이언트는 "기름 붓기" 같은 요청만 보낸다. 플레이어 이동만 각자 자기 캐릭터 권한(클라이언트 권한 이동) — 협동 게임이라 치트 방지보다 조작감을 택했다. 게임플레이 코드는 `Net.is_host()` 로 판정 여부를 가른다 (혼자 하기도 호스트).
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

**아직 확인 못 한 것**: 이 클라우드 컨테이너에서는 codeberg.org 와 godotengine.org 접속이 막혀 있어서 받는 스크립트를 실제로 돌려 보지 못했다. 스팀 경로(`SteamTransport`)도 스팀 클라이언트가 없어 실행해 보지 못했다. GodotSteam 버전에 따라 `steamInitEx` 인자나 `SteamMultiplayerPeer` 함수 이름이 다를 수 있어서 기본 인자만 쓰도록 짰다. 스팀이 켜진 PC에서 첫 확인이 필요하다.

## 그래픽 교체 지점

- 플레이어 겉모습: **`scenes/art/player_model.tscn` 하나만** 바꾸면 된다. `player.tscn` 은 이 씬을 `ModelPivot/Model` 로 넣어 쓴다.
- 약속: 루트는 `Node3D`, 발바닥이 원점, 앞이 -Z, 키 약 1.8m. 플레이어 색을 받으려면 루트 스크립트에 `set_player_color(color: Color)` 를 둔다 (지금은 `scripts/player/player_model.gd` 가 `tint_meshes` 에 색을 입힘). 충돌 모양은 `player.tscn` 쪽이라 그래픽과 상관없다.
- 월드의 지면·상자는 아직 임시. 레벨 그래픽이 정해지면 같은 방식(`scenes/art/` 씬)으로 뺀다.

## 조작

| 동작 | 키보드·마우스 | 게임패드 |
|---|---|---|
| 이동 | WASD | 왼쪽 스틱 |
| 카메라 | 마우스 | 오른쪽 스틱 |
| 점프 | Space | A |
| 일시 메뉴(계속/메뉴로 나가기) | Esc | Back/View |

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
| `tests/net/test_enet_two_peers.tscn` | ENet 서버 1 + 클라이언트 1: 스폰 위치, 양방향 이동 동기화, 호스트 퇴장 시 클라이언트 메뉴 복귀 |
| `tests/test_seeded_rng.tscn` | 시드 난수 결정론, 흐름 분리, 고정값 |

네트워크 테스트는 TESTING.md 의 "한 프로세스에 피어 여러 개" 대신 **클라이언트를 별도 Godot 프로세스**(`tests/net/enet_client_peer.tscn`, `OS.create_process`)로 띄운다.
`Net` 은 루트 MultiplayerAPI 와 씬 전환을 그대로 쓰기 때문에, 실제 게임과 같은 경로로 시험하려는 것이다. 클라이언트 출력은 같은 로그에 찍히고, 클라이언트 실패는 `QA_TEST_FAIL` 줄과 종료 코드로 서버 쪽 테스트 실패가 된다. 포트 24611 고정.

## 알려진 한계 / 다음 할 일

- 다른 플레이어 위치는 받은 값을 그대로 쓴다 (보간 없음). 실제 네트워크 지연에서는 끊겨 보일 수 있어 다음 단계에 보간을 넣는다.
- 한글 글꼴을 넣지 않았다. Windows 는 시스템 글꼴(맑은 고딕)로 대체되지만 Steam Deck/Linux 에는 한글 글꼴이 없을 수 있다 → 무료 글꼴(예: Noto Sans KR, OFL) 번들 필요.
- 메뉴 문자열은 아직 한국어 하드코딩. 영어 지원 때 번역 키로 옮긴다.
