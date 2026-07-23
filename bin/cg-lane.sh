#!/usr/bin/env bash
set -euo pipefail

VERSION="cg-multilane-v1.3"
STATE_DIR="${CG_LANE_STATE_DIR:-$HOME/.chatgpt-lanes}"
OUTPUT_DIR="${CG_OUTPUT_DIR:-$HOME/.chatgpt-output}"
CURRENT_FILE="$STATE_DIR/current_lane"
LANES_DIR="$STATE_DIR/lanes"
LOCKS_DIR="$STATE_DIR/locks"
RUNS_DIR="$STATE_DIR/runs"

log() { printf '%s\n' "$*"; }
die() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

sanitize_id() {
  local raw="${1:-}" label="${2:-id}"
  [ -n "$raw" ] || die "${label}_missing"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    *[!a-z0-9._-]* ) die "${label}_invalid_chars allowed=a-z0-9._- value=$raw" ;;
  esac
  [ "${#raw}" -le 80 ] || die "${label}_too_long"
  printf '%s\n' "$raw"
}

safe_task_label() {
  local value="${1:-unknown}"
  value="${value##*/}"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._@+-' '_')"
  value="${value##_}"
  value="${value%%_}"
  [ -n "$value" ] || value="unknown"
  printf '%.120s\n' "$value"
}

require_init() {
  mkdir -p "$LANES_DIR" "$LOCKS_DIR" "$RUNS_DIR" "$OUTPUT_DIR"
  if [ ! -s "$CURRENT_FILE" ]; then
    printf 'default\n' > "$CURRENT_FILE"
    mkdir -p "$LANES_DIR/default"
    write_meta "default" "pixel" "pixel-local" "none" "none" "bootstrap"
  fi
}

current_lane() {
  require_init
  sanitize_id "$(cat "$CURRENT_FILE")" lane
}

meta_path() {
  local lane="$1"
  printf '%s/%s/meta.env\n' "$LANES_DIR" "$lane"
}

write_meta() {
  local lane="$1" scope="$2" host="$3" route_class="$4" secret_class="$5" reason="${6:-manual}"
  mkdir -p "$LANES_DIR/$lane"
  {
    printf 'CG_LANE_ID=%s\n' "$lane"
    printf 'CG_LANE_SCOPE=%s\n' "$scope"
    printf 'CG_LANE_HOST=%s\n' "$host"
    printf 'CG_LANE_ROUTE_CLASS=%s\n' "$route_class"
    printf 'CG_LANE_SECRET_CLASS=%s\n' "$secret_class"
    printf 'CG_LANE_REASON=%s\n' "$reason"
    printf 'CG_LANE_UPDATED_AT=%s\n' "$(date -Is)"
    printf 'CG_LANE_VERSION=%s\n' "$VERSION"
  } > "$(meta_path "$lane")"
}

read_meta_value() {
  local lane="$1" key="$2" file
  file="$(meta_path "$lane")"
  [ -f "$file" ] || return 1
  awk -F= -v k="$key" '$1==k {print substr($0, length($1)+2)}' "$file" | tail -n 1
}

latest_global_log() {
  local p="$OUTPUT_DIR/latest.log"
  if [ -L "$p" ] || [ -f "$p" ]; then
    readlink -f "$p" 2>/dev/null || printf '%s\n' "$p"
  fi
}

link_lane_latest() {
  local lane="$1" run_id="$2" log_path="$3"
  [ -n "$log_path" ] || return 0
  [ -f "$log_path" ] || return 0
  mkdir -p "$LANES_DIR/$lane"
  ln -sfn "$log_path" "$LANES_DIR/$lane/latest.log"
  printf '%s\n' "$log_path" > "$LANES_DIR/$lane/latest.path"
  printf '%s\n' "$run_id" > "$LANES_DIR/$lane/latest.run_id"
}

route_guard() {
  local route_class="$1"
  case "$route_class" in
    none|read-only) return 0 ;;
    route-sensitive|dns-ha|magicdns|subnet-route|default-route)
      die "route_class_blocked_in_cg_multilane_v13 route_class=$route_class"
      ;;
    *) die "route_class_unknown route_class=$route_class" ;;
  esac
}

secret_guard() {
  local secret_class="$1"
  case "$secret_class" in
    none|public|redacted|possible|sensitive) return 0 ;;
    *) die "secret_class_unknown secret_class=$secret_class" ;;
  esac
}

