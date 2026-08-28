#!/usr/bin/env python3
"""Independent read-only Audit A/B for the V076 correction V2 contract.

This module intentionally does not import or execute the correction resolver or
its self-test.  It reads the frozen report, inventory, immutable records and
the authorised Git tree, then emits two append-only audit projections.  The
script is safe to rerun after a record regeneration; it never writes source
files or records and only replaces the two explicitly requested audit outputs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

try:
    from . import v076_post_touch_revalidation as _post_touch
except ImportError:
    import v076_post_touch_revalidation as _post_touch


AUTHORIZED_HEAD = "1e24cea73fc23e69e575fcea09df57238156af67"
AUTHORIZED_BASELINE_SHA = "b1097750f23007ba75d83f646fefe70a3bb5012540d38475a536fc5eee81e435"
AUTHORIZED_SCANNER_SHA = "d76cef3b028bd602d14250011e72484704f09f906da008da43890c7ac344ca65"
AUTHORIZED_V1_SHA = "5a3cd6ce9e218792b008cd22d120e80c2baa586ae2a53e52ce4b784c2c95909d"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_CORRECTION_V2_20260826"
RECORD_DIR = Path("docs/architecture/reuse_corrections/v2/records")
OUT_DIR = Path("reports/reuse/correction_v2")
SCANNER_PATHS = {
    "tools/v076/v076_reuse_point_inertia_gate.py",
    "tools/v076/v076_reuse_point_inertia_gate_selftest.py",
    "tools/rules/check_v06_mechanic_authority.py",
}
HISTORY_PREFIX = "HISTORY_"

FULL_CONVERGENCE_AUTHORIZATION_ID = (
    "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
)
FULL_CONVERGENCE_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
FULL_CONVERGENCE_BASELINE_SHA = "cfb84c08abacb294ea54ffc975f691869b33ac47a5d6a9f28377c54534f19166"
FULL_CONVERGENCE_FAILURE_SET_SHA = "dd3b9f88319ba008dafa0de8be14d4e7427a3cb02d7b3e11ed6d50e2c80893ef"
FULL_CONVERGENCE_SCHEMA_SHA = "87acd3a0eaa9ac75e7d5f6ffbd502f8a385275749d3a9ba5eae57a2b3f6b90df"
FULL_CONVERGENCE_SCHEMA = Path(
    "docs/architecture/reuse_corrections/v2/schema_full_convergence_20260827.json"
)
FULL_CONVERGENCE_SUCCESSOR_SCHEMA = Path(
    "docs/architecture/reuse_corrections/v2/"
    "schema_full_convergence_20260827_successor_v3.json"
)
FULL_CONVERGENCE_SUCCESSOR_SCHEMA_SHA = (
    "019bc57dcf92415c00b35b691f7adad9e736770bcf927622cb6db16b966c4543"
)
FULL_CONVERGENCE_BASELINE_REPORT = Path(
    "reports/reuse/correction_v2/epochs/full_convergence_20260827/"
    "baseline_raw_failure_report.json"
)
FULL_CONVERGENCE_RECORD_ROOT = (
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/"
)
FULL_CONVERGENCE_RECORD_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "full_convergence_record.v1"
)
FULL_CONVERGENCE_BATCH_MANIFEST_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "full_convergence_batch.v1"
)
DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "descendant_history_supplement.v2"
)
DESCENDANT_HISTORY_SUPPLEMENT_ID = "FULL_CONVERGENCE_DESCENDANT_HISTORY_20260827_002"
DESCENDANT_HISTORY_SUPPLEMENT_V3_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "descendant_history_supplement.v3"
)
DESCENDANT_HISTORY_SUPPLEMENT_V3_ID = "FULL_CONVERGENCE_DESCENDANT_HISTORY_20260827_003"
DESCENDANT_HISTORY_SCANNER = Path("tools/v076/v076_reuse_point_inertia_gate.py")
PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT = Path(
    "reports/reuse/correction_v2/epochs/full_convergence_20260827/"
    "descendant_history_supplement_570d6e3c.json"
)
PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA = (
    "65dcc1276767a1c2009fb2157041db2058783ca6ab23e49a3cafdc149b41fe82"
)
PREVIOUS_DESCENDANT_HISTORY_RAW = Path(
    "reports/reuse/correction_v2/epochs/full_convergence_20260827/"
    "descendant_history_raw_570d6e3c.json"
)
PREVIOUS_DESCENDANT_HISTORY_RAW_SHA = "72545ff3f19be36f47da40bdff693ba02d507c0e90feab622f9b470f98973fa9"
PREVIOUS_DESCENDANT_HISTORY_HEAD = "570d6e3c95b291f019351f5a3a325fc28cb57c80"
PREVIOUS_DESCENDANT_HISTORY_TREE = "e33db0d93844da7a804a5f33f8dadd8c3797260e"
PREVIOUS_DESCENDANT_HISTORY_SCANNER_SHA = (
    "f20759401008da5e22156a22af1d4bdcf527670cdfdc9cc73c76281d6783625a"
)
DESCENDANT_HISTORY_V3_RAW = Path(
    "reports/reuse/correction_v2/epochs/full_convergence_20260827/"
    "descendant_history_raw_da48a74b_003.json"
)
DESCENDANT_HISTORY_V3_SUPPLEMENT = Path(
    "reports/reuse/correction_v2/epochs/full_convergence_20260827/"
    "descendant_history_supplement_da48a74b_003.json"
)
DESCENDANT_HISTORY_V3_RAW_HEAD = "da48a74b3d12af9040230ea659b1663bd9eb2cbe"
DESCENDANT_HISTORY_V3_RAW_TREE = "2fa166e7aa8f7a3bcc33028fad9517ee2e8738a9"
DESCENDANT_HISTORY_V3_RAW_SHA = "812bd75c2e81d21a1a13305d45bf1045b1518b964f83ae88c2dd4f29ecf8dfac"
DESCENDANT_HISTORY_V3_SCANNER_SHA = "09bc04b52058cdafb7e966ca36230dc153dd637b829b766677ac542be02a9885"
DYNAMIC_REFERENCE_MANIFEST = Path("docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json")
EXACT_SUCCESSOR_FINGERPRINT_MAPPING = "EXACT_SUCCESSOR_FINGERPRINT_MAPPING"
EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT = "EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT"
ALLOWED_FROZEN_IDENTITY_DISPOSITIONS = {
    EXACT_SUCCESSOR_FINGERPRINT_MAPPING,
    EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT,
}
LEGACY_CHAIN_TERMINAL_SHA = "99f051cd23c250e0282db1708e49e2625d0e82279753a846a00a713614fed67d"
LEGACY_SEAL_PATH = Path(
    "reports/reuse/correction_v2/seals/ci_portability_v2/correction_authorization_manifest.json"
)
LEGACY_SEAL_SHA = "0731778c0b62f19bd15f7b6629ff82a67c11ec8ff9e6ca2923f4374eb170f948"
LEGACY_RECORD_SHA_BY_PATH = {
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_affected_domain_debt.json": "5d9ec47eed02e21cd19e36f9df2f402367e9498a717da07e2e2b1e1fe68aad6d",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_affected_owner_debt.json": "78160390f497b1d1b05078667c67dfafd928047e2118ef5f9cf98c518331fa33",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_change_class_debt.json": "144ad88f1b1f65ea973d8dbab4fb744a4eb71c4c8fde51bc7f50550aeae9c469",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_dynamic_reference_debt.json": "d66d75d42761fd1f6274ca9ea61b1af703d68816738f1d485ab50afacf4bb2db",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_focused_test_scope_debt.json": "654f021e14be59b690033d7667f9c3bd6324b85f8a3c3ba824785d18361ef042",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_reuse_scan_debt.json": "2e1c7ee76aff7dec57f1634be3a1913334ee282e2019ba09e97ae2b0396cac20",
}
BATCH_ARTIFACT_SPECS = {
    "batch_inventory_sha256": (
        "batch_inventory.json",
        "space_syndicate.v076.reuse_full_convergence.batch_inventory.v1",
        "inventory",
    ),
    "batch_classification_sha256": (
        "batch_classification.json",
        "space_syndicate.v076.reuse_full_convergence.batch_classification.v1",
        "classification",
    ),
    "batch_negative_checks_sha256": (
        "batch_negative_checks.json",
        "space_syndicate.v076.reuse_full_convergence.batch_negative_checks.v1",
        "negative_checks",
    ),
    "batch_review_a_sha256": (
        "batch_review_A.json",
        "space_syndicate.v076.reuse_full_convergence.batch_review.v1",
        "review_a",
    ),
    "batch_review_b_sha256": (
        "batch_review_B.json",
        "space_syndicate.v076.reuse_full_convergence.batch_review.v1",
        "review_b",
    ),
}

FULL_CONVERGENCE_RECORD_FIELDS = {
    "allowed_from_state",
    "allowed_rule_ids",
    "allowed_to_state",
    "authority_source_sha256",
    "authorization_base_head_sha",
    "authorization_id",
    "backlog_item_ids",
    "baseline_failure_set_sha256",
    "baseline_report_sha256",
    "batch_classification_sha256",
    "batch_id",
    "batch_inventory_sha256",
    "batch_negative_checks_sha256",
    "batch_review_a_sha256",
    "batch_review_b_sha256",
    "binding_head_sha",
    "binding_tree_sha",
    "component_ids",
    "component_set_sha256",
    "correction_id",
    "correction_reason",
    "created_at",
    "creator",
    "descendant_history_supplement_sha256",
    "domain_ids",
    "domain_set_sha256",
    "dynamic_reference_ids",
    "dynamic_reference_set_sha256",
    "failure_classes",
    "failure_count",
    "failure_fingerprint_set_sha256",
    "failure_fingerprints",
    "from_state",
    "future_failure_policy",
    "identity_binding_by_failure",
    "negative_examples",
    "owner_ids",
    "owner_set_sha256",
    "path_set_sha256",
    "paths",
    "previous_correction_chain_sha256",
    "record_kind",
    "record_payload_sha256",
    "required_untouched_state",
    "retirement_ids",
    "retirement_set_sha256",
    "revocation_policy",
    "rule_ids",
    "schema_version",
    "source_commit_set",
    "source_commit_set_sha256",
    "supersession_ids",
    "supersession_set_sha256",
    "to_effective_disposition",
    "touch_invalidation_policy",
    "transition_class_id",
    "untouched_in_current_delta",
}

FULL_CONVERGENCE_BATCH_MANIFEST_FIELDS = {
    "authorization_base_head_sha",
    "authorization_id",
    "baseline_failure_set_sha256",
    "baseline_report_sha256",
    "batch_classification_sha256",
    "batch_id",
    "batch_inventory_sha256",
    "batch_negative_checks_sha256",
    "batch_review_a_sha256",
    "batch_review_a_status",
    "batch_review_b_sha256",
    "batch_review_b_status",
    "batch_size_target",
    "batch_unknown_count",
    "batch_wildcard_count",
    "binding_head_sha",
    "binding_tree_sha",
    "current_failure_false_accept_count",
    "descendant_history_supplement_sha256",
    "failure_count",
    "failure_fingerprint_set_sha256",
    "failure_fingerprints",
    "identity_coverage_percent",
    "previous_batch_append_sha256",
    "record_bindings",
    "record_chain_start_sha256",
    "record_chain_terminal_sha256",
    "schema_version",
    "terminal_remainder_batch",
}

FULL_CONVERGENCE_RECORD_BINDING_FIELDS = {
    "correction_id",
    "failure_fingerprints",
    "path",
    "previous_correction_chain_sha256",
    "record_payload_sha256",
    "record_sha256",
}

FULL_CONVERGENCE_AUTHORITY_SOURCE_PATHS = (
    "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json",
    "docs/architecture/V076_SUPERSESSION_MAP.json",
    "docs/architecture/V076_OWNER_REUSE_MAP.md",
    "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json",
)

FULL_CONVERGENCE_IDENTITY_BINDING_FIELDS = {
    "authority_selectors",
    "current_blob_sha256",
    "current_component_id",
    "current_owner_id",
    "current_path",
    "current_production_reachability",
    "current_role",
    "diagnostic_only_status",
    "documentation_only_status",
    "domain_id",
    "dynamic_reference_status",
    "duplicate_identity_sha256",
    "duplicate_of_failure_fingerprint",
    "duplicate_reason",
    "first_seen_commit",
    "generated_evidence_status",
    "historical_blob_sha256",
    "historical_component_id",
    "historical_owner_id",
    "historical_path",
    "historical_production_reachability",
    "historical_role",
    "invalidation_policy",
    "last_seen_commit",
    "recommended_disposition",
    "retired_status",
    "source_commit",
    "subject_projection",
    "subject_projection_sha256",
    "superseded_by",
    "supersedes",
    "test_only_status",
}

FULL_CONVERGENCE_AUTHORITY_SELECTOR_FIELDS = {
    "component_ids",
    "dynamic_reference_ids",
    "paths",
    "retirement_ids",
    "supersession_ids",
}

FULL_CONVERGENCE_ALLOWED_DISPOSITIONS = {
    "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
    "HISTORICAL_DIAGNOSTIC_ONLY",
    "HISTORICAL_DOCUMENTATION_ONLY",
    "HISTORICAL_DUPLICATE_OBSERVATION",
    "HISTORICAL_DYNAMIC_REFERENCE_DIAGNOSTIC_ONLY",
    "HISTORICAL_DYNAMIC_REFERENCE_RESOLVED",
    "HISTORICAL_DYNAMIC_REFERENCE_SUPERSEDED",
    "HISTORICAL_DYNAMIC_REFERENCE_TEST_ONLY",
    "HISTORICAL_GENERATED_EVIDENCE",
    "HISTORICAL_RETIRED_NONREACHABLE",
    "HISTORICAL_SUPERSEDED_NONREACHABLE",
    "HISTORICAL_TEST_ONLY",
}

FULL_CONVERGENCE_DYNAMIC_REFERENCE_DISPOSITIONS = {
    value
    for value in FULL_CONVERGENCE_ALLOWED_DISPOSITIONS
    if value.startswith("HISTORICAL_DYNAMIC_REFERENCE_")
}

FULL_CONVERGENCE_IDENTITY_STATE_FIELDS = (
    "current_production_reachability",
    "current_role",
    "diagnostic_only_status",
    "documentation_only_status",
    "domain_id",
    "dynamic_reference_status",
    "generated_evidence_status",
    "historical_production_reachability",
    "historical_role",
    "retired_status",
    "test_only_status",
)

FULL_CONVERGENCE_SUBJECT_PROJECTION_FIELDS = {
    "dynamic_reference_rows",
    "owner_map_lines",
    "registry_rows",
    "supersession_rows",
}

FULL_CONVERGENCE_DYNAMIC_REFERENCE_ENTRY_FIELDS = {
    "callsite_contract",
    "dynamic_reference_id",
    "failure_policy",
    "loader",
    "production_reachable",
    "reference_expression",
    "resolution_method",
    "resolved_targets",
    "runtime_probe",
    "source_blob_sha256",
    "source_line_or_ast_location",
    "source_path",
    "target_set_sha256",
}

FULL_CONVERGENCE_DYNAMIC_REFERENCE_LOCATION_FIELDS = {
    "column",
    "containing_function",
    "line",
}

FULL_CONVERGENCE_DYNAMIC_REFERENCE_RUNTIME_PROBE_FIELDS = {
    "expected_target_count",
    "probe_id",
    "required_before_production_claim",
    "test_path",
}

FULL_CONVERGENCE_DYNAMIC_REFERENCE_FAILURE_POLICY_FIELDS = {
    "future_site_auto_resolution_count",
    "source_blob_change_invalidates",
    "source_location_change_invalidates",
    "target_set_change_invalidates",
    "unknown_callsite_fails_closed",
    "wildcard_count",
}

FULL_CONVERGENCE_DYNAMIC_REFERENCE_RESOLUTION_METHODS = {
    "EXACT_CONSTANT_CALL_GRAPH_MANIFEST",
}

FULL_CONVERGENCE_DYNAMIC_REFERENCE_CALLSITE_FIELDS = {
    "allowed_argument_constants",
    "external_or_unknown_invocation_count",
    "helper_function",
    "required_invocation_count",
    "required_loader_sites",
}

FULL_CONVERGENCE_DYNAMIC_REFERENCE_LOADER_SITE_FIELDS = {
    "column",
    "line",
    "loader",
    "reference_expression",
}

FULL_CONVERGENCE_REGISTRY_ALLOWED_COMPONENT_ROLES = {
    "ADAPTER",
    "CONSUMER",
    "DIAGNOSTIC_BENCH",
    "DIAGNOSTIC_ONLY",
    "DOCUMENTATION_ONLY",
    "GENERATED_EVIDENCE",
    "INPUT_ROUTING",
    "OWNER",
    "PORT",
    "PRESENTATION",
    "PROJECTION",
    "REDUCER",
    "RETIRED",
    "TEST_SUPPORT",
    "TOOLING",
}

FULL_CONVERGENCE_REGISTRY_NONPRODUCTION_ROLES = {
    "DIAGNOSTIC_BENCH",
    "DIAGNOSTIC_ONLY",
    "DOCUMENTATION_ONLY",
    "GENERATED_EVIDENCE",
    "RETIRED",
    "TEST_SUPPORT",
    "TOOLING",
}

FULL_CONVERGENCE_REGISTRY_ALLOWED_REUSE_DISPOSITIONS = {
    "ADAPT_AS_CONSUMER",
    "ADOPT_AS_OWNER",
    "REFERENCE_ONLY",
    "REUSE_AS_TEST",
}

FULL_CONVERGENCE_REGISTRY_COMPONENT_INVENTORY_FIELDS = {
    "authority_source_kind",
    "change_class",
    "class_name",
    "component_id",
    "component_role",
    "domain_id",
    "focused_test_ids",
    "golden_scenario_steps",
    "new_component_justification",
    "owner_component_id",
    "owner_path",
    "owns_identity",
    "owns_presentation",
    "owns_replay",
    "owns_rng",
    "owns_save",
    "owns_tick",
    "path",
    "production_reachable",
    "reads_authority",
    "reuse_candidates_considered",
    "reuse_disposition",
    "reuse_scan",
    "reuse_source_ids",
    "superseded_by",
    "supersedes",
    "writes_authority",
}

FULL_CONVERGENCE_REGISTRY_COMPONENT_INVENTORY_REQUIRED_FIELDS = (
    FULL_CONVERGENCE_REGISTRY_COMPONENT_INVENTORY_FIELDS - {"reuse_scan"}
)

FULL_CONVERGENCE_REGISTRY_HISTORICAL_BACKFILL_FIELDS = {
    "authority_source_kind",
    "component_id",
    "current_disposition",
    "historical_role",
    "production_reachability",
    "source_blob",
    "source_commit",
    "supersession",
}

FULL_CONVERGENCE_IDENTITY_NON_MIGRATION_DISPOSITIONS = {
    "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
    "HISTORICAL_DIAGNOSTIC_ONLY",
    "HISTORICAL_DOCUMENTATION_ONLY",
    "HISTORICAL_DUPLICATE_OBSERVATION",
    "HISTORICAL_DYNAMIC_REFERENCE_DIAGNOSTIC_ONLY",
    "HISTORICAL_DYNAMIC_REFERENCE_RESOLVED",
    "HISTORICAL_DYNAMIC_REFERENCE_TEST_ONLY",
    "HISTORICAL_GENERATED_EVIDENCE",
    "HISTORICAL_RETIRED_NONREACHABLE",
    "HISTORICAL_TEST_ONLY",
}

FULL_CONVERGENCE_DISALLOWED_TOKENS = {
    "*",
    "directory",
    "glob",
    "grandfather",
    "ignore",
    "legacy",
    "misc",
    "other",
    "prefix",
    "regex",
    "unknown",
    "unknown_accepted",
    "waive",
}

FULL_CONVERGENCE_TOUCH_INVALIDATION_POLICY = {
    "BLOB_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "COMPONENT_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "DOMAIN_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
    "OWNER_BINDING_CHANGED_INVALIDATION": True,
    "PRODUCTION_REACHABILITY_CHANGED_INVALIDATION": True,
    "RETIREMENT_CHANGED_INVALIDATION": True,
    "SUPERSESSION_CHANGED_INVALIDATION": True,
    "TOUCH_INVALIDATES_CORRECTION": True,
    "UNRELATED_DELTA_PRESERVES_CORRECTION": True,
}

FULL_CONVERGENCE_REVOCATION_POLICY = {
    "OLD_RECORD_MUTATION_FORBIDDEN": True,
    "REVOCATION_APPEND_ONLY": True,
}

DESCENDANT_HISTORY_IDENTITY_FIELDS = {
    "failure_fingerprint",
    "raw_failure",
    "repaired_frozen_current_fingerprints",
    "rule_id",
    "source_blob_sha256",
    "source_commit_sha",
    "source_component_id",
    "source_path",
    "transition_new_sha",
    "transition_old_sha",
}

FROZEN_IDENTITY_DISPOSITION_FIELDS = {
    "baseline_scanner_tool_sha256",
    "disposition",
    "evidence",
    "failure_fingerprint",
    "live_scanner_tool_sha256",
    "raw_failure",
    "rule_id",
    "subject_kind",
    "subject_value",
    "successor_failure_fingerprint",
    "transition_new_sha",
    "transition_old_sha",
    "wildcard_count",
}

SUCCESSOR_DISPOSITION_EVIDENCE_FIELDS = {
    "baseline_raw_report_sha256",
    "evidence_kind",
    "live_raw_report_sha256",
    "successor_raw_failure",
    "successor_rule_id",
    "successor_subject_kind",
    "successor_subject_value",
    "successor_transition_new_sha",
    "successor_transition_old_sha",
}

FALSE_COMPONENT_RETIREMENT_EVIDENCE_FIELDS = {
    "baseline_raw_report_sha256",
    "dynamic_reference_ids",
    "dynamic_reference_manifest_blob_sha256",
    "dynamic_reference_manifest_path",
    "evidence_kind",
    "live_raw_report_sha256",
    "resolved_target",
    "subject_directly_changed",
}

DESCENDANT_HISTORY_SUPPLEMENT_FIELDS = {
    "authorization_base_head_sha",
    "authorization_id",
    "baseline_historical_membership_policy",
    "baseline_failure_set_sha256",
    "baseline_report_sha256",
    "baseline_scanner_tool_sha256",
    "committed_only",
    "correction_membership_scope",
    "descendant_history_failure_count",
    "descendant_history_fingerprint_set_sha256",
    "descendant_history_fingerprints",
    "directory_discovery_allowed",
    "disposition_wildcard_count",
    "frozen_identity_disposition_by_failure",
    "future_failure_auto_membership_allowed",
    "identity_binding_by_failure",
    "live_frozen_historical_failure_count",
    "live_frozen_historical_fingerprint_set_sha256",
    "live_frozen_historical_fingerprints",
    "missing_frozen_historical_failure_count",
    "missing_frozen_historical_fingerprint_set_sha256",
    "missing_frozen_historical_fingerprints",
    "raw_current_delta_failure_count",
    "raw_failure_detection_suppressed_count",
    "raw_failure_count",
    "raw_historical_failure_count",
    "raw_report_head_sha",
    "raw_report_path",
    "raw_report_sha256",
    "raw_report_tree_sha",
    "repaired_frozen_current_failure_count",
    "repaired_frozen_current_fingerprint_set_sha256",
    "repaired_frozen_current_fingerprints",
    "scanner_tool_path",
    "scanner_tool_sha256",
    "schema_version",
    "supplement_id",
    "wildcard_membership_allowed",
}

DESCENDANT_HISTORY_SCANNER_EVOLUTION_FIELDS = {
    "evolution_kind",
    "from_raw_report_head_sha",
    "from_raw_report_tree_sha",
    "from_scanner_tool_sha256",
    "removed_rule_count",
    "scanner_change_commit_count",
    "scanner_change_commit_sequence_sha256",
    "scanner_change_commit_shas",
    "scanner_history_depth_reduction_count",
    "scanner_scope_reduction_count",
    "scanner_severity_downgrade_count",
    "scanner_tool_path",
    "to_raw_report_head_sha",
    "to_raw_report_tree_sha",
    "to_scanner_tool_sha256",
    "weakening_allowed",
}

DESCENDANT_HISTORY_SUPPLEMENT_V3_FIELDS = DESCENDANT_HISTORY_SUPPLEMENT_FIELDS | {
    "previous_supplement_path",
    "previous_supplement_sha256",
    "scanner_evolution",
}


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha_file(path: Path) -> str:
    return _sha_bytes(path.read_bytes())


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _json(path: Path) -> Any:
    return json.loads(
        path.read_text(encoding="utf-8-sig"),
        object_pairs_hook=_strict_object,
    )


def _git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def _git_bytes(root: Path, commit: str, relative: str) -> bytes | None:
    result = subprocess.run(
        ["git", "-C", str(root), "show", f"{commit}:{relative}"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return bytes(result.stdout) if result.returncode == 0 else None


def _sealed_tree_blob_finding(
    root: Path,
    path: Path,
    *,
    evaluated_head: str,
    expected_sha: str,
    code: str,
    message: str,
) -> dict[str, Any] | None:
    """Independently seal a tracked artifact to its evaluated-tree blob.

    The authority digest is over committed blob bytes.  The worktree copy must
    still clean-filter to the same Git object id so local edits cannot hide
    behind a valid commit while configured checkout EOL conversion stays
    portable.
    """

    relative = _exact_repo_relative(root, path)
    committed = (
        _git_bytes(root, evaluated_head, relative)
        if relative and _is_commit(evaluated_head)
        else None
    )
    tree_oid = (
        _git(root, "rev-parse", f"{evaluated_head}:{relative}")
        if relative and _is_commit(evaluated_head)
        else ""
    )
    clean_oid = (
        _git(root, "hash-object", f"--path={relative}", "--", relative)
        if relative and path.is_file()
        else ""
    )
    if (
        committed is None
        or _sha_bytes(committed) != expected_sha
        or re.fullmatch(r"[0-9a-f]{40}", tree_oid) is None
        or clean_oid != tree_oid
    ):
        return _finding(
            code,
            "P0",
            message,
            path=relative or str(path),
            expected_sha256=expected_sha,
            committed_sha256=(
                _sha_bytes(committed) if committed is not None else "MISSING"
            ),
        )
    return None


def _is_sha256(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def _is_commit(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def _is_exact_int(value: Any) -> bool:
    """Return true only for a JSON integer, never for Python's bool subtype."""

    return type(value) is int


def _is_exact_int_equal(value: Any, expected: int) -> bool:
    return _is_exact_int(value) and value == expected


def _is_exact_positive_int(value: Any) -> bool:
    return _is_exact_int(value) and value >= 1


def _matches_exact_scalar_contract(value: Any, expected: Any) -> bool:
    if type(expected) is bool:
        return value is expected
    if type(expected) is int:
        return _is_exact_int_equal(value, expected)
    return value == expected


def _is_exact_future_failure_policy(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and set(value)
        == {
            "FUTURE_FAILURE_AUTO_CORRECTION_COUNT",
            "NEW_FAILURE_REQUIRES_NEW_RECORD",
        }
        and _is_exact_int_equal(
            value.get("FUTURE_FAILURE_AUTO_CORRECTION_COUNT"), 0
        )
        and value.get("NEW_FAILURE_REQUIRES_NEW_RECORD") is True
    )


def _normalize_path(value: str) -> str:
    return value.removeprefix("res://").replace("\\", "/")


def _is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    if not _is_commit(ancestor) or not _is_commit(descendant):
        return False
    result = subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", ancestor, descendant],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def _resolve_commit_prefix(root: Path, prefix: str) -> str:
    if re.fullmatch(r"[0-9a-f]{12}", prefix) is None:
        return ""
    resolved = _git(root, "rev-parse", f"{prefix}^{{commit}}")
    return resolved if _is_commit(resolved) and resolved.startswith(prefix) else ""


