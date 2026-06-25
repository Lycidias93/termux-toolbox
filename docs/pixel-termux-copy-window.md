# Pixel/Termux Copy Window Workflow

This document describes a generic Pixel/Termux workflow for clean command capture and safe copy/paste handoff.
It is intentionally public-safe and does not include private infrastructure names, keys, routes, logs, or local secrets.

## Goals

- keep terminal scrollback small and readable
- capture long command output into timestamped logs
- return only relevant tails to chat or issue discussions
- use explicit `RESULT:` markers for machine-readable completion
- avoid pasting long inline scripts or secret-bearing logs

## Recommended command pattern

```bash
cgprep
cclear
cgrun 'set -euo pipefail
# command payload here
echo "RESULT: MY_TASK_DONE rc=0"'
```

For additional context after a run:

```bash
cgtail 120
```

## Safety rules

- Do not paste secrets, tokens, private keys, credentials, or full private configs.
- Prefer scripts or package files for complex work instead of large inline commands.
- Use a clear final marker such as `RESULT: TASK_DONE rc=0`.
- Keep generated logs outside synced/public folders unless they are explicitly sanitized.
- Treat public migration as allowlist-only.

## Public/private boundary

Public toolbox material should include reusable helpers, examples, templates, and generic documentation.
Private project material should stay in the internal repository or local-only config paths.
