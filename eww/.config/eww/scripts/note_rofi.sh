#!/usr/bin/env bash
# Edita la nota de un dia usando rofi (sin grab de teclado de eww).
# Uso: note_rofi.sh <offset> <YYYY-MM-DD>
off="$1"
date="$2"
cur="$("$HOME/.config/eww/scripts/getevent.sh" "$date")"

# rofi en modo dmenu sin entradas: Enter devuelve el texto escrito (custom).
# -filter precarga la nota actual para poder editarla.
txt=$(printf '' | rofi -dmenu -p "Nota" -mesg "$date" -filter "$cur")
rc=$?
[ $rc -ne 0 ] && exit 0   # ESC: no tocar nada

# Guarda (texto vacio => borra) y refresca grid + buffer de la nota
bash "$HOME/.config/eww/scripts/addevent.sh" "$off" "$date" "$txt"
bash "$HOME/.config/eww/scripts/select.sh" "$date"
