# Clipboard and notifications workflow

The toolbox is designed around predictable command output and safe copy handoff.

## Command capture

Use `cgrun` for commands that produce more than a few lines, modify files, touch repositories, or need a reliable result marker:

```bash
cgrun 'set -euo pipefail; pwd; git status --short; echo "RESULT: STATUS_DONE"'
```

Use `cgtail` to copy or inspect the final log window:

```bash
cgtail 80
```

## Output hygiene

Good command output should have:

- a clear scope
- enough context to understand the target directory
- a final `RESULT:` marker
- no credentials
- no raw private config
- no huge unbounded dumps

## Clipboard handoff

Clipboard handoff is best for compact, reviewable output. For larger output, send only the relevant tail and keep the full log locally.

Recommended:

```bash
cgrun 'set -euo pipefail; bash ./verify/verify-termux-toolbox.sh; echo "RESULT: VERIFY_DONE"'
cgtail 120
```

Avoid:

```text
huge live logs
private config dumps
SSH material
cloud backup config
unbounded recursive searches
```

## Notifications

Optional Termux:API notifications can be used after long local jobs:

```bash
termux-notification --title "Termux" --content "Job finished; run cgtail"
```

Keep notification content generic because Android notifications may be visible on the lock screen.
