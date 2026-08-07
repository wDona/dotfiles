#!/usr/bin/env bash
# =============================================================================
# spotify.sh - estado y control de Spotify para el popup de eww.
#
#   spotify.sh state            -> JSON que pinta el widget
#   spotify.sh refresh          -> empuja ese JSON a eww (spotify_json)
#   spotify.sh action <accion>  -> play-pause | next | previous | shuffle | loop
#   spotify.sh vol <0-100>      -> volumen SOLO de Spotify
#   spotify.sh vol-guard        -> bucle: repone el volumen si algo lo sube al tope
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
    vol_remember "$id" "${1:-0}"
}

# --- volumen entre canciones -------------------------------------------------
# Al cambiar de cancion algo escribe 99% o 100% en el sink-input de Spotify y se
# lleva por delante el volumen que hubieras puesto. MEDIDO: el indice del
# sink-input NO cambia (283 durante toda una sesion), o sea que el stream es el
# mismo y no hay nada que "restaurar al recrearse"; hay un escritor externo
# pisando el valor. Por eso esto NO se cuelga del cambio de cancion, sino de los
# eventos de volumen: da igual quien escriba y cuando.
#
# El valor recordado se guarda como INDICE + volumen (el indice solo sirve para
# saber de que stream hablamos si Spotify se reabre).
VOL_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/spotify-vol"

# Umbrales del guardia. El reset observado cae siempre en 99-100; por debajo de
# TOPE se asume que el cambio es tuyo y se memoriza.
# ponytail: heuristica por valor, no por autor — pactl no dice quien escribe.
# Consecuencia: subir a >=98 desde pavucontrol se revierte. Para dejarlo al tope
# usa el popup, que memoriza el valor nuevo y desactiva el guardia solo.
VOL_TOPE=98
VOL_MARGEN=95

vol_remember() {
    mkdir -p "${VOL_STATE%/*}"
    printf '%s %s\n' "$1" "$2" > "$VOL_STATE"
}

# Bucle largo: lo arranca spotify_bar.sh. Un evento por cambio de volumen, sin
# polling. Mientras nadie toque el volumen no consume nada.
vol_guard() {
    local kind num id vol prev
    pactl subscribe 2>/dev/null | while read -r _ _ _ kind num; do
        [ "$kind" = "sink-input" ] || continue
        id=$(sink_input)
        [ -n "$id" ] || continue
        vol=$(vol_get)
        [[ $vol =~ ^[0-9]+$ ]] || continue

        prev=""
        [ -r "$VOL_STATE" ] && read -r _ prev < "$VOL_STATE"

        if [ -n "$prev" ] && [ "$vol" -ge "$VOL_TOPE" ] && [ "$prev" -le "$VOL_MARGEN" ]; then
            pactl set-sink-input-volume "$id" "${prev}%"
        else
            vol_remember "$id" "$vol"
        fi
    done
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
    vol-guard) vol_guard ;;
    *)       echo "uso: spotify.sh {state|refresh|action <a>|vol <0-100>|vol-guard}" >&2; exit 1 ;;
esac
