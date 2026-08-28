#!/usr/bin/env python3
"""Strict append-only FULL_CONVERGENCE epoch for the V076 V2 resolver.

This module does not reinterpret or regenerate the original six V2 records.
They and the ``CI_PORTABILITY_V2`` seal are a frozen legacy epoch.  A full-
convergence record is accepted only when an explicit batch manifest names it,
the first new record continues the exact legacy terminal payload hash, and its
per-fingerprint subject projection remains unchanged at the evaluated Head.

The module intentionally contains no scanner logic and no product/runtime
logic.  It is imported by ``v076_reuse_exact_failure_correction_v2.py`` only
for the new epoch commands.
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, Iterable

try:
    from . import v076_post_touch_revalidation as _post_touch
    from . import v076_subject_projection_revalidation as _subject_projection_revalidation
    from . import v076_subject_projection_revalidation_independent_audit as _subject_projection_revalidation_independent
except ImportError:  # direct script execution
    import v076_post_touch_revalidation as _post_touch
    import v076_subject_projection_revalidation as _subject_projection_revalidation
    import v076_subject_projection_revalidation_independent_audit as _subject_projection_revalidation_independent


EPOCH_ID = "FULL_CONVERGENCE_20260827"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
AUTHORIZATION_BASE_HEAD_SHA = "d701a81dce693b584d52fbfca3e0e78b521ad775"
AUTHORIZED_BASELINE_REPORT_SHA256 = "cfb84c08abacb294ea54ffc975f691869b33ac47a5d6a9f28377c54534f19166"
AUTHORIZED_BASELINE_FAILURE_SET_SHA256 = "dd3b9f88319ba008dafa0de8be14d4e7427a3cb02d7b3e11ed6d50e2c80893ef"
AUTHORIZED_BASELINE_FAILURE_COUNT = 566
AUTHORIZED_BASELINE_HISTORICAL_COUNT = 510
AUTHORIZED_BASELINE_CURRENT_COUNT = 56

LEGACY_AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_CORRECTION_V2_20260826"
LEGACY_AUTHORIZED_HEAD_SHA = "1e24cea73fc23e69e575fcea09df57238156af67"
LEGACY_BASELINE_REPORT_SHA256 = "b1097750f23007ba75d83f646fefe70a3bb5012540d38475a536fc5eee81e435"
LEGACY_SCHEMA_SHA256 = "9f58d1dca66803883686629a20b58261b4b86f90451ee026fb9eb4a91047dde9"
LEGACY_RECORD_CHAIN_TERMINAL_SHA256 = "99f051cd23c250e0282db1708e49e2625d0e82279753a846a00a713614fed67d"
LEGACY_SEAL_MANIFEST_SHA256 = "0731778c0b62f19bd15f7b6629ff82a67c11ec8ff9e6ca2923f4374eb170f948"
LEGACY_SEAL_PLAN_SHA256 = "abb283532cea5b344de680152caeb413522469464ab7d6c4d4e2e10c73ea555b"

SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.full_convergence_record.v1"
BATCH_MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.full_convergence_batch.v1"
EPOCH_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.full_convergence_schema.v1"
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

PREDECESSOR_SCHEMA_REL = Path(
    "docs/architecture/reuse_corrections/v2/schema_full_convergence_20260827.json"
)
# This is the SHA-256 of the committed Git blob, not of a platform-smudged
# worktree rendering.  Git's text/eol checkout policy may materialize this
# tracked JSON with CRLF on Windows while the committed blob remains LF.
PREDECESSOR_SCHEMA_SHA256 = "87acd3a0eaa9ac75e7d5f6ffbd502f8a385275749d3a9ba5eae57a2b3f6b90df"
SCHEMA_REL = PREDECESSOR_SCHEMA_REL
SUCCESSOR_SCHEMA_REL = Path(
    "docs/architecture/reuse_corrections/v2/"
    "schema_full_convergence_20260827_successor_v3.json"
)
SUCCESSOR_SCHEMA_SHA256 = "019bc57dcf92415c00b35b691f7adad9e736770bcf927622cb6db16b966c4543"
RECORD_ROOT_REL = Path("docs/architecture/reuse_corrections/v2/records/full_convergence_20260827")
EPOCH_ROOT_REL = Path("reports/reuse/correction_v2/epochs/full_convergence_20260827")
BASELINE_REPORT_REL = EPOCH_ROOT_REL / "baseline_raw_failure_report.json"
DESCENDANT_HISTORY_SCANNER_REL = Path("tools/v076/v076_reuse_point_inertia_gate.py")
PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_REL = (
    EPOCH_ROOT_REL / "descendant_history_supplement_570d6e3c.json"
)
PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA256 = (
    "65dcc1276767a1c2009fb2157041db2058783ca6ab23e49a3cafdc149b41fe82"
)
PREVIOUS_DESCENDANT_HISTORY_RAW_REL = (
    EPOCH_ROOT_REL / "descendant_history_raw_570d6e3c.json"
)
PREVIOUS_DESCENDANT_HISTORY_RAW_SHA256 = (
    "72545ff3f19be36f47da40bdff693ba02d507c0e90feab622f9b470f98973fa9"
)
PREVIOUS_DESCENDANT_HISTORY_RAW_HEAD = "570d6e3c95b291f019351f5a3a325fc28cb57c80"
PREVIOUS_DESCENDANT_HISTORY_RAW_TREE = "e33db0d93844da7a804a5f33f8dadd8c3797260e"
PREVIOUS_DESCENDANT_HISTORY_SCANNER_SHA256 = (
    "f20759401008da5e22156a22af1d4bdcf527670cdfdc9cc73c76281d6783625a"
)
DESCENDANT_HISTORY_V3_RAW_REL = (
    EPOCH_ROOT_REL / "descendant_history_raw_da48a74b_003.json"
)
DESCENDANT_HISTORY_V3_SUPPLEMENT_REL = (
    EPOCH_ROOT_REL / "descendant_history_supplement_da48a74b_003.json"
)
DESCENDANT_HISTORY_V3_RAW_HEAD = "da48a74b3d12af9040230ea659b1663bd9eb2cbe"
DESCENDANT_HISTORY_V3_RAW_TREE = "2fa166e7aa8f7a3bcc33028fad9517ee2e8738a9"
DESCENDANT_HISTORY_V3_RAW_SHA256 = (
    "812bd75c2e81d21a1a13305d45bf1045b1518b964f83ae88c2dd4f29ecf8dfac"
)
DESCENDANT_HISTORY_V3_SCANNER_SHA256 = (
    "09bc04b52058cdafb7e966ca36230dc153dd637b829b766677ac542be02a9885"
)
DESCENDANT_HISTORY_V3_RAW_FAILURE_COUNT = 501
DESCENDANT_HISTORY_V3_RAW_HISTORICAL_COUNT = 501
DESCENDANT_HISTORY_V3_RAW_CURRENT_COUNT = 0
DESCENDANT_HISTORY_V3_REGISTERED_IDENTITY_COUNT = 520
DYNAMIC_REFERENCE_MANIFEST_REL = Path("docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json")
EXACT_SUCCESSOR_FINGERPRINT_MAPPING = "EXACT_SUCCESSOR_FINGERPRINT_MAPPING"
EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT = "EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT"
ALLOWED_FROZEN_IDENTITY_DISPOSITIONS = {
    EXACT_SUCCESSOR_FINGERPRINT_MAPPING,
    EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT,
}
LEGACY_SEAL_MANIFEST_REL = Path(
    "reports/reuse/correction_v2/seals/ci_portability_v2/correction_authorization_manifest.json"
)
LEGACY_SEAL_PLAN_REL = Path(
    "reports/reuse/correction_v2/seals/ci_portability_v2/correction_application_plan.json"
)
LEGACY_SCHEMA_REL = Path("docs/architecture/reuse_corrections/v2/schema.json")

# Filled from the committed schema artifact.  Keeping it in code prevents a
# schema plus freshly rewritten sidecar from silently broadening authority.
AUTHORIZED_SCHEMA_SHA256 = PREDECESSOR_SCHEMA_SHA256

AUTHORITY_SOURCE_PATHS = (
    "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json",
    "docs/architecture/V076_SUPERSESSION_MAP.json",
    "docs/architecture/V076_OWNER_REUSE_MAP.md",
    "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json",
)

DESCENDANT_HISTORY_IDENTITY_FIELDS = tuple(sorted((
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
)))

FROZEN_IDENTITY_DISPOSITION_FIELDS = tuple(sorted((
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
)))

SUCCESSOR_DISPOSITION_EVIDENCE_FIELDS = tuple(sorted((
    "baseline_raw_report_sha256",
    "evidence_kind",
    "live_raw_report_sha256",
    "successor_raw_failure",
    "successor_rule_id",
    "successor_subject_kind",
    "successor_subject_value",
    "successor_transition_new_sha",
    "successor_transition_old_sha",
)))

FALSE_COMPONENT_RETIREMENT_EVIDENCE_FIELDS = tuple(sorted((
    "baseline_raw_report_sha256",
    "dynamic_reference_ids",
    "dynamic_reference_manifest_blob_sha256",
    "dynamic_reference_manifest_path",
    "evidence_kind",
    "live_raw_report_sha256",
    "resolved_target",
    "subject_directly_changed",
)))

DESCENDANT_HISTORY_SUPPLEMENT_FIELDS = tuple(sorted((
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
)))

DESCENDANT_HISTORY_SCANNER_EVOLUTION_FIELDS = tuple(sorted((
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
)))

DESCENDANT_HISTORY_SUPPLEMENT_V3_FIELDS = tuple(sorted((
    *DESCENDANT_HISTORY_SUPPLEMENT_FIELDS,
    "previous_supplement_path",
    "previous_supplement_sha256",
    "scanner_evolution",
)))

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

LEGACY_RECORD_BINDINGS = (
    {
        "path": "docs/architecture/reuse_corrections/v2/records/historical_untouched_affected_domain_debt.json",
        "sha256": "5d9ec47eed02e21cd19e36f9df2f402367e9498a717da07e2e2b1e1fe68aad6d",
        "payload_sha256": "730048c94bd112e40d68d4e5e1fb05366f6d24242777c87d8ffbcf6fd92a89ac",
    },
    {
        "path": "docs/architecture/reuse_corrections/v2/records/historical_untouched_affected_owner_debt.json",
        "sha256": "78160390f497b1d1b05078667c67dfafd928047e2118ef5f9cf98c518331fa33",
        "payload_sha256": "effc35e0a3c38f9eebce5aa75e6502598a4fdbc4ce4f5051af1bf68467903378",
    },
    {
        "path": "docs/architecture/reuse_corrections/v2/records/historical_untouched_change_class_debt.json",
        "sha256": "144ad88f1b1f65ea973d8dbab4fb744a4eb71c4c8fde51bc7f50550aeae9c469",
        "payload_sha256": "e27d7c303e020fa30ba881426a67c4f45371b6c90567557e389b57745235b101",
    },
    {
        "path": "docs/architecture/reuse_corrections/v2/records/historical_untouched_dynamic_reference_debt.json",
        "sha256": "d66d75d42761fd1f6274ca9ea61b1af703d68816738f1d485ab50afacf4bb2db",
        "payload_sha256": "d711cb92bb6e53cb8ffb2527045dece4e6a20f22beb2c785760c9fed7b8627b4",
    },
    {
        "path": "docs/architecture/reuse_corrections/v2/records/historical_untouched_focused_test_scope_debt.json",
        "sha256": "654f021e14be59b690033d7667f9c3bd6324b85f8a3c3ba824785d18361ef042",
        "payload_sha256": "4a4b9495ad91f29c05fdce7682581de2d4e71435cbde14ac85ab4cdc68389a6a",
    },
    {
        "path": "docs/architecture/reuse_corrections/v2/records/historical_untouched_reuse_scan_debt.json",
        "sha256": "2e1c7ee76aff7dec57f1634be3a1913334ee282e2019ba09e97ae2b0396cac20",
        "payload_sha256": LEGACY_RECORD_CHAIN_TERMINAL_SHA256,
    },
)

IDENTITY_BINDING_FIELDS = tuple(sorted((
    "authority_selectors",
    "current_blob_sha256",
    "current_component_id",
    "domain_id",
    "current_owner_id",
    "current_path",
    "current_production_reachability",
    "current_role",
    "diagnostic_only_status",
    "documentation_only_status",
    "dynamic_reference_status",
    "duplicate_identity_sha256",
    "duplicate_of_failure_fingerprint",
    "duplicate_reason",
    "generated_evidence_status",
    "first_seen_commit",
    "historical_blob_sha256",
    "historical_component_id",
    "historical_owner_id",
    "historical_path",
    "historical_production_reachability",
    "historical_role",
    "invalidation_policy",
    "recommended_disposition",
    "retired_status",
    "subject_projection",
    "subject_projection_sha256",
    "source_commit",
    "superseded_by",
    "supersedes",
    "test_only_status",
    "last_seen_commit",
)))

AUTHORITY_SELECTOR_FIELDS = tuple(sorted((
    "component_ids",
    "dynamic_reference_ids",
    "paths",
    "retirement_ids",
    "supersession_ids",
)))

EXTENSION_RECORD_FIELDS = tuple(sorted((
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
    "correction_id",
    "correction_reason",
    "component_ids",
    "component_set_sha256",
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
)))

BATCH_MANIFEST_FIELDS = tuple(sorted((
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
)))

ALLOWED_DISPOSITIONS = {
    "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
    "HISTORICAL_SUPERSEDED_NONREACHABLE",
    "HISTORICAL_RETIRED_NONREACHABLE",
    "HISTORICAL_TEST_ONLY",
    "HISTORICAL_DIAGNOSTIC_ONLY",
    "HISTORICAL_GENERATED_EVIDENCE",
    "HISTORICAL_DOCUMENTATION_ONLY",
    "HISTORICAL_DUPLICATE_OBSERVATION",
    "HISTORICAL_DYNAMIC_REFERENCE_RESOLVED",
    "HISTORICAL_DYNAMIC_REFERENCE_SUPERSEDED",
    "HISTORICAL_DYNAMIC_REFERENCE_TEST_ONLY",
    "HISTORICAL_DYNAMIC_REFERENCE_DIAGNOSTIC_ONLY",
}

DYNAMIC_REFERENCE_DISPOSITIONS = {
    value
    for value in ALLOWED_DISPOSITIONS
    if value.startswith("HISTORICAL_DYNAMIC_REFERENCE_")
}

IDENTITY_STATE_FIELDS = (
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

SUBJECT_PROJECTION_FIELDS = {
    "dynamic_reference_rows",
    "owner_map_lines",
    "registry_rows",
    "supersession_rows",
}

DYNAMIC_REFERENCE_ENTRY_FIELDS = {
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

DYNAMIC_REFERENCE_LOCATION_FIELDS = {
    "column",
    "containing_function",
    "line",
}

DYNAMIC_REFERENCE_RUNTIME_PROBE_FIELDS = {
    "expected_target_count",
    "probe_id",
    "required_before_production_claim",
    "test_path",
}

DYNAMIC_REFERENCE_FAILURE_POLICY_FIELDS = {
    "future_site_auto_resolution_count",
    "source_blob_change_invalidates",
    "source_location_change_invalidates",
    "target_set_change_invalidates",
    "unknown_callsite_fails_closed",
    "wildcard_count",
}

DYNAMIC_REFERENCE_RESOLUTION_METHODS = {
    "EXACT_CONSTANT_CALL_GRAPH_MANIFEST",
}

DYNAMIC_REFERENCE_CALLSITE_FIELDS = {
    "allowed_argument_constants",
    "external_or_unknown_invocation_count",
    "helper_function",
    "required_invocation_count",
    "required_loader_sites",
}

DYNAMIC_REFERENCE_LOADER_SITE_FIELDS = {
    "column",
    "line",
    "loader",
    "reference_expression",
}

REGISTRY_ALLOWED_COMPONENT_ROLES = {
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

REGISTRY_ALLOWED_REUSE_DISPOSITIONS = {
    "ADAPT_AS_CONSUMER",
    "ADOPT_AS_OWNER",
    "REFERENCE_ONLY",
    "REUSE_AS_TEST",
}

REGISTRY_NONPRODUCTION_ROLES = {
    "DIAGNOSTIC_BENCH",
    "DIAGNOSTIC_ONLY",
    "DOCUMENTATION_ONLY",
    "GENERATED_EVIDENCE",
    "RETIRED",
    "TEST_SUPPORT",
    "TOOLING",
}

REGISTRY_COMPONENT_INVENTORY_FIELDS = {
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

REGISTRY_COMPONENT_INVENTORY_REQUIRED_FIELDS = (
    REGISTRY_COMPONENT_INVENTORY_FIELDS - {"reuse_scan"}
)

REGISTRY_HISTORICAL_BACKFILL_FIELDS = {
    "authority_source_kind",
    "component_id",
    "current_disposition",
    "historical_role",
    "production_reachability",
    "source_blob",
    "source_commit",
    "supersession",
}

IDENTITY_NON_MIGRATION_DISPOSITIONS = {
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

DISALLOWED_TOKENS = {
    "*", "glob", "regex", "prefix", "directory", "legacy", "misc", "other",
    "unknown", "unknown_accepted", "ignore", "waive", "grandfather",
}


def _identity_state_signature(
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


def _identity_allowed_state_signatures(
    disposition: str,
    binding: dict[str, Any],
) -> list[dict[str, str]]:
    current_role = str(binding.get("current_role", ""))
    historical_role = str(binding.get("historical_role", ""))
    active = _identity_state_signature(
        reachability="PRODUCTION_REACHABLE",
        role=current_role,
        historical_role=historical_role,
        retired_status="ACTIVE_LINEAGE",
    )
    test_only = _identity_state_signature(
        reachability="TEST_ONLY",
        role="TEST_SUPPORT",
        retired_status="NOT_RETIRED",
        test_status="TEST_ONLY",
    )
    diagnostic = _identity_state_signature(
        reachability="DIAGNOSTIC_ONLY",
        role=current_role,
        historical_role=historical_role,
        retired_status="NOT_RETIRED",
        diagnostic_status="DIAGNOSTIC_ONLY",
    )
    documentation = _identity_state_signature(
        reachability="DOCUMENTATION_ONLY",
        role="DOCUMENTATION_ONLY",
        retired_status="NOT_RETIRED",
        documentation_status="DOCUMENTATION_ONLY",
    )
    generated = _identity_state_signature(
        reachability="GENERATED_EVIDENCE_ONLY",
        role="GENERATED_EVIDENCE",
        retired_status="NOT_RETIRED",
        generated_status="GENERATED_EVIDENCE",
    )
    if disposition == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED":
        return [active]
    if disposition == "HISTORICAL_SUPERSEDED_NONREACHABLE":
        return [_identity_state_signature(
            reachability="PRODUCTION_REACHABLE",
            role=current_role,
            historical_reachability="NONREACHABLE",
            historical_role=historical_role,
            retired_status="SUPERSEDED_NONREACHABLE",
        )]
    if disposition == "HISTORICAL_RETIRED_NONREACHABLE":
        return [_identity_state_signature(
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
            _identity_state_signature(
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


def _identity_disposition_failures(
    binding: dict[str, Any],
    *,
    rule_id: str,
) -> list[str]:
    failures: list[str] = []
    disposition = str(binding.get("recommended_disposition", ""))
    is_dynamic_rule = rule_id == "HISTORY_DYNAMIC_REFERENCE_UNRESOLVED"
    if is_dynamic_rule != (disposition in DYNAMIC_REFERENCE_DISPOSITIONS):
        failures.append("IDENTITY_BINDING_RULE_DISPOSITION_MISMATCH")
    for field in IDENTITY_STATE_FIELDS:
        value = str(binding.get(field, ""))
        upper_value = value.upper()
        if not value or "UNKNOWN" in upper_value or "UNRESOLVED" in upper_value:
            failures.append(f"IDENTITY_BINDING_UNKNOWN:{field}")
    duplicate_target = str(binding.get("duplicate_of_failure_fingerprint", ""))
    duplicate_digest = str(binding.get("duplicate_identity_sha256", ""))
    duplicate_reason = str(binding.get("duplicate_reason", ""))
    if disposition == "HISTORICAL_DUPLICATE_OBSERVATION":
        if (
            re.fullmatch(r"V2F-[0-9a-f]{64}", duplicate_target) is None
            or not _is_sha256(duplicate_digest)
            or duplicate_reason
            != "SAME_RULE_AND_SUBJECT_DISTINCT_TRANSITION_OBSERVATION"
        ):
            failures.append("IDENTITY_BINDING_DUPLICATE_EVIDENCE_INVALID")
    elif duplicate_target or duplicate_digest or duplicate_reason:
        failures.append("IDENTITY_BINDING_DUPLICATE_EVIDENCE_UNEXPECTED")
    state = {
        field: str(binding.get(field, ""))
        for field in IDENTITY_STATE_FIELDS
        if field != "domain_id"
    }
    if (
        str(binding.get("current_role", "")) in REGISTRY_NONPRODUCTION_ROLES
        and str(binding.get("current_production_reachability", ""))
        == "PRODUCTION_REACHABLE"
    ):
        failures.append("IDENTITY_BINDING_NONPRODUCTION_ROLE_REACHABLE")
    allowed_signatures = _identity_allowed_state_signatures(disposition, binding)
    if not allowed_signatures or state not in allowed_signatures:
        failures.append("IDENTITY_BINDING_DISPOSITION_STATE_MATRIX_INVALID")
    if disposition == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED" and (
        not binding.get("current_path")
        or binding.get("current_blob_sha256") == "MISSING"
    ):
        failures.append("IDENTITY_BINDING_ACTIVE_LINEAGE_SEMANTICS_INVALID")
    if disposition in {
        "HISTORICAL_SUPERSEDED_NONREACHABLE",
        "HISTORICAL_DYNAMIC_REFERENCE_SUPERSEDED",
    } and (
        not isinstance(binding.get("superseded_by"), list)
        or not binding.get("superseded_by")
    ):
        failures.append("IDENTITY_BINDING_SUPERSESSION_SEMANTICS_INVALID")
    return sorted(set(failures))


class DuplicateJsonKeyError(ValueError):
    pass


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJsonKeyError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def load_json_strict(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"), object_pairs_hook=_strict_object)


def normalize_path(value: str) -> str:
    result = value.strip().replace("\\", "/")
    if result.startswith("res://"):
        result = result[6:]
    while "//" in result:
        result = result.replace("//", "/")
    return result


def _is_sha256(value: Any) -> bool:
    return isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{64}", value))


def _is_commit(value: Any) -> bool:
    return isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{40}", value))


def _is_int(value: Any) -> bool:
    """Reject bools at JSON integer trust boundaries."""

    return type(value) is int


def _is_exact_int(value: Any, expected: int) -> bool:
    return _is_int(value) and value == expected


def _line_set_sha(values: Iterable[str]) -> str:
    ordered = sorted(str(value) for value in values)
    return sha256_bytes(("\n".join(ordered) + "\n").encode("utf-8"))


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
    if result.returncode != 0:
        raise ValueError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def _git_bytes(root: Path, commit: str, relative: str) -> bytes | None:
    result = subprocess.run(
        ["git", "-C", str(root), "show", f"{commit}:{normalize_path(relative)}"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return bytes(result.stdout) if result.returncode == 0 else None


def _is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    result = subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", ancestor, descendant],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def failure_set_sha(report: dict[str, Any]) -> str:
    values = report.get("failures")
    if not isinstance(values, list):
        raise ValueError("BASELINE_FAILURE_LIST_INVALID")
    rendered = [str(value) for value in values]
    if len(rendered) != len(set(rendered)):
        raise ValueError("BASELINE_FAILURE_DUPLICATE")
    return _line_set_sha(rendered)


def authorized_failure_fingerprint_sets(report: dict[str, Any]) -> dict[str, set[str]]:
    if not isinstance(report, dict):
        raise ValueError("BASELINE_REPORT_NOT_OBJECT")
    values = report.get("failures")
    if not isinstance(values, list):
        raise ValueError("BASELINE_FAILURE_LIST_INVALID")
    result = {"historical": set(), "current": set()}
    for value in values:
        raw = str(value)
        rule_id = raw.split(":", 1)[0]
        bucket = "HISTORICAL" if rule_id.startswith("HISTORY_") else "CURRENT_DELTA_FAILURE"
        payload = f"V076_RAW_FAILURE_V2\n{bucket}\n{rule_id}\n{raw}\n".encode("utf-8")
        fingerprint = "V2F-" + sha256_bytes(payload)
        target = "historical" if bucket == "HISTORICAL" else "current"
        if fingerprint in result[target]:
            raise ValueError("BASELINE_FAILURE_FINGERPRINT_DUPLICATE")
        result[target].add(fingerprint)
    return result


def _raw_historical_identity(raw: str) -> dict[str, str]:
    """Project one frozen raw row into the identity facts a record must bind.

    The scanner has two historical subject shapes.  Component-metadata rows
    name a component id immediately after the transition; every other
    historical row names the historical path immediately after the transition.
    Dynamic-reference rows carry method/key tokens before that transition, so
    the transition is located structurally rather than by a fixed index.
    """

    parts = raw.split(":")
    rule_id = parts[0] if parts else ""
    transition_index = next(
        (
            index
            for index, value in enumerate(parts)
            if re.fullmatch(r"[0-9a-f]{12}->[0-9a-f]{12}", value)
        ),
        -1,
    )
    result = {
        "raw_failure": raw,
        "rule_id": rule_id,
        "transition_old_prefix": "",
        "transition_new_prefix": "",
        "subject_kind": "",
        "subject_value": "",
    }
    if transition_index < 0:
        return result
    old_prefix, new_prefix = parts[transition_index].split("->", 1)
    result["transition_old_prefix"] = old_prefix
    result["transition_new_prefix"] = new_prefix
    if transition_index + 1 >= len(parts):
        return result
    metadata_rules = {
        "HISTORY_COMPONENT_CHANGE_CLASS_NOT_DECLARED",
        "HISTORY_PRODUCT_AFFECTED_DOMAIN_MISSING",
        "HISTORY_PRODUCT_AFFECTED_OWNER_MISSING",
        "HISTORY_PRODUCT_FOCUSED_TESTS_MISSING",
        "HISTORY_PRODUCT_REUSE_SCAN_INVALID",
    }
    result["subject_kind"] = "component_id" if rule_id in metadata_rules else "path"
    result["subject_value"] = normalize_path(parts[transition_index + 1])
    return result


def authorized_failure_identity_by_fingerprint(
    report: dict[str, Any],
) -> dict[str, dict[str, str]]:
    if not isinstance(report, dict) or not isinstance(report.get("failures"), list):
        raise ValueError("BASELINE_FAILURE_LIST_INVALID")
    result: dict[str, dict[str, str]] = {}
    for value in report["failures"]:
        raw = str(value)
        rule_id = raw.split(":", 1)[0]
        bucket = "HISTORICAL" if rule_id.startswith("HISTORY_") else "CURRENT_DELTA_FAILURE"
        payload = f"V076_RAW_FAILURE_V2\n{bucket}\n{rule_id}\n{raw}\n".encode("utf-8")
        fingerprint = "V2F-" + sha256_bytes(payload)
        if fingerprint in result:
            raise ValueError("BASELINE_FAILURE_FINGERPRINT_DUPLICATE")
        identity = _raw_historical_identity(raw) if bucket == "HISTORICAL" else {
            "raw_failure": raw,
            "rule_id": rule_id,
            "transition_old_prefix": "",
            "transition_new_prefix": "",
            "subject_kind": "",
            "subject_value": "",
        }
        identity["bucket"] = bucket
        identity["failure_fingerprint"] = fingerprint
        result[fingerprint] = identity
    return result


def validate_authorized_baseline(path: Path) -> dict[str, Any]:
    failures: list[str] = []
    if not path.is_file():
        return {"status": "FAIL", "failures": ["BASELINE_MISSING"]}
    payload = path.read_bytes()
    if sha256_bytes(payload) != AUTHORIZED_BASELINE_REPORT_SHA256:
        failures.append("BASELINE_SHA256_MISMATCH")
    try:
        report = json.loads(payload.decode("utf-8-sig"), object_pairs_hook=_strict_object)
    except (UnicodeDecodeError, json.JSONDecodeError, DuplicateJsonKeyError):
        return {"status": "FAIL", "failures": ["BASELINE_JSON_INVALID"]}
    if not isinstance(report, dict):
        return {"status": "FAIL", "failures": ["BASELINE_REPORT_NOT_OBJECT"]}
    values = report.get("failures")
    if report.get("head_sha") != AUTHORIZATION_BASE_HEAD_SHA:
        failures.append("BASELINE_HEAD_MISMATCH")
    if not isinstance(values, list):
        failures.append("BASELINE_FAILURE_LIST_INVALID")
        values = []
    if len(values) != AUTHORIZED_BASELINE_FAILURE_COUNT:
        failures.append("BASELINE_FAILURE_COUNT_MISMATCH")
    historical = [value for value in values if str(value).startswith("HISTORY_")]
    current = [value for value in values if not str(value).startswith("HISTORY_")]
    if len(historical) != AUTHORIZED_BASELINE_HISTORICAL_COUNT:
        failures.append("BASELINE_HISTORICAL_COUNT_MISMATCH")
    if len(current) != AUTHORIZED_BASELINE_CURRENT_COUNT:
        failures.append("BASELINE_CURRENT_COUNT_MISMATCH")
    try:
        actual_set_sha = failure_set_sha(report)
    except ValueError as exc:
        failures.append(str(exc))
        actual_set_sha = ""
    if actual_set_sha != AUTHORIZED_BASELINE_FAILURE_SET_SHA256:
        failures.append("BASELINE_FAILURE_SET_SHA256_MISMATCH")
    return {
        "status": "PASS" if not failures else "FAIL",
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD_SHA,
        "baseline_report_sha256": sha256_bytes(payload),
        "baseline_failure_set_sha256": actual_set_sha,
        "failure_count": len(values),
        "historical_failure_count": len(historical),
        "current_failure_count": len(current),
        "failures": sorted(set(failures)),
    }


def _exact_repo_relative(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return ""


def _resolve_evaluated_head(root: Path, evaluated_head: str | None) -> str:
    """Resolve the exact commit used for a committed-blob authority check."""

    candidate = evaluated_head or ""
    if not candidate:
        try:
            candidate = _git(root, "rev-parse", "HEAD")
        except ValueError:
            return ""
    return candidate if _is_commit(candidate) else ""


def _committed_blob_bytes(
    root: Path,
    relative: str,
    *,
    evaluated_head: str | None,
) -> bytes | None:
    """Read one exact blob from the evaluated Git tree.

    This deliberately bypasses the platform worktree/smudge representation;
    the SHA-256 authority for a tracked artifact is the bytes returned by
    ``git show <head>:<path>``.
    """

    head = _resolve_evaluated_head(root, evaluated_head)
    if not head:
        return None
    return _git_bytes(root, head, normalize_path(relative))


def _git_object_id(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="ascii",
        errors="replace",
    )
    value = result.stdout.strip()
    return value if result.returncode == 0 and re.fullmatch(r"[0-9a-f]{40}", value) else ""


def _committed_blob_seal_failures(
    root: Path,
    path: Path,
    expected_sha256: str,
    *,
    evaluated_head: str | None,
    code_prefix: str,
) -> list[str]:
    """Return fail-closed findings for a committed blob plus its worktree.

    The committed hash is always computed from Git blob bytes.  Git itself
    applies the path's declared clean filters to the worktree copy and hashes
    that canonical result; equality with the evaluated tree object therefore
    accepts configured LF/CRLF checkout materialization while rejecting every
    content change that Git would stage.
    """

    relative = _exact_repo_relative(root, path)
    if not relative:
        return [f"{code_prefix}_PATH_INVALID"]
    head = _resolve_evaluated_head(root, evaluated_head)
    committed = _committed_blob_bytes(
        root,
        relative,
        evaluated_head=head,
    )
    if committed is None:
        return [f"{code_prefix}_COMMITTED_BLOB_MISSING"]
    failures: list[str] = []
    if sha256_bytes(committed) != expected_sha256:
        failures.append(f"{code_prefix}_COMMITTED_BLOB_SHA256_MISMATCH")
    if not path.is_file():
        failures.append(f"{code_prefix}_WORKTREE_MISSING")
    else:
        tree_oid = _git_object_id(root, "rev-parse", f"{head}:{relative}")
        clean_oid = _git_object_id(
            root,
            "hash-object",
            f"--path={relative}",
            "--",
            relative,
        )
        if not tree_oid or clean_oid != tree_oid:
            failures.append(f"{code_prefix}_WORKTREE_CONTENT_DRIFT")
    return sorted(set(failures))


def _validate_descendant_history_supplement_core(
    root: Path,
    supplement_path: Path | None,
    raw_report_path: Path | None,
    scanner_path: Path | None,
    *,
    evaluated_head: str,
    baseline_report_path: Path,
    expected_schema_version: str,
    expected_supplement_id: str,
    expected_fields: tuple[str, ...],
    require_live_scanner_bytes: bool = True,
) -> dict[str, Any]:
    """Validate one explicit, byte-sealed descendant HISTORY reconciliation.

    The supplement is not discovered.  Its three files must be passed by the
    caller, and the raw report must evaluate one committed Head with zero
    current failures.  A frozen identity must either remain live or have one
    exact append-only successor/false-component disposition.  Only live
    historical identities enter correction authority.
    """

    failures: list[str] = []
    empty = {
        "status": "FAIL",
        "failures": failures,
        "supplement_sha256": "",
        "authorized_historical_fingerprints": set(),
        "authorized_identity_by_fingerprint": {},
        "registered_historical_fingerprints": set(),
        "registered_identity_by_fingerprint": {},
        "dispositioned_historical_fingerprints": set(),
        "frozen_identity_disposition_by_failure": {},
        "raw_report_head_sha": "",
    }
    if supplement_path is None:
        failures.append("DESCENDANT_HISTORY_SUPPLEMENT_REQUIRED")
    if raw_report_path is None:
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_REQUIRED")
    if scanner_path is None:
        failures.append("DESCENDANT_HISTORY_SCANNER_REQUIRED")
    if failures:
        return empty
    assert supplement_path is not None
    assert raw_report_path is not None
    assert scanner_path is not None
    supplement_relative = _exact_repo_relative(root, supplement_path)
    raw_report_relative = _exact_repo_relative(root, raw_report_path)
    scanner_relative = _exact_repo_relative(root, scanner_path)
    epoch_prefix = EPOCH_ROOT_REL.as_posix() + "/"
    if not supplement_relative.startswith(epoch_prefix):
        failures.append("DESCENDANT_HISTORY_SUPPLEMENT_PATH_OUTSIDE_EPOCH")
    if not raw_report_relative.startswith(epoch_prefix):
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_PATH_OUTSIDE_EPOCH")
    if scanner_relative != DESCENDANT_HISTORY_SCANNER_REL.as_posix():
        failures.append("DESCENDANT_HISTORY_SCANNER_PATH_MISMATCH")
    try:
        supplement = load_json_strict(supplement_path)
        supplement_sha = sha256_file(supplement_path)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        supplement = {}
        supplement_sha = ""
        failures.append("DESCENDANT_HISTORY_SUPPLEMENT_JSON_INVALID")
    if not isinstance(supplement, dict):
        supplement = {}
        failures.append("DESCENDANT_HISTORY_SUPPLEMENT_NOT_OBJECT")
    if set(supplement) != set(expected_fields):
        failures.append("DESCENDANT_HISTORY_SUPPLEMENT_FIELD_SET_MISMATCH")
    for field in expected_fields:
        if field.endswith("_count") and not _is_int(supplement.get(field)):
            failures.append(
                f"DESCENDANT_HISTORY_SUPPLEMENT_{field.upper()}_TYPE_INVALID"
            )
    for field, expected in (
        ("schema_version", expected_schema_version),
        ("supplement_id", expected_supplement_id),
        ("authorization_id", AUTHORIZATION_ID),
        ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD_SHA),
        ("baseline_report_sha256", AUTHORIZED_BASELINE_REPORT_SHA256),
        ("baseline_failure_set_sha256", AUTHORIZED_BASELINE_FAILURE_SET_SHA256),
        ("baseline_historical_membership_policy", "LIVE_RAW_OR_EXACT_APPEND_ONLY_DISPOSITION"),
        ("committed_only", True),
        ("correction_membership_scope", "LIVE_HISTORICAL_ONLY"),
        ("directory_discovery_allowed", False),
        ("disposition_wildcard_count", 0),
        ("wildcard_membership_allowed", False),
        ("future_failure_auto_membership_allowed", False),
        ("raw_current_delta_failure_count", 0),
        ("raw_failure_detection_suppressed_count", 0),
        ("scanner_tool_path", DESCENDANT_HISTORY_SCANNER_REL.as_posix()),
        ("raw_report_path", raw_report_relative),
    ):
        if supplement.get(field) != expected:
            failures.append(f"DESCENDANT_HISTORY_SUPPLEMENT_{field.upper()}_MISMATCH")
    try:
        baseline_report = load_json_strict(baseline_report_path)
        frozen_sets = authorized_failure_fingerprint_sets(baseline_report)
        frozen_identities = authorized_failure_identity_by_fingerprint(baseline_report)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        frozen_sets = {"historical": set(), "current": set()}
        frozen_identities = {}
        failures.append("DESCENDANT_HISTORY_BASELINE_UNRESOLVED")
    if (
        len(frozen_sets["historical"]) != AUTHORIZED_BASELINE_HISTORICAL_COUNT
        or len(frozen_sets["current"]) != AUTHORIZED_BASELINE_CURRENT_COUNT
    ):
        failures.append("DESCENDANT_HISTORY_BASELINE_SET_INVALID")
    try:
        raw_report = load_json_strict(raw_report_path)
        raw_report_sha = sha256_file(raw_report_path)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        raw_report = {}
        raw_report_sha = ""
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_JSON_INVALID")
    if not isinstance(raw_report, dict):
        raw_report = {}
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_NOT_OBJECT")
    if supplement.get("raw_report_sha256") != raw_report_sha:
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_SHA256_MISMATCH")
    raw_values = raw_report.get("failures")
    if not isinstance(raw_values, list):
        raw_values = []
        failures.append("DESCENDANT_HISTORY_RAW_FAILURE_LIST_INVALID")
    raw_rendered = [str(value) for value in raw_values]
    if len(raw_rendered) != len(set(raw_rendered)):
        failures.append("DESCENDANT_HISTORY_RAW_FAILURE_DUPLICATE")
    try:
        final_sets = authorized_failure_fingerprint_sets(raw_report)
        final_identities = authorized_failure_identity_by_fingerprint(raw_report)
    except ValueError as exc:
        final_sets = {"historical": set(), "current": set()}
        final_identities = {}
        failures.append(f"DESCENDANT_HISTORY_RAW_FINGERPRINT_SET_INVALID:{exc}")
    if final_sets["current"]:
        failures.append("DESCENDANT_HISTORY_FINAL_CURRENT_FAILURE_COUNT_NOT_ZERO")
    live_frozen_fingerprints = frozen_sets["historical"] & final_sets["historical"]
    missing_frozen_fingerprints = frozen_sets["historical"] - final_sets["historical"]
    descendant_fingerprints = final_sets["historical"] - frozen_sets["historical"]
    if not descendant_fingerprints:
        failures.append("DESCENDANT_HISTORY_SUPPLEMENT_EMPTY")
    declared_descendant = supplement.get("descendant_history_fingerprints")
    if not isinstance(declared_descendant, list):
        declared_descendant = []
        failures.append("DESCENDANT_HISTORY_FINGERPRINT_LIST_INVALID")
    declared_descendant_rendered = [str(value) for value in declared_descendant]
    if (
        declared_descendant_rendered != sorted(declared_descendant_rendered)
        or len(declared_descendant_rendered) != len(set(declared_descendant_rendered))
        or any(not re.fullmatch(r"V2F-[0-9a-f]{64}", value) for value in declared_descendant_rendered)
    ):
        failures.append("DESCENDANT_HISTORY_FINGERPRINT_SET_INVALID")
    if set(declared_descendant_rendered) != descendant_fingerprints:
        failures.append("DESCENDANT_HISTORY_FINGERPRINT_MEMBERSHIP_MISMATCH")
    if not _is_exact_int(
        supplement.get("descendant_history_failure_count"),
        len(descendant_fingerprints),
    ):
        failures.append("DESCENDANT_HISTORY_FAILURE_COUNT_MISMATCH")
    if supplement.get("descendant_history_fingerprint_set_sha256") != _line_set_sha(
        declared_descendant_rendered
    ):
        failures.append("DESCENDANT_HISTORY_FINGERPRINT_SET_SHA256_MISMATCH")
    declared_live_frozen = supplement.get("live_frozen_historical_fingerprints")
    rendered_live_frozen = (
        [str(value) for value in declared_live_frozen]
        if isinstance(declared_live_frozen, list)
        else []
    )
    if (
        rendered_live_frozen != sorted(rendered_live_frozen)
        or len(rendered_live_frozen) != len(set(rendered_live_frozen))
        or set(rendered_live_frozen) != live_frozen_fingerprints
    ):
        failures.append("DESCENDANT_HISTORY_LIVE_FROZEN_MEMBERSHIP_MISMATCH")
    if (
        not _is_exact_int(
            supplement.get("live_frozen_historical_failure_count"),
            len(live_frozen_fingerprints),
        )
        or supplement.get("live_frozen_historical_fingerprint_set_sha256")
        != _line_set_sha(rendered_live_frozen)
    ):
        failures.append("DESCENDANT_HISTORY_LIVE_FROZEN_DIGEST_MISMATCH")
    declared_missing_frozen = supplement.get("missing_frozen_historical_fingerprints")
    rendered_missing_frozen = (
        [str(value) for value in declared_missing_frozen]
        if isinstance(declared_missing_frozen, list)
        else []
    )
    if (
        rendered_missing_frozen != sorted(rendered_missing_frozen)
        or len(rendered_missing_frozen) != len(set(rendered_missing_frozen))
        or set(rendered_missing_frozen) != missing_frozen_fingerprints
    ):
        failures.append("DESCENDANT_HISTORY_MISSING_FROZEN_MEMBERSHIP_MISMATCH")
    if (
        not _is_exact_int(
            supplement.get("missing_frozen_historical_failure_count"),
            len(missing_frozen_fingerprints),
        )
        or supplement.get("missing_frozen_historical_fingerprint_set_sha256")
        != _line_set_sha(rendered_missing_frozen)
    ):
        failures.append("DESCENDANT_HISTORY_MISSING_FROZEN_DIGEST_MISMATCH")
    if not _is_exact_int(supplement.get("raw_failure_count"), len(raw_rendered)):
        failures.append("DESCENDANT_HISTORY_RAW_FAILURE_COUNT_MISMATCH")
    if not _is_exact_int(
        supplement.get("raw_historical_failure_count"),
        len(final_sets["historical"]),
    ):
        failures.append("DESCENDANT_HISTORY_RAW_HISTORICAL_COUNT_MISMATCH")
    if not _is_exact_int(
        supplement.get("raw_current_delta_failure_count"),
        len(final_sets["current"]),
    ):
        failures.append("DESCENDANT_HISTORY_RAW_CURRENT_COUNT_MISMATCH")
    report_head = str(raw_report.get("head_sha", ""))
    if supplement.get("raw_report_head_sha") != report_head or not _is_commit(report_head):
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_HEAD_MISMATCH")
    if raw_report.get("include_worktree") is not False:
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_NOT_COMMITTED_ONLY")
    if raw_report.get("evaluated_source") != "COMMITTED_HEAD":
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_SOURCE_MISMATCH")
    if raw_report.get("merge_base_sha") != AUTHORIZATION_BASE_HEAD_SHA:
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_BASE_MISMATCH")
    report_tree = ""
    if _is_commit(report_head):
        try:
            report_tree = _git(root, "rev-parse", f"{report_head}^{{tree}}")
        except ValueError:
            report_tree = ""
    if supplement.get("raw_report_tree_sha") != report_tree or not _is_commit(report_tree):
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_TREE_MISMATCH")
    if (
        not _is_ancestor(root, AUTHORIZATION_BASE_HEAD_SHA, report_head)
        or not _is_ancestor(root, report_head, evaluated_head)
    ):
        failures.append("DESCENDANT_HISTORY_RAW_REPORT_HEAD_ANCESTRY_INVALID")
    try:
        scanner_sha = sha256_file(scanner_path)
    except OSError:
        scanner_sha = ""
        failures.append("DESCENDANT_HISTORY_SCANNER_UNREADABLE")
    scanner_at_report = _git_bytes(
        root, report_head, DESCENDANT_HISTORY_SCANNER_REL.as_posix()
    ) if _is_commit(report_head) else None
    scanner_at_report_sha = (
        sha256_bytes(scanner_at_report) if scanner_at_report is not None else ""
    )
    if supplement.get("scanner_tool_sha256") != scanner_at_report_sha or (
        require_live_scanner_bytes and scanner_sha != scanner_at_report_sha
    ):
        failures.append("DESCENDANT_HISTORY_SCANNER_SHA256_MISMATCH")
    baseline_scanner_bytes = _git_bytes(
        root,
        AUTHORIZATION_BASE_HEAD_SHA,
        DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
    )
    baseline_scanner_sha = (
        sha256_bytes(baseline_scanner_bytes)
        if baseline_scanner_bytes is not None
        else ""
    )
    if supplement.get("baseline_scanner_tool_sha256") != baseline_scanner_sha:
        failures.append("DESCENDANT_HISTORY_BASELINE_SCANNER_SHA256_MISMATCH")

    manifest_bytes = (
        _git_bytes(root, report_head, DYNAMIC_REFERENCE_MANIFEST_REL.as_posix())
        if _is_commit(report_head)
        else None
    )
    manifest_sha = sha256_bytes(manifest_bytes) if manifest_bytes is not None else ""
    target_to_dynamic_reference_ids: dict[str, list[str]] = {}
    try:
        manifest_document = json.loads(
            (manifest_bytes or b"").decode("utf-8-sig"),
            object_pairs_hook=_strict_object,
        )
    except (UnicodeDecodeError, json.JSONDecodeError, DuplicateJsonKeyError):
        manifest_document = {}
        failures.append("DESCENDANT_HISTORY_DYNAMIC_REFERENCE_MANIFEST_INVALID")
    entries = manifest_document.get("entries", []) if isinstance(manifest_document, dict) else []
    if not isinstance(entries, list):
        entries = []
        failures.append("DESCENDANT_HISTORY_DYNAMIC_REFERENCE_ENTRY_SET_INVALID")
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        reference_id = str(entry.get("dynamic_reference_id", ""))
        targets = entry.get("resolved_targets", [])
        if not reference_id or not isinstance(targets, list):
            continue
        for target in targets:
            normalized_target = normalize_path(str(target))
            if normalized_target:
                target_to_dynamic_reference_ids.setdefault(normalized_target, []).append(
                    reference_id
                )
    for target in target_to_dynamic_reference_ids:
        target_to_dynamic_reference_ids[target] = sorted(
            set(target_to_dynamic_reference_ids[target])
        )

    dispositions = supplement.get("frozen_identity_disposition_by_failure")
    if not isinstance(dispositions, dict) or set(dispositions) != missing_frozen_fingerprints:
        failures.append("DESCENDANT_HISTORY_FROZEN_DISPOSITION_SET_MISMATCH")
        dispositions = dispositions if isinstance(dispositions, dict) else {}
    verified_dispositions: dict[str, dict[str, Any]] = {}
    used_successors: set[str] = set()
    for fingerprint in sorted(missing_frozen_fingerprints):
        row_failure_count = len(failures)
        row = dispositions.get(fingerprint)
        frozen_identity = frozen_identities.get(fingerprint)
        if not isinstance(row, dict) or set(row) != set(FROZEN_IDENTITY_DISPOSITION_FIELDS):
            failures.append(f"DESCENDANT_HISTORY_DISPOSITION_FIELD_SET_MISMATCH:{fingerprint}")
            continue
        if not isinstance(frozen_identity, dict) or frozen_identity.get("bucket") != "HISTORICAL":
            failures.append(f"DESCENDANT_HISTORY_DISPOSITION_FROZEN_IDENTITY_UNRESOLVED:{fingerprint}")
            continue
        for field, expected in (
            ("failure_fingerprint", fingerprint),
            ("raw_failure", frozen_identity.get("raw_failure")),
            ("rule_id", frozen_identity.get("rule_id")),
            ("baseline_scanner_tool_sha256", baseline_scanner_sha),
            ("live_scanner_tool_sha256", scanner_at_report_sha),
            ("subject_kind", frozen_identity.get("subject_kind")),
            ("subject_value", frozen_identity.get("subject_value")),
            ("wildcard_count", 0),
        ):
            if row.get(field) != expected:
                failures.append(
                    f"DESCENDANT_HISTORY_DISPOSITION_{field.upper()}_MISMATCH:{fingerprint}"
                )
        disposition = str(row.get("disposition", ""))
        if disposition not in ALLOWED_FROZEN_IDENTITY_DISPOSITIONS:
            failures.append(f"DESCENDANT_HISTORY_DISPOSITION_KIND_INVALID:{fingerprint}")
        subject_value = normalize_path(str(frozen_identity.get("subject_value", "")))
        if (
            not subject_value
            or subject_value != frozen_identity.get("subject_value")
            or any(char in subject_value for char in "*?[]")
        ):
            failures.append(f"DESCENDANT_HISTORY_DISPOSITION_SUBJECT_NOT_EXACT:{fingerprint}")
        old_commit = _resolve_commit_prefix(
            root, str(frozen_identity.get("transition_old_prefix", ""))
        )
        new_commit = _resolve_commit_prefix(
            root, str(frozen_identity.get("transition_new_prefix", ""))
        )
        direct_parent = ""
        if new_commit:
            try:
                direct_parent = _git(root, "rev-parse", f"{new_commit}^1")
            except ValueError:
                direct_parent = ""
        if not old_commit or not new_commit or direct_parent != old_commit:
            failures.append(f"DESCENDANT_HISTORY_DISPOSITION_TRANSITION_INVALID:{fingerprint}")
        if row.get("transition_old_sha") != old_commit:
            failures.append(f"DESCENDANT_HISTORY_DISPOSITION_TRANSITION_OLD_MISMATCH:{fingerprint}")
        if row.get("transition_new_sha") != new_commit:
            failures.append(f"DESCENDANT_HISTORY_DISPOSITION_TRANSITION_NEW_MISMATCH:{fingerprint}")
        if new_commit and report_head and not _is_ancestor(root, new_commit, report_head):
            failures.append(f"DESCENDANT_HISTORY_DISPOSITION_TRANSITION_ANCESTRY_INVALID:{fingerprint}")
        evidence = row.get("evidence")
        successor_fingerprint = str(row.get("successor_failure_fingerprint", ""))
        if disposition == EXACT_SUCCESSOR_FINGERPRINT_MAPPING:
            if (
                not isinstance(evidence, dict)
                or set(evidence) != set(SUCCESSOR_DISPOSITION_EVIDENCE_FIELDS)
            ):
                failures.append(f"DESCENDANT_HISTORY_SUCCESSOR_EVIDENCE_FIELD_SET_MISMATCH:{fingerprint}")
                evidence = evidence if isinstance(evidence, dict) else {}
            successor_identity = final_identities.get(successor_fingerprint)
            if (
                successor_fingerprint not in descendant_fingerprints
                or successor_fingerprint in used_successors
                or not isinstance(successor_identity, dict)
            ):
                failures.append(f"DESCENDANT_HISTORY_SUCCESSOR_FINGERPRINT_INVALID:{fingerprint}")
                successor_identity = {}
            used_successors.add(successor_fingerprint)
            if (
                successor_identity.get("rule_id") != frozen_identity.get("rule_id")
                or successor_identity.get("subject_kind") != frozen_identity.get("subject_kind")
                or successor_identity.get("subject_value") != frozen_identity.get("subject_value")
            ):
                failures.append(f"DESCENDANT_HISTORY_SUCCESSOR_SUBJECT_MISMATCH:{fingerprint}")
            successor_old = _resolve_commit_prefix(
                root, str(successor_identity.get("transition_old_prefix", ""))
            )
            successor_new = _resolve_commit_prefix(
                root, str(successor_identity.get("transition_new_prefix", ""))
            )
            successor_parent = ""
            if successor_new:
                try:
                    successor_parent = _git(root, "rev-parse", f"{successor_new}^1")
                except ValueError:
                    successor_parent = ""
            if not successor_old or not successor_new or successor_parent != successor_old:
                failures.append(f"DESCENDANT_HISTORY_SUCCESSOR_TRANSITION_INVALID:{fingerprint}")
            for field, expected in (
                ("evidence_kind", "EXACT_LIVE_RAW_SUCCESSOR_IDENTITY"),
                ("baseline_raw_report_sha256", AUTHORIZED_BASELINE_REPORT_SHA256),
                ("live_raw_report_sha256", raw_report_sha),
                ("successor_raw_failure", successor_identity.get("raw_failure")),
                ("successor_rule_id", successor_identity.get("rule_id")),
                ("successor_transition_old_sha", successor_old),
                ("successor_transition_new_sha", successor_new),
                ("successor_subject_kind", successor_identity.get("subject_kind")),
                ("successor_subject_value", successor_identity.get("subject_value")),
            ):
                if evidence.get(field) != expected:
                    failures.append(
                        f"DESCENDANT_HISTORY_SUCCESSOR_EVIDENCE_{field.upper()}_MISMATCH:{fingerprint}"
                    )
        elif disposition == EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT:
            if successor_fingerprint:
                failures.append(f"DESCENDANT_HISTORY_FALSE_COMPONENT_SUCCESSOR_UNEXPECTED:{fingerprint}")
            if (
                not isinstance(evidence, dict)
                or set(evidence) != set(FALSE_COMPONENT_RETIREMENT_EVIDENCE_FIELDS)
            ):
                failures.append(f"DESCENDANT_HISTORY_FALSE_COMPONENT_EVIDENCE_FIELD_SET_MISMATCH:{fingerprint}")
                evidence = evidence if isinstance(evidence, dict) else {}
            changed_paths: set[str] = set()
            if old_commit and new_commit:
                try:
                    changed_paths = {
                        normalize_path(value)
                        for value in _git(
                            root, "diff", "--name-only", old_commit, new_commit
                        ).splitlines()
                        if value.strip()
                    }
                except ValueError:
                    changed_paths = set()
            exact_dynamic_ids = target_to_dynamic_reference_ids.get(subject_value, [])
            evidence_dynamic_ids = evidence.get("dynamic_reference_ids")
            rendered_dynamic_ids = (
                [str(value) for value in evidence_dynamic_ids]
                if isinstance(evidence_dynamic_ids, list)
                else []
            )
            if (
                frozen_identity.get("rule_id") != "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
                or frozen_identity.get("subject_kind") != "path"
            ):
                failures.append(f"DESCENDANT_HISTORY_FALSE_COMPONENT_RULE_INVALID:{fingerprint}")
            if subject_value in changed_paths or evidence.get("subject_directly_changed") is not False:
                failures.append(f"DESCENDANT_HISTORY_FALSE_COMPONENT_DIRECT_CHANGE_INVALID:{fingerprint}")
            if not exact_dynamic_ids or rendered_dynamic_ids != exact_dynamic_ids:
                failures.append(f"DESCENDANT_HISTORY_FALSE_COMPONENT_DYNAMIC_TARGET_INVALID:{fingerprint}")
            for field, expected in (
                ("evidence_kind", "EXACT_DYNAMIC_REFERENCE_TARGET_NOT_DIRECT_TRANSITION_CHANGE"),
                ("baseline_raw_report_sha256", AUTHORIZED_BASELINE_REPORT_SHA256),
                ("live_raw_report_sha256", raw_report_sha),
                ("dynamic_reference_manifest_path", DYNAMIC_REFERENCE_MANIFEST_REL.as_posix()),
                ("dynamic_reference_manifest_blob_sha256", manifest_sha),
                ("resolved_target", f"res://{subject_value}"),
            ):
                if evidence.get(field) != expected:
                    failures.append(
                        f"DESCENDANT_HISTORY_FALSE_COMPONENT_EVIDENCE_{field.upper()}_MISMATCH:{fingerprint}"
                    )
        if len(failures) == row_failure_count:
            verified_dispositions[fingerprint] = row
    if set(verified_dispositions) != missing_frozen_fingerprints:
        failures.append("DESCENDANT_HISTORY_FROZEN_DISPOSITION_COVERAGE_INVALID")
    repaired = supplement.get("repaired_frozen_current_fingerprints")
    if not isinstance(repaired, list):
        repaired = []
        failures.append("DESCENDANT_HISTORY_REPAIRED_CURRENT_LIST_INVALID")
    repaired_rendered = [str(value) for value in repaired]
    if (
        repaired_rendered != sorted(repaired_rendered)
        or len(repaired_rendered) != len(set(repaired_rendered))
        or set(repaired_rendered) != frozen_sets["current"]
    ):
        failures.append("DESCENDANT_HISTORY_REPAIRED_CURRENT_SET_MISMATCH")
    if not _is_exact_int(
        supplement.get("repaired_frozen_current_failure_count"),
        len(frozen_sets["current"]),
    ):
        failures.append("DESCENDANT_HISTORY_REPAIRED_CURRENT_COUNT_MISMATCH")
    if supplement.get("repaired_frozen_current_fingerprint_set_sha256") != _line_set_sha(
        repaired_rendered
    ):
        failures.append("DESCENDANT_HISTORY_REPAIRED_CURRENT_SET_SHA256_MISMATCH")
    bindings = supplement.get("identity_binding_by_failure")
    if not isinstance(bindings, dict) or set(bindings) != descendant_fingerprints:
        failures.append("DESCENDANT_HISTORY_IDENTITY_BINDING_SET_MISMATCH")
        bindings = bindings if isinstance(bindings, dict) else {}
    mapped_current: set[str] = set()
    authorized_identities: dict[str, dict[str, str]] = {}
    for fingerprint in sorted(descendant_fingerprints):
        binding = bindings.get(fingerprint)
        raw_identity = final_identities.get(fingerprint)
        if not isinstance(binding, dict) or set(binding) != set(DESCENDANT_HISTORY_IDENTITY_FIELDS):
            failures.append(f"DESCENDANT_HISTORY_IDENTITY_FIELD_SET_MISMATCH:{fingerprint}")
            continue
        if not isinstance(raw_identity, dict) or raw_identity.get("bucket") != "HISTORICAL":
            failures.append(f"DESCENDANT_HISTORY_RAW_IDENTITY_UNRESOLVED:{fingerprint}")
            continue
        for field, expected in (
            ("failure_fingerprint", fingerprint),
            ("raw_failure", raw_identity.get("raw_failure")),
            ("rule_id", raw_identity.get("rule_id")),
        ):
            if binding.get(field) != expected:
                failures.append(f"DESCENDANT_HISTORY_IDENTITY_{field.upper()}_MISMATCH:{fingerprint}")
        old_commit = _resolve_commit_prefix(
            root, str(raw_identity.get("transition_old_prefix", ""))
        )
        new_commit = _resolve_commit_prefix(
            root, str(raw_identity.get("transition_new_prefix", ""))
        )
        if (
            not old_commit
            or not new_commit
            or _git(root, "rev-parse", f"{new_commit}^1") != old_commit
        ):
            failures.append(f"DESCENDANT_HISTORY_TRANSITION_NOT_DIRECT_PARENT:{fingerprint}")
        if binding.get("transition_old_sha") != old_commit:
            failures.append(f"DESCENDANT_HISTORY_TRANSITION_OLD_MISMATCH:{fingerprint}")
        if binding.get("transition_new_sha") != new_commit:
            failures.append(f"DESCENDANT_HISTORY_TRANSITION_NEW_MISMATCH:{fingerprint}")
        if binding.get("source_commit_sha") != new_commit:
            failures.append(f"DESCENDANT_HISTORY_SOURCE_COMMIT_MISMATCH:{fingerprint}")
        if not _is_ancestor(root, new_commit, report_head):
            failures.append(f"DESCENDANT_HISTORY_SOURCE_COMMIT_ANCESTRY_INVALID:{fingerprint}")
        source_path = normalize_path(str(binding.get("source_path", "")))
        if (
            not source_path
            or source_path != binding.get("source_path")
            or source_path.startswith(("/", "../"))
            or source_path.endswith("/")
            or "/../" in source_path
            or any(char in source_path for char in "*?[]")
        ):
            failures.append(f"DESCENDANT_HISTORY_SOURCE_PATH_INVALID:{fingerprint}")
        subject_kind = str(raw_identity.get("subject_kind", ""))
        subject_value = normalize_path(str(raw_identity.get("subject_value", "")))
        if subject_kind == "path":
            if source_path != subject_value:
                failures.append(f"DESCENDANT_HISTORY_SOURCE_PATH_RAW_MISMATCH:{fingerprint}")
            if binding.get("source_component_id") != "":
                failures.append(f"DESCENDANT_HISTORY_SOURCE_COMPONENT_UNEXPECTED:{fingerprint}")
        elif subject_kind == "component_id":
            if binding.get("source_component_id") != subject_value:
                failures.append(f"DESCENDANT_HISTORY_SOURCE_COMPONENT_MISMATCH:{fingerprint}")
            try:
                changed_paths = {
                    normalize_path(value)
                    for value in _git(root, "diff", "--name-only", old_commit, new_commit).splitlines()
                    if value.strip()
                }
            except ValueError:
                changed_paths = set()
            if source_path not in changed_paths:
                failures.append(f"DESCENDANT_HISTORY_COMPONENT_SOURCE_PATH_NOT_TOUCHED:{fingerprint}")
        else:
            failures.append(f"DESCENDANT_HISTORY_RAW_SUBJECT_UNRESOLVED:{fingerprint}")
        source_bytes = _git_bytes(root, new_commit, source_path) if new_commit else None
        source_sha = sha256_bytes(source_bytes) if source_bytes is not None else ""
        if source_bytes is None or binding.get("source_blob_sha256") != source_sha:
            failures.append(f"DESCENDANT_HISTORY_SOURCE_BLOB_MISMATCH:{fingerprint}")
        mapped = binding.get("repaired_frozen_current_fingerprints")
        if not isinstance(mapped, list):
            mapped = []
        mapped_rendered = [str(value) for value in mapped]
        if (
            not mapped_rendered
            or mapped_rendered != sorted(mapped_rendered)
            or len(mapped_rendered) != len(set(mapped_rendered))
            or not set(mapped_rendered).issubset(frozen_sets["current"])
        ):
            failures.append(f"DESCENDANT_HISTORY_REPAIR_BINDING_INVALID:{fingerprint}")
        mapped_current.update(mapped_rendered)
        authorized_identity = dict(raw_identity)
        authorized_identity.update({
            "authority_origin": "DESCENDANT_HISTORY_SUPPLEMENT",
            "source_path": source_path,
            "supplement_raw_report_head_sha": report_head,
        })
        authorized_identities[fingerprint] = authorized_identity
    if mapped_current != frozen_sets["current"] or mapped_current != set(repaired_rendered):
        failures.append("DESCENDANT_HISTORY_REPAIR_BINDING_COVERAGE_MISMATCH")
    live_identities: dict[str, dict[str, Any]] = {}
    for fingerprint in sorted(final_sets["historical"]):
        if fingerprint in authorized_identities:
            live_identities[fingerprint] = dict(authorized_identities[fingerprint])
            continue
        identity = frozen_identities.get(fingerprint, final_identities.get(fingerprint))
        if not isinstance(identity, dict):
            failures.append(f"DESCENDANT_HISTORY_LIVE_IDENTITY_UNRESOLVED:{fingerprint}")
            continue
        row = dict(identity)
        row["authority_origin"] = "FROZEN_FULL_CONVERGENCE_BASELINE"
        live_identities[fingerprint] = row
    registered_identities: dict[str, dict[str, Any]] = {}
    for fingerprint in sorted(frozen_sets["historical"]):
        identity = frozen_identities.get(fingerprint)
        if not isinstance(identity, dict):
            failures.append(f"DESCENDANT_HISTORY_REGISTERED_IDENTITY_UNRESOLVED:{fingerprint}")
            continue
        row = dict(identity)
        row["authority_origin"] = "FROZEN_FULL_CONVERGENCE_BASELINE"
        if fingerprint in verified_dispositions:
            row["non_live_disposition"] = verified_dispositions[fingerprint]
        registered_identities[fingerprint] = row
    registered_identities.update(
        {
            fingerprint: dict(identity)
            for fingerprint, identity in authorized_identities.items()
        }
    )
    failures = sorted(set(failures))
    return {
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
        "supplement_sha256": supplement_sha,
        "authorized_historical_fingerprints": set(live_identities),
        "authorized_identity_by_fingerprint": live_identities,
        "registered_historical_fingerprints": set(registered_identities),
        "registered_identity_by_fingerprint": registered_identities,
        "dispositioned_historical_fingerprints": set(verified_dispositions),
        "frozen_identity_disposition_by_failure": verified_dispositions,
        "raw_report_head_sha": report_head,
        "frozen_current_identity_count": len(frozen_identities) - len(frozen_sets["historical"]),
    }


def validate_frozen_descendant_history_predecessor(
    root: Path,
    *,
    evaluated_head: str,
    baseline_report_path: Path,
) -> dict[str, Any]:
    """Validate the immutable 570d v2 receipt without treating it as live."""

    supplement_path = root / PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_REL
    raw_report_path = root / PREVIOUS_DESCENDANT_HISTORY_RAW_REL
    failures: list[str] = []
    try:
        supplement_bytes = supplement_path.read_bytes()
        raw_bytes = raw_report_path.read_bytes()
    except OSError:
        supplement_bytes = b""
        raw_bytes = b""
        failures.append("DESCENDANT_HISTORY_PREDECESSOR_INPUT_MISSING")
    if sha256_bytes(supplement_bytes) != PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA256:
        failures.append("DESCENDANT_HISTORY_PREDECESSOR_SUPPLEMENT_SHA256_MISMATCH")
    if sha256_bytes(raw_bytes) != PREVIOUS_DESCENDANT_HISTORY_RAW_SHA256:
        failures.append("DESCENDANT_HISTORY_PREDECESSOR_RAW_SHA256_MISMATCH")
    committed_supplement = _git_bytes(
        root, evaluated_head, PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_REL.as_posix()
    )
    committed_raw = _git_bytes(
        root, evaluated_head, PREVIOUS_DESCENDANT_HISTORY_RAW_REL.as_posix()
    )
    if committed_supplement != supplement_bytes or committed_raw != raw_bytes:
        failures.append("DESCENDANT_HISTORY_PREDECESSOR_COMMITTED_BYTES_MISMATCH")
    try:
        supplement = load_json_strict(supplement_path)
        raw_report = load_json_strict(raw_report_path)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        supplement = {}
        raw_report = {}
        failures.append("DESCENDANT_HISTORY_PREDECESSOR_JSON_INVALID")
    for field, expected in (
        ("schema_version", DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION),
        ("supplement_id", DESCENDANT_HISTORY_SUPPLEMENT_ID),
        ("raw_report_path", PREVIOUS_DESCENDANT_HISTORY_RAW_REL.as_posix()),
        ("raw_report_sha256", PREVIOUS_DESCENDANT_HISTORY_RAW_SHA256),
        ("raw_report_head_sha", PREVIOUS_DESCENDANT_HISTORY_RAW_HEAD),
        ("raw_report_tree_sha", PREVIOUS_DESCENDANT_HISTORY_RAW_TREE),
        ("scanner_tool_sha256", PREVIOUS_DESCENDANT_HISTORY_SCANNER_SHA256),
    ):
        if supplement.get(field) != expected:
            failures.append(f"DESCENDANT_HISTORY_PREDECESSOR_{field.upper()}_MISMATCH")
    if raw_report.get("head_sha") != PREVIOUS_DESCENDANT_HISTORY_RAW_HEAD:
        failures.append("DESCENDANT_HISTORY_PREDECESSOR_RAW_HEAD_MISMATCH")
    scanner_bytes = _git_bytes(
        root,
        PREVIOUS_DESCENDANT_HISTORY_RAW_HEAD,
        DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
    )
    if (
        scanner_bytes is None
        or sha256_bytes(scanner_bytes) != PREVIOUS_DESCENDANT_HISTORY_SCANNER_SHA256
    ):
        failures.append("DESCENDANT_HISTORY_PREDECESSOR_SCANNER_BLOB_MISMATCH")
    result = _validate_descendant_history_supplement_core(
        root,
        supplement_path,
        raw_report_path,
        root / DESCENDANT_HISTORY_SCANNER_REL,
        evaluated_head=evaluated_head,
        baseline_report_path=baseline_report_path,
        expected_schema_version=DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION,
        expected_supplement_id=DESCENDANT_HISTORY_SUPPLEMENT_ID,
        expected_fields=DESCENDANT_HISTORY_SUPPLEMENT_FIELDS,
        require_live_scanner_bytes=False,
    )
    result["failures"] = sorted(set(result.get("failures", [])) | set(failures))
    result["status"] = "PASS" if not result["failures"] else "FAIL"
    return result


def validate_descendant_history_successor_schema(
    root: Path,
    *,
    evaluated_head: str | None = None,
) -> list[str]:
    failures: list[str] = []
    path = root / SUCCESSOR_SCHEMA_REL
    try:
        schema = load_json_strict(path)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        return ["DESCENDANT_HISTORY_V3_SCHEMA_INVALID"]
    successor_seal_failures = _committed_blob_seal_failures(
        root,
        path,
        SUCCESSOR_SCHEMA_SHA256,
        evaluated_head=evaluated_head,
        code_prefix="DESCENDANT_HISTORY_V3_SCHEMA",
    )
    if successor_seal_failures:
        failures.append("DESCENDANT_HISTORY_V3_SCHEMA_SHA256_MISMATCH")
        failures.extend(successor_seal_failures)
    predecessor_path = root / PREDECESSOR_SCHEMA_REL
    if (
        schema.get("previous_schema_path") != PREDECESSOR_SCHEMA_REL.as_posix()
        or schema.get("previous_schema_sha256") != PREDECESSOR_SCHEMA_SHA256
    ):
        failures.append("DESCENDANT_HISTORY_V3_PREDECESSOR_SCHEMA_SEAL_INVALID")
    predecessor_seal_failures = _committed_blob_seal_failures(
        root,
        predecessor_path,
        PREDECESSOR_SCHEMA_SHA256,
        evaluated_head=evaluated_head,
        code_prefix="DESCENDANT_HISTORY_V3_PREDECESSOR_SCHEMA",
    )
    if predecessor_seal_failures:
        failures.append("DESCENDANT_HISTORY_V3_PREDECESSOR_SCHEMA_SEAL_INVALID")
        failures.extend(predecessor_seal_failures)
    expected = {
        "active_descendant_history_supplement_schema_version": DESCENDANT_HISTORY_SUPPLEMENT_V3_SCHEMA_VERSION,
        "active_descendant_history_supplement_id": DESCENDANT_HISTORY_SUPPLEMENT_V3_ID,
        "frozen_predecessor_supplement_path": PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_REL.as_posix(),
        "frozen_predecessor_supplement_sha256": PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA256,
        "directory_discovery_allowed": False,
        "wildcard_membership_allowed": False,
        "future_failure_auto_membership_allowed": False,
        "old_evidence_mutation_allowed": False,
        "previous_descendant_identity_drop_allowed": False,
        "scanner_weakening_allowed": False,
        "active_raw_report_path": DESCENDANT_HISTORY_V3_RAW_REL.as_posix(),
        "active_raw_report_sha256": DESCENDANT_HISTORY_V3_RAW_SHA256,
        "active_raw_report_head_sha": DESCENDANT_HISTORY_V3_RAW_HEAD,
        "active_raw_report_tree_sha": DESCENDANT_HISTORY_V3_RAW_TREE,
        "active_scanner_sha256": DESCENDANT_HISTORY_V3_SCANNER_SHA256,
        "active_raw_failure_count": DESCENDANT_HISTORY_V3_RAW_FAILURE_COUNT,
        "active_raw_historical_failure_count": DESCENDANT_HISTORY_V3_RAW_HISTORICAL_COUNT,
        "active_raw_current_failure_count": DESCENDANT_HISTORY_V3_RAW_CURRENT_COUNT,
        "active_registered_identity_count": DESCENDANT_HISTORY_V3_REGISTERED_IDENTITY_COUNT,
    }
    if any(schema.get(field) != value for field, value in expected.items()):
        failures.append("DESCENDANT_HISTORY_V3_SCHEMA_AUTHORITY_MISMATCH")
    if tuple(sorted(schema.get("scanner_evolution_required_fields", []))) != (
        DESCENDANT_HISTORY_SCANNER_EVOLUTION_FIELDS
    ):
        failures.append("DESCENDANT_HISTORY_V3_SCHEMA_SCANNER_FIELDS_MISMATCH")
    if set(schema.get("successor_required_additional_fields", [])) != {
        "previous_supplement_path", "previous_supplement_sha256", "scanner_evolution"
    }:
        failures.append("DESCENDANT_HISTORY_V3_SCHEMA_ADDITIONAL_FIELDS_MISMATCH")
    return failures


def _validate_descendant_history_supplement_v3(
    root: Path,
    supplement_path: Path | None,
    raw_report_path: Path | None,
    scanner_path: Path | None,
    *,
    evaluated_head: str,
    baseline_report_path: Path,
    expected_raw_head: str = DESCENDANT_HISTORY_V3_RAW_HEAD,
    expected_raw_tree: str = DESCENDANT_HISTORY_V3_RAW_TREE,
    expected_raw_sha256: str = DESCENDANT_HISTORY_V3_RAW_SHA256,
    expected_scanner_sha256: str = DESCENDANT_HISTORY_V3_SCANNER_SHA256,
) -> dict[str, Any]:
    result = _validate_descendant_history_supplement_core(
        root,
        supplement_path,
        raw_report_path,
        scanner_path,
        evaluated_head=evaluated_head,
        baseline_report_path=baseline_report_path,
        expected_schema_version=DESCENDANT_HISTORY_SUPPLEMENT_V3_SCHEMA_VERSION,
        expected_supplement_id=DESCENDANT_HISTORY_SUPPLEMENT_V3_ID,
        expected_fields=DESCENDANT_HISTORY_SUPPLEMENT_V3_FIELDS,
    )
    failures = list(result.get("failures", []))
    failures.extend(
        validate_descendant_history_successor_schema(
            root,
            evaluated_head=evaluated_head,
        )
    )
    if supplement_path is None:
        return result
    if _exact_repo_relative(root, supplement_path) != DESCENDANT_HISTORY_V3_SUPPLEMENT_REL.as_posix():
        failures.append("DESCENDANT_HISTORY_V3_SUPPLEMENT_PATH_MISMATCH")
    if raw_report_path is None or _exact_repo_relative(
        root, raw_report_path
    ) != DESCENDANT_HISTORY_V3_RAW_REL.as_posix():
        failures.append("DESCENDANT_HISTORY_V3_RAW_REPORT_PATH_MISMATCH")
    try:
        supplement = load_json_strict(supplement_path)
        previous = load_json_strict(root / PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_REL)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        failures.append("DESCENDANT_HISTORY_V3_PREDECESSOR_JSON_INVALID")
        supplement = {}
        previous = {}
    sealed_raw_expectations = {
        "raw_report_head_sha": expected_raw_head,
        "raw_report_tree_sha": expected_raw_tree,
        "raw_report_sha256": expected_raw_sha256,
        "scanner_tool_sha256": expected_scanner_sha256,
        "raw_failure_count": DESCENDANT_HISTORY_V3_RAW_FAILURE_COUNT,
        "raw_historical_failure_count": DESCENDANT_HISTORY_V3_RAW_HISTORICAL_COUNT,
        "raw_current_delta_failure_count": DESCENDANT_HISTORY_V3_RAW_CURRENT_COUNT,
    }
    for field, expected in sealed_raw_expectations.items():
        if supplement.get(field) != expected:
            failures.append(f"DESCENDANT_HISTORY_V3_SEALED_{field.upper()}_MISMATCH")
    if len(result.get("registered_historical_fingerprints", set())) != (
        DESCENDANT_HISTORY_V3_REGISTERED_IDENTITY_COUNT
    ):
        failures.append("DESCENDANT_HISTORY_V3_REGISTERED_IDENTITY_COUNT_MISMATCH")
    predecessor = validate_frozen_descendant_history_predecessor(
        root,
        evaluated_head=evaluated_head,
        baseline_report_path=baseline_report_path,
    )
    if predecessor.get("status") != "PASS":
        failures.extend(
            f"DESCENDANT_HISTORY_V3_PREDECESSOR_INVALID:{value}"
            for value in predecessor.get("failures", [])
        )
    if (
        supplement.get("previous_supplement_path")
        != PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_REL.as_posix()
    ):
        failures.append("DESCENDANT_HISTORY_V3_PREVIOUS_SUPPLEMENT_PATH_MISMATCH")
    if (
        supplement.get("previous_supplement_sha256")
        != PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA256
    ):
        failures.append("DESCENDANT_HISTORY_V3_PREVIOUS_SUPPLEMENT_SHA256_MISMATCH")

    previous_descendants = {
        str(value) for value in previous.get("descendant_history_fingerprints", [])
    }
    current_descendants = {
        str(value) for value in supplement.get("descendant_history_fingerprints", [])
    }
    if not previous_descendants.issubset(current_descendants):
        failures.append("DESCENDANT_HISTORY_V3_PREVIOUS_DESCENDANT_IDENTITY_DROPPED")
    previous_dispositions = previous.get("frozen_identity_disposition_by_failure", {})
    current_dispositions = supplement.get("frozen_identity_disposition_by_failure", {})
    stable_fields = (
        "disposition", "failure_fingerprint", "raw_failure", "rule_id",
        "subject_kind", "subject_value", "successor_failure_fingerprint",
        "transition_new_sha", "transition_old_sha", "wildcard_count",
    )
    if not isinstance(previous_dispositions, dict) or not isinstance(current_dispositions, dict):
        failures.append("DESCENDANT_HISTORY_V3_PREDECESSOR_DISPOSITION_SET_INVALID")
    else:
        for fingerprint, old_row in previous_dispositions.items():
            new_row = current_dispositions.get(fingerprint)
            if not isinstance(old_row, dict) or not isinstance(new_row, dict) or any(
                old_row.get(field) != new_row.get(field) for field in stable_fields
            ):
                failures.append(
                    f"DESCENDANT_HISTORY_V3_PREDECESSOR_DISPOSITION_DRIFT:{fingerprint}"
                )

    evolution = supplement.get("scanner_evolution")
    if not isinstance(evolution, dict) or set(evolution) != set(
        DESCENDANT_HISTORY_SCANNER_EVOLUTION_FIELDS
    ):
        failures.append("DESCENDANT_HISTORY_V3_SCANNER_EVOLUTION_FIELD_SET_MISMATCH")
        evolution = evolution if isinstance(evolution, dict) else {}
    for field in (
        "removed_rule_count",
        "scanner_change_commit_count",
        "scanner_history_depth_reduction_count",
        "scanner_scope_reduction_count",
        "scanner_severity_downgrade_count",
    ):
        if not _is_int(evolution.get(field)):
            failures.append(f"DESCENDANT_HISTORY_V3_{field.upper()}_TYPE_INVALID")
    expected_scalars = {
        "evolution_kind": "FAIL_CLOSED_VALIDATION_STRENGTHENING",
        "from_raw_report_head_sha": PREVIOUS_DESCENDANT_HISTORY_RAW_HEAD,
        "from_raw_report_tree_sha": PREVIOUS_DESCENDANT_HISTORY_RAW_TREE,
        "from_scanner_tool_sha256": PREVIOUS_DESCENDANT_HISTORY_SCANNER_SHA256,
        "removed_rule_count": 0,
        "scanner_history_depth_reduction_count": 0,
        "scanner_scope_reduction_count": 0,
        "scanner_severity_downgrade_count": 0,
        "scanner_tool_path": DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
        "to_raw_report_head_sha": supplement.get("raw_report_head_sha"),
        "to_raw_report_tree_sha": supplement.get("raw_report_tree_sha"),
        "to_scanner_tool_sha256": supplement.get("scanner_tool_sha256"),
        "weakening_allowed": False,
    }
    for field, expected in expected_scalars.items():
        if evolution.get(field) != expected:
            failures.append(f"DESCENDANT_HISTORY_V3_{field.upper()}_MISMATCH")
    to_head = str(supplement.get("raw_report_head_sha", ""))
    try:
        change_commits = [
            value
            for value in _git(
                root,
                "rev-list",
                "--reverse",
                f"{PREVIOUS_DESCENDANT_HISTORY_RAW_HEAD}..{to_head}",
                "--",
                DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
            ).splitlines()
            if value
        ]
    except ValueError:
        change_commits = []
        failures.append("DESCENDANT_HISTORY_V3_SCANNER_EVOLUTION_GIT_INVALID")
    declared_commits = evolution.get("scanner_change_commit_shas")
    rendered_commits = (
        [str(value) for value in declared_commits]
        if isinstance(declared_commits, list)
        else []
    )
    sequence_sha = sha256_bytes(("\n".join(change_commits) + "\n").encode("utf-8"))
    if not change_commits or rendered_commits != change_commits:
        failures.append("DESCENDANT_HISTORY_V3_SCANNER_CHANGE_COMMIT_SEQUENCE_MISMATCH")
    if not _is_exact_int(evolution.get("scanner_change_commit_count"), len(change_commits)):
        failures.append("DESCENDANT_HISTORY_V3_SCANNER_CHANGE_COMMIT_COUNT_MISMATCH")
    if evolution.get("scanner_change_commit_sequence_sha256") != sequence_sha:
        failures.append("DESCENDANT_HISTORY_V3_SCANNER_CHANGE_COMMIT_DIGEST_MISMATCH")
    to_scanner = _git_bytes(root, to_head, DESCENDANT_HISTORY_SCANNER_REL.as_posix())
    if (
        to_scanner is None
        or sha256_bytes(to_scanner) != evolution.get("to_scanner_tool_sha256")
    ):
        failures.append("DESCENDANT_HISTORY_V3_TO_SCANNER_BLOB_MISMATCH")
    failures = sorted(set(failures))
    result["failures"] = failures
    result["status"] = "PASS" if not failures else "FAIL"
    return result


def validate_descendant_history_supplement(
    root: Path,
    supplement_path: Path | None,
    raw_report_path: Path | None,
    scanner_path: Path | None,
    *,
    evaluated_head: str,
    baseline_report_path: Path,
) -> dict[str, Any]:
    try:
        document = load_json_strict(supplement_path) if supplement_path is not None else {}
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        document = {}
    is_v3_path = (
        supplement_path is not None
        and _exact_repo_relative(root, supplement_path)
        == DESCENDANT_HISTORY_V3_SUPPLEMENT_REL.as_posix()
    )
    if is_v3_path:
        return _validate_descendant_history_supplement_v3(
            root,
            supplement_path,
            raw_report_path,
            scanner_path,
            evaluated_head=evaluated_head,
            baseline_report_path=baseline_report_path,
        )
    return _validate_descendant_history_supplement_core(
        root,
        supplement_path,
        raw_report_path,
        scanner_path,
        evaluated_head=evaluated_head,
        baseline_report_path=baseline_report_path,
        expected_schema_version=DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION,
        expected_supplement_id=DESCENDANT_HISTORY_SUPPLEMENT_ID,
        expected_fields=DESCENDANT_HISTORY_SUPPLEMENT_FIELDS,
    )


def _artifact_common_failures(
    document: Any,
    manifest: dict[str, Any],
    *,
    expected_schema: str,
    label: str,
) -> list[str]:
    prefix = f"BATCH_ARTIFACT_{label.upper()}"
    if not isinstance(document, dict):
        return [f"{prefix}_NOT_OBJECT"]
    failures: list[str] = []
    expected_fingerprints = [str(value) for value in manifest.get("failure_fingerprints", [])]
    fingerprints = document.get("failure_fingerprints")
    rendered = [str(value) for value in fingerprints] if isinstance(fingerprints, list) else []
    if document.get("schema_version") != expected_schema:
        failures.append(f"{prefix}_SCHEMA_MISMATCH")
    if document.get("batch_id") != manifest.get("batch_id"):
        failures.append(f"{prefix}_BATCH_ID_MISMATCH")
    if rendered != expected_fingerprints:
        failures.append(f"{prefix}_FINGERPRINT_SET_MISMATCH")
    if not _is_exact_int(document.get("failure_count"), len(expected_fingerprints)):
        failures.append(f"{prefix}_FAILURE_COUNT_MISMATCH")
    return failures


def _validate_batch_artifact_document(
    document: Any,
    manifest: dict[str, Any],
    *,
    expected_schema: str,
    kind: str,
    authorized_identities: dict[str, dict[str, str]],
) -> list[str]:
    failures = _artifact_common_failures(
        document,
        manifest,
        expected_schema=expected_schema,
        label=kind,
    )
    if not isinstance(document, dict):
        return failures
    fingerprints = [str(value) for value in manifest.get("failure_fingerprints", [])]
    prefix = f"BATCH_ARTIFACT_{kind.upper()}"
    if kind == "inventory":
        if not _is_exact_int(
            document.get("identity_coverage_percent"), 100
        ) or not _is_exact_int(document.get("unknown_count"), 0):
            failures.append(f"{prefix}_COVERAGE_INVALID")
        rows = document.get("rows")
        if not isinstance(rows, dict) or set(rows) != set(fingerprints):
            failures.append(f"{prefix}_ROW_SET_MISMATCH")
        else:
            for fingerprint, row in rows.items():
                identity = authorized_identities.get(fingerprint, {})
                if not isinstance(row, dict):
                    failures.append(f"{prefix}_ROW_INVALID:{fingerprint}")
                    continue
                if row.get("failure_fingerprint") != fingerprint:
                    failures.append(f"{prefix}_ROW_FINGERPRINT_MISMATCH:{fingerprint}")
                if row.get("raw_failure") != identity.get("raw_failure"):
                    failures.append(f"{prefix}_ROW_RAW_FAILURE_MISMATCH:{fingerprint}")
                if row.get("rule_id") != identity.get("rule_id"):
                    failures.append(f"{prefix}_ROW_RULE_MISMATCH:{fingerprint}")
    elif kind == "classification":
        if not _is_exact_int(
            document.get("unknown_count"), 0
        ) or not _is_exact_int(document.get("wildcard_count"), 0):
            failures.append(f"{prefix}_COUNTS_INVALID")
        classifications = document.get("classifications")
        if not isinstance(classifications, dict) or set(classifications) != set(fingerprints):
            failures.append(f"{prefix}_ROW_SET_MISMATCH")
        else:
            for fingerprint, row in classifications.items():
                if not isinstance(row, dict):
                    failures.append(f"{prefix}_ROW_INVALID:{fingerprint}")
                    continue
                if row.get("failure_fingerprint") != fingerprint:
                    failures.append(f"{prefix}_ROW_FINGERPRINT_MISMATCH:{fingerprint}")
                if row.get("status") != "CLASSIFIED":
                    failures.append(f"{prefix}_ROW_STATUS_INVALID:{fingerprint}")
                if row.get("recommended_disposition") not in ALLOWED_DISPOSITIONS:
                    failures.append(f"{prefix}_ROW_DISPOSITION_INVALID:{fingerprint}")
    elif kind == "negative_checks":
        required_counts = {
            "current_failure_false_accept_count": 0,
            "future_failure_auto_correction_count": 0,
            "wildcard_count": 0,
        }
        if document.get("status") != "PASS":
            failures.append(f"{prefix}_STATUS_INVALID")
        for field, expected in required_counts.items():
            if not _is_exact_int(document.get(field), expected):
                failures.append(f"{prefix}_{field.upper()}_INVALID")
        checks = document.get("checks")
        if not isinstance(checks, dict) or not checks or any(value is not True for value in checks.values()):
            failures.append(f"{prefix}_CHECK_SET_INVALID")
    else:
        review_id = "A" if kind == "review_a" else "B"
        if document.get("review_id") != review_id:
            failures.append(f"{prefix}_REVIEW_ID_INVALID")
        if document.get("status") != "GO":
            failures.append(f"{prefix}_STATUS_INVALID")
        if not _is_exact_int(
            document.get("p0_count"), 0
        ) or not _is_exact_int(document.get("p1_count"), 0):
            failures.append(f"{prefix}_FINDING_COUNT_INVALID")
        if document.get("findings") != []:
            failures.append(f"{prefix}_FINDINGS_NOT_EMPTY")
    return sorted(set(failures))


def validate_batch_artifacts(
    manifest_path: Path,
    manifest: dict[str, Any],
    *,
    authorized_identities: dict[str, dict[str, str]],
) -> list[str]:
    failures: list[str] = []
    for hash_field, (filename, schema_version, kind) in BATCH_ARTIFACT_SPECS.items():
        path = manifest_path.parent / filename
        if not path.is_file():
            failures.append(f"BATCH_ARTIFACT_MISSING:{filename}")
            continue
        expected_hash = manifest.get(hash_field)
        actual_hash = sha256_file(path)
        if actual_hash != expected_hash:
            failures.append(f"BATCH_ARTIFACT_SHA256_MISMATCH:{filename}")
            continue
        try:
            document = load_json_strict(path)
        except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
            failures.append(f"BATCH_ARTIFACT_JSON_INVALID:{filename}")
            continue
        failures.extend(
            _validate_batch_artifact_document(
                document,
                manifest,
                expected_schema=schema_version,
                kind=kind,
                authorized_identities=authorized_identities,
            )
        )
    return sorted(set(failures))


def _classification_record_disposition_failures(
    root: Path,
    manifest_path: Path,
    manifest: dict[str, Any],
) -> list[str]:
    failures: list[str] = []
    classification_path = manifest_path.parent / "batch_classification.json"
    try:
        classification = load_json_strict(classification_path)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        return ["BATCH_CLASSIFICATION_DISPOSITION_MAP_UNREADABLE"]
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
        relative = normalize_path(str(record_binding.get("path", "")))
        try:
            record = load_json_strict(root / relative)
        except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
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
        failures.append("BATCH_CLASSIFICATION_RECORD_DISPOSITION_COVERAGE_MISMATCH")
    for fingerprint in sorted(manifest_fingerprints):
        if classification_by_fingerprint.get(fingerprint) != record_by_fingerprint.get(
            fingerprint
        ):
            failures.append(
                f"BATCH_CLASSIFICATION_RECORD_DISPOSITION_MISMATCH:{fingerprint}"
            )
    return sorted(set(failures))


def validate_schema(root: Path, *, evaluated_head: str | None = None) -> list[str]:
    path = root / SCHEMA_REL
    if not path.is_file():
        return ["FULL_CONVERGENCE_SCHEMA_MISSING"]
    if AUTHORIZED_SCHEMA_SHA256 == "TO_BE_FILLED":
        return ["FULL_CONVERGENCE_SCHEMA_HASH_NOT_AUTHORIZED"]
    schema_seal_failures = _committed_blob_seal_failures(
        root,
        path,
        AUTHORIZED_SCHEMA_SHA256,
        evaluated_head=evaluated_head,
        code_prefix="FULL_CONVERGENCE_SCHEMA",
    )
    if schema_seal_failures:
        return sorted({"FULL_CONVERGENCE_SCHEMA_HASH_MISMATCH", *schema_seal_failures})
    try:
        schema = load_json_strict(path)
    except (OSError, ValueError, json.JSONDecodeError):
        return ["FULL_CONVERGENCE_SCHEMA_JSON_INVALID"]
    failures: list[str] = []
    if schema.get("schema_version") != EPOCH_SCHEMA_VERSION:
        failures.append("FULL_CONVERGENCE_SCHEMA_VERSION_MISMATCH")
    if schema.get("authorization_id") != AUTHORIZATION_ID:
        failures.append("FULL_CONVERGENCE_SCHEMA_AUTHORIZATION_MISMATCH")
    if tuple(sorted(schema.get("record_required_fields", []))) != EXTENSION_RECORD_FIELDS:
        failures.append("FULL_CONVERGENCE_SCHEMA_RECORD_FIELDS_MISMATCH")
    if tuple(sorted(schema.get("batch_manifest_required_fields", []))) != BATCH_MANIFEST_FIELDS:
        failures.append("FULL_CONVERGENCE_SCHEMA_BATCH_FIELDS_MISMATCH")
    if tuple(sorted(schema.get("identity_binding_required_fields", []))) != IDENTITY_BINDING_FIELDS:
        failures.append("FULL_CONVERGENCE_SCHEMA_IDENTITY_FIELDS_MISMATCH")
    if tuple(sorted(schema.get("authority_selector_required_fields", []))) != AUTHORITY_SELECTOR_FIELDS:
        failures.append("FULL_CONVERGENCE_SCHEMA_SELECTOR_FIELDS_MISMATCH")
    if tuple(schema.get("authority_source_paths", [])) != tuple(
        sorted(AUTHORITY_SOURCE_PATHS)
    ):
        failures.append("FULL_CONVERGENCE_SCHEMA_AUTHORITY_SOURCE_PATHS_MISMATCH")
    if set(schema.get("subject_projection_required_fields", [])) != SUBJECT_PROJECTION_FIELDS:
        failures.append("FULL_CONVERGENCE_SCHEMA_PROJECTION_FIELDS_MISMATCH")
    if set(schema.get("allowed_dispositions", [])) != ALLOWED_DISPOSITIONS:
        failures.append("FULL_CONVERGENCE_SCHEMA_DISPOSITION_SET_MISMATCH")
    if schema.get("legacy_record_chain_terminal_sha256") != LEGACY_RECORD_CHAIN_TERMINAL_SHA256:
        failures.append("FULL_CONVERGENCE_SCHEMA_LEGACY_CHAIN_ANCHOR_MISMATCH")
    if schema.get("legacy_fingerprint_reuse_allowed") is not False:
        failures.append("FULL_CONVERGENCE_SCHEMA_LEGACY_FINGERPRINT_REUSE_POLICY_MISMATCH")
    if schema.get("previous_batch_manifest_discovery_allowed") is not False:
        failures.append("FULL_CONVERGENCE_SCHEMA_PREVIOUS_BATCH_DISCOVERY_POLICY_MISMATCH")
    if schema.get("previous_batch_manifest_required_for_non_initial_batch") is not True:
        failures.append("FULL_CONVERGENCE_SCHEMA_PREVIOUS_BATCH_REQUIREMENT_MISMATCH")
    if (
        schema.get("baseline_historical_membership_policy")
        != "LIVE_RAW_OR_EXACT_APPEND_ONLY_DISPOSITION"
    ):
        failures.append("FULL_CONVERGENCE_SCHEMA_BASELINE_MEMBERSHIP_POLICY_MISMATCH")
    if schema.get("correction_membership_scope") != "LIVE_HISTORICAL_ONLY":
        failures.append("FULL_CONVERGENCE_SCHEMA_CORRECTION_MEMBERSHIP_SCOPE_MISMATCH")
    if schema.get("current_failure_correction_allowed") is not False:
        failures.append("FULL_CONVERGENCE_SCHEMA_CURRENT_CORRECTION_POLICY_MISMATCH")
    if schema.get("descendant_history_supplement_required") is not True:
        failures.append("FULL_CONVERGENCE_SCHEMA_DESCENDANT_SUPPLEMENT_REQUIREMENT_MISMATCH")
    if schema.get("descendant_history_supplement_discovery_allowed") is not False:
        failures.append("FULL_CONVERGENCE_SCHEMA_DESCENDANT_DISCOVERY_POLICY_MISMATCH")
    if schema.get("descendant_history_wildcard_membership_allowed") is not False:
        failures.append("FULL_CONVERGENCE_SCHEMA_DESCENDANT_WILDCARD_POLICY_MISMATCH")
    if schema.get("descendant_history_future_auto_membership_allowed") is not False:
        failures.append("FULL_CONVERGENCE_SCHEMA_DESCENDANT_FUTURE_POLICY_MISMATCH")
    if (
        schema.get("descendant_history_supplement_schema_version")
        != DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION
    ):
        failures.append("FULL_CONVERGENCE_SCHEMA_DESCENDANT_VERSION_MISMATCH")
    if (
        tuple(sorted(schema.get("descendant_history_supplement_required_fields", [])))
        != DESCENDANT_HISTORY_SUPPLEMENT_FIELDS
    ):
        failures.append("FULL_CONVERGENCE_SCHEMA_DESCENDANT_FIELDS_MISMATCH")
    if (
        tuple(sorted(schema.get("frozen_identity_disposition_required_fields", [])))
        != FROZEN_IDENTITY_DISPOSITION_FIELDS
    ):
        failures.append("FULL_CONVERGENCE_SCHEMA_FROZEN_DISPOSITION_FIELDS_MISMATCH")
    if (
        tuple(sorted(schema.get("successor_disposition_evidence_required_fields", [])))
        != SUCCESSOR_DISPOSITION_EVIDENCE_FIELDS
    ):
        failures.append("FULL_CONVERGENCE_SCHEMA_SUCCESSOR_EVIDENCE_FIELDS_MISMATCH")
    if (
        tuple(sorted(schema.get("false_component_retirement_evidence_required_fields", [])))
        != FALSE_COMPONENT_RETIREMENT_EVIDENCE_FIELDS
    ):
        failures.append("FULL_CONVERGENCE_SCHEMA_FALSE_COMPONENT_EVIDENCE_FIELDS_MISMATCH")
    if (
        set(schema.get("frozen_identity_dispositions_allowed", []))
        != ALLOWED_FROZEN_IDENTITY_DISPOSITIONS
    ):
        failures.append("FULL_CONVERGENCE_SCHEMA_FROZEN_DISPOSITION_SET_MISMATCH")
    if schema.get("dynamic_reference_manifest_path") != DYNAMIC_REFERENCE_MANIFEST_REL.as_posix():
        failures.append("FULL_CONVERGENCE_SCHEMA_DYNAMIC_REFERENCE_MANIFEST_MISMATCH")
    return sorted(set(failures))


def verify_legacy_anchor(root: Path) -> dict[str, Any]:
    failures: list[str] = []
    previous = ""
    fingerprints: list[str] = []
    correction_ids: list[str] = []
    record_paths: list[str] = []
    for binding in LEGACY_RECORD_BINDINGS:
        record_paths.append(str(binding["path"]))
        path = root / binding["path"]
        if not path.is_file():
            failures.append(f"LEGACY_RECORD_MISSING:{binding['path']}")
            continue
        if sha256_file(path) != binding["sha256"]:
            failures.append(f"LEGACY_RECORD_BYTE_DRIFT:{binding['path']}")
            continue
        try:
            record = load_json_strict(path)
        except (OSError, ValueError, json.JSONDecodeError):
            failures.append(f"LEGACY_RECORD_JSON_INVALID:{binding['path']}")
            continue
        if record.get("authorization_id") != LEGACY_AUTHORIZATION_ID:
            failures.append(f"LEGACY_RECORD_AUTHORIZATION_DRIFT:{binding['path']}")
        if record.get("authorized_head_sha") != LEGACY_AUTHORIZED_HEAD_SHA:
            failures.append(f"LEGACY_RECORD_HEAD_DRIFT:{binding['path']}")
        if record.get("baseline_report_sha256") != LEGACY_BASELINE_REPORT_SHA256:
            failures.append(f"LEGACY_RECORD_BASELINE_DRIFT:{binding['path']}")
        if record.get("previous_correction_chain_sha256", "") != previous:
            failures.append(f"LEGACY_RECORD_CHAIN_BREAK:{binding['path']}")
        if record.get("record_payload_sha256") != binding["payload_sha256"]:
            failures.append(f"LEGACY_RECORD_PAYLOAD_DRIFT:{binding['path']}")
        correction_id = str(record.get("correction_id", ""))
        if not correction_id:
            failures.append(f"LEGACY_RECORD_CORRECTION_ID_MISSING:{binding['path']}")
        correction_ids.append(correction_id)
        previous = str(record.get("record_payload_sha256", ""))
        fingerprints.extend(str(value) for value in record.get("failure_fingerprints", []))
    if previous != LEGACY_RECORD_CHAIN_TERMINAL_SHA256:
        failures.append("LEGACY_RECORD_CHAIN_TERMINAL_MISMATCH")
    if len(fingerprints) != 12 or len(fingerprints) != len(set(fingerprints)):
        failures.append("LEGACY_RECORD_FINGERPRINT_SET_INVALID")
    if len(correction_ids) != len(set(correction_ids)):
        failures.append("LEGACY_RECORD_CORRECTION_ID_SET_INVALID")
    for relative, expected in (
        (LEGACY_SCHEMA_REL, LEGACY_SCHEMA_SHA256),
        (LEGACY_SEAL_MANIFEST_REL, LEGACY_SEAL_MANIFEST_SHA256),
        (LEGACY_SEAL_PLAN_REL, LEGACY_SEAL_PLAN_SHA256),
    ):
        path = root / relative
        if not path.is_file() or sha256_file(path) != expected:
            failures.append(f"LEGACY_ANCHOR_BYTE_DRIFT:{relative.as_posix()}")
    return {
        "status": "PASS" if not failures else "FAIL",
        "legacy_record_count": len(LEGACY_RECORD_BINDINGS),
        "legacy_corrected_fingerprint_count": len(fingerprints),
        "legacy_corrected_fingerprints": sorted(fingerprints),
        "legacy_correction_ids": sorted(correction_ids),
        "legacy_record_paths": sorted(record_paths),
        "legacy_record_chain_terminal_sha256": previous,
        "legacy_seal_manifest_sha256": LEGACY_SEAL_MANIFEST_SHA256,
        "failures": sorted(set(failures)),
    }


def _walk_dicts(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_dicts(child)


def _selector_failures(selector: Any) -> list[str]:
    if not isinstance(selector, dict):
        return ["SUBJECT_SELECTOR_NOT_OBJECT"]
    failures: list[str] = []
    if set(selector) != set(AUTHORITY_SELECTOR_FIELDS):
        failures.append("SUBJECT_SELECTOR_FIELD_SET_MISMATCH")
    total = 0
    for field in AUTHORITY_SELECTOR_FIELDS:
        values = selector.get(field)
        if not isinstance(values, list):
            failures.append(f"SUBJECT_SELECTOR_LIST_INVALID:{field}")
            continue
        rendered = [str(value) for value in values]
        total += len(rendered)
        if len(rendered) != len(set(rendered)) or rendered != sorted(rendered):
            failures.append(f"SUBJECT_SELECTOR_SET_INVALID:{field}")
        for value in rendered:
            normalized = normalize_path(value) if field == "paths" else value
            tokens = set(re.findall(r"[a-z0-9_]+", value.casefold()))
            if (
                not value
                or any(char in value for char in "*?[]")
                or tokens & DISALLOWED_TOKENS
                or (field == "paths" and (normalized != value or value.endswith("/") or value.startswith(("/", "../")) or "/../" in value))
            ):
                failures.append(f"SUBJECT_SELECTOR_NOT_EXACT:{field}:{value}")
    if total == 0:
        failures.append("SUBJECT_SELECTOR_EMPTY")
    return sorted(set(failures))


def _matches_selector(row: dict[str, Any], selector: dict[str, list[str]]) -> bool:
    component_ids = set(selector.get("component_ids", []))
    dynamic_reference_ids = set(selector.get("dynamic_reference_ids", []))
    paths = set(selector.get("paths", []))
    supersession_ids = set(selector.get("supersession_ids", []))
    retirement_ids = set(selector.get("retirement_ids", []))
    component_values = {
        str(row.get(key, ""))
        for key in (
            "component_id", "historical_component_id", "current_component_id",
            "owner_component_id", "old_component_id", "new_component_id",
        )
    }
    path_values = {
        normalize_path(str(row.get(key, "")))
        for key in (
            "path", "historical_path", "current_path", "owner_path",
            "old_owner_path", "new_owner_path", "source_path",
        )
    }
    resolved_targets = row.get("resolved_targets")
    if isinstance(resolved_targets, list):
        path_values.update(
            normalize_path(str(value)) for value in resolved_targets
        )
    id_values = {
        str(row.get(key, ""))
        for key in (
            "dynamic_reference_id",
            "supersession_id",
            "retirement_id",
            "record_id",
        )
    }
    return bool(
        component_ids & component_values
        or dynamic_reference_ids & id_values
        or paths & path_values
        or supersession_ids & id_values
        or retirement_ids & id_values
    )


def _json_at(root: Path, commit: str, relative: str) -> Any:
    payload = _git_bytes(root, commit, relative)
    if payload is None:
        return None
    return json.loads(payload.decode("utf-8-sig"), object_pairs_hook=_strict_object)


def subject_projection(root: Path, commit: str, selector: dict[str, list[str]]) -> dict[str, Any]:
    failures = _selector_failures(selector)
    if failures:
        raise ValueError(";".join(failures))
    registry = _json_at(root, commit, AUTHORITY_SOURCE_PATHS[0])
    supersession = _json_at(root, commit, AUTHORITY_SOURCE_PATHS[1])
    owner_map_payload = _git_bytes(root, commit, AUTHORITY_SOURCE_PATHS[2])
    dynamic_reference_manifest = _json_at(root, commit, AUTHORITY_SOURCE_PATHS[3])
    if (
        registry is None
        or supersession is None
        or owner_map_payload is None
        or dynamic_reference_manifest is None
    ):
        raise ValueError("SUBJECT_PROJECTION_AUTHORITY_SOURCE_MISSING")
    component_ids = {str(value) for value in selector.get("component_ids", [])}
    paths = {
        normalize_path(str(value)) for value in selector.get("paths", [])
    }
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
    registry_rows = [
        row
        for row in registry_candidates
        if isinstance(row, dict)
        and (
            str(row.get("component_id", "")) in component_ids
            or normalize_path(str(row.get("path", ""))) in paths
        )
    ]
    supersession_candidates: list[Any] = []
    if isinstance(supersession, dict):
        for key in ("entries", "retirement_entries"):
            values = supersession.get(key, [])
            if isinstance(values, list):
                supersession_candidates.extend(values)
    supersession_rows = [
        row
        for row in supersession_candidates
        if isinstance(row, dict)
        and (
            str(row.get("supersession_id", "")) in supersession_ids
            or str(row.get("retirement_id", "")) in retirement_ids
        )
    ]
    dynamic_candidates = (
        dynamic_reference_manifest.get("entries", [])
        if isinstance(dynamic_reference_manifest, dict)
        else []
    )
    dynamic_reference_rows = [
        row
        for row in dynamic_candidates
        if isinstance(row, dict)
        and str(row.get("dynamic_reference_id", ""))
        in dynamic_reference_ids
    ]
    registry_rows = sorted(registry_rows, key=lambda row: canonical_bytes(row))
    supersession_rows = sorted(supersession_rows, key=lambda row: canonical_bytes(row))
    dynamic_reference_rows = sorted(
        dynamic_reference_rows,
        key=lambda row: canonical_bytes(row),
    )
    exact_needles = sorted({
        str(value)
        for field in AUTHORITY_SELECTOR_FIELDS
        for value in selector.get(field, [])
        if value
    })
    owner_map_lines = sorted({
        line.rstrip()
        for line in owner_map_payload.decode("utf-8-sig", errors="replace").splitlines()
        if any(needle in line for needle in exact_needles)
    })
    if (
        not registry_rows
        and not supersession_rows
        and not owner_map_lines
        and not dynamic_reference_rows
    ):
        raise ValueError("SUBJECT_PROJECTION_SELECTOR_UNRESOLVED")
    return {
        "dynamic_reference_rows": dynamic_reference_rows,
        "owner_map_lines": owner_map_lines,
        "registry_rows": registry_rows,
        "supersession_rows": supersession_rows,
    }


def _dynamic_target_set_sha256(targets: Iterable[str]) -> str:
    return sha256_bytes("\n".join(targets).encode("utf-8"))


def _duplicate_identity_payload(identity: dict[str, Any]) -> dict[str, str]:
    return {
        field: str(identity.get(field, ""))
        for field in (
            "raw_failure",
            "rule_id",
            "subject_kind",
            "subject_value",
            "transition_new_prefix",
            "transition_old_prefix",
        )
    }


def _exact_relation_values(value: Any) -> list[str] | None:
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
            & DISALLOWED_TOKENS
            for item in rendered
        )
    ):
        return None
    return rendered


def _registry_row_failures(row: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    source_kind = str(row.get("authority_source_kind", ""))
    if source_kind == "historical_identity_backfill":
        if set(row) != REGISTRY_HISTORICAL_BACKFILL_FIELDS:
            failures.append("IDENTITY_BINDING_BACKFILL_FIELD_SET_INVALID")
        if (
            not str(row.get("component_id", ""))
            or any(
                char in str(row.get("component_id", ""))
                for char in "*?[]"
            )
            or not _is_commit(row.get("source_commit"))
            or not _is_sha256(row.get("source_blob"))
            or str(row.get("historical_role", ""))
            not in REGISTRY_ALLOWED_COMPONENT_ROLES
            or str(row.get("current_disposition", ""))
            not in ALLOWED_DISPOSITIONS
            or str(row.get("production_reachability", ""))
            not in {
                "DIAGNOSTIC_ONLY",
                "DOCUMENTATION_ONLY",
                "GENERATED_EVIDENCE_ONLY",
                "NONREACHABLE",
                "PRODUCTION_REACHABLE",
                "TEST_ONLY",
            }
            or _exact_relation_values(row.get("supersession")) is None
        ):
            failures.append("IDENTITY_BINDING_BACKFILL_IDENTITY_INVALID")
        return sorted(set(failures))
    if source_kind != "component_inventory":
        return ["IDENTITY_BINDING_REGISTRY_SOURCE_KIND_INVALID"]
    if (
        not set(row).issubset(REGISTRY_COMPONENT_INVENTORY_FIELDS)
        or not REGISTRY_COMPONENT_INVENTORY_REQUIRED_FIELDS.issubset(row)
    ):
        failures.append("IDENTITY_BINDING_REGISTRY_FIELD_SET_INVALID")
    component_id = str(row.get("component_id", ""))
    domain_id = str(row.get("domain_id", ""))
    owner_id = str(row.get("owner_component_id", ""))
    owner_path = str(row.get("owner_path", ""))
    path = str(row.get("path", ""))
    role = str(row.get("component_role", ""))
    for field, value in (
        ("component_id", component_id),
        ("domain_id", domain_id),
        ("owner_component_id", owner_id),
    ):
        if not value or any(char in value for char in "*?[]"):
            failures.append(
                f"IDENTITY_BINDING_REGISTRY_IDENTIFIER_INVALID:{field}"
            )
    if (
        not path
        or normalize_path(path) != path
        or path.startswith(("/", "../"))
        or path.endswith("/")
        or "/../" in path
        or any(char in path for char in "*?[]")
    ):
        failures.append("IDENTITY_BINDING_REGISTRY_PATH_INVALID")
    if (
        not owner_path
        or normalize_path(owner_path) != owner_path
        or owner_path.startswith(("/", "../"))
        or owner_path.endswith("/")
        or "/../" in owner_path
        or any(char in owner_path for char in "*?[]")
    ):
        failures.append("IDENTITY_BINDING_REGISTRY_OWNER_PATH_INVALID")
    if role not in REGISTRY_ALLOWED_COMPONENT_ROLES:
        failures.append("IDENTITY_BINDING_REGISTRY_ROLE_INVALID")
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
    if any(not isinstance(row.get(field), bool) for field in authority_bool_fields):
        failures.append("IDENTITY_BINDING_REGISTRY_AUTHORITY_FLAGS_INVALID")
    owns_by_field = {
        field: bool(row.get(field))
        for field in (
            "owns_identity",
            "owns_presentation",
            "owns_replay",
            "owns_rng",
            "owns_save",
            "owns_tick",
        )
    }
    if role == "OWNER":
        if (
            row.get("writes_authority") is not True
            or owner_id != component_id
            or normalize_path(owner_path) != normalize_path(path)
        ):
            failures.append("IDENTITY_BINDING_REGISTRY_OWNER_AUTHORITY_INVALID")
    else:
        if role != "DIAGNOSTIC_BENCH" and any(owns_by_field.values()):
            failures.append("IDENTITY_BINDING_REGISTRY_NONOWNER_OWNERSHIP_INVALID")
        if role == "DIAGNOSTIC_BENCH" and any(
            owns_by_field[field]
            for field in (
                "owns_identity",
                "owns_replay",
                "owns_rng",
                "owns_save",
                "owns_tick",
            )
        ):
            failures.append("IDENTITY_BINDING_REGISTRY_DIAGNOSTIC_OWNERSHIP_INVALID")
        if role != "REDUCER" and row.get("writes_authority") is not False:
            failures.append("IDENTITY_BINDING_REGISTRY_NONOWNER_WRITE_INVALID")
    if role in REGISTRY_NONPRODUCTION_ROLES and row.get(
        "production_reachable"
    ) is not False:
        failures.append("IDENTITY_BINDING_REGISTRY_NONPRODUCTION_ROLE_REACHABLE")
    for field in ("supersedes", "superseded_by"):
        if _exact_relation_values(row.get(field)) is None:
            failures.append(
                f"IDENTITY_BINDING_REGISTRY_RELATION_SET_INVALID:{field}"
            )
    reuse_disposition = row.get("reuse_disposition")
    current_disposition = row.get("current_disposition")
    if reuse_disposition is not None:
        if reuse_disposition not in REGISTRY_ALLOWED_REUSE_DISPOSITIONS:
            failures.append("IDENTITY_BINDING_REGISTRY_REUSE_DISPOSITION_INVALID")
        if role == "OWNER" and reuse_disposition != "ADOPT_AS_OWNER":
            failures.append("IDENTITY_BINDING_REGISTRY_OWNER_DISPOSITION_INVALID")
        if role != "OWNER" and reuse_disposition == "ADOPT_AS_OWNER":
            failures.append("IDENTITY_BINDING_REGISTRY_NONOWNER_DISPOSITION_INVALID")
        if role == "TEST_SUPPORT" and reuse_disposition != "REUSE_AS_TEST":
            failures.append("IDENTITY_BINDING_REGISTRY_TEST_DISPOSITION_INVALID")
    elif not isinstance(current_disposition, str) or not current_disposition:
        failures.append("IDENTITY_BINDING_REGISTRY_DISPOSITION_MISSING")
    return sorted(set(failures))


def _dynamic_reference_structure_failures(row: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    location = row.get("source_line_or_ast_location")
    targets = row.get("resolved_targets")
    rendered_targets = (
        [str(value) for value in targets]
        if isinstance(targets, list)
        else []
    )
    callsite = row.get("callsite_contract")
    if row.get("resolution_method") not in DYNAMIC_REFERENCE_RESOLUTION_METHODS:
        failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_RESOLUTION_METHOD_INVALID")
    if (
        not isinstance(callsite, dict)
        or set(callsite) != DYNAMIC_REFERENCE_CALLSITE_FIELDS
    ):
        return sorted(set([
            *failures,
            "IDENTITY_BINDING_DYNAMIC_REFERENCE_CALLSITE_CONTRACT_INVALID",
        ]))
    helper = str(callsite.get("helper_function", ""))
    constants = callsite.get("allowed_argument_constants")
    rendered_constants = (
        [str(value) for value in constants]
        if isinstance(constants, list)
        else []
    )
    sites = callsite.get("required_loader_sites")
    rendered_sites = sites if isinstance(sites, list) else []
    if (
        not helper
        or not isinstance(location, dict)
        or helper != str(location.get("containing_function", ""))
        or not rendered_constants
        or rendered_constants != sorted(rendered_constants)
        or len(rendered_constants) != len(set(rendered_constants))
        or any(
            re.fullmatch(r"[A-Z][A-Z0-9_]*", value) is None
            for value in rendered_constants
        )
        or not _is_exact_int(
            callsite.get("required_invocation_count"), len(rendered_constants)
        )
        or len(rendered_constants) != len(rendered_targets)
        or not _is_exact_int(
            callsite.get("external_or_unknown_invocation_count"), 0
        )
    ):
        failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_CALLSITE_CONTRACT_INVALID")
    site_keys: list[tuple[int, int, str, str]] = []
    for site in rendered_sites:
        if not isinstance(site, dict) or set(site) != DYNAMIC_REFERENCE_LOADER_SITE_FIELDS:
            failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_LOADER_SITE_INVALID")
            continue
        key = (
            site.get("line") if _is_int(site.get("line")) else 0,
            site.get("column") if _is_int(site.get("column")) else 0,
            str(site.get("loader", "")),
            str(site.get("reference_expression", "")),
        )
        site_keys.append(key)
        if (
            key[0] < 1
            or key[1] < 1
            or not key[2]
            or not key[3]
            or any(char in key[2] + key[3] for char in "*?[]")
        ):
            failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_LOADER_SITE_INVALID")
    if (
        not site_keys
        or site_keys != sorted(site_keys)
        or len(site_keys) != len(set(site_keys))
    ):
        failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_LOADER_SITE_SET_INVALID")
    if isinstance(location, dict):
        primary_site = (
            location.get("line"),
            location.get("column"),
            str(row.get("loader", "")),
            str(row.get("reference_expression", "")),
        )
        if primary_site not in site_keys:
            failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_PRIMARY_SITE_MISMATCH")
    runtime_probe = row.get("runtime_probe")
    if isinstance(runtime_probe, dict):
        test_path = normalize_path(str(runtime_probe.get("test_path", "")))
        probe_id = str(runtime_probe.get("probe_id", ""))
        if (
            not test_path
            or test_path.startswith(("/", "../"))
            or any(char in test_path for char in "*?[]")
            or Path(test_path).suffix != ".gd"
            or Path(test_path).stem != probe_id
        ):
            failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_RUNTIME_PROBE_INVALID")
    return sorted(set(failures))


def _identity_projection_failures(
    binding: dict[str, Any],
    *,
    rule_id: str,
    raw_failure: str = "",
) -> list[str]:
    """Bind every identity claim to exact authority rows, not record prose."""

    failures: list[str] = []
    projection = binding.get("subject_projection")
    if not isinstance(projection, dict):
        return ["IDENTITY_BINDING_PROJECTION_INVALID"]
    if set(projection) != SUBJECT_PROJECTION_FIELDS:
        failures.append("IDENTITY_BINDING_PROJECTION_FIELD_SET_INVALID")
    projected: dict[str, list[Any]] = {}
    for field in SUBJECT_PROJECTION_FIELDS:
        value = projection.get(field)
        if not isinstance(value, list):
            failures.append(f"IDENTITY_BINDING_PROJECTION_LIST_INVALID:{field}")
            projected[field] = []
        else:
            projected[field] = value
    if not any(projected.values()):
        failures.append("IDENTITY_BINDING_PROJECTION_EMPTY")

    registry_rows = [
        row for row in projected["registry_rows"] if isinstance(row, dict)
    ]
    if len(registry_rows) != len(projected["registry_rows"]):
        failures.append("IDENTITY_BINDING_REGISTRY_ROW_INVALID")
    selector = binding.get("authority_selectors")
    selector_components = (
        {str(value) for value in selector.get("component_ids", [])}
        if isinstance(selector, dict)
        else set()
    )
    selector_paths = (
        {normalize_path(str(value)) for value in selector.get("paths", [])}
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
        normalize_path(str(binding.get(field, "")))
        for field in ("current_path", "historical_path")
        if binding.get(field)
    }
    if selector_components != expected_components:
        failures.append("IDENTITY_BINDING_COMPONENT_SELECTOR_SET_MISMATCH")
    if selector_paths != expected_paths:
        failures.append("IDENTITY_BINDING_PATH_SELECTOR_SET_MISMATCH")

    for row in registry_rows:
        failures.extend(_registry_row_failures(row))
    inventory_rows = [
        row
        for row in registry_rows
        if row.get("authority_source_kind") == "component_inventory"
    ]
    backfill_rows = [
        row
        for row in registry_rows
        if row.get("authority_source_kind") == "historical_identity_backfill"
    ]
    projected_component_ids = [str(row.get("component_id", "")) for row in registry_rows]
    if set(projected_component_ids) != selector_components:
        failures.append("IDENTITY_BINDING_REGISTRY_SELECTOR_SET_MISMATCH")
    inventory_component_ids = [
        str(row.get("component_id", "")) for row in inventory_rows
    ]
    if any(
        inventory_component_ids.count(component_id) != 1
        for component_id in set(inventory_component_ids)
    ):
        failures.append("IDENTITY_BINDING_REGISTRY_PRIMARY_KEY_NOT_UNIQUE")
    backfill_primary_keys = [
        (
            str(row.get("component_id", "")),
            str(row.get("source_commit", "")),
            str(row.get("source_blob", "")),
        )
        for row in backfill_rows
    ]
    if len(backfill_primary_keys) != len(set(backfill_primary_keys)):
        failures.append("IDENTITY_BINDING_BACKFILL_PRIMARY_KEY_NOT_UNIQUE")

    bound_registry_rows: dict[str, dict[str, Any]] = {}

    def bind_inventory_side(prefix: str, row: dict[str, Any]) -> None:
        component_id = str(binding.get(f"{prefix}_component_id", ""))
        path = normalize_path(str(binding.get(f"{prefix}_path", "")))
        bound_registry_rows[prefix] = row
        if path and normalize_path(str(row.get("path", ""))) != path:
            failures.append(
                f"IDENTITY_BINDING_{prefix.upper()}_REGISTRY_PATH_MISMATCH"
            )
        if component_id not in selector_components:
            failures.append(
                f"IDENTITY_BINDING_{prefix.upper()}_COMPONENT_SELECTOR_MISSING"
            )
        for binding_field, row_field in (
            ("domain_id", "domain_id"),
            (f"{prefix}_role", "component_role"),
            (f"{prefix}_owner_id", "owner_component_id"),
        ):
            if str(binding.get(binding_field, "")) != str(row.get(row_field, "")):
                failures.append(
                    f"IDENTITY_BINDING_{prefix.upper()}_REGISTRY_{row_field.upper()}_MISMATCH"
                )
        reachable = row.get("production_reachable")
        declared_reachability = str(
            binding.get(f"{prefix}_production_reachability", "")
        )
        if not isinstance(reachable, bool):
            failures.append(
                f"IDENTITY_BINDING_{prefix.upper()}_REGISTRY_REACHABILITY_INVALID"
            )
        elif reachable and declared_reachability != "PRODUCTION_REACHABLE":
            failures.append(
                f"IDENTITY_BINDING_{prefix.upper()}_REGISTRY_REACHABILITY_MISMATCH"
            )
        elif not reachable and declared_reachability == "PRODUCTION_REACHABLE":
            failures.append(
                f"IDENTITY_BINDING_{prefix.upper()}_REGISTRY_REACHABILITY_MISMATCH"
            )
        role = str(row.get("component_role", ""))
        owner_id = str(row.get("owner_component_id", ""))
        if role == "OWNER":
            if owner_id != component_id:
                failures.append(
                    f"IDENTITY_BINDING_{prefix.upper()}_OWNER_SELF_BINDING_INVALID"
                )
        elif not owner_id:
            failures.append(
                f"IDENTITY_BINDING_{prefix.upper()}_OWNER_MISSING"
            )
        if owner_id:
            if owner_id not in selector_components:
                failures.append(
                    f"IDENTITY_BINDING_{prefix.upper()}_OWNER_SELECTOR_MISSING"
                )
            owner_rows = [
                owner_row
                for owner_row in inventory_rows
                if str(owner_row.get("component_id", "")) == owner_id
            ]
            if (
                len(owner_rows) != 1
                or str(owner_rows[0].get("domain_id", ""))
                != str(row.get("domain_id", ""))
                or owner_rows[0].get("component_role") != "OWNER"
                or owner_rows[0].get("owner_component_id") != owner_id
            ):
                failures.append(
                    f"IDENTITY_BINDING_{prefix.upper()}_OWNER_ROW_NOT_UNIQUE"
                )
            elif normalize_path(str(row.get("owner_path", ""))) != normalize_path(
                str(owner_rows[0].get("path", ""))
            ):
                failures.append(
                    f"IDENTITY_BINDING_{prefix.upper()}_OWNER_PATH_MISMATCH"
                )

    def bind_registry_side(prefix: str) -> None:
        component_id = str(binding.get(f"{prefix}_component_id", ""))
        if not component_id:
            failures.append(f"IDENTITY_BINDING_{prefix.upper()}_COMPONENT_MISSING")
            return
        if component_id not in selector_components:
            failures.append(
                f"IDENTITY_BINDING_{prefix.upper()}_COMPONENT_SELECTOR_MISSING"
            )
        inventory_candidates = [
            row
            for row in inventory_rows
            if str(row.get("component_id", "")) == component_id
        ]
        if prefix == "current":
            if len(inventory_candidates) != 1:
                failures.append("IDENTITY_BINDING_CURRENT_REGISTRY_ROW_NOT_UNIQUE")
                return
            bind_inventory_side(prefix, inventory_candidates[0])
            return

        component_backfills = [
            row
            for row in backfill_rows
            if str(row.get("component_id", "")) == component_id
        ]
        if component_backfills:
            exact_backfills = [
                row
                for row in component_backfills
                if row.get("source_commit") == binding.get("source_commit")
                and row.get("source_blob") == binding.get("historical_blob_sha256")
            ]
            if len(exact_backfills) != 1:
                failures.append("IDENTITY_BINDING_HISTORICAL_BACKFILL_ROW_NOT_UNIQUE")
                return
            row = exact_backfills[0]
            bound_registry_rows[prefix] = row
            for binding_field, row_field in (
                ("historical_role", "historical_role"),
                ("recommended_disposition", "current_disposition"),
                ("historical_production_reachability", "production_reachability"),
            ):
                if str(binding.get(binding_field, "")) != str(row.get(row_field, "")):
                    failures.append(
                        "IDENTITY_BINDING_HISTORICAL_BACKFILL_"
                        f"{row_field.upper()}_MISMATCH"
                    )
            backfill_supersession = _exact_relation_values(row.get("supersession"))
            binding_superseded_by = _exact_relation_values(
                binding.get("superseded_by")
            )
            if (
                backfill_supersession is None
                or binding_superseded_by is None
                or backfill_supersession != binding_superseded_by
            ):
                failures.append(
                    "IDENTITY_BINDING_HISTORICAL_BACKFILL_SUPERSESSION_MISMATCH"
                )
            historical_owner_id = str(binding.get("historical_owner_id", ""))
            historical_role = str(binding.get("historical_role", ""))
            if historical_role == "OWNER":
                if historical_owner_id != component_id:
                    failures.append(
                        "IDENTITY_BINDING_HISTORICAL_OWNER_SELF_BINDING_INVALID"
                    )
            else:
                owner_rows = [
                    owner_row
                    for owner_row in inventory_rows
                    if str(owner_row.get("component_id", "")) == historical_owner_id
                ]
                if historical_owner_id not in selector_components:
                    failures.append(
                        "IDENTITY_BINDING_HISTORICAL_OWNER_SELECTOR_MISSING"
                    )
                if (
                    len(owner_rows) != 1
                    or owner_rows[0].get("component_role") != "OWNER"
                    or owner_rows[0].get("owner_component_id")
                    != historical_owner_id
                    or str(owner_rows[0].get("domain_id", ""))
                    != str(binding.get("domain_id", ""))
                ):
                    failures.append(
                        "IDENTITY_BINDING_HISTORICAL_OWNER_ROW_NOT_UNIQUE"
                    )
            return

        if len(inventory_candidates) != 1:
            failures.append("IDENTITY_BINDING_HISTORICAL_REGISTRY_ROW_NOT_UNIQUE")
            return
        bind_inventory_side(prefix, inventory_candidates[0])

    bind_registry_side("historical")
    bind_registry_side("current")

    disposition = str(binding.get("recommended_disposition", ""))
    supersedes = _exact_relation_values(binding.get("supersedes"))
    superseded_by = _exact_relation_values(binding.get("superseded_by"))
    if supersedes is None:
        failures.append("IDENTITY_BINDING_SUPERSEDES_SET_INVALID")
        supersedes = []
    if superseded_by is None:
        failures.append("IDENTITY_BINDING_SUPERSEDED_BY_SET_INVALID")
        superseded_by = []
    if disposition in IDENTITY_NON_MIGRATION_DISPOSITIONS and (
        binding.get("historical_component_id") != binding.get("current_component_id")
        or normalize_path(str(binding.get("historical_path", "")))
        != normalize_path(str(binding.get("current_path", "")))
    ):
        failures.append("IDENTITY_BINDING_UNAUTHORIZED_LINEAGE_SUBSTITUTION")
    historical_registry_row = bound_registry_rows.get("historical", {})
    current_registry_row = bound_registry_rows.get("current", {})
    registry_supersedes = _exact_relation_values(
        current_registry_row.get("supersedes")
    )
    registry_superseded_by = _exact_relation_values(
        historical_registry_row.get("superseded_by")
    )
    if registry_supersedes is not None and supersedes != registry_supersedes:
        failures.append("IDENTITY_BINDING_SUPERSEDES_REGISTRY_MISMATCH")
    if (
        registry_superseded_by is not None
        and superseded_by != registry_superseded_by
    ):
        failures.append("IDENTITY_BINDING_SUPERSEDED_BY_REGISTRY_MISMATCH")

    dynamic_rows = [
        row
        for row in projected["dynamic_reference_rows"]
        if isinstance(row, dict)
    ]
    if len(dynamic_rows) != len(projected["dynamic_reference_rows"]):
        failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_ROW_INVALID")
    dynamic_rule = rule_id == "HISTORY_DYNAMIC_REFERENCE_UNRESOLVED"
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
        failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_SELECTOR_UNRESOLVED")
    if any(
        projected_dynamic_ids.count(reference_id) != 1
        for reference_id in selector_dynamic_ids
    ):
        failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_PRIMARY_KEY_NOT_UNIQUE")
    if dynamic_rule:
        source_path = normalize_path(str(binding.get("historical_path", "")))
        source_rows = [
            row
            for row in dynamic_rows
            if normalize_path(str(row.get("source_path", ""))) == source_path
            and str(row.get("dynamic_reference_id", ""))
            in selector_dynamic_ids
        ]
        exact_rows = source_rows
        raw_parts = raw_failure.split(":")
        if raw_failure and len(raw_parts) >= 5:
            loader, expression = raw_parts[1], raw_parts[2]
            exact_rows = [
                row
                for row in source_rows
                if row.get("loader") == loader
                and row.get("reference_expression") == expression
            ]
        if len(exact_rows) != 1:
            failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_ROW_NOT_UNIQUE")
        if (
            len(selector_dynamic_ids) != 1
            or len(exact_rows) != 1
            or selector_dynamic_ids[0]
            != str(exact_rows[0].get("dynamic_reference_id", ""))
        ):
            failures.append(
                "IDENTITY_BINDING_DYNAMIC_REFERENCE_SELECTOR_MISMATCH"
            )
        for row in exact_rows:
            if set(row) != DYNAMIC_REFERENCE_ENTRY_FIELDS:
                failures.append(
                    "IDENTITY_BINDING_DYNAMIC_REFERENCE_FIELD_SET_INVALID"
                )
                continue
            reference_id = str(row.get("dynamic_reference_id", ""))
            location = row.get("source_line_or_ast_location")
            targets = row.get("resolved_targets")
            runtime_probe = row.get("runtime_probe")
            policy = row.get("failure_policy")
            if (
                not reference_id
                or any(char in reference_id for char in "*?[]")
                or not _is_sha256(row.get("source_blob_sha256"))
                or not isinstance(location, dict)
                or set(location) != DYNAMIC_REFERENCE_LOCATION_FIELDS
                or not _is_int(location.get("line"))
                or location.get("line", 0) < 1
                or not _is_int(location.get("column"))
                or location.get("column", 0) < 1
                or not str(location.get("containing_function", ""))
                or not str(row.get("loader", ""))
                or not str(row.get("reference_expression", ""))
                or not isinstance(row.get("production_reachable"), bool)
                or not str(row.get("resolution_method", ""))
                or not isinstance(row.get("callsite_contract"), dict)
                or not row.get("callsite_contract")
                ):
                failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_METADATA_INVALID")
            failures.extend(_dynamic_reference_structure_failures(row))
            rendered_targets = (
                [str(value) for value in targets]
                if isinstance(targets, list)
                else []
            )
            if (
                not rendered_targets
                or rendered_targets != sorted(rendered_targets)
                or len(rendered_targets) != len(set(rendered_targets))
                or any(
                    not value.startswith("res://")
                    or normalize_path(value) != value[6:]
                    or any(char in value for char in "*?[]")
                    for value in rendered_targets
                )
                or row.get("target_set_sha256")
                != _dynamic_target_set_sha256(rendered_targets)
            ):
                failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_TARGET_SET_INVALID")
            if (
                not isinstance(runtime_probe, dict)
                or set(runtime_probe) != DYNAMIC_REFERENCE_RUNTIME_PROBE_FIELDS
                or not str(runtime_probe.get("probe_id", ""))
                or not str(runtime_probe.get("test_path", ""))
                or not _is_exact_int(
                    runtime_probe.get("expected_target_count"),
                    len(rendered_targets),
                )
                or runtime_probe.get("required_before_production_claim") is not True
            ):
                failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_RUNTIME_PROBE_INVALID")
            if (
                not isinstance(policy, dict)
                or set(policy) != DYNAMIC_REFERENCE_FAILURE_POLICY_FIELDS
                or policy.get("source_blob_change_invalidates") is not True
                or policy.get("source_location_change_invalidates") is not True
                or policy.get("target_set_change_invalidates") is not True
                or policy.get("unknown_callsite_fails_closed") is not True
                or not _is_exact_int(
                    policy.get("future_site_auto_resolution_count"), 0
                )
                or not _is_exact_int(policy.get("wildcard_count"), 0)
            ):
                failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_FAILURE_POLICY_INVALID")
    elif (
        isinstance(selector, dict)
        and selector.get("dynamic_reference_ids") != []
    ):
        failures.append("IDENTITY_BINDING_DYNAMIC_REFERENCE_SELECTOR_UNEXPECTED")

    selector_supersession_ids = (
        [str(value) for value in selector.get("supersession_ids", [])]
        if isinstance(selector, dict)
        and isinstance(selector.get("supersession_ids"), list)
        else []
    )
    selector_retirement_ids = (
        [str(value) for value in selector.get("retirement_ids", [])]
        if isinstance(selector, dict)
        and isinstance(selector.get("retirement_ids"), list)
        else []
    )
    supersession_rows = [
        row for row in projected["supersession_rows"] if isinstance(row, dict)
    ]
    if len(supersession_rows) != len(projected["supersession_rows"]):
        failures.append("IDENTITY_BINDING_DISPOSITION_AUTHORITY_ROW_INVALID")
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
        failures.append("IDENTITY_BINDING_DISPOSITION_AUTHORITY_KIND_INVALID")
    if set(projected_supersession_ids) != set(selector_supersession_ids):
        failures.append("IDENTITY_BINDING_SUPERSESSION_SELECTOR_UNRESOLVED")
    if any(
        projected_supersession_ids.count(authority_id) != 1
        for authority_id in selector_supersession_ids
    ):
        failures.append("IDENTITY_BINDING_SUPERSESSION_PRIMARY_KEY_NOT_UNIQUE")
    if set(projected_retirement_ids) != set(selector_retirement_ids):
        failures.append("IDENTITY_BINDING_RETIREMENT_SELECTOR_UNRESOLVED")
    if any(
        projected_retirement_ids.count(authority_id) != 1
        for authority_id in selector_retirement_ids
    ):
        failures.append("IDENTITY_BINDING_RETIREMENT_PRIMARY_KEY_NOT_UNIQUE")
    if disposition in {
        "HISTORICAL_SUPERSEDED_NONREACHABLE",
        "HISTORICAL_DYNAMIC_REFERENCE_SUPERSEDED",
    }:
        matching_rows = [
            row
            for row in supersession_rows
            if str(row.get("supersession_id", "")) in selector_supersession_ids
            and row.get("old_component_id")
            == binding.get("historical_component_id")
            and row.get("new_component_id") in binding.get("superseded_by", [])
            and row.get("domain_id") == binding.get("domain_id")
            and _is_exact_int(row.get("dual_write_count"), 0)
            and _is_exact_int(row.get("fallback_count"), 0)
            and _is_exact_int(row.get("old_owner_production_reachability"), 0)
        ]
        matched_ids = {
            str(row.get("supersession_id", "")) for row in matching_rows
        }
        matched_successors = sorted({
            str(row.get("new_component_id", ""))
            for row in matching_rows
            if row.get("new_component_id")
        })
        if (
            not selector_supersession_ids
            or len(matching_rows) != len(selector_supersession_ids)
            or matched_ids != set(selector_supersession_ids)
            or matched_successors != superseded_by
            or not set(matched_successors).issubset(selector_components)
            or binding.get("current_component_id") not in matched_successors
            or binding.get("historical_component_id") not in supersedes
        ):
            failures.append("IDENTITY_BINDING_SUPERSESSION_AUTHORITY_MISMATCH")
    elif selector_supersession_ids:
        failures.append("IDENTITY_BINDING_SUPERSESSION_SELECTOR_UNEXPECTED")
    if disposition == "HISTORICAL_RETIRED_NONREACHABLE":
        matching_rows = [
            row
            for row in supersession_rows
            if str(row.get("retirement_id", "")) in selector_retirement_ids
            and row.get("component_id") == binding.get("historical_component_id")
            and row.get("domain_id") == binding.get("domain_id")
            and row.get("production_reachable") is False
            and _is_exact_int(row.get("dual_write_count"), 0)
            and _is_exact_int(row.get("fallback_count"), 0)
            and row.get("retired_status") == "RETIRED_NONREACHABLE"
        ]
        matched_ids = {
            str(row.get("retirement_id", "")) for row in matching_rows
        }
        if (
            not selector_retirement_ids
            or len(matching_rows) != len(selector_retirement_ids)
            or matched_ids != set(selector_retirement_ids)
        ):
            failures.append("IDENTITY_BINDING_RETIREMENT_AUTHORITY_MISMATCH")
    elif selector_retirement_ids:
        failures.append("IDENTITY_BINDING_RETIREMENT_SELECTOR_UNEXPECTED")
    return sorted(set(failures))


def _dynamic_projection_repo_failures(
    root: Path,
    authority_commit: str,
    projection: dict[str, Any],
    *,
    source_commit: str,
) -> list[str]:
    failures: list[str] = []
    rows = projection.get("dynamic_reference_rows", [])
    if not isinstance(rows, list):
        return ["DYNAMIC_REFERENCE_PROJECTION_ROWS_INVALID"]
    for row in rows:
        if not isinstance(row, dict) or set(row) != DYNAMIC_REFERENCE_ENTRY_FIELDS:
            continue
        reference_id = str(row.get("dynamic_reference_id", ""))
        source_path = normalize_path(str(row.get("source_path", "")))
        source_bytes = (
            _git_bytes(root, source_commit, source_path)
            if source_path and _is_commit(source_commit)
            else None
        )
        if (
            source_bytes is None
            or sha256_bytes(source_bytes) != row.get("source_blob_sha256")
        ):
            failures.append(
                f"DYNAMIC_REFERENCE_SOURCE_BLOB_MISMATCH:{reference_id}"
            )
        if source_bytes is not None:
            source_text = source_bytes.decode(
                "utf-8-sig", errors="replace"
            )
            source_lines = source_text.splitlines()
            location = row.get("source_line_or_ast_location")
            line_number = (
                location.get("line") if isinstance(location, dict) else 0
            )
            column = (
                location.get("column") if isinstance(location, dict) else 0
            )
            loader = str(row.get("loader", ""))
            expression = str(row.get("reference_expression", ""))
            safe_line_number = line_number if _is_int(line_number) else 0
            source_line = (
                source_lines[safe_line_number - 1]
                if 1 <= safe_line_number <= len(source_lines)
                else ""
            )
            if (
                not source_line
                or not _is_int(column)
                or loader not in source_line
                or expression not in source_line
                or source_line.find(loader) + 1 != column
            ):
                failures.append(
                    f"DYNAMIC_REFERENCE_SOURCE_LOCATION_MISMATCH:{reference_id}"
                )
            containing_function = (
                str(location.get("containing_function", ""))
                if isinstance(location, dict)
                else ""
            )
            preceding_function = ""
            for candidate in reversed(
                source_lines[: max(safe_line_number - 1, 0)]
            ):
                match = re.match(r"\s*func\s+([A-Za-z0-9_]+)\s*\(", candidate)
                if match:
                    preceding_function = match.group(1)
                    break
            if preceding_function != containing_function:
                failures.append(
                    f"DYNAMIC_REFERENCE_CONTAINING_FUNCTION_MISMATCH:{reference_id}"
                )
            callsite = row.get("callsite_contract")
            sites = (
                callsite.get("required_loader_sites", [])
                if isinstance(callsite, dict)
                else []
            )
            for site in sites if isinstance(sites, list) else []:
                if not isinstance(site, dict):
                    continue
                site_line_number = site.get("line")
                site_column = site.get("column")
                site_loader = str(site.get("loader", ""))
                site_expression = str(site.get("reference_expression", ""))
                site_line = (
                    source_lines[site_line_number - 1]
                    if _is_int(site_line_number)
                    and 1 <= site_line_number <= len(source_lines)
                    else ""
                )
                if (
                    not site_line
                    or not _is_int(site_column)
                    or site_loader not in site_line
                    or site_expression not in site_line
                    or site_line.find(site_loader) + 1 != site_column
                ):
                    failures.append(
                        f"DYNAMIC_REFERENCE_LOADER_SITE_MISMATCH:{reference_id}"
                    )
            if isinstance(callsite, dict):
                helper = str(callsite.get("helper_function", ""))
                allowed_constants = [
                    str(value)
                    for value in callsite.get("allowed_argument_constants", [])
                ] if isinstance(
                    callsite.get("allowed_argument_constants"), list
                ) else []
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
                            for match in invocation_pattern.finditer(
                                source_line_candidate
                            )
                        )
                declared_targets = sorted(
                    str(value) for value in row.get("resolved_targets", [])
                ) if isinstance(row.get("resolved_targets"), list) else []
                if (
                    not allowed_constants
                    or any(not value for value in resolved_constant_targets)
                    or resolved_constant_targets != declared_targets
                    or sorted(helper_invocations) != sorted(allowed_constants)
                    or not _is_exact_int(
                        callsite.get("required_invocation_count"),
                        len(helper_invocations),
                    )
                ):
                    failures.append(
                        f"DYNAMIC_REFERENCE_CALLSITE_TARGET_BINDING_MISMATCH:{reference_id}"
                    )
        targets = row.get("resolved_targets", [])
        if isinstance(targets, list):
            for target in targets:
                target_path = normalize_path(str(target))
                if (
                    not target_path
                    or _git_bytes(root, authority_commit, target_path) is None
                ):
                    failures.append(
                        f"DYNAMIC_REFERENCE_TARGET_MISSING:{reference_id}:{target_path}"
                    )
        runtime_probe = row.get("runtime_probe")
        test_path = (
            normalize_path(str(runtime_probe.get("test_path", "")))
            if isinstance(runtime_probe, dict)
            else ""
        )
        if (
            not test_path
            or _git_bytes(root, authority_commit, test_path) is None
            or Path(test_path).stem
            != str(runtime_probe.get("probe_id", ""))
        ):
            failures.append(
                f"DYNAMIC_REFERENCE_RUNTIME_PROBE_MISSING:{reference_id}:{test_path}"
            )
    return sorted(set(failures))


def _record_payload(record: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in record.items() if key != "record_payload_sha256"}


def validate_extension_record_document(record: Any) -> list[str]:
    if not isinstance(record, dict):
        return ["EXTENSION_RECORD_NOT_OBJECT"]
    failures: list[str] = []
    if set(record) != set(EXTENSION_RECORD_FIELDS):
        failures.append("EXTENSION_RECORD_FIELD_SET_MISMATCH")
    for field, expected in (
        ("schema_version", SCHEMA_VERSION),
        ("record_kind", "CORRECTION_RECORD"),
        ("authorization_id", AUTHORIZATION_ID),
        ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD_SHA),
        ("baseline_report_sha256", AUTHORIZED_BASELINE_REPORT_SHA256),
        ("baseline_failure_set_sha256", AUTHORIZED_BASELINE_FAILURE_SET_SHA256),
        ("record_chain_start_sha256", None),
    ):
        if expected is not None and record.get(field) != expected:
            failures.append(f"EXTENSION_RECORD_{field.upper()}_MISMATCH")
    if not _is_commit(record.get("binding_head_sha")):
        failures.append("EXTENSION_RECORD_BINDING_HEAD_INVALID")
    if not _is_sha256(record.get("binding_tree_sha")) and not _is_commit(record.get("binding_tree_sha")):
        failures.append("EXTENSION_RECORD_BINDING_TREE_INVALID")
    fingerprints = record.get("failure_fingerprints")
    if not isinstance(fingerprints, list) or not fingerprints:
        failures.append("EXTENSION_RECORD_FINGERPRINTS_MISSING")
        fingerprints = []
    rendered = [str(value) for value in fingerprints]
    if len(rendered) > 50:
        failures.append("EXTENSION_RECORD_FINGERPRINT_COUNT_EXCEEDS_50")
    if len(rendered) != len(set(rendered)) or rendered != sorted(rendered):
        failures.append("EXTENSION_RECORD_FINGERPRINT_SET_INVALID")
    if any(not re.fullmatch(r"V2F-[0-9a-f]{64}", value) for value in rendered):
        failures.append("EXTENSION_RECORD_FINGERPRINT_FORMAT_INVALID")
    if not _is_exact_int(record.get("failure_count"), len(rendered)):
        failures.append("EXTENSION_RECORD_FINGERPRINT_COUNT_MISMATCH")
    if record.get("failure_fingerprint_set_sha256") != _line_set_sha(rendered):
        failures.append("EXTENSION_RECORD_FINGERPRINT_SET_HASH_MISMATCH")
    rules = record.get("rule_ids")
    classes = record.get("failure_classes")
    if (
        not isinstance(rules, list)
        or len(rules) != 1
        or not str(rules[0]).startswith("HISTORY_")
        or classes != rules
        or record.get("allowed_rule_ids") != rules
    ):
        failures.append("EXTENSION_RECORD_RULE_CLASS_INVALID")
    transition = str(record.get("transition_class_id", ""))
    if (
        not transition
        or any(char in transition for char in "*?[]")
        or re.fullmatch(r"[A-Z0-9_]+", transition) is None
        or set(re.findall(r"[a-z0-9_]+", transition.casefold())) & DISALLOWED_TOKENS
    ):
        failures.append("EXTENSION_RECORD_TRANSITION_CLASS_INVALID")
    if record.get("from_state") != "HISTORICAL_FAILURE_PRESENT_CLASSIFIED":
        failures.append("EXTENSION_RECORD_FROM_STATE_INVALID")
    if record.get("to_effective_disposition") != "CORRECTED_HISTORICAL_DEBT":
        failures.append("EXTENSION_RECORD_TO_STATE_INVALID")
    if record.get("allowed_from_state") != record.get("from_state") or record.get("allowed_to_state") != record.get("to_effective_disposition"):
        failures.append("EXTENSION_RECORD_ALLOWED_STATE_MISMATCH")
    if record.get("untouched_in_current_delta") is not True or record.get("required_untouched_state") is not True:
        failures.append("EXTENSION_RECORD_UNTOUCHED_ATTESTATION_INVALID")
    future = record.get("future_failure_policy")
    if not isinstance(future, dict) or future != {
        "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
        "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
    }:
        failures.append("EXTENSION_RECORD_FUTURE_AUTO_CORRECTION_ENABLED")
    touch = record.get("touch_invalidation_policy")
    required_touch = {
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
    if touch != required_touch:
        failures.append("EXTENSION_RECORD_TOUCH_POLICY_INVALID")
    if record.get("revocation_policy") != {
        "OLD_RECORD_MUTATION_FORBIDDEN": True,
        "REVOCATION_APPEND_ONLY": True,
    }:
        failures.append("EXTENSION_RECORD_REVOCATION_POLICY_INVALID")
    previous = record.get("previous_correction_chain_sha256")
    if not _is_sha256(previous):
        failures.append("EXTENSION_RECORD_CHAIN_PREDECESSOR_INVALID")
    bindings = record.get("identity_binding_by_failure")
    if not isinstance(bindings, dict) or set(bindings) != set(rendered):
        failures.append("EXTENSION_RECORD_IDENTITY_BINDING_SET_MISMATCH")
        bindings = {}
    for fingerprint, binding in bindings.items():
        if not isinstance(binding, dict) or set(binding) != set(IDENTITY_BINDING_FIELDS):
            failures.append(f"IDENTITY_BINDING_FIELD_SET_MISMATCH:{fingerprint}")
            continue
        failures.extend(f"{failure}:{fingerprint}" for failure in _selector_failures(binding.get("authority_selectors")))
        disposition = str(binding.get("recommended_disposition", ""))
        if disposition not in ALLOWED_DISPOSITIONS:
            failures.append(f"IDENTITY_BINDING_DISPOSITION_INVALID:{fingerprint}")
        rule_id = str(rules[0]) if isinstance(rules, list) and len(rules) == 1 else ""
        failures.extend(
            f"{failure}:{fingerprint}"
            for failure in _identity_disposition_failures(
                binding,
                rule_id=rule_id,
            )
        )
        failures.extend(
            f"{failure}:{fingerprint}"
            for failure in _identity_projection_failures(
                binding,
                rule_id=rule_id,
            )
        )
        for key in ("source_commit", "first_seen_commit", "last_seen_commit"):
            if not _is_commit(binding.get(key)):
                failures.append(f"IDENTITY_BINDING_COMMIT_INVALID:{key}:{fingerprint}")
        for key in ("historical_blob_sha256", "current_blob_sha256"):
            value = binding.get(key)
            if value != "MISSING" and not _is_sha256(value):
                failures.append(f"IDENTITY_BINDING_BLOB_INVALID:{key}:{fingerprint}")
        for key in ("historical_path", "current_path"):
            value = str(binding.get(key, ""))
            if value and (
                normalize_path(value) != value
                or value.startswith(("/", "../"))
                or value.endswith("/")
                or "/../" in value
                or any(char in value for char in "*?[]")
            ):
                failures.append(f"IDENTITY_BINDING_PATH_INVALID:{key}:{fingerprint}")
        projection = binding.get("subject_projection")
        if not isinstance(projection, dict):
            failures.append(f"IDENTITY_BINDING_PROJECTION_INVALID:{fingerprint}")
        elif binding.get("subject_projection_sha256") != sha256_bytes(canonical_bytes(projection)):
            failures.append(f"IDENTITY_BINDING_PROJECTION_HASH_MISMATCH:{fingerprint}")
        if binding.get("invalidation_policy") != touch:
            failures.append(f"IDENTITY_BINDING_INVALIDATION_POLICY_MISMATCH:{fingerprint}")
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
        failures.append("EXTENSION_RECORD_IDENTITY_GROUPING_MISMATCH")
    expected_sets = {
        "paths": sorted({
            normalize_path(str(binding.get(key, "")))
            for binding in bindings.values()
            if isinstance(binding, dict)
            for key in ("historical_path", "current_path")
            if binding.get(key)
        }),
        "component_ids": sorted({
            str(binding.get(key, ""))
            for binding in bindings.values()
            if isinstance(binding, dict)
            for key in ("historical_component_id", "current_component_id")
            if binding.get(key)
        }),
        "domain_ids": sorted({
            str(binding.get("domain_id", ""))
            for binding in bindings.values()
            if isinstance(binding, dict) and binding.get("domain_id")
        }),
        "owner_ids": sorted({
            str(binding.get(key, ""))
            for binding in bindings.values()
            if isinstance(binding, dict)
            for key in ("historical_owner_id", "current_owner_id")
            if binding.get(key)
        }),
        "dynamic_reference_ids": sorted({
            str(value)
            for binding in bindings.values()
            if isinstance(binding, dict)
            for value in (
                binding.get("authority_selectors", {}).get(
                    "dynamic_reference_ids", []
                )
                if isinstance(binding.get("authority_selectors"), dict)
                else []
            )
        }),
        "supersession_ids": sorted({
            str(value)
            for binding in bindings.values()
            if isinstance(binding, dict)
            for value in (
                binding.get("authority_selectors", {}).get("supersession_ids", [])
                if isinstance(binding.get("authority_selectors"), dict) else []
            )
        }),
        "retirement_ids": sorted({
            str(value)
            for binding in bindings.values()
            if isinstance(binding, dict)
            for value in (
                binding.get("authority_selectors", {}).get("retirement_ids", [])
                if isinstance(binding.get("authority_selectors"), dict) else []
            )
        }),
        "source_commit_set": sorted({
            str(binding.get("source_commit", ""))
            for binding in bindings.values()
            if isinstance(binding, dict) and binding.get("source_commit")
        }),
    }
    hash_fields = {
        "paths": "path_set_sha256",
        "component_ids": "component_set_sha256",
        "domain_ids": "domain_set_sha256",
        "owner_ids": "owner_set_sha256",
        "dynamic_reference_ids": "dynamic_reference_set_sha256",
        "supersession_ids": "supersession_set_sha256",
        "retirement_ids": "retirement_set_sha256",
        "source_commit_set": "source_commit_set_sha256",
    }
    for field, expected in expected_sets.items():
        if record.get(field) != expected:
            failures.append(f"EXTENSION_RECORD_{field.upper()}_MISMATCH")
        if record.get(hash_fields[field]) != _line_set_sha(expected):
            failures.append(f"EXTENSION_RECORD_{hash_fields[field].upper()}_MISMATCH")
    source_hashes = record.get("authority_source_sha256")
    if not isinstance(source_hashes, dict) or set(source_hashes) != set(AUTHORITY_SOURCE_PATHS):
        failures.append("EXTENSION_RECORD_AUTHORITY_SOURCE_SET_INVALID")
    elif any(not _is_sha256(value) for value in source_hashes.values()):
        failures.append("EXTENSION_RECORD_AUTHORITY_SOURCE_HASH_INVALID")
    for field in (
        "batch_inventory_sha256", "batch_classification_sha256", "batch_negative_checks_sha256",
        "batch_review_a_sha256", "batch_review_b_sha256",
        "descendant_history_supplement_sha256",
    ):
        if not _is_sha256(record.get(field)):
            failures.append(f"EXTENSION_RECORD_{field.upper()}_INVALID")
    if not isinstance(record.get("batch_id"), str) or not re.fullmatch(r"batch-[0-9]{3}", record.get("batch_id", "")):
        failures.append("EXTENSION_RECORD_BATCH_ID_INVALID")
    for field in ("correction_id", "correction_reason", "creator"):
        value = str(record.get(field, ""))
        if not value or any(char in value for char in "*?[]"):
            failures.append(f"EXTENSION_RECORD_{field.upper()}_INVALID")
    if re.fullmatch(
        r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",
        str(record.get("created_at", "")),
    ) is None:
        failures.append("EXTENSION_RECORD_CREATED_AT_INVALID")
    backlog_ids = record.get("backlog_item_ids")
    rendered_backlog = (
        [str(value) for value in backlog_ids]
        if isinstance(backlog_ids, list)
        else []
    )
    if (
        not rendered_backlog
        or rendered_backlog != sorted(rendered_backlog)
        or len(rendered_backlog) != len(set(rendered_backlog))
        or any(
            not value or any(char in value for char in "*?[]")
            for value in rendered_backlog
        )
    ):
        failures.append("EXTENSION_RECORD_BACKLOG_ITEM_IDS_INVALID")
    negative_examples = record.get("negative_examples")
    rendered_negative = (
        [str(value) for value in negative_examples]
        if isinstance(negative_examples, list)
        else []
    )
    if not {"CURRENT_DELTA_FAILURE", "WILDCARD"}.issubset(
        set(rendered_negative)
    ):
        failures.append("EXTENSION_RECORD_NEGATIVE_EXAMPLES_INVALID")
    if record.get("record_payload_sha256") != sha256_bytes(canonical_bytes(_record_payload(record))):
        failures.append("EXTENSION_RECORD_PAYLOAD_HASH_MISMATCH")
    return sorted(set(failures))


def _resolve_commit_prefix(root: Path, prefix: str) -> str:
    if not re.fullmatch(r"[0-9a-f]{12}", prefix):
        return ""
    try:
        resolved = _git(root, "rev-parse", f"{prefix}^{{commit}}")
    except ValueError:
        return ""
    return resolved if _is_commit(resolved) and resolved.startswith(prefix) else ""


def _supplement_source_commit_is_authorized(
    root: Path,
    source_commit: str,
    supplement_head: str,
) -> bool:
    """Accept one exact historical source only inside the sealed report past."""

    return (
        _is_commit(source_commit)
        and _is_commit(supplement_head)
        and _is_ancestor(root, source_commit, supplement_head)
    )


def _authorized_identity_binding_failures(
    root: Path,
    fingerprint: str,
    binding: dict[str, Any],
    identity: dict[str, str] | None,
    *,
    record_rule_ids: list[str],
) -> list[str]:
    failures: list[str] = []
    if not isinstance(identity, dict) or identity.get("bucket") != "HISTORICAL":
        return [f"IDENTITY_BASELINE_RAW_UNRESOLVED:{fingerprint}"]
    rule_id = str(identity.get("rule_id", ""))
    failures.extend(
        f"{failure}:{fingerprint}"
        for failure in _identity_projection_failures(
            binding,
            rule_id=rule_id,
            raw_failure=str(identity.get("raw_failure", "")),
        )
    )
    if record_rule_ids != [rule_id]:
        failures.append(f"IDENTITY_BASELINE_RULE_MISMATCH:{fingerprint}")
    source_commit = _resolve_commit_prefix(root, str(identity.get("transition_new_prefix", "")))
    old_commit = _resolve_commit_prefix(root, str(identity.get("transition_old_prefix", "")))
    if not source_commit or not old_commit:
        failures.append(f"IDENTITY_BASELINE_TRANSITION_UNRESOLVED:{fingerprint}")
    else:
        try:
            parent = _git(root, "rev-parse", f"{source_commit}^1")
        except ValueError:
            parent = ""
        if parent != old_commit:
            failures.append(f"IDENTITY_BASELINE_TRANSITION_NOT_DIRECT_PARENT:{fingerprint}")
        if binding.get("source_commit") != source_commit:
            failures.append(f"IDENTITY_BASELINE_SOURCE_COMMIT_MISMATCH:{fingerprint}")
        if binding.get("first_seen_commit") != source_commit:
            failures.append(f"IDENTITY_BASELINE_FIRST_SEEN_COMMIT_MISMATCH:{fingerprint}")
        last_seen = str(binding.get("last_seen_commit", ""))
        if identity.get("authority_origin") == "DESCENDANT_HISTORY_SUPPLEMENT":
            supplement_head = str(identity.get("supplement_raw_report_head_sha", ""))
            if (
                not _is_commit(last_seen)
                or not _is_ancestor(root, source_commit, last_seen)
                or not _is_ancestor(root, last_seen, supplement_head)
            ):
                failures.append(f"IDENTITY_SUPPLEMENT_LAST_SEEN_COMMIT_INVALID:{fingerprint}")
        elif (
            not _is_commit(last_seen)
            or not _is_ancestor(root, source_commit, last_seen)
            or not _is_ancestor(root, last_seen, AUTHORIZATION_BASE_HEAD_SHA)
        ):
            failures.append(f"IDENTITY_BASELINE_LAST_SEEN_COMMIT_INVALID:{fingerprint}")
    subject_kind = identity.get("subject_kind")
    subject_value = normalize_path(str(identity.get("subject_value", "")))
    selector = binding.get("authority_selectors")
    selector_paths = set(selector.get("paths", [])) if isinstance(selector, dict) else set()
    selector_components = set(selector.get("component_ids", [])) if isinstance(selector, dict) else set()
    if subject_kind == "path":
        if normalize_path(str(binding.get("historical_path", ""))) != subject_value:
            failures.append(f"IDENTITY_BASELINE_HISTORICAL_PATH_MISMATCH:{fingerprint}")
        if subject_value not in selector_paths:
            failures.append(f"IDENTITY_BASELINE_PATH_SELECTOR_MISSING:{fingerprint}")
    elif subject_kind == "component_id":
        component_values = {
            str(binding.get("historical_component_id", "")),
            str(binding.get("current_component_id", "")),
        }
        if subject_value not in component_values:
            failures.append(f"IDENTITY_BASELINE_COMPONENT_ID_MISMATCH:{fingerprint}")
        if subject_value not in selector_components:
            failures.append(f"IDENTITY_BASELINE_COMPONENT_SELECTOR_MISSING:{fingerprint}")
    else:
        failures.append(f"IDENTITY_BASELINE_SUBJECT_UNRESOLVED:{fingerprint}")
    if identity.get("authority_origin") == "DESCENDANT_HISTORY_SUPPLEMENT":
        supplement_source_path = normalize_path(str(identity.get("source_path", "")))
        if normalize_path(str(binding.get("historical_path", ""))) != supplement_source_path:
            failures.append(f"IDENTITY_SUPPLEMENT_SOURCE_PATH_MISMATCH:{fingerprint}")
        if supplement_source_path not in selector_paths:
            failures.append(f"IDENTITY_SUPPLEMENT_SOURCE_PATH_SELECTOR_MISSING:{fingerprint}")
    binding_paths = {
        normalize_path(str(binding.get(key, "")))
        for key in ("historical_path", "current_path")
        if binding.get(key)
    }
    binding_components = {
        str(binding.get(key, ""))
        for key in ("historical_component_id", "current_component_id")
        if binding.get(key)
    }
    if not binding_paths.issubset(selector_paths):
        failures.append(f"IDENTITY_BINDING_PATH_SELECTOR_COVERAGE_MISMATCH:{fingerprint}")
    if not binding_components.issubset(selector_components):
        failures.append(f"IDENTITY_BINDING_COMPONENT_SELECTOR_COVERAGE_MISMATCH:{fingerprint}")
    current_path = normalize_path(str(binding.get("current_path", "")))
    current_blob = binding.get("current_blob_sha256")
    disposition = str(binding.get("recommended_disposition", ""))
    if not current_path:
        if current_blob != "MISSING":
            failures.append(f"IDENTITY_MISSING_CURRENT_PATH_BLOB_NOT_MISSING:{fingerprint}")
        if disposition == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED":
            failures.append(f"IDENTITY_ACTIVE_LINEAGE_CURRENT_PATH_MISSING:{fingerprint}")
    return sorted(set(failures))


def validate_extension_record_against_repo(
    root: Path,
    record: dict[str, Any],
    *,
    evaluated_head: str,
    authorized_identities: dict[str, dict[str, str]] | None = None,
) -> list[str]:
    failures = validate_extension_record_document(record)
    if not isinstance(record, dict):
        return failures
    binding_head = str(record.get("binding_head_sha", ""))
    if not _is_commit(binding_head) or not _is_commit(evaluated_head):
        return sorted(set(failures + ["EXTENSION_RECORD_EVALUATED_HEAD_INVALID"]))
    if not _is_ancestor(root, AUTHORIZATION_BASE_HEAD_SHA, binding_head):
        failures.append("EXTENSION_RECORD_BINDING_HEAD_NOT_AUTHORIZED_DESCENDANT")
    if not _is_ancestor(root, binding_head, evaluated_head):
        failures.append("EXTENSION_RECORD_EVALUATED_HEAD_NOT_BINDING_DESCENDANT")
    try:
        tree = _git(root, "rev-parse", f"{binding_head}^{{tree}}")
    except ValueError:
        tree = ""
    if record.get("binding_tree_sha") != tree:
        failures.append("EXTENSION_RECORD_BINDING_TREE_MISMATCH")
    source_hashes = record.get("authority_source_sha256", {})
    for relative in AUTHORITY_SOURCE_PATHS:
        payload = _git_bytes(root, binding_head, relative)
        digest = sha256_bytes(payload) if payload is not None else "MISSING"
        if not isinstance(source_hashes, dict) or source_hashes.get(relative) != digest:
            failures.append(f"EXTENSION_RECORD_AUTHORITY_SOURCE_MISMATCH:{relative}")
    try:
        changed_paths = {
            normalize_path(value)
            for value in _git(root, "diff", "--name-only", binding_head, evaluated_head).splitlines()
            if value.strip()
        }
    except ValueError:
        changed_paths = set()
        failures.append("EXTENSION_RECORD_TOUCH_SET_UNRESOLVED")
    identity_map = authorized_identities or {}
    bindings = record.get("identity_binding_by_failure", {})
    if isinstance(bindings, dict):
        for fingerprint, binding in bindings.items():
            if not isinstance(binding, dict):
                continue
            selector = binding.get("authority_selectors")
            failures.extend(
                _authorized_identity_binding_failures(
                    root,
                    str(fingerprint),
                    binding,
                    identity_map.get(str(fingerprint)),
                    record_rule_ids=[str(value) for value in record.get("rule_ids", [])],
                )
            )
            if (
                binding.get("recommended_disposition")
                == "HISTORICAL_DUPLICATE_OBSERVATION"
            ):
                raw_identity = identity_map.get(str(fingerprint), {})
                duplicate_target = str(
                    binding.get("duplicate_of_failure_fingerprint", "")
                )
                duplicate_identity = identity_map.get(duplicate_target, {})
                peers = sorted(
                    other_fingerprint
                    for other_fingerprint, other_identity in identity_map.items()
                    if other_fingerprint != str(fingerprint)
                    and other_identity.get("rule_id") == raw_identity.get("rule_id")
                    and other_identity.get("subject_kind")
                    == raw_identity.get("subject_kind")
                    and other_identity.get("subject_value")
                    == raw_identity.get("subject_value")
                )
                canonical = min([str(fingerprint), *peers]) if peers else ""
                duplicate_digest = sha256_bytes(canonical_bytes(
                    _duplicate_identity_payload(duplicate_identity)
                )) if duplicate_identity else ""
                if (
                    not peers
                    or canonical == str(fingerprint)
                    or duplicate_target != canonical
                    or duplicate_target == str(fingerprint)
                    or duplicate_identity.get("rule_id")
                    != raw_identity.get("rule_id")
                    or duplicate_identity.get("subject_kind")
                    != raw_identity.get("subject_kind")
                    or duplicate_identity.get("subject_value")
                    != raw_identity.get("subject_value")
                    or binding.get("duplicate_identity_sha256")
                    != duplicate_digest
                ):
                    failures.append(
                        f"IDENTITY_DUPLICATE_OBSERVATION_AUTHORITY_MISMATCH:{fingerprint}"
                    )
            source_commit = str(binding.get("source_commit", ""))
            authorized_identity = (authorized_identities or {}).get(str(fingerprint), {})
            if _is_commit(source_commit):
                if authorized_identity.get("authority_origin") == "DESCENDANT_HISTORY_SUPPLEMENT":
                    supplement_head = str(
                        authorized_identity.get("supplement_raw_report_head_sha", "")
                    )
                    # A descendant supplement discovers a historical failure
                    # in a report evaluated after the authorization base. The
                    # component transition itself may legitimately predate
                    # that base (the source commit is still an exact ancestor
                    # of the sealed supplement report head). Requiring
                    # AUTHORIZATION_BASE_HEAD_SHA -> source_commit here would
                    # reject precisely those valid pre-base transitions and
                    # contradict the supplement validator's source->report
                    # ancestry contract.
                    if not _supplement_source_commit_is_authorized(
                        root,
                        source_commit,
                        supplement_head,
                    ):
                        failures.append(
                            f"IDENTITY_SOURCE_COMMIT_NOT_AUTHORIZED_SUPPLEMENT_DESCENDANT:{fingerprint}"
                        )
                elif not _is_ancestor(root, source_commit, AUTHORIZATION_BASE_HEAD_SHA):
                    failures.append(f"IDENTITY_SOURCE_COMMIT_NOT_AUTHORIZED_ANCESTOR:{fingerprint}")
            historical_path = normalize_path(str(binding.get("historical_path", "")))
            current_path = normalize_path(str(binding.get("current_path", "")))
            if historical_path and _is_commit(source_commit):
                historical_payload = _git_bytes(root, source_commit, historical_path)
                historical_digest = sha256_bytes(historical_payload) if historical_payload is not None else "MISSING"
                if historical_digest != binding.get("historical_blob_sha256"):
                    failures.append(f"HISTORICAL_BLOB_BINDING_MISMATCH:{fingerprint}")
            if current_path:
                binding_payload = _git_bytes(root, binding_head, current_path)
                binding_digest = sha256_bytes(binding_payload) if binding_payload is not None else "MISSING"
                evaluated_payload = _git_bytes(root, evaluated_head, current_path)
                evaluated_digest = sha256_bytes(evaluated_payload) if evaluated_payload is not None else "MISSING"
                if binding_digest != binding.get("current_blob_sha256"):
                    failures.append(f"CURRENT_BLOB_BINDING_MISMATCH:{fingerprint}")
                if evaluated_digest != binding.get("current_blob_sha256"):
                    failures.append(f"BLOB_CHANGED_CORRECTION_INVALID:{fingerprint}")
            if any(path and path in changed_paths for path in (historical_path, current_path)):
                failures.append(f"TOUCHED_CORRECTION_INVALID:{fingerprint}")
            try:
                bound_projection = subject_projection(root, binding_head, selector)
            except (ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
                failures.append(f"SUBJECT_PROJECTION_BINDING_UNRESOLVED:{fingerprint}")
                continue
            if bound_projection != binding.get("subject_projection"):
                failures.append(f"SUBJECT_PROJECTION_BINDING_MISMATCH:{fingerprint}")
            failures.extend(
                f"{failure}:{fingerprint}"
                for failure in _dynamic_projection_repo_failures(
                    root,
                    binding_head,
                    bound_projection,
                    source_commit=source_commit,
                )
            )
            try:
                evaluated_projection = subject_projection(root, evaluated_head, selector)
            except (ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
                failures.append(f"SUBJECT_PROJECTION_CHANGED_INVALID:{fingerprint}")
                continue
            if sha256_bytes(canonical_bytes(evaluated_projection)) != binding.get("subject_projection_sha256"):
                failures.append(f"SUBJECT_PROJECTION_CHANGED_INVALID:{fingerprint}")
            failures.extend(
                f"{failure}:{fingerprint}"
                for failure in _dynamic_projection_repo_failures(
                    root,
                    evaluated_head,
                    evaluated_projection,
                    source_commit=source_commit,
                )
            )
    return sorted(set(failures))


def validate_batch_manifest_document(manifest: Any) -> list[str]:
    if not isinstance(manifest, dict):
        return ["BATCH_MANIFEST_NOT_OBJECT"]
    failures: list[str] = []
    if set(manifest) != set(BATCH_MANIFEST_FIELDS):
        failures.append("BATCH_MANIFEST_FIELD_SET_MISMATCH")
    for field, expected in (
        ("schema_version", BATCH_MANIFEST_SCHEMA_VERSION),
        ("authorization_id", AUTHORIZATION_ID),
        ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD_SHA),
        ("baseline_report_sha256", AUTHORIZED_BASELINE_REPORT_SHA256),
        ("baseline_failure_set_sha256", AUTHORIZED_BASELINE_FAILURE_SET_SHA256),
        ("batch_size_target", "25_TO_50_FAILURE_FINGERPRINTS"),
        ("batch_review_a_status", "GO"),
        ("batch_review_b_status", "GO"),
        ("identity_coverage_percent", 100),
        ("batch_unknown_count", 0),
        ("batch_wildcard_count", 0),
        ("current_failure_false_accept_count", 0),
    ):
        if (
            type(expected) is int
            and not _is_exact_int(manifest.get(field), expected)
        ) or (
            type(expected) is not int
            and manifest.get(field) != expected
        ):
            failures.append(f"BATCH_MANIFEST_{field.upper()}_MISMATCH")
    batch_id = str(manifest.get("batch_id", ""))
    batch_match = re.fullmatch(r"batch-([0-9]{3})", batch_id)
    if batch_match is None:
        failures.append("BATCH_MANIFEST_BATCH_ID_INVALID")
    fingerprints = manifest.get("failure_fingerprints")
    if not isinstance(fingerprints, list):
        failures.append("BATCH_MANIFEST_FINGERPRINTS_INVALID")
        fingerprints = []
    rendered = [str(value) for value in fingerprints]
    if len(rendered) != len(set(rendered)) or rendered != sorted(rendered):
        failures.append("BATCH_MANIFEST_FINGERPRINT_SET_INVALID")
    if any(not re.fullmatch(r"V2F-[0-9a-f]{64}", value) for value in rendered):
        failures.append("BATCH_MANIFEST_FINGERPRINT_FORMAT_INVALID")
    if not _is_exact_int(manifest.get("failure_count"), len(rendered)):
        failures.append("BATCH_MANIFEST_FINGERPRINT_COUNT_MISMATCH")
    if len(rendered) > 50 or len(rendered) == 0:
        failures.append("BATCH_MANIFEST_SIZE_OUT_OF_RANGE")
    if not isinstance(manifest.get("terminal_remainder_batch"), bool):
        failures.append("BATCH_MANIFEST_TERMINAL_REMAINDER_FLAG_INVALID")
    if len(rendered) < 25 and manifest.get("terminal_remainder_batch") is not True:
        failures.append("BATCH_MANIFEST_NONTERMINAL_BELOW_TARGET")
    if manifest.get("failure_fingerprint_set_sha256") != _line_set_sha(rendered):
        failures.append("BATCH_MANIFEST_FINGERPRINT_SET_HASH_MISMATCH")
    if not _is_commit(manifest.get("binding_head_sha")):
        failures.append("BATCH_MANIFEST_BINDING_HEAD_INVALID")
    if not _is_commit(manifest.get("binding_tree_sha")):
        failures.append("BATCH_MANIFEST_BINDING_TREE_INVALID")
    for field in (
        "batch_inventory_sha256", "batch_classification_sha256", "batch_negative_checks_sha256",
        "batch_review_a_sha256", "batch_review_b_sha256", "record_chain_start_sha256",
        "record_chain_terminal_sha256", "descendant_history_supplement_sha256",
    ):
        if not _is_sha256(manifest.get(field)):
            failures.append(f"BATCH_MANIFEST_{field.upper()}_INVALID")
    previous_batch = manifest.get("previous_batch_append_sha256")
    if previous_batch != "" and not _is_sha256(previous_batch):
        failures.append("BATCH_MANIFEST_PREVIOUS_APPEND_INVALID")
    if batch_match is not None:
        batch_number = int(batch_match.group(1))
        if batch_number == 1 and previous_batch != "":
            failures.append("BATCH_MANIFEST_INITIAL_BATCH_PREVIOUS_APPEND_INVALID")
        if batch_number > 1 and not _is_sha256(previous_batch):
            failures.append("BATCH_MANIFEST_NONINITIAL_PREVIOUS_APPEND_REQUIRED")
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or not bindings:
        failures.append("BATCH_MANIFEST_RECORD_BINDINGS_INVALID")
        bindings = []
    covered: list[str] = []
    previous = str(manifest.get("record_chain_start_sha256", ""))
    for index, binding in enumerate(bindings):
        if not isinstance(binding, dict) or set(binding) != {
            "correction_id", "failure_fingerprints", "path", "record_payload_sha256",
            "record_sha256", "previous_correction_chain_sha256",
        }:
            failures.append(f"BATCH_MANIFEST_RECORD_BINDING_INVALID:{index}")
            continue
        path = normalize_path(str(binding.get("path", "")))
        expected_prefix = RECORD_ROOT_REL / batch_id
        if (
            not path.startswith(expected_prefix.as_posix() + "/")
            or path.endswith("/")
            or any(char in path for char in "*?[]")
            or "/../" in path
        ):
            failures.append(f"BATCH_MANIFEST_RECORD_PATH_INVALID:{index}")
        if binding.get("previous_correction_chain_sha256") != previous:
            failures.append(f"BATCH_MANIFEST_RECORD_CHAIN_BREAK:{index}")
        payload_hash = binding.get("record_payload_sha256")
        if not _is_sha256(payload_hash) or not _is_sha256(binding.get("record_sha256")):
            failures.append(f"BATCH_MANIFEST_RECORD_HASH_INVALID:{index}")
        previous = str(payload_hash)
        row_fingerprints = binding.get("failure_fingerprints")
        if not isinstance(row_fingerprints, list) or not row_fingerprints:
            failures.append(f"BATCH_MANIFEST_RECORD_FINGERPRINTS_INVALID:{index}")
        else:
            covered.extend(str(value) for value in row_fingerprints)
    if previous != manifest.get("record_chain_terminal_sha256"):
        failures.append("BATCH_MANIFEST_CHAIN_TERMINAL_MISMATCH")
    if sorted(covered) != rendered or len(covered) != len(set(covered)):
        failures.append("BATCH_MANIFEST_RECORD_COVERAGE_MISMATCH")
    if not manifest.get("previous_batch_append_sha256") and manifest.get("record_chain_start_sha256") != LEGACY_RECORD_CHAIN_TERMINAL_SHA256:
        failures.append("BATCH_MANIFEST_FIRST_BATCH_LEGACY_CHAIN_ANCHOR_MISMATCH")
    return sorted(set(failures))


def _derive_prior_manifest_path(
    current_path: Path,
    current_batch_id: str,
    prior_batch_id: str,
) -> Path | None:
    if current_path.parent.name == current_batch_id:
        # Canonical repository manifests are named after their batch
        # (batch-NNN/batch-NNN-manifest.json). Preserve the explicit filename
        # shape while changing only the sequence token; otherwise a canonical
        # batch-002 predecessor incorrectly resolves to
        # batch-001/batch-002-manifest.json. This remains sequence-bound and
        # performs no directory discovery.
        filename = current_path.name
        if current_batch_id in filename:
            filename = filename.replace(current_batch_id, prior_batch_id, 1)
        return current_path.parent.parent / prior_batch_id / filename
    if current_batch_id in current_path.name:
        return current_path.with_name(current_path.name.replace(current_batch_id, prior_batch_id, 1))
    return None


def _load_previous_batch_chain(
    manifest: Any,
    previous_batch_manifest_path: Path | None,
) -> tuple[list[str], list[tuple[Path, dict[str, Any]]]]:
    """Load every explicit predecessor by a sequence-bound path derivation.

    Only the immediate predecessor path is supplied by the caller.  Older
    paths are derived exactly from that path's ``batch-NNN`` segment; no
    directory enumeration or filename discovery grants authority.
    """

    if not isinstance(manifest, dict):
        return ["BATCH_MANIFEST_NOT_OBJECT"], []
    failures: list[str] = []
    chain: list[tuple[Path, dict[str, Any]]] = []
    expected_sha = manifest.get("previous_batch_append_sha256")
    if previous_batch_manifest_path is None:
        if expected_sha:
            failures.append("BATCH_PREVIOUS_MANIFEST_REQUIRED")
        return failures, chain
    if not expected_sha:
        return ["BATCH_PREVIOUS_MANIFEST_UNEXPECTED_FOR_INITIAL_BATCH"], chain
    current_manifest = manifest
    current_path = previous_batch_manifest_path
    all_fingerprints = {
        str(value) for value in manifest.get("failure_fingerprints", [])
    }
    depth = 0
    while True:
        depth += 1
        if depth > AUTHORIZED_BASELINE_HISTORICAL_COUNT:
            failures.append("BATCH_PREVIOUS_MANIFEST_CHAIN_DEPTH_EXCEEDED")
            break
        try:
            previous_manifest = load_json_strict(current_path)
        except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
            failures.append("BATCH_PREVIOUS_MANIFEST_JSON_INVALID")
            break
        if not isinstance(previous_manifest, dict):
            failures.append("BATCH_PREVIOUS_MANIFEST_NOT_OBJECT")
            break
        for failure in validate_batch_manifest_document(previous_manifest):
            failures.append(f"BATCH_PREVIOUS_MANIFEST_INVALID:{failure}")
        if sha256_file(current_path) != expected_sha:
            failures.append("BATCH_PREVIOUS_MANIFEST_SHA256_MISMATCH")
        if current_manifest.get("record_chain_start_sha256") != previous_manifest.get("record_chain_terminal_sha256"):
            failures.append("BATCH_PREVIOUS_MANIFEST_CHAIN_TERMINAL_MISMATCH")
        current_match = re.fullmatch(r"batch-([0-9]{3})", str(current_manifest.get("batch_id", "")))
        previous_match = re.fullmatch(r"batch-([0-9]{3})", str(previous_manifest.get("batch_id", "")))
        if (
            current_match is None
            or previous_match is None
            or int(current_match.group(1)) != int(previous_match.group(1)) + 1
        ):
            failures.append("BATCH_PREVIOUS_MANIFEST_SEQUENCE_MISMATCH")
        if previous_manifest.get("terminal_remainder_batch") is True:
            failures.append("BATCH_PREVIOUS_MANIFEST_ALREADY_TERMINAL")
        previous_fingerprints = {
            str(value) for value in previous_manifest.get("failure_fingerprints", [])
        }
        overlap = all_fingerprints & previous_fingerprints
        for fingerprint in sorted(overlap):
            label = (
                "BATCH_PREVIOUS_MANIFEST_FINGERPRINT_REUSE"
                if depth == 1
                else "BATCH_PRIOR_MANIFEST_FINGERPRINT_REUSE"
            )
            failures.append(f"{label}:{fingerprint}")
        all_fingerprints.update(previous_fingerprints)
        chain.append((current_path, previous_manifest))
        prior_sha = previous_manifest.get("previous_batch_append_sha256")
        if not prior_sha:
            if previous_manifest.get("batch_id") != "batch-001":
                failures.append("BATCH_PREVIOUS_MANIFEST_CHAIN_DID_NOT_REACH_BATCH_001")
            if previous_manifest.get("record_chain_start_sha256") != LEGACY_RECORD_CHAIN_TERMINAL_SHA256:
                failures.append("BATCH_PREVIOUS_MANIFEST_LEGACY_CHAIN_ANCHOR_MISMATCH")
            break
        previous_id = str(previous_manifest.get("batch_id", ""))
        match = re.fullmatch(r"batch-([0-9]{3})", previous_id)
        if match is None or int(match.group(1)) <= 1:
            failures.append("BATCH_PREVIOUS_MANIFEST_SEQUENCE_MISMATCH")
            break
        prior_id = f"batch-{int(match.group(1)) - 1:03d}"
        prior_path = _derive_prior_manifest_path(current_path, previous_id, prior_id)
        if prior_path is None:
            failures.append("BATCH_PREVIOUS_MANIFEST_PATH_NOT_SEQUENCE_BOUND")
            break
        current_manifest = previous_manifest
        current_path = prior_path
        expected_sha = prior_sha
    return sorted(set(failures)), chain


def validate_previous_batch_link(
    manifest: Any,
    previous_batch_manifest_path: Path | None,
) -> list[str]:
    failures, _ = _load_previous_batch_chain(manifest, previous_batch_manifest_path)
    return failures


def _resolve_post_touch_batch_manifest_path(
    root: Path,
    sidecar_path: Path,
    explicit_batch_chain: list[tuple[Path, dict[str, Any]]],
    *,
    explicit_batch_chain_valid: bool = True,
) -> tuple[list[str], Path | None]:
    """Resolve a sidecar batch anchor only from the explicit current chain.

    A post-touch sidecar can legitimately revalidate a predecessor batch after
    a later batch has been appended.  The sidecar declaration is therefore the
    routing input, while ``explicit_batch_chain`` is the complete allowlist.
    No directory discovery, wildcard, future batch, or unrelated valid batch
    can acquire trust through this resolver.  The post-touch validator remains
    responsible for the declared SHA, committed bytes, Head ordering, exact
    fingerprint set, and live projection checks.
    """

    if not explicit_batch_chain_valid:
        return ["POST_TOUCH_EXPLICIT_BATCH_CHAIN_INVALID"], None
    try:
        sidecar = load_json_strict(sidecar_path)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        return ["POST_TOUCH_SIDECAR_MANIFEST_JSON_INVALID"], None
    if not isinstance(sidecar, dict):
        return ["POST_TOUCH_SIDECAR_MANIFEST_NOT_OBJECT"], None
    declared_value = sidecar.get("current_batch_manifest_path")
    if not isinstance(declared_value, str):
        return ["POST_TOUCH_CURRENT_BATCH_PATH_DECLARATION_INVALID"], None
    # This is a trust-routing boundary, so aliases are not equivalent.  The
    # sidecar must spell the canonical repository-relative POSIX path exactly;
    # ``res://``, backslashes, whitespace, repeated separators, dot segments,
    # selectors, and absolute paths must not be normalized into authority.
    if declared_value != normalize_path(declared_value):
        return ["POST_TOUCH_CURRENT_BATCH_PATH_DECLARATION_NOT_CANONICAL"], None
    declared = declared_value
    allowed: dict[str, Path] = {}
    root_resolved = root.resolve()
    failures: list[str] = []
    for path, _ in explicit_batch_chain:
        resolved = path.resolve()
        try:
            relative = resolved.relative_to(root_resolved).as_posix()
        except ValueError:
            failures.append("POST_TOUCH_EXPLICIT_BATCH_CHAIN_PATH_OUTSIDE_ROOT")
            continue
        allowed[relative] = resolved
    selected = allowed.get(declared)
    if selected is None:
        failures.append("POST_TOUCH_CURRENT_BATCH_MANIFEST_NOT_IN_EXPLICIT_CHAIN")
    return sorted(set(failures)), selected


def _resolve_subject_projection_batch_manifest_path(
    root: Path,
    sidecar_path: Path,
    explicit_batch_chain: list[tuple[Path, dict[str, Any]]],
    *,
    explicit_batch_chain_valid: bool = True,
) -> tuple[list[str], Path | None]:
    """Route the one-shot projection sidecar only through the explicit chain."""

    if not explicit_batch_chain_valid:
        return ["SUBJECT_PROJECTION_EXPLICIT_BATCH_CHAIN_INVALID"], None
    try:
        sidecar = load_json_strict(sidecar_path)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        return ["SUBJECT_PROJECTION_SIDECAR_MANIFEST_JSON_INVALID"], None
    if not isinstance(sidecar, dict):
        return ["SUBJECT_PROJECTION_SIDECAR_MANIFEST_NOT_OBJECT"], None
    declared_value = sidecar.get("current_batch_manifest_path")
    if not isinstance(declared_value, str):
        return ["SUBJECT_PROJECTION_CURRENT_BATCH_PATH_DECLARATION_INVALID"], None
    if declared_value != normalize_path(declared_value):
        return ["SUBJECT_PROJECTION_CURRENT_BATCH_PATH_DECLARATION_NOT_CANONICAL"], None
    allowed: dict[str, Path] = {}
    failures: list[str] = []
    root_resolved = root.resolve()
    for path, _ in explicit_batch_chain:
        resolved = path.resolve()
        try:
            relative = resolved.relative_to(root_resolved).as_posix()
        except ValueError:
            failures.append("SUBJECT_PROJECTION_EXPLICIT_BATCH_CHAIN_PATH_OUTSIDE_ROOT")
            continue
        allowed[relative] = resolved
    selected = allowed.get(declared_value)
    if selected is None:
        failures.append("SUBJECT_PROJECTION_CURRENT_BATCH_MANIFEST_NOT_IN_EXPLICIT_CHAIN")
    return sorted(set(failures)), selected


def _subject_projection_revalidation_composite(
    root: Path,
    sidecar_path: Path,
    explicit_batch_chain: list[tuple[Path, dict[str, Any]]],
    *,
    evaluated_head: str,
    explicit_batch_chain_valid: bool,
    historical_delta_metadata_ledger_status: str,
) -> dict[str, Any]:
    """Require primary PASS, independent GO, and byte-for-byte trust parity."""

    routing_failures, selected = _resolve_subject_projection_batch_manifest_path(
        root,
        sidecar_path,
        explicit_batch_chain,
        explicit_batch_chain_valid=explicit_batch_chain_valid,
    )
    explicit_paths = [path for path, _ in explicit_batch_chain]
    primary: Any
    independent: Any
    if routing_failures or selected is None:
        primary = {
            "status": "FAIL", "failures": [], "trusted_by_fingerprint": {},
            "trusted_fingerprint_count": 0, "record_count": 0,
            "fingerprints": [],
        }
        independent = {
            "status": "NO_GO", "findings": [], "trusted_by_fingerprint": {},
            "trusted_fingerprint_count": 0, "record_count": 0,
            "fingerprints": [],
        }
    else:
        try:
            primary = _subject_projection_revalidation.validate_manifest_and_records(
                root,
                sidecar_path,
                evaluated_head=evaluated_head,
                current_batch_manifest_path=selected,
                explicit_batch_manifest_paths=explicit_paths,
            )
        except Exception as error:  # fail closed at the trust boundary
            primary = {
                "status": "FAIL",
                "failures": [f"SUBJECT_PROJECTION_PRIMARY_EXCEPTION:{type(error).__name__}"],
                "trusted_by_fingerprint": {}, "trusted_fingerprint_count": 0,
                "record_count": 0, "fingerprints": [],
            }
        try:
            independent = _subject_projection_revalidation_independent.audit_manifest_and_records(
                root,
                sidecar_path,
                evaluated_head=evaluated_head,
                current_batch_manifest_path=selected,
                explicit_batch_manifest_paths=explicit_paths,
            )
        except Exception as error:  # fail closed at the trust boundary
            independent = {
                "status": "NO_GO",
                "findings": [f"SUBJECT_PROJECTION_INDEPENDENT_EXCEPTION:{type(error).__name__}"],
                "trusted_by_fingerprint": {}, "trusted_fingerprint_count": 0,
                "record_count": 0, "fingerprints": [],
            }
    failures = list(routing_failures)
    primary_shape_failures, primary_result, primary_trusted = (
        _subject_projection_revalidation_result_shape_failures(
            primary,
            label="PRIMARY",
            required_status="PASS",
            diagnostic_field="failures",
        )
    )
    independent_shape_failures, independent_result, independent_trusted = (
        _subject_projection_revalidation_result_shape_failures(
            independent,
            label="INDEPENDENT",
            required_status="GO",
            diagnostic_field="findings",
        )
    )
    failures.extend(primary_shape_failures)
    failures.extend(independent_shape_failures)
    trust_set_parity = primary_trusted == independent_trusted
    if not trust_set_parity:
        failures.append("SUBJECT_PROJECTION_TRUST_SET_PARITY_INVALID")
    if historical_delta_metadata_ledger_status != "PASS":
        failures.append("SUBJECT_PROJECTION_HDM_LEDGER_REQUIRED_PASS")
    failures = sorted(set(failures))
    trusted = primary_trusted if not failures else {}
    return {
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
        "path": str(sidecar_path),
        "record_count": primary_result.get("record_count", 0),
        "primary_status": primary_result.get("status", "FAIL"),
        "independent_status": independent_result.get("status", "NO_GO"),
        "primary_trusted_fingerprint_count": len(primary_trusted),
        "independent_trusted_fingerprint_count": len(independent_trusted),
        "trusted_fingerprint_count": len(trusted),
        "trust_set_parity": trust_set_parity,
        "trusted_by_fingerprint": trusted,
    }


_SUBJECT_PROJECTION_TRUST_ROW_FIELDS = frozenset({
    "allowed_invalidations",
    "prior_record_path",
    "record_path",
    "revalidation_binding_head_sha",
    "revalidation_id",
})


def _subject_projection_revalidation_result_shape_failures(
    result: Any,
    *,
    label: str,
    required_status: str,
    diagnostic_field: str,
) -> tuple[list[str], dict[str, Any], dict[str, dict[str, Any]]]:
    """Close every validator-result field before it can become trust."""

    prefix = f"SUBJECT_PROJECTION_{label}"
    failures: list[str] = []
    if type(result) is not dict:
        return [f"{prefix}_RESULT_NOT_OBJECT"], {}, {}

    status = result.get("status")
    if type(status) is not str:
        failures.append(f"{prefix}_STATUS_NOT_STRING")
    if status != required_status:
        failures.append(f"{prefix}_REQUIRED_{required_status}")

    diagnostics = result.get(diagnostic_field)
    if (
        type(diagnostics) is not list
        or any(type(value) is not str for value in diagnostics)
    ):
        failures.append(
            f"{prefix}_{diagnostic_field.upper()}_NOT_STRING_LIST"
        )
        diagnostics = []
    failures.extend(f"{prefix}:{value}" for value in diagnostics)

    trusted_value = result.get("trusted_by_fingerprint")
    trusted: dict[str, dict[str, Any]] = {}
    if type(trusted_value) is not dict:
        failures.append(f"{prefix}_TRUST_NOT_OBJECT")
    else:
        for fingerprint, row in trusted_value.items():
            if (
                type(fingerprint) is not str
                or re.fullmatch(r"V2F-[0-9a-f]{64}", fingerprint) is None
            ):
                failures.append(f"{prefix}_TRUST_FINGERPRINT_INVALID")
                continue
            if (
                type(row) is not dict
                or any(type(key) is not str for key in row)
                or set(row) != _SUBJECT_PROJECTION_TRUST_ROW_FIELDS
            ):
                failures.append(f"{prefix}_TRUST_ROW_SHAPE_INVALID:{fingerprint}")
                continue
            allowed_invalidations = row.get("allowed_invalidations")
            if (
                type(allowed_invalidations) is not list
                or len(allowed_invalidations) != 1
                or type(allowed_invalidations[0]) is not str
                or allowed_invalidations[0]
                != "SUBJECT_PROJECTION_CHANGED_INVALID"
            ):
                failures.append(f"{prefix}_TRUST_POLICY_INVALID:{fingerprint}")
            if (
                type(row.get("prior_record_path")) is not str
                or not _subject_projection_revalidation._exact_path(
                    row["prior_record_path"]
                )
                or not row["prior_record_path"].startswith(
                    _subject_projection_revalidation.FULL_RECORD_ROOT
                )
            ):
                failures.append(f"{prefix}_TRUST_PRIOR_PATH_INVALID:{fingerprint}")
            if (
                type(row.get("record_path")) is not str
                or not _subject_projection_revalidation._exact_path(
                    row["record_path"]
                )
                or not row["record_path"].startswith(
                    _subject_projection_revalidation.RECORD_ROOT
                )
            ):
                failures.append(f"{prefix}_TRUST_RECORD_PATH_INVALID:{fingerprint}")
            if (
                type(row.get("revalidation_id")) is not str
                or not row["revalidation_id"]
            ):
                failures.append(f"{prefix}_TRUST_ID_INVALID:{fingerprint}")
            if (
                type(row.get("revalidation_binding_head_sha")) is not str
                or re.fullmatch(
                    r"[0-9a-f]{40}", row["revalidation_binding_head_sha"]
                ) is None
            ):
                failures.append(f"{prefix}_TRUST_HEAD_INVALID:{fingerprint}")
            trusted[fingerprint] = row

    reported_count = result.get("trusted_fingerprint_count")
    record_count = result.get("record_count")
    if (
        type(reported_count) is not int
        or reported_count != 82
        or len(trusted) != 82
        or type(record_count) is not int
        or record_count != 82
    ):
        failures.append(f"{prefix}_COUNT_INVALID")

    fingerprints = result.get("fingerprints")
    if (
        type(fingerprints) is not list
        or any(type(value) is not str for value in fingerprints)
        or fingerprints != sorted(fingerprints)
        or len(fingerprints) != 82
        or len(set(fingerprints)) != 82
        or set(fingerprints) != set(trusted)
    ):
        failures.append(f"{prefix}_FINGERPRINT_SET_INVALID")

    return sorted(set(failures)), result, trusted


def _validate_manifest_binding_against_repo(
    root: Path,
    manifest: dict[str, Any],
    *,
    evaluated_head: str,
) -> list[str]:
    failures: list[str] = []
    binding_head = str(manifest.get("binding_head_sha", ""))
    if not _is_commit(binding_head):
        return ["BATCH_MANIFEST_BINDING_HEAD_INVALID"]
    if not _is_ancestor(root, AUTHORIZATION_BASE_HEAD_SHA, binding_head):
        failures.append("BATCH_MANIFEST_BINDING_HEAD_NOT_AUTHORIZED_DESCENDANT")
    if not _is_ancestor(root, binding_head, evaluated_head):
        failures.append("BATCH_MANIFEST_EVALUATED_HEAD_NOT_BINDING_DESCENDANT")
    try:
        tree = _git(root, "rev-parse", f"{binding_head}^{{tree}}")
    except ValueError:
        tree = ""
        failures.append("BATCH_MANIFEST_BINDING_HEAD_UNRESOLVED")
    if manifest.get("binding_tree_sha") != tree:
        failures.append("BATCH_MANIFEST_BINDING_TREE_MISMATCH")
    return sorted(set(failures))


def _validate_manifest_records_against_repo(
    root: Path,
    manifest: dict[str, Any],
    *,
    evaluated_head: str,
    authorized_fingerprints: dict[str, set[str]],
    authorized_identities: dict[str, dict[str, str]],
    legacy_fingerprints: set[str],
    post_touch_trusted: dict[str, dict[str, Any]] | None = None,
    subject_projection_revalidation_trusted: dict[str, dict[str, Any]] | None = None,
) -> tuple[list[str], set[str]]:
    failures: list[str] = []
    seen: set[str] = set()
    expected_previous = str(manifest.get("record_chain_start_sha256", ""))
    artifact_hash_fields = set(BATCH_ARTIFACT_SPECS) | {
        "descendant_history_supplement_sha256"
    }
    for index, binding in enumerate(manifest.get("record_bindings", [])):
        if not isinstance(binding, dict):
            failures.append(f"BATCH_RECORD_BINDING_NOT_OBJECT:{index}")
            continue
        relative = normalize_path(str(binding.get("path", "")))
        path = root / relative
        if not path.is_file():
            failures.append(f"BATCH_RECORD_MISSING:{index}")
            continue
        if sha256_file(path) != binding.get("record_sha256"):
            failures.append(f"BATCH_RECORD_BYTE_DRIFT:{index}")
            continue
        try:
            record = load_json_strict(path)
        except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
            failures.append(f"BATCH_RECORD_JSON_INVALID:{index}")
            continue
        if not isinstance(record, dict):
            failures.append(f"BATCH_RECORD_NOT_OBJECT:{index}")
            continue
        extension_failures = validate_extension_record_against_repo(
            root,
            record,
            evaluated_head=evaluated_head,
            authorized_identities=authorized_identities,
        )
        trusted = post_touch_trusted or {}
        subject_projection_trusted = subject_projection_revalidation_trusted or {}
        # Suppression is one-for-one: only the exact declared invalidation
        # code for the exact trusted fingerprint may be removed.  Every
        # contract, binding, projection-resolution, or unrelated failure
        # remains blocking.
        filtered: list[str] = []
        for failure in extension_failures:
            matched = re.fullmatch(
                r"(BLOB_CHANGED_CORRECTION_INVALID|TOUCHED_CORRECTION_INVALID|SUBJECT_PROJECTION_CHANGED_INVALID):(V2F-[0-9a-f]{64})",
                failure,
            )
            if matched:
                code, fingerprint = matched.groups()
                if (
                    code == "SUBJECT_PROJECTION_CHANGED_INVALID"
                    and _subject_projection_revalidation.allows_invalidation(
                        subject_projection_trusted,
                        fingerprint=fingerprint,
                        invalidation_code=code,
                        prior_record_path=relative,
                    )
                ):
                    continue
                if _post_touch.allows_invalidation(
                    trusted,
                    fingerprint=fingerprint,
                    invalidation_code=code,
                    prior_record_path=relative,
                ):
                    continue
            filtered.append(failure)
        failures.extend(filtered)
        if record.get("batch_id") != manifest.get("batch_id"):
            failures.append(f"BATCH_RECORD_BATCH_ID_MISMATCH:{index}")
        if record.get("binding_head_sha") != manifest.get("binding_head_sha"):
            failures.append(f"BATCH_RECORD_BINDING_HEAD_MISMATCH:{index}")
        if record.get("binding_tree_sha") != manifest.get("binding_tree_sha"):
            failures.append(f"BATCH_RECORD_BINDING_TREE_MISMATCH:{index}")
        for field in artifact_hash_fields:
            if record.get(field) != manifest.get(field):
                failures.append(f"BATCH_RECORD_{field.upper()}_MISMATCH:{index}")
        if record.get("correction_id") != binding.get("correction_id"):
            failures.append(f"BATCH_RECORD_ID_MISMATCH:{index}")
        if record.get("record_payload_sha256") != binding.get("record_payload_sha256"):
            failures.append(f"BATCH_RECORD_PAYLOAD_MISMATCH:{index}")
        if binding.get("previous_correction_chain_sha256") != expected_previous:
            failures.append(f"BATCH_RECORD_BINDING_CHAIN_BREAK:{index}")
        if record.get("previous_correction_chain_sha256") != expected_previous:
            failures.append(f"BATCH_RECORD_ACTUAL_CHAIN_BREAK:{index}")
        binding_fingerprints = [str(value) for value in binding.get("failure_fingerprints", [])]
        record_fingerprints = [str(value) for value in record.get("failure_fingerprints", [])]
        if record_fingerprints != binding_fingerprints:
            failures.append(f"BATCH_RECORD_FINGERPRINT_BINDING_MISMATCH:{index}")
        expected_previous = str(record.get("record_payload_sha256", ""))
        for fingerprint in record_fingerprints:
            if fingerprint in seen:
                failures.append(f"BATCH_RECORD_FINGERPRINT_DUPLICATE:{fingerprint}")
            seen.add(fingerprint)
    if expected_previous != manifest.get("record_chain_terminal_sha256"):
        failures.append("BATCH_RECORD_ACTUAL_CHAIN_TERMINAL_MISMATCH")
    manifest_fingerprints = {
        str(value) for value in manifest.get("failure_fingerprints", [])
    }
    if seen != manifest_fingerprints:
        failures.append("BATCH_RECORD_ACTUAL_FINGERPRINT_COVERAGE_MISMATCH")
    for fingerprint in sorted(seen & legacy_fingerprints):
        failures.append(f"BATCH_RECORD_LEGACY_FINGERPRINT_REUSE:{fingerprint}")
    for fingerprint in sorted(seen):
        if fingerprint in authorized_fingerprints["current"]:
            failures.append(f"BATCH_RECORD_CURRENT_FAILURE_CORRECTION_FALSE_ACCEPT:{fingerprint}")
        elif fingerprint not in authorized_fingerprints["historical"]:
            failures.append(f"BATCH_RECORD_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL:{fingerprint}")
    return sorted(set(failures)), seen


def _empty_historical_delta_metadata_ledger_authority(
    *,
    status: str,
    failures: Iterable[str] = (),
    primary_status: str = "NOT_PROVIDED",
    independent_status: str = "NOT_PROVIDED",
    primary_projection_digest_match: bool = False,
    primary_authority_projection_digest: str = "",
    independent_authority_projection_digest: str = "",
) -> dict[str, Any]:
    """Return a closed, non-authoritative ledger projection."""

    return {
        "status": status,
        "failures": sorted(set(str(value) for value in failures)),
        "primary_status": primary_status,
        "independent_status": independent_status,
        "primary_projection_digest_match": primary_projection_digest_match,
        "primary_authority_projection_digest": primary_authority_projection_digest,
        "independent_authority_projection_digest": (
            independent_authority_projection_digest
        ),
        "ledger_path": "",
        "ledger_sha256": "",
        "raw_report_sha256": "",
        "raw_report_head_sha": "",
        "scanner_sha256": "",
        "raw_failure_count": 0,
        "semantic_historical_failure_count": 0,
        "true_current_failure_count": 0,
        "metadata_record_count": 0,
        "correction_record_count": 0,
        "component_count": 0,
        "authorized_failure_count": 0,
        "verified_failure_count": 0,
        "authorized_historical_fingerprints": [],
        "authorized_identity_by_fingerprint": {},
        "verified_historical_fingerprints": [],
        "record_summaries": [],
    }


def _historical_delta_metadata_authority_projection(
    *,
    evaluated_head_sha: str,
    evaluated_tree_sha: str,
    ledger_path: str,
    ledger_sha256: str,
    raw_report_sha256: str,
    raw_report_head_sha: str,
    scanner_sha256: str,
    counts: dict[str, int],
    authorized_identity_by_fingerprint: dict[str, dict[str, Any]],
    verified_historical_fingerprints: Iterable[str],
    record_summaries: Iterable[dict[str, Any]],
) -> dict[str, Any]:
    identities = {
        str(fingerprint): dict(identity)
        for fingerprint, identity in authorized_identity_by_fingerprint.items()
    }
    summaries = [
        {
            "correction_id": str(summary.get("correction_id", "")),
            "path": normalize_path(str(summary.get("path", ""))),
            "record_sha256": str(summary.get("record_sha256", "")),
            "record_payload_sha256": str(
                summary.get("record_payload_sha256", "")
            ),
            "failure_fingerprints": sorted(
                str(value)
                for value in summary.get("failure_fingerprints", [])
            ),
        }
        for summary in record_summaries
        if isinstance(summary, dict)
    ]
    summaries.sort(key=lambda row: (row["path"], row["correction_id"]))
    return {
        "schema_version": (
            "space_syndicate.v076.historical_delta_metadata."
            "authority_projection.v1"
        ),
        "evaluated_head_sha": evaluated_head_sha,
        "evaluated_tree_sha": evaluated_tree_sha,
        "ledger_path": ledger_path,
        "ledger_sha256": ledger_sha256,
        "raw_report_sha256": raw_report_sha256,
        "raw_report_head_sha": raw_report_head_sha,
        "scanner_sha256": scanner_sha256,
        **{
            field: counts[field]
            for field in sorted(counts)
        },
        "authorized_identity_by_fingerprint": {
            fingerprint: identities[fingerprint]
            for fingerprint in sorted(identities)
        },
        "verified_historical_fingerprints": sorted(
            str(value) for value in verified_historical_fingerprints
        ),
        "record_summaries": summaries,
    }


def _primary_historical_delta_metadata_authority_projection(
    root: Path,
    primary: dict[str, Any],
    *,
    evaluated_head: str,
) -> dict[str, Any]:
    head = _git(root, "rev-parse", f"{evaluated_head}^{{commit}}")
    tree = _git(root, "rev-parse", f"{head}^{{tree}}")
    identities = {
        str(fingerprint): dict(identity)
        for fingerprint, identity in primary.get(
            "authorized_identity_by_fingerprint", {}
        ).items()
        if isinstance(identity, dict)
    }
    verified = [
        str(value)
        for value in primary.get("verified_historical_fingerprints", [])
    ]
    component_ids = {
        str(identity.get("component_id", "")) for identity in identities.values()
    }
    component_ids.discard("")
    source_transitions = {
        str(identity.get("source_commit", "")) for identity in identities.values()
    }
    source_transitions.discard("")
    raw_head = str(primary.get("raw_report_head_sha", ""))
    scanner_bytes = _git_bytes(
        root,
        raw_head,
        "tools/v076/v076_reuse_point_inertia_gate.py",
    )
    if scanner_bytes is None:
        raise ValueError("PRIMARY_PROJECTION_SCANNER_BLOB_MISSING")
    counts = {
        "raw_failure_count": int(primary.get("raw_failure_count", -1)),
        "preledger_native_historical_bucket_count": int(
            primary.get("preledger_native_historical_bucket_count", -1)
        ),
        "ledger_exact_promoted_count": int(
            primary.get("ledger_exact_promoted_count", -1)
        ),
        "semantic_historical_failure_count": int(
            primary.get("semantic_historical_failure_count", -1)
        ),
        "true_current_failure_count": int(
            primary.get("true_current_failure_count", -1)
        ),
        "metadata_record_count": int(primary.get("metadata_record_count", -1)),
        "source_transition_count": len(source_transitions),
        "correction_record_count": int(
            primary.get("correction_record_count", -1)
        ),
        "component_count": len(component_ids),
        "authorized_failure_count": len(identities),
        "verified_failure_count": len(verified),
    }
    return _historical_delta_metadata_authority_projection(
        evaluated_head_sha=head,
        evaluated_tree_sha=tree,
        ledger_path=str(primary.get("ledger_path", "")),
        ledger_sha256=str(primary.get("ledger_sha256", "")),
        raw_report_sha256=str(primary.get("raw_report_sha256", "")),
        raw_report_head_sha=raw_head,
        scanner_sha256=sha256_bytes(scanner_bytes),
        counts=counts,
        authorized_identity_by_fingerprint=identities,
        verified_historical_fingerprints=verified,
        record_summaries=primary.get("record_summaries", []),
    )


def _independent_historical_delta_metadata_authority_projection(
    root: Path,
    ledger_path: Path,
    *,
    evaluated_head: str,
    independent_receipt: dict[str, Any],
) -> dict[str, Any]:
    try:
        from . import (
            v076_historical_delta_metadata_independent_audit
            as independent_validator,
        )
    except ImportError:  # direct script execution
        import v076_historical_delta_metadata_independent_audit as independent_validator

    root = root.resolve()
    head = independent_validator._exact_commit(root, evaluated_head)
    ledger, ledger_bytes = independent_validator._committed_document(
        root,
        head,
        independent_validator.LEDGER_PATH,
    )
    records = ledger.get("records") if isinstance(ledger, dict) else []
    if not isinstance(records, list):
        raise ValueError("INDEPENDENT_PROJECTION_METADATA_RECORD_LIST_INVALID")
    source_commit_by_fingerprint: dict[str, str] = {}
    identities: dict[str, dict[str, Any]] = {}
    for record in records:
        if not isinstance(record, dict):
            raise ValueError("INDEPENDENT_PROJECTION_METADATA_RECORD_INVALID")
        source_commit = str(record.get("source_commit", ""))
        bindings = record.get("failure_bindings")
        if not isinstance(bindings, list):
            raise ValueError("INDEPENDENT_PROJECTION_FAILURE_BINDING_LIST_INVALID")
        for binding in bindings:
            if not isinstance(binding, dict):
                raise ValueError("INDEPENDENT_PROJECTION_FAILURE_BINDING_INVALID")
            fingerprint = str(binding.get("failure_fingerprint", ""))
            if not fingerprint or fingerprint in identities:
                raise ValueError(
                    "INDEPENDENT_PROJECTION_FAILURE_FINGERPRINT_INVALID"
                )
            source_commit_by_fingerprint[fingerprint] = source_commit
            identities[fingerprint] = {
                "failure_fingerprint": fingerprint,
                "raw_failure": str(binding.get("raw_failure", "")),
                "rule_id": str(binding.get("rule_id", "")),
                "source_commit": source_commit,
                "component_id": str(binding.get("component_id", "")),
                "path": str(binding.get("source_component_path", "")),
                "target": "historical",
                "authority_origin": "HISTORICAL_DELTA_METADATA_LEDGER",
            }
    summaries: list[dict[str, Any]] = []
    verified: set[str] = set()
    correction_bindings = ledger.get("correction_record_bindings", [])
    if not isinstance(correction_bindings, list):
        raise ValueError("INDEPENDENT_PROJECTION_CORRECTION_BINDING_LIST_INVALID")
    for binding in correction_bindings:
        if not isinstance(binding, dict):
            raise ValueError("INDEPENDENT_PROJECTION_CORRECTION_BINDING_INVALID")
        relative = str(binding.get("path", ""))
        correction, correction_bytes = independent_validator._committed_document(
            root,
            head,
            relative,
        )
        fingerprints = [
            str(value) for value in correction.get("failure_fingerprints", [])
        ]
        verified.update(fingerprints)
        summaries.append({
            "correction_id": str(correction.get("correction_id", "")),
            "path": relative,
            "record_sha256": independent_validator._sha(correction_bytes),
            "record_payload_sha256": str(
                correction.get("record_payload_sha256", "")
            ),
            "failure_fingerprints": fingerprints,
        })
    counts = {
        field: int(independent_receipt.get(field, -1))
        for field in (
            "raw_failure_count",
            "preledger_native_historical_bucket_count",
            "ledger_exact_promoted_count",
            "semantic_historical_failure_count",
            "true_current_failure_count",
            "metadata_record_count",
            "source_transition_count",
            "correction_record_count",
            "component_count",
            "authorized_failure_count",
            "verified_failure_count",
        )
    }
    return _historical_delta_metadata_authority_projection(
        evaluated_head_sha=str(independent_receipt.get("evaluated_head_sha", "")),
        evaluated_tree_sha=str(independent_receipt.get("evaluated_tree_sha", "")),
        ledger_path=independent_validator.LEDGER_PATH,
        ledger_sha256=independent_validator._sha(ledger_bytes),
        raw_report_sha256=str(
            independent_receipt.get("raw_report_sha256", "")
        ),
        raw_report_head_sha=str(ledger.get("raw_report_head_sha", "")),
        scanner_sha256=str(independent_receipt.get("scanner_sha256", "")),
        counts=counts,
        authorized_identity_by_fingerprint=identities,
        verified_historical_fingerprints=verified,
        record_summaries=summaries,
    )


def validate_historical_delta_metadata_ledger_authority(
    root: Path,
    ledger_path: Path | None,
    *,
    evaluated_head: str,
) -> dict[str, Any]:
    """Run both explicit ledger gates and expose primary authority only on GO."""

    if ledger_path is None:
        return _empty_historical_delta_metadata_ledger_authority(
            status="NOT_PROVIDED"
        )
    try:
        try:
            from . import v076_historical_delta_metadata_ledger as primary_validator
            from . import (
                v076_historical_delta_metadata_independent_audit
                as independent_validator,
            )
        except ImportError:  # direct script execution
            import v076_historical_delta_metadata_ledger as primary_validator
            import v076_historical_delta_metadata_independent_audit as independent_validator
    except Exception as exc:  # pragma: no cover - exercised by deployment failures
        return _empty_historical_delta_metadata_ledger_authority(
            status="FAIL",
            failures=[
                "HISTORICAL_DELTA_METADATA_VALIDATOR_IMPORT_FAILED:"
                f"{type(exc).__name__}:{exc}"
            ],
            primary_status="FAIL",
            independent_status="NO_GO",
        )

    try:
        primary = primary_validator.validate_ledger(
            root,
            ledger_path,
            evaluated_head=evaluated_head,
        )
    except Exception as exc:  # fail closed at the authority boundary
        primary = {
            "status": "FAIL",
            "failures": [
                "HISTORICAL_DELTA_METADATA_PRIMARY_EXCEPTION:"
                f"{type(exc).__name__}:{exc}"
            ],
        }
    if not isinstance(primary, dict):
        primary = {
            "status": "FAIL",
            "failures": ["HISTORICAL_DELTA_METADATA_PRIMARY_RESULT_INVALID"],
        }
    try:
        independent = independent_validator.audit_ledger(
            root,
            ledger_path,
            evaluated_head=evaluated_head,
            primary_projection=primary,
        )
    except Exception as exc:  # fail closed at the independent boundary
        independent = {
            "status": "NO_GO",
            "failures": [
                "HISTORICAL_DELTA_METADATA_INDEPENDENT_EXCEPTION:"
                f"{type(exc).__name__}:{exc}"
            ],
            "primary_projection_digest_match": False,
        }
    if not isinstance(independent, dict):
        independent = {
            "status": "NO_GO",
            "failures": ["HISTORICAL_DELTA_METADATA_INDEPENDENT_RESULT_INVALID"],
            "primary_projection_digest_match": False,
        }

    failures = [
        f"HISTORICAL_DELTA_METADATA_PRIMARY:{value}"
        for value in primary.get("failures", [])
    ] + [
        f"HISTORICAL_DELTA_METADATA_INDEPENDENT:{value}"
        for value in independent.get("failures", [])
    ]
    primary_status = str(primary.get("status", "FAIL"))
    independent_status = str(independent.get("status", "NO_GO"))
    set_and_count_match = (
        independent.get("primary_projection_digest_match") is True
    )
    primary_authority_projection_digest = ""
    independent_authority_projection_digest = ""
    if primary_status == "PASS" and independent_status == "GO":
        try:
            primary_authority_projection = (
                _primary_historical_delta_metadata_authority_projection(
                    root,
                    primary,
                    evaluated_head=evaluated_head,
                )
            )
            independent_authority_projection = (
                _independent_historical_delta_metadata_authority_projection(
                    root,
                    ledger_path,
                    evaluated_head=evaluated_head,
                    independent_receipt=independent,
                )
            )
            primary_authority_projection_digest = sha256_bytes(
                canonical_bytes(primary_authority_projection)
            )
            independent_authority_projection_digest = sha256_bytes(
                canonical_bytes(independent_authority_projection)
            )
        except Exception as exc:
            failures.append(
                "HISTORICAL_DELTA_METADATA_AUTHORITY_PROJECTION_BUILD_FAILED:"
                f"{type(exc).__name__}:{exc}"
            )
    digest_match = bool(
        set_and_count_match
        and primary_authority_projection_digest
        and primary_authority_projection_digest
        == independent_authority_projection_digest
    )
    if primary_status != "PASS":
        failures.append("HISTORICAL_DELTA_METADATA_PRIMARY_GATE_NOT_PASS")
    if independent_status != "GO":
        failures.append("HISTORICAL_DELTA_METADATA_INDEPENDENT_GATE_NOT_GO")
    if not digest_match:
        failures.append("HISTORICAL_DELTA_METADATA_PRIMARY_PROJECTION_DIGEST_MISMATCH")
    if failures:
        return _empty_historical_delta_metadata_ledger_authority(
            status="FAIL",
            failures=failures,
            primary_status=primary_status,
            independent_status=independent_status,
            primary_projection_digest_match=digest_match,
            primary_authority_projection_digest=(
                primary_authority_projection_digest
            ),
            independent_authority_projection_digest=(
                independent_authority_projection_digest
            ),
        )

    authorized = {
        str(value)
        for value in primary.get("authorized_historical_fingerprints", [])
    }
    verified = {
        str(value)
        for value in primary.get("verified_historical_fingerprints", [])
    }
    identities = {
        str(fingerprint): dict(identity)
        for fingerprint, identity in primary.get(
            "authorized_identity_by_fingerprint", {}
        ).items()
        if isinstance(identity, dict)
    }
    record_summaries = [
        dict(value)
        for value in primary.get("record_summaries", [])
        if isinstance(value, dict)
    ]
    component_ids = {
        str(identity.get("component_id", "")) for identity in identities.values()
    }
    component_ids.discard("")
    projection_failures: list[str] = []
    if set(identities) != authorized:
        projection_failures.append(
            "HISTORICAL_DELTA_METADATA_PRIMARY_IDENTITY_SET_MISMATCH"
        )
    if verified != authorized:
        projection_failures.append(
            "HISTORICAL_DELTA_METADATA_PRIMARY_VERIFIED_SET_MISMATCH"
        )
    for field, expected in (
        ("authorized_failure_count", len(authorized)),
        ("verified_failure_count", len(verified)),
        ("component_count", len(component_ids)),
    ):
        if independent.get(field) != expected:
            projection_failures.append(
                "HISTORICAL_DELTA_METADATA_INDEPENDENT_"
                f"{field.upper()}_MISMATCH"
            )
    if projection_failures:
        return _empty_historical_delta_metadata_ledger_authority(
            status="FAIL",
            failures=projection_failures,
            primary_status=primary_status,
            independent_status=independent_status,
            primary_projection_digest_match=digest_match,
            primary_authority_projection_digest=(
                primary_authority_projection_digest
            ),
            independent_authority_projection_digest=(
                independent_authority_projection_digest
            ),
        )
    return {
        "status": "PASS",
        "failures": [],
        "primary_status": primary_status,
        "independent_status": independent_status,
        "primary_projection_digest_match": digest_match,
        "primary_authority_projection_digest": (
            primary_authority_projection_digest
        ),
        "independent_authority_projection_digest": (
            independent_authority_projection_digest
        ),
        "ledger_path": str(primary.get("ledger_path", "")),
        "ledger_sha256": str(primary.get("ledger_sha256", "")),
        "raw_report_sha256": str(primary.get("raw_report_sha256", "")),
        "raw_report_head_sha": str(primary.get("raw_report_head_sha", "")),
        "scanner_sha256": str(
            primary_authority_projection.get("scanner_sha256", "")
        ),
        "raw_failure_count": primary.get("raw_failure_count", 0),
        "semantic_historical_failure_count": primary.get(
            "semantic_historical_failure_count", 0
        ),
        "true_current_failure_count": primary.get("true_current_failure_count", 0),
        "metadata_record_count": primary.get("metadata_record_count", 0),
        "correction_record_count": primary.get("correction_record_count", 0),
        "component_count": len(component_ids),
        "authorized_failure_count": len(authorized),
        "verified_failure_count": len(verified),
        "authorized_historical_fingerprints": sorted(authorized),
        "authorized_identity_by_fingerprint": {
            fingerprint: identities[fingerprint]
            for fingerprint in sorted(identities)
        },
        "verified_historical_fingerprints": sorted(verified),
        "record_summaries": record_summaries,
    }


def _historical_delta_metadata_ledger_collision_failures(
    ledger_authority: dict[str, Any],
    *,
    legacy: dict[str, Any],
    batch_chain: Iterable[tuple[Path, dict[str, Any]]],
) -> list[str]:
    if ledger_authority.get("status") != "PASS":
        return []
    ledger_fingerprints = {
        str(value)
        for value in ledger_authority.get("authorized_historical_fingerprints", [])
    }
    ledger_summaries = [
        value
        for value in ledger_authority.get("record_summaries", [])
        if isinstance(value, dict)
    ]
    ledger_ids = {str(value.get("correction_id", "")) for value in ledger_summaries}
    ledger_paths = {
        normalize_path(str(value.get("path", ""))) for value in ledger_summaries
    }
    legacy_fingerprints = {
        str(value) for value in legacy.get("legacy_corrected_fingerprints", [])
    }
    legacy_ids = {str(value) for value in legacy.get("legacy_correction_ids", [])}
    legacy_paths = {
        normalize_path(str(value)) for value in legacy.get("legacy_record_paths", [])
    }
    batch_fingerprints: set[str] = set()
    batch_ids: set[str] = set()
    batch_paths: set[str] = set()
    for _, manifest in batch_chain:
        if not isinstance(manifest, dict):
            continue
        batch_fingerprints.update(
            str(value) for value in manifest.get("failure_fingerprints", [])
        )
        for binding in manifest.get("record_bindings", []):
            if not isinstance(binding, dict):
                continue
            batch_ids.add(str(binding.get("correction_id", "")))
            batch_paths.add(normalize_path(str(binding.get("path", ""))))

    failures: list[str] = []
    collision_sets = (
        (
            "HISTORICAL_DELTA_METADATA_LEDGER_LEGACY_FINGERPRINT_COLLISION",
            ledger_fingerprints & legacy_fingerprints,
        ),
        (
            "HISTORICAL_DELTA_METADATA_LEDGER_BATCH_FINGERPRINT_COLLISION",
            ledger_fingerprints & batch_fingerprints,
        ),
        (
            "HISTORICAL_DELTA_METADATA_LEDGER_LEGACY_CORRECTION_ID_COLLISION",
            ledger_ids & legacy_ids,
        ),
        (
            "HISTORICAL_DELTA_METADATA_LEDGER_BATCH_CORRECTION_ID_COLLISION",
            ledger_ids & batch_ids,
        ),
        (
            "HISTORICAL_DELTA_METADATA_LEDGER_LEGACY_RECORD_PATH_COLLISION",
            ledger_paths & legacy_paths,
        ),
        (
            "HISTORICAL_DELTA_METADATA_LEDGER_BATCH_RECORD_PATH_COLLISION",
            ledger_paths & batch_paths,
        ),
    )
    for code, values in collision_sets:
        failures.extend(f"{code}:{value}" for value in sorted(values) if value)
    return sorted(set(failures))


def validate_batch_manifest_against_repo(
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
    subject_projection_revalidation_path: Path | None = None,
    historical_delta_metadata_ledger_path: Path | None = None,
) -> dict[str, Any]:
    failures = validate_schema(root, evaluated_head=evaluated_head)
    legacy = verify_legacy_anchor(root)
    failures.extend(legacy["failures"])
    try:
        manifest = load_json_strict(manifest_path)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        manifest = {}
        failures.append("BATCH_MANIFEST_JSON_INVALID")
    manifest_document_failures = validate_batch_manifest_document(manifest)
    failures.extend(manifest_document_failures)
    if not isinstance(manifest, dict):
        manifest = {}
    chain_failures, previous_chain = _load_previous_batch_chain(
        manifest,
        previous_batch_manifest_path,
    )
    failures.extend(chain_failures)
    if baseline_report_path is None:
        authorized_fingerprints = {"historical": set(), "current": set()}
        authorized_identities: dict[str, dict[str, str]] = {}
        failures.append("BATCH_BASELINE_REPORT_REQUIRED")
    else:
        baseline = validate_authorized_baseline(baseline_report_path)
        failures.extend(
            f"BATCH_BASELINE_INVALID:{failure}" for failure in baseline.get("failures", [])
        )
        try:
            baseline_report = load_json_strict(baseline_report_path)
            authorized_fingerprints = authorized_failure_fingerprint_sets(baseline_report)
            authorized_identities = authorized_failure_identity_by_fingerprint(baseline_report)
        except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
            authorized_fingerprints = {"historical": set(), "current": set()}
            authorized_identities = {}
            failures.append("BATCH_BASELINE_FINGERPRINT_SET_UNRESOLVED")
    if baseline_report_path is None:
        supplement = {
            "status": "FAIL",
            "failures": ["DESCENDANT_HISTORY_BASELINE_REQUIRED"],
            "supplement_sha256": "",
            "authorized_historical_fingerprints": set(),
            "authorized_identity_by_fingerprint": {},
        }
    else:
        supplement = validate_descendant_history_supplement(
            root,
            descendant_history_supplement_path,
            descendant_history_raw_report_path,
            descendant_history_scanner_path,
            evaluated_head=evaluated_head,
            baseline_report_path=baseline_report_path,
        )
    failures.extend(
        f"BATCH_DESCENDANT_HISTORY_INVALID:{failure}"
        for failure in supplement.get("failures", [])
    )
    # Correction authority is the exact live historical Raw set.  Frozen
    # identities that were preserved by an exact non-live disposition remain
    # auditable registry identities, but must never be corrected as if live.
    authorized_fingerprints["historical"] = {
        str(value)
        for value in supplement.get("authorized_historical_fingerprints", set())
    }
    authorized_identities = {
        str(fingerprint): dict(identity)
        for fingerprint, identity in supplement.get(
            "authorized_identity_by_fingerprint", {}
        ).items()
        if isinstance(identity, dict)
    }
    expected_supplement_sha = supplement.get("supplement_sha256", "")
    post_touch_result: dict[str, Any] = {
        "status": "NOT_PROVIDED",
        "failures": [],
        "trusted_by_fingerprint": {},
        "record_count": 0,
        "fingerprints": [],
    }
    subject_projection_revalidation_result: dict[str, Any] = {
        "status": "NOT_PROVIDED",
        "failures": [],
        "path": "",
        "record_count": 0,
        "primary_status": "NOT_PROVIDED",
        "independent_status": "NOT_PROVIDED",
        "primary_trusted_fingerprint_count": 0,
        "independent_trusted_fingerprint_count": 0,
        "trusted_fingerprint_count": 0,
        "trust_set_parity": False,
        "trusted_by_fingerprint": {},
    }
    all_manifests = list(reversed(previous_chain)) + [(manifest_path, manifest)]
    historical_delta_metadata_ledger = (
        validate_historical_delta_metadata_ledger_authority(
            root,
            historical_delta_metadata_ledger_path,
            evaluated_head=evaluated_head,
        )
    )
    terminal_ledger_failures: list[str] = []
    if manifest.get("terminal_remainder_batch") is True:
        if historical_delta_metadata_ledger_path is None:
            terminal_ledger_failures.append(
                "BATCH_TERMINAL_HISTORICAL_DELTA_METADATA_LEDGER_REQUIRED"
            )
        elif historical_delta_metadata_ledger.get("status") != "PASS":
            terminal_ledger_failures.append(
                "BATCH_TERMINAL_HISTORICAL_DELTA_METADATA_LEDGER_NOT_PASS"
            )
    if terminal_ledger_failures:
        historical_delta_metadata_ledger = (
            _empty_historical_delta_metadata_ledger_authority(
                status="FAIL",
                failures=terminal_ledger_failures,
                primary_status=str(
                    historical_delta_metadata_ledger.get(
                        "primary_status", "NOT_PROVIDED"
                    )
                ),
                independent_status=str(
                    historical_delta_metadata_ledger.get(
                        "independent_status", "NOT_PROVIDED"
                    )
                ),
                primary_projection_digest_match=(
                    historical_delta_metadata_ledger.get(
                        "primary_projection_digest_match"
                    )
                    is True
                ),
            )
        )
        failures.extend(terminal_ledger_failures)
    if historical_delta_metadata_ledger.get("status") == "FAIL":
        failures.extend(
            f"BATCH_HISTORICAL_DELTA_METADATA_LEDGER_INVALID:{value}"
            for value in historical_delta_metadata_ledger.get("failures", [])
        )
    ledger_collision_failures = (
        _historical_delta_metadata_ledger_collision_failures(
            historical_delta_metadata_ledger,
            legacy=legacy,
            batch_chain=all_manifests,
        )
    )
    if ledger_collision_failures:
        historical_delta_metadata_ledger = (
            _empty_historical_delta_metadata_ledger_authority(
                status="FAIL",
                failures=ledger_collision_failures,
                primary_status=str(
                    historical_delta_metadata_ledger.get("primary_status", "FAIL")
                ),
                independent_status=str(
                    historical_delta_metadata_ledger.get(
                        "independent_status", "NO_GO"
                    )
                ),
                primary_projection_digest_match=(
                    historical_delta_metadata_ledger.get(
                        "primary_projection_digest_match"
                    )
                    is True
                ),
            )
        )
        failures.extend(ledger_collision_failures)
    # Sidecar trust may suppress exact prior-record invalidations, so expose it
    # only after the complete explicit batch chain has passed the same closed
    # manifest, repository-binding, evidence-artifact, disposition, baseline,
    # supplement, schema, and legacy preflight used by the final result.  A
    # syntactically valid chain with an unresolved/unauthorized binding Head is
    # not a valid trust chain.
    pre_sidecar_manifest_failures: list[str] = []
    for path, document in all_manifests:
        if document.get("descendant_history_supplement_sha256") != expected_supplement_sha:
            pre_sidecar_manifest_failures.append(
                f"BATCH_DESCENDANT_HISTORY_SUPPLEMENT_SHA256_MISMATCH:{document.get('batch_id', '')}"
            )
        pre_sidecar_manifest_failures.extend(
            _validate_manifest_binding_against_repo(
                root,
                document,
                evaluated_head=evaluated_head,
            )
        )
        pre_sidecar_manifest_failures.extend(
            validate_batch_artifacts(
                path,
                document,
                authorized_identities=authorized_identities,
            )
        )
        pre_sidecar_manifest_failures.extend(
            _classification_record_disposition_failures(root, path, document)
        )
    failures.extend(pre_sidecar_manifest_failures)
    explicit_batch_chain_valid = not failures
    if post_touch_revalidation_path is not None:
        routing_failures, sidecar_batch_manifest_path = (
            _resolve_post_touch_batch_manifest_path(
                root,
                post_touch_revalidation_path,
                all_manifests,
                explicit_batch_chain_valid=explicit_batch_chain_valid,
            )
        )
        if routing_failures:
            raw_post_touch_result = {
                "status": "FAIL",
                "failures": [],
                "trusted_by_fingerprint": {},
                "record_count": 0,
                "fingerprints": [],
            }
        else:
            raw_post_touch_result = _post_touch.validate_manifest_and_records(
                root,
                post_touch_revalidation_path,
                evaluated_head=evaluated_head,
                current_batch_manifest_path=sidecar_batch_manifest_path,
                projection_loader=subject_projection,
            )
        combined_post_touch_failures = sorted(set(
            routing_failures + list(raw_post_touch_result.get("failures", []))
        ))
        post_touch_result = dict(raw_post_touch_result)
        post_touch_result["failures"] = combined_post_touch_failures
        if combined_post_touch_failures or raw_post_touch_result.get("status") != "PASS":
            post_touch_result["status"] = "FAIL"
            post_touch_result["trusted_by_fingerprint"] = {}
        failures.extend(
            f"POST_TOUCH_REVALIDATION_INVALID:{failure}"
            for failure in post_touch_result.get("failures", [])
        )
        if post_touch_result.get("status") != "PASS":
            failures.append("POST_TOUCH_REVALIDATION_REQUIRED_VALID_SIDECAR")
    post_touch_trusted = post_touch_result.get("trusted_by_fingerprint", {})
    if subject_projection_revalidation_path is not None:
        subject_projection_revalidation_result = (
            _subject_projection_revalidation_composite(
                root,
                subject_projection_revalidation_path,
                all_manifests,
                evaluated_head=evaluated_head,
                explicit_batch_chain_valid=explicit_batch_chain_valid,
                historical_delta_metadata_ledger_status=str(
                    historical_delta_metadata_ledger.get("status", "FAIL")
                ),
            )
        )
        failures.extend(
            f"SUBJECT_PROJECTION_REVALIDATION_INVALID:{failure}"
            for failure in subject_projection_revalidation_result.get("failures", [])
        )
        if subject_projection_revalidation_result.get("status") != "PASS":
            failures.append(
                "SUBJECT_PROJECTION_REVALIDATION_REQUIRED_VALID_DUAL_AUDIT_SIDECAR"
            )
    subject_projection_revalidation_trusted = (
        subject_projection_revalidation_result.get("trusted_by_fingerprint", {})
    )
    legacy_fingerprints = set(legacy.get("legacy_corrected_fingerprints", []))
    global_fingerprints: set[str] = set()
    correction_ids: set[str] = set()
    current_seen: set[str] = set()
    for path, document in all_manifests:
        if document.get("descendant_history_supplement_sha256") != expected_supplement_sha:
            failures.append(
                f"BATCH_DESCENDANT_HISTORY_SUPPLEMENT_SHA256_MISMATCH:{document.get('batch_id', '')}"
            )
        failures.extend(_validate_manifest_binding_against_repo(root, document, evaluated_head=evaluated_head))
        failures.extend(
            validate_batch_artifacts(
                path,
                document,
                authorized_identities=authorized_identities,
            )
        )
        failures.extend(
            _classification_record_disposition_failures(root, path, document)
        )
        fingerprints = {
            str(value) for value in document.get("failure_fingerprints", [])
        }
        for fingerprint in sorted(global_fingerprints & fingerprints):
            failures.append(f"BATCH_GLOBAL_FINGERPRINT_REUSE:{fingerprint}")
        global_fingerprints.update(fingerprints)
        for fingerprint in sorted(fingerprints & legacy_fingerprints):
            failures.append(f"BATCH_LEGACY_FINGERPRINT_REUSE:{fingerprint}")
        for fingerprint in sorted(fingerprints):
            if fingerprint in authorized_fingerprints["current"]:
                failures.append(f"BATCH_CURRENT_FAILURE_CORRECTION_FALSE_ACCEPT:{fingerprint}")
            elif fingerprint not in authorized_fingerprints["historical"]:
                failures.append(f"BATCH_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL:{fingerprint}")
        for binding in document.get("record_bindings", []):
            if not isinstance(binding, dict):
                continue
            correction_id = str(binding.get("correction_id", ""))
            if correction_id in correction_ids:
                failures.append(f"BATCH_GLOBAL_CORRECTION_ID_REUSE:{correction_id}")
            correction_ids.add(correction_id)
        record_failures, seen = _validate_manifest_records_against_repo(
            root,
            document,
            evaluated_head=evaluated_head,
            authorized_fingerprints=authorized_fingerprints,
            authorized_identities=authorized_identities,
            legacy_fingerprints=legacy_fingerprints,
            post_touch_trusted=post_touch_trusted,
            subject_projection_revalidation_trusted=(
                subject_projection_revalidation_trusted
            ),
        )
        failures.extend(record_failures)
        if path == manifest_path:
            current_seen = seen
    failures = sorted(set(failures))
    return {
        "schema_version": f"{BATCH_MANIFEST_SCHEMA_VERSION}.verification",
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD_SHA,
        "evaluated_head_sha": evaluated_head,
        "batch_id": manifest.get("batch_id", ""),
        "failure_count": len(current_seen),
        "validated_batch_count": len(all_manifests),
        "validated_global_fingerprint_count": len(global_fingerprints),
        "descendant_history_supplement_sha256": expected_supplement_sha,
        "legacy_record_chain_terminal_sha256": LEGACY_RECORD_CHAIN_TERMINAL_SHA256,
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
        "post_touch_revalidation": {
            "status": post_touch_result.get("status", "NOT_PROVIDED"),
            "path": str(post_touch_revalidation_path) if post_touch_revalidation_path else "",
            "record_count": post_touch_result.get("record_count", 0),
            "trusted_fingerprint_count": len(post_touch_trusted or {}),
            "failures": post_touch_result.get("failures", []),
        },
        "subject_projection_revalidation": {
            key: value
            for key, value in subject_projection_revalidation_result.items()
            if key != "trusted_by_fingerprint"
        },
        "historical_delta_metadata_ledger": historical_delta_metadata_ledger,
    }
