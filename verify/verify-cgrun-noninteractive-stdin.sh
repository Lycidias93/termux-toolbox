#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="${CGRUN_CORE_PATH:-$ROOT/bin/cgrun-core-v95}"
TMP_BASE="${TMPDIR:-${TMP:-/tmp}}"

fail() {
  printf 'FAIL: %s\n' "$1"
  printf 'RESULT: CGRUN_NONINTERACTIVE_STDIN_VERIFY_FAIL\n'
  exit 1
}

[ -s "$CORE" ] || fail "core_missing path=$CORE"
bash -n "$CORE" || fail "core_syntax"
grep -Fq 'AUTOCLIP_V95_STDIN_CLOSED' "$CORE" || fail "stdin_closed_marker_missing"
grep -Fq 'stdin_mode=%s' "$CORE" || fail "stdin_mode_metadata_missing"
grep -Fq 'bash -lc "$COMMAND_TEXT" </dev/null' "$CORE" || fail "stdin_dev_null_redirect_missing"

mkdir -p "$TMP_BASE"
work="$(mktemp -d "$TMP_BASE/cgrun-stdin-verify.XXXXXX")"
cleanup() { rm -rf "$work" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

out="$work/out"
mkdir -p "$out"
probe='if IFS= read -r unexpected_value; then printf "UNEXPECTED_STDIN_DATA=%s\n" "$unexpected_value"; exit 91; else printf "RESULT: CGRUN_STDIN_EOF_PASS\n"; fi'

if command -v timeout >/dev/null 2>&1; then
  CG_OUTPUT_DIR="$out" CGRUN_HEARTBEAT_SECONDS=0 timeout 5 bash "$CORE" "$probe" >"$work/stdout" 2>"$work/stderr" \
    || fail "core_probe_nonzero_or_timeout"
else
  CG_OUTPUT_DIR="$out" CGRUN_HEARTBEAT_SECONDS=0 bash "$CORE" "$probe" >"$work/stdout" 2>"$work/stderr" \
    || fail "core_probe_nonzero"
fi

log="$out/latest.log"
[ -s "$log" ] || fail "latest_log_missing"
grep -Fq 'stdin_mode=dev-null' "$log" || fail "stdin_mode_not_logged"
grep -Fq 'RESULT: CGRUN_STDIN_EOF_PASS' "$log" || fail "stdin_eof_marker_missing"
! grep -Fq 'UNEXPECTED_STDIN_DATA=' "$log" || fail "stdin_was_inherited"

printf '%s\n' 'PASS cgrun_stdin_is_closed'
printf '%s\n' 'PASS prompt_capable_payload_gets_eof'
printf '%s\n' 'RESULT: CGRUN_NONINTERACTIVE_STDIN_VERIFY_PASS'
