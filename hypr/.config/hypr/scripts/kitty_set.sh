#!/usr/bin/env bash
# kitty_set.sh {opacity <0-100>|font <size>}  - edita kitty.conf y recarga (SIGUSR1).
set -uo pipefail
f="$HOME/.config/kitty/kitty.conf"

put() {  # clave valor  -> upsert linea "clave valor"
    if grep -q "^$1 " "$f"; then sed -i "s|^$1 .*|$1 $2|" "$f"
    else printf '%s %s\n' "$1" "$2" >> "$f"; fi
}

case "${1:-}" in
    opacity) put background_opacity "$(awk "BEGIN{printf \"%.2f\", ${2:-75}/100}")" ;;
    font)    put font_size "${2%%.*}" ;;
    *) echo "uso: kitty_set.sh {opacity <0-100>|font <size>}" >&2; exit 1 ;;
esac

for pid in $(pgrep -x kitty); do kill -SIGUSR1 "$pid" 2>/dev/null; done
