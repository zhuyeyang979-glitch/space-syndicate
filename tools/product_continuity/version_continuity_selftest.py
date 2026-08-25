#!/usr/bin/env python3
"""Self-test the continuity audit helper with 30+ read-only cases."""

from __future__ import annotations

import json
import copy
import subprocess
import sys
from pathlib import Path


if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from product_surface_reachability_audit import (  # noqa: E402
    CHECK_NAME,
    REACHABLE_SURFACES,
    UNREACHABLE_SURFACES,
    audit_repository,
    collect_graph,
    first_line_number,
    is_interesting_resource,
    parse_project_main_scene,
    parse_resource_edges,
    repo_root,
    resource_to_path,
)
from version_continuity_gate import (  # noqa: E402
    is_ancestor,
    load_registry,
    run_gate,
    validate_registry,
)


def _assert_equal(failures: list[str], name: str, actual: object, expected: object) -> None:
    if actual != expected:
        failures.append(f"{name}: expected={expected!r} actual={actual!r}")


def _assert_true(failures: list[str], name: str, condition: bool) -> None:
    if not condition:
        failures.append(f"{name}: expected truthy result")


def _assert_contains(failures: list[str], name: str, values: list[str], expected: str) -> None:
    if not any(expected == value or expected in value for value in values):
        failures.append(f"{name}: expected={expected!r} values={values!r}")


