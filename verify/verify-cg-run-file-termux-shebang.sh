#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="$ROOT/bin/cg-run-file"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cg-run-file-termux-shebang.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

FAKE_BIN="$TMP_ROOT/bin"
CAPTURE="$TMP_ROOT/capture"
mkdir -p "$FAKE_BIN" "$CAPTURE"

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'set -euo pipefail'
  printf '%s\n' '[ "${1:-}" = "run" ] || exit 91'
  printf '%s\n' 'script="${2:-}"'
  printf '%s\n' 'mode="${3:-}"'
  printf '%s\n' 'scope="${4:-}"'
  printf '%s\n' 'case "$mode" in verify|run) ;; *) exit 90 ;; esac'
  printf '%s\n' '[ -f "$script" ] || exit 92'
  printf '%s\n' 'printf '\''%s\n'\'' "$(head -n 1 "$script")" > "$CG_RUN_FILE_CAPTURE/first_line"'
  printf '%s\n' 'printf '\''%s\n'\'' "$script" > "$CG_RUN_FILE_CAPTURE/script_path"'
  printf '%s\n' 'printf '\''%s\n'\'' "$(basename "$script")" > "$CG_RUN_FILE_CAPTURE/task_basename"'
  printf '%s\n' 'printf '\''%s\n'\'' "$mode" > "$CG_RUN_FILE_CAPTURE/mode"'
  printf '%s\n' 'printf '\''%s\n'\'' "$scope" > "$CG_RUN_FILE_CAPTURE/scope"'
  printf '%s\n' 'printf '\''%s\n'\'' "${CG_RUN_FILE_SOURCE_PATH:-}" > "$CG_RUN_FILE_CAPTURE/source_path"'
  printf '%s\n' 'printf '\''%s\n'\'' "${CG_RUN_FILE_SOURCE_DIR:-}" > "$CG_RUN_FILE_CAPTURE/source_dir"'
  printf '%s\n' 'bash "$script" > "$CG_RUN_FILE_CAPTURE/payload_output"'
} > "$FAKE_BIN/cg-run-file-driver-v1"
chmod 0755 "$FAKE_BIN/cg-run-file-driver-v1"

reset_capture() {
  rm -f \
    "$CAPTURE/first_line" \
    "$CAPTURE/script_path" \
    "$CAPTURE/task_basename" \
    "$CAPTURE/mode" \
    "$CAPTURE/scope" \
    "$CAPTURE/source_path" \
    "$CAPTURE/source_dir" \
    "$CAPTURE/payload_output"
}

assert_common() {
  local name="$1" script="$2" expected_shebang="$3" requested_mode="$4"
  local expected_source expected_dir
  expected_source="$(readlink -f "$script")"
  expected_dir="${expected_source%/*}"
  [ "$(cat "$CAPTURE/first_line")" = "$expected_shebang" ] || return 1
  [ "$(cat "$CAPTURE/task_basename")" = "$(basename "$script")" ] || {
    printf 'FAIL task_basename_changed case=%s got=%s expected=%s\n' \
      "$name" "$(cat "$CAPTURE/task_basename")" "$(basename "$script")"
    return 1
  }
  [ "$(cat "$CAPTURE/mode")" = "verify" ] || {
    printf 'FAIL mode_not_canonical case=%s requested=%s got=%s expected=verify\n' \
      "$name" "${requested_mode:-default}" "$(cat "$CAPTURE/mode")"
    return 1
  }
  [ "$(cat "$CAPTURE/scope")" = "pixel" ] || return 1
  [ "$(cat "$CAPTURE/source_path")" = "$expected_source" ] || {
    printf 'FAIL source_path_not_preserved case=%s got=%s expected=%s\n' \
      "$name" "$(cat "$CAPTURE/source_path")" "$expected_source"
    return 1
  }
  [ "$(cat "$CAPTURE/source_dir")" = "$expected_dir" ] || {
    printf 'FAIL source_dir_not_preserved case=%s got=%s expected=%s\n' \
      "$name" "$(cat "$CAPTURE/source_dir")" "$expected_dir"
    return 1
  }
  grep -Fxq "RESULT: ${name}_DONE" "$CAPTURE/payload_output" || {
    printf 'FAIL payload_not_executed case=%s\n' "$name"
    return 1
  }
}

