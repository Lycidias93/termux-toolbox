#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/tools/review-termux-public-safety.sh"
TMP_BASE="${TMPDIR:-$HOME/.cache/tmp}"
mkdir -p "$TMP_BASE"
FIXTURE="$(mktemp -d "$TMP_BASE/termux-public-safety.XXXXXX")"
CLEAN_OUT="$(mktemp "$TMP_BASE/termux-public-safety-clean.XXXXXX")"
LEAK_OUT="$(mktemp "$TMP_BASE/termux-public-safety-leak.XXXXXX")"
BASENAME_OUT="$(mktemp "$TMP_BASE/termux-public-safety-basename.XXXXXX")"
BINARY_OUT="$(mktemp "$TMP_BASE/termux-public-safety-binary.XXXXXX")"
NEWLINE_OUT="$(mktemp "$TMP_BASE/termux-public-safety-newline.XXXXXX")"
VERIFIER_OUT="$(mktemp "$TMP_BASE/termux-public-safety-verifier.XXXXXX")"
cleanup() { rm -rf "$FIXTURE"; rm -f "$CLEAN_OUT" "$LEAK_OUT" "$BASENAME_OUT" "$BINARY_OUT" "$NEWLINE_OUT" "$VERIFIER_OUT"; }
trap cleanup EXIT

bash "$CHECKER" "$ROOT" >"$CLEAN_OUT"
grep -Fq 'RESULT: TERMUX_PUBLIC_SAFETY_REVIEW_DONE' "$CLEAN_OUT"
printf 'safe fixture\n' >"$FIXTURE/README.md"
bash "$CHECKER" "$FIXTURE" >/dev/null
auth_label='Author''ization:'
bearer_word='Bear''er'
printf '%s %s %s\n' "$auth_label" "$bearer_word" 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' >"$FIXTURE/leak.txt"
if bash "$CHECKER" "$FIXTURE" >"$LEAK_OUT" 2>&1; then
  echo 'FAIL public_safety_negative_fixture_not_detected'
  exit 1
fi
grep -Fq 'FAIL public_safety_review reason=forbidden_pattern' "$LEAK_OUT"
rm -f "$FIXTURE/leak.txt"
mkdir -p "$FIXTURE/nested"
printf '%s %s %s\n' "$auth_label" "$bearer_word" 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB' >"$FIXTURE/nested/secret-guard.sh"
if bash "$CHECKER" "$FIXTURE" >"$BASENAME_OUT" 2>&1; then
  echo 'FAIL public_safety_same_basename_fixture_not_detected'
  exit 1
fi
grep -Fq 'MATCH path=./nested/secret-guard.sh' "$BASENAME_OUT"
if grep -Fq 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB' "$BASENAME_OUT"; then echo 'FAIL public_safety_match_content_exposed'; exit 1; fi
grep -Fq 'FAIL public_safety_review reason=forbidden_pattern' "$BASENAME_OUT"
rm -rf "$FIXTURE/nested"
printf 'safe\000%s %s %s\n' "$auth_label" "$bearer_word" 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC' >"$FIXTURE/blob.bin"
if bash "$CHECKER" "$FIXTURE" >"$BINARY_OUT" 2>&1; then
  echo 'FAIL public_safety_binary_fixture_not_detected'
  exit 1
fi
grep -Fq 'MATCH path=./blob.bin' "$BINARY_OUT"
grep -Fq 'FAIL public_safety_review reason=forbidden_pattern' "$BINARY_OUT"
if grep -Fq 'CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC' "$BINARY_OUT"; then echo 'FAIL public_safety_binary_content_exposed'; exit 1; fi
rm -f "$FIXTURE/blob.bin"
newline_dir=$'review-termux-public-safety.sh\n.'
mkdir -p "$FIXTURE/tools/$newline_dir/tools"
printf '%s %s %s\n' "$auth_label" "$bearer_word" 'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' >"$FIXTURE/tools/$newline_dir/tools/secret-guard.sh"
if bash "$CHECKER" "$FIXTURE" >"$NEWLINE_OUT" 2>&1; then
  echo 'FAIL public_safety_newline_path_fixture_not_detected'
  exit 1
fi
grep -Fq 'FAIL public_safety_review reason=forbidden_pattern' "$NEWLINE_OUT"
if grep -Fq 'DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD' "$NEWLINE_OUT"; then echo 'FAIL public_safety_newline_content_exposed'; exit 1; fi
mkdir -p "$FIXTURE/verify"
printf '%s %s %s\n' "$auth_label" "$bearer_word" 'EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE' >"$FIXTURE/verify/verify-termux-toolbox.sh"
if bash "$CHECKER" "$FIXTURE" >"$VERIFIER_OUT" 2>&1; then
  echo 'FAIL public_safety_aggregate_verifier_fixture_not_detected'
  exit 1
fi
grep -Fq 'MATCH path=./verify/verify-termux-toolbox.sh' "$VERIFIER_OUT"
grep -Fq 'FAIL public_safety_review reason=forbidden_pattern' "$VERIFIER_OUT"
if grep -Fq 'EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE' "$VERIFIER_OUT"; then echo 'FAIL public_safety_aggregate_verifier_content_exposed'; exit 1; fi
grep -Fq 'bash tools/review-termux-public-safety.sh' "$ROOT/verify/verify-termux-toolbox.sh"
if grep -Fq 'SECRET_SCAN_FILE' "$ROOT/verify/verify-termux-toolbox.sh"; then echo 'FAIL aggregate_secret_content_printing_scan_present'; exit 1; fi
echo 'RESULT: TERMUX_PUBLIC_SAFETY_REVIEW_VERIFY_DONE'
