#!/bin/bash
# Teclado en Hyprland: idioma (EN/ES) y disposicion (QWERTY/DVORAK).
#   kb_switch.sh lang     -> alterna us <-> es
#   kb_switch.sh variant  -> alterna qwerty <-> dvorak
#   kb_switch.sh status   -> JSON indicador para waybar
#   kb_switch.sh init     -> estado inicial (us qwerty)
# hyprland.conf: kb_layout=us,es,us,es  kb_variant=,,dvorak,dvorak
#   idx = (es?1:0) + (dvorak?2:0)
S="${XDG_RUNTIME_DIR:-/tmp}/kb_state"
[ -f "$S" ] || echo "us qwerty" > "$S"
read -r lang var < "$S"

apply() {
    echo "$lang $var" > "$S"
    # idx: 0=us-dvorak 1=us-qwerty 2=es-dvorak 3=es-qwerty
    e=0; [ "$lang" = "es" ] && e=2
    q=0; [ "$var" = "qwerty" ] && q=1
    hyprctl switchxkblayout current $((e + q)) >/dev/null 2>&1
    pkill -RTMIN+9 waybar 2>/dev/null
}

case "$1" in
    lang)    [ "$lang" = "us" ] && lang="es" || lang="us"; apply ;;
    variant) [ "$var" = "qwerty" ] && var="dvorak" || var="qwerty"; apply ;;
    init)    lang="us"; var="dvorak"; apply ;;
    status)
        L=$([ "$lang" = "es" ] && echo "ES" || echo "EN")
        V=$([ "$var" = "dvorak" ] && echo "DV" || echo "QW")
        printf '{"text":"󰌌 %s\u00b7%s","tooltip":"Teclado: %s %s · click=disposicion, der=idioma","class":"kb"}\n' "$L" "$V" "$L" "$V"
        ;;
    *) exit 1 ;;
esac
