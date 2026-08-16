#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF="${CG_HANDOFF_PATH:-$ROOT/bin/cg-handoff}"
LANE="${CG_LANE_PATH:-$ROOT/bin/cg-lane.sh}"
DRIVER="${CG_RUN_FILE_DRIVER_PATH:-$ROOT/bin/cg-run-file-driver-v1}"
TMP_ROOT="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "$TMP_ROOT/cg-handoff-fixture.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM HUP

fail() {
  printf 'RESULT: CG_HANDOFF_FIXTURE_STOP outcome=stop reason=%s workflow_exit_code=1\n' "$1"
  exit 1
}

mkdir -p "$WORK/Download" "$WORK/bin" "$WORK/tmp"
artifact="$WORK/Download/pixel_local__fixture.sh"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' '# CG_HANDOFF_V1_START'
  printf '%s\n' '# cg_handoff_lane=chat-fixture'
  printf '%s\n' '# cg_handoff_scope=pixel'
  printf '%s\n' '# cg_handoff_host=pixel'
  printf '%s\n' '# cg_handoff_route_class=route'
  printf '%s\n' '# cg_handoff_secret_class=redacted'
  printf '%s\n' '# cg_handoff_run_mode=verify'
  printf '%s\n' '# cg_handoff_expected_marker=RESULT: FIXTURE_PASS'
  printf '%s\n' '# CG_HANDOFF_V1_END'
  printf '%s\n' "printf 'RESULT: FIXTURE_PASS\\n'"
} > "$artifact"
chmod 0700 "$artifact"

grep -Fq 'CG_HANDOFF_TTY_TAIL_DRAIN_V2' "$HANDOFF" || fail tty_tail_drain_v2_marker_missing
grep -Fq 'drain_pending_tty_input' "$HANDOFF" || fail tty_tail_drain_call_missing
grep -Fq 'CG_HANDOFF_TTY_QUIET_POLLS' "$HANDOFF" || fail tty_tail_settle_window_missing
grep -Fq 'exec 9<>"$tty"' "$HANDOFF" || fail tty_tail_controlling_tty_fd_missing
grep -Fq 'CG_HANDOFF_EARLY_AUTOCOPY_V1' "$HANDOFF" || fail early_autocopy_marker_missing

for route_class in none read-only route dns-ha magicdns subnet-route; do
  state="$WORK/lane-$route_class"
  output_dir="$WORK/output-$route_class"
  lane_name="route-fixture-${route_class//[^a-z0-9._-]/-}"
  route_output="$(CG_LANE_STATE_DIR="$state" CG_OUTPUT_DIR="$output_dir" bash "$LANE" use "$lane_name" pi4 pi4 "$route_class" redacted 2>&1)" || fail "route_class_rejected_${route_class}"
  printf '%s\n' "$route_output" | grep -Fq 'RESULT: CG_MULTILANE_USE_OK' || fail "route_class_use_marker_missing_${route_class}"
  grep -Fxq "CG_LANE_ROUTE_CLASS=$route_class" "$state/lanes/$lane_name/meta.env" || fail "route_class_meta_mismatch_${route_class}"
done
printf '%s\n' 'PASS canonical_route_classes'

for route_class in none read-only route dns-ha magicdns subnet-route; do
  driver_state="$WORK/driver-state-$route_class"
  driver_output="$WORK/driver-output-$route_class"
  mkdir -p "$driver_state/locks" "$driver_output"
  driver_lane="driver-${route_class//[^a-z0-9._-]/-}"
  driver_run="fixture-${route_class//[^a-z0-9._-]/-}"
  driver_lock="lane-$driver_lane"
  driver_result="$(CG_LANE_STATE_DIR="$driver_state" CG_OUTPUT_DIR="$driver_output" bash "$DRIVER" --payload "$artifact" verify "$driver_lane" pixel pi4 "$route_class" redacted "$driver_run" "$driver_lock" 2>&1)" || fail "driver_route_class_rejected_${route_class}"
  printf '%s\n' "$driver_result" | grep -Fq 'CG_MULTILANE_PAYLOAD_DONE payload_exit_code=0' || fail "driver_route_class_payload_missing_${route_class}"
done
printf '%s\n' 'PASS canonical_driver_route_classes'

for name in cgprep cclear cgcurrent; do
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'exit 0'
  } > "$WORK/bin/$name"
  chmod 0700 "$WORK/bin/$name"
done

write_success_cguse() {
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'printf "CGUSE:%s\n" "$*"'
  } > "$WORK/bin/cguse"
  chmod 0700 "$WORK/bin/cguse"
}

write_success_run_file() {
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'printf "RUNFILE:%s\n" "$*"'
    printf '%s\n' 'printf "MARKER:%s\n" "${CGFLOW_EXPECTED_MARKER:-}"'
  } > "$WORK/bin/cg-run-file"
  chmod 0700 "$WORK/bin/cg-run-file"
}

write_success_cguse
write_success_run_file
sha="$(sha256sum "$artifact" | awk '{print $1}')"
output="$(PATH="$WORK/bin:$PATH" CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" CG_OUTPUT_DIR="$WORK/output-success" TMPDIR="$WORK/tmp" bash "$HANDOFF" "$(basename "$artifact")" "$sha")"
printf '%s\n' "$output"

