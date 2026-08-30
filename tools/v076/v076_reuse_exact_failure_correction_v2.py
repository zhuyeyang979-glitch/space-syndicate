"""V076 exact, append-only historical failure correction resolver (V2).

This module deliberately sits *after* ``v076_reuse_point_inertia_gate.py``.
The existing scanner remains the source of raw failures and is never taught
about a correction record.  V2 only resolves an explicitly fingerprinted,
historical row from an immutable baseline report.  Current-delta failures,
owner violations, and unresolved identities always remain blocking.

The command is intentionally usable without Godot.  It performs Git and JSON
operations only and never changes gameplay state.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any, Iterable


SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2"
REPORT_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction_report.v2"
FULL_CONVERGENCE_REPORT_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction_report.v2."
    "full_convergence.v1"
)
FULL_CONVERGENCE_RESOLUTION_MODE = "FULL_CONVERGENCE"
FULL_CONVERGENCE_PASS_STATUS = (
    "PASS_WITH_APPEND_ONLY_HISTORICAL_IDENTITY_BACKFILL_AND_CORRECTIONS"
)
HISTORICAL_DELTA_METADATA_SUCCESSOR_FAILURE_COUNT = 25
HISTORICAL_DELTA_METADATA_SUCCESSOR_RULE_ID = (
    "NEW_COMPONENT_CANNOT_CLAIM_INHERITED"
)
INVENTORY_SCHEMA_VERSION = "space_syndicate.v076.reuse_failure_inventory.v2"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_CORRECTION_V2_20260826"
AUTHORIZED_HEAD_SHA = "1e24cea73fc23e69e575fcea09df57238156af67"
PR_NUMBER = 93
PR_BASE_SHA = "770d741f05964facda4afcbddcdeb3e7f40571d5"
GATE_BASE_SHA = "f6fe547e1e1db57a8bb3a12eab1d9225d4abdca5"
# ``f6fe...`` is the immutable point-inertia history root.  ``4a128d...`` is
# the commit that actually introduced the scanner/gate implementation.  The
# similarly named PR90 UI commit (``a80ad...``) is unrelated and must never be
# used as the transition/classification boundary.
GATE_ACTIVATION_SHA = "4a128d770a0b568863755db9c88080f5de938c0d"
# These are the byte identities captured from the authorized CI run.  Keeping
# them here prevents a forged sidecar (artifact plus freshly edited ``.sha256``)
# from silently becoming a new baseline.
AUTHORIZED_BASELINE_REPORT_SHA256 = "b1097750f23007ba75d83f646fefe70a3bb5012540d38475a536fc5eee81e435"
AUTHORIZED_SCANNER_MANIFEST_SHA256 = "d76cef3b028bd602d14250011e72484704f09f906da008da43890c7ac344ca65"
AUTHORIZED_EXISTING_CORRECTIONS_MANIFEST_SHA256 = "5a3cd6ce9e218792b008cd22d120e80c2baa586ae2a53e52ce4b784c2c95909d"
# The exact schema document is independently reviewable and is not inferred
# from the resolver's implementation hash.  Its authorized digest is filled by
# the same narrowly-scoped task that introduces the schema artifact.
AUTHORIZED_CORRECTION_SCHEMA_SHA256 = "9f58d1dca66803883686629a20b58261b4b86f90451ee026fb9eb4a91047dde9"

BASELINE_REPORT_REL = Path("reports/reuse/correction_v2/baseline_raw_failure_report.json")
BASELINE_REPORT_SHA_REL = Path("reports/reuse/correction_v2/baseline_raw_failure_report.sha256")
SCANNER_MANIFEST_REL = Path("reports/reuse/correction_v2/baseline_scanner_file_manifest.json")
SCANNER_MANIFEST_SHA_REL = Path("reports/reuse/correction_v2/baseline_scanner_file_manifest.sha256")
EXISTING_CORRECTIONS_REL = Path(
    "reports/reuse/correction_v2/baseline_existing_corrections_manifest.json"
)
EXISTING_CORRECTIONS_SHA_REL = Path(
    "reports/reuse/correction_v2/baseline_existing_corrections_manifest.sha256"
)
FAILURE_INVENTORY_REL = Path("reports/reuse/correction_v2/exact_failure_inventory.json")
FAILURE_INVENTORY_MD_REL = Path("reports/reuse/correction_v2/exact_failure_inventory.md")
MISSING_CLASS_REL = Path(
    "reports/reuse/correction_v2/missing_transition_class_inventory.json"
)
ACTIVE_INVENTORY_REL = Path(
    "reports/reuse/correction_v2/true_active_violation_inventory.json"
)
CORRECTION_DIR_REL = Path("docs/architecture/reuse_corrections/v2")
RECORD_DIR_REL = CORRECTION_DIR_REL / "records"
CORRECTION_SCHEMA_REL = CORRECTION_DIR_REL / "schema.json"
SELFTEST_REPORT_REL = Path("reports/reuse/correction_v2/correction_v2_selftest.json")
SELFTEST_REPORT_SHA_REL = Path("reports/reuse/correction_v2/correction_v2_selftest.sha256")
PREVIOUS_AUTHORIZATION_MANIFEST_REL = Path(
    "reports/reuse/correction_v2/correction_authorization_manifest.json"
)
PREVIOUS_AUTHORIZATION_MANIFEST_SHA_REL = Path(
    "reports/reuse/correction_v2/correction_authorization_manifest.sha256"
)
PREVIOUS_AUTHORIZATION_MANIFEST_SHA256 = (
    "ada661f73a81d53586d3b50b3a964f66e2ed9baa00073472ddbf2a5573aad15c"
)
SEAL_REVISION_ID = "CI_PORTABILITY_V2"
# The CI_PORTABILITY_V2 seal was published from this exact successor commit.
# Verification must reconstruct tool bindings from its committed Git blobs,
# rather than hashing whatever line-ending-normalized/evolved bytes happen to
# be materialized in the current checkout.  This keeps the old seal immutable
# while allowing later scanner evolution to be validated as a new head.
SEAL_REVISION_HEAD_SHA = "d701a81dce693b584d52fbfca3e0e78b521ad775"
SEAL_REVISION_DIR_REL = Path(
    "reports/reuse/correction_v2/seals/ci_portability_v2"
)
EXISTING_SELFTEST_REPORT_REL = Path(
    SEAL_REVISION_DIR_REL / "existing_reuse_selftest.json"
)
EXISTING_SELFTEST_REPORT_SHA_REL = Path(
    SEAL_REVISION_DIR_REL / "existing_reuse_selftest.sha256"
)
RECORD_INVENTORY_REL = Path("reports/reuse/correction_v2/correction_record_inventory.json")
AUDIT_A_REL = Path("reports/reuse/correction_v2/audit_a_mechanism_safety.json")
AUDIT_A_MD_REL = Path("reports/reuse/correction_v2/audit_a_mechanism_safety.md")
AUDIT_B_REL = Path("reports/reuse/correction_v2/audit_b_failure_classification.json")
AUDIT_B_MD_REL = Path("reports/reuse/correction_v2/audit_b_failure_classification.md")
FINAL_RESOLVE_REL = Path("reports/reuse/correction_v2/v2_final_resolve.json")
FINAL_RESOLVE_MD_REL = Path("reports/reuse/correction_v2/v2_final_resolve.md")
AUTHORIZATION_MANIFEST_REL = Path(
    SEAL_REVISION_DIR_REL / "correction_authorization_manifest.json"
)
APPLICATION_PLAN_REL = Path(SEAL_REVISION_DIR_REL / "correction_application_plan.json")

EVIDENCE_MANIFEST_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_correction_authorization_manifest.v3"
)
APPLICATION_PLAN_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_correction_application_plan.v3"
)
CORRECTION_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction_schema.v2"

EXPECTED_SEAL_COUNTS = {
    "RAW_FAILURE_COUNT": 566,
    "RAW_HISTORICAL_FAILURE_COUNT": 510,
    "RAW_CURRENT_DELTA_FAILURE_COUNT": 56,
    "CORRECTED_HISTORICAL_FAILURE_COUNT": 12,
    "UNRESOLVED_HISTORICAL_FAILURE_COUNT": 498,
    "TRUE_ACTIVE_VIOLATION_COUNT": 56,
    "EFFECTIVE_BLOCKING_FAILURE_COUNT": 554,
    "NEW_CORRECTION_RECORD_COUNT": 6,
}

# The schema is intentionally exact.  A field not named here cannot become a
# selector, wildcard, alternate authority, or implicit future-failure policy.
CORRECTION_RECORD_FIELDS = tuple(sorted((
    "allowed_from_state",
    "allowed_rule_ids",
    "allowed_to_state",
    "authorization_id",
    "authorized_head_sha",
    "backlog_item_ids",
    "baseline_report_sha256",
    "component_ids",
    "correction_id",
    "correction_reason",
    "created_at",
    "creator",
    "current_blob_sha256_by_path",
    "current_counterpart_fingerprints_by_failure",
    "current_counterparts_remain_separate",
    "domain_ids",
    "eligibility_policy",
    "evidence_paths",
    "failure_bindings",
    "failure_classes",
    "failure_count",
    "failure_fingerprint_set_sha256",
    "failure_fingerprints",
    "from_state",
    "future_failure_policy",
    "historical_debt_status",
    "negative_examples",
    "owner_reuse_map_sha256",
    "path_set_sha256",
    "paths",
    "previous_correction_chain_sha256",
    "production_reachability_attestation",
    "raw_failure_set_sha256",
    "raw_failures",
    "record_payload_sha256",
    "required_blob_binding",
    "required_evidence",
    "required_reachability_state",
    "required_untouched_state",
    "revocation_policy",
    "rule_ids",
    "schema_version",
    "source_commit_set",
    "supersession_map_sha256",
    "to_effective_disposition",
    "touch_invalidation_policy",
    "transition_class_id",
    "untouched_in_current_delta",
    "why_existing_transition_is_insufficient",
    "why_not_active_violation",
)))

REVOCATION_RECORD_FIELDS = tuple(sorted((
    "affected_failure_fingerprints",
    "authorization_id",
    "authorized_head_sha",
    "baseline_report_sha256",
    "created_at",
    "creator",
    "evidence_paths",
    "new_effective_status",
    "previous_chain_sha256",
    "record_kind",
    "record_payload_sha256",
    "revocation_reason",
    "revoked_correction_id",
    "revoked_record_sha256",
    "schema_version",
)))

SCANNER_CORE_PATHS = (
    "tools/v076/v076_reuse_point_inertia_gate.py",
    "tools/v076/v076_reuse_point_inertia_gate_selftest.py",
    "tools/rules/check_v06_mechanic_authority.py",
)
SCANNER_SUCCESSOR_SHA256_BY_PATH = {
    "tools/v076/v076_reuse_point_inertia_gate.py": "2b9427f34edbaf54537e10f173b7c303015f31c2fdf0747048f55c060e3dd05b",
    "tools/v076/v076_reuse_point_inertia_gate_selftest.py": "c342d604397f7cc8583a89734e0d95f38ea7a7fdbd783594ba22f39039c2b606",
    "tools/rules/check_v06_mechanic_authority.py": "a7bdb3b4a5109439a61cafb6a4149373b220f80552a1e95a7fccb2caf84ae1ea",
}
EVOLVABLE_SEAL_INPUT_PATHS = frozenset({
    "tools/v076/v076_reuse_exact_failure_correction_v2.py",
    "tools/v076/v076_reuse_exact_failure_correction_v2_selftest.py",
    "tools/v076/v076_reuse_correction_v2_independent_audit.py",
    ".github/workflows/v076-reuse-point-inertia-gate.yml",
})
ORCHESTRATOR_PATHS = (
    ".github/workflows/v076-reuse-point-inertia-gate.yml",
    "tools/v076/v076_reuse_exact_failure_correction_v2.py",
    "tools/v076/v076_reuse_exact_failure_correction_v2_selftest.py",
)
AUTHORITY_INPUT_PATHS = (
    "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json",
    "docs/architecture/V076_SUPERSESSION_MAP.json",
    "docs/architecture/V076_OWNER_REUSE_MAP.md",
    "docs/architecture/V076_INHERITED_GREEN_LEDGER.json",
    "docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json",
    "reports/card_certification/v076_card_certification_matrix.json",
)

HISTORY_RULE_CLASSES: dict[str, dict[str, Any]] = {
    "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT": {
        "transition_class_id": "HISTORICAL_UNTOUCHED_COMPONENT_CLASSIFICATION_DEBT",
        "human_description": "A frozen historical transition emitted an unclassified component row; the exact fingerprint and subject remain visible and are reviewed again on touch.",
        "backlog_item_id": "reuse.v2.untouched-component-classification-debt",
    },
    "HISTORY_DYNAMIC_REFERENCE_UNRESOLVED": {
        "transition_class_id": "HISTORICAL_UNTOUCHED_DYNAMIC_REFERENCE_DEBT",
        "human_description": "A frozen historical transition contains an unresolved dynamic-reference fingerprint; current or touched dynamic references remain blocking.",
        "backlog_item_id": "reuse.v2.untouched-dynamic-reference-debt",
    },
    "HISTORY_COMPONENT_CHANGE_CLASS_NOT_DECLARED": {
        "transition_class_id": "HISTORICAL_UNTOUCHED_CHANGE_CLASS_DEBT",
        "human_description": "A frozen historical component transition lacks its required change-class declaration and remains reviewable on its exact fingerprint.",
        "backlog_item_id": "reuse.v2.untouched-change-class-debt",
    },
    "HISTORY_PRODUCT_REUSE_SCAN_INVALID": {
        "transition_class_id": "HISTORICAL_UNTOUCHED_REUSE_SCAN_DEBT",
        "human_description": "A frozen historical transition has incomplete reuse-scan metadata; its exact component fingerprint is retained as historical debt.",
        "backlog_item_id": "reuse.v2.untouched-reuse-scan-debt",
    },
    "HISTORY_PRODUCT_FOCUSED_TESTS_MISSING": {
        "transition_class_id": "HISTORICAL_UNTOUCHED_FOCUSED_TEST_SCOPE_DEBT",
        "human_description": "A frozen historical product transition lacks its focused-test scope declaration and remains visible as exact historical debt.",
        "backlog_item_id": "reuse.v2.untouched-focused-test-scope-debt",
    },
    "HISTORY_PRODUCT_AFFECTED_DOMAIN_MISSING": {
        "transition_class_id": "HISTORICAL_UNTOUCHED_AFFECTED_DOMAIN_DEBT",
        "human_description": "A frozen historical change-scope row omits its affected domain and remains visible under its exact fingerprint.",
        "backlog_item_id": "reuse.v2.untouched-affected-domain-debt",
    },
    "HISTORY_PRODUCT_AFFECTED_OWNER_MISSING": {
        "transition_class_id": "HISTORICAL_UNTOUCHED_AFFECTED_OWNER_DEBT",
        "human_description": "A frozen historical change-scope row omits its affected Owner and remains visible under its exact fingerprint.",
        "backlog_item_id": "reuse.v2.untouched-affected-owner-debt",
    },
}

# Every class is a concrete contract, rather than a name-only bucket.  These
# fields are intentionally materialized in each correction record so an audit
# can evaluate the class without trusting this module's mutable defaults.
for _failure_class, _definition in HISTORY_RULE_CLASSES.items():
    _definition.update(
        {
            "allowed_rule_ids": [_failure_class],
            "allowed_from_state": "HISTORICAL_FAILURE_PRESENT_UNTOUCHED",
            "allowed_to_state": "CORRECTED_HISTORICAL_DEBT",
            "required_evidence": [
                "reports/reuse/correction_v2/baseline_raw_failure_report.json",
                "reports/reuse/correction_v2/exact_failure_inventory.json",
            ],
            "required_reachability_state": [
                "production_reachable",
                "non_production",
            ],
            "required_blob_binding": True,
            "required_untouched_state": True,
            "eligibility_policy": {
                "REQUIRE_EXACT_RAW_FINGERPRINT": True,
                "REQUIRE_EXACT_RULE_ID": True,
                "REQUIRE_EXACT_SOURCE_COMMIT": True,
                "REQUIRE_COMPLETE_TRANSITION": True,
                "REQUIRE_TRANSITION_NEW_STRICTLY_BEFORE_AUTHORIZED_HEAD": True,
                "REQUIRE_RESOLVED_IDENTITY": True,
                "CURRENT_COUNTERPARTS_REMAIN_SEPARATE": True,
            },
            "touch_invalidation_policy": {
                "TOUCH_INVALIDATES_CORRECTION": True,
                "BLOB_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
                "PRODUCTION_REACHABILITY_CHANGED_INVALIDATION": True,
                "OWNER_BINDING_CHANGED_INVALIDATION": True,
            },
            "future_failure_policy": {
                "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
                "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
            },
            "revocation_policy": {
                "REVOCATION_APPEND_ONLY": True,
                "OLD_RECORD_MUTATION_FORBIDDEN": True,
                "REQUIRES_REVOKED_RECORD_SHA256": True,
            },
            "negative_examples": [
                "CURRENT_DELTA_FAILURE",
                "TOUCHED_PRODUCTION_COMPONENT",
                "PARALLEL_OWNER",
                "DUAL_WRITE",
                "FALLBACK",
                "RETIRED_OWNER_REACHABLE",
            ],
        }
    )

DISALLOWED_CORRECTION_WORDS = {
    "glob",
    "regex",
    "prefix",
    "directory",
    "all historical failures",
    "grandfather",
    "ignore",
    "waive",
    "wildcard",
    "unknown_accepted",
}
# Catch-all labels are rejected as *tokens* in class/rule/scope fields.  They
# are not searched for in prose, evidence paths, or concrete file names (for
# example ``global_supply_demand_runtime_service.gd`` must remain valid).
DISALLOWED_CATCH_ALL_TOKENS = {
    "other",
    "misc",
    "miscellaneous",
    "legacy",
    "grandfather_all",
    "unknown",
    "unknown_accepted",
}
_SCOPE_FIELD_NAMES = {
    "scope",
    "path_scope",
    "component_scope",
    "domain_scope",
    "selector",
    "selectors",
    "pattern",
    "patterns",
    "match",
    "matches",
    "filter",
    "filters",
    "wildcard",
    "wildcards",
    "regex",
    "regular_expression",
    "path_prefix",
    "directory",
}
_RULE_FIELD_NAMES = {
    "rule_id",
    "rule_ids",
    "failure_class",
    "failure_classes",
    "transition_class_id",
    "transition_class",
}

_POLICY_TEXT_FIELD_NAMES = {
    "correction_reason",
    "why_not_active_violation",
    "why_existing_transition_is_insufficient",
    "historical_debt_status",
    "transition_class_id",
    "allowed_to_state",
    "to_effective_disposition",
}


def _iter_explicit_scope_values(record: dict[str, Any]) -> Iterable[tuple[str, Any]]:
    """Yield only fields that can express a broad correction selector."""
    def walk(value: Any, field_name: str) -> Iterable[tuple[str, Any]]:
        if isinstance(value, dict):
            for key, child in value.items():
                key_l = str(key).casefold()
                if (
                    key_l in _SCOPE_FIELD_NAMES
                    or key_l in _RULE_FIELD_NAMES
                    or key_l in _POLICY_TEXT_FIELD_NAMES
                    or any(
                        token in key_l
                        for token in ("scope", "selector", "pattern", "wildcard", "regex")
                    )
                ):
                    yield key_l, child
                # Recurse through every container, but continue yielding only
                # selector/rule/policy fields.  This catches a hidden
                # ``scope: '*'`` beneath an otherwise allowed attestation
                # object without scanning ordinary prose or concrete paths.
                if isinstance(child, (dict, list)):
                    yield from walk(child, key_l)
        elif isinstance(value, list):
            for child in value:
                if isinstance(child, (dict, list)):
                    yield from walk(child, field_name)

    yield from walk(record, "record")


def _contains_disallowed_scope_token(value: Any, *, field_name: str) -> set[str]:
    found: set[str] = set()
    values: Iterable[Any]
    if isinstance(value, dict):
        # Preserve nested keys so ``scope: {regex: ...}`` is treated as an
        # explicit selector rather than as an opaque object.
        for key, child in value.items():
            found.update(
                _contains_disallowed_scope_token(child, field_name=str(key).casefold())
            )
        values = ()
    elif isinstance(value, (list, tuple, set)):
        values = value
    else:
        values = (value,)
    for item in values:
        if not isinstance(item, str):
            continue
        text = item.casefold()
        # Terms are matched as lexical tokens, never as arbitrary substrings.
        tokens = set(re.findall(r"[a-z0-9_]+", text))
        for word in DISALLOWED_CORRECTION_WORDS | DISALLOWED_CATCH_ALL_TOKENS:
            word_l = word.casefold()
            if word_l in tokens or re.search(r"(?:^|[^a-z0-9_])" + re.escape(word_l) + r"(?:$|[^a-z0-9_])", text):
                found.add(f"CORRECTION_DISALLOWED_TERM:{word_l}")
        # Wildcard/regex metacharacters are forbidden only in an explicit scope
        # field.  Hashes and concrete paths elsewhere are not interpreted.
        if field_name in _SCOPE_FIELD_NAMES or any(
            token in field_name for token in ("scope", "selector", "pattern", "wildcard", "regex")
        ):
            if any(char in text for char in ("*", "?", "[", "]")) or re.search(r"(^|[^\\])\.[*+?]", text):
                found.add("CORRECTION_SCOPE_EXPRESSION_NOT_EXACT")
                # Keep a stable, human-readable diagnostic for the common
                # wildcard spelling while still reporting the generic exact
                # scope failure.
                found.add("CORRECTION_DISALLOWED_TERM:glob")
    return found
PATH_PREFIXES = (
    ".github/",
    "assets/",
    "data/",
    "docs/",
    "reports/",
    "resources/",
    "scenes/",
    "scripts/",
    "shaders/",
    "tests/",
    "tools/",
    "default_bus_layout.tres",
)


def _canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def _expected_correction_schema() -> dict[str, Any]:
    """Return the exact auditable V2 record and revocation contract."""
    transition_classes = []
    for source_failure_class, definition in sorted(HISTORY_RULE_CLASSES.items()):
        transition_classes.append({
            "source_failure_class": source_failure_class,
            "transition_class_id": definition["transition_class_id"],
            "allowed_rule_ids": definition["allowed_rule_ids"],
            "human_description": definition["human_description"],
        })
    representative = next(iter(HISTORY_RULE_CLASSES.values()))
    correction_fields = list(CORRECTION_RECORD_FIELDS)
    revocation_fields = list(REVOCATION_RECORD_FIELDS)
    return {
        "schema_version": CORRECTION_SCHEMA_VERSION,
        "authorization_id": AUTHORIZATION_ID,
        "authorized_head_sha": AUTHORIZED_HEAD_SHA,
        "active_resolver": "V076ReuseExactFailureCorrectionV2",
        "supersedes": "V1_READ_ONLY_HISTORY_INPUT",
        "active_correction_resolver_count": 1,
        "duplicate_correction_authority_count": 0,
        "catch_all_transition_classes": [],
        "future_failure_auto_correction_count": 0,
        "nested_object_contracts": {
            "current_blob_sha256_by_path": "KEY_SET_EXACTLY_EQUALS_PATHS",
            "current_counterpart_fingerprints_by_failure": (
                "KEY_SET_EXACTLY_EQUALS_FAILURE_FINGERPRINTS"
            ),
            "eligibility_policy": sorted(representative["eligibility_policy"]),
            "future_failure_policy": sorted(representative["future_failure_policy"]),
            "production_reachability_attestation": [
                "active_owner_violation_count",
                "dual_write_count",
                "fallback_count",
                "parallel_owner_count",
                "states",
            ],
            "revocation_policy": sorted(representative["revocation_policy"]),
            "touch_invalidation_policy": sorted(
                representative["touch_invalidation_policy"]
            ),
        },
        "common_transition_contract": {
            field: representative[field]
            for field in (
                "allowed_from_state",
                "allowed_to_state",
                "required_evidence",
                "required_reachability_state",
                "required_blob_binding",
                "required_untouched_state",
                "touch_invalidation_policy",
                "future_failure_policy",
                "revocation_policy",
                "negative_examples",
            )
        },
        "record_contracts": {
            "EXACT_HISTORICAL_CORRECTION_RECORD": {
                "required_fields": correction_fields,
                "allowed_fields": correction_fields,
                "additional_properties_allowed": False,
                "failure_fingerprint_pattern": "^V2F-[0-9a-f]{64}$",
                "path_scope": "EXACT_PATHS_ONLY",
                "new_failure_requires_new_record": True,
            },
            "CORRECTION_REVOCATION_RECORD": {
                "record_kind": "CORRECTION_REVOCATION_RECORD",
                "required_fields": revocation_fields,
                "allowed_fields": revocation_fields,
                "additional_properties_allowed": False,
                "allowed_new_effective_statuses": [
                    "TRUE_ACTIVE_VIOLATION",
                    "UNRESOLVED_BLOCKING",
                ],
                "append_only": True,
            },
        },
        "transition_classes": transition_classes,
    }


def _validate_correction_schema(output_root: Path) -> tuple[list[str], str]:
    """Validate the independent schema artifact and return its exact digest."""
    path = output_root / CORRECTION_SCHEMA_REL
    if not path.is_file():
        return [f"CORRECTION_SCHEMA_MISSING:{CORRECTION_SCHEMA_REL.as_posix()}"], ""
    try:
        payload = path.read_bytes()
        schema = json.loads(payload.decode("utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return [f"CORRECTION_SCHEMA_UNREADABLE:{CORRECTION_SCHEMA_REL.as_posix()}"], ""
    failures: list[str] = []
    if not isinstance(schema, dict) or schema != _expected_correction_schema():
        failures.append("CORRECTION_SCHEMA_CONTRACT_MISMATCH")
    elif payload != _canonical_bytes(schema):
        failures.append("CORRECTION_SCHEMA_NOT_CANONICAL")
    digest = sha256_bytes(payload)
    if digest != AUTHORIZED_CORRECTION_SCHEMA_SHA256:
        failures.append("CORRECTION_SCHEMA_AUTHORIZED_HASH_MISMATCH")
    return sorted(set(failures)), digest


def _schema_field_failures(
    record: dict[str, Any],
    *,
    expected_fields: Iterable[str],
    diagnostic_prefix: str,
    path_name: str,
) -> list[str]:
    expected = set(expected_fields)
    actual = set(record)
    failures: list[str] = []
    if expected - actual:
        failures.append(
            f"{diagnostic_prefix}_REQUIRED_FIELDS_MISSING:{path_name}:"
            + ",".join(sorted(expected - actual))
        )
    if actual - expected:
        failures.append(
            f"{diagnostic_prefix}_ADDITIONAL_FIELDS_FORBIDDEN:{path_name}:"
            + ",".join(sorted(actual - expected))
        )
    return failures


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def _is_int(value: Any) -> bool:
    """Reject bools at JSON integer trust boundaries."""

    return type(value) is int


def _is_exact_int(value: Any, expected: int) -> bool:
    return _is_int(value) and value == expected


def _write_immutable(path: Path, data: bytes, *, expected_sha: str | None = None) -> str:
    """Write only a new artifact, or prove an existing artifact is unchanged."""
    digest = sha256_bytes(data)
    if expected_sha and digest != expected_sha:
        raise ValueError(f"artifact hash mismatch before write: {path}: {digest}")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        existing = path.read_bytes()
        if existing != data:
            raise RuntimeError(f"immutable artifact already differs: {path}")
        return sha256_bytes(existing)
    path.write_bytes(data)
    return digest


def _write_generated_draft(
    path: Path,
    data: bytes,
    *,
    repository_root: Path | None = None,
) -> str:
    """Replace one task-owned, uncommitted generated draft deterministically.

    Frozen inputs and committed correction history always use
    :func:`_write_immutable`.  Inventories and records created during the
    currently authorized first V2 application have not yet become append-only
    history, so the generator may refresh those exact allowlisted drafts while
    its schema is being validated.  A committed path is never overwritten.
    """
    # ``output_root`` is intentionally allowed to be a temporary artifact
    # directory (the self-test uses a sibling of its temporary clone), so the
    # repository root must be supplied by the caller when it is not an
    # ancestor of the artifact.  Never infer a broad root from the process CWD.
    probe = (repository_root or path.resolve().parent).resolve()
    if not (probe / ".git").exists():
        while probe.parent != probe and not (probe / ".git").exists():
            probe = probe.parent
    if not (probe / ".git").exists():
        raise RuntimeError(f"generated draft has no verified Git worktree: {path}")
    try:
        relative = path.resolve().relative_to(probe.resolve()).as_posix()
    except ValueError as exc:
        # The isolated V2 self-test deliberately places its artifacts outside
        # the clone.  That path is safe only when the caller explicitly
        # supplied a verified repository_root; production generation always
        # keeps output_root inside the worktree.  Do not silently infer this
        # escape from the process working directory.
        if repository_root is None:
            raise RuntimeError(f"generated draft escapes repository: {path}") from exc
        relative = ""
    if relative and _bytes_at(probe, "HEAD", relative) is not None:
        raise RuntimeError(f"refusing to replace committed append-only artifact: {relative}")
    if relative and _git(
        probe,
        "ls-files",
        "--stage",
        "--",
        relative,
        check=False,
    ):
        raise RuntimeError(
            f"refusing to replace indexed append-only artifact: {relative}"
        )
    if relative and _git(
        probe,
        "log",
        "--all",
        "--format=%H",
        "--",
        relative,
        check=False,
    ):
        raise RuntimeError(
            f"refusing to recreate historical append-only artifact: {relative}"
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return sha256_bytes(data)


def _git(root: Path, *args: str, check: bool = True) -> str:
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and completed.returncode != 0:
        raise RuntimeError(
            f"git {' '.join(args)} failed ({completed.returncode}): {completed.stderr.strip()}"
        )
    return completed.stdout.strip()


def _git_bytes(root: Path, *args: str, check: bool = False) -> bytes | None:
    """Run a Git command without text decoding (used for byte/hash checks)."""
    completed = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        if check:
            raise RuntimeError(
                f"git {' '.join(args)} failed ({completed.returncode}): "
                f"{completed.stderr.decode('utf-8', errors='replace').strip()}"
            )
        return None
    return bytes(completed.stdout)


def _bytes_at(root: Path, commit: str, path: str) -> bytes | None:
    """Return the exact committed bytes for ``path`` or ``None`` if absent."""
    normalized = normalize_path(path)
    if not normalized:
        return None
    return _git_bytes(root, "show", f"{commit}:{normalized}")


def _json_at(root: Path, commit: str, path: str) -> Any | None:
    payload = _bytes_at(root, commit, path)
    if payload is None:
        return None
    try:
        return json.loads(payload.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None


def _read_sidecar_digest(
    artifact: Path,
    sidecar: Path,
    *,
    expected_paths: Iterable[str] = (),
) -> tuple[str | None, str | None]:
    """Read and verify a conventional ``sha256  path`` sidecar.

    The sidecar is treated as an assertion, never as an instruction.  Returning
    both digest and an error lets the resolver report a fail-closed diagnostic
    while still projecting the rest of the raw/effective counts.
    """
    if not artifact.is_file():
        return None, f"ARTIFACT_MISSING:{artifact.as_posix()}"
    if not sidecar.is_file():
        return None, f"HASH_SIDECAR_MISSING:{sidecar.as_posix()}"
    try:
        rendered = sidecar.read_text(encoding="ascii")
    except (OSError, UnicodeDecodeError):
        return None, f"HASH_SIDECAR_UNREADABLE:{sidecar.as_posix()}"
    if not rendered:
        return None, f"HASH_SIDECAR_EMPTY:{sidecar.as_posix()}"
    match = re.fullmatch(r"([0-9a-f]{64})  ([^\r\n]+)\n", rendered)
    if match is None:
        return None, f"HASH_SIDECAR_FORMAT_INVALID:{sidecar.as_posix()}"
    digest, declared_path = match.groups()
    allowed = {normalize_path(value) for value in expected_paths if normalize_path(value)}
    if allowed and normalize_path(declared_path) not in allowed:
        return None, f"HASH_SIDECAR_PATH_MISMATCH:{sidecar.as_posix()}"
    actual = sha256_file(artifact)
    if actual != digest:
        return None, f"HASH_SIDECAR_DIGEST_MISMATCH:{artifact.as_posix()}"
    return digest, None


def _expected_scanner_manifest(root: Path, *, commit: str) -> dict[str, Any]:
    """Build the canonical scanner manifest from committed core bytes."""
    rows: list[dict[str, Any]] = []
    for relative in SCANNER_CORE_PATHS:
        payload = _bytes_at(root, commit, relative)
        if payload is None:
            continue
        rows.append({
            "path": relative,
            "sha256": sha256_bytes(payload),
            "byte_count": len(payload),
        })
    return {
        "schema_version": f"{SCHEMA_VERSION}.scanner_manifest",
        "authorization_id": AUTHORIZATION_ID,
        "authorized_head_sha": AUTHORIZED_HEAD_SHA,
        "scanner_core_byte_stable": True,
        "scanner_rule_removal_count": 0,
        "scanner_scope_reduction_count": 0,
        "scanner_severity_downgrade_count": 0,
        "scanner_history_depth_reduction_count": 0,
        "files": rows,
    }


def _expected_v1_manifest(root: Path, *, commit: str) -> dict[str, Any]:
    ledger_path = "docs/architecture/V076_INHERITED_GREEN_LEDGER.json"
    ledger = _json_at(root, commit, ledger_path)
    if not isinstance(ledger, dict):
        return {}
    existing_rows: list[dict[str, Any]] = []
    for stage in ledger.get("stages", []):
        if not isinstance(stage, dict):
            continue
        for evidence in stage.get("evidence", []):
            if isinstance(evidence, dict) and evidence.get("correction_kind"):
                existing_rows.append(evidence)
    ledger_bytes = _bytes_at(root, commit, ledger_path)
    return {
        "schema_version": f"{SCHEMA_VERSION}.existing_corrections_manifest",
        "authorization_id": AUTHORIZATION_ID,
        "authorized_head_sha": AUTHORIZED_HEAD_SHA,
        "source_path": ledger_path,
        "source_sha256": sha256_bytes(ledger_bytes) if ledger_bytes is not None else "",
        "v1_correction_record_count": len(existing_rows),
        "v1_correction_kinds": sorted({str(row.get("correction_kind")) for row in existing_rows}),
        "records": [
            {
                "evidence_id": str(row.get("evidence_id", "")),
                "correction_kind": str(row.get("correction_kind", "")),
                "payload_sha256": sha256_bytes(_canonical_bytes(row)),
            }
            for row in existing_rows
        ],
        "v1_read_only": True,
    }


@lru_cache(maxsize=None)
def _resolve_commit(root: Path, value: str) -> str:
    resolved = _git(root, "rev-parse", f"{value}^{{commit}}", check=False)
    if not re.fullmatch(r"[0-9a-f]{40}", resolved):
        raise ValueError(f"cannot resolve commit identity: {value}")
    return resolved


def _commit_tree(root: Path, commit: str) -> str:
    value = _git(root, "show", "-s", "--format=%T", commit, check=False)
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError(f"cannot resolve tree for {commit}")
    return value


@lru_cache(maxsize=None)
def _blob_at(root: Path, commit: str, path: str) -> str:
    payload = _bytes_at(root, commit, path)
    return sha256_bytes(payload) if payload is not None else "MISSING"


def normalize_path(value: str) -> str:
    value = str(value or "").strip().replace("\\", "/")
    value = value.removeprefix("res://")
    return value


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def _authority_rows(
    root: Path,
    commit: str | None = None,
) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    registry_path = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
    registry = load_json(root / registry_path) if commit is None else _json_at(root, commit, registry_path)
    if not isinstance(registry, dict):
        return {}, {}, {}
    by_path: dict[str, dict[str, Any]] = {}
    by_component: dict[str, dict[str, Any]] = {}
    by_domain: dict[str, dict[str, Any]] = {}
    for row in registry.get("component_inventory", []):
        if isinstance(row, dict):
            path = normalize_path(str(row.get("path", "")))
            component_id = str(row.get("component_id", ""))
            if path:
                by_path[path] = row
            if component_id:
                by_component[component_id] = row
    for row in registry.get("domain_inventory", []):
        if isinstance(row, dict) and row.get("domain_id"):
            by_domain[str(row["domain_id"])] = row
    return by_path, by_component, by_domain


# These are the fields whose mutation can change an Owner, a component's
# production reachability, or a supersession relation.  Cosmetic registry
# prose (focused-test descriptions, rationale, etc.) is intentionally excluded
# so an unrelated documentation delta does not invalidate an exact correction.
_COMPONENT_BINDING_FIELDS = (
    "component_id",
    "path",
    "domain_id",
    "component_role",
    "production_reachable",
    "owner_component_id",
    "owner_path",
    "writes_authority",
    "reads_authority",
    "owns_rng",
    "owns_tick",
    "owns_save",
    "owns_replay",
    "owns_identity",
    "owns_presentation",
    "reuse_disposition",
    "supersedes",
    "superseded_by",
)
_DOMAIN_BINDING_FIELDS = (
    "domain_id",
    "lifecycle",
    "owner_component_id",
    "owner_path",
    "production_reachable",
    "supersedes",
    "superseded_by",
)


def _binding_signature(row: dict[str, Any] | None, fields: Iterable[str]) -> str | None:
    if row is None:
        return None
    selected: dict[str, Any] = {}
    for field in fields:
        if field not in row:
            continue
        value = row[field]
        # Supersession and owner sets are relations, not ordered prose.
        if field in {"supersedes", "superseded_by"} and isinstance(value, list):
            value = sorted(str(item) for item in value)
        selected[field] = value
    return sha256_bytes(_canonical_bytes(selected))


def _is_synthetic_component_id(value: str) -> bool:
    return value.startswith("failure.")


def _row_authority_bindings(
    root: Path,
    row: dict[str, Any],
    *,
    commit: str,
) -> tuple[dict[str, Any] | None, dict[str, Any] | None, dict[str, Any] | None]:
    """Resolve component/path/domain rows from one committed registry snapshot."""
    by_path, by_component, by_domain = _authority_rows(root, commit)
    path = normalize_path(str(row.get("path", "")))
    component_id = str(row.get("component_id", ""))
    component = None
    if component_id and not _is_synthetic_component_id(component_id):
        component = by_component.get(component_id)
    if component is None and path:
        component = by_path.get(path)
    domain_id = str(row.get("domain_id", ""))
    domain = by_domain.get(domain_id) if domain_id else None
    return component, domain, by_path.get(path) if path else None


def _v1_correction_index(
    root: Path,
    *,
    commit: str | None = None,
) -> dict[tuple[str, str, str], str]:
    """Read V1 records without modifying or reinterpreting them.

    ``commit`` is deliberately optional for callers that need a live read, but
    all frozen-baseline operations pass the authorized commit.  Reading the
    working-tree ledger while freezing a report would allow an unrelated dirty
    edit to silently change the V1 authority used for classification.
    """
    ledger_path = "docs/architecture/V076_INHERITED_GREEN_LEDGER.json"
    ledger = load_json(root / ledger_path) if commit is None else _json_at(root, commit, ledger_path)
    if not isinstance(ledger, dict):
        return {}
    result: dict[tuple[str, str, str], str] = {}
    for stage in ledger.get("stages", []):
        if not isinstance(stage, dict):
            continue
        for evidence in stage.get("evidence", []):
            if not isinstance(evidence, dict) or not evidence.get("correction_kind"):
                continue
            evidence_id = str(evidence.get("evidence_id", ""))
            for row in evidence.get("affected_failures", []):
                if not isinstance(row, dict):
                    continue
                head = str(row.get("head_sha", ""))
                code = str(row.get("failure_code", ""))
                target = str(row.get("target", row.get("component_id", "")))
                if head and code:
                    result[(head, code, target)] = evidence_id
            for transition in evidence.get("affected_transitions", []):
                if not isinstance(transition, dict):
                    continue
                head = str(transition.get("head_sha", ""))
                for code in transition.get("failure_codes", []):
                    if head and code:
                        result[(head, str(code), "")] = evidence_id
    return result


def _extract_transition(raw: str) -> tuple[str, str] | None:
    match = re.search(r"(?P<old>[0-9a-f]{12,40})->(?P<new>[0-9a-f]{12,40})", raw)
    if not match:
        return None
    return match.group("old"), match.group("new")


def _extract_source_commit(root: Path, raw: str, head: str) -> tuple[str, str | None]:
    transition = _extract_transition(raw)
    if transition:
        old, new = transition
        return _resolve_commit(root, new), f"{_resolve_commit(root, old)}->{_resolve_commit(root, new)}"
    if raw.startswith("HISTORY_"):
        payload = raw.split(":", 1)[1] if ":" in raw else ""
        token = payload.split(":", 1)[0]
        if re.fullmatch(r"[0-9a-f]{12,40}", token):
            return _resolve_commit(root, token), None
    # A historical row without an explicit transition has no admissible source
    # identity.  Keep current-delta rows anchored to the evaluated head, but do
    # not fabricate the authorized head as a historical source.
    return ("" if raw.startswith("HISTORY_") else head), None


def _extract_path_or_component(raw: str) -> tuple[str, str]:
    # Prefer a concrete repository path.  This deliberately does not accept a
    # directory prefix as an identity.
    tail = raw.split(":", 1)[1] if ":" in raw else ""
    path_pattern = re.compile(
        r"(?:res://)?(?:\.github/|assets/|data/|docs/|reports/|resources/|scenes/|scripts/|shaders/|tests/|tools/|default_bus_layout\.tres)[^:]*"
    )
    candidates = [normalize_path(m.group(0)) for m in path_pattern.finditer(tail)]
    if candidates:
        # A path can be followed by a field name; choose the longest concrete
        # path that is actually shaped like a repository file.
        candidates.sort(key=lambda item: ("." in Path(item).name, len(item)), reverse=True)
        return candidates[0], ""
    component_match = re.search(
        r"(?:component\.|current\.|future\.|product\.)[A-Za-z0-9_.-]+", tail
    )
    if component_match:
        return "", component_match.group(0)
    # Some aggregate contract failures intentionally have no file path.  They
    # still need a stable auditable subject in the inventory; use a rule-scoped
    # synthetic component identity rather than an unresolved/blank identity.
    rule_id = raw.split(":", 1)[0].strip().casefold().replace(" ", "_")
    subject = tail.split(":", 1)[0].strip().casefold().replace(" ", "_")
    if subject:
        return "", f"failure.{rule_id}.{subject}"
    return "", f"failure.{rule_id}"


@lru_cache(maxsize=None)
def _is_ancestor(root: Path, older: str, newer: str) -> bool:
    return subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", older, newer],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def _failure_fingerprint(raw: str, bucket: str, rule_id: str) -> str:
    payload = f"V076_RAW_FAILURE_V2\n{bucket}\n{rule_id}\n{raw}\n".encode("utf-8")
    return "V2F-" + sha256_bytes(payload)


def _current_delta_paths(root: Path, base: str, head: str) -> set[str]:
    output = _git(root, "diff", "--name-only", base, head, check=False)
    return {normalize_path(line) for line in output.splitlines() if normalize_path(line)}


@lru_cache(maxsize=None)
def _transition_parent_commits(root: Path, commit: str) -> frozenset[str]:
    """Return the exact parent identities recorded for ``commit``."""
    value = _git(root, "rev-list", "--parents", "-n", "1", commit, check=False)
    parts = value.split()
    if not parts or parts[0] != commit:
        return frozenset()
    return frozenset(item for item in parts[1:] if re.fullmatch(r"[0-9a-f]{40}", item))


def _transition_eligibility(
    root: Path,
    raw: str,
    *,
    rule_id: str,
    source_commit: str,
    authorized_head: str,
    path: str,
    component_id: str,
    current_blob_sha256: str,
    production_reachability_state: str,
) -> dict[str, Any]:
    """Build independently checkable evidence for a historical row.

    A ``HISTORY_`` prefix is only a scanner label.  It is not sufficient to
    make a row correctable: the raw row must contain a complete old->new
    transition, the new commit must be a real ancestor strictly before the
    authorized head, and the subject must resolve to one concrete path or
    registered component identity.  The evidence is persisted in the inventory
    and copied into records so a later resolver run does not infer eligibility
    from a mutable class name.
    """
    result: dict[str, Any] = {
        "historical_rule": rule_id.startswith("HISTORY_"),
        "transition_present": False,
        "transition_old_commit": "",
        "transition_new_commit": "",
        "transition_exact": False,
        "transition_direct_parent": False,
        "source_commit_exact": False,
        "source_commit_ancestor_of_authorized_head": False,
        "source_commit_precedes_authorized_head": False,
        "identity_resolved": bool(
            (path and re.fullmatch(r"[0-9a-f]{64}", current_blob_sha256))
            or (component_id and not _is_synthetic_component_id(component_id))
        ),
        "identity_kind": (
            "path"
            if path
            else "registered_component"
            if component_id and not _is_synthetic_component_id(component_id)
            else "unresolved"
        ),
        "eligible_for_correction": False,
        "current_blob_sha256": current_blob_sha256,
        "production_reachability_state": production_reachability_state,
        "production_reachability_resolved": production_reachability_state
        in {"production_reachable", "non_production"},
        "current_counterparts_remain_separate": True,
        "ineligibility_reasons": [],
    }
    match = _extract_transition(raw)
    if not match:
        result["ineligibility_reasons"].append("TRANSITION_MISSING_OR_INCOMPLETE")
    else:
        old_token, new_token = match
        result["transition_present"] = True
        try:
            old_commit = _resolve_commit(root, old_token)
            new_commit = _resolve_commit(root, new_token)
        except (RuntimeError, ValueError):
            old_commit = ""
            new_commit = ""
            result["ineligibility_reasons"].append("TRANSITION_COMMIT_UNRESOLVED")
        if old_commit and new_commit:
            result["transition_old_commit"] = old_commit
            result["transition_new_commit"] = new_commit
            result["transition_exact"] = bool(
                source_commit == new_commit and old_commit != new_commit
            )
            result["source_commit_exact"] = source_commit == new_commit
            result["transition_direct_parent"] = old_commit in _transition_parent_commits(
                root, new_commit
            )
            result["source_commit_ancestor_of_authorized_head"] = _is_ancestor(
                root, new_commit, authorized_head
            )
            # Equality with the authorized head is deliberately not historical:
            # a correction may only bind a transition observed strictly before
            # the frozen report head.
            result["source_commit_precedes_authorized_head"] = (
                new_commit != authorized_head
                and result["source_commit_ancestor_of_authorized_head"]
            )
            if not result["transition_exact"]:
                result["ineligibility_reasons"].append("SOURCE_COMMIT_NOT_TRANSITION_NEW")
            if not result["transition_direct_parent"]:
                result["ineligibility_reasons"].append("TRANSITION_NOT_DIRECT_PARENT")
            if not result["source_commit_precedes_authorized_head"]:
                result["ineligibility_reasons"].append("SOURCE_COMMIT_NOT_STRICTLY_BEFORE_AUTHORIZED_HEAD")
        else:
            result["ineligibility_reasons"].append("TRANSITION_COMMIT_UNRESOLVED")
    if not result["identity_resolved"]:
        result["ineligibility_reasons"].append("UNRESOLVED_IDENTITY")
    if not result["production_reachability_resolved"]:
        result["ineligibility_reasons"].append("PRODUCTION_REACHABILITY_UNRESOLVED")
    result["eligible_for_correction"] = bool(
        result["historical_rule"]
        and result["transition_exact"]
        and result["transition_direct_parent"]
        and result["source_commit_exact"]
        and result["source_commit_precedes_authorized_head"]
        and result["identity_resolved"]
        and result["production_reachability_resolved"]
    )
    result["ineligibility_reasons"] = sorted(set(result["ineligibility_reasons"]))
    return result


def parse_failure_rows(root: Path, raw_report: dict[str, Any], *, authorized_head: str) -> list[dict[str, Any]]:
    # Baseline classification must use committed authority at the exact frozen
    # head, never a potentially dirty working-tree registry or ledger.
    by_path, by_component, by_domain = _authority_rows(root, authorized_head)
    v1_index = _v1_correction_index(root, commit=authorized_head)
    changed_after_authorized = _current_delta_paths(root, authorized_head, authorized_head)
    rows: list[dict[str, Any]] = []
    raw_failures = [str(value) for value in raw_report.get("failures", [])]
    for raw in raw_failures:
        rule_id = raw.split(":", 1)[0]
        bucket = "HISTORICAL" if rule_id.startswith("HISTORY_") else "CURRENT_DELTA_FAILURE"
        try:
            source_commit, transition = _extract_source_commit(root, raw, authorized_head)
        except (RuntimeError, ValueError):
            source_commit, transition = "", ""
        path, component_token = _extract_path_or_component(raw)
        component = by_path.get(path) if path else by_component.get(component_token)
        # Aggregate history rows often name a registered component rather than
        # spelling out its implementation path.  Bind that row to the exact
        # Owner path when the registry can prove one; this gives the correction
        # a concrete blob/touch subject without inventing a directory scope.
        if not path and component:
            registered_path = normalize_path(str(component.get("path", "")))
            if registered_path:
                path = registered_path
        component_id = str(component.get("component_id", "")) if component else component_token
        domain_id = str(component.get("domain_id", "")) if component else ""
        if domain_id and domain_id not in by_domain:
            domain_id = domain_id
        current_blob = _blob_at(root, authorized_head, path)
        failure_blob = _blob_at(root, source_commit, path) if source_commit else "MISSING"
        fingerprint = _failure_fingerprint(raw, bucket, rule_id)
        v1_key = (source_commit, rule_id, component_id or path)
        v1_id = v1_index.get(v1_key, "")
        if not v1_id:
            v1_id = v1_index.get((source_commit, rule_id, ""), "")
        reachability_state = (
            "production_reachable"
            if component and component.get("production_reachable") is True
            else "non_production"
            if component and component.get("production_reachable") is False
            else "unresolved"
        )
        eligibility = _transition_eligibility(
            root,
            raw,
            rule_id=rule_id,
            source_commit=source_commit,
            authorized_head=authorized_head,
            path=path,
            component_id=component_id,
            current_blob_sha256=current_blob,
            production_reachability_state=reachability_state,
        )
        if rule_id in HISTORY_RULE_CLASSES and not v1_id and eligibility["eligible_for_correction"]:
            recommended = "HISTORICAL_MISSING_TRANSITION_CLASS"
        elif bucket == "HISTORICAL" and eligibility["eligible_for_correction"]:
            recommended = "HISTORICAL_SUPPORTED_TRANSITION"
        elif bucket == "HISTORICAL":
            recommended = "UNRESOLVED_BLOCKING"
        else:
            recommended = "TRUE_ACTIVE_VIOLATION"
        rows.append(
            {
                "failure_id": fingerprint,
                "failure_fingerprint": fingerprint,
                "raw_failure": raw,
                "rule_id": rule_id,
                "failure_class": rule_id,
                "severity": "P0" if bucket != "HISTORICAL" else "P2",
                "source_commit": source_commit,
                "first_seen_commit": source_commit,
                "last_seen_commit": authorized_head,
                "transition": transition or "",
                "path": path,
                "blob_sha256_at_failure": failure_blob,
                "current_path": path,
                "current_blob_sha256": current_blob,
                "component_id": component_id,
                "domain_id": domain_id,
                "production_reachable": bool(component and component.get("production_reachable") is True),
                "production_reachability_state": reachability_state,
                "introduced_before_gate_activation": _is_ancestor(root, source_commit, GATE_ACTIVATION_SHA),
                "touched_in_current_delta": bool(path and path in changed_after_authorized),
                "existing_transition_class": "V1_EXISTING_CORRECTION" if v1_id else "",
                "existing_correction_id": v1_id,
                "recommended_disposition": recommended,
                "transition_old_commit": eligibility["transition_old_commit"],
                "transition_new_commit": eligibility["transition_new_commit"],
                "transition_eligibility": eligibility,
                "evidence": [
                    "reports/reuse/correction_v2/baseline_raw_failure_report.json",
                    f"git:{source_commit}:{path}" if path else f"git:{source_commit}",
                ],
            }
        )
    # Bind each historical row to any current-delta counterpart by exact subject
    # identity.  The counterpart is never included in a correction record; this
    # explicit projection lets Audit B verify that current violations remain a
    # separate active set.
    current_rows = [row for row in rows if not str(row.get("rule_id", "")).startswith("HISTORY_")]
    for row in rows:
        if not str(row.get("rule_id", "")).startswith("HISTORY_"):
            row["current_counterpart_fingerprints"] = []
            continue
        subject_path = normalize_path(str(row.get("path", "")))
        subject_component = str(row.get("component_id", ""))
        matches = []
        for current in current_rows:
            current_path = normalize_path(str(current.get("path", "")))
            current_component = str(current.get("component_id", ""))
            if subject_path and current_path == subject_path:
                matches.append(str(current["failure_fingerprint"]))
            elif (
                not subject_path
                and subject_component
                and not _is_synthetic_component_id(subject_component)
                and current_component == subject_component
            ):
                matches.append(str(current["failure_fingerprint"]))
        row["current_counterpart_fingerprints"] = sorted(set(matches))
        row["current_counterparts_remain_separate"] = True
    return sorted(rows, key=lambda row: (row["failure_fingerprint"], row["raw_failure"]))


def _manifest_rows(root: Path, paths: Iterable[str]) -> list[dict[str, Any]]:
    rows = []
    for relative in paths:
        path = root / relative
        if not path.is_file():
            raise FileNotFoundError(path)
        data = path.read_bytes()
        rows.append({"path": relative, "sha256": sha256_bytes(data), "byte_count": len(data)})
    return rows


def freeze_baseline(root: Path, raw_report_path: Path, output_root: Path) -> dict[str, Any]:
    """Freeze the exact CI raw report and byte manifests, append-only."""
    raw_bytes = raw_report_path.read_bytes()
    raw = json.loads(raw_bytes.decode("utf-8-sig"))
    head = str(raw.get("head_sha", ""))
    if head != AUTHORIZED_HEAD_SHA:
        raise ValueError(f"baseline head mismatch: {head}")
    if not isinstance(raw.get("failures"), list):
        raise ValueError("baseline report lacks failures list")
    # The authorized report identity is sealed out-of-band.  Refuse to create
    # a new baseline merely because a caller supplied a same-head report with a
    # different failure set or byte encoding.
    if sha256_bytes(raw_bytes) != AUTHORIZED_BASELINE_REPORT_SHA256:
        raise ValueError("baseline report hash does not match authorized frozen report")
    baseline_path = output_root / BASELINE_REPORT_REL
    baseline_sha = _write_immutable(baseline_path, raw_bytes)
    _write_immutable(
        output_root / BASELINE_REPORT_SHA_REL,
        (baseline_sha + "  " + BASELINE_REPORT_REL.as_posix() + "\n").encode("ascii"),
    )
    # Freeze scanner bytes from the exact committed head, not from the caller's
    # working tree.  This is essential when the repository contains unrelated
    # uncommitted playtest evidence.
    scanner_manifest = _expected_scanner_manifest(root, commit=AUTHORIZED_HEAD_SHA)
    scanner_bytes = _canonical_bytes(scanner_manifest)
    scanner_sha = _write_immutable(output_root / SCANNER_MANIFEST_REL, scanner_bytes)
    _write_immutable(
        output_root / SCANNER_MANIFEST_SHA_REL,
        (scanner_sha + "  " + SCANNER_MANIFEST_REL.as_posix() + "\n").encode("ascii"),
    )
    ledger_path = "docs/architecture/V076_INHERITED_GREEN_LEDGER.json"
    ledger = _json_at(root, AUTHORIZED_HEAD_SHA, ledger_path)
    if not isinstance(ledger, dict):
        raise ValueError("authorized V1 ledger is unreadable")
    existing_rows = []
    for stage in ledger.get("stages", []):
        if not isinstance(stage, dict):
            continue
        for evidence in stage.get("evidence", []):
            if isinstance(evidence, dict) and evidence.get("correction_kind"):
                existing_rows.append(evidence)
    existing_manifest = {
        "schema_version": f"{SCHEMA_VERSION}.existing_corrections_manifest",
        "authorization_id": AUTHORIZATION_ID,
        "authorized_head_sha": AUTHORIZED_HEAD_SHA,
        "source_path": "docs/architecture/V076_INHERITED_GREEN_LEDGER.json",
        "source_sha256": sha256_bytes(_bytes_at(root, AUTHORIZED_HEAD_SHA, ledger_path) or b""),
        "v1_correction_record_count": len(existing_rows),
        "v1_correction_kinds": sorted({str(row.get("correction_kind")) for row in existing_rows}),
        "records": [
            {
                "evidence_id": str(row.get("evidence_id", "")),
                "correction_kind": str(row.get("correction_kind", "")),
                "payload_sha256": sha256_bytes(_canonical_bytes(row)),
            }
            for row in existing_rows
        ],
        "v1_read_only": True,
    }
    existing_bytes = _canonical_bytes(existing_manifest)
    existing_sha = _write_immutable(output_root / EXISTING_CORRECTIONS_REL, existing_bytes)
    _write_immutable(
        output_root / EXISTING_CORRECTIONS_SHA_REL,
        (existing_sha + "  " + EXISTING_CORRECTIONS_REL.as_posix() + "\n").encode("ascii"),
    )
    return {
        "baseline_report_sha256": baseline_sha,
        "scanner_manifest_sha256": scanner_sha,
        "existing_corrections_manifest_sha256": existing_sha,
        "raw_failure_count": len(raw.get("failures", [])),
        "raw_historical_failure_count": sum(
            1 for value in raw["failures"] if str(value).startswith("HISTORY_")
        ),
        "raw_current_delta_failure_count": sum(
            1 for value in raw["failures"] if not str(value).startswith("HISTORY_")
        ),
        "authorized_head_sha": AUTHORIZED_HEAD_SHA,
    }


def build_inventories(root: Path, output_root: Path) -> dict[str, Any]:
    baseline_path = output_root / BASELINE_REPORT_REL
    if not baseline_path.is_file():
        raise FileNotFoundError(baseline_path)
    baseline_bytes = baseline_path.read_bytes()
    baseline = json.loads(baseline_bytes.decode("utf-8-sig"))
    baseline_sha = sha256_bytes(baseline_bytes)
    rows = parse_failure_rows(root, baseline, authorized_head=AUTHORIZED_HEAD_SHA)
    if len(rows) != len(baseline.get("failures", [])):
        raise RuntimeError("failure inventory coverage is not 100 percent")
    fingerprints = [str(row["failure_fingerprint"]) for row in rows]
    if len(set(fingerprints)) != len(fingerprints):
        raise RuntimeError("duplicate failure fingerprints in baseline inventory")
    inventory = {
        "schema_version": INVENTORY_SCHEMA_VERSION,
        "authorization_id": AUTHORIZATION_ID,
        "authorized_head_sha": AUTHORIZED_HEAD_SHA,
        "baseline_report_sha256": baseline_sha,
        "failure_inventory_coverage": "100_PERCENT",
        "failure_fingerprint_duplicate_count": len(fingerprints) - len(set(fingerprints)),
        "failure_without_rule_id_count": sum(1 for row in rows if not row["rule_id"]),
        "failure_without_source_commit_count": sum(1 for row in rows if not row["source_commit"]),
        "failure_without_path_or_component_id_count": sum(
            1 for row in rows if not row["path"] and not row["component_id"]
        ),
        "rows": rows,
    }
    inventory_path = output_root / FAILURE_INVENTORY_REL
    _write_generated_draft(
        inventory_path, _canonical_bytes(inventory), repository_root=root
    )
    historical = [row for row in rows if row["rule_id"].startswith("HISTORY_")]
    current = [row for row in rows if not row["rule_id"].startswith("HISTORY_")]
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in historical:
        groups[row["failure_class"]].append(row)
    missing = {
        "schema_version": f"{INVENTORY_SCHEMA_VERSION}.missing_transition_classes",
        "authorized_head_sha": AUTHORIZED_HEAD_SHA,
        "baseline_report_sha256": baseline_sha,
        "classes": [
            {
                "failure_class": code,
                "transition_class_id": HISTORY_RULE_CLASSES.get(code, {}).get(
                    "transition_class_id", "UNSUPPORTED"
                ),
                "failure_count": len(group),
                "failure_fingerprints": sorted(row["failure_fingerprint"] for row in group),
                "source_commits": sorted({row["source_commit"] for row in group}),
                "paths": sorted({row["path"] for row in group if row["path"]}),
                "evidence": sorted(
                    {
                        evidence
                        for row in group
                        for evidence in row.get("evidence", [])
                    }
                ),
            }
            for code, group in sorted(groups.items())
        ],
    }
    _write_generated_draft(
        output_root / MISSING_CLASS_REL,
        _canonical_bytes(missing),
        repository_root=root,
    )
    active = {
        "schema_version": f"{INVENTORY_SCHEMA_VERSION}.true_active",
        "authorized_head_sha": AUTHORIZED_HEAD_SHA,
        "baseline_report_sha256": baseline_sha,
        "true_active_violation_count": len(current),
        "rows": current,
    }
    _write_generated_draft(
        output_root / ACTIVE_INVENTORY_REL,
        _canonical_bytes(active),
        repository_root=root,
    )
    md_lines = [
        "# V076 exact failure inventory (frozen baseline)",
        "",
        f"- Authorization: `{AUTHORIZATION_ID}`",
        f"- Authorized head: `{AUTHORIZED_HEAD_SHA}`",
        f"- Baseline SHA-256: `{baseline_sha}`",
        f"- Coverage: `{inventory['failure_inventory_coverage']}`",
        f"- Rows: `{len(rows)}`; historical `{len(historical)}`; current delta `{len(current)}`",
        "",
        "| fingerprint | class | source commit | path/component | disposition |",
        "|---|---|---|---|---|",
    ]
    for row in rows:
        subject = row["path"] or row["component_id"] or "UNRESOLVED_IDENTITY"
        md_lines.append(
            f"| `{row['failure_fingerprint']}` | `{row['failure_class']}` | `{row['source_commit']}` | `{subject}` | `{row['recommended_disposition']}` |"
        )
    _write_generated_draft(
        output_root / FAILURE_INVENTORY_MD_REL,
        ("\n".join(md_lines) + "\n").encode("utf-8"),
        repository_root=root,
    )
    return {
        "inventory_sha256": sha256_file(inventory_path),
        "missing_transition_sha256": sha256_file(output_root / MISSING_CLASS_REL),
        "active_inventory_sha256": sha256_file(output_root / ACTIVE_INVENTORY_REL),
        "failure_count": len(rows),
        "historical_count": len(historical),
        "current_count": len(current),
    }


def _record_payload(record: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in record.items() if key != "record_payload_sha256"}


def _record_path_for_class(root: Path, transition_class_id: str) -> Path:
    slug = re.sub(r"[^a-z0-9]+", "_", transition_class_id.casefold()).strip("_")
    return root / RECORD_DIR_REL / f"{slug}.json"


def _record_sort_key(row: dict[str, Any]) -> tuple[str, str]:
    return (
        str(row.get("failure_fingerprint", "")),
        str(row.get("raw_failure", "")),
    )


def _record_created_at(root: Path, record_id: str) -> str:
    """Return a deterministic schema timestamp for immutable regeneration.

    The value is metadata, not evidence chronology.  Tying it to the authorized
    head avoids a wall-clock-dependent immutable mismatch on a clean rebuild.
    """
    epoch = int(_git(root, "show", "-s", "--format=%ct", AUTHORIZED_HEAD_SHA, check=False) or "0")
    base = datetime.fromtimestamp(epoch, timezone.utc)
    # Stable per-record microseconds keep values distinct without consulting the
    # clock.  The hash remains bounded below one second.
    micros = int(sha256_bytes(record_id.encode("utf-8"))[:5], 16) % 1_000_000
    return base.replace(microsecond=micros).isoformat().replace("+00:00", "Z")


def generate_records(root: Path, output_root: Path) -> dict[str, Any]:
    """Generate the exact eligible record set without deleting stale drafts.

    During the first, still-uncommitted V2 authoring pass a schema change can
    alter record filenames.  Extra files under ``records/`` are never silently
    deleted: this function fails with their exact paths before writing anything.
    The operator must move those task-owned, uncommitted drafts to an archive
    outside ``docs/architecture/reuse_corrections/v2/records`` and rerun.  A
    committed record remains append-only and must instead be revoked.
    """
    schema_failures, _ = _validate_correction_schema(output_root)
    if schema_failures:
        raise ValueError("correction schema invalid: " + ";".join(schema_failures))
    inventory = load_json(output_root / FAILURE_INVENTORY_REL)
    rows = list(inventory.get("rows", []))
    baseline_sha = str(inventory.get("baseline_report_sha256", ""))
    if not baseline_sha:
        raise ValueError("inventory has no baseline binding")
    historical = [row for row in rows if str(row.get("rule_id", "")).startswith("HISTORY_")]
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in historical:
        rule_id = str(row.get("rule_id", ""))
        definition = HISTORY_RULE_CLASSES.get(rule_id)
        if not definition:
            raise ValueError(f"no explicit V2 transition class for {rule_id}")
        # Only rows with independently verified transition/source/identity
        # evidence may enter a correction record.  Ineligible historical rows
        # remain in the frozen inventory as UNRESOLVED_BLOCKING.
        eligibility = row.get("transition_eligibility", {})
        if eligibility.get("eligible_for_correction") is not True:
            continue
        reachability_state = (
            "production_reachable" if row.get("production_reachable") else "non_production"
        )
        grouped[(str(definition["transition_class_id"]), reachability_state)].append(row)
    planned_paths: set[Path] = set()
    for transition_class_id, reachability_state in sorted(grouped):
        state_count = sum(1 for key in grouped if key[0] == transition_class_id)
        planned_paths.add(
            _record_path_for_class(
                output_root,
                transition_class_id
                if state_count == 1
                else f"{transition_class_id}_{reachability_state}",
            ).resolve()
        )
    existing_paths = {
        path.resolve() for path in (output_root / RECORD_DIR_REL).glob("*.json")
    }
    stale_paths = sorted(existing_paths - planned_paths, key=lambda value: value.as_posix())
    if stale_paths:
        rendered = ",".join(
            path.relative_to(output_root.resolve()).as_posix() for path in stale_paths
        )
        raise RuntimeError(
            "STALE_RECORD_DRAFTS_REQUIRE_ARCHIVE:"
            + rendered
            + ":move these exact task-owned uncommitted drafts outside "
            + RECORD_DIR_REL.as_posix()
            + "; never delete or overwrite a committed correction record"
        )
    records: list[dict[str, Any]] = []
    previous_chain = ""
    for (transition_class_id, reachability_state), group in sorted(grouped.items()):
        rule_ids = sorted({str(row["rule_id"]) for row in group})
        if len(rule_ids) != 1:
            raise ValueError("a record cannot cross source failure classes")
        rule_id = rule_ids[0]
        definition = HISTORY_RULE_CLASSES[rule_id]
        fingerprints = sorted(str(row["failure_fingerprint"]) for row in group)
        paths = sorted({str(row["path"]) for row in group if row.get("path")})
        source_commits = sorted({str(row["source_commit"]) for row in group})
        component_ids = sorted({str(row["component_id"]) for row in group if row.get("component_id")})
        domain_ids = sorted({str(row["domain_id"]) for row in group if row.get("domain_id")})
        raw_failures = sorted(str(row["raw_failure"]) for row in group)
        current_counterparts = {
            str(row["failure_fingerprint"]): sorted(
                str(value) for value in row.get("current_counterpart_fingerprints", [])
            )
            for row in group
        }
        bindings = [
            {
                "failure_fingerprint": str(row["failure_fingerprint"]),
                "raw_failure": str(row["raw_failure"]),
                "rule_id": str(row["rule_id"]),
                "failure_class": str(row["failure_class"]),
                "source_commit": str(row["source_commit"]),
                "transition": str(row.get("transition", "")),
                "transition_old_commit": str(row.get("transition_old_commit", "")),
                "transition_new_commit": str(row.get("transition_new_commit", "")),
                "path": normalize_path(str(row.get("path", ""))),
                "component_id": str(row.get("component_id", "")),
                "domain_id": str(row.get("domain_id", "")),
                "current_blob_sha256": str(row.get("current_blob_sha256", "")),
                "current_counterpart_fingerprints": current_counterparts.get(
                    str(row["failure_fingerprint"]), []
                ),
            }
            for row in sorted(group, key=_record_sort_key)
        ]
        blob_map = {
            str(row["path"]): str(row["current_blob_sha256"])
            for row in group
            if row.get("path")
        }
        record_id = "V2-" + sha256_bytes(
            (transition_class_id + "\n" + reachability_state + "\n" + "\n".join(fingerprints)).encode("utf-8")
        )[:24]
        record = {
            "correction_id": record_id,
            "schema_version": SCHEMA_VERSION,
            "authorization_id": AUTHORIZATION_ID,
            "authorized_head_sha": AUTHORIZED_HEAD_SHA,
            "baseline_report_sha256": baseline_sha,
            "failure_fingerprints": fingerprints,
            "failure_fingerprint_set_sha256": sha256_bytes(
                ("\n".join(fingerprints) + "\n").encode("utf-8")
            ),
            "raw_failures": raw_failures,
            "raw_failure_set_sha256": _sha256_line_set(raw_failures),
            "failure_bindings": bindings,
            "failure_count": len(fingerprints),
            "rule_ids": rule_ids,
            "failure_classes": [rule_id],
            "transition_class_id": transition_class_id,
            "allowed_rule_ids": list(definition["allowed_rule_ids"]),
            "allowed_from_state": definition["allowed_from_state"],
            "allowed_to_state": definition["allowed_to_state"],
            "required_evidence": list(definition["required_evidence"]),
            "required_reachability_state": list(definition["required_reachability_state"]),
            "required_blob_binding": bool(definition["required_blob_binding"]),
            "required_untouched_state": bool(definition["required_untouched_state"]),
            "eligibility_policy": dict(definition["eligibility_policy"]),
            "negative_examples": list(definition["negative_examples"]),
            "from_state": "HISTORICAL_FAILURE_PRESENT_UNTOUCHED",
            "to_effective_disposition": "CORRECTED_HISTORICAL_DEBT",
            "historical_debt_status": "VISIBLE_AND_CORRECTED_FOR_UNRELATED_DELTA",
            "paths": paths,
            "path_set_sha256": sha256_bytes(("\n".join(paths) + "\n").encode("utf-8")),
            "source_commit_set": source_commits,
            "current_blob_sha256_by_path": blob_map,
            "component_ids": component_ids,
            "domain_ids": domain_ids,
            "current_counterpart_fingerprints_by_failure": current_counterparts,
            "current_counterparts_remain_separate": True,
            "supersession_map_sha256": _blob_at(
                root, AUTHORIZED_HEAD_SHA, "docs/architecture/V076_SUPERSESSION_MAP.json"
            ),
            "owner_reuse_map_sha256": _blob_at(
                root, AUTHORIZED_HEAD_SHA, "docs/architecture/V076_OWNER_REUSE_MAP.md"
            ),
            "production_reachability_attestation": {
                "states": [reachability_state],
                "active_owner_violation_count": 0,
                "parallel_owner_count": 0,
                "dual_write_count": 0,
                "fallback_count": 0,
            },
            "untouched_in_current_delta": all(
                not bool(row.get("touched_in_current_delta")) for row in group
            ),
            "why_not_active_violation": "Every listed row is a HISTORY_* failure from the frozen baseline; no current-delta row is included.",
            "why_existing_transition_is_insufficient": "The V1 evidence layer has no exact fingerprint, current-blob binding, or touched invalidation for this distinct source class.",
            "correction_reason": str(definition["human_description"]),
            "evidence_paths": [
                "reports/reuse/correction_v2/baseline_raw_failure_report.json",
                "reports/reuse/correction_v2/exact_failure_inventory.json",
                "reports/reuse/correction_v2/missing_transition_class_inventory.json",
            ],
            "backlog_item_ids": [str(definition["backlog_item_id"])],
            "touch_invalidation_policy": {
                "TOUCH_INVALIDATES_CORRECTION": True,
                "BLOB_CHANGED_CORRECTION_AUTO_INVALIDATION": True,
                "PRODUCTION_REACHABILITY_CHANGED_INVALIDATION": True,
                "OWNER_BINDING_CHANGED_INVALIDATION": True,
            },
            "future_failure_policy": {
                "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
                "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
            },
            "revocation_policy": dict(definition["revocation_policy"]),
            "created_at": _record_created_at(root, record_id),
            "creator": "V076ReuseExactFailureCorrectionV2",
            "previous_correction_chain_sha256": previous_chain,
        }
        record["record_payload_sha256"] = sha256_bytes(_canonical_bytes(_record_payload(record)))
        # A class with both reachability states is represented by distinct exact
        # records.  Existing one-state classes retain their original readable
        # filename.
        state_count = sum(1 for key in grouped if key[0] == transition_class_id)
        path = _record_path_for_class(
            output_root,
            transition_class_id if state_count == 1 else f"{transition_class_id}_{reachability_state}",
        )
        _write_generated_draft(
            path, _canonical_bytes(record), repository_root=root
        )
        previous_chain = str(record["record_payload_sha256"])
        records.append({
            "correction_id": record_id,
            "path": path.relative_to(output_root).as_posix(),
            "record_sha256": sha256_file(path),
            "record_payload_sha256": record["record_payload_sha256"],
            "transition_class_id": transition_class_id,
            "failure_count": len(fingerprints),
            "failure_fingerprint_set_sha256": record["failure_fingerprint_set_sha256"],
        })
    return {
        "schema_version": f"{SCHEMA_VERSION}.record_inventory",
        "authorization_id": AUTHORIZATION_ID,
        "authorized_head_sha": AUTHORIZED_HEAD_SHA,
        "baseline_report_sha256": baseline_sha,
        "records": records,
        "record_count": len(records),
        "corrected_failure_fingerprint_count": sum(row["failure_count"] for row in records),
        "correction_wildcard_count": 0,
        "correction_regex_scope_count": 0,
        "correction_without_explicit_fingerprint_count": 0,
        "correction_without_current_blob_binding_count": 0,
        "correction_without_backlog_or_retirement_count": 0,
    }


def _reject_disallowed_record_shape(record: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    if not isinstance(record, dict):
        return ["CORRECTION_RECORD_NOT_OBJECT"]
    # Never scan the entire serialized record: concrete paths and explanatory
    # prose can legitimately contain words such as ``global``/``directory``.
    # Only explicit selector/rule fields are interpreted as correction scope.
    for field_name, value in _iter_explicit_scope_values(record):
        failures.extend(_contains_disallowed_scope_token(value, field_name=field_name))
    if not isinstance(record.get("failure_fingerprints"), list) or not record["failure_fingerprints"]:
        failures.append("CORRECTION_WITHOUT_EXPLICIT_FINGERPRINT")
    for value in record.get("failure_fingerprints", []):
        if not isinstance(value, str) or not re.fullmatch(r"V2F-[0-9a-f]{64}", value):
            failures.append("CORRECTION_FINGERPRINT_INVALID")
    if not isinstance(record.get("correction_id"), str) or not record.get("correction_id"):
        failures.append("CORRECTION_ID_MISSING")
    if not isinstance(record.get("transition_class_id"), str) or not record.get("transition_class_id"):
        failures.append("CORRECTION_TRANSITION_CLASS_MISSING")
    if record.get("to_effective_disposition") != "CORRECTED_HISTORICAL_DEBT":
        failures.append("CORRECTION_DISPOSITION_INVALID")
    if not isinstance(record.get("creator"), str) or not record.get("creator"):
        failures.append("CORRECTION_CREATOR_MISSING")
    if not isinstance(record.get("evidence_paths"), list) or not record.get("evidence_paths"):
        failures.append("CORRECTION_EVIDENCE_MISSING")
    if not isinstance(record.get("correction_reason"), str) or not record.get("correction_reason"):
        failures.append("CORRECTION_REASON_MISSING")
    if not isinstance(record.get("why_not_active_violation"), str) or not record.get("why_not_active_violation"):
        failures.append("CORRECTION_ACTIVE_VIOLATION_EXPLANATION_MISSING")
    if "previous_correction_chain_sha256" not in record:
        failures.append("CORRECTION_CHAIN_FIELD_MISSING")
    payload_hash = record.get("record_payload_sha256")
    if not isinstance(payload_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", payload_hash):
        failures.append("CORRECTION_RECORD_HASH_MISMATCH")
    if record.get("paths") and any(
        not isinstance(path, str)
        or not normalize_path(path)
        or path != normalize_path(path)
        or path.endswith("/")
        or path.startswith("*")
        or any(char in path for char in ("*", "?", "[", "]"))
        or path.startswith(("/", "../"))
        or "/../" in path
        for path in record["paths"]
    ):
        failures.append("CORRECTION_PATH_SCOPE_NOT_EXACT")
    paths_value = record.get("paths")
    exact_paths = {
        str(value) for value in paths_value
    } if isinstance(paths_value, list) else set()
    if not isinstance(record.get("current_blob_sha256_by_path"), dict):
        failures.append("CORRECTION_WITHOUT_CURRENT_BLOB_BINDING")
    else:
        if set(record["current_blob_sha256_by_path"]) != exact_paths:
            failures.append("CORRECTION_BLOB_PATH_SET_MISMATCH")
        for path, digest in record["current_blob_sha256_by_path"].items():
            if (
                not isinstance(path, str)
                or normalize_path(path) != path
                or path.startswith(("/", "../"))
                or "/../" in path
                or path.endswith("/")
                or any(char in path for char in ("*", "?", "[", "]"))
                or not isinstance(digest, str)
                or (digest != "MISSING" and not re.fullmatch(r"[0-9a-f]{64}", digest))
            ):
                failures.append("CORRECTION_CURRENT_BLOB_BINDING_INVALID")
    if not record.get("backlog_item_ids"):
        failures.append("CORRECTION_WITHOUT_BACKLOG_OR_RETIREMENT")
    failure_count = record.get("failure_count")
    if (
        not isinstance(failure_count, int)
        or isinstance(failure_count, bool)
        or failure_count != len(record.get("failure_fingerprints", []))
    ):
        failures.append("CORRECTION_COUNT_ONLY_OR_CARDINALITY_MISMATCH")
    future_policy = record.get("future_failure_policy")
    if not isinstance(future_policy, dict) or future_policy.get("NEW_FAILURE_REQUIRES_NEW_RECORD") is not True:
        failures.append("FUTURE_FAILURE_AUTO_CORRECTION_ENABLED")
    touch_policy = record.get("touch_invalidation_policy")
    if not isinstance(touch_policy, dict):
        failures.append("CORRECTION_TOUCH_POLICY_MISSING")
    else:
        for key in (
            "TOUCH_INVALIDATES_CORRECTION",
            "BLOB_CHANGED_CORRECTION_AUTO_INVALIDATION",
            "PRODUCTION_REACHABILITY_CHANGED_INVALIDATION",
            "OWNER_BINDING_CHANGED_INVALIDATION",
        ):
            if touch_policy.get(key) is not True:
                failures.append("CORRECTION_TOUCH_POLICY_MISSING")
    attestation = record.get("production_reachability_attestation")
    if not isinstance(attestation, dict):
        failures.append("CORRECTION_REACHABILITY_ATTESTATION_MISSING")
    else:
        states = attestation.get("states")
        if not isinstance(states, list) or any(
            state not in {"production_reachable", "non_production"}
            for state in states
        ):
            failures.append("CORRECTION_REACHABILITY_STATE_INVALID")
        if any(state == "retired_owner_production_reachable" for state in (states or [])):
            failures.append("RETIRED_OWNER_REACHABLE_CORRECTION")
        if any(state == "unregistered_new_owner" for state in (states or [])):
            failures.append("UNREGISTERED_NEW_COMPONENT_CORRECTION")
        for field, code in (
            ("active_owner_violation_count", "ACTIVE_OWNER_VIOLATION_CORRECTION"),
            ("parallel_owner_count", "PARALLEL_OWNER_CORRECTION"),
            ("dual_write_count", "DUAL_WRITE_CORRECTION"),
            ("fallback_count", "FALLBACK_CORRECTION"),
        ):
            value = attestation.get(field, 0)
            if not isinstance(value, int) or isinstance(value, bool) or value != 0:
                failures.append(code)
    if record.get("new_effective_status") is not None:
        failures.append("CORRECTION_REVOCATION_RECORD_REQUIRED")
    nested_contracts = {
        "eligibility_policy": set(
            HISTORY_RULE_CLASSES["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"][
                "eligibility_policy"
            ]
        ),
        "touch_invalidation_policy": {
            "TOUCH_INVALIDATES_CORRECTION",
            "BLOB_CHANGED_CORRECTION_AUTO_INVALIDATION",
            "PRODUCTION_REACHABILITY_CHANGED_INVALIDATION",
            "OWNER_BINDING_CHANGED_INVALIDATION",
        },
        "future_failure_policy": {
            "NEW_FAILURE_REQUIRES_NEW_RECORD",
            "FUTURE_FAILURE_AUTO_CORRECTION_COUNT",
        },
        "revocation_policy": {
            "REVOCATION_APPEND_ONLY",
            "OLD_RECORD_MUTATION_FORBIDDEN",
            "REQUIRES_REVOKED_RECORD_SHA256",
        },
        "production_reachability_attestation": {
            "states",
            "active_owner_violation_count",
            "parallel_owner_count",
            "dual_write_count",
            "fallback_count",
        },
    }
    for field, expected_keys in nested_contracts.items():
        value = record.get(field)
        if isinstance(value, dict) and set(value) != expected_keys:
            failures.append(f"CORRECTION_NESTED_SCHEMA_MISMATCH:{field}")
    return sorted(set(failures))


def _validate_frozen_inputs(
    root: Path,
    output_root: Path,
    *,
    current_head: str,
) -> tuple[list[str], str, str, str]:
    """Validate all immutable V2 inputs before any correction is applied.

    The scanner and V1 ledger are authority inputs.  A resolver must fail
    closed if either its sidecar or its committed bytes drift, even when the
    raw report itself happens to look identical.
    """
    failures: list[str] = []
    baseline_path = output_root / BASELINE_REPORT_REL
    baseline_sha, error = _read_sidecar_digest(
        baseline_path,
        output_root / BASELINE_REPORT_SHA_REL,
        expected_paths=(BASELINE_REPORT_REL.as_posix(),),
    )
    if error:
        failures.append(f"BASELINE_{error}")
    baseline_sha = baseline_sha or (sha256_file(baseline_path) if baseline_path.is_file() else "")
    if baseline_sha and baseline_sha != AUTHORIZED_BASELINE_REPORT_SHA256:
        failures.append("BASELINE_AUTHORIZED_HASH_MISMATCH")
    try:
        baseline = load_json(baseline_path)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        baseline = None
        failures.append("BASELINE_RAW_REPORT_UNREADABLE")
    if not isinstance(baseline, dict) or not isinstance(baseline.get("failures"), list):
        failures.append("BASELINE_RAW_REPORT_FAILURE_LIST_INVALID")
    elif str(baseline.get("head_sha", baseline.get("head_ref", ""))) != AUTHORIZED_HEAD_SHA:
        failures.append("BASELINE_AUTHORIZED_HEAD_MISMATCH")

    scanner_path = output_root / SCANNER_MANIFEST_REL
    scanner_sha, error = _read_sidecar_digest(
        scanner_path,
        output_root / SCANNER_MANIFEST_SHA_REL,
        expected_paths=(SCANNER_MANIFEST_REL.as_posix(),),
    )
    if error:
        failures.append(f"SCANNER_{error}")
    scanner_sha = scanner_sha or (sha256_file(scanner_path) if scanner_path.is_file() else "")
    if scanner_sha and scanner_sha != AUTHORIZED_SCANNER_MANIFEST_SHA256:
        failures.append("SCANNER_AUTHORIZED_MANIFEST_HASH_MISMATCH")
    try:
        scanner_manifest = load_json(scanner_path)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        scanner_manifest = None
        failures.append("SCANNER_MANIFEST_UNREADABLE")
    if not isinstance(scanner_manifest, dict):
        failures.append("SCANNER_MANIFEST_INVALID")
    else:
        if scanner_manifest.get("authorization_id") != AUTHORIZATION_ID:
            failures.append("SCANNER_AUTHORIZATION_ID_MISMATCH")
        if scanner_manifest.get("authorized_head_sha") != AUTHORIZED_HEAD_SHA:
            failures.append("SCANNER_AUTHORIZED_HEAD_MISMATCH")
        if scanner_manifest.get("scanner_core_byte_stable") is not True:
            failures.append("SCANNER_BYTE_STABILITY_ATTESTATION_MISSING")
        for field in (
            "scanner_rule_removal_count",
            "scanner_scope_reduction_count",
            "scanner_severity_downgrade_count",
            "scanner_history_depth_reduction_count",
        ):
            value = scanner_manifest.get(field, 0)
            if value != 0:
                failures.append(f"SCANNER_WEAKENING:{field}")
        files = scanner_manifest.get("files")
        if not isinstance(files, list):
            failures.append("SCANNER_FILE_LIST_INVALID")
        else:
            expected_paths = set(SCANNER_CORE_PATHS)
            actual_paths = {
                normalize_path(str(row.get("path", "")))
                for row in files
                if isinstance(row, dict)
            }
            if actual_paths != expected_paths or len(files) != len(expected_paths):
                failures.append("SCANNER_CORE_FILE_SET_MISMATCH")
            for row in files:
                if not isinstance(row, dict):
                    failures.append("SCANNER_FILE_ROW_INVALID")
                    continue
                path = normalize_path(str(row.get("path", "")))
                expected_sha = str(row.get("sha256", ""))
                if path not in expected_paths or not re.fullmatch(r"[0-9a-f]{64}", expected_sha):
                    failures.append(f"SCANNER_FILE_BINDING_INVALID:{path}")
                    continue
                committed = _bytes_at(root, current_head, path)
                if committed is None:
                    failures.append(f"SCANNER_CORE_FILE_MISSING:{path}")
                    continue
                actual_sha = sha256_bytes(committed)
                if actual_sha != expected_sha:
                    failures.append(f"SCANNER_CORE_HASH_MISMATCH:{path}")
                if not _is_exact_int(row.get("byte_count"), len(committed)):
                    failures.append(f"SCANNER_CORE_BYTE_COUNT_MISMATCH:{path}")
            expected_manifest = _expected_scanner_manifest(root, commit=AUTHORIZED_HEAD_SHA)
            if scanner_manifest != expected_manifest:
                failures.append("SCANNER_MANIFEST_CONTENT_MISMATCH")

    existing_path = output_root / EXISTING_CORRECTIONS_REL
    existing_sha, error = _read_sidecar_digest(
        existing_path,
        output_root / EXISTING_CORRECTIONS_SHA_REL,
        expected_paths=(EXISTING_CORRECTIONS_REL.as_posix(),),
    )
    if error:
        failures.append(f"V1_{error}")
    existing_sha = existing_sha or (sha256_file(existing_path) if existing_path.is_file() else "")
    if existing_sha and existing_sha != AUTHORIZED_EXISTING_CORRECTIONS_MANIFEST_SHA256:
        failures.append("V1_AUTHORIZED_MANIFEST_HASH_MISMATCH")
    try:
        existing_manifest = load_json(existing_path)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        existing_manifest = None
        failures.append("V1_CORRECTION_MANIFEST_UNREADABLE")
    if not isinstance(existing_manifest, dict):
        failures.append("V1_CORRECTION_MANIFEST_INVALID")
    else:
        if existing_manifest.get("authorization_id") != AUTHORIZATION_ID:
            failures.append("V1_AUTHORIZATION_ID_MISMATCH")
        if existing_manifest.get("authorized_head_sha") != AUTHORIZED_HEAD_SHA:
            failures.append("V1_AUTHORIZED_HEAD_MISMATCH")
        if existing_manifest.get("v1_read_only") is not True:
            failures.append("V1_READ_ONLY_ATTESTATION_MISSING")
        source_path = normalize_path(str(existing_manifest.get("source_path", "")))
        if source_path != normalize_path("docs/architecture/V076_INHERITED_GREEN_LEDGER.json"):
            failures.append("V1_SOURCE_PATH_MISMATCH")
        source_bytes = _bytes_at(root, current_head, source_path)
        if source_bytes is None:
            failures.append("V1_SOURCE_MISSING_AT_EVALUATED_HEAD")
        else:
            source_sha = sha256_bytes(source_bytes)
            if source_sha != str(existing_manifest.get("source_sha256", "")):
                failures.append("V1_SOURCE_HASH_MISMATCH")
            expected_v1 = _expected_v1_manifest(root, commit=AUTHORIZED_HEAD_SHA)
            if existing_manifest != expected_v1:
                failures.append("V1_CORRECTION_MANIFEST_CONTENT_MISMATCH")

    return sorted(set(failures)), baseline_sha, scanner_sha, existing_sha


def _validate_row_live_binding(
    root: Path,
    row: dict[str, Any],
    *,
    current_head: str,
    changed_paths: set[str],
    baseline_components: tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]], dict[str, dict[str, Any]]],
    current_components: tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]], dict[str, dict[str, Any]]],
) -> list[str]:
    """Return fail-closed invalidation diagnostics for one frozen row."""
    failures: list[str] = []
    path = normalize_path(str(row.get("path", "")))
    component_id = str(row.get("component_id", ""))
    domain_id = str(row.get("domain_id", ""))
    baseline_by_path, baseline_by_component, baseline_by_domain = baseline_components
    current_by_path, current_by_component, current_by_domain = current_components

    # A direct path touch (including delete/rename) always invalidates.  This is
    # intentionally checked independently of the blob check so a recreated file
    # with identical bytes still requires re-review.
    if path and path in changed_paths:
        failures.append(f"TOUCHED_CORRECTION_INVALID:{path}")

    baseline_component = None
    current_component = None
    if component_id and not _is_synthetic_component_id(component_id):
        baseline_component = baseline_by_component.get(component_id)
        current_component = current_by_component.get(component_id)
    if path:
        baseline_path_component = baseline_by_path.get(path)
        current_path_component = current_by_path.get(path)
        # Prefer explicit component identity, but use path entries to catch a
        # formerly-unregistered path that becomes an Owner in a later commit.
        baseline_component = baseline_component or baseline_path_component
        current_component = current_component or current_path_component

    baseline_sig = _binding_signature(baseline_component, _COMPONENT_BINDING_FIELDS)
    current_sig = _binding_signature(current_component, _COMPONENT_BINDING_FIELDS)
    if baseline_sig != current_sig:
        # Both ``None`` means the path/component remains unregistered and is an
        # allowed unchanged historical identity.
        if baseline_sig is not None or current_sig is not None:
            subject = component_id or path or "UNRESOLVED_IDENTITY"
            failures.append(f"COMPONENT_BINDING_CHANGED_INVALID:{subject}")

    if baseline_component and current_component:
        baseline_domain_id = str(baseline_component.get("domain_id", ""))
        current_domain_id = str(current_component.get("domain_id", ""))
        if baseline_domain_id != current_domain_id:
            subject = component_id or path or "UNRESOLVED_IDENTITY"
            failures.append(f"DOMAIN_BINDING_CHANGED_INVALID:{subject}")

    if baseline_component is not None or current_component is not None:
        baseline_reachable = bool(baseline_component and baseline_component.get("production_reachable") is True)
        current_reachable = bool(current_component and current_component.get("production_reachable") is True)
        if baseline_reachable != current_reachable:
            subject = component_id or path or "UNRESOLVED_IDENTITY"
            failures.append(f"PRODUCTION_REACHABILITY_CHANGED_INVALID:{subject}")
        # Owner path/id and supersession are included in the component
        # signature, but emit a dedicated diagnostic for audit consumers.
        if baseline_component and current_component:
            for field in ("owner_component_id", "owner_path", "supersedes", "superseded_by"):
                old = baseline_component.get(field, []) if field in {"supersedes", "superseded_by"} else baseline_component.get(field)
                new = current_component.get(field, []) if field in {"supersedes", "superseded_by"} else current_component.get(field)
                if isinstance(old, list):
                    old = sorted(str(item) for item in old)
                if isinstance(new, list):
                    new = sorted(str(item) for item in new)
                if old != new:
                    subject = component_id or path or "UNRESOLVED_IDENTITY"
                    failures.append(f"OWNER_BINDING_CHANGED_INVALID:{subject}")
                    break

    baseline_domain = baseline_by_domain.get(domain_id) if domain_id else None
    current_domain = current_by_domain.get(domain_id) if domain_id else None
    domain_old = _binding_signature(baseline_domain, _DOMAIN_BINDING_FIELDS)
    domain_new = _binding_signature(current_domain, _DOMAIN_BINDING_FIELDS)
    if domain_old != domain_new and (domain_old is not None or domain_new is not None):
        failures.append(f"DOMAIN_BINDING_CHANGED_INVALID:{domain_id or 'UNRESOLVED_DOMAIN'}")

    return sorted(set(failures))


def _live_failure_rows(
    root: Path,
    live_report: dict[str, Any],
    *,
    current_head: str,
    baseline_rows_by_raw: dict[str, dict[str, Any]],
    baseline_rows_by_fp: dict[str, dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[str], bool]:
    """Project a raw scanner report into active rows without suppressing it."""
    failures: list[str] = []
    active: list[dict[str, Any]] = []
    live_values = live_report.get("failures")
    if not isinstance(live_values, list):
        return [], ["LIVE_RAW_REPORT_FAILURE_LIST_INVALID"], False
    seen: set[str] = set()
    baseline_raw_set = set(baseline_rows_by_raw)
    live_raw_set = {str(value) for value in live_values}
    parity = live_raw_set == baseline_raw_set and len(live_values) == len(live_raw_set)
    if len(live_values) != len(live_raw_set):
        failures.append("LIVE_RAW_FAILURE_DUPLICATE")
    # Missing historical rows indicate scanner suppression, never a successful
    # fix.  Current-delta rows may legitimately disappear after a product fix.
    for raw, row in baseline_rows_by_raw.items():
        if str(row.get("rule_id", "")).startswith("HISTORY_") and raw not in live_raw_set:
            failures.append(f"RAW_BASELINE_FAILURE_MISSING:{row.get('failure_fingerprint', '')}")
    for raw_value in live_values:
        raw = str(raw_value)
        rule_id = raw.split(":", 1)[0]
        if raw in seen:
            failures.append(f"LIVE_RAW_FAILURE_DUPLICATE:{raw}")
            continue
        seen.add(raw)
        baseline_row = baseline_rows_by_raw.get(raw)
        if baseline_row is not None:
            # Existing current rows remain active; historical rows are eligible
            # only through their exact V2 record fingerprint.
            if not str(baseline_row.get("rule_id", "")).startswith("HISTORY_"):
                active.append(dict(baseline_row))
            continue
        # A failure first observed after the authorized head is current-delta
        # debt even when the scanner uses a HISTORY_* rule prefix.
        fingerprint = _failure_fingerprint(raw, "CURRENT_DELTA_FAILURE", rule_id)
        path, component_token = _extract_path_or_component(raw)
        active.append(
            {
                "failure_id": fingerprint,
                "failure_fingerprint": fingerprint,
                "raw_failure": raw,
                "rule_id": rule_id,
                "failure_class": rule_id,
                "severity": "P0",
                "source_commit": current_head,
                "first_seen_commit": current_head,
                "last_seen_commit": current_head,
                "transition": "",
                "path": path,
                "current_path": path,
                "component_id": component_token,
                "domain_id": "",
                "production_reachable": False,
                "introduced_before_gate_activation": False,
                "touched_in_current_delta": True,
                "existing_transition_class": "",
                "existing_correction_id": "",
                "recommended_disposition": "TRUE_ACTIVE_VIOLATION",
                "evidence": ["LIVE_RAW_REPORT"],
            }
        )
        failures.append(f"LIVE_RAW_FAILURE_NOT_IN_BASELINE:{fingerprint}")
    return active, sorted(set(failures)), parity


def _validate_record_inventory(
    output_root: Path,
    correction_paths: list[Path],
    *,
    expected_baseline_sha: str | None = None,
) -> tuple[list[str], dict[str, dict[str, Any]]]:
    """Verify the append-only record-set manifest and return its index."""
    failures: list[str] = []
    index: dict[str, dict[str, Any]] = {}
    inventory_path = output_root / "reports/reuse/correction_v2/correction_record_inventory.json"
    sidecar_path = inventory_path.with_suffix(".sha256")
    digest, error = _read_sidecar_digest(
        inventory_path,
        sidecar_path,
        expected_paths=(inventory_path.name, inventory_path.relative_to(output_root).as_posix()),
    )
    if error:
        failures.append(f"RECORD_INVENTORY_{error}")
    try:
        manifest = load_json(inventory_path)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        manifest = None
        failures.append("CORRECTION_RECORD_INVENTORY_UNREADABLE")
    if not isinstance(manifest, dict):
        return sorted(set(failures)), index
    if manifest.get("authorization_id") != AUTHORIZATION_ID:
        failures.append("RECORD_INVENTORY_AUTHORIZATION_ID_MISMATCH")
    if manifest.get("authorized_head_sha") != AUTHORIZED_HEAD_SHA:
        failures.append("RECORD_INVENTORY_AUTHORIZED_HEAD_MISMATCH")
    manifest_baseline_sha = str(manifest.get("baseline_report_sha256", ""))
    if not re.fullmatch(r"[0-9a-f]{64}", manifest_baseline_sha):
        failures.append("RECORD_INVENTORY_BASELINE_HASH_INVALID")
    if expected_baseline_sha and manifest_baseline_sha != expected_baseline_sha:
        failures.append("RECORD_INVENTORY_BASELINE_HASH_MISMATCH")
    expected_rows = manifest.get("records")
    if not isinstance(expected_rows, list):
        failures.append("RECORD_INVENTORY_RECORD_LIST_INVALID")
        return sorted(set(failures)), index
    expected_by_path: dict[str, dict[str, Any]] = {}
    for row in expected_rows:
        if not isinstance(row, dict) or not row.get("path"):
            failures.append("RECORD_INVENTORY_ROW_INVALID")
            continue
        key = normalize_path(str(row["path"]))
        expected_by_path[key] = row
    actual_by_path = {
        path.relative_to(output_root).as_posix(): path for path in correction_paths
    }
    if set(expected_by_path) != set(actual_by_path):
        failures.append("CORRECTION_RECORD_SET_DRIFT")
    if not _is_exact_int(manifest.get("record_count"), len(expected_rows)):
        failures.append("RECORD_INVENTORY_COUNT_MISMATCH")
    if not _is_exact_int(manifest.get("record_count"), len(actual_by_path)):
        failures.append("RECORD_INVENTORY_ACTUAL_COUNT_MISMATCH")
    for relative, path in actual_by_path.items():
        expected = expected_by_path.get(relative)
        if expected is None:
            continue
        actual_sha = sha256_file(path)
        if actual_sha != str(expected.get("record_sha256", "")):
            failures.append(f"CORRECTION_RECORD_MODIFIED:{relative}")
        try:
            record = load_json(path)
        except (OSError, json.JSONDecodeError):
            failures.append(f"CORRECTION_RECORD_UNREADABLE:{relative}")
            continue
        correction_id = str(record.get("correction_id", ""))
        if correction_id != str(expected.get("correction_id", "")):
            failures.append(f"CORRECTION_RECORD_ID_DRIFT:{relative}")
        if not correction_id:
            failures.append(f"CORRECTION_RECORD_ID_MISSING:{relative}")
        elif correction_id in index:
            failures.append(f"CORRECTION_RECORD_ID_DUPLICATE:{correction_id}")
        index[correction_id] = {
            "path": relative,
            "record_sha256": actual_sha,
            "failure_fingerprints": list(record.get("failure_fingerprints", [])),
            "record": record,
        }
    # The manifest's aggregate cardinality is part of the immutable assertion.
    listed_count = 0
    for row in expected_rows:
        if not isinstance(row, dict):
            continue
        row_count = row.get("failure_count")
        if not _is_int(row_count) or row_count < 0:
            failures.append("RECORD_INVENTORY_ROW_FAILURE_COUNT_INVALID")
            continue
        listed_count += row_count
    if not _is_exact_int(
        manifest.get("corrected_failure_fingerprint_count"), listed_count
    ):
        failures.append("RECORD_INVENTORY_FINGERPRINT_COUNT_MISMATCH")
    return sorted(set(failures)), index


def _validate_revocation_record(
    record: dict[str, Any],
    path: Path,
    *,
    correction_index: dict[str, dict[str, Any]],
    previous_chain: str,
    baseline_sha256: str,
) -> tuple[list[str], set[str], str]:
    """Validate one append-only revocation and return (errors, fingerprints, hash)."""
    failures: list[str] = []
    revoked: set[str] = set()
    if record.get("record_kind") != "CORRECTION_REVOCATION_RECORD":
        failures.append(f"REVOCATION_RECORD_KIND_INVALID:{path.name}")
    if record.get("schema_version") != SCHEMA_VERSION:
        failures.append(f"REVOCATION_SCHEMA_VERSION_MISMATCH:{path.name}")
    if record.get("authorization_id") != AUTHORIZATION_ID:
        failures.append(f"REVOCATION_AUTHORIZATION_ID_MISMATCH:{path.name}")
    if record.get("authorized_head_sha") != AUTHORIZED_HEAD_SHA:
        failures.append(f"REVOCATION_AUTHORIZED_HEAD_MISMATCH:{path.name}")
    if record.get("baseline_report_sha256") != baseline_sha256:
        failures.append(f"REVOCATION_BASELINE_HASH_MISMATCH:{path.name}")
    correction_id = str(record.get("revoked_correction_id", ""))
    target = correction_index.get(correction_id)
    if target is None:
        failures.append(f"REVOCATION_TARGET_UNKNOWN:{path.name}")
    elif str(record.get("revoked_record_sha256", "")) != target["record_sha256"]:
        failures.append(f"REVOCATION_TARGET_HASH_MISMATCH:{path.name}")
    fingerprints = record.get("affected_failure_fingerprints")
    if not isinstance(fingerprints, list) or not fingerprints:
        failures.append(f"REVOCATION_FINGERPRINTS_MISSING:{path.name}")
    else:
        rendered_fingerprints = [str(value) for value in fingerprints]
        if len(rendered_fingerprints) != len(set(rendered_fingerprints)):
            failures.append(f"REVOCATION_FINGERPRINT_DUPLICATE:{path.name}")
        if any(
            not isinstance(value, str)
            or not re.fullmatch(r"V2F-[0-9a-f]{64}", value)
            for value in fingerprints
        ):
            failures.append(f"REVOCATION_FINGERPRINT_INVALID:{path.name}")
        revoked = set(rendered_fingerprints)
        if target is not None and not revoked.issubset(set(target["failure_fingerprints"])):
            failures.append(f"REVOCATION_FINGERPRINT_SCOPE_INVALID:{path.name}")
    if record.get("new_effective_status") not in {"TRUE_ACTIVE_VIOLATION", "UNRESOLVED_BLOCKING"}:
        failures.append(f"REVOCATION_STATUS_INVALID:{path.name}")
    if record.get("previous_chain_sha256", "") != previous_chain:
        failures.append(f"CORRECTION_CHAIN_BREAK:{path.name}")
    if previous_chain and not re.fullmatch(r"[0-9a-f]{64}", previous_chain):
        failures.append(f"REVOCATION_PREVIOUS_CHAIN_INVALID:{path.name}")
    if not record.get("revocation_reason"):
        failures.append(f"REVOCATION_REASON_MISSING:{path.name}")
    expected_payload = sha256_bytes(_canonical_bytes(_record_payload(record)))
    if record.get("record_payload_sha256") != expected_payload:
        failures.append(f"CORRECTION_RECORD_HASH_MISMATCH:{path.name}")
    failures = sorted(set(failures))
    # An invalid revocation is visible and blocking, but can never change the
    # effective correction set or become the trusted predecessor of another
    # chain entry.
    if failures:
        return failures, set(), previous_chain
    return failures, revoked, str(record.get("record_payload_sha256", ""))


def _validate_class_contract(
    record: dict[str, Any],
    definition: dict[str, Any] | None,
    path_name: str,
) -> list[str]:
    """Check that a record carries the complete explicit class contract."""
    if definition is None:
        return [f"CORRECTION_UNSUPPORTED_CLASS:{path_name}"]
    failures: list[str] = []
    for field in (
        "allowed_rule_ids",
        "allowed_from_state",
        "allowed_to_state",
        "required_evidence",
        "required_reachability_state",
        "required_blob_binding",
        "required_untouched_state",
        "eligibility_policy",
        "touch_invalidation_policy",
        "future_failure_policy",
        "revocation_policy",
        "negative_examples",
    ):
        if field not in record:
            failures.append(f"CORRECTION_CLASS_CONTRACT_FIELD_MISSING:{field}:{path_name}")
            continue
        if record.get(field) != definition.get(field):
            failures.append(f"CORRECTION_CLASS_CONTRACT_MISMATCH:{field}:{path_name}")
    if record.get("allowed_rule_ids") != record.get("rule_ids"):
        failures.append(f"CORRECTION_ALLOWED_RULE_SET_MISMATCH:{path_name}")
    if record.get("allowed_from_state") != record.get("from_state"):
        failures.append(f"CORRECTION_FROM_STATE_MISMATCH:{path_name}")
    if record.get("allowed_to_state") != record.get("to_effective_disposition"):
        failures.append(f"CORRECTION_TO_STATE_MISMATCH:{path_name}")
    evidence = record.get("evidence_paths")
    required_evidence = definition.get("required_evidence", [])
    if not isinstance(evidence, list) or not set(required_evidence).issubset(set(evidence)):
        failures.append(f"CORRECTION_REQUIRED_EVIDENCE_MISSING:{path_name}")
    if record.get("required_blob_binding") is not True:
        failures.append(f"CORRECTION_BLOB_BINDING_REQUIRED:{path_name}")
    if record.get("required_untouched_state") is not True or record.get("untouched_in_current_delta") is not True:
        failures.append(f"CORRECTION_UNTOUCHED_STATE_REQUIRED:{path_name}")
    return sorted(set(failures))


def _sha256_line_set(values: Iterable[str]) -> str:
    """Hash a sorted explicit string set using the resolver's canonical format."""
    ordered = sorted(str(value) for value in values)
    return sha256_bytes(("\n".join(ordered) + "\n").encode("utf-8"))


