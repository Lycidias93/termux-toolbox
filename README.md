# Termux Toolbox

A practical Termux toolkit for running commands cleanly, validating shell artifacts before execution, capturing useful logs, and keeping Android/Pixel shell workflows repeatable.

It exists for one reason: **mobile shell work gets messy fast**. Long outputs disappear, pasted command blocks become hard to verify, nested verification can overwrite the clipboard, logs can accidentally include private data, and setup steps are easy to forget when moving to a new device. This repo turns those habits into a safer, repeatable workflow.

## What this solves

| Problem | What the toolbox does | Why it matters |
|---|---|---|
| Long command output is hard to copy | `cgrun` captures the full run and `cgtail` returns a bounded useful tail | You can share clean evidence without flooding chat or terminal scrollback |
| Shell artifacts can be malformed | `cglint` checks Bash parsing, `shfmt` formatting and ShellCheck findings | Bad scripts stop before execution |
| Script handoffs are fragile on mobile | `cg-handoff` verifies the downloaded artifact and stages it safely before `cg-run-file` | Short paste commands replace large inline shell payloads |
| Nested verification overwrites the Android clipboard | The outermost `cgrun` owns the final AutoCopy; nested `cgrun`/`cg-handoff` runs use a clipboard sink | Intermediate checks no longer replace the result you actually need |
| Runtime/package state is uncertain | `cgdoctor` checks the installed toolbox and Termux environment | Environment problems are separated from task failures |
| Finding a local marker or file is slow | `cgfind` provides bounded literal search | Diagnosis stays fast and predictable |
| Failure logs are too large | `cgfail` extracts a bounded first-failure view | The useful error is easier to find and share |
| Notifications are useful but should not define success | `cgnotify` can send optional Termux:API notifications after a result exists | Notification delivery stays separate from workflow correctness |
| Public docs can leak private context | Public-safety review tools check for common secret/private patterns | The repo can stay publishable |
| Rebuilding Termux from memory is fragile | Setup, package baseline, Termux:API, clipboard, restore and troubleshooting docs are included | A new Pixel/Termux install can be rebuilt deliberately |

## What is included

### Command helpers

| Helper | Purpose |
|---|---|
| `cgprep` | Prepare a clean command/output workflow |
| `cclear` | Clear noisy terminal context before a run |
| `cgrun` | Run a command with captured logs, result markers, execution receipt and final AutoCopy behavior |
| `cgtail` | Return a bounded copy-friendly tail of the bound run |
| `cg-handoff` | Verify and stage a downloaded shell artifact, run the default `cglint` gate, then delegate to `cg-run-file` |
| `cg-run-file` | Execute a full script artifact through the repository-owned lane/run contract |
| `cglint` | Read-only shell validation: parser check, `shfmt -d`, ShellCheck warning/error gate; `--strict` also audits info/style findings |
| `cgdoctor` | Check Termux/toolbox runtime health and required command availability |
| `cgfind` | Fast bounded literal search over local files |
| `cgfail` | Extract useful failure/result markers from a bound run log |
| `cgnotify` | Optional post-result Android notification through Termux:API |
| `cgclean` | Clean old generated command logs with explicit retention |

### Current workflow guarantees

- **Pre-execution lint gate:** `cg-handoff` runs production-default `cglint` before the artifact can reach `cg-run-file`.
- **Noninteractive execution:** workflow payload stdin is bound to `/dev/null`, so accidental prompts receive EOF instead of hanging a run.
- **TTY tail drain:** `cg-handoff` drains delayed interactive terminal input before returning control to the parent shell.
- **Bundle handoff:** verified ZIP bundle handoff is supported for multi-artifact deliveries.
- **Outermost-only AutoCopy:** only the outer `cgrun` owns the final Android clipboard write; nested runs preserve their output in the outer log without overwriting the clipboard.
- **Execution receipts:** run completion records include task, lane, run ID, outcome and named exit-code fields.
- **Repository-owned runtime:** active `cgrun`/`cgtail` execution uses the v9.5 repository-owned core; historical v9.3 filenames remain compatibility shims only.

### Documentation

| Document | Why it exists |
|---|---|
| `docs/workflow.md` | Explains the basic command-run/copy-window workflow |
| `docs/pixel-termux-copy-window.md` | Documents the ChatGPT/Termux copy-window pattern |
| `docs/termux-setup.md` | Baseline setup for a usable Termux environment |
| `docs/termux-api.md` | How Termux:API fits into clipboard/notification workflows |
| `docs/clipboard-and-notifications.md` | Clipboard and notification usage without mixing in private config |
| `docs/restore-new-device.md` | Safe rebuild flow for a new Termux device |
| `docs/troubleshooting.md` | Common failure cases and checks |
| `docs/reference/termux-package-baseline.md` | Sanitized package baseline reference |
| `docs/heimnetz-migration-policy.md` | Rules for moving generic content out of a private Heimnetz repo |
| `docs/cgrun-v95-native-core.md` | Explains the repository-owned v9.5 core and original task binding |
| `docs/cg-execution-receipt.md` | Documents Execution Receipt v1 |

### Templates and checks

| Path | Purpose |
|---|---|
| `termux/termux.properties.example` | Public-safe Termux settings example |
| `tools/review-termux-public-safety.sh` | Public safety scan before publishing |
| `tools/audit-heimnetz-termux.sh` | Helper for finding Termux-related material in a private repo |
| `verify/verify-termux-toolbox.sh` | Main syntax/workflow verification suite |
| `verify/verify-toolkit-vnext.sh` | Verifies the vNext helpers, lint behavior and Outermost AutoCopy fixture |
| `verify/verify-cgrun-outermost-autocopy.sh` | Proves exactly one outer clipboard write while nested results remain preserved |
| `maintenance/verify-installed-cg-runtime.sh` | Verifies the installed runtime against the repository-owned contracts |

