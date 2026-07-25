#!/usr/bin/env python3
"""BRB overlay: fullscreen 'be right back' card with live countdown.

Usage: brb.py [minutes] [message...]
No args -> rofi prompt: "10 café"  (first token = minutes, rest = message)
Any key / click closes it.
"""
import sys, subprocess, time
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, GLib, Gdk

CSS = b"""
window { background: linear-gradient(135deg, #1a1b26, #24283b); }
#msg   { font-size: 64px; font-weight: 800; color: #c0caf5; }
#timer { font-size: 180px; font-weight: 900; color: #7aa2f7;
         font-feature-settings: "tnum"; }
#timer.over { color: #f7768e; }
#hint  { font-size: 20px; color: #565f89; }
"""


def parse(argv):
    if argv:
        raw = " ".join(argv)
    else:
        raw = subprocess.run(
            ["rofi", "-dmenu", "-p", "BRB", "-l", "0",
             "-mesg", "minutos + mensaje  (ej: 10 café)"],
            capture_output=True, text=True, input="",
        ).stdout.strip()
    if not raw:
        sys.exit(0)
    head, _, rest = raw.partition(" ")
    try:
        return int(head), (rest.strip() or "Vuelvo enseguida")
    except ValueError:
        return 5, raw


def on_activate(app, minutes, message):
    win = Gtk.ApplicationWindow(application=app)
    win.set_decorated(False)
    # sin fullscreen(): dispara direct_scanout y GTK4 se queda en negro.
    # tamano/pin los pone la windowrule brb-overlay en window-rules.conf.
    win.set_default_size(1920, 1080)

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
    box.set_valign(Gtk.Align.CENTER)
    box.set_halign(Gtk.Align.CENTER)

    msg = Gtk.Label(label=message, name="msg")
    timer = Gtk.Label(label="", name="timer")
    hint = Gtk.Label(label="cualquier tecla para cerrar", name="hint")
    for w in (msg, timer, hint):
        box.append(w)
    win.set_child(box)

    deadline = time.monotonic() + minutes * 60

    def tick():
        left = deadline - time.monotonic()
        over = left < 0
        s = int(abs(left))
        timer.set_label(f"{'+' if over else ''}{s // 60:02d}:{s % 60:02d}")
        # ponytail: css class toggle, no animation. add pulse if it needs more drama
        (timer.add_css_class if over else timer.remove_css_class)("over")
        return True

    tick()
    GLib.timeout_add(200, tick)

    for ctrl, sig in ((Gtk.EventControllerKey(), "key-pressed"),
                      (Gtk.GestureClick(), "pressed")):
        ctrl.connect(sig, lambda *_: win.close())
        win.add_controller(ctrl)

    prov = Gtk.CssProvider()
    prov.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    win.present()


if __name__ == "__main__":
    mins, text = parse(sys.argv[1:])
    app = Gtk.Application(application_id="dev.local.brb")
    app.connect("activate", on_activate, mins, text)
    app.run([])
