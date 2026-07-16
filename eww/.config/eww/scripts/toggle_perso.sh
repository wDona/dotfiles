#!/usr/bin/env bash
# Toggle del panel de Ajustes de eww (fondo, apariencia, configuraciones).
# Refresca todo el estado antes de abrir.
WP="$HOME/.config/hypr/scripts/wallpaper.sh"
APP="$HOME/.config/hypr/scripts/appearance.sh"
HT="$HOME/.config/hypr/scripts/hypr_tweak.sh"
KITTY="$HOME/.config/kitty/kitty.conf"

if ! eww ping >/dev/null 2>&1; then
    eww daemon >/dev/null 2>&1
    sleep 0.4
fi

if eww active-windows 2>/dev/null | grep -q "personalizacion"; then
    eww close personalizacion
    exit 0
fi

EC="$HOME/.config/eww/scripts/eww_color.sh"
EWIN="$HOME/.config/eww/scripts/eww_windows.sh"

# Opacidad y fuente de kitty actuales
kop=$(awk '/^background_opacity /{printf "%d", $2*100}' "$KITTY" 2>/dev/null)
[ -z "$kop" ] && kop=100
kfs=$(awk '/^font_size /{printf "%d", $2}' "$KITTY" 2>/dev/null)
[ -z "$kfs" ] && kfs=12

appj=$("$APP" get)
gtkcur=$(echo "$appj"  | jq -r '.gtk')
iconcur=$(echo "$appj" | jq -r '.icon')
curcur=$(echo "$appj"  | jq -r '.cursor')
fontcur=$(echo "$appj" | jq -r '.font' | sed 's/ [0-9]*$//')
cursz=$(echo "$appj"   | jq -r '.cursor_size')

eww update \
    view=home \
    conf_sel="" \
    wallpapers="$("$WP" list)" \
    confs="$(conf --list | jq -c 'to_entries | map({name:.key, path:.value})')" \
    themes_gtk="$("$APP" list-gtk)" \
    themes_icon="$("$APP" list-icon)" \
    cursors="$("$APP" list-cursor)" \
    fonts="$("$APP" list-font)" \
    hypr_t="$("$HT" get)" \
    kitty_op="$kop" \
    kitty_fs="$kfs" \
    gtk_cur="$gtkcur" \
    icon_cur="$iconcur" \
    cursor_cur="$curcur" \
    font_cur="$fontcur" \
    cursor_size="$cursz" \
    ewwcols="$("$EC" get)" \
    ewwwins="$("$EWIN")" \
    eww_presets="$("$EC" list-presets)"

mon=$("$(dirname "$0")/eww_screen.sh")
eww open personalizacion --screen "$mon"
