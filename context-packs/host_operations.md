# Context Pack: Host and Device Operations

Marker: CONTEXT_HOST_OPERATIONS_V1_20260710

## Purpose

Use this context for direct device and special workflow scopes.

## Mandatory order

1. Resolve repository and live host state.
2. Confirm host, target path, secret class and route class.
3. Run read-only preflight before changes.
4. Establish root cause.
5. Apply the smallest guarded change.
6. Verify using scope, host and result markers.

## Scope boundaries

- pixel is the control plane, not DNS, HA or VIP source of truth.
- pi3 and pi4 require Raspberry Pi and storage hostguards.
- berylax is OpenWrt and BusyBox ash, not Raspberry Pi or systemd.
- omen is Windows via OpenSSH and defaults to read-only.
- dns-ha-route never authorizes a route or DNS change by itself.
- pi-host-drop uses the dispatcher, remote verify and separate host run.
- pi4-takeout stays inside its documented pi4 service and storage workflow.
- zeropi2-edge remains separate from generic zeropi2 operations.

## Safety

- Never silently change DNS, HA, VIP, default routes, static routes, MagicDNS or subnet routes.
- Never infer successful host state from delivery alone.
- Do not expose secrets in context output or logs.
- Historical and superseded states are not operative evidence.