def _walk_dicts(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_dicts(child)


def _subject_projection(root: Path, commit: str, selector: dict[str, Any]) -> dict[str, Any] | None:
    registry_bytes = _git_bytes(
        root, commit, "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
    )
    supersession_bytes = _git_bytes(
        root, commit, "docs/architecture/V076_SUPERSESSION_MAP.json"
    )
    owner_bytes = _git_bytes(
        root, commit, "docs/architecture/V076_OWNER_REUSE_MAP.md"
    )
    dynamic_reference_bytes = _git_bytes(
        root, commit, "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json"
    )
    if (
        registry_bytes is None
        or supersession_bytes is None
        or owner_bytes is None
        or dynamic_reference_bytes is None
    ):
        return None
    try:
        registry = json.loads(
            registry_bytes.decode("utf-8-sig"), object_pairs_hook=_strict_object
        )
        supersession = json.loads(
            supersession_bytes.decode("utf-8-sig"), object_pairs_hook=_strict_object
        )
        dynamic_reference_manifest = json.loads(
            dynamic_reference_bytes.decode("utf-8-sig"),
            object_pairs_hook=_strict_object,
        )
    except (UnicodeDecodeError, ValueError):
        return None
    component_ids = {str(value) for value in selector.get("component_ids", [])}
    paths = {str(value).removeprefix("res://").replace("\\", "/") for value in selector.get("paths", [])}
    dynamic_reference_ids = {
        str(value) for value in selector.get("dynamic_reference_ids", [])
    }
    supersession_ids = {
        str(value) for value in selector.get("supersession_ids", [])
    }
    retirement_ids = {
        str(value) for value in selector.get("retirement_ids", [])
    }
    registry_candidates: list[Any] = []
    if isinstance(registry, dict):
        for key in ("component_inventory", "historical_identity_backfill"):
            values = registry.get(key, [])
            if isinstance(values, list):
                for value in values:
                    if isinstance(value, dict):
                        tagged = dict(value)
                        tagged["authority_source_kind"] = key
                        registry_candidates.append(tagged)
    registry_rows = sorted(
        [
            row
            for row in registry_candidates
            if isinstance(row, dict)
            and (
                str(row.get("component_id", "")) in component_ids
                or _normalize_path(str(row.get("path", ""))) in paths
            )
        ],
        key=_canonical,
    )
    supersession_candidates: list[Any] = []
    if isinstance(supersession, dict):
        for key in ("entries", "retirement_entries"):
            values = supersession.get(key, [])
            if isinstance(values, list):
                supersession_candidates.extend(values)
    supersession_rows = sorted(
        [
            row
            for row in supersession_candidates
            if isinstance(row, dict)
            and (
                str(row.get("supersession_id", "")) in supersession_ids
                or str(row.get("retirement_id", "")) in retirement_ids
            )
        ],
        key=_canonical,
    )
    dynamic_candidates = (
        dynamic_reference_manifest.get("entries", [])
        if isinstance(dynamic_reference_manifest, dict)
        else []
    )
    dynamic_reference_rows = sorted(
        [
            row
            for row in dynamic_candidates
            if isinstance(row, dict)
            and str(row.get("dynamic_reference_id", ""))
            in dynamic_reference_ids
        ],
        key=_canonical,
    )
    needles = sorted(
        component_ids
        | paths
        | dynamic_reference_ids
        | supersession_ids
        | retirement_ids
    )
    owner_lines = sorted({
        line.rstrip()
        for line in owner_bytes.decode("utf-8-sig", errors="replace").splitlines()
        if any(needle in line for needle in needles)
    })
    if (
        not registry_rows
        and not supersession_rows
        and not owner_lines
        and not dynamic_reference_rows
    ):
        return None
    return {
        "dynamic_reference_rows": dynamic_reference_rows,
        "owner_map_lines": owner_lines,
        "registry_rows": registry_rows,
        "supersession_rows": supersession_rows,
    }


def _canonical(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _line_set_sha(values: list[str]) -> str:
    return _sha_bytes(("\n".join(sorted(values)) + "\n").encode("utf-8"))


def _authorized_failure_fingerprint_sets(report: dict[str, Any]) -> dict[str, set[str]]:
    result = {"historical": set(), "current": set()}
    if not isinstance(report, dict):
        return result
    values = report.get("failures")
    if not isinstance(values, list):
        return result
    for value in values:
        raw = str(value)
        rule_id = raw.split(":", 1)[0]
        historical = rule_id.startswith(HISTORY_PREFIX)
        bucket = "HISTORICAL" if historical else "CURRENT_DELTA_FAILURE"
        payload = f"V076_RAW_FAILURE_V2\n{bucket}\n{rule_id}\n{raw}\n".encode("utf-8")
        result["historical" if historical else "current"].add(
            "V2F-" + _sha_bytes(payload)
        )
    return result


def _authorized_failure_identity_by_fingerprint(
    report: dict[str, Any],
) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    values = report.get("failures") if isinstance(report, dict) else None
    if not isinstance(values, list):
        return result
    metadata_rules = {
        "HISTORY_COMPONENT_CHANGE_CLASS_NOT_DECLARED",
        "HISTORY_PRODUCT_AFFECTED_DOMAIN_MISSING",
        "HISTORY_PRODUCT_AFFECTED_OWNER_MISSING",
        "HISTORY_PRODUCT_FOCUSED_TESTS_MISSING",
        "HISTORY_PRODUCT_REUSE_SCAN_INVALID",
    }
    for value in values:
        raw = str(value)
        rule_id = raw.split(":", 1)[0]
        historical = rule_id.startswith(HISTORY_PREFIX)
        bucket = "HISTORICAL" if historical else "CURRENT_DELTA_FAILURE"
        payload = f"V076_RAW_FAILURE_V2\n{bucket}\n{rule_id}\n{raw}\n".encode("utf-8")
        fingerprint = "V2F-" + _sha_bytes(payload)
        parts = raw.split(":")
        transition_index = next(
            (
                index
                for index, token in enumerate(parts)
                if re.fullmatch(r"[0-9a-f]{12}->[0-9a-f]{12}", token)
            ),
            -1,
        )
        old_prefix = ""
        new_prefix = ""
        subject_kind = ""
        subject_value = ""
        if historical and transition_index >= 0:
            old_prefix, new_prefix = parts[transition_index].split("->", 1)
            if transition_index + 1 < len(parts):
                subject_kind = "component_id" if rule_id in metadata_rules else "path"
                subject_value = parts[transition_index + 1].removeprefix("res://").replace("\\", "/")
        result[fingerprint] = {
            "bucket": bucket,
            "failure_fingerprint": fingerprint,
            "raw_failure": raw,
            "rule_id": rule_id,
            "transition_old_prefix": old_prefix,
            "transition_new_prefix": new_prefix,
            "subject_kind": subject_kind,
            "subject_value": subject_value,
        }
    return result


def _exact_repo_relative(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return ""


def _descendant_history_supplement_core_findings(
    root: Path,
    *,
    supplement_path: Path | None,
    raw_report_path: Path | None,
    scanner_path: Path | None,
    evaluated_head: str,
    baseline_report: dict[str, Any],
    baseline_sets: dict[str, set[str]],
    require_live_scanner_bytes: bool = True,
    expected_schema_version: str = DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION,
    expected_supplement_id: str = DESCENDANT_HISTORY_SUPPLEMENT_ID,
    expected_fields: set[str] = DESCENDANT_HISTORY_SUPPLEMENT_FIELDS,
) -> tuple[
    list[dict[str, Any]],
    set[str],
    dict[str, dict[str, str]],
    set[str],
    str,
    str,
]:
    """Independently duplicate the one-shot descendant HISTORY seal checks."""

    findings: list[dict[str, Any]] = []

    def add(code: str, message: str, **evidence: Any) -> None:
        findings.append(_finding(code, "P0", message, **evidence))

    if supplement_path is None or raw_report_path is None or scanner_path is None:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_EXPLICIT_INPUT_REQUIRED",
            "supplement, raw report, and scanner paths must all be supplied explicitly",
        )
        return findings, set(), {}, set(), "", ""
    supplement_relative = _exact_repo_relative(root, supplement_path)
    raw_report_relative = _exact_repo_relative(root, raw_report_path)
    scanner_relative = _exact_repo_relative(root, scanner_path)
    epoch_prefix = FULL_CONVERGENCE_BASELINE_REPORT.parent.as_posix() + "/"
    if not supplement_relative.startswith(epoch_prefix):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_SUPPLEMENT_PATH_INVALID",
            "supplement path is outside the explicit full-convergence epoch",
        )
    if not raw_report_relative.startswith(epoch_prefix):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_REPORT_PATH_INVALID",
            "raw report path is outside the explicit full-convergence epoch",
        )
    if scanner_relative != DESCENDANT_HISTORY_SCANNER.as_posix():
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_SCANNER_PATH_INVALID",
            "scanner path is not the one exact V076 gate implementation",
        )
    try:
        supplement = _json(supplement_path)
        supplement_sha = _sha_file(supplement_path)
    except (OSError, ValueError):
        supplement = None
        supplement_sha = ""
    if not isinstance(supplement, dict):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_SUPPLEMENT_INVALID",
            "supplement is not one strict JSON object",
        )
        return findings, set(), {}, set(), supplement_sha, ""
    if set(supplement) != expected_fields:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_SUPPLEMENT_FIELD_SET_INVALID",
            "supplement field set differs from the closed contract",
        )
    for field, expected in (
        ("schema_version", expected_schema_version),
        ("supplement_id", expected_supplement_id),
        ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
        ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
        ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
        ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
        ("baseline_historical_membership_policy", "LIVE_RAW_OR_EXACT_APPEND_ONLY_DISPOSITION"),
        ("committed_only", True),
        ("correction_membership_scope", "LIVE_HISTORICAL_ONLY"),
        ("directory_discovery_allowed", False),
        ("disposition_wildcard_count", 0),
        ("wildcard_membership_allowed", False),
        ("future_failure_auto_membership_allowed", False),
        ("raw_current_delta_failure_count", 0),
        ("raw_failure_detection_suppressed_count", 0),
        ("raw_report_path", raw_report_relative),
        ("scanner_tool_path", DESCENDANT_HISTORY_SCANNER.as_posix()),
    ):
        if not _matches_exact_scalar_contract(supplement.get(field), expected):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_AUTHORITY_MISMATCH",
                "supplement authority or fail-closed policy differs from the contract",
                field=field,
                expected=expected,
                actual=supplement.get(field),
            )
    try:
        raw_report = _json(raw_report_path)
        raw_report_sha = _sha_file(raw_report_path)
    except (OSError, ValueError):
        raw_report = None
        raw_report_sha = ""
    if not isinstance(raw_report, dict):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_REPORT_INVALID",
            "the explicit final raw report is not one strict JSON object",
        )
        return findings, set(), {}, set(), supplement_sha, ""
    if supplement.get("raw_report_sha256") != raw_report_sha:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_REPORT_HASH_MISMATCH",
            "final raw report bytes differ from the supplement digest",
        )
    raw_values = raw_report.get("failures")
    raw_rendered = [str(value) for value in raw_values] if isinstance(raw_values, list) else []
    if not isinstance(raw_values, list) or len(raw_rendered) != len(set(raw_rendered)):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_FAILURE_SET_INVALID",
            "final raw report failures are missing or duplicated",
        )
    final_sets = _authorized_failure_fingerprint_sets(raw_report)
    final_identities = _authorized_failure_identity_by_fingerprint(raw_report)
    if final_sets["current"]:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_FINAL_CURRENT_NOT_ZERO",
            "the sealed final raw report still contains current failures",
            current_failure_count=len(final_sets["current"]),
        )
    live_frozen = baseline_sets["historical"] & final_sets["historical"]
    missing_frozen = baseline_sets["historical"] - final_sets["historical"]
    descendants = final_sets["historical"] - baseline_sets["historical"]
    declared = supplement.get("descendant_history_fingerprints")
    rendered_declared = [str(value) for value in declared] if isinstance(declared, list) else []
    if (
        not descendants
        or rendered_declared != sorted(rendered_declared)
        or len(rendered_declared) != len(set(rendered_declared))
        or set(rendered_declared) != descendants
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_MEMBERSHIP_MISMATCH",
            "declared membership is not the exact nonempty final-minus-d701 historical set",
        )
    if (
        not _is_exact_int_equal(
            supplement.get("descendant_history_failure_count"), len(descendants)
        )
        or supplement.get("descendant_history_fingerprint_set_sha256")
        != _line_set_sha(rendered_declared)
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_MEMBERSHIP_DIGEST_MISMATCH",
            "descendant membership count or digest is not canonical",
        )
    declared_live_frozen = supplement.get("live_frozen_historical_fingerprints")
    rendered_live_frozen = (
        [str(value) for value in declared_live_frozen]
        if isinstance(declared_live_frozen, list)
        else []
    )
    if (
        rendered_live_frozen != sorted(rendered_live_frozen)
        or len(rendered_live_frozen) != len(set(rendered_live_frozen))
        or set(rendered_live_frozen) != live_frozen
        or not _is_exact_int_equal(
            supplement.get("live_frozen_historical_failure_count"),
            len(live_frozen),
        )
        or supplement.get("live_frozen_historical_fingerprint_set_sha256")
        != _line_set_sha(rendered_live_frozen)
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_LIVE_FROZEN_SET_INVALID",
            "live frozen membership, count, or digest is not exact",
        )
    declared_missing_frozen = supplement.get("missing_frozen_historical_fingerprints")
    rendered_missing_frozen = (
        [str(value) for value in declared_missing_frozen]
        if isinstance(declared_missing_frozen, list)
        else []
    )
    if (
        rendered_missing_frozen != sorted(rendered_missing_frozen)
        or len(rendered_missing_frozen) != len(set(rendered_missing_frozen))
        or set(rendered_missing_frozen) != missing_frozen
        or not _is_exact_int_equal(
            supplement.get("missing_frozen_historical_failure_count"),
            len(missing_frozen),
        )
        or supplement.get("missing_frozen_historical_fingerprint_set_sha256")
        != _line_set_sha(rendered_missing_frozen)
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_MISSING_FROZEN_SET_INVALID",
            "missing frozen membership, count, or digest is not exact",
        )
    if (
        not _is_exact_int_equal(
            supplement.get("raw_failure_count"), len(raw_rendered)
        )
        or not _is_exact_int_equal(
            supplement.get("raw_historical_failure_count"),
            len(final_sets["historical"]),
        )
        or not _is_exact_int_equal(
            supplement.get("raw_current_delta_failure_count"),
            len(final_sets["current"]),
        )
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_COUNTS_MISMATCH",
            "supplement raw counts differ from the parsed final report",
        )
    report_head = str(raw_report.get("head_sha", ""))
    report_tree = _git(root, "rev-parse", f"{report_head}^{{tree}}")
    if (
        supplement.get("raw_report_head_sha") != report_head
        or not _is_commit(report_head)
        or supplement.get("raw_report_tree_sha") != report_tree
        or not _is_commit(report_tree)
        or raw_report.get("include_worktree") is not False
        or raw_report.get("evaluated_source") != "COMMITTED_HEAD"
        or raw_report.get("merge_base_sha") != FULL_CONVERGENCE_BASE_HEAD
        or not _is_ancestor(root, FULL_CONVERGENCE_BASE_HEAD, report_head)
        or not _is_ancestor(root, report_head, evaluated_head)
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_COMMITTED_HEAD_BINDING_INVALID",
            "raw report is not bound to one authorized committed Head and tree",
        )
    try:
        scanner_sha = _sha_file(scanner_path)
    except OSError:
        scanner_sha = ""
    scanner_at_head = _git_bytes(root, report_head, DESCENDANT_HISTORY_SCANNER.as_posix())
    scanner_at_head_sha = _sha_bytes(scanner_at_head) if scanner_at_head is not None else ""
    if supplement.get("scanner_tool_sha256") != scanner_at_head_sha or (
        require_live_scanner_bytes and scanner_sha != scanner_at_head_sha
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_SCANNER_HASH_MISMATCH",
            "scanner bytes differ from the exact tool committed at the report Head",
        )
    baseline_scanner_bytes = _git_bytes(
        root, FULL_CONVERGENCE_BASE_HEAD, DESCENDANT_HISTORY_SCANNER.as_posix()
    )
    baseline_scanner_sha = (
        _sha_bytes(baseline_scanner_bytes)
        if baseline_scanner_bytes is not None
        else ""
    )
    if supplement.get("baseline_scanner_tool_sha256") != baseline_scanner_sha:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_BASELINE_SCANNER_HASH_MISMATCH",
            "baseline scanner bytes differ from the exact d701 tool",
        )
    baseline_identities = _authorized_failure_identity_by_fingerprint(baseline_report)
    manifest_bytes = _git_bytes(root, report_head, DYNAMIC_REFERENCE_MANIFEST.as_posix())
    manifest_sha = _sha_bytes(manifest_bytes) if manifest_bytes is not None else ""
    try:
        manifest_document = json.loads(
            (manifest_bytes or b"").decode("utf-8-sig"),
            object_pairs_hook=_strict_object,
        )
    except (UnicodeDecodeError, json.JSONDecodeError, DuplicateJsonKeyError):
        manifest_document = {}
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_DYNAMIC_REFERENCE_MANIFEST_INVALID",
            "the exact live dynamic-reference manifest is invalid",
        )
    target_to_ids: dict[str, list[str]] = {}
    entries = manifest_document.get("entries", []) if isinstance(manifest_document, dict) else []
    if not isinstance(entries, list):
        entries = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        reference_id = str(entry.get("dynamic_reference_id", ""))
        targets = entry.get("resolved_targets", [])
        if not reference_id or not isinstance(targets, list):
            continue
        for target in targets:
            normalized = _normalize_path(str(target))
            if normalized:
                target_to_ids.setdefault(normalized, []).append(reference_id)
    for target in target_to_ids:
        target_to_ids[target] = sorted(set(target_to_ids[target]))
    dispositions = supplement.get("frozen_identity_disposition_by_failure")
    if not isinstance(dispositions, dict) or set(dispositions) != missing_frozen:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_FROZEN_DISPOSITION_SET_INVALID",
            "the disposition map does not exactly cover every missing frozen identity",
        )
        dispositions = dispositions if isinstance(dispositions, dict) else {}
    verified_dispositions: set[str] = set()
    used_successors: set[str] = set()
    for fingerprint in sorted(missing_frozen):
        before = len(findings)
        row = dispositions.get(fingerprint)
        frozen_identity = baseline_identities.get(fingerprint)
        if not isinstance(row, dict) or set(row) != FROZEN_IDENTITY_DISPOSITION_FIELDS:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_DISPOSITION_FIELDS_INVALID",
                "one frozen disposition differs from the closed field contract",
                fingerprint=fingerprint,
            )
            continue
        if not isinstance(frozen_identity, dict):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_DISPOSITION_IDENTITY_UNRESOLVED",
                "one frozen disposition has no exact baseline identity",
                fingerprint=fingerprint,
            )
            continue
        expected_common = {
            "failure_fingerprint": fingerprint,
            "raw_failure": frozen_identity.get("raw_failure"),
            "rule_id": frozen_identity.get("rule_id"),
            "baseline_scanner_tool_sha256": baseline_scanner_sha,
            "live_scanner_tool_sha256": scanner_at_head_sha,
            "subject_kind": frozen_identity.get("subject_kind"),
            "subject_value": frozen_identity.get("subject_value"),
            "wildcard_count": 0,
        }
        if (
            not _is_exact_int_equal(row.get("wildcard_count"), 0)
            or any(
                row.get(field) != expected
                for field, expected in expected_common.items()
                if field != "wildcard_count"
            )
        ):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_DISPOSITION_IDENTITY_MISMATCH",
                "one frozen disposition does not bind the exact baseline raw identity",
                fingerprint=fingerprint,
            )
        disposition = str(row.get("disposition", ""))
        if disposition not in ALLOWED_FROZEN_IDENTITY_DISPOSITIONS:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_DISPOSITION_KIND_INVALID",
                "one frozen disposition kind is outside the closed contract",
                fingerprint=fingerprint,
            )
        subject = _normalize_path(str(frozen_identity.get("subject_value", "")))
        if not subject or any(char in subject for char in "*?[]"):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_DISPOSITION_SUBJECT_NOT_EXACT",
                "one frozen disposition subject is empty or wildcarded",
                fingerprint=fingerprint,
            )
        old_commit = _resolve_commit_prefix(
            root, str(frozen_identity.get("transition_old_prefix", ""))
        )
        new_commit = _resolve_commit_prefix(
            root, str(frozen_identity.get("transition_new_prefix", ""))
        )
        if (
            not old_commit
            or not new_commit
            or _git(root, "rev-parse", f"{new_commit}^1") != old_commit
            or row.get("transition_old_sha") != old_commit
            or row.get("transition_new_sha") != new_commit
            or not _is_ancestor(root, new_commit, report_head)
        ):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_DISPOSITION_TRANSITION_INVALID",
                "one frozen disposition transition is not one exact ancestor edge",
                fingerprint=fingerprint,
            )
        evidence = row.get("evidence")
        successor_fingerprint = str(row.get("successor_failure_fingerprint", ""))
        if disposition == EXACT_SUCCESSOR_FINGERPRINT_MAPPING:
            if not isinstance(evidence, dict) or set(evidence) != SUCCESSOR_DISPOSITION_EVIDENCE_FIELDS:
                add(
                    "FULL_CONVERGENCE_DESCENDANT_HISTORY_SUCCESSOR_EVIDENCE_INVALID",
                    "one successor disposition evidence field set is invalid",
                    fingerprint=fingerprint,
                )
                evidence = evidence if isinstance(evidence, dict) else {}
            successor_identity = final_identities.get(successor_fingerprint)
            if (
                successor_fingerprint not in descendants
                or successor_fingerprint in used_successors
                or not isinstance(successor_identity, dict)
            ):
                add(
                    "FULL_CONVERGENCE_DESCENDANT_HISTORY_SUCCESSOR_FINGERPRINT_INVALID",
                    "one successor is absent, non-novel, or reused",
                    fingerprint=fingerprint,
                )
                successor_identity = {}
            used_successors.add(successor_fingerprint)
            if (
                successor_identity.get("rule_id") != frozen_identity.get("rule_id")
                or successor_identity.get("subject_kind") != frozen_identity.get("subject_kind")
                or successor_identity.get("subject_value") != frozen_identity.get("subject_value")
            ):
                add(
                    "FULL_CONVERGENCE_DESCENDANT_HISTORY_SUCCESSOR_SUBJECT_INVALID",
                    "one successor does not preserve the exact rule and subject",
                    fingerprint=fingerprint,
                )
            successor_old = _resolve_commit_prefix(
                root, str(successor_identity.get("transition_old_prefix", ""))
            )
            successor_new = _resolve_commit_prefix(
                root, str(successor_identity.get("transition_new_prefix", ""))
            )
            expected_evidence = {
                "evidence_kind": "EXACT_LIVE_RAW_SUCCESSOR_IDENTITY",
                "baseline_raw_report_sha256": FULL_CONVERGENCE_BASELINE_SHA,
                "live_raw_report_sha256": raw_report_sha,
                "successor_raw_failure": successor_identity.get("raw_failure"),
                "successor_rule_id": successor_identity.get("rule_id"),
                "successor_transition_old_sha": successor_old,
                "successor_transition_new_sha": successor_new,
                "successor_subject_kind": successor_identity.get("subject_kind"),
                "successor_subject_value": successor_identity.get("subject_value"),
            }
            if (
                not successor_old
                or not successor_new
                or _git(root, "rev-parse", f"{successor_new}^1") != successor_old
                or any(evidence.get(field) != expected for field, expected in expected_evidence.items())
            ):
                add(
                    "FULL_CONVERGENCE_DESCENDANT_HISTORY_SUCCESSOR_BINDING_INVALID",
                    "one successor transition or evidence binding is invalid",
                    fingerprint=fingerprint,
                )
        elif disposition == EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT:
            if not isinstance(evidence, dict) or set(evidence) != FALSE_COMPONENT_RETIREMENT_EVIDENCE_FIELDS:
                add(
                    "FULL_CONVERGENCE_DESCENDANT_HISTORY_FALSE_COMPONENT_EVIDENCE_INVALID",
                    "one false-component evidence field set is invalid",
                    fingerprint=fingerprint,
                )
                evidence = evidence if isinstance(evidence, dict) else {}
            changed_paths = {
                _normalize_path(value)
                for value in _git(root, "diff", "--name-only", old_commit, new_commit).splitlines()
                if value.strip()
            }
            exact_ids = target_to_ids.get(subject, [])
            rendered_ids = (
                [str(value) for value in evidence.get("dynamic_reference_ids", [])]
                if isinstance(evidence.get("dynamic_reference_ids"), list)
                else []
            )
            expected_evidence = {
                "evidence_kind": "EXACT_DYNAMIC_REFERENCE_TARGET_NOT_DIRECT_TRANSITION_CHANGE",
                "baseline_raw_report_sha256": FULL_CONVERGENCE_BASELINE_SHA,
                "live_raw_report_sha256": raw_report_sha,
                "subject_directly_changed": False,
                "dynamic_reference_manifest_path": DYNAMIC_REFERENCE_MANIFEST.as_posix(),
                "dynamic_reference_manifest_blob_sha256": manifest_sha,
                "resolved_target": f"res://{subject}",
            }
            if (
                successor_fingerprint
                or frozen_identity.get("rule_id") != "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
                or frozen_identity.get("subject_kind") != "path"
                or subject in changed_paths
                or not exact_ids
                or rendered_ids != exact_ids
                or any(evidence.get(field) != expected for field, expected in expected_evidence.items())
            ):
                add(
                    "FULL_CONVERGENCE_DESCENDANT_HISTORY_FALSE_COMPONENT_BINDING_INVALID",
                    "one false-component disposition lacks exact transition and target evidence",
                    fingerprint=fingerprint,
                )
        if len(findings) == before:
            verified_dispositions.add(fingerprint)
    if verified_dispositions != missing_frozen:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_DISPOSITION_COVERAGE_INVALID",
            "verified dispositions do not cover the exact missing frozen set",
        )
    repaired = supplement.get("repaired_frozen_current_fingerprints")
    rendered_repaired = [str(value) for value in repaired] if isinstance(repaired, list) else []
    if (
        rendered_repaired != sorted(rendered_repaired)
        or len(rendered_repaired) != len(set(rendered_repaired))
        or set(rendered_repaired) != baseline_sets["current"]
        or not _is_exact_int_equal(
            supplement.get("repaired_frozen_current_failure_count"),
            len(baseline_sets["current"]),
        )
        or supplement.get("repaired_frozen_current_fingerprint_set_sha256")
        != _line_set_sha(rendered_repaired)
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_REPAIRED_CURRENT_SET_INVALID",
            "repaired current set is not the exact frozen 56-fingerprint set",
        )
    bindings = supplement.get("identity_binding_by_failure")
    if not isinstance(bindings, dict) or set(bindings) != descendants:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_IDENTITY_SET_INVALID",
            "supplement does not bind one exact identity for every descendant fingerprint",
        )
        bindings = bindings if isinstance(bindings, dict) else {}
    mapped_current: set[str] = set()
    authorized_identities: dict[str, dict[str, str]] = {}
    for fingerprint in sorted(descendants):
        binding = bindings.get(fingerprint)
        raw_identity = final_identities.get(fingerprint)
        if not isinstance(binding, dict) or set(binding) != DESCENDANT_HISTORY_IDENTITY_FIELDS:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_IDENTITY_FIELDS_INVALID",
                "one descendant identity field set differs from the closed contract",
                fingerprint=fingerprint,
            )
            continue
        if not isinstance(raw_identity, dict):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_IDENTITY_UNRESOLVED",
                "one descendant fingerprint has no exact final raw identity",
                fingerprint=fingerprint,
            )
            continue
        if (
            binding.get("failure_fingerprint") != fingerprint
            or binding.get("raw_failure") != raw_identity.get("raw_failure")
            or binding.get("rule_id") != raw_identity.get("rule_id")
        ):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_IDENTITY_MISMATCH",
                "identity raw text, rule, or fingerprint differs from the final report",
                fingerprint=fingerprint,
            )
        old_commit = _resolve_commit_prefix(root, str(raw_identity.get("transition_old_prefix", "")))
        new_commit = _resolve_commit_prefix(root, str(raw_identity.get("transition_new_prefix", "")))
        if (
            not old_commit
            or not new_commit
            or _git(root, "rev-parse", f"{new_commit}^1") != old_commit
            or binding.get("transition_old_sha") != old_commit
            or binding.get("transition_new_sha") != new_commit
            or binding.get("source_commit_sha") != new_commit
            or not _is_ancestor(root, new_commit, report_head)
        ):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_TRANSITION_BINDING_INVALID",
                "descendant transition is not one exact direct authorized parent edge",
                fingerprint=fingerprint,
            )
        source_path = _normalize_path(str(binding.get("source_path", "")))
        source_path_exact = (
            source_path
            and source_path == binding.get("source_path")
            and not source_path.startswith(("/", "../"))
            and not source_path.endswith("/")
            and "/../" not in source_path
            and not any(char in source_path for char in "*?[]")
        )
        subject_kind = str(raw_identity.get("subject_kind", ""))
        subject_value = _normalize_path(str(raw_identity.get("subject_value", "")))
        if not source_path_exact:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_SOURCE_PATH_INVALID",
                "descendant source path is not exact and wildcard-free",
                fingerprint=fingerprint,
            )
        if subject_kind == "path":
            if source_path != subject_value or binding.get("source_component_id") != "":
                add(
                    "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_SUBJECT_MISMATCH",
                    "source path/component differs from the exact raw path subject",
                    fingerprint=fingerprint,
                )
        elif subject_kind == "component_id":
            changed_paths = {
                _normalize_path(value)
                for value in _git(root, "diff", "--name-only", old_commit, new_commit).splitlines()
                if value.strip()
            }
            if (
                binding.get("source_component_id") != subject_value
                or source_path not in changed_paths
            ):
                add(
                    "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_SUBJECT_MISMATCH",
                    "component subject or its exact touched source path is not bound",
                    fingerprint=fingerprint,
                )
        else:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_SUBJECT_UNRESOLVED",
                "descendant raw row has no exact path or component subject",
                fingerprint=fingerprint,
            )
        source_bytes = _git_bytes(root, new_commit, source_path) if new_commit else None
        source_sha = _sha_bytes(source_bytes) if source_bytes is not None else ""
        if source_bytes is None or binding.get("source_blob_sha256") != source_sha:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_SOURCE_BLOB_MISMATCH",
                "descendant source blob differs from the exact new commit",
                fingerprint=fingerprint,
            )
        mapped = binding.get("repaired_frozen_current_fingerprints")
        rendered_mapped = [str(value) for value in mapped] if isinstance(mapped, list) else []
        if (
            not rendered_mapped
            or rendered_mapped != sorted(rendered_mapped)
            or len(rendered_mapped) != len(set(rendered_mapped))
            or not set(rendered_mapped).issubset(baseline_sets["current"])
        ):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_REPAIR_BINDING_INVALID",
                "descendant identity lacks a nonempty exact frozen-current repair binding",
                fingerprint=fingerprint,
            )
        mapped_current.update(rendered_mapped)
        identity = dict(raw_identity)
        identity.update({
            "authority_origin": "DESCENDANT_HISTORY_SUPPLEMENT",
            "source_path": source_path,
            "supplement_raw_report_head_sha": report_head,
        })
        authorized_identities[fingerprint] = identity
    if mapped_current != baseline_sets["current"] or mapped_current != set(rendered_repaired):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_REPAIR_COVERAGE_INVALID",
            "per-descendant repair bindings do not cover the exact frozen current set",
        )
    live_identities: dict[str, dict[str, str]] = {}
    for fingerprint in sorted(final_sets["historical"]):
        if fingerprint in authorized_identities:
            live_identities[fingerprint] = dict(authorized_identities[fingerprint])
            continue
        identity = baseline_identities.get(fingerprint, final_identities.get(fingerprint))
        if not isinstance(identity, dict):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_LIVE_IDENTITY_UNRESOLVED",
                "one live historical fingerprint has no exact identity",
                fingerprint=fingerprint,
            )
            continue
        row = dict(identity)
        row["authority_origin"] = "FROZEN_FULL_CONVERGENCE_BASELINE"
        live_identities[fingerprint] = row
    return (
        findings,
        descendants,
        live_identities,
        verified_dispositions,
        supplement_sha,
        report_head,
    )


