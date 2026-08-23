#!/usr/bin/env bash
set -euo pipefail

PREFIX_DIR="${PREFIX:?PREFIX is required}"
TOOLBOX="${TERMUX_TOOLBOX_REPO:-$HOME/src/termux-toolbox}"
HOME_DIR="${HOME:?HOME is required}"
BIN_DIR="$PREFIX_DIR/bin"
BASHRC="${CG_SHELL_RC_FILE:-$HOME_DIR/.bashrc}"
TMP_ROOT="${TMPDIR:-$PREFIX_DIR/tmp}"
START_MARKER="# TERMUX_TOOLBOX_NATIVE_CG_SHELL_GUARD_V1_START"
END_MARKER="# TERMUX_TOOLBOX_NATIVE_CG_SHELL_GUARD_V1_END"

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

runtime_names=(
  cgrun
  cgrun-core-v95
  cgtail-core-v95
  cgrun.autoclip-v93-real
  cgtail-autoclip-v93
  cg-lane.sh
  cg-run-file-driver-v1
  cg-run-file
  cg-handoff
  cglint
  cgdoctor
  cgfind
  cgfail
  cgnotify
)

for name in "${runtime_names[@]}"; do
  check_file "$BIN_DIR/$name"
  bash -n "$BIN_DIR/$name"
done
printf 'PASS: runtime_syntax\n'

grep -Fq 'AUTOCLIP_V95_CGRUN_EXECUTION_RECEIPT' "$BIN_DIR/cgrun" \
  || fail 'execution_receipt_wrapper_marker_missing'
grep -Fq 'AUTOCLIP_V95_NATIVE_CORE_BINDING' "$BIN_DIR/cgrun" \
  || fail 'native_core_binding_marker_missing'
grep -Fq 'AUTOCLIP_V95_CGRUN_CORE' "$BIN_DIR/cgrun-core-v95" \
  || fail 'native_cgrun_core_marker_missing'
grep -Fq 'AUTOCLIP_V95_STDIN_CLOSED' "$BIN_DIR/cgrun-core-v95" \
  || fail 'native_cgrun_stdin_closed_marker_missing'
grep -Fq 'AUTOCLIP_V95_CGTAIL_CORE' "$BIN_DIR/cgtail-core-v95" \
  || fail 'native_cgtail_core_marker_missing'
grep -Fq 'CGRUN_WORKFLOW_OK' "$BIN_DIR/cgrun" \
  || fail 'workflow_ok_marker_missing'
grep -Fq 'workflow_exit_code=' "$BIN_DIR/cgrun" \
  || fail 'workflow_exit_code_field_missing'
grep -Fq 'CG_MULTILANE_STALE_LOCK_RECOVERED' "$BIN_DIR/cg-run-file-driver-v1" \
  || fail 'stale_lock_recovery_marker_missing'
grep -Fq 'CG_MULTILANE_LOCK_BUSY' "$BIN_DIR/cg-run-file-driver-v1" \
  || fail 'lock_busy_autocopy_marker_missing'
canonical_route_case_re='none[[:space:]]*[|][[:space:]]*read-only[[:space:]]*[|][[:space:]]*route[[:space:]]*[|][[:space:]]*dns-ha[[:space:]]*[|][[:space:]]*magicdns[[:space:]]*[|][[:space:]]*subnet-route'
grep -Eq "$canonical_route_case_re" "$BIN_DIR/cg-lane.sh" \
  || fail 'canonical_route_classes_missing_from_lane_guard'
grep -Eq "$canonical_route_case_re" "$BIN_DIR/cg-run-file-driver-v1" \
  || fail 'canonical_route_classes_missing_from_run_driver'
grep -Fq 'CG_HANDOFF_V1_START' "$BIN_DIR/cg-handoff" \
  || fail 'cg_handoff_metadata_contract_missing'
grep -Fq 'CG_HANDOFF_TTY_TAIL_DRAIN_V2' "$BIN_DIR/cg-handoff" \
  || fail 'cg_handoff_tty_tail_drain_v2_marker_missing'
