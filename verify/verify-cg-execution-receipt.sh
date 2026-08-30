#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cg-execution-receipt.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
PREFIX_DIR="$TMP_ROOT/prefix"; HOME_DIR="$TMP_ROOT/home"; BIN_DIR="$PREFIX_DIR/bin"; OUT_DIR="$HOME_DIR/.chatgpt-output"; STATE_DIR="$HOME_DIR/.chatgpt-lanes"; CLIPBOARD="$TMP_ROOT/clipboard.txt"; TEST_TMP="$TMP_ROOT/tmp"
mkdir -p "$BIN_DIR" "$OUT_DIR" "$STATE_DIR/lanes/chat-alpha" "$TEST_TMP"
for name in cgrun cgrun-core-v95 cgtail-core-v95 cgrun.autoclip-v93-real cgtail-autoclip-v93; do install -m0755 "$ROOT/bin/$name" "$BIN_DIR/$name"; done
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'cat > "$CG_TEST_CLIPBOARD"' >"$TMP_ROOT/clipboard-writer.sh"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'cat "$CG_TEST_CLIPBOARD"' >"$TMP_ROOT/clipboard-reader.sh"
chmod 0755 "$TMP_ROOT/clipboard-writer.sh" "$TMP_ROOT/clipboard-reader.sh"
printf '%s\n' chat-alpha >"$STATE_DIR/current_lane"
printf '%s\n' 'CG_LANE_ID=chat-alpha' 'CG_LANE_SCOPE=pixel' 'CG_LANE_HOST=pixel' 'CG_LANE_ROUTE_CLASS=none' 'CG_LANE_SECRET_CLASS=public' >"$STATE_DIR/lanes/chat-alpha/meta.env"

run_clean() {
	env -i PATH="$BIN_DIR:$PATH" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" TMPDIR="$TEST_TMP" LC_ALL=C CG_OUTPUT_DIR="$OUT_DIR" CG_LANE_STATE_DIR="$STATE_DIR" CG_TEST_CLIPBOARD="$CLIPBOARD" CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-writer.sh" CGRUN_CLIPBOARD_READ_COMMAND="$TMP_ROOT/clipboard-reader.sh" CGRUN_HEARTBEAT_SECONDS=0 "$@"
}

success="$TMP_ROOT/success.out"
run_clean CG_RUN_ID=run-success CG_RUN_MODE=verify CGRUN_TASK_LABEL=direct-success bash "$BIN_DIR/cgrun" --shell "printf '%s\\n' 'RESULT: PAYLOAD_OK'" >"$success"
grep -Fq 'RESULT: CGRUN_CORE_DONE outcome=success command_exit_code=0' "$success"
grep -Fq 'RESULT: CGRUN_WORKFLOW_OK outcome=success chat_lane=chat-alpha task=direct-success run_id=run-success execution_id=run-success command_exit_code=0 handoff_outcome=success workflow_exit_id=WORKFLOW_OK workflow_exit_code=0' "$success"
grep -Fq 'receipt_version=v2' "$success"
grep -Fq 'workflow_exit_id=WORKFLOW_OK' "$success"
grep -Fq 'clipboard_verify_state=match' "$success"
grep -Fq 'execution_id=run-success' "$CLIPBOARD"
grep -Fq 'clipboard_delivery_state=pending_current_write' "$CLIPBOARD"
[ -f "$OUT_DIR/runs/run-success/run.log" ]

failure="$TMP_ROOT/failure.out"
set +e
run_clean CG_RUN_ID=run-failure CG_RUN_MODE=run CGRUN_TASK_LABEL=direct-failure bash "$BIN_DIR/cgrun" --shell 'exit 7' >"$failure" 2>&1
failure_rc=$?
set -e
[ "$failure_rc" -eq 7 ]
grep -Fq 'RESULT: CGRUN_CORE_DONE outcome=command_failed command_exit_code=7' "$failure"
grep -Fq 'workflow_exit_id=WORKFLOW_UNCLASSIFIED_NONZERO' "$failure"
grep -Fq 'workflow_diagnosis_id=RAW_RECEIPT_INSPECT' "$failure"
grep -Fq 'workflow_exit_code=7' "$failure"

artifact="$TMP_ROOT/artifact.out"
run_clean CG_RUN_ID=run-artifact CG_RUN_MODE=verify CG_RUN_SCRIPT=/tmp/cg-run-file-normalized.X/pixel_local__font_receipt_v95_smoke.sh CG_RUN_TASK=pixel_local__font_receipt_v95_smoke.sh bash "$BIN_DIR/cgrun" --shell "printf '%s\\n' 'RESULT: ARTIFACT_OK'" >"$artifact"
grep -Fq 'task=pixel_local__font_receipt_v95_smoke.sh' "$artifact"
if grep -Fq 'task=cg-run-file-normalized.' "$artifact" "$CLIPBOARD"; then printf '%s\n' 'FAIL normalized_temp_name_leaked_into_task'; exit 1; fi

if grep -Eq '^RESULT: CGRUN_.*(^|[[:space:]])rc=' "$success" "$failure" "$artifact" "$CLIPBOARD"; then printf '%s\n' 'FAIL ambiguous_cgrun_rc_field_present'; exit 1; fi
printf '%s\n' 'PASS cgrun_receipt_v2_success' 'PASS cgrun_receipt_v2_failure' 'PASS cgrun_exact_log_binding' 'PASS cgrun_clipboard_hash_readback' 'PASS cgrun_original_task_binding'
printf '%s\n' 'RESULT: CG_EXECUTION_RECEIPT_VERIFY_DONE outcome=success workflow_exit_code=0'
