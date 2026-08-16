# Canonical route classes and early cg-handoff AutoCopy

Stand: 2026-08-16.

## Problem

A `cg-handoff` artifact using the canonical `route` class was accepted by the handoff metadata parser but rejected by the older multilane guards before execution. The same early failure occurred before `cgrun`, so the mandatory AutoCopy path never ran and the failure handoff was not placed on the clipboard.

## Root cause

The route-class vocabulary drifted between layers:

- the Heimnetz bootstrap and `cg-handoff` accept `none|read-only|route|dns-ha|magicdns|subnet-route`;
- `cg-lane.sh` and `cg-run-file-driver-v1` still accepted only `none|read-only`;
- `cg-handoff` delegated preflight failures directly and had no early-failure clipboard path before `cg-run-file`/`cgrun`.

## Fix

- align `cg-lane.sh` and `cg-run-file-driver-v1` with the canonical route-class vocabulary;
- keep unknown and legacy-only route classes fail-closed;
- add `CG_HANDOFF_EARLY_AUTOCOPY_V1` so failures before `cgrun` create a bounded handoff and copy it through the configured clipboard command or `termux-clipboard-set`;
- retain full early failure context for `none|public|redacted` and redact it for `possible|sensitive`/unknown secret classes;
- capture `cgprep`/`cclear`/`cgcurrent`/`cguse` preflight output so the actual failing evidence is included in early AutoCopy;
- leave post-preflight execution on the existing `cgrun` AutoCopy path.

## Verification

The handoff fixture now exercises all six canonical route classes and the run-file driver route guard. It also injects a `cguse` failure and verifies that the early AutoCopy sink receives the failing preflight evidence, route/secret binding and final `CG_HANDOFF_STOP` marker. The installed-runtime verifier binds these checks in addition to source/install parity, noninteractive stdin and delayed TTY-tail verification.

## Risk / rollback

Risk is low and limited to Termux workflow orchestration. No host, DNS, HA, VIP, firewall, Tailscale or route state is changed by the repository patch. Rollback is a revert of the task commits or restoration of the previously installed runtime files during device acceptance.