grep -Fq 'CG_HANDOFF_TTY_QUIET_POLLS' "$BIN_DIR/cg-handoff" \
  || fail 'cg_handoff_tty_tail_settle_window_missing'
grep -Fq 'drain_pending_tty_input' "$BIN_DIR/cg-handoff" \
  || fail 'cg_handoff_tty_tail_drain_call_missing'
grep -Fq 'CG_HANDOFF_EARLY_AUTOCOPY_V1' "$BIN_DIR/cg-handoff" \
  || fail 'cg_handoff_early_autocopy_marker_missing'
grep -Fq 'cg-run-file "$dst" "$run_mode" "$scope" "$host" "$route_class" "$secret_class"' "$BIN_DIR/cg-handoff" \
  || fail 'cg_handoff_run_file_entrypoint_missing'
printf 'PASS: execution_receipt_contract\n'

for name in "${runtime_names[@]}"; do
  source_file="$TOOLBOX/bin/$name"
  installed_file="$BIN_DIR/$name"
  [[ -f "$source_file" ]] || fail "source_file_missing path=$source_file"
  source_sha="$(sha256sum "$source_file" | awk '{print $1}')"
  installed_sha="$(sha256sum "$installed_file" | awk '{print $1}')"
  [[ "$source_sha" == "$installed_sha" ]] \
    || fail "installed_source_mismatch name=$name source_sha=$source_sha installed_sha=$installed_sha"
  printf 'PASS: installed_source_match name=%s sha256=%s\n' "$name" "$source_sha"
done

if grep -Eq '^RESULT: CGRUN_.*(^|[[:space:]])rc=' \
  "$BIN_DIR/cgrun" "$BIN_DIR/cgrun-core-v95" "$BIN_DIR/cgrun.autoclip-v93-real"; then
  fail 'ambiguous_cgrun_rc_marker_present'
fi

SHELL_GUARD="$TOOLBOX/maintenance/ensure-native-cg-shell-guard.sh"
[[ -s "$SHELL_GUARD" ]] || fail "shell_guard_source_missing path=$SHELL_GUARD"
bash -n "$SHELL_GUARD" || fail "shell_guard_source_syntax path=$SHELL_GUARD"
[[ -f "$BASHRC" ]] || fail "shell_rc_missing path=$BASHRC"
bash -n "$BASHRC" || fail "shell_rc_syntax path=$BASHRC"
[[ "$(grep -Fxc "$START_MARKER" "$BASHRC" 2>/dev/null || true)" == "1" ]] \
  || fail "shell_guard_start_not_unique path=$BASHRC"
[[ "$(grep -Fxc "$END_MARKER" "$BASHRC" 2>/dev/null || true)" == "1" ]] \
  || fail "shell_guard_end_not_unique path=$BASHRC"
post_guard_content="$(awk -v end="$END_MARKER" '
  $0 == end { seen=1; next }
  seen && $0 !~ /^[[:space:]]*$/ { print; exit }
' "$BASHRC")"
[[ -z "$post_guard_content" ]] || fail "shell_guard_not_last path=$BASHRC"

