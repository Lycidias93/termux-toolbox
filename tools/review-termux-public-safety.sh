#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-.}"
cd "$ROOT"
echo "scope=termux-public-safety-review"
echo "root=$(pwd)"
# Self-exclude guard implementations because they intentionally contain forbidden-pattern definitions.
set +e
grep -RInE 'PRIVATE KEY|OPENSSH|BEGIN RSA|BEGIN EC|BEGIN DSA|ghp_|github_pat_|Authorization:|Bearer |refresh_token|access_token|client_secret|password=|passwd=|rclone\.conf|100\.100\.100\.100|192\.168\.|fd00::' . \
  --exclude-dir=.git \
  --exclude='*.sha256' \
  --exclude='SHA256SUMS' \
  --exclude='.gitignore' \
  --exclude='verify-termux-toolbox.sh' \
  --exclude='review-termux-public-safety.sh' \
  --exclude='secret-guard.sh' \
  --exclude='assistant-output-guard.sh'
scan_rc=$?
set -e
case "$scan_rc" in
  0)
    echo "FAIL public_safety_review reason=forbidden_pattern"
    exit 1
    ;;
  1)
    ;;
  *)
    echo "FAIL public_safety_review reason=scan_error rc=$scan_rc"
    exit 1
    ;;
esac
echo "PASS public_safety_review"
echo "RESULT: TERMUX_PUBLIC_SAFETY_REVIEW_DONE"
