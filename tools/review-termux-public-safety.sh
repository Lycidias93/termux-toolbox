#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-.}"
cd "$ROOT"
echo "scope=termux-public-safety-review"
echo "root=$(pwd)"
# Self-exclude this checker because it intentionally contains forbidden-pattern definitions.
if grep -RInE 'PRIVATE KEY|OPENSSH|BEGIN RSA|BEGIN EC|BEGIN DSA|ghp_|github_pat_|Authorization:|Bearer |refresh_token|access_token|client_secret|password=|passwd=|rclone\.conf|100\.100\.100\.100|192\.168\.|fd00::' . \
  --exclude-dir=.git \
  --exclude='*.sha256' \
  --exclude='SHA256SUMS' \
  --exclude='.gitignore' \
  --exclude='verify-termux-toolbox.sh' \
  --exclude='review-termux-public-safety.sh' --exclude='verify-termux-toolbox.sh'; then
  echo "FAIL public_safety_review"
  exit 1
fi
echo "PASS public_safety_review"
echo "RESULT: TERMUX_PUBLIC_SAFETY_REVIEW_DONE"
