#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/cg-lane.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cg-lane-secret-classes.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass=0
fail=0

check_accept() {
  local secret_class="$1"
  local lane="secret-${secret_class}"
  local state="$TMP_ROOT/state-${secret_class}"
  local output="$TMP_ROOT/output-${secret_class}"

  if CG_LANE_STATE_DIR="$state" CG_OUTPUT_DIR="$output" \
       bash "$SCRIPT" use "$lane" pixel pixel none "$secret_class" >/dev/null 2>&1; then
    printf 'PASS secret_class_accept=%s\n' "$secret_class"
    pass=$((pass + 1))
  else
    printf 'FAIL secret_class_rejected=%s\n' "$secret_class"
    fail=$((fail + 1))
  fi
}

for secret_class in none public redacted possible sensitive; do
  check_accept "$secret_class"
done

if CG_LANE_STATE_DIR="$TMP_ROOT/state-invalid" CG_OUTPUT_DIR="$TMP_ROOT/output-invalid" \
     bash "$SCRIPT" use secret-invalid pixel pixel none invalid >/dev/null 2>&1; then
  printf 'FAIL unknown_secret_class_accepted\n'
  fail=$((fail + 1))
else
  printf 'PASS unknown_secret_class_rejected\n'
  pass=$((pass + 1))
fi

if grep -Fq 'secret_class_sensitive_requires_CGRUN_AUTO_TAIL_0' "$SCRIPT"; then
  printf 'FAIL obsolete_sensitive_autotail_guard_present\n'
  fail=$((fail + 1))
else
  printf 'PASS obsolete_sensitive_autotail_guard_absent\n'
  pass=$((pass + 1))
fi

printf 'pass_count=%s\n' "$pass"
printf 'fail_count=%s\n' "$fail"

if [[ "$fail" -ne 0 ]]; then
  printf 'RESULT: CG_LANE_SECRET_CLASS_VERIFY_FAIL rc=1\n'
  exit 1
fi

printf 'RESULT: CG_LANE_SECRET_CLASS_VERIFY_DONE rc=0\n'