printf '%s\n' "$output" | grep -Fq 'CGUSE:chat-fixture pixel pixel route redacted' || fail cguse_binding_failed
printf '%s\n' "$output" | grep -Fq 'RUNFILE:' || fail run_file_missing
printf '%s\n' "$output" | grep -Fq ' verify pixel pixel route redacted' || fail run_file_args_failed
printf '%s\n' "$output" | grep -Fq 'MARKER:RESULT: FIXTURE_PASS' || fail expected_marker_failed

late_tty="$WORK/late-tty.fifo"
mkfifo "$late_tty"
{
  sleep 0.25
  printf '%s' '```' > "$late_tty"
} &
writer_pid=$!
set +e
late_output="$(PATH="$WORK/bin:$PATH" CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" CG_OUTPUT_DIR="$WORK/output-late" TMPDIR="$WORK/tmp" CG_HANDOFF_TTY_PATH="$late_tty" CG_HANDOFF_TTY_DRAIN=1 CG_HANDOFF_TTY_MAX_POLLS=30 CG_HANDOFF_TTY_QUIET_POLLS=12 CG_HANDOFF_TTY_POLL_TIMEOUT=0.05 bash "$HANDOFF" "$(basename "$artifact")" "$sha" 2>&1)"
late_rc=$?
set -e
wait "$writer_pid"
[[ "$late_rc" -eq 0 ]] || fail late_tty_fixture_run_failed
printf '%s\n' "$late_output" | grep -Eq 'CG_HANDOFF_TTY_DRAIN bytes=[3-9][0-9]* .*result=PASS|CG_HANDOFF_TTY_DRAIN bytes=3 .*result=PASS' || fail late_tty_tail_not_drained
printf '%s\n' 'PASS delayed_tty_tail_drain'

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'exit 7'
} > "$WORK/bin/cg-run-file"
chmod 0700 "$WORK/bin/cg-run-file"
set +e
PATH="$WORK/bin:$PATH" CG_HANDOFF_TTY_DRAIN=0 CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" CG_OUTPUT_DIR="$WORK/output-run-fail" TMPDIR="$WORK/tmp" bash "$HANDOFF" "$(basename "$artifact")" "$sha" >/dev/null 2>&1
run_rc=$?
set -e
[[ "$run_rc" -eq 7 ]] || fail run_file_exit_status_not_preserved

write_success_run_file
set +e
bad_output="$(PATH="$WORK/bin:$PATH" CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" CG_OUTPUT_DIR="$WORK/output-bad-hash" TMPDIR="$WORK/tmp" CG_HANDOFF_TTY_DRAIN=0 bash "$HANDOFF" "$(basename "$artifact")" "$(printf '0%.0s' {1..64})" 2>&1)"
bad_rc=$?
set -e
[[ "$bad_rc" -eq 2 ]] || fail bad_hash_rc_failed
printf '%s\n' "$bad_output" | grep -Fq 'reason=source_sha_mismatch' || fail bad_hash_reason_failed

clipboard_capture="$WORK/clipboard-capture.log"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf 'cat > %q\n' "$clipboard_capture"
} > "$WORK/bin/clipboard-sink"
chmod 0700 "$WORK/bin/clipboard-sink"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'printf "FAIL: fixture_cguse_failure\n" >&2'
  printf '%s\n' 'exit 23'
} > "$WORK/bin/cguse"
chmod 0700 "$WORK/bin/cguse"
set +e
early_output="$(PATH="$WORK/bin:$PATH" CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" CG_OUTPUT_DIR="$WORK/output-early" TMPDIR="$WORK/tmp" CG_HANDOFF_TTY_DRAIN=0 CG_HANDOFF_CLIPBOARD_COMMAND="$WORK/bin/clipboard-sink" bash "$HANDOFF" "$(basename "$artifact")" "$sha" 2>&1)"
early_rc=$?
set -e
[[ "$early_rc" -eq 2 ]] || fail early_autocopy_rc_failed
[[ -s "$clipboard_capture" ]] || fail early_autocopy_capture_missing
grep -Fq 'reason=cguse_failed' "$clipboard_capture" || fail early_autocopy_reason_missing
grep -Fq 'FAIL: fixture_cguse_failure' "$clipboard_capture" || fail early_autocopy_preflight_missing
grep -Fq 'route_class=route' "$clipboard_capture" || fail early_autocopy_route_binding_missing
grep -Fq 'RESULT: CG_HANDOFF_STOP outcome=stop reason=cguse_failed workflow_exit_code=2' "$clipboard_capture" || fail early_autocopy_stop_marker_missing
printf '%s\n' "$early_output" | grep -Fq 'RESULT: CG_HANDOFF_EARLY_AUTOCOPY_DONE clipboard_exit_code=0' || fail early_autocopy_result_missing
printf '%s\n' 'PASS early_failure_autocopy'

printf 'RESULT: CG_HANDOFF_FIXTURE_PASS outcome=success workflow_exit_code=0\n'
