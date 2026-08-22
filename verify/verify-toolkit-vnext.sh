#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="${TMPDIR:-${HOME:-.}/.cache/tmp}"
mkdir -p "$TMP_BASE"
WORK="$(mktemp -d "$TMP_BASE/termux-toolkit-vnext-verify.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  printf 'RESULT: TOOLKIT_VNEXT_VERIFY_FAIL workflow_exit_code=1\n' >&2
  exit 1
}

for script in cglint cgdoctor cgfind cgfail cgnotify; do
  path="$ROOT/bin/$script"
  [[ -s "$path" ]] || fail "missing_script path=$path"
  bash -n "$path" || fail "syntax path=$path"
  bash "$path" --help >/dev/null 2>&1 || fail "help_contract script=$script"
  printf 'PASS: script_contract script=%s\n' "$script"
done

printf '%s\n' 'alpha marker' 'beta marker' > "$WORK/search.txt"
bash "$ROOT/bin/cgfind" 'beta marker' "$WORK" > "$WORK/cgfind.out"
grep -Fq 'RESULT: CGFIND_DONE' "$WORK/cgfind.out" || fail "cgfind_result_missing"
grep -Fq 'search.txt' "$WORK/cgfind.out" || fail "cgfind_match_missing"
printf 'PASS: cgfind_fixture\n'

printf '%s\n' \
  'noise line' \
  'FAIL: fixture_failure reason=test' \
  'command_exit_code=7' \
  'RESULT: FIXTURE_DONE outcome=failed workflow_exit_code=7' > "$WORK/run.log"
bash "$ROOT/bin/cgfail" "$WORK/run.log" > "$WORK/cgfail.out"
grep -Fq 'FAIL: fixture_failure reason=test' "$WORK/cgfail.out" || fail "cgfail_failure_marker_missing"
grep -Fq 'RESULT: FIXTURE_DONE' "$WORK/cgfail.out" || fail "cgfail_result_marker_missing"
grep -Fq 'RESULT: CGFAIL_DONE' "$WORK/cgfail.out" || fail "cgfail_completion_missing"
printf 'PASS: cgfail_fixture\n'

bash "$ROOT/bin/cgnotify" --dry-run PASS 'fixture notification' > "$WORK/cgnotify.out"
grep -Fq 'RESULT: CGNOTIFY_DONE mode=dry_run' "$WORK/cgnotify.out" || fail "cgnotify_dry_run_missing"
printf 'PASS: cgnotify_fixture\n'

printf 'RESULT: TOOLKIT_VNEXT_VERIFY_DONE workflow_exit_code=0\n'
