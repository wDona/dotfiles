SETUP - resumen rapido (detalle en ../README.md)

INSTALAR EN UN PC NUEVO
  sudo pacman -S --needed git
  git clone <repo> ~/dotfiles
  sudo ~/dotfiles/setup/bootstrap.sh
  reiniciar

DESPUES, SOLO INICIAR SESION
  gcalcli init        Google Calendar (panel eww)
  claude / opencode   agentes IA
  Brave, VS Code      cuenta
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
  panel de energia     sudo systemctl disable --now tlp
  de eww (usa ppd)     sudo systemctl enable --now power-profiles-daemon

OJO
  - bootstrap crea NOPASSWD temporal en /etc/sudoers.d (makepkg y yay no
    corren como root). Se borra al salir, incluso si falla.
  - hypr/conf.d/env.conf tiene /home/wdona a pelo: cambialo si el usuario
    del PC nuevo no se llama igual.
  - tlp y power-profiles-daemon no pueden estar activos a la vez.
  - link.sh aparta lo que estorbe como .bkup, no borra nada.
