# Termux Toolbox

A practical Termux toolkit for running commands cleanly, validating shell artifacts before execution, capturing useful logs, and keeping Android/Pixel shell workflows repeatable.

It exists for one reason: **mobile shell work gets messy fast**. Long outputs disappear, pasted command blocks become hard to verify, parallel runs can race over “latest” state, nested verification can overwrite the clipboard, and setup steps are easy to forget when moving to a new device. This repo turns those habits into a safer, repeatable workflow.

## What this solves

| Problem | What the toolbox does | Why it matters |
|---|---|---|
| Parallel runs can race over `latest.log` | Every `cgrun` gets an exact `execution_id` and bound run directory; internal tail/receipt/lane binding never consumes global `latest.log` | A lane cannot accidentally copy or adopt another run’s output |
| Long command output is hard to copy | `cgrun` captures the full run; its diagnostic handoff keeps the first failure context plus a bounded final tail | Root cause and final state survive without flooding chat |
| Clipboard delivery can fail silently | AutoCopy records separate helper/clipboard/handoff exit codes and can hash-read back the Android clipboard | Successful payload execution is not confused with successful handoff |
| Shell artifacts can be malformed | `cglint` blocks parser and ShellCheck warning/error failures, reports `shfmt` formatting drift, and can enforce style with `--strict` | Safety-relevant script failures stop before execution |
| Script handoffs are fragile on mobile | `cg-handoff` verifies the downloaded artifact and stages it safely before `cg-run-file` | Short paste commands replace large inline shell payloads |
| Android/shared-storage download is unavailable | When an installed `cgbootstrap` exposes the optional source-rescue contract, `cg-handoff` can obtain a missing exact hash-bound artifact from that trusted provider; standalone installs still fail closed | A broken Android download path does not have to block an already-authorized diagnostic handoff |
| Nested verification overwrites the Android clipboard | The outermost `cgrun` owns final AutoCopy; nested `cgrun`/`cg-handoff` runs use a clipboard sink | Intermediate checks no longer replace the result you need |
| Runtime/package state is uncertain | `cgdoctor` checks the installed toolbox and Termux environment | Environment problems are separated from task failures |
| Failure logs are too large | `cgfail` provides bounded first-failure triage; `cgrun` now also embeds first-failure context automatically | Diagnosis stays compact and useful |
| Rebuilding Termux from memory is fragile | Setup, package baseline, Termux:API, clipboard, restore and troubleshooting docs are included | A new Pixel/Termux install can be rebuilt deliberately |

## What is included

### Command helpers

| Helper | Purpose |
|---|---|
| `cgprep` | Prepare a clean command/output workflow |
| `cclear` | Clear noisy terminal context before a run |
| `cgrun` | Run a command with exact-run logs, Receipt v2, semantic exit metadata and final AutoCopy |
| `cgtail` | Return a bounded tail; internal callers can bind it to an exact log and request a diagnostic envelope |
| `cg-handoff` | Verify and stage a downloaded shell artifact, optionally use a trusted `cgbootstrap` source-rescue provider when that source is missing, run the default `cglint` gate, then delegate to `cg-run-file` |
| `cg-run-file` | Execute a full script artifact through the repository-owned lane/run contract |
| `cg-lane.sh` | Lane state/status/tail utility; its `run-file` command delegates to the canonical run-file driver |
| `cglint` | Read-only shell validation: parser and ShellCheck warning/error failures block; `shfmt` drift warns in default mode; `--strict` also blocks formatting and info/style findings |
| `cgdoctor` | Check Termux/toolbox runtime health and required command availability |
| `cgfind` | Fast bounded literal search over local files |
| `cgfail` | Extract useful failure/result markers from a bound run log |
| `cgnotify` | Optional post-result Android notification through Termux:API |
| `cgclean` | Clean old generated command logs with explicit retention |

### Current workflow guarantees