verify_script_file() {
  local script="$1" first
  [ -f "$script" ] || die "script_missing path=$script"
  [ -s "$script" ] || die "script_empty path=$script"
  if grep -q $'\r' "$script"; then
    die "script_crlf_present path=$script"
  fi
  first="$(head -n 1 "$script")"
  case "$first" in
    '#!/usr/bin/env bash'|'#!/bin/bash'|'#!/system/bin/sh'|'#!/usr/bin/env sh'|'#!/bin/sh') ;;
    *) die "script_shebang_missing_or_unsupported first_line=$first" ;;
  esac
  [ -x "$script" ] || die "script_not_executable path=$script"
  case "$first" in
    '#!/usr/bin/env bash'|'#!/bin/bash') bash -n "$script" || die "script_bash_syntax path=$script" ;;
    *) sh -n "$script" || die "script_sh_syntax path=$script" ;;
  esac
}

acquire_lock() {
  local name="$1" run_id="$2" path
  path="$LOCKS_DIR/$name"
  if mkdir "$path" 2>/dev/null; then
    printf '%s\n' "$run_id" > "$path/run_id"
    printf '%s\n' "$$" > "$path/pid"
    printf '%s\n' "$(date -Is)" > "$path/created_at"
    return 0
  fi
  die "lock_busy lock=$name holder=$(cat "$path/run_id" 2>/dev/null || true)"
}

release_lock() {
  local name="$1"
  rm -rf "$LOCKS_DIR/$name" 2>/dev/null || true
}

cmd_init() {
  require_init
  log "version=$VERSION"
  log "state_dir=$STATE_DIR"
  log "output_dir=$OUTPUT_DIR"
  log "RESULT: CG_MULTILANE_INIT_OK"
}

cmd_use() {
  require_init
  local lane scope host route_class secret_class
  lane="$(sanitize_id "${1:-}" lane)"
  scope="$(sanitize_id "${2:-pixel}" scope)"
  host="$(sanitize_id "${3:-pixel-local}" host)"
  route_class="${4:-none}"
  secret_class="${5:-none}"
  route_guard "$route_class"
  secret_guard "$secret_class"
  write_meta "$lane" "$scope" "$host" "$route_class" "$secret_class" "cguse"
  printf '%s\n' "$lane" > "$CURRENT_FILE"
  log "lane=$lane"
  log "scope=$scope"
  log "host=$host"
  log "route_class=$route_class"
  log "secret_class=$secret_class"
  log "RESULT: CG_MULTILANE_USE_OK"
}

cmd_current() {
  local lane
  lane="$(current_lane)"
  log "lane=$lane"
  if [ -f "$(meta_path "$lane")" ]; then
    cat "$(meta_path "$lane")"
  fi
  log "RESULT: CG_MULTILANE_CURRENT_OK"
}

cmd_list() {
  require_init
  local cur
  cur="$(current_lane)"
  log "== lanes =="
  find "$LANES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | while IFS= read -r lane; do
    [ -n "$lane" ] || continue
    local mark scope host route secret
    mark=" "
    [ "$lane" = "$cur" ] && mark="*"
    scope="$(read_meta_value "$lane" CG_LANE_SCOPE || true)"
    host="$(read_meta_value "$lane" CG_LANE_HOST || true)"
    route="$(read_meta_value "$lane" CG_LANE_ROUTE_CLASS || true)"
    secret="$(read_meta_value "$lane" CG_LANE_SECRET_CLASS || true)"
    printf '%s %s scope=%s host=%s route=%s secret=%s\n' "$mark" "$lane" "${scope:-unknown}" "${host:-unknown}" "${route:-unknown}" "${secret:-unknown}"
  done
  log "RESULT: CG_MULTILANE_LIST_OK"
}

cmd_status() {
  require_init
  local cur
  cur="$(current_lane)"
  log "version=$VERSION"
  log "state_dir=$STATE_DIR"
  log "output_dir=$OUTPUT_DIR"
  log "current_lane=$cur"
  log "== locks =="
  find "$LOCKS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort || true
  log "== lane status =="
  find "$LANES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | while IFS= read -r lane; do
    [ -n "$lane" ] || continue
    local runid logpath bytes lines result
    runid="$(cat "$LANES_DIR/$lane/latest.run_id" 2>/dev/null || true)"
    logpath="$(cat "$LANES_DIR/$lane/latest.path" 2>/dev/null || true)"
    bytes="missing"
    lines="missing"
    result="missing"
    if [ -f "$logpath" ]; then
      bytes="$(wc -c < "$logpath" | tr -d ' ')"
      lines="$(wc -l < "$logpath" | tr -d ' ')"
      result="$(grep -E 'RESULT:|FAIL:|ERROR:|STOP:' "$logpath" | tail -n 1 || true)"
    fi
    printf '%s run=%s bytes=%s lines=%s last="%s"\n' "$lane" "${runid:-none}" "$bytes" "$lines" "$result"
  done
  log "RESULT: CG_MULTILANE_STATUS_OK"
}

