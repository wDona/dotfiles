#!/usr/bin/env bash
# Salta a un mes/anio concretos calculando el offset respecto a hoy.
# Uso: goto.sh <year> <month>   (month 1..12; valores fuera de rango ajustan el anio)
ty="$1"
tm="$2"
cy=$(date +%Y)
cm=$(date +%-m)
off=$(((ty - cy) * 12 + (tm - cm)))
exec "$HOME/.config/eww/scripts/nav.sh" "$off"
