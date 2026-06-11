#!/bin/bash
# Cambia el fondo de video (mpvpaper) al MP4 pasado como argumento.
# Uso: set-wallpaper.sh /ruta/al/video.mp4

VIDEO="$1"

if [ -z "$VIDEO" ] || [ ! -f "$VIDEO" ]; then
    echo "Uso: $0 /ruta/al/video.mp4"
    echo "Video no encontrado: $VIDEO"
    exit 1
fi

# Matar mpvpaper actual
pkill -x mpvpaper 2>/dev/null
sleep 0.3

# Lanzar nuevo fondo
mpvpaper -o "--loop --no-audio --vo=gpu --hwdec=auto" '*' "$VIDEO" &

disown
echo "Fondo cambiado a: $VIDEO"
