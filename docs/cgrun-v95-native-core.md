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
normalization directory.

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
original basename.

`maintenance/verify-installed-cg-runtime.sh` checks syntax, executable state, markers, and
SHA-256 parity for the wrapper, both native cores, compatibility shims, lane runtime, and
`cg-run-file`.
