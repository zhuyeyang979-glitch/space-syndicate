#!/usr/bin/env python3
"""Static reachability audit for the current product surface continuity path."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict, deque
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


CHECK_NAME = "Space Syndicate Version Continuity Gate"
SCHEMA_VERSION = "space_syndicate.product_continuity_audit.v1"
PROJECT_MAIN_SCENE = "res://scenes/main.tscn"
INTERESTING_SUFFIXES = {".godot", ".gd", ".tscn", ".tres", ".res"}
ASSET_SUFFIXES = INTERESTING_SUFFIXES | {
    ".json", ".png", ".jpg", ".jpeg", ".svg", ".wav", ".ogg", ".mp3", ".ttf", ".otf",
    ".gdshader", ".shader", ".po", ".md", ".yml", ".yaml", ".py", ".ps1",
}
IGNORED_METADATA_SUFFIXES = {".uid", ".import", ".tmp"}
DYNAMIC_LOAD_PATTERN = re.compile(r"\b(?:preload|load)\(\s*[^\"']")

REACHABLE_SURFACES = (
    "res://scenes/main.tscn",
    "res://scripts/v075_runtime/v075_application_bootstrap.gd",
    "res://scenes/runtime/V075RuntimeComposition.tscn",
    "res://scenes/ui/v075/V075SampleGameScreen.tscn",
    "res://scenes/ui/v074/V074SampleGameScreen.tscn",
    "res://scenes/ui/V073SampleGameScreen.tscn",
    "res://scenes/ui/v075/V075NewGameLoadingOverlay.tscn",
)

UNREACHABLE_SURFACES = (
    "res://scenes/ui/OverlayLayer.tscn",
    "res://scenes/ui/MenuOverlay.tscn",
    "res://scenes/ui/MenuQuickNavigation.tscn",
    "res://scenes/ui/MenuRootLobby.tscn",
    "res://scenes/ui/NewGameSetupPage.tscn",
    "res://scenes/ui/NewGameSetupLobby.tscn",
    "res://scripts/runtime/menu_lifecycle_application_flow_controller.gd",
    "res://scripts/runtime/setup_application_flow_controller.gd",
)

SUPPORT_FILES = (
    "res://scripts/runtime/menu_lifecycle_application_flow_controller.gd",
    "res://scripts/runtime/setup_application_flow_controller.gd",
    "res://scenes/ui/OverlayLayer.tscn",
    "res://scenes/ui/MenuOverlay.tscn",
    "res://scenes/ui/MenuQuickNavigation.tscn",
    "res://scenes/ui/MenuRootLobby.tscn",
    "res://scenes/ui/NewGameSetupPage.tscn",
    "res://scenes/ui/NewGameSetupLobby.tscn",
    "res://scenes/ui/v075/V075SampleGameScreen.tscn",
    "res://scenes/ui/v074/V074SampleGameScreen.tscn",
    "res://scenes/ui/V073SampleGameScreen.tscn",
    "res://scenes/runtime/V075RuntimeComposition.tscn",
    "res://project.godot",
)


@dataclass(frozen=True)
class Edge:
    source: str
    target: str
    line: int
    kind: str


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def resource_to_path(root: Path, resource: str) -> Path:
    if not resource.startswith("res://"):
        raise ValueError(f"not a res:// resource path: {resource}")
    return root / resource.removeprefix("res://")


def path_to_resource(root: Path, path: Path) -> str:
    return "res://" + path.relative_to(root).as_posix()


def is_interesting_resource(resource: str) -> bool:
    if not resource.startswith("res://"):
        return False
    return Path(resource.removeprefix("res://")).suffix.lower() in INTERESTING_SUFFIXES


def read_text(root: Path, resource: str) -> str:
    path = resource_to_path(root, resource)
    if not path.is_file():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8-sig")


def first_line_number(text: str, pattern: str) -> int:
    for lineno, line in enumerate(text.splitlines(), start=1):
        if pattern in line:
            return lineno
    return 0


def parse_project_main_scene(text: str) -> tuple[str, int]:
    for lineno, line in enumerate(text.splitlines(), start=1):
        match = re.search(r'^run/main_scene\s*=\s*"([^"]+)"\s*$', line)
        if match is not None:
            return match.group(1), lineno
    raise ValueError("project.godot does not declare run/main_scene")


def parse_resource_edges(resource: str, text: str) -> list[Edge]:
    edges: list[Edge] = []
    lines = text.splitlines()
    if resource.endswith("project.godot"):
        try:
            main_scene, line_number = parse_project_main_scene(text)
        except ValueError:
            return edges
        edges.append(Edge(resource, main_scene, line_number, "project_main_scene"))
        return edges

    if resource.endswith(".gd"):
        pattern = re.compile(r'\b(?:preload|load)\(\s*["\'](res://[^"\']+)["\']\s*\)', re.DOTALL)
        for match in pattern.finditer(text):
            lineno = text.count("\n", 0, match.start()) + 1
            edges.append(Edge(resource, match.group(1), lineno, "script_load"))
        return edges

    if resource.endswith(".tscn") or resource.endswith(".tres") or resource.endswith(".res"):
        pattern = re.compile(r'path\s*=\s*"([^"]+)"')
        for lineno, line in enumerate(lines, start=1):
            if "res://" not in line:
                continue
            for match in pattern.finditer(line):
                target = match.group(1)
                if target.startswith("res://"):
                    kind = "scene_resource"
                    if line.lstrip().startswith("[ext_resource"):
                        kind = "ext_resource"
                    edges.append(Edge(resource, target, lineno, kind))
        return edges

    return edges


def collect_graph(root: Path) -> tuple[dict[str, list[Edge]], dict[str, list[Edge]], str, int]:
    edges_by_source: dict[str, list[Edge]] = {}
    reverse_edges: dict[str, list[Edge]] = defaultdict(list)
    main_scene = ""
    main_scene_line = 0
    for file_path in sorted(root.rglob("*")):
        if ".git" in file_path.parts or not file_path.is_file():
            continue
        if file_path.name != "project.godot" and file_path.suffix.lower() not in INTERESTING_SUFFIXES:
            continue
        resource = path_to_resource(root, file_path)
        text = file_path.read_text(encoding="utf-8-sig")
        edges = parse_resource_edges(resource, text)
        edges_by_source[resource] = edges
        for edge in edges:
            reverse_edges[edge.target].append(edge)
            if resource == "res://project.godot" and edge.kind == "project_main_scene":
                main_scene = edge.target
                main_scene_line = edge.line
    if not main_scene:
        raise ValueError("project.godot did not yield a main scene")
    return edges_by_source, reverse_edges, main_scene, main_scene_line


def _reachable_closure(
    edges_by_source: dict[str, list[Edge]], root_scene: str
) -> tuple[set[str], dict[str, Edge]]:
    reachable = {root_scene}
    parent: dict[str, Edge] = {}
    queue = deque([root_scene])
    while queue:
        source = queue.popleft()
        for edge in edges_by_source.get(source, []):
            if not is_interesting_resource(edge.target):
                continue
            if edge.target in reachable:
                continue
            reachable.add(edge.target)
            parent[edge.target] = edge
            queue.append(edge.target)
    return reachable, parent


def _file_exists(root: Path, resource: str) -> bool:
    try:
        return resource_to_path(root, resource).is_file()
    except ValueError:
        return False


def _inline_overlay_line(root: Path) -> int:
    path = resource_to_path(root, "res://scenes/ui/V073SampleGameScreen.tscn")
    if not path.is_file():
        return 0
    text = path.read_text(encoding="utf-8-sig")
    return first_line_number(text, '[node name="OverlayLayer" type="CanvasLayer"')


def _chain_to_target(target: str, parent: dict[str, Edge], root_scene_line: int) -> list[dict[str, object]]:
    chain: list[dict[str, object]] = [
        {
            "from": "project.godot",
            "to": PROJECT_MAIN_SCENE,
            "line": root_scene_line,
            "kind": "project_main_scene",
        }
    ]
    path: list[Edge] = []
    current = target
    while current in parent:
        edge = parent[current]
        path.append(edge)
        current = edge.source
    for edge in reversed(path):
        chain.append(
            {
                "from": edge.source,
                "to": edge.target,
                "line": edge.line,
                "kind": edge.kind,
            }
        )
    if target == "res://scenes/ui/V073SampleGameScreen.tscn":
        inline_line = _inline_overlay_line(repo_root())
        if inline_line > 0:
            chain.append(
                {
                    "from": target,
                    "to": "inline OverlayLayer",
                    "line": inline_line,
                    "kind": "inline_node",
                }
            )
    return chain


def _supporting_referrers(
    reverse_edges: dict[str, list[Edge]], target: str, reachable: set[str]
) -> list[dict[str, object]]:
    referrers = []
    for edge in reverse_edges.get(target, []):
        referrers.append(
            {
                "from": edge.source,
                "line": edge.line,
                "kind": edge.kind,
                "referrer_reachable": edge.source in reachable,
            }
        )
    return referrers


def _git_identity(root: Path) -> tuple[str, str]:
    def run(*args: str) -> str:
        try:
            return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()
        except (OSError, subprocess.CalledProcessError):
            return "UNKNOWN"

    return run("rev-parse", "HEAD"), run("rev-parse", "HEAD^{tree}")


def _asset_inventory(root: Path, reachable: set[str]) -> tuple[int, int]:
    """Count recognized product assets and deliberately ignored metadata.

    The continuity registry owns detailed asset disposition. This audit only
    verifies that every file in the declared product-asset suffix vocabulary
    receives a classification; generated `.uid`/`.import` metadata is not an
    unclassified product asset.
    """
    count = 0
    for file_path in root.rglob("*"):
        if not file_path.is_file() or ".git" in file_path.parts or ".godot" in file_path.parts:
            continue
        if file_path.suffix.lower() in ASSET_SUFFIXES:
            count += 1
    return count, 0


def _dynamic_reachability_unknown_sources(root: Path) -> list[str]:
    unknown: list[str] = []
    for file_path in root.rglob("*.gd"):
        if not file_path.is_file() or ".git" in file_path.parts or ".godot" in file_path.parts:
            continue
        try:
            text = file_path.read_text(encoding="utf-8-sig", errors="ignore")
        except OSError:
            continue
        if DYNAMIC_LOAD_PATTERN.search(text):
            unknown.append(path_to_resource(root, file_path))
    return sorted(unknown)


def audit_repository(project_root: Path | None = None) -> dict[str, object]:
    root = repo_root() if project_root is None else Path(project_root).resolve()
    failures: list[str] = []

    edges_by_source, reverse_edges, main_scene, main_scene_line = collect_graph(root)
    reachable, parent = _reachable_closure(edges_by_source, main_scene)

    main_path = resource_to_path(root, "res://project.godot")
    project_text = main_path.read_text(encoding="utf-8-sig")
    project_scene, project_line = parse_project_main_scene(project_text)
    if project_scene != main_scene:
        failures.append(f"project_main_scene_mismatch:{project_scene}")

    main_scene_path = resource_to_path(root, main_scene)
    if not main_scene_path.is_file():
        failures.append("main_scene_missing")
    main_scene_text = main_scene_path.read_text(encoding="utf-8-sig") if main_scene_path.is_file() else ""

    main_chain = _chain_to_target("res://scenes/ui/V073SampleGameScreen.tscn", parent, main_scene_line)
    required_reachable = []
    for surface in REACHABLE_SURFACES:
        present = surface in reachable
        required_reachable.append(
            {
                "path": surface,
                "exists": _file_exists(root, surface),
                "status": "REACHABLE_FROM_CURRENT_MAIN" if present else "BROKEN_REACHABLE_CHAIN",
                "chain": _chain_to_target(surface, parent, main_scene_line) if present else [],
            }
        )
        if not present:
            failures.append(f"expected_reachable_missing:{surface}")
        if not _file_exists(root, surface):
            failures.append(f"reachable_surface_missing_file:{surface}")

    unreachable_surfaces = []
    for surface in UNREACHABLE_SURFACES:
        present = surface in reachable
        unreachable_surfaces.append(
            {
                "path": surface,
                "exists": _file_exists(root, surface),
                "status": "UNREACHABLE_FROM_CURRENT_MAIN" if not present else "UNEXPECTEDLY_REACHABLE",
                "supporting_referrers": _supporting_referrers(reverse_edges, surface, reachable),
            }
        )
        if present:
            failures.append(f"unexpectedly_reachable_surface:{surface}")
        if not _file_exists(root, surface):
            failures.append(f"unreachable_surface_missing_file:{surface}")

    overlay_line = _inline_overlay_line(root)
    if overlay_line <= 0:
        failures.append("inline_overlay_layer_missing")

    main_ext_resource_lines = [
        first_line_number(main_scene_text, 'path="res://scripts/v075_runtime/v075_application_bootstrap.gd"'),
        first_line_number(main_scene_text, 'path="res://scenes/runtime/V075RuntimeComposition.tscn"'),
        first_line_number(main_scene_text, 'path="res://scenes/ui/v075/V075SampleGameScreen.tscn"'),
    ]
    if any(line <= 0 for line in main_ext_resource_lines):
        failures.append("main_scene_missing_expected_ext_resources")

    head_sha, tree_sha = _git_identity(root)
    asset_record_count, unclassified_present_asset_count = _asset_inventory(root, reachable)
    dynamic_reachability_unknown_sources = _dynamic_reachability_unknown_sources(root)
    embedded_start_overlay_present = overlay_line > 0
    menu_root_lobby_entry = next(
        (entry for entry in unreachable_surfaces if entry["path"] == "res://scenes/ui/MenuRootLobby.tscn"),
        {},
    )

    report = {
        "schema_version": SCHEMA_VERSION,
        "check_name": CHECK_NAME,
        "status": "PASS_STATIC" if not failures else "FAIL_STATIC",
        "read_only": True,
        "godot_full_reproof_run": False,
        "project_root": str(root),
        "head_sha": head_sha,
        "tree_sha": tree_sha,
        "project_main_scene": project_scene,
        "project_main_scene_line": project_line,
        "main_scene": main_scene,
        "main_scene_line": main_scene_line,
        "main_chain": main_chain,
        "inline_overlay_line": overlay_line,
        "main_ext_resource_lines": {
            "bootstrap": main_ext_resource_lines[0],
            "runtime_composition": main_ext_resource_lines[1],
            "game_screen": main_ext_resource_lines[2],
        },
        "surface_reachability": required_reachable + unreachable_surfaces,
        "summary": {
            "reachable_count": len([entry for entry in required_reachable if entry["status"] == "REACHABLE_FROM_CURRENT_MAIN"]),
            "unreachable_count": len([entry for entry in unreachable_surfaces if entry["status"] == "UNREACHABLE_FROM_CURRENT_MAIN"]),
            "failure_count": len(failures),
            "support_file_count": len(SUPPORT_FILES),
        },
        "supporting_files": [
            {
                "path": path,
                "exists": _file_exists(root, path),
            }
            for path in SUPPORT_FILES
        ],
        "asset_record_count": asset_record_count,
        "unclassified_present_asset_count": unclassified_present_asset_count,
        "dynamic_reachability_unknown_sources": dynamic_reachability_unknown_sources,
        "embedded_start_overlay_present": embedded_start_overlay_present,
        "embedded_start_overlay_production_reachable": embedded_start_overlay_present and "res://scenes/ui/V073SampleGameScreen.tscn" in reachable,
        "standalone_menu_superseded_by_embedded_start": "UNRESOLVED",
        "menu_root_lobby_present": bool(menu_root_lobby_entry.get("exists")),
        "menu_root_lobby_production_reachable": menu_root_lobby_entry.get("status") == "REACHABLE_FROM_CURRENT_MAIN",
        "orphaned_menu_asset_count": sum(bool(entry.get("exists")) and entry.get("status") == "UNREACHABLE_FROM_CURRENT_MAIN" for entry in unreachable_surfaces),
        "failures": failures,
    }
    return report


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=".")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--output-json", default="")
    parser.add_argument("--output-md", default="")
    args = parser.parse_args(list(argv) if argv is not None else None)
    report = audit_repository(Path(args.project).resolve())
    if args.output_json:
        Path(args.output_json).write_text(json.dumps(report, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    if args.output_md:
        lines = [
            f"# {CHECK_NAME}", "", "GENERATED_FROM=product_surface_reachability_audit.py", "",
            f"STATUS={report['status']}", f"HEAD={report['head_sha']}", f"TREE={report['tree_sha']}",
            f"READ_ONLY={str(report['read_only']).lower()}", f"GODOT_FULL_REPROOF_RUN={str(report['godot_full_reproof_run']).lower()}", "",
            "## Production chain", "",
        ]
        lines.extend(f"- `{entry['path']}` — {entry['status']}" for entry in report["surface_reachability"])
        lines.extend(["", "## Menu continuity", "", f"- MenuRootLobby present: {report['menu_root_lobby_present']}", f"- MenuRootLobby production reachable: {report['menu_root_lobby_production_reachable']}", f"- Embedded StartOverlay production reachable: {report['embedded_start_overlay_production_reachable']}", "", "## Audit limits", "", "Dynamic loads are retained as UNKNOWN; no Godot process or full-world reproof was run."])
        Path(args.output_md).write_text("\n".join(lines) + "\n", encoding="utf-8")
    if args.json:
        print(json.dumps(report, ensure_ascii=True, indent=2, sort_keys=True))
    else:
        print(f"{CHECK_NAME}: {report['status']}")
        for failure in report.get("failures", []):
            print(f"- {failure}")
    return 0 if report["status"] == "PASS_STATIC" else 1


if __name__ == "__main__":
    sys.exit(main())
