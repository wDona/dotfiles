#!/usr/bin/env bash
# Toggle del widget de clima.
DIR="$(dirname "$0")"
"$DIR/eww_ensure.sh"

"$DIR/popup.sh" is-open clima && exec "$DIR/popup.sh" close

# Abre ya con el ultimo dato conocido y refresca por detras: si la cache de
# avisos caduco, weather.sh json se va a la red (hasta 15 s) y bloquear ahi el
# open es lo que hacia que el widget tardase segundos en aparecer.
"$DIR/popup.sh" open clima
eww update weather_json="$("$DIR/weather.sh" json)" &
