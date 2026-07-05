#!/usr/bin/env bash
set -euo pipefail

path="${1:-.}"
fail=0
say() { printf '%s\n' "$*"; }
err() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }
pass() { printf 'PASS: %s\n' "$*"; }

say '== host artifact name guard =='
say "path=$path"

while IFS= read -r item; do
  base="$(basename "$item")"
  lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
  if [[ "$base" != "$lower" ]]; then
    err "uppercase_name $item"
  fi
  case "$base" in
    target-*__*|targets-*__*|pixel_local__*|heimnetz__*) pass "name_ok $item" ;;
    *) err "name_policy_mismatch $item" ;;
  esac
done < <(find "$path" -maxdepth 1 -type f 2>/dev/null)

if [[ "$fail" -ne 0 ]]; then
  say 'RESULT: HOST_ARTIFACT_NAME_GUARD_FAIL rc=1'
  exit 1
fi
say 'RESULT: HOST_ARTIFACT_NAME_GUARD_PASS rc=0'