- **Exact-run binding:** `cgrun` stores each execution under `$CG_OUTPUT_DIR/runs/<execution_id>/`. The bound `run.log`, handoff capture and Receipt v2 are used directly. `latest.log` remains a compatibility/convenience pointer only and is not trusted as internal proof.
- **Diagnostic handoff:** failure AutoCopy includes the first relevant `FAIL`/`STOP`/`ERROR`/failure-result context and a bounded final tail.
- **Truthful handoff state:** `command_exit_code`, `helper_exit_code`, `clipboard_exit_code`, `handoff_exit_code` and `workflow_exit_code` remain separate. A clipboard failure can be non-strictly workflow-degraded, but it is never reported as handoff success.
- **Clipboard verification:** when `termux-clipboard-get` is available, the outer AutoCopy hashes the expected payload and readback without logging clipboard contents. Custom test/automation backends can provide a read command too.
- **Receipt v2 semantics:** completion records add stable semantic fields such as `workflow_exit_id`, class/stage, retry policy and diagnosis/fix/verify routing while preserving numeric layer exits.
- **Two explicit input modes:** `cgrun --shell '<shell program>'` performs intentional shell parsing; `cgrun --exec command arg...` preserves argv boundaries. The run-file driver uses `--exec`.
- **One run-file engine:** `cg-lane.sh run-file` delegates to `cg-run-file-driver-v1`; it no longer carries a second independent execution implementation.
- **Pre-execution lint gate:** `cg-handoff` runs production-default `cglint` before the artifact can reach `cg-run-file`.
- **Optional source rescue:** only when the normal source is missing or empty, `cg-handoff` may call an installed `cgbootstrap source-rescue` provider. The returned basename and SHA-256 must exactly match the requested handoff, the provider marker must be unique and well-formed, and the rescued file is independently rehashed before use. Missing/malformed providers remain a normal fail-closed `source_missing`/`source_empty` result.
- **Noninteractive execution:** workflow payload stdin is bound to `/dev/null`, so accidental prompts receive EOF instead of hanging a run.
- **TTY tail drain:** `cg-handoff` drains delayed interactive terminal input before returning control to the parent shell.
- **Bundle handoff:** verified ZIP bundle handoff is supported for multi-artifact deliveries.
- **Outermost-only AutoCopy:** only the outer `cgrun` owns the final Android clipboard write; nested runs preserve output without overwriting it.
- **Repository-owned runtime:** active `cgrun`/`cgtail` execution uses the v9.5 repository-owned core; historical v9.3 filenames remain compatibility shims only.

## Documentation

| Document | Why it exists |
|---|---|
| `docs/workflow.md` | Basic command-run/copy workflow |
| `docs/pixel-termux-copy-window.md` | ChatGPT/Termux copy-window pattern |
| `docs/termux-setup.md` | Baseline Termux setup |
| `docs/termux-api.md` | Termux:API integration |
| `docs/clipboard-and-notifications.md` | Clipboard and notification usage |
| `docs/restore-new-device.md` | Safe rebuild flow for a new device |
| `docs/troubleshooting.md` | Common failure cases and checks |
| `docs/reference/termux-package-baseline.md` | Sanitized package baseline |
| `docs/heimnetz-migration-policy.md` | Rules for private/public migration |
| `docs/cgrun-v95-native-core.md` | Repository-owned core, exact-run binding and input modes |
| `docs/cg-execution-receipt.md` | Execution Receipt v2 and semantic workflow exits |

## Verification

Relevant checks include:

```bash
bash ./verify/verify-termux-toolbox.sh
bash ./verify/verify-cg-execution-receipt.sh
bash ./verify/verify-termux-io-vnext.sh
bash ./maintenance/verify-installed-cg-runtime.sh
```

`verify/verify-termux-io-vnext.sh` specifically proves parallel exact-run isolation, truthful clipboard failure/degraded semantics, clipboard readback mismatch detection, argv fidelity, first-failure diagnostic capture, and canonical lane-driver exact log binding.

## What is intentionally not included

This repo is public-safe by design. It should not contain SSH keys/config, authentication material, API tokens, raw Termux backups, rclone configuration, private restore notes, private hostnames/IPs/topology, or full command logs that may contain private context.

## Use as a GitHub template

