#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX_DIR="${PREFIX:-/data/data/com.termux/files/usr}"
BIN_DIR="$PREFIX_DIR/bin"
SHELL_GUARD="$ROOT/maintenance/ensure-native-cg-shell-guard.sh"
RUNTIME_VERIFY="$ROOT/maintenance/verify-installed-cg-runtime.sh"
TOOLKIT_VERIFY="$ROOT/verify/verify-toolkit-vnext.sh"
SOURCE_RESCUE_VERIFY="$ROOT/maintenance/verify-cg-handoff-source-rescue-v1.sh"

fail() {
  printf 'FAIL: %s\n' "$1"
  printf 'RESULT: TERMUX_TOOLBOX_INSTALL_BLOCKED outcome=%s workflow_exit_code=20\n' "$1"
  exit 20
}

for source_file in \
  "$ROOT/bin/cgrun" \
  "$ROOT/bin/cgrun-core-v95" \
  "$ROOT/bin/cgtail-core-v95" \
  "$ROOT/bin/cgrun.autoclip-v93-real" \
  "$ROOT/bin/cgtail-autoclip-v93" \
  "$ROOT/bin/cg-lane.sh" \
  "$ROOT/bin/cg-run-file-driver-v1" \
  "$ROOT/bin/cg-run-file" \
  "$ROOT/bin/cg-handoff" \
  "$ROOT/bin/cglint" \
  "$ROOT/bin/cgdoctor" \
  "$ROOT/bin/cgfind" \
  "$ROOT/bin/cgfail" \
  "$ROOT/bin/cgnotify"
do
  [[ -s "$source_file" ]] || fail "runtime_source_missing path=$source_file"
  bash -n "$source_file" || fail "runtime_source_syntax path=$source_file"
done

for support_script in "$SHELL_GUARD" "$RUNTIME_VERIFY" "$TOOLKIT_VERIFY" "$SOURCE_RESCUE_VERIFY"; do
  [[ -s "$support_script" ]] || fail "support_script_missing path=$support_script"
  bash -n "$support_script" || fail "support_script_syntax path=$support_script"
done

TMPDIR="${TMPDIR:-$PREFIX_DIR/tmp}" bash "$TOOLKIT_VERIFY" \
  || fail "toolkit_vnext_fixture_failed"
TMPDIR="${TMPDIR:-$PREFIX_DIR/tmp}" CG_HANDOFF_PATH="$ROOT/bin/cg-handoff" bash "$SOURCE_RESCUE_VERIFY" \
  || fail "cg_handoff_source_rescue_source_fixture_failed"

mkdir -p "$BIN_DIR"
for f in "$ROOT"/bin/*; do
  [[ -f "$f" ]] || continue
  install -m 0755 "$f" "$BIN_DIR/$(basename "$f")"
done

PREFIX="$PREFIX_DIR" bash "$SHELL_GUARD"
PREFIX="$PREFIX_DIR" TERMUX_TOOLBOX_REPO="$ROOT" bash "$RUNTIME_VERIFY"
TMPDIR="${TMPDIR:-$PREFIX_DIR/tmp}" CG_HANDOFF_PATH="$BIN_DIR/cg-handoff" bash "$SOURCE_RESCUE_VERIFY" \
  || fail "cg_handoff_source_rescue_installed_fixture_failed"
printf 'RESULT: TERMUX_TOOLBOX_INSTALL_DONE outcome=success workflow_exit_code=0\n'
