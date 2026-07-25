#!/usr/bin/env bash
# Boton "Hoy": vuelve al mes actual y selecciona el dia de hoy.
echo "$(date +%T) today.sh START, cal_selected antes=$(eww get cal_selected)" >> /tmp/goto_debug.log
~/.config/eww/scripts/nav.sh 0
~/.config/eww/scripts/select.sh "$(date +%Y-%m-%d)"
eww update cal_picker="none" event_input=""
echo "$(date +%T) today.sh END, cal_selected despues=$(eww get cal_selected)" >> /tmp/goto_debug.log
