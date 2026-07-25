#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh - Replica este entorno en un Arch recien instalado.
#
# Da por hecho que ya existen: particiones, base/base-devel, kernel, drivers y
# red funcionando. A partir de ahi deja el PC listo: solo queda iniciar sesion
# en las cuentas (Google/gcalcli, Brave, VS Code, Claude, etc.).
#
# Uso:  sudo ~/dotfiles/setup/bootstrap.sh
# =============================================================================
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "✗ Ejecutalo con sudo: sudo $0" >&2; exit 1; }
[[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] || {
    echo "✗ Usa 'sudo' desde tu usuario normal, no una shell de root." >&2; exit 1; }

SETUP=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES=$(dirname "$SETUP")
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
USER_UID=$(id -u "$SUDO_USER")

asuser()  { sudo -u "$SUDO_USER" -H "$@"; }
userctl() { asuser env XDG_RUNTIME_DIR="/run/user/$USER_UID" systemctl --user "$@"; }
step()    { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }

# yay y makepkg no pueden correr como root y llaman a sudo por su cuenta: sin
# esto el script se para a pedir contrasena a mitad. Se retira siempre al salir.
SUDOERS_TMP=/etc/sudoers.d/00-dotfiles-bootstrap
cleanup() { rm -f "$SUDOERS_TMP"; }
trap cleanup EXIT
printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$SUDO_USER" > "$SUDOERS_TMP"
chmod 440 "$SUDOERS_TMP"

# -- 1. Repos ----------------------------------------------------------------
step "Repositorios (multilib para lib32-mesa)"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
fi

# -- 2. Paquetes oficiales ---------------------------------------------------
step "Paquetes oficiales (pacman)"
pacman -Syu --needed --noconfirm - < "$SETUP/packages.txt"

# -- 3. yay + AUR ------------------------------------------------------------
step "yay (helper de AUR)"
if ! command -v yay >/dev/null 2>&1; then
    tmp=$(asuser mktemp -d)
    asuser git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    asuser bash -c "cd '$tmp/yay-bin' && makepkg -s --noconfirm"
    pacman -U --noconfirm "$tmp"/yay-bin/*.pkg.tar.zst
    rm -rf "$tmp"
fi

step "Paquetes AUR"
asuser yay -S --needed --noconfirm - < "$SETUP/aur.txt"

# -- 4. Usuario: grupos y shell ----------------------------------------------
step "Grupos y shell del usuario"
usermod -aG wheel,video,storage,power "$SUDO_USER"
chsh -s /usr/bin/zsh "$SUDO_USER"

if [[ ! -d "$USER_HOME/.oh-my-zsh" ]]; then
    # KEEP_ZSHRC: nuestro .zshrc es un symlink al repo, el instalador no debe tocarlo.
    asuser env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# -- 5. Dotfiles -------------------------------------------------------------
step "Enlaces de configuracion"
asuser "$SETUP/link.sh"

# Los symlinks apuntan al repo: un script sin +x en git rompe en silencio el
# exec-once / on-click que lo llama directo.
find "$DOTFILES" -path '*/.git' -prune -o \
     \( -name '*.sh' -o -name '*.py' -o -path '*/local-bin/.local/bin/*' \) \
     -type f -print0 | xargs -0 chmod +x

# -- 6. Configuracion de sistema (/etc) --------------------------------------
step "Configuracion de sistema (/etc)"
# sddm.conf.d (wayland + dvorak + tema), pam.d/sddm (keyring) y vconsole.
cp -a "$SETUP/etc/." /etc/

# -- 7. Servicios ------------------------------------------------------------
step "Servicios del sistema"
systemctl enable NetworkManager.service sddm.service tlp.service

step "Servicios de usuario (audio, keyring)"
UNITS=(pipewire.socket pipewire-pulse.socket wireplumber.service
       gnome-keyring-daemon.socket p11-kit-server.socket xdg-user-dirs.service)
if [[ -S /run/user/$USER_UID/bus ]]; then
    userctl enable "${UNITS[@]}"
else
    # Sin sesion de usuario viva no hay bus al que hablar: se activan para todos.
    systemctl --global enable "${UNITS[@]}"
fi

# -- 8. Herramientas de usuario fuera de pacman ------------------------------
step "Herramientas de usuario (pipx, npm, uv, claude)"
# gcalcli: Google Calendar del panel de eww. No esta en los repos.
asuser pipx install --force gcalcli

asuser npm config set prefix "$USER_HOME/.npm-global"
mapfile -t npm_pkgs < <(grep -vE '^\s*(#|$)' "$SETUP/npm-global.txt")
asuser env PATH="$USER_HOME/.npm-global/bin:$PATH" npm install -g "${npm_pkgs[@]}"

command -v uv >/dev/null 2>&1 || \
    asuser sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
[[ -e "$USER_HOME/.local/bin/claude" ]] || \
    asuser bash -c 'curl -fsSL https://claude.ai/install.sh | bash'

# -- 9. Energia --------------------------------------------------------------
# tlp gestiona la energia (activado arriba). power-profiles-daemon se instala
# pero queda parado: los dos a la vez se pelean por el governor de la CPU.
# Para usar el selector de perfiles de eww: desactivar tlp y activar ppd.
step "Energia"
systemctl disable --now power-profiles-daemon.service 2>/dev/null || true

printf '\n\033[1;32m✓ Bootstrap completo.\033[0m Reinicia y luego solo queda iniciar sesion:\n'
cat <<'EOF'
  - gcalcli init            (Google Calendar del panel de eww)
  - claude / opencode       (login de los agentes)
  - Brave, VS Code          (sync de cuenta)
  - El keyring se crea al primer login grafico: pon la MISMA contrasena que la
    del usuario y SDDM lo desbloquea solo via PAM.
EOF
