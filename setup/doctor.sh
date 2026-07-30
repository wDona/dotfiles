#!/usr/bin/env bash
# =============================================================================
# doctor.sh - Comprueba que este PC tiene todo lo que los configs necesitan.
#
# bootstrap.sh deja el sistema listo; doctor.sh dice si SIGUE listo. Solo lee:
# no instala ni toca nada. Sirve tras un git pull, o cuando algo dejo de
# funcionar y no esta claro que falta.
#
# Uso:  ~/dotfiles/setup/doctor.sh          (como TU usuario, sin sudo)
#       ~/dotfiles/setup/doctor.sh --fix    (idem, y ofrece arreglar cada fallo)
# Sale con 1 si hay algun fallo, para poder encadenarlo en otros scripts.
# =============================================================================
set -uo pipefail
FIX=0; [[ "${1:-}" == "--fix" ]] && FIX=1

SETUP=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DOTFILES=$(dirname "$SETUP")
fails=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
# $2 (opcional) = comando que arregla el fallo. Con --fix se pregunta antes de correrlo.
bad()  {
    printf '  \033[31m✗\033[0m %s\n' "$1"; fails=$((fails + 1))
    if ((FIX)) && [[ -n "${2:-}" ]]; then
        read -rp "      → arreglar con: $2 ? [y/N] " ans
        [[ $ans == [yY] ]] && eval "$2"
    fi
}
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
step() { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }

# -- 1. Paquetes que los configs invocan --------------------------------------
step "Paquetes requeridos (setup/deps.txt)"
missing=()
while read -r pkg; do
    pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done < <(grep -vE '^\s*(#|$)' "$SETUP/deps.txt" | awk '{print $1}')
