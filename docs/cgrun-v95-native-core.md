# cgrun v9.5 native core / Termux I/O vNext

## Architecture

The repository owns the active runtime:

- `bin/cgrun`: exact execution identity, Receipt v2, semantic result and outer AutoCopy
- `bin/cgrun-core-v95`: command execution, exact log creation, heartbeat, timeout and stdin isolation
- `bin/cgtail-core-v95`: exact-log bounded tail and diagnostic envelope
- `bin/cg-run-file-driver-v1`: canonical lane/run engine
- `bin/cg-lane.sh`: lane state/status utility; `run-file` delegates to the canonical driver
- `bin/cgrun.autoclip-v93-real` and `bin/cgtail-autoclip-v93`: compatibility shims only

## Exact-run binding

Older generations used global `$HOME/.chatgpt-output/latest.log` as both a convenience pointer and an internal handoff input. Two overlapping runs could therefore change the pointer between command completion, tail generation and lane adoption.

I/O vNext assigns each run an `execution_id` and stores evidence below:

```text
$CG_OUTPUT_DIR/runs/<execution_id>/
```

The core receives an exact `CGRUN_BOUND_LOG_PATH`; the wrapper passes that same path explicitly to `cgtail-core-v95 --log ...`, and the run-file driver derives the same path directly from its `run_id`. `latest.log` is still updated for compatibility, but no internal proof step consumes it.

For a lane/run-file execution, `execution_id == run_id`, so lane metadata, log, AutoCopy and final receipt are byte-stable on the same identity.

## Input modes

The native core supports:

- `--shell <one string>` for deliberate Bash parsing
- `--exec <command> <arg...>` for argv-preserving execution
- the historical single shell-string form as compatibility mode

The canonical run-file driver uses `cgrun --exec`, eliminating its former quote/reparse layer.

All workflow payloads still receive stdin from `/dev/null`. There is no implicit interactive fallback; accidental prompts receive EOF instead of hanging the run.

## Diagnostic handoff

`cgtail-core-v95` supports `--log <exact-path> --diagnostic`. The diagnostic envelope contains:

1. exact source/log metadata;
2. the first relevant failure marker with bounded context;
3. a bounded final tail;
4. an explicit result marker.

This keeps the earliest root-cause evidence even when a long command produces hundreds of lines after the failure.

## Clipboard and handoff truth

The outer `cgrun` remains the sole AutoCopy owner. Numeric results are tracked independently as command/helper/clipboard/handoff/workflow exits.

A clipboard failure can no longer inherit a zero handoff code merely because tail generation succeeded. Non-strict mode may leave the command’s shell exit at zero, but the workflow is explicitly `DEGRADED`. Strict mode promotes the handoff code to the workflow exit.

When clipboard readback is available, `cgrun` compares SHA-256 of the expected handoff with readback and records only `match`/`mismatch`/failure state, not clipboard contents.

## Semantic workflow result

Receipt v2 preserves all numeric layer codes and adds stable workflow semantics: exit ID, class, stage, retry policy, auto-fix eligibility, and diagnosis/fix/verify routing identifiers. A generic nonzero payload result remains `WORKFLOW_UNCLASSIFIED_NONZERO` unless stronger evidence exists.

## Canonical run-file engine

`cg-run-file-driver-v1` is the sole execution engine. `cg-lane.sh run-file` now delegates to it instead of maintaining a second lock/wrapper/receipt implementation. The driver retains PID/start-tick stale-lock recovery and emits an explicit concurrency semantic on a live lane lock.

## Historical reliability fixes retained

I/O vNext preserves prior guarantees:

- original artifact basename survives Termux shebang normalization;
- mode is canonicalized to `verify|run` before run-ID creation;
- restored legacy shell functions are neutralized by the native shell guard;
- nested AutoCopy writes are sent to the outer run’s sink;
- repository verification remains read-only with respect to tracked source files;
- `cg-handoff` lint, bundle and TTY-tail-drain contracts remain upstream of `cg-run-file`.

## Verification

`verify/verify-cg-execution-receipt.sh` verifies Receipt v2, exact log binding, semantic success/failure, clipboard hash readback and task identity.

`verify/verify-termux-io-vnext.sh` verifies:

- two overlapping runs cannot cross-copy their logs;
- clipboard failure produces truthful degraded/strict behavior;
- clipboard readback mismatch is detected;
- `--exec` preserves spaces, `$` and semicolon bytes as arguments;
- first-failure context survives a long trailing log;
- `cg-lane.sh run-file` reaches the canonical driver and exact `$CG_OUTPUT_DIR/runs/<run_id>/run.log`.

`maintenance/verify-installed-cg-runtime.sh` remains the authority for a live installed runtime. Repository merge alone is not installed-runtime evidence; live acceptance still requires:

```text
RESULT: CG_INSTALLED_RUNTIME_VERIFY_DONE outcome=success workflow_exit_code=0
```
