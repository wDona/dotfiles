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

# Modelos GDK conocidos por eww (una por linea, sin el "[N] "). Se cachea:
# pedirlo cuesta abrir una ventana falsa y parsear el error (~80ms). Si el
# monitor actual no aparece en la cache (p.ej. lo acabas de conectar en
# caliente), se descarta y se repite fresco una vez (autocurativo).
CACHE="$HOME/.cache/eww_gdk_monitors"

fetch_fresh() {
    eww open dashboard --screen __nope__ 2>&1 | grep -oP '^\s*\[[0-9]+\]\s+\K.+'
}

match() {
    local list="$1" m
    while IFS= read -r m; do
        [ -z "$m" ] && continue
        [[ "$desc" == *"$m"* ]] && { echo "$m"; return 0; }
    done <<< "$list"
    return 1
}

if [ -s "$CACHE" ]; then
    gdk=$(cat "$CACHE")
    match "$gdk" && exit 0
fi

gdk=$(fetch_fresh)
printf '%s\n' "$gdk" > "$CACHE"
match "$gdk" && exit 0

# Fallback: primer monitor GDK
echo "0"
