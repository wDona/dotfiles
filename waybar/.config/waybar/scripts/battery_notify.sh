#!/usr/bin/env bash
# Watcher de bateria: notifica al CRUZAR HACIA ABAJO 20/10/5/3% (aunque este
# cargando, si baja se avisa igual) y arma un apagado automatico de proteccion
# al llegar a 5%, que se cancela solo si la bateria vuelve a subir por encima.
#
# Variables de entorno (solo para pruebas, no usar en produccion):
#   BATTERY_NOTIFY_BAT    ruta alternativa a /sys/class/power_supply/BATx
#   BATTERY_NOTIFY_DRYRUN 1 = no ejecuta systemctl poweroff, solo lo anuncia
#   BATTERY_NOTIFY_DELAY  segundos de cuenta atras (por defecto 120)
#   BATTERY_NOTIFY_POLL_NORMAL / _POLL_ARMED  intervalos de sondeo

BAT="${BATTERY_NOTIFY_BAT:-/sys/class/power_supply/BAT0}"
DRYRUN="${BATTERY_NOTIFY_DRYRUN:-0}"
THRESHOLDS=(20 10 5 3)
SHUTDOWN_PCT=5
SHUTDOWN_DELAY="${BATTERY_NOTIFY_DELAY:-120}"
POLL_NORMAL="${BATTERY_NOTIFY_POLL_NORMAL:-20}"
POLL_ARMED="${BATTERY_NOTIFY_POLL_ARMED:-5}"

notify() {
    local urgency="$1" title="$2" body="$3"
    notify-send -u "$urgency" -a "Bateria" "$title" "$body"
}

last_cap=$(cat "$BAT/capacity" 2>/dev/null)
armed=false
deadline=0
warned60=false
warned10=false

while true; do
    cap=$(cat "$BAT/capacity" 2>/dev/null)
    status=$(cat "$BAT/status" 2>/dev/null)

    if [ -n "$cap" ] && [ -n "$last_cap" ]; then
        # Notificaciones de umbral: solo al bajar (aunque este cargando)
        for t in "${THRESHOLDS[@]}"; do
            if [ "$last_cap" -gt "$t" ] && [ "$cap" -le "$t" ]; then
                if [ "$t" -le 10 ]; then
                    notify critical "Bateria baja: ${t}%" "Quedan ${cap}% de bateria."
                else
                    notify normal "Bateria: ${t}%" "Quedan ${cap}% de bateria."
                fi
            fi
        done

        # Armar cuenta atras de apagado al cruzar el umbral critico
        if [ "$last_cap" -gt "$SHUTDOWN_PCT" ] && [ "$cap" -le "$SHUTDOWN_PCT" ] && [ "$armed" = false ]; then
            armed=true
            warned60=false
            warned10=false
            deadline=$(( $(date +%s) + SHUTDOWN_DELAY ))
            notify critical "Bateria critica" "Apagado automatico en $((SHUTDOWN_DELAY / 60)) min si no conectas el cargador."
        fi
    fi

    if [ "$armed" = true ]; then
        if [ -n "$cap" ] && [ "$cap" -gt "$SHUTDOWN_PCT" ]; then
            armed=false
            notify normal "Bateria recuperada" "Apagado automatico cancelado."
        else
            remaining=$(( deadline - $(date +%s) ))
            if [ "$remaining" -le 0 ]; then
                notify critical "Apagando" "Bateria critica, apagando el equipo para protegerla."
                sleep 2
                if [ "$DRYRUN" = "1" ]; then
                    echo "[DRYRUN] systemctl poweroff"
                else
                    systemctl poweroff
                fi
                exit 0
            elif [ "$remaining" -le 10 ] && [ "$warned10" = false ]; then
                warned10=true
                notify critical "Apagando en 10s" "Conecta el cargador para cancelar."
            elif [ "$remaining" -le 60 ] && [ "$warned60" = false ]; then
                warned60=true
                notify critical "Apagando en 1 min" "Conecta el cargador para cancelar."
            fi
        fi
    fi

    last_cap="$cap"
    if [ "$armed" = true ]; then
        sleep "$POLL_ARMED"
    else
        sleep "$POLL_NORMAL"
    fi
done