def _descendant_history_successor_v3_findings(
    root: Path,
    *,
    supplement_path: Path,
    raw_report_path: Path,
    scanner_path: Path,
    evaluated_head: str,
    baseline_report: dict[str, Any],
    baseline_sets: dict[str, set[str]],
    expected_raw_head: str = DESCENDANT_HISTORY_V3_RAW_HEAD,
    expected_raw_tree: str = DESCENDANT_HISTORY_V3_RAW_TREE,
    expected_raw_sha: str = DESCENDANT_HISTORY_V3_RAW_SHA,
    expected_scanner_sha: str = DESCENDANT_HISTORY_V3_SCANNER_SHA,
) -> list[dict[str, Any]]:
    """Independently audit the v3 predecessor chain and scanner evolution."""

    findings: list[dict[str, Any]] = []

    def add(code: str, message: str, **evidence: Any) -> None:
        findings.append(_finding(code, "P0", message, **evidence))

    if (
        _exact_repo_relative(root, supplement_path) != DESCENDANT_HISTORY_V3_SUPPLEMENT.as_posix()
        or _exact_repo_relative(root, raw_report_path) != DESCENDANT_HISTORY_V3_RAW.as_posix()
    ):
        add("FULL_CONVERGENCE_DESCENDANT_V3_PATH_INVALID", "active v3 paths are not exact")

    try:
        supplement = _json(supplement_path)
        previous_path = root / PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT
        previous = _json(previous_path)
        successor_schema_path = root / FULL_CONVERGENCE_SUCCESSOR_SCHEMA
        successor_schema = _json(successor_schema_path)
    except (OSError, ValueError):
        add("FULL_CONVERGENCE_DESCENDANT_V3_JSON_INVALID", "v3 or predecessor is invalid")
        return findings
    successor_schema_finding = _sealed_tree_blob_finding(
        root,
        successor_schema_path,
        evaluated_head=evaluated_head,
        expected_sha=FULL_CONVERGENCE_SUCCESSOR_SCHEMA_SHA,
        code="FULL_CONVERGENCE_DESCENDANT_V3_SCHEMA_INVALID",
        message="successor schema committed blob or worktree content drifted",
    )
    if (
        successor_schema_finding is not None
        or successor_schema.get("active_descendant_history_supplement_schema_version")
        != DESCENDANT_HISTORY_SUPPLEMENT_V3_SCHEMA_VERSION
        or successor_schema.get("active_descendant_history_supplement_id")
        != DESCENDANT_HISTORY_SUPPLEMENT_V3_ID
    ):
        add("FULL_CONVERGENCE_DESCENDANT_V3_SCHEMA_INVALID", "successor schema bytes or identity drifted")
    if successor_schema_finding is not None:
        findings.append(successor_schema_finding)
    if (
        successor_schema.get("previous_schema_path")
        != FULL_CONVERGENCE_SCHEMA.as_posix()
        or successor_schema.get("previous_schema_sha256")
        != FULL_CONVERGENCE_SCHEMA_SHA
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_V3_PREDECESSOR_SCHEMA_SEAL_INVALID",
            "successor schema does not bind the exact predecessor blob",
        )
    predecessor_schema_finding = _sealed_tree_blob_finding(
        root,
        root / FULL_CONVERGENCE_SCHEMA,
        evaluated_head=evaluated_head,
        expected_sha=FULL_CONVERGENCE_SCHEMA_SHA,
        code="FULL_CONVERGENCE_DESCENDANT_V3_PREDECESSOR_SCHEMA_SEAL_INVALID",
        message="predecessor schema committed blob or worktree content drifted",
    )
    if predecessor_schema_finding is not None:
        findings.append(predecessor_schema_finding)
    if set(supplement) != DESCENDANT_HISTORY_SUPPLEMENT_V3_FIELDS:
        add("FULL_CONVERGENCE_DESCENDANT_V3_FIELD_SET_INVALID", "v3 field set is not closed")
    sealed = {
        "raw_report_head_sha": expected_raw_head,
        "raw_report_tree_sha": expected_raw_tree,
        "raw_report_sha256": expected_raw_sha,
        "scanner_tool_sha256": expected_scanner_sha,
        "raw_failure_count": 501,
        "raw_historical_failure_count": 501,
        "raw_current_delta_failure_count": 0,
    }
    if any(supplement.get(field) != value for field, value in sealed.items()):
        add("FULL_CONVERGENCE_DESCENDANT_V3_SEALED_RAW_INVALID", "sealed da48 Raw identity drifted")
    if (
        supplement.get("schema_version") != DESCENDANT_HISTORY_SUPPLEMENT_V3_SCHEMA_VERSION
        or supplement.get("supplement_id") != DESCENDANT_HISTORY_SUPPLEMENT_V3_ID
    ):
        add("FULL_CONVERGENCE_DESCENDANT_V3_IDENTITY_INVALID", "v3 schema or ID was reused")
    if (
        supplement.get("previous_supplement_path")
        != PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT.as_posix()
        or supplement.get("previous_supplement_sha256")
        != PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA
        or _sha_file(previous_path) != PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA
    ):
        add("FULL_CONVERGENCE_DESCENDANT_V3_PREDECESSOR_SEAL_INVALID", "v2 predecessor bytes drifted")
    previous_raw_path = root / PREVIOUS_DESCENDANT_HISTORY_RAW
    try:
        previous_raw = _json(previous_raw_path)
        previous_raw_sha = _sha_file(previous_raw_path)
    except (OSError, ValueError):
        previous_raw = {}
        previous_raw_sha = ""
    committed_previous = _git_bytes(
        root, evaluated_head, PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT.as_posix()
    )
    committed_previous_raw = _git_bytes(
        root, evaluated_head, PREVIOUS_DESCENDANT_HISTORY_RAW.as_posix()
    )
    historical_scanner = _git_bytes(
        root, PREVIOUS_DESCENDANT_HISTORY_HEAD, DESCENDANT_HISTORY_SCANNER.as_posix()
    )
    if (
        committed_previous is None
        or _sha_bytes(committed_previous) != PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA
        or committed_previous_raw is None
        or _sha_bytes(committed_previous_raw) != PREVIOUS_DESCENDANT_HISTORY_RAW_SHA
        or previous_raw_sha != PREVIOUS_DESCENDANT_HISTORY_RAW_SHA
        or previous.get("schema_version") != DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION
        or previous.get("supplement_id") != DESCENDANT_HISTORY_SUPPLEMENT_ID
        or previous.get("raw_report_path") != PREVIOUS_DESCENDANT_HISTORY_RAW.as_posix()
        or previous.get("raw_report_sha256") != PREVIOUS_DESCENDANT_HISTORY_RAW_SHA
        or previous.get("raw_report_head_sha") != PREVIOUS_DESCENDANT_HISTORY_HEAD
        or previous.get("raw_report_tree_sha") != PREVIOUS_DESCENDANT_HISTORY_TREE
        or previous_raw.get("head_sha") != PREVIOUS_DESCENDANT_HISTORY_HEAD
        or historical_scanner is None
        or _sha_bytes(historical_scanner) != PREVIOUS_DESCENDANT_HISTORY_SCANNER_SHA
    ):
        add("FULL_CONVERGENCE_DESCENDANT_V3_PREDECESSOR_CHAIN_INVALID", "v2 predecessor chain is not exact")
    previous_descendants = set(previous.get("descendant_history_fingerprints", []))
    current_descendants = set(supplement.get("descendant_history_fingerprints", []))
    if not previous_descendants.issubset(current_descendants):
        add("FULL_CONVERGENCE_DESCENDANT_V3_PREVIOUS_IDENTITY_DROPPED", "v3 drops a v2 identity")
    previous_dispositions = previous.get("frozen_identity_disposition_by_failure")
    current_dispositions = supplement.get("frozen_identity_disposition_by_failure")
    stable_fields = (
        "disposition", "failure_fingerprint", "raw_failure", "rule_id",
        "subject_kind", "subject_value", "successor_failure_fingerprint",
        "transition_new_sha", "transition_old_sha", "wildcard_count",
    )
    if not isinstance(previous_dispositions, dict) or not isinstance(current_dispositions, dict):
        add("FULL_CONVERGENCE_DESCENDANT_V3_DISPOSITION_SET_INVALID", "disposition chain is invalid")
    else:
        for fingerprint, old_row in previous_dispositions.items():
            new_row = current_dispositions.get(fingerprint)
            if not isinstance(old_row, dict) or not isinstance(new_row, dict) or any(
                old_row.get(field) != new_row.get(field) for field in stable_fields
            ):
                add(
                    "FULL_CONVERGENCE_DESCENDANT_V3_DISPOSITION_DRIFT",
                    "one frozen predecessor disposition drifted",
                    fingerprint=fingerprint,
                )
    evolution = supplement.get("scanner_evolution")
    if not isinstance(evolution, dict) or set(evolution) != DESCENDANT_HISTORY_SCANNER_EVOLUTION_FIELDS:
        add("FULL_CONVERGENCE_DESCENDANT_V3_SCANNER_EVOLUTION_FIELDS_INVALID", "scanner evolution is open")
        evolution = evolution if isinstance(evolution, dict) else {}
    count_fields = (
        "removed_rule_count",
        "scanner_change_commit_count",
        "scanner_history_depth_reduction_count",
        "scanner_scope_reduction_count",
        "scanner_severity_downgrade_count",
    )
    for field in count_fields:
        if type(evolution.get(field)) is not int:
            add("FULL_CONVERGENCE_DESCENDANT_V3_SCANNER_COUNT_TYPE_INVALID", "bool is not an integer", field=field)
    expected = {
        "evolution_kind": "FAIL_CLOSED_VALIDATION_STRENGTHENING",
        "from_raw_report_head_sha": PREVIOUS_DESCENDANT_HISTORY_HEAD,
        "from_raw_report_tree_sha": PREVIOUS_DESCENDANT_HISTORY_TREE,
        "from_scanner_tool_sha256": PREVIOUS_DESCENDANT_HISTORY_SCANNER_SHA,
        "removed_rule_count": 0,
        "scanner_history_depth_reduction_count": 0,
        "scanner_scope_reduction_count": 0,
        "scanner_severity_downgrade_count": 0,
        "scanner_tool_path": DESCENDANT_HISTORY_SCANNER.as_posix(),
        "to_raw_report_head_sha": supplement.get("raw_report_head_sha"),
        "to_raw_report_tree_sha": supplement.get("raw_report_tree_sha"),
        "to_scanner_tool_sha256": supplement.get("scanner_tool_sha256"),
        "weakening_allowed": False,
    }
    if any(evolution.get(field) != value for field, value in expected.items()):
        add("FULL_CONVERGENCE_DESCENDANT_V3_SCANNER_EVOLUTION_INVALID", "scanner evolution weakens or drifts")
    to_head = str(supplement.get("raw_report_head_sha", ""))
    commits = [
        value
        for value in _git(
            root,
            "rev-list",
            "--reverse",
            f"{PREVIOUS_DESCENDANT_HISTORY_HEAD}..{to_head}",
            "--",
            DESCENDANT_HISTORY_SCANNER.as_posix(),
        ).splitlines()
        if value
    ]
    declared = evolution.get("scanner_change_commit_shas")
    rendered = [str(value) for value in declared] if isinstance(declared, list) else []
    digest = _sha_bytes(("\n".join(commits) + "\n").encode("utf-8"))
    if (
        not commits
        or rendered != commits
        or not _is_exact_int_equal(evolution.get("scanner_change_commit_count"), len(commits))
        or evolution.get("scanner_change_commit_sequence_sha256") != digest
    ):
        add("FULL_CONVERGENCE_DESCENDANT_V3_SCANNER_SEQUENCE_INVALID", "scanner commit sequence is not exact")
    return findings


def _descendant_history_supplement_findings(
    root: Path,
    *,
    supplement_path: Path | None,
    raw_report_path: Path | None,
    scanner_path: Path | None,
    evaluated_head: str,
    baseline_report: dict[str, Any],
    baseline_sets: dict[str, set[str]],
    require_live_scanner_bytes: bool = True,
    expected_v3_raw_head: str = DESCENDANT_HISTORY_V3_RAW_HEAD,
    expected_v3_raw_tree: str = DESCENDANT_HISTORY_V3_RAW_TREE,
    expected_v3_raw_sha: str = DESCENDANT_HISTORY_V3_RAW_SHA,
    expected_v3_scanner_sha: str = DESCENDANT_HISTORY_V3_SCANNER_SHA,
) -> tuple[list[dict[str, Any]], set[str], dict[str, dict[str, str]], set[str], str, str]:
    try:
        document = _json(supplement_path) if supplement_path is not None else {}
    except (OSError, ValueError):
        document = {}
    is_v3 = (
        supplement_path is not None
        and _exact_repo_relative(root, supplement_path)
        == DESCENDANT_HISTORY_V3_SUPPLEMENT.as_posix()
    )
    result = _descendant_history_supplement_core_findings(
        root,
        supplement_path=supplement_path,
        raw_report_path=raw_report_path,
        scanner_path=scanner_path,
        evaluated_head=evaluated_head,
        baseline_report=baseline_report,
        baseline_sets=baseline_sets,
        require_live_scanner_bytes=require_live_scanner_bytes,
        expected_schema_version=(
            DESCENDANT_HISTORY_SUPPLEMENT_V3_SCHEMA_VERSION
            if is_v3 else DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION
        ),
        expected_supplement_id=(
            DESCENDANT_HISTORY_SUPPLEMENT_V3_ID
            if is_v3 else DESCENDANT_HISTORY_SUPPLEMENT_ID
        ),
        expected_fields=(
            DESCENDANT_HISTORY_SUPPLEMENT_V3_FIELDS
            if is_v3 else DESCENDANT_HISTORY_SUPPLEMENT_FIELDS
        ),
    )
    if is_v3 and supplement_path is not None and raw_report_path is not None and scanner_path is not None:
        result[0].extend(
            _descendant_history_successor_v3_findings(
                root,
                supplement_path=supplement_path,
                raw_report_path=raw_report_path,
                scanner_path=scanner_path,
                evaluated_head=evaluated_head,
                baseline_report=baseline_report,
                baseline_sets=baseline_sets,
                expected_raw_head=expected_v3_raw_head,
                expected_raw_tree=expected_v3_raw_tree,
                expected_raw_sha=expected_v3_raw_sha,
                expected_scanner_sha=expected_v3_scanner_sha,
            )
        )
    return result


def _selector_is_exact(selector: Any) -> bool:
    expected_fields = {
        "component_ids", "dynamic_reference_ids", "paths",
        "retirement_ids", "supersession_ids",
    }
    if not isinstance(selector, dict) or set(selector) != expected_fields:
        return False
    total = 0
    disallowed = {
        "glob", "regex", "prefix", "directory", "legacy", "misc", "other",
        "unknown", "ignore", "waive", "grandfather",
    }
    for field in sorted(expected_fields):
        values = selector.get(field)
        if not isinstance(values, list):
            return False
        rendered = [str(value) for value in values]
        total += len(rendered)
        if rendered != sorted(rendered) or len(rendered) != len(set(rendered)):
            return False
        for value in rendered:
            tokens = set(re.findall(r"[a-z0-9_]+", value.casefold()))
            if not value or any(char in value for char in "*?[]") or tokens & disallowed:
                return False
            if field == "paths":
                normalized = value.removeprefix("res://").replace("\\", "/")
                if (
                    normalized != value
                    or value.startswith(("/", "../"))
                    or value.endswith("/")
                    or "/../" in value
                ):
                    return False
    return total > 0


def _raw_identity_findings(
    root: Path,
    *,
    fingerprint: str,
    subject: dict[str, Any],
    identity: dict[str, str] | None,
    record_rule_ids: list[str],
    path: str,
) -> list[dict[str, Any]]:
    """Bind a correction subject back to its one exact frozen raw row."""

    findings: list[dict[str, Any]] = []

    def add(code: str, message: str, **evidence: Any) -> None:
        findings.append(_finding(
            code,
            "P0",
            message,
            path=path,
            fingerprint=fingerprint,
            **evidence,
        ))

    if not isinstance(identity, dict) or identity.get("bucket") != "HISTORICAL":
        add(
            "FULL_CONVERGENCE_BASELINE_RAW_IDENTITY_UNRESOLVED",
            "the record fingerprint does not resolve to one frozen historical raw row",
        )
        return findings
    rule_id = str(identity.get("rule_id", ""))
    findings.extend(_identity_projection_findings(
        subject,
        path=path,
        fingerprint=fingerprint,
        rule_id=rule_id,
        raw_failure=str(identity.get("raw_failure", "")),
    ))
    if record_rule_ids != [rule_id]:
        add(
            "FULL_CONVERGENCE_BASELINE_RAW_RULE_MISMATCH",
            "the record rule differs from the exact frozen raw rule",
            expected_rule_id=rule_id,
        )
    old_commit = _resolve_commit_prefix(
        root, str(identity.get("transition_old_prefix", ""))
    )
    source_commit = _resolve_commit_prefix(
        root, str(identity.get("transition_new_prefix", ""))
    )
    if not old_commit or not source_commit:
        add(
            "FULL_CONVERGENCE_BASELINE_RAW_TRANSITION_UNRESOLVED",
            "the frozen raw transition cannot be resolved to exact commits",
        )
    else:
        if _git(root, "rev-parse", f"{source_commit}^1") != old_commit:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_TRANSITION_NOT_DIRECT_PARENT",
                "the frozen raw transition is not a direct parent transition",
                old_commit=old_commit,
                source_commit=source_commit,
            )
        if subject.get("source_commit") != source_commit:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_SOURCE_COMMIT_MISMATCH",
                "the identity binding source commit differs from the raw transition",
                expected_source_commit=source_commit,
            )
        if subject.get("first_seen_commit") != source_commit:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_FIRST_SEEN_MISMATCH",
                "the identity binding first-seen commit differs from the raw transition",
                expected_first_seen_commit=source_commit,
            )
        last_seen = str(subject.get("last_seen_commit", ""))
        if identity.get("authority_origin") == "DESCENDANT_HISTORY_SUPPLEMENT":
            supplement_head = str(identity.get("supplement_raw_report_head_sha", ""))
            last_seen_invalid = (
                not _is_commit(last_seen)
                or not _is_ancestor(root, source_commit, last_seen)
                or not _is_ancestor(root, last_seen, supplement_head)
            )
        else:
            last_seen_invalid = (
                not _is_commit(last_seen)
                or not _is_ancestor(root, source_commit, last_seen)
                or not _is_ancestor(root, last_seen, FULL_CONVERGENCE_BASE_HEAD)
            )
        if last_seen_invalid:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_LAST_SEEN_INVALID",
                "last_seen_commit is outside its exact authorized history interval",
            )
    selector = subject.get("authority_selectors")
    selector_paths = {
        _normalize_path(str(value))
        for value in selector.get("paths", [])
    } if isinstance(selector, dict) else set()
    selector_components = {
        str(value) for value in selector.get("component_ids", [])
    } if isinstance(selector, dict) else set()
    subject_kind = str(identity.get("subject_kind", ""))
    subject_value = _normalize_path(str(identity.get("subject_value", "")))
    if subject_kind == "path":
        if _normalize_path(str(subject.get("historical_path", ""))) != subject_value:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_HISTORICAL_PATH_MISMATCH",
                "historical_path differs from the frozen raw path",
                expected_historical_path=subject_value,
            )
        if subject_value not in selector_paths:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_PATH_SELECTOR_MISSING",
                "the exact frozen raw path is absent from the authority selector",
                expected_path=subject_value,
            )
    elif subject_kind == "component_id":
        bound_components = {
            str(subject.get("historical_component_id", "")),
            str(subject.get("current_component_id", "")),
        }
        if subject_value not in bound_components:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_COMPONENT_MISMATCH",
                "the frozen raw component id is absent from the identity binding",
                expected_component_id=subject_value,
            )
        if subject_value not in selector_components:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_COMPONENT_SELECTOR_MISSING",
                "the exact frozen raw component id is absent from the authority selector",
                expected_component_id=subject_value,
            )
    else:
        add(
            "FULL_CONVERGENCE_BASELINE_RAW_SUBJECT_UNRESOLVED",
            "the frozen raw row does not expose an exact path or component subject",
        )
    if identity.get("authority_origin") == "DESCENDANT_HISTORY_SUPPLEMENT":
        supplement_source_path = _normalize_path(str(identity.get("source_path", "")))
        if _normalize_path(str(subject.get("historical_path", ""))) != supplement_source_path:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_RECORD_SOURCE_PATH_MISMATCH",
                "record historical path differs from the sealed descendant source path",
            )
        if supplement_source_path not in selector_paths:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_RECORD_SOURCE_SELECTOR_MISSING",
                "sealed descendant source path is absent from the record selector",
            )
    binding_paths = {
        _normalize_path(str(subject.get(field, "")))
        for field in ("historical_path", "current_path")
        if subject.get(field)
    }
    binding_components = {
        str(subject.get(field, ""))
        for field in ("historical_component_id", "current_component_id")
        if subject.get(field)
    }
    if not binding_paths.issubset(selector_paths):
        add(
            "FULL_CONVERGENCE_IDENTITY_PATH_SELECTOR_COVERAGE_MISMATCH",
            "not every bound path is covered by the exact authority selector",
        )
    if not binding_components.issubset(selector_components):
        add(
            "FULL_CONVERGENCE_IDENTITY_COMPONENT_SELECTOR_COVERAGE_MISMATCH",
            "not every bound component is covered by the exact authority selector",
        )
    current_path = _normalize_path(str(subject.get("current_path", "")))
    if not current_path:
        if subject.get("current_blob_sha256") != "MISSING":
            add(
                "FULL_CONVERGENCE_IDENTITY_MISSING_CURRENT_PATH_BLOB_NOT_MISSING",
                "an empty current path must bind the exact MISSING blob state",
            )
        if subject.get("recommended_disposition") == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED":
            add(
                "FULL_CONVERGENCE_IDENTITY_ACTIVE_LINEAGE_CURRENT_PATH_MISSING",
                "an active lineage disposition requires an exact current path",
            )
    return findings


def _record_payload(record: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in record.items() if k != "record_payload_sha256"}


def _sidecar(path: Path) -> tuple[str, str | None]:
    sidecar = path.with_suffix(".sha256")
    if not path.is_file() or not sidecar.is_file():
        return "", "missing artifact or sidecar"
    parts = sidecar.read_text(encoding="ascii").splitlines()[0].split(maxsplit=1)
    if len(parts) != 2 or not re.fullmatch(r"[0-9a-f]{64}", parts[0]):
        return "", "invalid sidecar"
    actual = _sha_file(path)
    if actual != parts[0]:
        return actual, "sidecar digest mismatch"
    return actual, None


def _read_registry(root: Path) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    path = root / "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
    try:
        payload = _json(path)
    except (OSError, ValueError):
        return {}, {}
    by_path: dict[str, dict[str, Any]] = {}
    by_id: dict[str, dict[str, Any]] = {}
    for row in payload.get("component_inventory", []):
        if not isinstance(row, dict):
            continue
        component_id = str(row.get("component_id", ""))
        path_value = str(row.get("path", "")).removeprefix("res://").replace("\\", "/")
        if component_id:
            by_id[component_id] = row
        if path_value:
            by_path[path_value] = row
    return by_path, by_id


def _tree_blob_map(root: Path) -> dict[str, str]:
    """Return path -> Git blob id from the authorised committed tree."""
    output = _git(root, "ls-tree", "-r", AUTHORIZED_HEAD)
    result: dict[str, str] = {}
    for line in output.splitlines():
        fields = line.split("\t", 1)
        if len(fields) != 2:
            continue
        identity, path = fields
        id_fields = identity.split()
        if len(id_fields) >= 3:
            result[path.replace("\\", "/")] = id_fields[2]
    return result


def _git_blob_sha256(root: Path, blob_id: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "cat-file", "blob", blob_id],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return _sha_bytes(result.stdout) if result.returncode == 0 else "MISSING"


def _record_paths(root: Path) -> list[Path]:
    directory = root / RECORD_DIR
    return sorted(path for path in directory.glob("*.json") if path.is_file())


def _finding(code: str, severity: str, message: str, **evidence: Any) -> dict[str, Any]:
    return {"code": code, "severity": severity, "message": message, "evidence": evidence}


def _batch_artifact_findings(
    manifest_path: Path,
    manifest: dict[str, Any],
    identities: dict[str, dict[str, str]],
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    expected_fingerprints = [str(value) for value in manifest.get("failure_fingerprints", [])]
    for hash_field, (filename, schema_version, kind) in BATCH_ARTIFACT_SPECS.items():
        path = manifest_path.parent / filename
        if not path.is_file():
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_ARTIFACT_MISSING",
                "P0",
                "a required batch evidence artifact is missing",
                artifact=filename,
            ))
            continue
        if _sha_file(path) != manifest.get(hash_field):
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_ARTIFACT_HASH_MISMATCH",
                "P0",
                "batch evidence bytes differ from the manifest digest",
                artifact=filename,
            ))
            continue
        try:
            document = _json(path)
        except (OSError, ValueError):
            document = None
        if not isinstance(document, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_ARTIFACT_INVALID",
                "P0",
                "a required batch evidence artifact is not a strict JSON object",
                artifact=filename,
            ))
            continue
        common_valid = (
            document.get("schema_version") == schema_version
            and document.get("batch_id") == manifest.get("batch_id")
            and [str(value) for value in document.get("failure_fingerprints", [])]
            == expected_fingerprints
            and _is_exact_int_equal(
                document.get("failure_count"), len(expected_fingerprints)
            )
        )
        if not common_valid:
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_ARTIFACT_SCHEMA_MISMATCH",
                "P0",
                "batch evidence schema, batch id, or fingerprint coverage is not exact",
                artifact=filename,
            ))
            continue
        if kind == "inventory":
            rows = document.get("rows")
            if (
                not _is_exact_int_equal(
                    document.get("identity_coverage_percent"), 100
                )
                or not _is_exact_int_equal(document.get("unknown_count"), 0)
                or not isinstance(rows, dict)
                or set(rows) != set(expected_fingerprints)
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_BATCH_INVENTORY_COVERAGE_INVALID",
                    "P0",
                    "inventory does not bind every fingerprint with zero unknowns",
                    artifact=filename,
                ))
            elif any(
                not isinstance(row, dict)
                or row.get("failure_fingerprint") != fingerprint
                or row.get("raw_failure") != identities.get(fingerprint, {}).get("raw_failure")
                or row.get("rule_id") != identities.get(fingerprint, {}).get("rule_id")
                for fingerprint, row in rows.items()
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_BATCH_INVENTORY_RAW_IDENTITY_MISMATCH",
                    "P0",
                    "inventory rows do not match their frozen raw identities",
                    artifact=filename,
                ))
        elif kind == "classification":
            rows = document.get("classifications")
            if (
                not _is_exact_int_equal(document.get("unknown_count"), 0)
                or not _is_exact_int_equal(document.get("wildcard_count"), 0)
                or not isinstance(rows, dict)
                or set(rows) != set(expected_fingerprints)
                or any(
                    not isinstance(row, dict)
                    or row.get("failure_fingerprint") != fingerprint
                    or row.get("status") != "CLASSIFIED"
                    or str(row.get("recommended_disposition", ""))
                    not in FULL_CONVERGENCE_ALLOWED_DISPOSITIONS
                    for fingerprint, row in (rows.items() if isinstance(rows, dict) else [])
                )
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_BATCH_CLASSIFICATION_INVALID",
                    "P0",
                    "classification does not cover every fingerprint with exact closed status",
                    artifact=filename,
                ))
        elif kind == "negative_checks":
            checks = document.get("checks")
            if (
                document.get("status") != "PASS"
                or not _is_exact_int_equal(
                    document.get("current_failure_false_accept_count"), 0
                )
                or not _is_exact_int_equal(
                    document.get("future_failure_auto_correction_count"), 0
                )
                or not _is_exact_int_equal(document.get("wildcard_count"), 0)
                or not isinstance(checks, dict)
                or not checks
                or any(value is not True for value in checks.values())
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_BATCH_NEGATIVE_CHECKS_INVALID",
                    "P0",
                    "negative checks are not an actual all-pass zero-waiver document",
                    artifact=filename,
                ))
        else:
            review_id = "A" if kind == "review_a" else "B"
            if (
                document.get("review_id") != review_id
                or document.get("status") != "GO"
                or not _is_exact_int_equal(document.get("p0_count"), 0)
                or not _is_exact_int_equal(document.get("p1_count"), 0)
                or document.get("findings") != []
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_BATCH_REVIEW_INVALID",
                    "P0",
                    "review GO is not supported by a zero-P0/P1 review document",
                    artifact=filename,
                ))
    return findings


