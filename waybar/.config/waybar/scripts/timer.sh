#!/bin/bash
# Temporizador para waybar (tiempo libre). Menu lo pone el widget eww
# (timermenu); este script solo aplica cambios de estado, el widget decide
# cuando confirmar reemplazo mirando timerinfo.class el mismo.
#   timer.sh apply <texto>       -> arranca timer/cronometro, valida formato
#   timer.sh presets             -> JSON con los presets (para el widget)
#   timer.sh addpreset <texto>   -> anade preset (valida formato)
#   timer.sh delpreset <texto>   -> borra preset
#   timer.sh forcecancel         -> cancela sin confirmar (ya confirma el widget)
#   timer.sh cancel              -> click derecho en la barra: pausa/reanuda
#                                    cronometro, o cancela timer con confirmacion rofi
#   timer.sh status | bar        -> JSON para waybar
# Formatos aceptados en el prompt:
#   90s | 5m | 1h | 1h30m | 2m30s | 1m45s   (unidades h/m/s)
#   MM:SS o HH:MM:SS        (ej 2:30 = 2min30s, 1:00:00 = 1h)
#   numero suelto           (ej 5 = 5 minutos)
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"; mkdir -p "$STATE_DIR"
S="$STATE_DIR/waybar_timer"            # epoch objetivo (persiste tras reinicio)
FIRED="$STATE_DIR/waybar_timer.fired"  # marca atomica: notificacion ya disparada
SW="$STATE_DIR/waybar_stopwatch"       # epoch de inicio del cronometro (cuenta arriba)
SWP="$STATE_DIR/waybar_stopwatch.paused" # segundos acumulados: cronometro en pausa
PRESETS="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/timer_presets"
[ -f "$PRESETS" ] || printf '30s\n5m\n10m\n1h\n1h30m\n' > "$PRESETS"
ICON="󰚭"
# Punto de estado pegado al icono (mismo truco pango que notif.sh y weather.sh):
# el modulo NO se tiñe entero, solo el punto, para que la barra siga monocroma.
# El hueco lo hace un espacio a 9pt (~3px). Con letter_spacing negativo el
# punto se montaba encima del icono al cambiar la metrica de la fuente.
DOT="<span foreground='#ffd700' size='9000' rise='5000'> •</span>"

