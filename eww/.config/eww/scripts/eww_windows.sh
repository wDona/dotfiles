#!/usr/bin/env bash
# Lista las ventanas eww definidas (auto-descubre `defwindow`). Si creas una
# nueva en eww.yuck aparece sola. JSON [{name}].
set -uo pipefail
YUCK="$HOME/.config/eww/eww.yuck"
grep -oP '\(defwindow\s+\K[A-Za-z0-9_-]+' "$YUCK" 2>/dev/null \
  | sort -u | jq -Rnc '[inputs | {name:.}]'
