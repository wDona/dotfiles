#!/usr/bin/env bash
# Toggle del menu de sistema eww (power + hardware + temporizador).
if ! eww ping >/dev/null 2>&1; then
    eww daemon >/dev/null 2>&1
    sleep 0.4
fi

if eww active-windows 2>/dev/null | grep -q "sysmenu"; then
    eww close sysmenu
else
    mon=$("$(dirname "$0")/eww_screen.sh")
    eww open sysmenu --screen "$mon"
fi
