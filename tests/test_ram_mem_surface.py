from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_ram_mem_top_level_segments_present():
    base = REPO_ROOT / "RAM_MEM"
    required = [
        "LRAM",
        "LAM",
        "Sys",
        "CORE",
        "GROK",
        "GEMINI",
        "RAW",
    ]
    missing = [name for name in required if not (base / name).exists()]
    assert not missing, f"missing RAM_MEM segments: {missing}"


def test_ram_mem_contains_mixed_artifact_types():
    base = REPO_ROOT / "RAM_MEM"
    assert list(base.rglob("*.txt")), "no txt artifacts found"
    assert list(base.rglob("*.md")), "no md artifacts found"
    assert list(base.rglob("*.py")), "no py artifacts found"


def test_gateway_script_contract_present():
    script = (REPO_ROOT / "scripts" / "gateway_io.sh").read_text(encoding="utf-8")
    assert "verify_github" in script
    assert "verify_onedrive" in script
    assert "verify_gworkspace" in script
    assert "do_export" in script
    assert "do_import" in script
    assert "Usage: $0 [verify|export|import <archive>]" in script
