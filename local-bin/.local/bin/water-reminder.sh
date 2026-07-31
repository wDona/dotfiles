#!/usr/bin/env bash
set -euo pipefail

state_dir="$HOME/.local/state/water-reminder"
last_notify_file="$state_dir/last_notify"
last_boot_file="$state_dir/last_boot"
mkdir -p "$state_dir"

now=$(date +%s)

if [ "${1:-}" = "boot" ]; then
    prev_boot=$(cat "$last_boot_file" 2>/dev/null || echo 0)
    cur_boot=$(date -d "$(uptime -s)" +%s)
    if [ "$prev_boot" -eq 0 ] || [ $((now - prev_boot)) -ge 7200 ]; then
        echo "$now" > "$last_notify_file"
    fi
    echo "$cur_boot" > "$last_boot_file"
fi

last_notify=$(cat "$last_notify_file" 2>/dev/null || echo "$now")
elapsed=$((now - last_notify))

if [ "$elapsed" -ge 1800 ]; then
    notify-send -a "Agua" "💧 Bebe agua" "Recordatorio cada 30 min"
    echo "$now" > "$last_notify_file"
fi
