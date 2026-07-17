# Maintenance audit state

The audit writes a mode-0600 state file to:

```text
$HOME/.chatgpt-output/termux-maintenance/latest-audit.env
```

Required fields include:

```text
AUDIT_FORMAT=TERMUX_TOOLBOX_MAINTENANCE_V1
AUDIT_EPOCH=<unix timestamp>
AUDIT_STATUS=PASS|WARN|FAIL
APPLY_ALLOWED=yes|no
TOOLBOX_HEAD=<commit>
TOOLBOX_DIRTY=yes|no
```

The update stage rejects a stale audit, a changed toolbox commit, a dirty worktree, invalid ownership or permissive state-file permissions.
