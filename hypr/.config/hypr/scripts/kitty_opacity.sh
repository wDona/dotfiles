#!/usr/bin/env bash
# Cambia background_opacity de kitty (recibe 0-100). Edita kitty.conf y aplica
# en vivo a las ventanas abiertas (SIGUSR1 recarga config).
set -uo pipefail
pct="${1:-75}"
# 0-100 -> 0.00-1.00
val=$(awk "BEGIN{printf \"%.2f\", $pct/100}")
f="$HOME/.config/kitty/kitty.conf"

if grep -q '^background_opacity ' "$f"; then
    sed -i "s|^background_opacity .*|background_opacity $val|" "$f"
else
    printf 'background_opacity %s\n' "$val" >> "$f"
fi

for pid in $(pgrep -x kitty); do kill -SIGUSR1 "$pid" 2>/dev/null; done
