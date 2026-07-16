#!/usr/bin/env bash
# Borra UN evento concreto del dia en Google (por su titulo) y refresca.
# Uso: note_del.sh <offset> <YYYY-MM-DD> <titulo...>
source "$HOME/.config/eww/scripts/env.sh"   # PATH con ~/.local/bin para gcalcli (pipx)
off="$1"
date="$2"
shift 2 2>/dev/null
title="$*"
[ -z "$title" ] && exit 0

next=$(date -d "$date +1 day" +%Y-%m-%d)
OWNER=$(cat "$HOME/.cache/eww_gcal_owner" 2>/dev/null)
CAL=(); [ -n "$OWNER" ] && CAL=(--calendar "$OWNER")

if command -v gcalcli >/dev/null 2>&1; then
    yes | gcalcli --nocolor "${CAL[@]}" delete "$title" "$date" "$next" >/dev/null 2>&1
fi

bash "$HOME/.config/eww/scripts/cal_sync.sh" "$off"
bash "$HOME/.config/eww/scripts/select.sh" "$date"
