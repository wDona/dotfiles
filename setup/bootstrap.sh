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

# Con una linea lenta, pacman aborta la transaccion entera ("Operation too
# slow") si una descarga baja de 1 byte/s 10 segundos seguidos. En un -Syu de
# 1 GB con kernel y jdk eso pasa constantemente y no se llega a instalar nada.
if ! grep -q '^DisableDownloadTimeout' /etc/pacman.conf; then
    sed -i '/^\[options\]/a DisableDownloadTimeout' /etc/pacman.conf
fi

# -- 2. Paquetes oficiales ---------------------------------------------------
step "Paquetes oficiales (pacman)"
# deps.txt = lo que los configs ejecutan de verdad (obligatorio).
# packages.txt = volcado de pacman -Qqen, el resto del entorno (comodidad).
grep -vE '^\s*(#|$)' "$SETUP/deps.txt" | awk '{print $1}' \
    | pacman -Syu --needed --noconfirm -
pacman -S --needed --noconfirm - < "$SETUP/packages.txt"

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
# sudo ignora (y avisa de) cualquier fichero de sudoers.d que no sea 0440 root:root.
chown root:root /etc/sudoers.d/*; chmod 0440 /etc/sudoers.d/*
# Un sudoers roto deja el sistema sin sudo: mejor enterarse aqui que al reiniciar.
visudo -c >/dev/null || { echo "✗ /etc/sudoers.d invalido" >&2; exit 1; }

# powerprofile: perfiles de energia sin ppd (ver seccion 9). Va a /usr/local/bin
# como root porque /etc/sudoers.d/10-powerprofile apunta ahi.
install -o root -g root -m 0755 "$SETUP/usr-local-bin/powerprofile" /usr/local/bin/powerprofile

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
# npm >=12 bloquea los postinstall por defecto. lean-ctx-bin descarga ahi su
# binario nativo: sin el, el paquete queda instalado pero vacio y todos los
# hooks de lean-ctx de ~/.claude/settings.json fallan con "No such file".
#
# --allow-scripts solo vale para esta instalacion. La aprobacion permanente va
# en ~/package.json (npm la guarda por proyecto, y $HOME cuenta como uno);
# --no-allow-scripts-pin la deja sin version, si no cada actualizacion de
# lean-ctx vuelve a quedarse sin binario. || true: npm <12 no conoce el
# subcomando y no es motivo para abortar el bootstrap.
asuser env PATH="$USER_HOME/.npm-global/bin:$PATH" \
    npm install -g --allow-scripts lean-ctx-bin "${npm_pkgs[@]}"
asuser bash -c 'cd "$HOME" && npm install-scripts approve lean-ctx-bin \
    --no-allow-scripts-pin' || true

command -v uv >/dev/null 2>&1 || \
    asuser sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
[[ -e "$USER_HOME/.local/bin/claude" ]] || \
    asuser bash -c 'curl -fsSL https://claude.ai/install.sh | bash'

# -- 9. Energia --------------------------------------------------------------
# tlp gestiona la energia (activado arriba). power-profiles-daemon lleva
# Conflicts=tlp.service: en cuanto arranca, systemd mata tlp.
#
# No basta con 'disable': ppd tiene activacion por D-Bus
# (net.hadess.PowerProfiles), y los propios widgets de este repo lo despiertan
# solos: waybar/scripts/battery.sh y eww/scripts/get_profile.sh consultan ese
# bus en cada refresco. Resultado con 'disable' a secas: tlp arranca al boot y
# muere por SIGTERM segundos despues, en cuanto pinta la barra. 'mask' es lo
# unico que corta tambien la activacion por D-Bus.
#
# Para usar el selector de perfiles de eww en vez de tlp:
#   sudo systemctl unmask --now power-profiles-daemon
#   sudo systemctl disable --now tlp
step "Energia (tlp manda; ppd enmascarado)"
systemctl mask --now power-profiles-daemon.service 2>/dev/null || true

# -- 10. Verificacion --------------------------------------------------------
# doctor.sh sale con 1 si algo falla y aqui hay set -e: || true para que el
# resumen de abajo se imprima igual.
#
# XDG_RUNTIME_DIR: sudo lo borra del entorno, y sin el 'systemctl --user' de
# doctor no encuentra el bus y da por parados todos los servicios de usuario.
# Aun asi, en un PC recien instalado no hay sesion viva: esas comprobaciones
# (audio, keyring) fallan hasta el primer login grafico. Es esperado.
step "Verificacion (doctor.sh)"
asuser env XDG_RUNTIME_DIR="/run/user/$USER_UID" "$SETUP/doctor.sh" || true

printf '\n\033[1;32m✓ Bootstrap completo.\033[0m Reinicia y luego solo queda iniciar sesion:\n'
cat <<'EOF'
  - gcalcli init            (Google Calendar del panel de eww)
  - claude / opencode       (login de los agentes)
  - Brave, VS Code          (sync de cuenta)
  - El keyring se crea al primer login grafico: pon la MISMA contrasena que la
    del usuario y SDDM lo desbloquea solo via PAM.
EOF
