#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDOFF="${CG_HANDOFF_PATH:-$ROOT/bin/cg-handoff}"
TMP_ROOT="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "$TMP_ROOT/cg-handoff-bundle-fixture.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM HUP

fail() {
	printf 'RESULT: CG_HANDOFF_BUNDLE_FIXTURE_STOP outcome=stop reason=%s workflow_exit_code=1\n' "$1"
	exit 1
}

mkdir -p "$WORK/Download" "$WORK/bin" "$WORK/tmp" "$WORK/bundle"
for name in cgprep cclear cgcurrent; do
	printf '#!/usr/bin/env bash\nexit 0\n' >"$WORK/bin/$name"
	chmod 0700 "$WORK/bin/$name"
done
printf '#!/usr/bin/env bash\nprintf '\''CGUSE:%%s\\n'\'' "$*"\n' >"$WORK/bin/cguse"
chmod 0700 "$WORK/bin/cguse"
printf '#!/usr/bin/env bash\nprintf '\''RESULT: CGLINT_DONE checked=1 workflow_exit_code=0 mode=default\\n'\''\n' >"$WORK/bin/cglint"
chmod 0700 "$WORK/bin/cglint"
cat >"$WORK/bin/cg-run-file-driver-v1" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == run ]] || exit 90
script="${2:-}"
mode="${3:-}"
scope="${4:-}"
printf 'RUNFILE:%s %s %s\n' "$script" "$mode" "$scope"
printf 'MARKER:%s\n' "${CGFLOW_EXPECTED_MARKER:-}"
bash "$script"
EOF
chmod 0700 "$WORK/bin/cg-run-file-driver-v1"

entry="$WORK/bundle/pixel_local__bundle_fixture.sh"
{
	printf '%s\n' '#!/data/data/com.termux/files/usr/bin/bash'
	printf '%s\n' '# CG_HANDOFF_V1_START'
	printf '%s\n' '# cg_handoff_lane=bundle-fixture'
	printf '%s\n' '# cg_handoff_scope=pixel'
	printf '%s\n' '# cg_handoff_host=pixel'
	printf '%s\n' '# cg_handoff_route_class=none'
	printf '%s\n' '# cg_handoff_secret_class=redacted'
	printf '%s\n' '# cg_handoff_run_mode=run'
	printf '%s\n' '# cg_handoff_expected_marker=RESULT: BUNDLE_FIXTURE_PASS'
	printf '%s\n' '# CG_HANDOFF_V1_END'
	printf '%s\n' 'set -euo pipefail'
	printf '%s\n' 'source_dir="${CG_RUN_FILE_SOURCE_DIR:-}"'
	printf '%s\n' '[[ -n "$source_dir" ]] || { printf "FAIL: source_context_missing\n"; exit 91; }'
	printf '%s\n' 'runtime_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"'
	printf '%s\n' '[[ "$runtime_dir" != "$source_dir" ]] || { printf "FAIL: normalization_not_exercised\n"; exit 92; }'
	printf '%s\n' '[[ -s "$source_dir/payload.txt" ]] || { printf "FAIL: sibling_payload_missing\n"; exit 93; }'
	printf '%s\n' '[[ "$(cat "$source_dir/payload.txt")" == payload ]] || { printf "FAIL: sibling_payload_mismatch\n"; exit 94; }'
	printf '%s\n' 'printf "SOURCE_CONTEXT:%s\n" "$source_dir"'
	printf '%s\n' 'printf "RESULT: BUNDLE_FIXTURE_PASS\n"'
} >"$entry"
chmod 0700 "$entry"
printf 'payload\n' >"$WORK/bundle/payload.txt"
entry_size="$(wc -c <"$entry" | tr -d '[:space:]')"
entry_sha="$(sha256sum "$entry" | awk '{print $1}')"
payload_size="$(wc -c <"$WORK/bundle/payload.txt" | tr -d '[:space:]')"
payload_sha="$(sha256sum "$WORK/bundle/payload.txt" | awk '{print $1}')"
cat >"$WORK/bundle/BUNDLE_MANIFEST.txt" <<EOF
bundle_format_version=1
entrypoint=pixel_local__bundle_fixture.sh
entrypoint_mode=run
member_count=2
member_1_name=pixel_local__bundle_fixture.sh
member_1_size=$entry_size
member_1_sha256=$entry_sha
member_2_name=payload.txt
member_2_size=$payload_size
member_2_sha256=$payload_sha
EOF
(
	cd "$WORK/bundle"
	zip -q "$WORK/Download/cg-handoff-fixture.zip" BUNDLE_MANIFEST.txt pixel_local__bundle_fixture.sh payload.txt
)
sha="$(sha256sum "$WORK/Download/cg-handoff-fixture.zip" | awk '{print $1}')"
path="$WORK/bin:$ROOT/bin:$PATH"
output="$(PATH="$path" CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" CG_OUTPUT_DIR="$WORK/output-success" TMPDIR="$WORK/tmp" CG_HANDOFF_TTY_DRAIN=0 bash "$HANDOFF" cg-handoff-fixture.zip "$sha")"
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -Fq 'CG_HANDOFF_BUNDLE_V1' || fail bundle_marker_missing
printf '%s\n' "$output" | grep -Fq 'CGUSE:bundle-fixture pixel pixel none redacted' || fail bundle_cguse_binding_failed
printf '%s\n' "$output" | grep -Fq 'RUNFILE:' || fail bundle_run_file_missing
printf '%s\n' "$output" | grep -Fq 'cg-run-file-normalized.' || fail cg_run_file_normalization_not_exercised
printf '%s\n' "$output" | grep -Fq ' run pixel' || fail bundle_run_file_args_failed
printf '%s\n' "$output" | grep -Fq 'MARKER:RESULT: BUNDLE_FIXTURE_PASS' || fail bundle_expected_marker_failed
printf '%s\n' "$output" | grep -Fq 'SOURCE_CONTEXT:' || fail bundle_source_context_missing
printf '%s\n' "$output" | grep -Fq 'RESULT: BUNDLE_FIXTURE_PASS' || fail bundle_entrypoint_not_executed
printf '%s\n' 'PASS bundle_sibling_context_survives_normalization'
printf '%s\n' 'PASS bundle_success'

