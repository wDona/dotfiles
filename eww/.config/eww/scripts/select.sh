#!/usr/bin/env bash
# Marca un dia y carga SUS EVENTOS (lista) en los slots sevN_* del panel.
# Uso: select.sh <YYYY-MM-DD>
date="$1"
EVENTS="$HOME/.config/eww/events.json"
# soporta formato nuevo (array) y viejo (string)
mapfile -t evs < <(jq -r --arg d "$date" '(.[$d] // []) | if type=="array" then .[] else . end' "$EVENTS" 2>/dev/null)

MAX=8
args=(cal_selected="$date" nev="${#evs[@]}")
for ((i=0;i<MAX;i++)); do
    if [ "$i" -lt "${#evs[@]}" ]; then
        args+=("sev${i}_show=true" "sev${i}_text=${evs[$i]}")
    else
        args+=("sev${i}_show=false" "sev${i}_text=")
    fi
done
eww update "${args[@]}"
