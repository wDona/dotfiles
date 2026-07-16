#!/usr/bin/env bash
# Launcher de apps + busqueda web integrada (rofi -dmenu).
#  - Apps ordenadas por FRECUENCIA de uso (mas usadas arriba).
#  - Matching por PREFIJO (se prioriza que empiece por lo tecleado).
#  - Historial de Brave anexado SIEMPRE al final (sin -sort -> orden preservado).
#  - Enter sobre app -> la abre (+1 al contador de uso).
#  - Enter sobre entrada de historial (titulo ┃ url) -> abre esa url en Brave.
#  - Enter en texto libre sin coincidencia -> Brave (URL o busqueda Google).

# Toggle: si rofi ya esta abierto, cerrar
if pgrep -x rofi >/dev/null; then
  pkill -x rofi
  exit 0
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
declare -A APP_ID

# Contador de usos persistente: lineas "count<TAB>name"
USES="$HOME/.cache/rofi_app_uses"
touch "$USES"
declare -A USE
while IFS=$'\t' read -r c n; do
  [ -n "$n" ] && USE["$n"]=$c
done < "$USES"

# Dirs en orden de prioridad (usuario primero -> gana en duplicados por nombre)
dirs=(
  "$HOME/.local/share/applications"
  "$HOME/.local/share/flatpak/exports/share/applications"
  /var/lib/flatpak/exports/share/applications
  /usr/local/share/applications
  /usr/share/applications
)

# Cache de apps parseadas: "name<TAB>icon<TAB>id" (sin uso, eso se aplica en runtime).
# Parsear .desktop es lo caro -> solo se regenera si algun .desktop cambio.
CACHE="$HOME/.cache/rofi_apps.cache"
existing=()
for d in "${dirs[@]}"; do [ -d "$d" ] && existing+=("$d"); done

if [ ! -f "$CACHE" ] || \
   [ -n "$(find "${existing[@]}" -name '*.desktop' -newer "$CACHE" -print -quit 2>/dev/null)" ]; then
  files=()
  for d in "${existing[@]}"; do
    for f in "$d"/*.desktop; do [ -e "$f" ] && files+=("$f"); done
  done
  # UN solo awk sobre todos los archivos (no fork por archivo). Dedup por nombre
  # en orden de prioridad (primer dir gana). Salta NoDisplay/Hidden.
  awk -F= '
    function flush(){
      if(fname!="" && name!="" && nodisplay!="true" && hidden!="true" && !(name in seen)){
        seen[name]=1; print name"\t"icon"\t"id
      }
      name="";icon="";nodisplay="";hidden="";sec=""
    }
    FILENAME!=fname{ flush(); fname=FILENAME; nf=split(FILENAME,a,"/"); id=a[nf] }
    /^\[/{ sec=$0 }
    sec=="[Desktop Entry]"{
      if($1=="Name"      && name==""     ){sub(/^Name=/,"");      name=$0}
      if($1=="Icon"      && icon==""     ){sub(/^Icon=/,"");      icon=$0}
      if($1=="NoDisplay" && nodisplay=="" ){sub(/^NoDisplay=/,""); nodisplay=$0}
      if($1=="Hidden"    && hidden==""   ){sub(/^Hidden=/,"");    hidden=$0}
    }
    END{ flush() }
  ' "${files[@]}" > "$CACHE" 2>/dev/null
fi

apps=()   # cada elemento: "count<TAB>name<TAB>icon"
while IFS=$'\t' read -r name icon id; do
  [ -z "$name" ] && continue
  APP_ID["$name"]="$id"
  apps+=("${USE[$name]:-0}"$'\t'"$name"$'\t'"$icon")
done < "$CACHE"

# Ordenar apps por uso desc, luego nombre asc -> emitir formato rofi (icono por fila)
if [ ${#apps[@]} -gt 0 ]; then
  while IFS=$'\t' read -r cnt name icon; do
    printf '%s\0icon\x1f%s\n' "$name" "$icon" >> "$tmp"
  done < <(printf '%s\n' "${apps[@]}" | sort -t$'\t' -k1,1nr -k2,2)
fi

# Historial de Brave anexado al final (titulo ┃ url, por frecuencia de visita).
# Lectura immutable=1 -> sin copiar la BD (instantaneo, no bloquea Brave).
HIST="$HOME/.config/BraveSoftware/Brave-Browser/Default/History"
if [ -f "$HIST" ]; then
  sqlite3 -separator " ┃ " "file:$HIST?immutable=1" \
    "SELECT COALESCE(NULLIF(title,''), url), url FROM urls
     WHERE url NOT LIKE 'chrome%' ORDER BY visit_count DESC, last_visit_time DESC LIMIT 300;" \
    2>/dev/null >> "$tmp"
fi

# -matching normal: 'fox' coincide con 'firefox'.
# -sort + fzf: prioriza prefijo / mejor match (apps o web, lo que coincida antes va primero).
sel=$(rofi -dmenu -i -p "Buscar" -show-icons -matching normal -sort -sorting-method fzf \
        -kb-cancel 'Escape,MousePrimary' \
        -mesg '🌐' < "$tmp")
[ -z "$sel" ] && exit 0

# App conocida -> lanzar (+1 uso); entrada de historial -> abrir url; resto -> web
if [ -n "${APP_ID[$sel]+x}" ]; then
  USE["$sel"]=$(( ${USE[$sel]:-0} + 1 ))
  { for n in "${!USE[@]}"; do printf '%s\t%s\n' "${USE[$n]}" "$n"; done; } > "$USES"
  setsid gtk-launch "${APP_ID[$sel]}" >/dev/null 2>&1 &
elif printf '%s' "$sel" | grep -qF " ┃ "; then
  setsid brave "${sel##* ┃ }" >/dev/null 2>&1 &
else
  case "$sel" in
    http://*|https://*) url="$sel" ;;
    *)
      if printf '%s' "$sel" | grep -qE '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$'; then
        url="https://$sel"
      else
        url="https://www.google.com/search?q=$(printf '%s' "$sel" | sed 's/ /+/g')"
      fi ;;
  esac
  setsid brave "$url" >/dev/null 2>&1 &
fi
