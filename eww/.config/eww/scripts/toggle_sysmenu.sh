#!/usr/bin/env bash
# Toggle del menu de sistema eww (power + hardware + temporizador).
"$(dirname "$0")/eww_ensure.sh"

if eww active-windows 2>/dev/null | grep -q "sysmenu"; then
    eww close sysmenu
else
    mon=$("$(dirname "$0")/eww_screen.sh")
    eww open sysmenu --screen "$mon"
fi
