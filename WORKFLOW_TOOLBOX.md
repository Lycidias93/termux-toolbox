# Workflow Toolbox

Marker: `WORKFLOW_TOOLBOX_BASELINE_V1_20260705`

## Rolle

Dieses Repo ist die zentrale technische Quelle für Cross-Repo-Workflow-Tools.

## Enthalten

- `tools/chatctx`
- `tools/cgflow`
- `tools/workflow-guard.sh`
- `tools/secret-guard.sh`
- `tools/route-change-guard.sh`
- `tools/host-artifact-name-guard.sh`
- `tools/assistant-output-guard.sh`
- `tools/cross-repo-workflow-audit`
- `tools/cross-repo-workflow-sync`
- `templates/state_gate.md`
- `context-packs/*`
- `task-cards/*`

## Consumer-Regel

Jedes aktive Repo muss mindestens lokale Wrapper unter `tools/chatctx` und `tools/cgflow` besitzen. Diese Wrapper delegieren an `$WORKFLOW_TOOLBOX_ROOT`, `$HOME/src/termux-toolbox` oder `../termux-toolbox`.

## Stop-Regel

Wenn die zentrale Toolbox nicht gefunden wird, stoppt der Wrapper mit `RESULT: WORKFLOW_TOOLBOX_MISSING rc=3`.
