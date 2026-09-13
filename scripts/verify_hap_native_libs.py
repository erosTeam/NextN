#!/usr/bin/env python3
"""Fail a build when the Reader native runtime is absent from its final HAP."""

from __future__ import annotations

import sys
import zipfile
from pathlib import Path


REQUIRED_NATIVE_LIBS = (
    "libs/arm64-v8a/libreader_enhancement.so",
    "libs/arm64-v8a/libomp.so",
    "libs/arm64-v8a/libc++_shared.so",
)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} <hap>", file=sys.stderr)
        return 2

    hap = Path(sys.argv[1])
    if not hap.is_file():
        print(f"ERROR: HAP not found: {hap}", file=sys.stderr)
        return 1

    with zipfile.ZipFile(hap) as archive:
        entries = {info.filename: info.file_size for info in archive.infolist()}

    missing = [name for name in REQUIRED_NATIVE_LIBS if entries.get(name, 0) <= 0]
    if missing:
        print(f"ERROR: HAP is missing required Reader native libraries: {', '.join(missing)}", file=sys.stderr)
        return 1

    print(f"Verified Reader native libraries in {hap}")
    for name in REQUIRED_NATIVE_LIBS:
        print(f"  {name}: {entries[name]} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
