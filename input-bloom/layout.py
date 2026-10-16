"""Physical keyboard layout and stable storage IDs used by InputBloom."""

from __future__ import annotations

from dataclasses import asdict, dataclass
import re


@dataclass(frozen=True)
class KeySpec:
    key: str
    label: str
    x: int
    y: int
    w: int
    h: int
    css_class: str = ""

    def to_json(self) -> dict[str, str | int]:
        data = asdict(self)
        data["cls"] = data.pop("css_class")
        return data


def build_keyboard_spec() -> list[KeySpec]:
    specs: list[KeySpec] = []
    unit, height, gap = 70, 56, 7
    main_x = 26
    y_f, y_1, y_2, y_3, y_4, y_5 = 50, 126, 194, 262, 330, 398

    main_width = 15 * unit + 14 * gap
    nav_x = main_x + main_width + 48
    num_x = nav_x + 3 * unit + 2 * gap + 34

    def add(
        key: str,
        label: str,
        x: int,
        y: int,
        width: int = unit,
        key_height: int = height,
        css_class: str = "",
    ) -> None:
        specs.append(KeySpec(key, label, x, y, width, key_height, css_class))

    add("Esc", "Esc", main_x, y_f)
    x = main_x + unit + gap
    for key in ("F1", "F2", "F3", "F4"):
        add(key, key, x, y_f)
        x += unit + gap
    x += 14
    for key in ("F5", "F6", "F7", "F8"):
        add(key, key, x, y_f)
        x += unit + gap
    x += 14
    for key in ("F9", "F10", "F11", "F12"):
        add(key, key, x, y_f)
        x += unit + gap

    add("PrintScreen", "PrtSc", nav_x, y_f, css_class="small")
    add("ScrollLock", "ScrLk", nav_x + unit + gap, y_f, css_class="small")
    add("Pause", "Pause", nav_x + 2 * (unit + gap), y_f, css_class="small")

    x = main_x
    for key in ("`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="):
        add(key, key, x, y_1)
        x += unit + gap
    add("Backspace", "Backspace", x, y_1, 2 * unit + gap, css_class="wide small")

    x = main_x
    add("Tab", "Tab", x, y_2, 100, css_class="wide")
    x += 100 + gap
    for key in ("Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]"):
        add(key, key, x, y_2)
        x += unit + gap
    add("\\", "\\", x, y_2, 86, css_class="wide")

    x = main_x
    add("CapsLock", "Caps", x, y_3, 116, css_class="wide")
    x += 116 + gap
    for key in ("A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'"):
        add(key, key, x, y_3)
        x += unit + gap
    add("Enter", "Enter", x, y_3, 123, css_class="wide")

    x = main_x
    add("LShift", "Shift", x, y_4, 144, css_class="wide")
    x += 144 + gap
    for key in ("Z", "X", "C", "V", "B", "N", "M", ",", ".", "/"):
        add(key, key, x, y_4)
        x += unit + gap
    add("RShift", "Shift", x, y_4, 155, css_class="wide")

    x = main_x
    for key, label in (("LCtrl", "Ctrl"), ("LWin", "Win"), ("LAlt", "Alt")):
        add(key, label, x, y_5, 80, css_class="wide")
        x += 80 + gap
    add("Space", "Space", x, y_5, 420, css_class="space")
    x += 420 + gap
    for key, label in (("RAlt", "Alt"), ("RWin", "Win"), ("AppsKey", "Menu"), ("RCtrl", "Ctrl")):
        add(key, label, x, y_5, 74, css_class="wide small")
        x += 74 + gap

    add("Insert", "Insert", nav_x, y_1, css_class="small")
    add("Home", "Home", nav_x + unit + gap, y_1, css_class="small")
    add("PgUp", "PgUp", nav_x + 2 * (unit + gap), y_1, css_class="small")
    add("Delete", "Delete", nav_x, y_2, css_class="small")
    add("End", "End", nav_x + unit + gap, y_2, css_class="small")
    add("PgDn", "PgDn", nav_x + 2 * (unit + gap), y_2, css_class="small")
    add("Up", "\u2191", nav_x + unit + gap, y_4)
    add("Left", "\u2190", nav_x, y_5)
    add("Down", "\u2193", nav_x + unit + gap, y_5)
    add("Right", "\u2192", nav_x + 2 * (unit + gap), y_5)

    add("NumLock", "Num\nLock", num_x, y_1, css_class="small")
    add("Num/", "/", num_x + unit + gap, y_1)
    add("Num*", "*", num_x + 2 * (unit + gap), y_1)
    add("Num-", "-", num_x + 3 * (unit + gap), y_1)
    add("Num7", "7", num_x, y_2)
    add("Num8", "8", num_x + unit + gap, y_2)
    add("Num9", "9", num_x + 2 * (unit + gap), y_2)
    add("Num+", "+", num_x + 3 * (unit + gap), y_2, unit, 2 * height + gap, "tall")
    add("Num4", "4", num_x, y_3)
    add("Num5", "5", num_x + unit + gap, y_3)
    add("Num6", "6", num_x + 2 * (unit + gap), y_3)
    add("Num1", "1", num_x, y_4)
    add("Num2", "2", num_x + unit + gap, y_4)
    add("Num3", "3", num_x + 2 * (unit + gap), y_4)
    add("NumEnter", "Enter", num_x + 3 * (unit + gap), y_4, unit, 2 * height + gap, "tall small")
    add("Num0", "0", num_x, y_5, 2 * unit + gap, css_class="wide")
    add("NumDel", ".", num_x + 2 * (unit + gap), y_5)
    return specs


KEYBOARD_SPEC = build_keyboard_spec()
TRACKED_KEYS = tuple(dict.fromkeys(spec.key for spec in KEYBOARD_SPEC))
TRACKED_KEY_SET = frozenset(TRACKED_KEYS)
MOUSE_KEYS = ("LButton", "RButton")

SPECIAL_IDS = {
    "`": "k_grave",
    "\\": "k_backslash",
    "'": "k_quote",
    "-": "k_minus",
    "=": "k_equal",
    "[": "k_lbracket",
    "]": "k_rbracket",
    ";": "k_semicolon",
    ",": "k_comma",
    ".": "k_period",
    "/": "k_slash",
    "Num/": "k_num_div",
    "Num*": "k_num_mult",
    "Num-": "k_num_sub",
    "Num+": "k_num_add",
    "NumDel": "k_num_decimal",
    "NumEnter": "k_num_enter",
}


def key_to_id(key: str) -> str:
    return SPECIAL_IDS.get(key, "k_" + re.sub(r"[^A-Za-z0-9]", "_", key))
