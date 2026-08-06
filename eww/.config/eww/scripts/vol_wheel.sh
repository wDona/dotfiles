#!/usr/bin/env bash
# Rueda del raton sobre el modulo de volumen de waybar:
# cambia el volumen y ensena el popup de eww (no swayosd), que se cierra solo
# a los 2s desde la ULTIMA rueda.
#
#   vol_wheel.sh up|down [pasos]
set -euo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STAMP="${XDG_RUNTIME_DIR:-/tmp}/eww_vol_autoclose"

"$DIR/vol.sh" "$1" "${2:-5}"

"$DIR/eww_ensure.sh"
eww active-windows 2>/dev/null | grep -q volumen \
    || eww open volumen --screen "$("$DIR/eww_screen.sh")"

# Empujar el valor a mano: vol_pct/vol_muted son defpoll de 300ms, asi que sin
# esto el popup va un tercio de segundo por detras de la rueda y con rueda
# rapida se ve saltar. El siguiente poll reescribe lo mismo, no estorba.
eww update vol_pct="$("$DIR/vol.sh" get)" vol_muted="$("$DIR/vol.sh" muted)"

# Antirrebote: cada rueda escribe una marca nueva y deja un vigilante. Al
# despertar, solo cierra el que sigue viendo SU marca, asi que rodar seguido
# reinicia la cuenta en vez de acumular cierres a destiempo.
mark=$(date +%s%N)
echo "$mark" > "$STAMP"
setsid bash -c "sleep 2; [ \"\$(cat '$STAMP' 2>/dev/null)\" = '$mark' ] && ~/.config/eww/scripts/popup.sh close" \
    >/dev/null 2>&1 &
