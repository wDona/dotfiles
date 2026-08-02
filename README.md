# 🐧 dotfiles

Entorno Arch Linux + Hyprland completo. Un solo comando lo reconstruye entero
sobre un Arch recien instalado; despues solo queda iniciar sesion en las cuentas.

## 🚀 Instalacion

Punto de partida: Arch instalado y con red (particiones, `base`/`base-devel`,
kernel y drivers ya hechos). Desde ahi:

```bash
sudo pacman -S --needed git
git clone https://github.com/tuusuario/dotfiles.git ~/dotfiles
sudo ~/dotfiles/setup/bootstrap.sh
```

Reinicia. Lo unico que queda a mano:

| Que | Como |
|---|---|
| Google Calendar (panel eww) | `gcalcli init` |
| Agentes IA | `claude`, `opencode` |
| Zen / VS Code | login de cuenta (uBlock + Bitwarden ya vienen instalados) |
| Keyring | se crea en el primer login grafico: **misma contrasena que el usuario** |

### Que hace `setup/bootstrap.sh`

1. Activa `multilib` en `pacman.conf` (hace falta para `lib32-mesa`).
2. Instala todo `setup/packages.txt` (repos oficiales).
3. Instala `yay` si no esta y con el todo `setup/aur.txt` (AUR).
4. Mete al usuario en `wheel video storage power`, pone `zsh` como shell e
   instala Oh My Zsh (respetando el `.zshrc` del repo).
5. Enlaza los dotfiles (`setup/link.sh`) y da `+x` a todos los scripts.
6. Copia `setup/etc/` a `/etc/`: config de SDDM (wayland + dvorak + tema),
   PAM de SDDM (keyring) y `vconsole.conf`.
7. Activa servicios: `NetworkManager`, `sddm`, `tlp`, `bluetooth`, `ananicy-cpp`,
   `grub-btrfsd`, timers de `snapper` (crea el config `root` si falta) y, de usuario,
   pipewire/wireplumber, `gnome-keyring-daemon.socket`, `p11-kit-server.socket`.
8. Instala lo que no esta en pacman: `gcalcli` (pipx), los globales de npm
   (`setup/npm-global.txt`), `uv` y Claude Code.

Es idempotente: puedes relanzarlo sin romper nada. Los ficheros reales que
estorben a un symlink se apartan como `.bkup` en vez de borrarse.

> ⚠️ Durante la ejecucion crea `/etc/sudoers.d/00-dotfiles-bootstrap` con
> NOPASSWD temporal (`makepkg` y `yay` no corren como root y llaman a `sudo`
> por su cuenta). Se borra siempre al terminar, incluso si el script falla.

### Verificar / arreglar: `setup/doctor.sh`

```bash
~/dotfiles/setup/doctor.sh          # solo comprueba
~/dotfiles/setup/doctor.sh --fix    # comprueba y, por cada fallo, ofrece arreglarlo (pregunta antes de tocar nada)
```

Sirve tras un `git pull` o cuando algo dejo de funcionar. Repasa paquetes
(`deps.txt`/`aur.txt`), herramientas fuera de pacman, symlinks, servicios,
conflictos conocidos (tlp/ppd) y los logins manuales de la tabla de arriba
(gcalcli, claude, opencode, credencial de push a GitHub). Lo que necesita
contrasena o sesion grafica (keyring, audio, servicios de usuario) solo lo
avisa, no lo arregla solo.

## 🔐 Keyring (gnome-keyring + SDDM + PAM)

`setup/etc/pam.d/sddm` trae los ganchos `pam_gnome_keyring.so` en `auth`,
`password` y `session`, y el bootstrap activa `gnome-keyring-daemon.socket`.
Con eso, si el keyring de login lleva **la misma contrasena que el usuario**,
SDDM lo desbloquea al iniciar sesion y ni Zen ni VS Code ni los agentes
vuelven a pedir la clave.

Si alguna vez se desincroniza (cambiaste la contrasena del usuario), abre
`seahorse` sobre el keyring *Login* y cambiale la contrasena a la nueva, o
borra `~/.local/share/keyrings/login.keyring` para que se cree de cero.

## 🔋 Energia

`tlp` es el que gestiona la energia. `power-profiles-daemon` se instala pero
queda **parado a proposito**: los dos a la vez se pelean por el governor de la
CPU. El selector de perfiles del panel de eww habla por D-Bus con ppd, asi que
solo funciona si haces el cambio:

```bash
sudo systemctl disable --now tlp
sudo systemctl enable --now power-profiles-daemon
```

## 🎮 Gaming / rendimiento

Hardware: Ryzen 7 5700X + RX 7800 XT (RADV), 32 GB RAM, `linux-lts`.

