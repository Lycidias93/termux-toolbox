#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rdc-nontty-handoff.XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT
PREFIX_DIR="$WORK/prefix"
HOME_DIR="$WORK/home"
BIN="$PREFIX_DIR/bin"
SHIM="$WORK/shim"
mkdir -p "$BIN" "$HOME_DIR" "$WORK/tmp" "$SHIM"
for name in cgrun cgrun-core-v95 cgtail-core-v95; do
    install -m 0755 "$ROOT/bin/$name" "$BIN/$name"
done

cat >"$SHIM/termux-clipboard-set" <<'SHIM_SCRIPT'
#!/usr/bin/env bash
printf '%s\n' 'CALLED' >>"$CG_TEST_ANDROID_CLIP_SENTINEL"
exit 89
SHIM_SCRIPT
chmod 0755 "$SHIM/termux-clipboard-set"
cat >"$SHIM/tee" <<'TEE_SCRIPT'
#!/usr/bin/env bash
/usr/bin/tee "$@"
rc=$?
if [[ "${CG_TEST_TEE_FAIL:-0}" == 1 ]]; then exit 47; fi
exit "$rc"
TEE_SCRIPT
chmod 0755 "$SHIM/tee"

cat >"$WORK/custom-writer.sh" <<'CUSTOM_SCRIPT'
#!/usr/bin/env bash
cat >"$CG_TEST_CUSTOM_CLIP_FILE"
CUSTOM_SCRIPT
chmod 0755 "$WORK/custom-writer.sh"

run_case() {
    local run_id="$1"
    shift
    env -i \
        PATH="$SHIM:$BIN:$PATH" \
        PREFIX="$PREFIX_DIR" \
        HOME="$HOME_DIR" \
        TMPDIR="$WORK/tmp" \
        LC_ALL=C \
        CG_TEST_ANDROID_CLIP_SENTINEL="$WORK/android-clipboard.called" \
        CG_TEST_CUSTOM_CLIP_FILE="$WORK/custom-capture" \
        CG_RUN_ID="$run_id" \
        CG_RUN_MODE=verify \
        CGRUN_HEARTBEAT_SECONDS=0 \
        "$@" bash "$BIN/cgrun" "printf '%s\\n' 'RESULT: RDC_NONTYY_PAYLOAD_OK'" >"$WORK/$run_id.out"
}

run_case noninteractive-stream
grep -Fq 'CGRUN_CLIPBOARD_TRANSPORT mode=noninteractive_stream clipboard_write=skipped result=PASS' "$WORK/noninteractive-stream.out"
grep -Fq 'clipboard_verify_state=noninteractive_stream' "$WORK/noninteractive-stream.out"
grep -Fq 'handoff_outcome=stream_only' "$WORK/noninteractive-stream.out"
grep -Fq 'handoff_outcome=stream_only' "$HOME_DIR/.chatgpt-output/runs/noninteractive-stream/receipt.log"
grep -Fq 'tee_exit_code=0' "$HOME_DIR/.chatgpt-output/runs/noninteractive-stream/receipt.log"
grep -Fq 'RESULT: CGRUN_WORKFLOW_OK outcome=success' "$WORK/noninteractive-stream.out"
[[ ! -e "$WORK/android-clipboard.called" ]]
printf '%s\n' 'PASS: noninteractive_android_clipboard_skipped'

run_case explicit-custom CGRUN_CLIPBOARD_COMMAND="$WORK/custom-writer.sh"
grep -Fq 'clipboard_verify_state=custom_write_only' "$WORK/explicit-custom.out"
grep -Fq 'RESULT: CGRUN_WORKFLOW_OK outcome=success' "$WORK/explicit-custom.out"
grep -Fq 'RESULT: RDC_NONTYY_PAYLOAD_OK' "$WORK/custom-capture"
[[ ! -e "$WORK/android-clipboard.called" ]]
printf '%s\n' 'PASS: explicit_clipboard_override_kept'

