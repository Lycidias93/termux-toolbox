#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-.}"
cd "$ROOT"
echo "scope=termux-public-safety-review"
echo "root=$(pwd)"

TMP_BASE="${TMPDIR:-${HOME:-/tmp}/.cache/tmp}"
mkdir -p "$TMP_BASE"
MATCHES="$(mktemp "$TMP_BASE/termux-public-safety-matches.XXXXXX")"
cleanup() { rm -f "$MATCHES"; }
trap cleanup EXIT

# Scan every repository file except non-content hash metadata. Guard implementations
# are filtered only by their exact repository paths so same-basename files elsewhere
# remain covered by the safety review.
set +e
grep -RIlE 'PRIVATE KEY|OPENSSH|BEGIN RSA|BEGIN EC|BEGIN DSA|ghp_|github_pat_|Authorization:|Bearer |refresh_token|access_token|client_secret|password=|passwd=|rclone\.conf|100\.100\.100\.100|192\.168\.|fd00::' . \
  --exclude-dir=.git \
  --exclude='*.sha256' \
  --exclude='SHA256SUMS' \
  --exclude='.gitignore' >"$MATCHES"
scan_rc=$?
set -e
case "$scan_rc" in
  0|1) ;;
  *)
    echo "FAIL public_safety_review reason=scan_error rc=$scan_rc"
    exit 1
    ;;
esac

found=0
while IFS= read -r match; do
  case "$match" in
    ./tools/review-termux-public-safety.sh|./tools/secret-guard.sh|./tools/assistant-output-guard.sh|./verify/verify-termux-toolbox.sh)
      continue
      ;;
  esac
  printf 'MATCH path=%s\n' "$match"
  found=1
done <"$MATCHES"

if (( found != 0 )); then
  echo "FAIL public_safety_review reason=forbidden_pattern"
  exit 1
fi

echo "PASS public_safety_review"
echo "RESULT: TERMUX_PUBLIC_SAFETY_REVIEW_DONE"
