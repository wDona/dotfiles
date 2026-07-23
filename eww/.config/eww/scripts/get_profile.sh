#!/usr/bin/env bash
# Perfil de energia activo (power-profiles-daemon), para defpoll de eww.
gdbus call --system --dest net.hadess.PowerProfiles \
    --object-path /net/hadess/PowerProfiles \
    --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile \
    2>/dev/null | grep -oP "'\K[^']+" | head -1
