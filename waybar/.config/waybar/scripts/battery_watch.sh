#!/usr/bin/env bash
# Escucha eventos udev de power_supply (enchufar/desenchufar cargador) y
# refresca el modulo de bateria de waybar al instante, sin esperar al poll.
udevadm monitor --udev --subsystem-match=power_supply 2>/dev/null | while read -r _; do
    pkill -RTMIN+11 waybar 2>/dev/null
done
