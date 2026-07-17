#!/usr/bin/env bash
set -euo pipefail

umask 077

PREFIX_DIR="${PREFIX:?PREFIX is required}"
OUT_DIR="${TERMUX_TOOLBOX_MAINTENANCE_OUTPUT_DIR:-$HOME/.chatgpt-output/termux-maintenance}"
TOOLBOX="${TERMUX_TOOLBOX_REPO:-$HOME/src/termux-toolbox}"
TMP_ROOT="${TMPDIR:-$PREFIX_DIR/tmp}"
STATE="$OUT_DIR/latest-audit.env"
RUN_ID="$(date '+%Y%m%d_%H%M%S')"
REPORT="$OUT_DIR/update_${RUN_ID}.log"
BACKUP_ROOT="$OUT_DIR/backups/$RUN_ID"
MAX_AUDIT_AGE="${TERMUX_TOOLBOX_MAX_AUDIT_AGE:-3600}"

mkdir -p "$OUT_DIR" "$TMP_ROOT" "$BACKUP_ROOT"
TMP_WORK="$(mktemp -d "$TMP_ROOT/termux-toolbox-update.XXXXXX")"

toolbox_before_sha=""
toolbox_changed=no
install_started=no
success=no
installed_names_manifest="$BACKUP_ROOT/installed-names.txt"
bin_backup_dir="$BACKUP_ROOT/bin"

cleanup_tmp() {
  rm -rf "$TMP_WORK"
}

rollback() {
  set +e
  printf '\n== rollback ==\n'
  printf 'package_rollback=not_automatic\n'

  if [[ "$install_started" == "yes" && -f "$installed_names_manifest" ]]; then
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      rm -f "$PREFIX_DIR/bin/$name"
    done <"$installed_names_manifest"

    if [[ -d "$bin_backup_dir" ]]; then
      find "$bin_backup_dir" -maxdepth 1 -type f -print0 \
        | while IFS= read -r -d '' saved; do
            install -m 0755 "$saved" "$PREFIX_DIR/bin/$(basename "$saved")"
          done
    fi
    printf 'toolbox_binaries_restore=attempted\n'
  fi

  if [[ "$toolbox_changed" == "yes" && -n "$toolbox_before_sha" && -d "$TOOLBOX/.git" ]]; then
    git -C "$TOOLBOX" reset --hard "$toolbox_before_sha"
    printf 'toolbox_git_restore=%s\n' "$toolbox_before_sha"
  fi
}

on_exit() {
  rc="$?"
  trap - EXIT
  if [[ "$rc" -ne 0 && "$success" != "yes" ]]; then
    rollback
    printf 'backup_root=%s\n' "$BACKUP_ROOT"
    printf 'RESULT: TERMUX_TOOLBOX_MAINTENANCE_UPDATE_FAILED rc=%s\n' "$rc"
  fi
  cleanup_tmp
  exit "$rc"
}
trap on_exit EXIT

exec > >(tee "$REPORT") 2>&1

section() {
  printf '\n== %s ==\n' "$1"
}

pass() {
  printf 'PASS: %s\n' "$1"
}

section "audit_gate"
if [[ ! -f "$STATE" ]]; then
  printf 'FAIL: audit_state_missing\n'
  exit 20
fi

state_uid="$(stat -c '%u' "$STATE")"
state_mode="$(stat -c '%a' "$STATE")"
if [[ "$state_uid" != "$(id -u)" ]]; then
  printf 'FAIL: audit_state_owner_mismatch\n'
  exit 21
fi
case "$state_mode" in
  600|400) ;;
  *)
    printf 'FAIL: audit_state_permissions mode=%s\n' "$state_mode"
    exit 22
    ;;
esac

audit_format="$(sed -n 's/^AUDIT_FORMAT=//p' "$STATE")"
audit_epoch="$(sed -n 's/^AUDIT_EPOCH=//p' "$STATE")"
apply_allowed="$(sed -n 's/^APPLY_ALLOWED=//p' "$STATE")"
audited_head="$(sed -n 's/^TOOLBOX_HEAD=//p' "$STATE")"
audited_dirty="$(sed -n 's/^TOOLBOX_DIRTY=//p' "$STATE")"

if [[ "$audit_format" != "TERMUX_TOOLBOX_MAINTENANCE_V1" ]]; then
  printf 'FAIL: audit_format_invalid\n'
  exit 23
fi
if [[ ! "$audit_epoch" =~ ^[0-9]+$ ]]; then
  printf 'FAIL: audit_epoch_invalid\n'
  exit 24
fi

audit_age=$(( $(date +%s) - audit_epoch ))
printf 'audit_age_seconds=%s\n' "$audit_age"
printf 'apply_allowed=%s\n' "$apply_allowed"

if [[ "$audit_age" -lt 0 || "$audit_age" -gt "$MAX_AUDIT_AGE" ]]; then
  printf 'FAIL: audit_too_old max_age=%s\n' "$MAX_AUDIT_AGE"
  exit 25
