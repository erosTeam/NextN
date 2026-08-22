#!/usr/bin/env python3
from pathlib import Path

from device_lease import CHECKED_PROTOCOL_RUNNER, direct_device_protocol_violation


HDC = "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
TARGET = "192.168.50.237:12345"
MANIFEST = str(
    Path(__file__).resolve().parent.parent
    / "docs"
    / "device-protocols"
    / "public-download-root-recovery-237.json"
)


def assert_allowed(command: list[str]) -> None:
    reason = direct_device_protocol_violation(command, TARGET)
    assert reason is None, f"expected allowed command, got: {reason}"


def assert_denied(command: list[str]) -> None:
    reason = direct_device_protocol_violation(command, TARGET)
    assert reason is not None, "expected command to be denied"


assert_allowed([HDC, "tconn", TARGET])
assert_allowed([HDC, "-t", TARGET, "shell", "echo", "ok"])
assert_allowed([HDC, "-t", TARGET, "shell", "param", "get", "bootevent.boot.completed"])
assert_allowed([HDC, "-t", TARGET, "file", "recv", "/data/local/tmp/a", "/tmp/a"])
assert_allowed(
    [
        "python3",
        str(CHECKED_PROTOCOL_RUNNER),
        MANIFEST,
    ]
)

assert_denied([HDC, "-t", TARGET, "shell", "power-shell", "wakeup"])
assert_denied([HDC, "-t", TARGET, "shell", "power-shell", "timeout", "-o", "86400000"])
assert_denied([HDC, "-t", TARGET, "shell", "uitest", "uiInput", "click", "1", "1"])
assert_denied([HDC, "-t", TARGET, "shell", "uinput", "-T", "-c", "1", "1"])
assert_denied([HDC, "-t", TARGET, "shell", "snapshot_display", "-f", "/tmp/a.jpeg"])
assert_denied([HDC, "-t", TARGET, "shell", "uitest", "dumpLayout", "-p", "/tmp/a.json"])
assert_denied([HDC, "-t", TARGET, "install", "-r", "/tmp/app.hap"])
assert_denied([HDC, "-t", "192.168.50.103:12345", "shell", "echo", "ok"])
assert_denied([HDC, "shell", "echo", "ok"])
assert_denied([HDC, "-t", TARGET, "shell", "echo", "ok", ";", "power-shell", "wakeup"])
assert_denied(["/bin/zsh", "-lc", f"{HDC} -t {TARGET} shell power-shell wakeup"])
assert_denied(["python3", "/tmp/run_device_protocol.py", "/tmp/protocol.json"])
assert_denied(["python3", str(CHECKED_PROTOCOL_RUNNER), "/tmp/protocol.json"])
assert_denied(["python3", "scripts/drive_device_directly.py"])
assert_denied(["node", "scripts/drive_device_directly.mjs"])

print("device protocol gate: pass")
