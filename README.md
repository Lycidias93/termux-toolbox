# Termux Toolbox

A small, safety-focused Termux helper collection for clean command runs, reproducible Pixel/Android shell workflows, and copy-window friendly ChatGPT operations.

This repository contains the public, reusable part of my Termux workflow. Private host details, raw logs, credentials, local network state, and device-specific recovery data stay outside this repository.

## What this gives you

- `cgprep` prepares the shell before copyable runs.
- `cclear` clears noisy terminal output before a fresh run.
- `cgrun` captures command output into a log with metadata and result markers.
- `cgtail` emits a compact tail from the latest run for clean copy/paste back into ChatGPT.
- `cgclean` handles explicit retention cleanup for generated run logs.
- Public safety checks help prevent private or environment-specific material from entering the repo.

## Repository layout

```text
bin/                         Termux helper commands
verify/                      Toolbox verification
termux/                      Public Termux examples
docs/                        Workflow and reference docs
docs/reference/              Sanitized package and environment references
tools/                       Audit and public-safety helper scripts
imported/heimnetz-scripts/   Public-safe scripts imported from the Heimnetz workflow
packages.txt                 Minimal package baseline
install.sh                   Local install helper
```

## Install

Clone the repo on Android/Termux:

```bash
git clone git@github.com:Lycidias93/termux-toolbox.git "$HOME/src/termux-toolbox"
cd "$HOME/src/termux-toolbox"
bash ./install.sh
```

Run a verify pass:

```bash
cd "$HOME/src/termux-toolbox"
bash ./verify/verify-termux-toolbox.sh
```

Optional public-safety review:

```bash
cd "$HOME/src/termux-toolbox"
bash ./tools/review-termux-public-safety.sh
```

## Basic workflow

Prepare a clean terminal window:

```bash
cgprep
cclear
```

Run a command with captured output:

```bash
cgrun 'set -euo pipefail; uname -a; echo "RESULT: SAMPLE_DONE rc=0"'
```

Send the compact result tail:

```bash
cgtail 80
```

## Design principles

- Keep reusable public helpers in this repo.
- Keep private operational state in the Heimnetz repo or outside Git entirely.
- Prefer full scripts over pasted fragments.
- Use explicit result markers for repeatable ChatGPT handoff.
- Verify before commit.
- Treat raw logs, device backups, credentials, SSH material, local routes, and private host inventory as non-public.

## Heimnetz relationship

The Heimnetz repository vendors a snapshot of this toolbox under:

```text
vendor/termux-toolbox/
```

Local Heimnetz-specific overlays live separately under:

```text
local/pixel-termux-toolbox/
```

The intended sync direction is:

```text
termux-toolbox -> heimnetz-geraete/vendor/termux-toolbox
```

There is no automatic reverse sync from Heimnetz-local content back into this public repository.

## Public safety

Before publishing changes, run:

```bash
bash ./tools/review-termux-public-safety.sh
bash ./verify/verify-termux-toolbox.sh
git diff --check
```

The repo intentionally contains public safety policy text and scanning tools. Those tools may contain detection patterns by design; the safety scripts account for that.

## License

See `LICENSE`.

<!-- TERMUX_TOOLBOX_DOCS_INDEX_BEGIN -->
## Documentation map

- [Termux setup baseline](docs/termux-setup.md)
- [Termux:API integration](docs/termux-api.md)
- [Clipboard and notifications workflow](docs/clipboard-and-notifications.md)
- [Restore on a new Termux device](docs/restore-new-device.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Termux package baseline](docs/reference/termux-package-baseline.md)
<!-- TERMUX_TOOLBOX_DOCS_INDEX_END -->
