#!/usr/bin/env bash
# Estado de internet REAL (ping), no solo iface up. Salida JSON para waybar.
ON=$'󰇧'
OFF=$'󰅤'
if ping -c1 -W1 1.1.1.1 >/dev/null 2>&1; then
    printf '{"text":"%s","class":"online","tooltip":"Internet: conectado"}\n' "$ON"
else
    printf '{"text":"%s","class":"offline","tooltip":"Internet: sin conexión"}\n' "$OFF"
fi
