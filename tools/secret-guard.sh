#!/usr/bin/env bash
set -euo pipefail

scope="${1:-all}"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"
fail=0

say() { printf '%s\n' "$*"; }
err() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }
pass() { printf 'PASS: %s\n' "$*"; }

say '== secret guard =='
say "scope=$scope"
say "repo_root=$repo_root"

patterns=(
  'BEGIN OPENSSH PRIVATE KEY'
  'BEGIN RSA PRIVATE KEY'
  'wg_private_key'
  'password='
  'PASS='
  'TOKEN='
  'SECRET='
  'api_key='
)

files="$(git ls-files 2>/dev/null || find . -type f -not -path './.git/*')"
for pat in "${patterns[@]}"; do
  if printf '%s\n' "$files" | xargs grep -In -- "$pat" >/tmp/workflow_secret_guard_hits.$$ 2>/dev/null; then
    cat /tmp/workflow_secret_guard_hits.$$ >&2
    err "secret_pattern_present $pat"
  else
    pass "secret_pattern_absent $pat"
  fi
  rm -f /tmp/workflow_secret_guard_hits.$$
done

if [[ "$fail" -ne 0 ]]; then
  say 'RESULT: SECRET_GUARD_FAIL rc=1'
  exit 1
fi
say 'RESULT: SECRET_GUARD_PASS rc=0'
