#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cg-execution-receipt.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

PREFIX_DIR="$TMP_ROOT/prefix"
HOME_DIR="$TMP_ROOT/home"
BIN_DIR="$PREFIX_DIR/bin"
OUT_DIR="$HOME_DIR/.chatgpt-output"
STATE_DIR="$HOME_DIR/.chatgpt-lanes"
CLIPBOARD="$TMP_ROOT/clipboard.txt"
mkdir -p "$BIN_DIR" "$OUT_DIR" "$STATE_DIR/lanes/chat-alpha"

for name in \
  cgrun \
  cgrun-core-v95 \
  cgtail-core-v95 \
  cgrun.autoclip-v93-real \
  cgtail-autoclip-v93
do
  install -m 0755 "$ROOT/bin/$name" "$BIN_DIR/$name"
done

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -euo pipefail'
  printf '%s\n' 'cat > "$CG_TEST_CLIPBOARD"'
} > "$TMP_ROOT/clipboard-writer.sh"
chmod 0755 "$TMP_ROOT/clipboard-writer.sh"

printf '%s\n' 'chat-alpha' > "$STATE_DIR/current_lane"
{
  printf '%s\n' 'CG_LANE_ID=chat-alpha'
  printf '%s\n' 'CG_LANE_SCOPE=pixel'
  printf '%s\n' 'CG_LANE_HOST=pixel'
  printf '%s\n' 'CG_LANE_ROUTE_CLASS=none'
  printf '%s\n' 'CG_LANE_SECRET_CLASS=public'
} > "$STATE_DIR/lanes/chat-alpha/meta.env"

success_output="$TMP_ROOT/success.out"
PATH="$BIN_DIR:$PATH" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" \
CG_LANE_STATE_DIR="$STATE_DIR" CG_TEST_CLIPBOARD="$CLIPBOARD" \
CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-writer.sh" \
CG_RUN_ID="run-success" CG_RUN_MODE="verify" CGRUN_TASK_LABEL="direct-success" \
  bash "$BIN_DIR/cgrun" "printf '%s\\n' 'RESULT: PAYLOAD_OK'" > "$success_output"

grep -Fq 'RESULT: CGRUN_CORE_DONE outcome=success command_exit_code=0 timed_out=no' "$success_output"
grep -Fq 'RESULT: CGRUN_WORKFLOW_OK outcome=success chat_lane=chat-alpha task=direct-success run_id=run-success command_exit_code=0 handoff_outcome=success workflow_exit_code=0' "$success_output"
grep -Fq '== cg execution receipt ==' "$CLIPBOARD"
grep -Fq 'task=direct-success' "$CLIPBOARD"
grep -Fq 'scope=pixel' "$CLIPBOARD"
grep -Fq 'host=pixel' "$CLIPBOARD"

failure_output="$TMP_ROOT/failure.out"
set +e
PATH="$BIN_DIR:$PATH" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" \
CG_LANE_STATE_DIR="$STATE_DIR" CG_TEST_CLIPBOARD="$CLIPBOARD" \
CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-writer.sh" \
CG_RUN_ID="run-failure" CG_RUN_MODE="run" CGRUN_TASK_LABEL="direct-failure" \
  bash "$BIN_DIR/cgrun" "exit 7" > "$failure_output" 2>&1
failure_exit_code=$?
set -e

[ "$failure_exit_code" -eq 7 ]
grep -Fq 'RESULT: CGRUN_CORE_DONE outcome=command_failed command_exit_code=7 timed_out=no' "$failure_output"
grep -Fq 'RESULT: CGRUN_WORKFLOW_FAILED outcome=command_failed chat_lane=chat-alpha task=direct-failure run_id=run-failure command_exit_code=7 handoff_outcome=success workflow_exit_code=7' "$failure_output"
grep -Fq 'RESULT: CGRUN_EXECUTION_FAILED outcome=command_failed chat_lane=chat-alpha task=direct-failure run_id=run-failure command_exit_code=7' "$CLIPBOARD"

artifact_output="$TMP_ROOT/artifact.out"
PATH="$BIN_DIR:$PATH" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" \
CG_LANE_STATE_DIR="$STATE_DIR" CG_TEST_CLIPBOARD="$CLIPBOARD" \
CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-writer.sh" \
CG_RUN_ID="run-artifact" CG_RUN_MODE="verify" \
CG_RUN_SCRIPT="/tmp/cg-run-file-normalized.X/pixel_local__font_receipt_v95_smoke.sh" \
CG_RUN_TASK="pixel_local__font_receipt_v95_smoke.sh" \
  bash "$BIN_DIR/cgrun" "printf '%s\\n' 'RESULT: ARTIFACT_OK'" > "$artifact_output"

grep -Fq 'RESULT: CGRUN_WORKFLOW_OK outcome=success chat_lane=chat-alpha task=pixel_local__font_receipt_v95_smoke.sh run_id=run-artifact command_exit_code=0 handoff_outcome=success workflow_exit_code=0' "$artifact_output"
grep -Fq 'task=pixel_local__font_receipt_v95_smoke.sh' "$CLIPBOARD"
if grep -Fq 'task=cg-run-file-normalized.' "$artifact_output" "$CLIPBOARD"; then
  printf '%s\n' 'FAIL normalized_temp_name_leaked_into_task'
  exit 1
fi

if grep -Eq '^RESULT: CGRUN_.*(^|[[:space:]])rc=' \
  "$success_output" "$failure_output" "$artifact_output" "$CLIPBOARD"; then
  printf '%s\n' 'FAIL ambiguous_cgrun_rc_field_present'
  exit 1
fi

printf '%s\n' 'PASS cgrun_native_core_success'
printf '%s\n' 'PASS cgrun_native_core_failure'
printf '%s\n' 'PASS cgrun_original_task_binding'
printf '%s\n' 'RESULT: CG_EXECUTION_RECEIPT_VERIFY_DONE outcome=success workflow_exit_code=0'
