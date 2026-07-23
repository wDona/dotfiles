#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# 1. Instalar yay si no existe (necesario para el AUR)
if ! command -v yay &> /dev/null; then
    echo "Instalando yay..."
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git
    cd yay && makepkg -si && cd ..
    rm -rf yay
fi

# 2. Elegir e instalar paquetes de los repositorios oficiales (TUI checklist,
# todo pre-marcado; desmarca lo que no quieras en este PC).
mapfile -t pac_sel < <(./select_pkgs.sh pacman_list.txt "Paquetes oficiales (pacman)")
if [ ${#pac_sel[@]} -gt 0 ]; then
    echo "Instalando paquetes oficiales..."
    sudo pacman -Syu --needed "${pac_sel[@]}"
else
    echo "Ningun paquete oficial seleccionado, salto."
fi

# 3. Elegir e instalar paquetes del AUR
mapfile -t aur_sel < <(./select_pkgs.sh aur_list.txt "Paquetes AUR (yay)")
if [ ${#aur_sel[@]} -gt 0 ]; then
    echo "Instalando paquetes del AUR..."
    yay -S --needed "${aur_sel[@]}"
else
    echo "Ningun paquete AUR seleccionado, salto."
fi

echo "¡Instalación completa!"