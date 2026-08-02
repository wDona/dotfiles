#!/usr/bin/env python3
"""BRB overlay: fullscreen 'be right back' card with live countdown.

Usage: brb.py [minutes] [message...]        (varios: separados por comas)
       brb.py 10 café, 5 agua, 25 curro
No args -> rofi prompt: "10 café"  (first token = minutes, rest = message)
             con historial de entradas anteriores para reutilizar.
             Enter con el campo vacio arranca la cola ya introducida.
             Alt+Supr sobre una entrada la borra del historial.
Los temporizadores se encadenan en el orden en que se meten: los pasados
quedan arriba en pequeño, el que corre en grande, los que faltan debajo.
Any key / click closes it.
"""
import html, os, sys, subprocess, time
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, GLib, Gdk

CSS = b"""
window { background: linear-gradient(135deg, #1a1b26, #24283b); }
.row        { opacity: 0.30; }
.row label  { font-size: 30px; font-weight: 800; }
.row .time  { color: #7aa2f7; font-feature-settings: "tnum"; }
.row .msg   { color: #c0caf5; }
.row.done label { color: #565f89; }
.row.current       { opacity: 1; }
.row.current .msg  { font-size: 64px; font-weight: 800; }
.row.current .time { font-size: 140px; font-weight: 900; }
.row.current.over .time { color: #f7768e; }
#hint  { font-size: 20px; color: #565f89; }
"""


HIST = os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "brb_history",
)
MAX_HIST = 15


def load_history():
    try:
        with open(HIST, encoding="utf-8") as f:
            return [ln.strip() for ln in f if ln.strip()]
    except FileNotFoundError:
        return []


def save_history(entries):
    os.makedirs(os.path.dirname(HIST), exist_ok=True)
    with open(HIST, "w", encoding="utf-8") as f:
        for e in entries[:MAX_HIST]:
            f.write(e + "\n")


def remember(raw):
    """Mueve raw al principio del historial (sin duplicarlo)."""
    entries = [e for e in load_history() if e != raw]
    entries.insert(0, raw)
    save_history(entries)


def split(raw):
    head, _, rest = raw.partition(" ")
    try:
        return int(head), (rest.strip() or "Vuelvo enseguida")
    except ValueError:
        # Sin numero delante: el texto entero es el mensaje, 5 min por defecto.
        return 5, raw


def parse(argv):
    if argv:
        raws = [p.strip() for p in " ".join(argv).split(",") if p.strip()]
        for r in raws:
            remember(r)
        return [split(r) for r in raws]

    queue = []
    # Cada Enter encola otro temporizador, en el orden en que se meten.
    # Shift+Enter arranca (Enter a secas no vale: con el campo vacio rofi
    # elige la primera entrada del historial). Alt+Supr borra del historial
    # y vuelve al menu en vez de salir, asi se limpian varias de una sentada.
    while True:
        hist = load_history()
        mesg = ("minutos + mensaje (ej: 10 café) · Enter encola · "
                "Shift+Enter arranca · Alt+Supr borra del historial")
        if queue:
            cola = " → ".join(f"{m}m {t}" for m, t in queue)
            mesg = f"<b>{html.escape(cola)}</b>\n{mesg}"
        proc = subprocess.run(
            ["rofi", "-dmenu", "-p", f"BRB {len(queue) + 1}",
             # -l al tamaño real: con historial vacio queda en 0 y el menu se
             # colapsa como antes, sin dejar un hueco de lista vacia.
             "-l", str(min(len(hist), 8)),
             "-kb-custom-1", "Alt+Delete",
             # Shift+Return viene ocupado por kb-accept-alt: hay que soltarlo
             # antes o rofi aborta por binding duplicado.
             "-kb-accept-alt", "",
             "-kb-custom-2", "Shift+Return",
             "-mesg", mesg],
            capture_output=True, text=True, input="\n".join(hist),
        )
        raw = proc.stdout.strip()

        if proc.returncode == 10:          # Alt+Supr
            if raw:
                save_history([e for e in load_history() if e != raw])
            continue
        if proc.returncode == 11:          # Shift+Enter: arranca lo encolado
            if queue:
                return queue
            sys.exit(0)
        if proc.returncode != 0 or not raw:  # Escape / vacio: cancela todo
            sys.exit(0)

        remember(raw)
        queue.append(split(raw))


def fmt(secs, sign=""):
    return f"{sign}{secs // 60:02d}:{secs % 60:02d}"


def on_activate(app, timers):
    win = Gtk.ApplicationWindow(application=app)
    win.set_decorated(False)
    # sin fullscreen(): dispara direct_scanout y GTK4 se queda en negro.
    # tamano/pin los pone la windowrule brb-overlay en window-rules.conf.
    win.set_default_size(1920, 1080)

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    box.set_valign(Gtk.Align.CENTER)
    box.set_halign(Gtk.Align.CENTER)

    rows = []
    for minutes, message in timers:
        row = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        row.set_halign(Gtk.Align.CENTER)
        row.add_css_class("row")
        msg = Gtk.Label(label=message, css_classes=["msg"])
        timer = Gtk.Label(label=fmt(minutes * 60), css_classes=["time"])
        row.append(msg)
        row.append(timer)
        box.append(row)
        rows.append((row, timer))

    hint = Gtk.Label(label="cualquier tecla para cerrar", name="hint")
    box.append(hint)
    win.set_child(box)

    state = {"i": 0, "deadline": time.monotonic() + timers[0][0] * 60}
    rows[0][0].add_css_class("current")

    def tick():
        i = state["i"]
        row, timer = rows[i]
        left = state["deadline"] - time.monotonic()

        if left < 0 and i + 1 < len(rows):
            # se acabo: arranca el siguiente, este sube a la lista de pasados
            row.remove_css_class("current")
            row.add_css_class("done")
            timer.set_label(fmt(0))
            state["i"] = i + 1
            state["deadline"] = time.monotonic() + timers[i + 1][0] * 60
            rows[i + 1][0].add_css_class("current")
            return True

        over = left < 0                    # solo el ultimo se pasa de rosca
        timer.set_label(fmt(int(abs(left)), "+" if over else ""))
        # ponytail: css class toggle, no animation. add pulse if it needs more drama
        (row.add_css_class if over else row.remove_css_class)("over")
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
    app = Gtk.Application(application_id="dev.local.brb")
    app.connect("activate", on_activate, parse(sys.argv[1:]))
    app.run([])
