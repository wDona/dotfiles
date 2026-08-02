#!/usr/bin/env python
"""Mando DS4 -> rofi, Lutris y la terminal de Claude.

- Boton PS: lanza launch_rofi.sh (que ya hace toggle: abre / cierra). Siempre activo.
- Contexto activo = rofi abierto, o ventana enfocada listada en CONTEXTS. En cualquiera:
    dpad -> flechas                   stick izq -> scroll
    stick der -> puntero              R2/L2 -> click izq/der
    X -> Enter        O -> Esc        triangulo -> Tab    cuadrado -> Backspace
    L1/R1 -> PageUp/PageDown          Share -> toggle de claude-term
- Fuera de contexto no emite nada, asi que los juegos no se enteran
  (no se hace grab del mando).
"""
import json
import subprocess
import threading
import time

from evdev import InputDevice, UInput, ecodes as e, list_devices

DEV_NAME = "Wireless Controller"
LAUNCH = "/home/wdona/.config/rofi/scripts/launch_rofi.sh"
CONTEXTS = {"net.lutris.Lutris", "claude-term"}  # class de ventana enfocada
TOGGLE_CLAUDE = "/home/wdona/.config/hypr/scripts/toggle_claude.sh"
POLL_CACHE = 0.4    # s que dura el resultado de pgrep/hyprctl
TICK_HZ = 60
MOUSE_SPEED = 900   # px/s a tope de stick derecho
SCROLL_SPEED = 32   # clicks de rueda/s a tope de stick izquierdo

BTN_KEYS = {
    e.BTN_SOUTH: e.KEY_ENTER,      # X
    e.BTN_EAST: e.KEY_ESC,         # O
    e.BTN_WEST: e.KEY_BACKSPACE,   # cuadrado
    e.BTN_NORTH: e.KEY_TAB,        # triangulo
    e.BTN_TL: e.KEY_PAGEUP,        # L1
    e.BTN_TR: e.KEY_PAGEDOWN,      # R1
}
# dpad -> (tecla valor negativo, tecla valor positivo)
AXIS_KEYS = {
    e.ABS_HAT0X: (e.KEY_LEFT, e.KEY_RIGHT),
    e.ABS_HAT0Y: (e.KEY_UP, e.KEY_DOWN),
}
MOUSE_BTNS = {e.BTN_TR2: e.BTN_LEFT, e.BTN_TL2: e.BTN_RIGHT}
ALL_KEYS = sorted(set(BTN_KEYS.values()) | {k for p in AXIS_KEYS.values() for k in p})


def find_pad():
    for path in list_devices():
        try:
            dev = InputDevice(path)
        except OSError:
            continue
        if DEV_NAME in dev.name and e.BTN_SOUTH in dev.capabilities().get(e.EV_KEY, []):
            return dev
    return None


def focused_class():
    try:
        out = subprocess.run(
            ["hyprctl", "activewindow", "-j"], capture_output=True, text=True, timeout=1
        ).stdout
        return json.loads(out).get("class", "")
    except (OSError, ValueError, subprocess.SubprocessError):
        return ""


class Emitter:
    """Teclado + raton virtuales. Las teclas se sueltan siempre; solo se pulsan en contexto."""

    def __init__(self, kbd, mouse):
        self.kbd, self.mouse = kbd, mouse
        self.pressed = {}          # code -> dispositivo que lo emitio
        self._active = False
        self._cls = ""
        self._checked = 0.0
        self.lock = threading.Lock()

    def _poll(self):
        """Refresca contexto. Cacheado: si no, seria un pgrep + hyprctl por evento."""
        now = time.monotonic()
        if now - self._checked > POLL_CACHE:
            self._checked = now
            was = self._active
            rofi = subprocess.run(
                ["pgrep", "-x", "rofi"], stdout=subprocess.DEVNULL
            ).returncode == 0
            # rofi es layer-shell: activewindow devuelve la ventana de debajo, no rofi
            self._cls = "" if rofi else focused_class()
            self._active = rofi or self._cls in CONTEXTS
            if was and not self._active:  # se cerro/desenfoco con algo pulsado
                self.release_all()

    def active(self):
        """True si rofi esta abierto o la ventana enfocada esta en CONTEXTS."""
        self._poll()
        return self._active

    def focused(self):
        """Class de la ventana enfocada ('' si rofi esta abierto por encima)."""
        self._poll()
        return self._cls

    def set(self, code, down, mouse=False):
        with self.lock:
            if down:
                if code in self.pressed:
                    return
                self.pressed[code] = self.mouse if mouse else self.kbd
            elif code not in self.pressed:
                return
            dev = self.pressed[code]
            dev.write(e.EV_KEY, code, 1 if down else 0)
            dev.syn()
            if not down:
                del self.pressed[code]

    def emit_rel(self, axis, value):
        with self.lock:
            self.mouse.write(e.EV_REL, axis, value)
            self.mouse.syn()

    def release_all(self):
        for code in list(self.pressed):
            self.set(code, False)


