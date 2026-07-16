#!/usr/bin/env bash
# Pull de eventos del calendario PROPIETARIO de Google -> events.json (cache
# que pinta el grid). Two-way: la escritura la hace addevent.sh via gcalcli.
# Uso: cal_sync.sh [offset_meses]   (refresca el grid de ese mes al acabar)
source "$HOME/.config/eww/scripts/env.sh"   # PATH con ~/.local/bin para gcalcli (pipx)
off="${1:-0}"
EVENTS="$HOME/.config/eww/events.json"
OWNER_CACHE="$HOME/.cache/eww_gcal_owner"

command -v gcalcli >/dev/null 2>&1 || exit 0   # sin gcalcli: no tocar nada

# Calendario propietario (cacheado; el read-only "Festivos" se ignora).
if [ ! -s "$OWNER_CACHE" ]; then
    gcalcli --nocolor list 2>/dev/null \
        | awk '$1=="owner"{$1="";sub(/^[ \t]+/,"");print;exit}' > "$OWNER_CACHE"
fi
OWNER=$(cat "$OWNER_CACHE" 2>/dev/null)
[ -z "$OWNER" ] && { bash "$HOME/.config/eww/scripts/nav.sh" "$off"; exit 0; }

# Ventana: -13 meses a +13 meses respecto al mes visible.
base=$(date -d "$(date +%Y-%m-01) ${off} month" +%Y-%m-01)
start=$(date -d "$base -13 month" +%Y-%m-%d)
end=$(date -d "$base +13 month" +%Y-%m-%d)

raw=$(gcalcli --nocolor --calendar "$OWNER" agenda "$start" "$end" --tsv 2>/dev/null)
# Si no hay ni cabecera, gcalcli fallo (red caida) -> NO pisar el cache.
printf '%s\n' "$raw" | head -1 | grep -q '^start_date' || { bash "$HOME/.config/eww/scripts/nav.sh" "$off"; exit 0; }

# Construir events.json: fecha -> titulos unidos por " · ".
tmp=$(mktemp)
# events.json = { "fecha": ["evento1","evento2",...] }  (varios eventos por dia)
printf '%s\n' "$raw" | awk -F'\t' 'NR>1 && $1!="" {
    if (seen[$1 SUBSEP $5]++) next
    t=$5; gsub(/\\/,"\\\\",t); gsub(/"/,"\\\"",t)
    if (a[$1]=="") a[$1]="\"" t "\""; else a[$1]=a[$1] ",\"" t "\""
} END {
    printf "{"; sep="";
    for (d in a){ printf "%s\"%s\":[%s]", sep, d, a[d]; sep="," }
    printf "}\n"
}' > "$tmp"

# Validar JSON antes de reemplazar.
if jq -e . "$tmp" >/dev/null 2>&1; then mv "$tmp" "$EVENTS"; else rm -f "$tmp"; fi

bash "$HOME/.config/eww/scripts/nav.sh" "$off"
