#!/usr/bin/env bash
# Toggle del popup de volumen eww (mismo patron que toggle_batmenu.sh).
if ! eww ping >/dev/null 2>&1; then
    eww daemon >/dev/null 2>&1
    sleep 0.4
fi

if eww active-windows 2>/dev/null | grep -q "volumen"; then
    eww close volumen
else
    mon=$("$(dirname "$0")/eww_screen.sh")
    eww open volumen --screen "$mon"
fi
