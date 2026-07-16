#!/usr/bin/env bash
# =============================================================================
# hypr_tweak.sh - Ajustes de Hyprland desde el panel de Ajustes. Aplica en vivo
# con `hyprctl keyword` y persiste en ~/.config/hypr/conf.d/overrides.conf (que
# hyprland.conf hace `source` al final, asi gana sobre los valores base).
# Estado en ~/.config/hypr-tweaks.conf.
#
#   hypr_tweak.sh set <key> <val>
#   hypr_tweak.sh get
#
# Keys:
#   enteros : gaps_in gaps_out border_size rounding blur_size
#   floats  : active_opacity inactive_opacity
#   bool    : blur_enabled animations        (0/1)
#   string  : border_grad                    (ej "rgba(d946efff) rgba(f472b6ff) 90deg")
# =============================================================================
set -uo pipefail
STATE="$HOME/.config/hypr-tweaks.conf"
OV="$HOME/.config/hypr/conf.d/overrides.conf"
mkdir -p "$(dirname "$OV")"
touch "$STATE"

get() { grep -m1 "^$1=" "$STATE" 2>/dev/null | cut -d= -f2-; }
setk() {
    if grep -q "^$1=" "$STATE"; then
        # usa | como separador raro por si el valor lleva /
        local tmp; tmp=$(grep -v "^$1=" "$STATE"); printf '%s\n' "$tmp" > "$STATE"
    fi
    printf '%s=%s\n' "$1" "$2" >> "$STATE"
}

bool() { [ "$1" = "1" ] && echo true || echo false; }
pct()  { awk "BEGIN{printf \"%.2f\", ${1:-100}/100}"; }   # 0-100 -> 0.00-1.00

live() {
    local k="$1" v="$2"
    case "$k" in
        gaps_in)          hyprctl keyword general:gaps_in "$v" ;;
        gaps_out)         hyprctl keyword general:gaps_out "$v" ;;
        border_size)      hyprctl keyword general:border_size "$v" ;;
        rounding)         hyprctl keyword decoration:rounding "$v" ;;
        blur_size)        hyprctl keyword decoration:blur:size "$v" ;;
        blur_enabled)     hyprctl keyword decoration:blur:enabled "$(bool "$v")" ;;
        active_opacity)   hyprctl keyword decoration:active_opacity "$(pct "$v")" ;;
        inactive_opacity) hyprctl keyword decoration:inactive_opacity "$(pct "$v")" ;;
        animations)       hyprctl keyword animations:enabled "$(bool "$v")" ;;
        border_grad)      hyprctl keyword general:col.active_border $v ;;
    esac >/dev/null 2>&1
}

# Reconstruye overrides.conf entero desde el estado (solo claves definidas).
rebuild() {
    local gi go bs rd bsz ben ao io anim grad
    gi=$(get gaps_in);   go=$(get gaps_out); bs=$(get border_size); rd=$(get rounding)
    bsz=$(get blur_size); ben=$(get blur_enabled)
    ao=$(get active_opacity); io=$(get inactive_opacity)
    anim=$(get animations); grad=$(get border_grad)
    {
        echo "# Generado por hypr_tweak.sh (panel Ajustes eww). No editar a mano."
        echo "general {"
        [ -n "$gi" ]   && echo "    gaps_in = $gi"
        [ -n "$go" ]   && echo "    gaps_out = $go"
        [ -n "$bs" ]   && echo "    border_size = $bs"
        [ -n "$grad" ] && echo "    col.active_border = $grad"
        echo "}"
        echo "decoration {"
        [ -n "$rd" ] && echo "    rounding = $rd"
        [ -n "$ao" ] && echo "    active_opacity = $(pct "$ao")"
        [ -n "$io" ] && echo "    inactive_opacity = $(pct "$io")"
        echo "    blur {"
        [ -n "$ben" ] && echo "        enabled = $(bool "$ben")"
        [ -n "$bsz" ] && echo "        size = $bsz"
        echo "    }"
        echo "}"
        echo "animations {"
        [ -n "$anim" ] && echo "    enabled = $(bool "$anim")"
        echo "}"
    } > "$OV"
}

num() { local v; v=$(get "$1"); echo "${v:-0}"; }

case "${1:-}" in
    set)
        [ -n "${3:-}" ] || { echo "uso: hypr_tweak.sh set <key> <val>" >&2; exit 1; }
        k="$2"; v="$3"
        case "$k" in
            gaps_in|gaps_out|border_size|rounding|blur_size|active_opacity|inactive_opacity)
                v="${v%%.*}" ;;  # entero (las opacidades van en % 0-100)
        esac
        setk "$k" "$v"; live "$k" "$v"; rebuild
        ;;
    get)
        jq -nc \
          --argjson gi "$(num gaps_in)" --argjson go "$(num gaps_out)" \
          --argjson bs "$(num border_size)" --argjson rd "$(num rounding)" \
          --argjson bsz "$(num blur_size)" --argjson ben "$(num blur_enabled)" \
          --argjson ao "$(num active_opacity)" --argjson io "$(num inactive_opacity)" \
          --argjson anim "$(num animations)" --arg grad "$(get border_grad)" \
          '{gaps_in:$gi,gaps_out:$go,border_size:$bs,rounding:$rd,blur_size:$bsz,blur_enabled:$ben,active_opacity:$ao,inactive_opacity:$io,animations:$anim,border_grad:$grad}'
        ;;
    *) echo "uso: hypr_tweak.sh {set <key> <val>|get}" >&2; exit 1 ;;
esac
