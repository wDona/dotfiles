#!/usr/bin/env bash
# select_pkgs.sh - Checklist TUI (whiptail) para elegir que paquetes de una
# lista instalar. Primero eliges si arranca todo marcado o todo desmarcado
# (botones Si/No, marca/desmarca todo de golpe), luego ajustas a mano.
# Uso: select_pkgs.sh <lista.txt> <titulo>   -> imprime los elegidos, uno por linea.
set -euo pipefail
list="$1"
title="${2:-Selecciona paquetes}"

mapfile -t pkgs < <(grep -v '^\s*$' "$list")

default="ON"
whiptail --title "$title" --yesno \
    "¿Empezar con TODO marcado? (No = todo desmarcado, marcas solo lo que quieras)" \
    9 60 --yes-button "Todo ON" --no-button "Todo OFF" \
    || default="OFF"

args=()
for p in "${pkgs[@]}"; do
    args+=("$p" "" "$default")
done

whiptail --title "$title" --separate-output --checklist \
    "Espacio = marcar/desmarcar, Enter = confirmar." \
    24 60 15 "${args[@]}" \
    3>&1 1>&2 2>&3 || true   # Cancel -> salir limpio (0 elegidos), sin morir por set -e
