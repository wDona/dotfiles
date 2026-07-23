#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh - Setup completo en un PC nuevo: paquetes + symlinks + bateria.
# Uso: chmod +x ~/dotfiles/bootstrap.sh && ~/dotfiles/bootstrap.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

./scripts/install.sh
./scripts/stow-setup.sh "$PWD"

# Symlinks apuntan al repo: cualquier script sin +x en git (o pisado por un
# editor) rompe silenciosamente los exec-once/on-click que lo llaman directo.
find "$PWD" -path '*/.git' -prune -o -path '*/scripts/*' -type f -not -name '*.txt' -print0 \
    | xargs -0 chmod +x

# gcalcli (Google Calendar del panel eww) via pipx, no esta en los repos
command -v pipx >/dev/null 2>&1 && pipx install --force gcalcli

# power-profiles-daemon: el panel de bateria de eww (rendimiento/equilibrado/
# ahorro) depende de su D-Bus. NO usar TLP a la vez (conflicto de governor).
# Solo se activa/tiene sentido con bateria (portatil); en sobremesa se deja
# como venga el sistema.
if compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
    echo "==> Bateria detectada: activando power-profiles-daemon"
    sudo systemctl enable --now power-profiles-daemon.service
fi

echo "✓ Bootstrap completo. Reinicia sesion para aplicar todo."
