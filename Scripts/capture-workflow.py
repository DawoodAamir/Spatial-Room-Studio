import subprocess
import sys
import threading
import time
from pathlib import Path

simulator, runner = sys.argv[1:3]
output = Path("build/Screenshots")
output.mkdir(parents=True, exist_ok=True)
captured = set()
errors = []
started = time.time()
stopped = threading.Event()

def capture_scenes():
    folder = None
    while not stopped.wait(0.25):
        if folder is None:
            result = subprocess.run(["xcrun", "simctl", "get_app_container", simulator, runner, "data"], capture_output=True, text=True)
            if result.returncode == 0:
                folder = Path(result.stdout.strip()) / "Documents"
            continue
        request = folder / "scene-request.txt"
        try:
            if request.stat().st_mtime < started:
                continue
            name = request.read_text()
        except FileNotFoundError:
            continue
        if name not in {"Workspace", "Volume"} or name in captured:
            continue
        try:
            subprocess.run(["xcrun", "simctl", "io", simulator, "screenshot", str(output / (name + ".png"))], check=True)
            response = folder / "scene-response.tmp"
            response.write_text(name)
            response.replace(folder / "scene-response.txt")
            captured.add(name)
        except Exception as error:
            errors.append(str(error))
            return

worker = threading.Thread(target=capture_scenes, daemon=True)
worker.start()
try:
    status = subprocess.run(sys.argv[3:]).returncode
finally:
    stopped.set()
    worker.join(timeout=10)
if errors:
    raise SystemExit("Scene capture failed: " + "; ".join(errors))
if status == 0 and captured != {"Workspace", "Volume"}:
    raise SystemExit("Both checked scene captures are required.")
raise SystemExit(status)
