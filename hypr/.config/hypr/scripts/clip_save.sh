#!/usr/bin/env bash
# Signal gpu-screen-recorder to save replay, notify success or failure.
CLIPS_DIR="$HOME/Videos/Clips"
TIMEOUT=8

pid=$(pgrep -f '^gpu-screen-recorder -w' | head -n1)
if [ -z "$pid" ]; then
    notify-send -u critical "Grabador" "Error: gpu-screen-recorder no esta corriendo"
    exit 1
fi

kill -SIGUSR1 "$pid"

new_file=$(timeout "$TIMEOUT" inotifywait -e close_write -e moved_to --format '%f' "$CLIPS_DIR" 2>/dev/null)

if [ -n "$new_file" ]; then
    # -A implica esperar: notify-send imprime la clave de accion al clicar
    action=$(notify-send -A default=Abrir "Grabador" "Clip guardado: $new_file")
    [ "$action" = "default" ] && nautilus --select "$CLIPS_DIR/$new_file" >/dev/null 2>&1 &
else
    notify-send -u critical "Grabador" "Error: clip no se guardo (timeout)"
fi
