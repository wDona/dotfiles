#!/bin/bash

# Si Rofi ya está abierto, lo cerramos y salimos
if pgrep -x "rofi" > /dev/null; then
    pkill -x rofi
    exit 0
fi

# Lanzar Rofi con tus parámetros preferidos
# He quitado -no-lazy-grab porque sin mover el cursor no es tan crítico
rofi -show drun -kb-cancel 'Escape,MousePrimary' -