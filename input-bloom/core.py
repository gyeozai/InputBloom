"""Thread-safe InputBloom state and INI persistence."""

from __future__ import annotations

from configparser import ConfigParser
from datetime import date, datetime
from pathlib import Path
import os
import threading
from typing import Callable

from layout import MOUSE_KEYS, TRACKED_KEYS, TRACKED_KEY_SET, key_to_id


class IniStore:
    """Read and write the same INI format as the AutoHotkey implementation."""

    def __init__(self, path: Path):
        self.path = path
        self._lock = threading.RLock()

    @staticmethod
    def _new_parser() -> ConfigParser:
        parser = ConfigParser(interpolation=None)
        parser.optionxform = str
        return parser

    def _read(self) -> ConfigParser:
        parser = self._new_parser()
        if self.path.exists():
            parser.read(self.path, encoding="utf-8")
        return parser

    def _day_counts(self, parser: ConfigParser, day: str) -> dict:
        return {
            "keys": self._load_section(parser, f"Keyboard_{day}", ((key, key_to_id(key)) for key in TRACKED_KEYS)),
            "mouse": self._load_section(parser, f"Mouse_{day}", ((button, button) for button in MOUSE_KEYS)),
        }

    def load_day(self, day: str) -> dict:
        with self._lock:
            return self._day_counts(self._read(), day)

    def load_history(self) -> dict:
        with self._lock:
            parser = self._read()
            days = set()
            for section in parser.sections():
                prefix, _, day = section.partition("_")
                if prefix not in ("Keyboard", "Mouse"):
                    continue
                try:
                    date.fromisoformat(day)
                except ValueError:
                    continue
                days.add(day)
            return {day: self._day_counts(parser, day) for day in sorted(days)}

    @staticmethod
    def _load_section(
        parser: ConfigParser, section: str, items
    ) -> dict[str, int]:
        counts: dict[str, int] = {}
        if not parser.has_section(section):
            return counts
        for logical_name, stored_name in items:
            try:
                value = parser.getint(section, stored_name, fallback=0)
            except ValueError:
                value = 0
            if value > 0:
                counts[logical_name] = value
        return counts

    def save_day(self, day: str, keys: dict[str, int], mouse: dict[str, int]) -> str:
        with self._lock:
            parser = self._read()
            self._replace_section(
                parser,
                f"Keyboard_{day}",
                ((key_to_id(key), keys.get(key, 0)) for key in TRACKED_KEYS),
            )
            self._replace_section(
                parser,
                f"Mouse_{day}",
                ((button, mouse.get(button, 0)) for button in MOUSE_KEYS),
            )
            if not parser.has_section("Meta"):
                parser.add_section("Meta")
            last_saved = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            parser.set("Meta", "LastSaved", last_saved)

            self.path.parent.mkdir(parents=True, exist_ok=True)
            temp_path = self.path.with_suffix(self.path.suffix + ".tmp")
            with temp_path.open("w", encoding="utf-8") as file:
                parser.write(file, space_around_delimiters=False)
            os.replace(temp_path, self.path)
            return last_saved

    @staticmethod
    def _replace_section(parser: ConfigParser, section: str, items) -> None:
        if parser.has_section(section):
            parser.remove_section(section)
        parser.add_section(section)
        for key, value in items:
            parser.set(section, key, str(value))


class InputBloomState:
    def __init__(self, store: IniStore, today_provider: Callable[[], date] = date.today):
        self.store = store
        self._today_provider = today_provider
        self._lock = threading.RLock()
        self.record_day = self._today_provider().isoformat()
        counts = store.load_day(self.record_day)
        self.key_counts = counts["keys"]
        self.mouse_counts = counts["mouse"]

    def _rollover_if_needed(self) -> None:
        today = self._today_provider().isoformat()
        if today != self.record_day:
            self.store.save_day(self.record_day, self.key_counts, self.mouse_counts)
            self.record_day = today
            counts = self.store.load_day(today)
            self.key_counts, self.mouse_counts = counts["keys"], counts["mouse"]

    def count_key(self, key: str) -> bool:
        if key not in TRACKED_KEY_SET:
            return False
        with self._lock:
            self._rollover_if_needed()
            self.key_counts[key] = self.key_counts.get(key, 0) + 1
        return True

    def count_mouse(self, button: str) -> bool:
        if button not in MOUSE_KEYS:
            return False
        with self._lock:
            self._rollover_if_needed()
            self.mouse_counts[button] = self.mouse_counts.get(button, 0) + 1
        return True

    def snapshot(self) -> dict:
        with self._lock:
            self._rollover_if_needed()
            return {"day": self.record_day, "keys": dict(self.key_counts), "mouse": dict(self.mouse_counts)}

    def save(self) -> None:
        with self._lock:
            self._rollover_if_needed()
            self.store.save_day(self.record_day, self.key_counts, self.mouse_counts)
