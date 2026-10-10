"""Replay Nix log events through nom; its exit code alone misses parse failures."""

import json
import re
import subprocess
import sys


def replay(events):
    result = subprocess.run(
        [sys.argv[1], "--json"],
        input="".join("@nix " + json.dumps(event) + "\n" for event in events),
        text=True,
        capture_output=True,
        timeout=10,
    )
    output = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", result.stdout + result.stderr)
    assert result.returncode == 0, output
    return output


def start(activity, **extra):
    return dict(action="start", id=1, level=3, text="", type=activity, **extra)


# CopySourcePath from Determinate Nix 3.23, including its named payload.
for activity in (10113, 99999):
    output = replay([
        start(
            activity,
            name="CopySourcePath",
            parent=0,
            payload={"nix.source.path": "/tmp/source.patch"},
            sid="replay",
        ),
        {"action": "stop", "id": 1},
    ])
    assert "nix-output-monitor error:" not in output, output

# Unknown results need the same tolerance, including HTTP metrics (10111).
for result_type in (10111, 99999):
    output = replay([
        start(0),
        {"action": "result", "id": 1, "type": result_type, "fields": [200]},
        {"action": "result", "id": 1, "type": 106, "fields": [10113, 1]},
        {"action": "stop", "id": 1},
    ])
    assert "nix-output-monitor error:" not in output, output

# Known build/download events must still be parsed and rendered after unknowns.
drv = sys.argv[2]
path = "/nix/store/00000000000000000000000000000000-download-replay"
output = replay([
    start(10113),
    {"action": "stop", "id": 1},
    start(105, fields=[drv, "", 1, 1]),
    {"action": "result", "id": 1, "type": 104, "fields": ["building"]},
    {"action": "result", "id": 1, "type": 101, "fields": ["build-log-replay"]},
    {"action": "stop", "id": 1},
    start(100, fields=[path, "https://cache.nixos.org", ""]),
    {"action": "stop", "id": 1},
])
assert "nix-output-monitor error:" not in output, output
assert "progress-replay" in output and "build-log-replay" in output, output
assert "Builds" in output and "Downloads" in output, output

# Tolerating new types must not suppress errors in malformed known events.
assert "nix-output-monitor error:" in replay([start(105, fields=[])])
print("PASS: new activity/results accepted, build/download progress preserved")
