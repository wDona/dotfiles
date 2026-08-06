#!/usr/bin/env bash
# Marca un dia y carga SUS EVENTOS (lista) en los slots sevN_* del panel.
# Uso: select.sh <YYYY-MM-DD>
date="$1"
EVENTS="$HOME/.config/eww/events.json"
# soporta formato nuevo (array) y viejo (string)
mapfile -t evs < <(jq -r --arg d "$date" '(.[$d] // []) | if type=="array" then .[] else . end' "$EVENTS" 2>/dev/null)

# Clima de ESE dia, ya resuelto. El panel de abajo no puede buscarlo el mismo:
# eww 0.5 no resuelve mapa[variable], asi que se le deja el objeto servido en
# una variable propia. Fuera del horizonte de prediccion queda {} y el bloque
# del clima no se muestra.
WCACHE="${XDG_CACHE_HOME:-$HOME/.cache}/eww-weather-cal.json"
wt=$(jq -c --arg d "$date" '.[$d] // {}' "$WCACHE" 2>/dev/null)
[ -z "$wt" ] && wt='{}'
# Booleano aparte para el :visible del bloque. Con el objeto vacio, preguntar
# por un campo que no existe (cal_selwt.icon != "") NO da falso en eww: el
# bloque se quedaba visible y ocupando sitio con las etiquetas en blanco.
haswt=false; [ "$wt" != "{}" ] && haswt=true

MAX=8
args=(cal_selected="$date" nev="${#evs[@]}" cal_selwt="$wt" cal_haswt="$haswt")
for ((i=0;i<MAX;i++)); do
    if [ "$i" -lt "${#evs[@]}" ]; then
        args+=("sev${i}_show=true" "sev${i}_text=${evs[$i]}")
    else
        args+=("sev${i}_show=false" "sev${i}_text=")
    fi
done
eww update "${args[@]}"
