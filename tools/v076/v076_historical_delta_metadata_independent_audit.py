#!/usr/bin/env python3
"""Independent read-only audit for V076 Historical Delta Metadata.

This module intentionally does not import the primary ledger validator or the
V2 resolver.  It re-derives the exact hashes, Git identities, append-only
prefix, component/owner/domain bindings, and epoch cardinalities.  Its output
is an audit receipt only; it never returns a classification authority map.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any, Iterable, Mapping


AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
AUTHORIZATION_BASE_HEAD_SHA = "d701a81dce693b584d52fbfca3e0e78b521ad775"
LEDGER_PATH = "docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json"
SCHEMA_PATH = "docs/architecture/V076_HISTORICAL_DELTA_METADATA_SCHEMA.json"
REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
SCANNER_PATH = "tools/v076/v076_reuse_point_inertia_gate.py"
RAW_ROOT = "reports/reuse/"
CORRECTION_ROOT = "docs/architecture/reuse_corrections/v2/records/"

LEDGER_SCHEMA_VERSION = "space_syndicate.v076.historical_delta_metadata_ledger.v1"
METADATA_SCHEMA_VERSION = "space_syndicate.v076.historical_delta_metadata_record.v1"
CORRECTION_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "historical_delta_metadata_record.v1"
)
SCHEMA_DOCUMENT_VERSION = "space_syndicate.v076.historical_delta_metadata_schema.v1"
LEDGER_ID = "V076_HISTORICAL_DELTA_METADATA_LEDGER"

ALLOWED_RULES = {
    "NEW_COMPONENT_CANNOT_CLAIM_INHERITED",
    "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID",
}
TRANSITION_BY_RULE = {
    "NEW_COMPONENT_CANNOT_CLAIM_INHERITED": "HISTORICAL_COMPONENT_IDENTITY_METADATA_BACKFILL",
    "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID": "HISTORICAL_AUTHORITY_REUSE_SCAN_METADATA_BACKFILL",
}
SELECTOR_POLICY = {
    "match_mode": "EXACT_FAILURE_FINGERPRINTS_ONLY",
    "wildcard_allowed": False,
    "regex_allowed": False,
    "path_prefix_allowed": False,
    "branch_selector_allowed": False,
    "date_selector_allowed": False,
    "future_failure_auto_match": False,
}
TOUCH_POLICY = {
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
FUTURE_POLICY = {"automatic_match": False, "new_failure_requires_new_record": True}

DEFAULT_EXPECTATIONS: dict[str, int | str] = {
    "raw_sha256": "28c3bb657b20f4d2e7f2eee14f1677d5bf5feb678883fe2f400ca54b89c629b0",
    "raw_head_sha": "7b2bd08a9916a3a517f2d418765c544cce0261cc",
    "raw_tree_sha": "990b070c3f7cfefa3bf6853ff22f9023049ede29",
    "scanner_sha256": "09bc04b52058cdafb7e966ca36230dc153dd637b829b766677ac542be02a9885",
    "raw_failure_count": 590,
    "native_historical_count": 505,
    "ledger_promoted_count": 82,
    "semantic_historical_count": 587,
    "true_current_count": 3,
    "authorized_failure_count": 86,
    "authorized_raw_set_sha256": "fc2c8d9d8ac8cee1db457eb583b568c537d8feebf63ce6a77b6b1c4f40e45c00",
    "authorized_fingerprint_set_sha256": "91373b8883708f835052cbebe1da8b53e33f4ef608d97b17f5ab45161cd0a8d9",
    "component_count": 82,
    "component_set_sha256": "f05bac67fea5ae37e96fd75a0907eb0daa7a67352cdb5a5b06f90fe22bcd1a17",
}

SELFTEST_FIXTURE_CONFIG_KEY = "v076.historicalDeltaMetadataFixture"

LEDGER_FIELDS = {
    "schema_version", "ledger_id", "authorization_id", "authorization_base_head_sha",
    "schema_path", "schema_sha256", "raw_report_path", "raw_report_sha256",
    "raw_report_head_sha", "raw_report_tree_sha", "scanner_path", "scanner_sha256",
    "registry_path", "selector_policy", "record_count", "records", "failure_count",
    "failure_fingerprint_set_sha256", "correction_record_count",
    "correction_record_bindings", "corrected_failure_count", "previous_ledger_path",
    "previous_ledger_sha256", "append_only", "ledger_payload_sha256",
}
METADATA_FIELDS = {
    "schema_version", "record_id", "source_commit", "parent_commit", "commit_tree",
    "parent_tree", "registry_path", "source_registry_sha256", "parent_registry_sha256",
    "change_class", "affected_domains", "affected_owners", "focused_tests",
    "historical_context", "current_disposition", "selector_policy",
    "reuse_scan_component_ids", "failure_count", "failure_fingerprint_set_sha256",
    "failure_bindings", "previous_record_payload_sha256", "record_payload_sha256",
}
FAILURE_BINDING_FIELDS = {
    "failure_fingerprint", "raw_failure", "rule_id", "component_id",
    "source_component_sha256", "current_component_sha256", "source_component_path",
    "current_component_path", "source_path_blob_sha256", "current_path_blob_sha256",
    "source_domain_id", "source_domain_sha256", "current_domain_sha256",
    "source_owner_component_id", "current_owner_component_id",
    "source_owner_component_sha256", "current_owner_component_sha256",
    "source_owner_path", "current_owner_path", "source_owner_path_blob_sha256",
    "current_owner_path_blob_sha256", "source_production_reachability",
}
CORRECTION_BINDING_FIELDS = {
    "correction_id", "path", "file_sha256", "record_payload_sha256",
    "failure_count", "failure_fingerprints",
}
CORRECTION_FIELDS = {
    "schema_version", "record_kind", "correction_id", "ledger_id",
    "metadata_record_ids", "authorization_id", "authorization_base_head_sha",
    "raw_report_sha256", "raw_report_head_sha", "rule_id", "transition_class_id",
    "source_commit", "parent_commit", "component_ids", "component_set_sha256",
    "failure_count", "failure_fingerprints", "failure_fingerprint_set_sha256",
    "selector_policy", "from_state", "to_effective_disposition",
    "untouched_in_current_delta", "touch_invalidation_policy", "future_failure_policy",
    "backlog_item_ids", "previous_correction_payload_sha256", "record_payload_sha256",
}
REUSE_SCAN_FIELDS = {
    "reuse_registry_search", "class_name_search", "semantic_signature_search",
    "owner_map_search", "state_write_surface_search", "rng_owner_search",
    "save_owner_search", "replay_owner_search", "signal_and_receipt_search",
    "reuse_candidate_count", "reuse_candidate_ids", "selected_reuse_disposition",
    "why_existing_owner_cannot_be_extended", "why_adapter_is_insufficient",
    "why_new_owner_is_required",
}


class DuplicateKey(ValueError):
    pass


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKey(key)
        result[key] = value
    return result


def _reject_non_finite_json_number(value: str) -> Any:
    raise ValueError(f"NON_FINITE_JSON_NUMBER:{value}")


def _json_bytes(payload: bytes) -> Any:
    return json.loads(
        payload.decode("utf-8-sig"),
        object_pairs_hook=_strict_object,
        parse_constant=_reject_non_finite_json_number,
    )


def _canonical(value: Any) -> bytes:
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


def _git_environment() -> dict[str, str]:
    environment = dict(os.environ)
    environment["GIT_NO_REPLACE_OBJECTS"] = "1"
    return environment


def _sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _line_set_sha(values: Iterable[str]) -> str:
    rendered = sorted(set(str(value) for value in values))
    return _sha((("\n".join(rendered) + "\n") if rendered else "").encode("utf-8"))


def _payload_sha(document: dict[str, Any], field: str) -> str:
    payload = dict(document)
    payload.pop(field, None)
    return _sha(_canonical(payload))


def _fingerprint(raw: str, rule_id: str) -> str:
    return "V2F-" + _sha(f"V076_RAW_FAILURE_V2\nHISTORICAL\n{rule_id}\n{raw}\n".encode("utf-8"))


def _git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=root, check=False, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace",
        env=_git_environment(),
    )
    if result.returncode != 0:
        raise ValueError(result.stderr.strip() or "GIT_COMMAND_FAILED")
    return result.stdout.strip()


def _grafts_file_nonempty(root: Path) -> bool:
    grafts_value = _git(root, "rev-parse", "--git-path", "info/grafts")
    grafts_path = Path(grafts_value)
    if not grafts_path.is_absolute():
        grafts_path = root / grafts_path
    try:
        return grafts_path.is_file() and bool(grafts_path.read_bytes().strip())
    except OSError as exc:
        raise ValueError("GIT_GRAFTS_STATE_UNREADABLE") from exc


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


def _git_bytes(root: Path, commit: str, relative: str) -> bytes | None:
    tree_result = subprocess.run(
        ["git", "ls-tree", "-z", commit, "--", f":(literal){relative}"],
        cwd=root,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=_git_environment(),
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
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=_git_environment(),
    )
    return bytes(blob_result.stdout) if blob_result.returncode == 0 else None


def _exact_commit(root: Path, value: Any) -> str:
    if not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{40}", value) is None:
        raise ValueError("COMMIT_NOT_EXACT_40HEX")
    resolved = _git(root, "rev-parse", f"{value}^{{commit}}")
    if resolved != value:
        raise ValueError("COMMIT_RESOLUTION_MISMATCH")
    return resolved


def _is_ancestor(root: Path, older: str, newer: str) -> bool:
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", older, newer], cwd=root,
        check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        env=_git_environment(),
    )
    return result.returncode == 0


def _repo_path(root: Path, value: Any, *, prefix: str | None = None) -> tuple[Path, str]:
    if not isinstance(value, str) or not value or "\\" in value:
        raise ValueError("PATH_NOT_CANONICAL")
    relative = Path(value)
    if relative.is_absolute() or relative.as_posix() != value:
        raise ValueError("PATH_NOT_REPOSITORY_RELATIVE")
    if any(part in {"", ".", ".."} for part in relative.parts):
        raise ValueError("PATH_TRAVERSAL")
    if prefix is not None and not value.startswith(prefix):
        raise ValueError("PATH_PREFIX_MISMATCH")
    canonical_root = root.resolve()
    expected = canonical_root / relative
    cursor = canonical_root
    for part in relative.parts:
        cursor = cursor / part
        try:
            stat_result = cursor.lstat()
        except FileNotFoundError:
            continue
        except OSError as exc:
            raise ValueError("PATH_STAT_FAILED") from exc
        if cursor.is_symlink() or bool(
            getattr(stat_result, "st_file_attributes", 0) & 0x400
        ):
            raise ValueError("PATH_LINK_OR_REPARSE_POINT")
    try:
        resolved = expected.resolve()
    except (OSError, RuntimeError) as exc:
        raise ValueError("PATH_RESOLUTION_FAILED") from exc
    if resolved != expected or not resolved.is_relative_to(root.resolve()):
        raise ValueError("PATH_LINK_OR_ESCAPE")
    return resolved, value


def _uses_link_or_reparse(path: Path) -> bool:
    candidates = [*reversed(path.absolute().parents), path.absolute()]
    for candidate in candidates:
        try:
            stat_result = candidate.lstat()
        except FileNotFoundError:
            continue
        except OSError:
            return True
        if candidate.is_symlink() or bool(
            getattr(stat_result, "st_file_attributes", 0) & 0x400
        ):
            return True
    return False


def _committed_document(root: Path, head: str, relative: str) -> tuple[dict[str, Any], bytes]:
    path, _ = _repo_path(root, relative)
    committed = _git_bytes(root, head, relative)
    if committed is None or not path.is_file() or path.read_bytes() != committed:
        raise ValueError(f"COMMITTED_BYTES_MISMATCH:{relative}")
    document = _json_bytes(committed)
    if not isinstance(document, dict):
        raise ValueError(f"DOCUMENT_NOT_OBJECT:{relative}")
    return document, committed


def _rows(document: dict[str, Any], key: str, identity: str) -> dict[str, dict[str, Any]]:
    values = document.get(key)
    if not isinstance(values, list):
        raise ValueError(f"ROW_LIST_INVALID:{key}")
    result: dict[str, dict[str, Any]] = {}
    for row in values:
        value = row.get(identity) if isinstance(row, dict) else None
        if not isinstance(value, str) or not value or value in result:
            raise ValueError(f"ROW_ID_INVALID:{key}:{value}")
        result[value] = row
    return result


def _row_sha(row: dict[str, Any]) -> str:
    return _sha(_canonical(row))


def _exact_strings(value: Any, *, allow_empty: bool = False) -> bool:
    return bool(
        isinstance(value, list) and (allow_empty or value)
        and all(isinstance(item, str) and item.strip() for item in value)
        and value == sorted(set(value))
    )


def _touched_paths(root: Path, older: str, newer: str) -> set[str]:
    if older == newer:
        return set()
    if not _is_ancestor(root, older, newer):
        raise ValueError("TOUCH_RANGE_NOT_ANCESTRAL")
    touched: set[str] = set()
    for commit in _git(root, "rev-list", f"{older}..{newer}").splitlines():
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


def _schema_findings(schema: dict[str, Any]) -> list[str]:
    expected = {
        "schema_version": SCHEMA_DOCUMENT_VERSION,
        "ledger_schema_version": LEDGER_SCHEMA_VERSION,
        "historical_record_schema_version": METADATA_SCHEMA_VERSION,
        "metadata_record_schema_version": METADATA_SCHEMA_VERSION,
        "correction_record_schema_version": CORRECTION_SCHEMA_VERSION,
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD_SHA,
        "authorized_raw_report_sha256": DEFAULT_EXPECTATIONS["raw_sha256"],
        "authorized_raw_report_head_sha": DEFAULT_EXPECTATIONS["raw_head_sha"],
        "authorized_raw_report_tree_sha": DEFAULT_EXPECTATIONS["raw_tree_sha"],
        "authorized_raw_failure_count": DEFAULT_EXPECTATIONS["raw_failure_count"],
        "authorized_raw_native_historical_count": DEFAULT_EXPECTATIONS[
            "native_historical_count"
        ],
        "authorized_raw_ledger_promoted_count": DEFAULT_EXPECTATIONS[
            "ledger_promoted_count"
        ],
        "authorized_raw_semantic_historical_count": DEFAULT_EXPECTATIONS[
            "semantic_historical_count"
        ],
        "authorized_raw_true_current_count": DEFAULT_EXPECTATIONS["true_current_count"],
        "authorized_ledger_failure_count": DEFAULT_EXPECTATIONS[
            "authorized_failure_count"
        ],
        "canonical_ledger_path": LEDGER_PATH,
        "raw_report_root": RAW_ROOT,
        "correction_record_root": CORRECTION_ROOT,
        "allowed_rule_ids": sorted(ALLOWED_RULES),
        "exact_selector_policy": SELECTOR_POLICY,
        "field_sets": {
            "ledger": sorted(LEDGER_FIELDS),
            "metadata_record": sorted(METADATA_FIELDS),
            "failure_binding": sorted(FAILURE_BINDING_FIELDS),
            "correction_binding": sorted(CORRECTION_BINDING_FIELDS),
            "correction_record": sorted(CORRECTION_FIELDS),
        },
        "raw_scanner_reads_ledger": False,
        "active_resolver_count": 1,
        "wildcard_allowed": False,
        "future_failure_auto_match_allowed": False,
        "history_rewrite_allowed": False,
        "component_path_blob_binding_required": True,
        "path_touch_history_invalidation_required": True,
    }
    return [] if schema == expected else ["SCHEMA_EXACT_DOCUMENT_MISMATCH"]


def _fingerprint_activation_commits(
    root: Path, evaluated_head: str
) -> dict[str, str]:
    activation_by_fingerprint: dict[str, str] = {}
    path_history_commits = set(
        _git(
            root,
            "rev-list",
            "--full-history",
            "--topo-order",
            evaluated_head,
            "--",
            LEDGER_PATH,
        ).splitlines()
    )
    for commit in _git(
        root, "rev-list", "--first-parent", "--reverse", evaluated_head
    ).splitlines():
        if commit not in path_history_commits:
            continue
        version_bytes = _git_bytes(root, commit, LEDGER_PATH)
        if version_bytes is None:
            continue
        version = _json_bytes(version_bytes)
        if not isinstance(version, dict):
            raise ValueError("LEDGER_HISTORY_VERSION_NOT_OBJECT")
        records = version.get("records")
        if not isinstance(records, list):
            continue
        for record in records:
            bindings = record.get("failure_bindings") if isinstance(record, dict) else None
            if not isinstance(bindings, list):
                continue
            for binding in bindings:
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
    return activation_by_fingerprint


def _append_only_findings(
    root: Path,
    evaluated_head: str,
    ledger: dict[str, Any],
    ledger_bytes: bytes,
) -> tuple[list[str], str]:
    findings: list[str] = []
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
            LEDGER_PATH,
        ).splitlines()
    )
    transition_commits = path_history_commits | {
        identity[0] for identity in graph if len(identity) > 2
    }
    transition_commits.add(evaluated_head)
    version_bytes_by_commit: dict[str, bytes | None] = {}

    def version_bytes(commit: str) -> bytes | None:
        if commit not in version_bytes_by_commit:
            version_bytes_by_commit[commit] = _git_bytes(
                root,
                commit,
                LEDGER_PATH,
            )
        return version_bytes_by_commit[commit]

    version_by_sha: dict[str, dict[str, Any] | None] = {}

    def version_document(payload: bytes) -> dict[str, Any] | None:
        payload_sha = _sha(payload)
        if payload_sha in version_by_sha:
            return version_by_sha[payload_sha]
        try:
            document = _json_bytes(payload)
        except (UnicodeDecodeError, json.JSONDecodeError, DuplicateKey, ValueError):
            findings.append("PREVIOUS_LEDGER_JSON_INVALID")
            version_by_sha[payload_sha] = None
            return None
        if not isinstance(document, dict):
            findings.append("PREVIOUS_LEDGER_NOT_OBJECT")
            version_by_sha[payload_sha] = None
            return None
        if set(document) != LEDGER_FIELDS or document.get(
            "ledger_payload_sha256"
        ) != _payload_sha(document, "ledger_payload_sha256"):
            findings.append("PREVIOUS_LEDGER_SEAL_INVALID")
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
                findings.append(f"APPEND_ONLY_{field.upper()}_MUTATION")

    introduction_commits: set[str] = set()
    for identity in graph:
        commit, *parents = identity
        if commit not in transition_commits:
            continue
        current_bytes = version_bytes(commit)
        present_parents = [
            (parent, version_bytes(parent))
            for parent in parents
            if version_bytes(parent) is not None
        ]
        if current_bytes is None:
            if present_parents:
                findings.append("LEDGER_HISTORY_DELETION")
            continue

        current_document = version_document(current_bytes)
        if not present_parents:
            introduction_commits.add(commit)
            if isinstance(current_document, dict) and (
                current_document.get("previous_ledger_path")
                or current_document.get("previous_ledger_sha256")
            ):
                findings.append("UNEXPECTED_PREVIOUS_LEDGER_BINDING")
            continue

        matching_parent_exists = any(
            payload == current_bytes for _, payload in present_parents
        )
        if not matching_parent_exists:
            expected_hashes = {
                _sha(payload)
                for _, payload in present_parents
                if payload is not None
            }
            if (
                not isinstance(current_document, dict)
                or current_document.get("previous_ledger_path") != LEDGER_PATH
                or current_document.get("previous_ledger_sha256")
                not in expected_hashes
            ):
                findings.append("PREVIOUS_LEDGER_BINDING_MISMATCH")

        distinct_parent_payloads: dict[str, bytes] = {}
        for _, payload in present_parents:
            if payload is None or payload == current_bytes:
                continue
            distinct_parent_payloads.setdefault(_sha(payload), payload)
        for parent_payload in distinct_parent_payloads.values():
            require_literal_prefix(
                version_document(parent_payload),
                current_document,
            )

    if len(introduction_commits) > 1:
        findings.append("LEDGER_HISTORY_REINTRODUCTION")

    head_bytes = version_bytes(evaluated_head)
    current_version = version_document(head_bytes) if head_bytes is not None else None
    if current_version != ledger or head_bytes != ledger_bytes:
        findings.append("CURRENT_LEDGER_HISTORY_MISMATCH")
    return findings, str(ledger.get("previous_ledger_sha256", ""))


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
    registry = _json_bytes(registry_bytes)
    if not isinstance(registry, dict):
        raise ValueError(f"REGISTRY_HISTORY_NOT_OBJECT:{commit}")
    snapshot = (
        _rows(registry, "component_inventory", "component_id"),
        _rows(registry, "domain_inventory", "domain_id"),
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
                    or _row_sha(before) != _row_sha(after)
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
                if before is None or after is None or _row_sha(before) != _row_sha(after):
                    changed_domains.add(domain_id)
    return changed_components, changed_domains, changed_reachability


def _audit_ledger_impl(
    root: Path,
    ledger_path: Path,
    *,
    evaluated_head: str,
    expectations: Mapping[str, int | str],
    history_ancestry_anchor: str,
    primary_projection: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Return an independent receipt; never return a resolver authority map."""
    root = root.resolve()
    failures: list[str] = []
    expectations = dict(expectations)
    try:
        if _grafts_file_nonempty(root):
            return {
                "status": "NO_GO",
                "failures": ["GIT_GRAFTS_FORBIDDEN"],
                "evaluated_head_sha": str(evaluated_head),
                "authorized_failure_count": 0,
                "verified_failure_count": 0,
                "primary_projection_digest_match": False,
            }
    except ValueError as exc:
        return {
            "status": "NO_GO",
            "failures": [f"GIT_GRAFTS_INVALID:{exc}"],
            "evaluated_head_sha": str(evaluated_head),
            "authorized_failure_count": 0,
            "verified_failure_count": 0,
            "primary_projection_digest_match": False,
        }
    try:
        head = _exact_commit(root, evaluated_head)
        canonical_ledger, relative_ledger = _repo_path(root, LEDGER_PATH)
        if (
            ledger_path.resolve() != canonical_ledger
            or _uses_link_or_reparse(ledger_path)
            or relative_ledger != LEDGER_PATH
        ):
            raise ValueError("LEDGER_PATH_MISMATCH")
        ledger, ledger_bytes = _committed_document(root, head, relative_ledger)
    except (OSError, ValueError, UnicodeDecodeError, json.JSONDecodeError, DuplicateKey) as exc:
        return {
            "status": "NO_GO",
            "failures": [f"LEDGER_INPUT_INVALID:{exc}"],
            "evaluated_head_sha": str(evaluated_head),
            "authorized_failure_count": 0,
            "verified_failure_count": 0,
            "primary_projection_digest_match": False,
        }
    if set(ledger) != LEDGER_FIELDS:
        failures.append("LEDGER_FIELD_SET_MISMATCH")
    for field, expected in (
        ("schema_version", LEDGER_SCHEMA_VERSION), ("ledger_id", LEDGER_ID),
        ("authorization_id", AUTHORIZATION_ID),
        ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD_SHA),
        ("schema_path", SCHEMA_PATH), ("registry_path", REGISTRY_PATH),
        ("scanner_path", SCANNER_PATH), ("selector_policy", SELECTOR_POLICY),
        ("append_only", True),
    ):
        if ledger.get(field) != expected:
            failures.append(f"LEDGER_{field.upper()}_MISMATCH")
    if ledger.get("ledger_payload_sha256") != _payload_sha(ledger, "ledger_payload_sha256"):
        failures.append("LEDGER_PAYLOAD_HASH_MISMATCH")

    try:
        schema, schema_bytes = _committed_document(root, head, SCHEMA_PATH)
        failures.extend(_schema_findings(schema))
        if ledger.get("schema_sha256") != _sha(schema_bytes):
            failures.append("SCHEMA_BINDING_HASH_MISMATCH")
    except (OSError, ValueError, UnicodeDecodeError, json.JSONDecodeError, DuplicateKey) as exc:
        schema_bytes = b""
        failures.append(f"SCHEMA_INVALID:{exc}")

    raw_path_value = str(ledger.get("raw_report_path", ""))
    try:
        _, raw_relative = _repo_path(root, raw_path_value, prefix=RAW_ROOT)
        raw, raw_bytes = _committed_document(root, head, raw_relative)
    except (OSError, ValueError, UnicodeDecodeError, json.JSONDecodeError, DuplicateKey) as exc:
        raw = {}
        raw_bytes = b""
        failures.append(f"RAW_INVALID:{exc}")
    raw_sha = _sha(raw_bytes)
    if raw_sha != ledger.get("raw_report_sha256") or raw_sha != expectations.get("raw_sha256"):
        failures.append("RAW_SHA256_MISMATCH")
    try:
        raw_head = _exact_commit(root, ledger.get("raw_report_head_sha"))
        raw_tree = _git(root, "rev-parse", f"{raw_head}^{{tree}}")
        if raw_head != expectations.get("raw_head_sha"):
            failures.append("RAW_HEAD_NOT_AUTHORIZED")
        if raw_tree != ledger.get("raw_report_tree_sha") or raw_tree != expectations.get("raw_tree_sha"):
            failures.append("RAW_TREE_MISMATCH")
        if not _is_ancestor(root, raw_head, head):
            failures.append("RAW_HEAD_NOT_EVALUATED_ANCESTOR")
        touched = _touched_paths(root, raw_head, head)
    except ValueError as exc:
        raw_head = ""
        raw_tree = ""
        touched = set()
        failures.append(f"RAW_IDENTITY_INVALID:{exc}")
    raw_values = raw.get("failures") if isinstance(raw, dict) else None
    if not isinstance(raw_values, list) or any(not isinstance(value, str) for value in raw_values):
        raw_values = []
        failures.append("RAW_FAILURE_LIST_INVALID")
    if len(raw_values) != len(set(raw_values)):
        failures.append("RAW_FAILURE_DUPLICATE")
    if raw.get("status") != ("PASS" if not raw_values else "FAIL"):
        failures.append("RAW_STATUS_MISMATCH")
    if raw.get("head_sha") != raw_head or raw.get("include_worktree") is not False or raw.get("evaluated_source") != "COMMITTED_HEAD":
        failures.append("RAW_COMMITTED_SUBJECT_MISMATCH")
    if len(raw_values) != expectations.get("raw_failure_count"):
        failures.append("RAW_FAILURE_COUNT_MISMATCH")
    scanner_bytes = _git_bytes(root, raw_head, SCANNER_PATH) if raw_head else None
    scanner_sha = _sha(scanner_bytes or b"")
    if scanner_bytes is None or scanner_sha != ledger.get("scanner_sha256") or scanner_sha != expectations.get("scanner_sha256"):
        failures.append("SCANNER_BINDING_MISMATCH")

    try:
        current_registry, current_registry_bytes = _committed_document(root, head, REGISTRY_PATH)
        current_components = _rows(current_registry, "component_inventory", "component_id")
        current_domains = _rows(current_registry, "domain_inventory", "domain_id")
        current_reuse = _rows(current_registry, "reuse_entries", "reuse_id")
    except (OSError, ValueError, UnicodeDecodeError, json.JSONDecodeError, DuplicateKey) as exc:
        current_registry_bytes = b""
        current_components = {}
        current_domains = {}
        current_reuse = {}
        failures.append(f"CURRENT_REGISTRY_INVALID:{exc}")
    try:
        activation_by_fingerprint = _fingerprint_activation_commits(root, head)
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError, DuplicateKey) as exc:
        activation_by_fingerprint = {}
        failures.append(f"LEDGER_ACTIVATION_HISTORY_INVALID:{exc}")

    records = ledger.get("records")
    if not isinstance(records, list):
        records = []
        failures.append("METADATA_RECORD_LIST_INVALID")
    if type(ledger.get("record_count")) is not int or ledger.get("record_count") != len(records):
        failures.append("METADATA_RECORD_COUNT_MISMATCH")
    previous_record = "0" * 64
    record_by_id: dict[str, dict[str, Any]] = {}
    seen_sources: set[str] = set()
    fp_binding: dict[str, dict[str, Any]] = {}
    component_ids: set[str] = set()
    raw_subset: set[str] = set()
    registry_snapshot_cache: dict[
        str,
        tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]],
    ] = {}
    registry_changes_by_activation: dict[
        str,
        tuple[set[str], set[str], set[str]],
    ] = {}
    for record in records:
        if not isinstance(record, dict) or set(record) != METADATA_FIELDS:
            failures.append("METADATA_FIELD_SET_MISMATCH")
            continue
        record_id = str(record.get("record_id", ""))
        if not record_id or record_id in record_by_id:
            failures.append(f"METADATA_RECORD_ID_DUPLICATE:{record_id}")
        record_by_id[record_id] = record
        for field, expected in (
            ("schema_version", METADATA_SCHEMA_VERSION), ("registry_path", REGISTRY_PATH),
            ("change_class", "DOCS_ONLY"),
            ("current_disposition", "CORRECTED_HISTORICAL_METADATA_DEBT"),
            ("selector_policy", SELECTOR_POLICY),
        ):
            if record.get(field) != expected:
                failures.append(f"METADATA_{field.upper()}_MISMATCH:{record_id}")
        if record.get("previous_record_payload_sha256") != previous_record:
            failures.append(f"METADATA_CHAIN_MISMATCH:{record_id}")
        if record.get("record_payload_sha256") != _payload_sha(record, "record_payload_sha256"):
            failures.append(f"METADATA_PAYLOAD_HASH_MISMATCH:{record_id}")
        previous_record = str(record.get("record_payload_sha256", ""))
        try:
            source = _exact_commit(root, record.get("source_commit"))
            parent = _exact_commit(root, record.get("parent_commit"))
            if source in seen_sources:
                failures.append(f"METADATA_SOURCE_DUPLICATE:{source}")
            seen_sources.add(source)
            parents = _git(root, "rev-list", "--parents", "-n", "1", source).split()[1:]
            if parents != [parent]:
                failures.append(f"METADATA_DIRECT_PARENT_MISMATCH:{record_id}")
            if record.get("commit_tree") != _git(root, "rev-parse", f"{source}^{{tree}}"):
                failures.append(f"METADATA_SOURCE_TREE_MISMATCH:{record_id}")
            if record.get("parent_tree") != _git(root, "rev-parse", f"{parent}^{{tree}}"):
                failures.append(f"METADATA_PARENT_TREE_MISMATCH:{record_id}")
            if not _is_ancestor(root, history_ancestry_anchor, source) or not _is_ancestor(root, source, raw_head):
                failures.append(f"METADATA_ANCESTRY_MISMATCH:{record_id}")
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
                failures.append(f"METADATA_SOURCE_SCOPE_MISMATCH:{record_id}")
            source_registry_bytes = _git_bytes(root, source, REGISTRY_PATH)
            parent_registry_bytes = _git_bytes(root, parent, REGISTRY_PATH)
            if source_registry_bytes is None or parent_registry_bytes is None:
                raise ValueError("REGISTRY_BLOB_MISSING")
            if _sha(source_registry_bytes) != record.get("source_registry_sha256"):
                failures.append(f"METADATA_SOURCE_REGISTRY_HASH_MISMATCH:{record_id}")
            if _sha(parent_registry_bytes) != record.get("parent_registry_sha256"):
                failures.append(f"METADATA_PARENT_REGISTRY_HASH_MISMATCH:{record_id}")
            source_registry = _json_bytes(source_registry_bytes)
            parent_registry = _json_bytes(parent_registry_bytes)
            source_components = _rows(source_registry, "component_inventory", "component_id")
            parent_components = _rows(parent_registry, "component_inventory", "component_id")
            source_domains = _rows(source_registry, "domain_inventory", "domain_id")
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError, DuplicateKey) as exc:
            source = ""
            parent = ""
            source_components = {}
            parent_components = {}
            source_domains = {}
            failures.append(f"METADATA_SOURCE_INVALID:{record_id}:{exc}")
        bindings = record.get("failure_bindings")
        if not isinstance(bindings, list):
            bindings = []
            failures.append(f"METADATA_BINDINGS_INVALID:{record_id}")
        if type(record.get("failure_count")) is not int or record.get("failure_count") != len(bindings):
            failures.append(f"METADATA_FAILURE_COUNT_MISMATCH:{record_id}")
        local_fps: list[str] = []
        local_domains: set[str] = set()
        local_owners: set[str] = set()
        local_reuse: set[str] = set()
        for binding in bindings:
            if not isinstance(binding, dict) or set(binding) != FAILURE_BINDING_FIELDS:
                failures.append(f"FAILURE_BINDING_FIELD_SET_MISMATCH:{record_id}")
                continue
            raw_failure = str(binding.get("raw_failure", ""))
            rule_id = str(binding.get("rule_id", ""))
            fingerprint = str(binding.get("failure_fingerprint", ""))
            component_id = str(binding.get("component_id", ""))
            if rule_id not in ALLOWED_RULES or not raw_failure.startswith(f"{rule_id}:"):
                failures.append(f"FAILURE_RULE_INVALID:{fingerprint}")
            if fingerprint != _fingerprint(raw_failure, rule_id):
                failures.append(f"FAILURE_FINGERPRINT_MISMATCH:{fingerprint}")
            if raw_failure not in raw_values:
                failures.append(f"FAILURE_RAW_MISSING:{fingerprint}")
            if fingerprint in fp_binding:
                failures.append(f"FAILURE_FINGERPRINT_DUPLICATE:{fingerprint}")
            fp_binding[fingerprint] = binding
            local_fps.append(fingerprint)
            raw_subset.add(raw_failure)
            component_ids.add(component_id)
            expected_transition = f"{parent[:12]}->{source[:12]}" if source and parent else ""
            parts = raw_failure.split(":")
            if len(parts) != 3 or parts[1] != expected_transition or parts[2] != component_id:
                failures.append(f"FAILURE_RAW_IDENTITY_MISMATCH:{fingerprint}")
            source_row = source_components.get(component_id)
            current_row = current_components.get(component_id)
            if source_row is None or current_row is None or component_id in parent_components:
                failures.append(f"FAILURE_COMPONENT_LIFECYCLE_MISMATCH:{fingerprint}")
                continue
            activation_commit = activation_by_fingerprint.get(fingerprint)
            if activation_commit is None:
                failures.append(f"FAILURE_ACTIVATION_COMMIT_MISSING:{fingerprint}")
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
                        failures.append(f"FAILURE_COMPONENT_ROW_TOUCHED:{fingerprint}")
                    if bound_domain_ids.intersection(changed_domain_ids):
                        failures.append(f"FAILURE_DOMAIN_ROW_TOUCHED:{fingerprint}")
                    if bound_owner_ids.intersection(changed_component_ids):
                        failures.append(f"FAILURE_OWNER_ROW_TOUCHED:{fingerprint}")
                    if component_id in changed_reachability_ids:
                        failures.append(
                            f"FAILURE_PRODUCTION_REACHABILITY_TOUCHED:{fingerprint}"
                        )
                except (ValueError, UnicodeDecodeError, json.JSONDecodeError, DuplicateKey) as exc:
                    failures.append(
                        f"FAILURE_REGISTRY_HISTORY_INVALID:{fingerprint}:{exc}"
                    )
            if binding.get("source_component_sha256") != _row_sha(source_row):
                failures.append(f"FAILURE_SOURCE_COMPONENT_HASH_MISMATCH:{fingerprint}")
            if binding.get("current_component_sha256") != _row_sha(current_row):
                failures.append(f"FAILURE_CURRENT_COMPONENT_HASH_MISMATCH:{fingerprint}")
            source_path = str(source_row.get("path", ""))
            current_path = str(current_row.get("path", ""))
            try:
                _, source_path = _repo_path(root, source_path)
                _, current_path = _repo_path(root, current_path)
            except ValueError as exc:
                failures.append(f"FAILURE_COMPONENT_PATH_INVALID:{fingerprint}:{exc}")
                source_path = ""
                current_path = ""
            source_domain_id = str(source_row.get("domain_id", ""))
            source_owner_id = str(source_row.get("owner_component_id", ""))
            current_owner_id = str(current_row.get("owner_component_id", ""))
            for field, expected in (
                ("source_component_path", source_path), ("current_component_path", current_path),
                ("source_domain_id", source_domain_id),
                ("source_owner_component_id", source_owner_id),
                ("current_owner_component_id", current_owner_id),
                ("source_production_reachability", source_row.get("production_reachable")),
            ):
                if binding.get(field) != expected:
                    failures.append(f"FAILURE_COMPONENT_FIELD_MISMATCH:{field}:{fingerprint}")
            source_path_bytes = _git_bytes(root, source, source_path) if source_path else None
            current_path_bytes = _git_bytes(root, head, current_path) if current_path else None
            if source_path_bytes is None or binding.get("source_path_blob_sha256") != _sha(source_path_bytes):
                failures.append(f"FAILURE_SOURCE_PATH_BLOB_MISMATCH:{fingerprint}")
            if current_path_bytes is None or binding.get("current_path_blob_sha256") != _sha(current_path_bytes):
                failures.append(f"FAILURE_CURRENT_PATH_BLOB_MISMATCH:{fingerprint}")
            if source_path in touched or current_path in touched:
                failures.append(f"FAILURE_COMPONENT_PATH_TOUCHED:{fingerprint}")
            source_domain = source_domains.get(source_domain_id)
            current_domain = current_domains.get(str(current_row.get("domain_id", "")))
            if source_domain is None or current_domain is None:
                failures.append(f"FAILURE_DOMAIN_MISSING:{fingerprint}")
            else:
                if binding.get("source_domain_sha256") != _row_sha(source_domain):
                    failures.append(f"FAILURE_SOURCE_DOMAIN_HASH_MISMATCH:{fingerprint}")
                if binding.get("current_domain_sha256") != _row_sha(current_domain):
                    failures.append(f"FAILURE_CURRENT_DOMAIN_HASH_MISMATCH:{fingerprint}")
            source_owner = source_components.get(source_owner_id)
            current_owner = current_components.get(current_owner_id)
            if source_owner is None or current_owner is None:
                failures.append(f"FAILURE_OWNER_MISSING:{fingerprint}")
            else:
                source_owner_path = str(source_owner.get("path", ""))
                current_owner_path = str(current_owner.get("path", ""))
                try:
                    _, source_owner_path = _repo_path(root, source_owner_path)
                    _, current_owner_path = _repo_path(root, current_owner_path)
                except ValueError as exc:
                    failures.append(f"FAILURE_OWNER_PATH_INVALID:{fingerprint}:{exc}")
                    source_owner_path = ""
                    current_owner_path = ""
                for field, expected in (
                    ("source_owner_component_sha256", _row_sha(source_owner)),
                    ("current_owner_component_sha256", _row_sha(current_owner)),
                    ("source_owner_path", source_owner_path),
                    ("current_owner_path", current_owner_path),
                ):
                    if binding.get(field) != expected:
                        failures.append(f"FAILURE_OWNER_FIELD_MISMATCH:{field}:{fingerprint}")
                source_owner_bytes = _git_bytes(root, source, source_owner_path) if source_owner_path else None
                current_owner_bytes = _git_bytes(root, head, current_owner_path) if current_owner_path else None
                if source_owner_bytes is None or binding.get("source_owner_path_blob_sha256") != _sha(source_owner_bytes):
                    failures.append(f"FAILURE_SOURCE_OWNER_BLOB_MISMATCH:{fingerprint}")
                if current_owner_bytes is None or binding.get("current_owner_path_blob_sha256") != _sha(current_owner_bytes):
                    failures.append(f"FAILURE_CURRENT_OWNER_BLOB_MISMATCH:{fingerprint}")
                if source_owner_path in touched or current_owner_path in touched:
                    failures.append(f"FAILURE_OWNER_PATH_TOUCHED:{fingerprint}")
            local_domains.add(source_domain_id)
            local_owners.add(source_owner_id)
            if rule_id == "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID":
                local_reuse.add(component_id)
                scan = current_row.get("reuse_scan")
                candidates = scan.get("reuse_candidate_ids") if isinstance(scan, dict) else None
                considered = current_row.get("reuse_candidates_considered")
                valid_scan = bool(
                    isinstance(scan, dict) and set(scan) == REUSE_SCAN_FIELDS
                    and all(scan.get(key) is True for key in REUSE_SCAN_FIELDS if key.endswith("_search"))
                    and isinstance(candidates, list) and candidates
                    and all(isinstance(value, str) and value in current_reuse for value in candidates)
                    and len(candidates) == len(set(candidates))
                    and type(scan.get("reuse_candidate_count")) is int
                    and scan.get("reuse_candidate_count") == len(candidates)
                    and isinstance(considered, list)
                    and all(isinstance(value, str) for value in considered)
                    and set(candidates).issubset(set(considered))
                    and scan.get("selected_reuse_disposition") == current_row.get("reuse_disposition")
                    and all(isinstance(scan.get(key), str) and scan[key].strip() for key in (
                        "why_existing_owner_cannot_be_extended", "why_adapter_is_insufficient",
                        "why_new_owner_is_required",
                    ))
                    and current_row.get("change_class") != "INHERITED"
                )
                if not valid_scan:
                    failures.append(f"FAILURE_REUSE_SCAN_INVALID:{fingerprint}")
        if local_fps != sorted(local_fps):
            failures.append(f"METADATA_FINGERPRINT_ORDER_INVALID:{record_id}")
        if record.get("failure_fingerprint_set_sha256") != _line_set_sha(local_fps):
            failures.append(f"METADATA_FINGERPRINT_SET_HASH_MISMATCH:{record_id}")
        if record.get("reuse_scan_component_ids") != sorted(local_reuse):
            failures.append(f"METADATA_REUSE_COMPONENT_SET_MISMATCH:{record_id}")
        if record.get("affected_domains") != sorted(local_domains):
            failures.append(f"METADATA_DOMAIN_SET_MISMATCH:{record_id}")
        if record.get("affected_owners") != sorted(local_owners):
            failures.append(f"METADATA_OWNER_SET_MISMATCH:{record_id}")
        if not _exact_strings(record.get("focused_tests")):
            failures.append(f"METADATA_FOCUSED_TESTS_INVALID:{record_id}")
        if not isinstance(record.get("historical_context"), str) or not record["historical_context"].strip():
            failures.append(f"METADATA_CONTEXT_INVALID:{record_id}")

    authorized = set(fp_binding)
    if type(ledger.get("failure_count")) is not int or ledger.get("failure_count") != len(authorized):
        failures.append("LEDGER_FAILURE_COUNT_MISMATCH")
    if ledger.get("failure_fingerprint_set_sha256") != _line_set_sha(authorized):
        failures.append("LEDGER_FAILURE_SET_HASH_MISMATCH")

    correction_bindings = ledger.get("correction_record_bindings")
    if not isinstance(correction_bindings, list):
        correction_bindings = []
        failures.append("CORRECTION_BINDING_LIST_INVALID")
    if type(ledger.get("correction_record_count")) is not int or ledger.get("correction_record_count") != len(correction_bindings):
        failures.append("CORRECTION_RECORD_COUNT_MISMATCH")
    previous_correction = "0" * 64
    verified: set[str] = set()
    correction_ids: set[str] = set()
    correction_paths: set[str] = set()
    for binding in correction_bindings:
        if not isinstance(binding, dict) or set(binding) != CORRECTION_BINDING_FIELDS:
            failures.append("CORRECTION_BINDING_FIELD_SET_MISMATCH")
            continue
        path_value = str(binding.get("path", ""))
        try:
            _, correction_relative = _repo_path(root, path_value, prefix=CORRECTION_ROOT)
            if any(token in correction_relative for token in ("*", "?", "[", "]")):
                raise ValueError("CORRECTION_GLOB_FORBIDDEN")
            if not correction_relative.endswith(".json"):
                raise ValueError("CORRECTION_NOT_JSON")
            correction, correction_bytes = _committed_document(root, head, correction_relative)
        except (OSError, ValueError, UnicodeDecodeError, json.JSONDecodeError, DuplicateKey) as exc:
            failures.append(f"CORRECTION_INPUT_INVALID:{path_value}:{exc}")
            continue
        if path_value in correction_paths:
            failures.append(f"CORRECTION_PATH_DUPLICATE:{path_value}")
        correction_paths.add(path_value)
        correction_id = str(binding.get("correction_id", ""))
        if not correction_id or correction_id in correction_ids:
            failures.append(f"CORRECTION_ID_DUPLICATE:{correction_id}")
        correction_ids.add(correction_id)
        if binding.get("file_sha256") != _sha(correction_bytes):
            failures.append(f"CORRECTION_FILE_HASH_MISMATCH:{correction_id}")
        if set(correction) != CORRECTION_FIELDS:
            failures.append(f"CORRECTION_FIELD_SET_MISMATCH:{correction_id}")
            continue
        for field, expected in (
            ("schema_version", CORRECTION_SCHEMA_VERSION),
            ("record_kind", "HISTORICAL_DELTA_METADATA_EXACT_CORRECTION"),
            ("correction_id", correction_id), ("ledger_id", LEDGER_ID),
            ("authorization_id", AUTHORIZATION_ID),
            ("authorization_base_head_sha", AUTHORIZATION_BASE_HEAD_SHA),
            ("raw_report_sha256", raw_sha), ("raw_report_head_sha", raw_head),
            ("selector_policy", SELECTOR_POLICY),
            ("from_state", "RAW_HISTORICAL_METADATA_FAILURE"),
            ("to_effective_disposition", "CORRECTED_HISTORICAL_METADATA_DEBT"),
            ("untouched_in_current_delta", True),
            ("touch_invalidation_policy", TOUCH_POLICY),
            ("future_failure_policy", FUTURE_POLICY),
        ):
            if correction.get(field) != expected:
                failures.append(f"CORRECTION_{field.upper()}_MISMATCH:{correction_id}")
        if correction.get("previous_correction_payload_sha256") != previous_correction:
            failures.append(f"CORRECTION_CHAIN_MISMATCH:{correction_id}")
        if correction.get("record_payload_sha256") != _payload_sha(correction, "record_payload_sha256"):
            failures.append(f"CORRECTION_PAYLOAD_HASH_MISMATCH:{correction_id}")
        previous_correction = str(correction.get("record_payload_sha256", ""))
        if binding.get("record_payload_sha256") != correction.get("record_payload_sha256"):
            failures.append(f"CORRECTION_BINDING_PAYLOAD_MISMATCH:{correction_id}")
        fps = correction.get("failure_fingerprints")
        if not _exact_strings(fps) or any(re.fullmatch(r"V2F-[0-9a-f]{64}", value) is None for value in (fps or [])):
            failures.append(f"CORRECTION_FINGERPRINT_SET_INVALID:{correction_id}")
            fps = []
        if binding.get("failure_fingerprints") != fps:
            failures.append(f"CORRECTION_BINDING_FINGERPRINT_MISMATCH:{correction_id}")
        if type(correction.get("failure_count")) is not int or correction.get("failure_count") != len(fps) or binding.get("failure_count") != len(fps):
            failures.append(f"CORRECTION_FAILURE_COUNT_MISMATCH:{correction_id}")
        if correction.get("failure_fingerprint_set_sha256") != _line_set_sha(fps):
            failures.append(f"CORRECTION_FAILURE_SET_HASH_MISMATCH:{correction_id}")
        if verified.intersection(fps):
            failures.append(f"CORRECTION_FINGERPRINT_COLLISION:{correction_id}")
        verified.update(fps)
        rule_id = str(correction.get("rule_id", ""))
        if rule_id not in ALLOWED_RULES or correction.get("transition_class_id") != TRANSITION_BY_RULE.get(rule_id):
            failures.append(f"CORRECTION_RULE_CLASS_MISMATCH:{correction_id}")
        if any(fp_binding.get(fp, {}).get("rule_id") != rule_id for fp in fps):
            failures.append(f"CORRECTION_RULE_GROUP_MISMATCH:{correction_id}")
        metadata_ids = correction.get("metadata_record_ids")
        if not _exact_strings(metadata_ids) or any(value not in record_by_id for value in (metadata_ids or [])):
            failures.append(f"CORRECTION_METADATA_IDS_INVALID:{correction_id}")
        fp_set = set(fps)
        matching_ids = sorted({
            record_id for record_id, record in record_by_id.items()
            if any(
                isinstance(item, dict) and item.get("failure_fingerprint") in fp_set
                for item in (
                    record.get("failure_bindings")
                    if isinstance(record.get("failure_bindings"), list)
                    else []
                )
            )
        })
        if metadata_ids != matching_ids:
            failures.append(f"CORRECTION_METADATA_SET_MISMATCH:{correction_id}")
        expected_components = sorted({str(fp_binding.get(fp, {}).get("component_id", "")) for fp in fps})
        if correction.get("component_ids") != expected_components or correction.get("component_set_sha256") != _line_set_sha(expected_components):
            failures.append(f"CORRECTION_COMPONENT_SET_MISMATCH:{correction_id}")
        source_commits = {str(record_by_id[value].get("source_commit", "")) for value in matching_ids}
        parent_commits = {str(record_by_id[value].get("parent_commit", "")) for value in matching_ids}
        if re.fullmatch(r"[0-9a-f]{40}", str(correction.get("source_commit", ""))) is None or source_commits != {correction.get("source_commit")}:
            failures.append(f"CORRECTION_SOURCE_COMMIT_MISMATCH:{correction_id}")
        if re.fullmatch(r"[0-9a-f]{40}", str(correction.get("parent_commit", ""))) is None or parent_commits != {correction.get("parent_commit")}:
            failures.append(f"CORRECTION_PARENT_COMMIT_MISMATCH:{correction_id}")
        if not _exact_strings(correction.get("backlog_item_ids")):
            failures.append(f"CORRECTION_BACKLOG_INVALID:{correction_id}")
    if verified != authorized:
        failures.append(f"CORRECTION_COVERAGE_MISMATCH:{len(authorized - verified)}:{len(verified - authorized)}")
    if type(ledger.get("corrected_failure_count")) is not int or ledger.get("corrected_failure_count") != len(verified):
        failures.append("LEDGER_CORRECTED_COUNT_MISMATCH")

    append_only_failures, predecessor_sha = _append_only_findings(
        root,
        head,
        ledger,
        ledger_bytes,
    )
    failures.extend(append_only_failures)

    native_historical = sum(1 for value in raw_values if value.split(":", 1)[0].startswith("HISTORY_"))
    promoted = sum(1 for binding in fp_binding.values() if not str(binding.get("rule_id", "")).startswith("HISTORY_"))
    semantic_historical = native_historical + promoted
    true_current = len(raw_values) - semantic_historical
    for label, actual, expected in (
        ("NATIVE_HISTORICAL", native_historical, expectations.get("native_historical_count")),
        ("LEDGER_PROMOTED", promoted, expectations.get("ledger_promoted_count")),
        ("SEMANTIC_HISTORICAL", semantic_historical, expectations.get("semantic_historical_count")),
        ("TRUE_CURRENT", true_current, expectations.get("true_current_count")),
        ("AUTHORIZED", len(authorized), expectations.get("authorized_failure_count")),
        ("COMPONENT", len(component_ids), expectations.get("component_count")),
    ):
        if actual != expected:
            failures.append(f"EPOCH_{label}_COUNT_MISMATCH")
    if _line_set_sha(raw_subset) != expectations.get("authorized_raw_set_sha256"):
        failures.append("EPOCH_AUTHORIZED_RAW_SET_HASH_MISMATCH")
    if _line_set_sha(authorized) != expectations.get("authorized_fingerprint_set_sha256"):
        failures.append("EPOCH_AUTHORIZED_FINGERPRINT_SET_HASH_MISMATCH")
    if _line_set_sha(component_ids) != expectations.get("component_set_sha256"):
        failures.append("EPOCH_COMPONENT_SET_HASH_MISMATCH")

    # A standalone independent audit may still be GO, but it has not proven
    # cross-implementation parity until the caller supplies the primary
    # projection.  Keep the receipt truthful so an orchestrator cannot mistake
    # an omitted comparison for a successful comparison.
    primary_match = False
    if primary_projection is not None:
        primary_authorized_values = primary_projection.get(
            "authorized_historical_fingerprints", []
        )
        primary_verified_values = primary_projection.get(
            "verified_historical_fingerprints", []
        )
        primary_authorized = (
            set(primary_authorized_values)
            if _exact_strings(primary_authorized_values, allow_empty=True)
            else set()
        )
        primary_verified = (
            set(primary_verified_values)
            if _exact_strings(primary_verified_values, allow_empty=True)
            else set()
        )
        count_parity = all(
            type(primary_projection.get(field)) is int
            and primary_projection.get(field) == expected
            for field, expected in (
                ("raw_failure_count", len(raw_values)),
                ("preledger_native_historical_bucket_count", native_historical),
                ("ledger_exact_promoted_count", promoted),
                ("semantic_historical_failure_count", semantic_historical),
                ("true_current_failure_count", true_current),
                ("metadata_record_count", len(records)),
                ("correction_record_count", len(correction_bindings)),
            )
        )
        primary_match = bool(
            primary_projection.get("status") == "PASS"
            and primary_authorized == authorized
            and primary_verified == verified
            and count_parity
        )
        if not primary_match:
            failures.append("PRIMARY_PROJECTION_SET_PARITY_MISMATCH")

    try:
        if _grafts_file_nonempty(root):
            failures.append("GIT_GRAFTS_FORBIDDEN")
    except ValueError as exc:
        failures.append(f"GIT_GRAFTS_INVALID:{exc}")
    failures = sorted(set(failures))
    return {
        "status": "GO" if not failures else "NO_GO",
        "failures": failures,
        "evaluated_head_sha": head,
        "evaluated_tree_sha": _git(root, "rev-parse", f"{head}^{{tree}}"),
        "ledger_sha256": _sha(ledger_bytes),
        "schema_sha256": _sha(schema_bytes),
        "raw_report_sha256": raw_sha,
        "scanner_sha256": scanner_sha,
        "raw_failure_count": len(raw_values),
        "preledger_native_historical_bucket_count": native_historical,
        "ledger_exact_promoted_count": promoted,
        "semantic_historical_failure_count": semantic_historical,
        "true_current_failure_count": true_current,
        "metadata_record_count": len(records),
        "source_transition_count": len(seen_sources),
        "authorized_failure_count": len(authorized),
        "authorized_failure_set_sha256": _line_set_sha(authorized),
        "correction_record_count": len(correction_bindings),
        "verified_failure_count": len(verified),
        "verified_failure_set_sha256": _line_set_sha(verified),
        "component_count": len(component_ids),
        "component_set_sha256": _line_set_sha(component_ids),
        "predecessor_ledger_sha256": predecessor_sha,
        "primary_projection_digest_match": primary_match,
        "wildcard_count": 0,
        "future_failure_auto_match_count": 0,
        "raw_failure_detection_suppressed_count": 0,
    }


