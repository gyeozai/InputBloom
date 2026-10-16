"""Record input for one session and show the local HTML dashboard."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import sys
import threading
import webbrowser

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "input-bloom"))

from core import IniStore, InputBloomState
from layout import KEYBOARD_SPEC
from monitor import InputMonitor


class Dashboard:
    def __init__(self, state: InputBloomState, monitor: InputMonitor, directory: Path):
        self.state = state
        self.monitor = monitor
        self.directory = directory
        self.history = state.store.load_history()
        self.day = state.snapshot()["day"]
        self.layout = [key.to_json() for key in KEYBOARD_SPEC]

    def update(self) -> None:
        current = self.state.snapshot()
        if self.day != current["day"]:
            self.history[self.day] = self.state.store.load_day(self.day)
            self.day = current["day"]
        self.history[self.day] = {"keys": current["keys"], "mouse": current["mouse"]}
        payload = {
            "layout": self.layout, "recordDay": self.day, "days": self.history,
            "monitor": {"active": self.monitor.active, "error": self.monitor.error},
        }
        temporary = self.directory / "data.tmp"
        temporary.write_text("window.updateInputBloom(" + json.dumps(payload, separators=(",", ":")) + ");", encoding="utf-8")
        temporary.replace(self.directory / "data.js")


def main() -> int:
    state = InputBloomState(IniStore(ROOT / "keyboard_mouse_daily_log.ini"))
    monitor = InputMonitor(state.count_key, state.count_mouse)
    try:
        monitor.start()
    except Exception as error:
        print(error)
        return 1

    runtime = ROOT / ".runtime"
    stop = threading.Event()
    worker = None
    try:
        runtime.mkdir(exist_ok=True)
        dashboard = Dashboard(state, monitor, runtime)
        dashboard.update()

        def refresh() -> None:
            elapsed = 0
            while not stop.wait(1):
                elapsed += 1
                if elapsed % 5 == 0:
                    state.save()
                dashboard.update()

        worker = threading.Thread(target=refresh, daemon=True)
        worker.start()
        webbrowser.open((ROOT / "index.html").as_uri())
        print("InputBloom is recording. Press Enter or Ctrl+C to stop and save.")
        try:
            input()
        except (KeyboardInterrupt, EOFError):
            pass
    finally:
        stop.set()
        if worker is not None:
            worker.join()
        monitor.stop()
        state.save()
        shutil.rmtree(runtime, ignore_errors=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