mkdir -p "$WORK/tampered"
(
	cd "$WORK/tampered"
	unzip -q "$WORK/Download/cg-handoff-fixture.zip"
	printf 'tamper\n' >>payload.txt
	zip -q "$WORK/Download/cg-handoff-tampered.zip" BUNDLE_MANIFEST.txt pixel_local__bundle_fixture.sh payload.txt
)
tampered_sha="$(sha256sum "$WORK/Download/cg-handoff-tampered.zip" | awk '{print $1}')"
set +e
tampered_output="$(PATH="$path" CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" CG_OUTPUT_DIR="$WORK/output-tampered" TMPDIR="$WORK/tmp" CG_HANDOFF_TTY_DRAIN=0 bash "$HANDOFF" cg-handoff-tampered.zip "$tampered_sha" 2>&1)"
tampered_rc=$?
set -e
[[ "$tampered_rc" -eq 2 ]] || fail bundle_tampered_rc
printf '%s\n' "$tampered_output" | grep -Eq 'reason=bundle_member_2_(size|sha)_mismatch' || fail bundle_tampered_reason
printf '%s\n' 'PASS bundle_member_integrity'

mkdir -p "$WORK/unexpected"
cp "$WORK/bundle/"* "$WORK/unexpected/"
printf 'extra\n' >"$WORK/unexpected/extra.txt"
(
	cd "$WORK/unexpected"
	zip -q "$WORK/Download/cg-handoff-unexpected.zip" BUNDLE_MANIFEST.txt pixel_local__bundle_fixture.sh payload.txt extra.txt
)
unexpected_sha="$(sha256sum "$WORK/Download/cg-handoff-unexpected.zip" | awk '{print $1}')"
set +e
unexpected_output="$(PATH="$path" CG_HANDOFF_DOWNLOAD_ROOT="$WORK/Download" CG_OUTPUT_DIR="$WORK/output-unexpected" TMPDIR="$WORK/tmp" CG_HANDOFF_TTY_DRAIN=0 bash "$HANDOFF" cg-handoff-unexpected.zip "$unexpected_sha" 2>&1)"
unexpected_rc=$?
set -e
[[ "$unexpected_rc" -eq 2 ]] || fail bundle_unexpected_rc
printf '%s\n' "$unexpected_output" | grep -Fq 'reason=bundle_unexpected_member_count' || fail bundle_unexpected_reason
printf '%s\n' 'PASS bundle_unexpected_member_rejected'

printf 'RESULT: CG_HANDOFF_BUNDLE_FIXTURE_PASS outcome=success workflow_exit_code=0\n'
