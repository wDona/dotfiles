#!/bin/bash
# Temporizador para waybar (tiempo libre).
#   timer.sh set     -> rofi pide tiempo, cuenta atras + notifica al acabar
#   timer.sh cancel  -> cancela
#   timer.sh status  -> JSON para waybar
# Formatos aceptados en el prompt:
#   90s | 5m | 1h | 1h30m | 2m30s | 1m45s   (unidades h/m/s)
#   MM:SS o HH:MM:SS        (ej 2:30 = 2min30s, 1:00:00 = 1h)
#   numero suelto           (ej 5 = 5 minutos)
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"; mkdir -p "$STATE_DIR"
S="$STATE_DIR/waybar_timer"            # epoch objetivo (persiste tras reinicio)
FIRED="$STATE_DIR/waybar_timer.fired"  # marca atomica: notificacion ya disparada
SW="$STATE_DIR/waybar_stopwatch"       # epoch de inicio del cronometro (cuenta arriba)
ICON="󰔙"

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
        printf '{"text":"%s %s","tooltip":"Cronometro · click der = parar","class":"running"}\n' \
            "$ICON" "$(fmt $((now - $(cat "$SW"))))"
        return
    fi
    # temporizador: cuenta atras
    if [ -f "$S" ]; then
        local end rem; end=$(cat "$S"); rem=$((end-now))
        if [ "$rem" -gt 0 ]; then
            printf '{"text":"%s %s","tooltip":"Suena a las %s · click der = cancelar","class":"running"}\n' \
                "$ICON" "$(fmt "$rem")" "$(date -d "@$end" '+%H:%M')"
            return
        fi
        # cumplido: notificar 1 sola vez (lock atomico) y volver al icono normal
        if mkdir "$FIRED" 2>/dev/null; then
            notify-send -u critical -a "Temporizador" "Temporizador" "Tiempo cumplido"
            rm -rf "$S" "$FIRED"
        fi
    fi
    printf '{"text":"","tooltip":"","class":"idle"}\n'
}

# Pregunta Si/No por rofi. Devuelve 0 solo si el usuario elige "Si".
confirm() { [ "$(printf 'No\nSi' | rofi -dmenu -kb-cancel 'Escape,MousePrimary' -p "$1")" = "Si" ]; }

case "$1" in
    set)
        # no pisar algo activo (timer o cronometro) sin confirmacion explicita
        if [ -f "$S" ] || [ -f "$SW" ]; then
            case "$(printf 'Cancelar actual\nCancelar y reemplazar\nVolver' | rofi -dmenu -kb-cancel 'Escape,MousePrimary' -p "Ya hay algo activo")" in
                "Cancelar y reemplazar") rm -rf "$S" "$FIRED" "$SW"; pkill -RTMIN+10 waybar ;;  # cancela ya y sigue al menu de tiempo
                "Cancelar actual") rm -rf "$S" "$FIRED" "$SW"; pkill -RTMIN+10 waybar; exit 0 ;;
                *) exit 0 ;;                                                         # Volver / vacio: no tocar
            esac
        fi
        # presets editables por el usuario (1 por linea)
        PRESETS="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/timer_presets"
        [ -f "$PRESETS" ] || printf '30s\n5m\n10m\n1h\n1h30m\n' > "$PRESETS"
        menu=$( { echo "Cronometro"; sort_presets; echo "[+] Nuevo preset"; echo "[-] Borrar preset"; } )
        inp=$(printf '%s\n' "$menu" | rofi -dmenu -kb-cancel 'Escape,MousePrimary' -p "Temporizador (o escribe: 5m, 2:30, @18:30)")
        [ -z "$inp" ] && exit 0
        case "$inp" in
            "[+] Nuevo preset")
                nuevo=$(rofi -dmenu -kb-cancel 'Escape,MousePrimary' -p "Nuevo preset (5m, 1h30m, 2:30, @18:30)")
                nuevo="${nuevo//[[:space:]]/}"; [ -z "$nuevo" ] && exit 0
                if [[ "$nuevo" == @* ]]; then
                    date -d "${nuevo#@}" +%s >/dev/null 2>&1 || { notify-send "Temporizador" "Hora no valida: $nuevo"; exit 0; }
                else
                    s=$(parse_secs "$nuevo"); { [ -z "$s" ] || [ "$s" -le 0 ]; } && { notify-send "Temporizador" "Formato no valido: $nuevo"; exit 0; }
                fi
                grep -qxF "$nuevo" "$PRESETS" || echo "$nuevo" >> "$PRESETS"
                notify-send "Temporizador" "Preset anadido: $nuevo"; exit 0 ;;
            "[-] Borrar preset")
                del=$(sort_presets | rofi -dmenu -kb-cancel 'Escape,MousePrimary' -p "Borrar que preset?")
                [ -z "$del" ] && exit 0
                # escribir A TRAVES del symlink (no mv, que lo reemplazaria por fichero real)
                resto=$(grep -vxF "$del" "$PRESETS"); printf '%s\n' "$resto" > "$PRESETS"
                notify-send "Temporizador" "Preset borrado: $del"; exit 0 ;;
        esac
        inp="${inp//[[:space:]]/}"
        [ -z "$inp" ] && exit 0
        rm -rf "$S" "$FIRED" "$SW"   # limpia estado previo
        if [[ "${inp,,}" == cronometro || "${inp,,}" == crono ]]; then
            date +%s > "$SW"; pkill -RTMIN+10 waybar; exit 0
        fi
        now=$(date +%s)
        if [[ "$inp" == @* ]]; then
            # hora concreta del dia; si ya paso -> manana
            clk="${inp#@}"
            end=$(date -d "$clk" +%s 2>/dev/null)
            [ -z "$end" ] && { notify-send "Temporizador" "Hora no valida: $inp"; exit 0; }
            [ "$end" -le "$now" ] && end=$(date -d "tomorrow $clk" +%s)
        else
            secs=$(parse_secs "$inp")
            { [ -z "$secs" ] || [ "$secs" -le 0 ]; } && { notify-send "Temporizador" "Formato no valido: $inp"; exit 0; }
            end=$((now+secs))
        fi
        echo "$end" > "$S"
        pkill -RTMIN+10 waybar
        ;;
    cancel)
        { [ -f "$S" ] || [ -f "$SW" ]; } || exit 0
        confirm "Cancelar?" || exit 0   # cancelacion siempre explicita
        rm -rf "$S" "$FIRED" "$SW"
        pkill -RTMIN+10 waybar
        ;;
    status|bar)
        emit
        ;;
esac
