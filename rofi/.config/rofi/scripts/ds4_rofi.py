#!/usr/bin/env python
"""Mando DS4 -> rofi, Lutris y la terminal de Claude.

- Boton PS: lanza launch_rofi.sh (que ya hace toggle: abre / cierra). Siempre activo.
- Contexto activo = rofi abierto, o ventana enfocada listada en CONTEXTS. En cualquiera:
    dpad y stick izq -> flechas       X -> Enter          O -> Esc
    triangulo -> Tab                  cuadrado -> Backspace
    L1/R1 -> PageUp/PageDown          R2/L2 -> click izq/der
- Stick derecho segun contexto: puntero en Lutris, scroll en claude-term,
  nada en rofi (no le hace falta).
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
# class de ventana enfocada -> que hace el stick derecho ahi
CONTEXTS = {
    "net.lutris.Lutris": "pointer",
    "claude-term": "scroll",
}
POLL_CACHE = 0.4    # s que dura el resultado de pgrep/hyprctl
TICK_HZ = 60
MOUSE_SPEED = 900   # px/s a tope de stick
SCROLL_SPEED = 12   # clicks de rueda/s a tope de stick

BTN_KEYS = {
    e.BTN_SOUTH: e.KEY_ENTER,      # X
    e.BTN_EAST: e.KEY_ESC,         # O
    e.BTN_WEST: e.KEY_BACKSPACE,   # cuadrado
    e.BTN_NORTH: e.KEY_TAB,        # triangulo
    e.BTN_TL: e.KEY_PAGEUP,        # L1
    e.BTN_TR: e.KEY_PAGEDOWN,      # R1
}
# eje -> (tecla valor negativo, tecla valor positivo)
AXIS_KEYS = {
    e.ABS_HAT0X: (e.KEY_LEFT, e.KEY_RIGHT),
    e.ABS_HAT0Y: (e.KEY_UP, e.KEY_DOWN),
    e.ABS_X: (e.KEY_LEFT, e.KEY_RIGHT),
    e.ABS_Y: (e.KEY_UP, e.KEY_DOWN),
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
        self._ctx = None
        self._checked = 0.0
        self.lock = threading.Lock()

    def context(self):
        """None, 'rofi', o el modo de stick derecho de CONTEXTS ('pointer'/'scroll').

        Cacheado: si no, seria un pgrep + hyprctl por evento del mando.
        """
        now = time.monotonic()
        if now - self._checked > POLL_CACHE:
            self._checked = now
            was = self._ctx
            if subprocess.run(["pgrep", "-x", "rofi"], stdout=subprocess.DEVNULL).returncode == 0:
                self._ctx = "rofi"
            else:
                self._ctx = CONTEXTS.get(focused_class())
            if was and was != self._ctx:  # cambio de contexto con algo pulsado
                self.release_all()
        return self._ctx

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


def axis_dir(dev, code, value):
    """-1 / 0 / +1 para hats (rango 1) y sticks (rango grande, con zona muerta)."""
    info = dev.absinfo(code)
    span = info.max - info.min
    if span <= 2:  # dpad
        return (value > 0) - (value < 0)
    center = (info.max + info.min) / 2
    if value < center - span * 0.3:
        return -1
    if value > center + span * 0.3:
        return 1
    return 0


def axis_norm(dev, code, value):
    """-1.0..1.0 con zona muerta, para el stick derecho."""
    info = dev.absinfo(code)
    center = (info.max + info.min) / 2
    frac = (value - center) / ((info.max - info.min) / 2)
    dead = 0.15
    if abs(frac) < dead:
        return 0.0
    frac = (abs(frac) - dead) / (1 - dead) * (1 if frac > 0 else -1)
    return frac * abs(frac)  # respuesta cuadratica: preciso cerca del centro


class Stick(threading.Thread):
    """El stick da posicion, no desplazamiento: hace falta un tick propio.

    Modo 'pointer' -> movimiento de raton. Modo 'scroll' -> rueda vertical.
    """

    daemon = True

    def __init__(self, out):
        super().__init__()
        self.out = out
        self.vec = [0.0, 0.0]
        self.wheel_acc = 0.0

    def run(self):
        step = 1.0 / TICK_HZ
        while True:
            x, y = self.vec
            mode = self.out.context() if (x or y) else None
            if mode == "pointer":
                dx, dy = round(x * MOUSE_SPEED * step), round(y * MOUSE_SPEED * step)
                if dx:
                    self.out.emit_rel(e.REL_X, dx)
                if dy:
                    self.out.emit_rel(e.REL_Y, dy)
            elif mode == "scroll":
                self.wheel_acc -= y * SCROLL_SPEED * step  # stick arriba = scroll arriba
                clicks = int(self.wheel_acc)
                if clicks:
                    self.wheel_acc -= clicks
                    self.out.emit_rel(e.REL_WHEEL, clicks)
            else:
                self.wheel_acc = 0.0
                time.sleep(step * 4)
                continue
            time.sleep(step)


def run(dev, out, stick):
    axis_state = {code: 0 for code in AXIS_KEYS}
    for ev in dev.read_loop():
        if ev.type == e.EV_KEY:
            if ev.code == e.BTN_MODE:
                if ev.value == 1:
                    out.release_all()
                    subprocess.Popen([LAUNCH])
            elif ev.code in MOUSE_BTNS:
                if ev.value == 1 and not out.context():
                    continue
                out.set(MOUSE_BTNS[ev.code], ev.value == 1, mouse=True)
            elif ev.code in BTN_KEYS:
                if ev.value == 2:  # autorepeat: ya lo hace el compositor
                    continue
                if ev.value == 1 and not out.context():
                    continue
                out.set(BTN_KEYS[ev.code], ev.value == 1)
        elif ev.type == e.EV_ABS:
            if ev.code in (e.ABS_RX, e.ABS_RY):
                stick.vec[ev.code == e.ABS_RY] = axis_norm(dev, ev.code, ev.value)
            elif ev.code in AXIS_KEYS:
                new = axis_dir(dev, ev.code, ev.value)
                old = axis_state[ev.code]
                if new == old:
                    continue
                axis_state[ev.code] = new
                neg, pos = AXIS_KEYS[ev.code]
                if old:
                    out.set(neg if old < 0 else pos, False)
                if new and out.context():
                    out.set(neg if new < 0 else pos, True)


def main():
    kbd = UInput({e.EV_KEY: ALL_KEYS}, name="ds4-rofi-kbd")
    mouse = UInput(
        {e.EV_KEY: list(MOUSE_BTNS.values()), e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL]},
        name="ds4-rofi-mouse",
    )
    out = Emitter(kbd, mouse)
    stick = Stick(out)
    stick.start()
    while True:  # el mando se conecta/desconecta cuando le da la gana
        dev = find_pad()
        if dev is None:
            time.sleep(2)
            continue
        try:
            run(dev, out, stick)
        except OSError:
            pass
        finally:
            out.release_all()
            stick.vec = [0.0, 0.0]
            dev.close()
        time.sleep(2)


if __name__ == "__main__":
    main()
