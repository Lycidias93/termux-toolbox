#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cg-run-file-lock-autocopy.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

BIN="$TMP_ROOT/bin"
HOME_DIR="$TMP_ROOT/home"
STATE="$HOME_DIR/.chatgpt-lanes"
OUT="$HOME_DIR/.chatgpt-output"
TMP="$TMP_ROOT/tmp"
mkdir -p "$BIN" "$STATE/lanes/chat-alpha" "$STATE/locks" "$OUT" "$TMP"

install -m 0755 "$ROOT/bin/cg-run-file" "$BIN/cg-run-file"
install -m 0755 "$ROOT/bin/cg-run-file-driver-v1" "$BIN/cg-run-file-driver-v1"

cat > "$BIN/cgrun" <<'STUB'
#!/usr/bin/env bash
set -u
printf '%s\n' 'RESULT: CGRUN_STUB_ENTER'
set +e
bash -c "$1"
rc=$?
set -e
printf 'RESULT: CGRUN_STUB_EXIT command_exit_code=%s\n' "$rc"
exit "$rc"
STUB
chmod 0755 "$BIN/cgrun"

printf '%s\n' 'chat-alpha' > "$STATE/current_lane"
{
  printf '%s\n' 'CG_LANE_ID=chat-alpha'
  printf '%s\n' 'CG_LANE_SCOPE=pixel'
  printf '%s\n' 'CG_LANE_HOST=pixel'
  printf '%s\n' 'CG_LANE_ROUTE_CLASS=none'
  printf '%s\n' 'CG_LANE_SECRET_CLASS=sensitive'
} > "$STATE/lanes/chat-alpha/meta.env"

cat > "$TMP/payload.sh" <<'PAYLOAD'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'RESULT: PAYLOAD_OK'
PAYLOAD
chmod 0755 "$TMP/payload.sh"

run_clean() {
  env -i \
    PATH="$BIN:/usr/bin:/bin" \
    HOME="$HOME_DIR" \
    TMPDIR="$TMP" \
    CG_LANE_STATE_DIR="$STATE" \
    CG_OUTPUT_DIR="$OUT" \
    bash "$BIN/cg-run-file" "$@"
}

stale_lock="$STATE/locks/lane-chat-alpha"
mkdir -p "$stale_lock"
printf '%s\n' 'old-interrupted-run' > "$stale_lock/run_id"
printf '%s\n' '999999' > "$stale_lock/pid"
printf '%s\n' '2026-08-09T16:29:57+02:00' > "$stale_lock/created_at"

stale_out="$TMP_ROOT/stale.out"
run_clean "$TMP/payload.sh" run pixel > "$stale_out" 2>&1
grep -Fq 'RESULT: CGRUN_STUB_ENTER' "$stale_out"
grep -Fq 'RESULT: CG_MULTILANE_STALE_LOCK_RECOVERED lock=lane-chat-alpha holder=old-interrupted-run' "$stale_out"
grep -Fq 'RESULT: PAYLOAD_OK' "$stale_out"
grep -Fq 'RESULT: CG_MULTILANE_RUN_FILE_OK outcome=success' "$stale_out"
[ ! -d "$stale_lock" ]

mkdir -p "$stale_lock"
printf '%s\n' 'live-run' > "$stale_lock/run_id"
printf '%s\n' "$$" > "$stale_lock/pid"
awk '{print $22}' "/proc/$$/stat" > "$stale_lock/pid_start_ticks"
printf '%s\n' "$(date -Is)" > "$stale_lock/created_at"

live_out="$TMP_ROOT/live.out"
live_rc=0
if run_clean "$TMP/payload.sh" run pixel > "$live_out" 2>&1; then
  printf '%s\n' 'FAIL expected_live_lock_block'
  exit 1
else
  live_rc=$?
fi
[ "$live_rc" -eq 75 ]
grep -Fq 'RESULT: CGRUN_STUB_ENTER' "$live_out"
grep -Fq 'FAIL: lock_busy lock=lane-chat-alpha holder=live-run' "$live_out"
grep -Fq 'RESULT: CG_MULTILANE_LOCK_BUSY outcome=blocked lock=lane-chat-alpha holder=live-run workflow_exit_code=75' "$live_out"
grep -Fq 'RESULT: CGRUN_STUB_EXIT command_exit_code=75' "$live_out"
[ -d "$stale_lock" ]

printf '%s\n' 'PASS stale_lock_is_recovered'
printf '%s\n' 'PASS live_lock_remains_blocked'
printf '%s\n' 'PASS lock_busy_occurs_inside_cgrun_path'
printf '%s\n' 'RESULT: CG_RUN_FILE_LOCK_AUTOCOPY_VERIFY_DONE outcome=success workflow_exit_code=0'
