"""Build the exact V076 historical-delta Registry successor and evidence inputs.

This tool never changes Raw scanner output.  Its Registry repair mode accepts
only the sealed 7b2bd08a Raw report and the exact three Registry-only
transitions that introduced 82 historical component rows.  It preserves every
row field except ``change_class`` and the four explicitly authorized
``reuse_scan`` objects, and it can write only the canonical Registry path
inside the selected project.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
from pathlib import Path
from typing import Any


SEALED_RAW_SHA256 = "28c3bb657b20f4d2e7f2eee14f1677d5bf5feb678883fe2f400ca54b89c629b0"
SEALED_RAW_HEAD = "7b2bd08a9916a3a517f2d418765c544cce0261cc"
SEALED_RAW_TREE = "990b070c3f7cfefa3bf6853ff22f9023049ede29"
SEALED_RAW_FAILURE_COUNT = 590
HISTORICAL_DELTA_FAILURE_COUNT = 86
HISTORICAL_DELTA_COMPONENT_COUNT = 82
HISTORICAL_DELTA_TRANSITION_COUNT = 3
HISTORICAL_DELTA_RAW_SET_SHA256 = (
    "fc2c8d9d8ac8cee1db457eb583b568c537d8feebf63ce6a77b6b1c4f40e45c00"
)
HISTORICAL_DELTA_COMPONENT_SET_SHA256 = (
    "f05bac67fea5ae37e96fd75a0907eb0daa7a67352cdb5a5b06f90fe22bcd1a17"
)
HISTORICAL_DELTA_TRANSITION_SET_SHA256 = (
    "1203a54e548887d49ace10713cce426b5e285a41a637436a16728d2f34abdde7"
)

REGISTRY_REL = Path("docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json")
SCHEMA_REL = Path("docs/architecture/V076_HISTORICAL_DELTA_METADATA_SCHEMA.json")
LEDGER_REL = Path("docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json")
SCANNER_REL = Path("tools/v076/v076_reuse_point_inertia_gate.py")
RAW_COPY_REL = Path(
    "reports/reuse/correction_v2/epochs/full_convergence_20260827/"
    "v076_current_7b2bd08a_raw.json"
)
CORRECTION_ROOT_REL = Path(
    "docs/architecture/reuse_corrections/v2/records/"
    "full_convergence_20260827/historical_delta_metadata"
)
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
AUTHORIZATION_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
REPAIRED_REGISTRY_SHA256 = (
    "88b0c8e22772849912c9449a5f5bf12df86c32d09516cca0bd0e85f7e0f4117d"
)
RAW_NATIVE_HISTORICAL_COUNT = 505
RAW_LEDGER_PROMOTED_COUNT = 82
RAW_SEMANTIC_HISTORICAL_COUNT = 587
RAW_TRUE_CURRENT_COUNT = 3
LEDGER_SCHEMA_VERSION = "space_syndicate.v076.historical_delta_metadata_ledger.v1"
METADATA_RECORD_SCHEMA_VERSION = "space_syndicate.v076.historical_delta_metadata_record.v1"
CORRECTION_RECORD_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "historical_delta_metadata_record.v1"
)
SCHEMA_DOCUMENT_VERSION = "space_syndicate.v076.historical_delta_metadata_schema.v1"
LEDGER_ID = "V076_HISTORICAL_DELTA_METADATA_LEDGER"
NEW_COMPONENT_RULE = "NEW_COMPONENT_CANNOT_CLAIM_INHERITED"
NEW_AUTHORITY_RULE = "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID"
ALLOWED_FAILURE_RULES = {NEW_COMPONENT_RULE, NEW_AUTHORITY_RULE}
TRANSITION_PREFIXES = {
    "70d4aa119da8->5af52a5bfe4f",
    "a99246f1b478->488c21f5d9e5",
    "89c4089d1817->8e6ce3e609e0",
}

EXACT_SELECTOR_POLICY = {
    "match_mode": "EXACT_FAILURE_FINGERPRINTS_ONLY",
    "wildcard_allowed": False,
    "regex_allowed": False,
    "path_prefix_allowed": False,
    "branch_selector_allowed": False,
    "date_selector_allowed": False,
    "future_failure_auto_match": False,
}
TOUCH_INVALIDATION_POLICY = {
    "path_touch_invalidates": True,
    "blob_change_invalidates": True,
    "component_change_invalidates": True,
    "domain_change_invalidates": True,
    "owner_change_invalidates": True,
    "production_reachability_change_invalidates": True,
    "supersession_change_invalidates": True,
    "retirement_change_invalidates": True,
    "unrelated_delta_preserves": True,
}
FUTURE_FAILURE_POLICY = {
    "automatic_match": False,
    "new_failure_requires_new_record": True,
}
TRANSITION_CLASS_BY_RULE = {
    NEW_COMPONENT_RULE: "HISTORICAL_COMPONENT_IDENTITY_METADATA_BACKFILL",
    NEW_AUTHORITY_RULE: "HISTORICAL_AUTHORITY_REUSE_SCAN_METADATA_BACKFILL",
}

LEDGER_FIELDS = {
    "schema_version",
    "ledger_id",
    "authorization_id",
    "authorization_base_head_sha",
    "schema_path",
    "schema_sha256",
    "raw_report_path",
    "raw_report_sha256",
    "raw_report_head_sha",
    "raw_report_tree_sha",
    "scanner_path",
    "scanner_sha256",
    "registry_path",
    "selector_policy",
    "record_count",
    "records",
    "failure_count",
    "failure_fingerprint_set_sha256",
    "correction_record_count",
    "correction_record_bindings",
    "corrected_failure_count",
    "previous_ledger_path",
    "previous_ledger_sha256",
    "append_only",
    "ledger_payload_sha256",
}
METADATA_RECORD_FIELDS = {
    "schema_version",
    "record_id",
    "source_commit",
    "parent_commit",
    "commit_tree",
    "parent_tree",
    "registry_path",
    "source_registry_sha256",
    "parent_registry_sha256",
    "change_class",
    "affected_domains",
    "affected_owners",
    "focused_tests",
    "historical_context",
    "current_disposition",
    "selector_policy",
    "reuse_scan_component_ids",
    "failure_count",
    "failure_fingerprint_set_sha256",
    "failure_bindings",
    "previous_record_payload_sha256",
    "record_payload_sha256",
}
FAILURE_BINDING_FIELDS = {
    "failure_fingerprint",
    "raw_failure",
    "rule_id",
    "component_id",
    "source_component_sha256",
    "current_component_sha256",
    "source_component_path",
    "current_component_path",
    "source_path_blob_sha256",
    "current_path_blob_sha256",
    "source_domain_id",
    "source_domain_sha256",
    "current_domain_sha256",
    "source_owner_component_id",
    "current_owner_component_id",
    "source_owner_component_sha256",
    "current_owner_component_sha256",
    "source_owner_path",
    "current_owner_path",
    "source_owner_path_blob_sha256",
    "current_owner_path_blob_sha256",
    "source_production_reachability",
}
CORRECTION_BINDING_FIELDS = {
    "correction_id",
    "path",
    "file_sha256",
    "record_payload_sha256",
    "failure_count",
    "failure_fingerprints",
}
CORRECTION_RECORD_FIELDS = {
    "schema_version",
    "record_kind",
    "correction_id",
    "ledger_id",
    "metadata_record_ids",
    "authorization_id",
    "authorization_base_head_sha",
    "raw_report_sha256",
    "raw_report_head_sha",
    "rule_id",
    "transition_class_id",
    "source_commit",
    "parent_commit",
    "component_ids",
    "component_set_sha256",
    "failure_count",
    "failure_fingerprints",
    "failure_fingerprint_set_sha256",
    "selector_policy",
    "from_state",
    "to_effective_disposition",
    "untouched_in_current_delta",
    "touch_invalidation_policy",
    "future_failure_policy",
    "backlog_item_ids",
    "previous_correction_payload_sha256",
    "record_payload_sha256",
}
REUSE_SCAN_FIELDS = {
    "reuse_registry_search",
    "class_name_search",
    "semantic_signature_search",
    "owner_map_search",
    "state_write_surface_search",
    "rng_owner_search",
    "save_owner_search",
    "replay_owner_search",
    "signal_and_receipt_search",
    "reuse_candidate_count",
    "reuse_candidate_ids",
    "selected_reuse_disposition",
    "why_existing_owner_cannot_be_extended",
    "why_adapter_is_insufficient",
    "why_new_owner_is_required",
}

TRANSITION_SPECS = (
    {
        "transition": "70d4aa119da8->5af52a5bfe4f",
        "source": "5af52a5bfe4f7734b0a01aeb9b63dd5e2d606acb",
        "parent": "70d4aa119da8e8322f6c2e8f7a236bee5e356b6e",
        "source_tree": "6e1df65d9945e3a46a4dd979f3af65f9971958a6",
        "parent_tree": "52e88c95ab7de5afd2364e1fcb4c937c8e06097f",
        "source_registry_sha256": (
            "58a97a4f6f4f4cde5884f8bf6b400f905b0c71676968371ea680c9a61cb951b9"
        ),
        "parent_registry_sha256": (
            "831ea1a35201b672080321e000f174bc1411ba359c7fba7840e7de26ed8c6e4d"
        ),
        "record_id": "V076-HDM-20260827-5AF52A5B",
        "component_count": 32,
        "failure_count": 36,
    },
    {
        "transition": "a99246f1b478->488c21f5d9e5",
        "source": "488c21f5d9e53a2419f311c24cd5aa0897d50196",
        "parent": "a99246f1b4780cb1d13ae2a31414ffa51dab602f",
        "source_tree": "2ad218d7cad1a7c33db0f12e52849f1430b50810",
        "parent_tree": "e9f6c0919ca0deac0065d8aea0e5c01f4346a785",
        "source_registry_sha256": (
            "dfdb9c9e28059755befd1c9dc381f7c5013e081d8a3f454f4dcd0d23e631bee5"
        ),
        "parent_registry_sha256": (
            "58a97a4f6f4f4cde5884f8bf6b400f905b0c71676968371ea680c9a61cb951b9"
        ),
        "record_id": "V076-HDM-20260827-488C21F5",
        "component_count": 25,
        "failure_count": 25,
    },
    {
        "transition": "89c4089d1817->8e6ce3e609e0",
        "source": "8e6ce3e609e0d27a6253aa5b7cad66a9f20dbeb1",
        "parent": "89c4089d1817f81a4980ae72dca4dc8dc958f576",
        "source_tree": "d873ae26e85d770074d9097f44e8d9612ecf4a82",
        "parent_tree": "2fca54dcea61a2146609ce4df6823d51429e8a4f",
        "source_registry_sha256": (
            "99dfd1dff415ad36d2f0e791e1388f5a0c389bb39711a33248deebe1a837e071"
        ),
        "parent_registry_sha256": (
            "dfdb9c9e28059755befd1c9dc381f7c5013e081d8a3f454f4dcd0d23e631bee5"
        ),
        "record_id": "V076-HDM-20260827-8E6CE3E6",
        "component_count": 25,
        "failure_count": 25,
    },
)

CORRECTION_SPECS = {
    ("70d4aa119da8->5af52a5bfe4f", NEW_AUTHORITY_RULE): (
        "V2-HDM-20260827-5AF52A5B-AUTHORITY-REUSE-SCAN",
        "v2-hdm-20260827-5af52a5b-authority-reuse-scan.json",
    ),
    ("70d4aa119da8->5af52a5bfe4f", NEW_COMPONENT_RULE): (
        "V2-HDM-20260827-5AF52A5B-COMPONENT-IDENTITY",
        "v2-hdm-20260827-5af52a5b-component-identity.json",
    ),
    ("a99246f1b478->488c21f5d9e5", NEW_COMPONENT_RULE): (
        "V2-HDM-20260827-488C21F5-COMPONENT-IDENTITY",
        "v2-hdm-20260827-488c21f5-component-identity.json",
    ),
    ("89c4089d1817->8e6ce3e609e0", NEW_COMPONENT_RULE): (
        "V2-HDM-20260827-8E6CE3E6-COMPONENT-IDENTITY",
        "v2-hdm-20260827-8e6ce3e6-component-identity.json",
    ),
}

# The 5af52a5b transition contains one card-domain lineage.  These explicit
# sets are closed: a future component cannot inherit either classification.
BATCH004_DOMAIN_CORE_IDS = {
    "component.current.authorized_card_semantic_envelope_v1",
    "component.current.card_effect_adapter_support_v06",
    "component.current.card_instance_decision_state_v1",
    "component.current.card_play_requirement_policy",
    "component.current.card_runtime_catalog_resource",
    "component.current.card_runtime_definition_resource",
    "component.current.card_runtime_family_resource",
    "component.current.card_runtime_kind_schema",
    "component.current.card_runtime_pack_resource",
    "component.current.card_runtime_rank_resource",
    "component.current.card_semantic_compiler_v1",
    "component.current.card_semantic_schema_v1",
    "component.current.shared_card_group_window",
    "component.current.unit_card_runtime_schema_v06",
}
BATCH004_CROSS_DOMAIN_IDS = {
    "component.current.card_flow_policy_v06",
    "component.current.card_flow_transaction_service_v06",
    "component.current.card_player_state_port_v06",
    "component.current.card_player_state_production_adapter_v06",
    "component.current.card_v04_interaction_semantic_reference_adapter_v1",
    "component.current.commodity_card_effect_adapter_v06",
    "component.current.commodity_flow_atomic_batch_sink_v06",
    "component.current.commodity_flow_candidate_snapshot_port_v06",
    "component.current.core_economic_card_effect_router_v06",
    "component.current.core_economic_card_runtime_adapter_v06",
    "component.current.facility_card_effect_adapter_v06",
    "component.current.global_supply_demand_card_effect_adapter_v06",
    "component.current.global_supply_demand_runtime_service_v06",
    "component.current.monster_card_effect_adapter_v06",
    "component.current.monster_card_owner_port_v06",
    "component.current.organization_card_effect_adapter_v06",
    "component.current.organization_production_port_v06",
    "component.current.unit_card_owner_forwarding_port_v06",
}

AUTHORITY_REDUCER_IDS = {
    "component.current.card_flow_policy_v06",
    "component.current.card_flow_transaction_service_v06",
    "component.current.card_player_state_port_v06",
    "component.current.global_supply_demand_runtime_service_v06",
}

ADAPTER_REASON_BY_COMPONENT = {
    "component.current.card_flow_policy_v06": (
        "A stateless adapter cannot preserve the existing pure plan/commit "
        "reducer's hand merge and discard decisions, inventory fingerprint, "
        "asset debit, and transaction commit semantics."
    ),
    "component.current.card_flow_transaction_service_v06": (
        "A stateless adapter cannot preserve belt and market revisions, "
        "inflight reservations, the exact-once journal, source revision, and "
        "the atomic state-port commit lifecycle."
    ),
    "component.current.card_player_state_port_v06": (
        "A stateless adapter cannot preserve player revisions, locks, "
        "reservations, global card-instance uniqueness, and the terminal "
        "transaction journal."
    ),
    "component.current.global_supply_demand_runtime_service_v06": (
        "A stateless adapter cannot preserve candidate revision, batch "
        "sequence, receipts, the transaction journal, or the "
        "prepare/commit/rollback/finalize lifecycle; permanent rate and "
        "quantity mutation remains with the existing external sink and Asset Owner."
    ),
}


class DuplicateJsonKeyError(ValueError):
    pass


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJsonKeyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json_strict(path: Path) -> Any:
    return json.loads(
        path.read_text(encoding="utf-8-sig"), object_pairs_hook=_strict_object
    )


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def line_set_sha(values: list[str] | set[str]) -> str:
    rendered = sorted(str(value) for value in values)
    payload = ("\n".join(rendered) + "\n") if rendered else ""
    return sha256_bytes(payload.encode("utf-8"))


def canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def payload_sha256(document: dict[str, Any], field: str) -> str:
    payload = dict(document)
    payload.pop(field, None)
    return sha256_bytes(canonical_json_bytes(payload))


def failure_fingerprint(raw_failure: str, rule_id: str) -> str:
    payload = f"V076_RAW_FAILURE_V2\nHISTORICAL\n{rule_id}\n{raw_failure}\n"
    return "V2F-" + sha256_bytes(payload.encode("utf-8"))


def _git_text(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        raise ValueError(result.stderr.strip() or "GIT_COMMAND_FAILED")
    return result.stdout.strip()


def _git_bytes(root: Path, ref: str, relative: str) -> bytes | None:
    result = subprocess.run(
        ["git", "show", f"{ref}:{relative}"],
        cwd=root,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout if result.returncode == 0 else None


def _resolve_exact_commit(root: Path, value: str, label: str) -> str:
    if re.fullmatch(r"[0-9a-f]{40}", value) is None:
        raise ValueError(f"{label}_NOT_EXACT_COMMIT")
    resolved = _git_text(root, "rev-parse", f"{value}^{{commit}}")
    if resolved != value:
        raise ValueError(f"{label}_COMMIT_MISMATCH")
    return resolved


def _is_ancestor(root: Path, older: str, newer: str) -> bool:
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", older, newer],
        cwd=root,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def _strict_json_bytes(payload: bytes) -> Any:
    return json.loads(
        payload.decode("utf-8-sig"), object_pairs_hook=_strict_object
    )


def _component_rows(document: dict[str, Any]) -> dict[str, dict[str, Any]]:
    values = document.get("component_inventory")
    if not isinstance(values, list):
        raise ValueError("REGISTRY_COMPONENT_INVENTORY_INVALID")
    result: dict[str, dict[str, Any]] = {}
    for row in values:
        component_id = row.get("component_id") if isinstance(row, dict) else None
        if not isinstance(component_id, str) or not component_id or component_id in result:
            raise ValueError(f"REGISTRY_COMPONENT_ROW_INVALID:{component_id}")
        result[component_id] = row
    return result


def _domain_rows(document: dict[str, Any]) -> dict[str, dict[str, Any]]:
    values = document.get("domain_inventory")
    if not isinstance(values, list):
        raise ValueError("REGISTRY_DOMAIN_INVENTORY_INVALID")
    result: dict[str, dict[str, Any]] = {}
    for row in values:
        domain_id = row.get("domain_id") if isinstance(row, dict) else None
        if not isinstance(domain_id, str) or not domain_id or domain_id in result:
            raise ValueError(f"REGISTRY_DOMAIN_ROW_INVALID:{domain_id}")
        result[domain_id] = row
    return result


def _reuse_entry_ids(document: dict[str, Any]) -> set[str]:
    values = document.get("reuse_entries")
    if not isinstance(values, list):
        raise ValueError("REGISTRY_REUSE_ENTRIES_INVALID")
    result: set[str] = set()
    for row in values:
        reuse_id = row.get("reuse_id") if isinstance(row, dict) else None
        if not isinstance(reuse_id, str) or not reuse_id or reuse_id in result:
            raise ValueError(f"REGISTRY_REUSE_ENTRY_INVALID:{reuse_id}")
        result.add(reuse_id)
    return result


def _row_sha256(row: dict[str, Any]) -> str:
    return sha256_bytes(canonical_json_bytes(row))


def _valid_reuse_scan(row: dict[str, Any], reuse_ids: set[str]) -> bool:
    scan = row.get("reuse_scan")
    candidates = scan.get("reuse_candidate_ids") if isinstance(scan, dict) else None
    considered = row.get("reuse_candidates_considered")
    return bool(
        isinstance(scan, dict)
        and set(scan) == REUSE_SCAN_FIELDS
        and all(
            scan.get(key) is True
            for key in REUSE_SCAN_FIELDS
            if key.endswith("_search")
        )
        and isinstance(candidates, list)
        and candidates
        and all(isinstance(value, str) and value in reuse_ids for value in candidates)
        and len(candidates) == len(set(candidates))
        and type(scan.get("reuse_candidate_count")) is int
        and scan.get("reuse_candidate_count") == len(candidates)
        and isinstance(considered, list)
        and all(isinstance(value, str) for value in considered)
        and set(candidates).issubset(set(considered))
        and scan.get("selected_reuse_disposition") == row.get("reuse_disposition")
        and all(
            isinstance(scan.get(key), str) and scan[key].strip()
            for key in (
                "why_existing_owner_cannot_be_extended",
                "why_adapter_is_insufficient",
                "why_new_owner_is_required",
            )
        )
    )


def _canonical_relative(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value or "\\" in value:
        raise ValueError(f"{label}_PATH_NOT_CANONICAL")
    candidate = Path(value)
    if candidate.is_absolute() or candidate.as_posix() != value:
        raise ValueError(f"{label}_PATH_NOT_CANONICAL")
    if any(part in {"", ".", ".."} for part in candidate.parts):
        raise ValueError(f"{label}_PATH_TRAVERSAL")
    return value


def _history_touched_paths(root: Path, older: str, newer: str) -> set[str]:
    if older == newer:
        return set()
    if not _is_ancestor(root, older, newer):
        raise ValueError("HISTORY_TOUCH_RANGE_NOT_ANCESTRAL")
    commits = _git_text(root, "rev-list", f"{older}..{newer}").splitlines()
    touched: set[str] = set()
    for commit in commits:
        values = _git_text(
            root,
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "-r",
            "-m",
            commit,
        ).splitlines()
        touched.update(value.replace("\\", "/") for value in values if value)
    return touched


def _expected_schema_document() -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_DOCUMENT_VERSION,
        "ledger_schema_version": LEDGER_SCHEMA_VERSION,
        "historical_record_schema_version": METADATA_RECORD_SCHEMA_VERSION,
        "metadata_record_schema_version": METADATA_RECORD_SCHEMA_VERSION,
        "correction_record_schema_version": CORRECTION_RECORD_SCHEMA_VERSION,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "authorized_raw_report_sha256": SEALED_RAW_SHA256,
        "authorized_raw_report_head_sha": SEALED_RAW_HEAD,
        "authorized_raw_report_tree_sha": SEALED_RAW_TREE,
        "authorized_raw_failure_count": SEALED_RAW_FAILURE_COUNT,
        "authorized_raw_native_historical_count": RAW_NATIVE_HISTORICAL_COUNT,
        "authorized_raw_ledger_promoted_count": RAW_LEDGER_PROMOTED_COUNT,
        "authorized_raw_semantic_historical_count": RAW_SEMANTIC_HISTORICAL_COUNT,
        "authorized_raw_true_current_count": RAW_TRUE_CURRENT_COUNT,
        "authorized_ledger_failure_count": HISTORICAL_DELTA_FAILURE_COUNT,
        "canonical_ledger_path": LEDGER_REL.as_posix(),
        "raw_report_root": "reports/reuse/",
        "correction_record_root": (
            "docs/architecture/reuse_corrections/v2/records/"
        ),
        "allowed_rule_ids": sorted(ALLOWED_FAILURE_RULES),
        "exact_selector_policy": EXACT_SELECTOR_POLICY,
        "field_sets": {
            "ledger": sorted(LEDGER_FIELDS),
            "metadata_record": sorted(METADATA_RECORD_FIELDS),
            "failure_binding": sorted(FAILURE_BINDING_FIELDS),
            "correction_binding": sorted(CORRECTION_BINDING_FIELDS),
            "correction_record": sorted(CORRECTION_RECORD_FIELDS),
        },
        "raw_scanner_reads_ledger": False,
        "active_resolver_count": 1,
        "wildcard_allowed": False,
        "future_failure_auto_match_allowed": False,
        "history_rewrite_allowed": False,
        "component_path_blob_binding_required": True,
        "path_touch_history_invalidation_required": True,
    }


def _is_reparse_point(path: Path) -> bool:
    metadata = os.lstat(path)
    attributes = getattr(metadata, "st_file_attributes", 0)
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    return stat.S_ISLNK(metadata.st_mode) or bool(attributes & reparse_flag)


def _assert_path_inside_without_reparse(
    root: Path, relative: str, *, allow_missing: bool
) -> Path:
    relative = _canonical_relative(relative, "OUTPUT")
    candidate = root.joinpath(*Path(relative).parts)
    probe = root
    for part in Path(relative).parts:
        probe = probe / part
        if not os.path.lexists(probe):
            if allow_missing:
                break
            raise ValueError(f"CANONICAL_PATH_NOT_FOUND:{relative}")
        if _is_reparse_point(probe):
            raise ValueError(f"CANONICAL_PATH_REPARSE_FORBIDDEN:{relative}")
    resolved = candidate.resolve(strict=False)
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ValueError(f"CANONICAL_PATH_ESCAPES_PROJECT:{relative}") from exc
    return candidate


def _git_project_root(project: Path) -> Path:
    try:
        root = project.resolve(strict=True)
    except FileNotFoundError as exc:
        raise ValueError("PROJECT_ROOT_NOT_FOUND") from exc
    if not root.is_dir():
        raise ValueError("PROJECT_ROOT_NOT_DIRECTORY")
    top_level = Path(_git_text(root, "rev-parse", "--show-toplevel")).resolve(
        strict=True
    )
    if top_level != root:
        raise ValueError("PROJECT_ROOT_NOT_GIT_TOP_LEVEL")
    return root


def _committed_worktree_bytes(root: Path, head: str, relative: Path) -> bytes:
    relative_text = relative.as_posix()
    path = _assert_path_inside_without_reparse(
        root, relative_text, allow_missing=False
    )
    committed = _git_bytes(root, head, relative_text)
    if committed is None:
        raise ValueError(f"HEAD_COMMITTED_FILE_MISSING:{relative_text}")
    working = path.read_bytes()
    if committed != working:
        raise ValueError(f"HEAD_WORKTREE_BYTES_MISMATCH:{relative_text}")
    return committed


def _load_registry_document(payload: bytes, label: str) -> dict[str, Any]:
    value = _strict_json_bytes(payload)
    if not isinstance(value, dict):
        raise ValueError(f"{label}_REGISTRY_NOT_OBJECT")
    _component_rows(value)
    _domain_rows(value)
    _reuse_entry_ids(value)
    return value


def _raw_failure_groups(raw_report: dict[str, Any]) -> dict[tuple[str, str], list[str]]:
    inventory = _historical_delta_inventory(raw_report)
    failures = raw_report.get("failures")
    if not isinstance(failures, list) or any(not isinstance(value, str) for value in failures):
        raise ValueError("SEALED_RAW_FAILURE_LIST_INVALID")
    native_historical = sum(
        1 for value in failures if value.split(":", 1)[0].startswith("HISTORY_")
    )
    promoted = sum(
        1
        for value in inventory["failures"]
        if value.split(":", 1)[0] == NEW_COMPONENT_RULE
    )
    semantic_historical = native_historical + promoted
    true_current = len(failures) - semantic_historical
    if (
        native_historical != RAW_NATIVE_HISTORICAL_COUNT
        or promoted != RAW_LEDGER_PROMOTED_COUNT
        or semantic_historical != RAW_SEMANTIC_HISTORICAL_COUNT
        or true_current != RAW_TRUE_CURRENT_COUNT
    ):
        raise ValueError("SEALED_RAW_HISTORICAL_BUCKET_COUNT_MISMATCH")
    groups: dict[tuple[str, str], list[str]] = {}
    for value in inventory["failures"]:
        parts = value.split(":")
        if len(parts) != 3:
            raise ValueError("HISTORICAL_DELTA_RAW_SHAPE_INVALID")
        groups.setdefault((parts[1], parts[0]), []).append(value)
    if set(groups) != set(CORRECTION_SPECS):
        raise ValueError("HISTORICAL_DELTA_CORRECTION_GROUP_SET_MISMATCH")
    expected_counts = {
        ("70d4aa119da8->5af52a5bfe4f", NEW_AUTHORITY_RULE): 4,
        ("70d4aa119da8->5af52a5bfe4f", NEW_COMPONENT_RULE): 32,
        ("a99246f1b478->488c21f5d9e5", NEW_COMPONENT_RULE): 25,
        ("89c4089d1817->8e6ce3e609e0", NEW_COMPONENT_RULE): 25,
    }
    if {key: len(value) for key, value in groups.items()} != expected_counts:
        raise ValueError("HISTORICAL_DELTA_CORRECTION_GROUP_COUNT_MISMATCH")
    return groups


def _git_blob_sha256(root: Path, commit: str, relative: str, label: str) -> str:
    relative = _canonical_relative(relative, label)
    payload = _git_bytes(root, commit, relative)
    if payload is None:
        raise ValueError(f"{label}_BLOB_MISSING:{commit}:{relative}")
    return sha256_bytes(payload)


def _source_transition_documents(
    root: Path,
    spec: dict[str, Any],
    target_ids: set[str],
    raw_head: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    source = _resolve_exact_commit(root, str(spec["source"]), "SOURCE")
    parent = _resolve_exact_commit(root, str(spec["parent"]), "PARENT")
    parents = _git_text(root, "rev-list", "--parents", "-n", "1", source).split()[1:]
    if parents != [parent]:
        raise ValueError(f"SOURCE_DIRECT_PARENT_MISMATCH:{source}")
    if _git_text(root, "rev-parse", f"{source}^{{tree}}") != spec["source_tree"]:
        raise ValueError(f"SOURCE_TREE_MISMATCH:{source}")
    if _git_text(root, "rev-parse", f"{parent}^{{tree}}") != spec["parent_tree"]:
        raise ValueError(f"PARENT_TREE_MISMATCH:{parent}")
    if not _is_ancestor(root, AUTHORIZATION_BASE_HEAD, source) or not _is_ancestor(
        root, source, raw_head
    ):
        raise ValueError(f"SOURCE_ANCESTRY_MISMATCH:{source}")
    changed = _git_text(
        root, "diff-tree", "--no-commit-id", "--name-only", "-r", source
    ).splitlines()
    if changed != [REGISTRY_REL.as_posix()]:
        raise ValueError(f"SOURCE_NOT_REGISTRY_ONLY:{source}")
    source_bytes = _git_bytes(root, source, REGISTRY_REL.as_posix())
    parent_bytes = _git_bytes(root, parent, REGISTRY_REL.as_posix())
    if source_bytes is None or parent_bytes is None:
        raise ValueError(f"SOURCE_REGISTRY_MISSING:{source}")
    if sha256_bytes(source_bytes) != spec["source_registry_sha256"]:
        raise ValueError(f"SOURCE_REGISTRY_SHA256_MISMATCH:{source}")
    if sha256_bytes(parent_bytes) != spec["parent_registry_sha256"]:
        raise ValueError(f"PARENT_REGISTRY_SHA256_MISMATCH:{parent}")
    source_document = _load_registry_document(source_bytes, "SOURCE")
    parent_document = _load_registry_document(parent_bytes, "PARENT")
    added = set(_component_rows(source_document)) - set(_component_rows(parent_document))
    removed = set(_component_rows(parent_document)) - set(_component_rows(source_document))
    if added != target_ids or removed:
        raise ValueError(f"SOURCE_COMPONENT_DELTA_MISMATCH:{source}")
    if len(added) != spec["component_count"]:
        raise ValueError(f"SOURCE_COMPONENT_COUNT_MISMATCH:{source}")
    return source_document, parent_document


def _historical_delta_inventory(raw_report: dict[str, Any]) -> dict[str, Any]:
    failures = raw_report.get("failures")
    if not isinstance(failures, list):
        raise ValueError("SEALED_RAW_FAILURE_LIST_INVALID")
    rendered = [str(value) for value in failures]
    if len(rendered) != SEALED_RAW_FAILURE_COUNT or len(rendered) != len(set(rendered)):
        raise ValueError("SEALED_RAW_FAILURE_SET_INVALID")
    selected = sorted(
        value
        for value in rendered
        if value.split(":", 1)[0] in ALLOWED_FAILURE_RULES
    )
    if len(selected) != HISTORICAL_DELTA_FAILURE_COUNT:
        raise ValueError("HISTORICAL_DELTA_FAILURE_COUNT_MISMATCH")
    if line_set_sha(selected) != HISTORICAL_DELTA_RAW_SET_SHA256:
        raise ValueError("HISTORICAL_DELTA_RAW_SET_MISMATCH")
    parts = [value.split(":") for value in selected]
    if any(len(row) != 3 for row in parts):
        raise ValueError("HISTORICAL_DELTA_RAW_SHAPE_INVALID")
    transitions = {row[1] for row in parts}
    components = {row[2] for row in parts}
    if transitions != TRANSITION_PREFIXES:
        raise ValueError("HISTORICAL_DELTA_TRANSITION_SET_MISMATCH")
    if line_set_sha(transitions) != HISTORICAL_DELTA_TRANSITION_SET_SHA256:
        raise ValueError("HISTORICAL_DELTA_TRANSITION_HASH_MISMATCH")
    if len(components) != HISTORICAL_DELTA_COMPONENT_COUNT:
        raise ValueError("HISTORICAL_DELTA_COMPONENT_COUNT_MISMATCH")
    if line_set_sha(components) != HISTORICAL_DELTA_COMPONENT_SET_SHA256:
        raise ValueError("HISTORICAL_DELTA_COMPONENT_SET_MISMATCH")
    component_transition = {row[2]: row[1] for row in parts}
    if len(component_transition) != HISTORICAL_DELTA_COMPONENT_COUNT:
        raise ValueError("HISTORICAL_DELTA_COMPONENT_TRANSITION_COLLISION")
    authority_failures = [row for row in parts if row[0] == NEW_AUTHORITY_RULE]
    if {row[2] for row in authority_failures} != AUTHORITY_REDUCER_IDS:
        raise ValueError("HISTORICAL_DELTA_AUTHORITY_REDUCER_SET_MISMATCH")
    return {
        "failures": selected,
        "components": components,
        "component_transition": component_transition,
        "transitions": transitions,
    }


def _reuse_scan(component_id: str) -> dict[str, Any]:
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
        "reuse_candidate_count": 2,
        "reuse_candidate_ids": [
            "reuse.v075.combat_candidate",
            "reuse.current.card_runtime_catalog_v06",
        ],
        "selected_reuse_disposition": "ADAPT_AS_CONSUMER",
        "why_existing_owner_cannot_be_extended": (
            "NOT_APPLICABLE_EXISTING_SUBORDINATE_REDUCER_REUSED_UNDER_"
            "THE_UNIQUE_V075_RUNTIME_OWNER"
        ),
        "why_adapter_is_insufficient": ADAPTER_REASON_BY_COMPONENT[component_id],
        "why_new_owner_is_required": (
            "NOT_REQUIRED_EXISTING_V075_RUNTIME_OWNER_REMAINS_THE_UNIQUE_OWNER"
        ),
    }


def _change_class(component_id: str, transition: str, role: str) -> str:
    if transition == "70d4aa119da8->5af52a5bfe4f":
        if component_id in BATCH004_DOMAIN_CORE_IDS:
            return "DOMAIN_CORE"
        if component_id in BATCH004_CROSS_DOMAIN_IDS:
            return "CROSS_DOMAIN_INTEGRATION"
        raise ValueError(f"BATCH004_COMPONENT_NOT_CLASSIFIED:{component_id}")
    if transition == "a99246f1b478->488c21f5d9e5":
        if role not in {"PRESENTATION", "PORT"}:
            raise ValueError(f"BATCH005_ROLE_UNEXPECTED:{component_id}:{role}")
        return "PRODUCTION_COMPOSITION"
    if transition == "89c4089d1817->8e6ce3e609e0":
        if component_id == "component.current.product_industry_entry_resource":
            if role != "PORT":
                raise ValueError("BATCH006_PRODUCT_RESOURCE_ROLE_UNEXPECTED")
            return "DOMAIN_CORE"
        if role != "TEST_SUPPORT":
            raise ValueError(f"BATCH006_TEST_ROLE_UNEXPECTED:{component_id}:{role}")
        return "TEST_ORACLE_ONLY"
    raise ValueError(f"UNKNOWN_HISTORICAL_DELTA_TRANSITION:{transition}")


def build_registry_successor(
    registry: dict[str, Any], raw_report: dict[str, Any]
) -> tuple[dict[str, Any], dict[str, Any]]:
    inventory = _historical_delta_inventory(raw_report)
    rows = registry.get("component_inventory")
    reuse_entries = registry.get("reuse_entries")
    if not isinstance(rows, list) or not isinstance(reuse_entries, list):
        raise ValueError("REGISTRY_COMPONENT_OR_REUSE_INVENTORY_INVALID")
    reuse_ids = {
        str(row.get("reuse_id", ""))
        for row in reuse_entries
        if isinstance(row, dict)
    }
    required_reuse = {
        "reuse.v075.combat_candidate",
        "reuse.current.card_runtime_catalog_v06",
    }
    if not required_reuse.issubset(reuse_ids):
        raise ValueError("REQUIRED_REUSE_CANDIDATE_NOT_REGISTERED")
    by_id: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("REGISTRY_COMPONENT_ROW_NOT_OBJECT")
        component_id = str(row.get("component_id", ""))
        if not component_id or component_id in by_id:
            raise ValueError(f"REGISTRY_COMPONENT_ID_INVALID_OR_DUPLICATE:{component_id}")
        by_id[component_id] = row
    target_ids = set(inventory["components"])
    if not target_ids.issubset(by_id):
        raise ValueError("REGISTRY_TARGET_COMPONENT_MISSING")
    before = json.loads(json.dumps(registry, ensure_ascii=False))
    class_counts: dict[str, int] = {}
    scan_count = 0
    for component_id in sorted(target_ids):
        row = by_id[component_id]
        if row.get("change_class") != "INHERITED":
            raise ValueError(f"TARGET_COMPONENT_NOT_INHERITED_BEFORE_REPAIR:{component_id}")
        transition = inventory["component_transition"][component_id]
        role = str(row.get("component_role", ""))
        new_class = _change_class(component_id, transition, role)
        row["change_class"] = new_class
        class_counts[new_class] = class_counts.get(new_class, 0) + 1
        if component_id in AUTHORITY_REDUCER_IDS:
            if (
                role != "REDUCER"
                or row.get("writes_authority") is not True
                or row.get("production_reachable") is not True
                or row.get("reuse_disposition") != "ADAPT_AS_CONSUMER"
            ):
                raise ValueError(f"AUTHORITY_REDUCER_SEMANTICS_INVALID:{component_id}")
            row["reuse_scan"] = _reuse_scan(component_id)
            scan_count += 1
        elif "reuse_scan" in row:
            raise ValueError(f"NONAUTHORITY_TARGET_ALREADY_HAS_REUSE_SCAN:{component_id}")

    after_by_id = {
        str(row.get("component_id", "")): row
        for row in registry["component_inventory"]
        if isinstance(row, dict)
    }
    before_by_id = {
        str(row.get("component_id", "")): row
        for row in before["component_inventory"]
        if isinstance(row, dict)
    }
    for component_id, after in after_by_id.items():
        prior = before_by_id[component_id]
        if component_id not in target_ids:
            if prior != after:
                raise ValueError(f"NONTARGET_COMPONENT_MUTATED:{component_id}")
            continue
        prior_stable = {
            key: value for key, value in prior.items() if key not in {"change_class", "reuse_scan"}
        }
        after_stable = {
            key: value for key, value in after.items() if key not in {"change_class", "reuse_scan"}
        }
        if prior_stable != after_stable:
            raise ValueError(f"TARGET_STABLE_FIELDS_MUTATED:{component_id}")
        if after.get("change_class") == "INHERITED":
            raise ValueError(f"TARGET_COMPONENT_STILL_INHERITED:{component_id}")
        if (component_id in AUTHORITY_REDUCER_IDS) != ("reuse_scan" in after):
            raise ValueError(f"TARGET_REUSE_SCAN_COVERAGE_INVALID:{component_id}")
    if scan_count != 4:
        raise ValueError("TARGET_REUSE_SCAN_COUNT_MISMATCH")
    if sum(class_counts.values()) != HISTORICAL_DELTA_COMPONENT_COUNT:
        raise ValueError("TARGET_CHANGE_CLASS_COVERAGE_MISMATCH")
    return registry, {
        "status": "PASS",
        "sealed_raw_head": SEALED_RAW_HEAD,
        "historical_delta_failure_count": HISTORICAL_DELTA_FAILURE_COUNT,
        "historical_delta_component_count": HISTORICAL_DELTA_COMPONENT_COUNT,
        "historical_delta_transition_count": HISTORICAL_DELTA_TRANSITION_COUNT,
        "reuse_scan_added_count": scan_count,
        "change_class_counts": dict(sorted(class_counts.items())),
        "non_target_mutation_count": 0,
        "stable_field_mutation_count": 0,
    }


def render_registry_successor_bytes(
    original: bytes,
    repaired: dict[str, Any],
    target_ids: set[str],
) -> bytes:
    """Replace only the 82 compact component rows and preserve all other bytes."""

    text = original.decode("utf-8-sig")
    rows = repaired.get("component_inventory", [])
    repaired_by_id = {
        str(row.get("component_id", "")): row
        for row in rows
        if isinstance(row, dict)
    }
    output: list[str] = []
    replaced: set[str] = set()
    for line in text.splitlines(keepends=True):
        newline = "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""
        body = line[: -len(newline)] if newline else line
        stripped = body.strip()
        trailing_comma = stripped.endswith(",")
        candidate = stripped[:-1] if trailing_comma else stripped
        parsed: Any = None
        if candidate.startswith("{") and '"component_id"' in candidate:
            try:
                parsed = json.loads(candidate, object_pairs_hook=_strict_object)
            except (json.JSONDecodeError, DuplicateJsonKeyError):
                parsed = None
        component_id = (
            str(parsed.get("component_id", "")) if isinstance(parsed, dict) else ""
        )
        if component_id not in target_ids:
            output.append(line)
            continue
        if component_id in replaced or component_id not in repaired_by_id:
            raise ValueError(f"TARGET_COMPACT_ROW_DUPLICATE_OR_MISSING:{component_id}")
        indent = body[: len(body) - len(body.lstrip())]
        rendered = json.dumps(
            repaired_by_id[component_id],
            ensure_ascii=False,
            separators=(",", ":"),
        )
        output.append(indent + rendered + ("," if trailing_comma else "") + newline)
        replaced.add(component_id)
    if replaced != target_ids:
        missing = sorted(target_ids - replaced)
        raise ValueError(f"TARGET_COMPACT_ROW_COVERAGE_MISMATCH:{len(missing)}")
    payload = "".join(output).encode("utf-8")
    reparsed = json.loads(
        payload.decode("utf-8-sig"), object_pairs_hook=_strict_object
    )
    if reparsed != repaired:
        raise ValueError("RENDERED_REGISTRY_SEMANTIC_MISMATCH")
    return payload


def build_historical_delta_evidence(
    root: Path,
    raw_bytes: bytes,
    evaluated_head: str,
) -> tuple[dict[str, bytes], dict[str, Any]]:
    """Build the six fixed formal evidence outputs without writing them."""

    evaluated_head = _resolve_exact_commit(root, evaluated_head, "EVALUATED_HEAD")
    if _git_text(root, "rev-parse", "HEAD") != evaluated_head:
        raise ValueError("EVALUATED_HEAD_NOT_CURRENT_HEAD")
    _resolve_exact_commit(root, AUTHORIZATION_BASE_HEAD, "AUTHORIZATION_BASE")
    raw_head = _resolve_exact_commit(root, SEALED_RAW_HEAD, "RAW_HEAD")
    if not _is_ancestor(root, AUTHORIZATION_BASE_HEAD, evaluated_head):
        raise ValueError("AUTHORIZATION_BASE_NOT_EVALUATED_HEAD_ANCESTOR")
    if not _is_ancestor(root, raw_head, evaluated_head):
        raise ValueError("RAW_HEAD_NOT_EVALUATED_HEAD_ANCESTOR")
    raw_tree = _git_text(root, "rev-parse", f"{raw_head}^{{tree}}")
    if raw_tree != SEALED_RAW_TREE:
        raise ValueError("RAW_HEAD_TREE_MISMATCH")
    if sha256_bytes(raw_bytes) != SEALED_RAW_SHA256:
        raise ValueError("SEALED_RAW_SHA256_MISMATCH")
    raw_report = _strict_json_bytes(raw_bytes)
    if not isinstance(raw_report, dict):
        raise ValueError("SEALED_RAW_REPORT_NOT_OBJECT")
    if (
        raw_report.get("status") != "FAIL"
        or raw_report.get("head_sha") != raw_head
        or raw_report.get("include_worktree") is not False
        or raw_report.get("evaluated_source") != "COMMITTED_HEAD"
    ):
        raise ValueError("SEALED_RAW_PROVENANCE_MISMATCH")
    groups = _raw_failure_groups(raw_report)

    schema_bytes = _committed_worktree_bytes(root, evaluated_head, SCHEMA_REL)
    schema = _strict_json_bytes(schema_bytes)
    if schema != _expected_schema_document():
        raise ValueError("COMMITTED_SCHEMA_CONTRACT_MISMATCH")
    current_registry_bytes = _committed_worktree_bytes(
        root, evaluated_head, REGISTRY_REL
    )
    if sha256_bytes(current_registry_bytes) != REPAIRED_REGISTRY_SHA256:
        raise ValueError("CURRENT_REGISTRY_SHA256_MISMATCH")
    current_registry = _load_registry_document(
        current_registry_bytes, "CURRENT"
    )
    current_components = _component_rows(current_registry)
    current_domains = _domain_rows(current_registry)
    current_reuse_ids = _reuse_entry_ids(current_registry)
    touched_paths = _history_touched_paths(root, raw_head, evaluated_head)

    records: list[dict[str, Any]] = []
    binding_by_fingerprint: dict[str, dict[str, Any]] = {}
    record_id_by_transition: dict[str, str] = {}
    for spec in TRANSITION_SPECS:
        transition = str(spec["transition"])
        transition_failures = sorted(
            failure
            for (failure_transition, _rule), values in groups.items()
            if failure_transition == transition
            for failure in values
        )
        if len(transition_failures) != spec["failure_count"]:
            raise ValueError(f"TRANSITION_FAILURE_COUNT_MISMATCH:{transition}")
        target_ids = {
            failure.split(":", 2)[2] for failure in transition_failures
        }
        if len(target_ids) != spec["component_count"]:
            raise ValueError(f"TRANSITION_COMPONENT_COUNT_MISMATCH:{transition}")
        source_registry, parent_registry = _source_transition_documents(
            root, spec, target_ids, raw_head
        )
        source_components = _component_rows(source_registry)
        parent_components = _component_rows(parent_registry)
        source_domains = _domain_rows(source_registry)
        bindings: list[dict[str, Any]] = []
        affected_domains: set[str] = set()
        affected_owners: set[str] = set()
        reuse_scan_component_ids: set[str] = set()
        focused_tests: set[str] = set()
        for raw_failure in transition_failures:
            rule_id, transition_token, component_id = raw_failure.split(":")
            if transition_token != transition or rule_id not in ALLOWED_FAILURE_RULES:
                raise ValueError(f"RAW_FAILURE_IDENTITY_MISMATCH:{raw_failure}")
            source_row = source_components.get(component_id)
            current_row = current_components.get(component_id)
            if (
                source_row is None
                or current_row is None
                or component_id in parent_components
            ):
                raise ValueError(f"COMPONENT_LIFECYCLE_MISMATCH:{component_id}")
            if source_row.get("change_class") != "INHERITED":
                raise ValueError(f"SOURCE_COMPONENT_NOT_INHERITED:{component_id}")
            if current_row.get("change_class") == "INHERITED":
                raise ValueError(f"CURRENT_COMPONENT_STILL_INHERITED:{component_id}")
            source_path = _canonical_relative(
                source_row.get("path"), "SOURCE_COMPONENT"
            )
            current_path = _canonical_relative(
                current_row.get("path"), "CURRENT_COMPONENT"
            )
            if source_path in touched_paths or current_path in touched_paths:
                raise ValueError(f"COMPONENT_PATH_TOUCHED_AFTER_RAW:{component_id}")
            source_domain_id = str(source_row.get("domain_id", ""))
            current_domain_id = str(current_row.get("domain_id", ""))
            source_domain = source_domains.get(source_domain_id)
            current_domain = current_domains.get(current_domain_id)
            if source_domain is None or current_domain is None:
                raise ValueError(f"COMPONENT_DOMAIN_MISSING:{component_id}")
            source_owner_id = str(source_row.get("owner_component_id", ""))
            current_owner_id = str(current_row.get("owner_component_id", ""))
            source_owner = source_components.get(source_owner_id)
            current_owner = current_components.get(current_owner_id)
            if source_owner is None or current_owner is None:
                raise ValueError(f"COMPONENT_OWNER_MISSING:{component_id}")
            if (
                source_owner.get("component_role") != "OWNER"
                or current_owner.get("component_role") != "OWNER"
            ):
                raise ValueError(f"COMPONENT_OWNER_ROLE_INVALID:{component_id}")
            source_owner_path = _canonical_relative(
                source_owner.get("path"), "SOURCE_OWNER"
            )
            current_owner_path = _canonical_relative(
                current_owner.get("path"), "CURRENT_OWNER"
            )
            if source_row.get("owner_path") != source_owner_path:
                raise ValueError(f"SOURCE_OWNER_PATH_BINDING_MISMATCH:{component_id}")
            if current_row.get("owner_path") != current_owner_path:
                raise ValueError(f"CURRENT_OWNER_PATH_BINDING_MISMATCH:{component_id}")
            if (
                source_owner_path in touched_paths
                or current_owner_path in touched_paths
            ):
                raise ValueError(f"OWNER_PATH_TOUCHED_AFTER_RAW:{component_id}")
            if rule_id == NEW_AUTHORITY_RULE:
                reuse_scan_component_ids.add(component_id)
                if not _valid_reuse_scan(current_row, current_reuse_ids):
                    raise ValueError(f"CURRENT_REUSE_SCAN_INVALID:{component_id}")
            for row in (source_row, current_row):
                tests = row.get("focused_test_ids")
                if not isinstance(tests, list) or any(
                    not isinstance(value, str) or not value.strip() for value in tests
                ):
                    raise ValueError(f"FOCUSED_TEST_SET_INVALID:{component_id}")
                focused_tests.update(tests)
            fingerprint = failure_fingerprint(raw_failure, rule_id)
            binding = {
                "failure_fingerprint": fingerprint,
                "raw_failure": raw_failure,
                "rule_id": rule_id,
                "component_id": component_id,
                "source_component_sha256": _row_sha256(source_row),
                "current_component_sha256": _row_sha256(current_row),
                "source_component_path": source_path,
                "current_component_path": current_path,
                "source_path_blob_sha256": _git_blob_sha256(
                    root, str(spec["source"]), source_path, "SOURCE_COMPONENT"
                ),
                "current_path_blob_sha256": _git_blob_sha256(
                    root, evaluated_head, current_path, "CURRENT_COMPONENT"
                ),
                "source_domain_id": source_domain_id,
                "source_domain_sha256": _row_sha256(source_domain),
                "current_domain_sha256": _row_sha256(current_domain),
                "source_owner_component_id": source_owner_id,
                "current_owner_component_id": current_owner_id,
                "source_owner_component_sha256": _row_sha256(source_owner),
                "current_owner_component_sha256": _row_sha256(current_owner),
                "source_owner_path": source_owner_path,
                "current_owner_path": current_owner_path,
                "source_owner_path_blob_sha256": _git_blob_sha256(
                    root, str(spec["source"]), source_owner_path, "SOURCE_OWNER"
                ),
                "current_owner_path_blob_sha256": _git_blob_sha256(
                    root, evaluated_head, current_owner_path, "CURRENT_OWNER"
                ),
                "source_production_reachability": source_row.get(
                    "production_reachable"
                ),
            }
            if set(binding) != FAILURE_BINDING_FIELDS:
                raise ValueError(f"FAILURE_BINDING_FIELD_SET_MISMATCH:{fingerprint}")
            if fingerprint in binding_by_fingerprint:
                raise ValueError(f"FAILURE_FINGERPRINT_COLLISION:{fingerprint}")
            binding_by_fingerprint[fingerprint] = binding
            bindings.append(binding)
            affected_domains.add(source_domain_id)
            affected_owners.add(source_owner_id)
        bindings.sort(key=lambda value: value["failure_fingerprint"])
        if not focused_tests:
            raise ValueError(f"TRANSITION_FOCUSED_TEST_SET_EMPTY:{transition}")
        record_id = str(spec["record_id"])
        record_id_by_transition[transition] = record_id
        record = {
            "schema_version": METADATA_RECORD_SCHEMA_VERSION,
            "record_id": record_id,
            "source_commit": spec["source"],
            "parent_commit": spec["parent"],
            "commit_tree": spec["source_tree"],
            "parent_tree": spec["parent_tree"],
            "registry_path": REGISTRY_REL.as_posix(),
            "source_registry_sha256": spec["source_registry_sha256"],
            "parent_registry_sha256": spec["parent_registry_sha256"],
            "change_class": "DOCS_ONLY",
            "affected_domains": sorted(affected_domains),
            "affected_owners": sorted(affected_owners),
            "focused_tests": sorted(focused_tests),
            "historical_context": (
                "Exact Registry-only historical metadata transition "
                f"{transition}; binds {len(bindings)} Raw failures across "
                f"{len(target_ids)} newly registered components without "
                "weakening or filtering Raw detection."
            ),
            "current_disposition": "CORRECTED_HISTORICAL_METADATA_DEBT",
            "selector_policy": EXACT_SELECTOR_POLICY,
            "reuse_scan_component_ids": sorted(reuse_scan_component_ids),
            "failure_count": len(bindings),
            "failure_fingerprint_set_sha256": line_set_sha(
                [value["failure_fingerprint"] for value in bindings]
            ),
            "failure_bindings": bindings,
            "previous_record_payload_sha256": "",
            "record_payload_sha256": "",
        }
        if set(record) != METADATA_RECORD_FIELDS:
            raise ValueError(f"METADATA_RECORD_FIELD_SET_MISMATCH:{record_id}")
        records.append(record)

    previous_record = "0" * 64
    for record in records:
        record["previous_record_payload_sha256"] = previous_record
        record["record_payload_sha256"] = payload_sha256(
            record, "record_payload_sha256"
        )
        previous_record = record["record_payload_sha256"]

    outputs: dict[str, bytes] = {RAW_COPY_REL.as_posix(): raw_bytes}
    correction_bindings: list[dict[str, Any]] = []
    correction_summaries: list[dict[str, Any]] = []
    previous_correction = "0" * 64
    corrected_fingerprints: set[str] = set()
    for spec in TRANSITION_SPECS:
        transition = str(spec["transition"])
        rules = sorted(rule for group_transition, rule in groups if group_transition == transition)
        for rule_id in rules:
            correction_id, filename = CORRECTION_SPECS[(transition, rule_id)]
            raw_failures = groups[(transition, rule_id)]
            fingerprints = sorted(
                failure_fingerprint(value, rule_id) for value in raw_failures
            )
            if corrected_fingerprints.intersection(fingerprints):
                raise ValueError(f"CORRECTION_FINGERPRINT_COLLISION:{correction_id}")
            corrected_fingerprints.update(fingerprints)
            component_ids = sorted(
                {
                    str(binding_by_fingerprint[value]["component_id"])
                    for value in fingerprints
                }
            )
            record_id = record_id_by_transition[transition]
            correction = {
                "schema_version": CORRECTION_RECORD_SCHEMA_VERSION,
                "record_kind": "HISTORICAL_DELTA_METADATA_EXACT_CORRECTION",
                "correction_id": correction_id,
                "ledger_id": LEDGER_ID,
                "metadata_record_ids": [record_id],
                "authorization_id": AUTHORIZATION_ID,
                "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
                "raw_report_sha256": SEALED_RAW_SHA256,
                "raw_report_head_sha": raw_head,
                "rule_id": rule_id,
                "transition_class_id": TRANSITION_CLASS_BY_RULE[rule_id],
                "source_commit": spec["source"],
                "parent_commit": spec["parent"],
                "component_ids": component_ids,
                "component_set_sha256": line_set_sha(component_ids),
                "failure_count": len(fingerprints),
                "failure_fingerprints": fingerprints,
                "failure_fingerprint_set_sha256": line_set_sha(fingerprints),
                "selector_policy": EXACT_SELECTOR_POLICY,
                "from_state": "RAW_HISTORICAL_METADATA_FAILURE",
                "to_effective_disposition": "CORRECTED_HISTORICAL_METADATA_DEBT",
                "untouched_in_current_delta": True,
                "touch_invalidation_policy": TOUCH_INVALIDATION_POLICY,
                "future_failure_policy": FUTURE_FAILURE_POLICY,
                "backlog_item_ids": [
                    "V076_HISTORICAL_METADATA_DEBT_"
                    f"{str(spec['source'])[:12].upper()}_{rule_id}"
                ],
                "previous_correction_payload_sha256": previous_correction,
                "record_payload_sha256": "",
            }
            if set(correction) != CORRECTION_RECORD_FIELDS:
                raise ValueError(
                    f"CORRECTION_RECORD_FIELD_SET_MISMATCH:{correction_id}"
                )
            correction["record_payload_sha256"] = payload_sha256(
                correction, "record_payload_sha256"
            )
            previous_correction = correction["record_payload_sha256"]
            correction_bytes = canonical_json_bytes(correction)
            correction_relative = (CORRECTION_ROOT_REL / filename).as_posix()
            outputs[correction_relative] = correction_bytes
            binding = {
                "correction_id": correction_id,
                "path": correction_relative,
                "file_sha256": sha256_bytes(correction_bytes),
                "record_payload_sha256": correction["record_payload_sha256"],
                "failure_count": len(fingerprints),
                "failure_fingerprints": fingerprints,
            }
            if set(binding) != CORRECTION_BINDING_FIELDS:
                raise ValueError(
                    f"CORRECTION_BINDING_FIELD_SET_MISMATCH:{correction_id}"
                )
            correction_bindings.append(binding)
            correction_summaries.append(
                {
                    "correction_id": correction_id,
                    "path": correction_relative,
                    "rule_id": rule_id,
                    "source_commit": spec["source"],
                    "failure_count": len(fingerprints),
                    "file_sha256": sha256_bytes(correction_bytes),
                    "record_payload_sha256": correction[
                        "record_payload_sha256"
                    ],
                }
            )
    if corrected_fingerprints != set(binding_by_fingerprint):
        raise ValueError("CORRECTION_COVERAGE_MISMATCH")
    if len(correction_bindings) != 4 or len(corrected_fingerprints) != 86:
        raise ValueError("CORRECTION_EXACT_COUNT_MISMATCH")

    scanner_bytes = _git_bytes(root, raw_head, SCANNER_REL.as_posix())
    if scanner_bytes is None:
        raise ValueError("RAW_SCANNER_BLOB_MISSING")
    ledger = {
        "schema_version": LEDGER_SCHEMA_VERSION,
        "ledger_id": LEDGER_ID,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "schema_path": SCHEMA_REL.as_posix(),
        "schema_sha256": sha256_bytes(schema_bytes),
        "raw_report_path": RAW_COPY_REL.as_posix(),
        "raw_report_sha256": SEALED_RAW_SHA256,
        "raw_report_head_sha": raw_head,
        "raw_report_tree_sha": raw_tree,
        "scanner_path": SCANNER_REL.as_posix(),
        "scanner_sha256": sha256_bytes(scanner_bytes),
        "registry_path": REGISTRY_REL.as_posix(),
        "selector_policy": EXACT_SELECTOR_POLICY,
        "record_count": len(records),
        "records": records,
        "failure_count": len(binding_by_fingerprint),
        "failure_fingerprint_set_sha256": line_set_sha(
            set(binding_by_fingerprint)
        ),
        "correction_record_count": len(correction_bindings),
        "correction_record_bindings": correction_bindings,
        "corrected_failure_count": len(corrected_fingerprints),
        "previous_ledger_path": "",
        "previous_ledger_sha256": "",
        "append_only": True,
        "ledger_payload_sha256": "",
    }
    if set(ledger) != LEDGER_FIELDS:
        raise ValueError("LEDGER_FIELD_SET_MISMATCH")
    ledger["ledger_payload_sha256"] = payload_sha256(
        ledger, "ledger_payload_sha256"
    )
    ledger_bytes = canonical_json_bytes(ledger)
    outputs[LEDGER_REL.as_posix()] = ledger_bytes
    if len(outputs) != 6:
        raise ValueError("FORMAL_OUTPUT_COUNT_MISMATCH")
    report = {
        "status": "PASS",
        "evaluated_head": evaluated_head,
        "raw_report_head": raw_head,
        "raw_report_tree": raw_tree,
        "raw_report_sha256": SEALED_RAW_SHA256,
        "raw_failure_count": SEALED_RAW_FAILURE_COUNT,
        "registry_sha256": REPAIRED_REGISTRY_SHA256,
        "schema_sha256": sha256_bytes(schema_bytes),
        "metadata_record_count": len(records),
        "metadata_record_ids": [value["record_id"] for value in records],
        "correction_record_count": len(correction_bindings),
        "correction_records": correction_summaries,
        "corrected_failure_count": len(corrected_fingerprints),
        "ledger_path": LEDGER_REL.as_posix(),
        "ledger_sha256": sha256_bytes(ledger_bytes),
        "ledger_payload_sha256": ledger["ledger_payload_sha256"],
        "previous_ledger_path": "",
        "previous_ledger_sha256": "",
    }
    return outputs, report


def _atomic_write(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp-v076-historical-delta")
    if temporary.exists():
        raise FileExistsError(f"TEMPORARY_OUTPUT_ALREADY_EXISTS:{temporary}")
    temporary.write_bytes(payload)
    os.replace(temporary, path)


def _formal_output_set() -> set[str]:
    return {
        RAW_COPY_REL.as_posix(),
        LEDGER_REL.as_posix(),
        *(
            (CORRECTION_ROOT_REL / filename).as_posix()
            for _correction_id, filename in CORRECTION_SPECS.values()
        ),
    }


def plan_formal_outputs(
    root: Path, outputs: dict[str, bytes]
) -> list[dict[str, Any]]:
    if set(outputs) != _formal_output_set():
        raise ValueError("FORMAL_OUTPUT_PATH_SET_MISMATCH")
    plan: list[dict[str, Any]] = []
    for relative, payload in outputs.items():
        path = _assert_path_inside_without_reparse(
            root, relative, allow_missing=True
        )
        if os.path.lexists(path):
            _assert_path_inside_without_reparse(root, relative, allow_missing=False)
            if not path.is_file():
                raise ValueError(f"FORMAL_OUTPUT_NOT_FILE:{relative}")
            existing = path.read_bytes()
            if existing != payload:
                raise ValueError(f"FORMAL_OUTPUT_CONFLICT:{relative}")
            action = "IDENTICAL"
        else:
            action = "CREATE"
        plan.append(
            {
                "path": relative,
                "action": action,
                "sha256": sha256_bytes(payload),
                "byte_count": len(payload),
            }
        )
    return plan


def write_formal_outputs(
    root: Path,
    outputs: dict[str, bytes],
    plan: list[dict[str, Any]],
) -> int:
    if any(value.get("action") not in {"CREATE", "IDENTICAL"} for value in plan):
        raise ValueError("FORMAL_OUTPUT_PLAN_INVALID")
    create_paths = {
        str(value["path"]) for value in plan if value.get("action") == "CREATE"
    }
    written = 0
    for relative, payload in outputs.items():
        if relative not in create_paths:
            continue
        target = _assert_path_inside_without_reparse(
            root, relative, allow_missing=True
        )
        target.parent.mkdir(parents=True, exist_ok=True)
        target = _assert_path_inside_without_reparse(
            root, relative, allow_missing=True
        )
        temporary = target.with_name(target.name + ".tmp-v076-hdm-evidence")
        if os.path.lexists(temporary):
            raise ValueError(f"FORMAL_OUTPUT_TEMPORARY_EXISTS:{relative}")
        try:
            with temporary.open("xb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            if os.path.lexists(target):
                if target.is_file() and target.read_bytes() == payload:
                    continue
                raise ValueError(f"FORMAL_OUTPUT_RACE_CONFLICT:{relative}")
            os.replace(temporary, target)
            written += 1
        finally:
            if os.path.lexists(temporary):
                temporary.unlink()
    final_plan = plan_formal_outputs(root, outputs)
    if any(value["action"] != "IDENTICAL" for value in final_plan):
        raise ValueError("FORMAL_OUTPUT_POST_WRITE_VERIFICATION_FAILED")
    return written


def canonical_registry_output(project: Path, requested_output: Path) -> tuple[Path, Path]:
    """Resolve and constrain repair output to this project's canonical Registry."""

    try:
        root = project.resolve(strict=True)
    except FileNotFoundError as exc:
        raise ValueError("PROJECT_ROOT_NOT_FOUND") from exc
    if not root.is_dir():
        raise ValueError("PROJECT_ROOT_NOT_DIRECTORY")

    lexical_registry_path = root / REGISTRY_REL
    if lexical_registry_path.is_symlink():
        raise ValueError("CANONICAL_REGISTRY_PATH_IS_SYMLINK")
    try:
        registry_path = lexical_registry_path.resolve(strict=True)
    except FileNotFoundError as exc:
        raise ValueError("CANONICAL_REGISTRY_PATH_NOT_FOUND") from exc
    if not registry_path.is_file():
        raise ValueError("CANONICAL_REGISTRY_PATH_NOT_FILE")
    try:
        registry_path.relative_to(root)
    except ValueError as exc:
        raise ValueError("CANONICAL_REGISTRY_PATH_ESCAPES_PROJECT") from exc

    output = requested_output.resolve(strict=False)
    if output != registry_path:
        raise ValueError("OUTPUT_NOT_CANONICAL_REGISTRY_PATH")
    return root, registry_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    repair = subparsers.add_parser("repair-registry")
    repair.add_argument("--project", type=Path, required=True)
    repair.add_argument("--raw-report", type=Path, required=True)
    repair.add_argument("--output", type=Path, required=True)
    evidence = subparsers.add_parser("build-historical-delta-evidence")
    evidence.add_argument("--project", type=Path, required=True)
    evidence.add_argument("--raw-report", type=Path, required=True)
    evidence.add_argument("--evaluated-head", required=True)
    evidence_mode = evidence.add_mutually_exclusive_group()
    evidence_mode.add_argument("--dry-run", action="store_true")
    evidence_mode.add_argument("--write", action="store_true")
    args = parser.parse_args()

    if args.command == "build-historical-delta-evidence":
        try:
            root = _git_project_root(args.project)
            raw_input = args.raw_report.absolute()
            if not os.path.lexists(raw_input):
                raise ValueError("SEALED_RAW_INPUT_NOT_FOUND")
            if _is_reparse_point(raw_input):
                raise ValueError("SEALED_RAW_INPUT_REPARSE_FORBIDDEN")
            raw_path = raw_input.resolve(strict=True)
            if not raw_path.is_file():
                raise ValueError("SEALED_RAW_INPUT_NOT_FILE")
            outputs, report = build_historical_delta_evidence(
                root,
                raw_path.read_bytes(),
                str(args.evaluated_head),
            )
            output_plan = plan_formal_outputs(root, outputs)
            written_count = (
                write_formal_outputs(root, outputs, output_plan)
                if args.write
                else 0
            )
        except (
            OSError,
            UnicodeDecodeError,
            json.JSONDecodeError,
            DuplicateJsonKeyError,
            ValueError,
        ) as exc:
            raise SystemExit(str(exc)) from exc
        report["mode"] = "WRITE" if args.write else "DRY_RUN"
        report["output_count"] = len(output_plan)
        report["output_plan"] = output_plan
        report["written_count"] = written_count
        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
        return 0

    try:
        root, registry_path = canonical_registry_output(args.project, args.output)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc
    raw_path = args.raw_report.resolve()
    if sha256_file(raw_path) != SEALED_RAW_SHA256:
        raise SystemExit("SEALED_RAW_SHA256_MISMATCH")
    raw_report = load_json_strict(raw_path)
    if (
        not isinstance(raw_report, dict)
        or raw_report.get("head_sha") != SEALED_RAW_HEAD
        or raw_report.get("include_worktree") is not False
        or raw_report.get("evaluated_source") != "COMMITTED_HEAD"
    ):
        raise SystemExit("SEALED_RAW_PROVENANCE_MISMATCH")
    original_registry_bytes = registry_path.read_bytes()
    registry = load_json_strict(registry_path)
    if not isinstance(registry, dict):
        raise SystemExit("REGISTRY_NOT_OBJECT")
    repaired, report = build_registry_successor(registry, raw_report)
    inventory = _historical_delta_inventory(raw_report)
    payload = render_registry_successor_bytes(
        original_registry_bytes,
        repaired,
        set(inventory["components"]),
    )
    _atomic_write(registry_path, payload)
    report["output"] = str(registry_path)
    report["output_sha256"] = sha256_bytes(payload)
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
