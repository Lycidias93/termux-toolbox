#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

mode="${1:-diff}"
case "$mode" in
  diff|cached|all) ;;
  -h|--help)
    printf '%s\n' 'Usage: tools/secret-guard.sh [diff|cached|all]'
    printf '%s\n' 'Scans git diffs and untracked text files for high-confidence secret smells without printing matching secret material.'
    printf '%s\n' 'Workflow metadata such as CGFLOW_RUN_TOKEN is not a credential and is ignored.'
    exit 0
    ;;
  *)
    printf 'ERROR: unknown mode: %s\n' "$mode" >&2
    exit 2
    ;;
esac

secret_core='(-----BEGIN [A-Z ]*(PRIVATE|RSA|OPENSSH|EC|PGP)[A-Z ]*-----|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._~+/=-]{20,}|(^|[^A-Za-z0-9_])(password|passwd|token|secret|api[_-]?key|client[_-]?secret|private[_-]?key|preshared[_-]?key|psk)[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9._~+/=:@-]{12,}|(^|[^A-Za-z0-9_])(TAILSCALE_AUTHKEY|GH_TOKEN|GITHUB_TOKEN|BOT_TOKEN|OPENAI_API_KEY|TELEGRAM[^[:space:]]*TOKEN)[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9._~+/=:@-]{12,}|(^|[^A-Za-z0-9_])wg[_-]?private[[:space:]]*=[[:space:]]*["'"'"']?[A-Za-z0-9._~+/=:@-]{12,})'

is_allowed_workflow_metadata_line() {
  local line="$1"
  case "$line" in
    *CGFLOW_RUN_TOKEN=*|*CGFLOW_LANE=*|*CGFLOW_SCOPE=*|*CGFLOW_HOST=*|*CGFLOW_ROUTE_CLASS=*|*CGFLOW_SECRET_CLASS=*|*CGFLOW_EXPECTED_MARKER=*) return 0 ;;
    *run_token=*|*lane=*|*scope=*|*host=*|*route_class=*|*secret_class=*|*expect_marker=*) return 0 ;;
    *) return 1 ;;
  esac
}

line_has_secret() {
  local line="$1"
  is_allowed_workflow_metadata_line "$line" && return 1
  printf '%s\n' "$line" | LC_ALL=C grep -Eiq "$secret_core"
}

scan_stream() {
  local hit=0 line=''
  while IFS= read -r line; do
    line_has_secret "$line" && hit=1
  done
  [[ "$hit" -eq 0 ]]
}

scan_diff() {
  local label="$1" cmd_a="$2" cmd_b="$3" hit=0 line=''
  while IFS= read -r line; do
    case "$line" in
      '+++'*) continue ;;
      '+'*) ;;
      *) continue ;;
    esac
    if line_has_secret "$line"; then
      hit=1
    fi
  done < <("$cmd_a" "$cmd_b" --unified=0)
  if [[ "$hit" -eq 1 ]]; then
    printf 'FAIL: secret_smell_%s\n' "$label"
    return 1
  fi
  printf 'PASS: secret_smell_%s\n' "$label"
}

scan_untracked() {
  local hit=0 count=0 f='' line=''
  while IFS= read -r -d '' f; do
    count=$((count + 1))
    if ! LC_ALL=C grep -Iq . "$f" 2>/dev/null; then
      continue
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
      if line_has_secret "$line"; then
        hit=1
      fi
    done < "$f"
  done < <(git ls-files --others --exclude-standard -z)
  if [[ "$hit" -eq 1 ]]; then
    printf '%s\n' 'FAIL: secret_smell_untracked'
    printf 'untracked_files_scanned=%s\n' "$count"
    return 1
  fi
  printf '%s\n' 'PASS: secret_smell_untracked'
  printf 'untracked_files_scanned=%s\n' "$count"
}

printf '%s\n' '== secret guard =='
printf 'scope=%s\n' "$mode"
printf 'repo_root=%s\n' "$repo_root"

rc=0
case "$mode" in
  diff)
    scan_diff worktree git diff || rc=1
    scan_untracked || rc=1
    ;;
  cached)
    scan_diff cached git diff --cached || rc=1
    ;;
  all)
    scan_diff worktree git diff || rc=1
    scan_diff cached git diff --cached || rc=1
    scan_untracked || rc=1
    ;;
esac

if [[ "$rc" -eq 0 ]]; then
  printf '%s\n' 'RESULT: SECRET_GUARD_PASS rc=0'
else
  printf '%s\n' 'RESULT: SECRET_GUARD_FAIL rc=1'
fi
exit "$rc"