def axis_dir(value):
    """-1 / 0 / +1 para el dpad (rango -1..1)."""
    return (value > 0) - (value < 0)


def axis_norm(dev, code, value):
    """-1.0..1.0 con zona muerta, para los sticks."""
    info = dev.absinfo(code)
    center = (info.max + info.min) / 2
    frac = (value - center) / ((info.max - info.min) / 2)
    dead = 0.15
    if abs(frac) < dead:
        return 0.0
    frac = (abs(frac) - dead) / (1 - dead) * (1 if frac > 0 else -1)
    return frac * abs(frac)  # respuesta cuadratica: preciso cerca del centro


class Sticks(threading.Thread):
    """Los sticks dan posicion, no desplazamiento: hace falta un tick propio.

    Izquierdo -> rueda (vertical y horizontal). Derecho -> puntero.
    """

    daemon = True

    def __init__(self, out):
        super().__init__()
        self.out = out
        self.left = [0.0, 0.0]
        self.right = [0.0, 0.0]
        self.wheel = [0.0, 0.0]  # acumuladores: la rueda va en clicks enteros

    def run(self):
        step = 1.0 / TICK_HZ
        while True:
            lx, ly = self.left
            rx, ry = self.right
            if not (lx or ly or rx or ry) or not self.out.active():
                self.wheel = [0.0, 0.0]
                time.sleep(step * 4)
                continue
            dx, dy = round(rx * MOUSE_SPEED * step), round(ry * MOUSE_SPEED * step)
            if dx:
                self.out.emit_rel(e.REL_X, dx)
            if dy:
                self.out.emit_rel(e.REL_Y, dy)
            self.wheel[0] += lx * SCROLL_SPEED * step
            self.wheel[1] -= ly * SCROLL_SPEED * step  # stick arriba = scroll arriba
            for i, axis in ((0, e.REL_HWHEEL), (1, e.REL_WHEEL)):
                clicks = int(self.wheel[i])
                if clicks:
                    self.wheel[i] -= clicks
                    self.out.emit_rel(axis, clicks)
            time.sleep(step)


def run(dev, out, sticks):
    axis_state = {code: 0 for code in AXIS_KEYS}
    for ev in dev.read_loop():
        if ev.type == e.EV_KEY:
            if ev.code == e.BTN_MODE:
                if ev.value == 1:
                    out.release_all()
                    subprocess.Popen([LAUNCH])
            # Share: esconde claude-term si esta enfocada, la saca desde Lutris.
            # Solo dentro de CONTEXTS, para no pisarselo a ningun juego.
            elif ev.code == e.BTN_SELECT:
                if ev.value == 1 and out.focused() in CONTEXTS:
                    out.release_all()
                    subprocess.Popen([TOGGLE_CLAUDE])
            elif ev.code in MOUSE_BTNS:
                if ev.value == 1 and not out.active():
                    continue
                out.set(MOUSE_BTNS[ev.code], ev.value == 1, mouse=True)
            elif ev.code in BTN_KEYS:
                if ev.value == 2:  # autorepeat: ya lo hace el compositor
                    continue
                if ev.value == 1 and not out.active():
                    continue
                out.set(BTN_KEYS[ev.code], ev.value == 1)
        elif ev.type == e.EV_ABS:
            if ev.code in (e.ABS_X, e.ABS_Y):
                sticks.left[ev.code == e.ABS_Y] = axis_norm(dev, ev.code, ev.value)
            elif ev.code in (e.ABS_RX, e.ABS_RY):
                sticks.right[ev.code == e.ABS_RY] = axis_norm(dev, ev.code, ev.value)
            elif ev.code in AXIS_KEYS:
                new = axis_dir(ev.value)
                old = axis_state[ev.code]
                if new == old:
                    continue
                axis_state[ev.code] = new
                neg, pos = AXIS_KEYS[ev.code]
                if old:
                    out.set(neg if old < 0 else pos, False)
                if new and out.active():
                    out.set(neg if new < 0 else pos, True)


def main():
    kbd = UInput({e.EV_KEY: ALL_KEYS}, name="ds4-rofi-kbd")
    mouse = UInput(
        {
            e.EV_KEY: list(MOUSE_BTNS.values()),
            e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL, e.REL_HWHEEL],
        },
        name="ds4-rofi-mouse",
    )
    out = Emitter(kbd, mouse)
    sticks = Sticks(out)
    sticks.start()
    while True:  # el mando se conecta/desconecta cuando le da la gana
        dev = find_pad()
        if dev is None:
            time.sleep(2)
            continue
        try:
            run(dev, out, sticks)
        except OSError:
            pass
        finally:
            out.release_all()
            sticks.left = [0.0, 0.0]
            sticks.right = [0.0, 0.0]
            dev.close()
        time.sleep(2)


if __name__ == "__main__":
    main()