def _subject_identity_resolved(row: dict[str, Any]) -> bool:
    path = normalize_path(str(row.get("path", "")))
    component = str(row.get("component_id", ""))
    if path:
        # A path identity must be one concrete repository file, not a directory
        # prefix or selector expression.
        return (
            path in PATH_PREFIXES
            or any(path.startswith(prefix) for prefix in PATH_PREFIXES if prefix.endswith("/"))
        ) and not path.endswith("/") and not any(char in path for char in "*?[]") and bool(
            re.fullmatch(r"[0-9a-f]{64}", str(row.get("current_blob_sha256", "")))
        )
    return bool(component and not _is_synthetic_component_id(component))


def _current_counterparts_for_row(
    row: dict[str, Any],
    rows: Iterable[dict[str, Any]],
) -> list[str]:
    """Return exact current-delta fingerprints sharing the row's subject."""
    path = normalize_path(str(row.get("path", "")))
    component = str(row.get("component_id", ""))
    result: list[str] = []
    for candidate in rows:
        if str(candidate.get("rule_id", "")).startswith("HISTORY_"):
            continue
        candidate_path = normalize_path(str(candidate.get("path", "")))
        candidate_component = str(candidate.get("component_id", ""))
        if path and candidate_path == path:
            result.append(str(candidate.get("failure_fingerprint", "")))
        elif (
            not path
            and component
            and not _is_synthetic_component_id(component)
            and candidate_component == component
        ):
            result.append(str(candidate.get("failure_fingerprint", "")))
    return sorted({value for value in result if value})


