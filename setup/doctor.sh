#!/usr/bin/env bash
# =============================================================================
# doctor.sh - Comprueba que este PC tiene todo lo que los configs necesitan.
#
# bootstrap.sh deja el sistema listo; doctor.sh dice si SIGUE listo. Solo lee:
# no instala ni toca nada. Sirve tras un git pull, o cuando algo dejo de
# funcionar y no esta claro que falta.
#
# Uso:  ~/dotfiles/setup/doctor.sh          (como TU usuario, sin sudo)
# Sale con 1 si hay algun fallo, para poder encadenarlo en otros scripts.
# =============================================================================
set -uo pipefail

SETUP=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES=$(dirname "$SETUP")
fails=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; fails=$((fails + 1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
step() { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }

# -- 1. Paquetes que los configs invocan --------------------------------------
step "Paquetes requeridos (setup/deps.txt)"
missing=()
while read -r pkg; do
    pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done < <(grep -vE '^\s*(#|$)' "$SETUP/deps.txt" | awk '{print $1}')
if ((${#missing[@]})); then
    bad "faltan: ${missing[*]}"
    echo "      sudo pacman -S --needed ${missing[*]}"
else
    ok "todos instalados"
fi

step "Paquetes AUR (setup/aur.txt)"
missing=()
while read -r pkg; do
    pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done < <(grep -vE '^\s*(#|$)' "$SETUP/aur.txt" | awk '{print $1}')
if ((${#missing[@]})); then
    bad "faltan: ${missing[*]}"
    echo "      yay -S --needed ${missing[*]}"
else
    ok "todos instalados"
fi

# -- 2. Herramientas fuera de pacman ------------------------------------------
step "Herramientas fuera de pacman"
# pipx lo instala en ~/.local/bin, que no siempre esta en el PATH del script.
{ command -v gcalcli >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/gcalcli" ]]; } \
    && ok "gcalcli" || bad "gcalcli (pipx install gcalcli) - panel de calendario de eww"
while read -r pkg; do
    npm ls -g --depth=0 "$pkg" >/dev/null 2>&1 \
        && ok "npm $pkg" || bad "npm $pkg (npm install -g $pkg)"
done < <(grep -vE '^\s*(#|$)' "$SETUP/npm-global.txt")

# -- 3. Referencias rotas en los propios configs ------------------------------
# Un exec-once o un on-click que apunta a un script borrado falla en silencio:
# no hay error visible, simplemente esa tecla o ese modulo deja de responder.
step "Rutas referenciadas por los configs"
broken=0
while read -r p; do
    [[ -e "$p" ]] || { bad "referenciado pero no existe: $p"; broken=1; }
done < <(grep -rhoE '[~$][A-Za-z_{}/.]*[A-Za-z0-9_./-]*\.(sh|py)\b' "$DOTFILES" \
           --exclude-dir=.git 2>/dev/null \
         | sed "s#\${HOME}#$HOME#g; s#\$HOME#$HOME#g; s#^~#$HOME#" \
         | grep "^$HOME" | sort -u)
((broken)) || ok "todas resuelven"

# Un script sin +x colgado de un exec-once falla igual de silenciosamente.
noexec=$(find "$DOTFILES" -path '*/.git' -prune -o \
              \( -name '*.sh' -o -path '*/local-bin/.local/bin/*' \) \
              -type f ! -executable -print 2>/dev/null | wc -l)
((noexec == 0)) && ok "todos los scripts son ejecutables" \
    || bad "$noexec script(s) sin permiso +x (bootstrap.sh los arregla)"

# -- 4. Symlinks --------------------------------------------------------------
step "Enlaces de configuracion"
dangling=$(find -L "$HOME/.config" "$HOME/.local/bin" -maxdepth 3 -type l 2>/dev/null | wc -l)
((dangling == 0)) && ok "sin symlinks rotos" \
    || bad "$dangling symlink(s) rotos (ejecuta: stow -R -t \$HOME <paquete>)"

# -- 5. Servicios de usuario --------------------------------------------------
step "Servicios de usuario"
for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do
    systemctl --user is-active --quiet "$unit" \
        && ok "$unit" || bad "$unit parado"
done
# graphical-session.target no se puede arrancar a mano: lo arrastra
# hyprland-session.target desde hypr/conf.d/exec.conf. Si esta caido,
# wireplumber muere por el Requisite= de su drop-in y no hay sonido.
systemctl --user is-active --quiet graphical-session.target \
    && ok "graphical-session.target" \
    || bad "graphical-session.target caido - sin el no arranca wireplumber (no hay sonido)"

# Sin sink real solo existe "Dummy Output": el volumen se mueve pero no suena.
if command -v wpctl >/dev/null 2>&1; then
    wpctl status 2>/dev/null | grep -qE '^\s*│?\s*\*?\s*[0-9]+\..*(Analog|HDMI|USB|Digital)' \
        && ok "hay una salida de audio real" \
        || bad "solo 'Dummy Output': ninguna tarjeta de sonido activa"
fi

# -- 6. Conflictos conocidos --------------------------------------------------
step "Conflictos conocidos"
# Los dos se pelean por el governor de la CPU; el selector de perfiles de eww
# necesita ppd, el resto del tiempo manda tlp. Nunca los dos a la vez.
tlp=$(systemctl is-active tlp.service 2>/dev/null)
ppd=$(systemctl is-active power-profiles-daemon.service 2>/dev/null)
[[ $tlp == active && $ppd == active ]] \
    && bad "tlp y power-profiles-daemon activos a la vez (ver README)" \
    || ok "gestion de energia: tlp=$tlp ppd=$ppd"

printf '\n'
((fails == 0)) && printf '\033[1;32m✓ Todo en orden.\033[0m\n' \
    || printf '\033[1;31m✗ %s comprobacion(es) fallidas.\033[0m\n' "$fails"
exit $((fails > 0))
