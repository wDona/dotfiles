# 🐧 dotfiles

Configuración personal de mi entorno Arch Linux con Hyprland. Gestinado con [GNU Stow](https://www.gnu.org/software/stow/).

## 📦 Stack

| Componente | Programa |
|---|---|
| Window Manager | Hyprland |
| Terminal | Kitty |
| Shell | Zsh + Oh My Zsh |
| Prompt | Starship |
| Bar | Waybar |
| Lanzador | Rofi |
| Notificaciones | Swaync |
| Editor | Neovim |
| Gestor de archivos | Nautilus |

## 🗂️ Estructura

```
dotfiles/
├── hypr/           # Hyprland, hyprlock, hypridle
├── kitty/          # Kitty terminal
├── waybar/         # Waybar + scripts
├── rofi/           # Rofi + powermenu
├── starship/       # Starship prompt
├── zsh/            # .zshrc
├── swaync/         # Notificaciones
├── gtk-3.0/        # Tema GTK3
├── gtk-4.0/        # Tema GTK4
├── nano/           # Nanorc
├── nwg-look/       # Configuración de apariencia GTK
├── xsettingsd/     # Xsettingsd
├── gsimplecal/     # Calendario
└── scripts/        # Scripts de instalación y utilidades
    ├── install.sh
    ├── stow-setup.sh
    ├── pacman_list.txt
    └── aur_list.txt
```

## 🚀 Instalación

### 1. Requisitos previos (Arch)

```bash
sudo pacman -S git stow
```

### 2. Clona el repositorio

```bash
git clone https://github.com/tuusuario/dotfiles.git ~/dotfiles
```

### 3. Bootstrap (paquetes + symlinks + gestion de energia)

```bash
chmod +x ~/dotfiles/bootstrap.sh
~/dotfiles/bootstrap.sh
```

Instala paquetes oficiales y AUR (`scripts/install.sh`), enlaza toda la config
con stow (`scripts/stow-setup.sh`), instala `gcalcli` (Google Calendar del
panel eww) y activa `power-profiles-daemon` si detecta bateria
(`/sys/class/power_supply/BAT*`) — el panel de bateria de eww cambia de
perfil (rendimiento/equilibrado/ahorro) via su D-Bus.

Si prefieres instalar solo lo que necesitas a mano, usa `scripts/stow-setup.sh`
y `scripts/install.sh` por separado (mismo contenido, sin activar el daemon de energia).

### 5. Instala Oh My Zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### 6. Cambia la shell a zsh

```bash
chsh -s $(which zsh)
```

## ⚙️ Plugins de Zsh (Viene en el install.sh)

| Plugin | Instalación |
|---|---|
| zsh-autosuggestions | `sudo pacman -S zsh-autosuggestions` |
| zsh-syntax-highlighting | `sudo pacman -S zsh-syntax-highlighting` |
| fzf-tab | `yay -S fzf-tab-git` |

## 🎨 Apariencia

- **Tema GTK**: Orchis Dark Purple
- **Iconos**: Papirus Dark
- **Fuente terminal**: JetBrainsMono Nerd Font
- **Cursor**: Catppuccin Mocha
- **Colores**: Catppuccin Mocha

## 📝 Notas

- Reinicia el PC al terminar la instalacion y el Stow para aplicar los cambios.
- En el .config/hypr/hyprland.conf esta puesto para usar dvorak, cambialo si lo sientes incomodo.
- El override.conf debe de estar en ~/.config/systemd/user/wireplumber.service.d/override.conf. Este archivo hace que el sonido se inicie despues de la sesion grafica, y evita tener que reiniciar el servicio de sonido manualmente para poder escuchar.
