# Maintenance workflow reference

The canonical maintenance entry point is documented in [`../MAINTENANCE.md`](../MAINTENANCE.md).

Use this document only as a stable documentation index for the `docs/` tree.

The workflow itself lives in:

```text
maintenance/run-maintenance.sh
maintenance/termux-environment-audit.sh
maintenance/update-termux-and-toolbox.sh
```

The maintenance contract is:

```text
audit -> APPLY_ALLOWED gate -> package update -> fast-forward-only toolbox update -> install parity -> post-audit
```

Old Python runtime directories are inventoried and left untouched. Toolbox files and the previous toolbox Git commit form the automatic rollback boundary. Package downgrades remain manual.
