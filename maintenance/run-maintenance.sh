#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX_DIR="${PREFIX:?PREFIX is required}"
TMP_ROOT="${TMPDIR:-$PREFIX_DIR/tmp}"
AUDIT="$ROOT/maintenance/termux-environment-audit.sh"
UPDATE="$ROOT/maintenance/update-termux-and-toolbox.sh"
SHELL_GUARD="$ROOT/maintenance/ensure-native-cg-shell-guard.sh"
RUNTIME_VERIFY="$ROOT/maintenance/verify-installed-cg-runtime.sh"
DOCTOR="$PREFIX_DIR/bin/cgdoctor"

section() {
  printf '\n== %s ==\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1"
  printf 'RESULT: TERMUX_TOOLBOX_MAINTENANCE_FAILED outcome=%s workflow_exit_code=1\n' "$1"
  exit 1
}

section "workflow_contract"
printf 'root=%s\n' "$ROOT"
printf 'prefix=%s\n' "$PREFIX_DIR"
printf 'tmp_root=%s\n' "$TMP_ROOT"
printf 'package_downgrade_rollback=not_automatic\n'
printf 'old_python_directory_delete=no\n'
printf 'toolbox_git_update=fast_forward_only\n'
printf 'native_shell_shadow_guard=required\n'
printf 'installed_runtime_verify=required\n'
printf 'toolkit_health_doctor=required_after_runtime_verify\n'

section "preflight"
for command_name in bash git pkg dpkg apt-get python pip sha256sum stat find; do
  command -v "$command_name" >/dev/null 2>&1 || fail "command_missing name=$command_name"
  printf 'PASS: command_present name=%s\n' "$command_name"
done

for script in "$AUDIT" "$UPDATE" "$SHELL_GUARD" "$RUNTIME_VERIFY"; do
  [[ -s "$script" ]] || fail "script_missing_or_empty path=$script"
  [[ "$(sed -n '1p' "$script")" == '#!/usr/bin/env bash' ]] || fail "shebang_invalid path=$script"
  if LC_ALL=C grep -q $'\r' "$script"; then
    fail "crlf_present path=$script"
  fi
  bash -n "$script"
  printf 'PASS: script_verify path=%s\n' "$script"
done

section "environment_audit_pre"
bash "$AUDIT"

section "maintenance_update"
bash "$UPDATE"

section "native_shell_shadow_guard"
PREFIX="$PREFIX_DIR" bash "$SHELL_GUARD"

section "installed_runtime_verify"
PREFIX="$PREFIX_DIR" TERMUX_TOOLBOX_REPO="$ROOT" bash "$RUNTIME_VERIFY"

section "toolkit_health_doctor"
[[ -x "$DOCTOR" ]] || fail "cgdoctor_missing path=$DOCTOR"
"$DOCTOR" --quick || fail "cgdoctor_quick_failed"
printf 'PASS: toolkit_health_doctor\n'

section "final"
printf 'RESULT: TERMUX_TOOLBOX_MAINTENANCE_DONE outcome=success workflow_exit_code=0\n'
