# Python artifacts through `cg-run-file`

`cg-run-file` accepts executable Python 3 artifacts with either of these exact shebangs:

```text
#!/data/data/com.termux/files/usr/bin/python3
#!/usr/bin/env python3
```

The wrapper does not broaden interpreter execution generically. It copies the Python payload into a private temporary directory, normalizes the payload shebang, validates it with `python3 -m py_compile`, and creates a temporary Bash launcher with the original artifact basename. The existing `cg-lane.sh` contract therefore continues to receive a verified Bash artifact while the original task label remains stable.

The temporary launcher executes the payload explicitly with `python3`. The temporary directory is removed after the run. Invalid Python syntax fails before lane execution.

Regression coverage is provided by `verify/verify-cg-run-file-termux-shebang.sh` for native Termux and portable Python 3 shebangs, payload execution, task-basename preservation, mode canonicalization, and syntax rejection.
