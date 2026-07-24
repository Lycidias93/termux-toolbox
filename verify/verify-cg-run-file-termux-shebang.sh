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
  printf '%s\n' '[ "${1:-}" = "run-file" ] || exit 91'
  printf '%s\n' 'script="${2:-}"'
  printf '%s\n' '[ -f "$script" ] || exit 92'
  printf '%s\n' 'printf '\''%s\n'\'' "$(head -n 1 "$script")" > "$CG_RUN_FILE_CAPTURE/first_line"'
  printf '%s\n' 'printf '\''%s\n'\'' "$script" > "$CG_RUN_FILE_CAPTURE/script_path"'
  printf '%s\n' 'printf '\''%s\n'\'' "$(basename "$script")" > "$CG_RUN_FILE_CAPTURE/task_basename"'
  printf '%s\n' 'printf '\''%s\n'\'' "${3:-}" > "$CG_RUN_FILE_CAPTURE/mode"'
  printf '%s\n' 'printf '\''%s\n'\'' "${4:-}" > "$CG_RUN_FILE_CAPTURE/scope"'
} > "$FAKE_BIN/cg-lane.sh"
chmod 0755 "$FAKE_BIN/cg-lane.sh"

run_case() {
  local name="$1" source_shebang="$2" expected_shebang="$3" requested_mode="$4"
  local script="$TMP_ROOT/$name.sh"

  printf '%s\nprintf "RESULT: %s_DONE\\n"\n' "$source_shebang" "$name" > "$script"
  chmod 0755 "$script"
  rm -f "$CAPTURE/first_line" "$CAPTURE/script_path" "$CAPTURE/task_basename" "$CAPTURE/mode" "$CAPTURE/scope"

  TMPDIR="$TMP_ROOT" PATH="$FAKE_BIN:$PATH" CG_RUN_FILE_CAPTURE="$CAPTURE" \
    bash "$WRAPPER" "$script" "$requested_mode" pixel

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
  printf 'PASS normalized_shebang_task_and_mode case=%s source=%s target=%s task=%s requested_mode=%s canonical_mode=verify\n' \
    "$name" "$source_shebang" "$expected_shebang" "$(basename "$script")" "${requested_mode:-default}"
}

run_case native_termux_bash '#!/data/data/com.termux/files/usr/bin/bash' '#!/usr/bin/env bash' 'VERIFY'
run_case native_termux_sh '#!/data/data/com.termux/files/usr/bin/sh' '#!/usr/bin/env sh' 'VeRiFy'
run_case portable_env_bash '#!/usr/bin/env bash' '#!/usr/bin/env bash' ''

invalid_script="$TMP_ROOT/invalid_mode.sh"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$invalid_script"
chmod 0755 "$invalid_script"
if TMPDIR="$TMP_ROOT" PATH="$FAKE_BIN:$PATH" CG_RUN_FILE_CAPTURE="$CAPTURE" \
  bash "$WRAPPER" "$invalid_script" deploy pixel >/dev/null 2>&1
then
  printf '%s\n' 'FAIL invalid_mode_accepted'
  exit 1
fi

printf '%s\n' 'PASS cg_run_file_mode_canonicalization'
printf '%s\n' 'PASS cg_run_file_invalid_mode_rejected'
printf '%s\n' 'RESULT: CG_RUN_FILE_TERMUX_SHEBANG_VERIFY_DONE outcome=success workflow_exit_code=0'
