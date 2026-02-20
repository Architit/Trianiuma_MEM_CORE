from __future__ import annotations

import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "gateway_io.sh"


def test_gateway_io_unknown_command_exits_2():
    proc = subprocess.run(
        ["bash", str(SCRIPT), "unknown"],
        capture_output=True,
        text=True,
        cwd=REPO_ROOT,
    )
    assert proc.returncode == 2
    assert "Usage:" in proc.stdout or "Usage:" in proc.stderr


def test_gateway_io_import_without_argument_fails():
    proc = subprocess.run(
        ["bash", str(SCRIPT), "import"],
        capture_output=True,
        text=True,
        cwd=REPO_ROOT,
    )
    assert proc.returncode == 1
    out = proc.stdout + proc.stderr
    assert "missing_archive_argument" in out
