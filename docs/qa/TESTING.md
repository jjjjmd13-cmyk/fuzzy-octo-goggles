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

### 협동(네트워크) 테스트

- 한 프로세스 안에서 여러 피어를 만든다: 노드 서브트리마다 `get_tree().set_multiplayer(SceneMultiplayer.new(), 경로)` 로
  다른 `MultiplayerAPI` 를 주고, 하나는 ENet 서버(`127.0.0.1`), 나머지는 클라이언트로 붙인다.
- 포트는 테스트마다 다르게 (CI에서 동시에 돌 수 있음). 연결 대기는 시그널 `await` + `time_limit_sec` 로 막는다.
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

- `pass/`: 통과해야 함
- `fail/`: 정확히 4개 실패로 잡혀야 함 — check 실패, 스크립트 오류, 성공 문자열 없음, 시간 초과
- 문법 오류가 있는 프로젝트는 임포트 단계에서 실패
- `project.godot` 없는 폴더는 건너뜀
