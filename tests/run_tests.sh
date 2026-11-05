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

# 임포트 한 번: import.log 에 남기고 종료 코드를 code 에 둔다.
run_import() {
  timeout "$IMPORT_TIMEOUT" "$GODOT" --headless --path "$PROJECT" --import >"$LOG_DIR/import.log" 2>&1
  code=$?
  # Godot 4.4.1 upstream #108994: saving GLTF succeeds, only its headless editor thumbnail fails.
  # Retain raw output and ignore only that exact, version-guarded two-line block.
  if [ -f "$PROJECT/tools/filter_godot_441_import.py" ] && grep -Fq 'servers/rendering/dummy/storage/texture_storage.h:107' "$LOG_DIR/import.log"; then
    python3 "$PROJECT/tools/filter_godot_441_import.py" "$LOG_DIR/import.log" "$("$GODOT" --version)"
  fi
}

# Godot 4.4.1 이 임포트를 다 끝낸 뒤 에디터를 닫다가 죽는 경우인가 (종료 코드 134, glibc "double free").
# 네 가지가 모두 맞을 때만: 종료 코드 134 / "loading_editor_layout: end" 가 있음 /
# 그 뒤에는 glibc 메모리 오류 줄(과 timeout 의 코어 덤프 알림)만 있음 / 오류 줄이 없음.
crashed_after_import() {
  [ "$code" -eq 134 ] || return 1
  grep -qx 'loading_editor_layout: end' "$LOG_DIR/import.log" || return 1
  ! grep -Eq "$ERROR_PATTERN" "$LOG_DIR/import.log" || return 1
  awk '
    $0 == "loading_editor_layout: end" { tail = 1; seen = 0; bad = 0; next }
    tail && /^(double free or corruption|free\(\): |malloc\(\): |corrupted |munmap_chunk\(\))/ { seen = 1; next }
    tail && ($0 ~ /^timeout: the monitored command dumped core$/ || $0 ~ /^[[:space:]]*$/) { next }
    tail { bad = 1 }
    END { exit !(tail && seen && !bad) }
  ' "$LOG_DIR/import.log"
}

echo "== 임포트: $PROJECT"
run_import
if crashed_after_import; then
  # 가져온 결과는 이미 저장됐다. 한 번만 다시 임포트해서 정말 끝났는지 확인한다 (테스트는 그대로 다 돈다).
  cat "$LOG_DIR/import.log"
  mv "$LOG_DIR/import.log" "$LOG_DIR/import.crash.log"
  echo "::warning::Godot 가 임포트를 끝낸 뒤 종료하다 죽음 (종료 코드 134) → 임포트 한 번 더 (첫 로그: import.crash.log)"
  run_import
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
