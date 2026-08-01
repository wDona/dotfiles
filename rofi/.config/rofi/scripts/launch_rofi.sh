#!/usr/bin/env bash
# Launcher de apps + busqueda web integrada (rofi -dmenu).
#  - Apps ordenadas por FRECUENCIA de uso (mas usadas arriba).
#  - Matching por PREFIJO (se prioriza que empiece por lo tecleado).
#  - Historial de Zen anexado SIEMPRE al final (sin -sort -> orden preservado).
#  - Enter sobre app -> la abre (+1 al contador de uso).
#  - Enter sobre entrada de historial (titulo ┃ url) -> abre esa url en Zen.
#  - Enter en texto libre sin coincidencia -> Zen (URL o busqueda Google).

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

# Cache de apps parseadas: "name<TAB>icon<TAB>id<TAB>meta" (sin uso, eso se aplica en runtime).
# Parsear .desktop es lo caro -> solo se regenera si algun .desktop cambio.
CACHE="$HOME/.cache/rofi_apps2.cache"
existing=()
for d in "${dirs[@]}"; do [ -d "$d" ] && existing+=("$d"); done

# Sin cache -> parsear todo. Con cache -> parsear SOLO los .desktop nuevos/modificados
# y fusionarlos encima (la entrada fresca gana por nombre, el resto se conserva).
files=()
if [ -f "$CACHE" ]; then
  # -newer sobre los .desktop no basta: pacman conserva el mtime del paquete, que
  # suele ser mas viejo que la cache -> apps recien instaladas nunca se veian.
  # El mtime del DIR si cambia al añadir/quitar ficheros: re-parsea ese dir entero.
  for d in "${existing[@]}"; do
    [ "$d" -nt "$CACHE" ] || continue
    for f in "$d"/*.desktop; do [ -e "$f" ] && files+=("$f"); done
  done
  while IFS= read -r f; do files+=("$f"); done \
    < <(find "${existing[@]}" -name '*.desktop' -newer "$CACHE" 2>/dev/null)
else
  for d in "${existing[@]}"; do
    for f in "$d"/*.desktop; do [ -e "$f" ] && files+=("$f"); done
  done
fi

if [ ${#files[@]} -gt 0 ]; then
  new=$(mktemp)
  # UN solo awk sobre todos los archivos (no fork por archivo). Dedup por nombre
  # en orden de prioridad (primer dir gana). Salta NoDisplay/Hidden.
  awk -F= '
    function flush(){
      if(fname!="" && name!="" && nodisplay!="true" && hidden!="true" && !(name in seen)){
        meta=kw" "gen; gsub(/[;\t]+/," ",meta)
        seen[name]=1; print name"\t"icon"\t"id"\t"meta
      }
      name="";icon="";nodisplay="";hidden="";kw="";gen="";sec=""
    }
    FILENAME!=fname{ flush(); fname=FILENAME; nf=split(FILENAME,a,"/"); id=a[nf] }
    /^\[/{ sec=$0 }
    sec=="[Desktop Entry]"{
      if($1=="Name"      && name==""     ){sub(/^Name=/,"");      name=$0}
      if($1=="Icon"      && icon==""     ){sub(/^Icon=/,"");      icon=$0}
      if($1=="NoDisplay" && nodisplay=="" ){sub(/^NoDisplay=/,""); nodisplay=$0}
      if($1=="Hidden"    && hidden==""   ){sub(/^Hidden=/,"");    hidden=$0}
      # Alias de busqueda: matchean pero no se muestran (campo meta de rofi).
      if($1=="Keywords"    && kw=="" ){sub(/^Keywords=/,"");    kw=$0}
      if($1=="GenericName" && gen==""){sub(/^GenericName=/,""); gen=$0}
    }
    END{ flush() }
  ' "${files[@]}" > "$new" 2>/dev/null
  [ -f "$CACHE" ] && cat "$CACHE" >> "$new"
  awk -F'\t' 'NF && !seen[$1]++' "$new" > "$CACHE"
  rm -f "$new"
fi

# Purga entradas cuyo .desktop ya no existe (borrar no dispara el -newer de arriba).
# Solo listado de nombres, sin parsear -> barato.
ids=$(mktemp); pruned=$(mktemp)
find "${existing[@]}" -name '*.desktop' -printf '%f\n' 2>/dev/null | sort -u > "$ids"
awk -F'\t' 'NR==FNR{keep[$0];next} $3 in keep' "$ids" "$CACHE" > "$pruned"
[ -s "$pruned" ] && mv "$pruned" "$CACHE"
rm -f "$ids" "$pruned"

apps=()   # cada elemento: "count<TAB>name<TAB>icon<TAB>meta"
while IFS=$'\t' read -r name icon id meta; do
  [ -z "$name" ] && continue
  APP_ID["$name"]="$id"
  apps+=("${USE[$name]:-0}"$'\t'"$name"$'\t'"$icon"$'\t'"$meta")
done < "$CACHE"

# Ordenar apps por uso desc, luego nombre asc -> emitir formato rofi (icono por fila)
if [ ${#apps[@]} -gt 0 ]; then
  while IFS=$'\t' read -r cnt name icon meta; do
    printf '%s\0icon\x1f%s\x1fmeta\x1f%s\n' "$name" "$icon" "$meta" >> "$tmp"
  done < <(printf '%s\n' "${apps[@]}" | sort -t$'\t' -k1,1nr -k2,2)
fi

# Historial de Zen anexado al final (titulo ┃ url, por frecuencia de visita).
# Lectura immutable=1 -> sin copiar la BD (instantaneo, no bloquea Zen).
# Perfil real: ver comentario largo en rofi-zen-url sobre profiles.ini (el
# Default=1 de [ProfileN] no es el que Zen abre, el de [InstallXXXX] si).
ZEN_DIR="$HOME/.config/zen"
zen_rel=$(awk -F= '
    /^\[Install/  { in_install = 1; next }
    /^\[/         { in_install = 0 }
    in_install && $1 == "Default" { print $2; exit }
' "$ZEN_DIR/profiles.ini" 2>/dev/null || true)
ZEN_PROFILE=""
[ -n "$zen_rel" ] && [ -d "$ZEN_DIR/$zen_rel" ] && ZEN_PROFILE="$ZEN_DIR/$zen_rel"
[ -z "$ZEN_PROFILE" ] && ZEN_PROFILE=$(find "$ZEN_DIR" -maxdepth 2 -name places.sqlite -printf '%T@ %h\n' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
HIST="$ZEN_PROFILE/places.sqlite"
if [ -n "$ZEN_PROFILE" ] && [ -f "$HIST" ]; then
  sqlite3 -separator " ┃ " "file:$HIST?immutable=1" \
    "SELECT COALESCE(NULLIF(title,''), url), url FROM moz_places
     WHERE url NOT LIKE 'about:%' AND url NOT LIKE 'chrome%' AND hidden = 0
     ORDER BY visit_count DESC, last_visit_date DESC LIMIT 300;" \
    2>/dev/null >> "$tmp"
fi

# -matching normal: 'fox' coincide con 'firefox'.
# -sort + fzf: prioriza prefijo / mejor match (apps o web, lo que coincida antes va primero).
sel=$(rofi -dmenu -i -p "Buscar" -show-icons -matching normal -sort -sorting-method fzf \
        -kb-cancel 'Escape,MousePrimary' < "$tmp")
[ -z "$sel" ] && exit 0

# App conocida -> lanzar (+1 uso); entrada de historial -> abrir url; resto -> web
if [ -n "${APP_ID[$sel]+x}" ]; then
  USE["$sel"]=$(( ${USE[$sel]:-0} + 1 ))
  { for n in "${!USE[@]}"; do printf '%s\t%s\n' "${USE[$n]}" "$n"; done; } > "$USES"
  setsid gtk-launch "${APP_ID[$sel]}" >/dev/null 2>&1 &
elif printf '%s' "$sel" | grep -qF " ┃ "; then
  setsid zen-browser "${sel##* ┃ }" >/dev/null 2>&1 &
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
  setsid zen-browser "$url" >/dev/null 2>&1 &
fi
