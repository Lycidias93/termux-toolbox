#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

path_is_route_sensitive() {
  local path="$1"
  local tokens

  case "$path" in
    tools/route-change-guard.sh|tools/route-change-guard-selftest.sh)
      return 1
      ;;
  esac

  tokens="$(printf "%s\n" "$path" | tr "[:upper:]" "[:lower:]" | tr -cs "[:alnum:]" "\n")"

  printf "%s\n" "$tokens" | grep -Eq "^(dns[0-9]*|adguard|unbound|ha|vip[0-9]*|route|routes|routing|wireguard[0-9]*|wg[0-9]+|tailscale|magicdns|subnet|fritz|fritzbox|network[0-9]*|networking|networkd|netplan|dhcp[0-9]*|keepalived|iptables|nftables)$"
}

if [ "${1:-}" = "--classify-path" ]; then
  path="${2:-}"
  [ -n "$path" ] || { echo "FAIL missing_path"; exit 2; }

  if path_is_route_sensitive "$path"; then
    echo "sensitive $path"
    exit 0
  fi

  echo "clear $path"
  exit 1
fi

scope="${1:-all}"
ack="${HEIMNETZ_ROUTEGUARD_ACK:-0}"
fail=0

say() { printf "%s\n" "$*"; }
err() { printf "FAIL: %s\n" "$*" >&2; fail=1; }
pass() { printf "PASS: %s\n" "$*"; }

say "== route change guard =="
say "scope=$scope"
say "repo_root=$repo_root"
say "ack=$ack"

changed="$({
  git diff --cached --name-only
  git diff --name-only
  git ls-files --others --exclude-standard
} | sort -u)"

route_hits="$(
  printf "%s\n" "$changed" | while IFS= read -r path; do
    [ -n "$path" ] || continue
    if path_is_route_sensitive "$path"; then
      printf "%s\n" "$path"
    fi
  done
)"

if [ -n "$route_hits" ] && [ "$ack" != "1" ]; then
  printf "%s\n" "$route_hits" >&2
  err "route_sensitive_paths_changed_without_ack"
else
  pass "routeguard_clear_or_acknowledged"
fi

if [ "$fail" != "0" ]; then
  say "RESULT: ROUTE_CHANGE_GUARD_FAIL rc=1"
  exit 1
fi

say "RESULT: ROUTE_CHANGE_GUARD_PASS rc=0"
