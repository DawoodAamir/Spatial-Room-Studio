#!/bin/bash
set -euo pipefail
mkdir -p build
xcrun simctl list devices available --json > build/simulators.json
simulator_id="${SIMULATOR_UDID:-$(python3 - <<'PY'
import json
from pathlib import Path
state = json.loads(Path('build/simulators.json').read_text())
for runtime, devices in state['devices'].items():
    if 'xrOS-27' in runtime or 'visionOS-27' in runtime:
        for device in devices:
            if device.get('isAvailable'):
                print(device['udid'])
                raise SystemExit
raise SystemExit('Install the visionOS 27 simulator runtime in Xcode before running this workflow.')
PY
)}"
xcrun simctl bootstatus "$simulator_id" -b
result="build/Workflow-$(date +%s).xcresult"
xcodebuild -project 'Spatial Room Studio.xcodeproj' -scheme 'Spatial Room Studio' -destination "platform=visionOS Simulator,id=$simulator_id" -derivedDataPath build/DerivedData test -collect-test-diagnostics never -resultBundlePath "$result"
xcrun xcresulttool export attachments --path "$result" --output-path build/Screenshots

