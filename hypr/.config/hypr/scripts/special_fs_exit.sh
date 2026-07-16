#!/bin/sh
# Saca la ventana activa de pantalla completa y, si esta en el special
# "fullscreen", la devuelve al workspace donde estaba antes (origen).
SPNAME=special:special

active=$(hyprctl activewindow -j | jq -r '.address')
[ -z "$active" ] || [ "$active" = "null" ] && exit 0
aws=$(hyprctl activewindow -j | jq -r '.workspace.name')

# Quitar fullscreen siempre
hyprctl dispatch fullscreenstate 0 0

# Si esta en el special, devolver al workspace de origen
if [ "$aws" = "$SPNAME" ]; then
    origin=$(cat "/tmp/hypr_fs/$active" 2>/dev/null)
    [ -z "$origin" ] && origin=$(hyprctl activeworkspace -j | jq -r '.id')
    hyprctl dispatch movetoworkspace "$origin,address:$active"
    rm -f "/tmp/hypr_fs/$active"
fi