def _full_convergence_selector_findings(
    selector: Any,
    *,
    path: str,
    fingerprint: str,
) -> list[dict[str, Any]]:
    """Independently enforce one exact authority selector contract."""

    findings: list[dict[str, Any]] = []

    def add(code: str, message: str, **evidence: Any) -> None:
        findings.append(_finding(
            code,
            "P0",
            message,
            path=path,
            fingerprint=fingerprint,
            **evidence,
        ))

    if not isinstance(selector, dict):
        add(
            "FULL_CONVERGENCE_SUBJECT_SELECTOR_NOT_OBJECT",
            "authority selector is not one strict object",
        )
        return findings
    if set(selector) != FULL_CONVERGENCE_AUTHORITY_SELECTOR_FIELDS:
        add(
            "FULL_CONVERGENCE_SUBJECT_SELECTOR_FIELD_SET_INVALID",
            "authority selector fields differ from the exact closed contract",
        )
    total = 0
    for field in sorted(FULL_CONVERGENCE_AUTHORITY_SELECTOR_FIELDS):
        values = selector.get(field)
        if not isinstance(values, list):
            add(
                "FULL_CONVERGENCE_SUBJECT_SELECTOR_LIST_INVALID",
                "authority selector field is not a list",
                field=field,
            )
            continue
        rendered = [str(value) for value in values]
        total += len(rendered)
        if rendered != sorted(rendered) or len(rendered) != len(set(rendered)):
            add(
                "FULL_CONVERGENCE_SUBJECT_SELECTOR_SET_INVALID",
                "authority selector values are not unique and sorted",
                field=field,
            )
        for value in rendered:
            normalized = _normalize_path(value) if field == "paths" else value
            tokens = set(re.findall(r"[a-z0-9_]+", value.casefold()))
            if (
                not value
                or any(char in value for char in "*?[]")
                or tokens & FULL_CONVERGENCE_DISALLOWED_TOKENS
                or (
                    field == "paths"
                    and (
                        normalized != value
                        or value.endswith("/")
                        or value.startswith(("/", "../"))
                        or "/../" in value
                    )
                )
            ):
                add(
                    "FULL_CONVERGENCE_SUBJECT_SELECTOR_NOT_EXACT",
                    "authority selector contains a wildcard or non-exact value",
                    field=field,
                    value=value,
                )
    if total == 0:
        add(
            "FULL_CONVERGENCE_SUBJECT_SELECTOR_EMPTY",
            "authority selector does not bind any exact identity",
        )
    return findings


def _full_convergence_identity_state_signature(
    *,
    reachability: str,
    role: str,
    retired_status: str,
    test_status: str = "NOT_TEST_ONLY",
    diagnostic_status: str = "NOT_DIAGNOSTIC_ONLY",
    documentation_status: str = "NOT_DOCUMENTATION_ONLY",
    generated_status: str = "NOT_GENERATED_EVIDENCE",
    dynamic_status: str = "NOT_DYNAMIC_REFERENCE",
    historical_reachability: str | None = None,
    historical_role: str | None = None,
) -> dict[str, str]:
    return {
        "current_production_reachability": reachability,
        "current_role": role,
        "diagnostic_only_status": diagnostic_status,
        "documentation_only_status": documentation_status,
        "dynamic_reference_status": dynamic_status,
        "generated_evidence_status": generated_status,
        "historical_production_reachability": (
            reachability
            if historical_reachability is None
            else historical_reachability
        ),
        "historical_role": role if historical_role is None else historical_role,
        "retired_status": retired_status,
        "test_only_status": test_status,
    }


def _full_convergence_identity_allowed_state_signatures(
    disposition: str,
    binding: dict[str, Any],
) -> list[dict[str, str]]:
    current_role = str(binding.get("current_role", ""))
    historical_role = str(binding.get("historical_role", ""))
    active = _full_convergence_identity_state_signature(
        reachability="PRODUCTION_REACHABLE",
        role=current_role,
        historical_role=historical_role,
        retired_status="ACTIVE_LINEAGE",
    )
    test_only = _full_convergence_identity_state_signature(
        reachability="TEST_ONLY",
        role="TEST_SUPPORT",
        retired_status="NOT_RETIRED",
        test_status="TEST_ONLY",
    )
    diagnostic = _full_convergence_identity_state_signature(
        reachability="DIAGNOSTIC_ONLY",
        role=current_role,
        historical_role=historical_role,
        retired_status="NOT_RETIRED",
        diagnostic_status="DIAGNOSTIC_ONLY",
    )
    documentation = _full_convergence_identity_state_signature(
        reachability="DOCUMENTATION_ONLY",
        role="DOCUMENTATION_ONLY",
        retired_status="NOT_RETIRED",
        documentation_status="DOCUMENTATION_ONLY",
    )
    generated = _full_convergence_identity_state_signature(
        reachability="GENERATED_EVIDENCE_ONLY",
        role="GENERATED_EVIDENCE",
        retired_status="NOT_RETIRED",
        generated_status="GENERATED_EVIDENCE",
    )
    if disposition == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED":
        return [active]
    if disposition == "HISTORICAL_SUPERSEDED_NONREACHABLE":
        return [_full_convergence_identity_state_signature(
            reachability="PRODUCTION_REACHABLE",
            role=current_role,
            historical_reachability="NONREACHABLE",
            historical_role=historical_role,
            retired_status="SUPERSEDED_NONREACHABLE",
        )]
    if disposition == "HISTORICAL_RETIRED_NONREACHABLE":
        return [_full_convergence_identity_state_signature(
            reachability="NONREACHABLE",
            role="RETIRED",
            historical_role="RETIRED",
            retired_status="RETIRED_NONREACHABLE",
        )]
    if disposition == "HISTORICAL_TEST_ONLY":
        return [test_only]
    if disposition == "HISTORICAL_DIAGNOSTIC_ONLY":
        return [diagnostic]
    if disposition == "HISTORICAL_DOCUMENTATION_ONLY":
        return [documentation]
    if disposition == "HISTORICAL_GENERATED_EVIDENCE":
        return [generated]
    if disposition == "HISTORICAL_DUPLICATE_OBSERVATION":
        return [active, test_only, diagnostic, documentation, generated]
    if disposition == "HISTORICAL_DYNAMIC_REFERENCE_RESOLVED":
        return [dict(active, dynamic_reference_status="RESOLVED")]
    if disposition == "HISTORICAL_DYNAMIC_REFERENCE_SUPERSEDED":
        return [dict(
            _full_convergence_identity_state_signature(
                reachability="PRODUCTION_REACHABLE",
                role=current_role,
                historical_reachability="NONREACHABLE",
                historical_role=historical_role,
                retired_status="SUPERSEDED_NONREACHABLE",
            ),
            dynamic_reference_status="SUPERSEDED",
        )]
    if disposition == "HISTORICAL_DYNAMIC_REFERENCE_TEST_ONLY":
        return [dict(test_only, dynamic_reference_status="RESOLVED")]
    if disposition == "HISTORICAL_DYNAMIC_REFERENCE_DIAGNOSTIC_ONLY":
        return [dict(diagnostic, dynamic_reference_status="RESOLVED")]
    return []


def _full_convergence_exact_relation_values(value: Any) -> list[str] | None:
    if not isinstance(value, list):
        return None
    rendered = [str(item) for item in value]
    if (
        rendered != sorted(rendered)
        or len(rendered) != len(set(rendered))
        or any(
            not item
            or any(char in item for char in "*?[]")
            or set(re.findall(r"[a-z0-9_]+", item.casefold()))
            & FULL_CONVERGENCE_DISALLOWED_TOKENS
            for item in rendered
        )
    ):
        return None
    return rendered


def _full_convergence_registry_row_findings(
    row: dict[str, Any],
    *,
    path: str,
    fingerprint: str,
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []

    def add(code: str, message: str, **evidence: Any) -> None:
        findings.append(_finding(
            code,
            "P0",
            message,
            path=path,
            fingerprint=fingerprint,
            **evidence,
        ))

    source_kind = str(row.get("authority_source_kind", ""))
    if source_kind == "historical_identity_backfill":
        if set(row) != FULL_CONVERGENCE_REGISTRY_HISTORICAL_BACKFILL_FIELDS:
            add(
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_BACKFILL_FIELD_SET_INVALID",
                "historical identity backfill fields are not closed",
            )
        component_id = str(row.get("component_id", ""))
        if (
            not component_id
            or any(char in component_id for char in "*?[]")
            or not _is_commit(row.get("source_commit"))
            or not _is_sha256(row.get("source_blob"))
            or str(row.get("historical_role", ""))
            not in FULL_CONVERGENCE_REGISTRY_ALLOWED_COMPONENT_ROLES
            or str(row.get("current_disposition", ""))
            not in FULL_CONVERGENCE_ALLOWED_DISPOSITIONS
            or str(row.get("production_reachability", ""))
            not in {
                "DIAGNOSTIC_ONLY",
                "DOCUMENTATION_ONLY",
                "GENERATED_EVIDENCE_ONLY",
                "NONREACHABLE",
                "PRODUCTION_REACHABLE",
                "TEST_ONLY",
            }
            or _full_convergence_exact_relation_values(
                row.get("supersession")
            )
            is None
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_BACKFILL_IDENTITY_INVALID",
                "historical identity backfill is not one exact closed identity",
            )
        if (
            str(row.get("historical_role", ""))
            in FULL_CONVERGENCE_REGISTRY_NONPRODUCTION_ROLES
            and row.get("production_reachability") == "PRODUCTION_REACHABLE"
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONPRODUCTION_ROLE_REACHABLE",
                "historical non-production role claims production reachability",
            )
        return findings

    if source_kind != "component_inventory":
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_SOURCE_KIND_INVALID",
            "Registry row is not from one recognized authority source",
        )
        return findings
    if (
        not set(row).issubset(
            FULL_CONVERGENCE_REGISTRY_COMPONENT_INVENTORY_FIELDS
        )
        or not FULL_CONVERGENCE_REGISTRY_COMPONENT_INVENTORY_REQUIRED_FIELDS.issubset(
            row
        )
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_FIELD_SET_INVALID",
            "component inventory fields are not closed",
        )
    component_id = str(row.get("component_id", ""))
    domain_id = str(row.get("domain_id", ""))
    owner_id = str(row.get("owner_component_id", ""))
    row_path = str(row.get("path", ""))
    owner_path = str(row.get("owner_path", ""))
    role = str(row.get("component_role", ""))
    if any(
        not value or any(char in value for char in "*?[]")
        for value in (component_id, domain_id, owner_id)
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_IDENTIFIER_INVALID",
            "Registry identity contains an empty or wildcard identifier",
        )
    if (
        not row_path
        or _normalize_path(row_path) != row_path
        or row_path.startswith(("/", "../"))
        or row_path.endswith("/")
        or "/../" in row_path
        or any(char in row_path for char in "*?[]")
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_PATH_INVALID",
            "Registry path is not one exact repository path",
        )
    if (
        not owner_path
        or _normalize_path(owner_path) != owner_path
        or owner_path.startswith(("/", "../"))
        or owner_path.endswith("/")
        or "/../" in owner_path
        or any(char in owner_path for char in "*?[]")
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_OWNER_PATH_INVALID",
            "Registry owner path is not one exact repository path",
        )
    if role not in FULL_CONVERGENCE_REGISTRY_ALLOWED_COMPONENT_ROLES:
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_ROLE_INVALID",
            "Registry role is outside the closed role set",
        )
    authority_bool_fields = (
        "owns_identity",
        "owns_presentation",
        "owns_replay",
        "owns_rng",
        "owns_save",
        "owns_tick",
        "production_reachable",
        "reads_authority",
        "writes_authority",
    )
    if any(
        not isinstance(row.get(field), bool)
        for field in authority_bool_fields
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_AUTHORITY_FLAGS_INVALID",
            "Registry authority and reachability flags are not boolean",
        )
    ownership_fields = (
        "owns_identity",
        "owns_presentation",
        "owns_replay",
        "owns_rng",
        "owns_save",
        "owns_tick",
    )
    if role == "OWNER":
        if (
            owner_id != component_id
            or owner_path != row_path
            or row.get("writes_authority") is not True
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_OWNER_AUTHORITY_INVALID",
                "Registry Owner is not self-bound with write authority",
            )
    else:
        if role == "DIAGNOSTIC_BENCH":
            forbidden_ownership = tuple(
                field for field in ownership_fields if field != "owns_presentation"
            )
            if any(row.get(field) is not False for field in forbidden_ownership):
                add(
                    "FULL_CONVERGENCE_IDENTITY_REGISTRY_DIAGNOSTIC_OWNERSHIP_INVALID",
                    "diagnostic bench owns authority outside presentation",
                )
        elif any(row.get(field) is not False for field in ownership_fields):
            add(
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONOWNER_OWNERSHIP_INVALID",
                "non-Owner claims an Owner authority flag",
            )
        if role != "REDUCER" and row.get("writes_authority") is not False:
            add(
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONOWNER_WRITE_INVALID",
                "non-Reducer non-Owner writes authority",
            )
    if role in FULL_CONVERGENCE_REGISTRY_NONPRODUCTION_ROLES and row.get(
        "production_reachable"
    ) is not False:
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONPRODUCTION_ROLE_REACHABLE",
            "semantic non-production role is production reachable",
        )
    for field in ("supersedes", "superseded_by"):
        if _full_convergence_exact_relation_values(row.get(field)) is None:
            add(
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_RELATION_SET_INVALID",
                "Registry relation list is not exact, sorted, and unique",
                field=field,
            )
    reuse_disposition = row.get("reuse_disposition")
    if reuse_disposition not in FULL_CONVERGENCE_REGISTRY_ALLOWED_REUSE_DISPOSITIONS:
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_REUSE_DISPOSITION_INVALID",
            "Registry reuse disposition is outside the closed set",
        )
    if role == "OWNER" and reuse_disposition != "ADOPT_AS_OWNER":
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_OWNER_DISPOSITION_INVALID",
            "Registry Owner is not adopted as the Owner",
        )
    if role != "OWNER" and reuse_disposition == "ADOPT_AS_OWNER":
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONOWNER_DISPOSITION_INVALID",
            "non-Owner claims Owner disposition",
        )
    if role == "TEST_SUPPORT" and reuse_disposition != "REUSE_AS_TEST":
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_TEST_DISPOSITION_INVALID",
            "test support is not classified as test reuse",
        )
    return findings


def _full_convergence_dynamic_structure_findings(
    row: dict[str, Any],
    *,
    path: str,
    fingerprint: str,
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []

    def add(code: str, message: str) -> None:
        findings.append(_finding(
            code,
            "P0",
            message,
            path=path,
            fingerprint=fingerprint,
        ))

    location = row.get("source_line_or_ast_location")
    targets = row.get("resolved_targets")
    rendered_targets = [str(value) for value in targets] if isinstance(targets, list) else []
    callsite = row.get("callsite_contract")
    if row.get("resolution_method") not in FULL_CONVERGENCE_DYNAMIC_REFERENCE_RESOLUTION_METHODS:
        add(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_RESOLUTION_METHOD_INVALID",
            "dynamic resolution method is outside the closed set",
        )
    if (
        not isinstance(callsite, dict)
        or set(callsite) != FULL_CONVERGENCE_DYNAMIC_REFERENCE_CALLSITE_FIELDS
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_CALLSITE_CONTRACT_INVALID",
            "dynamic callsite contract fields are not closed",
        )
        return findings
    helper = str(callsite.get("helper_function", ""))
    constants = callsite.get("allowed_argument_constants")
    rendered_constants = [str(value) for value in constants] if isinstance(constants, list) else []
    sites = callsite.get("required_loader_sites")
    rendered_sites = sites if isinstance(sites, list) else []
    if (
        not helper
        or not isinstance(location, dict)
        or helper != str(location.get("containing_function", ""))
        or not _is_exact_positive_int(location.get("line"))
        or not _is_exact_positive_int(location.get("column"))
        or not rendered_constants
        or rendered_constants != sorted(rendered_constants)
        or len(rendered_constants) != len(set(rendered_constants))
        or any(re.fullmatch(r"[A-Z][A-Z0-9_]*", value) is None for value in rendered_constants)
        or not _is_exact_int_equal(
            callsite.get("required_invocation_count"), len(rendered_constants)
        )
        or len(rendered_constants) != len(rendered_targets)
        or not _is_exact_int_equal(
            callsite.get("external_or_unknown_invocation_count"), 0
        )
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_CALLSITE_CONTRACT_INVALID",
            "dynamic callsite contract does not bind exact known invocations",
        )
    site_keys: list[tuple[int, int, str, str]] = []
    for site in rendered_sites:
        if not isinstance(site, dict) or set(site) != FULL_CONVERGENCE_DYNAMIC_REFERENCE_LOADER_SITE_FIELDS:
            add(
                "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_LOADER_SITE_INVALID",
                "dynamic loader site fields are not closed",
            )
            continue
        key = (
            site.get("line") if _is_exact_positive_int(site.get("line")) else 0,
            site.get("column")
            if _is_exact_positive_int(site.get("column"))
            else 0,
            str(site.get("loader", "")),
            str(site.get("reference_expression", "")),
        )
        site_keys.append(key)
        if key[0] < 1 or key[1] < 1 or not key[2] or not key[3]:
            add(
                "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_LOADER_SITE_INVALID",
                "dynamic loader site is incomplete",
            )
    if not site_keys or site_keys != sorted(site_keys) or len(site_keys) != len(set(site_keys)):
        add(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_LOADER_SITE_SET_INVALID",
            "dynamic loader sites are not exact, sorted, and unique",
        )
    if isinstance(location, dict) and (
        location.get("line"),
        location.get("column"),
        str(row.get("loader", "")),
        str(row.get("reference_expression", "")),
    ) not in site_keys:
        add(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_PRIMARY_SITE_MISMATCH",
            "dynamic primary site is not one required loader site",
        )
    runtime_probe = row.get("runtime_probe")
    if isinstance(runtime_probe, dict):
        test_path = _normalize_path(str(runtime_probe.get("test_path", "")))
        if (
            not test_path
            or test_path.startswith(("/", "../"))
            or any(char in test_path for char in "*?[]")
            or Path(test_path).suffix != ".gd"
            or Path(test_path).stem != str(runtime_probe.get("probe_id", ""))
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_RUNTIME_PROBE_INVALID",
                "dynamic runtime probe identity does not match its exact test path",
            )
    return findings


def _identity_projection_findings(
    binding: dict[str, Any],
    *,
    path: str,
    fingerprint: str,
    rule_id: str,
    raw_failure: str = "",
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []

    def add(code: str, message: str, **evidence: Any) -> None:
        findings.append(_finding(
            code,
            "P0",
            message,
            path=path,
            fingerprint=fingerprint,
            **evidence,
        ))

    projection = binding.get("subject_projection")
    if not isinstance(projection, dict):
        add(
            "FULL_CONVERGENCE_IDENTITY_PROJECTION_INVALID",
            "identity projection is not one strict object",
        )
        return findings
    if set(projection) != FULL_CONVERGENCE_SUBJECT_PROJECTION_FIELDS:
        add(
            "FULL_CONVERGENCE_IDENTITY_PROJECTION_FIELD_SET_INVALID",
            "identity projection fields differ from the closed contract",
        )
    projected: dict[str, list[Any]] = {}
    for field in FULL_CONVERGENCE_SUBJECT_PROJECTION_FIELDS:
        value = projection.get(field)
        if not isinstance(value, list):
            add(
                "FULL_CONVERGENCE_IDENTITY_PROJECTION_LIST_INVALID",
                "identity projection member is not a list",
                field=field,
            )
            projected[field] = []
        else:
            projected[field] = value
    if not any(projected.values()):
        add(
            "FULL_CONVERGENCE_IDENTITY_PROJECTION_EMPTY",
            "identity projection contains no authority row",
        )

    selector = binding.get("authority_selectors")
    selector_components = (
        {str(value) for value in selector.get("component_ids", [])}
        if isinstance(selector, dict)
        else set()
    )
    selector_paths = (
        {_normalize_path(str(value)) for value in selector.get("paths", [])}
        if isinstance(selector, dict)
        else set()
    )
    expected_components = {
        str(binding.get(field, ""))
        for field in (
            "current_component_id",
            "current_owner_id",
            "historical_component_id",
            "historical_owner_id",
        )
        if binding.get(field)
    }
    expected_paths = {
        _normalize_path(str(binding.get(field, "")))
        for field in ("current_path", "historical_path")
        if binding.get(field)
    }
    if selector_components != expected_components:
        add(
            "FULL_CONVERGENCE_IDENTITY_COMPONENT_SELECTOR_SET_MISMATCH",
            "component selectors differ from the exact identity and owner set",
        )
    if selector_paths != expected_paths:
        add(
            "FULL_CONVERGENCE_IDENTITY_PATH_SELECTOR_SET_MISMATCH",
            "path selectors differ from the exact historical/current path set",
        )
    registry_rows = [
        row for row in projected["registry_rows"] if isinstance(row, dict)
    ]
    if len(registry_rows) != len(projected["registry_rows"]):
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_ROW_INVALID",
            "identity projection contains a non-object Registry row",
        )
    for row in registry_rows:
        findings.extend(_full_convergence_registry_row_findings(
            row,
            path=path,
            fingerprint=fingerprint,
        ))
    component_inventory_rows = [
        row
        for row in registry_rows
        if row.get("authority_source_kind") == "component_inventory"
    ]
    historical_backfill_rows = [
        row
        for row in registry_rows
        if row.get("authority_source_kind") == "historical_identity_backfill"
    ]
    component_inventory_ids = [
        str(row.get("component_id", "")) for row in component_inventory_rows
    ]
    historical_backfill_ids = [
        str(row.get("component_id", "")) for row in historical_backfill_rows
    ]
    projected_authority_component_ids = set(component_inventory_ids) | set(
        historical_backfill_ids
    )
    if projected_authority_component_ids != selector_components:
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_SELECTOR_SET_MISMATCH",
            "projected Registry authority component ids differ from the selector",
        )
    if any(
        component_inventory_ids.count(component_id) != 1
        for component_id in set(component_inventory_ids)
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_PRIMARY_KEY_NOT_UNIQUE",
            "a component inventory component id does not occur exactly once",
        )
    historical_backfill_keys = [
        (
            str(row.get("component_id", "")),
            str(row.get("source_commit", "")),
            str(row.get("source_blob", "")),
        )
        for row in historical_backfill_rows
    ]
    if any(
        historical_backfill_keys.count(key) != 1
        for key in set(historical_backfill_keys)
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_BACKFILL_PRIMARY_KEY_NOT_UNIQUE",
            "a historical backfill composite identity occurs more than once",
        )

    bound_registry_rows: dict[str, dict[str, Any]] = {}

    def validate_selected_owner(
        prefix: str,
        *,
        owner_id: str,
        expected_domain: str,
        declared_owner_path: str = "",
    ) -> None:
        if not owner_id:
            add(
                "FULL_CONVERGENCE_IDENTITY_OWNER_MISSING",
                "identity side has no exact Owner",
                side=prefix,
            )
            return
        owner_rows = [
            row
            for row in component_inventory_rows
            if str(row.get("component_id", "")) == owner_id
        ]
        if (
            owner_id not in selector_components
            or len(owner_rows) != 1
            or str(owner_rows[0].get("domain_id", "")) != expected_domain
            or owner_rows[0].get("component_role") != "OWNER"
            or owner_rows[0].get("owner_component_id") != owner_id
            or owner_rows[0].get("owner_path") != owner_rows[0].get("path")
            or (
                declared_owner_path
                and declared_owner_path != str(owner_rows[0].get("path", ""))
            )
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_OWNER_ROW_NOT_UNIQUE",
                "identity Owner is not one selected same-domain inventory Owner",
                side=prefix,
            )

    def bind_inventory_side(prefix: str) -> None:
        component_id = str(binding.get(f"{prefix}_component_id", ""))
        row_path = _normalize_path(str(binding.get(f"{prefix}_path", "")))
        if not component_id:
            add(
                "FULL_CONVERGENCE_IDENTITY_COMPONENT_MISSING",
                "identity side has no exact component id",
                side=prefix,
            )
            return
        rows = [
            row
            for row in component_inventory_rows
            if str(row.get("component_id", "")) == component_id
        ]
        if len(rows) != 1:
            add(
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_ROW_NOT_UNIQUE",
                "identity side does not resolve to one primary Registry row",
                side=prefix,
            )
            return
        row = rows[0]
        bound_registry_rows[prefix] = row
        if row_path and _normalize_path(str(row.get("path", ""))) != row_path:
            add(
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_PATH_MISMATCH",
                "identity path differs from its unique Registry row",
                side=prefix,
            )
        for binding_field, row_field in (
            ("domain_id", "domain_id"),
            (f"{prefix}_role", "component_role"),
            (f"{prefix}_owner_id", "owner_component_id"),
        ):
            if str(binding.get(binding_field, "")) != str(row.get(row_field, "")):
                add(
                    "FULL_CONVERGENCE_IDENTITY_REGISTRY_FIELD_MISMATCH",
                    "identity field differs from its unique Registry row",
                    side=prefix,
                    field=row_field,
                )
        reachable = row.get("production_reachable")
        declared = str(binding.get(f"{prefix}_production_reachability", ""))
        if not isinstance(reachable, bool) or (
            reachable and declared != "PRODUCTION_REACHABLE"
        ) or (not reachable and declared == "PRODUCTION_REACHABLE"):
            add(
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_REACHABILITY_MISMATCH",
                "identity reachability differs from its unique Registry row",
                side=prefix,
            )
        role = str(row.get("component_role", ""))
        owner_id = str(row.get("owner_component_id", ""))
        if role == "OWNER" and owner_id != component_id:
            add(
                "FULL_CONVERGENCE_IDENTITY_OWNER_SELF_BINDING_INVALID",
                "Registry Owner does not self-bind",
                side=prefix,
            )
        elif role != "OWNER" and not owner_id:
            add(
                "FULL_CONVERGENCE_IDENTITY_OWNER_MISSING",
                "non-Owner has no exact Owner",
                side=prefix,
            )
        validate_selected_owner(
            prefix,
            owner_id=owner_id,
            expected_domain=str(row.get("domain_id", "")),
            declared_owner_path=str(row.get("owner_path", "")),
        )

    def bind_historical_side() -> None:
        prefix = "historical"
        component_id = str(binding.get("historical_component_id", ""))
        if not component_id:
            add(
                "FULL_CONVERGENCE_IDENTITY_COMPONENT_MISSING",
                "identity side has no exact component id",
                side=prefix,
            )
            return
        component_backfills = [
            row
            for row in historical_backfill_rows
            if str(row.get("component_id", "")) == component_id
        ]
        exact_backfills = [
            row
            for row in component_backfills
            if (
                str(row.get("source_commit", ""))
                == str(binding.get("source_commit", ""))
                and str(row.get("source_blob", ""))
                == str(binding.get("historical_blob_sha256", ""))
            )
        ]
        if component_backfills:
            if len(exact_backfills) != 1:
                add(
                    "FULL_CONVERGENCE_IDENTITY_REGISTRY_ROW_NOT_UNIQUE",
                    "historical identity does not resolve to one exact backfill row",
                    side=prefix,
                )
                return
            row = exact_backfills[0]
            bound_registry_rows[prefix] = row
            for binding_field, row_field in (
                ("historical_role", "historical_role"),
                ("recommended_disposition", "current_disposition"),
                (
                    "historical_production_reachability",
                    "production_reachability",
                ),
            ):
                if str(binding.get(binding_field, "")) != str(row.get(row_field, "")):
                    add(
                        "FULL_CONVERGENCE_IDENTITY_REGISTRY_FIELD_MISMATCH",
                        "historical identity differs from its exact backfill row",
                        side=prefix,
                        field=row_field,
                    )
            historical_owner_id = str(binding.get("historical_owner_id", ""))
            if row.get("historical_role") == "OWNER":
                if historical_owner_id != component_id:
                    add(
                        "FULL_CONVERGENCE_IDENTITY_OWNER_SELF_BINDING_INVALID",
                        "historical backfill Owner does not self-bind",
                        side=prefix,
                    )
            else:
                validate_selected_owner(
                    prefix,
                    owner_id=historical_owner_id,
                    expected_domain=str(binding.get("domain_id", "")),
                )
            return
        bind_inventory_side(prefix)

    bind_historical_side()
    bind_inventory_side("current")

    disposition = str(binding.get("recommended_disposition", ""))
    supersedes = _full_convergence_exact_relation_values(
        binding.get("supersedes")
    )
    superseded_by = _full_convergence_exact_relation_values(
        binding.get("superseded_by")
    )
    if supersedes is None:
        add(
            "FULL_CONVERGENCE_IDENTITY_SUPERSEDES_SET_INVALID",
            "identity supersedes list is not exact, sorted, and unique",
        )
        supersedes = []
    if superseded_by is None:
        add(
            "FULL_CONVERGENCE_IDENTITY_SUPERSEDED_BY_SET_INVALID",
            "identity superseded_by list is not exact, sorted, and unique",
        )
        superseded_by = []
    if disposition in FULL_CONVERGENCE_IDENTITY_NON_MIGRATION_DISPOSITIONS and (
        binding.get("historical_component_id") != binding.get("current_component_id")
        or _normalize_path(str(binding.get("historical_path", "")))
        != _normalize_path(str(binding.get("current_path", "")))
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_UNAUTHORIZED_LINEAGE_SUBSTITUTION",
            "non-migration disposition substitutes an unrelated current identity",
        )
    historical_registry_row = bound_registry_rows.get("historical", {})
    current_registry_row = bound_registry_rows.get("current", {})
    registry_supersedes = _full_convergence_exact_relation_values(
        current_registry_row.get("supersedes")
    )
    historical_relation_field = (
        "supersession"
        if historical_registry_row.get("authority_source_kind")
        == "historical_identity_backfill"
        else "superseded_by"
    )
    registry_superseded_by = _full_convergence_exact_relation_values(
        historical_registry_row.get(historical_relation_field)
    )
    if registry_supersedes is not None and supersedes != registry_supersedes:
        add(
            "FULL_CONVERGENCE_IDENTITY_SUPERSEDES_REGISTRY_MISMATCH",
            "identity supersedes list differs from its current Registry row",
        )
    if registry_superseded_by is not None and superseded_by != registry_superseded_by:
        add(
            "FULL_CONVERGENCE_IDENTITY_SUPERSEDED_BY_REGISTRY_MISMATCH",
            "identity superseded_by list differs from its historical Registry row",
        )

    dynamic_rows = [
        row
        for row in projected["dynamic_reference_rows"]
        if isinstance(row, dict)
    ]
    if len(dynamic_rows) != len(projected["dynamic_reference_rows"]):
        add(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_ROW_INVALID",
            "dynamic projection contains a non-object row",
        )
    is_dynamic = rule_id == "HISTORY_DYNAMIC_REFERENCE_UNRESOLVED"
    selector_dynamic_ids = (
        [str(value) for value in selector.get("dynamic_reference_ids", [])]
        if isinstance(selector, dict)
        and isinstance(selector.get("dynamic_reference_ids"), list)
        else []
    )
    projected_dynamic_ids = [
        str(row.get("dynamic_reference_id", "")) for row in dynamic_rows
    ]
    if set(projected_dynamic_ids) != set(selector_dynamic_ids):
        add(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_SELECTOR_UNRESOLVED",
            "dynamic projection ids differ from the exact selector",
        )
    if any(
        projected_dynamic_ids.count(reference_id) != 1
        for reference_id in selector_dynamic_ids
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_PRIMARY_KEY_NOT_UNIQUE",
            "a selected dynamic reference id does not occur exactly once",
        )
    if is_dynamic:
        source_path = _normalize_path(str(binding.get("historical_path", "")))
        rows = [
            row
            for row in dynamic_rows
            if _normalize_path(str(row.get("source_path", ""))) == source_path
            and str(row.get("dynamic_reference_id", "")) in selector_dynamic_ids
        ]
        parts = raw_failure.split(":")
        if raw_failure and len(parts) >= 5:
            rows = [
                row
                for row in rows
                if row.get("loader") == parts[1]
                and row.get("reference_expression") == parts[2]
            ]
        if (
            len(selector_dynamic_ids) != 1
            or len(rows) != 1
            or selector_dynamic_ids[0]
            != str(rows[0].get("dynamic_reference_id", ""))
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_SELECTOR_MISMATCH",
                "dynamic identity does not select one exact manifest entry",
            )
        for row in rows:
            if set(row) != FULL_CONVERGENCE_DYNAMIC_REFERENCE_ENTRY_FIELDS:
                add(
                    "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_FIELD_SET_INVALID",
                    "dynamic manifest row fields differ from the closed contract",
                )
                continue
            location = row.get("source_line_or_ast_location")
            targets = row.get("resolved_targets")
            rendered_targets = (
                [str(value) for value in targets]
                if isinstance(targets, list)
                else []
            )
            runtime_probe = row.get("runtime_probe")
            policy = row.get("failure_policy")
            if (
                not str(row.get("dynamic_reference_id", ""))
                or not _is_sha256(row.get("source_blob_sha256"))
                or not isinstance(location, dict)
                or set(location) != FULL_CONVERGENCE_DYNAMIC_REFERENCE_LOCATION_FIELDS
                or not _is_exact_positive_int(location.get("line"))
                or not _is_exact_positive_int(location.get("column"))
                or not str(location.get("containing_function", ""))
                or not str(row.get("loader", ""))
                or not str(row.get("reference_expression", ""))
                or not isinstance(row.get("production_reachable"), bool)
                or not str(row.get("resolution_method", ""))
                or not isinstance(row.get("callsite_contract"), dict)
                or not row.get("callsite_contract")
                ):
                    add(
                    "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_METADATA_INVALID",
                        "dynamic manifest row metadata is incomplete",
                    )
            findings.extend(_full_convergence_dynamic_structure_findings(
                row,
                path=path,
                fingerprint=fingerprint,
            ))
            if (
                not rendered_targets
                or rendered_targets != sorted(rendered_targets)
                or len(rendered_targets) != len(set(rendered_targets))
                or any(
                    not value.startswith("res://")
                    or _normalize_path(value) != value[6:]
                    or any(char in value for char in "*?[]")
                    for value in rendered_targets
                )
                or row.get("target_set_sha256")
                != _sha_bytes("\n".join(rendered_targets).encode("utf-8"))
            ):
                add(
                    "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_TARGET_SET_INVALID",
                    "dynamic target set is not one exact sorted digest-bound set",
                )
            if (
                not isinstance(runtime_probe, dict)
                or set(runtime_probe)
                != FULL_CONVERGENCE_DYNAMIC_REFERENCE_RUNTIME_PROBE_FIELDS
                or not str(runtime_probe.get("probe_id", ""))
                or not str(runtime_probe.get("test_path", ""))
                or not _is_exact_int_equal(
                    runtime_probe.get("expected_target_count"),
                    len(rendered_targets),
                )
                or runtime_probe.get("required_before_production_claim") is not True
            ):
                add(
                    "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_RUNTIME_PROBE_INVALID",
                    "dynamic runtime probe is not exact and required",
                )
            if (
                not isinstance(policy, dict)
                or set(policy)
                != FULL_CONVERGENCE_DYNAMIC_REFERENCE_FAILURE_POLICY_FIELDS
                or policy.get("source_blob_change_invalidates") is not True
                or policy.get("source_location_change_invalidates") is not True
                or policy.get("target_set_change_invalidates") is not True
                or policy.get("unknown_callsite_fails_closed") is not True
                or not _is_exact_int_equal(
                    policy.get("future_site_auto_resolution_count"), 0
                )
                or not _is_exact_int_equal(policy.get("wildcard_count"), 0)
            ):
                add(
                    "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_FAILURE_POLICY_INVALID",
                    "dynamic failure policy permits drift or future auto-resolution",
                )
    elif selector_dynamic_ids:
        add(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_SELECTOR_UNEXPECTED",
            "non-dynamic identity selects dynamic-reference authority",
        )

    selected_supersession_ids = (
        [str(value) for value in selector.get("supersession_ids", [])]
        if isinstance(selector, dict)
        and isinstance(selector.get("supersession_ids"), list)
        else []
    )
    selected_retirement_ids = (
        [str(value) for value in selector.get("retirement_ids", [])]
        if isinstance(selector, dict)
        and isinstance(selector.get("retirement_ids"), list)
        else []
    )
    supersession_rows = [
        row for row in projected["supersession_rows"] if isinstance(row, dict)
    ]
    if len(supersession_rows) != len(projected["supersession_rows"]):
        add(
            "FULL_CONVERGENCE_IDENTITY_DISPOSITION_AUTHORITY_ROW_INVALID",
            "disposition projection contains a non-object row",
        )
    projected_supersession_ids = [
        str(row.get("supersession_id", ""))
        for row in supersession_rows
        if row.get("supersession_id")
    ]
    projected_retirement_ids = [
        str(row.get("retirement_id", ""))
        for row in supersession_rows
        if row.get("retirement_id")
    ]
    if any(
        bool(row.get("supersession_id")) == bool(row.get("retirement_id"))
        for row in supersession_rows
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_DISPOSITION_AUTHORITY_KIND_INVALID",
            "authority row is neither one supersession nor one retirement",
        )
    if set(projected_supersession_ids) != set(selected_supersession_ids):
        add(
            "FULL_CONVERGENCE_IDENTITY_SUPERSESSION_SELECTOR_UNRESOLVED",
            "supersession selector does not resolve exactly",
        )
    if any(
        projected_supersession_ids.count(authority_id) != 1
        for authority_id in selected_supersession_ids
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_SUPERSESSION_PRIMARY_KEY_NOT_UNIQUE",
            "a selected supersession id does not occur exactly once",
        )
    if set(projected_retirement_ids) != set(selected_retirement_ids):
        add(
            "FULL_CONVERGENCE_IDENTITY_RETIREMENT_SELECTOR_UNRESOLVED",
            "retirement selector does not resolve exactly",
        )
    if any(
        projected_retirement_ids.count(authority_id) != 1
        for authority_id in selected_retirement_ids
    ):
        add(
            "FULL_CONVERGENCE_IDENTITY_RETIREMENT_PRIMARY_KEY_NOT_UNIQUE",
            "a selected retirement id does not occur exactly once",
        )
    if disposition in {
        "HISTORICAL_SUPERSEDED_NONREACHABLE",
        "HISTORICAL_DYNAMIC_REFERENCE_SUPERSEDED",
    }:
        rows = [
            row
            for row in supersession_rows
            if str(row.get("supersession_id", ""))
            in selected_supersession_ids
            and row.get("old_component_id")
            == binding.get("historical_component_id")
            and row.get("new_component_id") in binding.get("superseded_by", [])
            and row.get("domain_id") == binding.get("domain_id")
            and _is_exact_int_equal(row.get("dual_write_count"), 0)
            and _is_exact_int_equal(row.get("fallback_count"), 0)
            and _is_exact_int_equal(
                row.get("old_owner_production_reachability"), 0
            )
        ]
        matched_ids = {
            str(row.get("supersession_id", "")) for row in rows
        }
        matched_successors = sorted({
            str(row.get("new_component_id", ""))
            for row in rows
            if row.get("new_component_id")
        })
        if (
            not selected_supersession_ids
            or len(rows) != len(selected_supersession_ids)
            or matched_ids != set(selected_supersession_ids)
            or matched_successors != superseded_by
            or not set(matched_successors).issubset(selector_components)
            or binding.get("current_component_id") not in matched_successors
            or binding.get("historical_component_id") not in supersedes
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_SUPERSESSION_AUTHORITY_MISMATCH",
                "superseded disposition lacks one exact no-dual-write map row",
            )
    elif selected_supersession_ids:
        add(
            "FULL_CONVERGENCE_IDENTITY_SUPERSESSION_SELECTOR_UNEXPECTED",
            "non-superseded disposition selects supersession authority",
        )
    if disposition == "HISTORICAL_RETIRED_NONREACHABLE":
        rows = [
            row
            for row in supersession_rows
            if str(row.get("retirement_id", "")) in selected_retirement_ids
            and row.get("component_id")
            == binding.get("historical_component_id")
            and row.get("domain_id") == binding.get("domain_id")
            and row.get("production_reachable") is False
            and _is_exact_int_equal(row.get("dual_write_count"), 0)
            and _is_exact_int_equal(row.get("fallback_count"), 0)
            and row.get("retired_status") == "RETIRED_NONREACHABLE"
        ]
        matched_ids = {
            str(row.get("retirement_id", "")) for row in rows
        }
        if (
            not selected_retirement_ids
            or len(rows) != len(selected_retirement_ids)
            or matched_ids != set(selected_retirement_ids)
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_RETIREMENT_AUTHORITY_MISMATCH",
                "retired disposition lacks one exact nonreachable map row",
            )
    elif selected_retirement_ids:
        add(
            "FULL_CONVERGENCE_IDENTITY_RETIREMENT_SELECTOR_UNEXPECTED",
            "non-retired disposition selects retirement authority",
        )
    return findings


