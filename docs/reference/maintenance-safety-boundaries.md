# Maintenance safety boundaries

The maintenance workflow intentionally does not:

- delete old Python runtime directories;
- run `apt autoremove`;
- force-reset a dirty toolbox worktree;
- force-push or rewrite repository history;
- downgrade Termux packages automatically;
- copy private logs, credentials, SSH material or home-network configuration into the public repository.

The automatic rollback boundary covers the previous toolbox Git commit and installed toolbox helper files. Package-manager rollback remains a separate manual operation.
