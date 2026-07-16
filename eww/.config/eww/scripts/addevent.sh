#!/usr/bin/env bash
# Crea un evento all-day en Google Calendar (push, two-way con cal_sync.sh).
# ADITIVO: solo AÑADE. Nunca borra ni pisa otros eventos del dia (seguro en
# dias con cumpleaños/citas). Texto vacio = no hace nada.
# Editar/borrar un evento concreto = pendiente (UI selector de eventos).
# Uso: addevent.sh <offset> <YYYY-MM-DD> [texto...]
source "$HOME/.config/eww/scripts/env.sh"   # PATH con ~/.local/bin para gcalcli (pipx)
off="$1"
date="$2"
shift 2 2>/dev/null
text="$*"

OWNER=$(cat "$HOME/.cache/eww_gcal_owner" 2>/dev/null)
CAL=(); [ -n "$OWNER" ] && CAL=(--calendar "$OWNER")

if [ -n "$text" ] && command -v gcalcli >/dev/null 2>&1; then
    gcalcli --nocolor "${CAL[@]}" add --title "$text" --when "$date" --allday --duration 1 --noprompt >/dev/null 2>&1
fi

# Re-pull desde Google -> actualiza cache (events.json) + refresca el grid.
exec bash "$HOME/.config/eww/scripts/cal_sync.sh" "$off"
