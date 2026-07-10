#!/usr/bin/env bash
set -euo pipefail

base_dir="${1:-$HOME/src}"
fail=0
checked=0
skipped=0

repos=(
  audio-safe-volume-battery-aware
  pixel-10-pro-xl-thermal-fix
  Sortify-Dispatch
  asvd-bt-type-helper
  ssh-drop-dispatcher
  UnlimitedOnDemand_Auto_Reply
  plants-home-inventory
  module-reflash-trigger
  magisk-boot-watch
  pi3-ops
  heimnetz-geraete
)

for repo in "${repos[@]}"; do
  dir="$base_dir/$repo"
  echo "== consumer $repo =="

  if [ ! -d "$dir/.git" ]; then
    echo "SKIP checkout_absent path=$dir"
    skipped=$((skipped + 1))
    continue
  fi

  checked=$((checked + 1))

  for tool in chatctx cgflow; do
    path="$dir/tools/$tool"
    if [ ! -x "$path" ]; then
      echo "FAIL wrapper_missing_or_not_executable path=$path"
      fail=1
    fi
  done

  if ! (cd "$dir" && tools/chatctx pi4 >/dev/null); then
    echo "FAIL consumer_pi4_scope repo=$repo"
    fail=1
  else
    echo "PASS consumer_pi4_scope repo=$repo"
  fi

  if ! (cd "$dir" && tools/chatctx dns-ha-route >/dev/null); then
    echo "FAIL consumer_special_scope repo=$repo"
    fail=1
  else
    echo "PASS consumer_special_scope repo=$repo"
  fi
done

echo "checked=$checked"
echo "skipped=$skipped"

[ "$checked" -gt 0 ] || {
  echo "RESULT: WORKFLOW_SCOPE_CONSUMER_AUDIT_FAIL rc=2"
  exit 2
}

if [ "$fail" != "0" ]; then
  echo "RESULT: WORKFLOW_SCOPE_CONSUMER_AUDIT_FAIL rc=1"
  exit 1
fi

echo "RESULT: WORKFLOW_SCOPE_CONSUMER_AUDIT_PASS rc=0"
