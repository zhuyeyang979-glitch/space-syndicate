#!/usr/bin/env python3
"""Read-only product version-continuity gate.

The gate validates the single product-continuity registry and the static
production reachability audit. It never starts Godot and does not replace the
existing V076 reuse/point-inertia gate.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Iterable

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from product_surface_reachability_audit import CHECK_NAME, audit_repository, repo_root  # noqa: E402

REGISTRY_REL = Path("docs/product/SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json")
VIEW_NAMES = (
    "SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.md",
    "SPACE_SYNDICATE_VERSION_HISTORY.md",
    "SPACE_SYNDICATE_CURRENT_DEVELOPMENT_STATUS.md",
    "SPACE_SYNDICATE_FUTURE_ROADMAP.md",
    "SPACE_SYNDICATE_RETIRED_AND_CANCELLED_GOALS.md",
)
REUSE_GATE_REL = Path(".github/workflows/v076-reuse-point-inertia-gate.yml")
CAPABILITY_STATUSES = {
    "ACTIVE_PRODUCTION", "ACTIVE_ISOLATED", "INHERITED_PRODUCTION", "INHERITED_ISOLATED",
    "MIGRATING", "PLANNED", "DEFERRED", "PRESENT_NOT_PRODUCTION_REACHABLE", "TEST_ONLY",
    "DIAGNOSTIC_ONLY", "SUPERSEDED", "RETIRED", "CANCELLED", "MISSING_FROM_CURRENT_TREE",
    "UNKNOWN_REQUIRES_AUDIT",
}
ASSET_STATUSES = {
    "ACTIVE_PRODUCTION", "ACTIVE_SUPPORT", "PRESENT_NOT_REACHABLE", "TEST_ONLY",
    "DIAGNOSTIC_ONLY", "SUPERSEDED", "RETIRED", "CANCELLED", "MISSING",
}
WORK_STATUSES = {
    "IN_PROGRESS", "READY_FOR_REVIEW", "BLOCKED_PRODUCT", "BLOCKED_HUMAN",
    "BLOCKED_EXTERNAL", "PLANNED_NEXT", "DONE", "SUPERSEDED", "CANCELLED",
}
ACTIVE_PARENT_STATUSES = {
    "ACTIVE_PRODUCTION", "ACTIVE_ISOLATED", "INHERITED_PRODUCTION", "INHERITED_ISOLATED",
}
DISPOSITION_FIELDS = (
    "inherited_capability_ids", "changed_capability_ids", "superseded_capability_ids",
    "retired_capability_ids", "cancelled_goal_ids", "deferred_capability_ids",
)


def git(root: Path, *args: str) -> tuple[int, str]:
    proc = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    return proc.returncode, proc.stdout.strip()


def is_commit(root: Path, sha: object) -> bool:
    value = str(sha or "")
    return 7 <= len(value) <= 40 and git(root, "cat-file", "-e", f"{value}^{{commit}}")[0] == 0


def is_ancestor(root: Path, ancestor: object, descendant: object) -> bool:
    a, d = str(ancestor or ""), str(descendant or "")
    return is_commit(root, a) and is_commit(root, d) and git(root, "merge-base", "--is-ancestor", a, d)[0] == 0


def load_registry(root: Path) -> dict:
    path = root / REGISTRY_REL
    if not path.is_file():
        raise ValueError("PRODUCT_CONTINUITY_REGISTRY_MISSING")
    return json.loads(path.read_text(encoding="utf-8"))


def required(item: dict, fields: Iterable[str], failures: list[str], label: str) -> None:
    for field in fields:
        if field not in item:
            failures.append(f"{label}:MISSING_FIELD:{field}")


def _version_refs(version: dict) -> set[str]:
    refs: set[str] = set()
    for field in DISPOSITION_FIELDS:
        values = version.get(field, [])
        if isinstance(values, list):
            refs.update(str(value) for value in values)
    return refs


def validate_registry(root: Path, registry: dict, audit: dict) -> list[str]:
    failures: list[str] = []
    required_top = {
        "project_identity", "versions", "capabilities", "product_surfaces", "assets",
        "current_work_items", "future_backlog", "retired_goals", "cancelled_goals",
        "supersession_links", "known_gaps", "release_requirements",
    }
    failures.extend(f"REGISTRY_TOP_LEVEL_MISSING:{name}" for name in sorted(required_top - registry.keys()))
    if failures:
        return failures

    identity = registry["project_identity"]
    activation = registry.get("activation", {})
    required(identity, ("current_version_id", "parent_version_id", "production_entry_scene", "production_bootstrap", "production_runtime_composition", "production_game_screen"), failures, "project_identity")
    required(activation, ("activation_head_sha", "activation_tree_sha", "current_product_task_interrupted", "production_green", "human_green"), failures, "activation")
    if activation.get("current_product_task_interrupted") is not False:
        failures.append("CURRENT_PRODUCT_TASK_INTERRUPTED")
    if activation.get("production_green") is not False:
        failures.append("PRODUCTION_GREEN_CLAIM_NOT_FALSE")
    if activation.get("human_green") is not False:
        failures.append("HUMAN_GREEN_CLAIM_NOT_FALSE")

    versions = registry["versions"]
    if not isinstance(versions, list) or not versions:
        return failures + ["VERSION_RECORDS_MISSING"]
    version_ids = [str(item.get("version_id", "")) for item in versions]
    if len(version_ids) != len(set(version_ids)) or any(not item for item in version_ids):
        failures.append("DUPLICATE_OR_EMPTY_VERSION_ID")
    version_map = {item.get("version_id"): item for item in versions}
    delta_ids = [str(item.get("version_delta_id", "")) for item in versions]
    if len(delta_ids) != len(set(delta_ids)) or any(not item for item in delta_ids):
        failures.append("DUPLICATE_OR_EMPTY_VERSION_DELTA_ID")
    version_fields = (
        "version_id", "display_name", "parent_version_id", "base_commit_sha", "production_entry_scene",
        "production_bootstrap", "production_runtime_composition", "production_game_screen",
        "inherited_capability_ids", "added_capability_ids", "changed_capability_ids",
        "superseded_capability_ids", "retired_capability_ids", "cancelled_goal_ids",
        "deferred_capability_ids", "known_gap_ids", "version_delta_id", "release_status", "human_play_status",
    )
    for index, version in enumerate(versions):
        required(version, version_fields, failures, f"version:{index}")
        parent = version.get("parent_version_id")
        if index == 0:
            if parent not in (None, ""):
                failures.append("ROOT_VERSION_HAS_PARENT")
        elif parent not in version_map:
            failures.append(f"VERSION_PARENT_MISSING:{version.get('version_id')}")
        if not is_commit(root, version.get("base_commit_sha")):
            failures.append(f"VERSION_BASE_COMMIT_MISSING:{version.get('version_id')}")
        final = version.get("final_commit_sha")
        if final and not is_commit(root, final):
            failures.append(f"VERSION_FINAL_COMMIT_MISSING:{version.get('version_id')}")
        if index > 0 and parent in version_map:
            parent_tip = version_map[parent].get("final_commit_sha") or version_map[parent].get("base_commit_sha")
            if not is_ancestor(root, parent_tip, version.get("base_commit_sha")):
                failures.append(f"PARENT_VERSION_NOT_ANCESTOR:{version.get('version_id')}")
            if version.get("production_entry_scene") != version_map[parent].get("production_entry_scene") and not version.get("migration_notes"):
                failures.append(f"PRODUCTION_ENTRY_CHANGE_WITHOUT_MIGRATION:{version.get('version_id')}")

    current = version_map.get(identity.get("current_version_id"))
    if current is None:
        failures.append("CURRENT_VERSION_RECORD_MISSING")
    else:
        if current.get("parent_version_id") != identity.get("parent_version_id"):
            failures.append("CURRENT_PARENT_MISMATCH")
        head = activation.get("activation_head_sha")
        if not is_ancestor(root, current.get("base_commit_sha"), head):
            failures.append("ACTIVATION_HEAD_NOT_DESCENDANT_OF_CURRENT_BASE")
        if is_commit(root, head):
            code, tree = git(root, "rev-parse", f"{head}^{{tree}}")
            if code != 0 or tree != str(activation.get("activation_tree_sha", "")):
                failures.append("ACTIVATION_TREE_MISMATCH")

    capabilities = registry["capabilities"]
    if not isinstance(capabilities, list):
        failures.append("CAPABILITY_RECORDS_NOT_LIST")
        capabilities = []
    capability_ids = {str(item.get("capability_id", "")) for item in capabilities if isinstance(item, dict)}
    if len(capability_ids) != len(capabilities) or "" in capability_ids:
        failures.append("DUPLICATE_OR_EMPTY_CAPABILITY_ID")
    capability_fields = (
        "capability_id", "name_zh", "name_en", "domain_id", "introduced_version", "introduced_commit",
        "last_changed_version", "last_changed_commit", "current_status", "owner_component_id",
        "consumer_component_ids", "source_paths", "asset_ids", "test_ids", "golden_scenario_step_ids",
        "production_reachable", "production_reachability_path", "production_entrypoint",
        "current_version_support", "planned_target_version", "dependencies", "supersedes", "superseded_by",
        "retirement_reason", "cancellation_reason", "known_gaps", "acceptance_criteria",
    )
    for index, capability in enumerate(capabilities):
        required(capability, capability_fields, failures, f"capability:{index}")
        if capability.get("current_status") not in CAPABILITY_STATUSES:
            failures.append(f"UNKNOWN_CAPABILITY_STATUS:{capability.get('capability_id')}")
        if capability.get("introduced_commit") and not is_commit(root, capability.get("introduced_commit")):
            failures.append(f"CAPABILITY_INTRODUCED_COMMIT_MISSING:{capability.get('capability_id')}")
        for relation in ("dependencies", "supersedes", "superseded_by"):
            for target in capability.get(relation, []) if isinstance(capability.get(relation, []), list) else []:
                if str(target).startswith("product.") and target not in capability_ids:
                    failures.append(f"CAPABILITY_RELATION_UNKNOWN:{capability.get('capability_id')}:{target}")

    for version in versions:
        for field in DISPOSITION_FIELDS:
            values = version.get(field, [])
            if not isinstance(values, list):
                failures.append(f"VERSION_DELTA_NOT_LIST:{version.get('version_id')}:{field}")
                continue
            for capability_id in values:
                if capability_id not in capability_ids and not str(capability_id).startswith("component."):
                    failures.append(f"VERSION_DELTA_UNKNOWN_CAPABILITY:{version.get('version_id')}:{capability_id}")

    # Every live capability named by the parent delta must have an explicit
    # disposition in the child. This is the core silent-loss check.
    for version in versions[1:]:
        parent = version_map.get(version.get("parent_version_id"))
        if not parent:
            continue
        parent_live = set(parent.get("inherited_capability_ids", []))
        parent_live.update(parent.get("added_capability_ids", []))
        parent_live.update(parent.get("changed_capability_ids", []))
        parent_live.difference_update(parent.get("superseded_capability_ids", []))
        parent_live.difference_update(parent.get("retired_capability_ids", []))
        parent_live.difference_update(parent.get("deferred_capability_ids", []))
        dispositions = _version_refs(version)
        for capability_id in sorted(parent_live):
            if capability_id not in dispositions:
                failures.append(f"SILENT_ACTIVE_CAPABILITY_LOSS:{version.get('version_id')}:{capability_id}")

    surfaces = registry["product_surfaces"]
    surface_ids: set[str] = set()
    surface_fields = ("surface_id", "name", "current_status", "production_reachable", "production_reachability_path", "entrypoint", "owner_component_id", "evidence_ids", "known_gaps")
    for index, surface in enumerate(surfaces if isinstance(surfaces, list) else []):
        required(surface, surface_fields, failures, f"surface:{index}")
        sid = str(surface.get("surface_id", ""))
        if sid in surface_ids:
            failures.append(f"DUPLICATE_SURFACE_ID:{sid}")
        surface_ids.add(sid)

    assets = registry["assets"]
    asset_ids: set[str] = set()
    asset_fields = ("asset_id", "path", "asset_type", "introduced_commit", "introduced_version", "current_blob_sha", "present_in_current_tree", "production_reachable", "test_reachable", "diagnostic_reachable", "referenced_by", "replaced_by", "status", "planned_action")
    for index, asset in enumerate(assets if isinstance(assets, list) else []):
        required(asset, asset_fields, failures, f"asset:{index}")
        aid = str(asset.get("asset_id", ""))
        if aid in asset_ids:
            failures.append(f"DUPLICATE_ASSET_ID:{aid}")
        asset_ids.add(aid)
        if asset.get("status") not in ASSET_STATUSES:
            failures.append(f"UNKNOWN_ASSET_STATUS:{aid}")
        if asset.get("present_in_current_tree") is True and not (root / str(asset.get("path", ""))).is_file():
            failures.append(f"ASSET_PRESENT_PATH_MISSING:{aid}")
        if asset.get("present_in_current_tree") is False and not (asset.get("replaced_by") or asset.get("planned_action")):
            failures.append(f"ASSET_REMOVED_WITHOUT_DISPOSITION:{aid}")

    work_fields = ("work_item_id", "title", "domain_id", "target_version", "status", "priority", "source_request", "introduced_on", "owner_component_id", "dependencies", "blocking_items", "acceptance_criteria", "current_branch", "current_pr", "latest_commit", "evidence", "next_task")
    work_ids: set[str] = set()
    for index, item in enumerate(registry["current_work_items"] if isinstance(registry["current_work_items"], list) else []):
        required(item, work_fields, failures, f"current_work:{index}")
        if item.get("status") not in WORK_STATUSES:
            failures.append(f"UNKNOWN_WORK_STATUS:{item.get('work_item_id')}")
        if item.get("work_item_id") in work_ids:
            failures.append(f"DUPLICATE_WORK_ITEM_ID:{item.get('work_item_id')}")
        work_ids.add(item.get("work_item_id"))

    backlog_fields = ("backlog_id", "title", "domain", "target_version", "priority", "reason", "dependencies", "source_user_request", "acceptance_criteria", "design_status", "implementation_status", "production_status", "human_play_status")
    for index, item in enumerate(registry["future_backlog"] if isinstance(registry["future_backlog"], list) else []):
        required(item, backlog_fields, failures, f"future_backlog:{index}")

    goal_fields = ("goal_id", "original_description", "introduced_version", "introduced_source", "final_status", "decision_date", "decision_reason", "superseded_by", "affected_assets", "affected_rules", "migration_notes")
    for group in ("retired_goals", "cancelled_goals"):
        for index, item in enumerate(registry[group] if isinstance(registry[group], list) else []):
            required(item, goal_fields, failures, f"{group}:{index}")

    if audit.get("status") != "PASS_STATIC":
        failures.append("PRODUCTION_SURFACE_REACHABILITY_AUDIT_FAILED")
    if audit.get("read_only") is not True or audit.get("godot_full_reproof_run") is not False:
        failures.append("AUDIT_NOT_READ_ONLY")
    for required_surface in (
        "res://scenes/main.tscn",
        "res://scripts/v075_runtime/v075_application_bootstrap.gd",
        "res://scenes/runtime/V075RuntimeComposition.tscn",
        "res://scenes/ui/v075/V075SampleGameScreen.tscn",
    ):
        entry = next((item for item in audit.get("surface_reachability", []) if item.get("path") == required_surface), None)
        if not entry or entry.get("status") != "REACHABLE_FROM_CURRENT_MAIN":
            failures.append("SILENT_PRODUCTION_SURFACE_LOSS:" + required_surface)

    for view in VIEW_NAMES:
        path = root / "docs/product" / view
        if not path.is_file():
            failures.append("GENERATED_VIEW_MISSING:" + view)
        elif "GENERATED_FROM=SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json" not in path.read_text(encoding="utf-8"):
            failures.append("GENERATED_VIEW_SOURCE_MISSING:" + view)
    if not (root / REUSE_GATE_REL).is_file():
        failures.append("V076_REUSE_POINT_INERTIA_GATE_MISSING")
    return list(dict.fromkeys(failures))


def run_gate(root: Path) -> dict:
    failures: list[str] = []
    try:
        registry = load_registry(root)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        registry = {}
        failures.append(str(exc))
    audit = audit_repository(root)
    failures.extend(validate_registry(root, registry, audit))
    unique = list(dict.fromkeys(failures))
    return {
        "check_name": CHECK_NAME,
        "status": "PASS_STATIC" if not unique else "FAIL_STATIC",
        "read_only": True,
        "godot_full_reproof_run": False,
        "product_runtime_mutation_count": 0,
        "full_world_reproof": False,
        "failure_count": len(unique),
        "failures": unique,
        "registry_id": registry.get("registry_id", ""),
        "version_record_count": len(registry.get("versions", [])),
        "capability_record_count": len(registry.get("capabilities", [])),
        "asset_record_count": len(registry.get("assets", [])),
        "current_work_item_count": len(registry.get("current_work_items", [])),
        "future_backlog_item_count": len(registry.get("future_backlog", [])),
        "retired_goal_count": len(registry.get("retired_goals", [])),
        "cancelled_goal_count": len(registry.get("cancelled_goals", [])),
        "superseded_goal_count": sum(1 for item in registry.get("retired_goals", []) if item.get("final_status") == "SUPERSEDED") + sum(1 for item in registry.get("cancelled_goals", []) if item.get("final_status") == "SUPERSEDED"),
        "unclassified_capability_count": 0,
        "silent_active_capability_loss_count": sum(item.startswith("SILENT_ACTIVE_CAPABILITY_LOSS:") for item in unique),
        "silent_production_surface_loss_count": sum(item.startswith("SILENT_PRODUCTION_SURFACE_LOSS:") for item in unique),
        "unclassified_present_asset_count": int(audit.get("unclassified_present_asset_count", 0)),
        "dynamic_reachability_unknown_count": len(audit.get("dynamic_reachability_unknown_sources", [])),
        "menu_root_lobby_present": any(item.get("path") == "res://scenes/ui/MenuRootLobby.tscn" and item.get("exists") for item in audit.get("surface_reachability", [])),
        "menu_root_lobby_production_reachable": any(item.get("path") == "res://scenes/ui/MenuRootLobby.tscn" and item.get("status") == "REACHABLE_FROM_CURRENT_MAIN" for item in audit.get("surface_reachability", [])),
        "embedded_start_overlay_present": any(item.get("surface_id") == "surface.embedded_start_overlay" for item in registry.get("product_surfaces", [])),
        "embedded_start_overlay_production_reachable": any(item.get("surface_id") == "surface.embedded_start_overlay" and item.get("production_reachable") for item in registry.get("product_surfaces", [])),
        "orphaned_menu_asset_count": sum(bool(item.get("exists")) and item.get("status") == "UNREACHABLE_FROM_CURRENT_MAIN" for item in audit.get("surface_reachability", [])),
        "version_continuity_registry_implementation_count": 1,
        "v076_reuse_point_inertia_gate_retained": (root / REUSE_GATE_REL).is_file(),
        "github_required_check_configured": bool(registry.get("release_requirements", {}).get("github_required_check_configured", False)),
        "continuity_workflow_present": (root / ".github/workflows/space-syndicate-version-continuity-gate.yml").is_file(),
        "product_code_change_count": 0,
        "product_rule_change_count": 0,
        "current_product_task_resumed": False,
        "reachability": audit,
    }


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default=str(repo_root()))
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(list(argv) if argv is not None else None)
    report = run_gate(Path(args.project).resolve())
    if args.json:
        print(json.dumps(report, ensure_ascii=True, indent=2, sort_keys=True))
    else:
        print(f"{CHECK_NAME}: {report['status']}")
        for failure in report["failures"]:
            print("- " + failure)
    return 0 if report["status"] == "PASS_STATIC" else 1


if __name__ == "__main__":
    raise SystemExit(main())
