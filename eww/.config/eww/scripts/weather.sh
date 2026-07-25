#!/usr/bin/env bash
# Clima de Cordoba via open-meteo. Cachea 30 min para que la barra y el
# widget de eww compartan una sola peticion.
#
#   weather.sh bar    -> "󰖙 27°C"  (modulo de waybar)
#   weather.sh json   -> JSON para eww
#
# Sin API key. Coordenadas fijas (PC de sobremesa, no viaja).

set -u

LAT=37.8882
LON=-4.7794
CITY="Cordoba"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/eww-weather.json"
TTL=1800
DIAS=(Dom Lun Mar Mie Jue Vie Sab)

# Avisos AEMET via el agregador meteoalarm (mismo dato, sin API key: la API
# oficial de opendata.aemet.es exige clave por email).
# ES079 = Campiña cordobesa, la zona de Cordoba capital.
ZONE="ES079"
ALERTS_API="https://feeds.meteoalarm.org/api/v1/warnings/feeds-spain"
ACACHE="${XDG_CACHE_HOME:-$HOME/.cache}/eww-weather-alerts.json"

API="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}\
&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day\
&daily=weather_code,temperature_2m_max,temperature_2m_min\
&timezone=Europe/Madrid&forecast_days=4"

# Icono Nerd Font a partir del codigo WMO.
# https://open-meteo.com/en/docs -> "Weather variable documentation"
icon() {
    local code=$1 day=${2:-1}
    case $code in
        0)          [[ $day == 1 ]] && echo "󰖙" || echo "󰖔" ;;  # despejado
        1|2)        [[ $day == 1 ]] && echo "󰖕" || echo "󰼱" ;;  # poco nuboso
        3)          echo "󰖐" ;;                                  # cubierto
        45|48)      echo "󰖑" ;;                                  # niebla
        51|53|55)   echo "󰖗" ;;                                  # llovizna
        56|57|66|67) echo "󰙿" ;;                                 # lluvia helada
        61|63|65)   echo "󰖖" ;;                                  # lluvia
        71|73|75|77) echo "󰖘" ;;                                 # nieve
        80|81|82)   echo "󰖖" ;;                                  # chubascos
        85|86)      echo "󰖘" ;;                                  # chubascos de nieve
        95)         echo "󰙾" ;;                                  # tormenta
        96|99)      echo "󰖓" ;;                                  # tormenta con granizo
        *)          echo "󰼯" ;;                                  # desconocido
    esac
}

desc() {
    case $1 in
        0) echo "Despejado" ;;
        1) echo "Casi despejado" ;;
        2) echo "Parcialmente nuboso" ;;
        3) echo "Cubierto" ;;
        45|48) echo "Niebla" ;;
        51|53|55) echo "Llovizna" ;;
        56|57) echo "Llovizna helada" ;;
        61) echo "Lluvia debil" ;;
        63) echo "Lluvia" ;;
        65) echo "Lluvia fuerte" ;;
        66|67) echo "Lluvia helada" ;;
        71) echo "Nieve debil" ;;
        73) echo "Nieve" ;;
        75) echo "Nieve fuerte" ;;
        77) echo "Aguanieve" ;;
        80|81) echo "Chubascos" ;;
        82) echo "Chubascos fuertes" ;;
        85|86) echo "Chubascos de nieve" ;;
        95) echo "Tormenta" ;;
        96|99) echo "Tormenta con granizo" ;;
        *) echo "?" ;;
    esac
}

# Descarga si la cache falta, esta vacia o caducó.
fetch() {
    if [[ -s $CACHE ]]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$CACHE") ))
        (( age < TTL )) && return 0
    fi
    local tmp
    tmp=$(mktemp) || return 1
    if curl -sf --max-time 10 "$API" -o "$tmp" && jq -e .current "$tmp" >/dev/null 2>&1; then
        mv "$tmp" "$CACHE"
    else
        rm -f "$tmp"
        # Si hay cache vieja la seguimos usando; mejor dato rancio que hueco.
        [[ -s $CACHE ]]
    fi
}

