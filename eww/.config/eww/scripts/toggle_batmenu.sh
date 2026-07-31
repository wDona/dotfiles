#!/usr/bin/env bash
# Toggle del menu de perfiles de energia (bateria) eww.
"$(dirname "$0")/eww_ensure.sh"

if eww active-windows 2>/dev/null | grep -q "batmenu"; then
    eww close batmenu
else
    mon=$("$(dirname "$0")/eww_screen.sh")
    eww open batmenu --screen "$mon"
fi
