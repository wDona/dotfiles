#!/usr/bin/env bash
# Toggle del popup de volumen. La logica (cierre por ESC, click fuera, un solo
# popup a la vez) vive en popup.sh y es la misma para todos.
exec "$(dirname "$0")/popup.sh" toggle volumen
