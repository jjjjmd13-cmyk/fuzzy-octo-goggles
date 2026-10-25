#!/usr/bin/env bash
# run_tests.sh 자체 검사. 통과해야 할 프로젝트는 통과하고,
# 실패해야 할 프로젝트(6가지 실패 유형)는 정확히 6개 실패로 잡히는지 본다.
# 사용법: GODOT=<godot 경로> tests/selftest.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
export QA_TEST_TIMEOUT="${QA_TEST_TIMEOUT:-20}"
export QA_READY_TIMEOUT="${QA_READY_TIMEOUT:-10}"

for p in pass fail; do
  cp -r "$HERE/selftest/$p" "$WORK/$p"
  cp "$HERE/qa_test.gd" "$WORK/$p/tests/qa_test.gd"
done

echo "#### 통과해야 하는 프로젝트"
if ! "$HERE/run_tests.sh" "$WORK/pass"; then
  echo "::error::자체 검사 실패: 통과해야 할 테스트가 실패함"
  exit 1
fi

echo
echo "#### 실패해야 하는 프로젝트"
out="$("$HERE/run_tests.sh" "$WORK/fail")"
code=$?
# 일부러 낸 실패가 GitHub 오류 표시로 뜨지 않게 바꿔 찍는다.
sed 's/::error::/[예상된 실패] /' <<<"$out"
if [ "$code" -eq 0 ] || ! grep -q "결과: 통과 0 / 실패 6" <<<"$out"; then
  echo "::error::자체 검사 실패: 실패 6개를 모두 잡아내지 못함"
  exit 1
fi

echo
echo "#### 문법 오류는 임포트에서 실패"
cp -r "$WORK/pass" "$WORK/broken"
printf 'extends Node\nfunc _ready(:\n' >"$WORK/broken/broken.gd"
out="$("$HERE/run_tests.sh" "$WORK/broken" 2>&1)"
code=$?
if [ "$code" -eq 0 ] || ! grep -q "임포트 중 오류" <<<"$out"; then
  sed 's/::error::/[출력] /' <<<"$out"
  echo "::error::자체 검사 실패: 임포트 문법 오류를 잡아내지 못함"
  exit 1
fi
echo "잡아냄"

echo
echo "#### project.godot 없는 폴더는 건너뜀"
mkdir -p "$WORK/empty"
"$HERE/run_tests.sh" "$WORK/empty" | grep -q "프로젝트 없음" || { echo "::error::건너뛰기 실패"; exit 1; }

echo
echo "자체 검사 통과"
