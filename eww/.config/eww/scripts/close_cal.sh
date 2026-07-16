#!/usr/bin/env bash
# Cierra el calendario eww y restaura el submap (lo usa el bind de ESC).
# Solo hablar con eww si el daemon vive (si no, cada llamada espera ~1s al
# timeout de conexión y mete lag al botón del launcher en waybar).
if pgrep -x eww >/dev/null; then
    eww close calendario 2>/dev/null
    eww update cal_picker="none" cal_selected="" event_input="" 2>/dev/null
fi
hyprctl dispatch submap reset >/dev/null 2>&1