- `gamemode` + `lib32-gamemode`: Steam lo activa solo por juego.
- `mangohud` + `lib32-mangohud`: overlay de FPS/frametime/1% low, config en
  `MangoHud/.config/MangoHud/MangoHud.conf` (toggle `Shift_R+F12`).
- `gamescope`: compositor para forzar resolucion/FPS por juego cuando hace falta.
- VRR activo en el monitor principal (DP-2, 1920x1080 @ 239.96 Hz); los otros
  dos van a ~60 Hz sin VRR, es normal.
- `scx-scheds` esta instalado pero **sin usar**: el paquete de Arch no trae
  unidad systemd (`scx_loader.service` no existe), solo binarios sueltos.
  Se descarto activarlo.
- `cachyos-ananicy-rules-git` (AUR) da las reglas a `ananicy-cpp`; sin ellas
  el demonio no hace nada (`ananicy-cpp-rules` no existe en repos oficiales).

> ⚠️ **Pendiente en la BIOS:** CPPC desactivado. Sin el, el kernel no gestiona
> frecuencias (`/sys/devices/system/cpu/cpu0/cpufreq/` no existe, sin
> `amd_pstate`) y `gamemode` no puede fijar gobernador `performance` porque no
> hay ninguno. Es el mayor pendiente para los 1% low. Activar en
> `Advanced → AMD CBS → NBIO → CPPC = Enabled`. Verificar despues:
> `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver` (deberia decir
> `amd-pstate-epp`).

## 📸 Snapshots (snapper + btrfs)

Detectado por `findmnt -no FSTYPE /` en tiempo de bootstrap: si `/` es btrfs
se instala y activa todo lo de abajo; si no, ni se instalan los paquetes ni
aparece esta seccion en `doctor.sh`.

- `snapper` con config `root`, snapshot automatico antes/despues de cada
  transaccion de pacman (via `snap-pac`) mas timers `snapper-timeline` (cada
  hora) y `snapper-cleanup` (purga los viejos).
- `grub-btrfsd`: regenera el menu de GRUB con una entrada por snapshot, para
  arrancar directamente desde uno si algo rompe.

```bash
snapper list                    # ver snapshots
sudo snapper rollback <numero>  # revertir (pide reiniciar)
```

## 🗂️ Estructura

Cada carpeta de primer nivel es un paquete: su arbol interno se replica en
`$HOME` y cada fichero hoja se enlaza al repo (mismo modelo que GNU Stow, pero
sin la dependencia — lo hace `setup/link.sh`).

```
dotfiles/
├── setup/          # bootstrap.sh, link.sh, listas de paquetes, /etc
│   ├── bootstrap.sh
│   ├── link.sh
│   ├── packages.txt      # pacman -Qqen
│   ├── aur.txt           # pacman -Qqem
│   ├── npm-global.txt
│   └── etc/              # se copia tal cual a /etc
├── hypr/           # Hyprland, hyprlock, hypridle + scripts
├── eww/            # panel/dashboard, calendario, bateria, notas
├── waybar/         # barra + scripts
├── kitty/  rofi/  swaync/  swayosd/  starship/  zsh/  nano/
├── gtk-3.0/  gtk-4.0/  nwg-look/  xsettingsd/  gsimplecal/
├── local-bin/      # ~/.local/bin: conf, addconf, ocr-screen, osd-vol...
└── systemd/        # unidades de usuario (override de wireplumber)
```

### Anadir un paquete nuevo

Crea la carpeta replicando la ruta desde `$HOME` y relanza `setup/link.sh`:

```bash
mkdir -p ~/dotfiles/mpv/.config/mpv
mv ~/.config/mpv/mpv.conf ~/dotfiles/mpv/.config/mpv/
~/dotfiles/setup/link.sh
```

### Refrescar las listas de paquetes

```bash
pacman -Qqen > ~/dotfiles/setup/packages.txt
pacman -Qqem > ~/dotfiles/setup/aur.txt
```

## 🧰 Comando `conf`

`conf <alias>` abre la config de un programa en VS Code; `addconf <alias> <ruta>`
registra rutas nuevas en `~/.config/custom_confs`. Los dos viven en
`local-bin/` y el panel de eww los usa para el menu de configuraciones.

## 📦 Stack

| Componente | Programa |
|---|---|
| Window Manager | Hyprland |
| Display Manager | SDDM (tema astronaut, wayland, dvorak) |
| Terminal | Kitty |
| Shell | Zsh + Oh My Zsh + Starship |
| Barra / Widgets | Waybar + eww |
| Lanzador | Rofi |
| Notificaciones | Swaync + SwayOSD |
| Ficheros | Nautilus / Thunar |
| Editor | VS Code, nano |

