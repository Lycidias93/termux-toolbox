#!/usr/bin/env bash
set -euo pipefail
HEIMNETZ_DIR="${HEIMNETZ_DIR:-$HOME/src/heimnetz-geraete}"
TERMUX_RE='(termux|cgrun|cgtail|cgtail-lane|cgprep|cclear|cgclean|cgcurrent|cguse|cg-handoff|cg-run-file|cglint|cgdoctor|cgfind|cgfail|cgnotify|chatgpt-output|copy window|copy-window|AutoClip|cgtail_clip|CGRUN|CGTAIL|NoHeredoc|Heredoc-Guard|bracketed paste|Termux:API|termux-clipboard|termux-notification|termux-toast)'
cd "$HEIMNETZ_DIR"
git ls-files -co --exclude-standard \
  | grep -Ev '^(\.git/|vendor/termux-toolbox/|local/pixel-termux-toolbox/audit/|logs/|tmp/)' \
  | while IFS= read -r rel; do
      [ -f "$rel" ] || continue
      if grep -IlE "$TERMUX_RE" "$rel" >/dev/null 2>&1; then
        printf '%s\n' "$rel"
      fi
    done
