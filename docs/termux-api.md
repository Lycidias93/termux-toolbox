# Termux:API integration

Termux:API is optional, but it improves Android integration for clipboard, notifications, device status, and handoff workflows.

## Install

Install the Termux:API Android app from the same distribution channel as Termux, then install the Termux package:

```bash
pkg install termux-api
```

## Basic checks

```bash
command -v termux-clipboard-get
command -v termux-clipboard-set
command -v termux-notification
command -v termux-battery-status
```

A minimal smoke check:

```bash
termux-battery-status >/dev/null && echo "PASS termux-api battery"
printf '%s\n' 'termux-api clipboard smoke' | termux-clipboard-set
termux-clipboard-get | head -1
```

## Clipboard usage

Clipboard handoff is useful for short command results and copy-window workflows. Avoid copying secrets, private config, long raw logs, or credentials.

Recommended pattern:

```bash
cgrun 'set -euo pipefail; echo "hello"; echo "RESULT: SAMPLE_DONE"'
cgtail 80
```

## Notification usage

Notifications are useful for long-running local jobs:

```bash
termux-notification \
  --title "Termux job finished" \
  --content "Check cgtail for the result"
```

Do not place private paths or secret material in notification text.

## Common failures

| Symptom | Likely cause | Fix |
|---|---|---|
| `command not found` | package missing | `pkg install termux-api` |
| command hangs or returns empty | Android companion app missing or restricted | install/enable the app and check Android battery restrictions |
| clipboard does not update | Android clipboard restriction or missing permission | retry foregrounded Termux, then verify app permissions |
| notifications not shown | notification permission disabled | allow notifications for Termux/Termux:API |
