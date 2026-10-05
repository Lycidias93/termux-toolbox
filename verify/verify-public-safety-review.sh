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
cleanup() { rm -rf "$FIXTURE"; rm -f "$CLEAN_OUT" "$LEAK_OUT" "$BASENAME_OUT"; }
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
grep -Fq 'FAIL public_safety_review reason=forbidden_pattern' "$BASENAME_OUT"
echo 'RESULT: TERMUX_PUBLIC_SAFETY_REVIEW_VERIFY_DONE'