def _dynamic_projection_repo_findings(
    root: Path,
    authority_commit: str,
    projection: dict[str, Any],
    *,
    source_commit: str,
    path: str,
    fingerprint: str,
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []

    def add(code: str, message: str, **evidence: Any) -> None:
        findings.append(_finding(
            code,
            "P0",
            message,
            path=path,
            fingerprint=fingerprint,
            **evidence,
        ))

    rows = projection.get("dynamic_reference_rows", [])
    if not isinstance(rows, list):
        add(
            "FULL_CONVERGENCE_DYNAMIC_REFERENCE_PROJECTION_ROWS_INVALID",
            "dynamic projection rows are not a list",
        )
        return findings
    for row in rows:
        if (
            not isinstance(row, dict)
            or set(row) != FULL_CONVERGENCE_DYNAMIC_REFERENCE_ENTRY_FIELDS
        ):
            continue
        reference_id = str(row.get("dynamic_reference_id", ""))
        source_path = _normalize_path(str(row.get("source_path", "")))
        source_bytes = (
            _git_bytes(root, source_commit, source_path)
            if source_path and _is_commit(source_commit)
            else None
        )
        if (
            source_bytes is None
            or _sha_bytes(source_bytes) != row.get("source_blob_sha256")
        ):
            add(
                "FULL_CONVERGENCE_DYNAMIC_REFERENCE_SOURCE_BLOB_MISMATCH",
                "dynamic source blob differs from its source commit",
                dynamic_reference_id=reference_id,
            )
        if source_bytes is not None:
            source_text = source_bytes.decode("utf-8-sig", errors="replace")
            source_lines = source_text.splitlines()
            location = row.get("source_line_or_ast_location")
            line_number = (
                location.get("line")
                if isinstance(location, dict)
                and _is_exact_positive_int(location.get("line"))
                else 0
            )
            column = (
                location.get("column")
                if isinstance(location, dict)
                and _is_exact_positive_int(location.get("column"))
                else 0
            )
            loader = str(row.get("loader", ""))
            expression = str(row.get("reference_expression", ""))
            source_line = (
                source_lines[line_number - 1]
                if _is_exact_positive_int(line_number)
                and line_number <= len(source_lines)
                else ""
            )
            if (
                not source_line
                or loader not in source_line
                or expression not in source_line
                or source_line.find(loader) + 1 != column
            ):
                add(
                    "FULL_CONVERGENCE_DYNAMIC_REFERENCE_SOURCE_LOCATION_MISMATCH",
                    "dynamic source location does not identify the declared loader",
                    dynamic_reference_id=reference_id,
                )
            containing_function = (
                str(location.get("containing_function", ""))
                if isinstance(location, dict)
                else ""
            )
            preceding_function = ""
            for candidate in reversed(source_lines[: max(line_number - 1, 0)]):
                match = re.match(r"\s*func\s+([A-Za-z0-9_]+)\s*\(", candidate)
                if match:
                    preceding_function = match.group(1)
                    break
            if preceding_function != containing_function:
                add(
                    "FULL_CONVERGENCE_DYNAMIC_REFERENCE_CONTAINING_FUNCTION_MISMATCH",
                    "dynamic source location is not inside the declared function",
                    dynamic_reference_id=reference_id,
                )
            callsite = row.get("callsite_contract")
            sites = callsite.get("required_loader_sites", []) if isinstance(callsite, dict) else []
            for site in sites if isinstance(sites, list) else []:
                if not isinstance(site, dict):
                    continue
                site_line_number = site.get("line")
                site_column = site.get("column")
                site_loader = str(site.get("loader", ""))
                site_expression = str(site.get("reference_expression", ""))
                site_line = (
                    source_lines[site_line_number - 1]
                    if _is_exact_positive_int(site_line_number)
                    and site_line_number <= len(source_lines)
                    else ""
                )
                if (
                    not site_line
                    or not _is_exact_positive_int(site_column)
                    or site_loader not in site_line
                    or site_expression not in site_line
                    or site_line.find(site_loader) + 1 != site_column
                ):
                    add(
                        "FULL_CONVERGENCE_DYNAMIC_REFERENCE_LOADER_SITE_MISMATCH",
                        "one required loader site does not match source bytes",
                        dynamic_reference_id=reference_id,
                    )
            if isinstance(callsite, dict):
                helper = str(callsite.get("helper_function", ""))
                allowed_constants = [
                    str(value)
                    for value in callsite.get("allowed_argument_constants", [])
                ] if isinstance(callsite.get("allowed_argument_constants"), list) else []
                constant_values = {
                    match.group(1): match.group(2)
                    for match in re.finditer(
                        r'^\s*const\s+([A-Z][A-Z0-9_]*)\s*:?=\s*"([^"]+)"\s*$',
                        source_text,
                        flags=re.MULTILINE,
                    )
                }
                resolved_constant_targets = sorted(
                    constant_values.get(name, "") for name in allowed_constants
                )
                helper_invocations: list[str] = []
                if helper:
                    invocation_pattern = re.compile(
                        rf"\b{re.escape(helper)}\s*\(\s*([^\s,)]+)"
                    )
                    for source_line_candidate in source_lines:
                        if re.match(
                            rf"\s*func\s+{re.escape(helper)}\s*\(",
                            source_line_candidate,
                        ):
                            continue
                        helper_invocations.extend(
                            match.group(1)
                            for match in invocation_pattern.finditer(source_line_candidate)
                        )
                declared_targets = sorted(
                    str(value) for value in row.get("resolved_targets", [])
                ) if isinstance(row.get("resolved_targets"), list) else []
                if (
                    not allowed_constants
                    or any(not value for value in resolved_constant_targets)
                    or resolved_constant_targets != declared_targets
                    or sorted(helper_invocations) != sorted(allowed_constants)
                    or not _is_exact_int_equal(
                        callsite.get("required_invocation_count"),
                        len(helper_invocations),
                    )
                ):
                    add(
                        "FULL_CONVERGENCE_DYNAMIC_REFERENCE_CALLSITE_TARGET_BINDING_MISMATCH",
                        "dynamic targets are not derived from the exact source constants and calls",
                        dynamic_reference_id=reference_id,
                    )
        targets = row.get("resolved_targets", [])
        if isinstance(targets, list):
            for target in targets:
                target_path = _normalize_path(str(target))
                if not target_path or _git_bytes(root, authority_commit, target_path) is None:
                    add(
                        "FULL_CONVERGENCE_DYNAMIC_REFERENCE_TARGET_MISSING",
                        "dynamic target is absent from the authority commit",
                        dynamic_reference_id=reference_id,
                        target_path=target_path,
                    )
        runtime_probe = row.get("runtime_probe")
        test_path = (
            _normalize_path(str(runtime_probe.get("test_path", "")))
            if isinstance(runtime_probe, dict)
            else ""
        )
        if (
            not test_path
            or _git_bytes(root, authority_commit, test_path) is None
            or Path(test_path).stem != str(runtime_probe.get("probe_id", ""))
        ):
            add(
                "FULL_CONVERGENCE_DYNAMIC_REFERENCE_RUNTIME_PROBE_MISSING",
                "dynamic runtime probe path is absent or identity-mismatched",
                dynamic_reference_id=reference_id,
                test_path=test_path,
            )
    return findings


def _duplicate_observation_findings(
    fingerprint: str,
    binding: dict[str, Any],
    identities: dict[str, dict[str, str]],
    *,
    path: str,
) -> list[dict[str, Any]]:
    if (
        binding.get("recommended_disposition")
        != "HISTORICAL_DUPLICATE_OBSERVATION"
    ):
        return []
    identity = identities.get(fingerprint, {})
    duplicate_target = str(
        binding.get("duplicate_of_failure_fingerprint", "")
    )
    duplicate_identity = identities.get(duplicate_target, {})
    peers = sorted(
        other_fingerprint
        for other_fingerprint, other_identity in identities.items()
        if other_fingerprint != fingerprint
        and other_identity.get("rule_id") == identity.get("rule_id")
        and other_identity.get("subject_kind") == identity.get("subject_kind")
        and other_identity.get("subject_value") == identity.get("subject_value")
    )
    canonical = min([fingerprint, *peers]) if peers else ""
    duplicate_payload = {
        field: str(duplicate_identity.get(field, ""))
        for field in (
            "raw_failure",
            "rule_id",
            "subject_kind",
            "subject_value",
            "transition_new_prefix",
            "transition_old_prefix",
        )
    }
    if (
        peers
        and canonical != fingerprint
        and duplicate_target == canonical
        and duplicate_target != fingerprint
        and duplicate_identity.get("rule_id") == identity.get("rule_id")
        and duplicate_identity.get("subject_kind")
        == identity.get("subject_kind")
        and duplicate_identity.get("subject_value")
        == identity.get("subject_value")
        and binding.get("duplicate_identity_sha256")
        == _sha_bytes(_canonical(duplicate_payload))
        and binding.get("duplicate_reason")
        == "SAME_RULE_AND_SUBJECT_DISTINCT_TRANSITION_OBSERVATION"
    ):
        return []
    return [_finding(
        "FULL_CONVERGENCE_IDENTITY_DUPLICATE_OBSERVATION_AUTHORITY_MISMATCH",
        "P0",
        "duplicate disposition has no distinct canonical raw observation",
        path=path,
        fingerprint=fingerprint,
    )]


def _classification_record_disposition_findings(
    root: Path,
    manifest_path: Path,
    manifest: dict[str, Any],
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    try:
        classification = _json(manifest_path.parent / "batch_classification.json")
    except (OSError, ValueError):
        classification = None
    rows = (
        classification.get("classifications")
        if isinstance(classification, dict)
        else None
    )
    classification_by_fingerprint = {
        str(fingerprint): str(row.get("recommended_disposition", ""))
        for fingerprint, row in (rows.items() if isinstance(rows, dict) else [])
        if isinstance(row, dict)
    }
    record_by_fingerprint: dict[str, str] = {}
    for record_binding in manifest.get("record_bindings", []):
        if not isinstance(record_binding, dict):
            continue
        relative = _normalize_path(str(record_binding.get("path", "")))
        try:
            record = _json(root / relative)
        except (OSError, ValueError):
            continue
        identities = (
            record.get("identity_binding_by_failure")
            if isinstance(record, dict)
            else None
        )
        if not isinstance(identities, dict):
            continue
        for fingerprint, identity in identities.items():
            if isinstance(identity, dict):
                record_by_fingerprint[str(fingerprint)] = str(
                    identity.get("recommended_disposition", "")
                )
    manifest_fingerprints = {
        str(value) for value in manifest.get("failure_fingerprints", [])
    }
    if (
        set(classification_by_fingerprint) != manifest_fingerprints
        or set(record_by_fingerprint) != manifest_fingerprints
    ):
        findings.append(_finding(
            "FULL_CONVERGENCE_CLASSIFICATION_RECORD_DISPOSITION_COVERAGE_MISMATCH",
            "P0",
            "classification and record dispositions do not cover the exact batch",
            manifest_path=str(manifest_path),
        ))
    for fingerprint in sorted(manifest_fingerprints):
        if classification_by_fingerprint.get(fingerprint) != record_by_fingerprint.get(
            fingerprint
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_CLASSIFICATION_RECORD_DISPOSITION_MISMATCH",
                "P0",
                "classification disposition differs from the actual correction record",
                manifest_path=str(manifest_path),
                fingerprint=fingerprint,
            ))
    return findings


def _full_convergence_record_contract_findings(
    record: dict[str, Any],
    *,
    path: str,
    root: Path | None = None,
) -> list[dict[str, Any]]:
    """Duplicate the primary record contract without importing the resolver."""

    findings: list[dict[str, Any]] = []

    def add(code: str, message: str, **evidence: Any) -> None:
        findings.append(_finding(code, "P0", message, path=path, **evidence))

    if set(record) != FULL_CONVERGENCE_RECORD_FIELDS:
        add(
            "FULL_CONVERGENCE_RECORD_FIELD_SET_INVALID",
            "record fields differ from the exact closed contract",
        )
    for field, expected in (
        ("schema_version", FULL_CONVERGENCE_RECORD_SCHEMA_VERSION),
        ("record_kind", "CORRECTION_RECORD"),
        ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
        ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
        ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
        ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
    ):
        if record.get(field) != expected:
            add(
                "FULL_CONVERGENCE_RECORD_AUTHORITY_MISMATCH",
                "record authority or schema differs from the closed contract",
                field=field,
                expected=expected,
                actual=record.get(field),
            )
            if field == "schema_version":
                add(
                    "FULL_CONVERGENCE_RECORD_SCHEMA_VERSION_INVALID",
                    "record schema version differs from the authorized epoch",
                )
            elif field == "record_kind":
                add(
                    "FULL_CONVERGENCE_RECORD_KIND_INVALID",
                    "record kind is not the authorized correction record kind",
                )
    if not _is_commit(record.get("binding_head_sha")):
        add(
            "FULL_CONVERGENCE_RECORD_BINDING_HEAD_INVALID",
            "record binding Head is not one exact commit",
        )
    if not _is_commit(record.get("binding_tree_sha")):
        add(
            "FULL_CONVERGENCE_RECORD_BINDING_TREE_INVALID",
            "record binding tree is not one exact Git object id",
        )
    fingerprints_value = record.get("failure_fingerprints")
    fingerprints = (
        [str(value) for value in fingerprints_value]
        if isinstance(fingerprints_value, list)
        else []
    )
    if (
        not fingerprints
        or len(fingerprints) > 50
        or fingerprints != sorted(fingerprints)
        or len(fingerprints) != len(set(fingerprints))
        or any(
            re.fullmatch(r"V2F-[0-9a-f]{64}", value) is None
            for value in fingerprints
        )
    ):
        add(
            "FULL_CONVERGENCE_RECORD_FINGERPRINT_SET_INVALID",
            "record fingerprints are not one unique sorted exact V2 set",
        )
    if (
        not _is_exact_int_equal(record.get("failure_count"), len(fingerprints))
        or record.get("failure_fingerprint_set_sha256")
        != _line_set_sha(fingerprints)
    ):
        add(
            "FULL_CONVERGENCE_RECORD_FINGERPRINT_DIGEST_INVALID",
            "record fingerprint count or digest is not canonical",
        )
    rules_value = record.get("rule_ids")
    rules = (
        [str(value) for value in rules_value]
        if isinstance(rules_value, list)
        else []
    )
    if (
        len(rules) != 1
        or not rules[0].startswith(HISTORY_PREFIX)
        or record.get("failure_classes") != rules
        or record.get("allowed_rule_ids") != rules
    ):
        add(
            "FULL_CONVERGENCE_RECORD_RULE_CLASS_INVALID",
            "record is not restricted to one exact historical rule",
        )
    transition = str(record.get("transition_class_id", ""))
    if (
        not transition
        or any(char in transition for char in "*?[]")
        or re.fullmatch(r"[A-Z0-9_]+", transition) is None
        or set(re.findall(r"[a-z0-9_]+", transition.casefold()))
        & FULL_CONVERGENCE_DISALLOWED_TOKENS
    ):
        add(
            "FULL_CONVERGENCE_RECORD_TRANSITION_CLASS_INVALID",
            "record transition class is empty or contains a waiver token",
        )
    if record.get("from_state") != "HISTORICAL_FAILURE_PRESENT_CLASSIFIED":
        add(
            "FULL_CONVERGENCE_RECORD_FROM_STATE_INVALID",
            "record source state is not the classified historical state",
        )
    if record.get("to_effective_disposition") != "CORRECTED_HISTORICAL_DEBT":
        add(
            "FULL_CONVERGENCE_RECORD_TO_STATE_INVALID",
            "record destination state is not corrected historical debt",
        )
    if (
        record.get("allowed_from_state") != record.get("from_state")
        or record.get("allowed_to_state")
        != record.get("to_effective_disposition")
    ):
        add(
            "FULL_CONVERGENCE_RECORD_ALLOWED_STATE_INVALID",
            "record allowed state boundary differs from its exact transition",
        )
    if (
        record.get("untouched_in_current_delta") is not True
        or record.get("required_untouched_state") is not True
    ):
        add(
            "FULL_CONVERGENCE_RECORD_UNTOUCHED_ATTESTATION_INVALID",
            "record does not require the historical subject to remain untouched",
        )
    if not _is_exact_future_failure_policy(record.get("future_failure_policy")):
        add(
            "FULL_CONVERGENCE_RECORD_FUTURE_AUTO_CORRECTION_ENABLED",
            "record future-failure policy is not exact and fail-closed",
        )
    touch = record.get("touch_invalidation_policy")
    if touch != FULL_CONVERGENCE_TOUCH_INVALIDATION_POLICY:
        add(
            "FULL_CONVERGENCE_RECORD_TOUCH_POLICY_INVALID",
            "record touch invalidation policy differs from the closed contract",
        )
    if record.get("revocation_policy") != FULL_CONVERGENCE_REVOCATION_POLICY:
        add(
            "FULL_CONVERGENCE_RECORD_REVOCATION_POLICY_INVALID",
            "record revocation policy is not append-only and immutable",
        )
    if not _is_sha256(record.get("previous_correction_chain_sha256")):
        add(
            "FULL_CONVERGENCE_RECORD_CHAIN_PREDECESSOR_INVALID",
            "record predecessor is not one exact payload digest",
        )
    bindings_value = record.get("identity_binding_by_failure")
    bindings = bindings_value if isinstance(bindings_value, dict) else {}
    if not isinstance(bindings_value, dict) or set(bindings) != set(fingerprints):
        add(
            "FULL_CONVERGENCE_RECORD_IDENTITY_BINDING_SET_INVALID",
            "record identity bindings do not exactly cover its fingerprints",
        )
    for fingerprint, binding in bindings.items():
        if (
            not isinstance(binding, dict)
            or set(binding) != FULL_CONVERGENCE_IDENTITY_BINDING_FIELDS
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_BINDING_FIELD_SET_INVALID",
                "identity binding fields differ from the exact closed contract",
                fingerprint=fingerprint,
            )
            continue
        findings.extend(_full_convergence_selector_findings(
            binding.get("authority_selectors"),
            path=path,
            fingerprint=str(fingerprint),
        ))
        disposition = str(binding.get("recommended_disposition", ""))
        if disposition not in FULL_CONVERGENCE_ALLOWED_DISPOSITIONS:
            add(
                "FULL_CONVERGENCE_IDENTITY_DISPOSITION_INVALID",
                "identity binding disposition is outside the exact closed set",
                fingerprint=fingerprint,
            )
        rule_id = rules[0] if len(rules) == 1 else ""
        is_dynamic_rule = rule_id == "HISTORY_DYNAMIC_REFERENCE_UNRESOLVED"
        if is_dynamic_rule != (
            disposition in FULL_CONVERGENCE_DYNAMIC_REFERENCE_DISPOSITIONS
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_RULE_DISPOSITION_MISMATCH",
                "identity disposition is not valid for its exact historical rule",
                fingerprint=fingerprint,
            )
        findings.extend(_identity_projection_findings(
            binding,
            path=path,
            fingerprint=str(fingerprint),
            rule_id=rule_id,
        ))
        for field in FULL_CONVERGENCE_IDENTITY_STATE_FIELDS:
            rendered = str(binding.get(field, ""))
            upper_rendered = rendered.upper()
            if (
                not rendered
                or "UNKNOWN" in upper_rendered
                or "UNRESOLVED" in upper_rendered
            ):
                add(
                    "FULL_CONVERGENCE_IDENTITY_UNKNOWN_VALUE",
                    "identity binding retains an unknown or unresolved value",
                    fingerprint=fingerprint,
                    field=field,
                )
        duplicate_target = str(
            binding.get("duplicate_of_failure_fingerprint", "")
        )
        duplicate_digest = str(binding.get("duplicate_identity_sha256", ""))
        duplicate_reason = str(binding.get("duplicate_reason", ""))
        if disposition == "HISTORICAL_DUPLICATE_OBSERVATION":
            if (
                re.fullmatch(r"V2F-[0-9a-f]{64}", duplicate_target) is None
                or not _is_sha256(duplicate_digest)
                or duplicate_reason
                != "SAME_RULE_AND_SUBJECT_DISTINCT_TRANSITION_OBSERVATION"
            ):
                add(
                    "FULL_CONVERGENCE_IDENTITY_DUPLICATE_EVIDENCE_INVALID",
                    "duplicate disposition lacks exact target evidence",
                    fingerprint=fingerprint,
                )
        elif duplicate_target or duplicate_digest or duplicate_reason:
            add(
                "FULL_CONVERGENCE_IDENTITY_DUPLICATE_EVIDENCE_UNEXPECTED",
                "non-duplicate disposition carries duplicate evidence",
                fingerprint=fingerprint,
            )
        state = {
            field: str(binding.get(field, ""))
            for field in FULL_CONVERGENCE_IDENTITY_STATE_FIELDS
            if field != "domain_id"
        }
        allowed_signatures = _full_convergence_identity_allowed_state_signatures(
            disposition,
            binding,
        )
        if not allowed_signatures or state not in allowed_signatures:
            add(
                "FULL_CONVERGENCE_IDENTITY_DISPOSITION_STATE_MATRIX_INVALID",
                "identity disposition conflicts with the closed state matrix",
                fingerprint=fingerprint,
            )
        if disposition == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED" and (
            not binding.get("current_path")
            or binding.get("current_blob_sha256") == "MISSING"
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_ACTIVE_LINEAGE_SEMANTICS_INVALID",
                "active lineage has no current path or blob",
                fingerprint=fingerprint,
            )
        if disposition in {
            "HISTORICAL_SUPERSEDED_NONREACHABLE",
            "HISTORICAL_DYNAMIC_REFERENCE_SUPERSEDED",
        } and (
            not isinstance(binding.get("superseded_by"), list)
            or not binding.get("superseded_by")
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_SUPERSESSION_SEMANTICS_INVALID",
                "superseded identity has no exact successor set",
                fingerprint=fingerprint,
            )
        for field in ("source_commit", "first_seen_commit", "last_seen_commit"):
            if not _is_commit(binding.get(field)):
                add(
                    "FULL_CONVERGENCE_IDENTITY_COMMIT_INVALID",
                    "identity binding commit is not exact",
                    fingerprint=fingerprint,
                    field=field,
                )
        for field in ("historical_blob_sha256", "current_blob_sha256"):
            value = binding.get(field)
            if value != "MISSING" and not _is_sha256(value):
                add(
                    "FULL_CONVERGENCE_IDENTITY_BLOB_INVALID",
                    "identity binding blob is neither MISSING nor SHA-256",
                    fingerprint=fingerprint,
                    field=field,
                )
        for field in ("historical_path", "current_path"):
            value = str(binding.get(field, ""))
            if value and (
                _normalize_path(value) != value
                or value.startswith(("/", "../"))
                or value.endswith("/")
                or "/../" in value
                or any(char in value for char in "*?[]")
            ):
                add(
                    "FULL_CONVERGENCE_IDENTITY_PATH_INVALID",
                    "identity binding path is not one exact repository path",
                    fingerprint=fingerprint,
                    field=field,
                )
        projection = binding.get("subject_projection")
        if (
            not isinstance(projection, dict)
            or binding.get("subject_projection_sha256")
            != _sha_bytes(_canonical(projection if isinstance(projection, dict) else {}))
        ):
            add(
                "FULL_CONVERGENCE_IDENTITY_PROJECTION_HASH_INVALID",
                "identity projection does not match its canonical digest",
                fingerprint=fingerprint,
            )
        if binding.get("invalidation_policy") != touch:
            add(
                "FULL_CONVERGENCE_IDENTITY_INVALIDATION_POLICY_MISMATCH",
                "identity invalidation policy differs from its record",
                fingerprint=fingerprint,
            )
    grouping_values = {
        (
            str(binding.get("historical_production_reachability", "")),
            str(binding.get("current_production_reachability", "")),
            str(binding.get("recommended_disposition", "")),
        )
        for binding in bindings.values()
        if isinstance(binding, dict)
    }
    if len(grouping_values) > 1:
        add(
            "FULL_CONVERGENCE_RECORD_IDENTITY_GROUPING_MISMATCH",
            "one correction record mixes disposition or reachability classes",
        )
    expected_sets = {
        "paths": sorted({
            _normalize_path(str(binding.get(field, "")))
            for binding in bindings.values()
            if isinstance(binding, dict)
            for field in ("historical_path", "current_path")
            if binding.get(field)
        }),
        "component_ids": sorted({
            str(binding.get(field, ""))
            for binding in bindings.values()
            if isinstance(binding, dict)
            for field in ("historical_component_id", "current_component_id")
            if binding.get(field)
        }),
        "domain_ids": sorted({
            str(binding.get("domain_id", ""))
            for binding in bindings.values()
            if isinstance(binding, dict) and binding.get("domain_id")
        }),
        "owner_ids": sorted({
            str(binding.get(field, ""))
            for binding in bindings.values()
            if isinstance(binding, dict)
            for field in ("historical_owner_id", "current_owner_id")
            if binding.get(field)
        }),
        "supersession_ids": sorted({
            str(value)
            for binding in bindings.values()
            if isinstance(binding, dict)
            for value in (
                binding.get("authority_selectors", {}).get("supersession_ids", [])
                if isinstance(binding.get("authority_selectors"), dict)
                else []
            )
        }),
        "retirement_ids": sorted({
            str(value)
            for binding in bindings.values()
            if isinstance(binding, dict)
            for value in (
                binding.get("authority_selectors", {}).get("retirement_ids", [])
                if isinstance(binding.get("authority_selectors"), dict)
                else []
            )
        }),
        "source_commit_set": sorted({
            str(binding.get("source_commit", ""))
            for binding in bindings.values()
            if isinstance(binding, dict) and binding.get("source_commit")
        }),
    }
    digest_fields = {
        "paths": "path_set_sha256",
        "component_ids": "component_set_sha256",
        "domain_ids": "domain_set_sha256",
        "owner_ids": "owner_set_sha256",
        "supersession_ids": "supersession_set_sha256",
        "retirement_ids": "retirement_set_sha256",
        "source_commit_set": "source_commit_set_sha256",
    }
    for field, expected in expected_sets.items():
        if (
            record.get(field) != expected
            or record.get(digest_fields[field]) != _line_set_sha(expected)
        ):
            add(
                "FULL_CONVERGENCE_RECORD_AGGREGATE_SET_INVALID",
                "record aggregate set or digest differs from its identity bindings",
                field=field,
            )
    source_hashes = record.get("authority_source_sha256")
    if (
        not isinstance(source_hashes, dict)
        or set(source_hashes) != set(FULL_CONVERGENCE_AUTHORITY_SOURCE_PATHS)
        or any(not _is_sha256(value) for value in source_hashes.values())
    ):
        add(
            "FULL_CONVERGENCE_RECORD_AUTHORITY_SOURCE_SET_INVALID",
            "record authority source digest set is not exact",
        )
    elif root is not None and _is_commit(record.get("binding_head_sha")):
        binding_head = str(record.get("binding_head_sha"))
        for relative in FULL_CONVERGENCE_AUTHORITY_SOURCE_PATHS:
            payload = _git_bytes(root, binding_head, relative)
            expected = _sha_bytes(payload) if payload is not None else ""
            if source_hashes.get(relative) != expected:
                add(
                    "FULL_CONVERGENCE_RECORD_AUTHORITY_SOURCE_HASH_MISMATCH",
                    "record authority source digest differs from its binding Head",
                    authority_source_path=relative,
                )
    for field in (*BATCH_ARTIFACT_SPECS, "descendant_history_supplement_sha256"):
        if not _is_sha256(record.get(field)):
            add(
                "FULL_CONVERGENCE_RECORD_EVIDENCE_DIGEST_INVALID",
                "record evidence digest is not SHA-256",
                field=field,
            )
    if not re.fullmatch(r"batch-[0-9]{3}", str(record.get("batch_id", ""))):
        add(
            "FULL_CONVERGENCE_RECORD_BATCH_ID_INVALID",
            "record batch id is not exact",
        )
    for field in ("correction_id", "correction_reason", "creator"):
        value = str(record.get(field, ""))
        if not value or any(char in value for char in "*?[]"):
            add(
                "FULL_CONVERGENCE_RECORD_METADATA_INVALID",
                "record identity metadata is empty or contains selector syntax",
                field=field,
            )
    if re.fullmatch(
        r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",
        str(record.get("created_at", "")),
    ) is None:
        add(
            "FULL_CONVERGENCE_RECORD_CREATED_AT_INVALID",
            "record creation time is not one exact UTC timestamp",
        )
    backlog_values = record.get("backlog_item_ids")
    backlog = (
        [str(value) for value in backlog_values]
        if isinstance(backlog_values, list)
        else []
    )
    if (
        not backlog
        or backlog != sorted(backlog)
        or len(backlog) != len(set(backlog))
        or any(not value or any(char in value for char in "*?[]") for value in backlog)
    ):
        add(
            "FULL_CONVERGENCE_RECORD_BACKLOG_ITEM_IDS_INVALID",
            "record backlog ids are not one nonempty exact sorted set",
        )
    negative_values = record.get("negative_examples")
    negatives = (
        {str(value) for value in negative_values}
        if isinstance(negative_values, list)
        else set()
    )
    if not {"CURRENT_DELTA_FAILURE", "WILDCARD"}.issubset(negatives):
        add(
            "FULL_CONVERGENCE_RECORD_NEGATIVE_EXAMPLES_INVALID",
            "record does not bind both current-failure and wildcard negatives",
        )
    if record.get("record_payload_sha256") != _sha_bytes(
        _canonical(_record_payload(record))
    ):
        add(
            "FULL_CONVERGENCE_RECORD_PAYLOAD_HASH_MISMATCH",
            "record payload digest does not bind its canonical content",
        )
    return findings


