#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX_DIR="${PREFIX:-/data/data/com.termux/files/usr}"
BIN_DIR="$PREFIX_DIR/bin"

mkdir -p "$BIN_DIR"
for f in "$ROOT"/bin/*; do
  [ -f "$f" ] || continue
  install -m 0755 "$f" "$BIN_DIR/$(basename "$f")"
done

echo "RESULT: TERMUX_TOOLBOX_INSTALL_DONE"
