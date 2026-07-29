#!/usr/bin/env bash
# ─── Workspaces dinamicos ────────────────────────────────────────────────
# El 1-6 esta fijado a un monitor concreto en monitors.conf. Del 7 en adelante
# no hay regla, asi que Hyprland los crea en el monitor con foco: este script
# busca el primer hueco libre a partir del 7 y salta / manda la ventana ahi.
#
# Empezar en 7 y no en `dispatch workspace empty` es deliberado: `empty` coge
# el hueco mas bajo, y si tienes el 4 vacio te teletransportaria al monitor
# principal en vez de crear uno nuevo donde estas mirando.
set -euo pipefail

FIRST_DYNAMIC=7

# Primer hueco libre a partir del 7.
next_free() {
    local used ws
    used=$(hyprctl workspaces -j | jq -r '.[].id')
    ws=$FIRST_DYNAMIC
    while grep -qx -- "$ws" <<<"$used"; do
        ws=$((ws + 1))
    done
    echo "$ws"
}

# Vecino en el ciclo de workspaces del monitor con foco, con vuelta al
# principio. Va aqui y no con el dispatcher m+1/m-1 de Hyprland porque ese
# salta de monitor en cuanto hay workspaces dinamicos sin asignar (probado
# en 0.56). Devuelve vacio si la pantalla solo tiene un workspace.
neighbour() {
    local dir=$1 mon cur list
    mon=$(hyprctl activeworkspace -j | jq -r '.monitor')
    cur=$(hyprctl activeworkspace -j | jq -r '.id')
    # Solo workspaces normales (los special tienen id negativo) de esa pantalla.
    list=$(hyprctl workspaces -j \
        | jq -r --arg m "$mon" '[.[] | select(.monitor == $m and .id > 0)] | sort_by(.id) | .[].id')

    [ -z "$list" ] && return 0
    mapfile -t ids <<<"$list"
    local n=${#ids[@]} i
    [ "$n" -lt 2 ] && return 0
    for i in "${!ids[@]}"; do
        [ "${ids[$i]}" = "$cur" ] && break
    done
    if [ "$dir" = next ]; then
        i=$(( (i + 1) % n ))
    else
        i=$(( (i - 1 + n) % n ))
    fi
    echo "${ids[$i]}"
}

# Aplica un dispatcher sobre el workspace vecino, si lo hay.
to_neighbour() {
    local dispatcher=$1 dir=$2 ws
    ws=$(neighbour "$dir")
    [ -n "$ws" ] && hyprctl dispatch "$dispatcher" "$ws"
}

case "${1:-go}" in
    go)   hyprctl dispatch workspace "$(next_free)" ;;              # ir al nuevo
    move) hyprctl dispatch movetoworkspace "$(next_free)" ;;        # llevar ventana y seguirla
    send) hyprctl dispatch movetoworkspacesilent "$(next_free)" ;;  # llevar ventana y quedarte

    next) to_neighbour workspace next ;;                            # siguiente de esta pantalla
    prev) to_neighbour workspace prev ;;                            # anterior de esta pantalla

    # Mover la ventana activa a un workspace YA EXISTENTE de esta pantalla,
    # recorriendo el mismo ciclo. Es la forma de meter una segunda app en un
    # workspace dinamico: `go` solo busca huecos libres y nunca cae en uno ocupado.
    movenext) to_neighbour movetoworkspace next ;;                  # y seguirla
    moveprev) to_neighbour movetoworkspace prev ;;
    sendnext) to_neighbour movetoworkspacesilent next ;;            # y quedarte
    sendprev) to_neighbour movetoworkspacesilent prev ;;

    *) echo "uso: ${0##*/} [go|move|send|next|prev|movenext|moveprev|sendnext|sendprev]" >&2; exit 1 ;;
esac
