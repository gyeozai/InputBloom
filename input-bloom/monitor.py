"""Global keyboard and mouse monitoring backends."""

from __future__ import annotations

import ctypes
from ctypes import wintypes
from queue import SimpleQueue
import sys
import threading
from typing import Callable


KeyCallback = Callable[[str], bool]
MouseCallback = Callable[[str], bool]

LLKHF_EXTENDED = 0x01

# Windows virtual-key mappings.
VK_KEYS = {
    0x08: "Backspace",
    0x09: "Tab",
    0x13: "Pause",
    0x14: "CapsLock",
    0x1B: "Esc",
    0x20: "Space",
    0x21: "PgUp",
    0x22: "PgDn",
    0x23: "End",
    0x24: "Home",
    0x25: "Left",
    0x26: "Up",
    0x27: "Right",
    0x28: "Down",
    0x2C: "PrintScreen",
    0x2D: "Insert",
    0x2E: "Delete",
    0x5B: "LWin",
    0x5C: "RWin",
    0x5D: "AppsKey",
    0x60: "Num0",
    0x61: "Num1",
    0x62: "Num2",
    0x63: "Num3",
    0x64: "Num4",
    0x65: "Num5",
    0x66: "Num6",
    0x67: "Num7",
    0x68: "Num8",
    0x69: "Num9",
    0x6A: "Num*",
    0x6B: "Num+",
    0x6D: "Num-",
    0x6E: "NumDel",
    0x6F: "Num/",
    0x90: "NumLock",
    0x91: "ScrollLock",
    0xA0: "LShift",
    0xA1: "RShift",
    0xA2: "LCtrl",
    0xA3: "RCtrl",
    0xA4: "LAlt",
    0xA5: "RAlt",
    0xBA: ";",
    0xBB: "=",
    0xBC: ",",
    0xBD: "-",
    0xBE: ".",
    0xBF: "/",
    0xC0: "`",
    0xDB: "[",
    0xDC: "\\",
    0xDD: "]",
    0xDE: "'",
}

NUMPAD_NAV_KEYS = {
    0x21: "Num9",
    0x22: "Num3",
    0x23: "Num1",
    0x24: "Num7",
    0x25: "Num4",
    0x26: "Num8",
    0x27: "Num6",
    0x28: "Num2",
    0x2D: "Num0",
    0x2E: "NumDel",
}


def vk_to_key(vk_code: int, flags: int = 0) -> str | None:
    """Convert a Windows VK code into the original AutoHotkey logical key."""
    extended = bool(flags & LLKHF_EXTENDED)
    if vk_code == 0x0D:
        return "NumEnter" if extended else "Enter"
    if vk_code == 0x0C and not extended:
        return "Num5"
    if not extended and vk_code in NUMPAD_NAV_KEYS:
        return NUMPAD_NAV_KEYS[vk_code]
    if 0x30 <= vk_code <= 0x39 or 0x41 <= vk_code <= 0x5A:
        return chr(vk_code)
    if 0x70 <= vk_code <= 0x7B:
        return f"F{vk_code - 0x6F}"
    return VK_KEYS.get(vk_code)


class InputEventQueue:
    """Keep state locks and disk work off the Windows hook message thread.

    SimpleQueue.put_nowait never waits for the consumer. One worker preserves
    event order and stop() drains all accepted events before returning.
    """

    def __init__(self, on_key: KeyCallback, on_mouse: MouseCallback):
        self.on_key = on_key
        self.on_mouse = on_mouse
        self.queue = SimpleQueue()
        self.error = ""
        self.thread = threading.Thread(target=self._run, name="input-counts", daemon=True)

    def start(self) -> None:
        self.thread.start()

    def count_key(self, key: str) -> bool:
        self.queue.put_nowait(("key", key))
        return True

    def count_mouse(self, button: str) -> bool:
        self.queue.put_nowait(("mouse", button))
        return True

    def stop(self) -> None:
        self.queue.put_nowait(None)
        self.thread.join()

    def _run(self) -> None:
        while True:
            event = self.queue.get()
            if event is None:
                return
            kind, value = event
            try:
                (self.on_key if kind == "key" else self.on_mouse)(value)
            except Exception as exc:
                # Keep the hook thread independent, and report failures to the dashboard.
                self.error = f"Input count failed: {exc}"


