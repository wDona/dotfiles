#!/usr/bin/env bash
# Cambia la variante visual de waybar reescribiendo el @import de style.css.
#   variant.sh            -> imprime la activa
#   variant.sh list       -> lista las disponibles (* = activa)
#   variant.sh next       -> rota a la siguiente (para atajo de teclado)
#   variant.sh <nombre>   -> aplica esa
# Recarga con SIGUSR2, que waybar usa para releer config y CSS sin reiniciar.
set -euo pipefail
DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
CSS="$DIR/style.css"

# Escribir A TRAVES del symlink de stow: sed -i lo reemplazaria por un
# fichero real y el cambio dejaria de vivir en el repo de dotfiles.
set_variant() {
    [ -f "$DIR/variants/$1.css" ] || { echo "no existe: $1" >&2; exit 1; }
    local out; out=$(sed "s|^@import url(\"variants/.*|@import url(\"variants/$1.css\");|" "$CSS")
    printf '%s\n' "$out" > "$CSS"
    pkill -SIGUSR2 waybar 2>/dev/null || true
    echo "$1"
}

current() { sed -n 's|^@import url("variants/\(.*\)\.css");|\1|p' "$CSS"; }
names() { for f in "$DIR"/variants/*.css; do basename "$f" .css; done; }

case "${1:-}" in
"") current ;;
list)
    cur=$(current)
    while read -r n; do [ "$n" = "$cur" ] && echo "* $n" || echo "  $n"; done < <(names)
    ;;
next)
    cur=$(current)
    # primera de la lista que va despues de la actual; si es la ultima, vuelve al principio
    set_variant "$(names | grep -A1 -x "$cur" | tail -1 | grep -vx "$cur" || names | head -1)"
    ;;
*) set_variant "$1" ;;
esac
