#!/usr/bin/env bash
# Godot 헤드리스로 프로젝트를 임포트하고 tests/ 아래 테스트 씬을 모두 실행한다.
# 규칙: docs/qa/TESTING.md
#
# 사용법: tests/run_tests.sh [프로젝트 폴더]   (기본: 저장소 루트)
# 환경 변수:
#   GODOT              Godot 실행 파일 (기본: godot)
#   QA_TEST_TIMEOUT    테스트 씬 하나의 최대 실행 시간(초) (기본: 120)
#   QA_IMPORT_TIMEOUT  임포트 최대 시간(초) (기본: 600)
#   QA_READY_TIMEOUT   여러 프로세스 테스트에서 첫 역할의 준비 대기(초) (기본: 30)
#   QA_TEST_PORT_BASE  여러 프로세스 테스트에 줄 첫 포트 (기본: 25000, 테스트마다 +10)
#   QA_LOG_DIR         로그를 남길 폴더 (기본: 임시 폴더)
set -uo pipefail

PROJECT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
GODOT="${GODOT:-godot}"
TEST_TIMEOUT="${QA_TEST_TIMEOUT:-120}"
IMPORT_TIMEOUT="${QA_IMPORT_TIMEOUT:-600}"
READY_TIMEOUT="${QA_READY_TIMEOUT:-30}"
PORT_BASE="${QA_TEST_PORT_BASE:-25000}"
PASS_MARK="QA_TEST_PASS"
READY_MARK="QA_TEST_READY"
# 이 패턴이 출력에 있으면 종료 코드와 상관없이 실패로 본다.
ERROR_PATTERN='SCRIPT ERROR|Parse Error|Failed to load script|^ERROR:'

if [ ! -f "$PROJECT/project.godot" ]; then
  echo "프로젝트 없음: $PROJECT/project.godot 이 없어 건너뜀"
  exit 0
fi

LOG_DIR="${QA_LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"

echo "== 임포트: $PROJECT"
timeout "$IMPORT_TIMEOUT" "$GODOT" --headless --path "$PROJECT" --import >"$LOG_DIR/import.log" 2>&1
code=$?
# Godot 4.4.1 upstream #108994: saving GLTF succeeds, only its headless editor thumbnail fails.
# Retain raw output and ignore only that exact, version-guarded two-line block.
if [ "$code" -eq 0 ] && [ -f "$PROJECT/tools/filter_godot_441_import.py" ] && grep -Fq 'servers/rendering/dummy/storage/texture_storage.h:107' "$LOG_DIR/import.log"; then
  python3 "$PROJECT/tools/filter_godot_441_import.py" "$LOG_DIR/import.log" "$("$GODOT" --version)"
fi
cat "$LOG_DIR/import.log"
if [ "$code" -ne 0 ]; then
  echo "::error::임포트 실패 (종료 코드 $code)"
  exit 1
fi
if grep -Eq "$ERROR_PATTERN" "$LOG_DIR/import.log"; then
  echo "::error::임포트 중 오류 출력:"
  grep -E "$ERROR_PATTERN" "$LOG_DIR/import.log"
  exit 1
fi

# tests/ 아래 test_*.tscn. .gdignore 가 있는 폴더(Godot도 무시하는 곳)는 뺀다.
TESTS=()
while IFS= read -r f; do
  d="$(dirname "$f")"
  skip=0
  while [ "$d" != "." ]; do
    if [ -e "$PROJECT/$d/.gdignore" ]; then skip=1; break; fi
    d="$(dirname "$d")"
  done
  [ "$skip" -eq 0 ] && TESTS+=("$f")
done < <(cd "$PROJECT" && find tests -type f -name 'test_*.tscn' 2>/dev/null | sort)

if [ "${#TESTS[@]}" -eq 0 ]; then
  echo "테스트 씬 없음: tests/**/test_*.tscn 이 없어 임포트 검사만 함"
  exit 0
fi

# 로그 하나를 규칙대로 판정해 실패 이유를 찍는다 (통과면 아무것도 안 찍음).
judge() {
  local log="$1" code="$2"
  if [ "$code" -eq 124 ]; then
    echo "시간 초과 (${TEST_TIMEOUT}초)"
  elif [ "$code" -ne 0 ]; then
    echo "종료 코드 $code"
  elif grep -Eq "$ERROR_PATTERN" "$log"; then
    echo "오류 출력 있음"
  elif ! grep -qx "$PASS_MARK" "$log"; then
    echo "성공 문자열 $PASS_MARK 없음"
  fi
}

# 여러 프로세스 테스트: 첫 역할이 준비 문자열을 찍을 때까지 기다린다.
wait_ready() { # 로그, pid
  local i
  for ((i = 0; i < READY_TIMEOUT * 10; i++)); do
    grep -qx "$READY_MARK" "$1" 2>/dev/null && return 0
    kill -0 "$2" 2>/dev/null || return 1
    sleep 0.1
  done
  return 1
}

passed=0
failed=()
port="$PORT_BASE"
for t in "${TESTS[@]}"; do
  base="$LOG_DIR/$(echo "$t" | tr '/' '_')"
  roles_file="$PROJECT/${t%.tscn}.roles"
  echo "== 실행: $t"
  reason=""
  logs=()
  if [ ! -f "$roles_file" ]; then
    timeout "$TEST_TIMEOUT" "$GODOT" --headless --path "$PROJECT" "res://$t" >"$base.log" 2>&1
    reason="$(judge "$base.log" $?)"
    logs=("$base.log")
  else
    mapfile -t roles < <(grep -Ev '^[[:space:]]*(#|$)' "$roles_file" | sed 's/[[:space:]]//g')
    echo "   역할: ${roles[*]} (포트 $port)"
    pids=()
    for i in "${!roles[@]}"; do
      # 같은 역할이 여럿(client 2개 등)이어도 로그 파일이 겹치지 않게 순번을 넣는다.
      # (겹치면 두 프로세스가 한 파일에 동시에 써서 QA_TEST_PASS 줄이 다른 줄에 붙어 버림)
      log="$base.$i.${roles[$i]}.log"
      logs+=("$log")
      # 함수가 아니라 timeout 을 바로 띄워야 kill 이 Godot 까지 전달된다.
      timeout "$TEST_TIMEOUT" "$GODOT" --headless --path "$PROJECT" "res://$t" \
        -- "--role=${roles[$i]}" "--port=$port" >"$log" 2>&1 &
      pids+=($!)
      if [ "$i" -eq 0 ] && [ "${#roles[@]}" -gt 1 ] && ! wait_ready "$log" "${pids[0]}"; then
        reason="${roles[0]}: 준비 문자열 $READY_MARK 없음 (${READY_TIMEOUT}초)"
        kill "${pids[0]}" 2>/dev/null
        break
      fi
    done
    for i in "${!pids[@]}"; do
      wait "${pids[$i]}"
      code=$?
      r="$(judge "${logs[$i]}" "$code")"
      [ -n "$r" ] && [ -z "$reason" ] && reason="${roles[$i]}: $r"
    done
    port=$((port + 10))
  fi
  if [ -z "$reason" ]; then
    echo "   통과"
    passed=$((passed + 1))
  else
    echo "::error::$t 실패: $reason"
    for log in "${logs[@]}"; do
      echo "   --- $(basename "$log")"
      sed 's/^/   | /' "$log"
    done
    failed+=("$t ($reason)")
  fi
done

echo
echo "결과: 통과 $passed / 실패 ${#failed[@]}"
for f in "${failed[@]}"; do echo "  실패: $f"; done
[ "${#failed[@]}" -eq 0 ]
