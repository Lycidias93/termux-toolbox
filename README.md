# Termux Toolbox

A small, practical Termux toolkit for running commands cleanly, capturing useful logs, and keeping Android/Pixel shell workflows repeatable.

It exists for one reason: **mobile shell work gets messy fast**. Long outputs disappear, pasted command blocks become hard to verify, logs accidentally include private data, and setup steps are easy to forget when moving to a new device. This repo turns those habits into a safer, repeatable workflow.

## What this solves

| Problem | What the toolbox does | Why it matters |
|---|---|---|
| Long command output is hard to copy | `cgrun` captures the full run and `cgtail` returns the useful tail | You can share clean evidence without flooding a chat or terminal scrollback |
| Terminal sessions get noisy | `cgprep` and `cclear` prepare a clean copy window | Less confusion, fewer missed errors |
| Re-running checks is inconsistent | Helpers use predictable result markers and log paths | A failed run is easier to diagnose and compare |
| Public docs can leak private context | Public-safety review tools check for common secret/private patterns | The repo can stay publishable |
| Rebuilding Termux from memory is fragile | Setup, package baseline, Termux:API, clipboard, restore, and troubleshooting docs are included | A new Pixel/Termux install can be rebuilt deliberately |

## What is included

### Command helpers

| Helper | Purpose |
|---|---|
| `cgprep` | Prepare a clean command/output workflow |
| `cclear` | Clear noisy terminal context before a run |
| `cgrun` | Run commands with captured logs and result markers |
| `cgtail` | Return a bounded, copy-friendly tail of the latest run |
| `cgclean` | Clean old generated command logs with explicit retention |

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

### Templates and checks

| Path | Purpose |
|---|---|
| `termux/termux.properties.example` | Public-safe Termux settings example |
| `tools/review-termux-public-safety.sh` | Public safety scan before publishing |
| `tools/audit-heimnetz-termux.sh` | Helper for finding Termux-related material in a private repo |
| `verify/verify-termux-toolbox.sh` | Basic syntax and secret-pattern verification |

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

## Install

Clone the repo and run the installer:

```bash
git clone https://github.com/Lycidias93/termux-toolbox.git
cd termux-toolbox
bash ./install.sh
```

After installation, verify the toolbox:

```bash
bash ./verify/verify-termux-toolbox.sh
```

## Basic workflow

Prepare the terminal, run a command through `cgrun`, then share only the useful tail:

```bash
cgprep
cclear
cgrun 'set -euo pipefail; echo "hello"; echo "RESULT: EXAMPLE_DONE"'
cgtail 80
```

The important part is the contract:

1. Commands run with predictable shell behavior.
2. Logs are captured outside the scrollback.
3. The final output has a clear `RESULT:` marker.
4. Only bounded output is copied or shared.

## Why not just use shell history or scrollback?

Because scrollback is not a reliable artifact. It is easy to lose context, mix old and new output, miss the first failing line, or copy far more than intended. `cgrun`/`cgtail` make the run itself the artifact.

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

Do not automatically sync private overlays, logs, backups, or host-specific notes back into this public repo.

## Design principles

- **Small scripts over magic frameworks**: easy to inspect, easy to replace.
- **Logs as artifacts**: command output should be reproducible and bounded.
- **Public-safe by default**: examples are generic; private context stays private.
- **No raw backup publishing**: sanitized references are useful; dumps are risky.
- **Result markers matter**: every important run should end with a clear success/failure marker.

## License

See `LICENSE`.
