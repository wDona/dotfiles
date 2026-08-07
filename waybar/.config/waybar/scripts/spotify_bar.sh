#!/usr/bin/env bash
# =============================================================================
# Modulo de Spotify de waybar: icono + titulo que se ILUMINAN con la cancion.
#
# cava mide el nivel; no se pinta ni una barra. El brillo va con el volumen de
# lo que suena, de forma continua: mas sonido = mas blanco, silencio = apagado.
# El nivel se manda como clase (l0..l4) y el color lo pone el CSS, que ademas
# transiciona entre escalones: asi sube y baja como una luz y no a saltos.
#
# Cinco escalones y no un degradado real porque waybar solo sabe pasar clases,
# no colores; con la transicion del CSS la diferencia no se ve.
#
# En PAUSA no desaparece: icono apagado y titulo tenue. Solo con Spotify
# CERRADO el modulo se queda vacio y se colapsa.
# =============================================================================
set -u

RT="${XDG_RUNTIME_DIR:-/tmp}"
STATE="$RT/spotify_bar.state"
CONF=$(mktemp)
trap 'rm -f "$CONF"; kill 0 2>/dev/null' EXIT

printf 'CLOSED||\n' > "$STATE"

# ── Estado del reproductor, en segundo plano ─────────────────────────────
# playerctl -F bloquea y emite una linea por cambio; se vuelca SIEMPRE sobre el
# mismo fichero (>) para que el bucle principal lo lea de una sola lectura. Si
# Spotify se cierra, playerctl termina: se marca CLOSED y se reintenta.
{
    while :; do
        playerctl -p spotify -F metadata \
                  --format '{{status}}|{{title}}|{{artist}}' 2>/dev/null |
            while IFS= read -r line; do printf '%s\n' "$line" > "$STATE"; done
        printf 'CLOSED||\n' > "$STATE"
        sleep 2
    done
} &

# ── Guardia del volumen, en segundo plano ────────────────────────────────
# Al cambiar de cancion algo sube el sink-input de Spotify a 99-100% y se lleva
# por delante el volumen que hubieras puesto. El guardia escucha eventos de
# pactl y lo repone (ver spotify.sh). Vive aqui porque este script ya es el
# proceso permanente de Spotify; montarlo como servicio aparte seria un unit
# mas para un bucle que duerme el 99.9% del tiempo.
# El reintento es por si pipewire se reinicia y se lleva el subscribe.
{
    while :; do
        "$HOME/.config/eww/scripts/spotify.sh" vol-guard
        sleep 2
    done
} &

# ── cava ─────────────────────────────────────────────────────────────────
# 6 bandas: se promedian para sacar el nivel. Pocas a proposito, hay que
# parsearlas 25 veces por segundo y aqui no se pinta ninguna.
cat > "$CONF" <<EOF
[general]
framerate = 25
bars = 6
[input]
method = pulse
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 15
EOF

ICON="󰓇"      # Spotify, tambien en pausa: el estado ya lo dice el color
              # (.paused lo apaga) y cambiar de glifo movia el ancho del modulo
              # cada vez que pausabas.
last_title=""
esc=""
last_cls=""
peak=12       # referencia de nivel, con caida (ver el calculo de abajo)

emit() { printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$1" "$2" "$3"; }

cava -p "$CONF" | while IFS=';' read -r -a v; do
    IFS='|' read -r st title artist < "$STATE"

    # Escapado del titulo solo cuando cambia, no 25 veces por segundo.
    if [ "$title" != "$last_title" ]; then
        last_title="$title"
        esc=${title//\\/\\\\}; esc=${esc//\"/\\\"}
        # (El volumen NO se toca aqui: el reset no va sincronizado con el
        # cambio de titulo, lo lleva el guardia de arriba.)
    fi

    tot=0; n=0
    for x in "${v[@]}"; do
        [[ $x =~ ^[0-9]+$ ]] || continue
        tot=$((tot + x)); n=$((n + 1))
    done
    [ "$n" -eq 0 ] && continue

    case "$st" in
        CLOSED)
            cls="closed"; txt=""
            ;;
        Playing)
            # Nivel medio 0-100, PERO relativo a un pico propio que va cayendo,
            # no al maximo teorico de cava. Con cortes fijos casi ninguna
            # cancion llegaba a los extremos -la musica normal vive en la franja
            # media- y el modulo se quedaba entre dos escalones: por eso "no se
            # notaba". Con la referencia adaptativa cada tema recorre los cinco,
            # sea un tema flojo o uno masterizado a tope.
            lvl=$((tot * 100 / (n * 15)))
            peak=$((peak * 98 / 100))          # ~2%/frame: medio segundo de memoria
            [ "$lvl" -gt "$peak" ] && peak=$lvl
            [ "$peak" -lt 12 ] && peak=12      # suelo: en silencio no amplifica ruido
            rel=$((lvl * 100 / peak))

            # Cortes apretados arriba (90/78/65/50) porque el nivel relativo
            # rara vez baja del 50%: repartirlos por todo el 0-100 dejaba los
            # tres escalones de abajo sin usar. Probado con una rampa suave de
            # entrada: recorre los cinco.
            if   [ "$rel" -ge 90 ]; then cls="play l4"
            elif [ "$rel" -ge 78 ]; then cls="play l3"
            elif [ "$rel" -ge 65 ]; then cls="play l2"
            elif [ "$rel" -ge 50 ]; then cls="play l1"
            else                         cls="play l0"
            fi
            txt="$ICON  $esc"
            ;;
        *)
            cls="paused"; txt="$ICON  $esc"
            ;;
    esac

    # Solo se escribe cuando cambia algo: repetir la misma linea 25 veces por
    # segundo hace a waybar repintar el modulo para nada.
    if [ "$cls" != "$last_cls" ] || [ "$txt" != "${last_txt:-}" ]; then
        last_cls="$cls"; last_txt="$txt"
        emit "$txt" "$cls" "$artist"
    fi
done
