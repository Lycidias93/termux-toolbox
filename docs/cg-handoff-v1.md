# `cg-handoff` v1

`cg-handoff` is the short, metadata-driven front end for ChatGPT-provided `pixel_local__*.sh` artifacts.

It exists to remove long interactive paste launchers from the normal Termux workflow. Long serialized shell lines are hard to inspect on mobile and can leave Bash at a secondary `>` prompt when a client paste includes a partial shell token or formatting delimiter.

## User-facing invocation

A handoff is intentionally only two arguments:

```text
cg-handoff pixel_local__artifact.sh <sha256>
```

A basename resolves below `/storage/emulated/0/Download`. An absolute path is accepted only when its resolved path is still below that download root.

## Artifact metadata contract

The downloaded script carries exactly one block:

```text
# CG_HANDOFF_V1_START
# cg_handoff_lane=<lane>
# cg_handoff_scope=<scope>
# cg_handoff_host=<host>
# cg_handoff_route_class=<route-class>
# cg_handoff_secret_class=<secret-class>
# cg_handoff_run_mode=verify|run
# cg_handoff_expected_marker=<exact result marker prefix>
# CG_HANDOFF_V1_END
```

The outer SHA-256 remains supplied by the assistant response and is verified before metadata is consumed.

## Safety sequence

`cg-handoff` performs the previously repeated launcher sequence in one installed, repository-owned runtime:

1. require a regular non-empty `pixel_local__*.sh` under the Download root;
2. verify the externally bound SHA-256;
3. validate one metadata block and all lane/scope/host/route/secret/mode fields;
4. run `cgprep`, `cclear`, `cgcurrent`, then the metadata-bound `cguse`;
5. atomically stage the exact file to `$TMPDIR`, verify SHA-256 again and run `bash -n`;
6. export the artifact's expected marker;
7. `exec cg-run-file` exactly once and let the existing AutoCopy/receipt pipeline own completion.

It never accepts `target-*` or `targets-*` artifacts, never executes a Shared Storage file directly, and never appends a manual `cgtail`.

## Failure behavior

Any source, hash, metadata, lane, syntax or stage mismatch fails closed with:

```text
RESULT: CG_HANDOFF_STOP outcome=stop reason=<reason> workflow_exit_code=2
```

The fixture `maintenance/verify-cg-handoff-v1.sh` verifies the success path, complete lane binding, expected-marker propagation and hash-mismatch STOP behavior.

## Installed-runtime gate

`install.sh` installs `cg-handoff` with the other `bin/*` helpers. `maintenance/verify-installed-cg-runtime.sh` requires executable/LF/syntax/source parity and interactive `$PREFIX/bin/cg-handoff` resolution before it emits the existing installed-runtime PASS marker.
