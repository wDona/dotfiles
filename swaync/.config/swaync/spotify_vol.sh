#!/usr/bin/env bash
# Ajusta el volumen PROPIO de Spotify vía MPRIS (playerctl), no el global.
# Robusto: funciona aunque Spotify no tenga stream activo en PipeWire.
# Tras ajustar muestra un OSD (swayosd) con el % actual.
# Uso: spotify_vol.sh up|down [step%]
export PATH="$HOME/.local/bin:$PATH"
dir="$1"; step="${2:-5}"
frac=$(awk "BEGIN{printf \"%.3f\", $step/100}")

case "$dir" in
    up)   playerctl -p spotify volume "${frac}+" 2>/dev/null ;;
    down) playerctl -p spotify volume "${frac}-" 2>/dev/null ;;
    *)    exit 1 ;;
esac

vol=$(playerctl -p spotify volume 2>/dev/null)
[ -z "$vol" ] && exit 0

prog=$(awk "BEGIN{v=$vol; if(v>1)v=1; if(v<0)v=0; printf \"%.2f\", v}")
pct=$(awk "BEGIN{v=$vol; if(v>1)v=1; if(v<0)v=0; printf \"%d\", v*100+0.5}")
swayosd-client --custom-progress "$prog" \
    --custom-message "Spotify ${pct}%" \
    --custom-icon multimedia-player 2>/dev/null
