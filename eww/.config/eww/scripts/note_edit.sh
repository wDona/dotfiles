#!/usr/bin/env bash
# Añade un evento (multilinea) a un dia con zenity (additivo: NO pisa otros).
# Cierra el calendario mientras se edita y lo reabre (con el dia
# seleccionado) al Guardar o Cancelar.
# Uso: note_edit.sh <offset> <YYYY-MM-DD>
off="$1"
date="$2"

# Un solo editor por dia
exec 9>"/tmp/eww-note-${date}.lock"
flock -n 9 || exit 0

# Additivo: el dialogo arranca VACIO (crea un evento nuevo, no edita los otros)
cur=""

# Cerrar el calendario y soltar el submap mientras se edita
eww close calendario 2>/dev/null
hyprctl dispatch submap reset >/dev/null 2>&1

txt=$(printf '%s' "$cur" | python3 "$HOME/.config/eww/scripts/note_dialog.py" "$date")
rc=$?

# Guardar si se acepto (vacio => borra). Si no, solo refrescar el mes.
if [ "$rc" -eq 0 ]; then
    bash "$HOME/.config/eww/scripts/addevent.sh" "$off" "$date" "$txt"
else
    bash "$HOME/.config/eww/scripts/nav.sh" "$off"
fi

# Dejar el dia marcado y cargar su nota
bash "$HOME/.config/eww/scripts/select.sh" "$date"

# Reabrir el calendario en el monitor con foco + submap ESC
mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .id')
[ -z "$mon" ] && mon=0
eww open calendario --screen "$mon"
hyprctl dispatch submap calendar >/dev/null 2>&1
