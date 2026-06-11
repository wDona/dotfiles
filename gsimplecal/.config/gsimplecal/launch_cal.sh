#!/bin/bash

# 1. Matar instancias previas si existen (efecto toggle)
if pgrep -x "gsimplecal" > /dev/null; then
    pkill -x "gsimplecal"
    exit 0
fi

# 2. Tamaño via fuente (config) en lugar de GDK_DPI_SCALE fraccionario,
# que descentra el numero del dia dentro de la celda.

# Tema morado custom aislado (CSS en _gtktheme/gtk-3.0/gtk.css)
# Usamos un XDG_CONFIG_HOME propio para no afectar al resto de apps GTK.
export XDG_CONFIG_HOME="$HOME/.config/gsimplecal/_gtktheme"
export GTK_APPLICATION_PREFER_DARK_THEME=1

gsimplecal &

# 3. Esperar un momento a que se abra y asegurar el cierre al perder foco
# (Esto es un refuerzo para el archivo de config)
sleep 0.2