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
if ! QA_LOG_DIR="$WORK/pass-logs" "$HERE/run_tests.sh" "$WORK/pass"; then
  echo "::error::자체 검사 실패: 통과해야 할 테스트가 실패함"
  exit 1
fi
# 같은 역할(guest 2개)은 로그 파일이 따로여야 한다. 한 파일을 같이 쓰면 줄이 섞여
# 성공 줄이 깨지거나 한쪽 오류가 가려진다 (#24 에서 찾은 버그).
guest_logs=("$WORK"/pass-logs/*test_roles*guest*.log)
if [ "${#guest_logs[@]}" -ne 2 ]; then
  echo "::error::자체 검사 실패: guest 2개의 로그 파일이 ${#guest_logs[@]}개 (2개여야 함)"
  exit 1
fi
for log in "${guest_logs[@]}"; do
  if [ "$(grep -cx QA_TEST_PASS "$log")" -ne 1 ]; then
    echo "::error::자체 검사 실패: $(basename "$log") 에 성공 줄이 정확히 하나가 아님"
    exit 1
  fi
done
echo "같은 역할 로그 분리: 통과"

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
echo "#### Godot 4.4.1 GLTF 썸네일 오류 필터 (tools/filter_godot_441_import.py): 그 두 줄만 지우는지"
FILTER="$HERE/../tools/filter_godot_441_import.py"
FIX="$WORK/filter"
mkdir -p "$FIX"
BUG_ERR='ERROR: Parameter "t" is null.'
BUG_AT='   at: texture_2d_get (servers/rendering/dummy/storage/texture_storage.h:107)'
# 이름, Godot 버전, 지워져야 하나(1/0), 로그 내용
filter_case() {
  local name="$1" version="$2" expect_removed="$3" log="$FIX/$1/import.log"
  mkdir -p "$FIX/$name"
  printf '%s\n' "${@:4}" >"$log"
  cp "$log" "$log.orig"
  python3 -I "$FILTER" "$log" "$version" >/dev/null
  if [ "$expect_removed" -eq 1 ] && grep -q '^ERROR:' "$log"; then
    echo "::error::자체 검사 실패: 필터 [$name] 지워야 할 줄이 남음"; exit 1
  fi
  # 남겨야 하는 경우는 한 줄도 바뀌면 안 된다.
  if [ "$expect_removed" -eq 0 ] && ! cmp -s "$log" "$log.orig"; then
    echo "::error::자체 검사 실패: 필터 [$name] 진짜 오류를 숨김"; diff "$log.orig" "$log"; exit 1
  fi
  echo "   $name: 통과"
}
filter_case "알려진 버그 (지움)" "4.4.1.stable.official" 1 \
  "	reimport: step 40: tub.glb" "	import: step 104: Saving..." "$BUG_ERR" "$BUG_AT" "import: end"
filter_case "GLB 가 아닌 파일 (남김)" "4.4.1.stable.official" 0 \
  "	reimport: step 3: icon.png" "	import: step 104: Saving..." "$BUG_ERR" "$BUG_AT" "import: end"
filter_case "GLB 의 다른 오류 (남김)" "4.4.1.stable.official" 0 \
  "	reimport: step 40: tub.glb" "	import: step 104: Saving..." "ERROR: Failed loading resource: res://tub.glb." "$BUG_AT" "import: end"
filter_case "다른 Godot 버전 (남김)" "4.5.stable.official" 0 \
  "	reimport: step 40: tub.glb" "	import: step 104: Saving..." "$BUG_ERR" "$BUG_AT" "import: end"
filter_case "뒤에 다른 오류가 이어짐 (남김)" "4.4.1.stable.official" 0 \
  "	reimport: step 40: tub.glb" "	import: step 104: Saving..." "$BUG_ERR" "$BUG_AT" "ERROR: Cannot save scene."

echo
echo "#### 임포트를 끝낸 뒤 Godot 가 종료하다 죽으면 (종료 코드 134) 한 번만 다시 임포트"
# 가짜 Godot: --import 일 때만 FAKE_IMPORT 에 적힌 차례(쉼표)대로 흉내 내고, 나머지는 진짜 Godot 를 부른다.
FAKE="$WORK/fake_godot.sh"
cat >"$FAKE" <<'FAKE_EOF'
#!/usr/bin/env bash
for a in "$@"; do [ "$a" = --import ] && imp=1; done
if [ -n "${imp:-}" ]; then
  n=$(( $(cat "$FAKE_COUNT" 2>/dev/null || echo 0) + 1 ))
  echo "$n" >"$FAKE_COUNT"
  case "$(echo "$FAKE_IMPORT" | cut -d, -f"$n")" in
    exitcrash)
      printf 'reimport: end\nloading_editor_layout: begin: Loading editor steps: 5\n\tloading_editor_layout: step 0: Loading editor layout...\nloading_editor_layout: end\ndouble free or corruption (!prev)\n'
      exit 134 ;;
    midcrash)
      printf 'reimport: begin: (Re)Importing Assets steps: 5\n\treimport: step 1: tub.glb\ndouble free or corruption (!prev)\n'
      exit 134 ;;
  esac
fi
exec "$REAL_GODOT" "$@"
FAKE_EOF
chmod +x "$FAKE"
REAL_GODOT="${GODOT:-godot}"
# 이름, 임포트 차례, 통과해야 하나(1/0), 임포트 횟수
crash_case() {
  local count="$WORK/fake_count.$1"
  out="$(GODOT="$FAKE" REAL_GODOT="$REAL_GODOT" FAKE_IMPORT="$2" FAKE_COUNT="$count" \
    QA_LOG_DIR="$WORK/crash-logs.$1" "$HERE/run_tests.sh" "$WORK/pass" 2>&1)"
  local code=$? imports
  imports="$(cat "$count")"
  if { [ "$3" -eq 1 ] && [ "$code" -ne 0 ]; } || { [ "$3" -eq 0 ] && [ "$code" -eq 0 ]; } || [ "$imports" -ne "$4" ]; then
    sed 's/::error::/[출력] /; s/::warning::/[출력] /' <<<"$out"
    echo "::error::자체 검사 실패: 종료 크래시 [$1] 종료 코드 $code, 임포트 $imports번 (기대: 통과=$3, 임포트 $4번)"
    exit 1
  fi
  echo "   $1: 통과 (임포트 $imports번)"
}
crash_case "한 번 죽고 다시 하면 통과" "exitcrash,ok" 1 2
crash_case "두 번 다 죽으면 실패" "exitcrash,exitcrash" 0 2
crash_case "임포트 도중에 죽으면 바로 실패" "midcrash" 0 1
[ -f "$WORK/crash-logs.한 번 죽고 다시 하면 통과/import.crash.log" ] || { echo "::error::자체 검사 실패: 첫 임포트 로그(import.crash.log)가 남지 않음"; exit 1; }

echo
echo "#### project.godot 없는 폴더는 건너뜀"
mkdir -p "$WORK/empty"
"$HERE/run_tests.sh" "$WORK/empty" | grep -q "프로젝트 없음" || { echo "::error::건너뛰기 실패"; exit 1; }

echo
echo "자체 검사 통과"
