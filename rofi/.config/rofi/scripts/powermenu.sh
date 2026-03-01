#!/usr/bin/env bash

# Función para el menú de confirmación
confirm_exit() {
    # El primer argumento ($1) será la acción: "Apagar", "Reiniciar", etc.
    accion="$1"
    
    si="SÍ\0icon\x1fobject-select-symbolic" 
    no="NO\0icon\x1fwindow-close-symbolic"

    echo -e "${si}\n${no}" | rofi -dmenu -i -normal-window -no-lazy-grab -kb-cancel 'Escape,MousePrimary' -p "${accion}?" \
    -show-icons \
    -theme-str '
    window {
        width:              500px;
        height:             380px;
        background-color:   #1a1b26;
        border:             2px;
        border-color:       #bb9af7;
        border-radius:      20px;
        location:           center;
        anchor:             center;
    }
    mainbox {
        padding:            20px;
        children:           [ "message", "listview", "inputbar" ];
    }
    message { 
        expand: false; 
        margin: 0 0 10px 0; 
    }
    textbox {
        text-color:         #f7768e;
        horizontal-align:   0.5;
        font:               "JetBrainsMono Nerd Font Bold 14";
    }
    listview {
        columns:            2;
        lines:              1;
        spacing:            20px;
        expand:             true;
        fixed-height:       true;
    }
    element {
        padding:            15px;
        border-radius:      15px;
        orientation:        vertical;
    }
    element-icon {
        size:               80px;
        horizontal-align:   0.5;
        enabled:            true;
    }
    element-text {
        horizontal-align:   0.5;
        font:               "JetBrainsMono Nerd Font 12";
    }
    
    /* EL RECUADRO VERDE SIN FONDO BLANCO */
    inputbar {
        margin:             20px 0 0 0;
        padding:            10px;
        background-color:   #9ece6a; /* Tu verde */
        border-radius:      12px;
        children:           [ "dummy", "prompt", "dummy" ];
    }

    prompt {
        enabled:            true;
        background-color:   transparent; /* ESTO QUITA EL FONDO BLANCO */
        text-color:         #1a1b26;      /* Color de texto oscuro para que resalte */
        font:               "JetBrainsMono Nerd Font Bold 13";
        border:             0px;          /* Nos aseguramos de que no haya bordes */
        padding:            0px;          /* Quitamos rellenos extra */
    }

    dummy {
        expand:             true;
        background-color:   transparent;
    }
    
    entry { enabled: false; }

    element selected {
        background-color:   #24283b;
        border:             2px;
        border-color:       #9ece6a;
    }' \
    -hover-select -me-select-entry 'MousePrimary' -me-accept-entry '!MousePrimary'
}

# Opciones
# Definimos las opciones con sus iconos del sistema
# Formato: "Texto para el script\0icon\x1fNombre-del-archivo-de-icono"
# Definimos las opciones con sus iconos (estilo vertical)
opciones="Apagar\0icon\x1fsystem-shutdown
Reiniciar\0icon\x1fsystem-reboot
Suspender\0icon\x1fsystem-suspend
Cerrar Sesión\0icon\x1fsystem-log-out"

seleccion=$(echo -e "$opciones" | rofi -dmenu -i -normal-window -no-lazy-grab -kb-cancel 'Escape,MousePrimary' -p "Sistema" \
    -show-icons \
    -theme-str '
    window {
        width:              800px;      /* Ancho para que quepan los 4 en fila */
        height:             250px;      /* Altura reducida */
        location:           center;
        anchor:             center;
        background-color:   #1a1b26;
        border:             2px;
        border-color:       #bb9af7;
        border-radius:      20px;
    }
    listview {
        columns:            4;          /* ¡4 columnas para horizontal! */
        lines:              1;
        spacing:            20px;
        layout:             vertical;   /* Layout interno del elemento */
    }
    mainbox {
        padding:            20px 10px;
        children:           [ "listview" ];
    }

    element {
        padding:            25px 10px;
        border-radius:      15px;
        orientation:        vertical;
    }
    element-icon {
        size:               64px;       /* Tamaño equilibrado para barra lateral */
        horizontal-align:   0.5;
    }
    element-text {
        horizontal-align:   0.5;
        font:               "JetBrainsMono Nerd Font Bold 12";
    }
    element selected {
        background-color:   #24283b;
        border:             2px;
        border-color:       #9ece6a;
    }' \
    -hover-select -me-select-entry 'MousePrimary' -me-accept-entry '!MousePrimary')

case "$seleccion" in
    "Apagar")
        # Le pasamos "Apagar" como argumento
        ans=$(confirm_exit "Apagar")
        if [[ "$ans" == "SÍ" ]]; then poweroff; fi
        ;;
    "Reiniciar")
        ans=$(confirm_exit "Reiniciar")
        if [[ "$ans" == "SÍ" ]]; then reboot; fi
        ;;
    "Cerrar Sesión")
        ans=$(confirm_exit "Cerrar Sesión")
        if [[ "$ans" == "SÍ" ]]; then hyprctl dispatch exit; fi
        ;;
    "Suspender")
        systemctl suspend
        ;;
esac
