#!/usr/bin/env bash
set -euo pipefail

path="${1:-.}"
fail=0
say() { printf '%s\n' "$*"; }
err() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }
pass() { printf 'PASS: %s\n' "$*"; }

say '== assistant output guard =='
say "path=$path"

if find "$path" -type f -not -path '*/.git/*' -print0 | xargs -0 grep -In '```bash' >/tmp/workflow_output_guard_hits.$$ 2>/dev/null; then
  cat /tmp/workflow_output_guard_hits.$$ >&2
  err 'raw_bash_codeblock_marker_present'
else
  pass 'no_raw_bash_codeblock_marker'
fi
rm -f /tmp/workflow_output_guard_hits.$$

if [[ "$fail" -ne 0 ]]; then
  say 'RESULT: ASSISTANT_OUTPUT_GUARD_FAIL rc=1'
  exit 1
fi
say 'RESULT: ASSISTANT_OUTPUT_GUARD_PASS rc=0'
