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
    "descendant_history_supplement.v1"
)
DESCENDANT_HISTORY_SUPPLEMENT_ID = "FULL_CONVERGENCE_DESCENDANT_HISTORY_20260827_001"

SCHEMA_REL = Path("docs/architecture/reuse_corrections/v2/schema_full_convergence_20260827.json")
RECORD_ROOT_REL = Path("docs/architecture/reuse_corrections/v2/records/full_convergence_20260827")
EPOCH_ROOT_REL = Path("reports/reuse/correction_v2/epochs/full_convergence_20260827")
BASELINE_REPORT_REL = EPOCH_ROOT_REL / "baseline_raw_failure_report.json"
DESCENDANT_HISTORY_SCANNER_REL = Path("tools/v076/v076_reuse_point_inertia_gate.py")
LEGACY_SEAL_MANIFEST_REL = Path(
    "reports/reuse/correction_v2/seals/ci_portability_v2/correction_authorization_manifest.json"
)
LEGACY_SEAL_PLAN_REL = Path(
    "reports/reuse/correction_v2/seals/ci_portability_v2/correction_application_plan.json"
)
LEGACY_SCHEMA_REL = Path("docs/architecture/reuse_corrections/v2/schema.json")

# Filled from the committed schema artifact.  Keeping it in code prevents a
# schema plus freshly rewritten sidecar from silently broadening authority.
AUTHORIZED_SCHEMA_SHA256 = "474c4864fd72ad1761fbbaae90f31791e9c6ee7d9dcb0e4de53ef47240cb1b12"

