#!/usr/bin/env bash
# Toggle del calendario eww.
DIR="$(dirname "$0")"
"$DIR/eww_ensure.sh"

"$DIR/popup.sh" is-open calendario && exec "$DIR/popup.sh" close

# Volver al mes actual y rellenar el grid (cache) antes de abrir.
"$DIR/nav.sh" 0 >/dev/null 2>&1

"$DIR/popup.sh" open calendario

# Tiempo de hoy + 7 dias por detras: si la cache del clima esta caducada,
# weather.sh se va a la red y bloquear el open aqui se notaria al abrir.
# Deja el mapa en disco y vuelve a generar el grid: cal.sh lo lee y mete el
# icono dentro de cada celda (el widget no puede buscar por fecha, ver cal.sh).
# La primera vez del dia los iconos aparecen un segundo despues; el resto de
# aperturas ya salen con la cache caliente.
(
    WC="${XDG_CACHE_HOME:-$HOME/.cache}/eww-weather-cal.json"
    "$DIR/weather.sh" cal > "$WC.tmp" && mv "$WC.tmp" "$WC" && "$DIR/nav.sh" 0
) >/dev/null 2>&1 &

# Pull de Google en segundo plano (refresca el grid al terminar).
# nice+ionice: que no le robe CPU/red a la UI cuando navegas con las flechitas
# justo despues de abrir.
setsid nice -n 19 ionice -c3 "$DIR/cal_sync.sh" 0 >/dev/null 2>&1 &