def _manifest_record_findings(
    root: Path,
    manifest: dict[str, Any],
    *,
    evaluated_head: str,
    baseline_identities: dict[str, dict[str, str]],
) -> tuple[list[dict[str, Any]], set[str], set[str], int]:
    """Revalidate the exact records named by one manifest.

    This is intentionally used for every predecessor as well as the current
    manifest.  Merely re-reading predecessor manifest bindings is not enough:
    their record bytes, payloads, chain, fingerprints, frozen raw identities,
    blobs, and projections must still be valid at the evaluated Head.
    """

    findings: list[dict[str, Any]] = []
    seen: set[str] = set()
    correction_ids: set[str] = set()
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or not bindings:
        findings.append(_finding(
            "FULL_CONVERGENCE_RECORD_BINDINGS_MISSING",
            "P0",
            "the batch does not enumerate an explicit record set",
            batch_id=manifest.get("batch_id"),
        ))
        return findings, seen, correction_ids, 0
    expected_previous = str(manifest.get("record_chain_start_sha256", ""))
    for index, binding in enumerate(bindings):
        if (
            not isinstance(binding, dict)
            or set(binding) != FULL_CONVERGENCE_RECORD_BINDING_FIELDS
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_INVALID",
                "P0",
                "record binding is not one exact closed-contract object",
                batch_id=manifest.get("batch_id"),
                index=index,
            ))
            continue
        relative = _normalize_path(str(binding.get("path", "")))
        expected_prefix = (
            FULL_CONVERGENCE_RECORD_ROOT
            + str(manifest.get("batch_id", ""))
            + "/"
        )
        if (
            not relative.startswith(expected_prefix)
            or any(char in relative for char in "*?[]")
            or relative.endswith("/")
            or relative.startswith("/")
            or "/../" in relative
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PATH_NOT_EXACT",
                "P0",
                "record path is outside its exact batch root or contains selector syntax",
                path=relative,
                index=index,
            ))
            continue
        if binding.get("previous_correction_chain_sha256") != expected_previous:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CHAIN_BREAK",
                "P0",
                "manifest record predecessor does not match the prior payload",
                path=relative,
            ))
        path = root / relative
        if not path.is_file() or _sha_file(path) != binding.get("record_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BYTE_DRIFT",
                "P0",
                "record bytes do not match the explicit binding",
                path=relative,
            ))
            continue
        try:
            record = _json(path)
        except (OSError, ValueError):
            record = None
        if not isinstance(record, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_UNREADABLE",
                "P0",
                "record is not one strict JSON object",
                path=relative,
            ))
            continue
        findings.extend(_full_convergence_record_contract_findings(
            record,
            path=relative,
            root=root,
        ))
        for field, expected in (
            ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
            ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
            ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
            ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
            ("batch_id", manifest.get("batch_id")),
            ("binding_head_sha", manifest.get("binding_head_sha")),
            ("binding_tree_sha", manifest.get("binding_tree_sha")),
        ):
            if record.get(field) != expected:
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_AUTHORITY_MISMATCH",
                    "P0",
                    "record authority or batch binding differs from its manifest",
                    path=relative,
                    field=field,
                    expected=expected,
                    actual=record.get(field),
                ))
        for hash_field in BATCH_ARTIFACT_SPECS:
            if record.get(hash_field) != manifest.get(hash_field):
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_ARTIFACT_BINDING_MISMATCH",
                    "P0",
                    "record evidence digest differs from its manifest",
                    path=relative,
                    field=hash_field,
                ))
        if (
            record.get("descendant_history_supplement_sha256")
            != manifest.get("descendant_history_supplement_sha256")
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_DESCENDANT_SUPPLEMENT_BINDING_MISMATCH",
                "P0",
                "record descendant-history seal differs from its manifest",
                path=relative,
            ))
        expected_payload_sha = _sha_bytes(_canonical(_record_payload(record)))
        if record.get("record_payload_sha256") != expected_payload_sha:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PAYLOAD_HASH_MISMATCH",
                "P0",
                "record payload digest does not bind its canonical content",
                path=relative,
            ))
        if record.get("record_payload_sha256") != binding.get("record_payload_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PAYLOAD_BINDING_MISMATCH",
                "P0",
                "record payload digest differs from the manifest binding",
                path=relative,
            ))
        if record.get("previous_correction_chain_sha256") != expected_previous:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PREDECESSOR_BINDING_MISMATCH",
                "P0",
                "actual record predecessor does not continue the manifest chain",
                path=relative,
            ))
        if record.get("correction_id") != binding.get("correction_id"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_ID_BINDING_MISMATCH",
                "P0",
                "record correction id differs from the manifest binding",
                path=relative,
            ))
        correction_id = str(record.get("correction_id", ""))
        if correction_id in correction_ids:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CORRECTION_ID_REUSE",
                "P0",
                "one manifest repeats a correction id",
                path=relative,
                correction_id=correction_id,
            ))
        correction_ids.add(correction_id)
        if not _is_exact_future_failure_policy(
            record.get("future_failure_policy")
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FUTURE_AUTO_CORRECTION_ENABLED",
                "P0",
                "record future-failure policy is not exact and fail-closed",
                path=relative,
            ))
        rules = record.get("rule_ids")
        rendered_rules = [str(value) for value in rules] if isinstance(rules, list) else []
        if len(rendered_rules) != 1 or not rendered_rules[0].startswith(HISTORY_PREFIX):
            findings.append(_finding(
                "FULL_CONVERGENCE_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a new record is not restricted to one historical rule",
                path=relative,
            ))
        binding_fingerprints = [
            str(value) for value in binding.get("failure_fingerprints", [])
        ] if isinstance(binding.get("failure_fingerprints"), list) else []
        record_fingerprints = [
            str(value) for value in record.get("failure_fingerprints", [])
        ] if isinstance(record.get("failure_fingerprints"), list) else []
        if record_fingerprints != binding_fingerprints:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FINGERPRINT_BINDING_MISMATCH",
                "P0",
                "actual record fingerprints differ from the manifest binding",
                path=relative,
            ))
        subjects = record.get("identity_binding_by_failure")
        if not isinstance(subjects, dict) or set(subjects) != set(record_fingerprints):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_IDENTITY_BINDING_SET_MISMATCH",
                "P0",
                "record must bind one exact identity projection per fingerprint",
                path=relative,
            ))
            subjects = subjects if isinstance(subjects, dict) else {}
        binding_head = str(record.get("binding_head_sha", ""))
        changed_paths = {
            _normalize_path(value)
            for value in _git(
                root,
                "diff",
                "--name-only",
                binding_head,
                evaluated_head,
            ).splitlines()
            if value.strip()
        } if _is_commit(binding_head) and _is_commit(evaluated_head) else set()
        for fingerprint in record_fingerprints:
            if fingerprint in seen:
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_FINGERPRINT_DUPLICATE",
                    "P0",
                    "one manifest repeats a record fingerprint",
                    path=relative,
                    fingerprint=fingerprint,
                ))
            seen.add(fingerprint)
            subject = subjects.get(fingerprint)
            if not isinstance(subject, dict):
                continue
            findings.extend(_raw_identity_findings(
                root,
                fingerprint=fingerprint,
                subject=subject,
                identity=baseline_identities.get(fingerprint),
                record_rule_ids=rendered_rules,
                path=relative,
            ))
            findings.extend(_duplicate_observation_findings(
                fingerprint,
                subject,
                baseline_identities,
                path=relative,
            ))
            selector = subject.get("authority_selectors")
            projection = subject.get("subject_projection")
            if (
                not isinstance(projection, dict)
                or subject.get("subject_projection_sha256") != _sha_bytes(_canonical(projection))
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_SUBJECT_PROJECTION_HASH_MISMATCH",
                    "P0",
                    "subject projection is not bound by its canonical digest",
                    path=relative,
                    fingerprint=fingerprint,
                ))
                continue
            if not _selector_is_exact(selector):
                findings.append(_finding(
                    "FULL_CONVERGENCE_SUBJECT_SELECTOR_NOT_EXACT",
                    "P0",
                    "subject projection lacks an exact wildcard-free selector",
                    path=relative,
                    fingerprint=fingerprint,
                ))
                continue
            source_commit = str(subject.get("source_commit", ""))
            historical_path = _normalize_path(str(subject.get("historical_path", "")))
            current_path = _normalize_path(str(subject.get("current_path", "")))
            touched_paths = sorted(
                {value for value in (historical_path, current_path) if value}
                & changed_paths
            )
            if touched_paths:
                findings.append(_finding(
                    "FULL_CONVERGENCE_TOUCHED_CORRECTION_INVALID",
                    "P0",
                    "a bound historical or current path changed after correction binding",
                    path=relative,
                    fingerprint=fingerprint,
                    touched_paths=touched_paths,
                ))
            if historical_path and _is_commit(source_commit):
                historical_bytes = _git_bytes(root, source_commit, historical_path)
                historical_sha = _sha_bytes(historical_bytes) if historical_bytes is not None else "MISSING"
                if historical_sha != subject.get("historical_blob_sha256"):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_HISTORICAL_BLOB_BINDING_MISMATCH",
                        "P0",
                        "historical blob differs from the exact source commit",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
            if current_path:
                binding_bytes = _git_bytes(root, binding_head, current_path)
                evaluated_bytes = _git_bytes(root, evaluated_head, current_path)
                binding_sha = _sha_bytes(binding_bytes) if binding_bytes is not None else "MISSING"
                evaluated_sha = _sha_bytes(evaluated_bytes) if evaluated_bytes is not None else "MISSING"
                if binding_sha != subject.get("current_blob_sha256"):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_CURRENT_BLOB_BINDING_MISMATCH",
                        "P0",
                        "current blob differs from the record binding Head",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                if evaluated_sha != subject.get("current_blob_sha256"):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_CURRENT_BLOB_CHANGED",
                        "P0",
                        "current blob changed after correction binding",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
            binding_projection = _subject_projection(root, binding_head, selector)
            current_projection = _subject_projection(root, evaluated_head, selector)
            if binding_projection != projection:
                findings.append(_finding(
                    "FULL_CONVERGENCE_SUBJECT_BINDING_MISMATCH",
                    "P0",
                    "subject projection differs from its binding Head",
                    path=relative,
                    fingerprint=fingerprint,
                ))
            if isinstance(binding_projection, dict):
                findings.extend(_dynamic_projection_repo_findings(
                    root,
                    binding_head,
                    binding_projection,
                    source_commit=source_commit,
                    path=relative,
                    fingerprint=fingerprint,
                ))
            if current_projection != projection:
                findings.append(_finding(
                    "FULL_CONVERGENCE_SUBJECT_PROJECTION_CHANGED",
                    "P0",
                    "subject projection changed at the evaluated Head",
                    path=relative,
                    fingerprint=fingerprint,
                ))
            if isinstance(current_projection, dict):
                findings.extend(_dynamic_projection_repo_findings(
                    root,
                    evaluated_head,
                    current_projection,
                    source_commit=source_commit,
                    path=relative,
                    fingerprint=fingerprint,
                ))
        expected_previous = str(record.get("record_payload_sha256", ""))
    if expected_previous != manifest.get("record_chain_terminal_sha256"):
        findings.append(_finding(
            "FULL_CONVERGENCE_CHAIN_TERMINAL_MISMATCH",
            "P0",
            "batch terminal does not equal the final actual record payload",
            batch_id=manifest.get("batch_id"),
        ))
    manifest_fingerprints = {
        str(value) for value in manifest.get("failure_fingerprints", [])
    }
    if seen != manifest_fingerprints:
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_COVERAGE_MISMATCH",
            "P0",
            "actual records do not cover each manifest fingerprint exactly once",
            batch_id=manifest.get("batch_id"),
        ))
    return findings, seen, correction_ids, len(bindings)


def _derive_prior_manifest_path(
    current_path: Path,
    current_batch_id: str,
    prior_batch_id: str,
) -> Path | None:
    if current_path.parent.name == current_batch_id:
        # Keep canonical batch-NNN/batch-NNN-manifest.json names aligned with
        # the derived prior sequence. This is an explicit path transform,
        # not directory discovery.
        filename = current_path.name
        if current_batch_id in filename:
            filename = filename.replace(current_batch_id, prior_batch_id, 1)
        return current_path.parent.parent / prior_batch_id / filename
    if current_batch_id in current_path.name:
        return current_path.with_name(current_path.name.replace(current_batch_id, prior_batch_id, 1))
    return None


