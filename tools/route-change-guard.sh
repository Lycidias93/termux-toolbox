#!/usr/bin/env bash
set -euo pipefail

scope="${1:-all}"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"
ack="${HEIMNETZ_ROUTEGUARD_ACK:-0}"
fail=0

say() { printf '%s\n' "$*"; }
err() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }
pass() { printf 'PASS: %s\n' "$*"; }

say '== route change guard =='
say "scope=$scope"
say "repo_root=$repo_root"
say "ack=$ack"

changed="$(git diff --cached --name-only 2>/dev/null; git diff --name-only 2>/dev/null)"
route_hits="$(printf '%s\n' "$changed" | grep -Ei '(dns|ha|vip|route|wireguard|wg|tailscale|magicdns|subnet|fritz|network|dhcp)' || true)"

if [[ -n "$route_hits" && "$ack" != '1' ]]; then
  printf '%s\n' "$route_hits" >&2
  err 'route_sensitive_paths_changed_without_ack'
else
  pass 'routeguard_clear_or_acknowledged'
fi

if [[ "$fail" -ne 0 ]]; then
  say 'RESULT: ROUTE_CHANGE_GUARD_FAIL rc=1'
  exit 1
fi
say 'RESULT: ROUTE_CHANGE_GUARD_PASS rc=0'
