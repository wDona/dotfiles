#!/usr/bin/env python3
"""Dialogo de nota para el calendario eww.
Lee el texto inicial por stdin, lo muestra editable (multilinea).
- Guardar / Ctrl+Enter  -> imprime el texto en stdout y sale 0
- Cancelar / Esc         -> sale 1 sin imprimir
Argumentos: note_dialog.py <YYYY-MM-DD>
"""
import sys
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gdk, Gio

DATE = sys.argv[1] if len(sys.argv) > 1 else ""
INITIAL = "" if sys.stdin.isatty() else sys.stdin.read()
CSS = f"{Gio.File.new_for_path(__file__).get_parent().get_path()}/../zenity-theme/gtk-4.0/gtk.css"

result = {"text": None}


def on_activate(app):
    win = Gtk.ApplicationWindow(application=app)
    win.set_title(f"Nota {DATE}")
    win.set_default_size(480, 320)

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    for m in ("set_margin_top", "set_margin_bottom", "set_margin_start", "set_margin_end"):
        getattr(box, m)(12)
    win.set_child(box)

    lbl = Gtk.Label(label=DATE, xalign=0)
    lbl.add_css_class("note-date")
    box.append(lbl)

    sw = Gtk.ScrolledWindow(vexpand=True, hexpand=True)
    tv = Gtk.TextView(wrap_mode=Gtk.WrapMode.WORD_CHAR)
    buf = tv.get_buffer()
    buf.set_text(INITIAL)
    sw.set_child(tv)
    box.append(sw)

    btns = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8, homogeneous=True)
    cancel = Gtk.Button(label="Cancelar")
    save = Gtk.Button(label="Guardar")
    save.add_css_class("suggested-action")
    btns.append(cancel)
    btns.append(save)
    box.append(btns)

    def do_save(*_):
        s, e = buf.get_bounds()
        result["text"] = buf.get_text(s, e, True)
        win.close()

    def do_cancel(*_):
        result["text"] = None
        win.close()

    save.connect("clicked", do_save)
    cancel.connect("clicked", do_cancel)

    key = Gtk.EventControllerKey()
    key.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)

    def on_key(_ctrl, keyval, _code, state):
        ctrl = state & Gdk.ModifierType.CONTROL_MASK
        if keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter) and ctrl:
            do_save()
            return True
        if keyval == Gdk.KEY_Escape:
            do_cancel()
            return True
        return False

    key.connect("key-pressed", on_key)
    win.add_controller(key)

    try:
        prov = Gtk.CssProvider()
        prov.load_from_path(CSS)
        Gtk.StyleContext.add_provider_for_display(
            win.get_display(), prov, Gtk.STYLE_PROVIDER_PRIORITY_USER
        )
    except Exception:
        pass

    tv.grab_focus()
    win.present()


app = Gtk.Application(application_id="eww.note", flags=Gio.ApplicationFlags.NON_UNIQUE)
app.connect("activate", on_activate)
app.run([])

if result["text"] is None:
    sys.exit(1)
sys.stdout.write(result["text"])
sys.exit(0)
