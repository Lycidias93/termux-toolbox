#!/usr/bin/env bash
set -euo pipefail

umask 077

PREFIX_DIR="${PREFIX:?PREFIX is required}"
OUT_DIR="${TERMUX_TOOLBOX_MAINTENANCE_OUTPUT_DIR:-$HOME/.chatgpt-output/termux-maintenance}"
TOOLBOX="${TERMUX_TOOLBOX_REPO:-$HOME/src/termux-toolbox}"
TMP_ROOT="${TMPDIR:-$PREFIX_DIR/tmp}"
RUN_ID="$(date '+%Y%m%d_%H%M%S')"
REPORT="$OUT_DIR/audit_${RUN_ID}.log"
STATE="$OUT_DIR/latest-audit.env"

mkdir -p "$OUT_DIR" "$TMP_ROOT"
TMP_WORK="$(mktemp -d "$TMP_ROOT/termux-toolbox-audit.XXXXXX")"

cleanup() {
  rm -rf "$TMP_WORK"
}
trap cleanup EXIT

exec > >(tee "$REPORT") 2>&1

warnings=0
failures=0
apply_allowed=yes
toolbox_head=missing
toolbox_remote_main=unknown
toolbox_dirty=unknown

section() {
  printf '\n== %s ==\n' "$1"
}

pass() {
  printf 'PASS: %s\n' "$1"
}

warn() {
  warnings=$((warnings + 1))
  printf 'WARN: %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  apply_allowed=no
  printf 'FAIL: %s\n' "$1"
}

section "identity"
printf 'run_id=%s\n' "$RUN_ID"
printf 'date=%s\n' "$(date -Iseconds)"
printf 'prefix=%s\n' "$PREFIX_DIR"
printf 'home=%s\n' "$HOME"
printf 'tmp_root=%s\n' "$TMP_ROOT"
printf 'toolbox=%s\n' "$TOOLBOX"
printf 'arch=%s\n' "$(uname -m)"

if [[ -d "$TMP_ROOT" && -w "$TMP_ROOT" ]]; then
  pass "temporary_directory_writable"
else
  fail "temporary_directory_not_writable"
fi

section "filesystem"
df -h "$PREFIX_DIR" "$HOME" 2>/dev/null || true
df -i "$PREFIX_DIR" "$HOME" 2>/dev/null || true

section "package_database"
DPKG_AUDIT="$TMP_WORK/dpkg-audit.txt"
if dpkg --audit >"$DPKG_AUDIT" 2>&1; then
  if [[ -s "$DPKG_AUDIT" ]]; then
    cat "$DPKG_AUDIT"
    fail "dpkg_audit_reported_findings"
  else
    pass "dpkg_audit_clean"
  fi
else
  cat "$DPKG_AUDIT"
  fail "dpkg_audit_command_failed"
fi

APT_CHECK="$TMP_WORK/apt-check.txt"
if apt-get check >"$APT_CHECK" 2>&1; then
  cat "$APT_CHECK"
  pass "apt_dependency_check"
else
  cat "$APT_CHECK"
  fail "apt_dependency_check_failed"
fi

section "core_versions"
for package in python python-pip git gh openssh openssh-sftp-server rclone; do
  version="$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)"
  if [[ -n "$version" ]]; then
    printf '%s=%s\n' "$package" "$version"
  else
    printf '%s=not-installed\n' "$package"
  fi
done

section "pending_updates"
UPGRADABLE="$TMP_WORK/upgradable.txt"
apt list --upgradable 2>/dev/null | sed -n '2,$p' >"$UPGRADABLE" || true
upgradable_count="$(wc -l <"$UPGRADABLE" | tr -d ' ')"
printf 'upgradable_count=%s\n' "$upgradable_count"
if [[ "$upgradable_count" -gt 0 ]]; then
  sed -n '1,120p' "$UPGRADABLE"
  warn "packages_pending"
else
  pass "no_packages_pending_in_local_index"
fi

section "python_runtime"
current_python_dir=""
if command -v python >/dev/null 2>&1; then
  python --version
  current_python_dir="$(python -c 'import sys; print(f"python{sys.version_info.major}.{sys.version_info.minor}")')"
  python -c 'import sys,sysconfig; print("executable="+sys.executable); print("prefix="+sys.prefix); print("stdlib="+sysconfig.get_paths()["stdlib"])'
  pass "python_runtime"
else
  fail "python_command_missing"
fi

if command -v pip >/dev/null 2>&1; then
  pip --version
  PIP_CHECK="$TMP_WORK/pip-check.txt"
  if pip check >"$PIP_CHECK" 2>&1; then
    cat "$PIP_CHECK"
    pass "pip_check"
  else
    cat "$PIP_CHECK"
    fail "pip_check_failed"
  fi
else
  fail "pip_command_missing"
fi

section "old_python_directories"
old_python_count=0
while IFS= read -r directory; do
  [[ -n "$directory" ]] || continue
  name="$(basename "$directory")"
  if [[ "$name" == "$current_python_dir" ]]; then
    continue
  fi
  old_python_count=$((old_python_count + 1))
  printf 'old_python_directory=%s\n' "$directory"
  du -sh "$directory" 2>/dev/null || true
done < <(find "$PREFIX_DIR/lib" -maxdepth 1 -type d -name 'python[0-9]*.[0-9]*' 2>/dev/null | LC_ALL=C sort)

printf 'old_python_directory_count=%s\n' "$old_python_count"
if [[ "$old_python_count" -gt 0 ]]; then
  warn "old_python_directories_present_cleanup_deferred"
