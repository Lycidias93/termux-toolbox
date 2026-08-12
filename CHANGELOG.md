# Changelog

## Unreleased

- Hardened `cg-handoff` against post-run Bash PS2 prompts from queued mobile paste tails: after `cg-run-file` completes, it preserves the workflow exit code, drains pending interactive TTY input, and only then returns to the parent shell. The installed-runtime verifier and regression fixture require this behavior.
- Added `cg-handoff` v1, a metadata-driven two-argument frontend for ChatGPT `pixel_local__*.sh` downloads. It verifies the external SHA-256 before metadata use, binds lane/scope/host/route/secret/mode, stages atomically to `$TMPDIR`, verifies syntax and delegates exactly once to `cg-run-file`, replacing fragile long interactive paste launchers.
- Added `maintenance/verify-cg-handoff-v1.sh` covering successful staging/binding/expected-marker propagation and fail-closed hash mismatch behavior; the installed-runtime gate now requires `cg-handoff` source parity and shell resolution.
- Fixed `cg-run-file` stale lane locks left by interrupted runs: dead lock owners are recovered automatically while live owners remain fail-closed.
- Moved lane-lock acquisition into the `cgrun` execution path so `lock_busy` failures now receive the same mandatory AutoCopy/receipt handling as payload failures.
- Added PID start-tick lock ownership to avoid false liveness after PID reuse and cleanup traps for INT/TERM/HUP/EXIT.
- Added `verify-cg-run-file-lock-autocopy.sh` covering stale-lock recovery, live-lock preservation and `lock_busy` occurring inside the cgrun path.
- Added an idempotent native CG shell-resolution guard that keeps restored legacy `cgrun()` and `cgtail()` functions from shadowing the repository-owned v9.5 binaries.
- Integrated the guard into installation and maintenance, with automatic `.bashrc` backup, final-block enforcement, interactive resolution verification and restore-regression coverage.
- Extended the installed-runtime gate to require a unique final shell guard and `cgrun`/`cgtail` resolution to `$PREFIX/bin` files.
- Added a complete Termux maintenance workflow with a preflight audit, gated package update, fast-forward-only toolbox update, installed-helper parity verification and post-audit.
- Added explicit backup and rollback boundaries for toolbox files while keeping package downgrades manual.
- Added old Python runtime directory inventory without automatic deletion.
- Fixed route-guard false positives with token-boundary route path classification.
- Added route-guard self-tests for generic and genuinely route-sensitive paths.
- Added config/workflow-scopes.tsv as the central workflow scope registry.
- Added all direct Heimnetz device and special scopes to chatctx and cgflow.
