#!/usr/bin/env bash
# Toggle del popup de Spotify.
#
# Refresca ANTES de abrir (a diferencia de clima, que abre y refresca por
# detras): aqui el estado se lee en local en ~25ms, no hay red que esperar, y
# abrir primero solo conseguiria enseñar la cancion anterior durante un frame.
DIR="$(dirname "$0")"
"$DIR/eww_ensure.sh"

"$DIR/popup.sh" is-open spotify && exec "$DIR/popup.sh" close

eww update spotify_json="$("$DIR/spotify.sh" state)" 2>/dev/null

# El despliegue de arriba a abajo lo pone Hyprland (layerrule slide top sobre
# el namespace gtk-layer-shell), igual que en el resto de ventanas.
exec "$DIR/popup.sh" open spotify
