#!/usr/bin/env bash
# Perfil de energia activo, para defpoll de eww.
# Antes lo daba power-profiles-daemon por D-Bus; ppd esta enmascarado porque
# mata a tlp (Conflicts=), asi que lo lee powerprofile del kernel directamente.
exec /usr/local/bin/powerprofile get 2>/dev/null