## What is intentionally not included

This repo is public-safe by design. It should not contain:

- SSH keys, SSH config, or authentication material
- GitHub tokens, API tokens, cloud credentials, or app passwords
- raw Termux backups
- rclone configuration
- private restore notes
- private hostnames, IP addresses, DNS/VPN details, or home-network topology
- full command logs that may contain paths, tokens, URLs, or personal context

Private/local material belongs in a private repo or local backup, not here.

## Use as a GitHub template

This repository is enabled as a GitHub **template repository**. Use **Use this template** on GitHub when you want an independent repository that starts with this toolbox structure and files but has its own repository history and can be customized freely.

Choose the template path when you want to build your own toolbox variant. Choose a normal clone when you want to use this repository directly and keep pulling its future updates. Creating a repository from the template does not create an upstream update relationship to this repository.

After creating a repository from the template, review its public/private visibility, remove anything you do not need, keep credentials and host-specific data out of Git, and then use the same install and verification flow below.

## Install

Clone the repo and run the installer:

```bash
git clone https://github.com/Lycidias93/termux-toolbox.git
cd termux-toolbox
bash ./install.sh
```

After installation, verify the repository and installed runtime:

```bash
bash ./verify/verify-termux-toolbox.sh
bash ./maintenance/verify-installed-cg-runtime.sh
cgdoctor --quick
```

## Basic workflow

For a short direct command, prepare the terminal and run it through `cgrun`:

```bash
cgprep
cclear
cgrun 'set -euo pipefail; echo "hello"; echo "RESULT: EXAMPLE_DONE"'
```

`cgrun` captures the run and owns the final AutoCopy. Nested verifier runs do not overwrite that clipboard result.

For a downloaded full shell artifact, prefer the short `cg-handoff` path:

```bash
cg-handoff pixel_local__example.sh <expected-sha256>
```

`cg-handoff` verifies the external SHA-256, stages the artifact safely, runs the production-default `cglint` gate and delegates to `cg-run-file`. Multi-artifact deliveries use the verified bundle handoff rather than several independent paste/run sequences.

Useful diagnostics:

```bash
cglint ./example.sh
cgdoctor --quick
cgfind 'RESULT:' .
cgfail
cgnotify --dry-run PASS 'workflow complete'
```

The important part is the contract:

1. Shell artifacts are validated before execution.
2. Commands run noninteractively with predictable shell behavior.
3. Logs are captured outside terminal scrollback.
4. Important runs emit clear `RESULT:` markers and execution receipts.
5. The final outer run owns the clipboard handoff.
6. Nested checks remain visible in logs without replacing the final clipboard result.

## Why not just use shell history or scrollback?

Because scrollback is not a reliable artifact. It is easy to lose context, mix old and new output, miss the first failing line, or copy far more than intended. `cgrun`, bound logs and result markers make the run itself the artifact.

## Public safety model

Before publishing, run:

```bash
bash ./tools/review-termux-public-safety.sh
bash ./verify/verify-termux-toolbox.sh
```

These checks are intentionally conservative. They are not a full security audit, but they catch common mistakes before pushing a public repo.

## Heimnetz vendor model

This repo can be vendored into a private Heimnetz repo as a snapshot. The safe direction is:

```text
termux-toolbox -> private-repo/vendor/termux-toolbox
```

Do not automatically sync private overlays, logs, backups or host-specific notes back into this public repo.

## Design principles

- **Small scripts over magic frameworks:** easy to inspect, easy to replace.
- **Validate before execution:** parser, formatting and static-analysis failures should stop before a shell artifact runs.
- **Logs as artifacts:** command output should be reproducible and bounded.
- **One final clipboard owner:** nested workflows should not fight over Android AutoCopy.
- **Public-safe by default:** examples are generic; private context stays private.
- **No raw backup publishing:** sanitized references are useful; dumps are risky.
- **Result markers matter:** every important run should end with a clear success/failure marker.

## License

See `LICENSE`.

<!-- AUTOCLIP_V95_NATIVE_CORE_START -->
## AutoClip v9.5 native core

The active runtime is fully repository-owned. `bin/cgrun` calls `bin/cgrun-core-v95` and `bin/cgtail-core-v95` directly; it no longer delegates execution to an unmanaged restored v9.3 core.

The historical filenames `cgrun.autoclip-v93-real` and `cgtail-autoclip-v93` remain compatibility shims only. Installing the toolbox replaces any stale local copies with shims that route to the repository-owned v9.5 implementation.

Execution Receipt v1 uses named exit-code fields and never emits a generic `rc=<n>` field in a `CGRUN_*` completion marker. Native Termux shebang normalization keeps the original artifact basename, so receipts report the user-visible task rather than a `cg-run-file-normalized.*` temporary name.

See `docs/cgrun-v95-native-core.md` and `docs/cg-execution-receipt.md`.
<!-- AUTOCLIP_V95_NATIVE_CORE_END -->

<!-- TOOLBOX_ARTIFACT_LANE_BINDING_V2_20260710_START -->
## Artifact and lane-binding guard v2

- Full script artifacts are started through `cg-run-file`, normally via the verified `cg-handoff` frontend, not `cgrun <script>`.
- `CGRUN_AUTO_TAIL=0` must not be followed by an unbound `cgtail-lane` handoff.
- Manual lane tails require current lane/status evidence and an expected result marker.
- `tools/assistant-output-guard.sh` blocks these invalid patterns before copy/run.
<!-- TOOLBOX_ARTIFACT_LANE_BINDING_V2_20260710_END -->