def main() -> int:
    failures: list[str] = []
    root = repo_root()
    audit = audit_repository(root)

    project_text = resource_to_path(root, "res://project.godot").read_text(encoding="utf-8-sig")
    main_text = resource_to_path(root, "res://scenes/main.tscn").read_text(encoding="utf-8-sig")
    bootstrap_text = resource_to_path(root, "res://scripts/v075_runtime/v075_application_bootstrap.gd").read_text(
        encoding="utf-8-sig"
    )
    menu_controller_text = resource_to_path(
        root, "res://scripts/runtime/menu_lifecycle_application_flow_controller.gd"
    ).read_text(encoding="utf-8-sig")
    setup_controller_text = resource_to_path(
        root, "res://scripts/runtime/setup_application_flow_controller.gd"
    ).read_text(encoding="utf-8-sig")
    overlay_layer_text = resource_to_path(root, "res://scenes/ui/OverlayLayer.tscn").read_text(encoding="utf-8-sig")
    menu_overlay_text = resource_to_path(root, "res://scenes/ui/MenuOverlay.tscn").read_text(encoding="utf-8-sig")
    menu_quick_text = resource_to_path(root, "res://scenes/ui/MenuQuickNavigation.tscn").read_text(encoding="utf-8-sig")
    menu_root_text = resource_to_path(root, "res://scenes/ui/MenuRootLobby.tscn").read_text(encoding="utf-8-sig")
    setup_page_text = resource_to_path(root, "res://scenes/ui/NewGameSetupPage.tscn").read_text(encoding="utf-8-sig")
    setup_lobby_text = resource_to_path(root, "res://scenes/ui/NewGameSetupLobby.tscn").read_text(encoding="utf-8-sig")
    v075_text = resource_to_path(root, "res://scenes/ui/v075/V075SampleGameScreen.tscn").read_text(encoding="utf-8-sig")
    v074_text = resource_to_path(root, "res://scenes/ui/v074/V074SampleGameScreen.tscn").read_text(encoding="utf-8-sig")
    v073_text = resource_to_path(root, "res://scenes/ui/V073SampleGameScreen.tscn").read_text(encoding="utf-8-sig")

    case_count = 0

    project_scene, project_line = parse_project_main_scene(project_text)
    case_count += 1
    _assert_equal(failures, "project_main_scene", project_scene, "res://scenes/main.tscn")
    case_count += 1
    _assert_true(failures, "project_main_scene_line", project_line > 0)

    main_edges = parse_resource_edges("res://project.godot", project_text)
    case_count += 1
    _assert_equal(failures, "project_edge_count", len(main_edges), 1)
    case_count += 1
    _assert_equal(failures, "project_edge_target", main_edges[0].target if main_edges else None, "res://scenes/main.tscn")

    main_scene_edges = parse_resource_edges("res://scenes/main.tscn", main_text)
    case_count += 1
    _assert_equal(failures, "main_edge_count", len(main_scene_edges), 4)
    case_count += 1
    _assert_equal(
        failures,
        "main_edge_bootstrap",
        main_scene_edges[0].target if len(main_scene_edges) > 0 else None,
        "res://scripts/v075_runtime/v075_application_bootstrap.gd",
    )
    case_count += 1
    _assert_equal(
        failures,
        "main_edge_runtime",
        main_scene_edges[1].target if len(main_scene_edges) > 1 else None,
        "res://scenes/runtime/V075RuntimeComposition.tscn",
    )
    case_count += 1
    _assert_equal(
        failures,
        "main_edge_screen",
        main_scene_edges[2].target if len(main_scene_edges) > 2 else None,
        "res://scenes/ui/v075/V075SampleGameScreen.tscn",
    )
    case_count += 1
    _assert_equal(
        failures,
        "main_edge_loading_overlay",
        main_scene_edges[3].target if len(main_scene_edges) > 3 else None,
        "res://scenes/ui/v075/V075NewGameLoadingOverlay.tscn",
    )

    bootstrap_edges = parse_resource_edges("res://scripts/v075_runtime/v075_application_bootstrap.gd", bootstrap_text)
    case_count += 1
    _assert_equal(
        failures,
        "bootstrap_edge_target",
        bootstrap_edges[0].target if bootstrap_edges else None,
        "res://scripts/v075_runtime/game_runtime_context_query.gd",
    )

    menu_edges = parse_resource_edges("res://scripts/runtime/menu_lifecycle_application_flow_controller.gd", menu_controller_text)
    case_count += 1
    _assert_equal(
        failures,
        "menu_controller_root_lobby",
        next((edge.target for edge in menu_edges if edge.target.endswith("MenuRootLobby.tscn")), None),
        "res://scenes/ui/MenuRootLobby.tscn",
    )
    case_count += 1
    _assert_equal(
        failures,
        "menu_controller_credits",
        next((edge.target for edge in menu_edges if edge.target.endswith("CommercialCreditsSurface.tscn")), None),
        "res://scenes/ui/CommercialCreditsSurface.tscn",
    )
    case_count += 1
    _assert_equal(
        failures,
        "menu_controller_pause",
        next((edge.target for edge in menu_edges if edge.target.endswith("PauseMenuSummaryBoard.tscn")), None),
        "res://scenes/ui/PauseMenuSummaryBoard.tscn",
    )

    setup_edges = parse_resource_edges("res://scripts/runtime/setup_application_flow_controller.gd", setup_controller_text)
    case_count += 1
    _assert_equal(
        failures,
        "setup_controller_page",
        next((edge.target for edge in setup_edges if edge.target.endswith("NewGameSetupPage.tscn")), None),
        "res://scenes/ui/NewGameSetupPage.tscn",
    )

    overlay_edges = parse_resource_edges("res://scenes/ui/OverlayLayer.tscn", overlay_layer_text)
    case_count += 1
    _assert_true(failures, "overlay_has_menu_overlay", any(edge.target.endswith("MenuOverlay.tscn") for edge in overlay_edges))

    menu_overlay_edges = parse_resource_edges("res://scenes/ui/MenuOverlay.tscn", menu_overlay_text)
    case_count += 1
    _assert_true(
        failures,
        "menu_overlay_has_quick_navigation",
        any(edge.target.endswith("MenuQuickNavigation.tscn") for edge in menu_overlay_edges),
    )

    setup_page_edges = parse_resource_edges("res://scenes/ui/NewGameSetupPage.tscn", setup_page_text)
    case_count += 1
    _assert_true(
        failures,
        "setup_page_has_lobby",
        any(edge.target.endswith("NewGameSetupLobby.tscn") for edge in setup_page_edges),
    )

    setup_lobby_edges = parse_resource_edges("res://scenes/ui/NewGameSetupLobby.tscn", setup_lobby_text)
    case_count += 1
    _assert_true(failures, "setup_lobby_has_body", len(setup_lobby_edges) > 0)

    v075_edges = parse_resource_edges("res://scenes/ui/v075/V075SampleGameScreen.tscn", v075_text)
    case_count += 1
    _assert_equal(
        failures,
        "v075_edge_to_v074",
        next((edge.target for edge in v075_edges if edge.target.endswith("V074SampleGameScreen.tscn")), None),
        "res://scenes/ui/v074/V074SampleGameScreen.tscn",
    )

    v074_edges = parse_resource_edges("res://scenes/ui/v074/V074SampleGameScreen.tscn", v074_text)
    case_count += 1
    _assert_equal(
        failures,
        "v074_edge_to_v073",
        next((edge.target for edge in v074_edges if edge.target.endswith("V073SampleGameScreen.tscn")), None),
        "res://scenes/ui/V073SampleGameScreen.tscn",
    )

    v073_inline_line = first_line_number(v073_text, '[node name="OverlayLayer" type="CanvasLayer"')
    case_count += 1
    _assert_equal(failures, "v073_inline_overlay_line", v073_inline_line, 507)

    graph_edges, reverse_edges, main_scene, _main_scene_line = collect_graph(root)
    case_count += 1
    _assert_equal(failures, "collect_graph_main_scene", main_scene, "res://scenes/main.tscn")
    case_count += 1
    _assert_true(failures, "collect_graph_has_main_edges", len(graph_edges.get("res://scenes/main.tscn", [])) >= 3)

    reachable = {entry["path"]: entry for entry in audit["surface_reachability"]}
    case_count += 1
    _assert_equal(failures, "audit_status", audit["status"], "PASS_STATIC")
    case_count += 1
    _assert_equal(failures, "audit_check_name", audit["check_name"], CHECK_NAME)
    case_count += 1
    _assert_equal(failures, "audit_read_only", audit["read_only"], True)
    case_count += 1
    _assert_equal(failures, "audit_godot_reproof", audit["godot_full_reproof_run"], False)
    case_count += 1
    _assert_true(failures, "audit_reachable_surface_count", len(reachable) >= len(REACHABLE_SURFACES))

    for surface in REACHABLE_SURFACES:
        case_count += 1
        _assert_equal(
            failures,
            f"reachable_status:{surface}",
            reachable.get(surface, {}).get("status"),
            "REACHABLE_FROM_CURRENT_MAIN",
        )

    for surface in UNREACHABLE_SURFACES:
        case_count += 1
        _assert_equal(
            failures,
            f"unreachable_status:{surface}",
            reachable.get(surface, {}).get("status"),
            "UNREACHABLE_FROM_CURRENT_MAIN",
        )

    case_count += 1
    _assert_true(
        failures,
        "menu_root_referrer_present",
        any(edge.source == "res://scripts/runtime/menu_lifecycle_application_flow_controller.gd" for edge in reverse_edges["res://scenes/ui/MenuRootLobby.tscn"]),
    )
    case_count += 1
    _assert_true(
        failures,
        "menu_overlay_referrer_present",
        any(edge.source == "res://scenes/ui/OverlayLayer.tscn" for edge in reverse_edges["res://scenes/ui/MenuOverlay.tscn"]),
    )
    case_count += 1
    _assert_true(
        failures,
        "setup_page_referrer_present",
        any(edge.source == "res://scripts/runtime/setup_application_flow_controller.gd" for edge in reverse_edges["res://scenes/ui/NewGameSetupPage.tscn"]),
    )
    case_count += 1
    _assert_true(
        failures,
        "setup_lobby_referrer_present",
        any(edge.source == "res://scenes/ui/NewGameSetupPage.tscn" for edge in reverse_edges["res://scenes/ui/NewGameSetupLobby.tscn"]),
    )
    case_count += 1
    _assert_true(
        failures,
        "quick_navigation_referrer_present",
        any(edge.source == "res://scenes/ui/MenuOverlay.tscn" for edge in reverse_edges["res://scenes/ui/MenuQuickNavigation.tscn"]),
    )
    case_count += 1
    _assert_equal(
        failures,
        "inline_overlay_chain_marker",
        audit["main_chain"][-1]["to"] if audit["main_chain"] else None,
        "inline OverlayLayer",
    )
    case_count += 1
    _assert_equal(
        failures,
        "inline_overlay_chain_line",
        audit["main_chain"][-1]["line"] if audit["main_chain"] else None,
        507,
    )

    case_count += 1
    _assert_true(failures, "is_interesting_scene", is_interesting_resource("res://scenes/main.tscn"))
    case_count += 1
    _assert_true(failures, "is_interesting_script", is_interesting_resource("res://scripts/runtime/menu_lifecycle_application_flow_controller.gd"))
    case_count += 1
    _assert_true(failures, "is_not_interesting_png", not is_interesting_resource("res://docs/ui_qa/step.png"))

    case_count += 1
    _assert_equal(failures, "main_chain_bootstrap_line", audit["main_ext_resource_lines"]["bootstrap"], 3)
    case_count += 1
    _assert_equal(failures, "main_chain_runtime_line", audit["main_ext_resource_lines"]["runtime_composition"], 4)
    case_count += 1
    _assert_equal(failures, "main_chain_screen_line", audit["main_ext_resource_lines"]["game_screen"], 5)
    case_count += 1
    _assert_equal(failures, "overlay_support_exists", audit["supporting_files"][2]["exists"], True)

    # Registry and gate contract cases. These mutate deep copies only; no
    # repository file, product scene, or runtime process is changed.
    registry = load_registry(root)
    baseline_registry_failures = validate_registry(root, registry, audit)
    case_count += 1
    _assert_equal(failures, "registry_baseline_valid", baseline_registry_failures, [])

    def registry_case(name: str, mutator, expected: str | None = None, forbidden: str | None = None) -> None:
        nonlocal case_count
        candidate = copy.deepcopy(registry)
        mutator(candidate)
        result = validate_registry(root, candidate, audit)
        case_count += 1
        if expected is None:
            _assert_equal(failures, name, result, [])
        else:
            _assert_contains(failures, name, result, expected)
        if forbidden is not None:
            _assert_true(failures, f"{name}:forbidden", forbidden not in result)

    v76 = next(item for item in registry["versions"] if item["version_id"] == "v0.7.6")
    v75 = next(item for item in registry["versions"] if item["version_id"] == "v0.7.5")

    registry_case("missing_parent", lambda x: next(item for item in x["versions"] if item["version_id"] == "v0.7.6").__setitem__("parent_version_id", None), "VERSION_PARENT_MISSING:v0.7.6")
    registry_case("unknown_parent", lambda x: next(item for item in x["versions"] if item["version_id"] == "v0.7.6").__setitem__("parent_version_id", "v0.9.9"), "VERSION_PARENT_MISSING:v0.7.6")
    case_count += 1
    _assert_true(failures, "parent_commit_not_ancestor", not is_ancestor(root, v75["base_commit_sha"], "f49c86af20b6a65e9792aa87703154e853d4dc76"))
    registry_case("missing_base_commit", lambda x: next(item for item in x["versions"] if item["version_id"] == "v0.7.6").__setitem__("base_commit_sha", "0" * 40), "VERSION_BASE_COMMIT_MISSING:v0.7.6")
    registry_case("activation_tree_mismatch", lambda x: x["activation"].__setitem__("activation_tree_sha", "0" * 40), "ACTIVATION_TREE_MISMATCH")
    registry_case("unknown_delta_capability", lambda x: next(item for item in x["versions"] if item["version_id"] == "v0.7.6")["deferred_capability_ids"].append("product.unknown.delta"), "VERSION_DELTA_UNKNOWN_CAPABILITY:v0.7.6:product.unknown.delta")
    registry_case("silent_active_capability_loss", lambda x: next(item for item in x["versions"] if item["version_id"] == "v0.7.6")["inherited_capability_ids"].remove("product.main_table"), "SILENT_ACTIVE_CAPABILITY_LOSS:v0.7.6:product.main_table")
    registry_case("explicit_deferred_disposition", lambda x: (next(item for item in x["versions"] if item["version_id"] == "v0.7.6")["inherited_capability_ids"].remove("product.main_table"), next(item for item in x["versions"] if item["version_id"] == "v0.7.6")["deferred_capability_ids"].append("product.main_table")), None)
    case_count += 1
    _assert_true(failures, "superseded_capability_recorded", "product.v074.float_voronoi_authority" in v76["superseded_capability_ids"])
    case_count += 1
    _assert_true(failures, "retired_capability_recorded", "product.legacy_main_owner" in v75["retired_capability_ids"])
    registry_case("unknown_capability_status", lambda x: next(item for item in x["capabilities"] if item["capability_id"] == "product.main_table").__setitem__("current_status", "NOT_A_STATUS"), "UNKNOWN_CAPABILITY_STATUS:product.main_table")
    registry_case("missing_capability_field", lambda x: next(item for item in x["capabilities"] if item["capability_id"] == "product.main_table").pop("acceptance_criteria"), "capability:")
    registry_case("duplicate_capability_id", lambda x: x["capabilities"].append(copy.deepcopy(x["capabilities"][0])), "DUPLICATE_OR_EMPTY_CAPABILITY_ID")
    registry_case("asset_removed_without_disposition", lambda x: (x["assets"][0].__setitem__("present_in_current_tree", False), x["assets"][0].__setitem__("replaced_by", []), x["assets"][0].__setitem__("planned_action", "")), "ASSET_REMOVED_WITHOUT_DISPOSITION")
    registry_case("asset_removed_with_disposition", lambda x: (x["assets"][0].__setitem__("present_in_current_tree", False), x["assets"][0].__setitem__("replaced_by", ["asset.replacement"])), None)
    registry_case("duplicate_asset_id", lambda x: x["assets"].append(copy.deepcopy(x["assets"][0])), "DUPLICATE_ASSET_ID")
    registry_case("missing_surface_field", lambda x: next(iter(x["product_surfaces"])).pop("entrypoint"), "surface:0:MISSING_FIELD:entrypoint")
    registry_case("missing_work_field", lambda x: x["current_work_items"][0].pop("next_task"), "current_work:0:MISSING_FIELD:next_task")
    registry_case("invalid_work_status", lambda x: x["current_work_items"][0].__setitem__("status", "UNKNOWN"), "UNKNOWN_WORK_STATUS")
    registry_case("duplicate_work_id", lambda x: x["current_work_items"].append(copy.deepcopy(x["current_work_items"][0])), "DUPLICATE_WORK_ITEM_ID")
    registry_case("missing_backlog_field", lambda x: x["future_backlog"][0].pop("human_play_status"), "future_backlog:0:MISSING_FIELD:human_play_status")
    registry_case("missing_retired_goal_field", lambda x: x["retired_goals"][0].pop("decision_reason"), "retired_goals:0:MISSING_FIELD:decision_reason")

    audit_bad = copy.deepcopy(audit)
    audit_bad["status"] = "FAIL_STATIC"
    case_count += 1
    _assert_contains(failures, "audit_failure_propagates", validate_registry(root, registry, audit_bad), "PRODUCTION_SURFACE_REACHABILITY_AUDIT_FAILED")
    audit_bad = copy.deepcopy(audit)
    audit_bad["read_only"] = False
    case_count += 1
    _assert_contains(failures, "audit_mutation_rejected", validate_registry(root, registry, audit_bad), "AUDIT_NOT_READ_ONLY")
    audit_bad = copy.deepcopy(audit)
    audit_bad["surface_reachability"] = [entry for entry in audit_bad["surface_reachability"] if entry["path"] != "res://scenes/main.tscn"]
    case_count += 1
    _assert_contains(failures, "core_surface_loss_rejected", validate_registry(root, registry, audit_bad), "SILENT_PRODUCTION_SURFACE_LOSS:res://scenes/main.tscn")

    case_count += 1
    _assert_true(failures, "dynamic_loads_remain_unknown", isinstance(audit.get("dynamic_reachability_unknown_sources"), list))
    case_count += 1
    _assert_true(failures, "unclassified_assets_zero", audit.get("unclassified_present_asset_count") == 0)
    case_count += 1
    _assert_true(failures, "menu_present_but_unreachable", audit.get("menu_root_lobby_present") is True and audit.get("menu_root_lobby_production_reachable") is False)
    case_count += 1
    _assert_true(failures, "embedded_start_overlay_reachable", audit.get("embedded_start_overlay_present") is True and audit.get("embedded_start_overlay_production_reachable") is True)
    case_count += 1
    _assert_true(failures, "standalone_replacement_unresolved", audit.get("standalone_menu_superseded_by_embedded_start") == "UNRESOLVED")
    case_count += 1
    _assert_true(failures, "loading_overlay_reachable", "res://scenes/ui/v075/V075NewGameLoadingOverlay.tscn" in {entry["path"] for entry in audit["surface_reachability"] if entry["status"] == "REACHABLE_FROM_CURRENT_MAIN"})
    case_count += 1
    _assert_true(failures, "current_parent_is_v075", registry["project_identity"]["parent_version_id"] == "v0.7.5" and v76["parent_version_id"] == "v0.7.5")
    case_count += 1
    _assert_true(failures, "activation_head_is_e372", registry["activation"]["activation_head_sha"].startswith("e372c105"))
    case_count += 1
    _assert_true(failures, "human_green_false", registry["activation"]["human_green"] is False)
    case_count += 1
    _assert_true(failures, "production_green_false", registry["activation"]["production_green"] is False)
    case_count += 1
    _assert_true(failures, "step13_pending", registry["activation"]["golden_step_13_status"] == "PENDING")
    case_count += 1
    _assert_true(failures, "reuse_gate_retained", (root / ".github/workflows/v076-reuse-point-inertia-gate.yml").is_file())
    case_count += 1
    _assert_true(failures, "single_continuity_registry", len(list((root / "docs/product").glob("SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json"))) == 1)
    case_count += 1
    _assert_true(failures, "version_delta_ids_unique", len({item["version_delta_id"] for item in registry["versions"]}) == len(registry["versions"]))
    case_count += 1
    _assert_true(failures, "current_work_ids_unique", len({item["work_item_id"] for item in registry["current_work_items"]}) == len(registry["current_work_items"]))
    case_count += 1
    _assert_true(failures, "backlog_ids_unique", len({item["backlog_id"] for item in registry["future_backlog"]}) == len(registry["future_backlog"]))
    case_count += 1
    _assert_true(failures, "generated_views_present", all((root / "docs/product" / name).is_file() for name in ("SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.md", "SPACE_SYNDICATE_VERSION_HISTORY.md", "SPACE_SYNDICATE_CURRENT_DEVELOPMENT_STATUS.md", "SPACE_SYNDICATE_FUTURE_ROADMAP.md", "SPACE_SYNDICATE_RETIRED_AND_CANCELLED_GOALS.md")))
    case_count += 1
    _assert_true(failures, "generated_views_source_marker", all("GENERATED_FROM=SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json" in (root / "docs/product" / name).read_text(encoding="utf-8") for name in ("SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.md", "SPACE_SYNDICATE_VERSION_HISTORY.md", "SPACE_SYNDICATE_CURRENT_DEVELOPMENT_STATUS.md", "SPACE_SYNDICATE_FUTURE_ROADMAP.md", "SPACE_SYNDICATE_RETIRED_AND_CANCELLED_GOALS.md")))
    gate_report = run_gate(root)
    case_count += 1
    _assert_equal(failures, "full_gate_passes", gate_report["status"], "PASS_STATIC")
    case_count += 1
    _assert_equal(failures, "full_gate_has_no_failures", gate_report["failure_count"], 0)

    report = {
        "check_name": CHECK_NAME,
        "status": "PASS" if not failures else "FAIL",
        "case_count": case_count,
        "failure_count": len(failures),
        "failures": failures,
    }
    print(json.dumps(report, ensure_ascii=True, indent=2, sort_keys=True))
    print(f"VERSION_CONTINUITY_SELFTEST|status={report['status']}|case_count={case_count}|pass_count={case_count - len(failures)}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
