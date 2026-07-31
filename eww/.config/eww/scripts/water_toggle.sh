#!/usr/bin/env bash
set -euo pipefail

# systemctl enable/disable en unidades symlink (stow) borra el propio
# fragmento, no solo el want-symlink. Se gestiona el want-symlink a mano.
udir="$HOME/.config/systemd/user"
timer_want="$udir/timers.target.wants/water-reminder.timer"
boot_want="$udir/default.target.wants/water-reminder-boot.service"

case "${1:-status}" in
    status)
        systemctl --user is-active --quiet water-reminder.timer && echo 1 || echo 0
        ;;
    on)
        mkdir -p "$udir/timers.target.wants" "$udir/default.target.wants"
        ln -sf "$udir/water-reminder.timer" "$timer_want"
        ln -sf "$udir/water-reminder-boot.service" "$boot_want"
        systemctl --user daemon-reload
        systemctl --user start water-reminder.timer water-reminder-boot.service
        ;;
    off)
        systemctl --user stop water-reminder.timer
        rm -f "$timer_want" "$boot_want"
        systemctl --user daemon-reload
        ;;
esac
