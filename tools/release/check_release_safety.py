#!/usr/bin/env python3
"""Fail closed when a Windows Alpha export can expose development control bridges."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


RELEASE_FEATURE = "space_syndicate_release"
PRESET_NAME = "Windows Alpha 0.1"
RUNTIME_BRIDGE = Path("addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd")
REQUIRED_DEVELOPMENT_EXCLUDES = (
    ".mcp.json",
    ".github/*",
    "AGENTS.md",
    "tests/*",
    "tools/*",
    "scenes/tools/*",
    "scripts/tools/*",
    "addons/codex_mcp_companion/*",
    "addons/godot_mcp/*",
    "addons/space_syndicate_design_qa/*",
    "addons/funplay_mcp/core/*",
    "addons/funplay_mcp/ui/*",
)


def _read(root: Path, relative: str | Path) -> str:
    path = root / relative
    if not path.is_file():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8-sig")


def audit(root: Path) -> dict[str, object]:
    failures: list[str] = []
    preset_text = _read(root, "export_presets.cfg")
    project_text = _read(root, "project.godot")
    bridge_text = _read(root, RUNTIME_BRIDGE)

    preset_match = re.search(
        rf'(?ms)^\[preset\.\d+\]\s*.*?^name="{re.escape(PRESET_NAME)}"\s*.*?(?=^\[preset\.|\Z)',
        preset_text,
    )
    if preset_match is None:
        failures.append("windows_alpha_preset_missing")
        preset_block = ""
    else:
        preset_block = preset_match.group(0)

    if RELEASE_FEATURE not in preset_block:
        failures.append("release_feature_missing")
    if 'platform="Windows Desktop"' not in preset_block:
        failures.append("windows_platform_missing")
    if 'binary_format/embed_pck=true' not in preset_text:
        failures.append("embedded_pck_required")
    missing_development_excludes = [
        pattern for pattern in REQUIRED_DEVELOPMENT_EXCLUDES if pattern not in preset_block
    ]
    if missing_development_excludes:
        failures.append("development_resources_not_excluded")

    bridge_autoloaded = bool(
        re.search(r'^FunplayMcpRuntimeBridge\s*=\s*"\*res://', project_text, re.MULTILINE)
    )
    guard_checks = {
        "release_feature_constant": RELEASE_FEATURE in bridge_text,
        "feature_query": bool(re.search(r"OS\.has_feature\s*\(", bridge_text)),
        "ready_fail_closed": "_release_disabled" in bridge_text and "set_process(false)" in bridge_text,
        "exit_fail_closed": bool(re.search(r"func _exit_tree\(\).*?_release_disabled", bridge_text, re.DOTALL)),
    }
    if bridge_autoloaded and not all(guard_checks.values()):
        failures.append("autoloaded_development_bridge_not_release_guarded")

    forbidden_runtime_autoloads = []
    for match in re.finditer(r'(?m)^([A-Za-z0-9_]*Mcp[A-Za-z0-9_]*)\s*=\s*"\*res://([^\"]+)"', project_text):
        name = match.group(1)
        if name != "FunplayMcpRuntimeBridge":
            forbidden_runtime_autoloads.append(name)
    if forbidden_runtime_autoloads:
        failures.append("unexpected_mcp_runtime_autoload")

    return {
        "status": "PASS" if not failures else "FAIL",
        "preset": PRESET_NAME,
        "release_feature": RELEASE_FEATURE,
        "bridge_autoloaded": bridge_autoloaded,
        "bridge_guard_checks": guard_checks,
        "unexpected_mcp_runtime_autoloads": forbidden_runtime_autoloads,
        "missing_development_excludes": missing_development_excludes,
        "failures": failures,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=".")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    root = Path(args.project).resolve()
    try:
        result = audit(root)
    except (FileNotFoundError, OSError, UnicodeError) as exc:
        result = {"status": "FAIL", "failures": [f"audit_io_error:{exc}"]}
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"release safety: {result['status']}")
        for failure in result.get("failures", []):
            print(f"- {failure}")
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
