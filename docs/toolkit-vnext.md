# Termux workflow toolkit vNext

This layer adds small, composable helpers around the existing `cg*` runtime. It does not replace `cgrun`, `cg-run-file`, lane binding, AutoCopy, or the execution receipt.

## Helpers

- `cglint FILE...` is a read-only shell gate: parser check, ShellCheck, then `shfmt -d`. It never formats files in place.
- `cgdoctor [--quick]` reports Termux/toolbox health as machine-readable `PASS`, `WARN`, `FAIL`, and `RESULT` lines. The normal mode performs a bounded `termux-battery-status` API probe when available; it never reads or overwrites the clipboard.
- `cgfind QUERY [ROOT]` performs literal search with `ripgrep`, falling back to recursive `grep` when needed.
- `cgfail [LOG]` extracts only bounded failure/result/exit-code markers from a run log. It is a first diagnostic view, not a replacement for a bound `cgtail` handoff.
- `cgnotify STATUS MESSAGE` sends a bounded Android notification when Termux:API is available. Notification failure is intentionally non-fatal and cannot overwrite the caller's real workflow result. `--dry-run` is provided for fixtures.

## Package classes

`packages.txt` contains the normal toolbox baseline. Toolkit vNext adds:

- `jq`
- `ripgrep`
- `fd`
- `fzf`
- `shellcheck`
- `shfmt`

The following are useful diagnostic/benchmark packages but deliberately remain optional rather than normal runtime dependencies:

- `hyperfine` for repeatable micro-benchmarks;
- `socat` for socket/stream diagnosis;
- `strace` for focused process/syscall diagnosis where Android permissions allow it.

`cgdoctor` reports these optional tools as warnings when absent.

## Safety boundaries

- No helper changes DNS, routes, firewall state, Android settings, package state, or services.
- Search and failure-summary helpers are read-only.
- `cglint` uses `shfmt -d`, never in-place formatting.
- `cgnotify` is a post-result side effect only; notification delivery is never evidence that the underlying task passed.
- Private hostnames, paths, lane defaults, topology, and device policy belong in a private overlay, not this public repository.

## Verification

Run:

```text
bash verify/verify-toolkit-vnext.sh
bash verify/verify-termux-toolbox.sh
```

Installed-runtime verification remains separate from repository verification.
