#!/bin/bash

# =============================================================================
# conf.sh - Abre la configuración de un programa con VS Code
# Uso: conf.sh [programa]
# Ejemplo: conf.sh waybar
# =============================================================================

declare -A CONFIGS=(
    [waybar]="$HOME/dotfiles/waybar/.config/waybar"
    [hypr]="$HOME/dotfiles/hypr/.config/hypr"
    [hyprland]="$HOME/dotfiles/hypr/.config/hypr"
    [kitty]="$HOME/dotfiles/kitty/.config/kitty"
    [starship]="$HOME/dotfiles/starship/.config/starship"
    [zsh]="$HOME/dotfiles/zsh/.zshrc"
    [rofi]="$HOME/dotfiles/rofi/.config/rofi"
    [swaync]="$HOME/dotfiles/swaync/.config/swaync"
    [gtk3]="$HOME/dotfiles/gtk-3.0/.config/gtk-3.0"
    [gtk4]="$HOME/dotfiles/gtk-4.0/.config/gtk-4.0"
    [nano]="$HOME/dotfiles/nano/.nanorc"
    [gsimplecal]="$HOME/dotfiles/gsimplecal/.config/gsimplecal"
    [xsettingsd]="$HOME/dotfiles/xsettingsd/.config/xsettingsd"
    [nwg-look]="$HOME/dotfiles/nwg-look/.config/nwg-look"
    [dotfiles]="$HOME/dotfiles"
)

# Sin argumentos, muestra los disponibles
if [ -z "$1" ]; then
    echo "Uso: conf.sh [programa]"
    echo ""
    echo "Programas disponibles:"
    for key in $(echo "${!CONFIGS[@]}" | tr ' ' '\n' | sort); do
        echo "  $key"
    done
    exit 0
fi

TARGET="${CONFIGS[$1]}"

if [ -z "$TARGET" ]; then
    echo "✗ '$1' no encontrado. Ejecuta 'conf.sh' sin argumentos para ver los disponibles."
    exit 1
fi

if [ ! -e "$TARGET" ]; then
    echo "✗ La ruta no existe: $TARGET"
    exit 1
fi

code "$TARGET"

