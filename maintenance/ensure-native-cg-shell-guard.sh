#!/usr/bin/env bash
set -euo pipefail

HOME_DIR="${HOME:?HOME is required}"
PREFIX_DIR="${PREFIX:-/data/data/com.termux/files/usr}"
BASHRC="${CG_SHELL_RC_FILE:-$HOME_DIR/.bashrc}"
OUTPUT_DIR="${CG_OUTPUT_DIR:-$HOME_DIR/.chatgpt-output}"
BACKUP_ROOT="${CG_SHELL_GUARD_BACKUP_ROOT:-$OUTPUT_DIR/native-cg-shell-guard-backups}"
TMP_ROOT="${TMPDIR:-$PREFIX_DIR/tmp}"
START_MARKER="# TERMUX_TOOLBOX_NATIVE_CG_SHELL_GUARD_V1_START"
END_MARKER="# TERMUX_TOOLBOX_NATIVE_CG_SHELL_GUARD_V1_END"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  printf 'RESULT: CG_NATIVE_SHELL_GUARD_FAILED outcome=%s workflow_exit_code=1\n' "$1" >&2
  exit 1
}

[[ -x "$PREFIX_DIR/bin/cgrun" ]] || fail "native_cgrun_missing path=$PREFIX_DIR/bin/cgrun"
[[ -x "$PREFIX_DIR/bin/cgtail" ]] || fail "native_cgtail_missing path=$PREFIX_DIR/bin/cgtail"
mkdir -p "$(dirname "$BASHRC")" "$TMP_ROOT"
[[ -e "$BASHRC" ]] || : > "$BASHRC"
[[ -f "$BASHRC" ]] || fail "shell_rc_not_regular path=$BASHRC"

start_count="$(grep -Fxc "$START_MARKER" "$BASHRC" 2>/dev/null || true)"
end_count="$(grep -Fxc "$END_MARKER" "$BASHRC" 2>/dev/null || true)"
[[ "$start_count" == "$end_count" ]] \
  || fail "guard_marker_count_mismatch start=$start_count end=$end_count path=$BASHRC"

work_dir="$(mktemp -d "$TMP_ROOT/native-cg-shell-guard.XXXXXX")"
cleanup() { rm -rf "$work_dir" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
stripped="$work_dir/bashrc.stripped"
trimmed="$work_dir/bashrc.trimmed"
candidate="$work_dir/bashrc.candidate"

awk -v start="$START_MARKER" -v end="$END_MARKER" '
  $0 == start { skip=1; next }
  $0 == end { skip=0; next }
  !skip { print }
' "$BASHRC" > "$stripped"

awk '
  { line[NR]=$0 }
  END {
    last=NR
    while (last > 0 && line[last] ~ /^[[:space:]]*$/) last--
    for (i=1; i<=last; i++) print line[i]
  }
' "$stripped" > "$trimmed"

{
  if [[ -s "$trimmed" ]]; then
    cat "$trimmed"
    printf '\n'
  fi
  printf '%s\n' "$START_MARKER"
  printf '%s\n' '# Keep restored v9.3 compatibility functions from shadowing the repo-owned v9.5 binaries.'
  printf '%s\n' 'unset -f cgrun cgtail __autoclip_v934_latest_target __autoclip_v934_make_guard_log 2>/dev/null || true'
  printf '%s\n' 'hash -r 2>/dev/null || true'
  printf '%s\n' "$END_MARKER"
} > "$candidate"

bash -n "$candidate" || fail "candidate_shell_syntax path=$BASHRC"
changed=no
backup=none
if ! cmp -s "$BASHRC" "$candidate"; then
  backup_dir="$BACKUP_ROOT/$(date +%Y%m%d_%H%M%S)_$$"
  mkdir -p "$backup_dir"
  cp -a "$BASHRC" "$backup_dir/bashrc.before"
  mode="$(stat -c '%a' "$BASHRC" 2>/dev/null || printf '644')"
  install -m "$mode" "$candidate" "$BASHRC"
  changed=yes
  backup="$backup_dir/bashrc.before"
fi

[[ "$(grep -Fxc "$START_MARKER" "$BASHRC")" == "1" ]] \
  || fail "guard_start_not_unique path=$BASHRC"
[[ "$(grep -Fxc "$END_MARKER" "$BASHRC")" == "1" ]] \
  || fail "guard_end_not_unique path=$BASHRC"
post_guard_content="$(awk -v end="$END_MARKER" '
  $0 == end { seen=1; next }
  seen && $0 !~ /^[[:space:]]*$/ { print; exit }
' "$BASHRC")"
[[ -z "$post_guard_content" ]] || fail "guard_not_last path=$BASHRC"
bash -n "$BASHRC" || fail "shell_rc_syntax path=$BASHRC"

resolution="$(PATH="$PREFIX_DIR/bin:$PATH" bash --noprofile --rcfile "$BASHRC" -ic '
  printf "cgrun_type=%s\n" "$(type -t cgrun 2>/dev/null || true)"
  printf "cgtail_type=%s\n" "$(type -t cgtail 2>/dev/null || true)"
  printf "cgrun_path=%s\n" "$(type -P cgrun 2>/dev/null || true)"
  printf "cgtail_path=%s\n" "$(type -P cgtail 2>/dev/null || true)"
' 2>/dev/null)"
printf '%s\n' "$resolution"
grep -Fqx 'cgrun_type=file' <<< "$resolution" || fail "cgrun_shell_shadow_present"
grep -Fqx 'cgtail_type=file' <<< "$resolution" || fail "cgtail_shell_shadow_present"
grep -Fqx "cgrun_path=$PREFIX_DIR/bin/cgrun" <<< "$resolution" \
  || fail "cgrun_path_mismatch expected=$PREFIX_DIR/bin/cgrun"
grep -Fqx "cgtail_path=$PREFIX_DIR/bin/cgtail" <<< "$resolution" \
  || fail "cgtail_path_mismatch expected=$PREFIX_DIR/bin/cgtail"

printf 'shell_rc=%s\n' "$BASHRC"
printf 'changed=%s\n' "$changed"
printf 'backup=%s\n' "$backup"
printf 'RESULT: CG_NATIVE_SHELL_GUARD_DONE outcome=success changed=%s workflow_exit_code=0\n' "$changed"
