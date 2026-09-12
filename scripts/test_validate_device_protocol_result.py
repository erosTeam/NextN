#!/usr/bin/env python3
import json
import subprocess
import tempfile
from pathlib import Path


VALIDATOR = Path(__file__).resolve().parent / "validate_device_protocol_result.py"


def run_case(stdout: str, receive_stdout: str = "[Info]FileTransfer finish") -> subprocess.CompletedProcess[str]:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        artifact = root / "received.json"
        artifact.write_text("{}", encoding="utf-8")
        manifest = root / "manifest.json"
        manifest.write_text(json.dumps({"artifactDir": str(root)}), encoding="utf-8")
        metadata = {
            "status": "completed",
            "commands": [
                {
                    "name": "native-test",
                    "argv": ["hdc", "-t", "device", "shell", "aa", "test"],
                    "stdout": stdout,
                    "stderr": "",
                },
                {
                    "name": "receive",
                    "argv": ["hdc", "-t", "device", "file", "recv", "/remote", str(artifact)],
                    "stdout": receive_stdout,
                    "stderr": "",
                },
            ],
        }
        (root / "run-metadata.json").write_text(json.dumps(metadata), encoding="utf-8")
        return subprocess.run(["python3", str(VALIDATOR), str(manifest)], capture_output=True, text=True)


passed = run_case("OHOS_REPORT_RESULT: stream=Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0")
assert passed.returncode == 0, passed

errored = run_case("OHOS_REPORT_RESULT: stream=Tests run: 1, Failure: 0, Error: 1, Pass: 0, Ignore: 0")
assert errored.returncode != 0 and "error=1" in errored.stderr, errored

missing = run_case(
    "OHOS_REPORT_RESULT: stream=Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0",
    "[Fail]Error opening file: no such file or directory",
)
assert missing.returncode != 0 and "HDC receive failure" in missing.stderr, missing

print("device protocol result validator: pass")