def _manifest_contract_findings(
    root: Path,
    manifest_path: Path,
    manifest: dict[str, Any],
    *,
    evaluated_head: str,
    baseline_identities: dict[str, dict[str, str]],
    descendant_supplement_sha: str,
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    if set(manifest) != FULL_CONVERGENCE_BATCH_MANIFEST_FIELDS:
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_MANIFEST_FIELD_SET_INVALID",
            "P0",
            "batch manifest fields differ from the exact closed contract",
            manifest_path=str(manifest_path),
        ))
    if (
        manifest.get("schema_version")
        != FULL_CONVERGENCE_BATCH_MANIFEST_SCHEMA_VERSION
    ):
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_MANIFEST_SCHEMA_VERSION_INVALID",
            "P0",
            "batch manifest schema version differs from the authorized epoch",
            manifest_path=str(manifest_path),
        ))
    fingerprints = [
        str(value) for value in manifest.get("failure_fingerprints", [])
    ] if isinstance(manifest.get("failure_fingerprints"), list) else []
    if (
        fingerprints != sorted(fingerprints)
        or len(fingerprints) != len(set(fingerprints))
        or any(re.fullmatch(r"V2F-[0-9a-f]{64}", value) is None for value in fingerprints)
    ):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_SET_INVALID",
            "P0",
            "manifest fingerprints must be unique sorted exact V2 identities",
            manifest_path=str(manifest_path),
        ))
    if not _is_exact_int_equal(
        manifest.get("failure_count"), len(fingerprints)
    ):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_COUNT_MISMATCH",
            "P0",
            "manifest failure_count differs from its explicit fingerprint list",
            manifest_path=str(manifest_path),
        ))
    if manifest.get("failure_fingerprint_set_sha256") != _line_set_sha(fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_HASH_MISMATCH",
            "P0",
            "manifest fingerprint set digest is not canonical",
            manifest_path=str(manifest_path),
        ))
    if not 1 <= len(fingerprints) <= 50:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BATCH_SIZE_INVALID",
            "P0",
            "a batch must contain between one and fifty exact fingerprints",
            manifest_path=str(manifest_path),
        ))
    if len(fingerprints) < 25 and manifest.get("terminal_remainder_batch") is not True:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_NONTERMINAL_BELOW_TARGET",
            "P0",
            "a nonterminal batch cannot contain fewer than twenty-five fingerprints",
            manifest_path=str(manifest_path),
        ))
    for field, expected in (
        ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
        ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
        ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
        ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
        ("batch_review_a_status", "GO"),
        ("batch_review_b_status", "GO"),
        ("identity_coverage_percent", 100),
        ("batch_unknown_count", 0),
        ("batch_wildcard_count", 0),
        ("batch_size_target", "25_TO_50_FAILURE_FINGERPRINTS"),
        ("current_failure_false_accept_count", 0),
    ):
        if not _matches_exact_scalar_contract(manifest.get(field), expected):
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_AUTHORITY_MISMATCH",
                "P0",
                "batch authority or review assertion differs from the closed contract",
                manifest_path=str(manifest_path),
                field=field,
                expected=expected,
                actual=manifest.get(field),
            ))
    batch_match = re.fullmatch(
        r"batch-([0-9]{3})",
        str(manifest.get("batch_id", "")),
    )
    if batch_match is None:
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_ID_INVALID",
            "P0",
            "batch id is not the exact batch-NNN form",
            manifest_path=str(manifest_path),
        ))
    else:
        previous_append = manifest.get("previous_batch_append_sha256")
        batch_number = int(batch_match.group(1))
        if batch_number == 1 and previous_append != "":
            findings.append(_finding(
                "FULL_CONVERGENCE_INITIAL_BATCH_PREVIOUS_APPEND_INVALID",
                "P0",
                "batch-001 cannot claim a predecessor batch append",
                manifest_path=str(manifest_path),
            ))
        if batch_number > 1 and not _is_sha256(previous_append):
            findings.append(_finding(
                "FULL_CONVERGENCE_NONINITIAL_PREVIOUS_APPEND_REQUIRED",
                "P0",
                "every non-initial batch requires one exact predecessor digest",
                manifest_path=str(manifest_path),
            ))
    if not isinstance(manifest.get("terminal_remainder_batch"), bool):
        findings.append(_finding(
            "FULL_CONVERGENCE_TERMINAL_REMAINDER_FLAG_INVALID",
            "P0",
            "terminal remainder flag is not a strict boolean",
            manifest_path=str(manifest_path),
        ))
    binding_head = str(manifest.get("binding_head_sha", ""))
    binding_tree = _git(root, "rev-parse", f"{binding_head}^{{tree}}")
    if not _is_commit(binding_head) or not binding_tree:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BINDING_HEAD_UNRESOLVED",
            "P0",
            "manifest binding Head is not a resolvable commit",
            manifest_path=str(manifest_path),
        ))
    else:
        if manifest.get("binding_tree_sha") != binding_tree:
            findings.append(_finding(
                "FULL_CONVERGENCE_MANIFEST_BINDING_TREE_MISMATCH",
                "P0",
                "manifest binding tree differs from its exact Git Head",
                manifest_path=str(manifest_path),
            ))
        if not _is_ancestor(root, FULL_CONVERGENCE_BASE_HEAD, binding_head):
            findings.append(_finding(
                "FULL_CONVERGENCE_MANIFEST_BINDING_HEAD_NOT_AUTHORIZED_DESCENDANT",
                "P0",
                "manifest binding Head is not a descendant of d701",
                manifest_path=str(manifest_path),
            ))
        if not _is_ancestor(root, binding_head, evaluated_head):
            findings.append(_finding(
                "FULL_CONVERGENCE_MANIFEST_EVALUATED_HEAD_NOT_DESCENDANT",
                "P0",
                "evaluated Head does not descend from the manifest binding Head",
                manifest_path=str(manifest_path),
            ))
    bindings = manifest.get("record_bindings")
    chain = str(manifest.get("record_chain_start_sha256", ""))
    covered: list[str] = []
    if not isinstance(bindings, list) or not bindings:
        findings.append(_finding(
            "FULL_CONVERGENCE_RECORD_BINDINGS_MISSING",
            "P0",
            "the batch does not enumerate an explicit record set",
            manifest_path=str(manifest_path),
        ))
        bindings = []
    for index, binding in enumerate(bindings):
        if (
            not isinstance(binding, dict)
            or set(binding) != FULL_CONVERGENCE_RECORD_BINDING_FIELDS
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_INVALID",
                "P0",
                "record binding is not one exact closed-contract object",
                manifest_path=str(manifest_path),
                index=index,
            ))
            continue
        if binding.get("previous_correction_chain_sha256") != chain:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CHAIN_BREAK",
                "P0",
                "manifest record chain is discontinuous",
                manifest_path=str(manifest_path),
                index=index,
            ))
        payload_sha = binding.get("record_payload_sha256")
        if not _is_sha256(payload_sha) or not _is_sha256(binding.get("record_sha256")):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_HASH_INVALID",
                "P0",
                "manifest record binding lacks exact byte and payload hashes",
                manifest_path=str(manifest_path),
                index=index,
            ))
        chain = str(payload_sha)
        values = binding.get("failure_fingerprints")
        if isinstance(values, list):
            covered.extend(str(value) for value in values)
    if chain != manifest.get("record_chain_terminal_sha256"):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_CHAIN_TERMINAL_MISMATCH",
            "P0",
            "manifest terminal differs from its final record binding payload",
            manifest_path=str(manifest_path),
        ))
    if sorted(covered) != fingerprints or len(covered) != len(set(covered)):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_COVERAGE_MISMATCH",
            "P0",
            "manifest bindings do not cover each fingerprint exactly once",
            manifest_path=str(manifest_path),
        ))
    findings.extend(_batch_artifact_findings(
        manifest_path,
        manifest,
        baseline_identities,
    ))
    findings.extend(_classification_record_disposition_findings(
        root,
        manifest_path,
        manifest,
    ))
    if manifest.get("descendant_history_supplement_sha256") != descendant_supplement_sha:
        findings.append(_finding(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_MANIFEST_HASH_MISMATCH",
            "P0",
            "current manifest does not bind the exact explicit supplement bytes",
            manifest_path=str(manifest_path),
        ))
    return findings


def _predecessor_chain_findings(
    root: Path,
    current_manifest: dict[str, Any],
    immediate_path: Path | None,
    *,
    evaluated_head: str,
    baseline_identities: dict[str, dict[str, str]],
    descendant_supplement_sha: str,
) -> tuple[list[dict[str, Any]], list[tuple[Path, dict[str, Any]]]]:
    """Load the whole sequence-bound predecessor chain without discovery."""

    findings: list[dict[str, Any]] = []
    chain: list[tuple[Path, dict[str, Any]]] = []
    expected_sha = current_manifest.get("previous_batch_append_sha256")
    if not expected_sha:
        if immediate_path is not None:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_UNEXPECTED",
                "P0",
                "an initial batch supplied a predecessor path",
            ))
        return findings, chain
    if immediate_path is None:
        findings.append(_finding(
            "FULL_CONVERGENCE_PREVIOUS_MANIFEST_REQUIRED",
            "P0",
            "a non-initial batch did not supply its explicit immediate predecessor manifest",
        ))
        return findings, chain
    current = current_manifest
    path = immediate_path
    seen_fingerprints = {
        str(value) for value in current_manifest.get("failure_fingerprints", [])
    }
    for depth in range(1, 512):
        try:
            previous = _json(path)
        except (OSError, ValueError):
            previous = None
        if not isinstance(previous, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_UNREADABLE",
                "P0",
                "the sequence-bound predecessor is not one strict JSON object",
                manifest_path=str(path),
            ))
            break
        if _sha_file(path) != expected_sha:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_SHA_MISMATCH",
                "P0",
                "predecessor bytes do not match previous_batch_append_sha256",
                manifest_path=str(path),
            ))
        findings.extend(_manifest_contract_findings(
            root,
            path,
            previous,
            evaluated_head=evaluated_head,
            baseline_identities=baseline_identities,
            descendant_supplement_sha=descendant_supplement_sha,
        ))
        if current.get("record_chain_start_sha256") != previous.get("record_chain_terminal_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_TERMINAL_MISMATCH",
                "P0",
                "the current batch does not continue its predecessor record terminal",
                manifest_path=str(path),
            ))
        current_match = re.fullmatch(r"batch-([0-9]{3})", str(current.get("batch_id", "")))
        previous_match = re.fullmatch(r"batch-([0-9]{3})", str(previous.get("batch_id", "")))
        if (
            current_match is None
            or previous_match is None
            or int(current_match.group(1)) != int(previous_match.group(1)) + 1
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_SEQUENCE_MISMATCH",
                "P0",
                "batch ids are not an exact descending sequence",
                manifest_path=str(path),
            ))
        if previous.get("terminal_remainder_batch") is True:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_ALREADY_TERMINAL",
                "P0",
                "a batch follows a declared terminal remainder",
                manifest_path=str(path),
            ))
        previous_fingerprints = {
            str(value) for value in previous.get("failure_fingerprints", [])
        }
        for fingerprint in sorted(seen_fingerprints & previous_fingerprints):
            findings.append(_finding(
                "FULL_CONVERGENCE_PRIOR_MANIFEST_FINGERPRINT_REUSE",
                "P0",
                "a fingerprint is reused anywhere in the predecessor chain",
                fingerprint=fingerprint,
                manifest_path=str(path),
            ))
        seen_fingerprints.update(previous_fingerprints)
        chain.append((path, previous))
        prior_sha = previous.get("previous_batch_append_sha256")
        if not prior_sha:
            if previous.get("batch_id") != "batch-001":
                findings.append(_finding(
                    "FULL_CONVERGENCE_PREVIOUS_CHAIN_DID_NOT_REACH_BATCH_001",
                    "P0",
                    "predecessor chain ended before batch-001",
                    manifest_path=str(path),
                ))
            if previous.get("record_chain_start_sha256") != LEGACY_CHAIN_TERMINAL_SHA:
                findings.append(_finding(
                    "FULL_CONVERGENCE_LEGACY_CHAIN_NOT_CONTINUED",
                    "P0",
                    "batch-001 does not continue the frozen six-record terminal",
                    manifest_path=str(path),
                ))
            break
        previous_id = str(previous.get("batch_id", ""))
        if previous_match is None or int(previous_match.group(1)) <= 1:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_SEQUENCE_MISMATCH",
                "P0",
                "predecessor link underflows batch-001",
                manifest_path=str(path),
            ))
            break
        prior_id = f"batch-{int(previous_match.group(1)) - 1:03d}"
        prior_path = _derive_prior_manifest_path(path, previous_id, prior_id)
        if prior_path is None:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_PATH_NOT_SEQUENCE_BOUND",
                "P0",
                "older predecessor path cannot be derived from the explicit immediate path",
                manifest_path=str(path),
            ))
            break
        current = previous
        path = prior_path
        expected_sha = prior_sha
    else:
        findings.append(_finding(
            "FULL_CONVERGENCE_PREVIOUS_MANIFEST_CHAIN_DEPTH_EXCEEDED",
            "P0",
            "predecessor chain exceeded its frozen historical upper bound",
        ))
    return findings, chain


def _common_context(root: Path) -> dict[str, Any]:
    base = root / OUT_DIR
    baseline = base / "baseline_raw_failure_report.json"
    scanner = base / "baseline_scanner_file_manifest.json"
    v1 = base / "baseline_existing_corrections_manifest.json"
    raw_sha, raw_error = _sidecar(baseline)
    scanner_sha, scanner_error = _sidecar(scanner)
    v1_sha, v1_error = _sidecar(v1)
    return {
        "auditor_script_sha256": _sha_file(Path(__file__)),
        "evaluated_authorized_head_sha": AUTHORIZED_HEAD,
        "evaluated_authorized_tree_sha": _git(
            root, "rev-parse", f"{AUTHORIZED_HEAD}^{{tree}}"
        ),
        "authorization_id": AUTHORIZATION_ID,
        "authorized_head_sha": AUTHORIZED_HEAD,
        "baseline_report_sha256": raw_sha,
        "baseline_report_error": raw_error,
        "scanner_manifest_sha256": scanner_sha,
        "scanner_manifest_error": scanner_error,
        "existing_corrections_manifest_sha256": v1_sha,
        "existing_corrections_manifest_error": v1_error,
        "authorized_baseline_sha256_match": raw_sha == AUTHORIZED_BASELINE_SHA,
        "authorized_scanner_sha256_match": scanner_sha == AUTHORIZED_SCANNER_SHA,
        "authorized_v1_sha256_match": v1_sha == AUTHORIZED_V1_SHA,
    }


def audit_a(root: Path) -> dict[str, Any]:
    base = root / OUT_DIR
    findings: list[dict[str, Any]] = []
    context = _common_context(root)
    baseline = _json(base / "baseline_raw_failure_report.json")
    failure_inventory = _json(base / "exact_failure_inventory.json")
    scanner = _json(base / "baseline_scanner_file_manifest.json")
    records = []
    for path in _record_paths(root):
        try:
            records.append((path, _json(path)))
        except (OSError, ValueError):
            findings.append(_finding("CORRECTION_RECORD_UNREADABLE", "P0", "record is not valid JSON", path=str(path)))

    if not context["authorized_baseline_sha256_match"]:
        findings.append(_finding("BASELINE_HASH_NOT_AUTHORIZED", "P0", "frozen raw report hash differs from authorization", actual=context["baseline_report_sha256"], expected=AUTHORIZED_BASELINE_SHA))
    if not context["authorized_scanner_sha256_match"]:
        findings.append(_finding("SCANNER_MANIFEST_HASH_NOT_AUTHORIZED", "P0", "scanner manifest hash differs from authorization", actual=context["scanner_manifest_sha256"], expected=AUTHORIZED_SCANNER_SHA))
    if not context["authorized_v1_sha256_match"]:
        findings.append(_finding("V1_MANIFEST_HASH_NOT_AUTHORIZED", "P0", "V1 manifest hash differs from authorization", actual=context["existing_corrections_manifest_sha256"], expected=AUTHORIZED_V1_SHA))

    if any(
        not _is_exact_int_equal(scanner.get(field), 0)
        for field in (
            "scanner_rule_removal_count",
            "scanner_scope_reduction_count",
            "scanner_severity_downgrade_count",
            "scanner_history_depth_reduction_count",
        )
    ):
        findings.append(_finding("SCANNER_WEAKENING", "P0", "scanner manifest attests a weakening", scanner= scanner))
    listed_scanner = {str(row.get("path", "")) for row in scanner.get("files", []) if isinstance(row, dict)}
    if listed_scanner != SCANNER_PATHS:
        findings.append(_finding("SCANNER_CORE_FILE_SET_DRIFT", "P0", "scanner core file set differs from frozen allowlist", actual=sorted(listed_scanner), expected=sorted(SCANNER_PATHS)))

    inventory_path = base / "correction_record_inventory.json"
    try:
        inventory = _json(inventory_path)
    except (OSError, ValueError):
        inventory = {}
        findings.append(_finding("RECORD_INVENTORY_UNREADABLE", "P0", "record inventory is missing or invalid"))
    expected_paths = {str(row.get("path", "")).replace("\\", "/") for row in inventory.get("records", []) if isinstance(row, dict)}
    actual_paths = {path.relative_to(root).as_posix() for path, _ in records}
    if expected_paths != actual_paths:
        findings.append(_finding("RECORD_INVENTORY_SET_DRIFT", "P0", "record inventory does not exactly enumerate records", missing=sorted(expected_paths - actual_paths), extra=sorted(actual_paths - expected_paths)))
    all_fingerprints: list[str] = []
    previous_chain = ""
    for path, record in records:
        name = path.name
        fingerprints = record.get("failure_fingerprints", [])
        all_fingerprints.extend(str(x) for x in fingerprints if isinstance(x, str))
        if not isinstance(fingerprints, list) or not fingerprints:
            findings.append(_finding("EXPLICIT_FINGERPRINT_MISSING", "P0", "record has no explicit fingerprint list", path=name))
        if any(not isinstance(x, str) or not re.fullmatch(r"V2F-[0-9a-f]{64}", x) for x in fingerprints):
            findings.append(_finding("FINGERPRINT_FORMAT_INVALID", "P0", "record contains a non-exact V2 fingerprint", path=name))
        if record.get("previous_correction_chain_sha256", "") != previous_chain:
            findings.append(_finding("CORRECTION_CHAIN_BREAK", "P0", "record predecessor hash does not match prior record", path=name))
        previous_chain = str(record.get("record_payload_sha256", ""))
        if record.get("record_payload_sha256") != _sha_bytes(_canonical(_record_payload(record))):
            findings.append(_finding("RECORD_PAYLOAD_HASH_MISMATCH", "P0", "record payload hash is not immutable", path=name))
        for key in ("paths", "current_blob_sha256_by_path", "rule_ids", "failure_classes", "transition_class_id", "backlog_item_ids", "future_failure_policy", "touch_invalidation_policy", "revocation_policy", "raw_failures", "failure_bindings"):
            if key not in record:
                findings.append(_finding("RECORD_CONTRACT_FIELD_MISSING", "P0", "record lacks mandatory contract field", path=name, field=key))
        blob_map = record.get("current_blob_sha256_by_path")
        if not isinstance(blob_map, dict):
            findings.append(_finding("CURRENT_BLOB_BINDING_MISSING", "P0", "record has no current blob map", path=name))
        else:
            for key, value in blob_map.items():
                if value != "MISSING" and (not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value)):
                    findings.append(_finding("CURRENT_BLOB_BINDING_INVALID", "P0", "current blob binding is not SHA-256", path=name, subject=key, value=value))
        if record.get("future_failure_policy", {}).get("NEW_FAILURE_REQUIRES_NEW_RECORD") is not True:
            findings.append(_finding("FUTURE_AUTO_CORRECTION", "P0", "future failures could be auto-corrected", path=name))
        # Inspect only selector/class fields and use lexical tokens.  Concrete
        # paths such as ``global_supply_demand_*`` and prose/evidence are not
        # selectors and must not create a false P0.
        selector_values = []
        for key in ("scope", "path_scope", "component_scope", "domain_scope", "selector", "selectors", "pattern", "patterns", "match", "matches", "filter", "filters", "wildcard", "wildcards", "regex", "regular_expression", "rule_ids", "failure_classes", "transition_class_id"):
            value = record.get(key)
            selector_values.extend(value if isinstance(value, list) else [value])
        selector_text = " ".join(str(value).casefold() for value in selector_values)
        selector_tokens = set(re.findall(r"[a-z0-9_]+", selector_text))
        if any(token in selector_tokens for token in ("regex", "glob", "prefix", "directory", "legacy", "unknown", "unknown_accepted", "misc", "other")) or any(char in selector_text for char in ("*", "?", "[", "]")):
            findings.append(_finding("BROAD_CORRECTION_SELECTOR", "P0", "record contains a broad selector or waiver token", path=name))
        attestation = record.get("production_reachability_attestation", {})
        if any(
            not _is_exact_int_equal(attestation.get(key), 0)
            for key in (
                "active_owner_violation_count",
                "parallel_owner_count",
                "dual_write_count",
                "fallback_count",
            )
        ):
            findings.append(_finding("ACTIVE_OWNER_CORRECTION", "P0", "record attests an active owner, parallel owner, dual-write or fallback", path=name, attestation=attestation))
    duplicates = len(all_fingerprints) - len(set(all_fingerprints))
    if duplicates:
        findings.append(_finding("DUPLICATE_CORRECTION_FINGERPRINT", "P0", "same failure fingerprint is corrected more than once", duplicate_count=duplicates))
    historical = {str(x) for x in baseline.get("failures", []) if str(x).startswith(HISTORY_PREFIX)}
    current = {str(x) for x in baseline.get("failures", []) if not str(x).startswith(HISTORY_PREFIX)}
    current_fingerprints = {
        str(row.get("failure_fingerprint", ""))
        for row in failure_inventory.get("rows", [])
        if isinstance(row, dict) and not str(row.get("rule_id", "")).startswith(HISTORY_PREFIX)
    }
    corrected = set(all_fingerprints)
    inventory_by_fp = {
        str(row.get("failure_fingerprint", "")): row
        for row in failure_inventory.get("rows", [])
        if isinstance(row, dict)
    }
    v1_overlap = sorted(
        fingerprint
        for fingerprint in corrected
        if inventory_by_fp.get(fingerprint, {}).get("existing_correction_id")
    )
    if v1_overlap:
        findings.append(_finding("V1_V2_DUPLICATE_CORRECTION_AUTHORITY", "P0", "a V2 correction fingerprint is already owned by the read-only V1 authority", overlap=v1_overlap))
    if corrected & current_fingerprints:
        findings.append(_finding("CURRENT_FAILURE_CORRECTION_OVERLAP", "P0", "a current baseline failure fingerprint is corrected", overlap=sorted(corrected & current_fingerprints)))
    if not _is_exact_int_equal(
        inventory.get("corrected_failure_fingerprint_count"),
        len(all_fingerprints),
    ):
        findings.append(_finding("RECORD_INVENTORY_CARDINALITY_DRIFT", "P1", "record inventory fingerprint count is inaccurate", listed=inventory.get("corrected_failure_fingerprint_count"), actual=len(all_fingerprints)))
    return {
        "schema_version": "space_syndicate.v076.reuse_correction_v2.audit_a.v2",
        **context,
        "raw_failure_count": len(baseline.get("failures", [])),
        "raw_historical_failure_count": len(historical),
        "raw_current_delta_failure_count": len(current),
        "record_count": len(records),
        "corrected_fingerprint_count": len(all_fingerprints),
        "p0": [x for x in findings if x["severity"] == "P0"],
        "p1": [x for x in findings if x["severity"] == "P1"],
        "status": "GO" if not any(x["severity"] in {"P0", "P1"} for x in findings) else "NO_GO",
    }


def audit_b(root: Path) -> dict[str, Any]:
    base = root / OUT_DIR
    findings: list[dict[str, Any]] = []
    context = _common_context(root)
    baseline = _json(base / "baseline_raw_failure_report.json")
    inventory = _json(base / "exact_failure_inventory.json")
    rows = [row for row in inventory.get("rows", []) if isinstance(row, dict)]
    by_fp = {str(row.get("failure_fingerprint")): row for row in rows}
    by_raw = {str(row.get("raw_failure")): row for row in rows}
    registry_path, registry_id = _read_registry(root)
    tree_blobs = _tree_blob_map(root)
    records = []
    for path in _record_paths(root):
        try:
            records.append((path, _json(path)))
        except (OSError, ValueError):
            continue
    corrected: set[str] = set()
    for path, record in records:
        rule_ids = {str(x) for x in record.get("rule_ids", [])}
        classes = {str(x) for x in record.get("failure_classes", [])}
        for fingerprint in record.get("failure_fingerprints", []):
            fingerprint = str(fingerprint)
            corrected.add(fingerprint)
            row = by_fp.get(fingerprint)
            if row is None:
                findings.append(_finding("FINGERPRINT_NOT_IN_BASELINE", "P0", "correction fingerprint is absent from frozen inventory", path=path.name, fingerprint=fingerprint))
                continue
            eligibility = row.get("transition_eligibility")
            if not isinstance(eligibility, dict) or eligibility.get("eligible_for_correction") is not True:
                findings.append(_finding("TRANSITION_CLASS_NOT_ELIGIBLE", "P0", "record covers a row without independently verified historical transition eligibility", path=path.name, fingerprint=fingerprint, reasons=(eligibility or {}).get("ineligibility_reasons", [])))
            if not str(record.get("transition_class_id", "")):
                findings.append(_finding("TRANSITION_CLASS_MISSING", "P0", "record has no explicit transition class", path=path.name, fingerprint=fingerprint))
            if str(row.get("raw_failure")) not in by_raw:
                findings.append(_finding("RAW_FAILURE_IDENTITY_MISSING", "P0", "inventory row cannot be tied to raw failure", fingerprint=fingerprint))
            row_rule = str(row.get("rule_id", ""))
            if row_rule not in rule_ids or row_rule not in classes:
                findings.append(_finding("RULE_CLASS_MISMATCH", "P0", "record class does not match exact inventory row", path=path.name, fingerprint=fingerprint, row_rule=row_rule, record_rules=sorted(rule_ids), record_classes=sorted(classes)))
            if not row_rule.startswith(HISTORY_PREFIX):
                findings.append(_finding("CURRENT_DELTA_CORRECTION", "P0", "record covers a current-delta fingerprint", path=path.name, fingerprint=fingerprint, rule=row_rule))
            row_path = str(row.get("path", "")).replace("\\", "/")
            blob_map = record.get("current_blob_sha256_by_path", {})
            if row_path:
                expected = str(row.get("current_blob_sha256", ""))
                declared = blob_map.get(row_path) if isinstance(blob_map, dict) else None
                if declared != expected:
                    findings.append(_finding("CURRENT_BLOB_BINDING_MISMATCH", "P0", "record blob map differs from inventory", path=path.name, fingerprint=fingerprint, expected=expected, declared=declared))
                git_blob = tree_blobs.get(row_path)
                live_sha = _git_blob_sha256(root, git_blob) if git_blob else "MISSING"
                if live_sha != expected:
                    findings.append(_finding("CURRENT_BLOB_NOT_LIVE", "P0", "record blob binding does not match authorized tree", path=path.name, fingerprint=fingerprint, subject=row_path, expected=expected, actual=live_sha))
            else:
                findings.append(_finding("NO_CONCRETE_BLOB_SUBJECT", "P1", "corrected row has no concrete path and therefore no verifiable current blob binding", path=path.name, fingerprint=fingerprint, component_id=row.get("component_id", ""), domain_id=row.get("domain_id", "")))
            component_id = str(row.get("component_id", ""))
            subject = registry_path.get(row_path) if row_path else registry_id.get(component_id)
            if subject is None:
                findings.append(_finding("REACHABILITY_UNRESOLVED", "P1", "component/path is absent from authoritative registry; non-production reachability is unproven", path=path.name, fingerprint=fingerprint, subject=row_path or component_id))
            elif subject.get("production_reachable") is True and record.get("production_reachability_attestation", {}).get("states") == ["non_production_or_unresolved"]:
                findings.append(_finding("REACHABILITY_ATTESTATION_MISMATCH", "P0", "record says non-production/unresolved but registry says production reachable", path=path.name, fingerprint=fingerprint, subject=row_path or component_id))
    raw_values = {str(value) for value in baseline.get("failures", [])}
    if len(rows) != len(raw_values):
        findings.append(_finding("INVENTORY_COVERAGE_OR_DUPLICATE", "P0", "inventory does not cover each unique raw failure exactly once", raw_count=len(raw_values), inventory_count=len(rows)))
    if set(str(row.get("raw_failure")) for row in rows) != raw_values:
        findings.append(_finding("INVENTORY_RAW_SET_MISMATCH", "P0", "inventory raw failure set differs from frozen report"))
    current_rows = [row for row in rows if not str(row.get("rule_id", "")).startswith(HISTORY_PREFIX)]
    if not current_rows:
        findings.append(_finding("CURRENT_DELTA_NOT_RETAINED", "P0", "inventory has no independently classified current-delta failures"))
    historical_rows = [row for row in rows if str(row.get("rule_id", "")).startswith(HISTORY_PREFIX)]
    if len(corrected & {str(row.get("failure_fingerprint")) for row in current_rows}):
        findings.append(_finding("CURRENT_FINGERPRINT_CORRECTED", "P0", "at least one current-delta inventory fingerprint is corrected"))
    # Missing registry identities are retained as explicit P1 findings above;
    # this aggregate makes the audit decision easy to consume.
    unresolved_rows = [row for row in historical_rows if not ((str(row.get("path", "")) and str(row.get("path", "")).replace("\\", "/") in registry_path) or (str(row.get("component_id", "")) and str(row.get("component_id", "")) in registry_id))]
    unresolved = len(unresolved_rows)
    no_blob_rows = [row for row in historical_rows if not row.get("path")]
    no_blob = len(no_blob_rows)
    return {
        "schema_version": "space_syndicate.v076.reuse_correction_v2.audit_b.v2",
        **context,
        "raw_failure_count": len(raw_values),
        "raw_historical_failure_count": len(historical_rows),
        "raw_current_delta_failure_count": len(current_rows),
        "corrected_fingerprint_count": len(corrected),
        "registry_unresolved_historical_row_count": unresolved,
        "registry_unresolved_historical_fingerprints": sorted(str(row.get("failure_fingerprint", "")) for row in unresolved_rows),
        "historical_rows_without_concrete_path_count": no_blob,
        "historical_rows_without_concrete_path_fingerprints": sorted(str(row.get("failure_fingerprint", "")) for row in no_blob_rows),
        "p0": [x for x in findings if x["severity"] == "P0"],
        "p1": [x for x in findings if x["severity"] == "P1"],
        "status": "GO" if not any(x["severity"] in {"P0", "P1"} for x in findings) else "NO_GO",
    }


def _post_touch_sidecar_findings(
    root: Path,
    sidecar_path: Path | None,
    batch_manifest_path: Path,
    evaluated_head: str,
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]], dict[str, Any]]:
    """Validate the append-only sidecar and return trusted one-for-one map."""

    if sidecar_path is None:
        return [], {}, {"status": "NOT_PROVIDED", "record_count": 0, "path": ""}
    result = _post_touch.validate_manifest_and_records(
        root,
        sidecar_path,
        evaluated_head=evaluated_head,
        current_batch_manifest_path=batch_manifest_path,
        projection_loader=_subject_projection,
    )
    findings = [
        _finding(
            "FULL_CONVERGENCE_POST_TOUCH_REVALIDATION_INVALID",
            "P0",
            str(code),
            manifest_path=str(sidecar_path),
        )
        for code in result.get("failures", [])
    ]
    summary = {
        "status": result.get("status", "FAIL"),
        "record_count": result.get("record_count", 0),
        "trusted_fingerprint_count": len(result.get("trusted_by_fingerprint", {})),
        "path": str(sidecar_path),
        "failures": result.get("failures", []),
    }
    return findings, result.get("trusted_by_fingerprint", {}), summary