cmd_tail() {
  require_init
  local lane_or_run="${1:-$(current_lane)}" lines="${2:-120}" logpath=""
  case "$lines" in *[!0-9]*|'') die "lines_must_be_integer" ;; esac
  if [ -f "$RUNS_DIR/$lane_or_run/log.path" ]; then
    logpath="$(cat "$RUNS_DIR/$lane_or_run/log.path")"
  else
    local lane
    lane="$(sanitize_id "$lane_or_run" lane)"
    logpath="$(cat "$LANES_DIR/$lane/latest.path" 2>/dev/null || true)"
  fi
  [ -n "$logpath" ] || die "log_not_found target=$lane_or_run"
  [ -f "$logpath" ] || die "log_path_missing path=$logpath"
  log "== cgtail-lane target=$lane_or_run lines=$lines log=$logpath =="
  tail -n "$lines" "$logpath"
  log "RESULT: CG_MULTILANE_TAIL_OK chat_lane=$lane_or_run"
}

cmd_run_file() {
  require_init
  local script="${1:-}" mode="${2:-VERIFY}" scope_arg="${3:-}"
  local lane scope host route secret run_id run_dir lock_name log_path rc wrapper wrapper_q script_q task_label outcome result_marker
  [ -n "$script" ] || die "script_arg_missing"
  script="$(readlink -f "$script")"
  verify_script_file "$script"
  lane="$(current_lane)"
  scope="${scope_arg:-$(read_meta_value "$lane" CG_LANE_SCOPE || printf 'pixel')}"
  host="$(read_meta_value "$lane" CG_LANE_HOST || printf 'pixel-local')"
  route="$(read_meta_value "$lane" CG_LANE_ROUTE_CLASS || printf 'none')"
  secret="$(read_meta_value "$lane" CG_LANE_SECRET_CLASS || printf 'none')"
  route_guard "$route"
  secret_guard "$secret"
  command -v cgrun >/dev/null 2>&1 || die "cgrun_missing"
  run_id="$(date +%Y%m%d_%H%M%S)_${lane}_${mode}_${scope}_$$_$RANDOM"
  run_dir="$RUNS_DIR/$run_id"
  task_label="$(safe_task_label "$script")"
  mkdir -p "$run_dir"
  {
    printf 'CG_LANE_VERSION=%s\n' "$VERSION"
    printf 'CG_LANE_ID=%s\n' "$lane"
    printf 'CG_RUN_ID=%s\n' "$run_id"
    printf 'CG_RUN_MODE=%s\n' "$mode"
    printf 'CG_RUN_SCOPE=%s\n' "$scope"
    printf 'CG_RUN_HOST=%s\n' "$host"
    printf 'CG_RUN_ROUTE_CLASS=%s\n' "$route"
    printf 'CG_RUN_SECRET_CLASS=%s\n' "$secret"
    printf 'CG_RUN_SCRIPT=%s\n' "$script"
    printf 'CG_RUN_TASK=%s\n' "$task_label"
    printf 'CG_RUN_STARTED_AT=%s\n' "$(date -Is)"
  } > "$run_dir/meta.env"
  lock_name="lane-$lane"
  acquire_lock "$lock_name" "$run_id"
  rc=0
  wrapper="$run_dir/run_wrapper.sh"
  printf -v script_q '%q' "$script"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -uo pipefail\n'
    printf 'export CG_LANE_ID=%q\n' "$lane"
    printf 'export CG_LANE_SCOPE=%q\n' "$scope"
    printf 'export CG_LANE_HOST=%q\n' "$host"
    printf 'export CG_LANE_ROUTE_CLASS=%q\n' "$route"
    printf 'export CG_LANE_SECRET_CLASS=%q\n' "$secret"
    printf 'export CG_RUN_ID=%q\n' "$run_id"
    printf 'export CG_RUN_MODE=%q\n' "$mode"
    printf 'export CG_RUN_SCOPE=%q\n' "$scope"
    printf 'export CG_RUN_HOST=%q\n' "$host"
    printf 'export CG_RUN_SCRIPT=%q\n' "$script"
    printf "printf '%%s\\n' 'CG_MULTILANE_PAYLOAD_START'\n"
    printf 'bash %s\n' "$script_q"
    printf 'payload_exit_code=$?\n'
    printf "printf 'CG_MULTILANE_PAYLOAD_DONE payload_exit_code=%%s\\n' \"\$payload_exit_code\"\n"
    printf 'exit "$payload_exit_code"\n'
  } > "$wrapper"
  chmod 0755 "$wrapper"
  bash -n "$wrapper"
  printf -v wrapper_q '%q' "$wrapper"
  {
    log "CG_MULTILANE_HEADER lane=$lane run_id=$run_id mode=$mode scope=$scope host=$host route_class=$route secret_class=$secret script=$script"
    CG_LANE_ID="$lane" \
    CG_LANE_SCOPE="$scope" \
    CG_LANE_HOST="$host" \
    CG_LANE_ROUTE_CLASS="$route" \
    CG_LANE_SECRET_CLASS="$secret" \
    CG_RUN_ID="$run_id" \
    CG_RUN_MODE="$mode" \
    CG_RUN_SCOPE="$scope" \
    CG_RUN_HOST="$host" \
    CG_RUN_SCRIPT="$script" \
      cgrun "bash $wrapper_q"
  } || rc=$?
  log_path="$(latest_global_log || true)"
  if [ -n "$log_path" ]; then
    printf '%s\n' "$log_path" > "$run_dir/log.path"
    link_lane_latest "$lane" "$run_id" "$log_path"
  fi
  printf '%s\n' "$rc" > "$run_dir/rc"
  printf '%s\n' "$rc" > "$run_dir/workflow_exit_code"
  printf '%s\n' "$(date -Is)" > "$run_dir/finished_at"
  release_lock "$lock_name"

  if [ "$rc" -eq 0 ]; then
    outcome="success"
    result_marker="CG_MULTILANE_RUN_FILE_OK"
  else
    outcome="payload_failed"
    result_marker="CG_MULTILANE_RUN_FILE_FAILED"
    log "FAIL: $result_marker outcome=$outcome workflow_exit_code=$rc chat_lane=$lane task=$task_label run_id=$run_id log=$log_path" >&2
  fi

  log "== cg multilane completion =="
  log "outcome=$outcome"
  log "chat_lane=$lane"
  log "task=$task_label"
  log "scope=$scope"
  log "host=$host"
  log "route_class=$route"
  log "secret_class=$secret"
  log "run_id=$run_id"
  log "workflow_exit_code=$rc"
  log "log_path=$log_path"
  log "RESULT: $result_marker outcome=$outcome chat_lane=$lane task=$task_label run_id=$run_id workflow_exit_code=$rc log=$log_path"
  return "$rc"
}

