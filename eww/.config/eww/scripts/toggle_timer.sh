#!/usr/bin/env bash
# Toggle del menu de temporizador eww (reemplaza al rofi de timer.sh set).
"$(dirname "$0")/eww_ensure.sh"

if eww active-windows 2>/dev/null | grep -q "timermenu"; then
    eww close timermenu
    exit 0
fi

eww update timer_presets_json="$(~/.config/waybar/scripts/timer.sh presets)" timer_input="" timer_confirm=false
eww open timermenu