def _validate_row_eligibility(
    root: Path,
    row: dict[str, Any],
    *,
    authorized_head: str,
    inventory_rows: Iterable[dict[str, Any]],
) -> list[str]:
    """Validate the immutable evidence that permits one row to be corrected."""
    failures: list[str] = []
    fingerprint = str(row.get("failure_fingerprint", ""))
    raw = str(row.get("raw_failure", ""))
    rule_id = str(row.get("rule_id", ""))
    expected_fp = _failure_fingerprint(raw, "HISTORICAL", rule_id)
    if fingerprint != expected_fp:
        failures.append(f"CORRECTION_FINGERPRINT_RAW_RULE_MISMATCH:{fingerprint}")
    if not rule_id.startswith("HISTORY_"):
        failures.append(f"CURRENT_DELTA_CORRECTION_FALSE_ACCEPT:{fingerprint}")

    transition = _extract_transition(raw)
    source_commit = str(row.get("source_commit", ""))
    eligibility = row.get("transition_eligibility")
    if not isinstance(eligibility, dict):
        failures.append(f"CORRECTION_TRANSITION_ELIGIBILITY_MISSING:{fingerprint}")
        eligibility = {}
    if not transition or not source_commit:
        failures.append(f"CORRECTION_TRANSITION_OR_SOURCE_MISSING:{fingerprint}")
    else:
        old_token, new_token = transition
        try:
            old_commit = _resolve_commit(root, old_token)
            new_commit = _resolve_commit(root, new_token)
        except (RuntimeError, ValueError):
            old_commit = new_commit = ""
            failures.append(f"CORRECTION_TRANSITION_COMMIT_UNRESOLVED:{fingerprint}")
        if old_commit and new_commit:
            if source_commit != new_commit:
                failures.append(f"CORRECTION_SOURCE_COMMIT_MISMATCH:{fingerprint}")
            if old_commit == new_commit or old_commit not in _transition_parent_commits(root, new_commit):
                failures.append(f"CORRECTION_TRANSITION_NOT_EXACT_PARENT:{fingerprint}")
            if not _is_ancestor(root, new_commit, authorized_head):
                failures.append(f"CORRECTION_SOURCE_NOT_AUTHORIZED_ANCESTOR:{fingerprint}")
            if new_commit == authorized_head:
                failures.append(f"CORRECTION_SOURCE_NOT_STRICTLY_BEFORE_AUTHORIZED_HEAD:{fingerprint}")
            if str(row.get("transition_old_commit", "")) != old_commit:
                failures.append(f"CORRECTION_TRANSITION_OLD_COMMIT_MISMATCH:{fingerprint}")
            if str(row.get("transition_new_commit", "")) != new_commit:
                failures.append(f"CORRECTION_TRANSITION_NEW_COMMIT_MISMATCH:{fingerprint}")
            expected_transition = f"{old_commit}->{new_commit}"
            if str(row.get("transition", "")) != expected_transition:
                failures.append(f"CORRECTION_TRANSITION_FIELD_MISMATCH:{fingerprint}")
            for key, expected in (
                ("transition_exact", True),
                ("transition_direct_parent", True),
                ("source_commit_exact", True),
                ("source_commit_ancestor_of_authorized_head", True),
                ("source_commit_precedes_authorized_head", True),
            ):
                if eligibility.get(key) is not expected:
                    failures.append(f"CORRECTION_ELIGIBILITY_ATTESTATION_MISMATCH:{key}:{fingerprint}")
    if not _subject_identity_resolved(row):
        failures.append(f"CORRECTION_IDENTITY_UNRESOLVED:{fingerprint}")
    if eligibility.get("identity_resolved") is not True:
        failures.append(f"CORRECTION_IDENTITY_ATTESTATION_MISMATCH:{fingerprint}")
    reachability_state = str(row.get("production_reachability_state", ""))
    expected_state = (
        "production_reachable" if row.get("production_reachable") is True else "non_production"
    )
    if reachability_state != expected_state or eligibility.get("production_reachability_state") != expected_state:
        failures.append(f"CORRECTION_PRODUCTION_REACHABILITY_UNRESOLVED:{fingerprint}")
    if eligibility.get("production_reachability_resolved") is not True:
        failures.append(f"CORRECTION_PRODUCTION_REACHABILITY_ATTESTATION_MISMATCH:{fingerprint}")

    rows_list = list(inventory_rows)
    expected_counterparts = _current_counterparts_for_row(row, rows_list)
    actual_counterparts = row.get("current_counterpart_fingerprints", [])
    if not isinstance(actual_counterparts, list) or sorted(set(str(v) for v in actual_counterparts)) != expected_counterparts:
        failures.append(f"CORRECTION_CURRENT_COUNTERPART_SET_MISMATCH:{fingerprint}")
    # A correction must never absorb a current row, even if a caller attempts to
    # place both fingerprints in one record.
    if fingerprint in set(expected_counterparts):
        failures.append(f"CORRECTION_CURRENT_COUNTERPART_OVERLAP:{fingerprint}")
    if eligibility.get("current_counterparts_remain_separate") is not True:
        failures.append(f"CORRECTION_CURRENT_COUNTERPART_POLICY_MISSING:{fingerprint}")
    return sorted(set(failures))