cmd_adopt() {
  require_init
  local logpath="${1:-}" lane="${2:-$(current_lane)}" run_id
  [ -n "$logpath" ] || die "logpath_missing"
  logpath="$(readlink -f "$logpath")"
  [ -f "$logpath" ] || die "logpath_not_file path=$logpath"
  lane="$(sanitize_id "$lane" lane)"
  run_id="adopted_$(date +%Y%m%d_%H%M%S)_$lane"
  mkdir -p "$RUNS_DIR/$run_id"
  printf '%s\n' "$logpath" > "$RUNS_DIR/$run_id/log.path"
  printf 'adopted\n' > "$RUNS_DIR/$run_id/rc"
  link_lane_latest "$lane" "$run_id" "$logpath"
  log "RESULT: CG_MULTILANE_ADOPT_OK chat_lane=$lane run_id=$run_id log=$logpath"
}

cmd_unlock_stale() {
  require_init
  local lock="${1:-}" path pid
  [ -n "$lock" ] || die "lock_missing"
  lock="$(sanitize_id "$lock" lock)"
  path="$LOCKS_DIR/$lock"
  [ -d "$path" ] || die "lock_not_found lock=$lock"
  pid="$(cat "$path/pid" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    die "lock_pid_alive lock=$lock pid=$pid"
  fi
  rm -rf "$path"
  log "RESULT: CG_MULTILANE_UNLOCK_STALE_OK lock=$lock"
}

usage() {
  printf '%s\n' 'Usage:'
  printf '%s\n' '  cg-lane.sh init'
  printf '%s\n' '  cg-lane.sh use <lane> [scope] [host] [route_class] [secret_class]'
  printf '%s\n' '  cg-lane.sh current'
  printf '%s\n' '  cg-lane.sh list'
  printf '%s\n' '  cg-lane.sh status'
  printf '%s\n' '  cg-lane.sh tail [lane_or_run_id] [lines]'
  printf '%s\n' '  cg-lane.sh run-file <script> [mode] [scope]'
  printf '%s\n' '  cg-lane.sh adopt <log_path> [lane]'
  printf '%s\n' '  cg-lane.sh unlock-stale <lock>'
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    init) cmd_init "$@" ;;
    use) cmd_use "$@" ;;
    current) cmd_current "$@" ;;
    list) cmd_list "$@" ;;
    status) cmd_status "$@" ;;
    tail) cmd_tail "$@" ;;
    run-file) cmd_run_file "$@" ;;
    adopt) cmd_adopt "$@" ;;
    unlock-stale) cmd_unlock_stale "$@" ;;
    -h|--help|help|'') usage ;;
    *) die "unknown_command=$cmd" ;;
  esac
}

main "$@"
