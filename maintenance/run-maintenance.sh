#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX_DIR="${PREFIX:?PREFIX is required}"
TMP_ROOT="${TMPDIR:-$PREFIX_DIR/tmp}"
AUDIT="$ROOT/maintenance/termux-environment-audit.sh"
UPDATE="$ROOT/maintenance/update-termux-and-toolbox.sh"

section() {
  printf '\n== %s ==\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1"
  printf 'RESULT: TERMUX_TOOLBOX_MAINTENANCE_FAILED rc=1\n'
  exit 1
}

section "workflow_contract"
printf 'root=%s\n' "$ROOT"
printf 'prefix=%s\n' "$PREFIX_DIR"
printf 'tmp_root=%s\n' "$TMP_ROOT"
printf 'package_downgrade_rollback=not_automatic\n'
printf 'old_python_directory_delete=no\n'
printf 'toolbox_git_update=fast_forward_only\n'

section "preflight"
for command_name in bash git pkg dpkg apt-get python pip sha256sum stat find; do
  command -v "$command_name" >/dev/null 2>&1 || fail "command_missing name=$command_name"
  printf 'PASS: command_present name=%s\n' "$command_name"
done

for script in "$AUDIT" "$UPDATE"; do
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

section "final"
printf 'RESULT: TERMUX_TOOLBOX_MAINTENANCE_DONE rc=0\n'
