# cg-run-file: native Termux shebang compatibility

`cg-run-file` accepts portable shell shebangs directly and also supports the native Termux interpreter paths:

- `#!/data/data/com.termux/files/usr/bin/bash`
- `#!/data/data/com.termux/files/usr/bin/sh`

For native Termux paths, the wrapper creates a temporary executable copy below `TMPDIR`, replaces only the first line with the corresponding portable shebang, and then delegates to `cg-lane.sh run-file`. The source artifact is not modified.

Generated Pixel-local controllers should prefer:

```text
#!/usr/bin/env bash
```

The native paths remain accepted for compatibility with existing Termux-generated artifacts.

Regression coverage: `verify/verify-cg-run-file-termux-shebang.sh`.
