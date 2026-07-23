#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CGRUN="$ROOT/bin/cgrun"
CG_LANE="$ROOT/bin/cg-lane.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cg-execution-receipt.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

PREFIX_DIR="$TMP_ROOT/prefix"
HOME_DIR="$TMP_ROOT/home"
BIN_DIR="$PREFIX_DIR/bin"
OUT_DIR="$HOME_DIR/.chatgpt-output"
STATE_DIR="$HOME_DIR/.chatgpt-lanes"
CLIPBOARD="$TMP_ROOT/clipboard.txt"
mkdir -p "$BIN_DIR" "$OUT_DIR"

install -m 0755 "$CGRUN" "$BIN_DIR/cgrun"
install -m 0755 "$CG_LANE" "$BIN_DIR/cg-lane.sh"

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -uo pipefail'
  printf '%s\n' 'out="$HOME/.chatgpt-output"'
  printf '%s\n' 'log="$out/cgrun_receipt_test_$$.log"'
  printf '%s\n' 'case "${1:-}" in'
  printf '%s\n' '  fail)'
  printf '%s\n' '    printf "%s\n" "RESULT: PAYLOAD_FAILED" > "$log"'
  printf '%s\n' '    ln -sfn "$log" "$out/latest.log"'
  printf '%s\n' '    exit 7'
  printf '%s\n' '    ;;'
  printf '%s\n' '  run-wrapper)'
  printf '%s\n' '    shift'
  printf '%s\n' '    set +e'
  printf '%s\n' '    bash -lc "${1:-:}" > "$log" 2>&1'
  printf '%s\n' '    exit_code=$?'
  printf '%s\n' '    set -e'
  printf '%s\n' '    ln -sfn "$log" "$out/latest.log"'
  printf '%s\n' '    exit "$exit_code"'
  printf '%s\n' '    ;;'
  printf '%s\n' '  *)'
  printf '%s\n' '    printf "%s\n" "RESULT: PAYLOAD_OK" > "$log"'
  printf '%s\n' '    ln -sfn "$log" "$out/latest.log"'
  printf '%s\n' '    exit 0'
  printf '%s\n' '    ;;'
  printf '%s\n' 'esac'
} > "$BIN_DIR/cgrun.autoclip-v93-real"

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -euo pipefail'
  printf '%s\n' 'cat "$HOME/.chatgpt-output/latest.log"'
} > "$BIN_DIR/cgtail-autoclip-v93"

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -euo pipefail'
  printf '%s\n' 'cat > "$CG_TEST_CLIPBOARD"'
} > "$BIN_DIR/termux-clipboard-set"

chmod 0755 "$BIN_DIR/"*

mkdir -p "$STATE_DIR/lanes/chat-alpha"
printf '%s\n' 'chat-alpha' > "$STATE_DIR/current_lane"
{
  printf '%s\n' 'CG_LANE_ID=chat-alpha'
  printf '%s\n' 'CG_LANE_SCOPE=pi4'
  printf '%s\n' 'CG_LANE_HOST=pi4'
  printf '%s\n' 'CG_LANE_ROUTE_CLASS=none'
  printf '%s\n' 'CG_LANE_SECRET_CLASS=none'
} > "$STATE_DIR/lanes/chat-alpha/meta.env"

success_output="$TMP_ROOT/success.out"
PATH="$BIN_DIR:$PATH" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" \
CG_LANE_STATE_DIR="$STATE_DIR" CG_TEST_CLIPBOARD="$CLIPBOARD" \
CG_RUN_ID="run-success" CG_RUN_MODE="verify" CG_RUN_SCRIPT="/tmp/pi4_backup_verify.sh" \
  "$BIN_DIR/cgrun" ok > "$success_output"

grep -Fq 'RESULT: CGRUN_WORKFLOW_OK outcome=success chat_lane=chat-alpha task=pi4_backup_verify.sh run_id=run-success command_exit_code=0 handoff_outcome=success workflow_exit_code=0' "$success_output"
grep -Fq '== cg execution receipt ==' "$CLIPBOARD"
grep -Fq 'chat_lane=chat-alpha' "$CLIPBOARD"
grep -Fq 'task=pi4_backup_verify.sh' "$CLIPBOARD"
grep -Fq 'scope=pi4' "$CLIPBOARD"
grep -Fq 'host=pi4' "$CLIPBOARD"

