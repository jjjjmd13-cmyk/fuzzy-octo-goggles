#!/usr/bin/env bash
# 헤드리스 자동 테스트 실행. 사용법:
#   GODOT=/path/to/godot tests/run_tests.sh
# 모두 통과하면 "ALL_TESTS_PASSED" 를 출력하고 0 으로 끝난다.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT="${NET_TEST_PORT:-24600}"
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
FAILED=0

run_godot() { "$GODOT" --headless --path . "$@"; }

echo "== 프로젝트 임포트"
run_godot --import > "$LOG_DIR/import.log" 2>&1
if grep -E "SCRIPT ERROR|Parse Error|Failed to load" "$LOG_DIR/import.log"; then
	echo "임포트 중 오류"; FAILED=1
fi

echo "== 혼자 하기 테스트"
if run_godot res://tests/offline_test.tscn > "$LOG_DIR/offline.log" 2>&1 && grep -q OFFLINE_TEST_OK "$LOG_DIR/offline.log"; then
	echo "OFFLINE_TEST_OK"
else
	cat "$LOG_DIR/offline.log"; FAILED=1
fi

echo "== 네트워크 테스트 (ENet 서버 1 + 클라이언트 1, 포트 $PORT)"
run_godot res://tests/net_sync_test.tscn -- --role=server --port="$PORT" > "$LOG_DIR/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 100); do
	grep -q NET_TEST_SERVER_LISTENING "$LOG_DIR/server.log" 2>/dev/null && break
	kill -0 "$SERVER_PID" 2>/dev/null || break
	sleep 0.1
done
run_godot res://tests/net_sync_test.tscn -- --role=client --port="$PORT" > "$LOG_DIR/client.log" 2>&1
CLIENT_RC=$?
wait "$SERVER_PID"
SERVER_RC=$?
if [ "$SERVER_RC" -eq 0 ] && [ "$CLIENT_RC" -eq 0 ] \
	&& grep -q NET_TEST_SERVER_OK "$LOG_DIR/server.log" && grep -q NET_TEST_CLIENT_OK "$LOG_DIR/client.log"; then
	echo "NET_TEST_SERVER_OK"; echo "NET_TEST_CLIENT_OK"
else
	echo "--- server.log"; cat "$LOG_DIR/server.log"
	echo "--- client.log"; cat "$LOG_DIR/client.log"
	FAILED=1
fi

if [ "$FAILED" -eq 0 ]; then
	echo "ALL_TESTS_PASSED"
else
	echo "TESTS_FAILED (로그: $LOG_DIR)"
fi
exit "$FAILED"
