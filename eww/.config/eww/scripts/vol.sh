#!/usr/bin/env bash
# Estado y control del sink por defecto, para el popup de volumen de eww.
#
#   vol.sh get      -> porcentaje entero (0-100)
#   vol.sh muted    -> "true" | "false"
#   vol.sh set N    -> fija el volumen a N%
#   vol.sh up [N]   -> sube N puntos (5 por defecto)
#   vol.sh down [N] -> baja N puntos (5 por defecto)
#   vol.sh toggle   -> silencia / desilencia
#
# Se usa wpctl (WirePlumber) porque el stack de audio aqui es PipeWire y es lo
# que ya usa el resto del rice. `wpctl get-volume` imprime "Volume: 0.45" y,
# si esta silenciado, "Volume: 0.45 [MUTED]".
set -euo pipefail

SINK="@DEFAULT_AUDIO_SINK@"

case "${1:-get}" in
    get)
        # awk redondea en vez de truncar: con 0.45 wpctl da 45, pero con
        # valores tipo 0.549999 truncar daria 54 y el slider saltaria solo.
        wpctl get-volume "$SINK" | awk '{printf "%d", $2 * 100 + 0.5}'
        ;;
    muted)
        if wpctl get-volume "$SINK" | grep -q '\[MUTED\]'; then
            echo true
        else
            echo false
        fi
        ;;
    set)
        # -l 1.0 capa al 100%: sin el limite wpctl deja sobreamplificar por
        # encima del maximo del slider y el valor se sale del rango 0-100.
        wpctl set-volume -l 1.0 "$SINK" "${2:-0}%"
        ;;
    up)
        # Mismo -l 1.0 que en `set`: sin el, wpctl sobreamplifica por encima
        # del 100% y el slider del popup se sale de rango.
        wpctl set-volume -l 1.0 "$SINK" "${2:-5}%+"
        ;;
    down)
        wpctl set-volume "$SINK" "${2:-5}%-"
        ;;
    toggle)
        wpctl set-mute "$SINK" toggle
        ;;
esac
