#!/bin/sh
# CTRL+ALT+SHIFT+flecha: mover la ventana activa al monitor de al lado.
# Igual que `movewindow mon:$1`, salvo que si es la terminal de Claude se
# reajusta al tamaño del monitor destino (flotante: el dispatch la mueve
# conservando su tamaño, y en un monitor mas pequeño se saldria).
#   movewindow_mon.sh r|l|u|d

[ -n "$1" ] || exit 1

active=$(hyprctl activewindow -j | jq -r '.class')
hyprctl dispatch movewindow "mon:$1"

[ "$active" = "claude-term" ] && exec "$(dirname "$0")/fit_claude.sh"
exit 0
