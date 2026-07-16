#!/bin/sh
# Special "fullscreen" en modo solo-una-app.
# - Ventana activa NO en special -> evicta lo que hubiera en special, la manda
#   alli, muestra el special y la pone a pantalla completa.
# - Ventana activa YA en special -> la saca al workspace actual y quita fullscreen.
# SP = nombre para dispatch; SPNAME = nombre real que reporta hyprctl
SP=special
SPNAME=special:special

active=$(hyprctl activewindow -j | jq -r '.address')
[ -z "$active" ] || [ "$active" = "null" ] && exit 0

cur=$(hyprctl activeworkspace -j | jq -r '.id')
aws=$(hyprctl activewindow -j | jq -r '.workspace.name')

if [ "$aws" = "$SPNAME" ]; then
    # Sacarla del special y quitar fullscreen
    hyprctl dispatch fullscreen 0
    hyprctl dispatch movetoworkspace "$cur,address:$active"
    exit 0
fi

# Evicta cualquier ventana ya presente en el special (solo 1 permitida).
# Se enfoca, se le quita fullscreen y se manda al workspace actual.
for a in $(hyprctl clients -j | jq -r ".[] | select(.workspace.name==\"$SPNAME\") | .address"); do
    hyprctl dispatch focuswindow "address:$a"
    hyprctl dispatch fullscreenstate 0 0
    hyprctl dispatch movetoworkspacesilent "$cur,address:$a"
done

# Recuerda el workspace de origen para poder volver luego (SUPER+Down)
mkdir -p /tmp/hypr_fs
echo "$cur" > "/tmp/hypr_fs/$active"

# Manda la activa al special, lo muestra y la pone fullscreen
hyprctl dispatch movetoworkspacesilent "$SP,address:$active"
hyprctl dispatch togglespecialworkspace
hyprctl dispatch fullscreen 0
