#!/usr/bin/env bash
# Toggle del widget de clima. Mismo patron que toggle_cal.sh.

CONFIG_DIR="$HOME/.config/eww"

"$CONFIG_DIR/scripts/eww_ensure.sh"

if eww active-windows 2>/dev/null | grep -q "clima"; then
    eww close clima
else
    # Abre ya con el ultimo dato conocido y refresca por detras: si la cache de
    # avisos caduco, weather.sh json se va a la red (hasta 15 s) y bloquear ahi
    # el open es lo que hacia que el widget tardase segundos en aparecer.
    eww open clima --screen "$("$CONFIG_DIR/scripts/eww_screen.sh")"
    eww update weather_json="$("$CONFIG_DIR/scripts/weather.sh" json)" &
fi
