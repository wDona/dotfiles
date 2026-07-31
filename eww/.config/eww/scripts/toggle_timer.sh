#!/usr/bin/env bash
# Toggle del menu de temporizador eww (reemplaza al rofi de timer.sh set).
if ! eww ping >/dev/null 2>&1; then
    eww daemon >/dev/null 2>&1
    sleep 0.4
fi

if eww active-windows 2>/dev/null | grep -q "timermenu"; then
    eww close timermenu
    exit 0
fi

eww update timer_presets_json="$(~/.config/waybar/scripts/timer.sh presets)" timer_input="" timer_confirm=false
eww open timermenu
