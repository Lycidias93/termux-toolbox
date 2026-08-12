#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF="$ROOT/bin/cg-handoff"
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
  printf '%s\n' '# cg_handoff_route_class=read-only'
  printf '%s\n' '# cg_handoff_secret_class=redacted'
  printf '%s\n' '# cg_handoff_run_mode=verify'
  printf '%s\n' '# cg_handoff_expected_marker=RESULT: FIXTURE_PASS'
  printf '%s\n' '# CG_HANDOFF_V1_END'
  printf '%s\n' "printf 'RESULT: FIXTURE_PASS\\n'"
} > "$artifact"
chmod 0700 "$artifact"

grep -Fq 'CG_HANDOFF_TTY_TAIL_DRAIN_V1' "$HANDOFF" || fail tty_tail_drain_marker_missing
grep -Fq 'drain_pending_tty_input' "$HANDOFF" || fail tty_tail_drain_call_missing

for name in cgprep cclear cgcurrent; do
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'exit 0'
  } > "$WORK/bin/$name"
  chmod 0700 "$WORK/bin/$name"
done

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'printf "CGUSE:%s\n" "$*"'
} > "$WORK/bin/cguse"
chmod 0700 "$WORK/bin/cguse"

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'printf "RUNFILE:%s\n" "$*"'
  printf '%s\n' 'printf "MARKER:%s\n" "${CGFLOW_EXPECTED_MARKER:-}"'
} > "$WORK/bin/cg-run-file"
chmod 0700 "$WORK/bin/cg-run-file"

sha="$(sha256sum "$artifact" | awk '{print $1}')"
output="$(PATH="$WORK/bin:$PATH" CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" TMPDIR="$WORK/tmp" bash "$HANDOFF" "$(basename "$artifact")" "$sha")"
printf '%s\n' "$output"

printf '%s\n' "$output" | grep -Fq 'CGUSE:chat-fixture pixel pixel read-only redacted' || fail cguse_binding_failed
printf '%s\n' "$output" | grep -Fq 'RUNFILE:' || fail run_file_missing
printf '%s\n' "$output" | grep -Fq ' verify pixel pixel read-only redacted' || fail run_file_args_failed
printf '%s\n' "$output" | grep -Fq 'MARKER:RESULT: FIXTURE_PASS' || fail expected_marker_failed

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'exit 7'
} > "$WORK/bin/cg-run-file"
chmod 0700 "$WORK/bin/cg-run-file"
set +e
PATH="$WORK/bin:$PATH" CG_HANDOFF_TTY_DRAIN=0 CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" TMPDIR="$WORK/tmp" bash "$HANDOFF" "$(basename "$artifact")" "$sha" >/dev/null 2>&1
run_rc=$?
set -e
[[ "$run_rc" -eq 7 ]] || fail run_file_exit_status_not_preserved

set +e
bad_output="$(PATH="$WORK/bin:$PATH" CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" TMPDIR="$WORK/tmp" bash "$HANDOFF" "$(basename "$artifact")" "$(printf '0%.0s' {1..64})" 2>&1)"
bad_rc=$?
set -e
[[ "$bad_rc" -eq 2 ]] || fail bad_hash_rc_failed
printf '%s\n' "$bad_output" | grep -Fq 'reason=source_sha_mismatch' || fail bad_hash_reason_failed

printf 'RESULT: CG_HANDOFF_FIXTURE_PASS outcome=success workflow_exit_code=0\n'
