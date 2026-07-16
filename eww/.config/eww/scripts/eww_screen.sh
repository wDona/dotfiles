#!/usr/bin/env bash
# Imprime el identificador GDK del monitor Hyprland con foco, para pasarlo a
# `eww open --screen`. eww NO entiende conectores (DP-2/HDMI-A-1), solo nombres
# de modelo GDK (p.ej. SyncMaster, 24G2W1G3-). Ademas el orden GDK puede estar
# invertido respecto al id de Hyprland, asi que mapeamos por modelo, no por id.
#
# El modelo GDK aparece como substring del campo `description` de hyprctl.
# La lista de modelos que conoce eww se extrae del mensaje de error de `eww open`.

desc=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .description')
[ -z "$desc" ] && desc=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].description')

# Modelos GDK conocidos por eww (una por linea, sin el "[N] ")
gdk=$(eww open dashboard --screen __nope__ 2>&1 | grep -oP '^\s*\[[0-9]+\]\s+\K.+')

while IFS= read -r m; do
    [ -z "$m" ] && continue
    if [[ "$desc" == *"$m"* ]]; then
        echo "$m"
        exit 0
    fi
done <<< "$gdk"

# Fallback: primer monitor GDK
echo "0"
