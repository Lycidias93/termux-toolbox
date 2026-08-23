# Changelog

## Unreleased

- Added `cglint` for read-only shell artifact validation with parser checks, ShellCheck and `shfmt -d`.
- `cg-handoff` now runs the production-default `cglint` gate on the private staged shell entrypoint before `cg-run-file`, so parser, formatting, ShellCheck error and ShellCheck warning failures stop before execution; `cglint --strict` remains available for full info/style audits.
- Nested `cgrun`/`cg-handoff` verification runs no longer overwrite the Android clipboard: the outermost `cgrun` owns the single final AutoCopy, while nested results remain preserved in its bound log and final tail.
- Added `cgdoctor`, `cgfind` and `cgfail` for faster Termux health checks, repository search and bounded failure-marker diagnosis.
- Added non-fatal `cgnotify` Android notifications through Termux:API, including a dry-run mode.
- Extended the normal package baseline with `jq`, `ripgrep`, `fd`, `fzf`, `shellcheck` and `shfmt`; `hyperfine`, `socat` and `strace` remain optional diagnostic tools.
- Made `cgrun`/`cg-run-file` permanently noninteractive at the execution boundary: the native core now launches every workflow payload with stdin bound to `/dev/null`, so accidental `read`/prompt calls receive EOF instead of waiting for user input.
- Added source and installed-runtime regressions that execute an input-reading fixture and require `stdin_mode=dev-null` plus an immediate EOF result.
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
- Added host operation context and task-card coverage.
- Added complete central scope and consumer-wrapper verification.
- Removed the repo-only scope whitelist that caused unknown scope errors.

- Initial public Termux toolbox layout.
- Add verify script and basic helper placeholders.

<!-- AUTOCLIP_V933_TOOLBOX_CHANGELOG_START -->
### 2026-06-25

- Documented AutoClip v9.3.3 polish helpers: autoclip-doctor, cgarchive, and cgrun-noclip.
- Added note for recursive guard rc=12 stale-tail behavior when literal nested cgrun appears inside a payload.
- Kept archive maintenance manual: cgarchive dry-run before apply; no automatic weekly deletion.
<!-- AUTOCLIP_V933_TOOLBOX_CHANGELOG_END -->

<!-- AUTOCLIP_V934_TOOLBOX_CHANGELOG_START -->
### 2026-06-25

- Documented AutoClip v9.3.4 stale-tail guard.
- Added behavior note for nonzero cgrun exits before latest.log updates: create cgrun_guard_*.log, repoint latest.log, and auto-cgtail the guard log.
- Recorded expected markers: version=v9.3.4-rc12-stale-tail-fix, rc12_stale_latest_guard=enabled, CGRUN_STALE_LATEST_GUARD_LOG_DONE.
<!-- AUTOCLIP_V934_TOOLBOX_CHANGELOG_END -->