## 🎨 Apariencia

- **Tema GTK**: Orchis
- **Iconos**: Papirus / Tela Circle
- **Cursor**: Catppuccin Mocha Mauve
- **Fuente**: JetBrainsMono Nerd Font

## ⌨️ Shortcuts (Hyprland)

Definidos en `hypr/.config/hypr/conf.d/keybinds.conf`. Teclado dvorak.

| Tecla | Accion |
|---|---|
| `SUPER T` | Terminal (kitty) |
| `ALT F4` | Cerrar ventana activa |
| `SUPER F12` | Cerrar sesion |
| `SUPER E` | Explorador de archivos (nautilus) |
| `SUPER SUPER_L` (soltar) | Abridor de apps (rofi) |
| `SUPER B` | Zen browser |
| `SUPER V` | Discord |
| `SUPER S` | Spotify |
| `SUPER G` | Teamspeak / togglegroup (agrupar ventanas) |
| `SUPER SHIFT G` | Sacar ventana del grupo |
| `SUPER CTRL Tab` / `SUPER CTRL SHIFT Tab` | Siguiente / anterior pestaña del grupo |
| `SUPER F1` / `SUPER F2` | Cambiar idioma teclado / disposicion (EN-ES, QWERTY-DVORAK) |
| `SUPER W` | Launcher URL Zen con historial |
| `SUPER H` | Marcar notificaciones como leidas |
| `SUPER F11` | Pantalla completa |
| `CTRL ALT` + flechas | Mover ventana dentro del monitor |
| `CTRL ALT SHIFT` + flechas | Mover ventana a otro monitor |
| `SUPER ALT` izq/der | Mover workspace entero a otro monitor |
| `SUPER Space` | Toggle flotante |
| `SUPER Up` / `SUPER Down` | Maximizar (special fullscreen) / salir de maximizado |
| `SUPER 1-6` | Ir a workspace 1-6 |
| `` SUPER ` `` | Ir a workspace special |
| `SUPER 0` | Ir a workspace fijo (4788887) |
| `SUPER izq/der` | Recorrer workspaces dinamicos del monitor |
| `SUPER SHIFT` izq/der | Mandar ventana a siguiente/anterior workspace dinamico (sin seguir) |
| `SUPER CTRL` izq/der | Mandar ventana a siguiente/anterior workspace dinamico (siguiendola) |
| `SUPER A` | Crear/ir al siguiente workspace libre (>=7) |
| `SUPER CTRL A` | Nuevo workspace y seguir la ventana |
| `SUPER SHIFT A` | Mandar ventana a nuevo workspace, quedarte donde estas |
| `SUPER C` | Toggle Claude Code (terminal desplegable) |
| `ALT F5` | Reset de esa sesion: cierra todo y el proximo `SUPER C` abre claude y opencode desde cero |
| `SUPER SHIFT 1-6` | Mandar ventana a workspace 1-6 (sin seguir) |
| `CTRL SUPER 1-6` | Mandar ventana a workspace 1-6 (siguiendola) |
| `XF86AudioPlay/Next/Prev` | Control reproductor (playerctl) |
| `XF86AudioRaiseVolume/LowerVolume/Mute` | Volumen (SwayOSD) |
| `ALT Tab` | Switcher de ventanas |
| `SUPER O` | OCR de region seleccionada -> portapapeles |
| `SUPER D` | Toggle dashboard eww |
| `Print` | Captura de area -> editor swappy |
| `SHIFT Print` | Captura de pantalla completa -> portapapeles |
| `CTRL SHIFT S` | Guardar clip con notificacion |
| `SUPER L` | Bloquear pantalla |
| `SUPER + arrastrar / SUPER + click der arrastrar` | Mover / redimensionar ventana con raton |
| `SUPER N` | Overlay "BRB" (pantalla vuelvo en X). En el menu: `Enter` encola un temporizador (`10 café`), `Shift+Enter` arranca la cola, `Alt+Supr` borra del historial. Se encadenan en orden: pasados arriba, el que corre en grande, pendientes debajo |
| `SUPER SHIFT N` | BRB rapido, 5 min |
| `XF86MonBrightnessUp/Down` | Brillo |

## 📝 Notas

- El teclado esta en **dvorak** (`/etc/vconsole.conf`, `sddm.conf.d` y
  `hyprland.conf`). Cambialo en los tres sitios si no lo quieres.
- `override.conf` (paquete `systemd/`) retrasa wireplumber hasta que hay sesion
  grafica; sin el hay que reiniciar el servicio de audio a mano tras el login.
- Tras una actualizacion de `sddm` puede aparecer `/etc/pam.d/sddm.pacnew`:
  el bootstrap sobrescribe ese fichero con la version del repo.
