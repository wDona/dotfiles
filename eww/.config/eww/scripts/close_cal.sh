#!/usr/bin/env bash
# Alias historico: lo llaman varios modulos de waybar y el bind de ESC.
# Hoy cierra CUALQUIER popup de la barra, no solo el calendario.
exec "$(dirname "$0")/popup.sh" close
