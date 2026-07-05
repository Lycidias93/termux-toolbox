#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"
fail=0
say() { printf '%s\n' "$*"; }
err() { printf 'FAIL: %s\n' "$*" >&2; fail=1; }
pass() { printf 'PASS: %s\n' "$*"; }

check_lf() {
  local p="$1"
  if [[ ! -f "$p" ]]; then
    err "missing $p"
    return
  fi
  if LC_ALL=C grep -q $'\r' "$p"; then
    err "crlf_present $p"
  else
    pass "lf_only $p"
  fi
}

check_bash_script() {
  local p="$1"
  if [[ ! -s "$p" ]]; then
    err "missing_or_empty $p"
    return
  fi
  check_lf "$p"
  local first
  first="$(sed -n '1p' "$p")"
  if [[ "$first" == '#!/usr/bin/env bash' ]]; then
    pass "shebang_ok $p"
  else
    err "shebang_wrong $p"
  fi
  if [[ -x "$p" ]]; then
    pass "executable $p"
  else
    err "not_executable $p"
  fi
  if bash -n "$p"; then
    pass "bash_syntax $p"
  else
    err "bash_syntax $p"
  fi
  local lt='<'; local hd="${lt}${lt}"; local hs="${lt}${lt}${lt}"
  if LC_ALL=C grep -Fq "$hd" "$p" || LC_ALL=C grep -Fq "$hs" "$p"; then
    err "heredoc_or_herestring_present $p"
  else
    pass "no_heredoc_herestring $p"
  fi
}

say '== workflow guard =='
say "repo_root=$repo_root"

for p in tools/chatctx tools/cgflow; do
  check_bash_script "$p"
done

if [[ -f WORKFLOW_BASELINE.md ]]; then
  check_lf WORKFLOW_BASELINE.md
  pass 'workflow_baseline_doc_present'
elif [[ -f WORKFLOW_TOOLBOX.md ]]; then
  check_lf WORKFLOW_TOOLBOX.md
  pass 'workflow_toolbox_doc_present'
else
  err 'workflow_baseline_doc_missing'
fi

if [[ -f .workflow-baseline ]]; then
  check_lf .workflow-baseline
  pass 'workflow_baseline_marker_present'
elif [[ -f WORKFLOW_TOOLBOX.md ]]; then
  pass 'workflow_toolbox_marker_implicit'
else
  err 'workflow_baseline_marker_missing'
fi

if [[ "$fail" -ne 0 ]]; then
  say 'RESULT: WORKFLOW_GUARD_FAIL rc=1'
  exit 1
fi
say 'RESULT: WORKFLOW_GUARD_PASS rc=0'
