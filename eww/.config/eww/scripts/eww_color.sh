#!/usr/bin/env bash
# =============================================================================
# eww_color.sh - Edita la paleta de colores de eww (variables SCSS al principio
# de eww.scss) y recompila con `eww reload`, recolorea todo eww en vivo
# (calendario, dashboard, ajustes, sysmenu).
#
#   eww_color.sh get                 # JSON {bg,bg_cell,...} con los hex actuales
#   eww_color.sh set <key> <hex>     # cambia una variable
#   eww_color.sh pick <key>          # selector de color (zenity) -> set
#   eww_color.sh preset <name>       # aplica una paleta entera
#   eww_color.sh list-presets        # JSON [nombres]
#
# Keys (json) -> variable SCSS:
#   bg bg_cell surface accent accent2 fg fg_dim lila
# =============================================================================
set -uo pipefail
SCSS="$HOME/.config/eww/eww.scss"
ZTHEME="$HOME/.config/eww/zenity-theme"

# json_key -> nombre real de la variable scss
declare -A VAR=(
    [bg]="bg" [bg_cell]="bg-cell" [surface]="surface" [accent]="accent"
    [accent2]="accent2" [fg]="fg" [fg_dim]="fg-dim" [lila]="lila"
)
KEYS=(bg bg_cell surface accent accent2 fg fg_dim lila)

getcol() {  # json_key -> hex actual
    local v="${VAR[$1]}"
    grep -m1 -oP "^\\\$${v}:\\s*\\K#[0-9a-fA-F]{3,8}" "$SCSS"
}

setcol() {  # json_key hex
    local v="${VAR[$1]}" hex="$2"
    sed -i -E "s|^(\\\$${v}:)[[:space:]]*#[0-9a-fA-F]{3,8};|\\1 ${hex};|" "$SCSS"
}

hexof() {  # convierte rgb(r,g,b)/#hex -> #rrggbb
    case "$1" in
        \#*) printf '%s\n' "${1:0:7}" ;;
        rgb*) echo "$1" | sed -E 's/[^0-9,]//g' | awk -F, '{printf "#%02x%02x%02x\n",$1,$2,$3}' ;;
        *) printf '%s\n' "$1" ;;
    esac
}

# ── Presets (8 colores: bg bg_cell surface accent accent2 fg fg_dim lila) ──
declare -A PRESET_morado=( [bg]="#140f1a" [bg_cell]="#1c1228" [surface]="#2d1b4e" [accent]="#d946ef" [accent2]="#ec4899" [fg]="#f0f0ff" [fg_dim]="#5a4a6a" [lila]="#c9a0ff" )
declare -A PRESET_dracula=( [bg]="#282a36" [bg_cell]="#343746" [surface]="#44475a" [accent]="#bd93f9" [accent2]="#ff79c6" [fg]="#f8f8f2" [fg_dim]="#6272a4" [lila]="#bd93f9" )
declare -A PRESET_nord=( [bg]="#2e3440" [bg_cell]="#3b4252" [surface]="#434c5e" [accent]="#88c0d0" [accent2]="#81a1c1" [fg]="#eceff4" [fg_dim]="#4c566a" [lila]="#b48ead" )
declare -A PRESET_catppuccin=( [bg]="#1e1e2e" [bg_cell]="#313244" [surface]="#45475a" [accent]="#cba6f7" [accent2]="#f5c2e7" [fg]="#cdd6f4" [fg_dim]="#6c7086" [lila]="#b4befe" )
declare -A PRESET_gruvbox=( [bg]="#282828" [bg_cell]="#3c3836" [surface]="#504945" [accent]="#fabd2f" [accent2]="#fe8019" [fg]="#ebdbb2" [fg_dim]="#665c54" [lila]="#d3869b" )
PRESETS=(morado dracula nord catppuccin gruvbox)

apply_preset() {
    local name="$1" decl="PRESET_${1}" k
    declare -n p="$decl" 2>/dev/null || { echo "preset desconocido: $name" >&2; return 1; }
    for k in "${KEYS[@]}"; do [ -n "${p[$k]:-}" ] && setcol "$k" "${p[$k]}"; done
}

case "${1:-}" in
    get)
        out="{"; first=1
        for k in "${KEYS[@]}"; do
            [ $first -eq 0 ] && out+=","
            out+="\"$k\":\"$(getcol "$k")\""; first=0
        done
        echo "$out}"
        ;;
    set)   setcol "$2" "$3"; eww reload >/dev/null 2>&1 ;;
    pick)
        cur=$(getcol "$2")
        sel=$(XDG_CONFIG_HOME="$ZTHEME" zenity --color-selection \
              --title="Color: $2" --color="$cur" 2>/dev/null) || exit 0
        [ -n "$sel" ] && { setcol "$2" "$(hexof "$sel")"; eww reload >/dev/null 2>&1; }
        ;;
    preset) apply_preset "$2" && eww reload >/dev/null 2>&1 ;;
    list-presets) printf '%s\n' "${PRESETS[@]}" | jq -Rsc 'split("\n")|map(select(.!=""))' ;;
    *) echo "uso: eww_color.sh {get|set <key> <hex>|pick <key>|preset <name>|list-presets}" >&2; exit 1 ;;
esac
