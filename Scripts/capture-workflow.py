import subprocess
import sys
from pathlib import Path

simulator = sys.argv[1]
output = Path('build/Screenshots')
output.mkdir(parents=True, exist_ok=True)
captured = set()
process = subprocess.Popen(sys.argv[2:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
for line in process.stdout:
    print(line, end='', flush=True)
    for name in ['Workspace', 'Volume']:
        if f'SCENE_CAPTURE: {name}' in line and name not in captured:
            subprocess.run(['xcrun', 'simctl', 'io', simulator, 'screenshot', str(output / (name + '.png'))], check=True)
            captured.add(name)
status = process.wait()
if status == 0 and captured != {'Workspace', 'Volume'}:
    raise SystemExit('Both checked scene captures are required.')
raise SystemExit(status)
