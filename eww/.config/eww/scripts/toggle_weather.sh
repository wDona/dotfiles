#!/usr/bin/env bash
# Toggle del widget de clima.
DIR="$(dirname "$0")"
"$DIR/eww_ensure.sh"

"$DIR/popup.sh" is-open clima && exec "$DIR/popup.sh" close

# Posicion: centrado bajo el modulo, en el monitor con foco y a cualquier
# resolucion. El truco es que este script SOLO se lanza desde el click en el
# modulo, asi que el raton esta justo encima: `hyprctl cursorpos` da la x del
# modulo sin tener que medir nada. Antes era un x fijo calibrado a mano contra
# el borde derecho, y se descalibraba al cambiar de monitor, al alargarse el
# titulo de Spotify o al colapsarse el temporizador.
W=330   # = :width de la ventana `clima` en eww.yuck
Y=5     # justo debajo de la barra (los layer-shell empiezan bajo su zona)

read -r mx mw < <(hyprctl monitors -j 2>/dev/null \
    | jq -r '(.[] | select(.focused==true)) // .[0] | "\(.x) \(.width)"')
cx=$(hyprctl cursorpos 2>/dev/null | tr -d ' ' | cut -d, -f1)

if [ -n "${mx:-}" ] && [ -n "${cx:-}" ]; then
    x=$(( cx - mx - W / 2 ))
    # Recorte a los bordes del monitor: en pantallas estrechas (1360) el popup
    # se queda pegado al filo con 5px de aire en vez de salirse.
    max=$(( mw - W - 5 ))
    [ "$x" -gt "$max" ] && x=$max
    [ "$x" -lt 5 ] && x=5
    "$DIR/popup.sh" open clima "${x}x${Y}" "top left"
else
    # Sin hyprctl/jq: la geometria del yuck (anclada a la derecha)
    "$DIR/popup.sh" open clima
fi

# Refresca por detras: si la cache de avisos caduco, weather.sh json se va a la
# red (hasta 15 s) y bloquear ahi el open es lo que hacia que el widget tardase
# segundos en aparecer.
eww update weather_json="$("$DIR/weather.sh" json)" &
