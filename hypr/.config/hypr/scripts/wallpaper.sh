#!/usr/bin/env bash
# =============================================================================
# wallpaper.sh - Gestiona el fondo de pantalla (imagen estatica o video) con
# mpvpaper. Persiste la eleccion en un archivo de estado para sobrevivir al
# reinicio. Pensado para llamarse desde hyprland.conf (restore) y desde eww.
#
# Uso:
#   wallpaper.sh restore        # aplica el ultimo fondo guardado (autostart)
#   wallpaper.sh set <path>     # aplica un fondo y lo guarda como estado
#   wallpaper.sh list           # JSON de fondos en ~/Pictures/Wallpapers (eww)
#   wallpaper.sh browse         # selector de archivo (zenity) + set
#   wallpaper.sh thumb <path>   # genera/imprime la miniatura de un archivo
#   wallpaper.sh dim [0-100]    # oscurecimiento del fondo (sin arg: lo imprime)
# =============================================================================
set -uo pipefail

STATE="$HOME/.config/wallpaper.conf"
DIMSTATE="$HOME/.config/wallpaper-dim.conf"
WALLDIR="$HOME/Pictures/Wallpapers"
THUMBDIR="$HOME/.cache/wallpaper-thumbs"
SHADER="$HOME/.cache/wallpaper-dim.glsl"
ZENITY_THEME="$HOME/.config/eww/zenity-theme"
MPV_OPTS_COMMON="--loop --no-audio --vo=gpu --hwdec=auto --panscan=1.0"
MPV_OPTS_IMAGE_EXTRA="--image-display-duration=inf --no-osc"
DIM_DEFAULT=55  # 0 = negro total, 100 = sin oscurecer
MON='*'  # todos los monitores

mkdir -p "$WALLDIR" "$THUMBDIR"

# Nivel de oscurecimiento guardado (0-100), saneado y con fallback al default.
dim_level() {
    local v=""
    [ -f "$DIMSTATE" ] && v=$(head -n1 "$DIMSTATE" | tr -cd '0-9')
    [ -z "$v" ] && v=$DIM_DEFAULT
    [ "$v" -gt 100 ] && v=100
    printf '%s\n' "$v"
}

# Reescribe el shader GLSL con el factor actual y devuelve la opcion de mpv.
# Equivale a una capa negra encima con opacidad (100-nivel)%, pero mpv lo
# aplica en la GPU: oscurecer no cuesta CPU. A 100 no se aplica shader.
gen_dim_shader() {
    local lvl factor
    lvl=$(dim_level)
    [ "$lvl" -ge 100 ] && return 0
    factor=$(awk "BEGIN{printf \"%.4f\", $lvl/100}")
    cat > "$SHADER" <<EOF
// Generado por wallpaper.sh - NO editar (usa: wallpaper.sh dim <0-100>)
// Nivel actual: $lvl
//!HOOK MAIN
//!BIND HOOKED
//!DESC dim wallpaper
vec4 hook() {
    return vec4(HOOKED_tex(HOOKED_pos).rgb * $factor, 1.0);
}
EOF
    printf -- '--glsl-shader=%s\n' "$SHADER"
}

is_video() {
    case "${1,,}" in
        *.mp4|*.mkv|*.webm|*.mov|*.avi|*.gif) return 0 ;;
        *) return 1 ;;
    esac
}

# Aplica un fondo: mata el mpvpaper actual y lanza uno nuevo segun el tipo.
apply() {
    local path="$1"
    if [ ! -e "$path" ]; then
        echo "wallpaper.sh: no existe '$path'" >&2
        return 1
    fi
    pkill -x mpvpaper 2>/dev/null
    sleep 0.2
    local opts
    opts="$MPV_OPTS_COMMON $(gen_dim_shader)"
    is_video "$path" || opts="$opts $MPV_OPTS_IMAGE_EXTRA"
    setsid -f mpvpaper -o "$opts" "$MON" "$path" >/dev/null 2>&1
}

