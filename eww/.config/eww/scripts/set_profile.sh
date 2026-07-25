#!/usr/bin/env bash
# Cambia el perfil de energia (power-profiles-daemon) via D-Bus y refresca UI.
profile="$1"
case "$profile" in
    performance|balanced|power-saver) ;;
    *) echo "uso: $0 performance|balanced|power-saver" >&2; exit 1 ;;
esac

gdbus call --system --dest net.hadess.PowerProfiles \
    --object-path /net/hadess/PowerProfiles \
    --method org.freedesktop.DBus.Properties.Set net.hadess.PowerProfiles ActiveProfile \
    "<'${profile}'>" >/dev/null 2>&1

# Ahorro real extra que power-profiles-daemon no toca: wifi powersave y brillo.
wifi_conn=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2=="802-11-wireless"{print $1; exit}')
if [ -n "$wifi_conn" ]; then
    case "$profile" in
        power-saver) ps=3 ;;   # enable
        *)           ps=2 ;;   # disable (performance/balanced)
    esac
    nmcli connection modify "$wifi_conn" wifi.powersave "$ps" 2>/dev/null
    nmcli device reapply "$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')" >/dev/null 2>&1
fi
[ "$profile" = "power-saver" ] && command -v brightnessctl >/dev/null 2>&1 && brightnessctl set 40% -q

if pgrep -x eww >/dev/null; then
    eww update power_profile="$profile" 2>/dev/null
fi

pkill -RTMIN+11 waybar 2>/dev/null