AUTHORITY_SOURCE_PATHS = (
    "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json",
    "docs/architecture/V076_SUPERSESSION_MAP.json",
    "docs/architecture/V076_OWNER_REUSE_MAP.md",
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

DESCENDANT_HISTORY_SUPPLEMENT_FIELDS = tuple(sorted((
    "authorization_base_head_sha",
    "authorization_id",
    "baseline_failure_set_sha256",
    "baseline_report_sha256",
    "committed_only",
    "descendant_history_failure_count",
    "descendant_history_fingerprint_set_sha256",
    "descendant_history_fingerprints",
    "directory_discovery_allowed",
    "future_failure_auto_membership_allowed",
    "identity_binding_by_failure",
    "raw_current_delta_failure_count",
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

DISALLOWED_TOKENS = {
    "*", "glob", "regex", "prefix", "directory", "legacy", "misc", "other",
    "unknown", "unknown_accepted", "ignore", "waive", "grandfather",
}


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


def validate_descendant_history_supplement(
    root: Path,
    supplement_path: Path | None,
    raw_report_path: Path | None,
    scanner_path: Path | None,
    *,
    evaluated_head: str,
    baseline_report_path: Path,
) -> dict[str, Any]:
    """Validate one explicit, byte-sealed descendant HISTORY membership set.

    The supplement is not discovered.  Its three files must be passed by the
    caller, and the raw report must evaluate one committed Head with zero
    current failures.  Membership is the exact set difference between that
    report's historical fingerprints and the frozen d701 historical set.
    """

    failures: list[str] = []
    empty = {
        "status": "FAIL",
        "failures": failures,
        "supplement_sha256": "",
        "authorized_historical_fingerprints": set(),
        "authorized_identity_by_fingerprint": {},
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
    if set(supplement) != set(DESCENDANT_HISTORY_SUPPLEMENT_FIELDS):
        failures.append("DESCENDANT_HISTORY_SUPPLEMENT_FIELD_SET_MISMATCH")
    for field, expected in (
        ("schema_version", DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION),
        ("supplement_id", DESCENDANT_HISTORY_SUPPLEMENT_ID),
        ("authorization_id", AUTHORIZATION_ID),
        ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD_SHA),
        ("baseline_report_sha256", AUTHORIZED_BASELINE_REPORT_SHA256),
        ("baseline_failure_set_sha256", AUTHORIZED_BASELINE_FAILURE_SET_SHA256),
        ("committed_only", True),
        ("directory_discovery_allowed", False),
        ("wildcard_membership_allowed", False),
        ("future_failure_auto_membership_allowed", False),
        ("raw_current_delta_failure_count", 0),
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
    if not frozen_sets["historical"].issubset(final_sets["historical"]):
        failures.append("DESCENDANT_HISTORY_FROZEN_HISTORICAL_SET_NOT_PRESERVED")
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
    if supplement.get("descendant_history_failure_count") != len(descendant_fingerprints):
        failures.append("DESCENDANT_HISTORY_FAILURE_COUNT_MISMATCH")
    if supplement.get("descendant_history_fingerprint_set_sha256") != _line_set_sha(
        declared_descendant_rendered
    ):
        failures.append("DESCENDANT_HISTORY_FINGERPRINT_SET_SHA256_MISMATCH")
    if supplement.get("raw_failure_count") != len(raw_rendered):
        failures.append("DESCENDANT_HISTORY_RAW_FAILURE_COUNT_MISMATCH")
    if supplement.get("raw_historical_failure_count") != len(final_sets["historical"]):
        failures.append("DESCENDANT_HISTORY_RAW_HISTORICAL_COUNT_MISMATCH")
    if supplement.get("raw_current_delta_failure_count") != len(final_sets["current"]):
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
    if (
        supplement.get("scanner_tool_sha256") != scanner_sha
        or scanner_sha != scanner_at_report_sha
    ):
        failures.append("DESCENDANT_HISTORY_SCANNER_SHA256_MISMATCH")
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
    if supplement.get("repaired_frozen_current_failure_count") != len(frozen_sets["current"]):
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
        if (
            not _is_ancestor(root, AUTHORIZATION_BASE_HEAD_SHA, new_commit)
            or not _is_ancestor(root, new_commit, report_head)
        ):
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
    failures = sorted(set(failures))
    return {
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
        "supplement_sha256": supplement_sha,
        "authorized_historical_fingerprints": descendant_fingerprints,
        "authorized_identity_by_fingerprint": authorized_identities,
        "raw_report_head_sha": report_head,
        "frozen_current_identity_count": len(frozen_identities) - len(frozen_sets["historical"]),
    }


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
    if document.get("failure_count") != len(expected_fingerprints):
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
        if document.get("identity_coverage_percent") != 100 or document.get("unknown_count") != 0:
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
        if document.get("unknown_count") != 0 or document.get("wildcard_count") != 0:
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
            if document.get(field) != expected:
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
        if document.get("p0_count") != 0 or document.get("p1_count") != 0:
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


def validate_schema(root: Path) -> list[str]:
    path = root / SCHEMA_REL
    if not path.is_file():
        return ["FULL_CONVERGENCE_SCHEMA_MISSING"]
    if AUTHORIZED_SCHEMA_SHA256 == "TO_BE_FILLED":
        return ["FULL_CONVERGENCE_SCHEMA_HASH_NOT_AUTHORIZED"]
    if sha256_file(path) != AUTHORIZED_SCHEMA_SHA256:
        return ["FULL_CONVERGENCE_SCHEMA_HASH_MISMATCH"]
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
    if schema.get("baseline_historical_fingerprint_membership_required") is not True:
        failures.append("FULL_CONVERGENCE_SCHEMA_BASELINE_MEMBERSHIP_POLICY_MISMATCH")
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
    return sorted(set(failures))


def verify_legacy_anchor(root: Path) -> dict[str, Any]:
    failures: list[str] = []
    previous = ""
    fingerprints: list[str] = []
    for binding in LEGACY_RECORD_BINDINGS:
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
        previous = str(record.get("record_payload_sha256", ""))
        fingerprints.extend(str(value) for value in record.get("failure_fingerprints", []))
    if previous != LEGACY_RECORD_CHAIN_TERMINAL_SHA256:
        failures.append("LEGACY_RECORD_CHAIN_TERMINAL_MISMATCH")
    if len(fingerprints) != 12 or len(fingerprints) != len(set(fingerprints)):
        failures.append("LEGACY_RECORD_FINGERPRINT_SET_INVALID")
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
            "old_owner_path", "new_owner_path",
        )
    }
    id_values = {
        str(row.get(key, ""))
        for key in ("supersession_id", "retirement_id", "record_id")
    }
    return bool(
        component_ids & component_values
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
    if registry is None or supersession is None or owner_map_payload is None:
        raise ValueError("SUBJECT_PROJECTION_AUTHORITY_SOURCE_MISSING")
    registry_rows = [row for row in _walk_dicts(registry) if _matches_selector(row, selector)]
    supersession_rows = [row for row in _walk_dicts(supersession) if _matches_selector(row, selector)]
    registry_rows = sorted(registry_rows, key=lambda row: canonical_bytes(row))
    supersession_rows = sorted(supersession_rows, key=lambda row: canonical_bytes(row))
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
    if not registry_rows and not supersession_rows and not owner_map_lines:
        raise ValueError("SUBJECT_PROJECTION_SELECTOR_UNRESOLVED")
    return {
        "owner_map_lines": owner_map_lines,
        "registry_rows": registry_rows,
        "supersession_rows": supersession_rows,
    }


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
    if record.get("failure_count") != len(rendered):
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
    if not transition or set(re.findall(r"[a-z0-9_]+", transition.casefold())) & DISALLOWED_TOKENS:
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
        for key in (
            "domain_id", "historical_role", "current_role", "retired_status", "dynamic_reference_status",
            "historical_production_reachability", "current_production_reachability",
        ):
            value = str(binding.get(key, ""))
            if not value or "UNKNOWN" in value or "UNRESOLVED" in value:
                failures.append(f"IDENTITY_BINDING_UNKNOWN:{key}:{fingerprint}")
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
                    (authorized_identities or {}).get(str(fingerprint)),
                    record_rule_ids=[str(value) for value in record.get("rule_ids", [])],
                )
            )
            source_commit = str(binding.get("source_commit", ""))
            authorized_identity = (authorized_identities or {}).get(str(fingerprint), {})
            if _is_commit(source_commit):
                if authorized_identity.get("authority_origin") == "DESCENDANT_HISTORY_SUPPLEMENT":
                    supplement_head = str(
                        authorized_identity.get("supplement_raw_report_head_sha", "")
                    )
                    if (
                        not _is_ancestor(root, AUTHORIZATION_BASE_HEAD_SHA, source_commit)
                        or not _is_ancestor(root, source_commit, supplement_head)
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
            try:
                evaluated_projection = subject_projection(root, evaluated_head, selector)
            except (ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
                failures.append(f"SUBJECT_PROJECTION_CHANGED_INVALID:{fingerprint}")
                continue
            if sha256_bytes(canonical_bytes(evaluated_projection)) != binding.get("subject_projection_sha256"):
                failures.append(f"SUBJECT_PROJECTION_CHANGED_INVALID:{fingerprint}")
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
        if manifest.get(field) != expected:
            failures.append(f"BATCH_MANIFEST_{field.upper()}_MISMATCH")
    batch_id = str(manifest.get("batch_id", ""))
    if not re.fullmatch(r"batch-[0-9]{3}", batch_id):
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
    if manifest.get("failure_count") != len(rendered):
        failures.append("BATCH_MANIFEST_FINGERPRINT_COUNT_MISMATCH")
    if len(rendered) > 50 or len(rendered) == 0:
        failures.append("BATCH_MANIFEST_SIZE_OUT_OF_RANGE")
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
        return current_path.parent.parent / prior_batch_id / current_path.name
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
        failures.extend(
            validate_extension_record_against_repo(
                root,
                record,
                evaluated_head=evaluated_head,
                authorized_identities=authorized_identities,
            )
        )
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
) -> dict[str, Any]:
    failures = validate_schema(root)
    legacy = verify_legacy_anchor(root)
    failures.extend(legacy["failures"])
    try:
        manifest = load_json_strict(manifest_path)
    except (OSError, ValueError, json.JSONDecodeError, DuplicateJsonKeyError):
        manifest = {}
        failures.append("BATCH_MANIFEST_JSON_INVALID")
    failures.extend(validate_batch_manifest_document(manifest))
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
    authorized_fingerprints["historical"].update(
        supplement.get("authorized_historical_fingerprints", set())
    )
    authorized_identities.update(
        supplement.get("authorized_identity_by_fingerprint", {})
    )
    expected_supplement_sha = supplement.get("supplement_sha256", "")
    legacy_fingerprints = set(legacy.get("legacy_corrected_fingerprints", []))
    all_manifests = list(reversed(previous_chain)) + [(manifest_path, manifest)]
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
    }