if ((${#missing[@]})); then
    # -Syu y no -S: con la base de datos vieja pacman pide una version que el
    # mirror ya ha rotado y falla con un 404 en el .sig.
    bad "faltan: ${missing[*]}" "sudo pacman -Syu ${missing[*]}"
else
    ok "todos instalados"
fi

step "Paquetes AUR (setup/aur.txt)"
missing=()
while read -r pkg; do
    pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done < <(grep -vE '^\s*(#|$)' "$SETUP/aur.txt" | awk '{print $1}')
if ((${#missing[@]})); then
    bad "faltan: ${missing[*]}" "yay -S --needed ${missing[*]}"
else
    ok "todos instalados"
fi

# -- 2. Herramientas fuera de pacman ------------------------------------------
step "Herramientas fuera de pacman"
# pipx lo instala en ~/.local/bin, que no siempre esta en el PATH del script.
{ command -v gcalcli >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/gcalcli" ]]; } \
    && ok "gcalcli" || bad "gcalcli - panel de calendario de eww" "pipx install gcalcli"
while read -r pkg; do
    npm ls -g --depth=0 "$pkg" >/dev/null 2>&1 \
        && ok "npm $pkg" || bad "npm $pkg" "env PATH=\"$HOME/.npm-global/bin:\$PATH\" npm install -g $pkg"
done < <(grep -vE '^\s*(#|$)' "$SETUP/npm-global.txt")
# 'npm ls' solo mira que el paquete este: lean-ctx-bin baja su binario nativo en
# un postinstall, y npm >=12 lo bloquea por defecto. Sin binario el paquete
# figura instalado y todos los hooks de ~/.claude/settings.json revientan.
LEANCTX_BIN="$HOME/.npm-global/lib/node_modules/lean-ctx-bin/bin/lean-ctx"
[[ -x $LEANCTX_BIN ]] \
    && ok "binario de lean-ctx" \
    || bad "falta el binario de lean-ctx - hooks de Claude rotos" "env PATH=\"$HOME/.npm-global/bin:\$PATH\" npm install -g --allow-scripts lean-ctx-bin lean-ctx-bin"

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
    || bad "$noexec script(s) sin permiso +x" "find '$DOTFILES' -path '*/.git' -prune -o \\( -name '*.sh' -o -path '*/local-bin/.local/bin/*' \\) -type f ! -executable -exec chmod +x {} +"

# -- 4. Symlinks --------------------------------------------------------------
step "Enlaces de configuracion"
# SingletonLock/SingletonCookie (Chromium-based) y *.lock de Firefox/Zen son
# symlinks colgantes normales de apps abiertas, no algo que gestione link.sh.
dangling=$(find -L "$HOME/.config" "$HOME/.local/bin" -maxdepth 3 -type l 2>/dev/null \
    | grep -vE '/(SingletonLock|SingletonCookie|SingletonSocket|lock)$' | wc -l)
((dangling == 0)) && ok "sin symlinks rotos" \
    || bad "$dangling symlink(s) rotos" "$SETUP/link.sh"

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

# Si el keyring de login no lleva la misma contrasena que el usuario, PAM no lo
# desbloquea y Brave/VS Code/agentes vuelven a pedir la clave en cada arranque.
if systemctl --user is-active --quiet gnome-keyring-daemon.socket; then
    case $(busctl --user get-property org.freedesktop.secrets \
            /org/freedesktop/secrets/collection/login \
            org.freedesktop.Secret.Collection Locked 2>/dev/null) in
        "b false") ok "keyring de login desbloqueado" ;;
        "b true")  bad "keyring bloqueado: su contrasena no es la del usuario (ver README)" ;;
        *)         bad "no hay keyring de login (se crea en el primer login grafico)" ;;
    esac
else
    bad "gnome-keyring-daemon.socket parado"
fi

step "Bluetooth"
systemctl is-active --quiet bluetooth.service \
    && ok "bluetooth.service" \
    || bad "bluetooth.service parado - panel eww/scripts/bluetooth.sh sin datos" "sudo systemctl enable --now bluetooth"

step "Gaming"
systemctl is-active --quiet ananicy-cpp.service \
    && ok "ananicy-cpp.service" \
    || bad "ananicy-cpp.service parado" "sudo systemctl enable --now ananicy-cpp"
# Sin cachyos-ananicy-rules-git (AUR) el demonio corre pero no reordena nada.
[[ -n "$(ls -A /etc/ananicy.d 2>/dev/null)" ]] \
    && ok "reglas de ananicy presentes" \
    || bad "sin reglas en /etc/ananicy.d - ananicy-cpp no hace nada" "yay -S --needed cachyos-ananicy-rules-git"
# CPPC en la BIOS, no hay fix por software: solo se avisa (ver README).
[[ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver ]] \
    && ok "escalado de CPU: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver)" \
    || bad "sin amd_pstate - activa CPPC en la BIOS (Advanced > AMD CBS > NBIO > CPPC, ver README)"

step "Snapshots (snapper + btrfs)"
snapper list-configs 2>/dev/null | grep -q '^root ' \
    && ok "config snapper 'root'" \
    || bad "sin config snapper 'root' - / no es btrfs o falta crearlo" "sudo snapper -c root create-config /"
systemctl is-active --quiet snapper-timeline.timer \
    && ok "snapper-timeline.timer" \
    || bad "snapper-timeline.timer parado" "sudo systemctl enable --now snapper-timeline.timer"
systemctl is-active --quiet snapper-cleanup.timer \
    && ok "snapper-cleanup.timer" \
    || bad "snapper-cleanup.timer parado" "sudo systemctl enable --now snapper-cleanup.timer"
systemctl is-active --quiet grub-btrfsd.service \
    && ok "grub-btrfsd.service (snapshots en el menu de GRUB)" \
    || bad "grub-btrfsd.service parado" "sudo systemctl enable --now grub-btrfsd"

# -- 6. Conflictos conocidos --------------------------------------------------
step "Conflictos conocidos"
# Los dos se pelean por el governor de la CPU; el selector de perfiles de eww
# necesita ppd, el resto del tiempo manda tlp. Nunca los dos a la vez.
tlp=$(systemctl is-active tlp.service 2>/dev/null)
ppd=$(systemctl is-active power-profiles-daemon.service 2>/dev/null)
ppd_state=$(systemctl is-enabled power-profiles-daemon.service 2>/dev/null)
if [[ $tlp == active && $ppd_state == masked ]]; then
    ok "energia: tlp activo, ppd enmascarado"
elif [[ $tlp == failed && $ppd == active ]]; then
    # ppd se activa por D-Bus aunque este 'disabled': lo despiertan
    # battery.sh y get_profile.sh, y su Conflicts= mata tlp.
    bad "tlp muerto por ppd (Conflicts=)" "sudo systemctl mask --now power-profiles-daemon && sudo systemctl start tlp"
elif [[ $ppd == active && $tlp == active ]]; then
    bad "tlp y power-profiles-daemon activos a la vez (ver README)"
else
    ok "gestion de energia: tlp=$tlp ppd=$ppd ($ppd_state)"
fi

# powerprofile sustituye a ppd para el selector de eww y el perfil de waybar.
# Solo tiene sentido con bateria: en un sobremesa no hay perfiles que cambiar.
if ! compgen -G "/sys/class/power_supply/BAT*" >/dev/null; then
    ok "sobremesa (sin bateria): selector de energia no aplica"
elif [[ -x /usr/local/bin/powerprofile ]]; then
    ok "powerprofile instalado (perfil actual: $(/usr/local/bin/powerprofile get 2>/dev/null))"
    sudo -n /usr/local/bin/powerprofile set "$(/usr/local/bin/powerprofile get)" >/dev/null 2>&1 \
        && ok "sudo sin contrasena para powerprofile" \
        || bad "falta /etc/sudoers.d/10-powerprofile: el selector de eww no podra cambiar el perfil" "sudo cp '$SETUP/etc/sudoers.d/10-powerprofile' /etc/sudoers.d/ && sudo chown root:root /etc/sudoers.d/10-powerprofile && sudo chmod 0440 /etc/sudoers.d/10-powerprofile && sudo visudo -c"
else
    bad "/usr/local/bin/powerprofile ausente - selector de energia muerto" "sudo install -o root -g root -m 0755 '$SETUP/usr-local-bin/powerprofile' /usr/local/bin/powerprofile"
fi

printf '\n'
((fails == 0)) && printf '\033[1;32m✓ Todo en orden.\033[0m\n' \
    || printf '\033[1;31m✗ %s comprobacion(es) fallidas.\033[0m\n' "$fails"
exit $((fails > 0))
