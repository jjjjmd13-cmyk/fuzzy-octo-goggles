#!/usr/bin/env bash
# Godot 헤드리스로 프로젝트를 임포트하고 tests/ 아래 테스트 씬을 모두 실행한다.
# 규칙: docs/qa/TESTING.md
#
# 사용법: tests/run_tests.sh [프로젝트 폴더]   (기본: 저장소 루트)
# 환경 변수:
#   GODOT              Godot 실행 파일 (기본: godot)
#   QA_TEST_TIMEOUT    테스트 씬 하나의 최대 실행 시간(초) (기본: 120)
#   QA_IMPORT_TIMEOUT  임포트 최대 시간(초) (기본: 600)
set -uo pipefail

PROJECT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
GODOT="${GODOT:-godot}"
TEST_TIMEOUT="${QA_TEST_TIMEOUT:-120}"
IMPORT_TIMEOUT="${QA_IMPORT_TIMEOUT:-600}"
PASS_MARK="QA_TEST_PASS"
# 이 패턴이 출력에 있으면 종료 코드와 상관없이 실패로 본다.
ERROR_PATTERN='SCRIPT ERROR|Parse Error|Failed to load script|^ERROR:'

if [ ! -f "$PROJECT/project.godot" ]; then
  echo "프로젝트 없음: $PROJECT/project.godot 이 없어 건너뜀"
  exit 0
fi

LOG_DIR="$(mktemp -d)"

echo "== 임포트: $PROJECT"
timeout "$IMPORT_TIMEOUT" "$GODOT" --headless --path "$PROJECT" --import >"$LOG_DIR/import.log" 2>&1
code=$?
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

passed=0
failed=()
for t in "${TESTS[@]}"; do
  log="$LOG_DIR/$(echo "$t" | tr '/' '_').log"
  echo "== 실행: $t"
  timeout "$TEST_TIMEOUT" "$GODOT" --headless --path "$PROJECT" "res://$t" >"$log" 2>&1
  code=$?
  reason=""
  if [ "$code" -eq 124 ]; then
    reason="시간 초과 (${TEST_TIMEOUT}초)"
  elif [ "$code" -ne 0 ]; then
    reason="종료 코드 $code"
  elif grep -Eq "$ERROR_PATTERN" "$log"; then
    reason="오류 출력 있음"
  elif ! grep -qx "$PASS_MARK" "$log"; then
    reason="성공 문자열 $PASS_MARK 없음"
  fi
  if [ -z "$reason" ]; then
    echo "   통과"
    passed=$((passed + 1))
  else
    echo "::error::$t 실패: $reason"
    sed 's/^/   | /' "$log"
    failed+=("$t ($reason)")
  fi
done

echo
echo "결과: 통과 $passed / 실패 ${#failed[@]}"
for f in "${failed[@]}"; do echo "  실패: $f"; done
[ "${#failed[@]}" -eq 0 ]
