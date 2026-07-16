#!/bin/bash

# Foco aplicacion en Hyprland por nombre
APP_NAME="$1"

# Mapeo de nombres de apps a clases de Hyprland
declare -A APP_CLASSES=(
    ["discord"]="discord"
    ["claude"]="Claude"
    ["kitty"]="kitty"
    ["spotify"]="spotify"
    ["brave"]="brave"
    ["steam"]="steam"
    ["teamspeak"]="TeamSpeak 3"
    ["lutris"]="lutris"
    ["whatsapp"]="whatsapp-for-linux"
)

# Obtener clase de la app
CLASS="${APP_CLASSES[$APP_NAME]}"
[ -z "$CLASS" ] && CLASS="$APP_NAME"

# Buscar ventana y enfocar
if hyprctl clients | grep -qi "class: $CLASS"; then
    hyprctl dispatch focuswindow "class:$CLASS"
else
    # Si no existe, intentar lanzarla
    case "$APP_NAME" in
        discord) discord &;;
        claude) claude &;;
        kitty) kitty &;;
        spotify) spotify &;;
        brave) brave &;;
        steam) steam &;;
        teamspeak) teamspeak &;;
        lutris) lutris &;;
        whatsapp) whatsapp-for-linux &;;
    esac
fi
