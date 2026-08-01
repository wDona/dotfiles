#!/bin/sh
# Ajusta la terminal de Claude (SUPER+C) al monitor en el que ESTA: 57% de
# ancho pegada a la derecha y todo el alto util.
#
# La windowrule solo se aplica al abrir (y con % se calcula sobre el monitor
# donde nace), asi que al pasarla a un monitor de otro tamaño hay que
# recalcular: si no, en uno mas pequeño (1360x768) se sale de pantalla.
#
# Lo llaman toggle_claude.sh (al abrir y al traerla del stash) y
# movewindow_mon.sh (CTRL+ALT+SHIFT+flecha). Sin ventana no hace nada.

CLASS=claude-term
GAP=6
WIDTH_PCT=57

clients=$(hyprctl clients -j)
addr=$(echo "$clients" | jq -r ".[] | select(.class==\"$CLASS\") | .address" | head -n1)
[ -n "$addr" ] && [ "$addr" != "null" ] || exit 0

# El monitor donde vive la ventana (no el que tiene el foco): tras un
# `movewindow mon:r` el foco puede haberse quedado atras.
mon=$(echo "$clients" | jq -r --arg a "$addr" \
    '.[] | select(.address==$a) | .monitor')

# reserved = [left, top, right, bottom] -> lo que ocupa waybar; se descuenta
# para no quedar debajo de la barra. width/height vienen en pixeles fisicos:
# con scale != 1 hay que pasarlos a logicos, que es lo que usan los dispatch.
set -- $(hyprctl monitors -j | jq -r \
    --argjson m "$mon" --argjson g "$GAP" --argjson p "$WIDTH_PCT" '
    .[] | select(.id == $m)
    | (.width / .scale | floor)  as $mw
    | (.height / .scale | floor) as $mh
    | .reserved as $r
    | ($mw - $r[0] - $r[2] - 2*$g) as $uw
    | ($mh - $r[1] - $r[3] - 2*$g) as $uh
    | (($uw * $p / 100) | floor)  as $w
    | (.x + $r[0] + $g + $uw - $w) as $wx
    | (.y + $r[1] + $g)            as $wy
    | "\($w) \($uh) \($wx) \($wy)"')
[ $# -eq 4 ] || exit 0

hyprctl dispatch resizewindowpixel "exact $1 $2,address:$addr"
hyprctl dispatch movewindowpixel "exact $3 $4,address:$addr"
