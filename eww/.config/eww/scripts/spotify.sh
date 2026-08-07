#!/usr/bin/env bash
# =============================================================================
# spotify.sh - estado y control de Spotify para el popup de eww.
#
#   spotify.sh state            -> JSON que pinta el widget
#   spotify.sh refresh          -> empuja ese JSON a eww (spotify_json)
#   spotify.sh action <accion>  -> play-pause | next | previous | shuffle | loop
#   spotify.sh vol <0-100>      -> volumen SOLO de Spotify
#
# NO hay ningun proceso de fondo, a proposito. El estado se refresca al abrir el
# popup y despues de cada accion, igual que hace el widget de clima. Un
# `playerctl -F` en deflisten costaria un proceso vivo 24/7 para un panel que se
# mira tres segundos, y un defpoll costaria un fork por intervalo para siempre.
#
# Los clicks de waybar sobre el modulo mpris siguen funcionando por su cuenta
# (izq=play/pause, der=siguiente, medio=anterior). Los botones de aqui son
# deliberadamente redundantes: si un click de la barra deja de responder, el
# popup sigue dando acceso a todo.
# =============================================================================
set -u

P=(playerctl -p spotify)

# --- volumen -----------------------------------------------------------------
# MPRIS expone `Volume`, pero el cliente de Spotify para Linux lo ignora: hay
# que ir al sink-input de PipeWire. Y tiene que ser el del stream, NO el sink
# por defecto (@DEFAULT_AUDIO_SINK@), o esto le baja el volumen a todo el
# sistema en vez de solo a la musica.
sink_input() {
    pactl -f json list sink-inputs 2>/dev/null | jq -r '
        [ .[]
          | select(
              ( (.properties["application.name"] // "") + " "
              + (.properties["application.process.binary"] // "") )
              | ascii_downcase | test("spotify")
            )
          | .index
        ] | first // empty'
}

vol_get() {
    local id
    id=$(sink_input) || return
    [ -n "$id" ] || { echo 0; return; }
    pactl -f json list sink-inputs 2>/dev/null | jq -r --argjson i "$id" '
        [ .[] | select(.index == $i) | .volume | to_entries[0].value.value_percent ]
        | first // "0%"' | tr -d '%'
}

vol_set() {
    local id
    id=$(sink_input)
    [ -n "$id" ] || return 0
    pactl set-sink-input-volume "$id" "${1:-0}%"
}

# --- estado ------------------------------------------------------------------
state() {
    local raw status title artist shuffle loop vol

    # Un solo fork para status+title+artist. shuffle y loop van aparte porque no
    # todas las versiones de playerctl los aceptan dentro de --format.
    raw=$("${P[@]}" metadata --format '{{status}}	{{title}}	{{artist}}' 2>/dev/null) || raw=""

    if [ -z "$raw" ]; then
        printf '{"open":false,"playing":false,"title":"Spotify cerrado","artist":"","shuffle":false,"loop":"None","vol":0}\n'
        return
    fi

    IFS=$'\t' read -r status title artist <<< "$raw"
    shuffle=$("${P[@]}" shuffle 2>/dev/null) || shuffle="Off"
    loop=$("${P[@]}" loop 2>/dev/null) || loop="None"
    vol=$(vol_get)

    # jq construye el JSON: escapa comillas, barras y acentos raros de los
    # titulos sin que haya que pelearse con printf.
    jq -nc \
        --arg t "$title" \
        --arg a "$artist" \
        --arg l "${loop:-None}" \
        --argjson p "$([ "$status" = "Playing" ] && echo true || echo false)" \
        --argjson s "$([ "${shuffle:-Off}" = "On" ] && echo true || echo false)" \
        --argjson v "${vol:-0}" \
        '{open:true, playing:$p, title:$t, artist:$a, shuffle:$s, loop:$l, vol:$v}'
}

refresh() { eww update spotify_json="$(state)" 2>/dev/null; }

# --- acciones ----------------------------------------------------------------
do_action() {
    case "$1" in
        play-pause|next|previous) "${P[@]}" "$1" ;;
        shuffle)
            [ "$("${P[@]}" shuffle 2>/dev/null)" = "On" ] \
                && "${P[@]}" shuffle Off \
                || "${P[@]}" shuffle On
            ;;
        loop)
            # Ciclo None -> Playlist -> Track -> None, que es el orden al que
            # esta acostumbrado cualquiera que use Spotify.
            case "$("${P[@]}" loop 2>/dev/null)" in
                None)     "${P[@]}" loop Playlist ;;
                Playlist) "${P[@]}" loop Track ;;
                *)        "${P[@]}" loop None ;;
            esac
            ;;
        *) echo "accion desconocida: $1" >&2; return 1 ;;
    esac

    # MPRIS tarda un pelin en publicar el estado nuevo: sin esta pausa el popup
    # se repinta con el titulo de la cancion anterior o con el modo de
    # repeticion viejo. Y se refresca DOS veces porque el retardo no es fijo:
    # play/pause y skip llegan en ~300ms, pero shuffle y loop tardan a veces
    # medio segundo largo en publicarse y con un solo refresco el boton se
    # quedaba con el estado anterior hasta que tocabas otra cosa. El segundo
    # pase es una red de seguridad barata (un fork mas, solo al pulsar).
    sleep 0.3
    refresh
    ( sleep 0.7; refresh ) &
}

case "${1:-state}" in
    state)   state ;;
    refresh) refresh ;;
    action)  do_action "${2:?falta la accion}" ;;
    vol)     vol_set "${2:?falta el porcentaje}" ;;
    *)       echo "uso: spotify.sh {state|refresh|action <a>|vol <0-100>}" >&2; exit 1 ;;
esac
