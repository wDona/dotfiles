#!/bin/sh
# Claude Code flotante toggle (sin overlay special que bloquee el resto).
# - No corre  -> lanza kitty flotante en el workspace actual (windowrule da size/center).
# - Visible    -> lo manda a un special stash (oculto), workspace queda libre.
# - Oculto     -> lo trae al workspace actual, lo enfoca y lo pone encima.
# Terminales IntelliJ flotantes se mueven junto con Claude.
CLASS=claude-term
HIDE=special:claudehide
INTEL_CLASS="jetbrains-idea"
INTEL_TITLE="Terminal"

data=$(hyprctl clients -j)
addr=$(echo "$data" | jq -r ".[] | select(.class==\"$CLASS\") | .address" | head -n1)

# Buscar terminales flotantes de IntelliJ
get_intel_terminals() {
    echo "$data" | jq -r ".[] | select(.class==\"$INTEL_CLASS\" and .title==\"$INTEL_TITLE\") | .address"
}

if [ -z "$addr" ] || [ "$addr" = "null" ]; then
    setsid kitty --class "$CLASS" -e /home/wdona/.local/bin/claude >/dev/null 2>&1 &
    exit 0
fi

ws=$(echo "$data" | jq -r ".[] | select(.class==\"$CLASS\") | .workspace.name" | head -n1)
if [ "$ws" = "$HIDE" ]; then
    cur=$(hyprctl activeworkspace -j | jq -r '.id')
    hyprctl dispatch movetoworkspace "$cur,address:$addr"
    hyprctl dispatch alterzorder "top,address:$addr"
    hyprctl dispatch focuswindow "address:$addr"

    # Mover terminales de IntelliJ también al workspace actual
    get_intel_terminals | while read -r term_addr; do
        if [ -n "$term_addr" ] && [ "$term_addr" != "null" ]; then
            hyprctl dispatch movetoworkspacesilent "$cur,address:$term_addr"
        fi
    done
else
    hyprctl dispatch movetoworkspacesilent "$HIDE,address:$addr"

    # Mover terminales de IntelliJ también a special:claudehide
    get_intel_terminals | while read -r term_addr; do
        if [ -n "$term_addr" ] && [ "$term_addr" != "null" ]; then
            hyprctl dispatch movetoworkspacesilent "$HIDE,address:$term_addr"
        fi
    done
fi
