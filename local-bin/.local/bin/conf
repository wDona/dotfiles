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
    [hyprlock]="$HOME/dotfiles/hypr/.config/hypr/hyprlock.conf"
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
    [eww]="$HOME/dotfiles/eww/.config/eww"
    [swayosd]="$HOME/dotfiles/swayosd/.config/swayosd"
    [dotfiles]="$HOME/dotfiles"
)

CUSTOM_CONF_FILE="$HOME/.config/custom_confs"

load_custom_confs() {
    if [ -f "$CUSTOM_CONF_FILE" ]; then
        while IFS='|' read -r alias path; do
            [ -z "$alias" ] && continue
            CONFIGS["$alias"]="$path"
        done < "$CUSTOM_CONF_FILE"
    fi
}

load_custom_confs

# Help
show_help() {
    echo "Uso: conf [programa]"
    echo ""
    echo "Opciones:"
    echo "  -h, --help    Muestra esta ayuda"
    echo "  --list        Output JSON de todas las configuraciones"
    echo ""
    echo "Programas disponibles:"
    for key in $(echo "${!CONFIGS[@]}" | tr ' ' '\n' | sort); do
        echo "  $key"
    done
}

# Sin argumentos, muestra los disponibles
if [ -z "$1" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Output JSON para eww/integración
if [ "$1" = "--list" ]; then
    echo "{"
    first=1
    for key in $(echo "${!CONFIGS[@]}" | tr ' ' '\n' | sort); do
        [ $first -eq 0 ] && echo ","
        echo -n "  \"$key\": \"${CONFIGS[$key]}\""
        first=0
    done
    echo ""
    echo "}"
    exit 0
fi

TARGET="${CONFIGS[$1]}"

if [ -z "$TARGET" ]; then
    echo "✗ '$1' no encontrado. Ejecuta 'conf' sin argumentos para ver los disponibles."
    exit 1
fi

if [ ! -e "$TARGET" ]; then
    echo "✗ La ruta no existe: $TARGET"
    exit 1
fi

code "$TARGET"

