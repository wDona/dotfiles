#!/bin/sh
# Claude Code flotante toggle (sin overlay special que bloquee el resto).
# - No corre  -> lanza kitty flotante en el workspace actual (windowrule da size/center).
# - Visible    -> lo manda a un special stash (oculto), workspace queda libre.
# - Oculto     -> lo trae al workspace actual, lo enfoca y lo pone encima.
# Terminales IntelliJ flotantes se mueven junto con Claude.

# Hyprland arranca con el PATH del login, sin ~/.local/bin ni ~/.npm-global/bin
# (solo estan en .zshrc, interactiva). Sin esto `kitty -e herdr` muere al
# instante y todos los `herdr pane list` de abajo fallan -> no abre ningun
# agente. Se exporta para que kitty y los panes lo hereden.
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

CLASS=claude-term
HIDE=special:claudehide
HIDE_NAME=claudehide
INTEL_CLASS="jetbrains-idea"
INTEL_TITLE="Terminal"

# ALT+F4 tumba el server en background (hasta ~10s entre matar kitty y parar el
# server). Sin esto, un SUPER+C a 1s arranca un server que el teardown en curso
# mata acto seguido. El lock se retiene hasta que la ventana de kitty existe: si
# se soltara antes de lanzarla, un segundo SUPER+C entraria, veria `addr` vacio
# (la ventana aun no esta mapeada) y abriria una kitty clonada sobre el mismo
# server. Los hijos se lanzan con 9>&- para no heredar el fd y no retenerlo.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/herdr-reset.lock"
flock -w 15 9

data=$(hyprctl clients -j)
addr=$(echo "$data" | jq -r ".[] | select(.class==\"$CLASS\") | .address" | head -n1)

# Buscar terminales flotantes de IntelliJ
get_intel_terminals() {
    echo "$data" | jq -r ".[] | select(.class==\"$INTEL_CLASS\" and .title==\"$INTEL_TITLE\") | .address"
}

# El stash tiene que estar SIEMPRE oculto: mientras un special esta desplegado en
# el monitor, Hyprland abre dentro de el cualquier ventana nueva. En claudehide
# solo deben vivir Claude y las terminales de IntelliJ, asi que se cierra tras
# cada toggle (idempotente: no hace nada si ya estaba oculto).
close_stash() {
    [ "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .specialWorkspace.name')" = "$HIDE" ] \
        && hyprctl dispatch togglespecialworkspace "$HIDE_NAME"
}

# Garantiza que siempre haya un claude y un opencode vivos en herdr, sin
# duplicar: herdr reporta el agente vivo de cada pane en `.agent` ("claude" /
# "opencode"), asi que basta con relanzar el que falte. Corre en cada toggle
# (idempotente) y en background, porque el socket tarda en levantar tras
# lanzar herdr. El estado restaurado de session.json solo trae shells (guarda
# cwd/layout, no procesos), asi que tras un reset los agentes se recrean y el
# claude nuevo queda enfocado: la sesion vieja sigue ahi, pero detras.
# Rutas absolutas: ~/.npm-global/bin no esta en el PATH fuera de zsh interactiva.
CLAUDE_BIN="$HOME/.local/bin/claude"
OPENCODE_BIN="$HOME/.npm-global/bin/opencode"

has_agent() {
    herdr pane list 2>/dev/null \
        | jq -e --arg a "$1" '.result.panes[] | select(.agent == $a)' >/dev/null 2>&1
}

# El shell de un pane recien creado tarda en levantar; si `pane run` llega antes,
# el comando se pierde en silencio y el pane queda vivo sin agente (el bug del
# "se finge que abrio"). herdr publica terminal_title solo cuando el shell existe.
wait_pane_ready() {
    i=0
    while [ "$i" -lt 40 ]; do
        [ -n "$(herdr pane list 2>/dev/null \
            | jq -r --arg p "$1" '.result.panes[] | select(.pane_id==$p) | .terminal_title // empty')" ] \
            && return 0
        sleep 0.25
        i=$((i + 1))
    done
    return 1
}

# Primer pane sin agente, priorizando el workspace que ya llevaba ese label.
# Sin esto, tras un reset los workspaces restaurados (shells vacios, session.json
# guarda cwd/layout pero no procesos) se quedaban colgando y cada ALT+F4 añadia
# dos mas encima. Reutilizarlos ademas arranca el agente en el cwd de antes.
free_pane() {
    ws=$(herdr workspace list 2>/dev/null \
        | jq -r --arg a "$1" 'first(.result.workspaces[] | select(.label == $a) | .workspace_id) // empty')
    p=""
    [ -n "$ws" ] && p=$(echo "$panes" | jq -r --arg w "$ws" \
        'first(.result.panes[] | select(.agent == null and .workspace_id == $w) | .pane_id) // empty')
    [ -z "$p" ] && p=$(echo "$panes" \
        | jq -r 'first(.result.panes[] | select(.agent == null) | .pane_id) // empty')
    echo "$p"
}

# $1 = agente, $2 = binario, $3 = extra args de workspace create
ensure_agent() {
    has_agent "$1" && return

    pane=$(free_pane "$1")
    if [ -n "$pane" ]; then
        # El workspace reutilizado conserva el label viejo ("~", el del otro
        # agente...); renombrar para que la lista siga siendo legible.
        herdr workspace rename "${pane%%:*}" "$1" >/dev/null 2>&1
        [ "$3" = "--no-focus" ] || herdr workspace focus "${pane%%:*}" >/dev/null 2>&1
    else
        pane=$(herdr workspace create --label "$1" $3 2>/dev/null \
            | jq -r '.result.root_pane.pane_id // empty')
    fi
    [ -z "$pane" ] && return

    # Dos intentos: la deteccion de agente tarda unos segundos, asi que se espera
    # antes de reintentar para no encadenar dos lanzamientos en el mismo shell.
    n=0
    while [ "$n" -lt 2 ]; do
        wait_pane_ready "$pane" || return
        herdr pane run "$pane" "$2" >/dev/null 2>&1

        i=0
        while [ "$i" -lt 24 ]; do
            has_agent "$1" && return
            sleep 0.25
            i=$((i + 1))
        done
        n=$((n + 1))
    done
}

ensure_agents() {
    i=0
    while [ "$i" -lt 20 ]; do
        panes=$(herdr pane list 2>/dev/null) && [ -n "$panes" ] && break
        sleep 0.5
        i=$((i + 1))
    done
    [ -z "$panes" ] && return

    ensure_agent claude "$CLAUDE_BIN"                    # con foco: es lo primero que se ve
    panes=$(herdr pane list 2>/dev/null)
    ensure_agent opencode "$OPENCODE_BIN" --no-focus
}

if [ -z "$addr" ] || [ "$addr" = "null" ]; then
    setsid kitty --class "$CLASS" -e herdr >/dev/null 2>&1 9>&- &
    ensure_agents 9>&- &

    # El lock no se suelta hasta que la ventana esta mapeada; hasta entonces otro
    # SUPER+C veria addr vacio y clonaria la terminal.
    i=0
    while [ "$i" -lt 40 ]; do
        hyprctl clients -j | jq -e ".[] | select(.class==\"$CLASS\")" >/dev/null 2>&1 && break
        sleep 0.25
        i=$((i + 1))
    done
    exec 9>&-
    exit 0
fi

exec 9>&-
ensure_agents &

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

close_stash
