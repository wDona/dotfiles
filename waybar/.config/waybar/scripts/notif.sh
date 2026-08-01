#!/bin/bash
# Indicador de notificaciones swaync para waybar.
#  - Muestra el NUMERO de notis del cajon.
#  - Punto/realce rojo solo si hay NUEVAS sin ver.
#  - Al abrir el cajon: `notif.sh seen` marca todo como visto (rojo fuera),
#    pero las notis se conservan -> el numero sigue.
# Clases CSS emitidas: none | seen | new

SEEN="${XDG_RUNTIME_DIR:-/tmp}/swaync_seen_count"
[ -f "$SEEN" ] || echo 0 > "$SEEN"

count=$(swaync-client -c 2>/dev/null)
[ -z "$count" ] && count=0

# Subcomando: marcar como visto (lo llama el on-click al abrir el panel)
if [ "$1" = "seen" ]; then
    echo "$count" > "$SEEN"
    exit 0
fi

seen=$(cat "$SEEN" 2>/dev/null || echo 0)
# Si se cerraron notis, baja el contador de "visto"
if [ "$count" -lt "$seen" ]; then
    seen=$count
    echo "$seen" > "$SEEN"
fi

bell="󰂚"   # nf-md-bell (campana, codepoint F009A)

new=$((count - seen))
[ "$new" -lt 0 ] && new=0

if [ "$new" -gt 0 ]; then
    # hay sin leer -> campana con punto rojo en esquina sup-dcha (pango) + numero, sin recuadro
    # El hueco lo hace un espacio a 9pt (~3px), no letter_spacing negativo: ese
    # se comia el ancho del espacio segun la metrica de la fuente y con
    # ttf-jetbrains-mono-nerd 3.4 el punto acababa encima del icono.
    dot="<span foreground='#ff3030' size='9000' rise='5000'> •</span>"
    printf '{"text":"%s%s %s","class":"new","tooltip":"%s sin leer · %s en total"}\n' "$bell" "$dot" "$new" "$new" "$count"
elif [ "$count" -eq 0 ]; then
    printf '{"text":"%s","class":"none","tooltip":"Sin notificaciones"}\n' "$bell"
else
    # todas leidas -> solo campana, sin numero
    printf '{"text":"%s","class":"seen","tooltip":"%s leidas"}\n' "$bell" "$count"
fi
