#!/usr/bin/env bash
# =============================================================================
# link.sh - Enlaza cada paquete de dotfiles dentro de $HOME (sustituye a GNU Stow).
# Cada carpeta de primer nivel es un "paquete": su arbol interno se replica tal
# cual en $HOME y cada fichero hoja se convierte en un symlink al repo.
# Uso: setup/link.sh          (como TU usuario, nunca con sudo)
# =============================================================================
set -euo pipefail

DOTFILES=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SKIP=(setup .git)

for pkg in "$DOTFILES"/*/; do
    name=$(basename "$pkg")
    [[ " ${SKIP[*]} " == *" $name "* ]] && continue

    while IFS= read -r -d '' src; do
        rel=${src#"$pkg"}
        # .gitignore propio del paquete: config del repo, no del sistema.
        [[ "$rel" == ".gitignore" ]] && continue

        dst="$HOME/$rel"

        # Ya apunta al repo: puede ser un symlink del propio fichero o de una
        # carpeta padre (asi enlazaba stow). Sin esta guarda $dst resolveria
        # DENTRO del repo y el backup de abajo se llevaria el fichero original.
        [[ -e "$dst" && "$(readlink -f "$dst")" == "$src" ]] && continue

        mkdir -p "$(dirname "$dst")"

        # Fichero real preexistente: se aparta en vez de perderse (.bkup esta
        # en .gitignore, no ensucia el repo si cae dentro de el).
        if [[ -e "$dst" && ! -L "$dst" ]]; then
            mv "$dst" "$dst.bkup"
            echo "  ~ backup: $dst.bkup"
        fi

        ln -sfn "$src" "$dst"
    done < <(find "$pkg" -type f -print0)

    echo "✓ $name"
done

# Estado local generado por hypr_tweak.sh: esta en .gitignore, asi que un clon
# limpio no lo trae y el `source` final de hyprland.conf falla al arrancar.
OVERRIDES="$HOME/.config/hypr/conf.d/overrides.conf"
if [[ ! -e "$OVERRIDES" ]]; then
    mkdir -p "$(dirname "$OVERRIDES")"
    cat > "$OVERRIDES" <<'EOF'
# Generado por hypr_tweak.sh (panel Ajustes eww). No editar a mano.
# Vacio hasta el primer `hypr_tweak.sh set`: solo existe para que el
# `source` final de hyprland.conf no falle.
EOF
    echo "✓ overrides.conf (placeholder)"
fi

echo "✓ Enlaces completos."
