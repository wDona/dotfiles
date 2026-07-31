#!/bin/sh
# ALT+F4 normal, salvo sobre claude-term: ahi cierra kitty, para el server de
# herdr y limpia el stash. El estado persistido (session.json) se conserva.

# Hyprland arranca con el PATH del login, sin ~/.local/bin: sin esto `herdr`
# no se resuelve y el teardown no para nada. Ver npm-global-path-solo-zshrc.
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

CLASS=claude-term
HIDE_NAME=claudehide

active=$(hyprctl activewindow -j | jq -r '.class')

if [ "$active" != "$CLASS" ]; then
    hyprctl dispatch killactive
    exit 0
fi

LOG=/tmp/killf4.log
echo "--- $(date -Is) reset claude-term" >>"$LOG"

# Lock retenido durante todo el teardown: toggle_claude.sh espera aqui, si no un
# SUPER+C rapido levanta un server que el `herdr server stop` de abajo mata.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/herdr-reset.lock"
flock 9

# El pkill va PRIMERO: con un cliente attached, `herdr server stop` no para el
# server (falla en silencio y el siguiente SUPER+C reconecta al mismo server
# con el estado en memoria). Matar kitty desconecta al cliente.
pkill -f "kitty --class $CLASS" 2>/dev/null

i=0
while pgrep -f "kitty --class $CLASS" >/dev/null 2>&1 && [ "$i" -lt 20 ]; do
    sleep 0.25
    i=$((i + 1))
done

herdr server stop >>"$LOG" 2>&1

# El server guarda session.json justo antes de salir: hay que esperar a que
# muera para borrarlo, si no lo reescribe y el estado sobrevive al reinicio.
i=0
while pgrep -f "herdr server" >/dev/null 2>&1 && [ "$i" -lt 20 ]; do
    sleep 0.25
    i=$((i + 1))
done

# Si sigue vivo, a lo bruto. SIGTERM igual le da tiempo a reescribir
# session.json, por eso el rm va despues de confirmar que murio.
if pgrep -f "herdr server" >/dev/null 2>&1; then
    echo "server no murio con 'server stop', mandando SIGTERM" >>"$LOG"
    pkill -f "herdr server" 2>/dev/null
    i=0
    while pgrep -f "herdr server" >/dev/null 2>&1 && [ "$i" -lt 20 ]; do
        sleep 0.25
        i=$((i + 1))
    done
fi

# session.json NO se borra: los workspaces viejos se restauran al reabrir. Solo
# guardan cwd/layout (no procesos), asi que los agentes vuelven a arrancar en un
# workspace nuevo enfocado y la sesion anterior queda detras, no delante.
echo "server vivo tras reset: $(pgrep -f 'herdr server' | tr '\n' ' ')" >>"$LOG"

[ "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .specialWorkspace.name')" = "special:$HIDE_NAME" ] \
    && hyprctl dispatch togglespecialworkspace "$HIDE_NAME"

exit 0
