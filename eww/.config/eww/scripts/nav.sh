#!/usr/bin/env bash
# Actualiza el calendario eww al mes con el offset dado.
# Uso: nav.sh <offset>   (0 = mes actual, -1 anterior, +1 siguiente)
# Regenera cal_json porque eww no permite variables dentro de defpoll.

off="${1:-0}"
json="$(bash "$HOME/.config/eww/scripts/cal.sh" "$off")"
eww update cal_offset="$off" cal_json="$json"
