#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP_BASE="${TMPDIR:-$HOME/.cache/tmp}"
mkdir -p "$TMP_BASE"
SECRET_SCAN_FILE="$(mktemp "$TMP_BASE/termux-toolbox-secret-scan.XXXXXX")"
STATUS_BEFORE="$(mktemp "$TMP_BASE/termux-toolbox-status-before.XXXXXX")"
STATUS_AFTER="$(mktemp "$TMP_BASE/termux-toolbox-status-after.XXXXXX")"
cleanup() { rm -f "$SECRET_SCAN_FILE" "$STATUS_BEFORE" "$STATUS_AFTER"; }
trap cleanup EXIT

echo "scope=termux-toolbox-verify"
echo "root=$ROOT"
echo "tmp_base=$TMP_BASE"
echo

fail=0
inside_git=no
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  inside_git=yes
  git status --porcelain=v2 --untracked-files=all > "$STATUS_BEFORE"
fi

while IFS= read -r -d '' f; do
  rel="${f#./}"
  [ -s "$f" ] || { echo "FAIL empty file=$rel"; fail=1; continue; }
  if LC_ALL=C grep -q $'\r' "$f"; then
    echo "FAIL crlf file=$rel"
    fail=1
  fi
  if head -n 1 "$f" | grep -Eq '^#!.*(bash|sh)([[:space:]]|$)'; then
    if ! bash -n "$f" 2>/dev/null; then
      echo "FAIL syntax file=$rel"
      fail=1
    else
      echo "PASS syntax file=$rel"
    fi
  fi
done < <(find . -type f ! -path './.git/*' -print0)

if [ "$inside_git" = "yes" ]; then
  git diff --check
fi

# Exclude known policy/tooling files that intentionally contain forbidden-pattern definitions.
if grep -RInE '(BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|ghp_[A-Za-z0-9_]+|github_pat_|AKIA[0-9A-Z]{16}|client_secret|refresh_token|access_token|password=|token=)' . \
  --exclude-dir=.git \
  --exclude='verify-termux-toolbox.sh' \
  --exclude='review-termux-public-safety.sh' \
  --exclude='assistant-output-guard.sh' \
  --exclude='secret-guard.sh' >"$SECRET_SCAN_FILE" 2>/dev/null; then
  cat "$SECRET_SCAN_FILE"
  echo "FAIL secret_guard"
  exit 1
fi

# TERMUX_TOOLBOX_VERIFY_ARTIFACT_LANE_BINDING_V2_20260710
for required in \
  'ASSISTANT_OUTPUT_GUARD_ARTIFACT_LANE_BINDING_V2_20260710' \
  'artifact_cgrun_requires_cg_run_file' \
  'manual_lane_tail_after_autotail_optout_forbidden' \
  'manual_lane_tail_without_binding_preflight'
do
  if grep -Fq "$required" tools/assistant-output-guard.sh; then
    echo "PASS assistant_output_guard_contract=$required"
  else
    echo "FAIL assistant_output_guard_contract_missing=$required"
    fail=1
  fi
done

if [[ -f verify/verify-cg-lane-secret-classes.sh ]]; then
  if bash verify/verify-cg-lane-secret-classes.sh; then
    echo "PASS cg_lane_secret_class_contract"
  else
    echo "FAIL cg_lane_secret_class_contract"
    fail=1
  fi
else
  echo "FAIL cg_lane_secret_class_verify_missing"
  fail=1
fi

if [[ -f verify/verify-cg-run-file-termux-shebang.sh ]]; then
  if bash verify/verify-cg-run-file-termux-shebang.sh; then
    echo "PASS cg_run_file_termux_shebang_contract"
  else
    echo "FAIL cg_run_file_termux_shebang_contract"
    fail=1
  fi
else
  echo "FAIL cg_run_file_termux_shebang_verify_missing"
  fail=1
fi

if [[ -f verify/verify-cg-run-file-lock-autocopy.sh ]]; then
  if bash verify/verify-cg-run-file-lock-autocopy.sh; then
    echo "PASS cg_run_file_lock_autocopy_contract"
  else
    echo "FAIL cg_run_file_lock_autocopy_contract"
    fail=1
  fi
else
  echo "FAIL cg_run_file_lock_autocopy_verify_missing"
  fail=1
fi

if [[ -f verify/verify-native-cg-shell-guard.sh ]]; then
  if bash verify/verify-native-cg-shell-guard.sh; then
    echo "PASS native_cg_shell_guard_contract"
  else
    echo "FAIL native_cg_shell_guard_contract"
    fail=1
  fi
else
  echo "FAIL native_cg_shell_guard_verify_missing"
  fail=1
fi

if [[ -f verify/verify-cg-execution-receipt.sh ]]; then
  if bash verify/verify-cg-execution-receipt.sh; then
    echo "PASS cg_execution_receipt_contract"
  else
    echo "FAIL cg_execution_receipt_contract"
    fail=1
  fi
else
  echo "FAIL cg_execution_receipt_verify_missing"
  fail=1
fi

if [ "$inside_git" = "yes" ]; then
  git status --porcelain=v2 --untracked-files=all > "$STATUS_AFTER"
  if cmp -s "$STATUS_BEFORE" "$STATUS_AFTER"; then
    echo "PASS verifier_worktree_immutable"
  else
    echo "FAIL verifier_mutated_worktree"
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "RESULT: TERMUX_TOOLBOX_VERIFY_FAIL"
  exit 1
fi

echo "SECRET_GUARD_PASS_BASIC"
echo "RESULT: TERMUX_TOOLBOX_VERIFY_DONE"
