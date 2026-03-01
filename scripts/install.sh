#!/bin/bash

# 1. Instalar yay si no existe (necesario para el AUR)
if ! command -v yay &> /dev/null; then
    echo "Instalando yay..."
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git
    cd yay && makepkg -si && cd ..
    rm -rf yay
fi

# 2. Instalar paquetes de los repositorios oficiales
echo "Instalando paquetes oficiales..."
sudo pacman -Syu --needed - < ~/dotfiles/scripts/pacman_list.txt

# 3. Instalar paquetes del AUR
echo "Instalando paquetes del AUR..."
yay -S --needed - < ~/dotfiles/scripts/aur_list.txt

echo "¡Instalación completa!"