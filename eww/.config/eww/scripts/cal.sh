#!/usr/bin/env bash
# Genera el calendario de un mes como JSON para eww.
# Uso: cal.sh [offset_meses]   (0 = mes actual, -1 = anterior, +1 = siguiente)
# Cada celda: { date, day, dim, today, event }
# Top-level: { label, year, month, weeks[6][7] }. Semana empieza en lunes.

offset="${1:-0}"
EVENTS="$HOME/.config/eww/events.json"
[ -f "$EVENTS" ] || echo '{}' >"$EVENTS"

first=$(date -d "$(date +%Y-%m-01) ${offset} month" +%Y-%m-%d)
year=$(date -d "$first" +%Y)
month=$(date -d "$first" +%m)

meses=(Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre)
mnum=$(date -d "$first" +%-m)
label="${meses[$((mnum - 1))]} $year"

dow=$(date -d "$first" +%u)                                   # 1=lun .. 7=dom
days_in_month=$(date -d "$(date -d "$first +1 month") -1 day" +%d)
prev_last=$(date -d "$first -1 day" +%d)
prev_ym=$(date -d "$first -1 month" +%Y-%m)
next_ym=$(date -d "$first +1 month" +%Y-%m)
today=$(date +%Y-%m-%d)

# Fechas con evento (clave con lista no vacia; tolera el formato viejo string)
mapfile -t evdates < <(jq -r 'to_entries[] | select((.value|type=="array" and length>0) or (.value|type=="string" and .!="")) | .key' "$EVENTS" 2>/dev/null)
has_event() { local d="$1" e; for e in "${evdates[@]}"; do [[ "$e" == "$d" ]] && return 0; done; return 1; }

cell() { # date day dim
    local date="$1" day="$2" dim="$3" tdy="false" ev="false"
    [[ "$date" == "$today" ]] && tdy="true"
    has_event "$date" && ev="true"
    printf '{"date":"%s","day":"%s","dim":%s,"today":%s,"event":%s}' "$date" "$day" "$dim" "$tdy" "$ev"
}

cells=()
lead=$((dow - 1))
for ((i = lead; i > 0; i--)); do
    d=$((10#$prev_last - i + 1))
    cells+=("$(cell "$(printf '%s-%02d' "$prev_ym" "$d")" "$d" true)")
done
for ((d = 1; d <= 10#$days_in_month; d++)); do
    cells+=("$(cell "$(printf '%s-%s-%02d' "$year" "$month" "$d")" "$d" false)")
done
next=1
while ((${#cells[@]} < 42)); do
    cells+=("$(cell "$(printf '%s-%02d' "$next_ym" "$next")" "$next" true)")
    ((next++))
done

weeks=()
for ((w = 0; w < 6; w++)); do
    row=()
    for ((c = 0; c < 7; c++)); do row+=("${cells[$((w * 7 + c))]}"); done
    IFS=,
    weeks+=("[${row[*]}]")
    unset IFS
done

IFS=,
echo '{ "label": "'"$label"'", "mname": "'"${meses[$((mnum - 1))]}"'", "year": '"$year"', "month": '"$mnum"', "weeks": ['"${weeks[*]}"'] }'
unset IFS
