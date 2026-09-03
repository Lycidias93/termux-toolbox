#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF="${CG_HANDOFF_PATH:-$ROOT/bin/cg-handoff}"
TMP_BASE="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "$TMP_BASE/cg-handoff-source-rescue.XXXXXX")"
DOWNLOAD="$WORK/Download"
RESCUE="$WORK/rescue"
BIN="$WORK/bin"
CANONICAL="$WORK/canonical"
CALLED="$WORK/cgbootstrap.called"
trap 'rm -rf -- "$WORK"' EXIT INT TERM HUP

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	printf 'RESULT: CG_HANDOFF_SOURCE_RESCUE_FIXTURE_FAIL outcome=failure workflow_exit_code=1\n' >&2
	exit 1
}

mkdir -p "$DOWNLOAD" "$RESCUE" "$BIN" "$CANONICAL" "$WORK/tmp"
artifact="$CANONICAL/pixel_local__source_rescue_fixture.sh"
{
	printf '%s\n' '#!/usr/bin/env bash'
	printf '%s\n' '# CG_HANDOFF_V1_START'
	printf '%s\n' '# cg_handoff_lane=source-rescue-fixture'
	printf '%s\n' '# cg_handoff_scope=pixel'
	printf '%s\n' '# cg_handoff_host=pixel'
	printf '%s\n' '# cg_handoff_route_class=read-only'
	printf '%s\n' '# cg_handoff_secret_class=redacted'
	printf '%s\n' '# cg_handoff_run_mode=verify'
	printf '%s\n' '# cg_handoff_expected_marker=RESULT: SOURCE_RESCUE_FIXTURE_PAYLOAD_DONE'
	printf '%s\n' '# CG_HANDOFF_V1_END'
	printf '%s\n' "printf 'evidence_collection=complete\\nverdict=pass\\nfailure_count=0\\nwarning_count=0\\n'"
	printf '%s\n' "printf 'RESULT: SOURCE_RESCUE_FIXTURE_PAYLOAD_DONE outcome=success workflow_exit_code=0\\n'"
} >"$artifact"
sha="$(sha256sum "$artifact" | awk '{print $1}')"

for name in cgprep cclear cgcurrent; do
	{
		printf '%s\n' '#!/usr/bin/env bash'
		printf '%s\n' 'exit 0'
	} >"$BIN/$name"
	chmod 0700 "$BIN/$name"
done
{
	printf '%s\n' '#!/usr/bin/env bash'
	printf '%s\n' 'printf "CGUSE:%s\n" "$*"'
} >"$BIN/cguse"
{
	printf '%s\n' '#!/usr/bin/env bash'
	printf '%s\n' 'printf "RUNFILE:%s\n" "$*"'
	printf '%s\n' 'printf "MARKER:%s\n" "${CGFLOW_EXPECTED_MARKER:-}"'
} >"$BIN/cg-run-file"
{
	printf '%s\n' '#!/usr/bin/env bash'
	printf '%s\n' "printf 'RESULT: CGLINT_DONE checked=1 workflow_exit_code=0 mode=default\\n'"
} >"$BIN/cglint"
chmod 0700 "$BIN/cguse" "$BIN/cg-run-file" "$BIN/cglint"

{
	printf '%s\n' '#!/usr/bin/env bash'
	printf '%s\n' 'set -euo pipefail'
	printf '%s\n' ': >"$FIXTURE_CALLED"'
	printf '%s\n' '[[ "${1:-}" == source-rescue && "${2:-}" == pixel_local__source_rescue_fixture.sh ]] || exit 64'
	printf '%s\n' '[[ "${3:-}" =~ ^[0-9a-f]{64}$ ]] || exit 65'
	printf '%s\n' 'if [[ "${CGBOOTSTRAP_FIXTURE_MODE:-ok}" == bad-marker ]]; then'
	printf '%s\n' "  printf 'RESULT: TERMUX_BOOTSTRAP_SOURCE_RESCUE_DONE state=pass source_rescue_root=/invalid basename=wrong.sh sha256=%s workflow_exit_code=0\\n' \"$sha\""
	printf '%s\n' '  exit 0'
	printf '%s\n' 'fi'
	printf '%s\n' 'mkdir -p "$FIXTURE_RESCUE"'
	printf '%s\n' 'install -m 0600 "$FIXTURE_CANONICAL" "$FIXTURE_RESCUE/$2"'
	printf '%s\n' 'actual="$(sha256sum "$FIXTURE_RESCUE/$2" | awk '\''{print $1}'\'')"'
	printf '%s\n' '[[ "$actual" == "$3" ]] || exit 66'
	printf '%s\n' 'printf "RESULT: TERMUX_BOOTSTRAP_SOURCE_RESCUE_DONE state=pass source_rescue_root=%s basename=%s sha256=%s workflow_exit_code=0\n" "$FIXTURE_RESCUE" "$2" "$3"'
} >"$BIN/cgbootstrap"
chmod 0700 "$BIN/cgbootstrap"

