#!/usr/bin/env bash
# Toggle del menu de perfiles de energia (bateria) eww.
if ! eww ping >/dev/null 2>&1; then
    eww daemon >/dev/null 2>&1
    sleep 0.4
fi

if eww active-windows 2>/dev/null | grep -q "batmenu"; then
    eww close batmenu
else
    mon=$("$(dirname "$0")/eww_screen.sh")
    eww open batmenu --screen "$mon"
fi
