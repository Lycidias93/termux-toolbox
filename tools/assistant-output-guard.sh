#!/usr/bin/env bash
set -Eeuo pipefail

on_err() {
  local rc="$?"
  printf 'RESULT: ASSISTANT_OUTPUT_GUARD_FAIL rc=%s\n' "$rc"
  exit "$rc"
}
trap on_err ERR

fail=0
say() { printf '%s\n' "$*"; }
pass() { printf 'PASS: %s\n' "$*"; }
err() { printf 'FAIL: %s\n' "$*"; fail=1; }

input="${1:-}"
if [[ -z "$input" || "$input" == '-h' || "$input" == '--help' ]]; then
  say 'Usage: tools/assistant-output-guard.sh <assistant-output-file>'
  say 'Checks one captured assistant output before copy/run.'
  exit 2
fi

[[ -s "$input" ]] || { say "FAIL: missing_or_empty $input"; say 'RESULT: ASSISTANT_OUTPUT_GUARD_FAIL rc=1'; exit 1; }

say '== assistant output guard =='
say "time=$(date -Is)"
say "input=$input"
say

if LC_ALL=C grep -q $'\r' "$input"; then
  err 'crlf_present'
else
  pass 'lf_only'
fi

if grep -Fq 'STATE-GATE' "$input"; then
  pass 'state_gate_present'
else
  err 'state_gate_missing'
fi

cgrun_cmd_re='(^|[^[:alnum:]_./-])cgrun([[:space:];|&)]|$)'
runish_re='```|cgflow|bash -lc|chmod |git |python3|tsu|su -c|ssh '
if grep -Eq "$runish_re" "$input" || grep -Eq "$cgrun_cmd_re" "$input"; then
  if grep -Fq 'Code-output-Hardgate' "$input"; then
    pass 'code_output_hardgate_present'
  else
    err 'code_output_hardgate_missing_for_code_or_run'
  fi
else
  pass 'no_code_or_run_detected'
fi

if grep -Fq 'tools/cgflow' "$input"; then
  pass 'cgflow_present'
elif grep -Eq "$cgrun_cmd_re" "$input"; then
  if grep -Fq 'tools/chatctx ' "$input"; then
    pass 'free_cgrun_has_chatctx'
  else
    err 'free_cgrun_without_cgflow_or_chatctx'
  fi
else
  pass 'no_cgrun_detected'
fi

lt='<'; hd="${lt}${lt}"; hs="${lt}${lt}${lt}"
if grep -Fq "$hd" "$input" || grep -Fq "$hs" "$input"; then
  err 'heredoc_or_herestring_present'
else
  pass 'no_heredoc_herestring'
fi

if grep -Eq '(curl|wget)[^|;]*(\||;)[[:space:]]*(sudo[[:space:]]+)?(bash|sh)' "$input"; then
  err 'network_pipe_to_shell_present'
else
  pass 'no_network_pipe_to_shell'
fi

cgrun_count="$( { grep -Eo "$cgrun_cmd_re" "$input" 2>/dev/null || true; } | wc -l | tr -d ' ')"
if [[ "$cgrun_count" -gt 1 ]]; then
  err 'recursive_cgrun_present'
else
  pass 'no_recursive_cgrun'
fi

if grep -Eq '(bash|sh|python3?|perl|ruby)[[:space:]]+-($|[[:space:]])|(bash|sh)[[:space:]]+-s' "$input"; then
  err 'stdin_interpreter_present'
else
  pass 'no_stdin_interpreter'
fi

if grep -Eq '(base64[[:space:]]+(-d|--decode)|base64_decode|encoded_payload|base64_payload|frombase64)' "$input"; then
  err 'encoded_payload_or_base64_present'
else
  pass 'no_encoded_payload_or_base64'
fi

if grep -Eq "(python3?|perl|ruby|node)[[:space:]]+-c[[:space:]]+['\"]" "$input"; then
  err 'inline_interpreter_payload_present'
else
  pass 'no_inline_interpreter_payload'
fi

flat_input="$(tr '\n' ' ' < "$input")"
if printf '%s\n' "$flat_input" | grep -Eq -- '--log[[:space:]]+[^[:space:]]+.*--copy[[:space:]]+1|--copy[[:space:]]+1.*--log[[:space:]]+'; then
  err 'guard_copy_with_explicit_log_present'
else
  pass 'no_guard_copy_with_explicit_log'
