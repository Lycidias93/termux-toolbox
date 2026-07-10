#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"
registry="config/workflow-scopes.tsv"
tab="$(printf "\t")"
output_root="$HOME/.chatgpt-output/workflow-scope-verify"
mkdir -p "$output_root"

expected=(
  repo
  generic
  workflow-baseline
  pixel
  pixel-dispatcher
  pi3
  pi4
  berylax
  pi-host-drop
  dns-ha-route
  pi4-takeout
  zeropi2
  zeropi2-edge
  omen
)

[[ -s "$registry" ]] || { echo "FAIL registry_missing"; exit 10; }

registry_count=0
first=1
while IFS="$tab" read -r scope class pack card host route; do
  if [[ "$first" == "1" ]]; then
    first=0
    continue
  fi
  [[ -n "$scope" ]] || continue
  registry_count=$((registry_count + 1))
  [[ -s "$pack" ]] || { echo "FAIL missing_pack scope=$scope path=$pack"; exit 11; }
  [[ -s "$card" ]] || { echo "FAIL missing_card scope=$scope path=$card"; exit 12; }
done < "$registry"

[[ "$registry_count" == "${#expected[@]}" ]] || {
  echo "FAIL registry_count expected=${#expected[@]} actual=$registry_count"
  exit 13
}

list_output="$(tools/chatctx --list)"
for scope in "${expected[@]}"; do
  count=0
  first=1
  while IFS="$tab" read -r row_scope row_class row_pack row_card row_host row_route; do
    if [[ "$first" == "1" ]]; then
      first=0
      continue
    fi
    [[ "$row_scope" == "$scope" ]] && count=$((count + 1))
  done < "$registry"
  [[ "$count" == "1" ]] || { echo "FAIL registry_scope_count scope=$scope count=$count"; exit 14; }
  printf "%s\n" "$list_output" | grep -qx "$scope" || { echo "FAIL list_missing scope=$scope"; exit 15; }
  tools/chatctx "$scope" > "$output_root/chatctx-$scope.log"
  grep -q "scope=$scope" "$output_root/chatctx-$scope.log"
  HEIMNETZ_STATE_GATE_DECISION=VERIFY-ONLY tools/cgflow "$scope" verify-only none > "$output_root/cgflow-$scope.log"
  grep -q "RESULT: CGFLOW_PASS rc=0" "$output_root/cgflow-$scope.log"
  echo "PASS scope=$scope"
done

echo "scope_count=${#expected[@]}"
echo "output_root=$output_root"
echo "RESULT: WORKFLOW_SCOPE_VERIFY_PASS rc=0"
