# CG Execution Receipt v1

## Purpose

Every `cgrun` and `cg-run-file` completion must identify both the executed task and the originating chat lane. The receipt is appended to the mandatory AutoCopy handoff and the outer `cg-run-file` completion repeats the same identity at the terminal end.

## Receipt fields

- `outcome`: semantic result such as `success`, `command_failed`, `handoff_degraded`, or `command_and_handoff_failed`
- `chat_lane`: active `cg-multilane` lane and therefore the originating chat context
- `task`: sanitized artifact basename; direct `cgrun` uses `CGRUN_TASK_LABEL` or `direct-cgrun`
- `task_source`: `artifact` or `direct`
- `scope`
- `host`
- `route_class`
- `secret_class`
- `run_id`
- `run_mode`
- `command_exit_code`
- `log_path`

## Exit-code naming

Generic `rc=<n>` fields are not used by the `CGRUN_*` completion markers. Exit values are named by layer:

- `command_exit_code`: command or payload result
- `helper_exit_code`: cgtail helper result
- `clipboard_exit_code`: Android clipboard write result
- `handoff_exit_code`: effective AutoCopy handoff result
- `workflow_exit_code`: final shell status returned by `cgrun`

Existing `RESULT:` marker parsing remains valid. The marker name communicates `OK`, `DEGRADED`, or `FAILED`, while `outcome=` provides the specific reason.

## Final markers

Success:

```text
RESULT: CGRUN_WORKFLOW_OK outcome=success chat_lane=<lane> task=<task> run_id=<id> command_exit_code=0 handoff_outcome=success workflow_exit_code=0
```

Payload failure with successful handoff:

```text
RESULT: CGRUN_WORKFLOW_FAILED outcome=command_failed chat_lane=<lane> task=<task> run_id=<id> command_exit_code=<n> handoff_outcome=success workflow_exit_code=<n>
```

Non-strict handoff problem with successful command:

```text
RESULT: CGRUN_WORKFLOW_DEGRADED outcome=handoff_degraded ...
```

## Secret handling

The receipt contains only sanitized identifiers and classification metadata. `possible|sensitive` still use the redacted marker handoff; the receipt is appended after redaction and does not reintroduce raw command or payload content.

## Installed runtime contract

The repository owns the complete active runtime:

- `$PREFIX/bin/cgrun`
- `$PREFIX/bin/cgrun-core-v95`
- `$PREFIX/bin/cgtail-core-v95`
- `$PREFIX/bin/cg-lane.sh`
- `$PREFIX/bin/cg-run-file`

The historical filenames remain as repository-owned compatibility shims only:

- `$PREFIX/bin/cgrun.autoclip-v93-real`
- `$PREFIX/bin/cgtail-autoclip-v93`

The active `cgrun` wrapper calls the v9.5 native core files directly. It no longer delegates execution to an unmanaged restored v9.3 core. `install.sh` validates all source files before copying them and then runs the installed-runtime verifier.

After installation, `maintenance/verify-installed-cg-runtime.sh` verifies:

- every runtime file exists, is non-empty, executable, LF-only, and syntactically valid
- the installed wrapper and native cores contain their required v9.5 markers
- no ambiguous `rc=` field exists in a `CGRUN_*` result marker
- every installed runtime file exactly matches the checked-out repository source by SHA-256

The guarded maintenance workflow invokes this verifier after update and installation. Expected installed-runtime marker:

```text
RESULT: CG_INSTALLED_RUNTIME_VERIFY_DONE outcome=success workflow_exit_code=0
```

## Original artifact task binding

When `cg-run-file` normalizes a native Termux shebang, it uses a unique temporary directory but preserves the original artifact basename. The receipt therefore reports the user-visible artifact name rather than `cg-run-file-normalized.*`.

## Verification

`verify/verify-cg-execution-receipt.sh` covers:

- successful direct `cgrun` through the repository-owned core
- failed direct `cgrun` with preserved command exit code
- explicit original artifact task binding
- receipt presence in the clipboard handoff
- absence of ambiguous `rc=` fields in `CGRUN_*` result markers

`verify/verify-cg-run-file-termux-shebang.sh` additionally verifies that native Termux shebang normalization preserves the original artifact basename.

Expected marker:

```text
RESULT: CG_EXECUTION_RECEIPT_VERIFY_DONE outcome=success workflow_exit_code=0
```
