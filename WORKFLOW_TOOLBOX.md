# Workflow Toolbox

Marker: WORKFLOW_TOOLBOX_BASELINE_V2_20260710

## Role

This repository is the central technical source for cross-repository workflow tools.

## Central scope registry

config/workflow-scopes.tsv is the source of truth for chatctx and cgflow scope validation.

Canonical scopes:

- repo
- generic
- workflow-baseline
- pixel
- pixel-dispatcher
- pi3
- pi4
- berylax
- pi-host-drop
- dns-ha-route
- pi4-takeout
- zeropi2
- zeropi2-edge
- omen

## Included

- tools/chatctx
- tools/cgflow
- tools/workflow-scope-verify.sh
- tools/workflow-scope-consumer-audit.sh
- tools/workflow-guard.sh
- tools/secret-guard.sh
- tools/route-change-guard.sh
- tools/host-artifact-name-guard.sh
- tools/assistant-output-guard.sh
- tools/cross-repo-workflow-audit
- tools/cross-repo-workflow-sync
- templates/state_gate.md
- context-packs
- task-cards

## Consumer rule

Every active repository must provide local tools/chatctx and tools/cgflow wrappers.
The wrappers delegate to WORKFLOW_TOOLBOX_ROOT, HOME/src/termux-toolbox or a sibling termux-toolbox checkout.
Scope support must not be copied into consumer wrappers.

## Stop rule

When the central toolbox or scope registry cannot be resolved, the wrapper or central tool must stop.

## Route guard classification

Route-sensitive paths are matched using complete normalized path tokens.
Generic paths such as CHANGELOG.md and tools/chatctx must not trigger the guard.
The behavior is covered by tools/route-change-guard-selftest.sh.