parse_secs() {
    local in="${1//[[:space:]]/}"
    [ -z "$in" ] && { echo 0; return; }
    # HH:MM:SS o MM:SS
    if [[ "$in" =~ ^[0-9]+(:[0-9]+){1,2}$ ]]; then
        local total=0 part
        IFS=':' read -ra P_ <<< "$in"
        for part in "${P_[@]}"; do total=$((total*60 + 10#$part)); done
        echo "$total"; return
    fi
    # numero suelto = minutos
    if [[ "$in" =~ ^[0-9]+$ ]]; then echo $((10#$in*60)); return; fi
    # unidades h/m/s (en cualquier combinacion)
    if [[ "$in" =~ ^([0-9]+h)?([0-9]+m)?([0-9]+s)?$ ]]; then
        local h m s
        h=$(grep -oE '[0-9]+h' <<<"$in" | tr -d h)
        m=$(grep -oE '[0-9]+m' <<<"$in" | tr -d m)
        s=$(grep -oE '[0-9]+s' <<<"$in" | tr -d s)
        echo $(( 10#${h:-0}*3600 + 10#${m:-0}*60 + 10#${s:-0} )); return
    fi
    echo 0
}

fmt() {
    local r=$1
    if [ "$r" -ge 3600 ]; then printf '%d:%02d:%02d' $((r/3600)) $(((r%3600)/60)) $((r%60))
    else printf '%d:%02d' $((r/60)) $((r%60)); fi
}

# Lista los presets ordenados por duracion ascendente (los @hora van al final).
sort_presets() {
    local line k
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        if [[ "$line" == @* ]]; then k=$(date -d "${line#@}" +%s 2>/dev/null); k=${k:-9999999999}
        else k=$(parse_secs "$line"); fi
        printf '%s\t%s\n' "$k" "$line"
    done < "$PRESETS" | sort -n | cut -f2-
}

# Imprime el estado actual como JSON. Dispara la notificacion UNA sola vez
# al cumplirse (lock atomico via mkdir) -> sobrevive a reinicios: el poll de
# waybar la lanza en cuanto detecta que la hora objetivo ya paso.
emit() {
    local now; now=$(date +%s)
    # cronometro: cuenta arriba, no termina solo
    if [ -f "$SW" ]; then
        local t; t=$(fmt $((now - $(cat "$SW"))))
        printf '{"text":"%s %s","plain":"%s %s","tooltip":"Cronometro · click der = pausar","class":"running"}\n' \
            "$ICON" "$t" "$ICON" "$t"
        return
    fi
    # cronometro en pausa: tiempo congelado + punto amarillo (el punto es markup pango, solo para waybar)
    if [ -f "$SWP" ]; then
        local t; t=$(fmt "$(cat "$SWP")")
        printf '{"text":"%s%s %s","plain":"%s %s","tooltip":"Cronometro en pausa · click der = reanudar","class":"paused"}\n' \
            "$ICON" "$DOT" "$t" "$ICON" "$t"
        return
    fi
    # temporizador: cuenta atras
    if [ -f "$S" ]; then
        local end rem; end=$(cat "$S"); rem=$((end-now))
        if [ "$rem" -gt 0 ]; then
            local t; t=$(fmt "$rem")
            printf '{"text":"%s %s","plain":"%s %s","tooltip":"Suena a las %s · click der = cancelar","class":"running"}\n' \
                "$ICON" "$t" "$ICON" "$t" "$(date -d "@$end" '+%H:%M')"
            return
        fi
        # cumplido: notificar 1 sola vez (lock atomico) y mostrar 1min en rojo
        # contando en negativo antes de volver al icono normal
        local over=$((-rem))
        if [ "$over" -lt 60 ]; then
            if mkdir "$FIRED" 2>/dev/null; then
                notify-send -a "Temporizador" "Temporizador" "Tiempo cumplido"
            fi
            local t; t=$(fmt "$over")
            printf '{"text":"%s -%s","plain":"%s -%s","tooltip":"Tiempo cumplido","class":"done"}\n' \
                "$ICON" "$t" "$ICON" "$t"
            return
        fi
        rm -rf "$S" "$FIRED"
    fi
    printf '{"text":"%s","plain":"%s","tooltip":"Click = poner temporizador","class":"idle"}\n' "$ICON" "$ICON"
}

# Pregunta Si/No por rofi. Devuelve 0 solo si el usuario elige "Si".
confirm() { [ "$(printf 'No\nSi' | rofi -dmenu -kb-cancel 'Escape,MousePrimary' -p "$1")" = "Si" ]; }

case "$1" in
    presets)
        sort_presets | jq -R . | jq -s .
        ;;
    addpreset)
        nuevo="${2//[[:space:]]/}"; [ -z "$nuevo" ] && exit 0
        if [[ "$nuevo" == @* ]]; then
            date -d "${nuevo#@}" +%s >/dev/null 2>&1 || { notify-send "Temporizador" "Hora no valida: $nuevo"; exit 1; }
        else
            s=$(parse_secs "$nuevo"); { [ -z "$s" ] || [ "$s" -le 0 ]; } && { notify-send "Temporizador" "Formato no valido: $nuevo"; exit 1; }
        fi
        grep -qxF "$nuevo" "$PRESETS" || echo "$nuevo" >> "$PRESETS"
        ;;
    delpreset)
        del="$2"; [ -z "$del" ] && exit 0
        # escribir A TRAVES del symlink (no mv, que lo reemplazaria por fichero real)
        resto=$(grep -vxF "$del" "$PRESETS"); printf '%s\n' "$resto" > "$PRESETS"
        ;;
    apply)
        inp="${2//[[:space:]]/}"
        [ -z "$inp" ] && exit 0
        rm -rf "$S" "$FIRED" "$SW" "$SWP"   # limpia estado previo (el widget ya confirmo el reemplazo)
        if [[ "${inp,,}" == cronometro || "${inp,,}" == crono ]]; then
            date +%s > "$SW"; pkill -RTMIN+10 waybar; exit 0
        fi
        now=$(date +%s)
        if [[ "$inp" == @* ]]; then
            # hora concreta del dia; si ya paso -> manana
            clk="${inp#@}"
            end=$(date -d "$clk" +%s 2>/dev/null)
            [ -z "$end" ] && { notify-send "Temporizador" "Hora no valida: $inp"; exit 1; }
            [ "$end" -le "$now" ] && end=$(date -d "tomorrow $clk" +%s)
        else
            secs=$(parse_secs "$inp")
            { [ -z "$secs" ] || [ "$secs" -le 0 ]; } && { notify-send "Temporizador" "Formato no valido: $inp"; exit 1; }
            end=$((now+secs))
        fi
        echo "$end" > "$S"
        pkill -RTMIN+10 waybar
        ;;
    forcecancel)
        rm -rf "$S" "$FIRED" "$SW" "$SWP"
        pkill -RTMIN+10 waybar
        ;;
    cancel)
        # cronometro activo: click der pausa/reanuda (no cancela)
        if [ -f "$SW" ]; then
            echo $(( $(date +%s) - $(cat "$SW") )) > "$SWP"; rm -f "$SW"
            pkill -RTMIN+10 waybar; exit 0
        fi
        if [ -f "$SWP" ]; then
            echo $(( $(date +%s) - $(cat "$SWP") )) > "$SW"; rm -f "$SWP"
            pkill -RTMIN+10 waybar; exit 0
        fi
        # temporizador: cancelacion siempre explicita
        [ -f "$S" ] || exit 0
        confirm "Cancelar?" || exit 0
        rm -rf "$S" "$FIRED"
        pkill -RTMIN+10 waybar
        ;;
    status|bar)
        emit
        ;;
esac
