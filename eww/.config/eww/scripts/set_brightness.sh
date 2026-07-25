#!/usr/bin/env bash
# Ajusta el brillo (%) desde el slider del panel Hardware. Requiere brightnessctl
# (escribe /sys/class/backlight via udev/setuid helper, el usuario normal no puede
# escribir ahi directamente).
pct="${1%.*}"
[ -z "$pct" ] && exit 0
[ "$pct" -lt 1 ] && pct=1
command -v brightnessctl >/dev/null 2>&1 && brightnessctl set "${pct}%" -q
