#!/usr/bin/env bash
# Toggle del dashboard de hardware eww. Abre/cierra en el monitor con foco.
"$(dirname "$0")/eww_ensure.sh"

if eww active-windows 2>/dev/null | grep -q "dashboard"; then
    eww close dashboard
else
    mon=$("$(dirname "$0")/eww_screen.sh")
    eww open dashboard --screen "$mon"
fi
