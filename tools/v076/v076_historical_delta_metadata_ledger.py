#!/usr/bin/env python3
"""Strict Historical Delta Metadata evidence for the V076 V2 resolver.

This module never scans product history and never suppresses a Raw failure.  It
validates one explicitly named, append-only evidence ledger and the exact V2
correction records bound by that ledger.  The only consumer is the existing
V076 exact-failure resolver.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any, Iterable


AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
AUTHORIZATION_BASE_HEAD_SHA = "d701a81dce693b584d52fbfca3e0e78b521ad775"
AUTHORIZED_RAW_REPORT_SHA256 = "28c3bb657b20f4d2e7f2eee14f1677d5bf5feb678883fe2f400ca54b89c629b0"
AUTHORIZED_RAW_REPORT_HEAD_SHA = "7b2bd08a9916a3a517f2d418765c544cce0261cc"
AUTHORIZED_RAW_REPORT_TREE_SHA = "990b070c3f7cfefa3bf6853ff22f9023049ede29"
AUTHORIZED_RAW_FAILURE_COUNT = 590
AUTHORIZED_RAW_NATIVE_HISTORICAL_COUNT = 505
AUTHORIZED_RAW_LEDGER_PROMOTED_COUNT = 82
AUTHORIZED_RAW_SEMANTIC_HISTORICAL_COUNT = 587
AUTHORIZED_RAW_TRUE_CURRENT_COUNT = 3
AUTHORIZED_LEDGER_FAILURE_COUNT = 86
LEDGER_SCHEMA_VERSION = "space_syndicate.v076.historical_delta_metadata_ledger.v1"
METADATA_RECORD_SCHEMA_VERSION = "space_syndicate.v076.historical_delta_metadata_record.v1"
CORRECTION_RECORD_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "historical_delta_metadata_record.v1"
)
SCHEMA_DOCUMENT_VERSION = "space_syndicate.v076.historical_delta_metadata_schema.v1"
LEDGER_ID = "V076_HISTORICAL_DELTA_METADATA_LEDGER"
LEDGER_PATH = "docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json"
REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
SCHEMA_PATH = "docs/architecture/V076_HISTORICAL_DELTA_METADATA_SCHEMA.json"
RAW_REPORT_ROOT = "reports/reuse/"
CORRECTION_RECORD_ROOT = "docs/architecture/reuse_corrections/v2/records/"

ALLOWED_RULE_IDS = {
    "NEW_COMPONENT_CANNOT_CLAIM_INHERITED",
    "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID",
}
TRANSITION_CLASS_BY_RULE = {
    "NEW_COMPONENT_CANNOT_CLAIM_INHERITED": (
        "HISTORICAL_COMPONENT_IDENTITY_METADATA_BACKFILL"
    ),
    "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID": (
        "HISTORICAL_AUTHORITY_REUSE_SCAN_METADATA_BACKFILL"
    ),
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


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def line_set_sha(values: Iterable[str]) -> str:
    rendered = sorted(str(value) for value in values)
    return sha256_bytes((("\n".join(rendered) + "\n") if rendered else "").encode())


def failure_fingerprint(raw_failure: str, rule_id: str) -> str:
    payload = f"V076_RAW_FAILURE_V2\nHISTORICAL\n{rule_id}\n{raw_failure}\n"
    return "V2F-" + sha256_bytes(payload.encode("utf-8"))


def payload_sha256(document: dict[str, Any], field: str) -> str:
    payload = dict(document)
    payload.pop(field, None)
    return sha256_bytes(canonical_bytes(payload))


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"DUPLICATE_JSON_KEY:{key}")
        result[key] = value
    return result


def _reject_non_finite_json_number(value: str) -> Any:
    raise ValueError(f"NON_FINITE_JSON_NUMBER:{value}")


def load_json_strict(path: Path) -> Any:
    return json.loads(
        path.read_text(encoding="utf-8-sig"),
        object_pairs_hook=_strict_object,
        parse_constant=_reject_non_finite_json_number,
    )


def _load_json_bytes_strict(payload: bytes) -> Any:
    return json.loads(
        payload.decode("utf-8-sig"),
        object_pairs_hook=_strict_object,
        parse_constant=_reject_non_finite_json_number,
    )


def _git_environment() -> dict[str, str]:
    environment = dict(os.environ)
    environment["GIT_NO_REPLACE_OBJECTS"] = "1"
    return environment


def _grafts_file_nonempty(root: Path) -> bool:
    grafts_value = _git(root, "rev-parse", "--git-path", "info/grafts")
    grafts_path = Path(grafts_value)
    if not grafts_path.is_absolute():
        grafts_path = root / grafts_path
    try:
        return grafts_path.is_file() and bool(grafts_path.read_bytes().strip())
    except OSError as exc:
        raise ValueError("GIT_GRAFTS_STATE_UNREADABLE") from exc


def _git(root: Path, *args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        env=_git_environment(),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and result.returncode != 0:
        raise ValueError(result.stderr.strip() or "GIT_COMMAND_FAILED")
    return result.stdout.strip()


def _git_nul_paths(root: Path, *args: str) -> list[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        env=_git_environment(),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise ValueError(
            result.stderr.decode("utf-8", errors="replace").strip()
            or "GIT_COMMAND_FAILED"
        )
    if not result.stdout:
        return []
    if not result.stdout.endswith(b"\0"):
        raise ValueError("GIT_NUL_PATH_OUTPUT_INVALID")
    try:
        return [
            value.decode("utf-8")
            for value in result.stdout[:-1].split(b"\0")
        ]
    except UnicodeDecodeError as exc:
        raise ValueError("GIT_PATH_NOT_UTF8") from exc


def _git_bytes(root: Path, ref: str, relative: str) -> bytes | None:
    tree_result = subprocess.run(
        ["git", "ls-tree", "-z", ref, "--", f":(literal){relative}"],
        cwd=root,
        env=_git_environment(),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if tree_result.returncode != 0 or not tree_result.stdout:
        return None
    entries = tree_result.stdout.split(b"\0")
    if entries[-1] != b"" or len(entries) != 2:
        return None
    metadata, separator, raw_path = entries[0].partition(b"\t")
    if separator != b"\t":
        return None
    fields = metadata.split()
    if len(fields) != 3:
        return None
    mode, object_type, object_id = fields
    try:
        path_value = raw_path.decode("utf-8")
        object_id_value = object_id.decode("ascii")
    except (UnicodeDecodeError, ValueError):
        return None
    if (
        path_value != relative
        or object_type != b"blob"
        or mode not in {b"100644", b"100755"}
        or re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", object_id_value) is None
    ):
        return None
    blob_result = subprocess.run(
        ["git", "cat-file", "blob", object_id_value],
        cwd=root,
        env=_git_environment(),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return blob_result.stdout if blob_result.returncode == 0 else None


def _resolve_commit(root: Path, value: str) -> str:
    resolved = _git(root, "rev-parse", f"{value}^{{commit}}")
    if not re.fullmatch(r"[0-9a-f]{40}", resolved):
        raise ValueError(f"COMMIT_INVALID:{value}")
    return resolved


def _is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", ancestor, descendant],
        cwd=root,
        env=_git_environment(),
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def _component_rows(payload: bytes) -> dict[str, dict[str, Any]]:
    document = _load_json_bytes_strict(payload)
    rows = document.get("component_inventory") if isinstance(document, dict) else None
    if not isinstance(rows, list):
        raise ValueError("REGISTRY_COMPONENT_INVENTORY_INVALID")
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("component_id"), str):
            raise ValueError("REGISTRY_COMPONENT_ROW_INVALID")
        component_id = row["component_id"]
        if component_id in result:
            raise ValueError(f"REGISTRY_COMPONENT_ID_DUPLICATE:{component_id}")
        result[component_id] = row
    return result


def _reuse_entry_ids(payload: bytes) -> set[str]:
    document = _load_json_bytes_strict(payload)
    rows = document.get("reuse_entries") if isinstance(document, dict) else None
    if not isinstance(rows, list):
        raise ValueError("REGISTRY_REUSE_ENTRIES_INVALID")
    result: set[str] = set()
    for row in rows:
        reuse_id = row.get("reuse_id") if isinstance(row, dict) else None
        if not isinstance(reuse_id, str) or not reuse_id or reuse_id in result:
            raise ValueError(f"REGISTRY_REUSE_ENTRY_INVALID:{reuse_id}")
        result.add(reuse_id)
    return result


def _domain_rows(payload: bytes) -> dict[str, dict[str, Any]]:
    document = _load_json_bytes_strict(payload)
    rows = document.get("domain_inventory") if isinstance(document, dict) else None
    if not isinstance(rows, list):
        raise ValueError("REGISTRY_DOMAIN_INVENTORY_INVALID")
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        domain_id = row.get("domain_id") if isinstance(row, dict) else None
        if not isinstance(domain_id, str) or not domain_id or domain_id in result:
            raise ValueError(f"REGISTRY_DOMAIN_ROW_INVALID:{domain_id}")
        result[domain_id] = row
    return result


def _component_sha256(row: dict[str, Any]) -> str:
    return sha256_bytes(canonical_bytes(row))


def _valid_reuse_scan(row: dict[str, Any], reuse_entry_ids: set[str]) -> bool:
    scan = row.get("reuse_scan")
    candidates = scan.get("reuse_candidate_ids") if isinstance(scan, dict) else None
    considered = row.get("reuse_candidates_considered")
    return bool(
        isinstance(scan, dict)
        and set(scan) == REUSE_SCAN_FIELDS
        and all(scan.get(key) is True for key in REUSE_SCAN_FIELDS if key.endswith("_search"))
        and isinstance(candidates, list)
        and candidates
        and all(isinstance(candidate, str) and candidate in reuse_entry_ids for candidate in candidates)
        and len(candidates) == len(set(map(str, candidates)))
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


def _exact_sorted_strings(value: Any, *, allow_empty: bool = False) -> bool:
    return bool(
        isinstance(value, list)
        and (allow_empty or value)
        and all(isinstance(item, str) and item.strip() for item in value)
        and value == sorted(set(value))
    )


def _resolve_repo_path(
    root: Path,
    value: Any,
    *,
    required_prefix: str | None = None,
) -> Path:
    if not isinstance(value, str) or not value or "\\" in value:
        raise ValueError("PATH_NOT_CANONICAL_REPOSITORY_RELATIVE")
    candidate = Path(value)
    if candidate.is_absolute() or candidate.as_posix() != value:
        raise ValueError("PATH_NOT_CANONICAL_REPOSITORY_RELATIVE")
    if any(part in {"", ".", ".."} for part in candidate.parts):
        raise ValueError("PATH_TRAVERSAL_FORBIDDEN")
    if required_prefix is not None and not value.startswith(required_prefix):
        raise ValueError(f"PATH_PREFIX_MISMATCH:{required_prefix}")
    resolved = (root / candidate).resolve()
    try:
        resolved.relative_to(root.resolve())
    except ValueError as exc:
        raise ValueError("PATH_OUTSIDE_REPOSITORY") from exc
    return resolved


def _history_touched_paths(root: Path, older: str, newer: str) -> set[str]:
    if older == newer:
        return set()
    if not _is_ancestor(root, older, newer):
        raise ValueError("TOUCH_RANGE_NOT_ANCESTRAL")
    commits = _git(root, "rev-list", f"{older}..{newer}").splitlines()
    touched: set[str] = set()
    for commit in commits:
        values = _git_nul_paths(
            root,
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            "-m",
            "-z",
            commit,
        )
        touched.update(value for value in values if value)
    return touched


def _schema_failures(schema: Any) -> list[str]:
    failures: list[str] = []
    expected = {
        "schema_version": SCHEMA_DOCUMENT_VERSION,
        "ledger_schema_version": LEDGER_SCHEMA_VERSION,
        "historical_record_schema_version": METADATA_RECORD_SCHEMA_VERSION,
        "metadata_record_schema_version": METADATA_RECORD_SCHEMA_VERSION,
        "correction_record_schema_version": CORRECTION_RECORD_SCHEMA_VERSION,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD_SHA,
        "authorized_raw_report_sha256": AUTHORIZED_RAW_REPORT_SHA256,
        "authorized_raw_report_head_sha": AUTHORIZED_RAW_REPORT_HEAD_SHA,
        "authorized_raw_report_tree_sha": AUTHORIZED_RAW_REPORT_TREE_SHA,
        "authorized_raw_failure_count": AUTHORIZED_RAW_FAILURE_COUNT,
        "authorized_raw_native_historical_count": AUTHORIZED_RAW_NATIVE_HISTORICAL_COUNT,
        "authorized_raw_ledger_promoted_count": AUTHORIZED_RAW_LEDGER_PROMOTED_COUNT,
        "authorized_raw_semantic_historical_count": AUTHORIZED_RAW_SEMANTIC_HISTORICAL_COUNT,
        "authorized_raw_true_current_count": AUTHORIZED_RAW_TRUE_CURRENT_COUNT,
        "authorized_ledger_failure_count": AUTHORIZED_LEDGER_FAILURE_COUNT,
        "canonical_ledger_path": LEDGER_PATH,
        "raw_report_root": RAW_REPORT_ROOT,
        "correction_record_root": CORRECTION_RECORD_ROOT,
        "allowed_rule_ids": sorted(ALLOWED_RULE_IDS),
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
    if schema != expected:
        failures.append("HISTORICAL_DELTA_SCHEMA_MISMATCH")
    return failures


def _append_only_failures(
    root: Path, evaluated_head: str, ledger_path: str, ledger: dict[str, Any]
) -> tuple[list[str], dict[str, str]]:
    failures: list[str] = []
    activation_by_fingerprint: dict[str, str] = {}
    graph = [
        line.split()
        for line in _git(
            root,
            "rev-list",
            "--parents",
            "--reverse",
            "--topo-order",
            evaluated_head,
        ).splitlines()
        if line
    ]
    path_history_commits = set(
        _git(
            root,
            "rev-list",
            "--full-history",
            "--topo-order",
            evaluated_head,
            "--",
            ledger_path,
        ).splitlines()
    )
    transition_commits = path_history_commits | {
        identity[0] for identity in graph if len(identity) > 2
    }
    transition_commits.add(evaluated_head)
    version_bytes_by_commit: dict[str, bytes | None] = {}

    def version_bytes(commit: str) -> bytes | None:
        if commit not in version_bytes_by_commit:
            version_bytes_by_commit[commit] = _git_bytes(root, commit, ledger_path)
        return version_bytes_by_commit[commit]

    version_by_sha: dict[str, dict[str, Any] | None] = {}

    def version_document(payload: bytes) -> dict[str, Any] | None:
        payload_sha = sha256_bytes(payload)
        if payload_sha in version_by_sha:
            return version_by_sha[payload_sha]
        try:
            document = _load_json_bytes_strict(payload)
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
            failures.append("HISTORICAL_DELTA_PRIOR_LEDGER_INVALID")
            version_by_sha[payload_sha] = None
            return None
        if not isinstance(document, dict):
            failures.append("HISTORICAL_DELTA_PRIOR_LEDGER_NOT_OBJECT")
            version_by_sha[payload_sha] = None
            return None
        if set(document) != LEDGER_FIELDS or document.get(
            "ledger_payload_sha256"
        ) != payload_sha256(document, "ledger_payload_sha256"):
            failures.append("HISTORICAL_DELTA_PRIOR_LEDGER_SEAL_INVALID")
        version_by_sha[payload_sha] = document
        return document

    def require_literal_prefix(
        previous: dict[str, Any] | None,
        current: dict[str, Any] | None,
    ) -> None:
        for field in ("records", "correction_record_bindings"):
            old = previous.get(field) if isinstance(previous, dict) else None
            new = current.get(field) if isinstance(current, dict) else None
            if (
                not isinstance(old, list)
                or not isinstance(new, list)
                or new[: len(old)] != old
            ):
                failures.append(
                    f"HISTORICAL_DELTA_APPEND_ONLY_{field.upper()}_MUTATION"
                )

    introduction_commits: set[str] = set()
    for identity in graph:
        commit, *parents = identity
        if commit not in transition_commits:
            continue
        current_bytes = version_bytes(commit)
        parent_versions = [
            (parent, version_bytes(parent)) for parent in parents
        ]
        present_parents = [
            (parent, payload)
            for parent, payload in parent_versions
            if payload is not None
        ]
        if current_bytes is None:
            if present_parents:
                failures.append("HISTORICAL_DELTA_LEDGER_HISTORY_DELETION")
            continue

        current_document = version_document(current_bytes)
        if not present_parents:
            introduction_commits.add(commit)
            if isinstance(current_document, dict) and (
                current_document.get("previous_ledger_path")
                or current_document.get("previous_ledger_sha256")
            ):
                failures.append(
                    "HISTORICAL_DELTA_UNEXPECTED_PREVIOUS_LEDGER_BINDING"
                )
            continue

        matching_parent_exists = any(
            payload == current_bytes for _, payload in present_parents
        )
        if not matching_parent_exists:
            expected_hashes = {
                sha256_bytes(payload)
                for _, payload in present_parents
                if payload is not None
            }
            if not isinstance(current_document, dict) or current_document.get(
                "previous_ledger_path"
            ) != ledger_path:
                failures.append("HISTORICAL_DELTA_PREVIOUS_LEDGER_PATH_MISMATCH")
            if not isinstance(current_document, dict) or current_document.get(
                "previous_ledger_sha256"
            ) not in expected_hashes:
                failures.append("HISTORICAL_DELTA_PREVIOUS_LEDGER_HASH_MISMATCH")

        distinct_parent_payloads: dict[str, bytes] = {}
        for _, payload in present_parents:
            if payload is None or payload == current_bytes:
                continue
            distinct_parent_payloads.setdefault(sha256_bytes(payload), payload)
        for parent_payload in distinct_parent_payloads.values():
            require_literal_prefix(
                version_document(parent_payload),
                current_document,
            )

    if len(introduction_commits) > 1:
        failures.append("HISTORICAL_DELTA_LEDGER_HISTORY_REINTRODUCTION")

    first_parent_commits = _git(
        root,
        "rev-list",
        "--first-parent",
        "--reverse",
        evaluated_head,
    ).splitlines()
    for commit in first_parent_commits:
        if commit not in path_history_commits:
            continue
        payload = version_bytes(commit)
        if payload is None:
            continue
        version = version_document(payload)
        if not isinstance(version, dict):
            continue
        version_records = version.get("records")
        if isinstance(version_records, list):
            for record in version_records:
                version_bindings = (
                    record.get("failure_bindings")
                    if isinstance(record, dict)
                    else None
                )
                if not isinstance(version_bindings, list):
                    continue
                for binding in version_bindings:
                    fingerprint = (
                        binding.get("failure_fingerprint")
                        if isinstance(binding, dict)
                        else None
                    )
                    if (
                        isinstance(fingerprint, str)
                        and re.fullmatch(r"V2F-[0-9a-f]{64}", fingerprint)
                        and fingerprint not in activation_by_fingerprint
                    ):
                        activation_by_fingerprint[fingerprint] = commit

    head_bytes = version_bytes(evaluated_head)
    current_version = version_document(head_bytes) if head_bytes is not None else None
    if current_version != ledger:
        failures.append("HISTORICAL_DELTA_CURRENT_LEDGER_HISTORY_MISMATCH")
    return failures, activation_by_fingerprint


def _registry_snapshot_at(
    root: Path,
    commit: str,
    cache: dict[
        str,
        tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]],
    ],
) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    if commit in cache:
        return cache[commit]
    registry_bytes = _git_bytes(root, commit, REGISTRY_PATH)
    if registry_bytes is None:
        raise ValueError(f"REGISTRY_HISTORY_BLOB_MISSING:{commit}")
    snapshot = (
        _component_rows(registry_bytes),
        _domain_rows(registry_bytes),
    )
    cache[commit] = snapshot
    return snapshot


def _registry_row_history_changes(
    root: Path,
    activation_commit: str,
    evaluated_head: str,
    cache: dict[
        str,
        tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]],
    ],
) -> tuple[set[str], set[str], set[str]]:
    if not _is_ancestor(root, activation_commit, evaluated_head):
        raise ValueError("ACTIVATION_NOT_IN_EVALUATED_HISTORY")
    commits = _git(
        root,
        "rev-list",
        "--reverse",
        f"{activation_commit}^..{evaluated_head}",
    ).splitlines()
    changed_components: set[str] = set()
    changed_domains: set[str] = set()
    changed_reachability: set[str] = set()
    for commit in commits:
        identity = _git(root, "rev-list", "--parents", "-n", "1", commit).split()
        if len(identity) < 2:
            raise ValueError(f"ACTIVATION_TRANSITION_PARENT_MISSING:{commit}")
        current_components, current_domains = _registry_snapshot_at(root, commit, cache)
        for parent in identity[1:]:
            parent_components, parent_domains = _registry_snapshot_at(
                root, parent, cache
            )
            for component_id in set(parent_components) | set(current_components):
                before = parent_components.get(component_id)
                after = current_components.get(component_id)
                if (
                    before is None
                    or after is None
                    or _component_sha256(before) != _component_sha256(after)
                ):
                    changed_components.add(component_id)
                    if (
                        before is None
                        or after is None
                        or before.get("production_reachable")
                        != after.get("production_reachable")
                    ):
                        changed_reachability.add(component_id)
            for domain_id in set(parent_domains) | set(current_domains):
                before = parent_domains.get(domain_id)
                after = current_domains.get(domain_id)
                if (
                    before is None
                    or after is None
                    or _component_sha256(before) != _component_sha256(after)
                ):
                    changed_domains.add(domain_id)
    return changed_components, changed_domains, changed_reachability


def validate_ledger(
    root: Path,
    ledger_path: Path,
    *,
    evaluated_head: str,
    history_ancestry_anchor: str = AUTHORIZATION_BASE_HEAD_SHA,
    test_raw_authority_override: dict[str, int | str] | None = None,
) -> dict[str, Any]:
    """Validate one explicit ledger and return exact V2 authority projection."""
    root = root.resolve()
    ledger_path = ledger_path.resolve()
    failures: list[str] = []
    if re.fullmatch(r"[0-9a-f]{40}", evaluated_head) is None:
        return {
            "status": "FAIL",
            "failures": ["HISTORICAL_DELTA_EVALUATED_HEAD_NOT_EXACT_COMMIT"],
        }
    if re.fullmatch(r"[0-9a-f]{40}", history_ancestry_anchor) is None:
        return {
            "status": "FAIL",
            "failures": ["HISTORICAL_DELTA_ANCESTRY_ANCHOR_NOT_EXACT_COMMIT"],
        }
    try:
        if _grafts_file_nonempty(root):
            return {
                "status": "FAIL",
                "failures": ["HISTORICAL_DELTA_GIT_GRAFTS_FORBIDDEN"],
            }
    except ValueError as exc:
        return {
            "status": "FAIL",
            "failures": [f"HISTORICAL_DELTA_GIT_GRAFTS_INVALID:{exc}"],
        }
    authorized_repository = False
    try:
        _resolve_commit(root, AUTHORIZATION_BASE_HEAD_SHA)
        authorized_repository = True
    except ValueError:
        # Synthetic self-test repositories intentionally do not contain the
        # production authorization anchor.
        pass
    if authorized_repository and history_ancestry_anchor != AUTHORIZATION_BASE_HEAD_SHA:
        return {
            "status": "FAIL",
            "failures": ["HISTORICAL_DELTA_TEST_ANCESTRY_OVERRIDE_FORBIDDEN"],
        }
    if authorized_repository and test_raw_authority_override is not None:
        return {
            "status": "FAIL",
            "failures": ["HISTORICAL_DELTA_TEST_RAW_AUTHORITY_OVERRIDE_FORBIDDEN"],
        }
    try:
        head = _resolve_commit(root, evaluated_head)
    except ValueError as exc:
        return {"status": "FAIL", "failures": [str(exc)]}
    try:
        relative_ledger = ledger_path.relative_to(root).as_posix()
    except ValueError:
        return {"status": "FAIL", "failures": ["HISTORICAL_DELTA_LEDGER_OUTSIDE_REPOSITORY"]}
    if relative_ledger != LEDGER_PATH:
        return {"status": "FAIL", "failures": ["HISTORICAL_DELTA_LEDGER_PATH_MISMATCH"]}
    committed_ledger_bytes = _git_bytes(root, head, relative_ledger)
    try:
        worktree_ledger_bytes = ledger_path.read_bytes()
    except OSError as exc:
        return {
            "status": "FAIL",
            "failures": [f"HISTORICAL_DELTA_LEDGER_INVALID:{exc}"],
        }
    if (
        committed_ledger_bytes is None
        or committed_ledger_bytes != worktree_ledger_bytes
    ):
        failures.append("HISTORICAL_DELTA_LEDGER_COMMITTED_BYTES_MISMATCH")
    if committed_ledger_bytes is None:
        return {
            "status": "FAIL",
            "failures": sorted(set(failures)),
        }
    try:
        ledger = _load_json_bytes_strict(committed_ledger_bytes)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        return {
            "status": "FAIL",
            "failures": sorted(
                set(
                    [
                        *failures,
                        f"HISTORICAL_DELTA_LEDGER_INVALID:{exc}",
                    ]
                )
            ),
        }
    if not isinstance(ledger, dict):
        return {
            "status": "FAIL",
            "failures": sorted(
                set([*failures, "HISTORICAL_DELTA_LEDGER_NOT_OBJECT"])
            ),
        }
    if set(ledger) != LEDGER_FIELDS:
        failures.append("HISTORICAL_DELTA_LEDGER_FIELD_SET_MISMATCH")
    for field, expected in (
        ("schema_version", LEDGER_SCHEMA_VERSION),
        ("ledger_id", LEDGER_ID),
        ("authorization_id", AUTHORIZATION_ID),
        ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD_SHA),
        ("schema_path", SCHEMA_PATH),
        ("registry_path", REGISTRY_PATH),
        ("scanner_path", "tools/v076/v076_reuse_point_inertia_gate.py"),
        ("selector_policy", EXACT_SELECTOR_POLICY),
        ("append_only", True),
    ):
        if ledger.get(field) != expected:
            failures.append(f"HISTORICAL_DELTA_LEDGER_{field.upper()}_MISMATCH")
    if ledger.get("ledger_payload_sha256") != payload_sha256(
        ledger, "ledger_payload_sha256"
    ):
        failures.append("HISTORICAL_DELTA_LEDGER_PAYLOAD_HASH_MISMATCH")
    append_only_failures, activation_by_fingerprint = _append_only_failures(
        root, head, relative_ledger, ledger
    )
    failures.extend(append_only_failures)

    raw_authority: dict[str, int | str] = test_raw_authority_override or {
        "sha256": AUTHORIZED_RAW_REPORT_SHA256,
        "head_sha": AUTHORIZED_RAW_REPORT_HEAD_SHA,
        "tree_sha": AUTHORIZED_RAW_REPORT_TREE_SHA,
        "failure_count": AUTHORIZED_RAW_FAILURE_COUNT,
        "native_historical_count": AUTHORIZED_RAW_NATIVE_HISTORICAL_COUNT,
        "ledger_promoted_count": AUTHORIZED_RAW_LEDGER_PROMOTED_COUNT,
        "semantic_historical_count": AUTHORIZED_RAW_SEMANTIC_HISTORICAL_COUNT,
        "true_current_count": AUTHORIZED_RAW_TRUE_CURRENT_COUNT,
        "ledger_failure_count": AUTHORIZED_LEDGER_FAILURE_COUNT,
    }
    schema_path = root / str(ledger.get("schema_path", ""))
    try:
        schema_bytes = _git_bytes(root, head, SCHEMA_PATH)
        if schema_bytes is None or schema_bytes != schema_path.read_bytes():
            raise ValueError("SCHEMA_COMMITTED_BYTES_MISMATCH")
        schema = _load_json_bytes_strict(schema_bytes)
        failures.extend(_schema_failures(schema))
        if ledger.get("schema_sha256") != sha256_bytes(schema_bytes):
            failures.append("HISTORICAL_DELTA_SCHEMA_FILE_HASH_MISMATCH")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        failures.append(f"HISTORICAL_DELTA_SCHEMA_INVALID:{exc}")

    try:
        raw_path = _resolve_repo_path(
            root,
            ledger.get("raw_report_path"),
            required_prefix=RAW_REPORT_ROOT,
        )
        relative_raw = raw_path.relative_to(root).as_posix()
        raw_bytes = _git_bytes(root, head, relative_raw)
        if raw_bytes is None or raw_bytes != raw_path.read_bytes():
            raise ValueError("RAW_REPORT_COMMITTED_BYTES_MISMATCH")
        raw_report = _load_json_bytes_strict(raw_bytes)
        raw_sha = sha256_bytes(raw_bytes)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raw_report = {}
        raw_sha = ""
        failures.append(f"HISTORICAL_DELTA_RAW_REPORT_INVALID:{exc}")
    if ledger.get("raw_report_sha256") != raw_sha:
        failures.append("HISTORICAL_DELTA_RAW_REPORT_HASH_MISMATCH")
    if raw_sha != raw_authority.get("sha256"):
        failures.append("HISTORICAL_DELTA_RAW_REPORT_NOT_AUTHORIZED")
    raw_head = str(ledger.get("raw_report_head_sha", ""))
    touched_paths: set[str] = set()
    try:
        if re.fullmatch(r"[0-9a-f]{40}", raw_head) is None:
            raise ValueError("RAW_HEAD_NOT_EXACT_COMMIT")
        raw_head = _resolve_commit(root, raw_head)
        raw_tree = _git(root, "rev-parse", f"{raw_head}^{{tree}}")
        if ledger.get("raw_report_tree_sha") != raw_tree:
            failures.append("HISTORICAL_DELTA_RAW_REPORT_TREE_MISMATCH")
        if raw_head != raw_authority.get("head_sha"):
            failures.append("HISTORICAL_DELTA_RAW_REPORT_HEAD_NOT_AUTHORIZED")
        if raw_tree != raw_authority.get("tree_sha"):
            failures.append("HISTORICAL_DELTA_RAW_REPORT_TREE_NOT_AUTHORIZED")
        if not _is_ancestor(root, raw_head, head):
            failures.append("HISTORICAL_DELTA_RAW_HEAD_NOT_EVALUATED_ANCESTOR")
        else:
            touched_paths = _history_touched_paths(root, raw_head, head)
    except ValueError as exc:
        failures.append(f"HISTORICAL_DELTA_RAW_HEAD_INVALID:{exc}")
    raw_values = raw_report.get("failures") if isinstance(raw_report, dict) else None
    if not isinstance(raw_values, list) or any(not isinstance(value, str) for value in raw_values):
        raw_values = []
        failures.append("HISTORICAL_DELTA_RAW_FAILURE_LIST_INVALID")
    if len(raw_values) != len(set(raw_values)):
        failures.append("HISTORICAL_DELTA_RAW_FAILURE_DUPLICATE")
    if len(raw_values) != raw_authority.get("failure_count"):
        failures.append("HISTORICAL_DELTA_RAW_FAILURE_COUNT_MISMATCH")
    if isinstance(raw_report, dict):
        expected_raw_status = "PASS" if not raw_values else "FAIL"
        if raw_report.get("status") != expected_raw_status:
            failures.append("HISTORICAL_DELTA_RAW_REPORT_STATUS_MISMATCH")
        if raw_report.get("head_sha") != raw_head:
            failures.append("HISTORICAL_DELTA_RAW_REPORT_HEAD_MISMATCH")
        if raw_report.get("include_worktree") is not False:
            failures.append("HISTORICAL_DELTA_RAW_REPORT_NOT_COMMITTED_ONLY")
        if raw_report.get("evaluated_source") != "COMMITTED_HEAD":
            failures.append("HISTORICAL_DELTA_RAW_REPORT_SOURCE_MISMATCH")

    scanner_path = str(ledger.get("scanner_path", ""))
    scanner_bytes = _git_bytes(root, raw_head, scanner_path) if raw_head else None
    if scanner_bytes is None or ledger.get("scanner_sha256") != sha256_bytes(scanner_bytes):
        failures.append("HISTORICAL_DELTA_SCANNER_BINDING_MISMATCH")

    current_registry_bytes = _git_bytes(root, head, REGISTRY_PATH)
    try:
        current_components = (
            _component_rows(current_registry_bytes) if current_registry_bytes is not None else {}
        )
        current_reuse_entry_ids = (
            _reuse_entry_ids(current_registry_bytes)
            if current_registry_bytes is not None
            else set()
        )
        current_domains = (
            _domain_rows(current_registry_bytes)
            if current_registry_bytes is not None
            else {}
        )
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        current_components = {}
        current_reuse_entry_ids = set()
        current_domains = {}
        failures.append(f"HISTORICAL_DELTA_CURRENT_REGISTRY_INVALID:{exc}")

    records = ledger.get("records")
    if not isinstance(records, list):
        records = []
        failures.append("HISTORICAL_DELTA_RECORD_LIST_INVALID")
    if type(ledger.get("record_count")) is not int or ledger.get("record_count") != len(records):
        failures.append("HISTORICAL_DELTA_RECORD_COUNT_MISMATCH")
    previous_record_hash = "0" * 64
    seen_record_ids: set[str] = set()
    seen_sources: set[str] = set()
    seen_fingerprints: set[str] = set()
    binding_by_fingerprint: dict[str, dict[str, Any]] = {}
    record_by_id: dict[str, dict[str, Any]] = {}
    registry_snapshot_cache: dict[
        str,
        tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]],
    ] = {}
    registry_changes_by_activation: dict[
        str,
        tuple[set[str], set[str], set[str]],
    ] = {}
    for record in records:
        if not isinstance(record, dict) or set(record) != METADATA_RECORD_FIELDS:
            failures.append("HISTORICAL_DELTA_METADATA_RECORD_FIELD_SET_MISMATCH")
            continue
        record_id = str(record.get("record_id", ""))
        if not record_id or record_id in seen_record_ids:
            failures.append(f"HISTORICAL_DELTA_METADATA_RECORD_ID_DUPLICATE:{record_id}")
        seen_record_ids.add(record_id)
        record_by_id[record_id] = record
        if record.get("schema_version") != METADATA_RECORD_SCHEMA_VERSION:
            failures.append(f"HISTORICAL_DELTA_METADATA_RECORD_SCHEMA_MISMATCH:{record_id}")
        if record.get("selector_policy") != EXACT_SELECTOR_POLICY:
            failures.append(f"HISTORICAL_DELTA_METADATA_SELECTOR_POLICY_MISMATCH:{record_id}")
        if record.get("registry_path") != REGISTRY_PATH:
            failures.append(f"HISTORICAL_DELTA_METADATA_REGISTRY_PATH_MISMATCH:{record_id}")
        if record.get("change_class") != "DOCS_ONLY":
            failures.append(f"HISTORICAL_DELTA_METADATA_CHANGE_CLASS_MISMATCH:{record_id}")
        if record.get("current_disposition") != "CORRECTED_HISTORICAL_METADATA_DEBT":
            failures.append(f"HISTORICAL_DELTA_METADATA_DISPOSITION_MISMATCH:{record_id}")
        if record.get("previous_record_payload_sha256") != previous_record_hash:
            failures.append(f"HISTORICAL_DELTA_METADATA_RECORD_CHAIN_MISMATCH:{record_id}")
        expected_payload = payload_sha256(record, "record_payload_sha256")
        if record.get("record_payload_sha256") != expected_payload:
            failures.append(f"HISTORICAL_DELTA_METADATA_RECORD_HASH_MISMATCH:{record_id}")
        previous_record_hash = str(record.get("record_payload_sha256", ""))
        source = str(record.get("source_commit", ""))
        parent = str(record.get("parent_commit", ""))
        try:
            if re.fullmatch(r"[0-9a-f]{40}", source) is None or re.fullmatch(
                r"[0-9a-f]{40}", parent
            ) is None:
                raise ValueError("SOURCE_OR_PARENT_NOT_EXACT_COMMIT")
            source = _resolve_commit(root, source)
            parent = _resolve_commit(root, parent)
            if source in seen_sources:
                failures.append(f"HISTORICAL_DELTA_METADATA_SOURCE_DUPLICATE:{source}")
            seen_sources.add(source)
            actual_parents = _git(root, "rev-list", "--parents", "-n", "1", source).split()[1:]
            if actual_parents != [parent]:
                failures.append(f"HISTORICAL_DELTA_METADATA_DIRECT_PARENT_MISMATCH:{record_id}")
            if record.get("commit_tree") != _git(root, "rev-parse", f"{source}^{{tree}}"):
                failures.append(f"HISTORICAL_DELTA_METADATA_SOURCE_TREE_MISMATCH:{record_id}")
            if record.get("parent_tree") != _git(root, "rev-parse", f"{parent}^{{tree}}"):
                failures.append(f"HISTORICAL_DELTA_METADATA_PARENT_TREE_MISMATCH:{record_id}")
            if not _is_ancestor(root, history_ancestry_anchor, source) or not _is_ancestor(root, source, raw_head):
                failures.append(f"HISTORICAL_DELTA_METADATA_SOURCE_ANCESTRY_MISMATCH:{record_id}")
            changed = _git_nul_paths(
                root,
                "diff-tree",
                "--no-commit-id",
                "--name-only",
                "--no-renames",
                "-r",
                "-z",
                source,
            )
            if changed != [REGISTRY_PATH]:
                failures.append(f"HISTORICAL_DELTA_METADATA_SOURCE_SCOPE_MISMATCH:{record_id}")
            source_registry = _git_bytes(root, source, REGISTRY_PATH)
            parent_registry = _git_bytes(root, parent, REGISTRY_PATH)
            if source_registry is None or parent_registry is None:
                raise ValueError("REGISTRY_BLOB_MISSING")
            if record.get("source_registry_sha256") != sha256_bytes(source_registry):
                failures.append(f"HISTORICAL_DELTA_METADATA_SOURCE_REGISTRY_HASH_MISMATCH:{record_id}")
            if record.get("parent_registry_sha256") != sha256_bytes(parent_registry):
                failures.append(f"HISTORICAL_DELTA_METADATA_PARENT_REGISTRY_HASH_MISMATCH:{record_id}")
            source_components = _component_rows(source_registry)
            parent_components = _component_rows(parent_registry)
            source_domains = _domain_rows(source_registry)
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            failures.append(f"HISTORICAL_DELTA_METADATA_SOURCE_INVALID:{record_id}:{exc}")
            source_components = {}
            parent_components = {}
            source_domains = {}
        bindings = record.get("failure_bindings")
        if not isinstance(bindings, list):
            bindings = []
            failures.append(f"HISTORICAL_DELTA_METADATA_BINDINGS_INVALID:{record_id}")
        if type(record.get("failure_count")) is not int or record.get("failure_count") != len(bindings):
            failures.append(f"HISTORICAL_DELTA_METADATA_FAILURE_COUNT_MISMATCH:{record_id}")
        local_fingerprints: list[str] = []
        local_reuse_components: set[str] = set()
        local_domains: set[str] = set()
        local_owners: set[str] = set()
        for binding in bindings:
            if not isinstance(binding, dict) or set(binding) != FAILURE_BINDING_FIELDS:
                failures.append(f"HISTORICAL_DELTA_METADATA_FAILURE_BINDING_FIELD_SET_MISMATCH:{record_id}")
                continue
            raw_failure = str(binding.get("raw_failure", ""))
            rule_id = str(binding.get("rule_id", ""))
            component_id = str(binding.get("component_id", ""))
            fingerprint = str(binding.get("failure_fingerprint", ""))
            if rule_id not in ALLOWED_RULE_IDS or not raw_failure.startswith(f"{rule_id}:"):
                failures.append(f"HISTORICAL_DELTA_METADATA_RULE_INVALID:{fingerprint}")
            if fingerprint != failure_fingerprint(raw_failure, rule_id):
                failures.append(f"HISTORICAL_DELTA_METADATA_FINGERPRINT_MISMATCH:{fingerprint}")
            if raw_failure not in raw_values:
                failures.append(f"HISTORICAL_DELTA_METADATA_RAW_FAILURE_MISSING:{fingerprint}")
            if fingerprint in seen_fingerprints:
                failures.append(f"HISTORICAL_DELTA_METADATA_FINGERPRINT_DUPLICATE:{fingerprint}")
            seen_fingerprints.add(fingerprint)
            local_fingerprints.append(fingerprint)
            binding_by_fingerprint[fingerprint] = binding
            transition_token = raw_failure.split(":", 2)[1] if ":" in raw_failure else ""
            expected_transition = f"{parent[:12]}->{source[:12]}" if parent and source else ""
            if transition_token != expected_transition or not raw_failure.endswith(f":{component_id}"):
                failures.append(f"HISTORICAL_DELTA_METADATA_RAW_IDENTITY_MISMATCH:{fingerprint}")
            source_row = source_components.get(component_id)
            current_row = current_components.get(component_id)
            if source_row is None or current_row is None or component_id in parent_components:
                failures.append(f"HISTORICAL_DELTA_METADATA_COMPONENT_LIFECYCLE_MISMATCH:{fingerprint}")
                continue
            activation_commit = activation_by_fingerprint.get(fingerprint)
            if activation_commit is None:
                failures.append(
                    f"HISTORICAL_DELTA_METADATA_ACTIVATION_COMMIT_MISSING:{fingerprint}"
                )
            else:
                try:
                    if activation_commit not in registry_changes_by_activation:
                        registry_changes_by_activation[activation_commit] = (
                            _registry_row_history_changes(
                                root,
                                activation_commit,
                                head,
                                registry_snapshot_cache,
                            )
                        )
                    (
                        changed_component_ids,
                        changed_domain_ids,
                        changed_reachability_ids,
                    ) = registry_changes_by_activation[activation_commit]
                    bound_domain_ids = {
                        str(source_row.get("domain_id", "")),
                        str(current_row.get("domain_id", "")),
                    }
                    bound_owner_ids = {
                        str(source_row.get("owner_component_id", "")),
                        str(current_row.get("owner_component_id", "")),
                    }
                    if component_id in changed_component_ids:
                        failures.append(
                            f"HISTORICAL_DELTA_METADATA_COMPONENT_ROW_TOUCHED:{fingerprint}"
                        )
                    if bound_domain_ids.intersection(changed_domain_ids):
                        failures.append(
                            f"HISTORICAL_DELTA_METADATA_DOMAIN_ROW_TOUCHED:{fingerprint}"
                        )
                    if bound_owner_ids.intersection(changed_component_ids):
                        failures.append(
                            f"HISTORICAL_DELTA_METADATA_OWNER_ROW_TOUCHED:{fingerprint}"
                        )
                    if component_id in changed_reachability_ids:
                        failures.append(
                            "HISTORICAL_DELTA_METADATA_PRODUCTION_REACHABILITY_TOUCHED:"
                            f"{fingerprint}"
                        )
                except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
                    failures.append(
                        f"HISTORICAL_DELTA_METADATA_REGISTRY_HISTORY_INVALID:{fingerprint}:{exc}"
                    )
            if binding.get("source_component_sha256") != _component_sha256(source_row):
                failures.append(f"HISTORICAL_DELTA_METADATA_SOURCE_COMPONENT_HASH_MISMATCH:{fingerprint}")
            if binding.get("current_component_sha256") != _component_sha256(current_row):
                failures.append(f"HISTORICAL_DELTA_METADATA_CURRENT_COMPONENT_HASH_MISMATCH:{fingerprint}")
            source_path = str(source_row.get("path", ""))
            current_path = str(current_row.get("path", ""))
            for field, expected in (
                ("source_component_path", source_path),
                ("current_component_path", current_path),
                ("source_domain_id", source_row.get("domain_id")),
                ("source_owner_component_id", source_row.get("owner_component_id")),
                ("source_production_reachability", source_row.get("production_reachable")),
            ):
                if binding.get(field) != expected:
                    failures.append(f"HISTORICAL_DELTA_METADATA_COMPONENT_FIELD_MISMATCH:{field}:{fingerprint}")
            source_path_bytes = _git_bytes(root, source, source_path) if source_path else None
            current_path_bytes = _git_bytes(root, head, current_path) if current_path else None
            if source_path_bytes is None or binding.get("source_path_blob_sha256") != sha256_bytes(source_path_bytes):
                failures.append(f"HISTORICAL_DELTA_METADATA_SOURCE_PATH_BLOB_MISMATCH:{fingerprint}")
            if current_path_bytes is None or binding.get("current_path_blob_sha256") != sha256_bytes(current_path_bytes):
                failures.append(f"HISTORICAL_DELTA_METADATA_CURRENT_PATH_BLOB_MISMATCH:{fingerprint}")
            if source_path in touched_paths or current_path in touched_paths:
                failures.append(f"HISTORICAL_DELTA_METADATA_COMPONENT_PATH_TOUCHED:{fingerprint}")
            source_domain = source_domains.get(str(source_row.get("domain_id", "")))
            current_domain = current_domains.get(str(current_row.get("domain_id", "")))
            if source_domain is None or current_domain is None:
                failures.append(f"HISTORICAL_DELTA_METADATA_DOMAIN_BINDING_MISSING:{fingerprint}")
            else:
                if binding.get("source_domain_sha256") != _component_sha256(source_domain):
                    failures.append(f"HISTORICAL_DELTA_METADATA_SOURCE_DOMAIN_HASH_MISMATCH:{fingerprint}")
                if binding.get("current_domain_sha256") != _component_sha256(current_domain):
                    failures.append(f"HISTORICAL_DELTA_METADATA_CURRENT_DOMAIN_HASH_MISMATCH:{fingerprint}")
            source_owner_id = str(source_row.get("owner_component_id", ""))
            current_owner_id = str(current_row.get("owner_component_id", ""))
            source_owner = source_components.get(source_owner_id)
            current_owner = current_components.get(current_owner_id)
            if binding.get("current_owner_component_id") != current_owner_id:
                failures.append(f"HISTORICAL_DELTA_METADATA_CURRENT_OWNER_ID_MISMATCH:{fingerprint}")
            if source_owner is None or current_owner is None:
                failures.append(f"HISTORICAL_DELTA_METADATA_OWNER_BINDING_MISSING:{fingerprint}")
            else:
                source_owner_path = str(source_owner.get("path", ""))
                current_owner_path = str(current_owner.get("path", ""))
                for field, expected in (
                    ("source_owner_component_sha256", _component_sha256(source_owner)),
                    ("current_owner_component_sha256", _component_sha256(current_owner)),
                    ("source_owner_path", source_owner_path),
                    ("current_owner_path", current_owner_path),
                ):
                    if binding.get(field) != expected:
                        failures.append(f"HISTORICAL_DELTA_METADATA_OWNER_FIELD_MISMATCH:{field}:{fingerprint}")
                source_owner_bytes = _git_bytes(root, source, source_owner_path) if source_owner_path else None
                current_owner_bytes = _git_bytes(root, head, current_owner_path) if current_owner_path else None
                if source_owner_bytes is None or binding.get("source_owner_path_blob_sha256") != sha256_bytes(source_owner_bytes):
                    failures.append(f"HISTORICAL_DELTA_METADATA_SOURCE_OWNER_BLOB_MISMATCH:{fingerprint}")
                if current_owner_bytes is None or binding.get("current_owner_path_blob_sha256") != sha256_bytes(current_owner_bytes):
                    failures.append(f"HISTORICAL_DELTA_METADATA_CURRENT_OWNER_BLOB_MISMATCH:{fingerprint}")
                if source_owner_path in touched_paths or current_owner_path in touched_paths:
                    failures.append(f"HISTORICAL_DELTA_METADATA_OWNER_PATH_TOUCHED:{fingerprint}")
            local_domains.add(str(source_row.get("domain_id", "")))
            local_owners.add(str(source_row.get("owner_component_id", "")))
            if rule_id == "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID":
                local_reuse_components.add(component_id)
                if not _valid_reuse_scan(current_row, current_reuse_entry_ids) or current_row.get("change_class") == "INHERITED":
                    failures.append(f"HISTORICAL_DELTA_METADATA_REUSE_SCAN_REPAIR_INVALID:{fingerprint}")
        if local_fingerprints != sorted(local_fingerprints):
            failures.append(f"HISTORICAL_DELTA_METADATA_FINGERPRINT_ORDER_INVALID:{record_id}")
        if record.get("failure_fingerprint_set_sha256") != line_set_sha(local_fingerprints):
            failures.append(f"HISTORICAL_DELTA_METADATA_FINGERPRINT_SET_HASH_MISMATCH:{record_id}")
        if record.get("reuse_scan_component_ids") != sorted(local_reuse_components):
            failures.append(f"HISTORICAL_DELTA_METADATA_REUSE_COMPONENT_SET_MISMATCH:{record_id}")
        if record.get("affected_domains") != sorted(local_domains):
            failures.append(f"HISTORICAL_DELTA_METADATA_AFFECTED_DOMAIN_SET_MISMATCH:{record_id}")
        if record.get("affected_owners") != sorted(local_owners):
            failures.append(f"HISTORICAL_DELTA_METADATA_AFFECTED_OWNER_SET_MISMATCH:{record_id}")
        if not _exact_sorted_strings(record.get("focused_tests")):
            failures.append(f"HISTORICAL_DELTA_METADATA_FOCUSED_TEST_SET_INVALID:{record_id}")
        if not isinstance(record.get("historical_context"), str) or not record["historical_context"].strip():
            failures.append(f"HISTORICAL_DELTA_METADATA_CONTEXT_INVALID:{record_id}")

    if type(ledger.get("failure_count")) is not int or ledger.get("failure_count") != len(seen_fingerprints):
        failures.append("HISTORICAL_DELTA_FAILURE_COUNT_MISMATCH")
    if ledger.get("failure_fingerprint_set_sha256") != line_set_sha(seen_fingerprints):
        failures.append("HISTORICAL_DELTA_FINGERPRINT_SET_HASH_MISMATCH")
    promoted_count = sum(
        1
        for binding in binding_by_fingerprint.values()
        if not str(binding.get("rule_id", "")).startswith("HISTORY_")
    )
    native_historical_count = sum(
        1 for raw in raw_values if raw.split(":", 1)[0].startswith("HISTORY_")
    )
    semantic_historical_count = native_historical_count + promoted_count
    true_current_count = len(raw_values) - semantic_historical_count
    for label, actual, expected in (
        ("LEDGER_FAILURE", len(seen_fingerprints), raw_authority.get("ledger_failure_count")),
        ("NATIVE_HISTORICAL", native_historical_count, raw_authority.get("native_historical_count")),
        ("LEDGER_PROMOTED", promoted_count, raw_authority.get("ledger_promoted_count")),
        ("SEMANTIC_HISTORICAL", semantic_historical_count, raw_authority.get("semantic_historical_count")),
        ("TRUE_CURRENT", true_current_count, raw_authority.get("true_current_count")),
    ):
        if actual != expected:
            failures.append(f"HISTORICAL_DELTA_RAW_{label}_COUNT_MISMATCH")

    correction_bindings = ledger.get("correction_record_bindings")
    if not isinstance(correction_bindings, list):
        correction_bindings = []
        failures.append("HISTORICAL_DELTA_CORRECTION_BINDING_LIST_INVALID")
    if type(ledger.get("correction_record_count")) is not int or ledger.get("correction_record_count") != len(correction_bindings):
        failures.append("HISTORICAL_DELTA_CORRECTION_RECORD_COUNT_MISMATCH")
    previous_correction_hash = "0" * 64
    corrected: set[str] = set()
    record_summaries: list[dict[str, Any]] = []
    correction_ids: set[str] = set()
    for binding in correction_bindings:
        if not isinstance(binding, dict) or set(binding) != CORRECTION_BINDING_FIELDS:
            failures.append("HISTORICAL_DELTA_CORRECTION_BINDING_FIELD_SET_MISMATCH")
            continue
        path_value = str(binding.get("path", ""))
        try:
            correction_path = _resolve_repo_path(
                root,
                path_value,
                required_prefix=CORRECTION_RECORD_ROOT,
            )
        except ValueError:
            correction_path = root / "__invalid_historical_delta_correction_path__"
        if (
            correction_path.name == "__invalid_historical_delta_correction_path__"
            or any(token in path_value for token in ("*", "?", "[", "]"))
            or not path_value.endswith(".json")
        ):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_PATH_INVALID:{path_value}")
            continue
        try:
            correction_bytes = _git_bytes(root, head, path_value)
            if correction_bytes is None or correction_bytes != correction_path.read_bytes():
                raise ValueError("CORRECTION_COMMITTED_BYTES_MISMATCH")
            correction = _load_json_bytes_strict(correction_bytes)
            file_sha = sha256_bytes(correction_bytes)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_RECORD_INVALID:{path_value}:{exc}")
            continue
        correction_id = str(binding.get("correction_id", ""))
        if correction_id in correction_ids:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_ID_DUPLICATE:{correction_id}")
        correction_ids.add(correction_id)
        if binding.get("file_sha256") != file_sha:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_FILE_HASH_MISMATCH:{correction_id}")
        if not isinstance(correction, dict) or set(correction) != CORRECTION_RECORD_FIELDS:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_FIELD_SET_MISMATCH:{correction_id}")
            continue
        for field, expected in (
            ("schema_version", CORRECTION_RECORD_SCHEMA_VERSION),
            ("record_kind", "HISTORICAL_DELTA_METADATA_EXACT_CORRECTION"),
            ("correction_id", correction_id),
            ("ledger_id", LEDGER_ID),
            ("authorization_id", AUTHORIZATION_ID),
            ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD_SHA),
            ("raw_report_sha256", raw_sha),
            ("raw_report_head_sha", raw_head),
            ("selector_policy", EXACT_SELECTOR_POLICY),
            ("from_state", "RAW_HISTORICAL_METADATA_FAILURE"),
            ("to_effective_disposition", "CORRECTED_HISTORICAL_METADATA_DEBT"),
            ("untouched_in_current_delta", True),
            ("touch_invalidation_policy", TOUCH_INVALIDATION_POLICY),
            ("future_failure_policy", FUTURE_FAILURE_POLICY),
        ):
            if correction.get(field) != expected:
                failures.append(f"HISTORICAL_DELTA_CORRECTION_{field.upper()}_MISMATCH:{correction_id}")
        if correction.get("previous_correction_payload_sha256") != previous_correction_hash:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_CHAIN_MISMATCH:{correction_id}")
        expected_payload = payload_sha256(correction, "record_payload_sha256")
        if correction.get("record_payload_sha256") != expected_payload:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_PAYLOAD_HASH_MISMATCH:{correction_id}")
        previous_correction_hash = str(correction.get("record_payload_sha256", ""))
        if binding.get("record_payload_sha256") != correction.get("record_payload_sha256"):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_BINDING_PAYLOAD_MISMATCH:{correction_id}")
        fingerprints = correction.get("failure_fingerprints")
        if not isinstance(fingerprints, list) or any(not isinstance(value, str) for value in fingerprints):
            fingerprints = []
            failures.append(f"HISTORICAL_DELTA_CORRECTION_FINGERPRINT_LIST_INVALID:{correction_id}")
        if not fingerprints or fingerprints != sorted(set(fingerprints)) or any(
            re.fullmatch(r"V2F-[0-9a-f]{64}", value) is None for value in fingerprints
        ):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_FINGERPRINT_SET_INVALID:{correction_id}")
        if binding.get("failure_fingerprints") != fingerprints:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_BINDING_FINGERPRINT_MISMATCH:{correction_id}")
        if type(correction.get("failure_count")) is not int or correction.get("failure_count") != len(fingerprints) or binding.get("failure_count") != len(fingerprints):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_FAILURE_COUNT_MISMATCH:{correction_id}")
        if correction.get("failure_fingerprint_set_sha256") != line_set_sha(fingerprints):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_FINGERPRINT_SET_HASH_MISMATCH:{correction_id}")
        if corrected.intersection(fingerprints):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_FINGERPRINT_DUPLICATE:{correction_id}")
        corrected.update(fingerprints)
        rule_id = str(correction.get("rule_id", ""))
        if rule_id not in ALLOWED_RULE_IDS or correction.get("transition_class_id") != TRANSITION_CLASS_BY_RULE.get(rule_id):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_RULE_CLASS_MISMATCH:{correction_id}")
        if any(binding_by_fingerprint.get(fp, {}).get("rule_id") != rule_id for fp in fingerprints):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_RULE_GROUP_MISMATCH:{correction_id}")
        metadata_ids = correction.get("metadata_record_ids")
        if not _exact_sorted_strings(metadata_ids) or any(value not in record_by_id for value in metadata_ids):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_METADATA_RECORD_BINDING_INVALID:{correction_id}")
        matching_ids = sorted({
            record_id
            for record_id, record in record_by_id.items()
            if any(
                isinstance(item, dict) and item.get("failure_fingerprint") in set(fingerprints)
                for item in (
                    record.get("failure_bindings")
                    if isinstance(record.get("failure_bindings"), list)
                    else []
                )
            )
        })
        if metadata_ids != matching_ids:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_METADATA_RECORD_SET_MISMATCH:{correction_id}")
        component_ids = sorted({str(binding_by_fingerprint.get(fp, {}).get("component_id", "")) for fp in fingerprints})
        if correction.get("component_ids") != component_ids or correction.get("component_set_sha256") != line_set_sha(component_ids):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_COMPONENT_SET_MISMATCH:{correction_id}")
        source_records = [record_by_id[value] for value in matching_ids if value in record_by_id]
        source_commits = {str(record.get("source_commit", "")) for record in source_records}
        parent_commits = {str(record.get("parent_commit", "")) for record in source_records}
        if re.fullmatch(r"[0-9a-f]{40}", str(correction.get("source_commit", ""))) is None:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_SOURCE_COMMIT_NOT_EXACT:{correction_id}")
        if re.fullmatch(r"[0-9a-f]{40}", str(correction.get("parent_commit", ""))) is None:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_PARENT_COMMIT_NOT_EXACT:{correction_id}")
        if len(source_commits) != 1 or correction.get("source_commit") not in source_commits:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_SOURCE_COMMIT_MISMATCH:{correction_id}")
        if len(parent_commits) != 1 or correction.get("parent_commit") not in parent_commits:
            failures.append(f"HISTORICAL_DELTA_CORRECTION_PARENT_COMMIT_MISMATCH:{correction_id}")
        if not _exact_sorted_strings(correction.get("backlog_item_ids")):
            failures.append(f"HISTORICAL_DELTA_CORRECTION_BACKLOG_MISSING:{correction_id}")
        record_summaries.append({
            "correction_id": correction_id,
            "path": path_value,
            "record_sha256": file_sha,
            "record_payload_sha256": correction.get("record_payload_sha256", ""),
            "failure_fingerprints": fingerprints,
        })
    if corrected != seen_fingerprints:
        failures.append(
            "HISTORICAL_DELTA_CORRECTION_COVERAGE_MISMATCH:"
            f"missing={len(seen_fingerprints - corrected)}:extra={len(corrected - seen_fingerprints)}"
        )
    if type(ledger.get("corrected_failure_count")) is not int or ledger.get("corrected_failure_count") != len(corrected):
        failures.append("HISTORICAL_DELTA_CORRECTED_FAILURE_COUNT_MISMATCH")
    identities = {
        fingerprint: {
            "failure_fingerprint": fingerprint,
            "raw_failure": str(binding.get("raw_failure", "")),
            "rule_id": str(binding.get("rule_id", "")),
            "source_commit": next(
                (
                    str(record.get("source_commit", ""))
                    for record in records
                    if isinstance(record, dict)
                    and any(
                        isinstance(item, dict) and item.get("failure_fingerprint") == fingerprint
                        for item in (
                            record.get("failure_bindings")
                            if isinstance(record.get("failure_bindings"), list)
                            else []
                        )
                    )
                ),
                "",
            ),
            "component_id": str(binding.get("component_id", "")),
            "path": str(binding.get("source_component_path", "")),
            "target": "historical",
            "authority_origin": "HISTORICAL_DELTA_METADATA_LEDGER",
        }
        for fingerprint, binding in binding_by_fingerprint.items()
    }
    try:
        if _grafts_file_nonempty(root):
            failures.append("HISTORICAL_DELTA_GIT_GRAFTS_FORBIDDEN")
    except ValueError as exc:
        failures.append(f"HISTORICAL_DELTA_GIT_GRAFTS_INVALID:{exc}")
    valid = not failures
    return {
        "status": "PASS" if valid else "FAIL",
        "failures": sorted(set(failures)),
        "ledger_path": relative_ledger,
        "ledger_sha256": sha256_bytes(committed_ledger_bytes),
        "raw_report_sha256": raw_sha,
        "raw_report_head_sha": raw_head,
        "raw_failure_count": len(raw_values),
        "preledger_native_historical_bucket_count": native_historical_count,
        "ledger_exact_promoted_count": promoted_count,
        "semantic_historical_failure_count": semantic_historical_count,
        "true_current_failure_count": true_current_count,
        "metadata_record_count": len(records),
        "correction_record_count": len(correction_bindings),
        "authorized_historical_fingerprints": sorted(seen_fingerprints) if valid else [],
        "authorized_identity_by_fingerprint": {
            key: identities[key] for key in sorted(identities)
        } if valid else {},
        "verified_historical_fingerprints": sorted(corrected) if valid else [],
        "record_summaries": record_summaries if valid else [],
        "wildcard_count": 0,
        "future_failure_auto_match_count": 0,
        "raw_failure_detection_suppressed_count": 0,
    }


__all__ = [
    "ALLOWED_RULE_IDS",
    "AUTHORIZATION_BASE_HEAD_SHA",
    "AUTHORIZATION_ID",
    "AUTHORIZED_LEDGER_FAILURE_COUNT",
    "AUTHORIZED_RAW_FAILURE_COUNT",
    "AUTHORIZED_RAW_LEDGER_PROMOTED_COUNT",
    "AUTHORIZED_RAW_NATIVE_HISTORICAL_COUNT",
    "AUTHORIZED_RAW_REPORT_HEAD_SHA",
    "AUTHORIZED_RAW_REPORT_SHA256",
    "AUTHORIZED_RAW_REPORT_TREE_SHA",
    "AUTHORIZED_RAW_SEMANTIC_HISTORICAL_COUNT",
    "AUTHORIZED_RAW_TRUE_CURRENT_COUNT",
    "CORRECTION_RECORD_SCHEMA_VERSION",
    "EXACT_SELECTOR_POLICY",
    "FAILURE_BINDING_FIELDS",
    "FUTURE_FAILURE_POLICY",
    "LEDGER_FIELDS",
    "LEDGER_ID",
    "LEDGER_PATH",
    "LEDGER_SCHEMA_VERSION",
    "METADATA_RECORD_FIELDS",
    "METADATA_RECORD_SCHEMA_VERSION",
    "REGISTRY_PATH",
    "RAW_REPORT_ROOT",
    "CORRECTION_RECORD_ROOT",
    "SCHEMA_DOCUMENT_VERSION",
    "SCHEMA_PATH",
    "TOUCH_INVALIDATION_POLICY",
    "TRANSITION_CLASS_BY_RULE",
    "canonical_bytes",
    "failure_fingerprint",
    "line_set_sha",
    "load_json_strict",
    "payload_sha256",
    "sha256_bytes",
    "sha256_file",
    "validate_ledger",
]
