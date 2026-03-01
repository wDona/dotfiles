#!/bin/bash

MANIFEST_PATH="$HOME/.local/share/Steam/steamapps"

inotifywait -m "$MANIFEST_PATH" -e close_write --format '%f' |
    while read FILE; do
        if [[ "$FILE" == appmanifest_* ]]; then
            GAME_NAME=$(grep "name" "$MANIFEST_PATH/$FILE" | cut -d '"' -f 4)
            STATE=$(grep "StateFlags" "$MANIFEST_PATH/$FILE" | grep -oP '\d+')

            case $STATE in
                4)
                    notify-send "Steam" "✅ **$GAME_NAME** descargado." -i steam -a "Steam"
                    ;;
                16|1042|1044) # Estados comunes de pausa o espera
                    notify-send "Steam" "⏸️ **$GAME_NAME** en pausa o esperando." -i steam -a "Steam"
                    ;;
            esac
        fi
    done