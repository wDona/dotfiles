#!/usr/bin/env bash
# Toggle del widget de clima. Mismo patron que toggle_cal.sh.

CONFIG_DIR="$HOME/.config/eww"

if ! eww ping >/dev/null 2>&1; then
    eww daemon >/dev/null 2>&1
    sleep 0.4
fi

if eww active-windows 2>/dev/null | grep -q "clima"; then
    eww close clima
else
    eww update weather_json="$("$CONFIG_DIR/scripts/weather.sh" json)"
    eww open clima --screen "$("$CONFIG_DIR/scripts/eww_screen.sh")"
fi