fi
if [[ "$apply_allowed" != "yes" ]]; then
  printf 'FAIL: audit_blocked_apply\n'
  exit 26
fi
if [[ "$audited_dirty" != "no" ]]; then
  printf 'FAIL: audited_toolbox_not_clean\n'
  exit 27
fi
pass "audit_gate"

section "live_preflight"
if [[ ! -d "$TOOLBOX/.git" ]]; then
  printf 'FAIL: toolbox_repo_missing\n'
  exit 28
fi
if [[ "$(git -C "$TOOLBOX" branch --show-current)" != "main" ]]; then
  printf 'FAIL: toolbox_branch_not_main\n'
  exit 29
fi
if [[ -n "$(git -C "$TOOLBOX" status --porcelain=v1)" ]]; then
  printf 'FAIL: toolbox_worktree_became_dirty\n'
  exit 30
fi

live_head="$(git -C "$TOOLBOX" rev-parse HEAD)"
if [[ "$live_head" != "$audited_head" ]]; then
  printf 'FAIL: toolbox_head_changed_since_audit audited=%s live=%s\n' "$audited_head" "$live_head"
  exit 31
fi

DPKG_AUDIT="$TMP_WORK/dpkg-audit.txt"
dpkg --audit >"$DPKG_AUDIT" 2>&1
if [[ -s "$DPKG_AUDIT" ]]; then
  cat "$DPKG_AUDIT"
  printf 'FAIL: dpkg_audit_not_clean\n'
  exit 32
fi
apt-get check
pass "live_preflight"

section "backup"
toolbox_before_sha="$live_head"
pkg list-installed >"$BACKUP_ROOT/pkg-list-installed.txt" 2>&1 || true
apt-mark showmanual >"$BACKUP_ROOT/apt-mark-showmanual.txt" 2>&1 || true
dpkg --get-selections >"$BACKUP_ROOT/dpkg-selections.txt" 2>&1 || true
git -C "$TOOLBOX" status --short --branch >"$BACKUP_ROOT/toolbox-git-status.txt"

mkdir -p "$bin_backup_dir"
find "$TOOLBOX/bin" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort >"$installed_names_manifest"
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  if [[ -f "$PREFIX_DIR/bin/$name" ]]; then
    cp -p "$PREFIX_DIR/bin/$name" "$bin_backup_dir/$name"
  fi
done <"$installed_names_manifest"

printf 'toolbox_before_sha=%s\n' "$toolbox_before_sha"
printf 'backup_root=%s\n' "$BACKUP_ROOT"
pass "backup_created"

section "termux_package_update"
pkg update -y
pkg upgrade -y
dpkg --audit >"$DPKG_AUDIT" 2>&1
if [[ -s "$DPKG_AUDIT" ]]; then
  cat "$DPKG_AUDIT"
  printf 'FAIL: dpkg_audit_after_upgrade\n'
  exit 40
fi
apt-get check
python --version
pip --version
pip check
pass "termux_packages_updated"

section "toolbox_git_update"
git -C "$TOOLBOX" fetch --all --prune
git -C "$TOOLBOX" checkout main
git -C "$TOOLBOX" pull --ff-only
toolbox_after_sha="$(git -C "$TOOLBOX" rev-parse HEAD)"
if [[ "$toolbox_after_sha" != "$toolbox_before_sha" ]]; then
  toolbox_changed=yes
fi
printf 'toolbox_after_sha=%s\n' "$toolbox_after_sha"
if [[ -n "$(git -C "$TOOLBOX" status --porcelain=v1)" ]]; then
  printf 'FAIL: toolbox_dirty_after_pull\n'
  exit 41
fi
pass "toolbox_git_updated"

section "toolbox_verify_install"
TMPDIR="$TMP_ROOT" bash "$TOOLBOX/verify/verify-termux-toolbox.sh"
install_started=yes
find "$TOOLBOX/bin" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort >"$installed_names_manifest"
bash "$TOOLBOX/install.sh"
hash -r
pass "toolbox_verify_install"

section "installed_parity"
missing_count=0
mismatch_count=0
while IFS= read -r -d '' source_file; do
  name="$(basename "$source_file")"
  installed_file="$PREFIX_DIR/bin/$name"
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

printf 'missing_count=%s\n' "$missing_count"
printf 'mismatch_count=%s\n' "$mismatch_count"
if [[ "$missing_count" -ne 0 || "$mismatch_count" -ne 0 ]]; then
  printf 'FAIL: installed_toolbox_parity\n'
  exit 42
fi
pass "installed_toolbox_parity"

section "post_audit"
bash "$TOOLBOX/maintenance/termux-environment-audit.sh"
pass "post_audit"

section "final"
printf 'package_rollback=not_automatic\n'
printf 'toolbox_rollback_anchor=%s\n' "$toolbox_before_sha"
printf 'backup_root=%s\n' "$BACKUP_ROOT"
printf 'report=%s\n' "$REPORT"
printf 'RESULT: TERMUX_TOOLBOX_MAINTENANCE_UPDATE_DONE rc=0\n'
success=yes