# Avisos vigentes de la zona, ya filtrados y ordenados. Imprime un array JSON
# (vacio si no hay nada o si falla la red).
#
# El feed nacional trae avisos caducados y de nivel verde (= "sin aviso"), asi
# que se descartan los dos: solo amarillo/naranja/rojo y con expires futuro.
alerts() {
    local fresh=0
    if [[ -s $ACACHE ]]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$ACACHE") ))
        (( age < TTL )) && fresh=1
    fi

    if (( ! fresh )); then
        local raw tmp
        if raw=$(curl -sf --max-time 15 -A 'Mozilla/5.0' "$ALERTS_API" 2>/dev/null); then
            tmp=$(mktemp) || return 1
            if jq -c --arg z "$ZONE" --arg now "$(date -Is)" '
                  [ .warnings[].alert.info[]
                    | select(.language == "es-ES")
                    | select(any(.area[].geocode[]?;
                        .valueName == "EMMA_ID" and .value == $z))
                    | { onset, expires,
                        lvl: ([.parameter[] | select(.valueName=="awareness_level").value][0] // ""),
                        typ: ([.parameter[] | select(.valueName=="awareness_type").value][0] // "") } ]
                  | map(select(.expires > $now))
                  | map(.n = (.lvl | split(";")[0] | tonumber? // 0))
                  | map(select(.n >= 2))
                  | map(.t = (.typ | split(";")[1] // "" | ltrimstr(" ")))
                  | sort_by(.onset)
                  | unique_by([.n, .t, .onset])
                  | .[0:3]
                ' <<<"$raw" >"$tmp" 2>/dev/null; then
                mv "$tmp" "$ACACHE"
            else
                rm -f "$tmp"
            fi
        fi
    fi

    [[ -s $ACACHE ]] || { echo "[]"; return 0; }

    # Re-filtra por fecha al leer: la cache dura 30 min y un aviso corto (los de
    # temperatura duran ~8 h) puede haber expirado dentro de esa ventana.
    jq -c --arg now "$(date -Is)" \
          --argjson dias "$(printf '%s\n' "${DIAS[@]}" | jq -R . | jq -sc .)" '
        map(select(.expires > $now))
        | map({
            color: (.lvl | split(";")[1] | ltrimstr(" ") | ascii_downcase),
            # Los 9 tipos que emite AEMET + los restantes del catalogo
            # meteoalarm (no los usa hoy, pero salen gratis). La clave va en
            # minusculas porque la grafia NO es estable entre paises: en el
            # mismo feed conviven "high-temperature" y "High-temperature".
            # Un tipo nuevo se mostraria en ingles en vez de romperse.
            text:  (.t | ascii_downcase | {
                      "wind":"Viento", "snow-ice":"Nieve/hielo", "thunderstorm":"Tormentas",
                      "fog":"Niebla", "high-temperature":"Calor", "low-temperature":"Frio",
                      "rain":"Lluvia", "coastalevent":"Costeros", "avalanches":"Aludes",
                      "forest-fire":"Incendios", "forestfire":"Incendios",
                      "flooding":"Inundaciones", "flood":"Inundaciones",
                      "rain-flood":"Lluvia/riada"
                    }[.] // .),
            # onset ya viene en hora local ("...T13:00:00+02:00"). Se corta el
            # offset y se trata como UTC: mktime/strftime no lo desplazan, asi
            # que la hora sale tal cual. fromdateiso8601 aqui NO sirve: exige
            # que el ISO acabe en "Z" y peta con "+02:00".
            when:  ((.onset[0:19] | strptime("%Y-%m-%dT%H:%M:%S") | mktime) as $t
                    | $dias[($t | strftime("%w") | tonumber)]
                      + " " + ($t | strftime("%H:%M")))
          })' "$ACACHE" 2>/dev/null || echo "[]"
}

case "${1:-bar}" in
bar)
    fetch || { echo ""; exit 0; }
    read -r code temp day < <(jq -r '.current | "\(.weather_code) \(.temperature_2m|round) \(.is_day)"' "$CACHE")
    echo "$(icon "$code" "$day") ${temp}°C"
    ;;

json)
    if ! fetch; then
        echo '{"ok":false,"city":"'"$CITY"'","icon":"󰼯","temp":"--","desc":"Sin conexion","feels":"--","hum":"--","wind":"--","days":[],"alerts":[],"has_alerts":false}'
        exit 0
    fi

    # Dias: hoy + 3. Nombre corto en castellano desde la fecha.
    days="[]"
    for i in 0 1 2 3; do
        read -r date code max min < <(jq -r --argjson i "$i" \
            '.daily | "\(.time[$i]) \(.weather_code[$i]) \(.temperature_2m_max[$i]|round) \(.temperature_2m_min[$i]|round)"' "$CACHE")
        if [[ $i == 0 ]]; then
            name="Hoy"
        else
            # Sin LC_TIME: el locale es_ES puede no estar generado.
            name=${DIAS[$(date -d "$date" +%w)]}
        fi
        days=$(jq -c --arg n "$name" --arg ic "$(icon "$code")" --arg mx "$max" --arg mn "$min" \
            '. += [{name:$n, icon:$ic, max:$mx, min:$mn}]' <<<"$days")
    done

    jq -c -n --argjson c "$(jq -c .current "$CACHE")" \
             --arg city "$CITY" \
             --arg ic "$(icon "$(jq -r .current.weather_code "$CACHE")" "$(jq -r .current.is_day "$CACHE")")" \
             --arg d "$(desc "$(jq -r .current.weather_code "$CACHE")")" \
             --argjson days "$days" \
             --argjson al "$(alerts)" \
      '{ok:true, city:$city, icon:$ic, desc:$d,
        temp:  ($c.temperature_2m|round|tostring),
        feels: ($c.apparent_temperature|round|tostring),
        hum:   ($c.relative_humidity_2m|tostring),
        wind:  ($c.wind_speed_10m|round|tostring),
        days:  $days,
        alerts: $al,
        has_alerts: ($al | length > 0)}'
    ;;

selftest)
    # Comprueba el filtrado de avisos con una cache falsa: es lo unico que
    # puede fallar callado (mostrar avisos verdes/caducados, o ninguno).
    ACACHE=$(mktemp)
    trap 'rm -f "$ACACHE"' EXIT
    ayer=$(date -d '-1 day' +%Y-%m-%dT%H:%M:%S%:z)
    manana=$(date -d '+1 day' +%Y-%m-%dT13:00:00%:z)
    fin=$(date -d '+1 day' +%Y-%m-%dT20:00:00%:z)
    jq -n --arg ay "$ayer" --arg ma "$manana" --arg fi "$fin" '[
        {onset:$ma, expires:$fi, lvl:"3; orange; Severe", typ:"5; high-temperature", t:"high-temperature"},
        {onset:$ay, expires:$ay, lvl:"3; orange; Severe", typ:"1; Wind",             t:"Wind"}
      ]' > "$ACACHE"
    out=$(alerts)

    n=$(jq length <<<"$out")
    [[ $n == 1 ]]                                   || { echo "FALLO: esperaba 1 aviso, hay $n -> $out"; exit 1; }
    [[ $(jq -r '.[0].text'  <<<"$out") == Calor  ]] || { echo "FALLO: texto -> $out"; exit 1; }
    [[ $(jq -r '.[0].color' <<<"$out") == orange ]] || { echo "FALLO: color -> $out"; exit 1; }
    [[ $(jq -r '.[0].when'  <<<"$out") == *13:00 ]] || { echo "FALLO: hora -> $out"; exit 1; }
    echo "ok: caducado descartado, vigente formateado -> $out"
    ;;

*)
    echo "uso: weather.sh [bar|json|selftest]" >&2
    exit 1
    ;;
esac
