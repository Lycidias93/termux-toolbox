# Noninteractive RDC handoff transport — 2026-10-10

## Observed failure

A verified Pixel RDC shell invoked a canonical read-only Workflowfit bundle without an interactive terminal. The command payload and test succeeded, but `cgrun` invoked Android `termux-clipboard-set` anyway and timed out (exit 124); `cg-handoff` later attempted `/dev/tty` and printed an error. The receipt correctly separated payload success from clipboard delivery failure. Interactive user-operated Termux sessions continue to need AutoCopy.

## Source-only fix

- `bin/cgrun`: when **all** of fd 0, 1 and 2 are non-TTY and no custom clipboard command is provided, do not call Android Termux:API clipboard. Instead stream/log the exact bound handoff, set `clipboard_verify_state=noninteractive_stream`, `handoff_outcome=stream_only`, and emit `CGRUN_CLIPBOARD_TRANSPORT mode=noninteractive_stream clipboard_write=skipped result=PASS`. The returned workflow success still depends on the actual command and helper exits.
- The opt-out `CGRUN_NONTTY_STREAM_ONLY=0` preserves the previous Android clipboard attempt for a deliberately headless clipboard user; an explicit `CGRUN_CLIPBOARD_COMMAND` always takes precedence.
- `bin/cg-handoff`: skip the parent input-drain step before opening `/dev/tty` when all three standard descriptors are non-TTY. The normal interactive, bounded delayed TTY drain remains unchanged.
- `verify/verify-rdc-noninteractive-handoff-v1.sh` adds isolated tests of default streaming, custom clipboard override, and no-TTY drain behavior. The main toolbox verifier always executes the new test.

## Invariants and rollout boundary

No secret, host route, package, root module, network or Android setting is changed. Runtime source updates are **not** installed by a GitHub merge. A separate Pixel installer/version must be frozen and owner-approved before replacing executable files on the device under the Heimnetz `installation_class` gate; live installed `cg-handoff` and `cgrun` remain unchanged until then. No reboot is required by the source change itself.

The response transport for unattended RDC runs is the exact bounded stdout/log/receipt, not a pretend successful Android clipboard write. Interactive foreground Termux continues to copy the outermost result to the Android clipboard.