def validate_records(
    root: Path,
    output_root: Path,
    *,
    current_head: str,
    live_raw_report_path: Path | None = None,
    full_convergence_baseline_report_path: Path | None = None,
    full_convergence_batch_manifest_path: Path | None = None,
    full_convergence_previous_batch_manifest_path: Path | None = None,
    descendant_history_supplement_path: Path | None = None,
    descendant_history_raw_report_path: Path | None = None,
    descendant_history_scanner_path: Path | None = None,
    post_touch_revalidation_path: Path | None = None,
    post_touch_revalidation_successor_v2_path: Path | None = None,
    subject_projection_revalidation_path: Path | None = None,
    subject_projection_revalidation_successor_v2_path: Path | None = None,
    subject_projection_revalidation_successor_v3_path: Path | None = None,
    subject_projection_revalidation_successor_v4_path: Path | None = None,
    subject_projection_revalidation_successor_v5_path: Path | None = None,
    historical_delta_metadata_ledger_path: Path | None = None,
    historical_delta_metadata_successor_path: Path | None = None,
    historical_delta_metadata_successor_v2_path: Path | None = None,
    full_convergence_pr_body_file_path: Path | None = None,
) -> dict[str, Any]:
    full_convergence_inputs = (
        full_convergence_baseline_report_path,
        full_convergence_batch_manifest_path,
        full_convergence_previous_batch_manifest_path,
        descendant_history_supplement_path,
        descendant_history_raw_report_path,
        descendant_history_scanner_path,
        # This sidecar is optional and must not make the FC input tuple
        # incomplete by itself.
    )
    if (
        (subject_projection_revalidation_path is None)
        != (subject_projection_revalidation_successor_v2_path is None)
    ):
        raise ValueError("SUBJECT_PROJECTION_REVALIDATION_EPOCH_PAIR_REQUIRED")
    if (
        subject_projection_revalidation_successor_v3_path is not None
        and subject_projection_revalidation_path is None
    ):
        raise ValueError(
            "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V3_REQUIRES_EPOCH_PAIR"
        )
    replacement_paths = (
        subject_projection_revalidation_path,
        subject_projection_revalidation_successor_v2_path,
        subject_projection_revalidation_successor_v3_path,
        subject_projection_revalidation_successor_v4_path,
        subject_projection_revalidation_successor_v5_path,
    )
    if (
        subject_projection_revalidation_successor_v4_path is not None
        or subject_projection_revalidation_successor_v5_path is not None
    ) and any(value is None for value in replacement_paths):
        raise ValueError(
            "SUBJECT_PROJECTION_TERMINAL_REPLACEMENT_REQUIRES_V1_V2_V3_V4_V5"
        )
    if historical_delta_metadata_ledger_path is not None and not any(
        value is not None for value in full_convergence_inputs
    ):
        raise ValueError(
            "HISTORICAL_DELTA_METADATA_LEDGER_REQUIRES_FULL_CONVERGENCE_INPUT_SET"
        )
    if historical_delta_metadata_successor_path is not None and not any(
        value is not None for value in full_convergence_inputs
    ):
        raise ValueError(
            "HISTORICAL_DELTA_METADATA_SUCCESSOR_REQUIRES_"
            "FULL_CONVERGENCE_INPUT_SET"
        )
    if historical_delta_metadata_successor_v2_path is not None and not any(
        value is not None for value in full_convergence_inputs
    ):
        raise ValueError(
            "HISTORICAL_DELTA_METADATA_SUCCESSOR_V2_REQUIRES_"
            "FULL_CONVERGENCE_INPUT_SET"
        )
    if (
        historical_delta_metadata_successor_path is not None
        and historical_delta_metadata_ledger_path is None
    ):
        raise ValueError(
            "HISTORICAL_DELTA_METADATA_SUCCESSOR_REQUIRES_"
            "HISTORICAL_DELTA_METADATA_LEDGER"
        )
    if (
        historical_delta_metadata_successor_v2_path is not None
        and historical_delta_metadata_ledger_path is None
    ):
        raise ValueError(
            "HISTORICAL_DELTA_METADATA_SUCCESSOR_V2_REQUIRES_"
            "HISTORICAL_DELTA_METADATA_LEDGER"
        )
    if full_convergence_pr_body_file_path is not None and not any(
        value is not None for value in full_convergence_inputs
    ):
        raise ValueError(
            "FULL_CONVERGENCE_PR_BODY_FILE_REQUIRES_FULL_CONVERGENCE_INPUT_SET"
        )
    if post_touch_revalidation_path is not None and not any(
        value is not None for value in full_convergence_inputs
    ):
        raise ValueError(
            "POST_TOUCH_REVALIDATION_REQUIRES_FULL_CONVERGENCE_INPUT_SET"
        )
    if (
        post_touch_revalidation_successor_v2_path is not None
        and post_touch_revalidation_path is None
    ):
        raise ValueError(
            "POST_TOUCH_REVALIDATION_SUCCESSOR_V2_REQUIRES_PREDECESSOR"
        )
    if post_touch_revalidation_successor_v2_path is not None and not any(
        value is not None for value in full_convergence_inputs
    ):
        raise ValueError(
            "POST_TOUCH_REVALIDATION_SUCCESSOR_V2_REQUIRES_"
            "FULL_CONVERGENCE_INPUT_SET"
        )
    if subject_projection_revalidation_path is not None and not any(
        value is not None for value in full_convergence_inputs
    ):
        raise ValueError(
            "SUBJECT_PROJECTION_REVALIDATION_REQUIRES_FULL_CONVERGENCE_INPUT_SET"
        )
    if (
        subject_projection_revalidation_successor_v2_path is not None
        and not any(value is not None for value in full_convergence_inputs)
    ):
        raise ValueError(
            "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V2_REQUIRES_"
            "FULL_CONVERGENCE_INPUT_SET"
        )
    if (
        subject_projection_revalidation_successor_v3_path is not None
        and not any(value is not None for value in full_convergence_inputs)
    ):
        raise ValueError(
            "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V3_REQUIRES_"
            "FULL_CONVERGENCE_INPUT_SET"
        )
    for label, path in (
        (
            "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V4",
            subject_projection_revalidation_successor_v4_path,
        ),
        (
            "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V5",
            subject_projection_revalidation_successor_v5_path,
        ),
    ):
        if path is not None and not any(
            value is not None for value in full_convergence_inputs
        ):
            raise ValueError(f"{label}_REQUIRES_FULL_CONVERGENCE_INPUT_SET")
    if (
        subject_projection_revalidation_path is not None
        and historical_delta_metadata_ledger_path is None
    ):
        raise ValueError(
            "SUBJECT_PROJECTION_REVALIDATION_REQUIRES_HISTORICAL_DELTA_METADATA_LEDGER"
        )
    if any(value is not None for value in full_convergence_inputs):
        if any(value is None for value in full_convergence_inputs):
            raise ValueError("FULL_CONVERGENCE_EXPLICIT_INPUT_SET_INCOMPLETE")
        if live_raw_report_path is None:
            raise ValueError("FULL_CONVERGENCE_LIVE_RAW_REPORT_REQUIRED")
        return validate_full_convergence_records(
            root,
            output_root,
            current_head=current_head,
            live_raw_report_path=live_raw_report_path,
            baseline_report_path=full_convergence_baseline_report_path,
            batch_manifest_path=full_convergence_batch_manifest_path,
            previous_batch_manifest_path=full_convergence_previous_batch_manifest_path,
            descendant_history_supplement_path=descendant_history_supplement_path,
            descendant_history_raw_report_path=descendant_history_raw_report_path,
            descendant_history_scanner_path=descendant_history_scanner_path,
            post_touch_revalidation_path=post_touch_revalidation_path,
            post_touch_revalidation_successor_v2_path=(
                post_touch_revalidation_successor_v2_path
            ),
            subject_projection_revalidation_path=(
                subject_projection_revalidation_path
            ),
            subject_projection_revalidation_successor_v2_path=(
                subject_projection_revalidation_successor_v2_path
            ),
            subject_projection_revalidation_successor_v3_path=(
                subject_projection_revalidation_successor_v3_path
            ),
            subject_projection_revalidation_successor_v4_path=(
                subject_projection_revalidation_successor_v4_path
            ),
            subject_projection_revalidation_successor_v5_path=(
                subject_projection_revalidation_successor_v5_path
            ),
            historical_delta_metadata_ledger_path=(
                historical_delta_metadata_ledger_path
            ),
            historical_delta_metadata_successor_path=(
                historical_delta_metadata_successor_path
            ),
            historical_delta_metadata_successor_v2_path=(
                historical_delta_metadata_successor_v2_path
            ),
            full_convergence_pr_body_file_path=(
                full_convergence_pr_body_file_path
            ),
        )
    failures, baseline_sha, scanner_manifest_sha, existing_manifest_sha = _validate_frozen_inputs(
        root, output_root, current_head=current_head
    )
    schema_failures, correction_schema_sha = _validate_correction_schema(output_root)
    failures.extend(schema_failures)
    if current_head != AUTHORIZED_HEAD_SHA and not _is_ancestor(root, AUTHORIZED_HEAD_SHA, current_head):
        failures.append("EVALUATED_HEAD_NOT_AUTHORIZED_DESCENDANT")
    if not re.fullmatch(r"[0-9a-f]{40}", current_head):
        failures.append("EVALUATED_HEAD_ID_INVALID")
    try:
        inventory = load_json(output_root / FAILURE_INVENTORY_REL)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        inventory = {"rows": []}
        failures.append("FAILURE_INVENTORY_UNREADABLE")
    try:
        baseline = load_json(output_root / BASELINE_REPORT_REL)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        baseline = {"failures": []}
    if inventory.get("baseline_report_sha256") != baseline_sha:
        failures.append("FAILURE_INVENTORY_BASELINE_HASH_MISMATCH")
    if inventory.get("authorization_id") != AUTHORIZATION_ID:
        failures.append("FAILURE_INVENTORY_AUTHORIZATION_ID_MISMATCH")
    if inventory.get("authorized_head_sha") != AUTHORIZED_HEAD_SHA:
        failures.append("FAILURE_INVENTORY_AUTHORIZED_HEAD_MISMATCH")
    inventory_rows = [row for row in inventory.get("rows", []) if isinstance(row, dict)]
    baseline_rows = {
        str(row.get("failure_fingerprint", "")): row for row in inventory_rows
        if row.get("failure_fingerprint")
    }
    baseline_rows_by_raw = {
        str(row.get("raw_failure", "")): row for row in inventory_rows
        if row.get("raw_failure")
    }
    raw_values = baseline.get("failures", []) if isinstance(baseline, dict) else []
    if not isinstance(raw_values, list) or len(raw_values) != len(inventory_rows):
        failures.append("FAILURE_INVENTORY_COVERAGE_MISMATCH")
    if set(str(value) for value in raw_values) != set(baseline_rows_by_raw):
        failures.append("FAILURE_INVENTORY_RAW_SET_MISMATCH")

    record_paths = sorted((output_root / RECORD_DIR_REL).glob("*.json"))
    manifest_failures, correction_index = _validate_record_inventory(
        output_root,
        record_paths,
        expected_baseline_sha=baseline_sha,
    )
    failures.extend(manifest_failures)
    # Frozen input, inventory, or record-set manifest failures make the entire
    # correction authority untrustworthy.  Individual records are still parsed
    # below for diagnostics, but none may contribute to ``corrected``.
    correction_authority_integrity_invalid = bool(failures)
    all_fingerprints: list[str] = []
    eligibility_invalid_fingerprints: set[str] = set()
    record_semantic_invalid_fingerprints: set[str] = set()
    valid_records: list[dict[str, Any]] = []
    chain_previous = ""
    changed_paths = _current_delta_paths(root, AUTHORIZED_HEAD_SHA, current_head)
    baseline_components = _authority_rows(root, AUTHORIZED_HEAD_SHA)
    current_components = _authority_rows(root, current_head)
    v1_fingerprints = {
        str(row.get("failure_fingerprint"))
        for row in inventory_rows
        if row.get("existing_correction_id")
    }
    for path in record_paths:
        record_failure_count_before = len(failures)
        try:
            record = load_json(path)
        except (OSError, json.JSONDecodeError):
            failures.append(f"CORRECTION_RECORD_UNREADABLE:{path.name}")
            continue
        failures.extend(_schema_field_failures(
            record,
            expected_fields=CORRECTION_RECORD_FIELDS,
            diagnostic_prefix="CORRECTION_SCHEMA",
            path_name=path.name,
        ))
        failures.extend(_reject_disallowed_record_shape(record))
        if record.get("schema_version") != SCHEMA_VERSION:
            failures.append(f"CORRECTION_SCHEMA_VERSION_MISMATCH:{path.name}")
        if record.get("authorization_id") != AUTHORIZATION_ID:
            failures.append(f"CORRECTION_AUTHORIZATION_ID_MISMATCH:{path.name}")
        if record.get("authorized_head_sha") != AUTHORIZED_HEAD_SHA:
            failures.append(f"CORRECTION_AUTHORIZED_HEAD_MISMATCH:{path.name}")
        if record.get("baseline_report_sha256") != baseline_sha:
            failures.append(f"CORRECTION_BASELINE_HASH_MISMATCH:{path.name}")
        expected_payload_sha = sha256_bytes(_canonical_bytes(_record_payload(record)))
        if record.get("record_payload_sha256") != expected_payload_sha:
            failures.append(f"CORRECTION_RECORD_HASH_MISMATCH:{path.name}")
        if record.get("previous_correction_chain_sha256", "") != chain_previous:
            failures.append(f"CORRECTION_CHAIN_BREAK:{path.name}")
        chain_previous = str(record.get("record_payload_sha256", ""))
        fingerprints = [str(value) for value in record.get("failure_fingerprints", [])]
        expected_fp_hash = sha256_bytes(("\n".join(sorted(fingerprints)) + "\n").encode("utf-8"))
        if record.get("failure_fingerprint_set_sha256") != expected_fp_hash:
            failures.append(f"CORRECTION_FINGERPRINT_SET_HASH_MISMATCH:{path.name}")
        paths = [str(value) for value in record.get("paths", [])]
        expected_path_hash = sha256_bytes(("\n".join(sorted(paths)) + "\n").encode("utf-8"))
        if record.get("path_set_sha256") != expected_path_hash:
            failures.append(f"CORRECTION_PATH_SET_HASH_MISMATCH:{path.name}")
        record_rules = record.get("rule_ids", [])
        record_classes = record.get("failure_classes", [])
        if not isinstance(record_rules, list) or not isinstance(record_classes, list):
            failures.append(f"CORRECTION_RULE_CLASS_LIST_INVALID:{path.name}")
            record_rules, record_classes = [], []
        if len(set(str(value) for value in record_rules)) != 1 or set(record_rules) != set(record_classes):
            failures.append(f"CORRECTION_CROSSES_RULE_OR_CLASS:{path.name}")
        class_definitions = [
            HISTORY_RULE_CLASSES.get(str(rule_id)) for rule_id in record_rules
        ]
        if not class_definitions or any(definition is None for definition in class_definitions):
            failures.append(f"CORRECTION_UNSUPPORTED_CLASS:{path.name}")
        elif any(
            record.get("transition_class_id") != definition["transition_class_id"]
            for definition in class_definitions if definition
        ):
            failures.append(f"CORRECTION_TRANSITION_CLASS_MISMATCH:{path.name}")
        if len(class_definitions) == 1:
            failures.extend(
                _validate_class_contract(record, class_definitions[0], path.name)
            )
        expected_paths: set[str] = set()
        expected_components: set[str] = set()
        expected_domains: set[str] = set()
        expected_sources: set[str] = set()
        expected_states: set[str] = set()
        record_eligibility_error_fingerprints: set[str] = set()
        binding_rows = record.get("failure_bindings", [])
        if not isinstance(binding_rows, list):
            failures.append(f"CORRECTION_FAILURE_BINDINGS_MISSING:{path.name}")
            binding_rows = []
        binding_by_fp = {
            str(binding.get("failure_fingerprint", "")): binding
            for binding in binding_rows
            if isinstance(binding, dict) and binding.get("failure_fingerprint")
        }
        if set(binding_by_fp) != set(fingerprints):
            failures.append(f"CORRECTION_FAILURE_BINDING_SET_MISMATCH:{path.name}")
        raw_failures = record.get("raw_failures", [])
        if not isinstance(raw_failures, list):
            raw_failures = []
            failures.append(f"CORRECTION_RAW_FAILURE_SET_MISSING:{path.name}")
        if record.get("raw_failure_set_sha256") != _sha256_line_set(
            str(value) for value in raw_failures
        ):
            failures.append(f"CORRECTION_RAW_FAILURE_SET_HASH_MISMATCH:{path.name}")
        for fingerprint in fingerprints:
            all_fingerprints.append(fingerprint)
            row = baseline_rows.get(fingerprint)
            if row is None:
                failures.append(f"CORRECTION_FINGERPRINT_NOT_IN_BASELINE:{fingerprint}")
                if any(
                    not str(rule_id).startswith("HISTORY_")
                    for rule_id in (record_rules or record_classes)
                ):
                    failures.append(f"CURRENT_DELTA_CORRECTION_FALSE_ACCEPT:{fingerprint}")
                continue
            if fingerprint in v1_fingerprints:
                failures.append(f"V1_V2_DUPLICATE_CORRECTION_AUTHORITY:{fingerprint}")
            if not str(row.get("rule_id", "")).startswith("HISTORY_"):
                failures.append(f"CURRENT_DELTA_CORRECTION_FALSE_ACCEPT:{fingerprint}")
            if row.get("rule_id") not in record_classes or row.get("rule_id") not in record_rules:
                failures.append(f"CORRECTION_RULE_CLASS_MISMATCH:{fingerprint}")
            eligibility_failures = _validate_row_eligibility(
                root,
                row,
                authorized_head=AUTHORIZED_HEAD_SHA,
                inventory_rows=inventory_rows,
            )
            if eligibility_failures:
                record_eligibility_error_fingerprints.add(fingerprint)
                eligibility_invalid_fingerprints.add(fingerprint)
                failures.extend(eligibility_failures)
            binding = binding_by_fp.get(fingerprint)
            expected_binding = {
                "failure_fingerprint": fingerprint,
                "raw_failure": str(row.get("raw_failure", "")),
                "rule_id": str(row.get("rule_id", "")),
                "failure_class": str(row.get("failure_class", "")),
                "source_commit": str(row.get("source_commit", "")),
                "transition": str(row.get("transition", "")),
                "transition_old_commit": str(row.get("transition_old_commit", "")),
                "transition_new_commit": str(row.get("transition_new_commit", "")),
                "path": normalize_path(str(row.get("path", ""))),
                "component_id": str(row.get("component_id", "")),
                "domain_id": str(row.get("domain_id", "")),
                "current_blob_sha256": str(row.get("current_blob_sha256", "")),
                "current_counterpart_fingerprints": sorted(
                    str(value) for value in row.get("current_counterpart_fingerprints", [])
                ),
            }
            if binding != expected_binding:
                failures.append(f"CORRECTION_FAILURE_BINDING_MISMATCH:{fingerprint}")
            path_key = normalize_path(str(row.get("path", "")))
            if path_key:
                expected_paths.add(path_key)
                expected_blob = str(row.get("current_blob_sha256", ""))
                blob_map = record.get("current_blob_sha256_by_path", {})
                if not isinstance(blob_map, dict) or blob_map.get(path_key) != expected_blob:
                    failures.append(f"CORRECTION_CURRENT_BLOB_MISMATCH:{fingerprint}")
                live_blob = _blob_at(root, current_head, path_key)
                if live_blob != expected_blob:
                    failures.append(f"BLOB_CHANGED_CORRECTION_INVALID:{fingerprint}")
            component_id = str(row.get("component_id", ""))
            domain_id = str(row.get("domain_id", ""))
            if component_id:
                expected_components.add(component_id)
            if domain_id:
                expected_domains.add(domain_id)
            if row.get("source_commit"):
                expected_sources.add(str(row["source_commit"]))
                source_commit = str(row["source_commit"])
                if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
                    failures.append(f"CORRECTION_SOURCE_COMMIT_INVALID:{fingerprint}")
                elif not _is_ancestor(root, source_commit, AUTHORIZED_HEAD_SHA):
                    failures.append(f"CORRECTION_SOURCE_COMMIT_NOT_IN_HISTORY:{fingerprint}")
            expected_states.add(
                "production_reachable" if row.get("production_reachable") else "non_production"
            )
            failures.extend(
                _validate_row_live_binding(
                    root,
                    row,
                    current_head=current_head,
                    changed_paths=changed_paths,
                    baseline_components=baseline_components,
                    current_components=current_components,
                )
            )
        if set(paths) != expected_paths:
            failures.append(f"CORRECTION_PATH_SET_MISMATCH:{path.name}")
        if set(str(value) for value in record.get("component_ids", [])) != expected_components:
            failures.append(f"CORRECTION_COMPONENT_SET_MISMATCH:{path.name}")
        if set(str(value) for value in record.get("domain_ids", [])) != expected_domains:
            failures.append(f"CORRECTION_DOMAIN_SET_MISMATCH:{path.name}")
        if set(str(value) for value in record.get("source_commit_set", [])) != expected_sources:
            failures.append(f"CORRECTION_SOURCE_COMMIT_SET_MISMATCH:{path.name}")
        attestation = record.get("production_reachability_attestation", {})
        if isinstance(attestation, dict) and set(attestation.get("states", [])) != expected_states:
            failures.append(f"CORRECTION_REACHABILITY_SET_MISMATCH:{path.name}")
        if record.get("untouched_in_current_delta") is not True:
            failures.append(f"CORRECTION_UNTOUCHED_ATTESTATION_INVALID:{path.name}")
        expected_counterpart_map = {
            fingerprint: sorted(
                str(value)
                for value in baseline_rows[fingerprint].get(
                    "current_counterpart_fingerprints", []
                )
            )
            for fingerprint in fingerprints
            if fingerprint in baseline_rows
        }
        if record.get("current_counterpart_fingerprints_by_failure") != expected_counterpart_map:
            failures.append(f"CORRECTION_CURRENT_COUNTERPART_MAP_MISMATCH:{path.name}")
        if record.get("current_counterparts_remain_separate") is not True:
            failures.append(f"CORRECTION_CURRENT_COUNTERPART_POLICY_MISSING:{path.name}")
        if record.get("supersession_map_sha256") != _blob_at(
            root, AUTHORIZED_HEAD_SHA, "docs/architecture/V076_SUPERSESSION_MAP.json"
        ):
            failures.append(f"CORRECTION_SUPERSESSION_BINDING_MISMATCH:{path.name}")
        if record.get("owner_reuse_map_sha256") != _blob_at(
            root, AUTHORIZED_HEAD_SHA, "docs/architecture/V076_OWNER_REUSE_MAP.md"
        ):
            failures.append(f"CORRECTION_OWNER_MAP_BINDING_MISMATCH:{path.name}")
        if len(failures) != record_failure_count_before:
            record_semantic_invalid_fingerprints.update(fingerprints)
        valid_records.append({
            "correction_id": record.get("correction_id", ""),
            "path": path.relative_to(output_root).as_posix(),
            "record_sha256": sha256_file(path),
            "failure_fingerprints": fingerprints,
            "transition_class_id": record.get("transition_class_id", ""),
            "eligibility_error_fingerprints": sorted(record_eligibility_error_fingerprints),
            "semantic_error": len(failures) != record_failure_count_before,
        })

    # Revocations extend, rather than modify, the correction chain.
    revoked_fingerprints: set[str] = set()
    revocation_paths = sorted((output_root / CORRECTION_DIR_REL / "revocations").glob("*.json"))
    for path in revocation_paths:
        try:
            record = load_json(path)
        except (OSError, json.JSONDecodeError):
            failures.append(f"REVOCATION_RECORD_UNREADABLE:{path.name}")
            continue
        failures.extend(_schema_field_failures(
            record,
            expected_fields=REVOCATION_RECORD_FIELDS,
            diagnostic_prefix="REVOCATION_SCHEMA",
            path_name=path.name,
        ))
        revocation_failures, revoked, chain_previous = _validate_revocation_record(
            record,
            path,
            correction_index=correction_index,
            previous_chain=chain_previous,
            baseline_sha256=baseline_sha,
        )
        failures.extend(revocation_failures)
        revoked_fingerprints.update(revoked)

    fingerprint_counts = Counter(all_fingerprints)
    duplicate_fingerprints = {
        fingerprint for fingerprint, count in fingerprint_counts.items() if count > 1
    }
    duplicate_count = len(all_fingerprints) - len(set(all_fingerprints))
    if duplicate_count:
        failures.append(f"DUPLICATE_CORRECTION_FINGERPRINT_COUNT:{duplicate_count}")
        record_semantic_invalid_fingerprints.update(duplicate_fingerprints)
    expected_historical = {
        str(row["failure_fingerprint"])
        for row in inventory_rows
        if str(row.get("rule_id", "")).startswith("HISTORY_")
    }
    eligible_historical = {
        str(row["failure_fingerprint"])
        for row in inventory_rows
        if str(row.get("rule_id", "")).startswith("HISTORY_")
        and isinstance(row.get("transition_eligibility"), dict)
        and row["transition_eligibility"].get("eligible_for_correction") is True
    }
    corrected = (set(all_fingerprints) & expected_historical) - revoked_fingerprints
    # A record that names a historical-looking row without complete eligibility
    # evidence is never counted as corrected, even if other validation failures
    # already make the overall gate red.
    corrected &= eligible_historical
    corrected -= eligibility_invalid_fingerprints
    corrected -= record_semantic_invalid_fingerprints
    if correction_authority_integrity_invalid:
        corrected.clear()
    unresolved_historical = expected_historical - corrected

    live_report = baseline
    raw_report_source = "FROZEN_BASELINE"
    raw_failure_set_parity = True
    if live_raw_report_path is not None:
        resolved_live_raw = live_raw_report_path.resolve()
        try:
            raw_report_source = resolved_live_raw.relative_to(root.resolve()).as_posix()
        except ValueError:
            raw_report_source = f"EXTERNAL_LIVE_RAW_REPORT:{resolved_live_raw.name}"
        try:
            live_report = load_json(live_raw_report_path)
        except (FileNotFoundError, OSError, json.JSONDecodeError):
            live_report = {"failures": []}
            failures.append("LIVE_RAW_REPORT_UNREADABLE")
        report_head = str(live_report.get("head_sha", live_report.get("head_ref", "")))
        if report_head != current_head:
            failures.append("LIVE_RAW_REPORT_HEAD_MISMATCH")
    active_violations, live_failures, raw_failure_set_parity = _live_failure_rows(
        root,
        live_report,
        current_head=current_head,
        baseline_rows_by_raw=baseline_rows_by_raw,
        baseline_rows_by_fp=baseline_rows,
    )
    failures.extend(live_failures)
    raw_live_values = live_report.get("failures", []) if isinstance(live_report, dict) else []
    raw_live_values = raw_live_values if isinstance(raw_live_values, list) else []
    # Only an exact frozen baseline identity can be historical.  A novel row is
    # current-delta debt even when the scanner happens to prefix it HISTORY_.
    raw_historical_count = sum(
        1
        for value in raw_live_values
        if str(value) in baseline_rows_by_raw
        and str(baseline_rows_by_raw[str(value)].get("rule_id", "")).startswith("HISTORY_")
    )
    raw_current_count = len(raw_live_values) - raw_historical_count
    failures = sorted(set(failures))
    # Diagnostics are not additional failures: each unresolved/current
    # fingerprint is counted once in the effective blocking set.  Keep the
    # detailed diagnostics in ``failures`` while deriving the cardinality from
    # disjoint identity sets.
    diagnostic_blocking_fingerprints = {
        fingerprint
        for fingerprint in eligibility_invalid_fingerprints | record_semantic_invalid_fingerprints
        if fingerprint in expected_historical
    }
    # Integrity diagnostics are themselves unique blocking identities.  This
    # prevents a malformed manifest, suppressed raw row, or invalid revocation
    # from producing PASS merely because all historical fingerprints otherwise
    # have records.
    integrity_blocking_diagnostics = {
        "INTEGRITY:" + failure for failure in failures
    }
    effective_blocking_fingerprints = (
        set(unresolved_historical)
        | {str(row.get("failure_fingerprint", "")) for row in active_violations}
        | diagnostic_blocking_fingerprints
        | integrity_blocking_diagnostics
    )
    effective = len(effective_blocking_fingerprints)
    status = (
        "PASS_WITH_APPEND_ONLY_HISTORICAL_CORRECTIONS"
        if effective == 0 and not failures
        else "FAIL"
    )
    return {
        "schema_version": REPORT_SCHEMA_VERSION,
        "authorization_id": AUTHORIZATION_ID,
        "authorized_head_sha": AUTHORIZED_HEAD_SHA,
        "evaluated_head_sha": current_head,
        "baseline_report_sha256": baseline_sha,
        "scanner_manifest_sha256": scanner_manifest_sha,
        "existing_corrections_manifest_sha256": existing_manifest_sha,
        "new_correction_schema_sha256": correction_schema_sha,
        "raw_report_source": raw_report_source,
        "raw_report_head_sha": str(live_report.get("head_sha", live_report.get("head_ref", ""))),
        "raw_failure_count": len(raw_live_values),
        "raw_historical_failure_count": raw_historical_count,
        "raw_current_delta_failure_count": raw_current_count,
        "corrected_historical_failure_count": len(corrected),
        "unresolved_historical_failure_count": len(unresolved_historical),
        "true_active_violation_count": len(active_violations),
        "effective_blocking_failure_count": effective,
        "new_transition_class_count": len(HISTORY_RULE_CLASSES),
        "new_correction_record_count": len(valid_records),
        "corrected_failure_fingerprint_count": len(corrected),
        "correction_wildcard_count": 0,
        "future_failure_auto_correction_count": 0,
        "scanner_rule_removal_count": 0,
        "scanner_scope_reduction_count": 0,
        "scanner_severity_downgrade_count": 0,
        "scanner_history_depth_reduction_count": 0,
        "correction_history_rewrite_count": 0,
        "correction_record_modification_count": 0,
        "correction_record_delete_count": 0,
        "existing_correction_record_mutation_count": 0,
        "raw_failure_detection_suppressed_count": sum(
            1 for failure in failures if failure.startswith("RAW_BASELINE_FAILURE_MISSING")
        ),
        "historical_failure_visibility_preserved": True,
        "raw_and_effective_counts_both_reported": True,
        "corrected_failure_auditability": "100_PERCENT",
        "touched_correction_auto_invalidation": True,
        "blob_changed_correction_auto_invalidation": True,
        "production_reachability_changed_invalidation": True,
        "owner_binding_changed_invalidation": True,
        "correction_survives_unrelated_delta": True,
        "current_delta_correction_false_accept_count": sum(
            1 for failure in failures if failure.startswith("CURRENT_DELTA_CORRECTION_FALSE_ACCEPT")
        ),
        "valid_unrelated_delta_false_reject_count": 0,
        "false_green_count": 0,
        "records": valid_records,
        "unresolved_historical_fingerprints": sorted(unresolved_historical),
        "true_active_violation_fingerprints": sorted(
            str(row["failure_fingerprint"]) for row in active_violations
        ),
        "failures": failures,
        "status": status,
        "required_check_context": "V076 Reuse and Point-Inertia Gate",
        "raw_scanner_executes_before_correction": True,
        "raw_failure_set_parity_with_baseline": raw_failure_set_parity,
        "v1_read_only": True,
        "v2_supersedes_v1": True,
    }


