#!/usr/bin/env python3
"""Enforce the monotonic scripts/main.gd extinction budget."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
MAIN_PATH = Path("scripts/main.gd")
DEFAULT_BASELINE = Path("docs/migration/main_gd_budget_baseline.json")
SCAN_ROOTS = ("scripts", "scenes", "addons", "tests", "tools")
SCAN_SUFFIXES = {".gd", ".tscn", ".tres", ".cfg", ".json", ".ps1", ".py"}
SCAN_EXCLUDES = (
    "tools/architecture/",
    "tests/main_gd_architecture_gate_test.gd",
    "scripts/diagnostics/runtime_authority_audit.gd",
    "scripts/tools/runtime_authority_audit_bench.gd",
    "scenes/tools/RuntimeAuthorityAuditBench.tscn",
    "tests/run_rng_service_cutover_test.gd",
    "tests/table_selection_state_cutover_test.gd",
    "tests/world_session_state_cutover_test.gd",
)
CALLER_PATTERNS = (
    re.compile(r"\b(?:main|_main)\.(?:call|get|set|has_method)\s*\("),
    re.compile(r"res://scripts/main\.gd"),
    re.compile(r"/root/Main"),
    re.compile(r"get_tree\(\)\.current_scene"),
)


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _main_metrics(root: Path) -> dict[str, int]:
    path = root / MAIN_PATH
    if not path.exists():
        return {
            "physical_lines": 0,
            "nonblank_lines": 0,
            "methods": 0,
            "top_level_variables": 0,
            "constants": 0,
            "signals": 0,
            "top_level_preloads": 0,
        }
    text = _read_text(path)
    lines = text.splitlines()
    return {
        "physical_lines": len(lines),
        "nonblank_lines": sum(1 for line in lines if line.strip()),
        "methods": len(re.findall(r"^func\s+", text, re.MULTILINE)),
        "top_level_variables": len(re.findall(r"^var\s+", text, re.MULTILINE)),
        "constants": len(re.findall(r"^const\s+", text, re.MULTILINE)),
        "signals": len(re.findall(r"^signal\s+", text, re.MULTILINE)),
        "top_level_preloads": len(
            re.findall(r"^const\s+[^\n]*preload\(", text, re.MULTILINE)
        ),
    }


def _excluded(relative_path: str) -> bool:
    return relative_path == MAIN_PATH.as_posix() or any(
        relative_path.startswith(prefix) for prefix in SCAN_EXCLUDES
    )


def _caller_snapshot(root: Path) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for base_name in SCAN_ROOTS:
        base = root / base_name
        if not base.exists():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix.lower() not in SCAN_SUFFIXES:
                continue
            relative_path = path.relative_to(root).as_posix()
            if _excluded(relative_path):
                continue
            try:
                text = _read_text(path)
            except UnicodeDecodeError:
                continue
            count = sum(len(pattern.findall(text)) for pattern in CALLER_PATTERNS)
            if count > 0:
                rows.append({"path": relative_path, "occurrences": count})
    production_rows = [
        row
        for row in rows
        if (
            row["path"].startswith(("scripts/", "scenes/", "addons/"))
            and not row["path"].startswith("scripts/tools/")
        )
    ]
    return {
        "external_caller_files": len(rows),
        "external_call_occurrences": sum(row["occurrences"] for row in rows),
        "production_reference_files": sorted(row["path"] for row in production_rows),
        "callers": rows,
    }


def _current_snapshot(root: Path) -> dict[str, Any]:
    return {
        "main": _main_metrics(root),
        "callers": _caller_snapshot(root),
    }


def _failures(current: dict[str, Any], baseline: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    current_main = current["main"]
    baseline_main = baseline["main"]
    for key in (
        "physical_lines",
        "nonblank_lines",
        "methods",
        "top_level_variables",
        "constants",
        "signals",
        "top_level_preloads",
    ):
        if int(current_main[key]) > int(baseline_main[key]):
            failures.append(
                f"main_budget_increased:{key}:{current_main[key]}>{baseline_main[key]}"
            )

    current_callers = current["callers"]
    baseline_callers = baseline["callers"]
    for key in ("external_caller_files", "external_call_occurrences"):
        if int(current_callers[key]) > int(baseline_callers[key]):
            failures.append(
                f"main_callers_increased:{key}:"
                f"{current_callers[key]}>{baseline_callers[key]}"
            )

    allowed_production = set(baseline_callers["production_reference_files"])
    current_production = set(current_callers["production_reference_files"])
    for path in sorted(current_production - allowed_production):
        failures.append(f"new_production_main_reference:{path}")

    if current_main["physical_lines"] == 0 and current_callers["external_call_occurrences"] > 0:
        failures.append("main_removed_but_external_references_remain")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=REPO_ROOT)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    root = args.root.resolve()
    baseline_path = args.baseline
    if not baseline_path.is_absolute():
        baseline_path = root / baseline_path
    baseline = json.loads(_read_text(baseline_path))
    current = _current_snapshot(root)
    failures = _failures(current, baseline)
    result = {
        "ok": not failures,
        "baseline_commit": baseline.get("baseline_commit", ""),
        "current": current,
        "failures": failures,
    }
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        status = "PASS" if not failures else "FAIL"
        metrics = current["main"]
        caller_metrics = current["callers"]
        print(
            "MAIN_GD_BUDGET|status=%s|physical=%d|nonblank=%d|methods=%d|"
            "vars=%d|constants=%d|caller_files=%d|caller_occurrences=%d"
            % (
                status,
                metrics["physical_lines"],
                metrics["nonblank_lines"],
                metrics["methods"],
                metrics["top_level_variables"],
                metrics["constants"],
                caller_metrics["external_caller_files"],
                caller_metrics["external_call_occurrences"],
            )
        )
        for failure in failures:
            print(f"FAIL|{failure}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
