#!/usr/bin/env bash
# Entorno comun para los scripts del calendario.
# eww lo lanza Hyprland SIN ~/.local/bin en PATH -> gcalcli (instalado por pipx
# en ~/.local/bin) queda invisible y los scripts fallan mudos. Sourcear esto al
# inicio de cualquier script que invoque gcalcli.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;                 # ya esta, no duplicar
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