run_shell_case() {
  local name="$1" source_shebang="$2" expected_shebang="$3" requested_mode="$4"
  local script="$TMP_ROOT/$name.sh"

  printf '%s\nprintf "RESULT: %s_DONE\\n"\n' "$source_shebang" "$name" > "$script"
  chmod 0755 "$script"
  reset_capture

  TMPDIR="$TMP_ROOT" PATH="$FAKE_BIN:$PATH" CG_RUN_FILE_CAPTURE="$CAPTURE" \
    bash "$WRAPPER" "$script" "$requested_mode" pixel

  assert_common "$name" "$script" "$expected_shebang" "$requested_mode"
  printf 'PASS normalized_shell_shebang_task_mode_execution_and_source_context case=%s source=%s target=%s task=%s\n' \
    "$name" "$source_shebang" "$expected_shebang" "$(basename "$script")"
}

run_python_case() {
  local name="$1" source_shebang="$2"
  local script="$TMP_ROOT/$name.py"

  printf '%s\n' "$source_shebang" "print('RESULT: ${name}_DONE')" > "$script"
  chmod 0755 "$script"
  reset_capture

  TMPDIR="$TMP_ROOT" PATH="$FAKE_BIN:$PATH" CG_RUN_FILE_CAPTURE="$CAPTURE" \
    bash "$WRAPPER" "$script" VERIFY pixel

  assert_common "$name" "$script" '#!/usr/bin/env bash' VERIFY
  printf 'PASS normalized_python_artifact_task_mode_execution_and_source_context case=%s source=%s wrapper=%s task=%s\n' \
    "$name" "$source_shebang" '#!/usr/bin/env bash' "$(basename "$script")"
}

run_shell_case native_termux_bash '#!/data/data/com.termux/files/usr/bin/bash' '#!/usr/bin/env bash' 'VERIFY'
run_shell_case native_termux_sh '#!/data/data/com.termux/files/usr/bin/sh' '#!/usr/bin/env sh' 'VeRiFy'
run_shell_case portable_env_bash '#!/usr/bin/env bash' '#!/usr/bin/env bash' ''
run_python_case native_termux_python3 '#!/data/data/com.termux/files/usr/bin/python3'
run_python_case portable_env_python3 '#!/usr/bin/env python3'

invalid_mode_script="$TMP_ROOT/invalid_mode.sh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$invalid_mode_script"
chmod 0755 "$invalid_mode_script"
if TMPDIR="$TMP_ROOT" PATH="$FAKE_BIN:$PATH" CG_RUN_FILE_CAPTURE="$CAPTURE" \
  bash "$WRAPPER" "$invalid_mode_script" deploy pixel >/dev/null 2>&1
then
  printf '%s\n' 'FAIL invalid_mode_accepted'
  exit 1
fi

invalid_python="$TMP_ROOT/invalid_python.py"
printf '%s\n' '#!/data/data/com.termux/files/usr/bin/python3' 'def broken(' > "$invalid_python"
chmod 0755 "$invalid_python"
if TMPDIR="$TMP_ROOT" PATH="$FAKE_BIN:$PATH" CG_RUN_FILE_CAPTURE="$CAPTURE" \
  bash "$WRAPPER" "$invalid_python" verify pixel >/dev/null 2>&1
then
  printf '%s\n' 'FAIL invalid_python_syntax_accepted'
  exit 1
fi

printf '%s\n' 'PASS cg_run_file_mode_canonicalization'
printf '%s\n' 'PASS cg_run_file_invalid_mode_rejected'
printf '%s\n' 'PASS cg_run_file_python_syntax_guard'
printf '%s\n' 'PASS cg_run_file_source_context_preserved'
printf '%s\n' 'RESULT: CG_RUN_FILE_TERMUX_SHEBANG_VERIFY_DONE outcome=success workflow_exit_code=0'
