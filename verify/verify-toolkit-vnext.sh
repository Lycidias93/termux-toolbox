#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="${TMPDIR:-${HOME:-.}/.cache/tmp}"
mkdir -p "$TMP_BASE"
WORK="$(mktemp -d "$TMP_BASE/termux-toolkit-vnext-verify.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	printf 'RESULT: TOOLKIT_VNEXT_VERIFY_FAIL workflow_exit_code=1\n' >&2
	exit 1
}

for script in cglint cgdoctor cgfind cgfail cgnotify; do
	path="$ROOT/bin/$script"
	[[ -s "$path" ]] || fail "missing_script path=$path"
	bash -n "$path" || fail "syntax path=$path"
	bash "$path" --help >/dev/null 2>&1 || fail "help_contract script=$script"
	printf 'PASS: script_contract script=%s\n' "$script"
done

printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'printf '\''%s\n'\'' "ok"' >"$WORK/cglint-good.sh"
if ! bash "$ROOT/bin/cglint" "$WORK/cglint-good.sh" >"$WORK/cglint-good.out" 2>&1; then
	cat "$WORK/cglint-good.out" >&2
	fail "cglint_positive_fixture_failed"
fi
grep -Fq 'RESULT: CGLINT_DONE checked=1 workflow_exit_code=0 mode=default' "$WORK/cglint-good.out" || fail "cglint_positive_result_missing"
printf 'PASS: cglint_positive_fixture\n'

printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'unused_value="alpha beta"' 'printf '\''%s\n'\'' "ok"' >"$WORK/cglint-warning-bad.sh"
if bash "$ROOT/bin/cglint" "$WORK/cglint-warning-bad.sh" >"$WORK/cglint-warning-bad.out" 2>&1; then
	fail "cglint_warning_negative_fixture_unexpected_success"
fi
grep -Fq 'RESULT: CGLINT_FAIL' "$WORK/cglint-warning-bad.out" || fail "cglint_warning_negative_result_missing"
printf 'PASS: cglint_warning_negative_fixture\n'

printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'value="alpha beta"' 'printf '\''%s\n'\'' $value' >"$WORK/cglint-info.sh"
if ! bash "$ROOT/bin/cglint" "$WORK/cglint-info.sh" >"$WORK/cglint-info-default.out" 2>&1; then
	cat "$WORK/cglint-info-default.out" >&2
	fail "cglint_default_info_fixture_should_pass"
fi
grep -Fq 'RESULT: CGLINT_DONE checked=1 workflow_exit_code=0 mode=default' "$WORK/cglint-info-default.out" || fail "cglint_default_info_result_missing"
printf 'PASS: cglint_default_info_nonblocking_fixture\n'

if bash "$ROOT/bin/cglint" --strict "$WORK/cglint-info.sh" >"$WORK/cglint-info-strict.out" 2>&1; then
	fail "cglint_strict_info_fixture_unexpected_success"
fi
grep -Fq 'RESULT: CGLINT_FAIL' "$WORK/cglint-info-strict.out" || fail "cglint_strict_info_result_missing"
grep -Fq 'mode=strict' "$WORK/cglint-info-strict.out" || fail "cglint_strict_mode_marker_missing"
printf 'PASS: cglint_strict_info_fixture\n'

printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'if true;then' 'printf '\''%s\\n'\'' "ok"' 'fi' >"$WORK/cglint-format.sh"
format_probe_rc=0
shfmt -d -- "$WORK/cglint-format.sh" >"$WORK/cglint-format-proof.out" 2>"$WORK/cglint-format-proof.err" || format_probe_rc=$?
if [[ "$format_probe_rc" -ne 1 || ! -s "$WORK/cglint-format-proof.out" || -s "$WORK/cglint-format-proof.err" ]]; then
	cat "$WORK/cglint-format-proof.out" >&2 || true
	cat "$WORK/cglint-format-proof.err" >&2 || true
	fail "cglint_format_fixture_not_proven_drifting"
fi
if ! bash "$ROOT/bin/cglint" "$WORK/cglint-format.sh" >"$WORK/cglint-format-default.out" 2>&1; then
	cat "$WORK/cglint-format-default.out" >&2
	fail "cglint_default_shfmt_drift_should_pass"
fi
grep -Fq 'WARN: shfmt_diff_nonblocking' "$WORK/cglint-format-default.out" || fail "cglint_default_shfmt_warning_missing"
grep -Fq 'RESULT: CGLINT_DONE checked=1 workflow_exit_code=0 mode=default' "$WORK/cglint-format-default.out" || fail "cglint_default_shfmt_result_missing"
printf 'PASS: cglint_default_shfmt_nonblocking_fixture\n'

if bash "$ROOT/bin/cglint" --strict "$WORK/cglint-format.sh" >"$WORK/cglint-format-strict.out" 2>&1; then
	fail "cglint_strict_shfmt_drift_unexpected_success"
fi
grep -Fq 'FAIL: shfmt_diff' "$WORK/cglint-format-strict.out" || fail "cglint_strict_shfmt_failure_missing"
grep -Fq 'mode=strict' "$WORK/cglint-format-strict.out" || fail "cglint_strict_shfmt_mode_missing"
printf 'PASS: cglint_strict_shfmt_fixture\n'

printf '%s\n' 'alpha marker' 'beta marker' >"$WORK/search.txt"
bash "$ROOT/bin/cgfind" 'beta marker' "$WORK" >"$WORK/cgfind.out"
grep -Fq 'RESULT: CGFIND_DONE' "$WORK/cgfind.out" || fail "cgfind_result_missing"
grep -Fq 'search.txt' "$WORK/cgfind.out" || fail "cgfind_match_missing"
printf 'PASS: cgfind_fixture\n'

printf '%s\n' \
	'noise line' \
	'FAIL: fixture_failure reason=test' \
	'command_exit_code=7' \
	'RESULT: FIXTURE_DONE outcome=failed workflow_exit_code=7' >"$WORK/run.log"
bash "$ROOT/bin/cgfail" "$WORK/run.log" >"$WORK/cgfail.out"
grep -Fq 'FAIL: fixture_failure reason=test' "$WORK/cgfail.out" || fail "cgfail_failure_marker_missing"
grep -Fq 'RESULT: FIXTURE_DONE' "$WORK/cgfail.out" || fail "cgfail_result_marker_missing"
grep -Fq 'RESULT: CGFAIL_DONE' "$WORK/cgfail.out" || fail "cgfail_completion_missing"
printf 'PASS: cgfail_fixture\n'

bash "$ROOT/bin/cgnotify" --dry-run PASS 'fixture notification' >"$WORK/cgnotify.out"
grep -Fq 'RESULT: CGNOTIFY_DONE mode=dry_run' "$WORK/cgnotify.out" || fail "cgnotify_dry_run_missing"
printf 'PASS: cgnotify_fixture\n'

grep -Fq 'AUTOCLIP_V95_OUTERMOST_CLIPBOARD_OWNER' "$ROOT/bin/cgrun-core-v95" || fail "outermost_autocopy_marker_missing"
[[ -s "$ROOT/verify/verify-cgrun-outermost-autocopy.sh" ]] || fail "outermost_autocopy_verifier_missing"
bash "$ROOT/verify/verify-cgrun-outermost-autocopy.sh" || fail "outermost_autocopy_fixture_failed"
printf 'PASS: cgrun_outermost_autocopy_fixture\n'

printf 'RESULT: TOOLKIT_VNEXT_VERIFY_DONE workflow_exit_code=0\n'
