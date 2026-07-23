#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX_DIR="${PREFIX:-/data/data/com.termux/files/usr}"
BIN_DIR="$PREFIX_DIR/bin"
CORE="$BIN_DIR/cgrun.autoclip-v93-real"
TAIL_HELPER="$BIN_DIR/cgtail-autoclip-v93"
RUNTIME_VERIFY="$ROOT/maintenance/verify-installed-cg-runtime.sh"

fail() {
  printf 'FAIL: %s\n' "$1"
  printf 'RESULT: TERMUX_TOOLBOX_INSTALL_BLOCKED outcome=%s workflow_exit_code=20\n' "$1"
  exit 20
}

[[ -x "$CORE" ]] || fail "cgrun_core_missing path=$CORE"
[[ -x "$TAIL_HELPER" ]] || fail "cgtail_helper_missing path=$TAIL_HELPER"
[[ -s "$RUNTIME_VERIFY" ]] || fail "runtime_verifier_missing path=$RUNTIME_VERIFY"
bash -n "$RUNTIME_VERIFY"

mkdir -p "$BIN_DIR"
for f in "$ROOT"/bin/*; do
  [[ -f "$f" ]] || continue
  install -m 0755 "$f" "$BIN_DIR/$(basename "$f")"
done

PREFIX="$PREFIX_DIR" TERMUX_TOOLBOX_REPO="$ROOT" bash "$RUNTIME_VERIFY"
printf 'RESULT: TERMUX_TOOLBOX_INSTALL_DONE outcome=success workflow_exit_code=0\n'