fi

if grep -Fq 'CGRUN_AUTO_TAIL=0' "$input" && grep -Eq "$cgrun_cmd_re" "$input" && grep -Eq 'cgtail-autocopy-guard[.]sh|cgautotail-guard[.]sh|--run-token|--expect-marker' "$input"; then
  missing_meta=0
  for key in CGFLOW_RUN_TOKEN CGFLOW_LANE CGFLOW_SCOPE CGFLOW_HOST CGFLOW_ROUTE_CLASS CGFLOW_SECRET_CLASS CGFLOW_EXPECTED_MARKER; do
    if grep -Fq "echo \"${key}=" "$input" || grep -Fq "printf \"${key}=" "$input" || grep -Fq "printf '${key}=" "$input"; then
      :
    else
      say "FAIL: guarded_cgrun_metadata_echo_missing $key"
      missing_meta=1
      fail=1
    fi
  done
  if [[ "$missing_meta" -eq 0 ]]; then
    pass 'guarded_cgrun_metadata_echo_present'
  fi
else
  pass 'guarded_cgrun_metadata_echo_not_required'
fi

if grep -Fq 'CGRUN_AUTO_TAIL=0' "$input" && grep -Fq 'cgtail' "$input" && grep -Eq "$cgrun_cmd_re" "$input"; then
  if grep -Fq 'set +e' "$input" && grep -Eq 'rc="?\$\?"?' "$input" && grep -Eq '\([[:space:]]*exit[[:space:]]+"?\$rc"?[[:space:]]*\)' "$input"; then
    pass 'cgrun_nonzero_tail_preserved_interactive_safe'
  else
    err 'cgrun_nonzero_can_skip_cgtail_or_close_shell'
  fi
else
  pass 'cgrun_nonzero_tail_pattern_not_detected'
fi

if grep -Fq 'RESULT: CGTAIL_CLIPBOARD_HANDOFF_DONE' "$input"; then
  if grep -Fq 'tools/cgtail-autocopy-guard.sh' "$input" || grep -Fq 'CGTAIL_EXPECT_RESULT=' "$input"; then
    pass 'cgtail_expected_marker_guard_present'
  else
    err 'cgtail_expected_marker_missing'
  fi
else
  pass 'cgtail_clipboard_handoff_not_detected'
fi

if grep -Fq '/tmp' "$input"; then
  err 'hardcoded_tmp_present'
else
  pass 'no_hardcoded_tmp'
fi

if grep -Eq '\.(sha256|sha512)([^[:alnum:]_]|$)' "$input"; then
  err 'sha_sidecar_present'
else
  pass 'no_sha_sidecar'
fi

secret_scan="$(sed -E 's/CGFLOW_RUN_TOKEN=/CGFLOW_RUN_META=/g; s/run_token=/run_meta=/g; s/--run-token/--run-meta/g; s/CG_RUN_TOKEN=/CG_RUN_META=/g; s/RUN_TOKEN=/RUN_META=/g' "$input")"
if printf '%s\n' "$secret_scan" | grep -Eiq '(ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]+|xox[baprs]-|AKIA[0-9A-Z]{16}|BEGIN OPENSSH PRIVATE KEY|BEGIN RSA PRIVATE KEY|password=|token=|secret=)'; then
  err 'secret_smell_present'
else
  pass 'no_secret_smell'
fi

if grep -Fq 'HEIMNETZ_ROUTEGUARD_ACK=1' "$input"; then
  if grep -Fq 'Routeguard:' "$input" && grep -Fq 'keine DNS/HA/VIP/Default-Route' "$input"; then
    pass 'routeguard_ack_has_visible_routeguard_context'
  else
    err 'routeguard_ack_without_visible_routeguard_context'
  fi
else
  pass 'routeguard_ack_not_used'
fi

if grep -Eq 'tools/cgflow|bash -lc' "$input" || grep -Eq "$cgrun_cmd_re" "$input"; then
  if grep -Eq '^RESULT: ' "$input"; then
    pass 'result_marker_present'
  else
    err 'result_marker_missing_for_run'
  fi
else
  pass 'result_marker_not_required'
fi

if [[ "$fail" -eq 0 ]]; then
  say 'RESULT: ASSISTANT_OUTPUT_GUARD_PASS rc=0'
else
  say 'RESULT: ASSISTANT_OUTPUT_GUARD_FAIL rc=1'
  exit 1
fi