failure_output="$TMP_ROOT/failure.out"
set +e
PATH="$BIN_DIR:$PATH" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" \
CG_LANE_STATE_DIR="$STATE_DIR" CG_TEST_CLIPBOARD="$CLIPBOARD" \
CG_RUN_ID="run-failure" CG_RUN_MODE="run" CG_RUN_SCRIPT="/tmp/pi3_dns_check.sh" \
  "$BIN_DIR/cgrun" fail > "$failure_output" 2>&1
failure_exit_code=$?
set -e

[ "$failure_exit_code" -eq 7 ]
grep -Fq 'RESULT: CGRUN_WORKFLOW_FAILED outcome=command_failed chat_lane=chat-alpha task=pi3_dns_check.sh run_id=run-failure command_exit_code=7 handoff_outcome=success workflow_exit_code=7' "$failure_output"
grep -Fq 'RESULT: CGRUN_EXECUTION_FAILED outcome=command_failed chat_lane=chat-alpha task=pi3_dns_check.sh run_id=run-failure command_exit_code=7' "$CLIPBOARD"

artifact="$TMP_ROOT/pi4_takeout_verify.sh"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -euo pipefail'
  printf '%s\n' "printf '%s\\n' 'RESULT: PI4_TAKEOUT_VERIFY_OK'"
} > "$artifact"
chmod 0755 "$artifact"

PATH="$BIN_DIR:$PATH" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" \
CG_LANE_STATE_DIR="$STATE_DIR" CG_OUTPUT_DIR="$OUT_DIR" CG_TEST_CLIPBOARD="$CLIPBOARD" \
  "$BIN_DIR/cg-lane.sh" use chat-takeout pi4-takeout pi4 none public >/dev/null

lane_output="$TMP_ROOT/lane.out"
PATH="$BIN_DIR:$PATH" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" \
CG_LANE_STATE_DIR="$STATE_DIR" CG_OUTPUT_DIR="$OUT_DIR" CG_TEST_CLIPBOARD="$CLIPBOARD" \
CGRUN_TASK_LABEL="run-wrapper" \
  "$BIN_DIR/cg-lane.sh" run-file "$artifact" VERIFY pi4-takeout > "$lane_output"

grep -Fq '== cg multilane completion ==' "$lane_output"
grep -Fq 'chat_lane=chat-takeout' "$lane_output"
grep -Fq 'task=pi4_takeout_verify.sh' "$lane_output"
grep -Fq 'scope=pi4-takeout' "$lane_output"
grep -Fq 'host=pi4' "$lane_output"
grep -Fq 'workflow_exit_code=0' "$lane_output"
grep -Eq 'RESULT: CG_MULTILANE_RUN_FILE_OK outcome=success chat_lane=chat-takeout task=pi4_takeout_verify.sh run_id=.* workflow_exit_code=0' "$lane_output"

grep -Fq '== cg execution receipt ==' "$CLIPBOARD"
grep -Fq 'chat_lane=chat-takeout' "$CLIPBOARD"
grep -Fq 'task=pi4_takeout_verify.sh' "$CLIPBOARD"
grep -Fq 'scope=pi4-takeout' "$CLIPBOARD"
grep -Fq 'host=pi4' "$CLIPBOARD"

if grep -Eq '^RESULT: CGRUN_.*(^|[[:space:]])rc=' "$success_output" "$failure_output" "$lane_output" "$CLIPBOARD"; then
  printf '%s\n' 'FAIL ambiguous_cgrun_rc_field_present'
  exit 1
fi

printf '%s\n' 'PASS cgrun_execution_receipt_success'
printf '%s\n' 'PASS cgrun_execution_receipt_failure'
printf '%s\n' 'PASS cg_lane_execution_receipt_binding'
printf '%s\n' 'RESULT: CG_EXECUTION_RECEIPT_VERIFY_DONE'
