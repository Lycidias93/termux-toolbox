# cg-run-file: native Termux shebang compatibility

`cg-run-file` accepts portable shell shebangs directly and also supports the native Termux interpreter paths:

- `#!/data/data/com.termux/files/usr/bin/bash`
- `#!/data/data/com.termux/files/usr/bin/sh`

For native Termux paths, the wrapper creates a temporary executable copy below `TMPDIR`, replaces only the first line with the corresponding portable shebang, and then delegates to `cg-lane.sh run-file`. The source artifact is not modified.

Installed toolbox commands under `bin/` use the native Termux Bash shebang because Android does not provide `/usr/bin/env` for direct kernel execution. `install.sh` rejects a non-native shebang in these runtime entry points.

Generated Pixel-local controllers transported through `cg-run-file` may still prefer:

```text
#!/usr/bin/env bash
```

`cg-run-file` normalizes supported controller shebangs inside a private temporary copy before execution, so this portable artifact form does not imply that installed `bin/*` commands may use `/usr/bin/env`.

Regression coverage: `verify/verify-cg-run-file-termux-shebang.sh`.