run_case tee-failed CG_TEST_TEE_FAIL=1
grep -Fq 'CGRUN_CLIPBOARD_TRANSPORT mode=noninteractive_stream clipboard_write=skipped result=FAIL' "$WORK/tee-failed.out"
grep -Fq 'handoff_outcome=stream_failed' "$HOME_DIR/.chatgpt-output/runs/tee-failed/receipt.log"
grep -Fq 'workflow_exit_id=CGRUN_STREAM_DELIVERY_FAILED' "$WORK/tee-failed.out"
grep -Fq 'RESULT: CGRUN_WORKFLOW_DEGRADED' "$WORK/tee-failed.out"
set +e
run_case tee-strict CG_TEST_TEE_FAIL=1 CGRUN_AUTO_TAIL_STRICT=1
strict_rc=$?
set -e
[[ "$strict_rc" -eq 47 ]]
grep -Fq 'RESULT: CGRUN_WORKFLOW_FAILED outcome=handoff_failed' "$WORK/tee-strict.out"
printf '%s\n' 'PASS: tee_transport_failure_propagation'

set +e
env -i PATH="$SHIM:$BIN:$PATH" HOME="$HOME_DIR" TMPDIR="$WORK/tmp" \
  CG_OUTPUT_DIR="$WORK/early-logs" CG_TEST_ANDROID_CLIP_SENTINEL="$WORK/android-clipboard.called" \
  bash "$ROOT/bin/cg-handoff" >"$WORK/early-failure.out" 2>&1
early_rc=$?
set -e
[[ "$early_rc" -eq 2 ]]
grep -Fq 'RESULT: CG_HANDOFF_EARLY_AUTOCOPY_DONE clipboard_exit_code=0' "$WORK/early-failure.out"
grep -Fq 'transport=noninteractive_stream' "$WORK/early-failure.out"
[[ ! -e "$WORK/android-clipboard.called" ]]
printf '%s\n' 'PASS: early_failure_noninteractive_stream'

if command -v script >/dev/null 2>&1; then
    env -i PATH="$SHIM:$BIN:$PATH" PREFIX="$PREFIX_DIR" HOME="$HOME_DIR" TMPDIR="$WORK/tmp" \
        CG_TEST_ANDROID_CLIP_SENTINEL="$WORK/android-clipboard.called" \
        CG_RUN_ID=with-controlling-tty CG_RUN_MODE=verify CGRUN_HEARTBEAT_SECONDS=0 \
        script -q -e -c "bash '$BIN/cgrun' 'printf ok' </dev/null >'$WORK/controlling-tty.out' 2>&1" /dev/null >"$WORK/pty-wrapper.out" 2>&1
    grep -Fq 'CALLED' "$WORK/android-clipboard.called"
    grep -Fq 'clipboard_verify_state=write_only' "$WORK/controlling-tty.out"
    printf '%s\n' 'PASS: redirected_stdio_controlling_tty_keeps_clipboard'
    rm -f "$WORK/android-clipboard.called"
fi

awk '/^has_controlling_tty\(\) \{$/{inside=1} inside{print} inside && /^\}$/{exit}' "$ROOT/bin/cg-handoff" >"$WORK/tty-function.sh"
awk '/^drain_pending_tty_input\(\) \{$/{inside=1} inside{print} inside && /^\}$/{exit}' "$ROOT/bin/cg-handoff" >>"$WORK/tty-function.sh"
grep -Fq 'drain_pending_tty_input() {' "$WORK/tty-function.sh"
env -i PATH="$PATH" bash -c 'source "$1"; drain_pending_tty_input' _ "$WORK/tty-function.sh" </dev/null >"$WORK/tty.out" 2>"$WORK/tty.err"
grep -Fq 'CG_HANDOFF_TTY_DRAIN mode=noninteractive result=not_applicable' "$WORK/tty.out"
[[ ! -s "$WORK/tty.err" ]]
printf '%s\n' 'PASS: noninteractive_tty_drain_skipped'

for script in "$ROOT/bin/cgrun" "$ROOT/bin/cg-handoff" "$ROOT/verify/verify-rdc-noninteractive-handoff-v1.sh"; do
    bash -n "$script"
done
printf '%s\n' 'RESULT: RDC_NONINTERACTIVE_HANDOFF_VERIFY_DONE outcome=success cases=6 workflow_exit_code=0'
