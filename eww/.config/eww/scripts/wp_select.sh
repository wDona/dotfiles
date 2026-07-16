#!/usr/bin/env bash
# Aplica un fondo (desde el grid o el boton Examinar) y refresca la lista que
# pinta el panel de Personalizacion de eww.
# Uso: wp_select.sh set <path>   |   wp_select.sh browse
WP="$HOME/.config/hypr/scripts/wallpaper.sh"

case "${1:-}" in
    set)    "$WP" set "$2" ;;
    browse) "$WP" browse ;;
    *)      echo "uso: wp_select.sh {set <path>|browse}" >&2; exit 1 ;;
esac

eww update wallpapers="$("$WP" list)"
