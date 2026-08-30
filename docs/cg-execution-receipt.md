# CG Execution Receipt v2

## Purpose

Every `cgrun` completion binds command evidence, handoff evidence and semantic workflow diagnosis to one exact execution identity. Numeric exit codes remain the raw evidence; semantic fields are additive and route failures to diagnosis, fix and verify actions without inventing a root cause from a generic number.

`cg-run-file` uses the same `run_id` as the underlying `cgrun` execution, so its lane metadata, exact log, AutoCopy and completion marker describe one run.

## Exact-run identity

Each run has:

- `run_id`: lane/workflow run identifier when one exists
- `execution_id`: exact `cgrun` execution identity; for a lane run it equals `run_id`
- `log_path`: exact bound run log
- `handoff_path`: exact generated AutoCopy payload
- `receipt_path`: final local Receipt v2

Internal consumers do **not** resolve evidence through global `latest.log`. `latest.log` remains a compatibility pointer for manual convenience only.

## Numeric layer exits

- `command_exit_code`: command or payload result
- `helper_exit_code`: bound `cgtail`/diagnostic helper result
- `clipboard_exit_code`: clipboard write/readback result
- `handoff_exit_code`: effective helper/clipboard handoff result
- `workflow_exit_code`: final shell status returned by `cgrun`

A successful command plus failed clipboard is never handoff success. In non-strict mode the shell may still return `workflow_exit_code=0`, but the marker/outcome is `CGRUN_WORKFLOW_DEGRADED` and the semantic exit identifies the handoff defect. `CGRUN_AUTO_TAIL_STRICT=1` promotes handoff failure to the workflow exit.

## Semantic fields

Receipt v2 adds:

- `workflow_exit_id`
- `workflow_exit_class`
- `workflow_exit_stage`
- `workflow_retry_policy`
- `workflow_auto_fix`
- `workflow_diagnosis_id`
- `workflow_fix_id`
- `workflow_verify_id`
- `workflow_exit_confidence`
- `workflow_exit_source`

Examples emitted directly by the Termux producer include `WORKFLOW_OK`, `WORKFLOW_TIMEOUT`, `WORKFLOW_UNCLASSIFIED_NONZERO`, `CGRUN_TAIL_HELPER_FAILED`, `CGRUN_CLIPBOARD_DELIVERY_FAILED` and `CGRUN_CLIPBOARD_READBACK_MISMATCH`.

## Clipboard verification

The outer AutoCopy computes SHA-256 for the exact payload. With the native Termux API, if `termux-clipboard-get` is available and readback verification is enabled, `cgrun` hashes the readback and records only the comparison result:

- `match`
- `mismatch`
- `readback_failed`
- `readback_unavailable`
- `write_only` / `custom_write_only`

The clipboard content itself is not persisted as verification metadata. Sensitive/redacted runs retain their existing redacted handoff policy.

Because the success/failure of the current clipboard write cannot be known before that write occurs, the payload being copied contains a `receipt_version=v2-precopy` envelope with exact run identity, command/helper status and `clipboard_delivery_state=pending_current_write`. The final post-write Receipt v2 is stored locally and printed to the terminal with the real clipboard/handoff status; it is not recursively recopied.

## Result markers

Successful command and handoff:

```text
RESULT: CGRUN_WORKFLOW_OK ... workflow_exit_id=WORKFLOW_OK workflow_exit_code=0
```

Payload failure:

```text
RESULT: CGRUN_WORKFLOW_FAILED ... workflow_exit_id=WORKFLOW_UNCLASSIFIED_NONZERO workflow_exit_code=<n>
```

Successful command but non-strict clipboard/handoff problem:

```text
RESULT: CGRUN_WORKFLOW_DEGRADED ... workflow_exit_id=CGRUN_CLIPBOARD_DELIVERY_FAILED workflow_exit_code=0
```

Generic `rc=<n>` fields are not used by `CGRUN_*` completion markers.

## Input modes

`cgrun` supports two explicit modes:

- `cgrun --shell '<program>'`: intentional `bash -lc` parsing
- `cgrun --exec command arg...`: direct argv-preserving execution

Legacy `cgrun '<program>'` remains a compatibility shell mode. The canonical run-file driver uses `--exec` so its internal arguments are not reconstructed into a shell string.

## Installed runtime contract

The active runtime remains repository-owned:

- `$PREFIX/bin/cgrun`
- `$PREFIX/bin/cgrun-core-v95`
- `$PREFIX/bin/cgtail-core-v95`
- `$PREFIX/bin/cg-lane.sh`
- `$PREFIX/bin/cg-run-file`
- `$PREFIX/bin/cg-run-file-driver-v1`

Historical v9.3 filenames remain compatibility shims only.

Installed-runtime acceptance still requires:

```text
RESULT: CG_INSTALLED_RUNTIME_VERIFY_DONE outcome=success workflow_exit_code=0
```

## Verification

`verify/verify-cg-execution-receipt.sh` covers Receipt v2 success/failure, semantic fields, exact log binding, clipboard hash readback and original artifact task binding.

`verify/verify-termux-io-vnext.sh` additionally covers parallel run isolation, clipboard failure/degraded behavior, readback mismatch, argv fidelity, first-failure diagnostic capture and canonical lane-driver exact-log binding.

Expected focused markers:

```text
RESULT: CG_EXECUTION_RECEIPT_VERIFY_DONE outcome=success workflow_exit_code=0
RESULT: TERMUX_IO_VNEXT_VERIFY_DONE outcome=success workflow_exit_code=0
```
