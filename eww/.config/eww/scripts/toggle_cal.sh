#!/usr/bin/env bash
# Toggle del calendario eww. Arranca el daemon si hace falta, lo abre en el
# monitor con foco y activa un submap de Hyprland para cerrar con ESC.

CONFIG_DIR="$HOME/.config/eww"

# Asegurar daemon
if ! eww ping >/dev/null 2>&1; then
    eww daemon >/dev/null 2>&1
    sleep 0.4
fi

if eww active-windows 2>/dev/null | grep -q "calendario"; then
    eww close calendario
    eww update cal_picker="none" cal_selected="" event_input="" 2>/dev/null
    hyprctl dispatch submap reset >/dev/null 2>&1
else
    # monitor con foco (Hyprland) -> pantalla de eww
    mon=$("$CONFIG_DIR/scripts/eww_screen.sh")
    # volver al mes actual y rellenar el grid (cache) antes de abrir
    "$CONFIG_DIR/scripts/nav.sh" 0 >/dev/null 2>&1
    eww open calendario --screen "$mon"
    # submap: ESC cierra el calendario (resto de teclas pasan normal)
    hyprctl dispatch submap calendar >/dev/null 2>&1
    # pull de Google en segundo plano (refresca el grid al terminar)
    setsid "$CONFIG_DIR/scripts/cal_sync.sh" 0 >/dev/null 2>&1 &
fi
