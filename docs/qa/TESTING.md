# 테스트 실행 규칙

CI(`.github/workflows/ci.yml`)와 로컬 모두 `tests/run_tests.sh` 하나로 테스트를 돌린다.
Godot 버전은 **4.4.1** (CLAUDE.md 고정).

## CI 가 하는 일

PR 과 `main` 푸시마다:

1. Godot 4.4.1 헤드리스를 받는다 (`~/godot` 캐시).
2. `tests/selftest.sh` — 테스트 실행기 자체 검사 (아래 "실행기 자체 검사").
3. `tests/run_tests.sh` — 실제 프로젝트 검사:
   - 저장소 루트에 `project.godot` 이 **없으면** `프로젝트 없음` 을 찍고 통과(건너뜀).
   - `godot --headless --path . --import` 로 임포트. 종료 코드가 0이 아니거나 출력에 오류가 있으면 실패.
   - `tests/` 아래 테스트 씬을 하나씩 실행. 하나라도 실패하면 CI 실패.
   - 테스트 씬이 하나도 없으면 임포트 검사만 하고 통과.

## 테스트 씬 규칙

| 항목 | 규칙 |
|---|---|
| 위치·이름 | `tests/` 아래 아무 깊이, 파일 이름 `test_*.tscn` (예: `tests/net/test_enet_two_peers.tscn`) |
| 실행 방법 | 씬 하나당 Godot 프로세스 하나: `godot --headless --path . res://tests/…/test_x.tscn` |
| 성공 조건 | **아래 셋 모두** ① 종료 코드 0 ② 출력에 `QA_TEST_PASS` 만 있는 줄이 있음 ③ 출력에 오류 없음 |
| 실패 표시 | 실패 이유를 `QA_TEST_FAIL: <이유>` 로 출력하고 종료 코드 1 (`get_tree().quit(1)`) |
| 시간 제한 | 씬 하나 120초 (`QA_TEST_TIMEOUT` 로 바꿈). 넘으면 실패 |
| 제외 | `.gdignore` 파일이 있는 폴더 안의 씬은 실행하지 않는다 (Godot도 무시하는 폴더) |
| 여러 프로세스 | 씬 옆에 같은 이름의 `.roles` 파일이 있으면 역할마다 프로세스를 하나씩 띄운다 (아래 "여러 프로세스 테스트") |

"출력에 오류"는 다음 중 하나가 있는 줄이다: `SCRIPT ERROR`, `Parse Error`, `Failed to load script`, 줄 맨 앞의 `ERROR:`.
Godot는 실행 중 스크립트 오류가 나도 종료 코드를 바꾸지 않기 때문에 출력도 같이 본다.
`push_error()` 도 `ERROR:` 를 찍으므로, 게임 코드가 `push_error()` 를 부르는 경로를 시험하면 그 테스트는 실패로 잡힌다.
그런 테스트가 필요하면 QA 에 이슈로 알려 달라 (예외 규칙을 따로 만든다).

## 테스트 쓰는 법 (`tests/qa_test.gd`)

테스트 씬의 루트 노드 스크립트가 `res://tests/qa_test.gd` 를 상속하고 `run_test()` 를 덮어쓴다.
`run_test()` 가 끝나면 자동으로 결과를 찍고 종료한다. `await` 를 써도 된다.

```gdscript
extends "res://tests/qa_test.gd"


func run_test() -> void:
	var player := preload("res://scenes/player/player.tscn").instantiate()
	add_child(player)
	await get_tree().physics_frame
	check(player.is_inside_tree(), "플레이어가 트리에 들어감")
	check_eq(player.health, 100, "시작 체력")
```

| 함수 | 뜻 |
|---|---|
| `check(조건, 메시지)` | 조건이 거짓이면 실패로 기록 (테스트는 계속 진행) |
| `check_eq(실제, 기대, 메시지)` | 같지 않으면 실패로 기록 |
| `fail(메시지)` | 무조건 실패로 기록 |
| `finish()` | 바로 끝내기 (보통은 부를 필요 없음) |
| `time_limit_sec` | 테스트 안쪽 시간 제한 (기본 30초). 넘으면 실패로 끝남 |

