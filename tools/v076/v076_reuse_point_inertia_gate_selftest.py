#!/usr/bin/env python3
"""Production-shaped self-test for the V0.7.6 reuse/inertia gate.

The fixtures call the canonical ``validate_model`` entry point directly.  They
exercise base/head authority snapshots and PR/gate deltas without starting
Godot, mutating the repository, or maintaining a second scanner.
"""

from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import v076_reuse_point_inertia_gate as gate  # noqa: E402


SELFTEST_SCHEMA = "space_syndicate.v076.reuse_point_inertia_gate_selftest.v1"
BASE_OWNER_ID = "component.map.existing_owner"
BASE_OWNER_PATH = "scripts/v076/map/existing_owner.gd"
BASE_DOMAIN_ID = "map"
LEGACY_DEBT_PATH = "tests/legacy/pr70_runtime_attempt.gd"


def _reuse_scan(*, reasons_present: bool = True) -> dict[str, Any]:
    reason = "No additional owner is created; the registered owner boundary is preserved."
    if not reasons_present:
        reason = ""
    return {
        "reuse_registry_search": True,
        "class_name_search": True,
        "semantic_signature_search": True,
        "owner_map_search": True,
        "state_write_surface_search": True,
        "rng_owner_search": True,
        "save_owner_search": True,
        "replay_owner_search": True,
        "signal_and_receipt_search": True,
        "reuse_candidate_count": 1,
        "reuse_candidate_ids": ["reuse.map.existing_owner"],
        "selected_reuse_disposition": "ADOPT_AS_OWNER",
        "why_existing_owner_cannot_be_extended": reason,
        "why_adapter_is_insufficient": reason,
        "why_new_owner_is_required": reason,
    }


def _component(
    component_id: str,
    path: str,
    domain_id: str,
    role: str,
    *,
    production_reachable: bool,
    owner_component_id: str = BASE_OWNER_ID,
    reuse_disposition: str = "ADAPT_AS_CONSUMER",
    include_reuse_scan: bool = False,
) -> dict[str, Any]:
    is_owner = role == "OWNER"
    row: dict[str, Any] = {
        "component_id": component_id,
        "class_name": "SelfTest" + "".join(part.title() for part in component_id.split(".")),
        "path": path,
        "domain_id": domain_id,
        "component_role": role,
        "production_reachable": production_reachable,
        "writes_authority": is_owner and production_reachable,
        "reads_authority": production_reachable,
        "owns_rng": False,
        "owns_tick": is_owner and production_reachable,
        "owns_save": False,
        "owns_replay": False,
        "owns_identity": is_owner and production_reachable,
        "owns_presentation": False,
        "owner_component_id": component_id if is_owner else owner_component_id,
        "owner_path": path if is_owner else BASE_OWNER_PATH,
        "reuse_disposition": reuse_disposition,
        "reuse_source_ids": ["reuse.map.existing_owner"],
        "reuse_candidates_considered": ["reuse.map.existing_owner"],
        "new_component_justification": "Self-test fixture for a classified delta.",
        "supersedes": [],
        "superseded_by": [],
        "change_class": "DOMAIN_CORE",
        "focused_test_ids": ["v076.reuse_point_inertia.selftest"],
        "golden_scenario_steps": ["golden.map.owner"],
    }
    if include_reuse_scan:
        row["reuse_scan"] = _reuse_scan()
    return row


def _status() -> dict[str, Any]:
    return {
        "schema_version": "space_syndicate.v076.canonical_pr_status.v1",
        "pr_number": 93,
        "stage_1_status": "ISOLATED_GREEN",
        "stage_2_status": "ISOLATED_GREEN",
        "stage_3_status": "ISOLATED_GREEN",
        "stage_1_ledger_status": "INHERITED_GREEN",
        "stage_2_ledger_status": "INHERITED_GREEN",
        "stage_3_ledger_status": "CURRENT_DELTA_GREEN",
        "historical_reuse_status": "ACTIVE",
        "point_inertia_status": "ACTIVE",
        "golden_isolated_green_count": 1,
        "golden_production_green_count": 0,
        "golden_human_green_count": 0,
        "production_cutover_status": False,
        "latest_completed_stage": gate.CANONICAL_STAGE_IDS[2],
        "latest_completed_stage_head_sha": "c" * 40,
        "next_stage": "V076_STAGE_4_PENDING_OWNER_REGISTRATION",
        "v075_pr90_dependency_boundary": "REFERENCE_ONLY_EXACT_BASE_NO_V076_CUTOVER",
    }


def _authorities() -> dict[str, dict[str, Any]]:
    owner = _component(
        BASE_OWNER_ID,
        BASE_OWNER_PATH,
        BASE_DOMAIN_ID,
        "OWNER",
        production_reachable=True,
        reuse_disposition="ADOPT_AS_OWNER",
        include_reuse_scan=True,
    )
    certification = {field: True for field in gate.CARD_CERTIFICATION_FIELDS}
    return {
        "historical_reuse": {
            "schema_version": gate.AUTHORITY_CONTRACTS["historical_reuse"][0],
            "registry_id": gate.AUTHORITY_CONTRACTS["historical_reuse"][2],
            "candidate_head_sha": "c" * 40,
            "component_inventory": [owner],
            "domain_inventory": [
                {
                    "domain_id": BASE_DOMAIN_ID,
                    "lifecycle": "ACTIVE_CURRENT_DOMAIN",
                    "owner_component_id": BASE_OWNER_ID,
                }
            ],
            "reuse_entries": [
                {
                    "reuse_id": "reuse.map.existing_owner",
                    "disposition": "ADOPT_AS_OWNER",
                }
            ],
            "unique_owner_domains": [
                {
                    "domain_id": BASE_DOMAIN_ID,
                    "unique_owner": owner["class_name"],
                    "owner_path": BASE_OWNER_PATH,
                }
            ],
            "legacy_debt_grandfather_paths": [LEGACY_DEBT_PATH],
        },
        "supersession": {
            "schema_version": gate.AUTHORITY_CONTRACTS["supersession"][0],
            "map_id": gate.AUTHORITY_CONTRACTS["supersession"][2],
            "entries": [],
            "production_cutover": False,
        },
        "inherited_green": {
            "schema_version": gate.AUTHORITY_CONTRACTS["inherited_green"][0],
            "ledger_id": gate.AUTHORITY_CONTRACTS["inherited_green"][2],
            "candidate": {
                "head_sha": "c" * 40,
                "tree_sha": "b" * 40,
            },
            "stages": [
                {
                    "stage_id": gate.CANONICAL_STAGE_IDS[0],
                    "ledger_status": "INHERITED_GREEN",
                },
                {
                    "stage_id": gate.CANONICAL_STAGE_IDS[1],
                    "ledger_status": "INHERITED_GREEN",
                },
                {
                    "stage_id": gate.CANONICAL_STAGE_IDS[2],
                    "ledger_status": "CURRENT_DELTA_GREEN",
                    "head_sha": "c" * 40,
                },
            ],
            "canonical_change_scope": {
                "change_classes": ["TOOLING_ONLY", "DOCS_ONLY"],
                "full_reproof_required": False,
                "full_reproof_trigger": "NONE",
                "focused_tests": sorted(gate.REQUIRED_TOOLING_FOCUSED_TESTS),
                "affected_domains": [BASE_DOMAIN_ID],
                "affected_owners": [BASE_OWNER_ID],
                "inherited_sentinels": [
                    "architecture",
                    "semantic_architecture",
                    "owner",
                    "main_retirement",
                    "privacy",
                    "card_semantic",
                    "production_composition",
                ],
                "why_focused_tests_are_sufficient": (
                    "The fixture delta is gate tooling only and inherits all product sentinels."
                ),
            },
            "canonical_pr_status": _status(),
            "gate_activation_boundary_commit": gate.ACTIVATION_BOUNDARY_COMMIT,
            "point_inertia_baseline_sha": gate.V076_GATE_BASE_SHA,
            "agent_merge_requires_reuse_gate": True,
            "required_check_name": gate.CHECK_NAME,
        },
        "golden": {
            "schema_version": gate.AUTHORITY_CONTRACTS["golden"][0],
            "scenario_id": gate.AUTHORITY_CONTRACTS["golden"][2],
            "candidate_head_sha": "c" * 40,
            "human_execution_count": 0,
            "production_pass_count": 0,
            "isolated_green_count": 1,
            "steps": [
                {
                    "step_id": "golden.map.owner",
                    "status": "ISOLATED_GREEN",
                    "human_executed": False,
                    "production_composition": False,
                    "pass_claimed": True,
                    "required_surface": "isolated architecture fixture",
                    "evidence": "Focused isolated self-test receipt.",
                }
            ],
            "summary": {
                "step_count": 1,
                "isolated_green_step_ids": ["golden.map.owner"],
                "pending_step_ids": [],
                "human_pass_step_ids": [],
                "production_pass_step_ids": [],
            },
        },
        "card_matrix": {
            "schema_version": gate.AUTHORITY_CONTRACTS["card_matrix"][0],
            "matrix_id": gate.AUTHORITY_CONTRACTS["card_matrix"][2],
            "certification_dimensions": list(gate.CARD_CERTIFICATION_FIELDS),
            "category_matrix": [
                {
                    "category_id": "ordinary_cards",
                    "card_count": 1,
                    "certification": certification,
                }
            ],
            "aggregate": {
                "category_count": 1,
                "category_card_count_sum": 1,
                "alpha07_certified_card_count": 1,
            },
        },
    }


def _implementation_paths() -> dict[str, list[str]]:
    return {
        "historical_reuse": ["docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"],
        "supersession": ["docs/architecture/V076_SUPERSESSION_MAP.json"],
        "inherited_green": ["docs/architecture/V076_INHERITED_GREEN_LEDGER.json"],
        "golden": ["docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json"],
        "card_matrix": ["reports/card_certification/v076_card_certification_matrix.json"],
        "owner_map": ["docs/architecture/V076_OWNER_REUSE_MAP.md"],
    }


def _write_authority_fixture(
    root: Path, authorities: dict[str, dict[str, Any]]
) -> None:
    for key in gate.SCHEMA_PREFIXES:
        relative_path = _implementation_paths()[key][0]
        target = root / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            json.dumps(authorities[key], ensure_ascii=False, indent=2, sort_keys=True)
            + "\n",
            encoding="utf-8",
        )