mkdir -p "$TMP_ROOT"
probe_dir="$(mktemp -d "$TMP_ROOT/native-cg-resolution-verify.XXXXXX")"
cleanup() { rm -rf "$probe_dir" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
probe="$probe_dir/resolution-probe.sh"
{
  printf '%s\n' '#!/usr/bin/env bash'
  printf '%s\n' 'printf "cgrun_type=%s\n" "$(type -t cgrun 2>/dev/null || true)"'
  printf '%s\n' 'printf "cgtail_type=%s\n" "$(type -t cgtail 2>/dev/null || true)"'
  printf '%s\n' 'printf "cg_handoff_type=%s\n" "$(type -t cg-handoff 2>/dev/null || true)"'
  printf '%s\n' 'printf "cgrun_path=%s\n" "$(type -P cgrun 2>/dev/null || true)"'
  printf '%s\n' 'printf "cgtail_path=%s\n" "$(type -P cgtail 2>/dev/null || true)"'
  printf '%s\n' 'printf "cg_handoff_path=%s\n" "$(type -P cg-handoff 2>/dev/null || true)"'
} > "$probe"
chmod 0700 "$probe"
resolution="$(PATH="$BIN_DIR:$PATH" bash --noprofile --rcfile "$BASHRC" -i "$probe" 2>/dev/null)"
printf '%s\n' "$resolution"
contains_resolution_line() {
  local needle="$1"
  case $'\n'"$resolution"$'\n' in
    *$'\n'"$needle"$'\n'*) return 0 ;;
    *) return 1 ;;
  esac
}
contains_resolution_line 'cgrun_type=file' || fail 'cgrun_shell_shadow_present'
contains_resolution_line 'cgtail_type=file' || fail 'cgtail_shell_shadow_present'
contains_resolution_line 'cg_handoff_type=file' || fail 'cg_handoff_shell_shadow_present'
contains_resolution_line "cgrun_path=$BIN_DIR/cgrun" \
  || fail "cgrun_path_mismatch expected=$BIN_DIR/cgrun"
contains_resolution_line "cgtail_path=$BIN_DIR/cgtail" \
  || fail "cgtail_path_mismatch expected=$BIN_DIR/cgtail"
contains_resolution_line "cg_handoff_path=$BIN_DIR/cg-handoff" \
  || fail "cg_handoff_path_mismatch expected=$BIN_DIR/cg-handoff"
printf 'PASS: native_shell_resolution shell_rc=%s\n' "$BASHRC"

[[ -s "$TOOLBOX/verify/verify-cgrun-noninteractive-stdin.sh" ]] \
  || fail 'cgrun_noninteractive_stdin_verifier_missing'
CGRUN_CORE_PATH="$BIN_DIR/cgrun-core-v95" bash "$TOOLBOX/verify/verify-cgrun-noninteractive-stdin.sh" \
  || fail 'cgrun_noninteractive_stdin_runtime_failed'
printf 'PASS: cgrun_noninteractive_stdin_runtime\n'

[[ -s "$TOOLBOX/maintenance/verify-cg-handoff-v1.sh" ]] \
  || fail 'cg_handoff_delayed_tty_verifier_missing'
CG_HANDOFF_PATH="$BIN_DIR/cg-handoff" \
CG_LANE_PATH="$BIN_DIR/cg-lane.sh" \
CG_RUN_FILE_DRIVER_PATH="$BIN_DIR/cg-run-file-driver-v1" \
  bash "$TOOLBOX/maintenance/verify-cg-handoff-v1.sh" \
  || fail 'cg_handoff_delayed_tty_runtime_failed'
printf 'PASS: cg_handoff_delayed_tty_runtime\n'

for name in cglint cgdoctor cgfind cgfail cgnotify; do
  bash "$BIN_DIR/$name" --help >/dev/null 2>&1 \
    || fail "toolkit_helper_help_failed name=$name"
done
bash "$BIN_DIR/cgdoctor" --quick >/dev/null \
  || fail 'cgdoctor_quick_runtime_failed'
bash "$BIN_DIR/cgnotify" --dry-run PASS 'installed runtime fixture' >/dev/null \
  || fail 'cgnotify_dry_run_runtime_failed'
printf 'PASS: toolkit_vnext_installed_smoke\n'

printf 'runtime_version=v9.5-native-core-receipt\n'
printf 'run_file_driver_version=v1\n'
printf 'handoff_version=v1.1\n'
printf 'handoff_tty_tail_drain=v2\n'
printf 'toolkit_vnext=v1\n'
printf 'stdin_mode=dev-null\n'
printf 'toolbox_head=%s\n' "$(git -C "$TOOLBOX" rev-parse HEAD 2>/dev/null || printf unknown)"
printf 'RESULT: CG_INSTALLED_RUNTIME_VERIFY_DONE outcome=success workflow_exit_code=0\n'
