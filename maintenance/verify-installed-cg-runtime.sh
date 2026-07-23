#!/usr/bin/env bash
set -euo pipefail

PREFIX_DIR="${PREFIX:?PREFIX is required}"
TOOLBOX="${TERMUX_TOOLBOX_REPO:-$HOME/src/termux-toolbox}"
BIN_DIR="$PREFIX_DIR/bin"

fail() {
  printf 'FAIL: %s\n' "$1"
  printf 'RESULT: CG_INSTALLED_RUNTIME_VERIFY_FAILED outcome=%s workflow_exit_code=1\n' "$1"
  exit 1
}

check_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "file_missing path=$path"
  [[ -s "$path" ]] || fail "file_empty path=$path"
  [[ -x "$path" ]] || fail "file_not_executable path=$path"
  if LC_ALL=C grep -q $'\r' "$path"; then
    fail "crlf_present path=$path"
  fi
  printf 'PASS: runtime_file path=%s\n' "$path"
}

for path in \
  "$BIN_DIR/cgrun" \
  "$BIN_DIR/cg-lane.sh" \
  "$BIN_DIR/cgrun.autoclip-v93-real" \
  "$BIN_DIR/cgtail-autoclip-v93"
do
  check_file "$path"
done

bash -n "$BIN_DIR/cgrun"
bash -n "$BIN_DIR/cg-lane.sh"
printf 'PASS: runtime_syntax\n'

grep -Fq 'AUTOCLIP_V95_CGRUN_EXECUTION_RECEIPT' "$BIN_DIR/cgrun" \
  || fail 'execution_receipt_wrapper_marker_missing'
grep -Fq 'CGRUN_WORKFLOW_OK' "$BIN_DIR/cgrun" \
  || fail 'workflow_ok_marker_missing'
grep -Fq 'chat_lane=' "$BIN_DIR/cgrun" \
  || fail 'chat_lane_field_missing'
grep -Fq 'task=' "$BIN_DIR/cgrun" \
  || fail 'task_field_missing'
grep -Fq 'workflow_exit_code=' "$BIN_DIR/cgrun" \
  || fail 'workflow_exit_code_field_missing'
printf 'PASS: execution_receipt_contract\n'

for name in cgrun cg-lane.sh; do
  source_file="$TOOLBOX/bin/$name"
  installed_file="$BIN_DIR/$name"
  [[ -f "$source_file" ]] || fail "source_file_missing path=$source_file"
  source_sha="$(sha256sum "$source_file" | awk '{print $1}')"
  installed_sha="$(sha256sum "$installed_file" | awk '{print $1}')"
  [[ "$source_sha" == "$installed_sha" ]] \
    || fail "installed_source_mismatch name=$name source_sha=$source_sha installed_sha=$installed_sha"
  printf 'PASS: installed_source_match name=%s sha256=%s\n' "$name" "$source_sha"
done

printf 'runtime_version=v9.5-execution-receipt\n'
printf 'toolbox_head=%s\n' "$(git -C "$TOOLBOX" rev-parse HEAD 2>/dev/null || printf unknown)"
printf 'RESULT: CG_INSTALLED_RUNTIME_VERIFY_DONE outcome=success workflow_exit_code=0\n'