class InputMonitor:
    """Record input on Windows without blocking the input hook thread."""

    def __init__(self, on_key: KeyCallback, on_mouse: MouseCallback):
        self._implementation = None
        self.events = InputEventQueue(on_key, on_mouse)

    @property
    def active(self) -> bool:
        return bool(self._implementation and self._implementation.thread.is_alive()
                    and self.events.thread.is_alive() and not self.events.error)

    @property
    def error(self) -> str:
        return self.events.error

    def start(self) -> None:
        if sys.platform != "win32":
            raise RuntimeError("Windows input hooks require Windows Python. Run python3 -B app.py in Windows PowerShell; WSL/Linux Python cannot capture Windows input.")
        self.events.start()
        try:
            self._implementation = WindowsHookMonitor(self.events.count_key, self.events.count_mouse)
            self._implementation.start()
        except Exception:
            self.stop()
            raise

    def stop(self) -> None:
        if self._implementation is not None:
            self._implementation.stop()
        if self.events.thread.is_alive():
            self.events.stop()


class WindowsHookMonitor:
    """Low-level Windows hooks for accurate host-wide input monitoring."""

    backend = "windows-hooks"
    WH_KEYBOARD_LL = 13
    WH_MOUSE_LL = 14
    WM_KEYDOWN = 0x0100
    WM_SYSKEYDOWN = 0x0104
    WM_LBUTTONDOWN = 0x0201
    WM_RBUTTONDOWN = 0x0204
    WM_QUIT = 0x0012
    HC_ACTION = 0

    class KBDLLHOOKSTRUCT(ctypes.Structure):
        _fields_ = (
            ("vkCode", wintypes.DWORD),
            ("scanCode", wintypes.DWORD),
            ("flags", wintypes.DWORD),
            ("time", wintypes.DWORD),
            ("dwExtraInfo", ctypes.c_void_p),
        )

    def __init__(self, on_key: KeyCallback, on_mouse: MouseCallback):
        if sys.platform != "win32":
            raise RuntimeError("Native Windows hooks require Windows Python.")
        self.on_key = on_key
        self.on_mouse = on_mouse
        self.user32 = ctypes.WinDLL("user32", use_last_error=True)
        self.kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        self.user32.SetWindowsHookExW.argtypes = (
            ctypes.c_int,
            ctypes.c_void_p,
            wintypes.HINSTANCE,
            wintypes.DWORD,
        )
        self.user32.SetWindowsHookExW.restype = ctypes.c_void_p
        self.user32.CallNextHookEx.argtypes = (
            ctypes.c_void_p,
            ctypes.c_int,
            wintypes.WPARAM,
            wintypes.LPARAM,
        )
        self.user32.CallNextHookEx.restype = ctypes.c_ssize_t
        self.user32.UnhookWindowsHookEx.argtypes = (ctypes.c_void_p,)
        self.user32.UnhookWindowsHookEx.restype = wintypes.BOOL
        self.user32.PostThreadMessageW.argtypes = (
            wintypes.DWORD,
            wintypes.UINT,
            wintypes.WPARAM,
            wintypes.LPARAM,
        )
        self.user32.PostThreadMessageW.restype = wintypes.BOOL
        self.user32.PeekMessageW.argtypes = (ctypes.POINTER(wintypes.MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT, wintypes.UINT)
        self.user32.PeekMessageW.restype = wintypes.BOOL
        self.user32.GetMessageW.argtypes = (ctypes.POINTER(wintypes.MSG), wintypes.HWND, wintypes.UINT, wintypes.UINT)
        self.user32.GetMessageW.restype = wintypes.BOOL
        self.kernel32.GetCurrentThreadId.restype = wintypes.DWORD
        self.thread = threading.Thread(target=self._run, name="input-hooks", daemon=True)
        self.ready = threading.Event()
        self.thread_id = 0
        self.keyboard_hook = None
        self.mouse_hook = None
        self.start_error = ""
        self._keyboard_proc_ref = None
        self._mouse_proc_ref = None

    def start(self) -> None:
        self.thread.start()
        if not self.ready.wait(timeout=3):
            raise RuntimeError("Timed out while starting Windows input hooks.")
        if self.start_error:
            raise RuntimeError(self.start_error)

    def stop(self) -> None:
        if self.thread_id:
            self.user32.PostThreadMessageW(self.thread_id, self.WM_QUIT, 0, 0)
        if self.thread.is_alive():
            self.thread.join(timeout=2)

    def _run(self) -> None:
        hook_proc = ctypes.WINFUNCTYPE(
            ctypes.c_ssize_t, ctypes.c_int, wintypes.WPARAM, wintypes.LPARAM
        )
        self._keyboard_proc_ref = hook_proc(self._keyboard_proc)
        self._mouse_proc_ref = hook_proc(self._mouse_proc)
        self.thread_id = self.kernel32.GetCurrentThreadId()
        # Create the message queue before announcing readiness, so an immediate
        # stop cannot lose WM_QUIT in a start/stop race.
        message = wintypes.MSG()
        self.user32.PeekMessageW(ctypes.byref(message), None, 0, 0, 0)
        self.keyboard_hook = self.user32.SetWindowsHookExW(
            self.WH_KEYBOARD_LL, self._keyboard_proc_ref, None, 0
        )
        self.mouse_hook = self.user32.SetWindowsHookExW(
            self.WH_MOUSE_LL, self._mouse_proc_ref, None, 0
        )
        if not self.keyboard_hook or not self.mouse_hook:
            error_code = ctypes.get_last_error()
            self.start_error = f"SetWindowsHookExW failed with Windows error {error_code}."
            self._unhook()
            self.ready.set()
            return
        self.ready.set()

        message = wintypes.MSG()
        while self.user32.GetMessageW(ctypes.byref(message), None, 0, 0) > 0:
            self.user32.TranslateMessage(ctypes.byref(message))
            self.user32.DispatchMessageW(ctypes.byref(message))
        self._unhook()

    def _unhook(self) -> None:
        if self.keyboard_hook:
            self.user32.UnhookWindowsHookEx(self.keyboard_hook)
            self.keyboard_hook = None
        if self.mouse_hook:
            self.user32.UnhookWindowsHookEx(self.mouse_hook)
            self.mouse_hook = None

    def _keyboard_proc(self, code: int, w_param: int, l_param: int) -> int:
        try:
            if code == self.HC_ACTION and w_param in (self.WM_KEYDOWN, self.WM_SYSKEYDOWN):
                data = ctypes.cast(l_param, ctypes.POINTER(self.KBDLLHOOKSTRUCT)).contents
                key = vk_to_key(data.vkCode, data.flags)
                if key:
                    self.on_key(key)
        except Exception:
            # A counting failure must never interrupt Windows input forwarding.
            pass
        return self.user32.CallNextHookEx(None, code, w_param, l_param)

    def _mouse_proc(self, code: int, w_param: int, l_param: int) -> int:
        try:
            if code == self.HC_ACTION:
                if w_param == self.WM_LBUTTONDOWN:
                    self.on_mouse("LButton")
                elif w_param == self.WM_RBUTTONDOWN:
                    self.on_mouse("RButton")
        except Exception:
            # A counting failure must never interrupt Windows input forwarding.
            pass
        return self.user32.CallNextHookEx(None, code, w_param, l_param)
