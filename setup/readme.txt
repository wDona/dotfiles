SETUP - resumen rapido (detalle en ../README.md)

INSTALAR EN UN PC NUEVO
  sudo pacman -S --needed git
  git clone <repo> ~/dotfiles
  sudo ~/dotfiles/setup/bootstrap.sh
  reiniciar

DESPUES, SOLO INICIAR SESION
  gcalcli init        Google Calendar (panel eww)
  claude / opencode   agentes IA
  Zen, VS Code        cuenta (uBlock+Bitwarden force-installed por policy)
  keyring             se crea en el 1er login grafico:
                      MISMA contrasena que el usuario

FICHEROS
  bootstrap.sh     todo el setup. Necesita sudo.
  link.sh          symlinks a $HOME (sustituye a stow). SIN sudo.
  packages.txt     pacman -Qqen
  aur.txt          pacman -Qqem
  npm-global.txt   globales de npm
  etc/             se copia tal cual a /etc

TAREAS SUELTAS
  relinkar             ~/dotfiles/setup/link.sh
  refrescar paquetes   pacman -Qqen > setup/packages.txt
                       pacman -Qqem > setup/aur.txt
  perfiles de energia  ya no hace falta tocar nada: manda tlp y el selector
                       de eww usa /usr/local/bin/powerprofile (kernel directo).
                       Probar:  powerprofile get
                                sudo powerprofile set balanced

OJO
  - bootstrap crea NOPASSWD temporal en /etc/sudoers.d (makepkg y yay no
    corren como root). Se borra al salir, incluso si falla.
  - hypr/conf.d/env.conf tiene /home/wdona a pelo: cambialo si el usuario
    del PC nuevo no se llama igual.
  - power-profiles-daemon queda ENMASCARADO a proposito: lleva
    Conflicts=tlp.service y mataba a tlp en cada arranque. Con 'disable' no
    bastaba, se activaba por D-Bus solo con que waybar pintase la barra.
    El selector de eww no lo echa de menos: powerprofile hace lo mismo
    escribiendo platform_profile, gobernador y EPP.
  - powerprofile vive en /usr/local/bin (de root) y no en el repo enlazado:
    /etc/sudoers.d/10-powerprofile le da NOPASSWD, y un script con sudo
    NOPASSWD que el usuario pueda editar es root gratis. bootstrap.sh lo
    copia desde setup/usr-local-bin/.
  - link.sh aparta lo que estorbe como .bkup, no borra nada.
