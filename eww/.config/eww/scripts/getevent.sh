#!/usr/bin/env bash
# Imprime el texto del evento de una fecha (vacio si no hay).
# Uso: getevent.sh <YYYY-MM-DD>
EVENTS="$HOME/.config/eww/events.json"
[ -f "$EVENTS" ] || { echo ""; exit 0; }
jq -r --arg d "$1" '.[$d] // ""' "$EVENTS"
