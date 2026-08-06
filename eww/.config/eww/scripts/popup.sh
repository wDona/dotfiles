#!/usr/bin/env bash
# =============================================================================
# popup.sh - gestor UNICO de los popups de eww que cuelgan de la barra.
#
#   popup.sh toggle <ventana>   click en el modulo de waybar
#   popup.sh open   <ventana>   para los toggle_*.sh que refrescan estado antes
#   popup.sh close              ESC, click fuera, botones X, acciones internas
#   popup.sh is-open <ventana>  codigo de salida, sin salida por pantalla
#
# UX COMUN A TODOS (el dashboard de hardware queda FUERA a proposito):
#   - un click en el modulo lo abre, otro click lo cierra
#   - ESC lo cierra (submap `popup` de Hyprland, ver hypr/conf.d/exec.conf)
#   - un click en cualquier punto de la pantalla fuera del popup lo cierra
#     (ventana `backdrop`: transparente, a pantalla completa, justo debajo)
#   - abrir uno cierra el que hubiera: nunca hay dos a la vez
#
# NO hay onhoverlost en ninguno. Cerrarse porque el raton se salio dos pixeles
# es justo el accidente que hacia que estos paneles se sintieran fragiles:
# ahora todo cierre es deliberado (un click en cualquier sitio, o una tecla).
#
# El backdrop NO tapa la barra: waybar reserva su franja con exclusive zone y
# el backdrop empieza justo debajo. Por eso cambiar de un popup a otro sigue
# costando UN click sobre el modulo, y no dos (cerrar + abrir).
# =============================================================================
set -u

DIR="$(dirname "$0")"

# Ventanas gestionadas. `dashboard` NO esta y no debe estarlo: es un panel que
# se deja fijo mientras se trabaja, no un menu efimero.
POPUPS=(calendario clima volumen sysmenu batmenu personalizacion)

# Hablar con eww cuesta ~1s de timeout si el daemon no vive, y `close` lo
# llaman botones de waybar que deben responder al instante.
alive() { pgrep -x eww >/dev/null; }

open_list() { eww active-windows 2>/dev/null | cut -d: -f1; }

is_open() { open_list | grep -qx "$1"; }

close_all() {
    if alive; then
        local abiertas w
        abiertas=$(open_list)
        for w in backdrop "${POPUPS[@]}"; do
            grep -qx "$w" <<< "$abiertas" && eww close "$w" 2>/dev/null
        done
        # Estado efimero que no debe sobrevivir al cierre: si no, al reabrir
        # el calendario aparece el selector de mes desplegado.
        eww update cal_picker="none" cal_selected="" event_input="" 2>/dev/null
    fi
    # Siempre, aunque eww no viva: dejar el submap colgado deja al usuario sin
    # atajos de teclado hasta reiniciar Hyprland.
    hyprctl dispatch submap reset >/dev/null 2>&1
}

open_win() {
    local win="$1" mon
    "$DIR/eww_ensure.sh"
    close_all
    mon=$("$DIR/eww_screen.sh")
    # El backdrop va PRIMERO: dentro de la misma capa (overlay) manda el orden
    # de creacion, asi que lo que se abre despues queda por encima.
    eww open backdrop --screen "$mon"
    eww open "$win" --screen "$mon"
    hyprctl dispatch submap popup >/dev/null 2>&1
}

case "${1:-}" in
    close)
        close_all
        ;;
    open)
        open_win "${2:?falta la ventana}"
        ;;
    toggle)
        win="${2:?falta la ventana}"
        "$DIR/eww_ensure.sh"
        if is_open "$win"; then close_all; else open_win "$win"; fi
        ;;
    is-open)
        is_open "${2:?falta la ventana}"
        ;;
    *)
        echo "uso: popup.sh {toggle|open|close|is-open} [ventana]" >&2
        exit 1
        ;;
esac
