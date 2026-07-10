#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TMP_BASE="${TMPDIR:-$HOME/.cache/tmp}"
mkdir -p "$TMP_BASE"
SECRET_SCAN_FILE="$(mktemp "$TMP_BASE/termux-toolbox-secret-scan.XXXXXX")"
cleanup() { rm -f "$SECRET_SCAN_FILE"; }
trap cleanup EXIT

echo "scope=termux-toolbox-verify"
echo "root=$ROOT"
echo "tmp_base=$TMP_BASE"
echo

fail=0

while IFS= read -r -d '' f; do
  rel="${f#./}"
  [ -s "$f" ] || { echo "FAIL empty file=$rel"; fail=1; continue; }
  if LC_ALL=C grep -q $'\r' "$f"; then
    echo "FAIL crlf file=$rel"
    fail=1
  fi
  if head -n 1 "$f" | grep -q '^#!'; then
    chmod +x "$f"
    if head -n 1 "$f" | grep -Eq 'bash|sh'; then
      if ! bash -n "$f" 2>/dev/null; then
        echo "FAIL syntax file=$rel"
        fail=1
      else
        echo "PASS syntax file=$rel"
      fi
    fi
  fi
done < <(find . -type f ! -path './.git/*' -print0)

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
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

if [ "$fail" -ne 0 ]; then
  echo "RESULT: TERMUX_TOOLBOX_VERIFY_FAIL"
  exit 1
fi

echo "SECRET_GUARD_PASS_BASIC"
echo "RESULT: TERMUX_TOOLBOX_VERIFY_DONE"
