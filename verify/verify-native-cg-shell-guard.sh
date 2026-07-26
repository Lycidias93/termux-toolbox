#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUARD="$ROOT/maintenance/ensure-native-cg-shell-guard.sh"
TMP_BASE="${TMPDIR:-$HOME/.cache/tmp}"
mkdir -p "$TMP_BASE"
CASE_DIR="$(mktemp -d "$TMP_BASE/native-cg-shell-guard-verify.XXXXXX")"
cleanup() { rm -rf "$CASE_DIR" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  printf 'RESULT: CG_NATIVE_SHELL_GUARD_VERIFY_FAILED outcome=%s workflow_exit_code=1\n' "$1" >&2
  exit 1
}

[[ -s "$GUARD" ]] || fail "guard_missing path=$GUARD"
bash -n "$GUARD"
HOME_FIXTURE="$CASE_DIR/home"
PREFIX_FIXTURE="$CASE_DIR/prefix"
BASHRC="$HOME_FIXTURE/.bashrc"
BACKUP_ROOT="$CASE_DIR/backups"
mkdir -p "$HOME_FIXTURE" "$PREFIX_FIXTURE/bin" "$PREFIX_FIXTURE/tmp"

for name in cgrun cgtail; do
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf 'printf "native_%s\\n"\n' "$name"
  } > "$PREFIX_FIXTURE/bin/$name"
  chmod 0755 "$PREFIX_FIXTURE/bin/$name"
done

write_legacy_bashrc() {
  {
    printf '%s\n' '# restored legacy AutoCopy wrapper'
    printf '%s\n' 'cgrun() { printf "legacy_cgrun\n"; }'
    printf '%s\n' 'cgtail() { printf "legacy_cgtail\n"; }'
    printf '%s\n' '__autoclip_v934_latest_target() { printf "legacy_latest\n"; }'
  } > "$BASHRC"
}

run_guard() {
  HOME="$HOME_FIXTURE" \
  PREFIX="$PREFIX_FIXTURE" \
  TMPDIR="$PREFIX_FIXTURE/tmp" \
  CG_OUTPUT_DIR="$CASE_DIR/output" \
  CG_SHELL_RC_FILE="$BASHRC" \
  CG_SHELL_GUARD_BACKUP_ROOT="$BACKUP_ROOT" \
    bash "$GUARD"
}

resolve_types() {
  probe="$CASE_DIR/type-probe.sh"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'printf "%s\n" "$(type -t cgrun 2>/dev/null || true)"'
    printf '%s\n' 'printf "%s\n" "$(type -t cgtail 2>/dev/null || true)"'
  } > "$probe"
  chmod 0700 "$probe"
  PATH="$PREFIX_FIXTURE/bin:$PATH" bash --noprofile --rcfile "$BASHRC" -i "$probe" 2>/dev/null
}

write_legacy_bashrc
first_output="$(run_guard)"
printf '%s\n' "$first_output"
printf '%s\n' "$first_output" | grep -Fq 'RESULT: CG_NATIVE_SHELL_GUARD_DONE outcome=success changed=yes workflow_exit_code=0' \
  || fail "first_apply_marker_missing"
[[ "$(grep -Fxc '# TERMUX_TOOLBOX_NATIVE_CG_SHELL_GUARD_V1_START' "$BASHRC")" == "1" ]] \
  || fail "start_marker_not_unique_after_first_apply"
[[ "$(grep -Fxc '# TERMUX_TOOLBOX_NATIVE_CG_SHELL_GUARD_V1_END' "$BASHRC")" == "1" ]] \
  || fail "end_marker_not_unique_after_first_apply"
[[ "$(resolve_types)" == $'file\nfile' ]] || fail "native_resolution_failed_after_first_apply"
first_backup_count="$(find "$BACKUP_ROOT" -type f -name bashrc.before 2>/dev/null | wc -l | tr -d '[:space:]')"
[[ "$first_backup_count" == "1" ]] || fail "first_backup_count value=$first_backup_count"
printf '%s\n' 'PASS: first_apply_and_resolution'

second_output="$(run_guard)"
printf '%s\n' "$second_output"
printf '%s\n' "$second_output" | grep -Fq 'RESULT: CG_NATIVE_SHELL_GUARD_DONE outcome=success changed=no workflow_exit_code=0' \
  || fail "idempotent_marker_missing"
second_backup_count="$(find "$BACKUP_ROOT" -type f -name bashrc.before 2>/dev/null | wc -l | tr -d '[:space:]')"
[[ "$second_backup_count" == "1" ]] || fail "idempotent_created_backup count=$second_backup_count"
printf '%s\n' 'PASS: idempotent_apply'

write_legacy_bashrc
restore_output="$(run_guard)"
printf '%s\n' "$restore_output"
printf '%s\n' "$restore_output" | grep -Fq 'RESULT: CG_NATIVE_SHELL_GUARD_DONE outcome=success changed=yes workflow_exit_code=0' \
  || fail "restore_repair_marker_missing"
[[ "$(resolve_types)" == $'file\nfile' ]] || fail "native_resolution_failed_after_restore"
restore_backup_count="$(find "$BACKUP_ROOT" -type f -name bashrc.before 2>/dev/null | wc -l | tr -d '[:space:]')"
[[ "$restore_backup_count" == "2" ]] || fail "restore_backup_count value=$restore_backup_count"
post_guard_content="$(awk '
  $0 == "# TERMUX_TOOLBOX_NATIVE_CG_SHELL_GUARD_V1_END" { seen=1; next }
  seen && $0 !~ /^[[:space:]]*$/ { print; exit }
' "$BASHRC")"
[[ -z "$post_guard_content" ]] || fail "guard_not_last_after_restore"
printf '%s\n' 'PASS: restored_legacy_wrapper_repaired'
printf '%s\n' 'RESULT: CG_NATIVE_SHELL_GUARD_VERIFY_DONE outcome=success workflow_exit_code=0'
