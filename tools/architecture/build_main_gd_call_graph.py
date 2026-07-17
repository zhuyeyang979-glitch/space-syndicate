#!/usr/bin/env python3
"""Generate a deterministic production call graph for scripts/main.gd."""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MAIN = ROOT / "scripts/main.gd"
OUTPUT = ROOT / "docs/migration/main_gd_production_call_graph.json"
SOURCE_SUFFIXES = {".gd", ".tscn", ".tres", ".cfg", ".json", ".ps1"}
EXCLUDED_PREFIXES = (".git/", ".godot/", "docs/", "reports/", "tools/architecture/")


def _text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _git_head() -> str:
    return subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
    ).strip()


def _domain(name: str) -> str:
    checks = (
        ("card_execution", ("card", "skill", "resolution", "auction", "counter")),
        ("world_state", ("player", "district", "world", "region", "rng")),
        ("runtime_loop", ("process", "tick", "timer", "clock", "pause")),
        ("setup_catalog", ("new_game", "setup", "role", "catalog", "starter")),
        ("save_restore", ("save", "load", "restore", "serialize")),
        ("presentation", ("snapshot", "screen", "menu", "codex", "panel", "ui")),
        ("monster", ("monster",)),
        ("military", ("military",)),
        ("weather", ("weather",)),
        ("economy", ("econom", "gdp", "product", "market", "route", "commodity")),
        ("ai", ("ai_", "_ai")),
        ("audio", ("audio", "sfx", "bgm")),
    )
    lowered = name.lower()
    for domain_name, needles in checks:
        if any(needle in lowered for needle in needles):
            return domain_name
    return "unassigned"


def _function_rows(main_text: str) -> list[dict[str, Any]]:
    matches = list(re.finditer(r"(?m)^func\s+([A-Za-z0-9_]+)\b", main_text))
    rows: list[dict[str, Any]] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(main_text)
        body = main_text[match.start() : end]
        signature_end = body.find(":\n")
        signature = body[: signature_end + 1] if signature_end >= 0 else body.splitlines()[0]
        return_match = re.search(r"\)\s*->\s*([^:]+):", signature, re.DOTALL)
        rows.append(
            {
                "name": match.group(1),
                "line": main_text.count("\n", 0, match.start()) + 1,
                "domain": _domain(match.group(1)),
                "return_type": return_match.group(1).strip() if return_match else "",
                "direct_main_calls": sorted(
                    set(
                        call
                        for call in re.findall(r"\b(_[A-Za-z0-9_]+)\s*\(", body)
                        if call != match.group(1)
                    )
                ),
                "dynamic_method_strings": sorted(
                    set(re.findall(r"\.call\(\s*[&]?\"([A-Za-z0-9_]+)\"", body))
                ),
                "emitted_signals": sorted(
                    set(re.findall(r"\.emit_signal\(\s*[&]?\"([A-Za-z0-9_]+)\"", body))
                ),
            }
        )
    return rows


def _source_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in SOURCE_SUFFIXES:
            continue
        relative = path.relative_to(ROOT).as_posix()
        if relative == "scripts/main.gd" or relative.startswith(EXCLUDED_PREFIXES):
            continue
        files.append(path)
    return sorted(files)


def _external_consumers(
    files: list[Path], method_names: set[str]
) -> tuple[list[dict[str, Any]], dict[str, list[str]]]:
    callers: list[dict[str, Any]] = []
    method_consumers: dict[str, list[str]] = {name: [] for name in method_names}
    method_pattern = re.compile(
        r"(?:call|has_method)\(\s*[&]?\"(" + "|".join(map(re.escape, method_names)) + r")\""
    )
    for path in files:
        try:
            source = _text(path)
        except UnicodeDecodeError:
            continue
        relative = path.relative_to(ROOT).as_posix()
        dynamic_methods = sorted(set(method_pattern.findall(source)))
        direct_main = len(
            re.findall(r"\b(?:main|_main)\.(?:call|get|set|has_method)\s*\(", source)
        )
        main_resource = source.count("res://scripts/main.gd")
        current_scene = source.count("get_tree().current_scene")
        root_main = source.count("/root/Main")
        if dynamic_methods or direct_main or main_resource or current_scene or root_main:
            callers.append(
                {
                    "path": relative,
                    "dynamic_methods": dynamic_methods,
                    "direct_main_operations": direct_main,
                    "main_resource_references": main_resource,
                    "current_scene_references": current_scene,
                    "root_main_references": root_main,
                }
            )
        for method_name in dynamic_methods:
            method_consumers[method_name].append(relative)
    return callers, method_consumers


def _top_level_symbols(main_text: str) -> dict[str, list[dict[str, Any]]]:
    rows: dict[str, list[dict[str, Any]]] = {"variables": [], "constants": [], "signals": []}
    for kind, pattern in (
        ("variables", r"(?m)^var\s+([A-Za-z0-9_]+)"),
        ("constants", r"(?m)^const\s+([A-Za-z0-9_]+)"),
        ("signals", r"(?m)^signal\s+([A-Za-z0-9_]+)"),
    ):
        for match in re.finditer(pattern, main_text):
            rows[kind].append(
                {
                    "name": match.group(1),
                    "line": main_text.count("\n", 0, match.start()) + 1,
                    "domain": _domain(match.group(1)),
                }
            )
    return rows


def main() -> None:
    main_text = _text(MAIN)
    functions = _function_rows(main_text)
    files = _source_files()
    callers, method_consumers = _external_consumers(
        files, {row["name"] for row in functions}
    )
    for row in functions:
        row["external_consumers"] = method_consumers[row["name"]]

    process_row = next((row for row in functions if row["name"] == "_process"), {})
    graph = {
        "schema_version": 1,
        "baseline_commit": _git_head(),
        "main_path": "scripts/main.gd",
        "main_stats": {
            "physical_lines": len(main_text.splitlines()),
            "nonblank_lines": sum(1 for line in main_text.splitlines() if line.strip()),
            "methods": len(functions),
            "top_level_variables": len(re.findall(r"(?m)^var\s+", main_text)),
            "constants": len(re.findall(r"(?m)^const\s+", main_text)),
        },
        "top_level_symbols": _top_level_symbols(main_text),
        "functions": functions,
        "external_callers": callers,
        "scene_connections_to_main": [
            line.strip()
            for path in files
            if path.suffix == ".tscn"
            for line in _text(path).splitlines()
            if "[connection " in line and 'to="."' in line
        ],
        "root_world_binding_sites": [
            {
                "line": index + 1,
                "text": line.strip(),
            }
            for index, line in enumerate(main_text.splitlines())
            if "bind_ai_world(self)" in line or re.search(r"bind_[A-Za-z0-9_]*world\(self\)", line)
        ],
        "process_direct_calls": process_row.get("direct_main_calls", []),
    }
    OUTPUT.write_text(
        json.dumps(graph, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        "MAIN_GD_CALL_GRAPH|methods=%d|external_callers=%d|output=%s"
        % (len(functions), len(callers), OUTPUT.relative_to(ROOT).as_posix())
    )


if __name__ == "__main__":
    main()
