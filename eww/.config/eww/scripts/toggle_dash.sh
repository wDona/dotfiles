#!/usr/bin/env bash
# Toggle del dashboard de hardware eww. Abre/cierra en el monitor con foco.
if ! eww ping >/dev/null 2>&1; then
    eww daemon >/dev/null 2>&1
    sleep 0.4
fi

if eww active-windows 2>/dev/null | grep -q "dashboard"; then
    eww close dashboard
else
    mon=$("$(dirname "$0")/eww_screen.sh")
    eww open dashboard --screen "$mon"
fi