# Genera (si hace falta) y devuelve la ruta de la miniatura PNG de un archivo.
gen_thumb() {
    local src="$1"
    local key out
    key=$(printf '%s' "$src" | md5sum | cut -d' ' -f1)
    out="$THUMBDIR/$key.png"
    if [ ! -f "$out" ] || [ "$src" -nt "$out" ]; then
        if is_video "$src"; then
            ffmpeg -y -loglevel error -ss 0 -i "$src" -frames:v 1 \
                   -vf "scale=320:-1" "$out" </dev/null >/dev/null 2>&1
        else
            magick "$src" -resize 320x "$out" >/dev/null 2>&1
        fi
    fi
    printf '%s\n' "$out"
}

case "${1:-}" in
    set)
        [ -n "${2:-}" ] || { echo "uso: wallpaper.sh set <path>" >&2; exit 1; }
        apply "$2" && printf '%s\n' "$2" > "$STATE"
        ;;

    restore)
        if [ -f "$STATE" ]; then
            p=$(head -n1 "$STATE")
            [ -n "$p" ] && apply "$p"
        fi
        ;;

    thumb)
        [ -n "${2:-}" ] || { echo "uso: wallpaper.sh thumb <path>" >&2; exit 1; }
        gen_thumb "$2"
        ;;

    dim)
        # Sin argumento solo consulta; con argumento guarda y reaplica el fondo
        # actual para que el cambio se vea al momento.
        if [ -z "${2:-}" ]; then
            dim_level
        else
            case "$2" in
                ''|*[!0-9]*) echo "uso: wallpaper.sh dim <0-100>" >&2; exit 1 ;;
            esac
            [ "$2" -le 100 ] || { echo "wallpaper.sh: dim debe estar entre 0 y 100" >&2; exit 1; }
            printf '%s\n' "$2" > "$DIMSTATE"
            [ -f "$STATE" ] && p=$(head -n1 "$STATE") && [ -n "$p" ] && apply "$p"
        fi
        ;;

    list)
        current=""
        [ -f "$STATE" ] && current=$(realpath -m "$(head -n1 "$STATE")")
        shopt -s nullglob nocaseglob
        {
            for f in "$WALLDIR"/*.{png,jpg,jpeg,webp,gif,mp4,mkv,webm,mov,avi}; do
                [ -e "$f" ] || continue
                thumb=$(gen_thumb "$f")
                is_video "$f" && t=video || t=image
                sel=false; [ "$(realpath -m "$f")" = "$current" ] && sel=true
                jq -nc --arg p "$f" --arg th "$thumb" --arg n "$(basename "$f")" \
                       --arg t "$t" --argjson s "$sel" \
                       '{path:$p,thumb:$th,name:$n,type:$t,selected:$s}'
            done
        } | jq -sc '.'
        ;;

    browse)
        sel=$(XDG_CONFIG_HOME="$ZENITY_THEME" zenity --file-selection \
              --title="Elige un fondo (imagen o video)" \
              --filename="$WALLDIR/" \
              --file-filter="Fondos | *.png *.jpg *.jpeg *.webp *.gif *.mp4 *.mkv *.webm *.mov *.avi" \
              --file-filter="Todos | *" 2>/dev/null)
        if [ -n "$sel" ]; then
            # Si el archivo esta fuera de ~/Pictures/Wallpapers, lo enlazamos
            # ahi para que aparezca en el grid del panel en adelante.
            case "$sel" in
                "$WALLDIR"/*) : ;;
                *) ln -sf "$sel" "$WALLDIR/$(basename "$sel")" 2>/dev/null ;;
            esac
            "$0" set "$sel"
        fi
        ;;

    *)
        echo "uso: wallpaper.sh {restore|set <path>|list|browse|thumb <path>|dim [0-100]}" >&2
        exit 1
        ;;
esac
