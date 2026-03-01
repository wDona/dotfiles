#!/bin/bash

# =============================================================================
# stow-setup.sh - Elimina configs existentes y hace stow de dotfiles
# Uso: ./stow-setup.sh [ruta_dotfiles]
# Ejemplo: ./stow-setup.sh ~/dotfiles
# =============================================================================

DOTFILES="${1:-$HOME/dotfiles}"

# Carpetas a ignorar (no son paquetes stow)
IGNORE=("scripts" "systemd" ".git")

if [ ! -d "$DOTFILES" ]; then
    echo "✗ No se encuentra la carpeta dotfiles: $DOTFILES"
    exit 1
fi

echo "==> Usando dotfiles en: $DOTFILES"
echo ""

for package in "$DOTFILES"/*/; do
    package_name=$(basename "$package")

    # Ignora carpetas especiales
    if [[ " ${IGNORE[@]} " =~ " ${package_name} " ]]; then
        echo "--- Ignorando paquete: $package_name ---"
        echo ""
        continue
    fi

    echo "--- Procesando paquete: $package_name ---"

    find "$package" -not -type d | while read -r file; do
        relative="${file#$package}"
        target="$HOME/$relative"

        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo "  -> Eliminando: $target"
            rm -rf "$target"
        elif [ -L "$target" ]; then
            echo "  -> Ya es symlink, omitiendo: $target"
        fi
    done

    stow --dir="$DOTFILES" --target="$HOME" "$package_name" && echo "  ✓ $package_name" || echo "  ✗ Error en $package_name"
    echo ""
done

echo "✓ Proceso completado."