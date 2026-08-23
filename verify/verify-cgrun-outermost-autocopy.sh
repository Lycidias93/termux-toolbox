#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cgrun-outermost-autocopy.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

PREFIX_DIR="$TMP_ROOT/prefix"
HOME_DIR="$TMP_ROOT/home"
BIN_DIR="$PREFIX_DIR/bin"
OUT_DIR="$HOME_DIR/.chatgpt-output"
STATE_DIR="$HOME_DIR/.chatgpt-lanes"
TEST_TMP="$TMP_ROOT/tmp"
CLIPBOARD="$TMP_ROOT/clipboard.txt"
COPY_COUNT="$TMP_ROOT/clipboard.count"
PAYLOAD="$TMP_ROOT/nested-payload.sh"
OUTPUT="$TMP_ROOT/outer.out"
mkdir -p "$BIN_DIR" "$OUT_DIR" "$STATE_DIR/lanes/chat-outer" "$TEST_TMP"

for name in \
	cgrun \
	cgrun-core-v95 \
	cgtail-core-v95 \
	cgrun.autoclip-v93-real \
	cgtail-autoclip-v93; do
	install -m 0755 "$ROOT/bin/$name" "$BIN_DIR/$name"
done

cat >"$TMP_ROOT/clipboard-writer.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
count=0
if [[ -s "$CG_TEST_CLIPBOARD_COUNT" ]]; then
	read -r count <"$CG_TEST_CLIPBOARD_COUNT"
fi
count=$((count + 1))
printf '%s\n' "$count" >"$CG_TEST_CLIPBOARD_COUNT"
cat >"$CG_TEST_CLIPBOARD"
SCRIPT
chmod 0755 "$TMP_ROOT/clipboard-writer.sh"

cat >"$PAYLOAD" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf 'nested_cgrun_clipboard=%s\n' "${CGRUN_CLIPBOARD_COMMAND:-unset}"
printf 'nested_handoff_clipboard=%s\n' "${CG_HANDOFF_CLIPBOARD_COMMAND:-unset}"
CG_RUN_ID=inner-run \
	CG_RUN_MODE=verify \
	CGRUN_TASK_LABEL=inner-autocopy-fixture \
	bash "$CG_TEST_BIN/cgrun" "printf '%s\\n' 'RESULT: INNER_AUTOCOPY_FIXTURE_OK'"
SCRIPT
chmod 0755 "$PAYLOAD"

printf '%s\n' 'chat-outer' >"$STATE_DIR/current_lane"
{
	printf '%s\n' 'CG_LANE_ID=chat-outer'
	printf '%s\n' 'CG_LANE_SCOPE=pixel'
	printf '%s\n' 'CG_LANE_HOST=pixel'
	printf '%s\n' 'CG_LANE_ROUTE_CLASS=none'
	printf '%s\n' 'CG_LANE_SECRET_CLASS=public'
} >"$STATE_DIR/lanes/chat-outer/meta.env"

run_clean() {
	env -i \
		PATH="$BIN_DIR:$PATH" \
		PREFIX="$PREFIX_DIR" \
		HOME="$HOME_DIR" \
		TMPDIR="$TEST_TMP" \
		LC_ALL=C \
		CG_LANE_STATE_DIR="$STATE_DIR" \
		CG_TEST_BIN="$BIN_DIR" \
		CG_TEST_CLIPBOARD="$CLIPBOARD" \
		CG_TEST_CLIPBOARD_COUNT="$COPY_COUNT" \
		CGRUN_CLIPBOARD_COMMAND="$TMP_ROOT/clipboard-writer.sh" \
		CGRUN_HEARTBEAT_SECONDS=0 \
		"$@"
}

run_clean \
	CG_RUN_ID=outer-run \
	CG_RUN_MODE=verify \
	CGRUN_TASK_LABEL=outermost-autocopy-fixture \
	bash "$BIN_DIR/cgrun" "bash '$PAYLOAD'" >"$OUTPUT"

grep -Fq 'RESULT: CGRUN_WORKFLOW_OK outcome=success chat_lane=chat-outer task=outermost-autocopy-fixture run_id=outer-run' "$OUTPUT"
[[ -s "$COPY_COUNT" ]] || {
	printf '%s\n' 'FAIL outermost_autocopy_count_missing' >&2
	exit 1
}
copy_count="$(cat "$COPY_COUNT")"
[[ "$copy_count" == "1" ]] || {
	printf 'FAIL outermost_autocopy_count actual=%s expected=1\n' "$copy_count" >&2
	exit 1
}

grep -Fq 'task=outermost-autocopy-fixture' "$CLIPBOARD" || {
	printf '%s\n' 'FAIL outermost_clipboard_receipt_missing' >&2
	exit 1
}

LATEST="$(readlink -f "$OUT_DIR/latest.log")"
grep -Fq 'nested_cgrun_clipboard=/dev/null' "$LATEST" || {
	printf '%s\n' 'FAIL nested_cgrun_clipboard_sink_missing' >&2
	exit 1
}
grep -Fq 'nested_handoff_clipboard=/dev/null' "$LATEST" || {
	printf '%s\n' 'FAIL nested_handoff_clipboard_sink_missing' >&2
	exit 1
}
grep -Fq 'RESULT: INNER_AUTOCOPY_FIXTURE_OK' "$LATEST" || {
	printf '%s\n' 'FAIL nested_result_not_preserved_in_outer_log' >&2
	exit 1
}

printf '%s\n' 'PASS outermost_clipboard_write_exactly_once'
printf '%s\n' 'PASS nested_cgrun_autocopy_suppressed'
printf '%s\n' 'PASS nested_cg_handoff_autocopy_sink_bound'
printf '%s\n' 'PASS nested_result_preserved_in_outer_log'
printf '%s\n' 'RESULT: CGRUN_OUTERMOST_AUTOCOPY_VERIFY_DONE outcome=success workflow_exit_code=0'
