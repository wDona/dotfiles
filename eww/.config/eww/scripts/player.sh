#!/usr/bin/env bash
# Estado del reproductor mpris para el dashboard eww.
P="playerctl"
status=$($P status 2>/dev/null)
if [ -z "$status" ]; then
    printf '{"playing":false,"status":"none","title":"Nada sonando","artist":"","icon":"󰝚"}\n'
    exit 0
fi
title=$($P metadata title 2>/dev/null | head -c 40)
artist=$($P metadata artist 2>/dev/null | head -c 40)
[ "$status" = "Playing" ] && playing=true || playing=false
[ "$status" = "Playing" ] && icon="󰏤" || icon="󰐊"
esc() { python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1"; }
printf '{"playing":%s,"status":"%s","title":%s,"artist":%s,"icon":"%s"}\n' \
    "$playing" "$status" "$(esc "$title")" "$(esc "$artist")" "$icon"
