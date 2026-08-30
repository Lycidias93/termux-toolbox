#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/termux-io-vnext.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT
PREFIX_DIR="$TMP_ROOT/prefix"; HOME_DIR="$TMP_ROOT/home"; BIN_DIR="$PREFIX_DIR/bin"; OUT_DIR="$HOME_DIR/.chatgpt-output"; STATE_DIR="$HOME_DIR/.chatgpt-lanes"; TEST_TMP="$TMP_ROOT/tmp"
mkdir -p "$BIN_DIR" "$OUT_DIR" "$STATE_DIR/lanes/lane-a" "$STATE_DIR/lanes/lane-b" "$TEST_TMP"
for name in cgrun cgrun-core-v95 cgtail-core-v95 cg-run-file-driver-v1 cg-lane.sh; do install -m0755 "$ROOT/bin/$name" "$BIN_DIR/$name"; done
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'cat >"$CG_TEST_CLIPBOARD"' >"$TMP_ROOT/clipboard-write.sh"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'cat "$CG_TEST_CLIPBOARD"' >"$TMP_ROOT/clipboard-read.sh"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" wrong' >"$TMP_ROOT/clipboard-wrong.sh"
chmod 0755 "$TMP_ROOT"/clipboard-*.sh
printf 'lane-a\n' >"$STATE_DIR/current_lane"
for lane in lane-a lane-b; do { printf 'CG_LANE_ID=%s\n' "$lane"; printf 'CG_LANE_SCOPE=pixel\nCG_LANE_HOST=pixel\nCG_LANE_ROUTE_CLASS=none\nCG_LANE_SECRET_CLASS=public\n'; } >"$STATE_DIR/lanes/$lane/meta.env"; done
runenv() { env -i PATH="$BIN_DIR:$PATH" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" TMPDIR="$TEST_TMP" LC_ALL=C CG_OUTPUT_DIR="$OUT_DIR" CG_LANE_STATE_DIR="$STATE_DIR" CGRUN_HEARTBEAT_SECONDS=0 "$@"; }

clip_a="$TMP_ROOT/clip-a"; clip_b="$TMP_ROOT/clip-b"
runenv CG_LANE_ID=lane-a CG_RUN_ID=run-a CG_TEST_CLIPBOARD="$clip_a" CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-write.sh" CGRUN_CLIPBOARD_READ_COMMAND="$TMP_ROOT/clipboard-read.sh" bash "$BIN_DIR/cgrun" --shell "printf '%s\\n' 'A_BEGIN'; sleep 0.25; printf '%s\\n' 'RESULT: A_DONE'" >"$TMP_ROOT/a.out" & pid_a=$!
sleep 0.05
runenv CG_LANE_ID=lane-b CG_RUN_ID=run-b CG_TEST_CLIPBOARD="$clip_b" CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-write.sh" CGRUN_CLIPBOARD_READ_COMMAND="$TMP_ROOT/clipboard-read.sh" bash "$BIN_DIR/cgrun" --shell "printf '%s\\n' 'B_BEGIN'; printf '%s\\n' 'RESULT: B_DONE'" >"$TMP_ROOT/b.out" & pid_b=$!
wait "$pid_a"; wait "$pid_b"
grep -Fq 'RESULT: A_DONE' "$clip_a"; ! grep -Fq 'RESULT: B_DONE' "$clip_a"; grep -Fq 'RESULT: B_DONE' "$clip_b"; ! grep -Fq 'RESULT: A_DONE' "$clip_b"
grep -Fq 'source_mode=bound' "$clip_a"; grep -Fq 'execution_id=run-a' "$TMP_ROOT/a.out"; grep -Fq 'clipboard_verify_state=match' "$TMP_ROOT/a.out"

set +e
runenv CG_LANE_ID=lane-a CG_RUN_ID=clip-fail CGRUN_CLIPBOARD_COMMAND=/bin/false bash "$BIN_DIR/cgrun" --shell "printf '%s\\n' 'RESULT: CMD_OK'" >"$TMP_ROOT/clip-fail.out" 2>&1
rc=$?
set -e
[ "$rc" -eq 0 ]; grep -Fq 'RESULT: CGRUN_WORKFLOW_DEGRADED' "$TMP_ROOT/clip-fail.out"; grep -Fq 'workflow_exit_id=CGRUN_CLIPBOARD_DELIVERY_FAILED' "$TMP_ROOT/clip-fail.out"; grep -Eq 'handoff_exit_code=[1-9][0-9]*' "$TMP_ROOT/clip-fail.out"

set +e
runenv CG_LANE_ID=lane-a CG_RUN_ID=clip-strict CGRUN_AUTO_TAIL_STRICT=1 CGRUN_CLIPBOARD_COMMAND=/bin/false bash "$BIN_DIR/cgrun" --shell "printf '%s\\n' 'RESULT: CMD_OK'" >"$TMP_ROOT/clip-strict.out" 2>&1
strict_rc=$?
set -e
[ "$strict_rc" -ne 0 ]; grep -Fq 'RESULT: CGRUN_WORKFLOW_FAILED outcome=handoff_failed' "$TMP_ROOT/clip-strict.out"

clip_mismatch="$TMP_ROOT/clip-mismatch"
set +e
runenv CG_LANE_ID=lane-a CG_RUN_ID=clip-mismatch CG_TEST_CLIPBOARD="$clip_mismatch" CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-write.sh" CGRUN_CLIPBOARD_READ_COMMAND="$TMP_ROOT/clipboard-wrong.sh" bash "$BIN_DIR/cgrun" --shell "printf '%s\\n' 'RESULT: CMD_OK'" >"$TMP_ROOT/mismatch.out" 2>&1
mismatch_rc=$?
set -e
[ "$mismatch_rc" -eq 0 ]; grep -Fq 'workflow_exit_id=CGRUN_CLIPBOARD_READBACK_MISMATCH' "$TMP_ROOT/mismatch.out"; grep -Fq 'clipboard_verify_state=mismatch' "$TMP_ROOT/mismatch.out"

printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'printf "argc=%s\\n" "$#"' 'i=0' 'for arg in "$@"; do i=$((i+1)); printf "arg%s=<%s>\\n" "$i" "$arg"; done' 'printf "%s\\n" "RESULT: ARGV_DONE"' >"$TMP_ROOT/argv.sh"
chmod 0755 "$TMP_ROOT/argv.sh"
clip_argv="$TMP_ROOT/clip-argv"
runenv CG_LANE_ID=lane-a CG_RUN_ID=argv CG_TEST_CLIPBOARD="$clip_argv" CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-write.sh" CGRUN_CLIPBOARD_READ_COMMAND="$TMP_ROOT/clipboard-read.sh" bash "$BIN_DIR/cgrun" --exec bash "$TMP_ROOT/argv.sh" 'a b' 'x$y' 'semi;colon' >"$TMP_ROOT/argv.out"
grep -Fq 'input_mode=exec' "$TMP_ROOT/argv.out"; grep -Fq 'argc=3' "$clip_argv"; grep -Fq 'arg1=<a b>' "$clip_argv"; grep -Fq 'arg2=<x$y>' "$clip_argv"; grep -Fq 'arg3=<semi;colon>' "$clip_argv"

clip_diag="$TMP_ROOT/clip-diag"
set +e
runenv CG_LANE_ID=lane-a CG_RUN_ID=diag CG_TEST_CLIPBOARD="$clip_diag" CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-write.sh" CGRUN_CLIPBOARD_READ_COMMAND="$TMP_ROOT/clipboard-read.sh" bash "$BIN_DIR/cgrun" --shell "printf '%s\\n' 'FAIL: first_root'; i=0; while [ \$i -lt 220 ]; do printf 'filler-%s\\n' \"\$i\"; i=\$((i+1)); done; exit 9" >"$TMP_ROOT/diag.out" 2>&1
diag_rc=$?
set -e
[ "$diag_rc" -eq 9 ]; grep -Fq '== diagnostic envelope ==' "$clip_diag"; grep -Fq 'FAIL: first_root' "$clip_diag"; grep -Fq 'workflow_exit_id=WORKFLOW_UNCLASSIFIED_NONZERO' "$TMP_ROOT/diag.out"

script="$TMP_ROOT/pixel_local__driver.sh"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'printf "%s\\n" "RESULT: DRIVER_OK"' >"$script"
chmod 0755 "$script"
printf 'lane-a\n' >"$STATE_DIR/current_lane"
clip_driver="$TMP_ROOT/clip-driver"
runenv CG_TEST_CLIPBOARD="$clip_driver" CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-write.sh" CGRUN_CLIPBOARD_READ_COMMAND="$TMP_ROOT/clipboard-read.sh" bash "$BIN_DIR/cg-lane.sh" run-file "$script" verify pixel >"$TMP_ROOT/driver.out"
run_id="$(grep '^run_id=' "$TMP_ROOT/driver.out" | tail -n1 | cut -d= -f2-)"; [ -n "$run_id" ]; [ -f "$OUT_DIR/runs/$run_id/run.log" ]; [ "$(cat "$STATE_DIR/lanes/lane-a/latest.path")" = "$OUT_DIR/runs/$run_id/run.log" ]; grep -Fq 'RESULT: DRIVER_OK' "$OUT_DIR/runs/$run_id/run.log"

printf '%s\n' 'PASS exact_run_binding_parallel' 'PASS clipboard_failure_semantics' 'PASS clipboard_readback_mismatch' 'PASS argv_exec_fidelity' 'PASS diagnostic_envelope_first_failure' 'PASS canonical_lane_driver_exact_log'
printf '%s\n' 'RESULT: TERMUX_IO_VNEXT_VERIFY_DONE outcome=success workflow_exit_code=0'
