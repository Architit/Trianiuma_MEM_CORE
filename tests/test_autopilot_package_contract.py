# Copyright (c) 2026-06-07 RADRILONIUMA / TRIANIUMA Kingdom. All rights reserved.
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
RAM_SYS = REPO_ROOT / "RAM_MEM" / "Sys"


def test_autopilot_package_core_files_present():
    required = [
        RAM_SYS / "autopilot_package" / "README.md",
        RAM_SYS / "autopilot_package" / "requirements.txt",
        RAM_SYS / "autopilot_package" / "service" / "main.py",
        RAM_SYS / "autopilot_package" / "service" / "security_controls.py",
        RAM_SYS / "ATPLT" / "autopilot_package" / "README.md",
        RAM_SYS / "ATPLT" / "autopilot_package" / "requirements.txt",
        RAM_SYS / "ATPLT" / "autopilot_package" / "service" / "main.py",
        RAM_SYS / "ATPLT" / "autopilot_package" / "service" / "security_controls.py",
    ]
    missing = [str(p.relative_to(REPO_ROOT)) for p in required if not p.exists()]
    assert not missing, f"missing autopilot files: {missing}"


def test_autopilot_main_references_security_controls():
    local_main = (RAM_SYS / "autopilot_package" / "service" / "main.py").read_text(
        encoding="utf-8"
    )
    atplt_main = (
        RAM_SYS / "ATPLT" / "autopilot_package" / "service" / "main.py"
    ).read_text(encoding="utf-8")
    assert "security_controls" in local_main
    assert "security_controls" in atplt_main