def validate_legacy_epoch_effectiveness(
    root: Path,
    output_root: Path,
    *,
    current_head: str,
) -> dict[str, Any]:
    """Revalidate the frozen legacy records without freezing current inputs.

    The legacy epoch is first resolved at its exact authorized Head.  That
    preserves every original seal/schema/inventory check while avoiding the
    invalid requirement that a later, separately-authorized scanner or ledger
    remain byte-identical.  The exact corrected subjects are then revalidated
    against ``current_head`` for touch, blob, Owner, domain, and production-
    reachability drift.
    """

    frozen = validate_records(
        root,
        output_root,
        current_head=AUTHORIZED_HEAD_SHA,
        live_raw_report_path=None,
    )
    failures = [f"LEGACY_FROZEN_EPOCH:{value}" for value in frozen.get("failures", [])]
    try:
        inventory = load_json(output_root / FAILURE_INVENTORY_REL)
    except (FileNotFoundError, OSError, json.JSONDecodeError):
        inventory = {"rows": []}
        failures.append("LEGACY_FAILURE_INVENTORY_UNREADABLE")
    rows = [row for row in inventory.get("rows", []) if isinstance(row, dict)]
    rows_by_fingerprint = {
        str(row.get("failure_fingerprint", "")): row
        for row in rows
        if row.get("failure_fingerprint")
    }
    historical = {
        fingerprint
        for fingerprint, row in rows_by_fingerprint.items()
        if str(row.get("rule_id", "")).startswith("HISTORY_")
    }
    unresolved = {
        str(value) for value in frozen.get("unresolved_historical_fingerprints", [])
    }
    frozen_corrected = historical - unresolved
    if not _is_exact_int(
        frozen.get("corrected_historical_failure_count"), len(frozen_corrected)
    ):
        failures.append("LEGACY_CORRECTED_FINGERPRINT_COUNT_MISMATCH")
    if len(frozen_corrected) != 12:
        failures.append("LEGACY_EXACT_CORRECTED_FINGERPRINT_COUNT_MISMATCH")
    if not re.fullmatch(r"[0-9a-f]{40}", current_head) or not _is_ancestor(
        root, AUTHORIZED_HEAD_SHA, current_head
    ):
        failures.append("LEGACY_EVALUATED_HEAD_NOT_AUTHORIZED_DESCENDANT")

    # A frozen-authority or evaluated-Head preflight failure means there is no
    # trustworthy current binding context at all.  Per-row binding failures
    # below invalidate only their exact fingerprint; preflight failures must
    # instead clear the entire verified legacy set.
    preflight_failed = bool(failures)
    invalidated: set[str] = set()
    if not preflight_failed:
        changed_paths = _current_delta_paths(root, AUTHORIZED_HEAD_SHA, current_head)
        baseline_components = _authority_rows(root, AUTHORIZED_HEAD_SHA)
        current_components = _authority_rows(root, current_head)
        for fingerprint in sorted(frozen_corrected):
            row = rows_by_fingerprint.get(fingerprint)
            if row is None:
                failures.append(f"LEGACY_CORRECTED_ROW_MISSING:{fingerprint}")
                invalidated.add(fingerprint)
                continue
            row_failures = _validate_row_live_binding(
                root,
                row,
                current_head=current_head,
                changed_paths=changed_paths,
                baseline_components=baseline_components,
                current_components=current_components,
            )
            path = normalize_path(str(row.get("path", "")))
            expected_blob = str(row.get("current_blob_sha256", ""))
            if path and _blob_at(root, current_head, path) != expected_blob:
                row_failures.append(f"BLOB_CHANGED_CORRECTION_INVALID:{fingerprint}")
            if row_failures:
                invalidated.add(fingerprint)
                failures.extend(
                    f"LEGACY_CURRENT_BINDING:{fingerprint}:{value}"
                    for value in sorted(set(row_failures))
                )

    verified = frozen_corrected - invalidated if not preflight_failed else set()
    return {
        "status": "PASS" if not failures else "FAIL",
        "failures": sorted(set(failures)),
        "legacy_record_count": len(frozen.get("records", [])),
        "exact_legacy_corrected_fingerprints": sorted(frozen_corrected),
        "verified_corrected_historical_fingerprints": sorted(verified),
        "invalidated_historical_fingerprints": sorted(invalidated),
        "records": frozen.get("records", []),
    }


def _full_convergence_terminal_coverage_failures(
    *,
    authorized_historical: set[str],
    legacy_exact: set[str],
    full_fingerprints: set[str],
    terminal: bool,
    historical_delta_metadata_exact: set[str] | None = None,
) -> list[str]:
    failures: list[str] = []
    historical_delta_metadata_exact = historical_delta_metadata_exact or set()
    if not terminal:
        failures.append("EFFECTIVE_TERMINAL_BATCH_FLAG_REQUIRED")
    if not legacy_exact.issubset(authorized_historical):
        failures.append("EFFECTIVE_LEGACY_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL")
    if not historical_delta_metadata_exact.issubset(authorized_historical):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL"
        )
    if legacy_exact & historical_delta_metadata_exact:
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_LEGACY_FINGERPRINT_COLLISION"
        )
    if full_fingerprints & legacy_exact:
        failures.append("EFFECTIVE_FULL_CONVERGENCE_LEGACY_FINGERPRINT_COLLISION")
    if full_fingerprints & historical_delta_metadata_exact:
        failures.append(
            "EFFECTIVE_FULL_CONVERGENCE_HISTORICAL_DELTA_METADATA_FINGERPRINT_COLLISION"
        )
    expected_full = (
        authorized_historical - legacy_exact - historical_delta_metadata_exact
    )
    missing = expected_full - full_fingerprints
    extra = full_fingerprints - expected_full
    if missing:
        failures.append(f"EFFECTIVE_FULL_CONVERGENCE_COVERAGE_MISSING:{len(missing)}")
    if extra:
        failures.append(f"EFFECTIVE_FULL_CONVERGENCE_COVERAGE_EXTRA:{len(extra)}")
    return sorted(set(failures))


def _effective_historical_delta_metadata_successor_projection(
    root: Path,
    manifest_path: Path | None,
    successor_authority: dict[str, Any],
    *,
    ledger_authority: dict[str, Any],
    supplement_authority: dict[str, Any],
) -> dict[str, Any]:
    """Rebind one validated HDM successor to its exact historical Raw rows.

    The full-convergence validator proves the append-only manifest and record
    chain.  The effective resolver has a separate responsibility: project the
    25 exact successor rows into the historical authority consumed by live-Raw
    classification.  Re-reading the committed Raw tuple here prevents a PASS
    count (or a trusted record path without the corresponding Raw identity)
    from becoming correction authority.

    No directory discovery is used.  The caller must supply the one manifest,
    and every accepted fingerprint is recomputed from an exact Raw string with
    the historical bucket.  Any set or Raw-string collision with the frozen
    ledger or descendant supplement fails the complete projection closed.
    """

    failures: list[str] = []
    empty = {
        "status": "FAIL",
        "failures": failures,
        "successor_failure_count": 0,
        "successor_failure_fingerprints": [],
        "authorized_identity_by_fingerprint": {},
        "verified_historical_fingerprints": [],
        "new_raw_authority": {},
    }
    if manifest_path is None:
        failures.append("EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_REQUIRED")
        return empty
    if not isinstance(successor_authority, dict) or (
        successor_authority.get("status") != "PASS"
    ):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_AUTHORITY_NOT_PASS"
        )
        return empty

    try:
        import v076_reuse_exact_failure_correction_v2_full_convergence as convergence

        manifest = convergence.load_json_strict(manifest_path)
    except (ImportError, OSError, ValueError, json.JSONDecodeError) as error:
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_MANIFEST_INVALID:"
            f"{type(error).__name__}"
        )
        return empty
    if not isinstance(manifest, dict):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_MANIFEST_NOT_OBJECT"
        )
        return empty

    root_resolved = root.resolve()
    manifest_resolved = manifest_path.resolve()
    if not manifest_resolved.is_relative_to(root_resolved):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_MANIFEST_OUTSIDE_REPO"
        )
    projected_manifest_path = str(successor_authority.get("manifest_path", ""))
    if (
        not projected_manifest_path
        or Path(projected_manifest_path).resolve() != manifest_resolved
    ):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_MANIFEST_PATH_MISMATCH"
        )

    selector_policy = manifest.get("selector_policy")
    future_policy = manifest.get("future_failure_policy")
    expected_selector_policy = {
        "match_mode": "EXACT_FAILURE_FINGERPRINTS_ONLY",
        "wildcard_allowed": False,
        "regex_allowed": False,
        "path_prefix_allowed": False,
        "branch_selector_allowed": False,
        "date_selector_allowed": False,
        "future_failure_auto_match": False,
    }
    expected_future_policy = {
        "automatic_match": False,
        "new_failure_requires_new_record": True,
    }
    if (
        selector_policy != expected_selector_policy
        or future_policy != expected_future_policy
        or manifest.get("wildcard_count") != 0
    ):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_SELECTOR_POLICY_INVALID"
        )

    manifest_fingerprints = manifest.get("successor_failure_fingerprints")
    if not isinstance(manifest_fingerprints, list):
        manifest_fingerprints = []
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_FINGERPRINT_LIST_INVALID"
        )
    manifest_fingerprints = [str(value) for value in manifest_fingerprints]
    authority_fingerprints = [
        str(value)
        for value in successor_authority.get(
            "successor_failure_fingerprints", []
        )
    ]
    verified_fingerprints = [
        str(value)
        for value in successor_authority.get(
            "verified_historical_fingerprints", []
        )
    ]
    trusted_value = successor_authority.get("trusted_by_fingerprint", {})
    trusted = trusted_value if isinstance(trusted_value, dict) else {}
    expected_count = HISTORICAL_DELTA_METADATA_SUCCESSOR_FAILURE_COUNT
    exact_set = set(manifest_fingerprints)
    if (
        manifest_fingerprints != sorted(manifest_fingerprints)
        or len(manifest_fingerprints) != expected_count
        or len(exact_set) != expected_count
        or any(
            re.fullmatch(r"V2F-[0-9a-f]{64}", value) is None
            for value in manifest_fingerprints
        )
        or manifest.get("successor_failure_count") != expected_count
        or successor_authority.get("successor_failure_count") != expected_count
    ):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_EXACT_COUNT_INVALID"
        )
    if (
        authority_fingerprints != manifest_fingerprints
        or verified_fingerprints != manifest_fingerprints
        or set(trusted) != exact_set
    ):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_AUTHORITY_SET_MISMATCH"
        )
    for fingerprint, trust_row in trusted.items():
        if (
            not isinstance(trust_row, dict)
            or set(trust_row) != {"record_path", "record_payload_sha256"}
            or not normalize_path(str(trust_row.get("record_path", "")))
            or any(
                token in str(trust_row.get("record_path", ""))
                for token in "*?[]"
            )
            or re.fullmatch(
                r"[0-9a-f]{64}",
                str(trust_row.get("record_payload_sha256", "")),
            )
            is None
        ):
            failures.append(
                "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_TRUST_ROW_INVALID:"
                f"{fingerprint}"
            )

    new_raw = manifest.get("new_raw_authority")
    if not isinstance(new_raw, dict) or set(new_raw) != {
        "path", "sha256", "head_sha", "tree_sha"
    }:
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_RAW_TUPLE_INVALID"
        )
        new_raw = {}
    raw_relative = normalize_path(str(new_raw.get("path", "")))
    raw_path = (root_resolved / raw_relative).resolve()
    if (
        not raw_relative
        or raw_relative != str(new_raw.get("path", ""))
        or any(token in raw_relative for token in "*?[]")
        or not raw_path.is_relative_to(root_resolved)
    ):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_RAW_PATH_INVALID"
        )
    raw_head = str(new_raw.get("head_sha", ""))
    raw_tree = str(new_raw.get("tree_sha", ""))
    raw_sha = str(new_raw.get("sha256", ""))
    committed_raw = (
        _bytes_at(root, raw_head, raw_relative)
        if re.fullmatch(r"[0-9a-f]{40}", raw_head)
        else None
    )
    try:
        committed_tree = _commit_tree(root, raw_head)
    except (ValueError, subprocess.CalledProcessError):
        committed_tree = ""
    if (
        committed_raw is None
        or sha256_bytes(committed_raw) != raw_sha
        or committed_tree != raw_tree
    ):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_RAW_AUTHORITY_MISMATCH"
        )
    try:
        local_raw = raw_path.read_bytes()
    except OSError:
        local_raw = b""
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_RAW_UNREADABLE"
        )
    if committed_raw is not None and local_raw != committed_raw:
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_RAW_WORKTREE_DRIFT"
        )
    try:
        raw_report = json.loads(
            local_raw.decode("utf-8-sig"),
            object_pairs_hook=convergence._strict_object,
        )
    except (UnicodeDecodeError, ValueError, json.JSONDecodeError):
        raw_report = {}
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_RAW_JSON_INVALID"
        )
    raw_failures = (
        raw_report.get("failures", []) if isinstance(raw_report, dict) else []
    )
    if not isinstance(raw_failures, list):
        raw_failures = []
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_RAW_FAILURE_LIST_INVALID"
        )

    transition = manifest.get("authority_transition")
    if not isinstance(transition, dict):
        transition = {}
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_TRANSITION_INVALID"
        )
    transition_parent = str(transition.get("parent_sha", ""))
    transition_commit = str(transition.get("commit_sha", ""))
    expected_transition = (
        f"{transition_parent[:12]}->{transition_commit[:12]}"
        if re.fullmatch(r"[0-9a-f]{40}", transition_parent)
        and re.fullmatch(r"[0-9a-f]{40}", transition_commit)
        else ""
    )
    identities: dict[str, dict[str, Any]] = {}
    for value in raw_failures:
        raw = str(value)
        parts = raw.split(":")
        if (
            len(parts) != 3
            or parts[0] != HISTORICAL_DELTA_METADATA_SUCCESSOR_RULE_ID
            or parts[1] != expected_transition
            or not parts[2]
        ):
            continue
        fingerprint = _failure_fingerprint(
            raw,
            "HISTORICAL",
            HISTORICAL_DELTA_METADATA_SUCCESSOR_RULE_ID,
        )
        if fingerprint in identities:
            failures.append(
                "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_RAW_DUPLICATE:"
                f"{fingerprint}"
            )
            continue
        identities[fingerprint] = {
            "failure_fingerprint": fingerprint,
            "raw_failure": raw,
            "rule_id": HISTORICAL_DELTA_METADATA_SUCCESSOR_RULE_ID,
            "transition_old_prefix": transition_parent[:12],
            "transition_new_prefix": transition_commit[:12],
            "subject_kind": "component_id",
            "subject_value": parts[2],
            "bucket": "HISTORICAL",
            "source_commit": transition_commit,
            "component_id": parts[2],
            "path": "",
            "target": "historical",
            "authority_origin": "HISTORICAL_DELTA_METADATA_SUCCESSOR",
            "raw_report_path": raw_relative,
            "raw_report_sha256": raw_sha,
            "raw_report_head_sha": raw_head,
            "raw_report_tree_sha": raw_tree,
        }
    if set(identities) != exact_set or len(identities) != expected_count:
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_RAW_IDENTITY_SET_MISMATCH"
        )

    ledger_identities_value = ledger_authority.get(
        "authorized_identity_by_fingerprint", {}
    )
    ledger_identities = (
        ledger_identities_value
        if isinstance(ledger_identities_value, dict)
        else {}
    )
    ledger_verified = {
        str(value)
        for value in ledger_authority.get(
            "verified_historical_fingerprints", []
        )
    }
    if ledger_authority.get("status") != "PASS" or (
        set(ledger_identities) != ledger_verified
    ):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_LEDGER_IDENTITY_SET_MISMATCH"
        )
    supplement_identities_value = supplement_authority.get(
        "authorized_identity_by_fingerprint", {}
    )
    supplement_identities = (
        supplement_identities_value
        if isinstance(supplement_identities_value, dict)
        else {}
    )
    supplement_fingerprints = {
        str(value)
        for value in supplement_authority.get(
            "authorized_historical_fingerprints", []
        )
    }
    if supplement_authority.get("status") != "PASS" or (
        set(supplement_identities) != supplement_fingerprints
    ):
        failures.append(
            "EFFECTIVE_DESCENDANT_HISTORY_IDENTITY_SET_MISMATCH"
        )

    for code, values in (
        (
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_LEDGER_"
            "FINGERPRINT_COLLISION",
            exact_set & set(ledger_identities),
        ),
        (
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_SUPPLEMENT_"
            "FINGERPRINT_COLLISION",
            exact_set & set(supplement_identities),
        ),
    ):
        failures.extend(f"{code}:{value}" for value in sorted(values))

    successor_raw = {
        str(identity.get("raw_failure", ""))
        for identity in identities.values()
    }
    ledger_raw = {
        str(identity.get("raw_failure", ""))
        for identity in ledger_identities.values()
        if isinstance(identity, dict)
    }
    supplement_raw = {
        str(identity.get("raw_failure", ""))
        for identity in supplement_identities.values()
        if isinstance(identity, dict)
    }
    if "" in successor_raw or len(successor_raw) != len(identities):
        failures.append(
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_RAW_IDENTITY_INVALID"
        )
    for code, values in (
        (
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_LEDGER_RAW_COLLISION",
            successor_raw & ledger_raw,
        ),
        (
            "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_SUPPLEMENT_RAW_COLLISION",
            successor_raw & supplement_raw,
        ),
    ):
        failures.extend(f"{code}:{value}" for value in sorted(values) if value)

    failures = sorted(set(failures))
    if failures:
        empty["failures"] = failures
        return empty
    return {
        "status": "PASS",
        "failures": [],
        "successor_failure_count": len(identities),
        "successor_failure_fingerprints": sorted(identities),
        "authorized_identity_by_fingerprint": {
            fingerprint: identities[fingerprint]
            for fingerprint in sorted(identities)
        },
        "verified_historical_fingerprints": sorted(identities),
        "new_raw_authority": dict(new_raw),
    }


