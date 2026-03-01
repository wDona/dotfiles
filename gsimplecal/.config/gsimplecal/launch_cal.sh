#!/bin/bash

# 1. Matar instancias previas si existen (efecto toggle)
if pgrep -x "gsimplecal" > /dev/null; then
    pkill -x "gsimplecal"
    exit 0
fi

# 2. Lanzar con escala de interfaz (2 = doble de grande, 1.5 = un poco más grande)
# Ajusta GDK_SCALE según tu preferencia
export GDK_DPI_SCALE=1.5
gsimplecal &

# 3. Esperar un momento a que se abra y asegurar el cierre al perder foco
# (Esto es un refuerzo para el archivo de config)
sleep 0.2