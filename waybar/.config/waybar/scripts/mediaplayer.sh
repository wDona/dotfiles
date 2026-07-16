#!/bin/bash
# Marquee de Spotify para waybar.
# OJO: loop continuo -> en waybar usar "exec" SIN "interval".
#   scroll up   -> siguiente cancion
#   scroll down -> anterior
#   click       -> play/pause

WIDTH=22        # ancho visible de la ventana de scroll
STEP=0.35       # segundos entre frames del marquee
SEP="   •   "   # separador al envolver el texto

pos=0
last=""

while true; do
    status=$(playerctl -p spotify status 2>/dev/null)

    case "$status" in
        Playing) icon="" ;;
        Paused)  icon="" ;;
        *)       echo ""; sleep 1; continue ;;   # nada sonando -> modulo vacio
    esac

    track=$(playerctl -p spotify metadata --format '{{artist}} - {{title}}' 2>/dev/null)
    [ -z "$track" ] && { echo ""; sleep 1; continue; }

    # reinicia el scroll al cambiar de cancion
    if [ "$track" != "$last" ]; then
        pos=0
        last="$track"
    fi

    if [ "${#track}" -le "$WIDTH" ]; then
        printf '%s %s\n' "$icon" "$track"   # cabe entero -> sin scroll
        sleep 1
        continue
    fi

    # ventana deslizante circular sobre "track + separador"
    full="${track}${SEP}"
    len=${#full}
    doubled="${full}${full}"
    window=${doubled:pos:WIDTH}
    printf '%s %s\n' "$icon" "$window"

    pos=$(( (pos + 1) % len ))
    sleep "$STEP"
done
