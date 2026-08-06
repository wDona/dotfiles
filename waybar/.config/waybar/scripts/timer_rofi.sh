#!/usr/bin/env bash
# =============================================================================
# timer_rofi.sh - poner temporizador con el teclado (SUPER+R).
#
# Es el camino de teclado del MISMO temporizador que el popup de la barra:
# los dos acaban llamando a timer.sh, no hay dos estados.
#   - raton   -> click en el modulo, lista de presets, un click
#   - teclado -> SUPER+R, escribes "5m", Enter
#
# Por que rofi y no una ventana de eww: para escribir dentro de un popup de eww
# la ventana tiene que pedir el teclado en exclusiva (:focusable), y entonces
# Hyprland le entrega TODO el input; la barra deja de responder al raton y solo
# se puede salir con su boton de cerrar. Rofi es una ventana normal, ya va con
# la paleta del rice (rofi/config.rasi) y no rompe nada.
#
# Tres tipos de fila, y se distinguen por el icono:
#   󰈼  cronometro        fija
#   (sin icono)          presets: los eliges tu, duran hasta que los borres
#   󰋚  historial         lo ultimo que pusiste, se llena solo (10 max)
# Alt+Supr sobre una fila la borra (preset o historial), igual que en brb.py.
# =============================================================================
set -u

TIMER="$HOME/.config/waybar/scripts/timer.sh"
HINT="5m · 1h30m · 2:30 · @18:30  ·  Alt+Supr borra una fila"
H_PRE="󰋚  "   # prefijo de las filas de historial (se quita antes de aplicar)

info=$("$TIMER" status)
class=$(jq -r '.class' <<< "$info")
plain=$(jq -r '.plain' <<< "$info")

CANCELAR="󰜺  Cancelar lo actual"
CRONO="󰈼  Cronometro"

presets=$("$TIMER" presets | jq -r '.[]')

# El historial no repite lo que ya es preset: seria la misma fila dos veces.
historial=$("$TIMER" history 2>/dev/null)
if [ -n "$historial" ] && [ -n "$presets" ]; then
    historial=$(grep -vxF -f <(printf '%s\n' "$presets") <<< "$historial" || true)
fi
[ -n "$historial" ] && historial=$(sed "s/^/${H_PRE}/" <<< "$historial")

# Con algo corriendo, la primera fila es cancelar y el aviso dice que elegir
# cualquier otra cosa lo reemplaza: la advertencia va DELANTE de la accion, no
# en un dialogo despues.
filas=$(printf '%s\n%s\n%s' "$CRONO" "$presets" "$historial" | grep -v '^$')
if [ "$class" != "idle" ]; then
    mesg="Ahora: ${plain}  ·  elegir otra cosa lo reemplaza"
    filas=$(printf '%s\n%s' "$CANCELAR" "$filas")
else
    mesg="$HINT"
fi

sel=$(printf '%s\n' "$filas" | rofi -dmenu -i -p "Temporizador" -mesg "$mesg" \
        -kb-cancel 'Escape,MousePrimary' -kb-custom-1 'Alt+Delete')
rc=$?

[ -z "$sel" ] && exit 0

# rc 10 = Alt+Supr: borrar la fila y volver al menu, sin poner nada.
if [ "$rc" -eq 10 ]; then
    case "$sel" in
        "$CANCELAR"|"$CRONO") ;;                       # fijas, no se borran
        "$H_PRE"*) "$TIMER" delhist "${sel#"$H_PRE"}" ;;
        *)         "$TIMER" delpreset "$sel" ;;
    esac
    exec "$0"
fi
[ "$rc" -ne 0 ] && exit 0

case "$sel" in
    "$CANCELAR") exec "$TIMER" forcecancel ;;
    "$CRONO")    exec "$TIMER" apply cronometro ;;
    "$H_PRE"*)   exec "$TIMER" apply "${sel#"$H_PRE"}" ;;
    # Preset elegido o texto escrito a mano: timer.sh valida el formato y avisa
    # por notificacion si no cuela.
    *)           exec "$TIMER" apply "$sel" ;;
esac
