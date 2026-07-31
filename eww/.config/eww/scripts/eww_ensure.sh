#!/usr/bin/env bash
# Arranca el daemon de eww si hace falta. flock evita que dos toggles
# a la vez (login, doble click) lancen cada uno su propio daemon.
exec 8>"${XDG_RUNTIME_DIR:-/tmp}/eww_daemon.lock"
flock 8
eww ping >/dev/null 2>&1 || { eww daemon >/dev/null 2>&1; sleep 0.4; }
