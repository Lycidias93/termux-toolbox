#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cg-run-file-lock-autocopy.XXXXXX")"
HOST_PATH="${PATH:?PATH is required}"
HOST_LD_PRELOAD="${LD_PRELOAD:-}"
trap 'rm -rf "$TMP_ROOT"' EXIT
BIN="$TMP_ROOT/bin"; HOME_DIR="$TMP_ROOT/home"; STATE="$HOME_DIR/.chatgpt-lanes"; OUT="$HOME_DIR/.chatgpt-output"; TMP="$TMP_ROOT/tmp"
mkdir -p "$BIN" "$STATE/lanes/chat-alpha" "$STATE/locks" "$OUT" "$TMP"
install -m0755 "$ROOT/bin/cg-run-file" "$BIN/cg-run-file"
install -m0755 "$ROOT/bin/cg-run-file-driver-v1" "$BIN/cg-run-file-driver-v1"
cat >"$BIN/cgrun" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
run_id="${CG_RUN_ID:-none}"
out="${CG_OUTPUT_DIR:-$HOME/.chatgpt-output}"
log="$out/runs/$run_id/run.log"
mkdir -p "$(dirname "$log")"
: >"$log"
printf '%s\n' 'RESULT: CGRUN_STUB_ENTER' | tee -a "$log"
set +e
if [ "${1:-}" = "--exec" ]; then
  shift
  "$@" 2>&1 | tee -a "$log"
  rc="${PIPESTATUS[0]}"
else
  bash -c "${1:-}" 2>&1 | tee -a "$log"
  rc="${PIPESTATUS[0]}"
fi
set -e
printf 'RESULT: CGRUN_STUB_EXIT command_exit_code=%s\n' "$rc" | tee -a "$log"
exit "$rc"
STUB
chmod 0755 "$BIN/cgrun"
printf '%s\n' chat-alpha >"$STATE/current_lane"
printf '%s\n' 'CG_LANE_ID=chat-alpha' 'CG_LANE_SCOPE=pixel' 'CG_LANE_HOST=pixel' 'CG_LANE_ROUTE_CLASS=none' 'CG_LANE_SECRET_CLASS=sensitive' >"$STATE/lanes/chat-alpha/meta.env"
cat >"$TMP/payload.sh" <<'PAYLOAD'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'RESULT: PAYLOAD_OK'
PAYLOAD
chmod 0755 "$TMP/payload.sh"
run_clean() { env -i PATH="$BIN:$HOST_PATH" LD_PRELOAD="$HOST_LD_PRELOAD" HOME="$HOME_DIR" TMPDIR="$TMP" CG_LANE_STATE_DIR="$STATE" CG_OUTPUT_DIR="$OUT" bash "$BIN/cg-run-file" "$@"; }

stale_lock="$STATE/locks/lane-chat-alpha"
mkdir -p "$stale_lock"; printf '%s\n' old-interrupted-run >"$stale_lock/run_id"; printf '%s\n' 999999 >"$stale_lock/pid"; printf '%s\n' '2026-08-09T16:29:57+02:00' >"$stale_lock/created_at"
stale_out="$TMP_ROOT/stale.out"
run_clean "$TMP/payload.sh" run pixel >"$stale_out" 2>&1
grep -Fq 'RESULT: CGRUN_STUB_ENTER' "$stale_out"
grep -Fq 'RESULT: CG_MULTILANE_STALE_LOCK_RECOVERED lock=lane-chat-alpha holder=old-interrupted-run' "$stale_out"
grep -Fq 'RESULT: PAYLOAD_OK' "$stale_out"
grep -Fq 'RESULT: CG_MULTILANE_RUN_FILE_OK outcome=success' "$stale_out"
[ ! -d "$stale_lock" ]

mkdir -p "$stale_lock"; printf '%s\n' live-run >"$stale_lock/run_id"; printf '%s\n' "$$" >"$stale_lock/pid"; awk '{print $22}' "/proc/$$/stat" >"$stale_lock/pid_start_ticks"; printf '%s\n' "$(date -Is)" >"$stale_lock/created_at"
live_out="$TMP_ROOT/live.out"
set +e; run_clean "$TMP/payload.sh" run pixel >"$live_out" 2>&1; live_rc=$?; set -e
[ "$live_rc" -eq 75 ]
grep -Fq 'RESULT: CGRUN_STUB_ENTER' "$live_out"
grep -Fq 'FAIL: lock_busy lock=lane-chat-alpha holder=live-run' "$live_out"
grep -Fq 'RESULT: CG_MULTILANE_LOCK_BUSY outcome=blocked lock=lane-chat-alpha holder=live-run workflow_exit_id=WORKFLOW_CONCURRENCY_RETRY workflow_exit_code=75' "$live_out"
grep -Fq 'RESULT: CGRUN_STUB_EXIT command_exit_code=75' "$live_out"
[ -d "$stale_lock" ]
printf '%s\n' 'PASS stale_lock_is_recovered' 'PASS live_lock_remains_blocked' 'PASS lock_busy_occurs_inside_cgrun_exec_path'
printf '%s\n' 'RESULT: CG_RUN_FILE_LOCK_AUTOCOPY_VERIFY_DONE outcome=success workflow_exit_code=0'