def audit_ledger(
    root: Path,
    ledger_path: Path,
    *,
    evaluated_head: str,
    primary_projection: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Audit the frozen production authority; no caller-supplied override exists."""
    return _audit_ledger_impl(
        root,
        ledger_path,
        evaluated_head=evaluated_head,
        expectations=DEFAULT_EXPECTATIONS,
        history_ancestry_anchor=AUTHORIZATION_BASE_HEAD_SHA,
        primary_projection=primary_projection,
    )


def audit_fixture_ledger_for_selftest(
    root: Path,
    ledger_path: Path,
    *,
    evaluated_head: str,
    history_ancestry_anchor: str,
    test_expectations: Mapping[str, int | str],
    primary_projection: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Exercise the independent algorithm only inside an explicitly marked fixture repo."""
    root = root.resolve()
    try:
        _exact_commit(root, AUTHORIZATION_BASE_HEAD_SHA)
    except ValueError:
        pass
    else:
        return {
            "status": "NO_GO",
            "failures": ["SELFTEST_FIXTURE_FORBIDDEN_IN_AUTHORIZED_REPOSITORY"],
            "authorized_failure_count": 0,
            "verified_failure_count": 0,
            "primary_projection_digest_match": False,
        }
    try:
        _exact_commit(root, history_ancestry_anchor)
    except ValueError as exc:
        return {
            "status": "NO_GO",
            "failures": [f"SELFTEST_FIXTURE_AUTHORITY_INVALID:{exc}"],
            "authorized_failure_count": 0,
            "verified_failure_count": 0,
            "primary_projection_digest_match": False,
        }
    marker_result = subprocess.run(
        ["git", "config", "--local", "--get", SELFTEST_FIXTURE_CONFIG_KEY],
        cwd=root,
        env=_git_environment(),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    marker = marker_result.stdout.strip() if marker_result.returncode == 0 else ""
    if marker != "true":
        return {
            "status": "NO_GO",
            "failures": ["SELFTEST_FIXTURE_MARKER_MISSING"],
            "authorized_failure_count": 0,
            "verified_failure_count": 0,
            "primary_projection_digest_match": False,
        }
    if set(test_expectations) != set(DEFAULT_EXPECTATIONS) or any(
        type(test_expectations[key]) is not type(DEFAULT_EXPECTATIONS[key])
        for key in DEFAULT_EXPECTATIONS
    ):
        return {
            "status": "NO_GO",
            "failures": ["SELFTEST_EXPECTATION_FIELD_SET_INVALID"],
            "authorized_failure_count": 0,
            "verified_failure_count": 0,
            "primary_projection_digest_match": False,
        }
    return _audit_ledger_impl(
        root,
        ledger_path,
        evaluated_head=evaluated_head,
        expectations=test_expectations,
        history_ancestry_anchor=history_ancestry_anchor,
        primary_projection=primary_projection,
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument("--head-ref", required=True)
    args = parser.parse_args(argv)
    report = audit_ledger(
        args.project.resolve(), args.ledger.resolve(), evaluated_head=args.head_ref
    )
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if report.get("status") == "GO" else 1


if __name__ == "__main__":
    raise SystemExit(main())
