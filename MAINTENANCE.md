# Termux maintenance workflow

This workflow updates Termux packages and the checked-out Termux Toolbox without silently deleting old runtime directories or rewriting a dirty Git worktree.

## Entry point

Run the complete workflow from the repository root:

```bash
bash maintenance/run-maintenance.sh
```

The entry point performs:

1. package database and dependency checks;
2. Python and pip checks;
3. old Python runtime directory inventory;
4. toolbox branch, worktree, origin and remote-main checks;
5. repository verification and installed-helper parity checks;
6. a gated package upgrade;
7. a fast-forward-only toolbox update;
8. toolbox installation and SHA-256 parity verification;
9. a final environment audit.

## Apply gate

The update script only proceeds when a recent audit reports:

```text
APPLY_ALLOWED=yes
```

The audit state is stored below:

```text
$HOME/.chatgpt-output/termux-maintenance/latest-audit.env
```

By default, an audit is accepted for 3600 seconds. Override this only when the maintenance window requires it:

```bash
TERMUX_TOOLBOX_MAX_AUDIT_AGE=1800 bash maintenance/run-maintenance.sh
```

## Repository location

The default checkout is:

```text
$HOME/src/termux-toolbox
```

A different checkout may be selected explicitly:

```bash
TERMUX_TOOLBOX_REPO="$HOME/other/termux-toolbox" bash maintenance/run-maintenance.sh
```

The checkout must:

- be on `main`;
- have a clean worktree;
- use the canonical GitHub origin;
- remain on the audited commit until the update starts.

The update uses `git pull --ff-only`. It never force-resets an unrelated dirty worktree.

## Rollback boundary

Before changing installed toolbox helpers, the workflow records:

- installed package lists;
- manually installed package selections;
- the toolbox Git commit;
- copies of installed toolbox commands.

If the toolbox update or installation fails, it attempts to restore the previous toolbox Git commit and installed helper files.

Termux package downgrades are not automatic. Package-manager rollback must be handled separately.

## Old Python directories

After a Python upgrade, `dpkg` may leave an older directory below `$PREFIX/lib` when it still contains files.

The maintenance workflow inventories such directories and reports:

```text
WARN: old_python_directories_present_cleanup_deferred
```

It does not delete them. Removal requires a separate ownership and dependency review.

## Result markers

Successful stages end with:

```text
RESULT: TERMUX_TOOLBOX_ENVIRONMENT_AUDIT_DONE status=PASS|WARN apply_allowed=yes
RESULT: TERMUX_TOOLBOX_MAINTENANCE_UPDATE_DONE rc=0
RESULT: TERMUX_TOOLBOX_MAINTENANCE_DONE rc=0
```

A `WARN` audit remains eligible for apply when no blocking package, dependency, pip or repository finding exists.
