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

SCHEMA_REL = Path("docs/architecture/reuse_corrections/v2/schema_full_convergence_20260827.json")
BASELINE_REPORT_REL = Path("reports/reuse/correction_v2/baseline_raw_failure_report.json")
RECORD_ROOT_REL = Path("docs/architecture/reuse_corrections/v2/records/full_convergence_20260827")
EPOCH_ROOT_REL = Path("reports/reuse/correction_v2/epochs/full_convergence_20260827")
LEGACY_SEAL_MANIFEST_REL = Path(
    "reports/reuse/correction_v2/seals/ci_portability_v2/correction_authorization_manifest.json"
)
LEGACY_SEAL_PLAN_REL = Path(
    "reports/reuse/correction_v2/seals/ci_portability_v2/correction_application_plan.json"
)
LEGACY_SCHEMA_REL = Path("docs/architecture/reuse_corrections/v2/schema.json")

# Filled from the committed schema artifact.  Keeping it in code prevents a
# schema plus freshly rewritten sidecar from silently broadening authority.
AUTHORIZED_SCHEMA_SHA256 = "12578feb719858f84283ecb06dd31735df2f8656c1c11202c9f7d8478867af14"

AUTHORITY_SOURCE_PATHS = (
    "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json",
    "docs/architecture/V076_SUPERSESSION_MAP.json",
    "docs/architecture/V076_OWNER_REUSE_MAP.md",
)

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
    ):
        if not _is_sha256(record.get(field)):
            failures.append(f"EXTENSION_RECORD_{field.upper()}_INVALID")
    if not isinstance(record.get("batch_id"), str) or not re.fullmatch(r"batch-[0-9]{3}", record.get("batch_id", "")):
        failures.append("EXTENSION_RECORD_BATCH_ID_INVALID")
    if record.get("record_payload_sha256") != sha256_bytes(canonical_bytes(_record_payload(record))):
        failures.append("EXTENSION_RECORD_PAYLOAD_HASH_MISMATCH")
    return sorted(set(failures))


