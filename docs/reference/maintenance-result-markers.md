# Maintenance result markers

Successful maintenance runs use these markers:

```text
RESULT: TERMUX_TOOLBOX_ENVIRONMENT_AUDIT_DONE status=PASS|WARN apply_allowed=yes
RESULT: TERMUX_TOOLBOX_MAINTENANCE_UPDATE_DONE rc=0
RESULT: TERMUX_TOOLBOX_MAINTENANCE_DONE rc=0
```

A warning-only audit may proceed when `apply_allowed=yes`. A blocking package, dependency, pip or repository finding sets `apply_allowed=no`.

Old Python runtime directories are warning-only and are not deleted by the workflow.