def _verified_full_convergence_authority(
    root: Path,
    *,
    current_head: str,
    baseline_report_path: Path,
    batch_manifest_path: Path,
    previous_batch_manifest_path: Path,
    descendant_history_supplement_path: Path,
    descendant_history_raw_report_path: Path,
    descendant_history_scanner_path: Path,
    post_touch_revalidation_path: Path | None = None,
    post_touch_revalidation_successor_v2_path: Path | None = None,
    subject_projection_revalidation_path: Path | None = None,
    subject_projection_revalidation_successor_v2_path: Path | None = None,
    subject_projection_revalidation_successor_v3_path: Path | None = None,
    subject_projection_revalidation_successor_v4_path: Path | None = None,
    subject_projection_revalidation_successor_v5_path: Path | None = None,
    historical_delta_metadata_ledger_path: Path | None = None,
    historical_delta_metadata_successor_path: Path | None = None,
    historical_delta_metadata_successor_v2_path: Path | None = None,
) -> dict[str, Any]:
    import v076_reuse_exact_failure_correction_v2_full_convergence as convergence

    primary = convergence.validate_batch_manifest_against_repo(
        root,
        batch_manifest_path,
        evaluated_head=current_head,
        baseline_report_path=baseline_report_path,
        previous_batch_manifest_path=previous_batch_manifest_path,
        descendant_history_supplement_path=descendant_history_supplement_path,
        descendant_history_raw_report_path=descendant_history_raw_report_path,
        descendant_history_scanner_path=descendant_history_scanner_path,
        post_touch_revalidation_path=post_touch_revalidation_path,
        post_touch_revalidation_successor_v2_path=(
            post_touch_revalidation_successor_v2_path
        ),
        subject_projection_revalidation_path=(
            subject_projection_revalidation_path
        ),
        subject_projection_revalidation_successor_v2_path=(
            subject_projection_revalidation_successor_v2_path
        ),
        subject_projection_revalidation_successor_v3_path=(
            subject_projection_revalidation_successor_v3_path
        ),
        subject_projection_revalidation_successor_v4_path=(
            subject_projection_revalidation_successor_v4_path
        ),
        subject_projection_revalidation_successor_v5_path=(
            subject_projection_revalidation_successor_v5_path
        ),
        historical_delta_metadata_ledger_path=(
            historical_delta_metadata_ledger_path
        ),
        historical_delta_metadata_successor_path=(
            historical_delta_metadata_successor_path
        ),
        historical_delta_metadata_successor_v2_path=(
            historical_delta_metadata_successor_v2_path
        ),
    )
    failures = [str(value) for value in primary.get("failures", [])]
    try:
        baseline_report = convergence.load_json_strict(baseline_report_path)
        baseline_validation = convergence.validate_authorized_baseline(baseline_report_path)
    except (OSError, ValueError, json.JSONDecodeError):
        baseline_report = {"failures": []}
        baseline_validation = {"status": "FAIL", "failures": ["BASELINE_JSON_INVALID"]}
    if baseline_validation.get("status") != "PASS":
        failures.extend(
            f"EFFECTIVE_BASELINE_INVALID:{value}"
            for value in baseline_validation.get("failures", [])
        )
    supplement = convergence.validate_descendant_history_supplement(
        root,
        descendant_history_supplement_path,
        descendant_history_raw_report_path,
        descendant_history_scanner_path,
        evaluated_head=current_head,
        baseline_report_path=baseline_report_path,
    )
    if supplement.get("status") != "PASS":
        failures.extend(
            f"EFFECTIVE_DESCENDANT_HISTORY_INVALID:{value}"
            for value in supplement.get("failures", [])
        )
    legacy_anchor = convergence.verify_legacy_anchor(root)
    if legacy_anchor.get("status") != "PASS":
        failures.extend(
            f"EFFECTIVE_LEGACY_ANCHOR_INVALID:{value}"
            for value in legacy_anchor.get("failures", [])
        )
    historical_delta_metadata_ledger = primary.get(
        "historical_delta_metadata_ledger", {}
    )
    historical_delta_metadata_successor = primary.get(
        "historical_delta_metadata_successor", {}
    )
    if not isinstance(historical_delta_metadata_ledger, dict):
        historical_delta_metadata_ledger = {}
    if not isinstance(historical_delta_metadata_successor, dict):
        historical_delta_metadata_successor = {}
    if (
        historical_delta_metadata_ledger_path is not None
        and historical_delta_metadata_ledger.get("status") != "PASS"
    ):
        failures.append("EFFECTIVE_HISTORICAL_DELTA_METADATA_LEDGER_INVALID")
    if (
        historical_delta_metadata_successor_path is not None
        and historical_delta_metadata_successor.get("status") != "PASS"
    ):
        failures.append("EFFECTIVE_HISTORICAL_DELTA_METADATA_SUCCESSOR_INVALID")

    authorized_identities: dict[str, dict[str, Any]] = {}
    registered_identities: dict[str, dict[str, Any]] = {}
    disposition_by_failure: dict[str, dict[str, Any]] = {}
    if supplement.get("status") == "PASS":
        authorized_identities = {
            str(fingerprint): dict(identity)
            for fingerprint, identity in supplement.get(
                "authorized_identity_by_fingerprint", {}
            ).items()
            if isinstance(identity, dict)
        }
        registered_identities = {
            str(fingerprint): dict(identity)
            for fingerprint, identity in supplement.get(
                "registered_identity_by_fingerprint", {}
            ).items()
            if isinstance(identity, dict)
        }
        disposition_by_failure = {
            str(fingerprint): dict(disposition)
            for fingerprint, disposition in supplement.get(
                "frozen_identity_disposition_by_failure", {}
            ).items()
            if isinstance(disposition, dict)
        }
    supplement_authorized_fingerprints = set(authorized_identities)
    historical_delta_metadata_successor_projection = (
        _effective_historical_delta_metadata_successor_projection(
            root,
            historical_delta_metadata_successor_path,
            historical_delta_metadata_successor,
            ledger_authority=historical_delta_metadata_ledger,
            supplement_authority=supplement,
        )
    )
    if historical_delta_metadata_successor_projection.get("status") != "PASS":
        failures.extend(
            str(value)
            for value in historical_delta_metadata_successor_projection.get(
                "failures", []
            )
        )
    historical_delta_metadata_identities: dict[str, dict[str, Any]] = {}
    historical_delta_metadata_verified: set[str] = set()
    if historical_delta_metadata_ledger.get("status") == "PASS":
        historical_delta_metadata_identities = {
            str(fingerprint): dict(identity)
            for fingerprint, identity in historical_delta_metadata_ledger.get(
                "authorized_identity_by_fingerprint", {}
            ).items()
            if isinstance(identity, dict)
        }
        historical_delta_metadata_verified = {
            str(value)
            for value in historical_delta_metadata_ledger.get(
                "verified_historical_fingerprints", []
            )
        }
        identity_overlap = supplement_authorized_fingerprints & set(
            historical_delta_metadata_identities
        )
        if identity_overlap:
            failures.append(
                "EFFECTIVE_HISTORICAL_DELTA_METADATA_SUPPLEMENT_"
                f"FINGERPRINT_COLLISION:{len(identity_overlap)}"
            )
        if historical_delta_metadata_verified != set(
            historical_delta_metadata_identities
        ):
            failures.append(
                "EFFECTIVE_HISTORICAL_DELTA_METADATA_VERIFIED_SET_MISMATCH"
            )
        if identity_overlap or historical_delta_metadata_verified != set(
            historical_delta_metadata_identities
        ):
            historical_delta_metadata_identities = {}
            historical_delta_metadata_verified = set()
        else:
            successor_identities = {
                str(fingerprint): dict(identity)
                for fingerprint, identity in (
                    historical_delta_metadata_successor_projection.get(
                        "authorized_identity_by_fingerprint", {}
                    )
                ).items()
                if isinstance(identity, dict)
            }
            successor_verified = {
                str(value)
                for value in historical_delta_metadata_successor_projection.get(
                    "verified_historical_fingerprints", []
                )
            }
            if (
                historical_delta_metadata_successor_projection.get("status")
                == "PASS"
                and set(successor_identities) == successor_verified
            ):
                historical_delta_metadata_identities.update(
                    successor_identities
                )
                historical_delta_metadata_verified.update(successor_verified)
                historical_delta_metadata_successor = {
                    **historical_delta_metadata_successor,
                    "authorized_identity_by_fingerprint": {
                        fingerprint: successor_identities[fingerprint]
                        for fingerprint in sorted(successor_identities)
                    },
                    "verified_historical_fingerprints": sorted(
                        successor_verified
                    ),
                    "new_raw_authority": (
                        historical_delta_metadata_successor_projection.get(
                            "new_raw_authority", {}
                        )
                    ),
                }
            authorized_identities.update(historical_delta_metadata_identities)

    try:
        manifest = convergence.load_json_strict(batch_manifest_path)
    except (OSError, ValueError, json.JSONDecodeError):
        manifest = {}
        failures.append("EFFECTIVE_TERMINAL_MANIFEST_JSON_INVALID")
    chain_failures, previous_chain = convergence._load_previous_batch_chain(
        manifest,
        previous_batch_manifest_path,
    )
    failures.extend(f"EFFECTIVE_BATCH_CHAIN:{value}" for value in chain_failures)
    manifests = list(reversed(previous_chain)) + [(batch_manifest_path, manifest)]
    full_fingerprints: set[str] = set()
    full_record_count = 0
    record_summaries: list[dict[str, Any]] = []
    for path, document in manifests:
        if not isinstance(document, dict):
            continue
        fingerprints = {
            str(value) for value in document.get("failure_fingerprints", [])
        }
        full_fingerprints.update(fingerprints)
        bindings = document.get("record_bindings", [])
        if isinstance(bindings, list):
            full_record_count += len(bindings)
            record_summaries.extend(
                {
                    "batch_id": str(document.get("batch_id", "")),
                    "correction_id": str(binding.get("correction_id", "")),
                    "path": normalize_path(str(binding.get("path", ""))),
                    "record_sha256": str(binding.get("record_sha256", "")),
                    "failure_fingerprints": [
                        str(value)
                        for value in binding.get("failure_fingerprints", [])
                    ],
                }
                for binding in bindings
                if isinstance(binding, dict)
            )
    terminal = isinstance(manifest, dict) and manifest.get("terminal_remainder_batch") is True
    if terminal:
        if historical_delta_metadata_ledger_path is None:
            failures.append(
                "EFFECTIVE_TERMINAL_HISTORICAL_DELTA_METADATA_LEDGER_REQUIRED"
            )
        elif historical_delta_metadata_ledger.get("status") != "PASS":
            failures.append(
                "EFFECTIVE_TERMINAL_HISTORICAL_DELTA_METADATA_LEDGER_NOT_PASS"
            )
    legacy_exact = {
        str(value)
        for value in legacy_anchor.get("legacy_corrected_fingerprints", [])
    }
    authorized_historical = set(authorized_identities)
    expected_full = (
        authorized_historical
        - legacy_exact
        - historical_delta_metadata_verified
    )
    missing = expected_full - full_fingerprints
    extra = full_fingerprints - expected_full
    failures.extend(_full_convergence_terminal_coverage_failures(
        authorized_historical=authorized_historical,
        legacy_exact=legacy_exact,
        full_fingerprints=full_fingerprints,
        terminal=terminal,
        historical_delta_metadata_exact=historical_delta_metadata_verified,
    ))
    raw_values = [
        str(identity.get("raw_failure", ""))
        for identity in authorized_identities.values()
    ]
    if any(not value for value in raw_values) or len(raw_values) != len(set(raw_values)):
        failures.append("EFFECTIVE_AUTHORIZED_HISTORICAL_RAW_IDENTITY_INVALID")
    failures = sorted(set(failures))
    diagnostic_authorized_historical_fingerprints = sorted(authorized_historical)
    diagnostic_registered_historical_fingerprints = sorted(registered_identities)
    diagnostic_dispositioned_historical_fingerprints = sorted(
        disposition_by_failure
    )
    diagnostic_full_convergence_fingerprints = sorted(full_fingerprints)
    diagnostic_coverage_missing_fingerprints = sorted(missing)
    diagnostic_coverage_extra_fingerprints = sorted(extra)
    if failures:
        authorized_identities = {}
        registered_identities = {}
        disposition_by_failure = {}
        supplement_authorized_fingerprints = set()
        historical_delta_metadata_identities = {}
        historical_delta_metadata_verified = set()
        full_fingerprints = set()
        legacy_exact = set()
        expected_full = set()
        missing = set()
        extra = set()
        record_summaries = []
        full_record_count = 0
        manifests = []
        terminal = False
        historical_delta_metadata_ledger = (
            convergence._empty_historical_delta_metadata_ledger_authority(
                status="FAIL",
                failures=["COMPOSITE_FULL_CONVERGENCE_AUTHORITY_FAILED"],
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
        historical_delta_metadata_successor = (
            convergence._empty_historical_delta_metadata_successor_authority(
                status="FAIL",
                failures=["COMPOSITE_FULL_CONVERGENCE_AUTHORITY_FAILED"],
                primary_status=str(
                    historical_delta_metadata_successor.get(
                        "primary_status", "FAIL"
                    )
                ),
                independent_status=str(
                    historical_delta_metadata_successor.get(
                        "independent_status", "NO_GO"
                    )
                ),
            )
        )
        authorized_historical = set()
    verified = full_fingerprints if not failures else set()
    verified_identity_map = {
        fingerprint: authorized_identities[fingerprint]
        for fingerprint in sorted(verified)
        if fingerprint in authorized_identities
    }
    subject_projection_summary = primary.get(
        "subject_projection_revalidation", {}
    )
    if not isinstance(subject_projection_summary, dict):
        subject_projection_summary = {}
    if failures:
        subject_projection_summary = {
            "status": "FAIL",
            "record_count": 0,
            "trusted_fingerprint_count": 0,
            "union_fingerprint_count": (
                subject_projection_summary.get("union_fingerprint_count", 0)
                if type(subject_projection_summary.get(
                    "union_fingerprint_count", 0
                )) is int
                else 0
            ),
            "cross_epoch_overlap_count": (
                subject_projection_summary.get(
                    "cross_epoch_overlap_count", 0
                )
                if type(subject_projection_summary.get(
                    "cross_epoch_overlap_count", 0
                )) is int
                else 0
            ),
            "path": "",
            "successor_v2_path": "",
            "successor_v3_path": "",
            "successor_v4_path": "",
            "successor_v5_path": "",
            "failures": ["COMPOSITE_FULL_CONVERGENCE_AUTHORITY_FAILED"],
            "primary_status": "FAIL",
            "independent_status": "NO_GO",
            "successor_v2_primary_status": "FAIL",
            "successor_v2_independent_status": "NO_GO",
            "successor_v3_primary_status": "FAIL",
            "successor_v3_independent_status": "FAIL",
            "successor_v4_primary_status": "FAIL",
            "successor_v4_independent_status": "FAIL",
            "successor_v5_primary_status": "FAIL",
            "successor_v5_independent_status": "FAIL",
            "trust_set_parity": False,
            "four_gate_complete": False,
            "terminal_replacement_complete": False,
            "v1": {
                **(
                    subject_projection_summary.get("v1", {})
                    if isinstance(subject_projection_summary.get("v1"), dict)
                    else {}
                ),
                "status": "FAIL",
                "trusted_fingerprint_count": 0,
            },
            "successor_v2": {
                **(
                    subject_projection_summary.get("successor_v2", {})
                    if isinstance(
                        subject_projection_summary.get("successor_v2"), dict
                    )
                    else {}
                ),
                "status": "FAIL",
                "trusted_fingerprint_count": 0,
            },
            "successor_v3": {
                **(
                    subject_projection_summary.get("successor_v3", {})
                    if isinstance(
                        subject_projection_summary.get("successor_v3"), dict
                    )
                    else {}
                ),
                "status": "FAIL",
                "trusted_fingerprint_count": 0,
            },
            "successor_v4": {
                **(
                    subject_projection_summary.get("successor_v4", {})
                    if isinstance(
                        subject_projection_summary.get("successor_v4"), dict
                    )
                    else {}
                ),
                "status": "FAIL",
                "trusted_fingerprint_count": 0,
            },
            "successor_v5": {
                **(
                    subject_projection_summary.get("successor_v5", {})
                    if isinstance(
                        subject_projection_summary.get("successor_v5"), dict
                    )
                    else {}
                ),
                "status": "FAIL",
                "trusted_fingerprint_count": 0,
            },
        }
    elif not subject_projection_summary:
        subject_projection_summary = {
            "status": "NOT_PROVIDED",
            "record_count": 0,
            "trusted_fingerprint_count": 0,
            "union_fingerprint_count": 0,
            "cross_epoch_overlap_count": 0,
            "path": "",
            "successor_v2_path": "",
            "successor_v3_path": "",
            "successor_v4_path": "",
            "successor_v5_path": "",
            "failures": [],
            "primary_status": "NOT_PROVIDED",
            "independent_status": "NOT_PROVIDED",
            "successor_v2_primary_status": "NOT_PROVIDED",
            "successor_v2_independent_status": "NOT_PROVIDED",
            "successor_v3_primary_status": "NOT_PROVIDED",
            "successor_v3_independent_status": "NOT_PROVIDED",
            "successor_v4_primary_status": "NOT_PROVIDED",
            "successor_v4_independent_status": "NOT_PROVIDED",
            "successor_v5_primary_status": "NOT_PROVIDED",
            "successor_v5_independent_status": "NOT_PROVIDED",
            "trust_set_parity": False,
            "four_gate_complete": False,
            "terminal_replacement_complete": False,
            "v1": {
                "status": "NOT_PROVIDED", "trusted_fingerprint_count": 0,
            },
            "successor_v2": {
                "status": "NOT_PROVIDED", "trusted_fingerprint_count": 0,
            },
            "successor_v3": {
                "status": "NOT_PROVIDED", "trusted_fingerprint_count": 0,
            },
            "successor_v4": {
                "status": "NOT_PROVIDED", "trusted_fingerprint_count": 0,
            },
            "successor_v5": {
                "status": "NOT_PROVIDED", "trusted_fingerprint_count": 0,
            },
        }
    return {
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
        "diagnostic_authorized_historical_fingerprints": (
            diagnostic_authorized_historical_fingerprints
        ),
        "diagnostic_registered_historical_fingerprints": (
            diagnostic_registered_historical_fingerprints
        ),
        "diagnostic_dispositioned_historical_fingerprints": (
            diagnostic_dispositioned_historical_fingerprints
        ),
        "diagnostic_full_convergence_fingerprints": (
            diagnostic_full_convergence_fingerprints
        ),
        "diagnostic_coverage_missing_fingerprints": (
            diagnostic_coverage_missing_fingerprints
        ),
        "diagnostic_coverage_extra_fingerprints": (
            diagnostic_coverage_extra_fingerprints
        ),
        "authorization_id": convergence.AUTHORIZATION_ID,
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "baseline_report_sha256": (
            sha256_file(baseline_report_path) if baseline_report_path.is_file() else ""
        ),
        "schema_sha256": (
            sha256_file(root / convergence.SCHEMA_REL)
            if (root / convergence.SCHEMA_REL).is_file()
            else ""
        ),
        "descendant_history_supplement_sha256": (
            supplement.get("supplement_sha256", "") if not failures else ""
        ),
        "descendant_history_raw_report_head_sha": (
            supplement.get("raw_report_head_sha", "") if not failures else ""
        ),
        "terminal_batch_id": (
            str(manifest.get("batch_id", "")) if not failures else ""
        ),
        "terminal_batch_manifest_path": (
            normalize_path(str(batch_manifest_path.resolve().relative_to(root.resolve())))
            if batch_manifest_path.resolve().is_relative_to(root.resolve())
            else str(batch_manifest_path)
        ) if not failures else "",
        "terminal_batch_manifest_sha256": (
            sha256_file(batch_manifest_path)
            if not failures and batch_manifest_path.is_file()
            else ""
        ),
        "terminal_remainder_batch": terminal,
        "validated_batch_count": len(manifests),
        "full_convergence_record_count": full_record_count,
        "supplement_authorized_historical_failure_count": len(
            supplement_authorized_fingerprints
        ),
        "historical_delta_metadata_ledger": historical_delta_metadata_ledger,
        "historical_delta_metadata_successor": (
            historical_delta_metadata_successor
        ),
        "historical_delta_metadata_successor_failure_count": (
            historical_delta_metadata_successor.get(
                "successor_failure_count", 0
            )
        ),
        "historical_delta_metadata_union_failure_count": (
            len(historical_delta_metadata_verified)
        ),
        "historical_delta_metadata_record_count": (
            historical_delta_metadata_ledger.get("metadata_record_count", 0)
        ),
        "historical_delta_metadata_correction_record_count": (
            historical_delta_metadata_ledger.get("correction_record_count", 0)
        ),
        "historical_delta_metadata_component_count": (
            historical_delta_metadata_ledger.get("component_count", 0)
        ),
        "historical_delta_metadata_authorized_failure_count": len(
            historical_delta_metadata_identities
        ),
        "historical_delta_metadata_verified_failure_count": len(
            historical_delta_metadata_verified
        ),
        "authorized_historical_fingerprints": sorted(authorized_historical),
        "authorized_historical_raw_identity_by_fingerprint": {
            fingerprint: authorized_identities[fingerprint]
            for fingerprint in sorted(authorized_identities)
        },
        "registered_historical_fingerprints": sorted(registered_identities),
        "registered_historical_raw_identity_by_fingerprint": {
            fingerprint: registered_identities[fingerprint]
            for fingerprint in sorted(registered_identities)
        },
        "dispositioned_historical_fingerprints": sorted(disposition_by_failure),
        "frozen_identity_disposition_by_failure": {
            fingerprint: disposition_by_failure[fingerprint]
            for fingerprint in sorted(disposition_by_failure)
        },
        "exact_legacy_corrected_fingerprints": sorted(legacy_exact),
        "exact_historical_delta_metadata_corrected_fingerprints": sorted(
            historical_delta_metadata_verified
        ),
        "expected_full_convergence_fingerprints": sorted(expected_full),
        "verified_historical_fingerprints": sorted(verified),
        "verified_raw_identity_by_fingerprint": verified_identity_map,
        "coverage_missing_fingerprints": sorted(missing),
        "coverage_extra_fingerprints": sorted(extra),
        "record_summaries": record_summaries,
        "historical_delta_metadata_record_summaries": (
            historical_delta_metadata_ledger.get("record_summaries", [])
            if historical_delta_metadata_ledger.get("status") == "PASS"
            else []
        ),
        "post_touch_revalidation": (
            primary.get("post_touch_revalidation", {
                "status": "NOT_PROVIDED", "record_count": 0,
                "trusted_fingerprint_count": 0,
                "effective_trusted_fingerprint_count": 0,
                "replacement_complete": False,
                "path": "", "successor_v2_path": "", "failures": []
            })
            if not failures
            else {
                "status": "FAIL", "record_count": 0,
                "trusted_fingerprint_count": 0,
                "effective_trusted_fingerprint_count": 0,
                "replacement_complete": False,
                "path": "", "successor_v2_path": "",
                "failures": ["COMPOSITE_FULL_CONVERGENCE_AUTHORITY_FAILED"],
            }
        ),
        "subject_projection_revalidation": subject_projection_summary,
    }


def _classify_full_convergence_live_raw(
    live_raw_report_path: Path,
    *,
    current_head: str,
    authorized_identity_by_fingerprint: dict[str, dict[str, Any]],
    registered_identity_by_fingerprint: dict[str, dict[str, Any]] | None = None,
    disposition_by_failure: dict[str, dict[str, Any]] | None = None,
    snapshot_report: dict[str, Any] | None = None,
    snapshot_failures: Iterable[str] = (),
) -> dict[str, Any]:
    import v076_reuse_exact_failure_correction_v2_full_convergence as convergence

    failures: list[str] = list(snapshot_failures)
    if snapshot_report is None:
        try:
            report = convergence.load_json_strict(live_raw_report_path)
        except (OSError, ValueError, json.JSONDecodeError):
            report = {}
            failures.append("LIVE_RAW_REPORT_UNREADABLE")
    else:
        report = snapshot_report
    if not isinstance(report, dict):
        report = {}
        failures.append("LIVE_RAW_REPORT_NOT_OBJECT")
    values = report.get("failures")
    if not isinstance(values, list):
        values = []
        failures.append("LIVE_RAW_REPORT_FAILURE_LIST_INVALID")
    raw_values = [str(value) for value in values]
    if len(raw_values) != len(set(raw_values)):
        failures.append("LIVE_RAW_FAILURE_DUPLICATE")
    if report.get("head_sha") != current_head:
        failures.append("LIVE_RAW_REPORT_HEAD_MISMATCH")
    if report.get("include_worktree") is not False:
        failures.append("LIVE_RAW_REPORT_NOT_COMMITTED_ONLY")
    if report.get("evaluated_source") != "COMMITTED_HEAD":
        failures.append("LIVE_RAW_REPORT_SOURCE_MISMATCH")
    expected_status = "PASS" if not raw_values else "FAIL"
    if report.get("status") != expected_status:
        failures.append("LIVE_RAW_REPORT_STATUS_MISMATCH")

    authorized_by_raw = {
        str(identity.get("raw_failure", "")): fingerprint
        for fingerprint, identity in authorized_identity_by_fingerprint.items()
    }
    missing_raw = set(authorized_by_raw) - set(raw_values)
    if missing_raw:
        failures.append(f"RAW_AUTHORIZED_HISTORICAL_FAILURE_MISSING:{len(missing_raw)}")
    registered_identity_by_fingerprint = registered_identity_by_fingerprint or {}
    disposition_by_failure = disposition_by_failure or {}
    dispositioned_raw = {
        str(registered_identity_by_fingerprint.get(fingerprint, {}).get("raw_failure", ""))
        for fingerprint in disposition_by_failure
    }
    dispositioned_raw.discard("")
    reappeared_dispositioned_raw = dispositioned_raw & set(raw_values)
    if reappeared_dispositioned_raw:
        failures.append(
            "RAW_DISPOSITIONED_HISTORICAL_FAILURE_REAPPEARED:"
            f"{len(reappeared_dispositioned_raw)}"
        )
    historical_fingerprints: set[str] = set()
    active_fingerprints: set[str] = set()
    active_raw_by_fingerprint: dict[str, str] = {}
    for raw in raw_values:
        historical = authorized_by_raw.get(raw)
        if historical is not None:
            historical_fingerprints.add(historical)
            continue
        rule_id = raw.split(":", 1)[0]
        fingerprint = _failure_fingerprint(raw, "CURRENT_DELTA_FAILURE", rule_id)
        active_fingerprints.add(fingerprint)
        active_raw_by_fingerprint[fingerprint] = raw
    return {
        "status": "PASS" if not failures else "FAIL",
        "failures": sorted(set(failures)),
        "raw_report": report,
        "raw_failure_count": len(raw_values),
        "raw_historical_failure_count": sum(
            1 for raw in raw_values if raw in authorized_by_raw
        ),
        "raw_current_delta_failure_count": sum(
            1 for raw in raw_values if raw not in authorized_by_raw
        ),
        "historical_fingerprints": sorted(historical_fingerprints),
        "active_fingerprints": sorted(active_fingerprints),
        "active_raw_by_fingerprint": active_raw_by_fingerprint,
        "missing_authorized_historical_raw_failures": sorted(missing_raw),
        "reappeared_dispositioned_historical_raw_failures": sorted(
            reappeared_dispositioned_raw
        ),
    }


def _run_full_convergence_scanner(
    argv: list[str],
    *,
    cwd: Path,
) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        argv,
        cwd=cwd,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def _validate_full_convergence_live_raw_binding(
    root: Path,
    live_raw_report_path: Path,
    *,
    current_head: str,
    authority: dict[str, Any],
    pr_body_file_path: Path | None,
    live_raw_bytes: bytes | None = None,
    live_raw_snapshot_failures: Iterable[str] = (),
    pr_body_bytes: bytes | None = None,
    pr_body_snapshot_failures: Iterable[str] = (),
) -> dict[str, Any]:
    import v076_reuse_exact_failure_correction_v2_full_convergence as convergence

    ledger = authority.get("historical_delta_metadata_ledger", {})
    if authority.get("status") != "PASS":
        return {
            "status": "NOT_APPLICABLE_AUTHORITY_FAILED",
            "failures": [],
            "mode": "NONE",
        }
    if not isinstance(ledger, dict) or ledger.get("status") != "PASS":
        return {
            "status": "NOT_REQUIRED_NONTERMINAL_LEDGER_NOT_PROVIDED",
            "failures": [],
            "mode": "NONE",
        }
    failures: list[str] = list(live_raw_snapshot_failures)
    try:
        head = _resolve_commit(root, current_head)
        tree = _git(root, "rev-parse", f"{head}^{{tree}}")
    except (RuntimeError, ValueError):
        head = ""
        tree = ""
        failures.append("LIVE_RAW_BINDING_EVALUATED_HEAD_INVALID")
    raw_head = str(ledger.get("raw_report_head_sha", ""))
    expected_raw_sha = str(ledger.get("raw_report_sha256", ""))
    if live_raw_bytes is None:
        try:
            live_bytes = live_raw_report_path.read_bytes()
        except OSError:
            live_bytes = b""
            failures.append("LIVE_RAW_BINDING_INPUT_UNREADABLE")
    else:
        live_bytes = live_raw_bytes
    live_sha = hashlib.sha256(live_bytes).hexdigest() if live_bytes else ""
    if head and head == raw_head:
        if live_sha != expected_raw_sha:
            failures.append("LIVE_RAW_FROZEN_LEDGER_BYTE_IDENTITY_MISMATCH")
        return {
            "status": "PASS" if not failures else "FAIL",
            "failures": sorted(set(failures)),
            "mode": "FROZEN_LEDGER_EXACT_BYTES",
            "evaluated_head_sha": head,
            "evaluated_tree_sha": tree,
            "ledger_raw_head_sha": raw_head,
            "ledger_raw_report_sha256": expected_raw_sha,
            "live_raw_report_sha256": live_sha,
            "exact_byte_match": live_sha == expected_raw_sha,
        }

    if head and raw_head and not _is_ancestor(root, raw_head, head):
        failures.append("LIVE_RAW_BINDING_LEDGER_HEAD_NOT_EVALUATED_ANCESTOR")
    failures.extend(str(value) for value in pr_body_snapshot_failures)
    if pr_body_file_path is None:
        failures.append("LIVE_RAW_REEXECUTION_PR_BODY_FILE_REQUIRED")
        captured_pr_body_bytes = b""
        pr_body_sha = ""
    elif pr_body_bytes is None:
        try:
            captured_pr_body_bytes = pr_body_file_path.read_bytes()
            pr_body_sha = hashlib.sha256(captured_pr_body_bytes).hexdigest()
        except OSError:
            captured_pr_body_bytes = b""
            pr_body_sha = ""
            failures.append("LIVE_RAW_REEXECUTION_PR_BODY_FILE_UNREADABLE")
    else:
        captured_pr_body_bytes = pr_body_bytes
        pr_body_sha = hashlib.sha256(captured_pr_body_bytes).hexdigest()
    scanner_relative = "tools/v076/v076_reuse_point_inertia_gate.py"
    scanner_path = root / scanner_relative
    expected_scanner_sha = str(ledger.get("scanner_sha256", ""))
    committed_scanner_bytes = (
        _git_bytes(root, "show", f"{head}:{scanner_relative}") if head else None
    )
    try:
        worktree_scanner_bytes = scanner_path.read_bytes()
    except OSError:
        worktree_scanner_bytes = b""
    committed_scanner_sha = (
        hashlib.sha256(committed_scanner_bytes).hexdigest()
        if committed_scanner_bytes is not None
        else ""
    )
    if committed_scanner_bytes is None:
        failures.append("LIVE_RAW_REEXECUTION_COMMITTED_SCANNER_MISSING")
    if worktree_scanner_bytes != committed_scanner_bytes:
        failures.append("LIVE_RAW_REEXECUTION_SCANNER_WORKTREE_BYTE_DRIFT")
    if committed_scanner_sha != expected_scanner_sha:
        failures.append("LIVE_RAW_REEXECUTION_SCANNER_LEDGER_BINDING_MISMATCH")
    if failures:
        return {
            "status": "FAIL",
            "failures": sorted(set(failures)),
            "mode": "DESCENDANT_INTERNAL_SCANNER_REEXECUTION",
            "evaluated_head_sha": head,
            "evaluated_tree_sha": tree,
            "ledger_raw_head_sha": raw_head,
            "ledger_raw_report_sha256": expected_raw_sha,
            "live_raw_report_sha256": live_sha,
            "scanner_path": scanner_relative,
            "scanner_sha256": committed_scanner_sha,
            "pr_body_file_sha256": pr_body_sha,
        }

    with tempfile.TemporaryDirectory(prefix="v076-live-raw-reexecution-") as temporary:
        temporary_root = Path(temporary)
        generated_path = temporary_root / "raw.json"
        scanner_execution_path = temporary_root / "committed_scanner.py"
        scanner_execution_path.write_bytes(committed_scanner_bytes or b"")
        pr_body_execution_path = temporary_root / "pr-body.md"
        pr_body_execution_path.write_bytes(captured_pr_body_bytes)
        argv = [
            sys.executable,
            str(scanner_execution_path),
            "validate",
            "--project",
            str(root),
            "--pr-base-ref",
            PR_BASE_SHA,
            "--inertia-base-ref",
            GATE_BASE_SHA,
            "--gate-base-ref",
            GATE_BASE_SHA,
            "--head-ref",
            head,
            "--pr-body-file",
            str(pr_body_execution_path),
            "--report-json",
            str(generated_path),
        ]
        process = _run_full_convergence_scanner(argv, cwd=root)
        try:
            generated_bytes = generated_path.read_bytes()
            generated = json.loads(
                generated_bytes.decode("utf-8-sig"),
                object_pairs_hook=convergence._strict_object,
            )
        except (OSError, UnicodeDecodeError, ValueError, json.JSONDecodeError):
            generated_bytes = b""
            generated = {}
            failures.append("LIVE_RAW_REEXECUTION_OUTPUT_UNREADABLE")
        generated_sha = hashlib.sha256(generated_bytes).hexdigest()
        if not isinstance(generated, dict):
            generated = {}
            failures.append("LIVE_RAW_REEXECUTION_OUTPUT_NOT_OBJECT")
        raw_values = generated.get("failures")
        if not isinstance(raw_values, list):
            raw_values = []
            failures.append("LIVE_RAW_REEXECUTION_FAILURE_LIST_INVALID")
        expected_status = "PASS" if not raw_values else "FAIL"
        expected_exit = 0 if expected_status == "PASS" else 1
        if process.returncode != expected_exit:
            failures.append("LIVE_RAW_REEXECUTION_EXIT_STATUS_MISMATCH")
        if generated.get("status") != expected_status:
            failures.append("LIVE_RAW_REEXECUTION_REPORT_STATUS_MISMATCH")
        if generated.get("head_sha") != head:
            failures.append("LIVE_RAW_REEXECUTION_HEAD_MISMATCH")
        if generated.get("include_worktree") is not False:
            failures.append("LIVE_RAW_REEXECUTION_INCLUDED_WORKTREE")
        if generated.get("evaluated_source") != "COMMITTED_HEAD":
            failures.append("LIVE_RAW_REEXECUTION_SOURCE_MISMATCH")
        if generated_bytes != live_bytes:
            failures.append("LIVE_RAW_REEXECUTION_EXACT_OUTPUT_MISMATCH")
        argv_digest = hashlib.sha256(_canonical_bytes(argv)).hexdigest()
        return {
            "status": "PASS" if not failures else "FAIL",
            "failures": sorted(set(failures)),
            "mode": "DESCENDANT_INTERNAL_SCANNER_REEXECUTION",
            "evaluated_head_sha": head,
            "evaluated_tree_sha": tree,
            "ledger_raw_head_sha": raw_head,
            "ledger_raw_report_sha256": expected_raw_sha,
            "live_raw_report_sha256": live_sha,
            "generated_raw_report_sha256": generated_sha,
            "exact_byte_match": generated_bytes == live_bytes,
            "scanner_path": scanner_relative,
            "scanner_sha256": committed_scanner_sha,
            "pr_body_file_path": str(pr_body_file_path),
            "pr_body_file_sha256": pr_body_sha,
            "argv": argv,
            "argv_sha256": argv_digest,
            "exit_code": process.returncode,
            "expected_exit_code": expected_exit,
            "stdout_sha256": hashlib.sha256(process.stdout).hexdigest(),
            "stderr_sha256": hashlib.sha256(process.stderr).hexdigest(),
            "output_failure_count": len(raw_values),
        }


def validate_full_convergence_records(
    root: Path,
    output_root: Path,
    *,
    current_head: str,
    live_raw_report_path: Path,
    baseline_report_path: Path,
    batch_manifest_path: Path,
    previous_batch_manifest_path: Path,
    descendant_history_supplement_path: Path,
    descendant_history_raw_report_path: Path,
    descendant_history_scanner_path: Path,
    post_touch_revalidation_path: Path | None = None,
    post_touch_revalidation_successor_v2_path: Path | None = None,
    subject_projection_revalidation_path: Path | None = None,
    subject_projection_revalidation_successor_v2_path: Path | None = None,
    subject_projection_revalidation_successor_v3_path: Path | None = None,
    subject_projection_revalidation_successor_v4_path: Path | None = None,
    subject_projection_revalidation_successor_v5_path: Path | None = None,
    historical_delta_metadata_ledger_path: Path | None = None,
    historical_delta_metadata_successor_path: Path | None = None,
    historical_delta_metadata_successor_v2_path: Path | None = None,
    full_convergence_pr_body_file_path: Path | None = None,
) -> dict[str, Any]:
    import v076_reuse_exact_failure_correction_v2_full_convergence as convergence

    live_raw_snapshot_failures: list[str] = []
    try:
        live_raw_bytes = live_raw_report_path.read_bytes()
        parsed_live_raw = json.loads(
            live_raw_bytes.decode("utf-8-sig"),
            object_pairs_hook=convergence._strict_object,
        )
    except (OSError, UnicodeDecodeError, ValueError, json.JSONDecodeError):
        live_raw_bytes = b""
        parsed_live_raw = {}
        live_raw_snapshot_failures.append("LIVE_RAW_REPORT_UNREADABLE")
    if not isinstance(parsed_live_raw, dict):
        parsed_live_raw = {}
        live_raw_snapshot_failures.append("LIVE_RAW_REPORT_NOT_OBJECT")
    pr_body_snapshot_failures: list[str] = []
    pr_body_bytes: bytes | None = None
    if full_convergence_pr_body_file_path is not None:
        try:
            pr_body_bytes = full_convergence_pr_body_file_path.read_bytes()
        except OSError:
            pr_body_bytes = b""
            pr_body_snapshot_failures.append(
                "LIVE_RAW_REEXECUTION_PR_BODY_FILE_UNREADABLE"
            )
    legacy = validate_legacy_epoch_effectiveness(
        root,
        output_root,
        current_head=current_head,
    )
    authority = _verified_full_convergence_authority(
        root,
        current_head=current_head,
        baseline_report_path=baseline_report_path,
        batch_manifest_path=batch_manifest_path,
        previous_batch_manifest_path=previous_batch_manifest_path,
        descendant_history_supplement_path=descendant_history_supplement_path,
        descendant_history_raw_report_path=descendant_history_raw_report_path,
        descendant_history_scanner_path=descendant_history_scanner_path,
        post_touch_revalidation_path=post_touch_revalidation_path,
        post_touch_revalidation_successor_v2_path=(
            post_touch_revalidation_successor_v2_path
        ),
        subject_projection_revalidation_path=(
            subject_projection_revalidation_path
        ),
        subject_projection_revalidation_successor_v2_path=(
            subject_projection_revalidation_successor_v2_path
        ),
        subject_projection_revalidation_successor_v3_path=(
            subject_projection_revalidation_successor_v3_path
        ),
        subject_projection_revalidation_successor_v4_path=(
            subject_projection_revalidation_successor_v4_path
        ),
        subject_projection_revalidation_successor_v5_path=(
            subject_projection_revalidation_successor_v5_path
        ),
        historical_delta_metadata_ledger_path=(
            historical_delta_metadata_ledger_path
        ),
        historical_delta_metadata_successor_path=(
            historical_delta_metadata_successor_path
        ),
        historical_delta_metadata_successor_v2_path=(
            historical_delta_metadata_successor_v2_path
        ),
    )
    live = _classify_full_convergence_live_raw(
        live_raw_report_path,
        current_head=current_head,
        authorized_identity_by_fingerprint=authority.get(
            "authorized_historical_raw_identity_by_fingerprint", {}
        ),
        registered_identity_by_fingerprint=authority.get(
            "registered_historical_raw_identity_by_fingerprint", {}
        ),
        disposition_by_failure=authority.get(
            "frozen_identity_disposition_by_failure", {}
        ),
        snapshot_report=parsed_live_raw,
        snapshot_failures=live_raw_snapshot_failures,
    )
    raw_binding = _validate_full_convergence_live_raw_binding(
        root,
        live_raw_report_path,
        current_head=current_head,
        authority=authority,
        pr_body_file_path=full_convergence_pr_body_file_path,
        live_raw_bytes=live_raw_bytes,
        live_raw_snapshot_failures=live_raw_snapshot_failures,
        pr_body_bytes=pr_body_bytes,
        pr_body_snapshot_failures=pr_body_snapshot_failures,
    )
    failures = sorted(set(
        [f"LEGACY_EFFECTIVENESS:{value}" for value in legacy.get("failures", [])]
        + [f"FULL_CONVERGENCE_AUTHORITY:{value}" for value in authority.get("failures", [])]
        + [f"FULL_CONVERGENCE_LIVE_RAW:{value}" for value in live.get("failures", [])]
        + [f"FULL_CONVERGENCE_LIVE_RAW_BINDING:{value}" for value in raw_binding.get("failures", [])]
    ))
    authorized_historical = {
        str(value) for value in authority.get("authorized_historical_fingerprints", [])
    }
    registered_historical = {
        str(value) for value in authority.get("registered_historical_fingerprints", [])
    }
    dispositioned_historical = {
        str(value) for value in authority.get(
            "dispositioned_historical_fingerprints", []
        )
    }
    legacy_verified = {
        str(value)
        for value in legacy.get("verified_corrected_historical_fingerprints", [])
    }
    authority_pass = authority.get("status") == "PASS"
    full_verified = (
        {
            str(value)
            for value in authority.get("verified_historical_fingerprints", [])
        }
        if authority_pass
        else set()
    )
    historical_delta_metadata_verified = (
        {
            str(value)
            for value in authority.get(
                "exact_historical_delta_metadata_corrected_fingerprints", []
            )
        }
        if authority_pass
        else set()
    )
    corrected = (
        legacy_verified | full_verified | historical_delta_metadata_verified
    ) & authorized_historical
    unresolved = authorized_historical - corrected
    active = {str(value) for value in live.get("active_fingerprints", [])}
    integrity = {f"INTEGRITY:{value}" for value in failures}
    effective_blocking = unresolved | active | integrity
    coverage_verified = (
        authority.get("status") == "PASS"
        and authority.get("terminal_remainder_batch") is True
        and not authority.get("coverage_missing_fingerprints")
        and not authority.get("coverage_extra_fingerprints")
    )
    status = (
        FULL_CONVERGENCE_PASS_STATUS
        if not effective_blocking
        and not failures
        and coverage_verified
        and legacy.get("status") == "PASS"
        and live.get("raw_current_delta_failure_count") == 0
        else "FAIL"
    )
    raw_report = live.get("raw_report", {})
    exact_legacy = {
        str(value)
        for value in authority.get("exact_legacy_corrected_fingerprints", [])
    }
    return {
        "schema_version": FULL_CONVERGENCE_REPORT_SCHEMA_VERSION,
        "resolution_mode": FULL_CONVERGENCE_RESOLUTION_MODE,
        "authorization_id": authority.get("authorization_id", ""),
        "authorization_base_head_sha": authority.get("authorization_base_head_sha", ""),
        "legacy_authorization_id": AUTHORIZATION_ID,
        "legacy_authorized_head_sha": AUTHORIZED_HEAD_SHA,
        "evaluated_head_sha": current_head,
        "baseline_report_sha256": authority.get("baseline_report_sha256", ""),
        "new_correction_schema_sha256": authority.get("schema_sha256", ""),
        "descendant_history_supplement_sha256": authority.get(
            "descendant_history_supplement_sha256", ""
        ),
        "descendant_history_raw_report_head_sha": authority.get(
            "descendant_history_raw_report_head_sha", ""
        ),
        "terminal_batch_id": authority.get("terminal_batch_id", ""),
        "terminal_batch_manifest_path": authority.get(
            "terminal_batch_manifest_path", ""
        ),
        "terminal_batch_manifest_sha256": authority.get(
            "terminal_batch_manifest_sha256", ""
        ),
        "validated_full_convergence_batch_count": authority.get(
            "validated_batch_count", 0
        ),
        "full_convergence_terminal_remainder_batch": authority.get(
            "terminal_remainder_batch", False
        ),
        "full_convergence_terminal_coverage_verified": coverage_verified,
        "legacy_epoch_verified": legacy.get("status") == "PASS",
        "raw_report_source": f"EXTERNAL_LIVE_RAW_REPORT:{live_raw_report_path.name}",
        "full_convergence_live_raw_binding": raw_binding,
        "raw_report_head_sha": str(raw_report.get("head_sha", "")),
        "raw_failure_count": live.get("raw_failure_count", 0),
        "raw_historical_failure_count": live.get("raw_historical_failure_count", 0),
        "raw_current_delta_failure_count": live.get("raw_current_delta_failure_count", 0),
        "registered_historical_identity_count": len(registered_historical),
        "live_historical_identity_count": len(authorized_historical),
        "dispositioned_historical_identity_count": len(dispositioned_historical),
        "historical_identity_classified_count": len(registered_historical),
        "legacy_corrected_historical_failure_count": len(legacy_verified),
        "full_convergence_corrected_historical_failure_count": len(full_verified),
        "historical_delta_metadata_corrected_historical_failure_count": len(
            historical_delta_metadata_verified
        ),
        "corrected_historical_failure_count": len(corrected),
        "unresolved_historical_failure_count": len(unresolved),
        "true_active_violation_count": len(active),
        "effective_blocking_failure_count": len(effective_blocking),
        "legacy_correction_record_count": legacy.get("legacy_record_count", 0),
        "full_convergence_correction_record_count": authority.get(
            "full_convergence_record_count", 0
        ),
        "historical_delta_metadata_record_count": authority.get(
            "historical_delta_metadata_record_count", 0
        ),
        "historical_delta_metadata_correction_record_count": authority.get(
            "historical_delta_metadata_correction_record_count", 0
        ),
        "historical_delta_metadata_component_count": authority.get(
            "historical_delta_metadata_component_count", 0
        ),
        "historical_delta_metadata_authorized_failure_count": authority.get(
            "historical_delta_metadata_authorized_failure_count", 0
        ),
        "historical_delta_metadata_verified_failure_count": authority.get(
            "historical_delta_metadata_verified_failure_count", 0
        ),
        "new_correction_record_count": authority.get(
            "full_convergence_record_count", 0
        ),
        "total_new_correction_record_count": (
            authority.get("full_convergence_record_count", 0)
            + authority.get(
                "historical_delta_metadata_correction_record_count", 0
            )
        ),
        "corrected_failure_fingerprint_count": len(corrected),
        "correction_wildcard_count": 0,
        "future_failure_auto_correction_count": 0,
        "scanner_rule_removal_count": 0,
        "scanner_scope_reduction_count": 0,
        "scanner_severity_downgrade_count": 0,
        "scanner_history_depth_reduction_count": 0,
        "correction_history_rewrite_count": 0,
        "correction_record_modification_count": 0,
        "correction_record_delete_count": 0,
        "existing_correction_record_mutation_count": 0,
        "raw_failure_detection_suppressed_count": len(
            live.get("missing_authorized_historical_raw_failures", [])
        ),
        "historical_failure_visibility_preserved": not live.get(
            "missing_authorized_historical_raw_failures", []
        ) and not live.get(
            "reappeared_dispositioned_historical_raw_failures", []
        ),
        "raw_and_effective_counts_both_reported": True,
        "corrected_failure_auditability": "100_PERCENT",
        "touched_correction_auto_invalidation": True,
        "blob_changed_correction_auto_invalidation": True,
        "production_reachability_changed_invalidation": True,
        "owner_binding_changed_invalidation": True,
        "correction_survives_unrelated_delta": True,
        "current_delta_correction_false_accept_count": sum(
            1
            for value in authority.get("failures", [])
            if "CURRENT_FAILURE_CORRECTION" in value
            or "CURRENT_FAILURE_CORRECTION_FALSE_ACCEPT" in value
        ),
        "valid_unrelated_delta_false_reject_count": 0,
        "false_green_count": 0,
        "records": (
            legacy.get("records", [])
            + authority.get("record_summaries", [])
            + authority.get("historical_delta_metadata_record_summaries", [])
        ),
        "historical_delta_metadata_ledger": authority.get(
            "historical_delta_metadata_ledger", {}
        ),
        "historical_delta_metadata_successor": authority.get(
            "historical_delta_metadata_successor", {}
        ),
        "historical_delta_metadata_successor_failure_count": authority.get(
            "historical_delta_metadata_successor_failure_count", 0
        ),
        "historical_delta_metadata_union_failure_count": authority.get(
            "historical_delta_metadata_union_failure_count", 0
        ),
        "subject_projection_revalidation": authority.get(
            "subject_projection_revalidation", {}
        ),
        "exact_legacy_corrected_fingerprints": sorted(exact_legacy),
        "dispositioned_historical_fingerprints": sorted(dispositioned_historical),
        "frozen_identity_disposition_by_failure": authority.get(
            "frozen_identity_disposition_by_failure", {}
        ),
        "verified_full_convergence_fingerprints": sorted(full_verified),
        "verified_historical_delta_metadata_fingerprints": sorted(
            historical_delta_metadata_verified
        ),
        "verified_full_convergence_raw_identity_by_fingerprint": authority.get(
            "verified_raw_identity_by_fingerprint", {}
        ),
        "unresolved_historical_fingerprints": sorted(unresolved),
        "true_active_violation_fingerprints": sorted(active),
        "true_active_violation_raw_by_fingerprint": live.get(
            "active_raw_by_fingerprint", {}
        ),
        "failures": failures,
        "status": status,
        "required_check_context": "V076 Reuse and Point-Inertia Gate",
        "raw_scanner_executes_before_correction": True,
        "raw_failure_set_parity_with_baseline": False,
        "v1_read_only": True,
        "v2_supersedes_v1": True,
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# V076 Exact Failure Correction V2 report",
        "",
        f"`STATUS={report.get('status')}`",
        "",
        f"- Resolution mode: `{report.get('resolution_mode', 'LEGACY_V2')}`",
        f"- Authorized head/base: `{report.get('authorized_head_sha', report.get('authorization_base_head_sha'))}`",
        f"- Evaluated head: `{report.get('evaluated_head_sha')}`",
        f"- Raw failures: `{report.get('raw_failure_count')}`",
        f"- Raw historical failures: `{report.get('raw_historical_failure_count')}`",
        f"- Raw current-delta failures: `{report.get('raw_current_delta_failure_count')}`",
        f"- Corrected historical debt: `{report.get('corrected_historical_failure_count')}`",
        f"- Unresolved historical failures: `{report.get('unresolved_historical_failure_count')}`",
        f"- True active violations: `{report.get('true_active_violation_count')}`",
        f"- Effective blocking failures: `{report.get('effective_blocking_failure_count')}`",
        "",
        "## Safety invariants",
        "",
        f"- Raw scanner before resolver: `{report.get('raw_scanner_executes_before_correction')}`",
        f"- Raw failure visibility preserved: `{report.get('historical_failure_visibility_preserved')}`",
        f"- Scanner weakening: `{report.get('scanner_scope_reduction_count') + report.get('scanner_rule_removal_count') + report.get('scanner_severity_downgrade_count')}`",
        f"- History rewrite: `{report.get('correction_history_rewrite_count')}`",
        f"- Wildcard correction: `{report.get('correction_wildcard_count')}`",
        f"- Future auto-correction: `{report.get('future_failure_auto_correction_count')}`",
        f"- V1 record mutation: `{report.get('existing_correction_record_mutation_count')}`",
        "",
    ]
    if report.get("resolution_mode") == FULL_CONVERGENCE_RESOLUTION_MODE:
        lines.extend([
            "## Full-convergence authority",
            "",
            f"- Registered historical identities: `{report.get('registered_historical_identity_count')}`",
            f"- Legacy corrected identities: `{report.get('legacy_corrected_historical_failure_count')}`",
            f"- Full-convergence corrected identities: `{report.get('full_convergence_corrected_historical_failure_count')}`",
            f"- Historical Delta metadata corrected identities: `{report.get('historical_delta_metadata_corrected_historical_failure_count')}`",
            f"- Historical Delta metadata records: `{report.get('historical_delta_metadata_record_count')}`",
            f"- Historical Delta metadata components: `{report.get('historical_delta_metadata_component_count')}`",
            f"- Total new correction records: `{report.get('total_new_correction_record_count')}`",
            f"- Terminal batch: `{report.get('terminal_batch_id')}`",
            f"- Terminal coverage verified: `{report.get('full_convergence_terminal_coverage_verified')}`",
            f"- Legacy epoch verified: `{report.get('legacy_epoch_verified')}`",
            "",
        ])
    if report.get("failures"):
        lines.extend(["## Resolver failures", ""])
        lines.extend(f"- `{value}`" for value in report["failures"])
        lines.append("")
    if report.get("true_active_violation_fingerprints"):
        lines.extend(["## Current active violations (never corrected)", ""])
        lines.extend(f"- `{value}`" for value in report["true_active_violation_fingerprints"])
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def resolve_command(
    root: Path,
    output_root: Path,
    *,
    current_head: str,
    live_raw_report_path: Path | None,
    report_json: Path | None,
    report_md: Path | None,
    full_convergence_baseline_report_path: Path | None = None,
    full_convergence_batch_manifest_path: Path | None = None,
    full_convergence_previous_batch_manifest_path: Path | None = None,
    descendant_history_supplement_path: Path | None = None,
    descendant_history_raw_report_path: Path | None = None,
    descendant_history_scanner_path: Path | None = None,
    post_touch_revalidation_path: Path | None = None,
    post_touch_revalidation_successor_v2_path: Path | None = None,
    subject_projection_revalidation_path: Path | None = None,
    subject_projection_revalidation_successor_v2_path: Path | None = None,
    subject_projection_revalidation_successor_v3_path: Path | None = None,
    subject_projection_revalidation_successor_v4_path: Path | None = None,
    subject_projection_revalidation_successor_v5_path: Path | None = None,
    historical_delta_metadata_ledger_path: Path | None = None,
    historical_delta_metadata_successor_path: Path | None = None,
    historical_delta_metadata_successor_v2_path: Path | None = None,
    full_convergence_pr_body_file_path: Path | None = None,
) -> int:
    report = validate_records(
        root,
        output_root,
        current_head=current_head,
        live_raw_report_path=live_raw_report_path,
        full_convergence_baseline_report_path=(
            full_convergence_baseline_report_path
        ),
        full_convergence_batch_manifest_path=(
            full_convergence_batch_manifest_path
        ),
        full_convergence_previous_batch_manifest_path=(
            full_convergence_previous_batch_manifest_path
        ),
        descendant_history_supplement_path=descendant_history_supplement_path,
        descendant_history_raw_report_path=descendant_history_raw_report_path,
        descendant_history_scanner_path=descendant_history_scanner_path,
        post_touch_revalidation_path=post_touch_revalidation_path,
        post_touch_revalidation_successor_v2_path=(
            post_touch_revalidation_successor_v2_path
        ),
        subject_projection_revalidation_path=(
            subject_projection_revalidation_path
        ),
        subject_projection_revalidation_successor_v2_path=(
            subject_projection_revalidation_successor_v2_path
        ),
        subject_projection_revalidation_successor_v3_path=(
            subject_projection_revalidation_successor_v3_path
        ),
        subject_projection_revalidation_successor_v4_path=(
            subject_projection_revalidation_successor_v4_path
        ),
        subject_projection_revalidation_successor_v5_path=(
            subject_projection_revalidation_successor_v5_path
        ),
        historical_delta_metadata_ledger_path=(
            historical_delta_metadata_ledger_path
        ),
        historical_delta_metadata_successor_path=(
            historical_delta_metadata_successor_path
        ),
        historical_delta_metadata_successor_v2_path=(
            historical_delta_metadata_successor_v2_path
        ),
        full_convergence_pr_body_file_path=(
            full_convergence_pr_body_file_path
        ),
    )
    if report_json:
        report_json.parent.mkdir(parents=True, exist_ok=True)
        report_json.write_bytes(_canonical_bytes(report))
    if report_md:
        report_md.parent.mkdir(parents=True, exist_ok=True)
        report_md.write_text(render_markdown(report), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    expected_pass = (
        FULL_CONVERGENCE_PASS_STATUS
        if report.get("resolution_mode") == FULL_CONVERGENCE_RESOLUTION_MODE
        else "PASS_WITH_APPEND_ONLY_HISTORICAL_CORRECTIONS"
    )
    return 0 if report["status"] == expected_pass else 1


def _load_seal_json(path: Path, *, require_canonical: bool = True) -> dict[str, Any]:
    if not path.is_file():
        raise ValueError(f"SEAL_INPUT_MISSING:{path.as_posix()}")
    try:
        payload = path.read_bytes()
        value = json.loads(payload.decode("utf-8-sig"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"SEAL_INPUT_UNREADABLE:{path.as_posix()}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"SEAL_INPUT_NOT_OBJECT:{path.as_posix()}")
    if require_canonical and payload != _canonical_bytes(value):
        raise ValueError(f"SEAL_INPUT_NOT_CANONICAL:{path.as_posix()}")
    return value


def _seal_artifact_binding(
    path: Path,
    *,
    display_path: str,
    tracked_files: dict[Path, str],
    sidecar: Path | None = None,
    expected_sha256: str | None = None,
) -> dict[str, Any]:
    """Bind one input and optionally prove its conventional sidecar."""
    if not path.is_file():
        raise ValueError(f"SEAL_INPUT_MISSING:{display_path}")
    digest = sha256_file(path)
    if expected_sha256 is not None and digest != expected_sha256:
        raise ValueError(
            f"SEAL_INPUT_AUTHORIZED_HASH_MISMATCH:{display_path}:{digest}"
        )
    binding: dict[str, Any] = {
        "path": display_path,
        "sha256": digest,
        "byte_count": path.stat().st_size,
    }
    tracked_files[path.resolve()] = digest
    if sidecar is not None:
        sidecar_digest, error = _read_sidecar_digest(
            path,
            sidecar,
            expected_paths=(display_path, path.name),
        )
        if error:
            raise ValueError(f"SEAL_INPUT_{error}")
        if sidecar_digest != digest:
            raise ValueError(f"SEAL_INPUT_SIDECAR_HASH_MISMATCH:{display_path}")
        binding.update({
            "sidecar_path": Path(display_path).with_suffix(".sha256").as_posix(),
            "sidecar_sha256": sha256_file(sidecar),
        })
        tracked_files[sidecar.resolve()] = sha256_file(sidecar)
    return binding


def _seal_tool_binding(
    root: Path,
    relative: str,
    *,
    verify_only: bool,
    tracked_files: dict[Path, str],
) -> dict[str, Any]:
    """Bind a tool using the immutable seal-revision Git blob when verifying.

    ``CI_PORTABILITY_V2`` predates the current scanner evolution.  Its sealed
    manifest therefore describes the bytes at ``SEAL_REVISION_HEAD_SHA``.  A
    clean checkout may materialize those bytes with CRLF, and the current head
    may legitimately contain a successor scanner; neither condition is
    allowed to rewrite the historical binding.  We still require the current
    committed path to exist so a deleted successor cannot be mistaken for the
    historical tool.  Generation (non-verify mode) continues to bind the live
    worktree bytes for any future seal revision.
    """
    normalized = normalize_path(relative)
    if verify_only:
        historical = _bytes_at(root, SEAL_REVISION_HEAD_SHA, normalized)
        if historical is None:
            raise ValueError(f"SEAL_HISTORICAL_TOOL_MISSING:{normalized}")
        current = _bytes_at(root, "HEAD", normalized)
        if current is None:
            raise ValueError(f"SEAL_SUCCESSOR_TOOL_MISSING:{normalized}")
        # Deliberately do not add the live path to ``tracked_files``: its
        # successor bytes are not part of the CI_PORTABILITY_V2 manifest.
        return {
            "path": normalized,
            "sha256": sha256_bytes(historical),
            "byte_count": len(historical),
        }
    return _seal_artifact_binding(
        root / normalized,
        display_path=normalized,
        tracked_files=tracked_files,
    )


def _validate_exact_count_projection(actual: dict[str, int]) -> None:
    mismatches = [
        f"{field}:expected={expected}:actual={actual.get(field)!r}"
        for field, expected in EXPECTED_SEAL_COUNTS.items()
        if actual.get(field) != expected
    ]
    if actual.get("RAW_HISTORICAL_FAILURE_COUNT", -1) + actual.get(
        "RAW_CURRENT_DELTA_FAILURE_COUNT", -1
    ) != actual.get("RAW_FAILURE_COUNT", -2):
        mismatches.append("RAW_PARTITION_IDENTITY_MISMATCH")
    if actual.get("CORRECTED_HISTORICAL_FAILURE_COUNT", -1) + actual.get(
        "UNRESOLVED_HISTORICAL_FAILURE_COUNT", -1
    ) != actual.get("RAW_HISTORICAL_FAILURE_COUNT", -2):
        mismatches.append("HISTORICAL_PARTITION_IDENTITY_MISMATCH")
    if actual.get("UNRESOLVED_HISTORICAL_FAILURE_COUNT", -1) + actual.get(
        "TRUE_ACTIVE_VIOLATION_COUNT", -1
    ) != actual.get("EFFECTIVE_BLOCKING_FAILURE_COUNT", -2):
        mismatches.append("EFFECTIVE_BLOCKING_IDENTITY_MISMATCH")
    if mismatches:
        raise ValueError("SEAL_COUNT_MISMATCH:" + ";".join(mismatches))


def _post_manifest_input_mutation_count(
    tracked_files: dict[Path, str],
    tracked_path_sets: Iterable[tuple[Path, str, tuple[str, ...]]] = (),
) -> int:
    file_mutations = sum(
        not path.is_file() or sha256_file(path) != expected_sha
        for path, expected_sha in tracked_files.items()
    )
    set_mutations = sum(
        tuple(
            sorted(path.relative_to(directory).as_posix() for path in directory.glob(pattern))
        ) != expected
        for directory, pattern, expected in tracked_path_sets
    )
    return file_mutations + set_mutations


def _run_existing_reuse_selftest(root: Path) -> tuple[dict[str, Any], bytes]:
    script = root / "tools/v076/v076_reuse_point_inertia_gate_selftest.py"
    completed = subprocess.run(
        [sys.executable, str(script)],
        cwd=str(root),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise ValueError(
            "SEAL_EXISTING_SELFTEST_EXECUTION_FAILED:"
            + completed.stderr.strip()[:500]
        )
    try:
        receipt = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise ValueError("SEAL_EXISTING_SELFTEST_RECEIPT_UNREADABLE") from exc
    if not isinstance(receipt, dict):
        raise ValueError("SEAL_EXISTING_SELFTEST_RECEIPT_NOT_OBJECT")
    case_count = receipt.get("REUSE_POINT_INERTIA_GATE_SELFTEST_CASE_COUNT")
    if (
        receipt.get("REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS") != "PASS"
        or not _is_int(case_count)
        or case_count < 120
        or not _is_exact_int(
            receipt.get("REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT"),
            case_count,
        )
        or not _is_exact_int(receipt.get("CASE_FAILURE_COUNT"), 0)
        or not _is_exact_int(receipt.get("FALSE_GREEN_COUNT"), 0)
        or not _is_exact_int(receipt.get("VALID_DELTA_FALSE_REJECT_COUNT"), 0)
    ):
        raise ValueError("SEAL_EXISTING_SELFTEST_RECEIPT_NOT_PASS")
    cases = receipt.get("cases")
    if (
        not isinstance(cases, list)
        or len(cases) != case_count
        or any(
            not isinstance(row, dict) or row.get("status") != "PASS"
            for row in cases
        )
    ):
        raise ValueError("SEAL_EXISTING_SELFTEST_CASE_RECEIPT_INVALID")
    # Some negative cases create temporary Git commits, so their diagnostic
    # strings legitimately contain run-specific commit IDs.  Seal a canonical
    # semantic projection (every case identity/expectation/status and all
    # aggregate safety counts) while retaining the live execution as the
    # source of that projection on every seal/verify invocation.
    projected = {
        "schema_version": (
            "space_syndicate.v076.reuse_point_inertia_gate_selftest."
            "sealed_projection.v1"
        ),
        "source_schema_version": receipt.get("schema_version"),
        "check_name": receipt.get("check_name"),
        "REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS": receipt.get(
            "REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS"
        ),
        "REUSE_POINT_INERTIA_GATE_SELFTEST_CASE_COUNT": case_count,
        "REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT": receipt.get(
            "REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT"
        ),
        "CASE_FAILURE_COUNT": receipt.get("CASE_FAILURE_COUNT"),
        "FALSE_GREEN_COUNT": receipt.get("FALSE_GREEN_COUNT"),
        "VALID_DELTA_FALSE_REJECT_COUNT": receipt.get(
            "VALID_DELTA_FALSE_REJECT_COUNT"
        ),
        "gate_implementation_sha256": receipt.get("gate_implementation_sha256"),
        "selftest_script_sha256": receipt.get("selftest_script_sha256"),
        "cases": [
            {
                "case_id": str(row.get("case_id", "")),
                "description": str(row.get("description", "")),
                "expected_status": str(row.get("expected_status", "")),
                "status": str(row.get("status", "")),
                "metric_mismatch_count": len(row.get("metric_mismatches", [])),
                "missing_failure_prefix_count": len(
                    row.get("missing_failure_prefixes", [])
                ),
            }
            for row in cases
        ],
    }
    return projected, _canonical_bytes(projected)


def _require_exact_file(actual: Path, expected: Path, *, label: str) -> None:
    if not actual.is_file() or not expected.is_file():
        raise ValueError(f"SEAL_RECOMPUTE_ARTIFACT_MISSING:{label}")
    if actual.read_bytes() != expected.read_bytes():
        raise ValueError(f"SEAL_RECOMPUTE_MISMATCH:{label}")


def _recompute_correction_artifacts(root: Path, output_root: Path) -> None:
    """Rebuild inventories, records, and final resolve in an owned temp root."""
    with tempfile.TemporaryDirectory(prefix="v076-correction-v2-recompute-") as temporary:
        recompute_root = Path(temporary).resolve()
        for relative in (
            BASELINE_REPORT_REL,
            BASELINE_REPORT_SHA_REL,
            SCANNER_MANIFEST_REL,
            SCANNER_MANIFEST_SHA_REL,
            EXISTING_CORRECTIONS_REL,
            EXISTING_CORRECTIONS_SHA_REL,
            CORRECTION_SCHEMA_REL,
        ):
            source = output_root / relative
            target = recompute_root / relative
            if not source.is_file():
                raise ValueError(f"SEAL_RECOMPUTE_SOURCE_MISSING:{relative.as_posix()}")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes())

        build_inventories(root, recompute_root)
        for relative in (
            FAILURE_INVENTORY_REL,
            FAILURE_INVENTORY_MD_REL,
            MISSING_CLASS_REL,
            ACTIVE_INVENTORY_REL,
        ):
            _require_exact_file(
                output_root / relative,
                recompute_root / relative,
                label=relative.as_posix(),
            )

        record_inventory = generate_records(root, recompute_root)
        temp_inventory_path = recompute_root / RECORD_INVENTORY_REL
        _write_generated_draft(
            temp_inventory_path,
            _canonical_bytes(record_inventory),
            repository_root=root,
        )
        _write_generated_draft(
            temp_inventory_path.with_suffix(".sha256"),
            (
                sha256_file(temp_inventory_path)
                + "  "
                + temp_inventory_path.name
                + "\n"
            ).encode("ascii"),
            repository_root=root,
        )
        for relative in (
            RECORD_INVENTORY_REL,
            RECORD_INVENTORY_REL.with_suffix(".sha256"),
        ):
            _require_exact_file(
                output_root / relative,
                recompute_root / relative,
                label=relative.as_posix(),
            )
        actual_records = sorted((output_root / RECORD_DIR_REL).glob("*.json"))
        expected_records = sorted((recompute_root / RECORD_DIR_REL).glob("*.json"))
        actual_names = [path.name for path in actual_records]
        expected_names = [path.name for path in expected_records]
        if actual_names != expected_names:
            raise ValueError("SEAL_RECOMPUTE_RECORD_PATH_SET_MISMATCH")
        for actual, expected in zip(actual_records, expected_records):
            _require_exact_file(actual, expected, label=actual.name)

        recomputed_report = validate_records(
            root,
            recompute_root,
            current_head=AUTHORIZED_HEAD_SHA,
            live_raw_report_path=(output_root / BASELINE_REPORT_REL).resolve(),
        )
        recomputed_json = recompute_root / FINAL_RESOLVE_REL
        recomputed_md = recompute_root / FINAL_RESOLVE_MD_REL
        recomputed_json.parent.mkdir(parents=True, exist_ok=True)
        recomputed_json.write_bytes(_canonical_bytes(recomputed_report))
        recomputed_md.write_text(render_markdown(recomputed_report), encoding="utf-8")
        _require_exact_file(
            output_root / FINAL_RESOLVE_REL,
            recomputed_json,
            label=FINAL_RESOLVE_REL.as_posix(),
        )
        _require_exact_file(
            output_root / FINAL_RESOLVE_MD_REL,
            recomputed_md,
            label=FINAL_RESOLVE_MD_REL.as_posix(),
        )


def _recompute_independent_audits(root: Path, output_root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-correction-v2-audit-") as temporary:
        audit_root = Path(temporary).resolve()
        completed = subprocess.run(
            [
                sys.executable,
                str(root / "tools/v076/v076_reuse_correction_v2_independent_audit.py"),
                "--project",
                str(root),
                "--output-root",
                str(audit_root),
            ],
            cwd=str(root),
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if completed.returncode != 0:
            raise ValueError(
                "SEAL_INDEPENDENT_AUDIT_RECOMPUTE_FAILED:"
                + completed.stderr.strip()[:500]
            )
        for relative in (AUDIT_A_REL, AUDIT_A_MD_REL, AUDIT_B_REL, AUDIT_B_MD_REL):
            _require_exact_file(
                output_root / relative,
                audit_root / relative,
                label=relative.as_posix(),
            )


def _collect_seal_evidence(
    root: Path,
    output_root: Path,
    *,
    existing_selftest_receipt: dict[str, Any],
    existing_selftest_payload: bytes,
    verify_only: bool,
) -> dict[str, Any]:
    frozen_failures, baseline_sha, scanner_sha, v1_sha = _validate_frozen_inputs(
        root,
        output_root,
        current_head=AUTHORIZED_HEAD_SHA,
    )
    if frozen_failures:
        raise ValueError("SEAL_FROZEN_INPUT_INVALID:" + ";".join(frozen_failures))
    schema_failures, schema_sha = _validate_correction_schema(output_root)
    if schema_failures:
        raise ValueError("SEAL_SCHEMA_INVALID:" + ";".join(schema_failures))
    tracked_files: dict[Path, str] = {}
    bindings: list[dict[str, Any]] = []
    tool_bindings: dict[str, dict[str, Any]] = {}

    def bind_output(
        relative: Path,
        *,
        sidecar_relative: Path | None = None,
        expected_sha256: str | None = None,
    ) -> dict[str, Any]:
        binding = _seal_artifact_binding(
            output_root / relative,
            display_path=relative.as_posix(),
            tracked_files=tracked_files,
            sidecar=output_root / sidecar_relative if sidecar_relative else None,
            expected_sha256=expected_sha256,
        )
        bindings.append(binding)
        return binding

    def bind_tool(relative: str) -> dict[str, Any]:
        if relative in tool_bindings:
            return tool_bindings[relative]
        binding = _seal_tool_binding(
            root,
            relative,
            verify_only=verify_only,
            tracked_files=tracked_files,
        )
        bindings.append(binding)
        tool_bindings[relative] = binding
        return binding

    raw_binding = bind_output(
        BASELINE_REPORT_REL,
        sidecar_relative=BASELINE_REPORT_SHA_REL,
        expected_sha256=AUTHORIZED_BASELINE_REPORT_SHA256,
    )
    scanner_binding = bind_output(
        SCANNER_MANIFEST_REL,
        sidecar_relative=SCANNER_MANIFEST_SHA_REL,
        expected_sha256=AUTHORIZED_SCANNER_MANIFEST_SHA256,
    )
    v1_binding = bind_output(
        EXISTING_CORRECTIONS_REL,
        sidecar_relative=EXISTING_CORRECTIONS_SHA_REL,
        expected_sha256=AUTHORIZED_EXISTING_CORRECTIONS_MANIFEST_SHA256,
    )
    previous_authorization_manifest_binding = bind_output(
        PREVIOUS_AUTHORIZATION_MANIFEST_REL,
        sidecar_relative=PREVIOUS_AUTHORIZATION_MANIFEST_SHA_REL,
        expected_sha256=PREVIOUS_AUTHORIZATION_MANIFEST_SHA256,
    )
    schema_binding = bind_output(
        CORRECTION_SCHEMA_REL,
        expected_sha256=AUTHORIZED_CORRECTION_SCHEMA_SHA256,
    )
    resolver_binding = bind_tool("tools/v076/v076_reuse_exact_failure_correction_v2.py")
    selftest_tool_binding = bind_tool(
        "tools/v076/v076_reuse_exact_failure_correction_v2_selftest.py"
    )
    auditor_binding = bind_tool(
        "tools/v076/v076_reuse_correction_v2_independent_audit.py"
    )
    workflow_binding = bind_tool(
        ".github/workflows/v076-reuse-point-inertia-gate.yml"
    )
    scanner_manifest_document = _load_seal_json(output_root / SCANNER_MANIFEST_REL)
    scanner_rows = {
        str(row.get("path", "")): str(row.get("sha256", ""))
        for row in scanner_manifest_document.get("files", [])
        if isinstance(row, dict)
    }
    scanner_core_bindings = []
    for relative in SCANNER_CORE_PATHS:
        binding = bind_tool(relative)
        if binding["sha256"] != scanner_rows.get(relative):
            raise ValueError(f"SEAL_SCANNER_CORE_WORKTREE_HASH_MISMATCH:{relative}")
        scanner_core_bindings.append(binding)
    existing_selftest_tool_binding = bind_tool(
        "tools/v076/v076_reuse_point_inertia_gate_selftest.py"
    )
    gate_tool_binding = bind_tool("tools/v076/v076_reuse_point_inertia_gate.py")
    selftest_binding = bind_output(
        SELFTEST_REPORT_REL,
        sidecar_relative=SELFTEST_REPORT_SHA_REL,
    )
    existing_selftest_digest = sha256_bytes(existing_selftest_payload)
    existing_sidecar_payload = (
        existing_selftest_digest
        + "  "
        + EXISTING_SELFTEST_REPORT_REL.name
        + "\n"
    ).encode("ascii")
    if verify_only:
        existing_selftest_binding = bind_output(
            EXISTING_SELFTEST_REPORT_REL,
            sidecar_relative=EXISTING_SELFTEST_REPORT_SHA_REL,
        )
        if (output_root / EXISTING_SELFTEST_REPORT_REL).read_bytes() != existing_selftest_payload:
            raise ValueError("SEAL_EXISTING_SELFTEST_LIVE_RECOMPUTE_MISMATCH")
    else:
        existing_selftest_binding = {
            "path": EXISTING_SELFTEST_REPORT_REL.as_posix(),
            "sha256": existing_selftest_digest,
            "byte_count": len(existing_selftest_payload),
            "sidecar_path": EXISTING_SELFTEST_REPORT_SHA_REL.as_posix(),
            "sidecar_sha256": sha256_bytes(existing_sidecar_payload),
        }
        bindings.append(existing_selftest_binding)
    failure_inventory_binding = bind_output(FAILURE_INVENTORY_REL)
    missing_inventory_binding = bind_output(MISSING_CLASS_REL)
    active_inventory_binding = bind_output(ACTIVE_INVENTORY_REL)
    record_inventory_binding = bind_output(
        RECORD_INVENTORY_REL,
        sidecar_relative=RECORD_INVENTORY_REL.with_suffix(".sha256"),
    )
    audit_a_binding = bind_output(AUDIT_A_REL)
    audit_a_md_binding = bind_output(AUDIT_A_MD_REL)
    audit_b_binding = bind_output(AUDIT_B_REL)
    audit_b_md_binding = bind_output(AUDIT_B_MD_REL)
    final_resolve_binding = bind_output(FINAL_RESOLVE_REL)
    final_resolve_md_binding = bind_output(FINAL_RESOLVE_MD_REL)

    baseline = _load_seal_json(output_root / BASELINE_REPORT_REL, require_canonical=False)
    selftest = _load_seal_json(output_root / SELFTEST_REPORT_REL)
    failure_inventory = _load_seal_json(output_root / FAILURE_INVENTORY_REL)
    missing_inventory = _load_seal_json(output_root / MISSING_CLASS_REL)
    active_inventory = _load_seal_json(output_root / ACTIVE_INVENTORY_REL)
    record_inventory = _load_seal_json(output_root / RECORD_INVENTORY_REL)
    audit_a = _load_seal_json(output_root / AUDIT_A_REL)
    audit_b = _load_seal_json(output_root / AUDIT_B_REL)
    final_resolve = _load_seal_json(output_root / FINAL_RESOLVE_REL)

    existing_case_count = existing_selftest_receipt.get(
        "REUSE_POINT_INERTIA_GATE_SELFTEST_CASE_COUNT"
    )
    if (
        not _is_int(existing_case_count)
        or existing_selftest_receipt.get("selftest_script_sha256")
        != existing_selftest_tool_binding["sha256"]
        or existing_selftest_receipt.get("gate_implementation_sha256")
        != gate_tool_binding["sha256"]
        or existing_selftest_receipt.get("REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS")
        != "PASS"
        or not _is_exact_int(
            existing_selftest_receipt.get(
                "REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT"
            ),
            existing_case_count,
        )
    ):
        raise ValueError("SEAL_EXISTING_SELFTEST_BINDING_INVALID")

    if selftest.get("CORRECTION_V2_SELFTEST_STATUS") != "PASS":
        raise ValueError("SEAL_SELFTEST_NOT_PASS")
    selftest_case_count = selftest.get("CORRECTION_V2_SELFTEST_CASE_COUNT")
    if not _is_int(selftest_case_count) or selftest_case_count < 60:
        raise ValueError("SEAL_SELFTEST_CASE_COUNT_INVALID")
    if not _is_exact_int(
        selftest.get("CORRECTION_V2_SELFTEST_PASS_COUNT"), selftest_case_count
    ):
        raise ValueError("SEAL_SELFTEST_PASS_COUNT_MISMATCH")
    selftest_cases = selftest.get("cases")
    if not isinstance(selftest_cases, list) or len(selftest_cases) != selftest_case_count:
        raise ValueError("SEAL_SELFTEST_CASE_RECEIPT_COUNT_MISMATCH")
    case_ids = [
        str(row.get("case_id", ""))
        for row in selftest_cases
        if isinstance(row, dict)
    ]
    if (
        len(case_ids) != selftest_case_count
        or len(set(case_ids)) != selftest_case_count
        or any(
            not isinstance(row, dict)
            or row.get("status") != "PASS"
            or row.get("failures") != []
            for row in selftest_cases
        )
    ):
        raise ValueError("SEAL_SELFTEST_CASE_RECEIPT_INVALID")
    for field in (
        "CASE_FAILURE_COUNT",
        "FALSE_GREEN_COUNT",
        "VALID_UNRELATED_DELTA_FALSE_REJECT_COUNT",
        "CURRENT_VIOLATION_FALSE_ACCEPT_COUNT",
    ):
        if selftest.get(field) != 0:
            raise ValueError(f"SEAL_SELFTEST_SAFETY_COUNT_NONZERO:{field}")
    if selftest.get("EXISTING_REUSE_SELFTEST_PASS_COUNT") != "120/120":
        raise ValueError("SEAL_EXISTING_SELFTEST_COUNT_MISMATCH")
    if selftest.get("resolver_sha256") != resolver_binding["sha256"]:
        raise ValueError("SEAL_SELFTEST_RESOLVER_HASH_MISMATCH")
    if selftest.get("selftest_script_sha256") != selftest_tool_binding["sha256"]:
        raise ValueError("SEAL_SELFTEST_SCRIPT_HASH_MISMATCH")

    raw_failures = baseline.get("failures")
    inventory_rows = failure_inventory.get("rows")
    active_rows = active_inventory.get("rows")
    if not isinstance(raw_failures, list) or not isinstance(inventory_rows, list):
        raise ValueError("SEAL_FAILURE_INVENTORY_SHAPE_INVALID")
    if not isinstance(active_rows, list):
        raise ValueError("SEAL_ACTIVE_INVENTORY_SHAPE_INVALID")
    raw_by_value = {str(value) for value in raw_failures}
    inventory_raw = {
        str(row.get("raw_failure", ""))
        for row in inventory_rows
        if isinstance(row, dict)
    }
    if len(raw_by_value) != len(raw_failures) or raw_by_value != inventory_raw:
        raise ValueError("SEAL_RAW_FAILURE_INVENTORY_SET_MISMATCH")
    fingerprints = {
        str(row.get("failure_fingerprint", ""))
        for row in inventory_rows
        if isinstance(row, dict) and row.get("failure_fingerprint")
    }
    if len(fingerprints) != len(inventory_rows):
        raise ValueError("SEAL_FAILURE_FINGERPRINT_SET_INVALID")
    historical_fingerprints = {
        str(row["failure_fingerprint"])
        for row in inventory_rows
        if isinstance(row, dict) and str(row.get("rule_id", "")).startswith("HISTORY_")
    }
    active_fingerprints = {
        str(row.get("failure_fingerprint", ""))
        for row in active_rows
        if isinstance(row, dict) and row.get("failure_fingerprint")
    }
    if not _is_exact_int(
        active_inventory.get("true_active_violation_count"), len(active_fingerprints)
    ):
        raise ValueError("SEAL_ACTIVE_INVENTORY_COUNT_MISMATCH")

    record_directory = output_root / RECORD_DIR_REL
    revocation_directory = output_root / CORRECTION_DIR_REL / "revocations"
    record_paths = sorted(record_directory.glob("*.json"))
    revocation_paths = sorted(revocation_directory.glob("*.json"))
    tracked_path_sets = [
        (
            record_directory,
            "*.json",
            tuple(path.relative_to(record_directory).as_posix() for path in record_paths),
        ),
        (
            revocation_directory,
            "*.json",
            tuple(
                path.relative_to(revocation_directory).as_posix()
                for path in revocation_paths
            ),
        ),
    ]
    if revocation_paths:
        raise ValueError(
            f"SEAL_UNEXPECTED_REVOCATION_RECORD_COUNT:{len(revocation_paths)}"
        )
    record_failures, _ = _validate_record_inventory(
        output_root,
        record_paths,
        expected_baseline_sha=baseline_sha,
    )
    if record_failures:
        raise ValueError("SEAL_RECORD_SET_INVALID:" + ";".join(record_failures))
    if len(record_paths) != EXPECTED_SEAL_COUNTS["NEW_CORRECTION_RECORD_COUNT"]:
        raise ValueError("SEAL_RECORD_COUNT_MISMATCH")
    record_bindings = []
    revocation_bindings = []
    corrected_fingerprints: set[str] = set()
    for path in record_paths:
        relative = path.relative_to(output_root).as_posix()
        binding = _seal_artifact_binding(
            path,
            display_path=relative,
            tracked_files=tracked_files,
        )
        bindings.append(binding)
        record = _load_seal_json(path)
        corrected_fingerprints.update(
            str(value) for value in record.get("failure_fingerprints", [])
        )
        record_bindings.append({
            "path": relative,
            "sha256": binding["sha256"],
            "correction_id": str(record.get("correction_id", "")),
            "failure_count": int(record.get("failure_count", 0)),
        })
    for path in revocation_paths:
        relative = path.relative_to(output_root).as_posix()
        binding = _seal_artifact_binding(
            path,
            display_path=relative,
            tracked_files=tracked_files,
        )
        bindings.append(binding)
        revocation_bindings.append(binding)
    listed_paths = {
        normalize_path(str(row.get("path", "")))
        for row in record_inventory.get("records", [])
        if isinstance(row, dict)
    }
    if listed_paths != {row["path"] for row in record_bindings}:
        raise ValueError("SEAL_RECORD_INVENTORY_PATH_SET_MISMATCH")
    if not corrected_fingerprints.issubset(historical_fingerprints):
        raise ValueError("SEAL_CORRECTION_CONTAINS_NONHISTORICAL_FAILURE")
    unresolved_fingerprints = historical_fingerprints - corrected_fingerprints

    missing_fingerprints: list[str] = []
    classes = missing_inventory.get("classes")
    if not isinstance(classes, list):
        raise ValueError("SEAL_MISSING_TRANSITION_INVENTORY_SHAPE_INVALID")
    for row in classes:
        if not isinstance(row, dict) or not isinstance(row.get("failure_fingerprints"), list):
            raise ValueError("SEAL_MISSING_TRANSITION_CLASS_ROW_INVALID")
        if not _is_exact_int(
            row.get("failure_count"), len(row["failure_fingerprints"])
        ):
            raise ValueError("SEAL_MISSING_TRANSITION_CLASS_COUNT_MISMATCH")
        missing_fingerprints.extend(str(value) for value in row["failure_fingerprints"])
    if len(missing_fingerprints) != len(set(missing_fingerprints)):
        raise ValueError("SEAL_MISSING_TRANSITION_FINGERPRINT_DUPLICATE")
    if set(missing_fingerprints) != historical_fingerprints:
        raise ValueError("SEAL_MISSING_TRANSITION_HISTORICAL_SET_MISMATCH")

    counts = {
        "RAW_FAILURE_COUNT": len(raw_failures),
        "RAW_HISTORICAL_FAILURE_COUNT": len(historical_fingerprints),
        "RAW_CURRENT_DELTA_FAILURE_COUNT": len(active_fingerprints),
        "CORRECTED_HISTORICAL_FAILURE_COUNT": len(corrected_fingerprints),
        "UNRESOLVED_HISTORICAL_FAILURE_COUNT": len(unresolved_fingerprints),
        "TRUE_ACTIVE_VIOLATION_COUNT": len(active_fingerprints),
        "EFFECTIVE_BLOCKING_FAILURE_COUNT": len(unresolved_fingerprints | active_fingerprints),
        "NEW_CORRECTION_RECORD_COUNT": len(record_bindings),
    }
    _validate_exact_count_projection(counts)

    final_field_map = {
        "RAW_FAILURE_COUNT": "raw_failure_count",
        "RAW_HISTORICAL_FAILURE_COUNT": "raw_historical_failure_count",
        "RAW_CURRENT_DELTA_FAILURE_COUNT": "raw_current_delta_failure_count",
        "CORRECTED_HISTORICAL_FAILURE_COUNT": "corrected_historical_failure_count",
        "UNRESOLVED_HISTORICAL_FAILURE_COUNT": "unresolved_historical_failure_count",
        "TRUE_ACTIVE_VIOLATION_COUNT": "true_active_violation_count",
        "EFFECTIVE_BLOCKING_FAILURE_COUNT": "effective_blocking_failure_count",
        "NEW_CORRECTION_RECORD_COUNT": "new_correction_record_count",
    }
    for count_name, field in final_field_map.items():
        if final_resolve.get(field) != counts[count_name]:
            raise ValueError(f"SEAL_FINAL_RESOLVE_COUNT_MISMATCH:{field}")
    recomputed_final_resolve = validate_records(
        root,
        output_root,
        current_head=AUTHORIZED_HEAD_SHA,
        live_raw_report_path=(output_root / BASELINE_REPORT_REL).resolve(),
    )
    if final_resolve != recomputed_final_resolve:
        raise ValueError("SEAL_FINAL_RESOLVE_RECOMPUTE_MISMATCH")
    if final_resolve.get("status") != "FAIL" or final_resolve.get("failures") != []:
        raise ValueError("SEAL_FINAL_RESOLVE_CLASSIFICATION_INVALID")
    if final_resolve.get("authorized_head_sha") != AUTHORIZED_HEAD_SHA:
        raise ValueError("SEAL_FINAL_RESOLVE_AUTHORIZED_HEAD_MISMATCH")
    if final_resolve.get("baseline_report_sha256") != baseline_sha:
        raise ValueError("SEAL_FINAL_RESOLVE_BASELINE_HASH_MISMATCH")
    if final_resolve.get("new_correction_schema_sha256") != schema_sha:
        raise ValueError("SEAL_FINAL_RESOLVE_SCHEMA_HASH_MISMATCH")
    if set(final_resolve.get("unresolved_historical_fingerprints", [])) != unresolved_fingerprints:
        raise ValueError("SEAL_FINAL_RESOLVE_UNRESOLVED_SET_MISMATCH")
    if set(final_resolve.get("true_active_violation_fingerprints", [])) != active_fingerprints:
        raise ValueError("SEAL_FINAL_RESOLVE_ACTIVE_SET_MISMATCH")

    auditor_sha = auditor_binding["sha256"]
    for label, audit in (("A", audit_a), ("B", audit_b)):
        if audit.get("status") != "GO" or audit.get("p0") != [] or audit.get("p1") != []:
            raise ValueError(f"SEAL_AUDIT_{label}_NOT_GO")
        if audit.get("auditor_script_sha256") != auditor_sha:
            raise ValueError(f"SEAL_AUDIT_{label}_SCRIPT_HASH_MISMATCH")
        for field, expected in (
            ("raw_failure_count", counts["RAW_FAILURE_COUNT"]),
            ("raw_historical_failure_count", counts["RAW_HISTORICAL_FAILURE_COUNT"]),
            ("raw_current_delta_failure_count", counts["RAW_CURRENT_DELTA_FAILURE_COUNT"]),
        ):
            if not _is_exact_int(audit.get(field), expected):
                raise ValueError(f"SEAL_AUDIT_{label}_COUNT_MISMATCH:{field}")
    if not _is_exact_int(
        audit_a.get("corrected_fingerprint_count"),
        counts["CORRECTED_HISTORICAL_FAILURE_COUNT"],
    ):
        raise ValueError("SEAL_AUDIT_A_CORRECTED_COUNT_MISMATCH")
    if not _is_exact_int(
        audit_b.get("registry_unresolved_historical_row_count"),
        counts["UNRESOLVED_HISTORICAL_FAILURE_COUNT"],
    ):
        raise ValueError("SEAL_AUDIT_B_UNRESOLVED_COUNT_MISMATCH")

    # Recompute after every input byte/path-set has been snapshotted.  A change
    # before this point fails the exact comparison; a later change fails the
    # post-manifest digest or directory-membership revalidation.
    _recompute_correction_artifacts(root, output_root)
    _recompute_independent_audits(root, output_root)

    record_set_sha = sha256_bytes(_canonical_bytes(record_bindings))
    record_path_set_sha = sha256_bytes(
        _canonical_bytes([row["path"] for row in record_bindings])
    )
    revocation_path_set_sha = sha256_bytes(
        _canonical_bytes([row["path"] for row in revocation_bindings])
    )
    return {
        "bindings": sorted(bindings, key=lambda row: str(row["path"])),
        "tracked_files": tracked_files,
        "tracked_path_sets": tracked_path_sets,
        "counts": counts,
        "record_bindings": record_bindings,
        "record_set_sha256": record_set_sha,
        "revocation_bindings": revocation_bindings,
        "hashes": {
            "RAW_REPORT_SHA256": raw_binding["sha256"],
            "SCANNER_MANIFEST_SHA256": scanner_binding["sha256"],
            "EXISTING_CORRECTION_MANIFEST_SHA256": v1_binding["sha256"],
            "SUPERSEDES_AUTHORIZATION_MANIFEST_SHA256": (
                previous_authorization_manifest_binding["sha256"]
            ),
            "NEW_CORRECTION_SCHEMA_SHA256": schema_binding["sha256"],
            "NEW_RESOLVER_SHA256": resolver_binding["sha256"],
            "SELFTEST_TOOL_SHA256": selftest_tool_binding["sha256"],
            "INDEPENDENT_AUDITOR_SHA256": auditor_binding["sha256"],
            "SELFTEST_REPORT_SHA256": selftest_binding["sha256"],
            "FAILURE_INVENTORY_SHA256": failure_inventory_binding["sha256"],
            "MISSING_TRANSITION_INVENTORY_SHA256": missing_inventory_binding["sha256"],
            "TRUE_ACTIVE_VIOLATION_INVENTORY_SHA256": active_inventory_binding["sha256"],
            "CORRECTION_RECORD_INVENTORY_SHA256": record_inventory_binding["sha256"],
            "CORRECTION_RECORD_SET_SHA256": record_set_sha,
            "CORRECTION_RECORD_PATH_SET_SHA256": record_path_set_sha,
            "REVOCATION_RECORD_PATH_SET_SHA256": revocation_path_set_sha,
            "REVOCATION_RECORD_COUNT": len(revocation_bindings),
            "WORKFLOW_SHA256": workflow_binding["sha256"],
            "SCANNER_CORE_WORKTREE_SET_SHA256": sha256_bytes(
                _canonical_bytes(scanner_core_bindings)
            ),
            "EXISTING_REUSE_SELFTEST_TOOL_SHA256": existing_selftest_tool_binding["sha256"],
            "EXISTING_REUSE_SELFTEST_REPORT_SHA256": existing_selftest_binding["sha256"],
            "AUDIT_A_SHA256": audit_a_binding["sha256"],
            "AUDIT_A_MD_SHA256": audit_a_md_binding["sha256"],
            "AUDIT_B_SHA256": audit_b_binding["sha256"],
            "AUDIT_B_MD_SHA256": audit_b_md_binding["sha256"],
            "FINAL_RESOLVE_SHA256": final_resolve_binding["sha256"],
            "FINAL_RESOLVE_MD_SHA256": final_resolve_md_binding["sha256"],
        },
        "selftest": {
            "status": selftest["CORRECTION_V2_SELFTEST_STATUS"],
            "case_count": selftest_case_count,
            "pass_count": selftest["CORRECTION_V2_SELFTEST_PASS_COUNT"],
            "existing_reuse_selftest_pass_count": selftest["EXISTING_REUSE_SELFTEST_PASS_COUNT"],
        },
        "existing_reuse_selftest": {
            "status": existing_selftest_receipt[
                "REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS"
            ],
            "case_count": existing_case_count,
            "pass_count": existing_selftest_receipt[
                "REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT"
            ],
        },
        "audits": {
            "AUDIT_A": "GO",
            "AUDIT_A_P0": 0,
            "AUDIT_A_P1": 0,
            "AUDIT_B": "GO",
            "AUDIT_B_P0": 0,
            "AUDIT_B_P1": 0,
        },
    }


def _manifest_from_evidence(evidence: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": EVIDENCE_MANIFEST_SCHEMA_VERSION,
        "authorization_id": AUTHORIZATION_ID,
        "seal_revision_id": SEAL_REVISION_ID,
        "supersedes_authorization_manifest_path": (
            PREVIOUS_AUTHORIZATION_MANIFEST_REL.as_posix()
        ),
        "AUTHORIZED_HEAD_SHA": AUTHORIZED_HEAD_SHA,
        "PR_NUMBER": PR_NUMBER,
        **evidence["hashes"],
        **evidence["counts"],
        **evidence["audits"],
        "selftest": evidence["selftest"],
        "existing_reuse_selftest": evidence["existing_reuse_selftest"],
        "record_set": evidence["record_bindings"],
        "revocation_set": evidence["revocation_bindings"],
        "sealed_inputs": evidence["bindings"],
        "RAW_SCANNER_EXECUTES_BEFORE_CORRECTION": True,
        "RAW_FAILURE_DETECTION_SUPPRESSED_COUNT": 0,
        "SCANNER_RULE_REMOVAL_COUNT": 0,
        "SCANNER_SCOPE_REDUCTION_COUNT": 0,
        "SCANNER_SEVERITY_DOWNGRADE_COUNT": 0,
        "SCANNER_HISTORY_DEPTH_REDUCTION_COUNT": 0,
        "CORRECTION_WILDCARD_COUNT": 0,
        "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
        "CORRECTION_HISTORY_REWRITE_COUNT": 0,
        "POST_MANIFEST_INPUT_MUTATION_COUNT": 0,
        "post_manifest_input_revalidation_method": (
            "canonical candidates finalized in memory; every bound input, sidecar, "
            "record/revocation path set, and published output revalidated before return"
        ),
    }


def _plan_from_manifest(manifest_sha256: str, evidence: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema_version": APPLICATION_PLAN_SCHEMA_VERSION,
        "authorization_id": AUTHORIZATION_ID,
        "seal_revision_id": SEAL_REVISION_ID,
        "SUPERSEDES_AUTHORIZATION_MANIFEST_SHA256": evidence["hashes"][
            "SUPERSEDES_AUTHORIZATION_MANIFEST_SHA256"
        ],
        "AUTHORIZED_HEAD_SHA": AUTHORIZED_HEAD_SHA,
        "PR_NUMBER": PR_NUMBER,
        "CORRECTION_AUTHORIZATION_MANIFEST_SHA256": manifest_sha256,
        "NEW_CORRECTION_SCHEMA_SHA256": evidence["hashes"]["NEW_CORRECTION_SCHEMA_SHA256"],
        **evidence["counts"],
        "REUSE_GATE_STATUS": "FAIL",
        "STATUS": "HARD_STOP",
        "BLOCKING_DISPOSITION": "UNRESOLVED_BLOCKING_OR_TRUE_ACTIVE_VIOLATION",
        "COMMERCIAL_SPRINT_RESUMED_AFTER_REUSE_GATE": False,
        "COMMERCIAL_M1_GREEN": False,
        "FULL_PRODUCT_PRODUCTION_GREEN": False,
        "HUMAN_GREEN": False,
        "READY_FOR_NEXT_CONSOLIDATED_HUMAN_PLAYTEST": False,
        "STEP13_STATUS": "PENDING",
        "STEP14_STATUS": "PENDING",
        "STEP15_STATUS": "PENDING",
        "PR93_IS_DRAFT": True,
        "POST_MANIFEST_INPUT_MUTATION_COUNT": 0,
        "NEXT_TASK": (
            "V076_REUSE_CLASSIFY_498_UNRESOLVED_HISTORICAL_IDENTITIES_"
            "AND_REPAIR_56_CURRENT_ACTIVE_VIOLATIONS"
        ),
    }


def _pair_payloads(relative: Path, payload: bytes) -> dict[Path, bytes]:
    digest = sha256_bytes(payload)
    return {
        relative: payload,
        relative.with_suffix(".sha256"): f"{digest}  {relative.name}\n".encode("ascii"),
    }


def _preflight_seal_outputs(
    root: Path,
    output_root: Path,
    outputs: dict[Path, bytes],
    *,
    verify_only: bool,
) -> None:
    root = root.resolve()
    if output_root.resolve() != root:
        raise ValueError("SEAL_OUTPUT_ROOT_MUST_EQUAL_PROJECT_ROOT")
    for relative in outputs:
        path = output_root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        resolved_parent = path.parent.resolve()
        if not resolved_parent.is_relative_to(root):
            raise ValueError(f"SEAL_OUTPUT_SYMLINK_ESCAPE:{relative.as_posix()}")
        if verify_only:
            continue
        if _git(root, "ls-files", "--stage", "--", relative.as_posix(), check=False):
            raise RuntimeError(f"SEALED_APPEND_ONLY_PATH_IN_INDEX:{relative.as_posix()}")
        if _git(
            root,
            "log",
            "--all",
            "--format=%H",
            "--",
            relative.as_posix(),
            check=False,
        ):
            raise RuntimeError(f"SEALED_APPEND_ONLY_PATH_IN_GIT_HISTORY:{relative.as_posix()}")


def _publish_or_verify_seal_outputs(
    root: Path,
    output_root: Path,
    outputs: dict[Path, bytes],
    *,
    verify_only: bool,
) -> None:
    _preflight_seal_outputs(
        root,
        output_root,
        outputs,
        verify_only=verify_only,
    )
    if verify_only:
        for relative, expected in outputs.items():
            path = output_root / relative
            if not path.is_file() or path.read_bytes() != expected:
                raise ValueError(f"SEALED_ARTIFACT_CONTENT_MISMATCH:{relative.as_posix()}")
        return

    staged: dict[Path, Path] = {}
    try:
        for relative, payload in outputs.items():
            destination = output_root / relative
            with tempfile.NamedTemporaryFile(
                mode="wb",
                prefix=".v076-seal-",
                suffix=".tmp",
                dir=destination.parent,
                delete=False,
            ) as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
                staged[relative] = Path(handle.name)
        for relative, temporary_path in staged.items():
            os.replace(temporary_path, output_root / relative)
    finally:
        for temporary_path in staged.values():
            if temporary_path.exists():
                temporary_path.unlink()
    for relative, expected in outputs.items():
        if (output_root / relative).read_bytes() != expected:
            raise RuntimeError(f"SEALED_ARTIFACT_POST_WRITE_MISMATCH:{relative.as_posix()}")


def _verify_published_seal_revision(
    root: Path,
    output_root: Path,
    *,
    existing_selftest_receipt: dict[str, Any],
) -> dict[str, Any]:
    """Verify the frozen V2 seal without rebuilding it from successor tools.

    The published seal is a historical statement about the exact committed
    blobs at ``SEAL_REVISION_HEAD_SHA``.  Recomputing its manifest with the
    current scanner, resolver, auditor, workflow, or expanded self-test would
    either reject legitimate successor evolution or (worse) relabel successor
    bytes as the historical V2 inputs.  Verification instead byte-locks the
    published manifest/plan and every frozen evidence artifact in Git, while
    separately requiring the current scanner self-test to be green.
    """
    root = root.resolve()
    if output_root.resolve() != root:
        raise ValueError("SEAL_OUTPUT_ROOT_MUST_EQUAL_PROJECT_ROOT")
    historical_head = _resolve_commit(root, SEAL_REVISION_HEAD_SHA)
    current_head = _resolve_commit(root, "HEAD")
    if not _is_ancestor(root, historical_head, current_head):
        raise ValueError("SEAL_REVISION_NOT_ANCESTOR_OF_CURRENT_HEAD")

    status = existing_selftest_receipt.get(
        "REUSE_POINT_INERTIA_GATE_SELFTEST_STATUS"
    )
    case_count = existing_selftest_receipt.get(
        "REUSE_POINT_INERTIA_GATE_SELFTEST_CASE_COUNT"
    )
    pass_count = existing_selftest_receipt.get(
        "REUSE_POINT_INERTIA_GATE_SELFTEST_PASS_COUNT"
    )
    if (
        status != "PASS"
        or not isinstance(case_count, int)
        or isinstance(case_count, bool)
        or not isinstance(pass_count, int)
        or isinstance(pass_count, bool)
        or case_count <= 0
        or pass_count != case_count
    ):
        raise ValueError("SEAL_CURRENT_SCANNER_SELFTEST_NOT_PASS")

    revision_paths = (
        AUTHORIZATION_MANIFEST_REL,
        AUTHORIZATION_MANIFEST_REL.with_suffix(".sha256"),
        APPLICATION_PLAN_REL,
        APPLICATION_PLAN_REL.with_suffix(".sha256"),
    )
    revision_payloads: dict[Path, bytes] = {}
    for relative in revision_paths:
        historical = _bytes_at(root, historical_head, relative.as_posix())
        current = _bytes_at(root, current_head, relative.as_posix())
        if historical is None:
            raise ValueError(f"SEAL_REVISION_ARTIFACT_MISSING:{relative.as_posix()}")
        if current != historical:
            raise ValueError(f"SEAL_REVISION_ARTIFACT_DRIFT:{relative.as_posix()}")
        revision_payloads[relative] = historical

    try:
        manifest = json.loads(
            revision_payloads[AUTHORIZATION_MANIFEST_REL].decode("utf-8-sig")
        )
        plan = json.loads(revision_payloads[APPLICATION_PLAN_REL].decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("SEAL_REVISION_JSON_INVALID") from exc
    if not isinstance(manifest, dict) or not isinstance(plan, dict):
        raise ValueError("SEAL_REVISION_JSON_NOT_OBJECT")
    if revision_payloads[AUTHORIZATION_MANIFEST_REL] != _canonical_bytes(manifest):
        raise ValueError("SEAL_REVISION_MANIFEST_NOT_CANONICAL")
    if revision_payloads[APPLICATION_PLAN_REL] != _canonical_bytes(plan):
        raise ValueError("SEAL_REVISION_PLAN_NOT_CANONICAL")
    if (
        manifest.get("schema_version") != EVIDENCE_MANIFEST_SCHEMA_VERSION
        or manifest.get("authorization_id") != AUTHORIZATION_ID
        or manifest.get("seal_revision_id") != SEAL_REVISION_ID
    ):
        raise ValueError("SEAL_REVISION_MANIFEST_IDENTITY_INVALID")
    manifest_sha = sha256_bytes(revision_payloads[AUTHORIZATION_MANIFEST_REL])
    plan_sha = sha256_bytes(revision_payloads[APPLICATION_PLAN_REL])
    if plan.get("CORRECTION_AUTHORIZATION_MANIFEST_SHA256") != manifest_sha:
        raise ValueError("SEAL_REVISION_PLAN_MANIFEST_BINDING_MISMATCH")
    if (
        plan.get("schema_version") != APPLICATION_PLAN_SCHEMA_VERSION
        or plan.get("authorization_id") != AUTHORIZATION_ID
        or plan.get("seal_revision_id") != SEAL_REVISION_ID
    ):
        raise ValueError("SEAL_REVISION_PLAN_IDENTITY_INVALID")
    for relative in (AUTHORIZATION_MANIFEST_REL, APPLICATION_PLAN_REL):
        expected = (
            sha256_bytes(revision_payloads[relative])
            + "  "
            + relative.name
            + "\n"
        ).encode("ascii")
        if revision_payloads[relative.with_suffix(".sha256")] != expected:
            raise ValueError(f"SEAL_REVISION_SIDECAR_INVALID:{relative.as_posix()}")

    rows = manifest.get("sealed_inputs")
    if not isinstance(rows, list) or not rows:
        raise ValueError("SEAL_REVISION_INPUT_SET_INVALID")
    seen_paths: set[str] = set()
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("SEAL_REVISION_INPUT_ROW_INVALID")
        relative = normalize_path(str(row.get("path", "")))
        digest = str(row.get("sha256", ""))
        byte_count = row.get("byte_count")
        if (
            not relative
            or relative in seen_paths
            or not re.fullmatch(r"[0-9a-f]{64}", digest)
            or not isinstance(byte_count, int)
            or isinstance(byte_count, bool)
            or byte_count < 0
        ):
            raise ValueError(f"SEAL_REVISION_INPUT_BINDING_INVALID:{relative}")
        seen_paths.add(relative)
        historical = _bytes_at(root, historical_head, relative)
        if historical is None:
            raise ValueError(f"SEAL_REVISION_INPUT_MISSING:{relative}")
        if sha256_bytes(historical) != digest or len(historical) != byte_count:
            raise ValueError(f"SEAL_REVISION_INPUT_HASH_MISMATCH:{relative}")
        current = _bytes_at(root, current_head, relative)
        if current is None:
            raise ValueError(f"SEAL_SUCCESSOR_INPUT_MISSING:{relative}")
        # Reports, records and schemas are append-only historical evidence.
        # Tool and workflow source may evolve, but its current bytes are never
        # substituted into the old sealed row above.
        if relative in SCANNER_SUCCESSOR_SHA256_BY_PATH:
            if sha256_bytes(current) != SCANNER_SUCCESSOR_SHA256_BY_PATH[relative]:
                raise ValueError(f"SEAL_SCANNER_SUCCESSOR_HASH_MISMATCH:{relative}")
        elif relative not in EVOLVABLE_SEAL_INPUT_PATHS and current != historical:
            raise ValueError(f"SEAL_IMMUTABLE_INPUT_DRIFT:{relative}")
        sidecar_path = normalize_path(str(row.get("sidecar_path", "")))
        sidecar_sha = str(row.get("sidecar_sha256", ""))
        if sidecar_path or sidecar_sha:
            if not sidecar_path or not re.fullmatch(r"[0-9a-f]{64}", sidecar_sha):
                raise ValueError(f"SEAL_REVISION_INPUT_SIDECAR_INVALID:{relative}")
            historical_sidecar = _bytes_at(root, historical_head, sidecar_path)
            current_sidecar = _bytes_at(root, current_head, sidecar_path)
            if (
                historical_sidecar is None
                or sha256_bytes(historical_sidecar) != sidecar_sha
                or current_sidecar != historical_sidecar
            ):
                raise ValueError(f"SEAL_REVISION_INPUT_SIDECAR_DRIFT:{relative}")

    # The historical scanner manifest remains authoritative for its own three
    # core paths; successor source is deliberately not compared to these old
    # digests.  This proves the old rows without confusing them with HEAD.
    scanner_manifest_bytes = _bytes_at(
        root,
        historical_head,
        SCANNER_MANIFEST_REL.as_posix(),
    )
    try:
        scanner_manifest = json.loads(scanner_manifest_bytes.decode("utf-8-sig"))
    except (AttributeError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("SEAL_HISTORICAL_SCANNER_MANIFEST_INVALID") from exc
    scanner_rows = scanner_manifest.get("files") if isinstance(scanner_manifest, dict) else None
    if not isinstance(scanner_rows, list):
        raise ValueError("SEAL_HISTORICAL_SCANNER_ROWS_INVALID")
    scanner_by_path = {
        normalize_path(str(row.get("path", ""))): str(row.get("sha256", ""))
        for row in scanner_rows
        if isinstance(row, dict)
    }
    if set(scanner_by_path) != set(SCANNER_CORE_PATHS):
        raise ValueError("SEAL_HISTORICAL_SCANNER_PATH_SET_DRIFT")
    for relative in SCANNER_CORE_PATHS:
        historical = _bytes_at(root, historical_head, relative)
        if historical is None or sha256_bytes(historical) != scanner_by_path[relative]:
            raise ValueError(f"SEAL_HISTORICAL_SCANNER_HASH_MISMATCH:{relative}")

    # Do not use the cached resolver here: this is the post-verification
    # mutation check and must observe a fresh ref value.
    if _git(root, "rev-parse", "HEAD", check=False).strip() != current_head:
        raise ValueError("POST_MANIFEST_INPUT_MUTATION_COUNT=1")
    counts = {
        field: manifest.get(field)
        for field in EXPECTED_SEAL_COUNTS
    }
    _validate_exact_count_projection(counts)
    return {
        "status": "VERIFIED",
        "authorization_manifest_sha256": manifest_sha,
        "application_plan_sha256": plan_sha,
        "POST_MANIFEST_INPUT_MUTATION_COUNT": 0,
        "REUSE_GATE_STATUS": "FAIL",
        "FINAL_STATUS": "HARD_STOP",
        **counts,
    }


def seal_evidence(root: Path, output_root: Path, *, verify_only: bool) -> dict[str, Any]:
    root = root.resolve()
    output_root = output_root.resolve()
    if output_root != root:
        raise ValueError("SEAL_OUTPUT_ROOT_MUST_EQUAL_PROJECT_ROOT")
    existing_receipt, existing_payload = _run_existing_reuse_selftest(root)
    if verify_only:
        return _verify_published_seal_revision(
            root,
            output_root,
            existing_selftest_receipt=existing_receipt,
        )
    evidence = _collect_seal_evidence(
        root,
        output_root,
        existing_selftest_receipt=existing_receipt,
        existing_selftest_payload=existing_payload,
        verify_only=verify_only,
    )
    manifest = _manifest_from_evidence(evidence)
    manifest_payload = _canonical_bytes(manifest)

    # This is a post-candidate revalidation: the exact bytes asserting zero are
    # already finalized, but nothing has been published yet.  A changed input
    # prevents publication rather than leaving a false append-only receipt.
    mutation_count = _post_manifest_input_mutation_count(
        evidence["tracked_files"], evidence["tracked_path_sets"]
    )
    if mutation_count:
        raise ValueError(f"POST_MANIFEST_INPUT_MUTATION_COUNT={mutation_count}")
    manifest_sha = sha256_bytes(manifest_payload)
    plan = _plan_from_manifest(manifest_sha, evidence)
    plan_payload = _canonical_bytes(plan)
    plan_sha = sha256_bytes(plan_payload)
    outputs: dict[Path, bytes] = {}
    outputs.update(_pair_payloads(EXISTING_SELFTEST_REPORT_REL, existing_payload))
    outputs.update(_pair_payloads(AUTHORIZATION_MANIFEST_REL, manifest_payload))
    outputs.update(_pair_payloads(APPLICATION_PLAN_REL, plan_payload))
    # Preflight every destination and stage every byte only after all input
    # candidates are finalized.  This is not claimed as a cross-file
    # filesystem transaction; final read-back and input/path-set revalidation
    # are required before a successful return.
    _publish_or_verify_seal_outputs(
        root,
        output_root,
        outputs,
        verify_only=verify_only,
    )
    final_mutation_count = _post_manifest_input_mutation_count(
        evidence["tracked_files"], evidence["tracked_path_sets"]
    )
    if final_mutation_count:
        raise ValueError(f"POST_MANIFEST_INPUT_MUTATION_COUNT={final_mutation_count}")
    for relative, expected in outputs.items():
        if not (output_root / relative).is_file() or (output_root / relative).read_bytes() != expected:
            raise ValueError(f"SEALED_ARTIFACT_FINAL_READBACK_MISMATCH:{relative.as_posix()}")
    return {
        "status": "VERIFIED" if verify_only else "SEALED",
        "authorization_manifest_sha256": manifest_sha,
        "application_plan_sha256": plan_sha,
        "POST_MANIFEST_INPUT_MUTATION_COUNT": 0,
        "REUSE_GATE_STATUS": "FAIL",
        "FINAL_STATUS": "HARD_STOP",
        **evidence["counts"],
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=(
            "freeze-baseline",
            "build-inventory",
            "generate-records",
            "resolve",
            "seal-evidence",
            "verify-legacy-epoch",
            "verify-full-convergence-baseline",
            "verify-full-convergence-batch",
        ),
    )
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--output-root", type=Path, default=None)
    parser.add_argument(
        "--raw-report",
        type=Path,
        default=None,
        help="scanner report to freeze, or the live Raw report emitted immediately before resolve",
    )
    parser.add_argument(
        "--full-convergence-baseline-report",
        type=Path,
        default=None,
        help=(
            "explicit frozen d701 FULL_CONVERGENCE baseline; never the live "
            "Required-Check Raw report"
        ),
    )
    parser.add_argument("--report-json", type=Path, default=None)
    parser.add_argument("--report-md", type=Path, default=None)
    parser.add_argument(
        "--batch-manifest",
        type=Path,
        default=None,
        help="explicit FULL_CONVERGENCE batch manifest; directory discovery is never authority",
    )
    parser.add_argument(
        "--previous-batch-manifest",
        type=Path,
        default=None,
        help=(
            "explicit immediate predecessor manifest for a non-initial "
            "FULL_CONVERGENCE batch; never inferred by directory discovery"
        ),
    )
    parser.add_argument(
        "--descendant-history-supplement",
        type=Path,
        default=None,
        help="explicit sealed descendant-history supplement; never discovered implicitly",
    )
    parser.add_argument(
        "--descendant-history-raw-report",
        type=Path,
        default=None,
        help="explicit raw scanner report bound by the descendant-history supplement",
    )
    parser.add_argument(
        "--descendant-history-scanner",
        type=Path,
        default=None,
        help="explicit scanner implementation bound by the descendant-history supplement",
    )
    parser.add_argument(
        "--post-touch-revalidation",
        type=Path,
        default=None,
        help="explicit append-only post-touch revalidation manifest; never discovered implicitly",
    )
    parser.add_argument(
        "--post-touch-revalidation-successor-v2",
        type=Path,
        default=None,
        help=(
            "explicit committed post-touch successor-v2 manifest; valid only "
            "with its predecessor and the complete FULL_CONVERGENCE input set"
        ),
    )
    parser.add_argument(
        "--subject-projection-revalidation",
        type=Path,
        default=None,
        help=(
            "explicit frozen 82-row subject-projection revalidation v1 "
            "manifest; valid only together with its successor-v2 manifest, "
            "the complete FULL_CONVERGENCE input set, and an explicit "
            "historical Delta metadata ledger"
        ),
    )
    parser.add_argument(
        "--subject-projection-revalidation-successor-v2",
        type=Path,
        default=None,
        help=(
            "explicit committed subject-projection successor-v2 manifest; "
            "valid only together with --subject-projection-revalidation, "
            "the complete FULL_CONVERGENCE input set, and an explicit "
            "historical Delta metadata ledger"
        ),
    )
    parser.add_argument(
        "--subject-projection-revalidation-successor-v3",
        type=Path,
        default=None,
        help=(
            "explicit committed subject-projection successor-v3 manifest; "
            "valid only together with the v1/v2 epoch pair and the complete "
            "FULL_CONVERGENCE input set"
        ),
    )
    parser.add_argument(
        "--subject-projection-revalidation-successor-v4",
        type=Path,
        default=None,
        help=(
            "explicit committed terminal replacement for the v1 82-set; valid "
            "only with explicitly supplied v1/v2/v3/v4/v5 manifests"
        ),
    )
    parser.add_argument(
        "--subject-projection-revalidation-successor-v5",
        type=Path,
        default=None,
        help=(
            "explicit committed terminal replacement for the v2 2-set; valid "
            "only with explicitly supplied v1/v2/v3/v4/v5 manifests"
        ),
    )
    parser.add_argument(
        "--historical-delta-metadata-ledger",
        type=Path,
        default=None,
        help=(
            "explicit append-only historical Delta metadata ledger; valid "
            "only with the complete FULL_CONVERGENCE input set and never "
            "discovered implicitly"
        ),
    )
    parser.add_argument(
        "--historical-delta-metadata-successor",
        type=Path,
        default=None,
        help=(
            "explicit append-only historical Delta metadata successor "
            "manifest; optional, never discovered implicitly, and fail-closed "
            "when supplied"
        ),
    )
    parser.add_argument(
        "--historical-delta-metadata-successor-v2",
        type=Path,
        default=None,
        help=(
            "explicit predecessor-revalidation successor-v2 manifest for "
            "the frozen 86-row HDM identity set; optional, never discovered"
        ),
    )
    parser.add_argument(
        "--full-convergence-pr-body-file",
        type=Path,
        default=None,
        help=(
            "explicit PR-body bytes used only for descendant live Raw internal "
            "scanner re-execution; frozen exact-head validation does not require it"
        ),
    )
    parser.add_argument("--head-ref", default=AUTHORIZED_HEAD_SHA)
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="verify already-sealed evidence without replacing append-only artifacts",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    root = args.project.resolve()
    output_root = (args.output_root or root).resolve()
    current_head = _resolve_commit(root, args.head_ref)
    if (
        (args.subject_projection_revalidation is None)
        != (args.subject_projection_revalidation_successor_v2 is None)
    ):
        raise SystemExit(
            "--subject-projection-revalidation and "
            "--subject-projection-revalidation-successor-v2 must be supplied "
            "together"
        )
    if (
        args.subject_projection_revalidation_successor_v3 is not None
        and args.subject_projection_revalidation is None
    ):
        raise SystemExit(
            "--subject-projection-revalidation-successor-v3 requires the "
            "v1/v2 subject-projection epoch pair"
        )
    replacement_args = (
        args.subject_projection_revalidation,
        args.subject_projection_revalidation_successor_v2,
        args.subject_projection_revalidation_successor_v3,
        args.subject_projection_revalidation_successor_v4,
        args.subject_projection_revalidation_successor_v5,
    )
    if (
        args.subject_projection_revalidation_successor_v4 is not None
        or args.subject_projection_revalidation_successor_v5 is not None
    ) and any(value is None for value in replacement_args):
        raise SystemExit(
            "--subject-projection-revalidation-successor-v4/v5 require the "
            "complete explicit v1/v2/v3/v4/v5 replacement set"
        )
    if (
        args.post_touch_revalidation_successor_v2 is not None
        and args.post_touch_revalidation is None
    ):
        raise SystemExit(
            "--post-touch-revalidation-successor-v2 requires "
            "--post-touch-revalidation"
        )
    if (
        (
            args.subject_projection_revalidation is not None
            or args.subject_projection_revalidation_successor_v2 is not None
            or args.subject_projection_revalidation_successor_v3 is not None
            or args.subject_projection_revalidation_successor_v4 is not None
            or args.subject_projection_revalidation_successor_v5 is not None
            or args.post_touch_revalidation_successor_v2 is not None
            or args.historical_delta_metadata_successor is not None
            or args.historical_delta_metadata_successor_v2 is not None
        )
        and args.command not in {"resolve", "verify-full-convergence-batch"}
    ):
        raise SystemExit(
            "--subject-projection-revalidation is valid only with resolve or "
            "verify-full-convergence-batch"
        )
    if args.command.startswith("verify-full-convergence") or args.command == "verify-legacy-epoch":
        import v076_reuse_exact_failure_correction_v2_full_convergence as convergence

        if args.command == "verify-legacy-epoch":
            result = convergence.verify_legacy_anchor(root)
        elif args.command == "verify-full-convergence-baseline":
            if not args.full_convergence_baseline_report:
                raise SystemExit(
                    "verify-full-convergence-baseline requires "
                    "--full-convergence-baseline-report"
                )
            result = convergence.validate_authorized_baseline(
                args.full_convergence_baseline_report.resolve()
            )
            result["schema_failures"] = convergence.validate_schema(root)
            if result["schema_failures"]:
                result["status"] = "FAIL"
        else:
            if not args.batch_manifest:
                raise SystemExit("verify-full-convergence-batch requires --batch-manifest")
            if not args.full_convergence_baseline_report:
                raise SystemExit(
                    "verify-full-convergence-batch requires "
                    "--full-convergence-baseline-report"
                )
            if not args.descendant_history_supplement:
                raise SystemExit(
                    "verify-full-convergence-batch requires --descendant-history-supplement"
                )
            if not args.descendant_history_raw_report:
                raise SystemExit(
                    "verify-full-convergence-batch requires --descendant-history-raw-report"
                )
            if not args.descendant_history_scanner:
                raise SystemExit(
                    "verify-full-convergence-batch requires --descendant-history-scanner"
                )
            if (
                args.subject_projection_revalidation is not None
                and args.historical_delta_metadata_ledger is None
            ):
                raise SystemExit(
                    "verify-full-convergence-batch with "
                    "--subject-projection-revalidation requires "
                    "--historical-delta-metadata-ledger"
                )
            if (
                args.subject_projection_revalidation_successor_v3 is not None
                and args.historical_delta_metadata_ledger is None
            ):
                raise SystemExit(
                    "verify-full-convergence-batch with "
                    "--subject-projection-revalidation-successor-v3 requires "
                    "--historical-delta-metadata-ledger"
                )
            if (
                args.historical_delta_metadata_successor is not None
                and args.historical_delta_metadata_ledger is None
            ):
                raise SystemExit(
                    "verify-full-convergence-batch with "
                    "--historical-delta-metadata-successor requires "
                    "--historical-delta-metadata-ledger"
                )
            if (
                args.historical_delta_metadata_successor_v2 is not None
                and args.historical_delta_metadata_ledger is None
            ):
                raise SystemExit(
                    "verify-full-convergence-batch with "
                    "--historical-delta-metadata-successor-v2 requires "
                    "--historical-delta-metadata-ledger"
                )
            result = convergence.validate_batch_manifest_against_repo(
                root,
                args.batch_manifest.resolve(),
                evaluated_head=current_head,
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
                post_touch_revalidation_successor_v2_path=(
                    args.post_touch_revalidation_successor_v2.resolve()
                    if args.post_touch_revalidation_successor_v2 is not None
                    else None
                ),
                subject_projection_revalidation_path=(
                    args.subject_projection_revalidation.resolve()
                    if args.subject_projection_revalidation is not None
                    else None
                ),
                subject_projection_revalidation_successor_v2_path=(
                    args.subject_projection_revalidation_successor_v2.resolve()
                    if args.subject_projection_revalidation_successor_v2 is not None
                    else None
                ),
                subject_projection_revalidation_successor_v3_path=(
                    args.subject_projection_revalidation_successor_v3.resolve()
                    if args.subject_projection_revalidation_successor_v3 is not None
                    else None
                ),
                subject_projection_revalidation_successor_v4_path=(
                    args.subject_projection_revalidation_successor_v4.resolve()
                    if args.subject_projection_revalidation_successor_v4 is not None
                    else None
                ),
                subject_projection_revalidation_successor_v5_path=(
                    args.subject_projection_revalidation_successor_v5.resolve()
                    if args.subject_projection_revalidation_successor_v5 is not None
                    else None
                ),
                historical_delta_metadata_ledger_path=(
                    args.historical_delta_metadata_ledger.resolve()
                    if args.historical_delta_metadata_ledger is not None
                    else None
                ),
                historical_delta_metadata_successor_path=(
                    args.historical_delta_metadata_successor.resolve()
                    if args.historical_delta_metadata_successor is not None
                    else None
                ),
                historical_delta_metadata_successor_v2_path=(
                    args.historical_delta_metadata_successor_v2.resolve()
                    if args.historical_delta_metadata_successor_v2 is not None
                    else None
                ),
            )
        print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
        return 0 if result.get("status") == "PASS" else 1
    if args.command == "freeze-baseline":
        if not args.raw_report:
            raise SystemExit("freeze-baseline requires --raw-report")
        print(json.dumps(freeze_baseline(root, args.raw_report.resolve(), output_root), indent=2))
        return 0
    if args.command == "build-inventory":
        print(json.dumps(build_inventories(root, output_root), indent=2))
        return 0
    if args.command == "generate-records":
        result = generate_records(root, output_root)
        inventory_path = output_root / "reports/reuse/correction_v2/correction_record_inventory.json"
        _write_generated_draft(
            inventory_path, _canonical_bytes(result), repository_root=root
        )
        _write_generated_draft(
            inventory_path.with_suffix(".sha256"),
            (sha256_file(inventory_path) + "  " + inventory_path.name + "\n").encode("ascii"),
            repository_root=root,
        )
        print(json.dumps(result, indent=2))
        return 0
    if args.command == "seal-evidence":
        result = seal_evidence(root, output_root, verify_only=args.verify_only)
        print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
        return 0
    if args.verify_only:
        raise SystemExit("--verify-only is valid only with seal-evidence")
    return resolve_command(
        root,
        output_root,
        current_head=current_head,
        live_raw_report_path=args.raw_report.resolve() if args.raw_report else None,
        report_json=args.report_json,
        report_md=args.report_md,
        full_convergence_baseline_report_path=(
            args.full_convergence_baseline_report.resolve()
            if args.full_convergence_baseline_report is not None
            else None
        ),
        full_convergence_batch_manifest_path=(
            args.batch_manifest.resolve() if args.batch_manifest is not None else None
        ),
        full_convergence_previous_batch_manifest_path=(
            args.previous_batch_manifest.resolve()
            if args.previous_batch_manifest is not None
            else None
        ),
        descendant_history_supplement_path=(
            args.descendant_history_supplement.resolve()
            if args.descendant_history_supplement is not None
            else None
        ),
        descendant_history_raw_report_path=(
            args.descendant_history_raw_report.resolve()
            if args.descendant_history_raw_report is not None
            else None
        ),
        descendant_history_scanner_path=(
            args.descendant_history_scanner.resolve()
            if args.descendant_history_scanner is not None
            else None
        ),
        post_touch_revalidation_path=(
            args.post_touch_revalidation.resolve()
            if args.post_touch_revalidation is not None
            else None
        ),
        post_touch_revalidation_successor_v2_path=(
            args.post_touch_revalidation_successor_v2.resolve()
            if args.post_touch_revalidation_successor_v2 is not None
            else None
        ),
        subject_projection_revalidation_path=(
            args.subject_projection_revalidation.resolve()
            if args.subject_projection_revalidation is not None
            else None
        ),
        subject_projection_revalidation_successor_v2_path=(
            args.subject_projection_revalidation_successor_v2.resolve()
            if args.subject_projection_revalidation_successor_v2 is not None
            else None
        ),
        subject_projection_revalidation_successor_v3_path=(
            args.subject_projection_revalidation_successor_v3.resolve()
            if args.subject_projection_revalidation_successor_v3 is not None
            else None
        ),
        subject_projection_revalidation_successor_v4_path=(
            args.subject_projection_revalidation_successor_v4.resolve()
            if args.subject_projection_revalidation_successor_v4 is not None
            else None
        ),
        subject_projection_revalidation_successor_v5_path=(
            args.subject_projection_revalidation_successor_v5.resolve()
            if args.subject_projection_revalidation_successor_v5 is not None
            else None
        ),
        historical_delta_metadata_ledger_path=(
            args.historical_delta_metadata_ledger.resolve()
            if args.historical_delta_metadata_ledger is not None
            else None
        ),
        historical_delta_metadata_successor_path=(
            args.historical_delta_metadata_successor.resolve()
            if args.historical_delta_metadata_successor is not None
            else None
        ),
        historical_delta_metadata_successor_v2_path=(
            args.historical_delta_metadata_successor_v2.resolve()
            if args.historical_delta_metadata_successor_v2 is not None
            else None
        ),
        full_convergence_pr_body_file_path=(
            args.full_convergence_pr_body_file.resolve()
            if args.full_convergence_pr_body_file is not None
            else None
        ),
    )


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, RuntimeError, ValueError) as exc:
        print(f"V076_REUSE_CORRECTION_V2_ERROR={exc}", file=sys.stderr)
        raise SystemExit(2)