def _suppress_post_touch_findings(
    findings: list[dict[str, Any]],
    trusted: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    code_map = {
        "FULL_CONVERGENCE_CURRENT_BLOB_CHANGED": "BLOB_CHANGED_CORRECTION_INVALID",
        "FULL_CONVERGENCE_TOUCHED_CORRECTION_INVALID": "TOUCHED_CORRECTION_INVALID",
        "FULL_CONVERGENCE_SUBJECT_PROJECTION_CHANGED": "SUBJECT_PROJECTION_CHANGED_INVALID",
    }
    kept: list[dict[str, Any]] = []
    for finding in findings:
        code = str(finding.get("code", ""))
        fp = str(finding.get("evidence", {}).get("fingerprint", ""))
        finding_path = _normalize_path(
            str(finding.get("evidence", {}).get("path", ""))
        )
        mapped = code_map.get(code)
        if mapped and _post_touch.allows_invalidation(
            trusted,
            fingerprint=fp,
            invalidation_code=mapped,
            prior_record_path=finding_path,
        ):
            continue
        kept.append(finding)
    return kept


def audit_full_convergence_batch(
    root: Path,
    manifest_path: Path,
    *,
    evaluated_head: str,
    baseline_report_path: Path | None = None,
    previous_batch_manifest_path: Path | None = None,
    descendant_history_supplement_path: Path | None = None,
    descendant_history_raw_report_path: Path | None = None,
    descendant_history_scanner_path: Path | None = None,
    post_touch_revalidation_path: Path | None = None,
) -> dict[str, Any]:
    """Independently verify one explicit new-epoch batch and its legacy anchor.

    This intentionally duplicates the security-critical checks instead of
    importing the resolver extension.  Directory discovery is not authority:
    only record paths enumerated by ``manifest_path`` are evaluated.
    """
    findings: list[dict[str, Any]] = []
    baseline_fingerprints = {"historical": set(), "current": set()}
    baseline_identities: dict[str, dict[str, str]] = {}
    baseline_report: dict[str, Any] = {}
    if baseline_report_path is None:
        findings.append(_finding(
            "FULL_CONVERGENCE_BASELINE_REQUIRED",
            "P0",
            "the full-convergence batch audit requires the explicit authorized raw report",
        ))
    elif not baseline_report_path.is_file() or _sha_file(baseline_report_path) != FULL_CONVERGENCE_BASELINE_SHA:
        findings.append(_finding(
            "FULL_CONVERGENCE_BASELINE_DRIFT",
            "P0",
            "the d701 raw failure report differs from the authorized digest",
        ))
    else:
        try:
            baseline_report = _json(baseline_report_path)
        except (OSError, ValueError):
            baseline_report = {}
            findings.append(_finding(
                "FULL_CONVERGENCE_BASELINE_UNREADABLE",
                "P0",
                "the authorized raw failure report is not valid JSON",
            ))
        baseline_fingerprints = _authorized_failure_fingerprint_sets(baseline_report)
        baseline_identities = _authorized_failure_identity_by_fingerprint(
            baseline_report
        )
        if (
            len(baseline_fingerprints["historical"]) != 510
            or len(baseline_fingerprints["current"]) != 56
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_BASELINE_FINGERPRINT_SET_INVALID",
                "P0",
                "the frozen report does not derive the exact 510 historical and 56 current fingerprints",
            ))
    (
        supplement_findings,
        descendant_fingerprints,
        live_historical_identities,
        dispositioned_fingerprints,
        descendant_supplement_sha,
        descendant_report_head,
    ) = _descendant_history_supplement_findings(
        root,
        supplement_path=descendant_history_supplement_path,
        raw_report_path=descendant_history_raw_report_path,
        scanner_path=descendant_history_scanner_path,
        evaluated_head=evaluated_head,
        baseline_report=baseline_report,
        baseline_sets=baseline_fingerprints,
    )
    findings.extend(supplement_findings)
    # Correction authority is exactly the live historical Raw set.  The
    # independently verified non-live dispositions remain preserved evidence,
    # not correction candidates.
    baseline_fingerprints["historical"] = set(live_historical_identities)
    baseline_identities = {
        str(fingerprint): dict(identity)
        for fingerprint, identity in live_historical_identities.items()
    }
    schema_path = root / FULL_CONVERGENCE_SCHEMA
    schema_finding = _sealed_tree_blob_finding(
        root,
        schema_path,
        evaluated_head=evaluated_head,
        expected_sha=FULL_CONVERGENCE_SCHEMA_SHA,
        code="FULL_CONVERGENCE_SCHEMA_DRIFT",
        message="full-convergence schema committed blob or worktree content drifted",
    )
    if schema_finding is not None:
        findings.append(schema_finding)
    seal_path = root / LEGACY_SEAL_PATH
    if not seal_path.is_file() or _sha_file(seal_path) != LEGACY_SEAL_SHA:
        findings.append(_finding(
            "LEGACY_SEAL_BYTE_DRIFT",
            "P0",
            "the CI_PORTABILITY_V2 predecessor seal changed",
        ))
    legacy_fingerprints: set[str] = set()
    for relative, expected in LEGACY_RECORD_SHA_BY_PATH.items():
        path = root / relative
        if not path.is_file() or _sha_file(path) != expected:
            findings.append(_finding(
                "LEGACY_RECORD_BYTE_DRIFT",
                "P0",
                "one of the exact six legacy records changed",
                path=relative,
            ))
            continue
        try:
            legacy_record = _json(path)
        except (OSError, ValueError):
            findings.append(_finding(
                "LEGACY_RECORD_UNREADABLE",
                "P0",
                "one of the byte-locked legacy records is not valid JSON",
                path=relative,
            ))
            continue
        values = legacy_record.get("failure_fingerprints")
        if not isinstance(values, list):
            findings.append(_finding(
                "LEGACY_RECORD_FINGERPRINT_SET_INVALID",
                "P0",
                "one of the byte-locked legacy records lacks its fingerprint set",
                path=relative,
            ))
            continue
        for value in values:
            rendered = str(value)
            if rendered in legacy_fingerprints:
                findings.append(_finding(
                    "LEGACY_RECORD_FINGERPRINT_DUPLICATE",
                    "P0",
                    "legacy records contain a duplicate corrected fingerprint",
                    path=relative,
                    fingerprint=rendered,
                ))
            legacy_fingerprints.add(rendered)
    try:
        manifest = _json(manifest_path)
    except (OSError, ValueError):
        manifest = {}
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_MANIFEST_UNREADABLE",
            "P0",
            "the explicit batch manifest is missing or invalid JSON",
        ))
    if not isinstance(manifest, dict):
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_MANIFEST_NOT_OBJECT",
            "P0",
            "the explicit batch manifest must be a JSON object",
        ))
        manifest = {}
    post_touch_findings, post_touch_trusted, post_touch_summary = _post_touch_sidecar_findings(
        root,
        post_touch_revalidation_path,
        manifest_path,
        evaluated_head,
    )
    findings.extend(post_touch_findings)
    findings.extend(_manifest_contract_findings(
        root,
        manifest_path,
        manifest,
        evaluated_head=evaluated_head,
        baseline_identities=baseline_identities,
        descendant_supplement_sha=descendant_supplement_sha,
    ))
    manifest_fingerprints = [
        str(value) for value in manifest.get("failure_fingerprints", [])
    ]
    if (
        manifest_fingerprints != sorted(manifest_fingerprints)
        or len(manifest_fingerprints) != len(set(manifest_fingerprints))
        or any(not re.fullmatch(r"V2F-[0-9a-f]{64}", value) for value in manifest_fingerprints)
    ):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_SET_INVALID",
            "P0",
            "manifest fingerprints must be unique sorted exact V2 identities",
        ))
    if not _is_exact_int_equal(
        manifest.get("failure_count"), len(manifest_fingerprints)
    ):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_COUNT_MISMATCH",
            "P0",
            "manifest failure_count differs from its explicit fingerprint list",
        ))
    if manifest.get("failure_fingerprint_set_sha256") != _line_set_sha(manifest_fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_HASH_MISMATCH",
            "P0",
            "manifest fingerprint set digest is not canonical",
        ))
    if not 1 <= len(manifest_fingerprints) <= 50:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BATCH_SIZE_INVALID",
            "P0",
            "a batch must contain between one and fifty exact fingerprints",
        ))
    if len(manifest_fingerprints) < 25 and manifest.get("terminal_remainder_batch") is not True:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_NONTERMINAL_BELOW_TARGET",
            "P0",
            "a nonterminal batch cannot contain fewer than twenty-five fingerprints",
        ))
    manifest_binding_head = str(manifest.get("binding_head_sha", ""))
    manifest_binding_tree = _git(root, "rev-parse", f"{manifest_binding_head}^{{tree}}")
    if not re.fullmatch(r"[0-9a-f]{40}", manifest_binding_head) or not manifest_binding_tree:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BINDING_HEAD_UNRESOLVED",
            "P0",
            "manifest binding Head is not a resolvable commit",
        ))
    elif manifest.get("binding_tree_sha") != manifest_binding_tree:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BINDING_TREE_MISMATCH",
            "P0",
            "manifest binding tree differs from its exact Git Head",
        ))
    for field, expected in (
        ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
        ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
        ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
        ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
        ("batch_review_a_status", "GO"),
        ("batch_review_b_status", "GO"),
        ("identity_coverage_percent", 100),
        ("batch_unknown_count", 0),
        ("batch_wildcard_count", 0),
        ("current_failure_false_accept_count", 0),
    ):
        if not _matches_exact_scalar_contract(manifest.get(field), expected):
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_AUTHORITY_MISMATCH",
                "P0",
                "batch authority or review assertion differs from the closed contract",
                field=field,
                expected=expected,
                actual=manifest.get(field),
            ))
    findings.extend(_batch_artifact_findings(
        manifest_path,
        manifest,
        baseline_identities,
    ))
    chain_findings, predecessor_chain = _predecessor_chain_findings(
        root,
        manifest,
        previous_batch_manifest_path,
        evaluated_head=evaluated_head,
        baseline_identities=baseline_identities,
        descendant_supplement_sha=descendant_supplement_sha,
    )
    findings.extend(chain_findings)
    predecessor_fingerprints: set[str] = set()
    predecessor_correction_ids: set[str] = set()
    predecessor_record_count = 0
    for predecessor_path, predecessor_manifest in reversed(predecessor_chain):
        if (
            predecessor_manifest.get("descendant_history_supplement_sha256")
            != descendant_supplement_sha
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_MANIFEST_HASH_MISMATCH",
                "P0",
                "predecessor manifest does not bind the same explicit supplement bytes",
                manifest_path=str(predecessor_path),
            ))
        record_findings, record_fingerprints, correction_ids, record_count = (
            _manifest_record_findings(
                root,
                predecessor_manifest,
                evaluated_head=evaluated_head,
                baseline_identities=baseline_identities,
            )
        )
        findings.extend(record_findings)
        for fingerprint in sorted(record_fingerprints):
            if fingerprint in baseline_fingerprints["current"]:
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_CURRENT_FAILURE_CORRECTION",
                    "P0",
                    "a predecessor record fingerprint belongs to the frozen current set",
                    manifest_path=str(predecessor_path),
                    fingerprint=fingerprint,
                ))
            elif fingerprint not in baseline_fingerprints["historical"]:
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL",
                    "P0",
                    "a predecessor record fingerprint is absent from the frozen historical set",
                    manifest_path=str(predecessor_path),
                    fingerprint=fingerprint,
                ))
            if fingerprint in legacy_fingerprints:
                findings.append(_finding(
                    "FULL_CONVERGENCE_LEGACY_FINGERPRINT_REUSE",
                    "P0",
                    "a predecessor record repeats a frozen legacy correction fingerprint",
                    manifest_path=str(predecessor_path),
                    fingerprint=fingerprint,
                ))
        for fingerprint in sorted(predecessor_fingerprints & record_fingerprints):
            findings.append(_finding(
                "FULL_CONVERGENCE_PRIOR_RECORD_FINGERPRINT_REUSE",
                "P0",
                "actual predecessor records reuse a nonadjacent fingerprint",
                manifest_path=str(predecessor_path),
                fingerprint=fingerprint,
            ))
        predecessor_fingerprints.update(record_fingerprints)
        for correction_id in sorted(predecessor_correction_ids & correction_ids):
            findings.append(_finding(
                "FULL_CONVERGENCE_PRIOR_RECORD_CORRECTION_ID_REUSE",
                "P0",
                "actual predecessor records reuse a correction id",
                manifest_path=str(predecessor_path),
                correction_id=correction_id,
            ))
        predecessor_correction_ids.update(correction_ids)
        predecessor_record_count += record_count
    current_record_findings, _, _, _ = _manifest_record_findings(
        root,
        manifest,
        evaluated_head=evaluated_head,
        baseline_identities=baseline_identities,
    )
    findings.extend(current_record_findings)
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or not bindings:
        findings.append(_finding(
            "FULL_CONVERGENCE_RECORD_BINDINGS_MISSING",
            "P0",
            "the batch does not enumerate an explicit record set",
        ))
        bindings = []
    previous = str(manifest.get("record_chain_start_sha256", ""))
    if not manifest.get("previous_batch_append_sha256") and previous != LEGACY_CHAIN_TERMINAL_SHA:
        findings.append(_finding(
            "FULL_CONVERGENCE_LEGACY_CHAIN_NOT_CONTINUED",
            "P0",
            "the first full-convergence batch does not continue the six-record terminal",
            expected=LEGACY_CHAIN_TERMINAL_SHA,
            actual=previous,
        ))
    all_fingerprints: list[str] = []
    for index, binding in enumerate(bindings):
        if (
            not isinstance(binding, dict)
            or set(binding) != FULL_CONVERGENCE_RECORD_BINDING_FIELDS
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_INVALID",
                "P0",
                "record binding is not one exact closed-contract object",
                index=index,
            ))
            continue
        relative = str(binding.get("path", "")).replace("\\", "/")
        if (
            not relative.startswith(FULL_CONVERGENCE_RECORD_ROOT)
            or any(char in relative for char in "*?[]")
            or relative.endswith("/")
            or "/../" in relative
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PATH_NOT_EXACT",
                "P0",
                "record path is outside the explicit epoch root or contains selector syntax",
                path=relative,
            ))
            continue
        if binding.get("previous_correction_chain_sha256") != previous:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CHAIN_BREAK",
                "P0",
                "record predecessor does not match the prior payload",
                path=relative,
            ))
        previous = str(binding.get("record_payload_sha256", ""))
        path = root / relative
        if not path.is_file() or _sha_file(path) != binding.get("record_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BYTE_DRIFT",
                "P0",
                "record bytes do not match the explicit binding",
                path=relative,
            ))
            continue
        try:
            record = _json(path)
        except (OSError, ValueError):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_UNREADABLE",
                "P0",
                "record is not valid JSON",
                path=relative,
            ))
            continue
        if not isinstance(record, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_NOT_OBJECT",
                "P0",
                "a new record must be a JSON object",
                path=relative,
            ))
            continue
        findings.extend(_full_convergence_record_contract_findings(
            record,
            path=relative,
            root=root,
        ))
        if record.get("authorization_id") != FULL_CONVERGENCE_AUTHORIZATION_ID:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_AUTHORIZATION_MISMATCH",
                "P0",
                "a new record does not use the new epoch authorization",
                path=relative,
            ))
        if record.get("authorization_base_head_sha") != FULL_CONVERGENCE_BASE_HEAD:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BASE_HEAD_MISMATCH",
                "P0",
                "a new record is not rooted at d701",
                path=relative,
            ))
        if record.get("baseline_report_sha256") != FULL_CONVERGENCE_BASELINE_SHA:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BASELINE_MISMATCH",
                "P0",
                "a new record is not bound to the d701 raw report",
                path=relative,
            ))
        if record.get("binding_head_sha") != manifest.get("binding_head_sha"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_HEAD_MISMATCH",
                "P0",
                "record and batch manifest bind different Heads",
                path=relative,
            ))
        if record.get("binding_tree_sha") != manifest.get("binding_tree_sha"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_TREE_MISMATCH",
                "P0",
                "record and batch manifest bind different trees",
                path=relative,
            ))
        for hash_field in BATCH_ARTIFACT_SPECS:
            if record.get(hash_field) != manifest.get(hash_field):
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_ARTIFACT_BINDING_MISMATCH",
                    "P0",
                    "record evidence digest differs from its manifest",
                    path=relative,
                    field=hash_field,
                ))
        if (
            record.get("descendant_history_supplement_sha256")
            != manifest.get("descendant_history_supplement_sha256")
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_DESCENDANT_SUPPLEMENT_BINDING_MISMATCH",
                "P0",
                "record descendant-history seal differs from its manifest",
                path=relative,
            ))
        expected_payload_sha = _sha_bytes(_canonical(_record_payload(record)))
        if record.get("record_payload_sha256") != expected_payload_sha:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PAYLOAD_HASH_MISMATCH",
                "P0",
                "record payload digest does not bind its canonical content",
                path=relative,
            ))
        if record.get("record_payload_sha256") != binding.get("record_payload_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PAYLOAD_BINDING_MISMATCH",
                "P0",
                "record payload digest differs from the explicit manifest binding",
                path=relative,
            ))
        if record.get("previous_correction_chain_sha256") != binding.get("previous_correction_chain_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PREDECESSOR_BINDING_MISMATCH",
                "P0",
                "record predecessor differs from the explicit manifest chain",
                path=relative,
            ))
        if record.get("correction_id") != binding.get("correction_id"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_ID_BINDING_MISMATCH",
                "P0",
                "record correction id differs from the explicit manifest binding",
                path=relative,
            ))
        if not _is_exact_future_failure_policy(
            record.get("future_failure_policy")
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FUTURE_AUTO_CORRECTION_ENABLED",
                "P0",
                "record future-failure policy is not exact and fail-closed",
                path=relative,
            ))
        rules = record.get("rule_ids", [])
        if not isinstance(rules, list) or len(rules) != 1 or not str(rules[0]).startswith(HISTORY_PREFIX):
            findings.append(_finding(
                "FULL_CONVERGENCE_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a new record is not restricted to one historical rule",
                path=relative,
            ))
        subjects = record.get("identity_binding_by_failure")
        if not isinstance(subjects, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_SUBJECT_PROJECTION_MISSING",
                "P0",
                "record lacks per-fingerprint subject projections",
                path=relative,
            ))
        else:
            for fingerprint, subject in subjects.items():
                if not isinstance(subject, dict):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_PROJECTION_INVALID",
                        "P0",
                        "subject projection is not an object",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                    continue
                findings.extend(_raw_identity_findings(
                    root,
                    fingerprint=str(fingerprint),
                    subject=subject,
                    identity=baseline_identities.get(str(fingerprint)),
                    record_rule_ids=(
                        [str(value) for value in rules]
                        if isinstance(rules, list)
                        else []
                    ),
                    path=relative,
                ))
                findings.extend(_duplicate_observation_findings(
                    str(fingerprint),
                    subject,
                    baseline_identities,
                    path=relative,
                ))
                projection = subject.get("subject_projection")
                if (
                    not isinstance(projection, dict)
                    or subject.get("subject_projection_sha256") != _sha_bytes(_canonical(projection))
                ):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_PROJECTION_HASH_MISMATCH",
                        "P0",
                        "subject projection is not bound by its canonical digest",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                    continue
                selector = subject.get("authority_selectors")
                binding_head = str(record.get("binding_head_sha", ""))
                if not _selector_is_exact(selector):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_SELECTOR_NOT_EXACT",
                        "P0",
                        "subject projection lacks an exact wildcard-free selector",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                    continue
                binding_projection = _subject_projection(root, binding_head, selector)
                current_projection = _subject_projection(root, evaluated_head, selector)
                if binding_projection != projection:
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_BINDING_MISMATCH",
                        "P0",
                        "subject projection differs from its binding Head",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                if current_projection != projection:
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_PROJECTION_CHANGED",
                        "P0",
                        "subject projection changed at the evaluated Head",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
        record_fingerprints = [str(value) for value in record.get("failure_fingerprints", [])]
        if record_fingerprints != list(binding.get("failure_fingerprints", [])):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FINGERPRINT_BINDING_MISMATCH",
                "P0",
                "record fingerprint set differs from the batch manifest",
                path=relative,
            ))
        if not isinstance(subjects, dict) or set(subjects) != set(record_fingerprints):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_IDENTITY_BINDING_SET_MISMATCH",
                "P0",
                "record must bind one exact identity projection per fingerprint",
                path=relative,
            ))
        all_fingerprints.extend(record_fingerprints)
    if previous != manifest.get("record_chain_terminal_sha256"):
        findings.append(_finding(
            "FULL_CONVERGENCE_CHAIN_TERMINAL_MISMATCH",
            "P0",
            "batch terminal does not equal the final record payload",
        ))
    if sorted(all_fingerprints) != manifest_fingerprints or len(all_fingerprints) != len(set(all_fingerprints)):
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_COVERAGE_MISMATCH",
            "P0",
            "record bindings do not cover each manifest fingerprint exactly once",
        ))
    for fingerprint in sorted(set(all_fingerprints) & predecessor_fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_PRIOR_RECORD_FINGERPRINT_REUSE",
            "P0",
            "the current actual records reuse a fingerprint from any predecessor",
            fingerprint=fingerprint,
        ))
    current_correction_ids = {
        str(binding.get("correction_id", ""))
        for binding in bindings
        if isinstance(binding, dict)
    }
    for correction_id in sorted(current_correction_ids & predecessor_correction_ids):
        findings.append(_finding(
            "FULL_CONVERGENCE_PRIOR_RECORD_CORRECTION_ID_REUSE",
            "P0",
            "the current batch reuses a correction id from a predecessor",
            correction_id=correction_id,
        ))
    for fingerprint in sorted(set(manifest_fingerprints)):
        if fingerprint in baseline_fingerprints["current"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a manifest fingerprint belongs to the frozen current-failure set",
                fingerprint=fingerprint,
            ))
        elif fingerprint not in baseline_fingerprints["historical"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL",
                "P0",
                "a manifest fingerprint is absent from the frozen historical-failure set",
                fingerprint=fingerprint,
            ))
    for fingerprint in sorted(set(manifest_fingerprints) & legacy_fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_LEGACY_FINGERPRINT_REUSE",
            "P0",
            "a new-epoch batch repeats a fingerprint already corrected by the frozen legacy epoch",
            fingerprint=fingerprint,
        ))
    for fingerprint in sorted(set(all_fingerprints)):
        if fingerprint in baseline_fingerprints["current"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a record fingerprint belongs to the frozen current-failure set",
                fingerprint=fingerprint,
            ))
        elif fingerprint not in baseline_fingerprints["historical"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL",
                "P0",
                "a record fingerprint is absent from the frozen historical-failure set",
                fingerprint=fingerprint,
            ))
    findings = _suppress_post_touch_findings(findings, post_touch_trusted)
    return {
        "schema_version": "space_syndicate.v076.reuse_correction_v2.full_convergence_independent_audit.v1",
        "authorization_id": FULL_CONVERGENCE_AUTHORIZATION_ID,
        "authorization_base_head_sha": FULL_CONVERGENCE_BASE_HEAD,
        "authorized_head_sha": FULL_CONVERGENCE_BASE_HEAD,
        "evaluated_head_sha": evaluated_head,
        "raw_failure_count": 566,
        "raw_historical_failure_count": 510,
        "raw_current_delta_failure_count": 56,
        "manifest_path": str(manifest_path),
        "legacy_record_count": len(LEGACY_RECORD_SHA_BY_PATH),
        "new_record_count": predecessor_record_count + len(bindings),
        "new_fingerprint_count": len(predecessor_fingerprints | set(all_fingerprints)),
        "validated_batch_count": len(predecessor_chain) + 1,
        "descendant_history_supplement_sha256": descendant_supplement_sha,
        "descendant_history_raw_report_head_sha": descendant_report_head,
        "descendant_history_authorized_fingerprint_count": len(descendant_fingerprints),
        "post_touch_revalidation": post_touch_summary,
        "live_historical_correction_authority_count": len(
            baseline_fingerprints["historical"]
        ),
        "dispositioned_historical_identity_count": len(dispositioned_fingerprints),
        "p0": [item for item in findings if item["severity"] == "P0"],
        "p1": [item for item in findings if item["severity"] == "P1"],
        "status": "GO" if not findings else "NO_GO",
    }


def _markdown(title: str, report: dict[str, Any]) -> str:
    lines = [f"# {title}", "", f"- Status: `{report['status']}`", f"- P0: `{len(report['p0'])}`", f"- P1: `{len(report['p1'])}`", f"- Authorized head: `{report['authorized_head_sha']}`", f"- Raw failures: `{report['raw_failure_count']}`", f"- Raw historical: `{report['raw_historical_failure_count']}`", f"- Raw current delta: `{report['raw_current_delta_failure_count']}`", ""]
    if "registry_unresolved_historical_row_count" in report:
        lines.extend([
            f"- Registry-unresolved historical rows retained as blocking: `{report['registry_unresolved_historical_row_count']}`",
            f"- Historical rows without concrete path/blob subject: `{report.get('historical_rows_without_concrete_path_count', 0)}`",
            "",
            "Unresolved fingerprints are retained in `registry_unresolved_historical_fingerprints` in the JSON report; none are treated as corrected.",
            "",
        ])
    for label in ("P0", "P1"):
        entries = report[label.casefold()]
        lines.extend([f"## {label}", ""])
        if not entries:
            lines.append("None.")
        else:
            for item in entries:
                evidence = ", ".join(f"{k}={v}" for k, v in item.get("evidence", {}).items())
                lines.append(f"- `{item['code']}` — {item['message']} ({evidence})")
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument(
        "--output-root",
        type=Path,
        default=None,
        help="write audit reports beneath this root while reading only --project inputs",
    )
    parser.add_argument(
        "--full-convergence-batch-manifest",
        type=Path,
        default=None,
        help="independently audit only the explicitly enumerated new-epoch batch",
    )
    parser.add_argument(
        "--previous-batch-manifest",
        type=Path,
        default=None,
        help="explicit immediate predecessor manifest for a non-initial full-convergence batch",
    )
    parser.add_argument(
        "--full-convergence-baseline-report",
        type=Path,
        default=None,
        help="explicit d701 raw report bound by the full-convergence authorization",
    )
    parser.add_argument(
        "--descendant-history-supplement",
        type=Path,
        default=None,
        help="explicit one-shot byte-sealed descendant HISTORY membership manifest",
    )
    parser.add_argument(
        "--descendant-history-raw-report",
        type=Path,
        default=None,
        help="explicit committed-only final raw report with current failure count zero",
    )
    parser.add_argument(
        "--descendant-history-scanner",
        type=Path,
        default=None,
        help="explicit scanner file whose bytes must match the report Head",
    )
    parser.add_argument(
        "--post-touch-revalidation",
        type=Path,
        default=None,
        help="explicit append-only post-touch revalidation manifest; never discovered implicitly",
    )
    parser.add_argument(
        "--evaluated-head-ref",
        default="HEAD",
        help="Head used for subject-projection invalidation in full-convergence mode",
    )
    args = parser.parse_args(argv)
    if (
        args.post_touch_revalidation is not None
        and args.full_convergence_batch_manifest is None
    ):
        parser.error(
            "--post-touch-revalidation requires "
            "--full-convergence-batch-manifest and its complete full-convergence input set"
        )
    root = args.project.resolve()
    output_root = (args.output_root or root).resolve()
    out = output_root / OUT_DIR
    out.mkdir(parents=True, exist_ok=True)
    if args.full_convergence_batch_manifest is not None:
        if (
            args.full_convergence_baseline_report is None
            or args.descendant_history_supplement is None
            or args.descendant_history_raw_report is None
            or args.descendant_history_scanner is None
        ):
            raise SystemExit(
                "--full-convergence-batch-manifest requires "
                "--full-convergence-baseline-report, "
                "--descendant-history-supplement, "
                "--descendant-history-raw-report, and "
                "--descendant-history-scanner"
            )
        report = audit_full_convergence_batch(
            root,
            args.full_convergence_batch_manifest.resolve(),
            evaluated_head=_git(root, "rev-parse", f"{args.evaluated_head_ref}^{{commit}}"),
            baseline_report_path=args.full_convergence_baseline_report.resolve(),
            previous_batch_manifest_path=(
                args.previous_batch_manifest.resolve()
                if args.previous_batch_manifest is not None
                else None
            ),
            descendant_history_supplement_path=(
                args.descendant_history_supplement.resolve()
            ),
            descendant_history_raw_report_path=(
                args.descendant_history_raw_report.resolve()
            ),
            descendant_history_scanner_path=(
                args.descendant_history_scanner.resolve()
            ),
            post_touch_revalidation_path=(
                args.post_touch_revalidation.resolve()
                if args.post_touch_revalidation is not None else None
            ),
        )
        (out / "audit_full_convergence_batch.json").write_bytes(_canonical(report))
        (out / "audit_full_convergence_batch.md").write_text(
            _markdown("Independent Audit — Full-convergence V2 batch", report),
            encoding="utf-8",
        )
        print(json.dumps({"full_convergence_batch": report}, ensure_ascii=False, indent=2))
        return 0 if report["status"] == "GO" else 1
    report_a = audit_a(root)
    report_b = audit_b(root)
    (out / "audit_a_mechanism_safety.json").write_bytes(_canonical(report_a))
    (out / "audit_a_mechanism_safety.md").write_text(_markdown("Audit A — Correction mechanism safety", report_a), encoding="utf-8")
    (out / "audit_b_failure_classification.json").write_bytes(_canonical(report_b))
    (out / "audit_b_failure_classification.md").write_text(_markdown("Audit B — Failure classification accuracy", report_b), encoding="utf-8")
    print(json.dumps({"audit_a": report_a, "audit_b": report_b}, ensure_ascii=False, indent=2))
    return 0 if report_a["status"] == "GO" and report_b["status"] == "GO" else 1


if __name__ == "__main__":
    raise SystemExit(main())
