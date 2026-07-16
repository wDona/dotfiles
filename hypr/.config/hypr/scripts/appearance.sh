#!/usr/bin/env bash
# =============================================================================
# appearance.sh - Apariencia GTK (tema, iconos, cursor, tamaño cursor, fuente)
# via gsettings, con estado persistente en ~/.config/appearance.conf. Lo llama
# hyprland.conf (restore) en el arranque y el panel de Ajustes de eww.
#
#   appearance.sh restore
#   appearance.sh set-gtk|set-icon|set-cursor|set-font <name>
#   appearance.sh set-cursor-size <n>
#   appearance.sh list-gtk|list-icon|list-cursor|list-font   # JSON [{name,selected}]
#   appearance.sh get                                        # JSON estado
# =============================================================================
set -uo pipefail
STATE="$HOME/.config/appearance.conf"
IFACE="org.gnome.desktop.interface"
touch "$STATE"

get_state() { grep -m1 "^$1=" "$STATE" 2>/dev/null | cut -d= -f2-; }
set_state() {
    local k="$1" v="$2"
    if grep -q "^$k=" "$STATE"; then
        sed -i "s|^$k=.*|$k=$v|" "$STATE"
    else
        printf '%s=%s\n' "$k" "$v" >> "$STATE"
    fi
}

# $1 = lista por stdin, $2 = valor actual  ->  JSON [{name,selected}]
as_rows() { jq -R . | jq -sc --arg c "$1" 'map({name:.,selected:(.==$c)})'; }

list_gtk() {
    local cur; cur=$(get_state gtk)
    {
        [ -n "$cur" ] && echo "$cur"
        { ls -d ~/.themes/*/ /usr/share/themes/*/ ; } 2>/dev/null | while read -r d; do
            { [ -d "${d}gtk-3.0" ] || [ -d "${d}gtk-4.0" ]; } && basename "$d"
        done
    } | sort -u | as_rows "$cur"
}

list_icon() {
    local cur; cur=$(get_state icon)
    { ls -d ~/.icons/*/ /usr/share/icons/*/ ; } 2>/dev/null | while read -r d; do
        [ -f "${d}index.theme" ] && [ ! -d "${d}cursors" ] && basename "$d"
    done | sort -u | grep -viE '^(default|hicolor)$' | as_rows "$cur"
}

list_cursor() {
    local cur; cur=$(get_state cursor)
    {
        [ -n "$cur" ] && echo "$cur"
        { ls -d ~/.icons/*/ ~/.local/share/icons/*/ /usr/share/icons/*/ ; } 2>/dev/null | while read -r d; do
            { [ -d "${d}cursors" ] || [ -f "${d}manifest.hl" ]; } && basename "$d"
        done
    } | sort -u | as_rows "$cur"
}

list_font() {
    local cur; cur=$(get_state font); cur="${cur% *}"   # quita el tamaño
    fc-list : family 2>/dev/null | sed 's/,.*//' | sort -u | as_rows "$cur"
}

# tamaño actual de la fuente (numero al final de font-name), por defecto 11
font_size() { local f; f=$(get_state font); echo "${f##* }" | grep -qE '^[0-9]+$' && echo "${f##* }" || echo 11; }

case "${1:-}" in
    set-gtk)    gsettings set $IFACE gtk-theme "$2";    set_state gtk "$2" ;;
    set-icon)   gsettings set $IFACE icon-theme "$2";   set_state icon "$2" ;;
    set-cursor)
        gsettings set $IFACE cursor-theme "$2"; set_state cursor "$2"
        hyprctl setcursor "$2" "$(get_state cursor_size 2>/dev/null || echo 24)" >/dev/null 2>&1
        ;;
    set-cursor-size)
        gsettings set $IFACE cursor-size "$2"; set_state cursor_size "$2"
        c=$(get_state cursor); [ -n "$c" ] && hyprctl setcursor "$c" "$2" >/dev/null 2>&1
        ;;
    set-font)
        nf="$2 $(font_size)"; gsettings set $IFACE font-name "$nf"; set_state font "$nf" ;;
    restore)
        g=$(get_state gtk); i=$(get_state icon); c=$(get_state cursor)
        cs=$(get_state cursor_size); f=$(get_state font)
        [ -n "$g" ]  && gsettings set $IFACE gtk-theme "$g"
        [ -n "$i" ]  && gsettings set $IFACE icon-theme "$i"
        [ -n "$c" ]  && gsettings set $IFACE cursor-theme "$c"
        [ -n "$cs" ] && gsettings set $IFACE cursor-size "$cs"
        [ -n "$f" ]  && gsettings set $IFACE font-name "$f"
        [ -n "$c" ]  && hyprctl setcursor "$c" "${cs:-24}" >/dev/null 2>&1
        gsettings set $IFACE color-scheme 'prefer-dark'
        ;;
    list-gtk)    list_gtk ;;
    list-icon)   list_icon ;;
    list-cursor) list_cursor ;;
    list-font)   list_font ;;
    get)
        jq -nc --arg g "$(get_state gtk)" --arg i "$(get_state icon)" \
               --arg c "$(get_state cursor)" --arg cs "$(get_state cursor_size)" \
               --arg f "$(get_state font)" \
               '{gtk:$g,icon:$i,cursor:$c,cursor_size:($cs|tonumber? // 24),font:$f}'
        ;;
    *)
        echo "uso: appearance.sh {restore|set-gtk|set-icon|set-cursor|set-font <name>|set-cursor-size <n>|list-gtk|list-icon|list-cursor|list-font|get}" >&2
        exit 1
        ;;
esac