def validate_extension_record_against_repo(
    root: Path,
    record: dict[str, Any],
    *,
    evaluated_head: str,
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
            source_commit = str(binding.get("source_commit", ""))
            if _is_commit(source_commit) and not _is_ancestor(root, source_commit, AUTHORIZATION_BASE_HEAD_SHA):
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
        "record_chain_terminal_sha256",
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


def validate_previous_batch_link(
    manifest: Any,
    previous_batch_manifest_path: Path | None,
) -> list[str]:
    """Validate only the explicitly supplied immediate predecessor manifest.

    No directory enumeration is permitted to infer authority.  The first
    batch has no predecessor manifest and must continue the legacy terminal;
    every later batch must name the exact predecessor bytes via
    ``previous_batch_append_sha256`` and continue its record terminal.
    """
    if not isinstance(manifest, dict):
        return ["BATCH_MANIFEST_NOT_OBJECT"]
    failures: list[str] = []
    previous_append_sha = manifest.get("previous_batch_append_sha256")
    if previous_batch_manifest_path is None:
        if previous_append_sha:
            failures.append("BATCH_PREVIOUS_MANIFEST_REQUIRED")
        return failures
    if not previous_append_sha:
        return ["BATCH_PREVIOUS_MANIFEST_UNEXPECTED_FOR_INITIAL_BATCH"]
    try:
        previous_manifest = load_json_strict(previous_batch_manifest_path)
    except (OSError, ValueError, json.JSONDecodeError):
        return ["BATCH_PREVIOUS_MANIFEST_JSON_INVALID"]
    if not isinstance(previous_manifest, dict):
        return ["BATCH_PREVIOUS_MANIFEST_NOT_OBJECT"]
    for failure in validate_batch_manifest_document(previous_manifest):
        failures.append(f"BATCH_PREVIOUS_MANIFEST_INVALID:{failure}")
    if sha256_file(previous_batch_manifest_path) != previous_append_sha:
        failures.append("BATCH_PREVIOUS_MANIFEST_SHA256_MISMATCH")
    if manifest.get("record_chain_start_sha256") != previous_manifest.get("record_chain_terminal_sha256"):
        failures.append("BATCH_PREVIOUS_MANIFEST_CHAIN_TERMINAL_MISMATCH")
    current_match = re.fullmatch(r"batch-([0-9]{3})", str(manifest.get("batch_id", "")))
    previous_match = re.fullmatch(r"batch-([0-9]{3})", str(previous_manifest.get("batch_id", "")))
    if (
        current_match is None
        or previous_match is None
        or int(current_match.group(1)) != int(previous_match.group(1)) + 1
    ):
        failures.append("BATCH_PREVIOUS_MANIFEST_SEQUENCE_MISMATCH")
    if previous_manifest.get("terminal_remainder_batch") is True:
        failures.append("BATCH_PREVIOUS_MANIFEST_ALREADY_TERMINAL")
    current_fingerprints = {
        str(value) for value in manifest.get("failure_fingerprints", [])
    }
    previous_fingerprints = {
        str(value) for value in previous_manifest.get("failure_fingerprints", [])
    }
    for fingerprint in sorted(current_fingerprints & previous_fingerprints):
        failures.append(f"BATCH_PREVIOUS_MANIFEST_FINGERPRINT_REUSE:{fingerprint}")
    return sorted(set(failures))


def validate_batch_manifest_against_repo(
    root: Path,
    manifest_path: Path,
    *,
    evaluated_head: str,
    baseline_report_path: Path | None = None,
    previous_batch_manifest_path: Path | None = None,
) -> dict[str, Any]:
    failures = validate_schema(root)
    legacy = verify_legacy_anchor(root)
    failures.extend(legacy["failures"])
    try:
        manifest = load_json_strict(manifest_path)
    except (OSError, ValueError, json.JSONDecodeError):
        manifest = {}
        failures.append("BATCH_MANIFEST_JSON_INVALID")
    failures.extend(validate_batch_manifest_document(manifest))
    if not isinstance(manifest, dict):
        manifest = {}
    failures.extend(validate_previous_batch_link(manifest, previous_batch_manifest_path))
    manifest_binding_head = str(manifest.get("binding_head_sha", ""))
    if _is_commit(manifest_binding_head):
        if not _is_ancestor(root, AUTHORIZATION_BASE_HEAD_SHA, manifest_binding_head):
            failures.append("BATCH_MANIFEST_BINDING_HEAD_NOT_AUTHORIZED_DESCENDANT")
        if not _is_ancestor(root, manifest_binding_head, evaluated_head):
            failures.append("BATCH_MANIFEST_EVALUATED_HEAD_NOT_BINDING_DESCENDANT")
        try:
            manifest_tree = _git(root, "rev-parse", f"{manifest_binding_head}^{{tree}}")
        except ValueError:
            manifest_tree = ""
            failures.append("BATCH_MANIFEST_BINDING_HEAD_UNRESOLVED")
        if manifest.get("binding_tree_sha") != manifest_tree:
            failures.append("BATCH_MANIFEST_BINDING_TREE_MISMATCH")
    legacy_fingerprints = set(legacy.get("legacy_corrected_fingerprints", []))
    new_fingerprints = {
        str(value)
        for value in manifest.get("failure_fingerprints", [])
    }
    for fingerprint in sorted(legacy_fingerprints & new_fingerprints):
        failures.append(f"BATCH_LEGACY_FINGERPRINT_REUSE:{fingerprint}")
    if baseline_report_path is None:
        authorized_fingerprints = {"historical": set(), "current": set()}
        failures.append("BATCH_BASELINE_REPORT_REQUIRED")
    else:
        baseline = validate_authorized_baseline(baseline_report_path)
        failures.extend(
            f"BATCH_BASELINE_INVALID:{failure}" for failure in baseline.get("failures", [])
        )
        try:
            baseline_report = load_json_strict(baseline_report_path)
            authorized_fingerprints = authorized_failure_fingerprint_sets(baseline_report)
        except (OSError, ValueError, json.JSONDecodeError):
            authorized_fingerprints = {"historical": set(), "current": set()}
            failures.append("BATCH_BASELINE_FINGERPRINT_SET_UNRESOLVED")
    for fingerprint in sorted(new_fingerprints):
        if fingerprint in authorized_fingerprints["current"]:
            failures.append(f"BATCH_CURRENT_FAILURE_CORRECTION_FALSE_ACCEPT:{fingerprint}")
        elif fingerprint not in authorized_fingerprints["historical"]:
            failures.append(f"BATCH_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL:{fingerprint}")
    seen: set[str] = set()
    for index, binding in enumerate(manifest.get("record_bindings", [])):
        if not isinstance(binding, dict):
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
        except (OSError, ValueError, json.JSONDecodeError):
            failures.append(f"BATCH_RECORD_JSON_INVALID:{index}")
            continue
        if not isinstance(record, dict):
            failures.append(f"BATCH_RECORD_NOT_OBJECT:{index}")
            continue
        failures.extend(validate_extension_record_against_repo(root, record, evaluated_head=evaluated_head))
        if record.get("binding_head_sha") != manifest.get("binding_head_sha"):
            failures.append(f"BATCH_RECORD_BINDING_HEAD_MISMATCH:{index}")
        if record.get("binding_tree_sha") != manifest.get("binding_tree_sha"):
            failures.append(f"BATCH_RECORD_BINDING_TREE_MISMATCH:{index}")
        if record.get("correction_id") != binding.get("correction_id"):
            failures.append(f"BATCH_RECORD_ID_MISMATCH:{index}")
        if record.get("record_payload_sha256") != binding.get("record_payload_sha256"):
            failures.append(f"BATCH_RECORD_PAYLOAD_MISMATCH:{index}")
        for fingerprint in record.get("failure_fingerprints", []):
            if fingerprint in seen:
                failures.append(f"BATCH_RECORD_FINGERPRINT_DUPLICATE:{fingerprint}")
            seen.add(str(fingerprint))
    for fingerprint in sorted(seen & legacy_fingerprints):
        failures.append(f"BATCH_RECORD_LEGACY_FINGERPRINT_REUSE:{fingerprint}")
    for fingerprint in sorted(seen):
        if fingerprint in authorized_fingerprints["current"]:
            failures.append(f"BATCH_RECORD_CURRENT_FAILURE_CORRECTION_FALSE_ACCEPT:{fingerprint}")
        elif fingerprint not in authorized_fingerprints["historical"]:
            failures.append(f"BATCH_RECORD_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL:{fingerprint}")
    failures = sorted(set(failures))
    return {
        "schema_version": f"{BATCH_MANIFEST_SCHEMA_VERSION}.verification",
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD_SHA,
        "evaluated_head_sha": evaluated_head,
        "batch_id": manifest.get("batch_id", ""),
        "failure_count": len(seen),
        "legacy_record_chain_terminal_sha256": LEGACY_RECORD_CHAIN_TERMINAL_SHA256,
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
    }
