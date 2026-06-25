#!/usr/bin/env bash
set -euo pipefail

PUBLIC_DIR="${PUBLIC_DIR:-$HOME/src/termux-toolbox}"
HEIMNETZ_DIR="${HEIMNETZ_DIR:-$HOME/src/heimnetz-geraete}"
VENDOR_DIR="$HEIMNETZ_DIR/vendor/termux-toolbox"

[ -d "$PUBLIC_DIR/.git" ] || { echo "FAIL missing_public_repo dir=$PUBLIC_DIR"; exit 1; }
[ -d "$HEIMNETZ_DIR/.git" ] || { echo "FAIL missing_heimnetz_repo dir=$HEIMNETZ_DIR"; exit 1; }

copy_allowlisted_public_snapshot() {
  src="$1"
  dst="$2"
  rm -rf "$dst"
  mkdir -p "$dst"

  for item in README.md LICENSE SECURITY.md CHANGELOG.md .gitignore .gitattributes packages.txt install.sh bin docs verify; do
    if [ -e "$src/$item" ]; then
      cp -R "$src/$item" "$dst/$item"
    fi
  done
}

public_source_commit() {
  if git -C "$PUBLIC_DIR" rev-parse --verify --quiet HEAD >/dev/null; then
    git -C "$PUBLIC_DIR" rev-parse --short HEAD
  else
    echo "UNCOMMITTED"
  fi
}

copy_allowlisted_public_snapshot "$PUBLIC_DIR" "$VENDOR_DIR"
public_source_commit > "$VENDOR_DIR/.public-source-commit"
git -C "$PUBLIC_DIR" remote get-url origin > "$VENDOR_DIR/.public-source-remote" 2>/dev/null || true

cd "$HEIMNETZ_DIR"
git diff --check

echo "RESULT: PUBLIC_TOOLBOX_VENDOR_SYNC_DONE"