else
  pass "no_old_python_directories"
fi

section "toolbox_repository"
if [[ ! -d "$TOOLBOX/.git" ]]; then
  fail "toolbox_repo_missing"
else
  toolbox_head="$(git -C "$TOOLBOX" rev-parse HEAD)"
  branch="$(git -C "$TOOLBOX" branch --show-current)"
  printf 'branch=%s\n' "$branch"
  printf 'head=%s\n' "$toolbox_head"

  if [[ "$branch" == "main" ]]; then
    pass "toolbox_branch_main"
  else
    fail "toolbox_branch_not_main"
  fi

  STATUS_FILE="$TMP_WORK/toolbox-status.txt"
  git -C "$TOOLBOX" status --porcelain=v1 >"$STATUS_FILE"
  if [[ -s "$STATUS_FILE" ]]; then
    toolbox_dirty=yes
    cat "$STATUS_FILE"
    fail "toolbox_worktree_dirty"
  else
    toolbox_dirty=no
    pass "toolbox_worktree_clean"
  fi

  origin="$(git -C "$TOOLBOX" remote get-url origin 2>/dev/null || true)"
  case "$origin" in
    git@github.com:Lycidias93/termux-toolbox.git|https://github.com/Lycidias93/termux-toolbox.git|https://github.com/Lycidias93/termux-toolbox)
      pass "toolbox_origin_expected"
      ;;
    *)
      fail "toolbox_origin_unexpected_or_missing"
      ;;
  esac

  LS_REMOTE="$TMP_WORK/ls-remote.txt"
  if git -C "$TOOLBOX" ls-remote --exit-code origin refs/heads/main >"$LS_REMOTE" 2>&1; then
    toolbox_remote_main="$(awk 'NR==1 {print $1}' "$LS_REMOTE")"
    printf 'remote_main=%s\n' "$toolbox_remote_main"
    if [[ "$toolbox_remote_main" == "$toolbox_head" ]]; then
      pass "toolbox_main_current"
    else
      warn "toolbox_main_update_available"
    fi
  else
    sed -n '1,80p' "$LS_REMOTE"
    fail "toolbox_remote_main_unreachable"
  fi

  if [[ -f "$TOOLBOX/verify/verify-termux-toolbox.sh" ]]; then
    if TMPDIR="$TMP_ROOT" bash "$TOOLBOX/verify/verify-termux-toolbox.sh"; then
      pass "toolbox_repo_verify"
    else
      fail "toolbox_repo_verify_failed"
    fi
  else
    fail "toolbox_verify_script_missing"
  fi

  section "installed_parity"
  checked_count=0
  missing_count=0
  mismatch_count=0
  while IFS= read -r -d '' source_file; do
    name="$(basename "$source_file")"
    installed_file="$PREFIX_DIR/bin/$name"
    checked_count=$((checked_count + 1))
    if [[ ! -f "$installed_file" ]]; then
      printf 'MISSING: %s\n' "$installed_file"
      missing_count=$((missing_count + 1))
      continue
    fi
    source_sha="$(sha256sum "$source_file" | awk '{print $1}')"
    installed_sha="$(sha256sum "$installed_file" | awk '{print $1}')"
    if [[ "$source_sha" == "$installed_sha" ]]; then
      printf 'MATCH: %s\n' "$name"
    else
      printf 'MISMATCH: %s\n' "$name"
      mismatch_count=$((mismatch_count + 1))
    fi
  done < <(find "$TOOLBOX/bin" -maxdepth 1 -type f -print0 | LC_ALL=C sort -z)

  printf 'checked_count=%s\n' "$checked_count"
  printf 'missing_count=%s\n' "$missing_count"
  printf 'mismatch_count=%s\n' "$mismatch_count"
  if [[ "$missing_count" -gt 0 || "$mismatch_count" -gt 0 ]]; then
    warn "toolbox_install_not_in_sync"
  else
    pass "toolbox_install_in_sync"
  fi
fi

section "audit_result"
if [[ "$failures" -gt 0 ]]; then
  audit_status=FAIL
elif [[ "$warnings" -gt 0 ]]; then
  audit_status=WARN
else
  audit_status=PASS
fi

{
  printf 'AUDIT_FORMAT=TERMUX_TOOLBOX_MAINTENANCE_V1\n'
  printf 'AUDIT_RUN_ID=%s\n' "$RUN_ID"
  printf 'AUDIT_EPOCH=%s\n' "$(date +%s)"
  printf 'AUDIT_STATUS=%s\n' "$audit_status"
  printf 'APPLY_ALLOWED=%s\n' "$apply_allowed"
  printf 'TOOLBOX_PATH=%s\n' "$TOOLBOX"
  printf 'TOOLBOX_HEAD=%s\n' "$toolbox_head"
  printf 'TOOLBOX_REMOTE_MAIN=%s\n' "$toolbox_remote_main"
  printf 'TOOLBOX_DIRTY=%s\n' "$toolbox_dirty"
  printf 'REPORT_PATH=%s\n' "$REPORT"
} >"$STATE"
chmod 0600 "$STATE"

printf 'warnings=%s\n' "$warnings"
printf 'failures=%s\n' "$failures"
printf 'apply_allowed=%s\n' "$apply_allowed"
printf 'state=%s\n' "$STATE"
printf 'report=%s\n' "$REPORT"
printf 'RESULT: TERMUX_TOOLBOX_ENVIRONMENT_AUDIT_DONE status=%s apply_allowed=%s\n' "$audit_status" "$apply_allowed"

if [[ "$apply_allowed" != "yes" ]]; then
  exit 2
fi
