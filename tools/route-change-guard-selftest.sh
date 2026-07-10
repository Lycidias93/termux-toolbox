#!/usr/bin/env bash
set -euo pipefail

guard="tools/route-change-guard.sh"

clear_paths=(
  CHANGELOG.md
  tools/chatctx
  tools/route-change-guard.sh
  config/workflow-scopes.tsv
  context-packs/host_operations.md
)

sensitive_paths=(
  dns/config.yml
  docs/dns-ha-route.md
  network/dhcp.conf
  config/tailscale.json
  runbooks/fritzbox/network.md
  services/keepalived/vip.conf
  wireguard/wg0.conf
)

for path in "${clear_paths[@]}"; do
  if "$guard" --classify-path "$path" >/dev/null; then
    echo "FAIL false_positive path=$path"
    exit 10
  fi
  echo "PASS clear path=$path"
done

for path in "${sensitive_paths[@]}"; do
  if ! "$guard" --classify-path "$path" >/dev/null; then
    echo "FAIL false_negative path=$path"
    exit 11
  fi
  echo "PASS sensitive path=$path"
done

echo "RESULT: ROUTE_CHANGE_GUARD_SELFTEST_PASS rc=0"