def _git_fixture(root: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    return completed.stdout.strip()


def _registered_stage4_fixture() -> gate.ValidationInput:
    data = _valid_input()
    owner = _add_active_owner(data, "stage4_history")
    owner["owns_tick"] = False
    scope = data.authorities["inherited_green"]["canonical_change_scope"]
    scope["change_classes"] = ["DOMAIN_CORE"]
    scope["affected_domains"] = [owner["domain_id"]]
    scope["affected_owners"] = [owner["component_id"]]
    scope["focused_tests"] = list(owner["focused_test_ids"])
    stage4_path = str(owner["path"])
    data.gate_changed_paths = [{"status": "A", "path": stage4_path}]
    data.pr_body = _pr_body(data)
    return data


def _pr_body(data: gate.ValidationInput) -> str:
    status = data.authorities["inherited_green"]["canonical_pr_status"]
    return "V0.7.6 Stage 3 isolated evidence is current.\n\n" + gate.render_status_block(status)


def _valid_input() -> gate.ValidationInput:
    authorities = _authorities()
    data = gate.ValidationInput(
        authorities=authorities,
        implementation_paths=_implementation_paths(),
        baseline_authorities=copy.deepcopy(authorities),
        changed_paths=[],
        gate_changed_paths=[
            {"status": "A", "path": "tools/v076/v076_reuse_point_inertia_gate.py"},
            {"status": "M", "path": "docs/architecture/V076_INHERITED_GREEN_LEDGER.json"},
        ],
        pr_body="",
        stage_parent_is_descendant=True,
        scanner_presence={
            str(scanner["scanner_id"]): True for scanner in gate.SCANNER_INVENTORY
        },
        component_declared_classes={
            component["path"]: component["class_name"]
            for component in authorities["historical_reuse"]["component_inventory"]
            if gate._is_product_component_path(component["path"])
            and component["path"].endswith(".gd")
        },
        evidence_artifact_bindings={},
        git_commit_tree_bindings={"c" * 40: "b" * 40},
        retired_scanner_status="PASS",
    )
    data.pr_body = _pr_body(data)
    return data


def _valid_historical_owner_to_reducer_evidence() -> dict[str, Any]:
    return {
        "supersession_id": (
            "historical.player-mana-to-v07-asset-batch-core"
        ),
        "cutover_commit_exists": True,
        "cutover_is_source_ancestor": True,
        "cutover_is_head_ancestor": True,
        "source_is_head_ancestor": True,
        "old_source_path_exists": True,
        "old_source_blob_sha256": (
            "0bf285bd2f0e10d4f44ba6779a94fdf10367cf131396b59367b7b26e9d772ac5"
        ),
        "cutover_parent_main_has_old_composition": True,
        "cutover_parent_old_composition_has_old_scene": True,
        "cutover_main_has_new_composition": True,
        "cutover_main_has_old_composition": False,
        "cutover_owner_has_new_reducer": True,
        "cutover_manifest_sha256": (
            "9562593e7173d4d6437992916f64562107593e539833ca27b64d6ff4bc0ac52d"
        ),
        "cutover_manifest_contract_valid": True,
        "current_reference_closure_failure_count": 0,
        "current_closure_has_new_reducer": True,
        "current_closure_has_old_composition": False,
        "current_closure_has_old_component_scene": False,
        "current_main_has_old_composition": False,
        "current_main_has_old_component_scene": False,
    }


def _historical_owner_to_reducer_fixture() -> gate.ValidationInput:
    data = _valid_input()
    row = copy.deepcopy(gate.HISTORICAL_OWNER_TO_CURRENT_REDUCER_EXPECTED_ROW)
    old_id = str(row["old_component_id"])
    new_id = str(row["new_component_id"])
    owner_id = str(row["new_owner_component_id"])
    domain_id = str(row["domain_id"])
    owner_path = "scripts/v075_runtime/v075_runtime_owner.gd"

    for authorities in (data.authorities, data.baseline_authorities):
        registry = authorities["historical_reuse"]
        owner = registry["component_inventory"][0]
        owner.update(
            {
                "component_id": owner_id,
                "class_name": "V075RuntimeOwner",
                "path": owner_path,
                "domain_id": domain_id,
                "owner_component_id": owner_id,
                "owner_path": owner_path,
            }
        )
        registry["domain_inventory"][0].update(
            {"domain_id": domain_id, "owner_component_id": owner_id}
        )
        registry["unique_owner_domains"][0].update(
            {
                "domain_id": domain_id,
                "unique_owner": "V075RuntimeOwner",
                "owner_path": owner_path,
            }
        )
        reducer = _component(
            new_id,
            str(row["new_owner_path"]),
            domain_id,
            "REDUCER",
            production_reachable=True,
            owner_component_id=owner_id,
        )
        reducer.update(
            {
                "class_name": "V07AssetBatchCore",
                "writes_authority": True,
                "owner_path": owner_path,
                "supersedes": [old_id],
            }
        )
        registry["component_inventory"].append(reducer)
        registry["historical_identity_backfill"] = [
            {
                "component_id": old_id,
                "current_disposition": "HISTORICAL_SUPERSEDED_NONREACHABLE",
                "historical_role": "OWNER",
                "production_reachability": "NONREACHABLE",
                "source_blob": str(row["old_source_blob_sha256"]),
                "source_commit": str(row["old_source_commit"]),
                "supersession": [new_id],
            }
        ]
        supersession = authorities["supersession"]
        supersession["supersession_kinds"] = [
            gate.HISTORICAL_OWNER_TO_CURRENT_REDUCER_KIND
        ]
        supersession["entries"] = [copy.deepcopy(row)]
        scope = authorities["inherited_green"]["canonical_change_scope"]
        scope["affected_domains"] = [domain_id]
        scope["affected_owners"] = [owner_id]

    data.component_declared_classes = {
        owner_path: "V075RuntimeOwner",
        str(row["new_owner_path"]): "V07AssetBatchCore",
    }
    data.git_commit_tree_bindings = {
        "c" * 40: "b" * 40,
        str(row["cutover_commit"]): "a" * 40,
    }
    data.historical_owner_to_reducer_cutover_evidence = {
        str(row["supersession_id"]): _valid_historical_owner_to_reducer_evidence()
    }
    data.pr_body = _pr_body(data)
    return data


def _registry(data: gate.ValidationInput) -> dict[str, Any]:
    return data.authorities["historical_reuse"]


def _add_active_owner(
    data: gate.ValidationInput,
    suffix: str,
    *,
    include_reuse_scan: bool = True,
) -> dict[str, Any]:
    component_id = f"component.{suffix}.owner"
    domain_id = f"domain.{suffix}"
    path = f"scripts/v076/{suffix}/runtime_owner.gd"
    component = _component(
        component_id,
        path,
        domain_id,
        "OWNER",
        production_reachable=True,
        reuse_disposition="ADOPT_AS_OWNER",
        include_reuse_scan=include_reuse_scan,
    )
    registry = _registry(data)
    registry["component_inventory"].append(component)
    registry["domain_inventory"].append(
        {
            "domain_id": domain_id,
            "lifecycle": "ACTIVE_CURRENT_DOMAIN",
            "owner_component_id": component_id,
        }
    )
    registry["unique_owner_domains"].append(
        {
            "domain_id": domain_id,
            "unique_owner": component["class_name"],
            "owner_path": path,
        }
    )
    data.changed_paths.append({"status": "A", "path": path})
    if data.component_declared_classes is not None:
        data.component_declared_classes[path] = component["class_name"]
    return component


def _add_non_owner(
    data: gate.ValidationInput,
    suffix: str,
    role: str,
    *,
    production_reachable: bool,
    owner_component_id: str = BASE_OWNER_ID,
) -> dict[str, Any]:
    path = f"scripts/v076/map/{suffix}.gd"
    component = _component(
        f"component.map.{suffix}",
        path,
        BASE_DOMAIN_ID,
        role,
        production_reachable=production_reachable,
        owner_component_id=owner_component_id,
        reuse_disposition=(
            "REUSE_AS_TEST" if role == "DIAGNOSTIC_BENCH" else "ADAPT_AS_CONSUMER"
        ),
    )
    _registry(data)["component_inventory"].append(component)
    data.changed_paths.append({"status": "A", "path": path})
    if data.component_declared_classes is not None:
        data.component_declared_classes[path] = component["class_name"]
    return component


def _pending_domain_first_owner_fixture() -> gate.ValidationInput:
    data = _valid_input()
    domain_id = "future.private_direct_action_input"
    component_id = "component.stage4.private_direct_action.owner"
    component_path = "scripts/v076/direct_action/private_direct_action_owner.gd"
    pending_domain = {
        "domain_id": domain_id,
        "lifecycle": "PENDING_FUTURE_DOMAIN",
        "owner_component_id": "",
    }
    pending_owner_row = {
        "domain_id": domain_id,
        "unique_owner": "UNASSIGNED_PENDING_ATOMIC_CUTOVER",
        "owner_count": 0,
        "binding_status": "PENDING",
    }
    data.baseline_authorities["historical_reuse"][
        "unique_owner_domains"
    ].append(copy.deepcopy(pending_owner_row))
    registry = data.authorities["historical_reuse"]
    registry["domain_inventory"].append(copy.deepcopy(pending_domain))
    registry["unique_owner_domains"].append(copy.deepcopy(pending_owner_row))

    owner = _component(
        component_id,
        component_path,
        domain_id,
        "OWNER",
        production_reachable=True,
        reuse_disposition="ADOPT_AS_OWNER",
        include_reuse_scan=True,
    )
    owner["owns_tick"] = False
    owner["change_class"] = "CROSS_DOMAIN_INTEGRATION"
    owner["owner_component_id"] = component_id
    owner["owner_path"] = component_path
    registry["component_inventory"].append(owner)
    registry["domain_inventory"][-1] = {
        "domain_id": domain_id,
        "lifecycle": "ACTIVE_CURRENT_DOMAIN",
        "owner_component_id": component_id,
    }
    registry["unique_owner_domains"][-1] = {
        "domain_id": domain_id,
        "unique_owner": owner["class_name"],
        "owner_path": component_path,
        "owner_count": 1,
        "binding_status": "ACTIVE_STAGE4_ISOLATED",
    }
    scope = data.authorities["inherited_green"]["canonical_change_scope"]
    scope["change_classes"] = ["CROSS_DOMAIN_INTEGRATION"]
    scope["affected_domains"] = [domain_id]
    scope["affected_owners"] = [component_id]
    scope["focused_tests"] = list(owner["focused_test_ids"])
    scope["why_focused_tests_are_sufficient"] = (
        "The first pending-domain Owner is registered and implemented atomically."
    )
    data.changed_paths = [{"status": "A", "path": component_path}]
    data.gate_changed_paths = copy.deepcopy(data.changed_paths)
    if data.component_declared_classes is not None:
        data.component_declared_classes[component_path] = owner["class_name"]
    data.pr_body = _pr_body(data)
    return data


def _prepare_atomic_replacement(data: gate.ValidationInput) -> dict[str, Any]:
    registry = _registry(data)
    old = registry["component_inventory"][0]
    old["production_reachable"] = False
    old["writes_authority"] = False
    old["reads_authority"] = False
    old["owns_tick"] = False
    old["owns_identity"] = False

    new_id = "component.map.replacement_owner"
    new_path = "scripts/v076/map/replacement_owner.gd"
    new = _component(
        new_id,
        new_path,
        BASE_DOMAIN_ID,
        "OWNER",
        production_reachable=True,
        reuse_disposition="ADOPT_AS_OWNER",
        include_reuse_scan=True,
    )
    new["supersedes"] = [BASE_OWNER_ID]
    old["superseded_by"] = [new_id]
    registry["component_inventory"].append(new)
    registry["unique_owner_domains"][0]["unique_owner"] = new["class_name"]
    registry["unique_owner_domains"][0]["owner_path"] = new_path
    registry["domain_inventory"][0]["owner_component_id"] = new_id
    data.changed_paths.append({"status": "A", "path": new_path})
    if data.component_declared_classes is not None:
        data.component_declared_classes[new_path] = new["class_name"]

    entry = {
        "supersession_id": "selftest.atomic.replacement.one",
        "kind": "REPLACED_IN_V076_CANDIDATE",
        "domain_id": BASE_DOMAIN_ID,
        "old_component_id": BASE_OWNER_ID,
        "new_component_id": new_id,
        "old_owner_path": BASE_OWNER_PATH,
        "new_owner_path": new_path,
        "replacement_reason": "Atomic owner cutover fixture.",
        "migration_strategy": "single_commit_delete_old_reachability",
        "consumer_inventory": ["component.map.consumer"],
        "save_impact": "NONE",
        "rng_impact": "NONE",
        "replay_impact": "NONE",
        "cutover_commit": "c" * 40,
        "old_owner_retirement_status": "RETIRED_BY_CONSTITUTION",
        "dual_write_count": 0,
        "fallback_count": 0,
        "old_owner_production_reachability": 0,
        "new_owner_production_owner_count": 1,
    }
    data.authorities["supersession"]["entries"] = [entry]
    return entry


def _valid_extend_owner(data: gate.ValidationInput) -> None:
    data.changed_paths.append({"status": "M", "path": BASE_OWNER_PATH})


def _valid_consumer(data: gate.ValidationInput) -> None:
    _add_non_owner(data, "consumer", "CONSUMER", production_reachable=True)


def _valid_adapter(data: gate.ValidationInput) -> None:
    adapter = _add_non_owner(data, "historical_adapter", "ADAPTER", production_reachable=True)
    adapter["reuse_source_ids"] = ["reuse.map.existing_owner"]


def _valid_diagnostic(data: gate.ValidationInput) -> None:
    _add_non_owner(data, "diagnostic_bench", "DIAGNOSTIC_BENCH", production_reachable=False)


def _new_owner_without_scan(data: gate.ValidationInput) -> None:
    _add_active_owner(data, "unsearched", include_reuse_scan=False)


def _parallel_owner(data: gate.ValidationInput) -> None:
    component = _component(
        "component.map.parallel_owner",
        "scripts/v076/map/parallel_owner.gd",
        BASE_DOMAIN_ID,
        "OWNER",
        production_reachable=True,
        reuse_disposition="ADOPT_AS_OWNER",
        include_reuse_scan=True,
    )
    component["owns_tick"] = False
    _registry(data)["component_inventory"].append(component)
    data.changed_paths.append({"status": "A", "path": component["path"]})
    if data.component_declared_classes is not None:
        data.component_declared_classes[component["path"]] = component["class_name"]


def _unbound_consumer(data: gate.ValidationInput) -> None:
    _add_non_owner(
        data,
        "unbound_consumer",
        "CONSUMER",
        production_reachable=True,
        owner_component_id="component.missing.owner",
    )


def _unclassified_component(data: gate.ValidationInput) -> None:
    data.changed_paths.append(
        {"status": "A", "path": "scripts/v076/unclassified/runtime_component.gd"}
    )


def _replacement_without_supersession(data: gate.ValidationInput) -> None:
    _prepare_atomic_replacement(data)
    data.authorities["supersession"]["entries"] = []


def _replacement_dual_write(data: gate.ValidationInput) -> None:
    _prepare_atomic_replacement(data)["dual_write_count"] = 1


def _replacement_fallback(data: gate.ValidationInput) -> None:
    _prepare_atomic_replacement(data)["fallback_count"] = 1


def _replacement_old_reachable(data: gate.ValidationInput) -> None:
    _prepare_atomic_replacement(data)["old_owner_production_reachability"] = 1


def _reactivate_retired(data: gate.ValidationInput, reuse_id: str, suffix: str) -> None:
    _registry(data)["reuse_entries"].append(
        {"reuse_id": reuse_id, "disposition": "RETIRED"}
    )
    owner = _add_active_owner(data, suffix)
    owner["reuse_source_ids"] = [reuse_id]


def _generic_retired_reactivation(data: gate.ValidationInput) -> None:
    _reactivate_retired(data, "reuse.retired.runtime", "retired_reactivation")


def _reuse_entry_delete(data: gate.ValidationInput) -> None:
    data.baseline_authorities["historical_reuse"]["reuse_entries"].append(
        {"reuse_id": "reuse.inherited.only", "disposition": "REFERENCE_ONLY"}
    )


def _inherited_green_delete(data: gate.ValidationInput) -> None:
    data.baseline_authorities["inherited_green"]["stages"].append(
        {"stage_id": "stage.2", "ledger_status": "INHERITED_GREEN"}
    )


def _golden_step_delete(data: gate.ValidationInput) -> None:
    data.baseline_authorities["golden"]["steps"].append(
        {
            "step_id": "golden.deleted.step",
            "status": "ISOLATED_GREEN",
            "human_executed": False,
            "production_composition": False,
            "pass_claimed": True,
            "required_surface": "isolated architecture fixture",
        }
    )


def _golden_bool_count_attack(data: gate.ValidationInput) -> None:
    golden = data.authorities["golden"]
    golden["human_execution_count"] = False
    golden["production_pass_count"] = False
    golden["isolated_green_count"] = True
    golden["summary"]["step_count"] = True


def _canonical_status_bool_count_attack(data: gate.ValidationInput) -> None:
    status = data.authorities["inherited_green"]["canonical_pr_status"]
    status["golden_isolated_green_count"] = True
    status["golden_production_green_count"] = False
    status["golden_human_green_count"] = False
    data.pr_body = _pr_body(data)


def _card_aggregate_bool_count_attack(data: gate.ValidationInput) -> None:
    aggregate = data.authorities["card_matrix"]["aggregate"]
    aggregate["category_count"] = True
    aggregate["category_card_count_sum"] = True
    aggregate["alpha07_certified_card_count"] = True


def _supersession_bool_count_attack(data: gate.ValidationInput) -> None:
    entry = _prepare_atomic_replacement(data)
    entry["dual_write_count"] = False
    entry["fallback_count"] = False
    entry["old_owner_production_reachability"] = False
    entry["new_owner_production_owner_count"] = True


def _active_unique_owner_count_attack(data: gate.ValidationInput) -> None:
    owner_row = data.authorities["historical_reuse"]["unique_owner_domains"][0]
    owner_row["binding_status"] = "ACTIVE_SELFTEST"
    owner_row["owner_count"] = True


def _diagnostic_as_human(data: gate.ValidationInput) -> None:
    step = data.authorities["golden"]["steps"][0]
    step.update(
        {
            "status": "HUMAN_GREEN",
            "human_executed": True,
            "production_composition": True,
            "pass_claimed": True,
            "required_surface": "diagnostic bench fixture",
        }
    )


def _card_certification_reset(data: gate.ValidationInput) -> None:
    category = data.authorities["card_matrix"]["category_matrix"][0]
    category["certification"] = {
        field: False for field in gate.CARD_CERTIFICATION_FIELDS
    }
    data.authorities["card_matrix"]["aggregate"]["alpha07_certified_card_count"] = 0


def _tooling_full_reproof(data: gate.ValidationInput) -> None:
    scope = data.authorities["inherited_green"]["canonical_change_scope"]
    scope["full_reproof_required"] = True
    scope["full_reproof_trigger"] = "verified product regression evidence"


def _full_reproof_without_trigger(data: gate.ValidationInput) -> None:
    scope = data.authorities["inherited_green"]["canonical_change_scope"]
    scope["full_reproof_required"] = True
    scope["full_reproof_trigger"] = ""


def _pr_body_missing(data: gate.ValidationInput) -> None:
    data.pr_body = "V0.7.6 Stage 3 description without a canonical status block."


def _pr_body_stale_stage(data: gate.ValidationInput) -> None:
    status = data.authorities["inherited_green"]["canonical_pr_status"]
    status["latest_completed_stage"] = "STAGE_3"
    status["next_stage"] = "STAGE_4"
    data.pr_body = "V0.7.6 Stage 2 remains current.\n\n" + gate.render_status_block(status)


def _production_cutover_false_green(data: gate.ValidationInput) -> None:
    data.authorities["supersession"]["production_cutover"] = True
    status = data.authorities["inherited_green"]["canonical_pr_status"]
    status["production_cutover_status"] = True
    data.pr_body = _pr_body(data)


def _untouched_legacy_debt(_data: gate.ValidationInput) -> None:
    return


def _touched_unclassified_legacy(data: gate.ValidationInput) -> None:
    data.gate_changed_paths.append({"status": "M", "path": LEGACY_DEBT_PATH})


def _normal_stage_inheritance(_data: gate.ValidationInput) -> None:
    return


def _old_base_restart(data: gate.ValidationInput) -> None:
    data.stage_parent_is_descendant = False


def _pr70_runtime_revival(data: gate.ValidationInput) -> None:
    _reactivate_retired(data, "reuse.pr70.runtime_attempt", "pr70_runtime_revival")


def _new_owner_empty_reasons(data: gate.ValidationInput) -> None:
    owner = _add_active_owner(data, "empty_reasons")
    owner["reuse_scan"] = _reuse_scan(reasons_present=False)


def _valid_atomic_replacement(data: gate.ValidationInput) -> None:
    _prepare_atomic_replacement(data)


def _unknown_domain_owner(data: gate.ValidationInput) -> None:
    component = _add_active_owner(data, "unknown_domain")
    component["owns_tick"] = False
    component["owns_rng"] = False
    component["owns_replay"] = False
    component["domain_id"] = "domain.not.registered"
    _registry(data)["domain_inventory"] = [
        row for row in _registry(data)["domain_inventory"]
        if row["domain_id"] != "domain.unknown_domain"
    ]
    _registry(data)["unique_owner_domains"] = [
        row for row in _registry(data)["unique_owner_domains"]
        if row["domain_id"] != "domain.unknown_domain"
    ]


def _delete_component_inventory(data: gate.ValidationInput) -> None:
    _registry(data)["component_inventory"] = []


def _delete_domain_inventory(data: gate.ValidationInput) -> None:
    _registry(data)["domain_inventory"] = []


def _delete_unique_owner_domain(data: gate.ValidationInput) -> None:
    _registry(data)["unique_owner_domains"] = []


def _same_id_identity_replacement(data: gate.ValidationInput) -> None:
    component = _registry(data)["component_inventory"][0]
    old_path = component["path"]
    component["class_name"] = "RenamedExistingOwner"
    component["path"] = "scripts/runtime/renamed_existing_owner.gd"
    component["owner_path"] = component["path"]
    row = _registry(data)["unique_owner_domains"][0]
    row["unique_owner"] = component["class_name"]
    row["owner_path"] = component["path"]
    data.changed_paths.append({"status": "A", "path": component["path"]})
    if data.component_declared_classes is not None:
        data.component_declared_classes.pop(old_path, None)
        data.component_declared_classes[component["path"]] = component["class_name"]


def _unclassified_legacy_product_script(data: gate.ValidationInput) -> None:
    data.changed_paths.append(
        {"status": "A", "path": "scripts/runtime/v076_stage4_market_owner.gd"}
    )


def _invalid_authority_schema_or_id(data: gate.ValidationInput) -> None:
    data.authorities["historical_reuse"]["registry_id"] = "WRONG"
    data.authorities["card_matrix"]["schema_version"] = (
        "space_syndicate.v076.card_certification_matrix.not-a-real-version"
    )


def _invalid_canonical_status(data: gate.ValidationInput) -> None:
    status = data.authorities["inherited_green"]["canonical_pr_status"]
    status["historical_reuse_status"] = "BANANA"
    status["stage_3_status"] = "PENDING"
    data.pr_body = _pr_body(data)


def _human_green_without_evidence(data: gate.ValidationInput) -> None:
    step = data.authorities["golden"]["steps"][0]
    step.update(
        {
            "status": "HUMAN_GREEN",
            "human_executed": True,
            "production_composition": True,
            "pass_claimed": True,
            "required_surface": "production player-facing composition",
        }
    )
    status = data.authorities["inherited_green"]["canonical_pr_status"]
    status["golden_isolated_green_count"] = 0
    status["golden_human_green_count"] = 1
    data.pr_body = _pr_body(data)


def _alpha_without_prerequisites(data: gate.ValidationInput) -> None:
    cert = data.authorities["card_matrix"]["category_matrix"][0]["certification"]
    cert["TARGET_QUERY_GREEN"] = False
    cert["ALPHA07_CERTIFIED"] = True


def _duplicate_kernel_class(data: gate.ValidationInput) -> None:
    component = _add_active_owner(data, "duplicate_kernel")
    base = _registry(data)["component_inventory"][0]
    component["class_name"] = base["class_name"]
    component["owns_tick"] = True
    component["owns_rng"] = True
    component["owns_replay"] = True
    _registry(data)["unique_owner_domains"][-1]["unique_owner"] = component["class_name"]
    if data.component_declared_classes is not None:
        data.component_declared_classes[component["path"]] = component["class_name"]


def _negative_stage3_prose(data: gate.ValidationInput) -> None:
    status = data.authorities["inherited_green"]["canonical_pr_status"]
    data.pr_body = "Stage 3 is not implemented and remains pending.\n\n" + gate.render_status_block(status)


def _irrelevant_focused_tests(data: gate.ValidationInput) -> None:
    data.authorities["inherited_green"]["canonical_change_scope"]["focused_tests"] = [
        "unrelated_test"
    ]


def _nonowner_reuses_retired(data: gate.ValidationInput) -> None:
    reuse_id = "reuse.retired.consumer_source"
    _registry(data)["reuse_entries"].append(
        {"reuse_id": reuse_id, "disposition": "RETIRED"}
    )
    consumer = _add_non_owner(
        data, "retired_consumer", "CONSUMER", production_reachable=True
    )
    consumer["reuse_source_ids"] = [reuse_id]


def _consumer_bound_to_consumer(data: gate.ValidationInput) -> None:
    first = _add_non_owner(data, "consumer_a", "CONSUMER", production_reachable=True)
    second = _add_non_owner(data, "consumer_b", "CONSUMER", production_reachable=True)
    second["owner_component_id"] = first["component_id"]
    second["owner_path"] = first["path"]


def _valid_release_candidate_reproof(data: gate.ValidationInput) -> None:
    scope = data.authorities["inherited_green"]["canonical_change_scope"]
    scope["change_classes"] = ["RELEASE_CANDIDATE"]
    scope["full_reproof_required"] = True
    scope["full_reproof_trigger"] = "Exact release candidate changes production composition."
    scope["affected_owners"] = [BASE_OWNER_ID]
    scope["why_focused_tests_are_insufficient"] = (
        "Release acceptance must prove the exact production composition and all release surfaces."
    )
    scope.pop("why_focused_tests_are_sufficient", None)


def _valid_evidenced_production_cutover(data: gate.ValidationInput) -> None:
    scope = data.authorities["inherited_green"]["canonical_change_scope"]
    scope["change_classes"] = ["PRODUCTION_COMPOSITION"]
    supersession = data.authorities["supersession"]
    supersession["production_cutover"] = True
    supersession["production_cutover_evidence"] = {
        "atomic_cutover": True,
        "candidate_head_sha": "c" * 40,
        "receipt_path": "reports/cutover-receipt.json",
        "receipt_sha256": "e" * 64,
        "production_scene_path": "res://scenes/main.tscn",
        "production_scene_sha256": "a" * 64,
        "affected_owners": [BASE_OWNER_ID],
    }
    data.evidence_artifact_bindings = {
        "scenes/main.tscn": {"present": True, "sha256": "a" * 64},
        "reports/cutover-receipt.json": {
            "present": True,
            "sha256": "e" * 64,
            "json": {
                "schema_version": "space_syndicate.v076.production_cutover_receipt.v1",
                "status": "PASS",
                "candidate_head_sha": "c" * 40,
                "atomic_cutover": True,
                "production_scene_path": "res://scenes/main.tscn",
            },
        },
    }
    status = data.authorities["inherited_green"]["canonical_pr_status"]
    status["production_cutover_status"] = True
    data.pr_body = _pr_body(data)


def _duplicate_status_blocks(data: gate.ValidationInput) -> None:
    data.pr_body += "\n\n" + gate.render_status_block(
        data.authorities["inherited_green"]["canonical_pr_status"]
    )


def _body_false_green_claim(data: gate.ValidationInput) -> None:
    data.pr_body += "\n\nHuman green. Production cutover complete."


def _product_scope_missing_owner(data: gate.ValidationInput) -> None:
    component = _add_non_owner(
        data, "scoped_consumer", "CONSUMER", production_reachable=True
    )
    data.gate_changed_paths.append({"status": "A", "path": component["path"]})
    data.authorities["inherited_green"]["canonical_change_scope"].update(
        {
            "change_classes": ["DOMAIN_CORE"],
            "affected_owners": [],
            "focused_tests": list(component["focused_test_ids"]),
        }
    )


@dataclass(frozen=True)
class Case:
    case_id: str
    description: str
    expected_status: str
    mutate: Callable[[gate.ValidationInput], None]
    expected_failure_prefixes: tuple[str, ...] = ()
    expected_metrics: tuple[tuple[str, Any], ...] = ()


CASES = (
    Case("01", "valid extension of existing owner", "PASS", _valid_extend_owner),
    Case("02", "valid consumer bound to existing owner", "PASS", _valid_consumer),
    Case("03", "valid adapter reuses historical result", "PASS", _valid_adapter),
    Case("04", "valid non-production diagnostic bench", "PASS", _valid_diagnostic),
    Case(
        "05",
        "new owner without reuse scan",
        "FAIL",
        _new_owner_without_scan,
        ("NEW_OWNER_WITHOUT_REUSE_SCAN:",),
        (("NEW_OWNER_WITHOUT_REUSE_SCAN_COUNT", 1),),
    ),
    Case(
        "06",
        "two production owners in one active domain",
        "FAIL",
        _parallel_owner,
        ("ACTIVE_DOMAIN_OWNER_COUNT:",),
        (("PARALLEL_PRODUCTION_OWNER_COUNT", 1),),
    ),
    Case(
        "07",
        "consumer without owner binding",
        "FAIL",
        _unbound_consumer,
        ("NON_OWNER_WITHOUT_OWNER_BINDING:",),
        (("NON_OWNER_WITHOUT_OWNER_BINDING_COUNT", 1),),
    ),
    Case(
        "08",
        "new component missing classification",
        "FAIL",
        _unclassified_component,
        ("UNCLASSIFIED_NEW_COMPONENT:",),
        (("UNCLASSIFIED_NEW_COMPONENT_COUNT", 1),),
    ),
    Case(
        "09",
        "owner replacement without supersession",
        "FAIL",
        _replacement_without_supersession,
        ("OWNER_REPLACEMENT_WITHOUT_SUPERSESSION:",),
    ),
    Case(
        "10",
        "owner replacement retains dual write",
        "FAIL",
        _replacement_dual_write,
        ("OWNER_REPLACEMENT_WITH_DUAL_WRITE",),
        (("DUAL_WRITE_COUNT", 1),),
    ),
    Case(
        "11",
        "owner replacement retains fallback",
        "FAIL",
        _replacement_fallback,
        ("OWNER_REPLACEMENT_WITH_FALLBACK",),
        (("FALLBACK_COUNT", 1),),
    ),
    Case(
        "12",
        "old owner remains production reachable",
        "FAIL",
        _replacement_old_reachable,
        ("OLD_OWNER_STILL_PRODUCTION_REACHABLE",),
        (("OLD_OWNER_STILL_PRODUCTION_REACHABLE_COUNT", 1),),
    ),
    Case(
        "13",
        "retired implementation is reactivated",
        "FAIL",
        _generic_retired_reactivation,
        ("RETIRED_IMPLEMENTATION_REACTIVATED:",),
        (("RETIRED_IMPLEMENTATION_REACTIVATION_COUNT", 1),),
    ),
    Case(
        "14",
        "historical reuse entry is silently deleted",
        "FAIL",
        _reuse_entry_delete,
        ("HISTORICAL_REUSE_ENTRY_SILENT_DELETE:",),
        (("HISTORICAL_REUSE_ENTRY_SILENT_DELETE_COUNT", 1),),
    ),
    Case(
        "15",
        "inherited green stage is silently deleted",
        "FAIL",
        _inherited_green_delete,
        ("INHERITED_GREEN_SILENT_REMOVAL:",),
        (("INHERITED_GREEN_SILENT_REMOVAL_COUNT", 1),),
    ),
    Case(
        "16",
        "golden scenario step is deleted",
        "FAIL",
        _golden_step_delete,
        ("GOLDEN_SCENARIO_STEP_DELETE:",),
        (("GOLDEN_SCENARIO_STEP_DELETE_COUNT", 1),),
    ),
    Case(
        "17",
        "diagnostic fixture impersonates human green",
        "FAIL",
        _diagnostic_as_human,
        ("DIAGNOSTIC_AS_HUMAN_PASS:",),
        (("DIAGNOSTIC_AS_HUMAN_PASS_COUNT", 1),),
    ),
    Case(
        "18",
        "card certification matrix is reset",
        "FAIL",
        _card_certification_reset,
        ("CARD_CERTIFICATION_RESET:", "ALPHA07_CERTIFIED_CARD_COUNT_NOT_MONOTONIC"),
    ),
    Case(
        "19",
        "tooling-only delta demands full reproof",
        "FAIL",
        _tooling_full_reproof,
        ("TOOLING_ONLY_FULL_PRODUCT_REPROOF",),
        (("UNJUSTIFIED_FULL_REPROOF_COUNT", 1),),
    ),
    Case(
        "20",
        "full reproof has no trigger",
        "FAIL",
        _full_reproof_without_trigger,
        ("TOOLING_ONLY_FULL_PRODUCT_REPROOF",),
        (("UNJUSTIFIED_FULL_REPROOF_COUNT", 1),),
    ),
    Case(
        "21",
        "PR body canonical status block is missing",
        "FAIL",
        _pr_body_missing,
        ("STALE_PR_STATUS_BLOCK:MISSING",),
    ),
    Case(
        "22",
        "PR body stage description is stale",
        "FAIL",
        _pr_body_stale_stage,
        ("PR93_DESCRIPTION_STAGE3_STALE",),
    ),
    Case(
        "23",
        "PR body falsely claims production cutover",
        "FAIL",
        _production_cutover_false_green,
        ("PRODUCTION_CUTOVER_EVIDENCE_MISSING",),
    ),
    Case(
        "24",
        "untouched historical debt does not block",
        "PASS",
        _untouched_legacy_debt,
        expected_metrics=(("UNTOUCHED_LEGACY_DEBT_BLOCK_COUNT", 0),),
    ),
    Case(
        "25",
        "touched historical component remains unclassified",
        "FAIL",
        _touched_unclassified_legacy,
        ("TOUCHED_UNCLASSIFIED_LEGACY_COMPONENT:",),
        (("TOUCHED_UNCLASSIFIED_LEGACY_COMPONENT_COUNT", 1),),
    ),
    Case("26", "normal stage inheritance", "PASS", _normal_stage_inheritance),
    Case(
        "27",
        "stage restarts from an old base",
        "FAIL",
        _old_base_restart,
        ("STAGE_PARENT_NOT_PREVIOUS_STAGE_DESCENDANT",),
    ),
    Case(
        "28",
        "retired PR70 runtime attempt is revived",
        "FAIL",
        _pr70_runtime_revival,
        ("RETIRED_IMPLEMENTATION_REACTIVATED:",),
        (("RETIRED_IMPLEMENTATION_REACTIVATION_COUNT", 1),),
    ),
    Case(
        "29",
        "new owner was searched but reasons are empty",
        "FAIL",
        _new_owner_empty_reasons,
        ("OWNER_REUSE_REASON_EMPTY:",),
    ),
    Case("30", "valid atomic owner replacement", "PASS", _valid_atomic_replacement),
    Case(
        "31",
        "production owner references an unknown domain",
        "FAIL",
        _unknown_domain_owner,
        ("COMPONENT_DOMAIN_UNKNOWN:",),
    ),
    Case(
        "32",
        "component inventory row is silently deleted",
        "FAIL",
        _delete_component_inventory,
        ("COMPONENT_INVENTORY_SILENT_DELETE:",),
    ),
    Case(
        "33",
        "domain inventory row is silently deleted",
        "FAIL",
        _delete_domain_inventory,
        ("DOMAIN_INVENTORY_SILENT_DELETE:",),
    ),
    Case(
        "34",
        "unique owner domain row is silently deleted",
        "FAIL",
        _delete_unique_owner_domain,
        ("UNIQUE_OWNER_DOMAIN_SILENT_DELETE:",),
    ),
    Case(
        "35",
        "same component id silently changes class and path",
        "FAIL",
        _same_id_identity_replacement,
        ("COMPONENT_IDENTITY_SILENT_REPLACEMENT:",),
    ),
    Case(
        "36",
        "legacy production script path evades V076-only matching",
        "FAIL",
        _unclassified_legacy_product_script,
        ("UNCLASSIFIED_NEW_COMPONENT:",),
    ),
    Case(
        "37",
        "canonical authority schema or id is wrong",
        "FAIL",
        _invalid_authority_schema_or_id,
        ("AUTHORITY_ID_MISMATCH:", "AUTHORITY_SCHEMA_MISMATCH:"),
    ),
    Case(
        "38",
        "canonical PR status uses invented states",
        "FAIL",
        _invalid_canonical_status,
        ("CANONICAL_STAGE_STATUS_INVALID:", "CANONICAL_HISTORICAL_REUSE_STATUS_INVALID"),
    ),
    Case(
        "39",
        "human green lacks human and production evidence",
        "FAIL",
        _human_green_without_evidence,
        ("GOLDEN_HUMAN_FALSE_GREEN:",),
    ),
    Case(
        "40",
        "Alpha certification is true without prerequisite axes",
        "FAIL",
        _alpha_without_prerequisites,
        ("CARD_CERTIFICATION_PREREQUISITE_MISSING:",),
    ),
    Case(
        "41",
        "second domain reuses the deterministic Kernel class and authority surfaces",
        "FAIL",
        _duplicate_kernel_class,
        ("COMPONENT_CLASS_NAME_NOT_UNIQUE", "GLOBAL_AUTHORITY_SURFACE_PARALLEL_OWNER:"),
    ),
    Case(
        "42",
        "negative Stage 3 prose cannot satisfy the current-status sentence",
        "FAIL",
        _negative_stage3_prose,
        ("PR93_DESCRIPTION_STAGE3_STALE",),
    ),
    Case(
        "43",
        "unrelated focused test list cannot prove the gate delta",
        "FAIL",
        _irrelevant_focused_tests,
        ("TOOLING_FOCUSED_TEST_SET_INCOMPLETE",),
    ),
    Case(
        "44",
        "production consumer reconnects a retired implementation",
        "FAIL",
        _nonowner_reuses_retired,
        ("RETIRED_IMPLEMENTATION_REACTIVATED:",),
    ),
    Case(
        "45",
        "consumer binds another consumer instead of the canonical owner",
        "FAIL",
        _consumer_bound_to_consumer,
        ("NON_OWNER_BOUND_TO_NON_OWNER:",),
    ),
    Case(
        "46",
        "release candidate may request an evidence-scoped full reproof",
        "PASS",
        _valid_release_candidate_reproof,
    ),
    Case(
        "47",
        "production cutover with atomic evidence remains a legal future state",
        "PASS",
        _valid_evidenced_production_cutover,
    ),
    Case(
        "48",
        "multiple canonical PR status blocks are rejected",
        "FAIL",
        _duplicate_status_blocks,
        ("STALE_PR_STATUS_BLOCK:COUNT:",),
    ),
    Case(
        "49",
        "free prose cannot claim human green or cutover beyond canonical status",
        "FAIL",
        _body_false_green_claim,
        ("PR93_DESCRIPTION_FALSE_GREEN:",),
    ),
    Case(
        "50",
        "product delta omits the affected canonical owner",
        "FAIL",
        _product_scope_missing_owner,
        ("PRODUCT_DELTA_AFFECTED_OWNERS_INCOMPLETE",),
    ),
    Case(
        "139",
        "Golden aggregate counts reject bool-as-int substitutions",
        "FAIL",
        _golden_bool_count_attack,
        (
            "GOLDEN_HUMAN_COUNT_TYPE_INVALID",
            "GOLDEN_PRODUCTION_COUNT_TYPE_INVALID",
            "GOLDEN_ISOLATED_COUNT_TYPE_INVALID",
            "GOLDEN_SUMMARY_STEP_COUNT_TYPE_INVALID",
        ),
    ),
    Case(
        "140",
        "canonical status counts reject bool-as-int substitutions",
        "FAIL",
        _canonical_status_bool_count_attack,
        (
            "CANONICAL_STATUS_COUNT_TYPE:golden_isolated_green_count",
            "CANONICAL_STATUS_COUNT_TYPE:golden_production_green_count",
            "CANONICAL_STATUS_COUNT_TYPE:golden_human_green_count",
        ),
    ),
    Case(
        "141",
        "card aggregate counts reject bool-as-int substitutions",
        "FAIL",
        _card_aggregate_bool_count_attack,
        (
            "CARD_CERTIFIED_COUNT_INVALID",
            "CARD_CERTIFICATION_CATEGORY_COUNT_MISMATCH",
            "CARD_CERTIFICATION_CARD_SUM_MISMATCH",
        ),
    ),
    Case(
        "142",
        "supersession counts reject bool-as-int substitutions",
        "FAIL",
        _supersession_bool_count_attack,
        (
            "SUPERSESSION_INTEGER_FIELD:component.map.replacement_owner:dual_write_count",
            "SUPERSESSION_INTEGER_FIELD:component.map.replacement_owner:fallback_count",
            "SUPERSESSION_INTEGER_FIELD:component.map.replacement_owner:old_owner_production_reachability",
            "SUPERSESSION_INTEGER_FIELD:component.map.replacement_owner:new_owner_production_owner_count",
        ),
    ),
    Case(
        "143",
        "active unique-owner cardinality rejects bool-as-int substitution",
        "FAIL",
        _active_unique_owner_count_attack,
        (
            f"UNIQUE_OWNER_COUNT_TYPE_INVALID:{BASE_DOMAIN_ID}",
        ),
    ),
)


def _matches_prefix(failures: list[str], prefix: str) -> bool:
    return any(failure.startswith(prefix) for failure in failures)


def run_selftest() -> dict[str, Any]:
    results: list[dict[str, Any]] = []
    false_green_count = 0
    valid_false_reject_count = 0

    for case in CASES:
        data = _valid_input()
        case.mutate(data)
        report = gate.validate_model(data)
        observed_status = str(report.get("status", "FAIL"))
        failures = [str(value) for value in report.get("failures", [])]
        metrics = report.get("metrics", {})

        missing_failure_prefixes = [
            prefix
            for prefix in case.expected_failure_prefixes
            if not _matches_prefix(failures, prefix)
        ]
        metric_mismatches = [
            {
                "metric": key,
                "expected": expected,
                "observed": metrics.get(key),
            }
            for key, expected in case.expected_metrics
            if metrics.get(key) != expected
        ]
        passed = (
            observed_status == case.expected_status
            and not missing_failure_prefixes
            and not metric_mismatches
        )
        if case.expected_status == "FAIL" and observed_status == "PASS":
            false_green_count += 1
        if case.expected_status == "PASS" and observed_status != "PASS":
            valid_false_reject_count += 1

        results.append(
            {
                "case_id": case.case_id,
                "description": case.description,
                "expected_status": case.expected_status,
                "observed_status": observed_status,
                "status": "PASS" if passed else "FAIL",
                "missing_failure_prefixes": missing_failure_prefixes,
                "metric_mismatches": metric_mismatches,
                "observed_failures": failures,
            }
        )

    expected_head = "a" * 40
    ratchet_cases = (
        (
            "51",
            "merge ratchet accepts one completed success on the expected head",
            "PASS",
            [
                {
                    "name": gate.CHECK_NAME,
                    "status": "completed",
                    "conclusion": "success",
                    "head_sha": expected_head,
                }
            ],
        ),
        (
            "52",
            "merge ratchet rejects duplicate exact-name checks",
            "FAIL",
            [
                {
                    "name": gate.CHECK_NAME,
                    "status": "completed",
                    "conclusion": "success",
                    "head_sha": expected_head,
                },
                {
                    "name": gate.CHECK_NAME,
                    "status": "queued",
                    "conclusion": None,
                    "head_sha": expected_head,
                },
            ],
        ),
        (
            "53",
            "merge ratchet rejects a success from a stale head",
            "FAIL",
            [
                {
                    "name": gate.CHECK_NAME,
                    "status": "completed",
                    "conclusion": "success",
                    "head_sha": "b" * 40,
                }
            ],
        ),
        (
            "54",
            "merge ratchet accepts duplicate completed successes on the expected head",
            "PASS",
            [
                {
                    "name": gate.CHECK_NAME,
                    "status": "completed",
                    "conclusion": "success",
                    "head_sha": expected_head,
                },
                {
                    "name": gate.CHECK_NAME,
                    "status": "completed",
                    "conclusion": "success",
                    "head_sha": expected_head,
                },
            ],
        ),
        (
            "55",
            "merge ratchet uses the latest identified current-head run",
            "PASS",
            [
                {
                    "id": 100,
                    "name": gate.CHECK_NAME,
                    "status": "completed",
                    "conclusion": "failure",
                    "head_sha": expected_head,
                },
                {
                    "id": 101,
                    "name": gate.CHECK_NAME,
                    "status": "completed",
                    "conclusion": "success",
                    "head_sha": expected_head,
                },
            ],
        ),
        (
            "56",
            "merge ratchet rejects a newer pending current-head run",
            "FAIL",
            [
                {
                    "id": 100,
                    "name": gate.CHECK_NAME,
                    "status": "completed",
                    "conclusion": "success",
                    "head_sha": expected_head,
                },
                {
                    "id": 101,
                    "name": gate.CHECK_NAME,
                    "status": "in_progress",
                    "conclusion": None,
                    "head_sha": expected_head,
                },
            ],
        ),
    )
    with tempfile.TemporaryDirectory(prefix="v076-gate-selftest-") as temp_dir:
        checks_path = Path(temp_dir) / "checks.json"
        for case_id, description, expected_status, rows in ratchet_cases:
            checks_path.write_text(
                json.dumps({"check_runs": rows}, ensure_ascii=False), encoding="utf-8"
            )
            ratchet = gate.merge_ratchet(checks_path, expected_head)
            observed_status = str(ratchet.get("status", "FAIL"))
            passed = observed_status == expected_status
            if expected_status == "FAIL" and observed_status == "PASS":
                false_green_count += 1
            if expected_status == "PASS" and observed_status != "PASS":
                valid_false_reject_count += 1
            results.append(
                {
                    "case_id": case_id,
                    "description": description,
                    "expected_status": expected_status,
                    "observed_status": observed_status,
                    "status": "PASS" if passed else "FAIL",
                    "missing_failure_prefixes": [],
                    "metric_mismatches": [],
                    "observed_failures": [] if passed else ["MERGE_RATCHET_MISMATCH"],
                }
            )

    def append_direct_case(
        case_id: str,
        description: str,
        expected_status: str,
        observed_status: str,
        observed_failures: list[str],
    ) -> None:
        nonlocal false_green_count, valid_false_reject_count
        passed = observed_status == expected_status
        if expected_status == "FAIL" and observed_status == "PASS":
            false_green_count += 1
        if expected_status == "PASS" and observed_status != "PASS":
            valid_false_reject_count += 1
        results.append(
            {
                "case_id": case_id,
                "description": description,
                "expected_status": expected_status,
                "observed_status": observed_status,
                "status": "PASS" if passed else "FAIL",
                "missing_failure_prefixes": [],
                "metric_mismatches": [],
                "observed_failures": observed_failures,
            }
        )

    previous = _authorities()
    regressed = copy.deepcopy(previous)
    regressed_cert = regressed["card_matrix"]["category_matrix"][0]["certification"]
    regressed_cert["ALPHA07_CERTIFIED"] = False
    regressed["card_matrix"]["aggregate"]["alpha07_certified_card_count"] = 0
    history_failures = gate._monotonic_transition_failures(
        previous, regressed, "selftest-history"
    )
    history_rejected = any(
        failure.startswith("CARD_CERTIFICATION_RESET:selftest-history:")
        for failure in history_failures
    )
    append_direct_case(
        "57",
        "activation-root history walk rejects an intermediate green reset",
        "FAIL",
        "FAIL" if history_rejected else "PASS",
        history_failures,
    )

    stable_history_failures = gate._monotonic_transition_failures(
        previous, copy.deepcopy(previous), "selftest-stable-history"
    )
    append_direct_case(
        "58",
        "activation-root history walk accepts a stable monotonic transition",
        "PASS",
        "PASS" if not stable_history_failures else "FAIL",
        stable_history_failures,
    )

    with tempfile.TemporaryDirectory(prefix="v076-retired-scanner-contract-") as temp_dir:
        temp_root = Path(temp_dir)
        scanner_path = temp_root / "tools" / "rules" / "check_v06_mechanic_authority.py"
        scanner_path.parent.mkdir(parents=True)
        scanner_path.write_text(
            """import json, sys
if '--self-test' in sys.argv:
    print(json.dumps({'status':'PASS','case_count':1,'failures':[]})); raise SystemExit(0)
print(json.dumps({'status':'FAIL','production_hits':[{'path':'untouched.gd'}],'source_splitting_hits':[]})); raise SystemExit(1)
""",
            encoding="utf-8",
        )
        scanner_status, scanner_report = gate.run_retired_scanner(temp_root, set())
        append_direct_case(
            "59",
            "valid inherited scanner debt remains grandfathered for an empty Delta",
            "PASS",
            scanner_status,
            [] if scanner_status == "PASS" else [str(scanner_report)],
        )
        scanner_path.write_text(
            """import json, sys
if '--self-test' in sys.argv:
    print(json.dumps({'status':'PASS','case_count':1,'failures':[]})); raise SystemExit(0)
print('not-json'); raise SystemExit(2)
""",
            encoding="utf-8",
        )
        scanner_status, scanner_report = gate.run_retired_scanner(temp_root, set())
        append_direct_case(
            "60",
            "non-JSON or invalid retired-scanner summary fails closed",
            "FAIL",
            scanner_status,
            [] if scanner_status == "FAIL" else [str(scanner_report)],
        )

    project_root = SCRIPT_DIR.parents[1]
    v076_workflow = (
        project_root / ".github" / "workflows" / "v076-reuse-point-inertia-gate.yml"
    ).read_text(encoding="utf-8-sig")
    v075_workflow = (
        project_root / ".github" / "workflows" / "v075-pr90-acceptance.yml"
    ).read_text(encoding="utf-8-sig")
    workflow_invariants = bool(
        f'$gateBase = "{gate.V076_GATE_BASE_SHA}"' in v076_workflow
        and "HEAD^" not in v076_workflow
        and "external_activation_boundary" in v076_workflow
        and "point_inertia_baseline_sha" in v076_workflow
        and "previous Head lacks a completed successful V075 acceptance" in v075_workflow
        and "actions/workflows/v075-pr90-acceptance.yml/runs" in v075_workflow
    )
    append_direct_case(
        "61",
        "CI binds immutable Gate history and inherits product skips only from a green Head",
        "PASS",
        "PASS" if workflow_invariants else "FAIL",
        [] if workflow_invariants else ["WORKFLOW_EXTERNAL_INVARIANT_MISSING"],
    )

    def install_golden_evidence(data: gate.ValidationInput, *, human: bool) -> None:
        subject_sha = data.authorities["historical_reuse"]["candidate_head_sha"]
        step = data.authorities["golden"]["steps"][0]
        step_id = step["step_id"]
        scene_path = "res://scenes/main.tscn"
        scene_bytes = b"[gd_scene format=3]\n"
        scene_sha = hashlib.sha256(scene_bytes).hexdigest()
        production_receipt = {
            "schema_version": "space_syndicate.v076.golden_production_execution_receipt.v1",
            "evidence_type": "V076_GOLDEN_PRODUCTION_EXECUTION",
            "candidate_head_sha": subject_sha,
            "step_id": step_id,
            "status": "PASS",
            "execution_mode": "PRODUCTION_COMPOSITION",
            "diagnostic_only": False,
            "fixture_only": False,
            "production_scene_path": scene_path,
            "pass_count": 1,
        }
        production_bytes = json.dumps(
            production_receipt, sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
        production_sha = hashlib.sha256(production_bytes).hexdigest()
        production_path = "reports/v076/golden-production.json"
        step.update(
            {
                "status": "HUMAN_GREEN" if human else "PRODUCTION_GREEN",
                "human_executed": human,
                "production_composition": True,
                "pass_claimed": True,
                "required_surface": "production main composition",
                "production_evidence": {
                    "evidence_type": "V076_GOLDEN_PRODUCTION_EXECUTION",
                    "candidate_head_sha": subject_sha,
                    "receipt_path": production_path,
                    "receipt_sha256": production_sha,
                    "production_scene_path": scene_path,
                    "production_scene_sha256": scene_sha,
                    "pass_count": 1,
                },
            }
        )
        data.evidence_artifact_bindings = {
            "scenes/main.tscn": {
                "present": True,
                "sha256": scene_sha,
                "json": None,
            },
            production_path: {
                "present": True,
                "sha256": production_sha,
                "json": production_receipt,
            },
        }
        status = data.authorities["inherited_green"]["canonical_pr_status"]
        status["golden_isolated_green_count"] = 0
        status["golden_production_green_count"] = 0 if human else 1
        status["golden_human_green_count"] = 1 if human else 0
        golden = data.authorities["golden"]
        golden["isolated_green_count"] = 0
        golden["production_pass_count"] = 1
        golden["human_execution_count"] = 1 if human else 0
        golden["summary"] = {
            "step_count": 1,
            "isolated_green_step_ids": [],
            "pending_step_ids": [],
            "human_pass_step_ids": [step_id] if human else [],
            "production_pass_step_ids": [step_id],
        }
        if human:
            human_receipt = {
                "schema_version": "space_syndicate.v076.golden_human_execution_receipt.v1",
                "evidence_type": "V076_GOLDEN_HUMAN_EXECUTION",
                "evidence_source_type": "HUMAN_EXECUTED",
                "candidate_head_sha": subject_sha,
                "step_id": step_id,
                "status": "PASS",
                "human_executed": True,
                "production_composition": True,
                "observer_kind": "HUMAN",
                "observer": "human-reviewer-01",
                "evidence_id": "human-session-01",
                "production_receipt_sha256": production_sha,
            }
            human_bytes = json.dumps(
                human_receipt, sort_keys=True, separators=(",", ":")
            ).encode("utf-8")
            human_sha = hashlib.sha256(human_bytes).hexdigest()
            human_path = "reports/v076/golden-human.json"
            step["human_evidence"] = {
                "evidence_type": "V076_GOLDEN_HUMAN_EXECUTION",
                "evidence_source_type": "HUMAN_EXECUTED",
                "observer_kind": "HUMAN",
                "human_confirmed": True,
                "candidate_head_sha": subject_sha,
                "evidence_id": "human-session-01",
                "observer": "human-reviewer-01",
                "receipt_path": human_path,
                "receipt_sha256": human_sha,
            }
            data.evidence_artifact_bindings[human_path] = {
                "present": True,
                "sha256": human_sha,
                "json": human_receipt,
            }
        data.pr_body = _pr_body(data)

    fake_human = _valid_input()
    install_golden_evidence(fake_human, human=True)
    fake_step = fake_human.authorities["golden"]["steps"][0]
    fake_step["production_evidence"]["candidate_head_sha"] = "a" * 40
    fake_step["production_evidence"]["production_scene_path"] = "res://scenes/fake_main.tscn"
    fake_step["human_evidence"]["observer"] = "automation-bot"
    fake_human.evidence_artifact_bindings = {}
    fake_report = gate.validate_model(fake_human)
    append_direct_case(
        "62",
        "self-asserted Golden human evidence cannot impersonate bound production artifacts",
        "FAIL",
        str(fake_report["status"]),
        [str(value) for value in fake_report.get("failures", [])],
    )

    valid_production = _valid_input()
    install_golden_evidence(valid_production, human=False)
    production_report = gate.validate_model(valid_production)
    append_direct_case(
        "63",
        "cryptographically bound production Golden evidence is a legal future state",
        "PASS",
        str(production_report["status"]),
        [str(value) for value in production_report.get("failures", [])],
    )

    valid_human = _valid_input()
    install_golden_evidence(valid_human, human=True)
    human_report = gate.validate_model(valid_human)
    append_direct_case(
        "64",
        "typed human-executed evidence bound to production receipts is legal",
        "PASS",
        str(human_report["status"]),
        [str(value) for value in human_report.get("failures", [])],
    )

    def regression(prior_status: str, suffix: str) -> dict[str, str]:
        return {
            "failure_evidence": f"failure-{suffix}",
            "origin_commit": "c" * 40,
            "promotion_metadata_commit": "e" * 40,
            "affected_commit": "d" * 40,
            "affected_owner": BASE_OWNER_ID,
            "repair_plan": f"repair-{suffix}",
            "prior_status": prior_status,
        }

    marked = copy.deepcopy(previous)
    marked_stage = marked["inherited_green"]["stages"][2]
    marked_stage["ledger_status"] = "REGRESSED_WITH_EVIDENCE"
    marked_stage["regression"] = regression("CURRENT_DELTA_GREEN", "stage")
    marked_step = marked["golden"]["steps"][0]
    marked_step["status"] = "REGRESSED_WITH_EVIDENCE"
    marked_step["regression"] = regression("ISOLATED_GREEN", "golden")
    marked_category = marked["card_matrix"]["category_matrix"][0]
    marked_category["certification"]["RECEIPT_GREEN"] = "REGRESSED_WITH_EVIDENCE"
    marked_category["regression"] = regression("CERTIFIED_TRUE", "card")
    marker_failures = gate._monotonic_transition_failures(
        previous, marked, "selftest-regression-marker"
    )
    washed = copy.deepcopy(marked)
    washed["inherited_green"]["stages"][2]["ledger_status"] = "PENDING"
    washed["inherited_green"]["stages"][2].pop("regression", None)
    washed["golden"]["steps"][0]["status"] = "PENDING"
    washed["golden"]["steps"][0].pop("regression", None)
    washed["card_matrix"]["category_matrix"][0]["certification"]["RECEIPT_GREEN"] = False
    washed["card_matrix"]["category_matrix"][0].pop("regression", None)
    wash_failures = gate._monotonic_transition_failures(
        marked, washed, "selftest-regression-wash"
    )
    sticky_rejected = bool(
        not marker_failures
        and any("REGRESSION_NOT_STICKY" in failure for failure in wash_failures)
    )
    append_direct_case(
        "65",
        "regression evidence is sticky and cannot be washed through a second commit",
        "FAIL",
        "FAIL" if sticky_rejected else "PASS",
        marker_failures + wash_failures,
    )
    retained_failures = gate._monotonic_transition_failures(
        marked, copy.deepcopy(marked), "selftest-regression-retained"
    )
    append_direct_case(
        "66",
        "a complete unchanged regression marker remains a legal retained record",
        "PASS",
        "PASS" if not retained_failures else "FAIL",
        retained_failures,
    )

    retired_previous = copy.deepcopy(previous)
    retired_previous["historical_reuse"]["reuse_entries"].append(
        {"reuse_id": "reuse.retired.sticky", "disposition": "RETIRED"}
    )
    retired_reactivated = copy.deepcopy(retired_previous)
    retired_reactivated["historical_reuse"]["reuse_entries"][-1]["disposition"] = (
        "ADAPT_AS_CONSUMER"
    )
    retired_failures = gate._monotonic_transition_failures(
        retired_previous, retired_reactivated, "selftest-retired-sticky"
    )
    append_direct_case(
        "67",
        "a RETIRED reuse disposition cannot be reactivated by rewriting the row",
        "FAIL",
        "FAIL" if any("RETIRED_REUSE_DISPOSITION_REACTIVATED" in value for value in retired_failures) else "PASS",
        retired_failures,
    )

    domain_retired = copy.deepcopy(previous)
    domain_retired["historical_reuse"]["domain_inventory"][0]["lifecycle"] = "RETIRED_DOMAIN"
    domain_failures = gate._monotonic_transition_failures(
        previous, domain_retired, "selftest-domain-retirement"
    )
    append_direct_case(
        "68",
        "an active domain cannot silently retire without explicit evidence",
        "FAIL",
        "FAIL" if any("ACTIVE_DOMAIN_LIFECYCLE_SILENT_DOWNGRADE" in value for value in domain_failures) else "PASS",
        domain_failures,
    )

    owner_cleared = copy.deepcopy(previous)
    owner_cleared["historical_reuse"]["component_inventory"][0]["writes_authority"] = False
    owner_failures = gate._monotonic_transition_failures(
        previous, owner_cleared, "selftest-owner-surface"
    )
    append_direct_case(
        "69",
        "an existing owner authority surface cannot silently turn off",
        "FAIL",
        "FAIL" if any("COMPONENT_AUTHORITY_SURFACE_SILENT_DOWNGRADE" in value for value in owner_failures) else "PASS",
        owner_failures,
    )

    identity_drift = _valid_input()
    identity_drift.authorities["golden"]["candidate_head_sha"] = "a" * 40
    identity_report = gate.validate_model(identity_drift)
    append_direct_case(
        "70",
        "Golden and ledger evidence subjects must match the canonical candidate SHA",
        "FAIL",
        str(identity_report["status"]),
        [str(value) for value in identity_report.get("failures", [])],
    )

    summary_drift = _valid_input()
    summary_drift.authorities["golden"]["summary"]["isolated_green_step_ids"] = []
    summary_report = gate.validate_model(summary_drift)
    append_direct_case(
        "71",
        "Golden aggregate and step inventories cannot contradict their rows",
        "FAIL",
        str(summary_report["status"]),
        [str(value) for value in summary_report.get("failures", [])],
    )

    valid_retirement = _valid_input()
    retired_domain = valid_retirement.authorities["historical_reuse"]["domain_inventory"][0]
    retired_domain["lifecycle"] = "RETIRED_DOMAIN"
    retired_domain["retirement_evidence"] = {
        "prior_lifecycle": "ACTIVE_CURRENT_DOMAIN",
        "authorized_change_class": "RULESET_CONSTITUTION",
        "affected_commit": "d" * 40,
        "affected_owner": BASE_OWNER_ID,
        "retirement_reason": "The constitution explicitly retires this domain.",
        "retirement_plan": "Retain the historical Owner row but remove all production reachability.",
    }
    retired_owner = valid_retirement.authorities["historical_reuse"]["component_inventory"][0]
    for field in gate.COMPONENT_AUTHORITY_INERTIA_FIELDS:
        retired_owner[field] = False
    valid_retirement.component_presence = {BASE_OWNER_PATH: False}
    retirement_report = gate.validate_model(valid_retirement)
    retirement_history = gate._monotonic_transition_failures(
        valid_retirement.baseline_authorities,
        valid_retirement.authorities,
        "selftest-evidenced-domain-retirement",
    )
    append_direct_case(
        "72",
        "an explicit constitution-backed domain retirement remains a legal future state",
        "PASS",
        "PASS" if retirement_report["status"] == "PASS" and not retirement_history else "FAIL",
        [str(value) for value in retirement_report.get("failures", [])] + retirement_history,
    )

    minimal_supersession = _valid_input()
    entry = _prepare_atomic_replacement(minimal_supersession)
    minimal_supersession.authorities["supersession"]["entries"] = [
        {
            "domain_id": entry["domain_id"],
            "old_component_id": entry["old_component_id"],
            "new_component_id": entry["new_component_id"],
        }
    ]
    minimal_report = gate.validate_model(minimal_supersession)
    append_direct_case(
        "73",
        "a three-field supersession row cannot authorize an owner replacement",
        "FAIL",
        str(minimal_report["status"]),
        [str(value) for value in minimal_report.get("failures", [])],
    )

    sequential = _valid_input()
    first_entry = _prepare_atomic_replacement(sequential)
    registry = sequential.authorities["historical_reuse"]
    intermediate = registry["component_inventory"][-1]
    for field in gate.COMPONENT_AUTHORITY_INERTIA_FIELDS:
        intermediate[field] = False
    final_id = "component.map.final_owner"
    final_path = "scripts/v076/map/final_owner.gd"
    final_owner = _component(
        final_id,
        final_path,
        BASE_DOMAIN_ID,
        "OWNER",
        production_reachable=True,
        reuse_disposition="ADOPT_AS_OWNER",
        include_reuse_scan=True,
    )
    final_owner["supersedes"] = [intermediate["component_id"]]
    intermediate["superseded_by"] = [final_id]
    registry["component_inventory"].append(final_owner)
    registry["domain_inventory"][0]["owner_component_id"] = final_id
    registry["unique_owner_domains"][0]["unique_owner"] = final_owner["class_name"]
    registry["unique_owner_domains"][0]["owner_path"] = final_path
    second_entry = copy.deepcopy(first_entry)
    second_entry.update(
        {
            "supersession_id": "selftest.atomic.replacement.two",
            "old_component_id": intermediate["component_id"],
            "new_component_id": final_id,
            "old_owner_path": intermediate["path"],
            "new_owner_path": final_path,
            "replacement_reason": "Second atomic owner cutover fixture.",
            "cutover_commit": "c" * 40,
        }
    )
    sequential.authorities["supersession"]["entries"] = [first_entry, second_entry]
    sequential.changed_paths.append({"status": "A", "path": final_path})
    if sequential.component_declared_classes is not None:
        sequential.component_declared_classes[final_path] = final_owner["class_name"]
    sequential_report = gate.validate_model(sequential)
    append_direct_case(
        "74",
        "a retained A-to-B-to-C supersession chain is a legal sequential replacement",
        "PASS",
        str(sequential_report["status"]),
        [str(value) for value in sequential_report.get("failures", [])],
    )

    unknown_status = copy.deepcopy(previous)
    unknown_status["golden"]["steps"][0]["status"] = "INVENTED_GREEN"
    unknown_failures = gate._monotonic_transition_failures(
        previous, unknown_status, "selftest-unknown-golden"
    )
    append_direct_case(
        "75",
        "an unknown Golden state cannot bridge two otherwise valid commits",
        "FAIL",
        "FAIL" if any("GOLDEN_SCENARIO_STATUS_INVALID" in value for value in unknown_failures) else "PASS",
        unknown_failures,
    )

    bot_human = _valid_input()
    install_golden_evidence(bot_human, human=True)
    bot_step = bot_human.authorities["golden"]["steps"][0]
    bot_evidence = bot_step["human_evidence"]
    old_human_path = bot_evidence["receipt_path"]
    bot_receipt = copy.deepcopy(bot_human.evidence_artifact_bindings[old_human_path]["json"])
    bot_receipt["observer"] = "bot"
    bot_bytes = json.dumps(bot_receipt, sort_keys=True, separators=(",", ":")).encode("utf-8")
    bot_sha = hashlib.sha256(bot_bytes).hexdigest()
    bot_evidence["observer"] = "bot"
    bot_evidence["receipt_sha256"] = bot_sha
    bot_human.evidence_artifact_bindings[old_human_path] = {
        "present": True,
        "sha256": bot_sha,
        "json": bot_receipt,
    }
    bot_report = gate.validate_model(bot_human)
    append_direct_case(
        "76",
        "a bot observer cannot satisfy typed HUMAN_EXECUTED evidence",
        "FAIL",
        str(bot_report["status"]),
        [str(value) for value in bot_report.get("failures", [])],
    )

    diagnostic_production = _valid_input()
    install_golden_evidence(diagnostic_production, human=False)
    diagnostic_production.authorities["golden"]["steps"][0]["required_surface"] = (
        "diagnostic bench scripted fixture"
    )
    diagnostic_report = gate.validate_model(diagnostic_production)
    append_direct_case(
        "77",
        "a diagnostic surface cannot impersonate production Golden evidence",
        "FAIL",
        str(diagnostic_report["status"]),
        [str(value) for value in diagnostic_report.get("failures", [])],
    )

    wrong_tree = _valid_input()
    wrong_tree.git_commit_tree_bindings = {"c" * 40: "a" * 40}
    wrong_tree_report = gate.validate_model(wrong_tree)
    append_direct_case(
        "78",
        "the evidence subject commit must bind the declared Git tree",
        "FAIL",
        str(wrong_tree_report["status"]),
        [str(value) for value in wrong_tree_report.get("failures", [])],
    )

    reactivated_domain = copy.deepcopy(valid_retirement.authorities)
    reactivation_failures = gate._monotonic_transition_failures(
        valid_retirement.authorities,
        previous,
        "selftest-retired-domain-reactivation",
    )
    append_direct_case(
        "79",
        "a retired domain cannot be reactivated in a later commit",
        "FAIL",
        "FAIL" if any("RETIRED_DOMAIN_REACTIVATED" in value for value in reactivation_failures) else "PASS",
        reactivation_failures,
    )

    production_root_paths = [
        "shaders/v076_stage4_owner.gdshader",
        "themes/GameTheme.tres",
        "project.godot",
        "addons/funplay_mcp/runtime/stage4_runtime_owner.gd",
        "addons/unknown_runtime/stage4_runtime_owner.gd",
        "assets/v076/new_surface.tres",
        "localization/v076_stage4.po",
        "export_presets.cfg",
    ]
    production_root_reports: list[dict[str, Any]] = []
    for production_path in production_root_paths:
        candidate = _valid_input()
        candidate.changed_paths = [{"status": "A", "path": production_path}]
        candidate.gate_changed_paths = [{"status": "A", "path": production_path}]
        production_root_reports.append(gate.validate_model(candidate))
    production_roots_rejected = bool(
        all(gate._is_product_component_path(path) for path in production_root_paths)
        and all(report["status"] == "FAIL" for report in production_root_reports)
        and all(
            any(
                failure.startswith("UNCLASSIFIED_NEW_COMPONENT:")
                or failure == "PRODUCT_DELTA_COMPONENT_CLASSIFICATION_INCOMPLETE"
                for failure in report.get("failures", [])
            )
            for report in production_root_reports
        )
    )
    append_direct_case(
        "80",
        "every Godot-loadable production root fails closed when its component is unregistered",
        "FAIL",
        "FAIL" if production_roots_rejected else "PASS",
        sorted(
            {
                str(failure)
                for report in production_root_reports
                for failure in report.get("failures", [])
            }
        ),
    )

    rule_authority_paths = [
        "docs/tabletop_rulebook_v06.md",
        "docs/rules_v06_runtime_directive.md",
        "README.md",
        "docs/rules/v076_stage4.md",
        "resources/rules/v076_stage4.tres",
        "data/cards/v076_stage4.json",
        "resources/cards/runtime/v076_stage4.tres",
    ]
    rule_reports: list[dict[str, Any]] = []
    for rule_path in rule_authority_paths:
        candidate = _valid_input()
        candidate.gate_changed_paths = [{"status": "M", "path": rule_path}]
        rule_reports.append(gate.validate_model(candidate))
    rules_rejected = bool(
        all(gate._is_rule_authority_path(path) for path in rule_authority_paths)
        and all(report["status"] == "FAIL" for report in rule_reports)
        and all(
            any(
                failure.startswith("TOOLING_GATE_PRODUCT_RULE_CHANGE:")
                for failure in report.get("failures", [])
            )
            for report in rule_reports
        )
    )
    append_direct_case(
        "81",
        "current production rule authorities cannot pass under a tooling or docs-only declaration",
        "FAIL",
        "FAIL" if rules_rejected else "PASS",
        sorted(
            {
                str(failure)
                for report in rule_reports
                for failure in report.get("failures", [])
            }
        ),
    )

    staged_path = "scripts/v076/stage4_history/runtime_owner.gd"
    intermediate = copy.deepcopy(previous)
    intermediate_failures = gate._monotonic_transition_failures(
        previous,
        intermediate,
        "selftest-code-before-registry",
        [{"status": "A", "path": staged_path}],
    )
    registered = _valid_input()
    registered_owner = _add_active_owner(registered, "stage4_history")
    registered_owner["owns_tick"] = False
    registered_scope = registered.authorities["inherited_green"]["canonical_change_scope"]
    registered_scope["change_classes"] = ["DOMAIN_CORE"]
    registered_scope["affected_domains"] = [registered_owner["domain_id"]]
    registered_scope["affected_owners"] = [registered_owner["component_id"]]
    registered_scope["focused_tests"] = list(registered_owner["focused_test_ids"])
    registered.gate_changed_paths = [{"status": "A", "path": staged_path}]
    registered.pr_body = _pr_body(registered)
    registered_report = gate.validate_model(registered)
    staged_history_rejected = bool(
        any(
            failure.startswith("HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:")
            for failure in intermediate_failures
        )
        and registered_report["status"] == "PASS"
    )
    append_direct_case(
        "82",
        "an unregistered product commit remains a history failure even if the next commit registers it",
        "FAIL",
        "FAIL" if staged_history_rejected else "PASS",
        intermediate_failures
        + [str(value) for value in registered_report.get("failures", [])],
    )

    replacement = _valid_input()
    _prepare_atomic_replacement(replacement)
    erased = copy.deepcopy(replacement.authorities)
    erased["supersession"]["entries"] = []
    erased["historical_reuse"]["component_inventory"][0]["superseded_by"] = []
    erased["historical_reuse"]["component_inventory"][-1]["supersedes"] = []
    erased_failures = gate._monotonic_transition_failures(
        replacement.authorities,
        erased,
        "selftest-supersession-history-erasure",
    )
    append_direct_case(
        "83",
        "supersession entries and reciprocal links are append-only history",
        "FAIL",
        "FAIL"
        if any(
            "SUPERSESSION_ENTRY_SILENT_DELETE" in failure
            or "COMPONENT_SUPERSESSION_LINK_SHRANK" in failure
            for failure in erased_failures
        )
        else "PASS",
        erased_failures,
    )

    cycled = copy.deepcopy(replacement)
    forward = cycled.authorities["supersession"]["entries"][0]
    reverse = copy.deepcopy(forward)
    reverse.update(
        {
            "supersession_id": "selftest.atomic.replacement.reverse-cycle",
            "old_component_id": forward["new_component_id"],
            "new_component_id": forward["old_component_id"],
            "old_owner_path": forward["new_owner_path"],
            "new_owner_path": forward["old_owner_path"],
            "replacement_reason": "Invalid reverse owner cycle fixture.",
        }
    )
    cycled.authorities["supersession"]["entries"].append(reverse)
    cycle_report = gate.validate_model(cycled)
    append_direct_case(
        "84",
        "an owner supersession graph cannot cycle back to a retired owner",
        "FAIL",
        str(cycle_report["status"]),
        [str(value) for value in cycle_report.get("failures", [])],
    )

    empty_consumer_replacement = _valid_input()
    empty_consumer_entry = _prepare_atomic_replacement(empty_consumer_replacement)
    empty_consumer_entry["consumer_inventory"] = []
    empty_consumer_report = gate.validate_model(empty_consumer_replacement)
    append_direct_case(
        "85",
        "an unused Owner may be atomically replaced with an explicit empty consumer inventory",
        "PASS",
        str(empty_consumer_report["status"]),
        [str(value) for value in empty_consumer_report.get("failures", [])],
    )

    unknown_stage = _valid_input()
    unknown_stage.authorities["inherited_green"]["stages"].append(
        {"stage_id": "V076_STAGE_4_UNKNOWN", "ledger_status": "BANANA"}
    )
    unknown_stage_report = gate.validate_model(unknown_stage)
    append_direct_case(
        "86",
        "every future Stage ledger row must use a canonical point-inertia state",
        "FAIL",
        str(unknown_stage_report["status"]),
        [str(value) for value in unknown_stage_report.get("failures", [])],
    )

    card_regression = _valid_input()
    card_row = card_regression.authorities["card_matrix"]["category_matrix"][0]
    card_row["certification"]["ALPHA07_CERTIFIED"] = "REGRESSED_WITH_EVIDENCE"
    card_row["regression"] = regression("CERTIFIED_TRUE", "alpha-card")
    card_regression_report = gate.validate_model(card_regression)
    card_regression_history = gate._monotonic_transition_failures(
        card_regression.baseline_authorities,
        card_regression.authorities,
        "selftest-card-regression",
    )
    append_direct_case(
        "87",
        "an evidence-backed card regression preserves the cumulative certified-card count",
        "PASS",
        "PASS"
        if card_regression_report["status"] == "PASS" and not card_regression_history
        else "FAIL",
        [str(value) for value in card_regression_report.get("failures", [])]
        + card_regression_history,
    )

    stage_regression = _valid_input()
    stage_row = stage_regression.authorities["inherited_green"]["stages"][2]
    stage_row["ledger_status"] = "REGRESSED_WITH_EVIDENCE"
    stage_row["regression"] = regression("CURRENT_DELTA_GREEN", "stage-three")
    stage_status = stage_regression.authorities["inherited_green"]["canonical_pr_status"]
    stage_status["stage_3_status"] = "REGRESSED_WITH_EVIDENCE"
    stage_status["stage_3_ledger_status"] = "REGRESSED_WITH_EVIDENCE"
    stage_regression.pr_body = (
        "V0.7.6 Stage 3 regressed with evidence.\n\n"
        + gate.render_status_block(stage_status)
    )
    stage_regression_report = gate.validate_model(stage_regression)
    stage_regression_history = gate._monotonic_transition_failures(
        stage_regression.baseline_authorities,
        stage_regression.authorities,
        "selftest-stage-regression",
    )
    append_direct_case(
        "88",
        "an honestly described evidence-backed Stage regression is a legal point-inertia state",
        "PASS",
        "PASS"
        if stage_regression_report["status"] == "PASS" and not stage_regression_history
        else "FAIL",
        [str(value) for value in stage_regression_report.get("failures", [])]
        + stage_regression_history,
    )

    live_history_failures: list[str] = []
    live_history_transition_count = 0
    try:
        with tempfile.TemporaryDirectory(prefix="v076-history-wash-") as temp_path:
            history_root = Path(temp_path)
            _git_fixture(history_root, "init", "-b", "main")
            _git_fixture(history_root, "config", "user.name", "V076 Gate Selftest")
            _git_fixture(history_root, "config", "user.email", "v076-gate@example.invalid")
            history_authorities = _authorities()
            _write_authority_fixture(history_root, history_authorities)
            base_source = history_root / BASE_OWNER_PATH
            base_source.parent.mkdir(parents=True, exist_ok=True)
            base_source.write_text(
                "extends RefCounted\n"
                f"class_name {history_authorities['historical_reuse']['component_inventory'][0]['class_name']}\n",
                encoding="utf-8",
            )
            _git_fixture(history_root, "add", ".")
            _git_fixture(history_root, "commit", "-m", "activation")
            activation_sha = _git_fixture(history_root, "rev-parse", "HEAD")

            staged_file = history_root / staged_path
            staged_file.parent.mkdir(parents=True, exist_ok=True)
            staged_file.write_text("extends RefCounted\n", encoding="utf-8")
            _git_fixture(history_root, "add", ".")
            _git_fixture(history_root, "commit", "-m", "code before registry")

            registered_fixture = _registered_stage4_fixture()
            _write_authority_fixture(history_root, registered_fixture.authorities)
            _git_fixture(history_root, "add", ".")
            _git_fixture(history_root, "commit", "-m", "late registry")
            history_head = _git_fixture(history_root, "rev-parse", "HEAD")
            (
                live_history_failures,
                live_history_transition_count,
            ) = gate.committed_history_failures(
                history_root,
                activation_sha,
                history_head,
                _implementation_paths(),
            )
    except (OSError, subprocess.CalledProcessError) as error:
        live_history_failures = [f"SELFTEST_HISTORY_FIXTURE_ERROR:{error}"]
    append_direct_case(
        "89",
        "the public committed-history orchestrator rejects code-before-registry across two commits",
        "FAIL",
        "FAIL"
        if live_history_transition_count == 2
        and any(
            failure.startswith("HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:")
            for failure in live_history_failures
        )
        else "PASS",
        live_history_failures,
    )

    atomic_history_failures: list[str] = []
    atomic_history_transition_count = 0
    try:
        with tempfile.TemporaryDirectory(prefix="v076-history-atomic-") as temp_path:
            atomic_root = Path(temp_path)
            _git_fixture(atomic_root, "init", "-b", "main")
            _git_fixture(atomic_root, "config", "user.name", "V076 Gate Selftest")
            _git_fixture(atomic_root, "config", "user.email", "v076-gate@example.invalid")
            atomic_authorities = _authorities()
            _write_authority_fixture(atomic_root, atomic_authorities)
            atomic_base_source = atomic_root / BASE_OWNER_PATH
            atomic_base_source.parent.mkdir(parents=True, exist_ok=True)
            atomic_base_source.write_text(
                "extends RefCounted\n"
                f"class_name {atomic_authorities['historical_reuse']['component_inventory'][0]['class_name']}\n",
                encoding="utf-8",
            )
            _git_fixture(atomic_root, "add", ".")
            _git_fixture(atomic_root, "commit", "-m", "activation")
            atomic_activation = _git_fixture(atomic_root, "rev-parse", "HEAD")

            registered_fixture = _registered_stage4_fixture()
            atomic_file = atomic_root / staged_path
            atomic_file.parent.mkdir(parents=True, exist_ok=True)
            atomic_owner = _registry(registered_fixture)["component_inventory"][-1]
            atomic_file.write_text(
                "extends RefCounted\n"
                f"class_name {atomic_owner['class_name']}\n",
                encoding="utf-8",
            )
            _write_authority_fixture(atomic_root, registered_fixture.authorities)
            _git_fixture(atomic_root, "add", ".")
            _git_fixture(atomic_root, "commit", "-m", "atomic registry and code")
            atomic_head = _git_fixture(atomic_root, "rev-parse", "HEAD")
            (
                atomic_history_failures,
                atomic_history_transition_count,
            ) = gate.committed_history_failures(
                atomic_root,
                atomic_activation,
                atomic_head,
                _implementation_paths(),
            )
    except (OSError, subprocess.CalledProcessError) as error:
        atomic_history_failures = [f"SELFTEST_HISTORY_FIXTURE_ERROR:{error}"]
    append_direct_case(
        "90",
        "the public committed-history orchestrator accepts atomic registry plus implementation",
        "PASS",
        "PASS"
        if atomic_history_transition_count == 1 and not atomic_history_failures
        else "FAIL",
        atomic_history_failures,
    )

    sidecar_fixture = _valid_input()
    sidecar_scope = sidecar_fixture.authorities["inherited_green"]["canonical_change_scope"]
    sidecar_scope["change_classes"] = ["DOMAIN_CORE"]
    sidecar_scope["affected_domains"] = [BASE_DOMAIN_ID]
    sidecar_scope["affected_owners"] = [BASE_OWNER_ID]
    sidecar_scope["focused_tests"] = ["v076.reuse_point_inertia.selftest"]
    source_sidecar = BASE_OWNER_PATH + ".uid"
    sidecar_fixture.changed_paths = [{"status": "M", "path": source_sidecar}]
    sidecar_fixture.gate_changed_paths = [{"status": "M", "path": source_sidecar}]
    sidecar_report = gate.validate_model(sidecar_fixture)
    exempt_sidecars = [
        "scripts/diagnostics/runtime_authority_audit.gd.uid",
        "addons/funplay_mcp/plugin.gd.uid",
        "addons/funplay_mcp/icon.svg.import",
    ]
    sidecar_binding_green = bool(
        gate._component_binding_path(source_sidecar) == BASE_OWNER_PATH
        and sidecar_report["status"] == "PASS"
        and all(not gate._is_product_component_path(path) for path in exempt_sidecars)
        and gate._is_product_component_path(
            "addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd.uid"
        )
    )
    append_direct_case(
        "91",
        "Godot sidecars inherit their source binding without bypassing runtime addon coverage",
        "PASS",
        "PASS" if sidecar_binding_green else "FAIL",
        [str(value) for value in sidecar_report.get("failures", [])],
    )

    rename_rows = gate._parse_name_status_z(
        (
            "R100\0scripts/v076/stage4/owner.gd\0scripts/tools/owner_capture.gd\0"
            "R100\0scripts/tools/fixture.gd\0scripts/v076/stage4/fixture.gd\0"
            "M\0resources/cards/runtime/families/普通卡.tres\0"
        ).encode("utf-8")
    )
    expected_rename_rows = [
        {"status": "D", "path": "scripts/v076/stage4/owner.gd"},
        {"status": "A", "path": "scripts/tools/owner_capture.gd"},
        {"status": "D", "path": "scripts/tools/fixture.gd"},
        {"status": "A", "path": "scripts/v076/stage4/fixture.gd"},
        {"status": "M", "path": "resources/cards/runtime/families/普通卡.tres"},
    ]
    append_direct_case(
        "92",
        "NUL-safe rename classification preserves old, new, and Unicode rule paths",
        "PASS",
        "PASS" if rename_rows == expected_rename_rows else "FAIL",
        [] if rename_rows == expected_rename_rows else [f"RENAME_ROWS:{rename_rows!r}"],
    )

    false_origin = _valid_input()
    false_origin_base_row = false_origin.baseline_authorities["card_matrix"]["category_matrix"][0]
    false_origin_head_row = false_origin.authorities["card_matrix"]["category_matrix"][0]
    false_origin_base_row["certification"]["ALPHA07_CERTIFIED"] = False
    false_origin_head_row["certification"]["ALPHA07_CERTIFIED"] = "REGRESSED_WITH_EVIDENCE"
    false_origin_head_row["regression"] = regression("CERTIFIED_TRUE", "false-origin")
    false_origin.baseline_authorities["card_matrix"]["aggregate"]["alpha07_certified_card_count"] = 0
    false_origin_report = gate.validate_model(false_origin)

    new_regressed = copy.deepcopy(previous)
    new_regressed["inherited_green"]["stages"].append(
        {
            "stage_id": "V076_STAGE_4_NEVER_GREEN",
            "ledger_status": "REGRESSED_WITH_EVIDENCE",
            "regression": regression("CURRENT_DELTA_GREEN", "never-green-stage"),
        }
    )
    new_regressed["golden"]["steps"].append(
        {
            "step_id": "golden.never.green",
            "status": "REGRESSED_WITH_EVIDENCE",
            "human_executed": False,
            "production_composition": False,
            "pass_claimed": False,
            "required_surface": "future production surface",
            "regression": regression("ISOLATED_GREEN", "never-green-golden"),
        }
    )
    new_regressed_failures = gate._monotonic_transition_failures(
        previous,
        new_regressed,
        "selftest-regression-origin",
    )
    regression_origin_rejected = bool(
        false_origin_report["status"] == "FAIL"
        and any(
            "CARD_CERTIFICATION_REGRESSION_WITHOUT_GREEN_ORIGIN" in failure
            for failure in false_origin_report.get("failures", [])
        )
        and any(
            "INHERITED_STAGE_REGRESSION_WITHOUT_GREEN_ORIGIN" in failure
            for failure in new_regressed_failures
        )
        and any(
            "GOLDEN_SCENARIO_REGRESSION_WITHOUT_GREEN_ORIGIN" in failure
            for failure in new_regressed_failures
        )
    )
    append_direct_case(
        "93",
        "regression evidence must descend from an actually green prior state",
        "FAIL",
        "FAIL" if regression_origin_rejected else "PASS",
        [str(value) for value in false_origin_report.get("failures", [])]
        + new_regressed_failures,
    )

    scan_erased = copy.deepcopy(previous)
    erased_owner = scan_erased["historical_reuse"]["component_inventory"][0]
    erased_owner["change_class"] = "INHERITED"
    erased_owner.pop("reuse_scan", None)
    scan_erasure_failures = gate._monotonic_transition_failures(
        previous, scan_erased, "selftest-reuse-scan-erasure"
    )
    scan_erasure_rejected = bool(
        any("COMPONENT_CHANGE_CLASS_REVERTED_TO_INHERITED" in value for value in scan_erasure_failures)
        and any("HISTORY_AUTHORITY_INERTIA_REUSE_SCAN_INVALID" in value for value in scan_erasure_failures)
    )
    append_direct_case(
        "94",
        "an established authority cannot erase its reuse scan by relabeling itself inherited",
        "FAIL",
        "FAIL" if scan_erasure_rejected else "PASS",
        scan_erasure_failures,
    )

    hidden_tool_row = {
        "status": "A",
        "path": "scripts/tools/hidden_runtime_owner.gd",
        "production_reachable": True,
    }
    ordinary_test_row = {"status": "A", "path": "tests/focused_owner_test.gd"}
    composition_context_green = bool(
        gate._is_product_composition_path("project.godot")
        and gate._is_product_composition_path("scenes/main.tscn")
        and gate._is_changed_component_candidate_path(
            hidden_tool_row, True, strict_composition_context=True
        )
        and not gate._is_changed_component_candidate_path(
            {
                "status": "A",
                "path": "scripts/tools/string_spoof.gd",
                "production_reachable": "true",
            },
            False,
            strict_composition_context=True,
        )
        and not gate._is_changed_component_candidate_path(
            ordinary_test_row, False, strict_composition_context=True
        )
    )
    append_direct_case(
        "95",
        "composition changes expose trusted-path runtime files while ordinary product plus test deltas stay focused",
        "PASS",
        "PASS" if composition_context_green else "FAIL",
        [] if composition_context_green else ["COMPOSITION_CONTEXT_CLASSIFIER_MISMATCH"],
    )

    path_contract_green = bool(
        gate._is_forced_production_path("assets/runtime/tuning.md")
        and gate._is_forced_production_path("assets/runtime/tuning")
        and gate._is_forced_production_path("Stage4RuntimeOwner.gd")
        and gate._is_rule_authority_path("resources/cards/v076/stage4.tres")
        and gate._is_rule_authority_path("data/v076/stage4_rules.json")
        and not gate._is_rule_authority_path("resources/compendium/v076_entry.tres")
    )
    append_direct_case(
        "96",
        "runtime data extensions and future card rule roots fail closed without reclassifying compendium presentation",
        "PASS",
        "PASS" if path_contract_green else "FAIL",
        [] if path_contract_green else ["RUNTIME_OR_RULE_PATH_CLASSIFIER_MISMATCH"],
    )

    stub_snapshot = copy.deepcopy(previous)
    stub_snapshot["historical_reuse"]["component_inventory"][0].pop("focused_test_ids")
    stub_failures = gate._authority_snapshot_contract_failures(stub_snapshot, "selftest-stub")
    empty_scope_snapshot = copy.deepcopy(previous)
    empty_scope = empty_scope_snapshot["inherited_green"]["canonical_change_scope"]
    empty_scope["focused_tests"] = []
    empty_scope["inherited_sentinels"] = []
    empty_scope_failures = gate._authority_snapshot_contract_failures(
        empty_scope_snapshot, "selftest-empty-scope"
    )
    double_owner = _valid_input()
    _parallel_owner(double_owner)
    double_owner_failures = gate._authority_snapshot_contract_failures(
        double_owner.authorities, "selftest-double-owner-snapshot"
    )
    snapshot_contract_rejected = bool(
        stub_failures and empty_scope_failures and double_owner_failures
    )
    append_direct_case(
        "97",
        "every historical authority snapshot enforces full rows, nonempty scope, and owner cardinality",
        "FAIL",
        "FAIL" if snapshot_contract_rejected else "PASS",
        stub_failures + empty_scope_failures + double_owner_failures,
    )

    diagnostic = _valid_input()
    diagnostic_component = _component(
        "component.tools.stage4_diagnostic",
        "scripts/tools/v076/stage4_diagnostic.gd",
        BASE_DOMAIN_ID,
        "DIAGNOSTIC_BENCH",
        production_reachable=False,
    )
    diagnostic_component["change_class"] = "TEST_ORACLE_ONLY"
    _registry(diagnostic)["component_inventory"].append(diagnostic_component)
    diagnostic_delta = {"status": "A", "path": diagnostic_component["path"]}
    diagnostic.changed_paths.append(diagnostic_delta)
    diagnostic.gate_changed_paths.append(diagnostic_delta)
    diagnostic.authorities["inherited_green"]["canonical_change_scope"][
        "change_classes"
    ].append("TEST_ORACLE_ONLY")
    diagnostic_report = gate.validate_model(diagnostic)
    diagnostic_history = gate._monotonic_transition_failures(
        diagnostic.baseline_authorities,
        diagnostic.authorities,
        "selftest-production-shaped-diagnostic",
        [diagnostic_delta],
    )
    append_direct_case(
        "98",
        "a registered non-production diagnostic in a trusted tools path remains a legal focused delta",
        "PASS",
        "PASS" if diagnostic_report["status"] == "PASS" and not diagnostic_history else "FAIL",
        [str(value) for value in diagnostic_report.get("failures", [])] + diagnostic_history,
    )

    fake_tool = _valid_input()
    fake_tool_component = _component(
        "component.fake.main_scene_tool",
        "scenes/main.tscn",
        BASE_DOMAIN_ID,
        "TOOLING",
        production_reachable=False,
    )
    fake_tool_component["change_class"] = "TOOLING_ONLY"
    _registry(fake_tool)["component_inventory"].append(fake_tool_component)
    fake_tool_delta = {"status": "M", "path": fake_tool_component["path"]}
    fake_tool.changed_paths.append(fake_tool_delta)
    fake_tool.gate_changed_paths.append(fake_tool_delta)
    fake_tool_report = gate.validate_model(fake_tool)
    append_direct_case(
        "99",
        "the canonical main scene cannot self-declare as non-production tooling",
        "FAIL",
        str(fake_tool_report["status"]),
        [str(value) for value in fake_tool_report.get("failures", [])],
    )

    stage_without_evidence = _valid_input()
    stage_without_evidence.authorities["inherited_green"]["canonical_pr_status"][
        "stage_3_status"
    ] = "PRODUCTION_GREEN"
    stage_without_evidence.pr_body = _pr_body(stage_without_evidence)
    stage_without_evidence_report = gate.validate_model(stage_without_evidence)
    ghost_stage = _valid_input()
    ghost_stage.authorities["inherited_green"]["stages"].append(
        {
            "stage_id": "V076_STAGE_4_GHOST_NO_CAPABILITY",
            "ledger_status": "CURRENT_DELTA_GREEN",
            "head_sha": "c" * 40,
        }
    )
    ghost_status = ghost_stage.authorities["inherited_green"]["canonical_pr_status"]
    ghost_status["latest_completed_stage"] = "V076_STAGE_4_GHOST_NO_CAPABILITY"
    ghost_status["next_stage"] = "V076_STAGE_5_PENDING"
    ghost_stage.pr_body = _pr_body(ghost_stage)
    ghost_report = gate.validate_model(ghost_stage)
    stage_evidence_rejected = bool(
        any("CANONICAL_STAGE_STATUS_WITHOUT_GOLDEN_EVIDENCE" in value for value in stage_without_evidence_report.get("failures", []))
        and any("INHERITED_STAGE_WITHOUT_NEW_GOLDEN_CAPABILITY" in value for value in ghost_report.get("failures", []))
    )
    append_direct_case(
        "100",
        "Stage status cannot outrun Golden evidence or introduce a capability-free ghost Stage",
        "FAIL",
        "FAIL" if stage_evidence_rejected else "PASS",
        [str(value) for value in stage_without_evidence_report.get("failures", [])]
        + [str(value) for value in ghost_report.get("failures", [])],
    )

    english_claim = _valid_input()
    english_claim.pr_body += "\n\nGolden human green; no blockers remain."
    chinese_claim = _valid_input()
    chinese_claim.pr_body += "\n\n真人试玩已通过，无阻塞。主场景生产切换已完成，无回退。"
    legal_stage_sentence = _valid_input()
    legal_stage_sentence.pr_body = (
        "Stage 3 isolated evidence is current; Stage 4 pending.\n\n"
        + gate.render_status_block(
            legal_stage_sentence.authorities["inherited_green"]["canonical_pr_status"]
        )
    )
    english_claim_report = gate.validate_model(english_claim)
    chinese_claim_report = gate.validate_model(chinese_claim)
    legal_stage_report = gate.validate_model(legal_stage_sentence)
    prose_contract_green = bool(
        english_claim_report["status"] == "FAIL"
        and chinese_claim_report["status"] == "FAIL"
        and legal_stage_report["status"] == "PASS"
    )
    append_direct_case(
        "101",
        "PR prose rejects English and Chinese false-green claims without misreading the next Stage clause",
        "PASS",
        "PASS" if prose_contract_green else "FAIL",
        [str(value) for value in english_claim_report.get("failures", [])]
        + [str(value) for value in chinese_claim_report.get("failures", [])]
        + [str(value) for value in legal_stage_report.get("failures", [])],
    )

    wrong_scene = _valid_input()
    install_golden_evidence(wrong_scene, human=False)
    wrong_step = wrong_scene.authorities["golden"]["steps"][0]
    wrong_receipt_path = wrong_step["production_evidence"]["receipt_path"]
    wrong_receipt = copy.deepcopy(
        wrong_scene.evidence_artifact_bindings[wrong_receipt_path]["json"]
    )
    wrong_scene_path = "res://scenes/fixtures/scripted_fixture.tscn"
    wrong_receipt["production_scene_path"] = wrong_scene_path
    wrong_receipt_bytes = json.dumps(
        wrong_receipt, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    wrong_receipt_sha = hashlib.sha256(wrong_receipt_bytes).hexdigest()
    wrong_step["production_evidence"]["production_scene_path"] = wrong_scene_path
    wrong_step["production_evidence"]["receipt_sha256"] = wrong_receipt_sha
    wrong_scene.evidence_artifact_bindings[wrong_receipt_path] = {
        "present": True,
        "sha256": wrong_receipt_sha,
        "json": wrong_receipt,
    }
    wrong_scene.evidence_artifact_bindings["scenes/fixtures/scripted_fixture.tscn"] = (
        wrong_scene.evidence_artifact_bindings["scenes/main.tscn"]
    )
    wrong_scene_report = gate.validate_model(wrong_scene)
    append_direct_case(
        "102",
        "hash-bound scripted fixture evidence cannot impersonate the canonical production scene",
        "FAIL",
        str(wrong_scene_report["status"]),
        [str(value) for value in wrong_scene_report.get("failures", [])],
    )

    bad_regression = copy.deepcopy(previous)
    bad_regression_stage = bad_regression["inherited_green"]["stages"][2]
    bad_regression_stage["ledger_status"] = "REGRESSED_WITH_EVIDENCE"
    bad_regression_stage["regression"] = {
        "failure_evidence": "unbound assertion",
        "affected_commit": "x",
        "affected_owner": "component.does.not.exist",
        "repair_plan": "repair after evidence is bound",
        "prior_status": "CURRENT_DELTA_GREEN",
    }
    bad_regression_failures = gate._regression_binding_failures(
        bad_regression, "selftest-bad-regression-binding", "SELFTEST", set()
    )
    append_direct_case(
        "103",
        "regression evidence binds a real commit and registered affected owner",
        "FAIL",
        "FAIL" if bad_regression_failures else "PASS",
        bad_regression_failures,
    )

    invalid_cutover_commit = _valid_input()
    invalid_cutover_entry = _prepare_atomic_replacement(invalid_cutover_commit)
    invalid_cutover_entry["cutover_commit"] = "definitely-not-a-commit"
    invalid_cutover_report = gate.validate_model(invalid_cutover_commit)
    append_direct_case(
        "104",
        "an owner supersession cutover must bind a real commit-shaped identity",
        "FAIL",
        str(invalid_cutover_report["status"]),
        [str(value) for value in invalid_cutover_report.get("failures", [])],
    )

    fake_cutover = _valid_input()
    _valid_evidenced_production_cutover(fake_cutover)
    fake_cutover_evidence = fake_cutover.authorities["supersession"][
        "production_cutover_evidence"
    ]
    fake_cutover_evidence["candidate_head_sha"] = "a" * 40
    fake_cutover_evidence["production_scene_path"] = "res://definitely/not/a/scene.txt"
    fake_cutover_evidence["affected_owners"] = "bogus-owner"
    fake_cutover.pr_body = _pr_body(fake_cutover)
    fake_cutover_report = gate.validate_model(fake_cutover)
    append_direct_case(
        "105",
        "production cutover evidence binds the candidate, canonical scene, receipt, and typed owner set",
        "FAIL",
        str(fake_cutover_report["status"]),
        [str(value) for value in fake_cutover_report.get("failures", [])],
    )

    sibling_subject = _valid_input()
    sibling_subject.evidence_subject_is_head_ancestor = False
    sibling_subject.evidence_subject_product_tree_matches_head = False
    sibling_subject_report = gate.validate_model(sibling_subject)
    append_direct_case(
        "106",
        "Golden evidence subject must be a Head ancestor with an unchanged product tree",
        "FAIL",
        str(sibling_subject_report["status"]),
        [str(value) for value in sibling_subject_report.get("failures", [])],
    )

    missing_history_path_failures: list[str] = []
    try:
        with tempfile.TemporaryDirectory(prefix="v076-history-missing-path-") as temp_path:
            missing_root = Path(temp_path)
            _git_fixture(missing_root, "init", "-b", "main")
            _git_fixture(missing_root, "config", "user.name", "V076 Gate Selftest")
            _git_fixture(missing_root, "config", "user.email", "v076-gate@example.invalid")
            missing_base = _authorities()
            _write_authority_fixture(missing_root, missing_base)
            missing_base_source = missing_root / BASE_OWNER_PATH
            missing_base_source.parent.mkdir(parents=True, exist_ok=True)
            missing_base_source.write_text(
                "extends RefCounted\n"
                f"class_name {missing_base['historical_reuse']['component_inventory'][0]['class_name']}\n",
                encoding="utf-8",
            )
            _git_fixture(missing_root, "add", ".")
            _git_fixture(missing_root, "commit", "-m", "activation")
            missing_activation = _git_fixture(missing_root, "rev-parse", "HEAD")
            missing_registered = _registered_stage4_fixture()
            _write_authority_fixture(missing_root, missing_registered.authorities)
            _git_fixture(missing_root, "add", ".")
            _git_fixture(missing_root, "commit", "-m", "registry without implementation")
            missing_head = _git_fixture(missing_root, "rev-parse", "HEAD")
            missing_history_path_failures, _ = gate.committed_history_failures(
                missing_root,
                missing_activation,
                missing_head,
                _implementation_paths(),
            )
    except (OSError, subprocess.CalledProcessError) as error:
        missing_history_path_failures = [f"SELFTEST_HISTORY_FIXTURE_ERROR:{error}"]
    append_direct_case(
        "107",
        "a registry-only production Owner cannot precede its implementation commit",
        "FAIL",
        "FAIL"
        if any(
            value.startswith("HISTORY_REGISTERED_COMPONENT_PATH_MISSING:")
            for value in missing_history_path_failures
        )
        else "PASS",
        missing_history_path_failures,
    )

    closure_stage_a_failures: list[str] = []
    closure_stage_b_failures: list[str] = []
    try:
        with tempfile.TemporaryDirectory(prefix="v076-history-reference-closure-") as temp_path:
            closure_root = Path(temp_path)
            _git_fixture(closure_root, "init", "-b", "main")
            _git_fixture(closure_root, "config", "user.name", "V076 Gate Selftest")
            _git_fixture(closure_root, "config", "user.email", "v076-gate@example.invalid")
            closure_authorities = _authorities()
            main_component = _component(
                "component.main.composition",
                "scenes/main.tscn",
                BASE_DOMAIN_ID,
                "PRESENTATION",
                production_reachable=True,
            )
            main_component["change_class"] = "PRODUCTION_COMPOSITION"
            closure_authorities["historical_reuse"]["component_inventory"].append(
                main_component
            )
            closure_scope = closure_authorities["inherited_green"][
                "canonical_change_scope"
            ]
            closure_scope["change_classes"].append("PRODUCTION_COMPOSITION")
            _write_authority_fixture(closure_root, closure_authorities)
            closure_base_source = closure_root / BASE_OWNER_PATH
            closure_base_source.parent.mkdir(parents=True, exist_ok=True)
            closure_base_source.write_text(
                "extends RefCounted\n"
                f"class_name {closure_authorities['historical_reuse']['component_inventory'][0]['class_name']}\n",
                encoding="utf-8",
            )
            closure_main = closure_root / "scenes/main.tscn"
            closure_main.parent.mkdir(parents=True, exist_ok=True)
            closure_main.write_text("[gd_scene format=3]\n", encoding="utf-8")
            (closure_root / "project.godot").write_text(
                '[application]\nrun/main_scene="res://scenes/main.tscn"\n',
                encoding="utf-8",
            )
            _git_fixture(closure_root, "add", ".")
            _git_fixture(closure_root, "commit", "-m", "activation")
            closure_activation = _git_fixture(closure_root, "rev-parse", "HEAD")

            hidden_runtime = closure_root / "scripts/tools/hidden_runtime_owner.gd"
            hidden_runtime.parent.mkdir(parents=True, exist_ok=True)
            hidden_runtime.write_text(
                "extends RefCounted\nclass_name HiddenRuntimeOwner\n",
                encoding="utf-8",
            )
            _git_fixture(closure_root, "add", ".")
            _git_fixture(closure_root, "commit", "-m", "unreachable focused helper")
            closure_stage_a = _git_fixture(closure_root, "rev-parse", "HEAD")
            closure_stage_a_failures, _ = gate.committed_history_failures(
                closure_root,
                closure_activation,
                closure_stage_a,
                _implementation_paths(),
            )

            closure_main.write_text(
                "[gd_scene format=3]\n"
                '[ext_resource type="Script" path="res://scripts/tools/hidden_runtime_owner.gd" id="1"]\n',
                encoding="utf-8",
            )
            _git_fixture(closure_root, "add", ".")
            _git_fixture(closure_root, "commit", "-m", "wire helper into production")
            closure_stage_b = _git_fixture(closure_root, "rev-parse", "HEAD")
            closure_stage_b_failures, _ = gate.committed_history_failures(
                closure_root,
                closure_activation,
                closure_stage_b,
                _implementation_paths(),
            )
    except (OSError, subprocess.CalledProcessError) as error:
        closure_stage_b_failures = [f"SELFTEST_HISTORY_FIXTURE_ERROR:{error}"]
    closure_wiring_rejected = bool(
        not closure_stage_a_failures
        and any(
            "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT" in value
            and "scripts/tools/hidden_runtime_owner.gd" in value
            for value in closure_stage_b_failures
        )
    )
    append_direct_case(
        "108",
        "a previously harmless tools file is classified at the exact commit that production first references it",
        "FAIL",
        "FAIL" if closure_wiring_rejected else "PASS",
        closure_stage_a_failures + closure_stage_b_failures,
    )

    dynamic_rule_path = "docs/ai_runtime_ownership_contract.md"
    dynamic_rule_paths = gate._rule_authority_paths_at(
        project_root, "HEAD", True
    )
    dynamic_rule = _valid_input()
    dynamic_rule_delta = {
        "status": "M",
        "path": dynamic_rule_path,
        "rule_authority": True,
    }
    dynamic_rule.changed_paths.append(dynamic_rule_delta)
    dynamic_rule.gate_changed_paths.append(dynamic_rule_delta)
    dynamic_rule_report = gate.validate_model(dynamic_rule)
    rule_dependency_path = "scripts/rules/space_syndicate_ruleset_profile_v06.gd"
    derived_rule_rows = gate.augment_changed_paths_with_rule_authorities(
        project_root,
        "HEAD",
        "HEAD",
        True,
        [{"status": "M", "path": rule_dependency_path}],
    )
    rule_dependency_derived = any(
        row.get("path") == rule_dependency_path
        and row.get("rule_authority") is True
        for row in derived_rule_rows
    )
    dynamic_rule_rejected = bool(
        dynamic_rule_path in dynamic_rule_paths
        and "AGENTS.md" not in dynamic_rule_paths
        and rule_dependency_derived
        and dynamic_rule_report["status"] == "FAIL"
        and dynamic_rule_report["metrics"]["PRODUCT_RULE_CHANGE_COUNT"] >= 1
    )
    append_direct_case(
        "109",
        "the Gate reuses registry-declared rule sources without treating broad scanner inputs as rules",
        "FAIL",
        "FAIL" if dynamic_rule_rejected else "PASS",
        [str(value) for value in dynamic_rule_report.get("failures", [])],
    )

    closure_semantics_failures: list[str] = []
    dynamic_reference_failures: list[str] = []
    unicode_path_failures: list[str] = []
    try:
        with tempfile.TemporaryDirectory(prefix="v076-closure-semantics-") as temp_path:
            closure_root = Path(temp_path)
            _git_fixture(closure_root, "init")
            _git_fixture(closure_root, "config", "user.email", "selftest@example.invalid")
            _git_fixture(closure_root, "config", "user.name", "V076 Gate Selftest")
            files = {
                "project.godot": (
                    '[application]\nrun/main_scene="res://scenes/main.tscn"\n'
                    '[editor_plugins]\nenabled=PackedStringArray('
                    '"res://addons/editor_only/plugin.gd")\n'
                ),
                "scenes/main.tscn": (
                    '[gd_scene load_steps=2 format=3]\n'
                    '[ext_resource type="Script" '
                    'path="res://scripts/runtime/main_runtime.gd" id="1"]\n'
                ),
                "scripts/runtime/main_runtime.gd": (
                    'extends RefCounted\nclass_name ClosureRuntime\n'
                    'const PROFILE_PATH := "res://resources/runtime/old_profile.tres"\n'
                    'func read_profile():\n\treturn load(PROFILE_PATH)\n'
                ),
                "resources/runtime/old_profile.tres": "[gd_resource format=3]\n",
                "tests/hidden_profile.tres": "[gd_resource format=3]\n",
                "tests/comment_only.gd": "extends RefCounted\n",
                "addons/editor_only/plugin.gd": "extends EditorPlugin\n",
                "resources/cards/runtime/families/普通卡.tres": "[gd_resource format=3]\n",
            }
            for relative, payload in files.items():
                target = closure_root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(payload, encoding="utf-8")
            _git_fixture(closure_root, "add", ".")
            _git_fixture(closure_root, "commit", "-m", "closure baseline")
            closure_base = _git_fixture(closure_root, "rev-parse", "HEAD")

            (closure_root / "scripts/runtime/main_runtime.gd").write_text(
                'extends RefCounted\nclass_name ClosureRuntime\n'
                'const PROFILE_PATH := "res://tests/hidden_profile.tres"\n'
                '# documentation only: "res://tests/comment_only.gd"\n'
                'func read_profile():\n\treturn load(PROFILE_PATH)\n',
                encoding="utf-8",
            )
            _git_fixture(closure_root, "add", ".")
            _git_fixture(closure_root, "commit", "-m", "retarget literal profile")
            closure_retarget = _git_fixture(closure_root, "rev-parse", "HEAD")
            retarget_rows = gate.snapshot_changed_paths(
                closure_root, closure_base, closure_retarget, False
            )
            retarget_rows = gate.augment_changed_paths_with_production_references(
                closure_root,
                closure_base,
                closure_retarget,
                False,
                retarget_rows,
                ["scripts/runtime/main_runtime.gd"],
            )
            by_retarget_path = {row.get("path"): row for row in retarget_rows}
            if by_retarget_path.get("tests/hidden_profile.tres", {}).get(
                "production_reachable"
            ) is not True:
                closure_semantics_failures.append("CONST_RETARGET_NOT_REACHABLE")
            if by_retarget_path.get(
                "resources/runtime/old_profile.tres", {}
            ).get("production_reachable_before") is not True:
                closure_semantics_failures.append("REMOVED_REFERENCE_NOT_RECORDED")
            if "tests/comment_only.gd" in by_retarget_path:
                closure_semantics_failures.append("COMMENT_REFERENCE_FALSE_EDGE")
            if "addons/editor_only/plugin.gd" in by_retarget_path:
                closure_semantics_failures.append("EDITOR_PLUGIN_FALSE_EDGE")

            (closure_root / "scripts/runtime/main_runtime.gd").write_text(
                'extends RefCounted\nclass_name ClosureRuntime\n'
                'const PROFILE_PATH := "res://tests/hidden_profile.tres"\n'
                'func read_profile(runtime_path: String):\n'
                '\tvar primary := load(PROFILE_PATH)\n'
                '\treturn load(runtime_path) if primary != null else null\n',
                encoding="utf-8",
            )
            _git_fixture(
                closure_root,
                "mv",
                "resources/cards/runtime/families/普通卡.tres",
                "resources/cards/runtime/families/稀有卡.tres",
            )
            _git_fixture(closure_root, "add", ".")
            _git_fixture(closure_root, "commit", "-m", "add unresolved loader")
            closure_dynamic = _git_fixture(closure_root, "rev-parse", "HEAD")
            dynamic_rows = gate.snapshot_changed_paths(
                closure_root, closure_retarget, closure_dynamic, False
            )
            unicode_paths = {str(row.get("path", "")) for row in dynamic_rows}
            expected_unicode = {
                "resources/cards/runtime/families/普通卡.tres",
                "resources/cards/runtime/families/稀有卡.tres",
            }
            if not expected_unicode.issubset(unicode_paths):
                unicode_path_failures.append(
                    f"UNICODE_PATHS_MISSING:{sorted(unicode_paths)!r}"
                )
            dynamic_rows = gate.augment_changed_paths_with_production_references(
                closure_root,
                closure_retarget,
                closure_dynamic,
                False,
                dynamic_rows,
                ["scripts/runtime/main_runtime.gd"],
            )
            emitted_reference_failures = [
                str(value)
                for row in dynamic_rows
                for value in row.get("production_reference_failures", [])
            ]
            if not any(
                value.startswith("DYNAMIC_REFERENCE_UNRESOLVED:load:runtime_path")
                for value in emitted_reference_failures
            ):
                dynamic_reference_failures.append(
                    f"DYNAMIC_REFERENCE_NOT_REJECTED:{emitted_reference_failures!r}"
                )
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        closure_semantics_failures.append(f"CLOSURE_FIXTURE_ERROR:{error}")

    append_direct_case(
        "110",
        "production closure follows const loads while ignoring comments and editor-only sections",
        "PASS",
        "PASS" if not closure_semantics_failures else "FAIL",
        closure_semantics_failures,
    )
    append_direct_case(
        "111",
        "a newly introduced unresolved dynamic production load fails closed",
        "FAIL",
        "FAIL" if not dynamic_reference_failures else "PASS",
        dynamic_reference_failures or ["DYNAMIC_REFERENCE_UNRESOLVED"],
    )
    append_direct_case(
        "112",
        "real Git rename records preserve Unicode card authority paths without quote loss",
        "PASS",
        "PASS" if not unicode_path_failures else "FAIL",
        unicode_path_failures,
    )

    pending_activation_report = gate.validate_model(
        _pending_domain_first_owner_fixture()
    )
    append_direct_case(
        "113",
        "a pending future domain may atomically register its first unique Owner",
        "PASS",
        str(pending_activation_report.get("status", "FAIL")),
        [str(value) for value in pending_activation_report.get("failures", [])],
    )

    predeclared_capability = _valid_input()
    predeclared_step = {
        "step_id": "golden.predeclared.stage4",
        "status": "PENDING",
        "human_executed": False,
        "production_composition": False,
        "pass_claimed": False,
        "required_surface": "future isolated Stage 4 fixture",
    }
    baseline_golden = predeclared_capability.baseline_authorities["golden"]
    baseline_golden["steps"].append(copy.deepcopy(predeclared_step))
    baseline_golden["summary"]["step_count"] = 2
    baseline_golden["summary"]["pending_step_ids"] = [
        "golden.predeclared.stage4"
    ]
    current_golden = predeclared_capability.authorities["golden"]
    proven_step = copy.deepcopy(predeclared_step)
    proven_step.update(
        {
            "status": "ISOLATED_GREEN",
            "pass_claimed": True,
            "evidence": "Focused isolated Stage 4 self-test receipt.",
        }
    )
    current_golden["steps"].append(proven_step)
    current_golden["isolated_green_count"] = 2
    current_golden["summary"]["step_count"] = 2
    current_golden["summary"]["isolated_green_step_ids"] = [
        "golden.map.owner",
        "golden.predeclared.stage4",
    ]
    current_golden["summary"]["pending_step_ids"] = []
    stage4_id = "V076_STAGE_4_PREDECLARED_GOLDEN_CAPABILITY"
    predeclared_capability.authorities["inherited_green"]["stages"].append(
        {
            "stage_id": stage4_id,
            "ledger_status": "CURRENT_DELTA_GREEN",
            "head_sha": "c" * 40,
            "stage_kind": "PLAYABLE_CAPABILITY",
            "golden_step_ids": ["golden.predeclared.stage4"],
        }
    )
    predeclared_status = predeclared_capability.authorities["inherited_green"][
        "canonical_pr_status"
    ]
    predeclared_status["golden_isolated_green_count"] = 2
    predeclared_status["latest_completed_stage"] = stage4_id
    predeclared_status["next_stage"] = "V076_STAGE_5_PENDING"
    predeclared_capability.pr_body = _pr_body(predeclared_capability)
    predeclared_capability_report = gate.validate_model(predeclared_capability)
    append_direct_case(
        "114",
        "a predeclared pending Golden step may become a new isolated Stage capability",
        "PASS",
        str(predeclared_capability_report.get("status", "FAIL")),
        [
            str(value)
            for value in predeclared_capability_report.get("failures", [])
        ],
    )

    correction_failures: list[str] = []
    invalid_correction_failures: list[str] = []
    mutated_correction_failures: list[str] = []
    reuse_scan_correction_failures: list[str] = []
    invalid_reuse_scan_correction_failures: list[str] = []
    mutated_reuse_scan_correction_failures: list[str] = []
    focused_scope_correction_failures: list[str] = []
    invalid_focused_scope_correction_failures: list[str] = []
    mutated_focused_scope_correction_failures: list[str] = []
    try:
        with tempfile.TemporaryDirectory(prefix="v076-history-correction-") as temp_path:
            correction_root = Path(temp_path)
            _git_fixture(correction_root, "init", "-b", "main")
            _git_fixture(
                correction_root, "config", "user.name", "V076 Gate Selftest"
            )
            _git_fixture(
                correction_root,
                "config",
                "user.email",
                "v076-gate@example.invalid",
            )
            correction_owner_path = correction_root / BASE_OWNER_PATH
            correction_owner_path.parent.mkdir(parents=True, exist_ok=True)
            correction_owner_path.write_text(
                "extends RefCounted\nclass_name ExistingMapOwner\n",
                encoding="utf-8",
            )
            history_registry = _authorities()["historical_reuse"]
            history_registry["component_inventory"][0][
                "reuse_candidates_considered"
            ] = []
            history_registry_path = correction_root / (
                "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
            )
            history_registry_path.parent.mkdir(parents=True, exist_ok=True)
            history_registry_path.write_text(
                json.dumps(history_registry, ensure_ascii=False, indent=2, sort_keys=True)
                + "\n",
                encoding="utf-8",
            )
            _git_fixture(correction_root, "add", ".")
            _git_fixture(correction_root, "commit", "-m", "existing owner baseline")
            (correction_root / "subject.txt").write_text(
                "existing owner repair subject\n", encoding="utf-8"
            )
            _git_fixture(correction_root, "add", ".")
            _git_fixture(correction_root, "commit", "-m", "repair subject")
            correction_head = _git_fixture(correction_root, "rev-parse", "HEAD")
            correction_tree = _git_fixture(
                correction_root, "rev-parse", "HEAD^{tree}"
            )
            correction_authorities = _authorities()
            correction_authorities["inherited_green"]["stages"][0][
                "evidence"
            ] = [
                {
                    "evidence_id": "selftest-history-classification-correction",
                    "result": "PASS",
                    "correction_kind": gate.HISTORY_CLASSIFICATION_CORRECTION_KIND,
                    "component_id": BASE_OWNER_ID,
                    "domain_id": BASE_DOMAIN_ID,
                    "repair_subject_head_sha": correction_head,
                    "repair_subject_tree_sha": correction_tree,
                    "prior_lifecycle": "REFERENCE_ONLY_DOMAIN",
                    "corrected_lifecycle": "ACTIVE_CURRENT_DOMAIN",
                    "new_owner_created": False,
                    "parallel_owner_count": 0,
                    "affected_transitions": [
                        {
                            "head_sha": correction_head,
                            "failure_codes": [
                                "HISTORY_PRODUCT_OWNER_BINDING_INVALID",
                                "HISTORY_REFERENCE_ONLY_AUTHORITY_WRITE",
                            ],
                        }
                    ],
                    "rationale": "Exact repair evidence for an existing unique Owner.",
                }
            ]
            correction_rows, correction_failures = (
                gate._history_classification_corrections(
                    correction_root, correction_head, correction_authorities
                )
            )
            if correction_rows != {
                correction_head: {
                    ("HISTORY_PRODUCT_OWNER_BINDING_INVALID", BASE_OWNER_ID),
                    ("HISTORY_REFERENCE_ONLY_AUTHORITY_WRITE", BASE_DOMAIN_ID),
                }
            }:
                correction_failures.append(
                    f"CORRECTION_EXACT_SCOPE_MISMATCH:{correction_rows!r}"
                )
            invalid_authorities = copy.deepcopy(correction_authorities)
            invalid_authorities["inherited_green"]["stages"][0]["evidence"][0][
                "affected_transitions"
            ][0]["failure_codes"] = ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"]
            invalid_rows, invalid_correction_failures = (
                gate._history_classification_corrections(
                    correction_root, correction_head, invalid_authorities
                )
            )
            if invalid_rows:
                invalid_correction_failures.append(
                    f"INVALID_CORRECTION_WAS_APPLIED:{invalid_rows!r}"
                )
            mutated_authorities = copy.deepcopy(correction_authorities)
            mutated_authorities["inherited_green"]["stages"][0]["evidence"][0][
                "rationale"
            ] = "Silently rewritten correction evidence."
            mutation_transition_failures = gate._monotonic_transition_failures(
                correction_authorities,
                mutated_authorities,
                "selftest-correction-mutation",
                [],
            )
            if not any(
                failure.startswith("HISTORY_CLASSIFICATION_CORRECTION_MUTATED:")
                for failure in mutation_transition_failures
            ):
                mutated_correction_failures.append(
                    f"CORRECTION_MUTATION_NOT_REJECTED:{mutation_transition_failures!r}"
                )

            reuse_scan_authorities = copy.deepcopy(correction_authorities)
            reuse_scan_authorities["inherited_green"]["stages"][0]["evidence"] = [
                {
                    "evidence_id": "selftest-reuse-scan-candidate-repair",
                    "result": "PASS",
                    "correction_kind": gate.HISTORY_REUSE_SCAN_CORRECTION_KIND,
                    "repair_subject_head_sha": correction_head,
                    "repair_subject_tree_sha": correction_tree,
                    "corrected_reuse_candidate_id": "reuse.map.existing_owner",
                    "prior_condition": "CANDIDATE_ID_PRESENT_BUT_NOT_DECLARED_CONSIDERED",
                    "corrected_condition": "CANDIDATE_ID_DECLARED_IN_BOTH_SCAN_LISTS",
                    "affected_component_ids": [BASE_OWNER_ID],
                    "affected_failures": [
                        {
                            "head_sha": correction_head,
                            "failure_code": "HISTORY_AUTHORITY_REUSE_SCAN_INVALID",
                            "component_id": BASE_OWNER_ID,
                        },
                        {
                            "head_sha": correction_head,
                            "failure_code": "HISTORY_AUTHORITY_INERTIA_REUSE_SCAN_INVALID",
                            "component_id": BASE_OWNER_ID,
                        },
                    ],
                    "product_behavior_changed": False,
                    "new_owner_created": False,
                    "rationale": "Exact reuse-scan metadata repair for an existing Owner.",
                }
            ]
            reuse_scan_rows, reuse_scan_correction_failures = (
                gate._history_reuse_scan_corrections(
                    correction_root, correction_head, reuse_scan_authorities
                )
            )
            expected_reuse_scan_rows = {
                correction_head: {
                    ("HISTORY_AUTHORITY_REUSE_SCAN_INVALID", BASE_OWNER_ID),
                    ("HISTORY_AUTHORITY_INERTIA_REUSE_SCAN_INVALID", BASE_OWNER_ID),
                }
            }
            if reuse_scan_rows != expected_reuse_scan_rows:
                reuse_scan_correction_failures.append(
                    f"REUSE_SCAN_CORRECTION_EXACT_SCOPE_MISMATCH:{reuse_scan_rows!r}"
                )
            invalid_reuse_scan_authorities = copy.deepcopy(reuse_scan_authorities)
            invalid_reuse_scan_authorities["inherited_green"]["stages"][0]["evidence"][0][
                "affected_failures"
            ][0]["failure_code"] = "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
            invalid_reuse_scan_rows, invalid_reuse_scan_correction_failures = (
                gate._history_reuse_scan_corrections(
                    correction_root,
                    correction_head,
                    invalid_reuse_scan_authorities,
                )
            )
            if invalid_reuse_scan_rows or not any(
                failure.startswith("HISTORY_REUSE_SCAN_CORRECTION_INVALID:")
                for failure in invalid_reuse_scan_correction_failures
            ):
                invalid_reuse_scan_correction_failures = [
                    f"INVALID_REUSE_SCAN_CORRECTION_WAS_APPLIED:{invalid_reuse_scan_rows!r}"
                ]
            else:
                invalid_reuse_scan_correction_failures = []
            mutated_reuse_scan_authorities = copy.deepcopy(reuse_scan_authorities)
            mutated_reuse_scan_authorities["inherited_green"]["stages"][0]["evidence"][0][
                "rationale"
            ] = "Silently rewritten reuse-scan correction evidence."
            mutated_reuse_scan_transition_failures = gate._monotonic_transition_failures(
                reuse_scan_authorities,
                mutated_reuse_scan_authorities,
                "selftest-reuse-scan-correction-mutation",
                [],
            )
            if not any(
                failure.startswith("HISTORY_REUSE_SCAN_CORRECTION_MUTATED:")
                for failure in mutated_reuse_scan_transition_failures
            ):
                mutated_reuse_scan_correction_failures.append(
                    "REUSE_SCAN_CORRECTION_MUTATION_NOT_REJECTED"
                )

            focused_test_id = "v076.focused.scope.selftest"
            focused_transition_authorities = _authorities()
            focused_transition_component = focused_transition_authorities[
                "historical_reuse"
            ]["component_inventory"][0]
            focused_transition_component["focused_test_ids"] = [focused_test_id]
            focused_transition_authorities["inherited_green"][
                "canonical_change_scope"
            ]["focused_tests"] = []
            history_registry_path.write_text(
                json.dumps(
                    focused_transition_authorities["historical_reuse"],
                    ensure_ascii=False,
                    indent=2,
                    sort_keys=True,
                )
                + "\n",
                encoding="utf-8",
            )
            focused_ledger_path = correction_root / (
                "docs/architecture/V076_INHERITED_GREEN_LEDGER.json"
            )
            focused_ledger_path.write_text(
                json.dumps(
                    focused_transition_authorities["inherited_green"],
                    ensure_ascii=False,
                    indent=2,
                    sort_keys=True,
                )
                + "\n",
                encoding="utf-8",
            )
            _git_fixture(correction_root, "add", ".")
            _git_fixture(
                correction_root,
                "commit",
                "-m",
                "declare focused test before canonical scope",
            )
            focused_transition_head = _git_fixture(
                correction_root, "rev-parse", "HEAD"
            )
            focused_transition_tree = _git_fixture(
                correction_root, "rev-parse", "HEAD^{tree}"
            )
            focused_scope_authorities = copy.deepcopy(
                focused_transition_authorities
            )
            focused_scope_authorities["inherited_green"][
                "canonical_change_scope"
            ]["focused_tests"] = [focused_test_id]
            focused_scope_authorities["inherited_green"]["stages"][0][
                "evidence"
            ] = [
                {
                    "evidence_id": "selftest-focused-test-scope-repair",
                    "result": "PASS",
                    "correction_kind": (
                        gate.HISTORY_FOCUSED_TEST_SCOPE_CORRECTION_KIND
                    ),
                    "repair_subject_head_sha": focused_transition_head,
                    "repair_subject_tree_sha": focused_transition_tree,
                    "prior_condition": (
                        "COMPONENT_TEST_DECLARED_BEFORE_CANONICAL_SCOPE"
                    ),
                    "corrected_condition": (
                        "COMPONENT_TEST_PRESENT_IN_CANONICAL_SCOPE"
                    ),
                    "affected_component_ids": [BASE_OWNER_ID],
                    "added_focused_test_ids": [focused_test_id],
                    "affected_failures": [
                        {
                            "head_sha": focused_transition_head,
                            "failure_code": (
                                "HISTORY_PRODUCT_FOCUSED_TESTS_MISSING"
                            ),
                            "component_id": BASE_OWNER_ID,
                        }
                    ],
                    "product_behavior_changed": False,
                    "new_owner_created": False,
                    "rationale": (
                        "Exact focused-test scope metadata repair."
                    ),
                }
            ]
            focused_scope_rows, focused_scope_correction_failures = (
                gate._history_focused_test_scope_corrections(
                    correction_root,
                    focused_transition_head,
                    focused_scope_authorities,
                )
            )
            expected_focused_scope_rows = {
                focused_transition_head: {
                    ("HISTORY_PRODUCT_FOCUSED_TESTS_MISSING", BASE_OWNER_ID)
                }
            }
            if focused_scope_rows != expected_focused_scope_rows:
                focused_scope_correction_failures.append(
                    "FOCUSED_SCOPE_CORRECTION_EXACT_SCOPE_MISMATCH:"
                    f"{focused_scope_rows!r}"
                )
            invalid_focused_scope_authorities = copy.deepcopy(
                focused_scope_authorities
            )
            invalid_focused_scope_authorities["inherited_green"]["stages"][0][
                "evidence"
            ][0]["added_focused_test_ids"] = ["v076.not.executed"]
            invalid_focused_rows, invalid_focused_failures = (
                gate._history_focused_test_scope_corrections(
                    correction_root,
                    focused_transition_head,
                    invalid_focused_scope_authorities,
                )
            )
            if invalid_focused_rows or not any(
                failure.startswith(
                    "HISTORY_FOCUSED_TEST_SCOPE_CORRECTION_INVALID:"
                )
                for failure in invalid_focused_failures
            ):
                invalid_focused_scope_correction_failures.append(
                    "INVALID_FOCUSED_SCOPE_CORRECTION_WAS_APPLIED"
                )
            mutated_focused_scope_authorities = copy.deepcopy(
                focused_scope_authorities
            )
            mutated_focused_scope_authorities["inherited_green"]["stages"][0][
                "evidence"
            ][0]["rationale"] = "Silently rewritten focused scope repair."
            mutated_focused_failures = gate._monotonic_transition_failures(
                focused_scope_authorities,
                mutated_focused_scope_authorities,
                "selftest-focused-scope-correction-mutation",
                [],
            )
            if not any(
                failure.startswith(
                    "HISTORY_FOCUSED_TEST_SCOPE_CORRECTION_MUTATED:"
                )
                for failure in mutated_focused_failures
            ):
                mutated_focused_scope_correction_failures.append(
                    "FOCUSED_SCOPE_CORRECTION_MUTATION_NOT_REJECTED"
                )
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        correction_failures.append(f"CORRECTION_FIXTURE_ERROR:{error}")
        invalid_correction_failures.append(f"CORRECTION_FIXTURE_ERROR:{error}")
        mutated_correction_failures.append(f"CORRECTION_FIXTURE_ERROR:{error}")
        focused_scope_correction_failures.append(
            f"CORRECTION_FIXTURE_ERROR:{error}"
        )
    append_direct_case(
        "115",
        "an exact existing-Owner lifecycle correction names every repairable transition and failure",
        "PASS",
        "PASS" if not correction_failures else "FAIL",
        correction_failures,
    )
    append_direct_case(
        "116",
        "history correction evidence cannot excuse code-before-registry or another failure class",
        "FAIL",
        "FAIL" if invalid_correction_failures else "PASS",
        invalid_correction_failures,
    )
    append_direct_case(
        "117",
        "accepted history classification correction evidence is append-only and immutable",
        "FAIL",
        "FAIL" if not mutated_correction_failures else "PASS",
        mutated_correction_failures
        or ["HISTORY_CLASSIFICATION_CORRECTION_MUTATED"],
    )
    append_direct_case(
        "118",
        "reuse-scan correction is exact, fail-closed, and append-only",
        "PASS",
        "PASS"
        if not (
            reuse_scan_correction_failures
            or invalid_reuse_scan_correction_failures
            or mutated_reuse_scan_correction_failures
        )
        else "FAIL",
        reuse_scan_correction_failures
        + invalid_reuse_scan_correction_failures
        + mutated_reuse_scan_correction_failures,
    )

    pending_cutover = _valid_input()
    pending_cutover.pr_body = (
        _pr_body(pending_cutover)
        + "\n\nProduction cutover still requires separate authorization."
    )
    pending_cutover_report = gate.validate_model(pending_cutover)
    append_direct_case(
        "119",
        "truthful pending cutover prose is not classified as a positive cutover claim",
        "PASS",
        str(pending_cutover_report["status"]),
        [str(value) for value in pending_cutover_report.get("failures", [])],
    )
    append_direct_case(
        "120",
        "focused-test scope repair is exact, executed, fail-closed, and append-only",
        "PASS",
        "PASS"
        if not (
            focused_scope_correction_failures
            or invalid_focused_scope_correction_failures
            or mutated_focused_scope_correction_failures
        )
        else "FAIL",
        focused_scope_correction_failures
        + invalid_focused_scope_correction_failures
        + mutated_focused_scope_correction_failures,
    )

    manifest_valid_failures: list[str] = []
    manifest_identity_negative_failures: list[str] = []
    manifest_target_negative_failures: list[str] = []
    manifest_future_negative_failures: list[str] = []
    try:
        with tempfile.TemporaryDirectory(
            prefix="v076-dynamic-reference-manifest-"
        ) as temp_path:
            manifest_root = Path(temp_path)
            _git_fixture(manifest_root, "init")
            _git_fixture(
                manifest_root, "config", "user.email", "selftest@example.invalid"
            )
            _git_fixture(
                manifest_root, "config", "user.name", "V076 Gate Selftest"
            )
            source_path = "scripts/runtime/manifest_runtime.gd"
            target_paths = sorted(
                [
                    "res://assets/manifest/a.png",
                    "res://assets/manifest/b.png",
                ]
            )
            source_text = (
                "extends RefCounted\n"
                "class_name ManifestRuntime\n"
                'const A_PATH := "res://assets/manifest/a.png"\n'
                'const B_PATH := "res://assets/manifest/b.png"\n'
                "func build():\n"
                "\treturn [_load_optional_texture(A_PATH), "
                "_load_optional_texture(B_PATH)]\n"
                "func _load_optional_texture(path: String):\n"
                "\tif ResourceLoader.exists(path):\n"
                "\t\treturn load(path)\n"
                "\tvar image := Image.new()\n"
                "\tif image.load(path) == OK:\n"
                "\t\treturn ImageTexture.create_from_image(image)\n"
                "\treturn null\n"
            )

            def fixture_location(loader: str) -> tuple[int, int]:
                for line_number, line_text in enumerate(
                    source_text.splitlines(), start=1
                ):
                    needle = "load(path)" if loader == "load" else loader
                    column = line_text.find(needle)
                    if column >= 0:
                        return line_number, column + 1
                raise RuntimeError(f"fixture loader not found: {loader}")

            exists_line, exists_column = fixture_location(
                "ResourceLoader.exists"
            )
            load_line, load_column = fixture_location("load")
            image_line, image_column = fixture_location("image.load")
            source_sha256 = hashlib.sha256(source_text.encode("utf-8")).hexdigest()
            target_sha256 = gate._dynamic_target_set_sha256(target_paths)
            callsite_contract = {
                "helper_function": "_load_optional_texture",
                "required_invocation_count": 2,
                "allowed_argument_constants": ["A_PATH", "B_PATH"],
                "external_or_unknown_invocation_count": 0,
                "required_loader_sites": [
                    {
                        "line": exists_line,
                        "column": exists_column,
                        "loader": "ResourceLoader.exists",
                        "reference_expression": "path",
                    },
                    {
                        "line": load_line,
                        "column": load_column,
                        "loader": "load",
                        "reference_expression": "path",
                    },
                    {
                        "line": image_line,
                        "column": image_column,
                        "loader": "image.load",
                        "reference_expression": "path",
                    },
                ],
            }
            runtime_probe = {
                "probe_id": "manifest_runtime_probe",
                "test_path": "tests/manifest_runtime_probe.gd",
                "expected_target_count": 2,
                "required_before_production_claim": True,
            }
            failure_policy = {
                "source_blob_change_invalidates": True,
                "source_location_change_invalidates": True,
                "target_set_change_invalidates": True,
                "unknown_callsite_fails_closed": True,
                "future_site_auto_resolution_count": 0,
                "wildcard_count": 0,
            }

            def fixture_entry(
                entry_id: str,
                loader: str,
                line: int,
                column: int,
            ) -> dict[str, Any]:
                return {
                    "dynamic_reference_id": entry_id,
                    "source_path": source_path,
                    "source_blob_sha256": source_sha256,
                    "source_line_or_ast_location": {
                        "line": line,
                        "column": column,
                        "containing_function": "_load_optional_texture",
                    },
                    "loader": loader,
                    "reference_expression": "path",
                    "resolved_targets": list(target_paths),
                    "target_set_sha256": target_sha256,
                    "production_reachable": True,
                    "resolution_method": "EXACT_CONSTANT_CALL_GRAPH_MANIFEST",
                    "callsite_contract": copy.deepcopy(callsite_contract),
                    "runtime_probe": copy.deepcopy(runtime_probe),
                    "failure_policy": copy.deepcopy(failure_policy),
                }

            valid_manifest = {
                "schema_version": gate.DYNAMIC_REFERENCE_MANIFEST_SCHEMA,
                "manifest_id": gate.DYNAMIC_REFERENCE_MANIFEST_ID,
                "entries": [
                    fixture_entry(
                        "dynamic.selftest.manifest.exists",
                        "ResourceLoader.exists",
                        exists_line,
                        exists_column,
                    ),
                    fixture_entry(
                        "dynamic.selftest.manifest.load",
                        "load",
                        load_line,
                        load_column,
                    ),
                ],
            }
            fixture_files = {
                "project.godot": (
                    '[application]\nrun/main_scene="res://scenes/main.tscn"\n'
                ),
                "scenes/main.tscn": (
                    '[gd_scene load_steps=2 format=3]\n'
                    '[ext_resource type="Script" '
                    'path="res://scripts/runtime/manifest_runtime.gd" id="1"]\n'
                ),
                source_path: source_text,
                "assets/manifest/a.png": "fixture-a\n",
                "assets/manifest/b.png": "fixture-b\n",
                "tests/manifest_runtime_probe.gd": "extends RefCounted\n",
                gate.DYNAMIC_REFERENCE_MANIFEST_PATH: json.dumps(
                    valid_manifest, ensure_ascii=False, indent=2
                )
                + "\n",
            }
            for relative, payload in fixture_files.items():
                target = manifest_root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(payload.encode("utf-8"))
            _git_fixture(manifest_root, "add", ".")
            _git_fixture(manifest_root, "commit", "-m", "valid exact manifest")
            manifest_head = _git_fixture(manifest_root, "rev-parse", "HEAD")

            def evaluate_manifest(
                manifest_payload: dict[str, Any],
                source_payload: str = source_text,
            ) -> dict[str, Any]:
                (manifest_root / source_path).write_bytes(
                    source_payload.encode("utf-8")
                )
                (manifest_root / gate.DYNAMIC_REFERENCE_MANIFEST_PATH).write_bytes(
                    (
                        json.dumps(
                            manifest_payload, ensure_ascii=False, indent=2
                        )
                        + "\n"
                    ).encode("utf-8")
                )
                return gate._snapshot_reference_closure(
                    manifest_root,
                    manifest_head,
                    ["project.godot"],
                    True,
                )

            valid_result = gate._snapshot_reference_closure(
                manifest_root,
                manifest_head,
                ["project.godot"],
                False,
            )
            if valid_result["dynamic_manifest_failures"]:
                manifest_valid_failures.extend(
                    sorted(valid_result["dynamic_manifest_failures"])
                )
            if any(
                site[0] == source_path for site in valid_result["dynamic_sites"]
            ):
                manifest_valid_failures.append("EXACT_SITE_REMAINED_DYNAMIC")
            expected_reachable = {
                target.removeprefix("res://") for target in target_paths
            }
            if not expected_reachable.issubset(valid_result["reachable"]):
                manifest_valid_failures.append("EXACT_TARGETS_NOT_REACHABLE")

            for label, mutate in (
                (
                    "SOURCE_SHA",
                    lambda row: row.update(
                        {"source_blob_sha256": "0" * 64}
                    ),
                ),
                (
                    "SOURCE_LINE",
                    lambda row: row["source_line_or_ast_location"].update(
                        {"line": exists_line + 1}
                    ),
                ),
                (
                    "LOADER",
                    lambda row: row.update({"loader": "ResourceLoader.load"}),
                ),
                (
                    "EXPRESSION",
                    lambda row: row.update(
                        {"reference_expression": "runtime_path"}
                    ),
                ),
            ):
                invalid = copy.deepcopy(valid_manifest)
                mutate(invalid["entries"][0])
                result = evaluate_manifest(invalid)
                if not result["dynamic_manifest_failures"] or not any(
                    site[0] == source_path
                    and site[1] == "ResourceLoader.exists"
                    for site in result["dynamic_sites"]
                ):
                    manifest_identity_negative_failures.append(
                        f"{label}_DID_NOT_FAIL_CLOSED"
                    )

            bad_hash = copy.deepcopy(valid_manifest)
            bad_hash["entries"][0]["target_set_sha256"] = "0" * 64
            bad_hash_result = evaluate_manifest(bad_hash)
            if not bad_hash_result["dynamic_manifest_failures"]:
                manifest_target_negative_failures.append(
                    "TARGET_HASH_DID_NOT_FAIL_CLOSED"
                )

            wildcard = copy.deepcopy(valid_manifest)
            wildcard_targets = list(wildcard["entries"][0]["resolved_targets"])
            wildcard_targets[0] = "res://assets/manifest/*"
            wildcard_targets.sort()
            wildcard["entries"][0]["resolved_targets"] = wildcard_targets
            wildcard["entries"][0]["target_set_sha256"] = (
                gate._dynamic_target_set_sha256(wildcard_targets)
            )
            wildcard_result = evaluate_manifest(wildcard)
            if not wildcard_result["dynamic_manifest_failures"]:
                manifest_target_negative_failures.append(
                    "TARGET_WILDCARD_DID_NOT_FAIL_CLOSED"
                )

            false_target = copy.deepcopy(valid_manifest)
            false_targets = [
                "res://assets/manifest/b.png",
                "res://tests/manifest_runtime_probe.gd",
            ]
            false_target["entries"][0]["resolved_targets"] = false_targets
            false_target["entries"][0]["target_set_sha256"] = (
                gate._dynamic_target_set_sha256(false_targets)
            )
            false_target_result = evaluate_manifest(false_target)
            if not any(
                "ENTRY_CONSTANT_TARGET_BINDING" in failure
                for failure in false_target_result["dynamic_manifest_failures"]
            ):
                manifest_target_negative_failures.append(
                    "FALSE_TARGET_DID_NOT_FAIL_CLOSED"
                )

            future_source = (
                source_text
                + "func future_load(runtime_path: String):\n"
                + "\treturn load(runtime_path)\n"
            )
            future_manifest = copy.deepcopy(valid_manifest)
            future_sha = hashlib.sha256(
                future_source.encode("utf-8")
            ).hexdigest()
            for entry in future_manifest["entries"]:
                entry["source_blob_sha256"] = future_sha
            future_result = evaluate_manifest(future_manifest, future_source)
            if future_result["dynamic_manifest_failures"] or not any(
                site[0] == source_path
                and site[1] == "load"
                and site[2] == "runtime_path"
                for site in future_result["dynamic_sites"]
            ):
                manifest_future_negative_failures.append(
                    "FUTURE_SITE_WAS_AUTO_RESOLVED:"
                    f"manifest={sorted(future_result['dynamic_manifest_failures'])!r}:"
                    f"sites={sorted(future_result['dynamic_sites'])!r}"
                )

            unknown_source = (
                source_text
                + "func unknown_helper_call(runtime_path: String):\n"
                + "\treturn _load_optional_texture(runtime_path)\n"
            )
            unknown_manifest = copy.deepcopy(valid_manifest)
            unknown_sha = hashlib.sha256(
                unknown_source.encode("utf-8")
            ).hexdigest()
            for entry in unknown_manifest["entries"]:
                entry["source_blob_sha256"] = unknown_sha
            unknown_result = evaluate_manifest(unknown_manifest, unknown_source)
            if not any(
                "ENTRY_CALLSITE_SET" in failure
                for failure in unknown_result["dynamic_manifest_failures"]
            ):
                manifest_future_negative_failures.append(
                    "UNKNOWN_HELPER_CALL_DID_NOT_INVALIDATE"
                )

            missing_probe = copy.deepcopy(valid_manifest)
            missing_probe["entries"][0]["runtime_probe"]["test_path"] = (
                "tests/missing_probe.gd"
            )
            missing_probe_result = evaluate_manifest(missing_probe)
            if not missing_probe_result["dynamic_manifest_failures"]:
                manifest_future_negative_failures.append(
                    "MISSING_RUNTIME_PROBE_DID_NOT_INVALIDATE"
                )

            permissive_policy = copy.deepcopy(valid_manifest)
            permissive_policy["entries"][0]["failure_policy"][
                "future_site_auto_resolution_count"
            ] = 1
            permissive_policy["entries"][0]["failure_policy"][
                "wildcard_count"
            ] = 1
            permissive_policy_result = evaluate_manifest(permissive_policy)
            if not permissive_policy_result["dynamic_manifest_failures"]:
                manifest_future_negative_failures.append(
                    "PERMISSIVE_POLICY_DID_NOT_INVALIDATE"
                )
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        rendered = f"DYNAMIC_MANIFEST_FIXTURE_ERROR:{error}"
        manifest_valid_failures.append(rendered)
        manifest_identity_negative_failures.append(rendered)
        manifest_target_negative_failures.append(rendered)
        manifest_future_negative_failures.append(rendered)

    append_direct_case(
        "121",
        "an exact source-bound dynamic manifest resolves only its declared targets",
        "PASS",
        "PASS" if not manifest_valid_failures else "FAIL",
        manifest_valid_failures,
    )
    append_direct_case(
        "122",
        "dynamic source SHA, line, loader, and expression drift all fail closed",
        "PASS",
        "PASS" if not manifest_identity_negative_failures else "FAIL",
        manifest_identity_negative_failures,
    )
    append_direct_case(
        "123",
        "target hash, wildcard, and false constant target cannot be manifested",
        "PASS",
        "PASS" if not manifest_target_negative_failures else "FAIL",
        manifest_target_negative_failures,
    )
    append_direct_case(
        "124",
        "future sites, unknown callers, missing probes, and permissive policy do not auto-pass",
        "PASS",
        "PASS" if not manifest_future_negative_failures else "FAIL",
        manifest_future_negative_failures,
    )

    # Rule-authority documents stay visible to the rule-change stream, but are
    # not Godot components.  A runtime-loadable card resource remains eligible
    # for component classification so this boundary cannot become a scope
    # reduction in disguise.
    rule_boundary = _valid_input()
    rule_boundary.gate_changed_paths = [
        {"status": "M", "path": "docs/rules/v06_mechanic_status_registry.json"},
    ]
    rule_boundary_report = gate.validate_model(rule_boundary)
    rule_path = "docs/rules/v06_mechanic_status_registry.json"
    runtime_rule_path = "resources/cards/runtime/v076_stage4.tres"
    rule_boundary_failures = [
        str(value) for value in rule_boundary_report.get("failures", [])
    ]
    rule_boundary_green = bool(
        gate._is_rule_authority_path(rule_path)
        and gate._is_non_component_rule_authority_path(rule_path)
        and not gate._is_non_component_rule_authority_path(runtime_rule_path)
        and rule_boundary_report.get("metrics", {}).get("PRODUCT_RULE_CHANGE_COUNT") == 1
        and any(
            value.startswith("TOOLING_GATE_PRODUCT_RULE_CHANGE:")
            for value in rule_boundary_failures
        )
        and not any(
            value in {
                "PRODUCT_DELTA_COMPONENT_CLASSIFICATION_INCOMPLETE",
                "PRODUCT_DELTA_FOCUSED_TESTS_INCOMPLETE",
            }
            for value in rule_boundary_failures
        )
    )
    append_direct_case(
        "125",
        "non-component rule authorities remain scanned while runtime rule resources stay component-eligible",
        "PASS",
        "PASS" if rule_boundary_green else "FAIL",
        rule_boundary_failures,
    )

    provenance_valid_failures: list[str] = []
    provenance_identity_negative_failures: list[str] = []
    provenance_ancestry_negative_failures: list[str] = []
    provenance_anchor_negative_failures: list[str] = []
    provenance_head_ancestry_negative_failures: list[str] = []
    provenance_candidate_negative_failures: list[str] = []
    promotion_top_level_negative_failures: list[str] = []
    promotion_step_evidence_negative_failures: list[str] = []
    try:
        with tempfile.TemporaryDirectory(prefix="v076-golden-provenance-") as temp_path:
            provenance_root = Path(temp_path)
            golden_relative = "docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json"
            golden_path = provenance_root / golden_relative
            golden_path.parent.mkdir(parents=True, exist_ok=True)

            def write_golden(
                candidate: str,
                status: str,
                evidence_candidate: str,
                evidence_tree: str,
            ) -> None:
                golden_path.write_text(
                    json.dumps(
                        {
                            "candidate_head_sha": candidate,
                            "candidate_tree_sha": evidence_tree,
                            "steps": [
                                {
                                    "step_id": "STEP09",
                                    "status": status,
                                    "production_evidence": {
                                        "candidate_head_sha": evidence_candidate,
                                        "candidate_tree_sha": evidence_tree,
                                    },
                                }
                            ],
                        },
                        sort_keys=True,
                    )
                    + "\n",
                    encoding="utf-8",
                )

            _git_fixture(provenance_root, "init", "-b", "main")
            _git_fixture(provenance_root, "config", "user.name", "V076 Gate Selftest")
            _git_fixture(
                provenance_root, "config", "user.email", "v076-gate@example.invalid"
            )
            write_golden("0" * 40, "PENDING", "0" * 40, "0" * 40)
            _git_fixture(provenance_root, "add", ".")
            _git_fixture(provenance_root, "commit", "-m", "activation")
            activation = _git_fixture(provenance_root, "rev-parse", "HEAD")

            write_golden("0" * 40, "PRODUCTION_GREEN", "0" * 40, "0" * 40)
            _git_fixture(provenance_root, "add", golden_relative)
            _git_fixture(provenance_root, "commit", "-m", "green origin")
            origin = _git_fixture(provenance_root, "rev-parse", "HEAD")
            origin_tree = _git_fixture(provenance_root, "show", "-s", "--format=%T", origin)

            write_golden(origin, "PRODUCTION_GREEN", origin, origin_tree)
            _git_fixture(provenance_root, "add", golden_relative)
            _git_fixture(provenance_root, "commit", "-m", "promotion metadata")
            promotion = _git_fixture(provenance_root, "rev-parse", "HEAD")
            promotion_tree = _git_fixture(
                provenance_root, "show", "-s", "--format=%T", promotion
            )

            marker = provenance_root / "affected.txt"
            marker.write_text("affected\n", encoding="utf-8")
            _git_fixture(provenance_root, "add", "affected.txt")
            _git_fixture(provenance_root, "commit", "-m", "affected product change")
            affected = _git_fixture(provenance_root, "rev-parse", "HEAD")
            affected_tree = _git_fixture(
                provenance_root, "show", "-s", "--format=%T", affected
            )

            current_golden = json.loads(golden_path.read_text(encoding="utf-8"))
            current_step = current_golden["steps"][0]
            current_step["status"] = "REGRESSED_WITH_EVIDENCE"
            current_step["regression"] = {
                "failure_evidence": "current-subject revalidation pending",
                "origin_commit": origin,
                "promotion_metadata_commit": promotion,
                "affected_commit": affected,
                "affected_owner": BASE_OWNER_ID,
                "repair_plan": "revalidate the exact subject",
                "prior_status": "PRODUCTION_GREEN",
            }

            def evaluate_provenance(
                value: dict[str, Any], evaluated_head: str = affected
            ) -> tuple[dict[str, Any], list[str]]:
                return gate.golden_regression_provenance(
                    provenance_root,
                    evaluated_head,
                    golden_relative,
                    value,
                    provenance_ancestry_anchor=activation,
                )

            valid_provenance, valid_failures = evaluate_provenance(current_golden)
            if valid_failures or valid_provenance.get("STEP09", {}).get("valid") is not True:
                provenance_valid_failures.extend(valid_failures or ["VALID_PROVENANCE_REJECTED"])

            wrong_step = copy.deepcopy(current_golden)
            wrong_step["steps"][0]["step_id"] = "STEP_WRONG"
            _, wrong_step_failures = evaluate_provenance(wrong_step)
            if not any("ORIGIN_STEP_NOT_GREEN" in value for value in wrong_step_failures):
                provenance_identity_negative_failures.append("WRONG_STEP_ACCEPTED")

            wrong_prior = copy.deepcopy(current_golden)
            wrong_prior["steps"][0]["regression"]["prior_status"] = "ISOLATED_GREEN"
            _, wrong_prior_failures = evaluate_provenance(wrong_prior)
            if not any("PRIOR_STATUS_MISMATCH" in value for value in wrong_prior_failures):
                provenance_identity_negative_failures.append("WRONG_PRIOR_ACCEPTED")

            late_origin = copy.deepcopy(current_golden)
            late_origin["steps"][0]["regression"]["origin_commit"] = affected
            _, late_origin_failures = evaluate_provenance(late_origin)
            if not any("ORIGIN_NOT_STRICT_ANCESTOR" in value for value in late_origin_failures):
                provenance_ancestry_negative_failures.append("LATE_ORIGIN_ACCEPTED")

            late_promotion = copy.deepcopy(current_golden)
            late_promotion["steps"][0]["regression"][
                "promotion_metadata_commit"
            ] = affected
            _, late_promotion_failures = evaluate_provenance(late_promotion)
            if not any(
                "PROMOTION_NOT_STRICTLY_BETWEEN" in value
                for value in late_promotion_failures
            ):
                provenance_ancestry_negative_failures.append("LATE_PROMOTION_ACCEPTED")

            _git_fixture(provenance_root, "switch", "-c", "side", activation)
            write_golden("0" * 40, "PRODUCTION_GREEN", "0" * 40, "0" * 40)
            _git_fixture(provenance_root, "add", golden_relative)
            _git_fixture(provenance_root, "commit", "-m", "non ancestor origin")
            side_origin = _git_fixture(provenance_root, "rev-parse", "HEAD")
            side_tree = _git_fixture(
                provenance_root, "show", "-s", "--format=%T", side_origin
            )
            _git_fixture(provenance_root, "switch", "main")
            non_ancestor = copy.deepcopy(current_golden)
            non_ancestor_step = non_ancestor["steps"][0]
            non_ancestor_step["regression"]["origin_commit"] = side_origin
            non_ancestor_step["production_evidence"]["candidate_head_sha"] = side_origin
            non_ancestor_step["production_evidence"]["candidate_tree_sha"] = side_tree
            _, non_ancestor_failures = evaluate_provenance(non_ancestor)
            if not any("ORIGIN_NOT_STRICT_ANCESTOR" in value for value in non_ancestor_failures):
                provenance_ancestry_negative_failures.append("NON_ANCESTOR_ACCEPTED")

            outside_anchor_origin = _git_fixture(
                provenance_root,
                "commit-tree",
                origin_tree,
                "-m",
                "origin outside branch-local ancestry anchor",
            )
            outside_anchor = copy.deepcopy(current_golden)
            outside_anchor_step = outside_anchor["steps"][0]
            outside_anchor_step["regression"]["origin_commit"] = outside_anchor_origin
            outside_anchor_step["production_evidence"][
                "candidate_head_sha"
            ] = outside_anchor_origin
            _, outside_anchor_failures = evaluate_provenance(outside_anchor)
            if not any(
                "ORIGIN_NOT_PROVENANCE_ANCHOR_DESCENDANT" in value
                for value in outside_anchor_failures
            ):
                provenance_anchor_negative_failures.append(
                    "OUTSIDE_ANCHOR_ORIGIN_ACCEPTED"
                )

            side_promotion = _git_fixture(
                provenance_root,
                "commit-tree",
                promotion_tree,
                "-p",
                origin,
                "-m",
                "promotion outside evaluated Head ancestry",
            )
            promotion_outside_head = copy.deepcopy(current_golden)
            promotion_outside_head["steps"][0]["regression"][
                "promotion_metadata_commit"
            ] = side_promotion
            _, promotion_outside_head_failures = evaluate_provenance(
                promotion_outside_head
            )
            if not any(
                "PROMOTION_NOT_PROVENANCE_ANCHOR_TO_HEAD_ANCESTRY" in value
                for value in promotion_outside_head_failures
            ):
                provenance_head_ancestry_negative_failures.append(
                    "PROMOTION_OUTSIDE_HEAD_ACCEPTED"
                )

            side_affected = _git_fixture(
                provenance_root,
                "commit-tree",
                affected_tree,
                "-p",
                promotion,
                "-m",
                "affected commit outside evaluated Head ancestry",
            )
            affected_outside_head = copy.deepcopy(current_golden)
            affected_outside_head["steps"][0]["regression"][
                "affected_commit"
            ] = side_affected
            _, affected_outside_head_failures = evaluate_provenance(
                affected_outside_head
            )
            if not any(
                "AFFECTED_COMMIT_NOT_HEAD_ANCESTOR" in value
                for value in affected_outside_head_failures
            ):
                provenance_head_ancestry_negative_failures.append(
                    "AFFECTED_OUTSIDE_HEAD_ACCEPTED"
                )

            stale_sha = copy.deepcopy(current_golden)
            stale_sha["steps"][0]["production_evidence"]["candidate_head_sha"] = "f" * 40
            _, stale_sha_failures = evaluate_provenance(stale_sha)
            if not any("STALE_CANDIDATE_SHA" in value for value in stale_sha_failures):
                provenance_candidate_negative_failures.append("STALE_SHA_ACCEPTED")

            stale_tree = copy.deepcopy(current_golden)
            stale_tree["steps"][0]["production_evidence"]["candidate_tree_sha"] = "f" * 40
            _, stale_tree_failures = evaluate_provenance(stale_tree)
            if not any("STALE_CANDIDATE_TREE" in value for value in stale_tree_failures):
                provenance_candidate_negative_failures.append("STALE_TREE_ACCEPTED")

            _git_fixture(provenance_root, "switch", "-c", "wrong-top-tree", origin)
            write_golden(origin, "PRODUCTION_GREEN", origin, origin_tree)
            wrong_top_tree_snapshot = json.loads(
                golden_path.read_text(encoding="utf-8")
            )
            wrong_top_tree_snapshot["candidate_tree_sha"] = "f" * 40
            golden_path.write_text(
                json.dumps(wrong_top_tree_snapshot, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            _git_fixture(provenance_root, "add", golden_relative)
            _git_fixture(
                provenance_root, "commit", "-m", "wrong promotion top-level tree"
            )
            wrong_top_tree_promotion = _git_fixture(
                provenance_root, "rev-parse", "HEAD"
            )
            wrong_top_tree_marker = provenance_root / "wrong-top-tree-affected.txt"
            wrong_top_tree_marker.write_text("affected\n", encoding="utf-8")
            _git_fixture(
                provenance_root, "add", "wrong-top-tree-affected.txt"
            )
            _git_fixture(
                provenance_root, "commit", "-m", "wrong top tree affected change"
            )
            wrong_top_tree_affected = _git_fixture(
                provenance_root, "rev-parse", "HEAD"
            )
            wrong_top_tree_current = copy.deepcopy(wrong_top_tree_snapshot)
            wrong_top_tree_current_step = wrong_top_tree_current["steps"][0]
            wrong_top_tree_current_step["status"] = "REGRESSED_WITH_EVIDENCE"
            wrong_top_tree_current_step["regression"] = {
                "failure_evidence": "wrong top-level tree fixture",
                "origin_commit": origin,
                "promotion_metadata_commit": wrong_top_tree_promotion,
                "affected_commit": wrong_top_tree_affected,
                "affected_owner": BASE_OWNER_ID,
                "repair_plan": "reject the malformed promotion snapshot",
                "prior_status": "PRODUCTION_GREEN",
            }
            _, wrong_top_tree_failures = evaluate_provenance(
                wrong_top_tree_current, wrong_top_tree_affected
            )
            if not any(
                "PROMOTION_TOP_LEVEL_CANDIDATE_TREE_MISMATCH" in value
                for value in wrong_top_tree_failures
            ):
                promotion_top_level_negative_failures.append(
                    "WRONG_PROMOTION_TOP_LEVEL_TREE_ACCEPTED"
                )

            _git_fixture(provenance_root, "switch", "main")
            _git_fixture(
                provenance_root, "switch", "-c", "wrong-step-evidence", origin
            )
            write_golden(origin, "PRODUCTION_GREEN", origin, origin_tree)
            wrong_step_evidence_snapshot = json.loads(
                golden_path.read_text(encoding="utf-8")
            )
            wrong_step_promotion_evidence = wrong_step_evidence_snapshot["steps"][0][
                "production_evidence"
            ]
            wrong_step_promotion_evidence["candidate_head_sha"] = "f" * 40
            wrong_step_promotion_evidence["candidate_tree_sha"] = "e" * 40
            golden_path.write_text(
                json.dumps(wrong_step_evidence_snapshot, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            _git_fixture(provenance_root, "add", golden_relative)
            _git_fixture(
                provenance_root, "commit", "-m", "wrong promotion step evidence"
            )
            wrong_step_evidence_promotion = _git_fixture(
                provenance_root, "rev-parse", "HEAD"
            )
            wrong_step_evidence_marker = (
                provenance_root / "wrong-step-evidence-affected.txt"
            )
            wrong_step_evidence_marker.write_text("affected\n", encoding="utf-8")
            _git_fixture(
                provenance_root, "add", "wrong-step-evidence-affected.txt"
            )
            _git_fixture(
                provenance_root, "commit", "-m", "wrong step evidence affected change"
            )
            wrong_step_evidence_affected = _git_fixture(
                provenance_root, "rev-parse", "HEAD"
            )
            wrong_step_evidence_current = copy.deepcopy(
                wrong_step_evidence_snapshot
            )
            wrong_step_evidence_current_step = wrong_step_evidence_current["steps"][0]
            wrong_step_evidence_current_step["status"] = "REGRESSED_WITH_EVIDENCE"
            wrong_step_evidence_current_step["production_evidence"] = {
                "candidate_head_sha": origin,
                "candidate_tree_sha": origin_tree,
            }
            wrong_step_evidence_current_step["regression"] = {
                "failure_evidence": "wrong step evidence fixture",
                "origin_commit": origin,
                "promotion_metadata_commit": wrong_step_evidence_promotion,
                "affected_commit": wrong_step_evidence_affected,
                "affected_owner": BASE_OWNER_ID,
                "repair_plan": "reject the malformed promotion snapshot",
                "prior_status": "PRODUCTION_GREEN",
            }
            _, wrong_step_evidence_failures = evaluate_provenance(
                wrong_step_evidence_current, wrong_step_evidence_affected
            )
            if not any(
                "PROMOTION_STEP_EVIDENCE_SHA_MISMATCH" in value
                for value in wrong_step_evidence_failures
            ):
                promotion_step_evidence_negative_failures.append(
                    "WRONG_PROMOTION_STEP_EVIDENCE_SHA_ACCEPTED"
                )
            if not any(
                "PROMOTION_STEP_EVIDENCE_TREE_MISMATCH" in value
                for value in wrong_step_evidence_failures
            ):
                promotion_step_evidence_negative_failures.append(
                    "WRONG_PROMOTION_STEP_EVIDENCE_TREE_ACCEPTED"
                )
            _git_fixture(provenance_root, "switch", "main")
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        rendered = f"GOLDEN_PROVENANCE_FIXTURE_ERROR:{error}"
        provenance_valid_failures.append(rendered)
        provenance_identity_negative_failures.append(rendered)
        provenance_ancestry_negative_failures.append(rendered)
        provenance_anchor_negative_failures.append(rendered)
        provenance_head_ancestry_negative_failures.append(rendered)
        provenance_candidate_negative_failures.append(rendered)
        promotion_top_level_negative_failures.append(rendered)
        promotion_step_evidence_negative_failures.append(rendered)

    real_chain_failures: list[str] = []
    try:
        repository_root = SCRIPT_DIR.parents[1]
        real_golden_path = (
            "docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json"
        )
        real_origin = "f8340207d785e7b35ea7451048e5d71d0325232c"
        real_promotion = "3bf9e9b2468e4a279af47cd3be36d0660abcfe91"
        real_affected = "ce3b644dedaa752b09e97fadf3c7880889ea7e9f"
        real_promotion_snapshot = gate._git_json_at(
            repository_root, real_promotion, real_golden_path
        )
        if not isinstance(real_promotion_snapshot, dict):
            real_chain_failures.append("REAL_PROMOTION_SNAPSHOT_MISSING")
        else:
            real_current = copy.deepcopy(real_promotion_snapshot)
            real_steps = gate._index(real_current.get("steps", []), "step_id")
            for real_step_id in ("STEP09", "STEP11", "STEP12"):
                real_step = real_steps.get(real_step_id)
                if not isinstance(real_step, dict):
                    real_chain_failures.append(
                        f"REAL_PROMOTION_STEP_MISSING:{real_step_id}"
                    )
                    continue
                real_step["status"] = "REGRESSED_WITH_EVIDENCE"
                real_step["regression"] = {
                    "failure_evidence": "real-chain selftest revalidation",
                    "origin_commit": real_origin,
                    "promotion_metadata_commit": real_promotion,
                    "affected_commit": real_affected,
                    "affected_owner": BASE_OWNER_ID,
                    "repair_plan": "retain exact historical provenance",
                    "prior_status": "PRODUCTION_GREEN",
                }
            real_result, real_failures = gate.golden_regression_provenance(
                repository_root,
                "HEAD",
                real_golden_path,
                real_current,
                provenance_ancestry_anchor=gate.V076_GATE_BASE_SHA,
                label="REAL_F834_3BF_CE3",
            )
            real_chain_failures.extend(real_failures)
            for real_step_id in ("STEP09", "STEP11", "STEP12"):
                if real_result.get(real_step_id, {}).get("valid") is not True:
                    real_chain_failures.append(
                        f"REAL_CHAIN_STEP_REJECTED:{real_step_id}"
                    )
            if gate._is_ancestor(
                repository_root, gate.ACTIVATION_BOUNDARY_COMMIT, real_origin
            ):
                real_chain_failures.append(
                    "EXTERNAL_ACTIVATION_MISTAKEN_FOR_BRANCH_ANCESTRY"
                )
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        real_chain_failures.append(f"REAL_GOLDEN_PROVENANCE_ERROR:{error}")

    append_direct_case(
        "126",
        "Golden regression binds distinct green-origin and promotion-metadata commits",
        "PASS",
        "PASS" if not provenance_valid_failures else "FAIL",
        provenance_valid_failures,
    )
    append_direct_case(
        "127",
        "wrong Golden step and wrong prior status fail closed",
        "FAIL",
        "FAIL" if not provenance_identity_negative_failures else "PASS",
        provenance_identity_negative_failures,
    )
    append_direct_case(
        "128",
        "late or non-ancestor origin and promotion commits fail closed",
        "FAIL",
        "FAIL" if not provenance_ancestry_negative_failures else "PASS",
        provenance_ancestry_negative_failures,
    )
    append_direct_case(
        "129",
        "stale Golden candidate SHA and tree fail closed",
        "FAIL",
        "FAIL" if not provenance_candidate_negative_failures else "PASS",
        provenance_candidate_negative_failures,
    )

    quoted_extends_failures: list[str] = []
    try:
        with tempfile.TemporaryDirectory(prefix="v076-quoted-extends-") as temp_path:
            closure_root = Path(temp_path)
            _git_fixture(closure_root, "init", "-b", "main")
            _git_fixture(closure_root, "config", "user.name", "V076 Gate Selftest")
            _git_fixture(
                closure_root, "config", "user.email", "v076-gate@example.invalid"
            )
            scripts = closure_root / "scripts"
            scripts.mkdir(parents=True, exist_ok=True)
            (scripts / "base.gd").write_text("extends RefCounted\n", encoding="utf-8")
            (scripts / "child.gd").write_text(
                'extends "res://scripts/base.gd"\n# extends "res://scripts/ignored.gd"\n',
                encoding="utf-8",
            )
            _git_fixture(closure_root, "add", ".")
            _git_fixture(closure_root, "commit", "-m", "quoted extends fixture")
            closure = gate._snapshot_reference_closure(
                closure_root, "HEAD", ["scripts/child.gd"], False
            )["reachable"]
            if not {"scripts/child.gd", "scripts/base.gd"}.issubset(set(closure)):
                quoted_extends_failures.append(f"QUOTED_EXTENDS_MISSING:{sorted(closure)}")
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        quoted_extends_failures.append(f"QUOTED_EXTENDS_FIXTURE_ERROR:{error}")
    append_direct_case(
        "130",
        "quoted GDScript extends participates in the production reference closure",
        "PASS",
        "PASS" if not quoted_extends_failures else "FAIL",
        quoted_extends_failures,
    )

    anonymous_path = BASE_OWNER_PATH
    anonymous_identity = gate._anonymous_path_bound_identity(anonymous_path)

    def configure_component_identity(
        data: gate.ValidationInput, class_identity: str, declared_identity: str
    ) -> None:
        for authority_set in (data.authorities, data.baseline_authorities):
            component = authority_set["historical_reuse"]["component_inventory"][0]
            component["class_name"] = class_identity
            authority_set["historical_reuse"]["unique_owner_domains"][0][
                "unique_owner"
            ] = class_identity
        data.component_declared_classes = {anonymous_path: declared_identity}

    anonymous_valid = _valid_input()
    configure_component_identity(anonymous_valid, anonymous_identity, anonymous_identity)
    anonymous_valid_report = gate.validate_model(anonymous_valid)
    append_direct_case(
        "131",
        "an anonymous GDScript uses an explicit normalized path-bound identity",
        "PASS",
        str(anonymous_valid_report["status"]),
        [str(value) for value in anonymous_valid_report.get("failures", [])],
    )

    anonymous_negative_failures: list[str] = []
    declared_as_anonymous = _valid_input()
    configure_component_identity(
        declared_as_anonymous, anonymous_identity, "V076SelftestOwner"
    )
    declared_report = gate.validate_model(declared_as_anonymous)
    if not any(
        value.startswith("COMPONENT_CLASS_DECLARATION_MISMATCH:")
        for value in declared_report.get("failures", [])
    ):
        anonymous_negative_failures.append("DECLARED_CLASS_ACCEPTED_SENTINEL")

    fabricated_class = _valid_input()
    configure_component_identity(fabricated_class, "MonsterArtView", anonymous_identity)
    fabricated_report = gate.validate_model(fabricated_class)
    if not any(
        value.startswith("COMPONENT_CLASS_DECLARATION_MISMATCH:")
        for value in fabricated_report.get("failures", [])
    ):
        anonymous_negative_failures.append("ANONYMOUS_SCRIPT_ACCEPTED_FAKE_CLASS")

    for label, wrong_identity in (
        ("WRONG_PATH", gate._anonymous_path_bound_identity("scripts/wrong.gd")),
        ("CASE_DRIFT", anonymous_identity.replace("scripts/", "Scripts/", 1)),
    ):
        wrong_path_bound = _valid_input()
        configure_component_identity(
            wrong_path_bound, wrong_identity, anonymous_identity
        )
        wrong_report = gate.validate_model(wrong_path_bound)
        if not any(
            "ANONYMOUS_PATH_IDENTITY_INVALID" in value
            for value in wrong_report.get("failures", [])
        ):
            anonymous_negative_failures.append(f"{label}_SENTINEL_ACCEPTED")
    append_direct_case(
        "132",
        "declared, fabricated, wrong-path, and case-drift anonymous identities fail closed",
        "FAIL",
        "FAIL" if not anonymous_negative_failures else "PASS",
        anonymous_negative_failures,
    )
    append_direct_case(
        "133",
        "a promotion snapshot with the wrong top-level candidate tree fails closed",
        "FAIL",
        "FAIL" if not promotion_top_level_negative_failures else "PASS",
        promotion_top_level_negative_failures,
    )
    append_direct_case(
        "134",
        "a promotion snapshot with wrong step production-evidence SHA and tree fails closed",
        "FAIL",
        "FAIL" if not promotion_step_evidence_negative_failures else "PASS",
        promotion_step_evidence_negative_failures,
    )
    external_activation_drift = _valid_input()
    external_activation_drift.authorities["inherited_green"][
        "gate_activation_boundary_commit"
    ] = "f" * 40
    external_activation_drift_report = gate.validate_model(external_activation_drift)
    append_direct_case(
        "135",
        "the external PR90 activation evidence identity remains exact",
        "FAIL",
        str(external_activation_drift_report["status"]),
        [
            str(value)
            for value in external_activation_drift_report.get("failures", [])
        ],
    )
    append_direct_case(
        "136",
        "a Golden origin outside the branch-local provenance anchor fails closed",
        "FAIL",
        "FAIL" if not provenance_anchor_negative_failures else "PASS",
        provenance_anchor_negative_failures,
    )
    append_direct_case(
        "137",
        "promotion and affected commits outside the evaluated Head ancestry fail closed",
        "FAIL",
        "FAIL" if not provenance_head_ancestry_negative_failures else "PASS",
        provenance_head_ancestry_negative_failures,
    )
    append_direct_case(
        "138",
        "the real f834 origin, 3bf promotion, and ce3 affected chain uses the branch-local Gate base",
        "PASS",
        "PASS" if not real_chain_failures else "FAIL",
        real_chain_failures,
    )

    historical_reducer = _historical_owner_to_reducer_fixture()
    historical_reducer_report = gate.validate_model(historical_reducer)
    append_direct_case(
        "139",
        "the exact PlayerMana historical Owner to current V07 reducer transition passes",
        "PASS",
        str(historical_reducer_report.get("status", "FAIL")),
        [str(value) for value in historical_reducer_report.get("failures", [])],
    )

    def append_historical_reducer_negative(
        case_id: str,
        description: str,
        mutate: Callable[[gate.ValidationInput], None],
        expected_failure_prefix: str,
    ) -> None:
        candidate = _historical_owner_to_reducer_fixture()
        mutate(candidate)
        candidate_report = gate.validate_model(candidate)
        candidate_failures = [
            str(value) for value in candidate_report.get("failures", [])
        ]
        rejected_for_expected_reason = bool(
            candidate_report.get("status") == "FAIL"
            and any(
                value.startswith(expected_failure_prefix)
                for value in candidate_failures
            )
        )
        append_direct_case(
            case_id,
            description,
            "FAIL",
            "FAIL" if rejected_for_expected_reason else "PASS",
            candidate_failures,
        )

    evidence_id = "historical.player-mana-to-v07-asset-batch-core"
    append_historical_reducer_negative(
        "140",
        "a bool cannot impersonate the exact current closure failure count",
        lambda data: data.historical_owner_to_reducer_cutover_evidence[
            evidence_id
        ].__setitem__("current_reference_closure_failure_count", False),
        f"HISTORICAL_REDUCER_SUPERSESSION:{evidence_id}:CURRENT_CLOSURE_INVALID",
    )
    append_historical_reducer_negative(
        "141",
        "historical source blob evidence is bound to the exact retained source",
        lambda data: data.historical_owner_to_reducer_cutover_evidence[
            evidence_id
        ].__setitem__("old_source_blob_sha256", "0" * 64),
        f"HISTORICAL_REDUCER_SUPERSESSION:{evidence_id}:SOURCE_BINDING_MISMATCH",
    )
    append_historical_reducer_negative(
        "142",
        "the historical PlayerMana identity requires exactly one backfill row",
        lambda data: data.authorities["historical_reuse"].__setitem__(
            "historical_identity_backfill", []
        ),
        f"HISTORICAL_REDUCER_SUPERSESSION:{evidence_id}:BACKFILL_NOT_UNIQUE",
    )
    append_historical_reducer_negative(
        "143",
        "the current V07 asset component must remain a reachable writing reducer",
        lambda data: data.authorities["historical_reuse"][
            "component_inventory"
        ][1].__setitem__("component_role", "CONSUMER"),
        f"HISTORICAL_REDUCER_SUPERSESSION:{evidence_id}:NEW_REDUCER_STATE_INVALID",
    )
    append_historical_reducer_negative(
        "144",
        "the current reducer must bind to the one same-domain production Owner",
        lambda data: data.authorities["historical_reuse"][
            "component_inventory"
        ][0].__setitem__("owner_path", "scripts/wrong/runtime_owner.gd"),
        f"HISTORICAL_REDUCER_SUPERSESSION:{evidence_id}:NEW_OWNER_BINDING_INVALID",
    )
    append_historical_reducer_negative(
        "145",
        "the atomic cutover manifest must retain its exact committed hash",
        lambda data: data.historical_owner_to_reducer_cutover_evidence[
            evidence_id
        ].__setitem__("cutover_manifest_sha256", "0" * 64),
        f"HISTORICAL_REDUCER_SUPERSESSION:{evidence_id}:CUTOVER_EVIDENCE_INVALID",
    )

    pass_count = sum(result["status"] == "PASS" for result in results)
    case_count = len(results)
    status = (
        "PASS"
        if case_count >= 30
        and pass_count == case_count
        and false_green_count == 0
        and valid_false_reject_count == 0
        else "FAIL"
    )
    return {
        "schema_version": SELFTEST_SCHEMA,
        "check_name": gate.CHECK_NAME,
        "REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS": status,
        "REUSE_POINT_INERTIA_GATE_SELFTEST_CASE_COUNT": case_count,
        "REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT": pass_count,
        "FALSE_GREEN_COUNT": false_green_count,
        "VALID_DELTA_FALSE_REJECT_COUNT": valid_false_reject_count,
        "CASE_FAILURE_COUNT": case_count - pass_count,
        "VALID_DELTA_CASE_COUNT": sum(
            result.get("expected_status") == "PASS" for result in results
        ),
        "INVALID_DELTA_CASE_COUNT": sum(
            result.get("expected_status") == "FAIL" for result in results
        ),
        "fixture_model": "ValidationInput->validate_model",
        "godot_execution_count": 0,
        "repository_mutation_count": 0,
        "gate_implementation_sha256": hashlib.sha256(
            Path(gate.__file__).read_bytes()
        ).hexdigest(),
        "selftest_script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "cases": results,
    }


def main() -> int:
    receipt = run_selftest()
    print(json.dumps(receipt, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if receipt["REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