`qa_test.gd` 를 쓰지 않아도 위 "성공 조건"만 지키면 된다.

### 여러 프로세스 테스트 (호스트 + 클라이언트)

게임의 `Net` 은 autoload 하나라 한 프로세스에 피어 하나다. 그래서 협동 테스트는 역할마다 Godot 프로세스를 따로 띄운다.

1. 테스트 씬 옆에 같은 이름의 `.roles` 파일을 둔다. 한 줄에 역할 하나, **첫 줄이 호스트**. `#` 로 시작하는 줄은 설명.
   ```
   # tests/test_net_sync.roles
   server
   client
   ```
   3인이면 `client` 를 두 줄 쓴다 (같은 이름 여러 번 가능).
2. 실행기가 역할마다 `godot --headless --path . res://tests/test_net_sync.tscn -- --role=<역할> --port=<포트>` 를 띄운다.
   포트는 테스트마다 다르다 (`24600` 부터 10씩).
3. 첫 역할(호스트)이 접속을 받을 준비가 되면 `QA_TEST_READY` 한 줄을 찍는다 (`qa_test.gd` 의 `report_ready()`).
   실행기는 이걸 본 뒤에 나머지 역할을 한꺼번에 띄운다. 30초 안에 안 나오면 실패.
4. **모든 프로세스가 각각** 성공 조건(종료 코드 0, `QA_TEST_PASS`, 오류 없음)을 지켜야 테스트 통과.

`qa_test.gd` 를 상속하면 `role`, `port` 변수에 인수가 들어 있다.

```gdscript
extends "res://tests/qa_test.gd"


func run_test() -> void:
	if role == "server":
		Net.host_enet(port)
		await Net.session_started
		report_ready()
		var client_id: int = await Net.player_joined
		# ... 확인 ...
	else:
		Net.join_enet("127.0.0.1", port)
		await Net.session_started
		# ... 확인 ...
```

주의: 클라이언트가 확인을 끝내자마자 종료하면, 호스트가 접속을 다 처리하기 전에 끊겨 `peer_connected` 를 못 받을 수 있다.
클라이언트는 호스트가 끊을 때까지(`server_disconnected` / `Net.session_ended`) 기다렸다가 끝내는 게 안전하다.

### 협동(네트워크) 테스트 일반

- 포트는 실행기가 주는 `port` 를 쓴다 (고정 포트 금지, CI 에서 겹칠 수 있음). 연결 대기는 시그널 `await` + `time_limit_sec` 로 막는다.
- Steam(GodotSteam)은 CI 에 Steam 클라이언트가 없어 자동 테스트가 안 된다. 스팀 흐름은 `TEST_PLAN.md` 수동 체크리스트로 한다.

## 누가 쓰나

- QA 가 `tests/` 를 관리한다. 개발팀도 자기 기능 PR 에 테스트 씬을 같이 넣어도 된다 (위 규칙을 따를 것).
- 테스트가 쓰는 게임 쪽 기능(명령줄 인수, 디버그 훅 등)이 필요하면 QA 가 개발팀에 이슈로 요청한다.

## 로컬에서 돌리기

```bash
# Godot 설치는 CLAUDE.md 참고
export GODOT=/tmp/godot/Godot_v4.4.1-stable_linux.x86_64
tests/run_tests.sh          # 저장소 루트 프로젝트
tests/selftest.sh           # 실행기 자체 검사 (약 30초)
```

## 실행기 자체 검사

`tests/selftest/` 에 아주 작은 Godot 프로젝트 두 개가 있다 (`.gdignore` 로 본 프로젝트에서는 무시됨).
`tests/selftest.sh` 가 이걸 임시 폴더에 복사해서 다음을 확인한다. 실행기를 고치면 이것도 통과해야 한다.

- `pass/`: 통과해야 함 (한 프로세스 테스트, 여러 프로세스 테스트 ENet 호스트 + 손님)
- `fail/`: 정확히 5개 실패로 잡혀야 함 — check 실패, 스크립트 오류, 성공 문자열 없음, 시간 초과, 호스트가 `QA_TEST_READY` 를 안 찍음
- 문법 오류가 있는 프로젝트는 임포트 단계에서 실패
- `project.godot` 없는 폴더는 건너뜀
