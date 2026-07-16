#!/usr/bin/env bash
# swaync ejecuta esto en CADA notificacion (config.json -> scripts -> app-name ".*").
# Elige el sonido segun la app que la envia.
# Variables que swaync inyecta: SWAYNC_APP_NAME, SWAYNC_SUMMARY, SWAYNC_BODY,
#   SWAYNC_URGENCY, SWAYNC_CATEGORY, SWAYNC_DESKTOP_ENTRY, SWAYNC_ID...
SND="$HOME/.config/swaync/sounds"     # sonidos por app (crea aqui los .mp3/.ogg)
DEF="$HOME/.config/swaync/notif.mp3"  # sonido por defecto

# --- TEMPORAL: registra que apps llegan, para descubrir el app-name exacto ---
echo "$(date +%T) app='${SWAYNC_APP_NAME}' urg='${SWAYNC_URGENCY}' sum='${SWAYNC_SUMMARY}'" >> /tmp/swaync_apps.log

# Mapa app -> sonido + volumen (en minusculas). Anade casos aqui.
# vol: 0..65536 (65536 = 100%). Default 100%.
vol=65536
case "${SWAYNC_APP_NAME,,}" in
    temporizador)     f="$SND/timer.mp3"; vol=30000 ;;
    spotify)          f="$SND/spotify.mp3" ;;
    discord|vesktop)  f="$SND/discord.mp3" ;;
    telegram*)        f="$SND/telegram.mp3" ;;
    *)                f="$DEF" ;;
esac

# Si el sonido de la app no existe, usa el por defecto (a volumen normal).
[ -f "$f" ] || { f="$DEF"; vol=65536; }
exec paplay --volume "$vol" "$f"