[[ -s "$HANDOFF" ]] || fail handoff_missing
grep -Fq 'CG_HANDOFF_SOURCE_RESCUE_V1' "$HANDOFF" || fail source_rescue_marker_missing

rm -f -- "$DOWNLOAD/$(basename "$artifact")" "$CALLED"
output="$(PATH="$BIN:$PATH" FIXTURE_CALLED="$CALLED" FIXTURE_RESCUE="$RESCUE" FIXTURE_CANONICAL="$artifact" CG_HANDOFF_DOWNLOAD_ROOT="$DOWNLOAD" CG_OUTPUT_DIR="$WORK/output-rescue" TMPDIR="$WORK/tmp" CG_HANDOFF_TTY_DRAIN=0 bash "$HANDOFF" "$(basename "$artifact")" "$sha" 2>&1)" || fail rescue_handoff_failed
[[ -s "$CALLED" ]] || fail rescue_provider_not_called
printf '%s\n' "$output" | grep -Fq 'CG_HANDOFF_SOURCE_RESCUE_V1 state=pass provider=cgbootstrap' || fail rescue_accept_marker_missing
printf '%s\n' "$output" | grep -Fq 'RUNFILE:' || fail rescued_payload_not_dispatched
printf '%s\n' "$output" | grep -Fq 'MARKER:RESULT: SOURCE_RESCUE_FIXTURE_PAYLOAD_DONE' || fail rescued_expected_marker_missing
printf '%s\n' 'PASS missing_source_rescued_by_hash_bound_provider'

rm -rf -- "$RESCUE"
mkdir -p "$RESCUE"
rm -f -- "$CALLED"
set +e
bad_output="$(PATH="$BIN:$PATH" FIXTURE_CALLED="$CALLED" FIXTURE_RESCUE="$RESCUE" FIXTURE_CANONICAL="$artifact" CGBOOTSTRAP_FIXTURE_MODE=bad-marker CG_HANDOFF_DOWNLOAD_ROOT="$DOWNLOAD" CG_OUTPUT_DIR="$WORK/output-bad" TMPDIR="$WORK/tmp" CG_HANDOFF_TTY_DRAIN=0 bash "$HANDOFF" "$(basename "$artifact")" "$sha" 2>&1)"
bad_rc=$?
set -e
[[ "$bad_rc" -eq 2 ]] || fail malformed_rescue_marker_rc
printf '%s\n' "$bad_output" | grep -Fq 'reason=source_missing' || fail malformed_rescue_marker_not_rejected
printf '%s\n' 'PASS malformed_rescue_marker_fails_closed'

install -m 0600 "$artifact" "$DOWNLOAD/$(basename "$artifact")"
rm -f -- "$CALLED"
normal_output="$(PATH="$BIN:$PATH" FIXTURE_CALLED="$CALLED" FIXTURE_RESCUE="$RESCUE" FIXTURE_CANONICAL="$artifact" CG_HANDOFF_DOWNLOAD_ROOT="$DOWNLOAD" CG_OUTPUT_DIR="$WORK/output-normal" TMPDIR="$WORK/tmp" CG_HANDOFF_TTY_DRAIN=0 bash "$HANDOFF" "$(basename "$artifact")" "$sha" 2>&1)" || fail normal_download_handoff_failed
[[ ! -e "$CALLED" ]] || fail rescue_provider_called_for_existing_source
printf '%s\n' "$normal_output" | grep -Fq 'RUNFILE:' || fail normal_source_not_dispatched
printf '%s\n' 'PASS existing_download_source_keeps_normal_path'

printf 'RESULT: CG_HANDOFF_SOURCE_RESCUE_FIXTURE_PASS outcome=success workflow_exit_code=0\n'