This repository is enabled as a GitHub **template repository**. Use **Use this template** when you want an independent repository with the same starting structure. Keep credentials and host-specific data out of Git.

## Install

```bash
git clone https://github.com/Lycidias93/termux-toolbox.git
cd termux-toolbox
bash ./install.sh
bash ./verify/verify-termux-toolbox.sh
bash ./maintenance/verify-installed-cg-runtime.sh
cgdoctor --quick
```

## Basic workflow

For shell syntax that intentionally needs Bash parsing:

```bash
cgrun --shell 'set -euo pipefail; echo "hello"; echo "RESULT: EXAMPLE_DONE"'
```

For a command where argument boundaries must be preserved exactly:

```bash
cgrun --exec printf '%s\n' 'argument with spaces'
```

The legacy `cgrun '<shell program>'` form remains compatible, but new automation should choose `--shell` or `--exec` explicitly.

For a downloaded full shell artifact, prefer the short handoff path:

```bash
cg-handoff pixel_local__example.sh <expected-sha256>
```

`cg-handoff` verifies SHA-256, stages the artifact safely, runs production-default `cglint`, then delegates to `cg-run-file`. Multi-artifact deliveries use verified bundle handoff. If the source file is missing and an installed `cgbootstrap` implements the optional source-rescue contract, the same command can use that trusted provider; without such a provider, the handoff still fails closed rather than fetching arbitrary content itself.

Useful diagnostics:

```bash
cglint ./example.sh
cgdoctor --quick
cgfind 'RESULT:' .
cgfail
cgnotify --dry-run PASS 'workflow complete'
```

## Why not just use shell history or scrollback?

Scrollback is not a reliable artifact. It is easy to lose context, mix old and new output, miss the first failing line, or copy too much. Exact run IDs, bound logs, result markers and Receipt v2 make the run itself the artifact.

## Public safety model

Before publishing, run:

```bash
bash ./tools/review-termux-public-safety.sh
bash ./verify/verify-termux-toolbox.sh
```

## Heimnetz vendor model

The safe sync direction is:

```text
termux-toolbox -> private-repo/vendor/termux-toolbox
```

Do not automatically sync private overlays, logs, backups or host-specific notes back into this public repo.

## Design principles

- **Exact identity over “latest”:** convenience pointers are never proof inputs.
- **Small scripts over magic frameworks:** easy to inspect and replace.
- **Validate before execution:** parser/static-analysis failures stop before a shell artifact runs.
- **Logs as artifacts:** command output should be reproducible and bounded.
- **One final clipboard owner:** nested workflows should not fight over Android AutoCopy.
- **Raw numeric exits plus semantic routing:** retain evidence while making diagnosis actionable.
- **Public-safe by default:** examples are generic; private context stays private.
- **Result markers matter:** every important run should end with a clear success/failure marker.

## License

See `LICENSE`.

<!-- AUTOCLIP_V95_NATIVE_CORE_START -->
## AutoClip v9.5 native core / I/O vNext

The active runtime is fully repository-owned. `bin/cgrun` calls `bin/cgrun-core-v95` and `bin/cgtail-core-v95` directly. Historical `cgrun.autoclip-v93-real` and `cgtail-autoclip-v93` names remain compatibility shims only.

Execution Receipt v2 preserves named layer exit codes, adds semantic workflow routing, binds every internal handoff to an exact execution log, and treats `latest.log` as compatibility-only. Native Termux shebang normalization keeps the original artifact basename.

See `docs/cgrun-v95-native-core.md` and `docs/cg-execution-receipt.md`.
<!-- AUTOCLIP_V95_NATIVE_CORE_END -->

<!-- TOOLBOX_ARTIFACT_LANE_BINDING_V2_20260710_START -->
## Artifact and lane-binding guard v2

- Full script artifacts are started through `cg-run-file`, normally via the verified `cg-handoff` frontend, not `cgrun <script>`.
- Manual lane tails require current lane/status evidence and an expected result marker.
- `tools/assistant-output-guard.sh` blocks invalid artifact/lane handoff patterns before copy/run.
<!-- TOOLBOX_ARTIFACT_LANE_BINDING_V2_20260710_END -->
