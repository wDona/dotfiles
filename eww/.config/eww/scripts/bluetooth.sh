#!/usr/bin/env bash
# Backend bluetooth pa eww: list/refresh/connect/disconnect/power
set -euo pipefail

json_list() {
    local powered="false"
    bluetoothctl show | grep -q "Powered: yes" && powered="true"

    local connected="[]" available="[]"
    if [ "$powered" = "true" ]; then
        while read -r _ mac name; do
            [ -z "${mac:-}" ] && continue
            local info is_conn entry
            info=$(bluetoothctl info "$mac" 2>/dev/null)
            is_conn="false"
            echo "$info" | grep -q "Connected: yes" && is_conn="true"
            entry=$(jq -n --arg mac "$mac" --arg name "$name" '{mac:$mac,name:$name}')
            if [ "$is_conn" = "true" ]; then
                connected=$(echo "$connected" | jq --argjson e "$entry" '. + [$e]')
            else
                available=$(echo "$available" | jq --argjson e "$entry" '. + [$e]')
            fi
        done < <(bluetoothctl devices)
    fi

    jq -n --argjson powered "$powered" --argjson connected "$connected" --argjson available "$available" \
        '{powered:$powered, connected:$connected, available:$available}'
}

update_eww() { eww update bt_state="$(json_list)"; }

case "${1:-list}" in
    list) json_list ;;
    refresh)
        bluetoothctl --timeout 4 scan on >/dev/null 2>&1 || true
        update_eww
        ;;
    connect)
        bluetoothctl trust "$2" >/dev/null 2>&1 || true
        bluetoothctl connect "$2" >/dev/null 2>&1 || true
        update_eww
        ;;
    disconnect)
        bluetoothctl disconnect "$2" >/dev/null 2>&1 || true
        update_eww
        ;;
    power)
        bluetoothctl power "$2" >/dev/null 2>&1 || true
        update_eww
        ;;
    *)
        echo "usage: bluetooth.sh {list|refresh|connect <mac>|disconnect <mac>|power on|off}" >&2
        exit 1
        ;;
esac
