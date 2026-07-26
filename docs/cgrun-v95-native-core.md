# cgrun v9.5 native core and original task binding

## Root cause

The execution-receipt wrapper originally delegated every run to the pre-existing local file
`$PREFIX/bin/cgrun.autoclip-v93-real`. The repository installer checked that file but did not
own or replace it. A successful wrapper installation therefore kept the old v9.3 execution
core active. Its legacy completion marker `RESULT: CGRUN_DONE rc=<n>` remained visible inside
otherwise valid v9.5 output.

`cg-run-file` also normalized native Termux shebangs into a temporary file named
`cg-run-file-normalized.*`. The lane layer derived the receipt task from that temporary
execution path, so the original artifact basename was lost.

The first native-core regression was correct when run from a clean shell, but it inherited
`CG_RUN_*` and `CG_LANE_*` variables when invoked from an outer `cg-run-file` workflow. That
made its direct-run cases identify the outer controller task and lane instead of the isolated
test values. Because the first assertion failed under `set -e`, the regression stopped before
printing its PASS markers.

After environment isolation was added, the intentionally failing `exit 7` case still invoked
the global `ERR` diagnostic trap. `set +e` permits control flow to continue, but it does not
turn an `ERR` trap into an expected-result handler. The failure case is therefore executed as
the condition of an `if` statement, where its exit status is captured and asserted explicitly;
only unexpected failures reach the diagnostic trap.

A fresh Pixel native-core smoke then exposed a final identity mismatch: `cg-run-file` omitted
its mode argument by default, so `cg-lane.sh` used the uppercase default `VERIFY` when building
the outer run ID. The receipt sanitizer canonicalized that value to lowercase `verify`, leaving
the outer completion and receipt with different run IDs. `cg-run-file` now canonicalizes the
mode to `verify|run` before the lane creates the run ID and rejects all other values.

The aggregate verifier also changed every shebang-bearing source file to executable with
`chmod +x`. Git recorded those mutations as `100644 -> 100755` mode-only changes even though
all file contents remained byte-identical. That made later guarded updates stop on a dirty
worktree created by the verifier itself.

A later Pixel restore exposed a separate shell-resolution defect. The installed v9.5 files
were correct, but an old `cgrun()` and `cgtail()` function block restored into `~/.bashrc`
shadowed the files in `$PREFIX/bin`. The functions called the historical v9.3 compatibility
names and added a second AutoTail, so the clipboard handoff was overwritten and the obsolete
`CGRUN_AUTO_TAIL_DONE rc=... original_cgrun_rc=...` marker returned.

## Fixed architecture

The repository now owns the full active runtime:

- `bin/cgrun`: receipt, AutoCopy, lane identity, and workflow result
- `bin/cgrun-core-v95`: command execution, log creation, heartbeat, timeout, and named core result
- `bin/cgtail-core-v95`: bounded dynamic tail output
- `bin/cgrun.autoclip-v93-real`: compatibility shim only
- `bin/cgtail-autoclip-v93`: compatibility shim only

The active wrapper calls the v9.5 core files directly. The legacy filenames remain installed
only so older local callers fail over to the same repository-owned implementation rather than
an unmanaged restored file.

For normalized scripts, `cg-run-file` creates a unique temporary directory but keeps the
original artifact basename. Receipts therefore identify the user-visible artifact, not the
normalization directory. The run mode is canonicalized before run-ID creation, so the lane,
core metadata, receipt, AutoCopy handoff, and outer completion share one byte-identical run ID.

Repository verification is read-only with respect to tracked source files. Shell checks use
`bash -n`, nested verifier scripts are invoked explicitly with `bash`, and the aggregate
verifier compares Git status before and after execution. Any verifier-created worktree change
is a hard failure.

`maintenance/ensure-native-cg-shell-guard.sh` owns an idempotent final block in `~/.bashrc`.
Every installer and maintenance run removes older copies of that block, appends one canonical
copy at the end, unsets restored legacy functions, refreshes Bash command hashing, and verifies
that interactive Bash resolves `cgrun` and `cgtail` as the native files in `$PREFIX/bin`.
A changed shell file is backed up under `$HOME/.chatgpt-output/native-cg-shell-guard-backups`.
The guard does not delete the historical function source; it makes it inert after shell startup
and therefore remains reversible through the recorded backup.

## Verification

`verify/verify-cg-execution-receipt.sh` checks:

- direct success and failure through the repository-owned core
- explicit capture of the expected failure exit code without invoking the unexpected-error trap
- absence of generic `rc=` fields in `CGRUN_*` result markers
- original artifact task binding
- receipt presence in the clipboard handoff
- isolation from inherited outer `CG_RUN_*` and `CG_LANE_*` values by running each case through
  a minimal `env -i` environment
- diagnostic capture output on any future unexpected assertion failure

`verify/verify-cg-run-file-termux-shebang.sh` checks that shebang normalization preserves the
original basename, canonicalizes uppercase, mixed-case, and omitted modes to `verify`, and
rejects unsupported run modes before they can create a divergent run ID.

`verify/verify-native-cg-shell-guard.sh` checks first application, backup creation, interactive
file resolution, idempotent reapplication, and repair after a simulated legacy `.bashrc`
restore.

`verify/verify-termux-toolbox.sh` checks syntax without changing executable bits and emits
`PASS verifier_worktree_immutable` only when its complete run leaves Git status unchanged.

`maintenance/verify-installed-cg-runtime.sh` checks syntax, executable state, markers, SHA-256
parity, guard uniqueness and final position, and interactive file resolution for the wrapper,
both native cores, compatibility shims, lane runtime, and `cg-run-file`.
