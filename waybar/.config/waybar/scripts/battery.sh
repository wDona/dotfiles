#!/usr/bin/env bash
# Estado de bateria (icono + porcentaje exacto) para waybar. Salida JSON.
# Clases CSS emitidas: charging | full | discharging | critical | none

BAT=/sys/class/power_supply/BAT0
AC=/sys/class/power_supply/AC0

cap=$(cat "$BAT/capacity" 2>/dev/null)
status=$(cat "$BAT/status" 2>/dev/null)
ac_online=$(cat "$AC/online" 2>/dev/null)

if [ -z "$cap" ]; then
    printf '{"text":"","class":"none","tooltip":"Sin bateria"}\n'
    exit 0
fi

profile=$(/usr/local/bin/powerprofile get 2>/dev/null)

case "$profile" in
    performance) prof_lbl="rendimiento" ;;
    balanced)    prof_lbl="equilibrado" ;;
    power-saver) prof_lbl="ahorro" ;;
    *)           prof_lbl="?" ;;
esac

class="discharging"
# AC0/online cambia al instante en ambas direcciones; BAT0/status puede ir
# unos segundos por detras (el EC tarda en confirmar Charging/Discharging).
# Por eso mandamos por online y solo miramos status para matizar "Full".
charging=false
if [ -n "$ac_online" ]; then
    [ "$ac_online" = "1" ] && charging=true
else
    [ "$status" = "Charging" ] && charging=true
fi

if [ "$charging" = true ]; then
    if [ "$status" = "Full" ] || [ "$cap" -ge 100 ]; then
        icon="󰁹"
        class="full"
    else
        icon="󰂄"
        class="charging"
    fi
else
    if   [ "$cap" -ge 95 ]; then icon="󰁹"
    elif [ "$cap" -ge 80 ]; then icon="󰂂"
    elif [ "$cap" -ge 60 ]; then icon="󰂀"
    elif [ "$cap" -ge 40 ]; then icon="󰁾"
    elif [ "$cap" -ge 20 ]; then icon="󰁻"; class="critical"
    elif [ "$cap" -ge 10 ]; then icon="󰁺"; class="critical"
    else
        icon="󰂎"
        class="critical"
    fi
fi

printf '{"text":"%s %s%%","class":"%s","tooltip":"Bateria: %s%% · %s · Perfil: %s"}\n' \
    "$icon" "$cap" "$class" "$cap" "$status" "$prof_lbl"
