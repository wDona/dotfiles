#!/usr/bin/env bash
# Toggle del menu de sistema (power + hardware + temporizador).
exec "$(dirname "$0")/popup.sh" toggle sysmenu
