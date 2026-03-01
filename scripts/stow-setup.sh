#!/bin/bash

# =============================================================================
# stow-setup.sh - Elimina configs existentes y hace stow de dotfiles
# Uso: ./stow-setup.sh [ruta_dotfiles]
# Ejemplo: ./stow-setup.sh ~/dotfiles
# =============================================================================

DOTFILES="${1:-$HOME/dotfiles}"

if [ ! -d "$DOTFILES" ]; then
    echo "✗ No se encuentra la carpeta dotfiles: $DOTFILES"
    exit 1
fi

echo "==> Usando dotfiles en: $DOTFILES"
echo ""

# Recorre cada paquete (carpeta) dentro de dotfiles
for package in "$DOTFILES"/*/; do
    package_name=$(basename "$package")

    # Ignora carpetas especiales
    [[ "$package_name" == "scripts" ]] && continue
    [[ "$package_name" == ".git" ]] && continue

    echo "--- Procesando paquete: $package_name ---"

    # Recorre todos los archivos del paquete
    find "$package" -not -type d | while read -r file; do
        # Obtiene la ruta relativa al paquete
        relative="${file#$package}"

        # Ruta destino en home
        target="$HOME/$relative"

        # Si existe y NO es ya un symlink, lo elimina
        if [ -e "$target" ] && [ ! -L "$target" ]; then
            echo "  -> Eliminando: $target"
            rm -rf "$target"
        elif [ -L "$target" ]; then
            echo "  -> Ya es symlink, omitiendo: $target"
        fi
    done

    # Hace stow del paquete
    echo "  -> Stowing $package_name..."
    stow --dir="$DOTFILES" --target="$HOME" "$package_name" && echo "  ✓ $package_name" || echo "  ✗ Error en $package_name"
    echo ""
done

echo "✓ Proceso completado."
