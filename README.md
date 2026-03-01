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

### 3. Ejecuta el script de stow

```bash
chmod +x ~/dotfiles/scripts/stow-setup.sh
~/dotfiles/scripts/stow-setup.sh
```

El script recorre automáticamente todas las carpetas del repositorio, elimina los archivos de configuración existentes que no sean symlinks y crea los symlinks con stow.

### 4. Instala Oh My Zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### 5. Cambia la shell a zsh

```bash
chsh -s $(which zsh)
```

Reinicia la sesión y listo.

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
- El override.conf debe de estar en ~/.config/systemd/user/wireplumber.service.d/override.conf
