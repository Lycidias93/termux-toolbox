#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cg-run-file-lock-autocopy-integration.XXXXXX")"
HOST_PATH="${PATH:?PATH is required}"
HOST_LD_PRELOAD="${LD_PRELOAD:-}"
trap 'rm -rf "$TMP_ROOT"' EXIT
PREFIX_DIR="$TMP_ROOT/prefix"; HOME_DIR="$TMP_ROOT/home"; BIN_DIR="$PREFIX_DIR/bin"; STATE_DIR="$HOME_DIR/.chatgpt-lanes"; OUT_DIR="$HOME_DIR/.chatgpt-output"; TEST_TMP="$TMP_ROOT/tmp"; CLIPBOARD="$TMP_ROOT/clipboard.txt"; OUTPUT="$TMP_ROOT/run.out"
mkdir -p "$BIN_DIR" "$STATE_DIR/lanes/chat-lock" "$STATE_DIR/locks" "$OUT_DIR" "$TEST_TMP"
for name in cgrun cgrun-core-v95 cgtail-core-v95 cg-run-file-driver-v1 cg-run-file; do install -m0755 "$ROOT/bin/$name" "$BIN_DIR/$name"; done
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'cat > "$CG_TEST_CLIPBOARD"' >"$TMP_ROOT/clipboard-writer.sh"
chmod 0755 "$TMP_ROOT/clipboard-writer.sh"
printf '%s\n' chat-lock >"$STATE_DIR/current_lane"
printf '%s\n' 'CG_LANE_ID=chat-lock' 'CG_LANE_SCOPE=pixel' 'CG_LANE_HOST=pixel' 'CG_LANE_ROUTE_CLASS=none' 'CG_LANE_SECRET_CLASS=sensitive' >"$STATE_DIR/lanes/chat-lock/meta.env"
payload="$TEST_TMP/payload.sh"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'printf "%s\n" "RESULT: PAYLOAD_SHOULD_NOT_RUN"' >"$payload"
chmod 0755 "$payload"
lock="$STATE_DIR/locks/lane-chat-lock"
mkdir -p "$lock"; printf '%s\n' live-integration-holder >"$lock/run_id"; printf '%s\n' "$$" >"$lock/pid"; awk '{print $22}' "/proc/$$/stat" >"$lock/pid_start_ticks"; printf '%s\n' "$(date -Is)" >"$lock/created_at"

set +e
env -i PATH="$BIN_DIR:$HOST_PATH" LD_PRELOAD="$HOST_LD_PRELOAD" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" TMPDIR="$TEST_TMP" LC_ALL=C CG_LANE_STATE_DIR="$STATE_DIR" CG_OUTPUT_DIR="$OUT_DIR" CG_TEST_CLIPBOARD="$CLIPBOARD" CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-writer.sh" CGRUN_HEARTBEAT_SECONDS=0 bash "$BIN_DIR/cg-run-file" "$payload" run pixel >"$OUTPUT" 2>&1
run_rc=$?
set -e
[ "$run_rc" -eq 75 ] || { printf 'FAIL lock_busy_exit_code got=%s expected=75\n' "$run_rc"; cat "$OUTPUT" 2>/dev/null || true; exit 1; }
[ -s "$CLIPBOARD" ] || { printf '%s\n' 'FAIL lock_busy_clipboard_missing'; cat "$OUTPUT" 2>/dev/null || true; exit 1; }
grep -Fq '== cgrun redacted mandatory AutoCopy ==' "$CLIPBOARD"
grep -Fq 'secret_class=sensitive' "$CLIPBOARD"
grep -Fq 'RESULT: CG_MULTILANE_LOCK_BUSY outcome=blocked lock=lane-chat-lock holder=live-integration-holder workflow_exit_id=WORKFLOW_CONCURRENCY_RETRY workflow_exit_code=75' "$CLIPBOARD"
grep -Fq 'receipt_version=v2-precopy' "$CLIPBOARD"
grep -Fq 'execution_id=' "$CLIPBOARD"
grep -Fq 'command_exit_code=75' "$CLIPBOARD"
grep -Fq 'clipboard_delivery_state=pending_current_write' "$CLIPBOARD"
grep -Fq 'workflow_exit_id=WORKFLOW_UNCLASSIFIED_NONZERO' "$OUTPUT"
grep -Fq 'workflow_diagnosis_id=RAW_RECEIPT_INSPECT' "$OUTPUT"
if grep -Fq 'RESULT: PAYLOAD_SHOULD_NOT_RUN' "$OUTPUT" "$CLIPBOARD"; then printf '%s\n' 'FAIL payload_ran_while_lock_busy'; exit 1; fi
[ -d "$lock" ] || { printf '%s\n' 'FAIL live_lock_was_removed'; exit 1; }
printf '%s\n' 'PASS live_lock_redacted_autocopy' 'PASS live_lock_precopy_receipt_bound' 'PASS live_lock_semantic_marker_preserved' 'PASS live_lock_payload_not_executed'
printf '%s\n' 'RESULT: CG_RUN_FILE_LOCK_AUTOCOPY_INTEGRATION_VERIFY_DONE outcome=success workflow_exit_code=0'
