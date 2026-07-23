#!/usr/bin/env bash
# Brillo actual en % (0-100), leyendo directo de sysfs (no necesita brightnessctl).
BL=/sys/class/backlight/amdgpu_bl1
cur=$(cat "$BL/brightness" 2>/dev/null)
max=$(cat "$BL/max_brightness" 2>/dev/null)
if [ -n "$cur" ] && [ -n "$max" ] && [ "$max" -gt 0 ]; then
    pct=$(( cur * 100 / max ))
    [ "$pct" -gt 100 ] && pct=100
    echo "$pct"
else
    echo 50
fi
