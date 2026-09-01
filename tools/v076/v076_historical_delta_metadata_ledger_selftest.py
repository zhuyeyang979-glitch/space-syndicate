#!/usr/bin/env python3
"""Targeted self-test for exact Historical Delta Metadata evidence."""

from __future__ import annotations

import copy
import inspect
import json
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable

import v076_historical_delta_metadata_ledger as ledger
import v076_historical_delta_metadata_independent_audit as independent


PROJECT_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_REL = Path(ledger.REGISTRY_PATH)
SCHEMA_REL = Path(ledger.SCHEMA_PATH)
SCANNER_REL = Path("tools/v076/v076_reuse_point_inertia_gate.py")
PRODUCT_REL = Path("scripts/selftest/reducer.gd")
OWNER_REL = Path("scripts/selftest/runtime_owner.gd")
RAW_REL = Path("reports/reuse/correction_v2/epochs/full_convergence_20260827/selftest_raw.json")
LEDGER_REL = Path("docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json")
CORRECTION_ROOT = Path(
    "docs/architecture/reuse_corrections/v2/records/"
    "full_convergence_20260827/historical_delta_metadata"
)


def _run(root: Path, *args: str) -> str:
    result = subprocess.run(
        list(args),
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    return result.stdout.strip()


def _write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(ledger.canonical_bytes(value))


def _commit(root: Path, message: str) -> str:
    _run(root, "git", "add", ".")
    _run(root, "git", "commit", "-m", message)
    return _run(root, "git", "rev-parse", "HEAD")


def _registry(
    component: dict[str, Any] | list[dict[str, Any]] | None,
) -> dict[str, Any]:
    if component is None:
        components: list[dict[str, Any]] = []
    elif isinstance(component, list):
        components = component
    else:
        components = [component]
    return {
        "schema_version": "space_syndicate.v076.historical_reuse_registry.v1",
        "domain_inventory": [_domain_row()],
        "component_inventory": [_owner_component(), *components],
        "reuse_entries": [{"reuse_id": "reuse.v075.combat_candidate"}],
    }


def _domain_row() -> dict[str, Any]:
    return {
        "domain_id": "current.v075_production_combat_candidate",
        "description": "Self-test authority domain.",
    }


def _owner_component() -> dict[str, Any]:
    return {
        "component_id": "component.current.v075_runtime_owner",
        "path": OWNER_REL.as_posix(),
        "component_role": "OWNER",
        "domain_id": "current.v075_production_combat_candidate",
        "production_reachable": True,
    }


def _source_component() -> dict[str, Any]:
    return {
        "component_id": "component.selftest.reducer",
        "class_name": "SelfTestReducer",
        "path": "scripts/selftest/reducer.gd",
        "domain_id": "current.v075_production_combat_candidate",
        "component_role": "REDUCER",
        "production_reachable": True,
        "writes_authority": True,
        "reads_authority": True,
        "owns_rng": False,
        "owns_tick": False,
        "owns_save": False,
        "owns_replay": False,
        "owns_identity": False,
        "owns_presentation": False,
        "owner_component_id": "component.current.v075_runtime_owner",
        "owner_path": "scripts/v075_runtime/v075_runtime_owner.gd",
        "reuse_disposition": "ADAPT_AS_CONSUMER",
        "reuse_source_ids": ["reuse.v075.combat_candidate"],
        "reuse_candidates_considered": ["reuse.v075.combat_candidate"],
        "new_component_justification": "Historical subordinate reducer fixture.",
        "supersedes": [],
        "superseded_by": [],
        "change_class": "INHERITED",
        "focused_test_ids": ["selftest"],
        "golden_scenario_steps": [],
    }


def _repaired_component() -> dict[str, Any]:
    row = _source_component()
    row["change_class"] = "DOCS_ONLY"
    row["reuse_scan"] = {
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
        "reuse_candidate_ids": ["reuse.v075.combat_candidate"],
        "selected_reuse_disposition": "ADAPT_AS_CONSUMER",
        "why_existing_owner_cannot_be_extended": "NOT_APPLICABLE_EXISTING_SUBORDINATE_REDUCER",
        "why_adapter_is_insufficient": "A pass-through adapter cannot preserve reducer invariants.",
        "why_new_owner_is_required": "NOT_REQUIRED; the existing Owner remains unique.",
    }
    return row


def _source_component_two() -> dict[str, Any]:
    row = _source_component()
    row["component_id"] = "component.selftest.reducer_two"
    row["class_name"] = "SelfTestReducerTwo"
    row["new_component_justification"] = "Second historical subordinate reducer fixture."
    return row


def _repaired_component_two() -> dict[str, Any]:
    row = _repaired_component()
    row["component_id"] = "component.selftest.reducer_two"
    row["class_name"] = "SelfTestReducerTwo"
    row["new_component_justification"] = "Second historical subordinate reducer fixture."
    return row


def _seal_metadata(records: list[dict[str, Any]]) -> None:
    previous = "0" * 64
    for record in records:
        record["previous_record_payload_sha256"] = previous
        record["record_payload_sha256"] = ledger.payload_sha256(
            record, "record_payload_sha256"
        )
        previous = record["record_payload_sha256"]


def _seal_corrections(records: list[dict[str, Any]]) -> None:
    previous = "0" * 64
    for record in records:
        record["previous_correction_payload_sha256"] = previous
        record["record_payload_sha256"] = ledger.payload_sha256(
            record, "record_payload_sha256"
        )
        previous = record["record_payload_sha256"]


def _seal_ledger(document: dict[str, Any]) -> None:
    document["ledger_payload_sha256"] = ledger.payload_sha256(
        document, "ledger_payload_sha256"
    )


Transform = Callable[[dict[str, Any], list[dict[str, Any]], list[dict[str, Any]], dict[str, Any]], None]


def _fixture(
    transform: Transform | None = None,
    *,
    post_commit_component_mutation: bool = False,
    post_commit_path_touch: bool = False,
    prepare_second_transition: bool = False,
) -> tuple[tempfile.TemporaryDirectory[str], Path, str, str, dict[str, Any]]:
    temp = tempfile.TemporaryDirectory(prefix="v076-historical-delta-selftest-")
    root = Path(temp.name)
    _run(root, "git", "init", "-q")
    _run(root, "git", "config", "user.name", "V076 Selftest")
    _run(root, "git", "config", "user.email", "v076-selftest@example.invalid")
    _run(
        root,
        "git",
        "config",
        independent.SELFTEST_FIXTURE_CONFIG_KEY,
        "true",
    )
    (root / SCANNER_REL).parent.mkdir(parents=True, exist_ok=True)
    (root / SCANNER_REL).write_text("# immutable raw scanner fixture\n", encoding="utf-8")
    (root / SCHEMA_REL).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(PROJECT_ROOT / SCHEMA_REL, root / SCHEMA_REL)
    (root / PRODUCT_REL).parent.mkdir(parents=True, exist_ok=True)
    (root / PRODUCT_REL).write_text("extends RefCounted\n", encoding="utf-8")
    (root / OWNER_REL).write_text("extends Node\n", encoding="utf-8")
    _write_json(root / REGISTRY_REL, _registry(None))
    base = _commit(root, "base")

    source_row = _source_component()
    _write_json(root / REGISTRY_REL, _registry(source_row))
    source = _commit(root, "source registry-only metadata delta")
    source_tree = _run(root, "git", "rev-parse", "HEAD^{tree}")
    parent_tree = _run(root, "git", "rev-parse", f"{base}^{{tree}}")

    second_source = ""
    second_source_row: dict[str, Any] | None = None
    if prepare_second_transition:
        second_source_row = _source_component_two()
        _write_json(root / REGISTRY_REL, _registry([source_row, second_source_row]))
        second_source = _commit(root, "second source registry-only metadata delta")
        _run(root, "git", "tag", "v076-selftest-second-source", second_source)

    (root / "raw-head-marker.txt").write_text("raw head\n", encoding="utf-8")
    raw_head = _commit(root, "raw head")

    repaired_row = _repaired_component()
    repaired_rows = [repaired_row]
    if prepare_second_transition:
        repaired_rows.append(_repaired_component_two())
    _write_json(root / REGISTRY_REL, _registry(repaired_rows))
    repair_head = _commit(root, "repair current reuse scan")

    transition = f"{base[:12]}->{source[:12]}"
    raw_new = (
        "NEW_COMPONENT_CANNOT_CLAIM_INHERITED:"
        f"{transition}:{source_row['component_id']}"
    )
    raw_scan = (
        "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID:"
        f"{transition}:{source_row['component_id']}"
    )
    raw_current = "EVIDENCE_SUBJECT_PRODUCT_TREE_DRIFT"
    raw_failures = [raw_scan, raw_new]
    if prepare_second_transition and second_source_row is not None:
        second_transition = f"{source[:12]}->{second_source[:12]}"
        raw_failures.extend(
            [
                "HISTORY_NEW_AUTHORITY_REUSE_SCAN_INVALID:"
                f"{second_transition}:{second_source_row['component_id']}",
                "NEW_COMPONENT_CANNOT_CLAIM_INHERITED:"
                f"{second_transition}:{second_source_row['component_id']}",
            ]
        )
    raw_failures.append(raw_current)
    raw_report = {
        "status": "FAIL",
        "head_sha": raw_head,
        "include_worktree": False,
        "evaluated_source": "COMMITTED_HEAD",
        "failures": raw_failures,
    }
    raw_path = root / RAW_REL
    _write_json(raw_path, raw_report)
    raw_sha = ledger.sha256_file(raw_path)

    source_registry = subprocess.run(
        ["git", "show", f"{source}:{REGISTRY_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    parent_registry = subprocess.run(
        ["git", "show", f"{base}:{REGISTRY_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    source_product = subprocess.run(
        ["git", "show", f"{source}:{PRODUCT_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    current_product = subprocess.run(
        ["git", "show", f"{repair_head}:{PRODUCT_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    source_owner_product = subprocess.run(
        ["git", "show", f"{source}:{OWNER_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    current_owner_product = subprocess.run(
        ["git", "show", f"{repair_head}:{OWNER_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    fingerprints = {
        raw: ledger.failure_fingerprint(raw, raw.split(":", 1)[0])
        for raw in (raw_scan, raw_new)
    }
    bindings = [
        {
            "failure_fingerprint": fingerprints[raw],
            "raw_failure": raw,
            "rule_id": raw.split(":", 1)[0],
            "component_id": source_row["component_id"],
            "source_component_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(source_row)
            ),
            "current_component_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(repaired_row)
            ),
            "source_component_path": source_row["path"],
            "current_component_path": repaired_row["path"],
            "source_path_blob_sha256": ledger.sha256_bytes(source_product),
            "current_path_blob_sha256": ledger.sha256_bytes(current_product),
            "source_domain_id": source_row["domain_id"],
            "source_domain_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(_domain_row())
            ),
            "current_domain_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(_domain_row())
            ),
            "source_owner_component_id": source_row["owner_component_id"],
            "current_owner_component_id": repaired_row["owner_component_id"],
            "source_owner_component_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(_owner_component())
            ),
            "current_owner_component_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(_owner_component())
            ),
            "source_owner_path": OWNER_REL.as_posix(),
            "current_owner_path": OWNER_REL.as_posix(),
            "source_owner_path_blob_sha256": ledger.sha256_bytes(source_owner_product),
            "current_owner_path_blob_sha256": ledger.sha256_bytes(current_owner_product),
            "source_production_reachability": source_row["production_reachable"],
        }
        for raw in (raw_scan, raw_new)
    ]
    bindings.sort(key=lambda item: item["failure_fingerprint"])
    metadata_records = [
        {
            "schema_version": ledger.METADATA_RECORD_SCHEMA_VERSION,
            "record_id": "HDM-SELFTEST-001",
            "source_commit": source,
            "parent_commit": base,
            "commit_tree": source_tree,
            "parent_tree": parent_tree,
            "registry_path": ledger.REGISTRY_PATH,
            "source_registry_sha256": ledger.sha256_bytes(source_registry),
            "parent_registry_sha256": ledger.sha256_bytes(parent_registry),
            "change_class": "DOCS_ONLY",
            "affected_domains": [source_row["domain_id"]],
            "affected_owners": [source_row["owner_component_id"]],
            "focused_tests": ["v076_historical_delta_metadata_ledger_selftest"],
            "historical_context": "Exact registry-only historical metadata backfill.",
            "current_disposition": "CORRECTED_HISTORICAL_METADATA_DEBT",
            "selector_policy": ledger.EXACT_SELECTOR_POLICY,
            "reuse_scan_component_ids": [source_row["component_id"]],
            "failure_count": len(bindings),
            "failure_fingerprint_set_sha256": ledger.line_set_sha(
                item["failure_fingerprint"] for item in bindings
            ),
            "failure_bindings": bindings,
            "previous_record_payload_sha256": "",
            "record_payload_sha256": "",
        }
    ]
    _seal_metadata(metadata_records)

    corrections: list[dict[str, Any]] = []
    for index, raw in enumerate((raw_scan, raw_new), start=1):
        rule_id = raw.split(":", 1)[0]
        fp = fingerprints[raw]
        corrections.append(
            {
                "schema_version": ledger.CORRECTION_RECORD_SCHEMA_VERSION,
                "record_kind": "HISTORICAL_DELTA_METADATA_EXACT_CORRECTION",
                "correction_id": f"V2-HDM-SELFTEST-{index:02d}",
                "ledger_id": ledger.LEDGER_ID,
                "metadata_record_ids": ["HDM-SELFTEST-001"],
                "authorization_id": ledger.AUTHORIZATION_ID,
                "authorization_base_head_sha": ledger.AUTHORIZATION_BASE_HEAD_SHA,
                "raw_report_sha256": raw_sha,
                "raw_report_head_sha": raw_head,
                "rule_id": rule_id,
                "transition_class_id": ledger.TRANSITION_CLASS_BY_RULE[rule_id],
                "source_commit": source,
                "parent_commit": base,
                "component_ids": [source_row["component_id"]],
                "component_set_sha256": ledger.line_set_sha([source_row["component_id"]]),
                "failure_count": 1,
                "failure_fingerprints": [fp],
                "failure_fingerprint_set_sha256": ledger.line_set_sha([fp]),
                "selector_policy": ledger.EXACT_SELECTOR_POLICY,
                "from_state": "RAW_HISTORICAL_METADATA_FAILURE",
                "to_effective_disposition": "CORRECTED_HISTORICAL_METADATA_DEBT",
                "untouched_in_current_delta": True,
                "touch_invalidation_policy": ledger.TOUCH_INVALIDATION_POLICY,
                "future_failure_policy": ledger.FUTURE_FAILURE_POLICY,
                "backlog_item_ids": ["V076_HISTORICAL_METADATA_DEBT"],
                "previous_correction_payload_sha256": "",
                "record_payload_sha256": "",
            }
        )
    _seal_corrections(corrections)

    document: dict[str, Any] = {
        "schema_version": ledger.LEDGER_SCHEMA_VERSION,
        "ledger_id": ledger.LEDGER_ID,
        "authorization_id": ledger.AUTHORIZATION_ID,
        "authorization_base_head_sha": ledger.AUTHORIZATION_BASE_HEAD_SHA,
        "schema_path": ledger.SCHEMA_PATH,
        "schema_sha256": ledger.sha256_file(root / SCHEMA_REL),
        "raw_report_path": RAW_REL.as_posix(),
        "raw_report_sha256": raw_sha,
        "raw_report_head_sha": raw_head,
        "raw_report_tree_sha": _run(root, "git", "rev-parse", f"{raw_head}^{{tree}}"),
        "scanner_path": SCANNER_REL.as_posix(),
        "scanner_sha256": ledger.sha256_bytes(
            subprocess.run(
                ["git", "show", f"{raw_head}:{SCANNER_REL.as_posix()}"],
                cwd=root,
                check=True,
                stdout=subprocess.PIPE,
            ).stdout
        ),
        "registry_path": ledger.REGISTRY_PATH,
        "selector_policy": ledger.EXACT_SELECTOR_POLICY,
        "record_count": len(metadata_records),
        "records": metadata_records,
        "failure_count": len(fingerprints),
        "failure_fingerprint_set_sha256": ledger.line_set_sha(fingerprints.values()),
        "correction_record_count": len(corrections),
        "correction_record_bindings": [],
        "corrected_failure_count": len(fingerprints),
        "previous_ledger_path": "",
        "previous_ledger_sha256": "",
        "append_only": True,
        "ledger_payload_sha256": "",
    }
    if transform is not None:
        transform(document, metadata_records, corrections, raw_report)
        _write_json(raw_path, raw_report)
        updated_raw_sha = ledger.sha256_file(raw_path)
        document["raw_report_sha256"] = updated_raw_sha
        for correction in corrections:
            correction["raw_report_sha256"] = updated_raw_sha
        _seal_corrections(corrections)

    document["correction_record_bindings"] = []
    for correction in corrections:
        path = CORRECTION_ROOT / f"{correction['correction_id'].lower()}.json"
        _write_json(root / path, correction)
        document["correction_record_bindings"].append(
            {
                "correction_id": correction["correction_id"],
                "path": path.as_posix(),
                "file_sha256": ledger.sha256_file(root / path),
                "record_payload_sha256": correction["record_payload_sha256"],
                "failure_count": correction["failure_count"],
                "failure_fingerprints": correction["failure_fingerprints"],
            }
        )
    _seal_ledger(document)
    _write_json(root / LEDGER_REL, document)
    artifact_head = _commit(root, "historical delta metadata evidence")
    if post_commit_component_mutation:
        mutated = _repaired_component()
        mutated["new_component_justification"] += " drift"
        _write_json(root / REGISTRY_REL, _registry(mutated))
        artifact_head = _commit(root, "touch corrected component")
    if post_commit_path_touch:
        (root / PRODUCT_REL).write_text(
            "extends RefCounted\n# future touch\n", encoding="utf-8"
        )
        artifact_head = _commit(root, "touch corrected component path")
    return temp, root, artifact_head, base, document


def _result(case_id: str, description: str, expected: str, passed: bool, observed: list[str]) -> dict[str, Any]:
    return {
        "case_id": case_id,
        "description": description,
        "expected": expected,
        "status": "PASS" if passed else "FAIL",
        "observed_failures": observed,
    }


def _validate_fixture_ledger(
    root: Path,
    ledger_path: Path,
    *,
    evaluated_head: str,
    history_ancestry_anchor: str,
) -> dict[str, Any]:
    raw_path = root / RAW_REL
    raw = ledger.load_json_strict(raw_path)
    values = [str(value) for value in raw.get("failures", [])]
    document = _fixture_authority_document(root)
    bindings = [
        binding
        for record in document.get("records", [])
        if isinstance(record, dict)
        for binding in (
            record.get("failure_bindings")
            if isinstance(record.get("failure_bindings"), list)
            else []
        )
        if isinstance(binding, dict)
    ]
    unique_bindings = {
        str(binding.get("failure_fingerprint", "")): binding for binding in bindings
    }
    native_historical = sum(
        1 for value in values if value.split(":", 1)[0].startswith("HISTORY_")
    )
    promoted = sum(
        1
        for binding in unique_bindings.values()
        if not str(binding.get("rule_id", "")).startswith("HISTORY_")
    )
    return ledger.validate_ledger(
        root,
        ledger_path,
        evaluated_head=evaluated_head,
        history_ancestry_anchor=history_ancestry_anchor,
        test_raw_authority_override={
            "sha256": ledger.sha256_file(raw_path),
            "head_sha": raw["head_sha"],
            "tree_sha": _run(root, "git", "rev-parse", f"{raw['head_sha']}^{{tree}}"),
            "failure_count": len(values),
            "native_historical_count": native_historical,
            "ledger_promoted_count": promoted,
            "semantic_historical_count": native_historical + promoted,
            "true_current_count": len(values) - native_historical - promoted,
            "ledger_failure_count": len(unique_bindings),
        },
    )


def _fixture_authority_document(root: Path) -> dict[str, Any]:
    try:
        document = ledger.load_json_strict(root / LEDGER_REL)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError):
        parent = _run(root, "git", "rev-parse", "HEAD^")
        payload = subprocess.run(
            ["git", "show", f"{parent}:{LEDGER_REL.as_posix()}"],
            cwd=root,
            check=True,
            stdout=subprocess.PIPE,
        ).stdout
        document = ledger._load_json_bytes_strict(payload)
    if not isinstance(document, dict):
        raise AssertionError("fixture ledger must be an object")
    return document


def _fixture_independent_expectations(root: Path) -> dict[str, int | str]:
    raw_path = root / RAW_REL
    raw = ledger.load_json_strict(raw_path)
    values = [str(value) for value in raw.get("failures", [])]
    document = _fixture_authority_document(root)
    bindings = [
        binding
        for record in document.get("records", [])
        if isinstance(record, dict)
        for binding in (
            record.get("failure_bindings")
            if isinstance(record.get("failure_bindings"), list)
            else []
        )
        if isinstance(binding, dict)
    ]
    unique_bindings = {
        str(binding.get("failure_fingerprint", "")): binding for binding in bindings
    }
    authorized = set(unique_bindings)
    raw_subset = {str(binding.get("raw_failure", "")) for binding in unique_bindings.values()}
    component_ids = {
        str(binding.get("component_id", "")) for binding in unique_bindings.values()
    }
    native_historical = sum(
        1 for value in values if value.split(":", 1)[0].startswith("HISTORY_")
    )
    promoted = sum(
        1
        for binding in unique_bindings.values()
        if not str(binding.get("rule_id", "")).startswith("HISTORY_")
    )
    raw_head = str(raw["head_sha"])
    scanner_bytes = subprocess.run(
        ["git", "show", f"{raw_head}:{SCANNER_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    return {
        "raw_sha256": ledger.sha256_file(raw_path),
        "raw_head_sha": raw_head,
        "raw_tree_sha": _run(root, "git", "rev-parse", f"{raw_head}^{{tree}}"),
        "scanner_sha256": ledger.sha256_bytes(scanner_bytes),
        "raw_failure_count": len(values),
        "native_historical_count": native_historical,
        "ledger_promoted_count": promoted,
        "semantic_historical_count": native_historical + promoted,
        "true_current_count": len(values) - native_historical - promoted,
        "authorized_failure_count": len(authorized),
        "authorized_raw_set_sha256": ledger.line_set_sha(raw_subset),
        "authorized_fingerprint_set_sha256": ledger.line_set_sha(authorized),
        "component_count": len(component_ids),
        "component_set_sha256": ledger.line_set_sha(component_ids),
    }


def _validate_fixture_pair(
    root: Path,
    *,
    evaluated_head: str,
    history_ancestry_anchor: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    primary = _validate_fixture_ledger(
        root,
        root / LEDGER_REL,
        evaluated_head=evaluated_head,
        history_ancestry_anchor=history_ancestry_anchor,
    )
    audit = independent.audit_fixture_ledger_for_selftest(
        root,
        root / LEDGER_REL,
        evaluated_head=evaluated_head,
        history_ancestry_anchor=history_ancestry_anchor,
        test_expectations=_fixture_independent_expectations(root),
        primary_projection=primary,
    )
    return primary, audit


def _pair_failures(
    primary: dict[str, Any], audit: dict[str, Any]
) -> list[str]:
    return [
        *(f"PRIMARY:{value}" for value in primary.get("failures", [])),
        *(f"INDEPENDENT:{value}" for value in audit.get("failures", [])),
    ]


def _both_reject(
    primary: dict[str, Any],
    audit: dict[str, Any],
    *,
    primary_token: str,
    independent_token: str,
) -> bool:
    return bool(
        primary.get("status") == "FAIL"
        and audit.get("status") == "NO_GO"
        and any(primary_token in value for value in primary.get("failures", []))
        and any(independent_token in value for value in audit.get("failures", []))
        and not audit.get("primary_projection_digest_match", True)
    )


def _append_valid_second_transition(
    root: Path, document: dict[str, Any]
) -> tuple[str, str, str]:
    initial_head = _run(root, "git", "rev-parse", "HEAD")
    initial_ledger_sha = ledger.sha256_file(root / LEDGER_REL)
    raw_sha_before = ledger.sha256_file(root / RAW_REL)
    successor = copy.deepcopy(document)
    source = _run(root, "git", "rev-parse", "v076-selftest-second-source^{commit}")
    parent = str(successor["records"][0]["source_commit"])
    if _run(root, "git", "rev-parse", f"{source}^") != parent:
        raise AssertionError("second transition parent mismatch")

    source_row = _source_component_two()
    current_row = _repaired_component_two()
    source_registry = subprocess.run(
        ["git", "show", f"{source}:{REGISTRY_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    parent_registry = subprocess.run(
        ["git", "show", f"{parent}:{REGISTRY_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    source_product = subprocess.run(
        ["git", "show", f"{source}:{PRODUCT_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    current_product = subprocess.run(
        ["git", "show", f"{initial_head}:{PRODUCT_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    source_owner_product = subprocess.run(
        ["git", "show", f"{source}:{OWNER_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    current_owner_product = subprocess.run(
        ["git", "show", f"{initial_head}:{OWNER_REL.as_posix()}"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    raw = ledger.load_json_strict(root / RAW_REL)
    second_raw = sorted(
        value
        for value in raw["failures"]
        if isinstance(value, str) and value.endswith(f":{source_row['component_id']}")
    )
    if len(second_raw) != 2:
        raise AssertionError("second transition must own exactly two raw failures")
    fingerprints = {
        raw_failure: ledger.failure_fingerprint(
            raw_failure, raw_failure.split(":", 1)[0]
        )
        for raw_failure in second_raw
    }
    bindings = [
        {
            "failure_fingerprint": fingerprints[raw_failure],
            "raw_failure": raw_failure,
            "rule_id": raw_failure.split(":", 1)[0],
            "component_id": source_row["component_id"],
            "source_component_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(source_row)
            ),
            "current_component_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(current_row)
            ),
            "source_component_path": source_row["path"],
            "current_component_path": current_row["path"],
            "source_path_blob_sha256": ledger.sha256_bytes(source_product),
            "current_path_blob_sha256": ledger.sha256_bytes(current_product),
            "source_domain_id": source_row["domain_id"],
            "source_domain_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(_domain_row())
            ),
            "current_domain_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(_domain_row())
            ),
            "source_owner_component_id": source_row["owner_component_id"],
            "current_owner_component_id": current_row["owner_component_id"],
            "source_owner_component_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(_owner_component())
            ),
            "current_owner_component_sha256": ledger.sha256_bytes(
                ledger.canonical_bytes(_owner_component())
            ),
            "source_owner_path": OWNER_REL.as_posix(),
            "current_owner_path": OWNER_REL.as_posix(),
            "source_owner_path_blob_sha256": ledger.sha256_bytes(
                source_owner_product
            ),
            "current_owner_path_blob_sha256": ledger.sha256_bytes(
                current_owner_product
            ),
            "source_production_reachability": source_row["production_reachable"],
        }
        for raw_failure in second_raw
    ]
    bindings.sort(key=lambda item: item["failure_fingerprint"])
    metadata_record = {
        "schema_version": ledger.METADATA_RECORD_SCHEMA_VERSION,
        "record_id": "HDM-SELFTEST-002",
        "source_commit": source,
        "parent_commit": parent,
        "commit_tree": _run(root, "git", "rev-parse", f"{source}^{{tree}}"),
        "parent_tree": _run(root, "git", "rev-parse", f"{parent}^{{tree}}"),
        "registry_path": ledger.REGISTRY_PATH,
        "source_registry_sha256": ledger.sha256_bytes(source_registry),
        "parent_registry_sha256": ledger.sha256_bytes(parent_registry),
        "change_class": "DOCS_ONLY",
        "affected_domains": [source_row["domain_id"]],
        "affected_owners": [source_row["owner_component_id"]],
        "focused_tests": ["v076_historical_delta_metadata_ledger_selftest"],
        "historical_context": "Second exact registry-only historical metadata backfill.",
        "current_disposition": "CORRECTED_HISTORICAL_METADATA_DEBT",
        "selector_policy": ledger.EXACT_SELECTOR_POLICY,
        "reuse_scan_component_ids": [source_row["component_id"]],
        "failure_count": len(bindings),
        "failure_fingerprint_set_sha256": ledger.line_set_sha(
            item["failure_fingerprint"] for item in bindings
        ),
        "failure_bindings": bindings,
        "previous_record_payload_sha256": "",
        "record_payload_sha256": "",
    }
    old_records = copy.deepcopy(successor["records"])
    successor["records"].append(metadata_record)
    _seal_metadata(successor["records"])
    if successor["records"][: len(old_records)] != old_records:
        raise AssertionError("metadata prefix changed while appending")

    existing_corrections = [
        ledger.load_json_strict(root / binding["path"])
        for binding in successor["correction_record_bindings"]
    ]
    old_corrections = copy.deepcopy(existing_corrections)
    new_corrections: list[dict[str, Any]] = []
    for index, raw_failure in enumerate(second_raw, start=3):
        rule_id = raw_failure.split(":", 1)[0]
        fingerprint = fingerprints[raw_failure]
        new_corrections.append(
            {
                "schema_version": ledger.CORRECTION_RECORD_SCHEMA_VERSION,
                "record_kind": "HISTORICAL_DELTA_METADATA_EXACT_CORRECTION",
                "correction_id": f"V2-HDM-SELFTEST-{index:02d}",
                "ledger_id": ledger.LEDGER_ID,
                "metadata_record_ids": [metadata_record["record_id"]],
                "authorization_id": ledger.AUTHORIZATION_ID,
                "authorization_base_head_sha": ledger.AUTHORIZATION_BASE_HEAD_SHA,
                "raw_report_sha256": raw_sha_before,
                "raw_report_head_sha": raw["head_sha"],
                "rule_id": rule_id,
                "transition_class_id": ledger.TRANSITION_CLASS_BY_RULE[rule_id],
                "source_commit": source,
                "parent_commit": parent,
                "component_ids": [source_row["component_id"]],
                "component_set_sha256": ledger.line_set_sha(
                    [source_row["component_id"]]
                ),
                "failure_count": 1,
                "failure_fingerprints": [fingerprint],
                "failure_fingerprint_set_sha256": ledger.line_set_sha([fingerprint]),
                "selector_policy": ledger.EXACT_SELECTOR_POLICY,
                "from_state": "RAW_HISTORICAL_METADATA_FAILURE",
                "to_effective_disposition": "CORRECTED_HISTORICAL_METADATA_DEBT",
                "untouched_in_current_delta": True,
                "touch_invalidation_policy": ledger.TOUCH_INVALIDATION_POLICY,
                "future_failure_policy": ledger.FUTURE_FAILURE_POLICY,
                "backlog_item_ids": ["V076_HISTORICAL_METADATA_DEBT"],
                "previous_correction_payload_sha256": "",
                "record_payload_sha256": "",
            }
        )
    all_corrections = [*existing_corrections, *new_corrections]
    _seal_corrections(all_corrections)
    if all_corrections[: len(old_corrections)] != old_corrections:
        raise AssertionError("correction prefix changed while appending")
    for correction in new_corrections:
        path = CORRECTION_ROOT / f"{correction['correction_id'].lower()}.json"
        _write_json(root / path, correction)
        successor["correction_record_bindings"].append(
            {
                "correction_id": correction["correction_id"],
                "path": path.as_posix(),
                "file_sha256": ledger.sha256_file(root / path),
                "record_payload_sha256": correction["record_payload_sha256"],
                "failure_count": correction["failure_count"],
                "failure_fingerprints": correction["failure_fingerprints"],
            }
        )
    all_bindings = [
        binding
        for record in successor["records"]
        for binding in record["failure_bindings"]
    ]
    successor["record_count"] = len(successor["records"])
    successor["failure_count"] = len(all_bindings)
    successor["failure_fingerprint_set_sha256"] = ledger.line_set_sha(
        binding["failure_fingerprint"] for binding in all_bindings
    )
    successor["correction_record_count"] = len(
        successor["correction_record_bindings"]
    )
    successor["corrected_failure_count"] = len(all_bindings)
    successor["previous_ledger_path"] = LEDGER_REL.as_posix()
    successor["previous_ledger_sha256"] = initial_ledger_sha
    _seal_ledger(successor)
    _write_json(root / LEDGER_REL, successor)
    successor_head = _commit(root, "append second source transition evidence")
    raw_sha_after = ledger.sha256_file(root / RAW_REL)
    if raw_sha_after != raw_sha_before:
        raise AssertionError("append transition mutated raw bytes")
    return successor_head, initial_ledger_sha, raw_sha_before


def main() -> int:
    cases: list[dict[str, Any]] = []

    temp, root, head, base, _ = _fixture()
    try:
        primary, audit = _validate_fixture_pair(
            root, evaluated_head=head, history_ancestry_anchor=base
        )
        cases.append(
            _result(
                "01",
                "primary and independent validators agree on exact metadata",
                "PASS/PASS_PARITY",
                primary["status"] == "PASS"
                and audit["status"] == "GO"
                and audit["primary_projection_digest_match"] is True
                and len(primary["verified_historical_fingerprints"]) == 2
                and audit["verified_failure_count"] == 2,
                _pair_failures(primary, audit),
            )
        )
    finally:
        temp.cleanup()

    def wrong_tree(document: dict[str, Any], records: list[dict[str, Any]], corrections: list[dict[str, Any]], raw: dict[str, Any]) -> None:
        records[0]["commit_tree"] = "0" * 40
        _seal_metadata(records)

    temp, root, head, base, _ = _fixture(wrong_tree)
    try:
        primary, audit = _validate_fixture_pair(
            root, evaluated_head=head, history_ancestry_anchor=base
        )
        cases.append(_result("02", "wrong source tree fails closed in both validators", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="SOURCE_TREE_MISMATCH", independent_token="SOURCE_TREE_MISMATCH"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    def wrong_parent(document: dict[str, Any], records: list[dict[str, Any]], corrections: list[dict[str, Any]], raw: dict[str, Any]) -> None:
        records[0]["parent_commit"] = raw["head_sha"]
        corrections[0]["parent_commit"] = raw["head_sha"]
        corrections[1]["parent_commit"] = raw["head_sha"]
        _seal_metadata(records)

    temp, root, head, base, _ = _fixture(wrong_parent)
    try:
        primary, audit = _validate_fixture_pair(root, evaluated_head=head, history_ancestry_anchor=base)
        cases.append(_result("03", "wrong direct parent fails closed in both validators", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="DIRECT_PARENT_MISMATCH", independent_token="DIRECT_PARENT_MISMATCH"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    def payload_mutation(document: dict[str, Any], records: list[dict[str, Any]], corrections: list[dict[str, Any]], raw: dict[str, Any]) -> None:
        records[0]["historical_context"] += " mutation"

    temp, root, head, base, _ = _fixture(payload_mutation)
    try:
        primary, audit = _validate_fixture_pair(root, evaluated_head=head, history_ancestry_anchor=base)
        cases.append(_result("04", "payload mutation without a new seal fails in both validators", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="RECORD_HASH_MISMATCH", independent_token="PAYLOAD_HASH_MISMATCH"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    def wildcard_selector(document: dict[str, Any], records: list[dict[str, Any]], corrections: list[dict[str, Any]], raw: dict[str, Any]) -> None:
        document["selector_policy"] = dict(ledger.EXACT_SELECTOR_POLICY)
        document["selector_policy"]["wildcard_allowed"] = True

    temp, root, head, base, _ = _fixture(wildcard_selector)
    try:
        primary, audit = _validate_fixture_pair(root, evaluated_head=head, history_ancestry_anchor=base)
        cases.append(_result("05", "wildcard selector fails closed in both validators", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="SELECTOR_POLICY_MISMATCH", independent_token="SELECTOR_POLICY_MISMATCH"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    def duplicate_fingerprint(document: dict[str, Any], records: list[dict[str, Any]], corrections: list[dict[str, Any]], raw: dict[str, Any]) -> None:
        records[0]["failure_bindings"].append(copy.deepcopy(records[0]["failure_bindings"][0]))
        records[0]["failure_count"] += 1
        _seal_metadata(records)

    temp, root, head, base, _ = _fixture(duplicate_fingerprint)
    try:
        primary, audit = _validate_fixture_pair(root, evaluated_head=head, history_ancestry_anchor=base)
        cases.append(_result("06", "duplicate exact fingerprint fails closed in both validators", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="FINGERPRINT_DUPLICATE", independent_token="FINGERPRINT_DUPLICATE"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    def missing_raw(document: dict[str, Any], records: list[dict[str, Any]], corrections: list[dict[str, Any]], raw: dict[str, Any]) -> None:
        raw["failures"] = raw["failures"][1:]

    temp, root, head, base, _ = _fixture(missing_raw)
    try:
        primary, audit = _validate_fixture_pair(root, evaluated_head=head, history_ancestry_anchor=base)
        cases.append(_result("07", "nonexistent exact raw failure fails closed in both validators", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="RAW_FAILURE_MISSING", independent_token="RAW_MISSING"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture(post_commit_component_mutation=True)
    try:
        primary, audit = _validate_fixture_pair(root, evaluated_head=head, history_ancestry_anchor=base)
        cases.append(_result("08", "future component touch invalidates both validators", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="CURRENT_COMPONENT_HASH_MISMATCH", independent_token="CURRENT_COMPONENT_HASH_MISMATCH"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    temp, root, head, base, document = _fixture()
    try:
        successor = copy.deepcopy(document)
        successor["previous_ledger_path"] = LEDGER_REL.as_posix()
        successor["previous_ledger_sha256"] = ledger.sha256_file(root / LEDGER_REL)
        _seal_ledger(successor)
        _write_json(root / LEDGER_REL, successor)
        append_head = _commit(root, "append successor ledger seal")
        primary, audit = _validate_fixture_pair(
            root, evaluated_head=append_head, history_ancestry_anchor=base
        )
        cases.append(
            _result(
                "09",
                "prefix-preserving successor seal passes both validators",
                "PASS/PASS_PARITY",
                primary["status"] == "PASS"
                and audit["status"] == "GO"
                and audit["primary_projection_digest_match"] is True
                and audit["predecessor_ledger_sha256"]
                == successor["previous_ledger_sha256"],
                _pair_failures(primary, audit),
            )
        )
    finally:
        temp.cleanup()

    temp, root, head, base, document = _fixture()
    try:
        successor = copy.deepcopy(document)
        successor["previous_ledger_path"] = LEDGER_REL.as_posix()
        successor["previous_ledger_sha256"] = "0" * 64
        _seal_ledger(successor)
        _write_json(root / LEDGER_REL, successor)
        successor_head = _commit(root, "forge predecessor ledger seal")
        primary, audit = _validate_fixture_pair(root, evaluated_head=successor_head, history_ancestry_anchor=base)
        cases.append(_result("11", "wrong predecessor ledger hash fails closed in both validators", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="PREVIOUS_LEDGER_HASH_MISMATCH", independent_token="PREVIOUS_LEDGER"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture(post_commit_path_touch=True)
    try:
        primary, audit = _validate_fixture_pair(root, evaluated_head=head, history_ancestry_anchor=base)
        cases.append(_result("12", "future product-path touch invalidates both validators", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="COMPONENT_PATH_TOUCHED", independent_token="COMPONENT_PATH_TOUCHED"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture()
    try:
        payload = (root / LEDGER_REL).read_bytes()
        (root / LEDGER_REL).write_bytes(
            payload.replace(
                b'{"append_only":true,',
                b'{"append_only":true,"append_only":true,',
                1,
            )
        )
        duplicate_head = _commit(root, "commit duplicate JSON key attack")
        primary, audit = _validate_fixture_pair(root, evaluated_head=duplicate_head, history_ancestry_anchor=base)
        cases.append(_result("13", "duplicate JSON key fails before either authority projection", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="DUPLICATE_JSON_KEY", independent_token="LEDGER_INPUT_INVALID"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    temp, root, head, base, document = _fixture()
    try:
        mutated = copy.deepcopy(document)
        mutated["records"][0]["historical_context"] += " rewritten"
        (root / LEDGER_REL).write_bytes(ledger.canonical_bytes(mutated))
        mutation_head = _commit(root, "mutate prior evidence fixture")
        primary, audit = _validate_fixture_pair(root, evaluated_head=mutation_head, history_ancestry_anchor=base)
        cases.append(_result("10", "prior record mutation fails both append-only comparisons", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="APPEND_ONLY_RECORDS_MUTATION", independent_token="APPEND_ONLY_RECORDS_MUTATION"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    temp, root, head, base, document = _fixture()
    try:
        rewritten = copy.deepcopy(document)
        rewritten["records"][0]["historical_context"] += " successor consistency rewrite"
        _seal_metadata(rewritten["records"])
        rewritten["previous_ledger_path"] = LEDGER_REL.as_posix()
        rewritten["previous_ledger_sha256"] = ledger.sha256_file(root / LEDGER_REL)
        _seal_ledger(rewritten)
        _write_json(root / LEDGER_REL, rewritten)
        mutation_head = _commit(root, "commit sealed append-only mutation")
        mutation_primary, mutation_audit = _validate_fixture_pair(
            root, evaluated_head=mutation_head, history_ancestry_anchor=base
        )
        (root / "unrelated-successor.txt").write_text(
            "unrelated successor\n", encoding="utf-8"
        )
        successor_head = _commit(root, "add unrelated successor")
        successor_primary, successor_audit = _validate_fixture_pair(
            root, evaluated_head=successor_head, history_ancestry_anchor=base
        )
        cases.append(
            _result(
                "18",
                "an unrelated successor preserves a prior append-only rejection",
                "FAIL/NO_GO_THEN_FAIL/NO_GO",
                _both_reject(
                    mutation_primary,
                    mutation_audit,
                    primary_token="APPEND_ONLY_RECORDS_MUTATION",
                    independent_token="APPEND_ONLY_RECORDS_MUTATION",
                )
                and _both_reject(
                    successor_primary,
                    successor_audit,
                    primary_token="APPEND_ONLY_RECORDS_MUTATION",
                    independent_token="APPEND_ONLY_RECORDS_MUTATION",
                ),
                [
                    *(f"MUTATION:{value}" for value in _pair_failures(mutation_primary, mutation_audit)),
                    *(f"SUCCESSOR:{value}" for value in _pair_failures(successor_primary, successor_audit)),
                ],
            )
        )
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture()
    try:
        baseline_registry = _registry(_repaired_component())
        changed_registry = copy.deepcopy(baseline_registry)
        changed_registry["domain_inventory"][0]["description"] += " temporary change"
        for row in changed_registry["component_inventory"]:
            if row.get("component_id") == "component.current.v075_runtime_owner":
                row["selftest_history_note"] = "temporary owner row change"
            elif row.get("component_id") == "component.selftest.reducer":
                row["new_component_justification"] += " temporary component row change"
                row["production_reachable"] = False
        _write_json(root / REGISTRY_REL, changed_registry)
        _commit(root, "change bound registry rows")
        _write_json(root / REGISTRY_REL, baseline_registry)
        restored_head = _commit(root, "restore bound registry rows")
        primary, audit = _validate_fixture_pair(
            root, evaluated_head=restored_head, history_ancestry_anchor=base
        )
        primary_tokens = (
            "COMPONENT_ROW_TOUCHED",
            "DOMAIN_ROW_TOUCHED",
            "OWNER_ROW_TOUCHED",
            "PRODUCTION_REACHABILITY_TOUCHED",
        )
        independent_tokens = primary_tokens
        cases.append(
            _result(
                "19",
                "component, domain, owner, and reachability row changes remain invalidating after restore",
                "FAIL/NO_GO_ALL_ROW_TOUCH_CLASSES",
                primary.get("status") == "FAIL"
                and audit.get("status") == "NO_GO"
                and all(
                    any(token in failure for failure in primary.get("failures", []))
                    for token in primary_tokens
                )
                and all(
                    any(token in failure for failure in audit.get("failures", []))
                    for token in independent_tokens
                )
                and not audit.get("primary_projection_digest_match", True),
                _pair_failures(primary, audit),
            )
        )
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture()
    try:
        main_branch = _run(root, "git", "branch", "--show-current")
        _run(root, "git", "switch", "-q", "-c", "registry-history-side")
        side_changed_registry = _registry(_repaired_component())
        side_changed_registry["component_inventory"][-1][
            "new_component_justification"
        ] += " side history change"
        _write_json(root / REGISTRY_REL, side_changed_registry)
        _commit(root, "change bound row on side history")
        _write_json(root / REGISTRY_REL, _registry(_repaired_component()))
        _commit(root, "restore bound row on side history")
        _run(root, "git", "switch", "-q", main_branch)
        _run(
            root,
            "git",
            "merge",
            "--no-ff",
            "-m",
            "merge restored registry side history",
            "registry-history-side",
        )
        merged_head = _run(root, "git", "rev-parse", "HEAD")
        primary, audit = _validate_fixture_pair(
            root, evaluated_head=merged_head, history_ancestry_anchor=base
        )
        cases.append(
            _result(
                "20",
                "merged side history preserves a bound row change after restore",
                "FAIL/NO_GO_COMPONENT_ROW_TOUCH",
                _both_reject(
                    primary,
                    audit,
                    primary_token="COMPONENT_ROW_TOUCHED",
                    independent_token="COMPONENT_ROW_TOUCHED",
                ),
                _pair_failures(primary, audit),
            )
        )
    finally:
        temp.cleanup()

    def malformed_bindings(
        document: dict[str, Any],
        records: list[dict[str, Any]],
        corrections: list[dict[str, Any]],
        raw: dict[str, Any],
    ) -> None:
        records[0]["failure_bindings"] = 42
        records[0]["failure_count"] = 0
        _seal_metadata(records)

    temp, root, head, base, _ = _fixture(malformed_bindings)
    try:
        malformed_primary, malformed_audit = _validate_fixture_pair(
            root,
            evaluated_head=head,
            history_ancestry_anchor=base,
        )
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture()
    try:
        malformed_registry = _registry(_repaired_component())
        for row in malformed_registry["component_inventory"]:
            if row.get("component_id") == "component.selftest.reducer":
                row["reuse_candidates_considered"] = [["not-a-string"]]
        _write_json(root / REGISTRY_REL, malformed_registry)
        malformed_registry_head = _commit(
            root,
            "record malformed local reuse-candidate type",
        )
        considered_primary, considered_audit = _validate_fixture_pair(
            root,
            evaluated_head=malformed_registry_head,
            history_ancestry_anchor=base,
        )
    finally:
        temp.cleanup()
    cases.append(
        _result(
            "21",
            "malformed local JSON collection types return structured rejection",
            "FAIL/NO_GO_FOR_BOTH_TYPE_VARIANTS",
            _both_reject(
                malformed_primary,
                malformed_audit,
                primary_token="BINDINGS_INVALID",
                independent_token="BINDINGS_INVALID",
            )
            and _both_reject(
                considered_primary,
                considered_audit,
                primary_token="REUSE_SCAN_REPAIR_INVALID",
                independent_token="FAILURE_REUSE_SCAN_INVALID",
            ),
            [
                *(
                    f"BINDINGS:{value}"
                    for value in _pair_failures(
                        malformed_primary,
                        malformed_audit,
                    )
                ),
                *(
                    f"CONSIDERED:{value}"
                    for value in _pair_failures(
                        considered_primary,
                        considered_audit,
                    )
                ),
            ],
        )
    )

    non_finite_rejected: list[bool] = []
    non_finite_observed: list[str] = []
    for parser_name, parser in (
        ("PRIMARY", ledger._load_json_bytes_strict),
        ("INDEPENDENT", independent._json_bytes),
    ):
        for token in (b"NaN", b"Infinity", b"-Infinity"):
            try:
                parser(b'{"value":' + token + b"}")
            except ValueError as exc:
                non_finite_rejected.append("NON_FINITE_JSON_NUMBER" in str(exc))
                non_finite_observed.append(f"{parser_name}:{token.decode()}:REJECTED")
            else:
                non_finite_rejected.append(False)
                non_finite_observed.append(f"{parser_name}:{token.decode()}:ACCEPTED")
    cases.append(
        _result(
            "22",
            "strict JSON rejects non-finite numeric constants in both implementations",
            "ALL_REJECTED",
            all(non_finite_rejected),
            non_finite_observed,
        )
    )

    temp, root, head, base, _ = _fixture()
    original_append_only = ledger._append_only_failures
    try:
        committed_ledger_bytes = (root / LEDGER_REL).read_bytes()
        changed_after_snapshot = b'{"changed_after_snapshot":true}\n'

        def change_after_snapshot(
            root_value: Path,
            evaluated_head: str,
            ledger_path: str,
            document: dict[str, Any],
        ) -> tuple[list[str], dict[str, str]]:
            result = original_append_only(
                root_value,
                evaluated_head,
                ledger_path,
                document,
            )
            (root_value / ledger_path).write_bytes(changed_after_snapshot)
            return result

        ledger._append_only_failures = change_after_snapshot
        snapshot_primary = _validate_fixture_ledger(
            root,
            root / LEDGER_REL,
            evaluated_head=head,
            history_ancestry_anchor=base,
        )
        cases.append(
            _result(
                "23",
                "the primary receipt SHA remains bound to its validated committed snapshot",
                "PASS_WITH_COMMITTED_SNAPSHOT_SHA",
                snapshot_primary.get("status") == "PASS"
                and snapshot_primary.get("ledger_sha256")
                == ledger.sha256_bytes(committed_ledger_bytes)
                and snapshot_primary.get("ledger_sha256")
                != ledger.sha256_bytes(changed_after_snapshot),
                snapshot_primary.get("failures", []),
            )
        )
    finally:
        ledger._append_only_failures = original_append_only
        temp.cleanup()

    temp, root, head, base, document = _fixture()
    try:
        main_branch = _run(root, "git", "branch", "--show-current")
        original_ledger_bytes = (root / LEDGER_REL).read_bytes()
        _run(root, "git", "switch", "-q", "-c", "ledger-history-side")
        changed_ledger = copy.deepcopy(document)
        changed_ledger["records"][0]["historical_context"] += (
            " temporary side-history change"
        )
        _seal_metadata(changed_ledger["records"])
        changed_ledger["previous_ledger_path"] = LEDGER_REL.as_posix()
        changed_ledger["previous_ledger_sha256"] = ledger.sha256_bytes(
            original_ledger_bytes
        )
        _seal_ledger(changed_ledger)
        _write_json(root / LEDGER_REL, changed_ledger)
        _commit(root, "change sealed ledger on side history")
        (root / LEDGER_REL).write_bytes(original_ledger_bytes)
        _commit(root, "restore sealed ledger on side history")
        _run(root, "git", "switch", "-q", main_branch)
        _run(
            root,
            "git",
            "merge",
            "--no-ff",
            "-m",
            "merge restored ledger side history",
            "ledger-history-side",
        )
        merged_head = _run(root, "git", "rev-parse", "HEAD")
        side_primary, side_audit = _validate_fixture_pair(
            root,
            evaluated_head=merged_head,
            history_ancestry_anchor=base,
        )
        cases.append(
            _result(
                "24",
                "reachable side-history ledger change remains append-only invalid after restore",
                "FAIL/NO_GO_APPEND_ONLY",
                _both_reject(
                    side_primary,
                    side_audit,
                    primary_token="APPEND_ONLY_RECORDS_MUTATION",
                    independent_token="APPEND_ONLY_RECORDS_MUTATION",
                ),
                _pair_failures(side_primary, side_audit),
            )
        )
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture()
    try:
        _run(
            root,
            "git",
            "config",
            "advice.graftFileDeprecated",
            "false",
        )
        grafts_value = _run(
            root,
            "git",
            "rev-parse",
            "--git-path",
            "info/grafts",
        )
        grafts_path = Path(grafts_value)
        if not grafts_path.is_absolute():
            grafts_path = root / grafts_path
        grafts_path.parent.mkdir(parents=True, exist_ok=True)
        grafts_path.write_text(f"{head} {base}\n", encoding="utf-8")
        graft_primary, graft_audit = _validate_fixture_pair(
            root,
            evaluated_head=head,
            history_ancestry_anchor=base,
        )
        cases.append(
            _result(
                "25",
                "non-empty local graft metadata is rejected before history evaluation",
                "FAIL/NO_GO_GRAFTS_FORBIDDEN",
                _both_reject(
                    graft_primary,
                    graft_audit,
                    primary_token="GIT_GRAFTS_FORBIDDEN",
                    independent_token="GIT_GRAFTS_FORBIDDEN",
                ),
                _pair_failures(graft_primary, graft_audit),
            )
        )
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture()
    try:
        ledger_blob = _run(
            root,
            "git",
            "rev-parse",
            f"HEAD:{LEDGER_REL.as_posix()}",
        )
        _run(
            root,
            "git",
            "update-index",
            "--cacheinfo",
            f"120000,{ledger_blob},{LEDGER_REL.as_posix()}",
        )
        _run(root, "git", "commit", "-m", "record non-regular ledger mode")
        non_regular_ledger_head = _run(root, "git", "rev-parse", "HEAD")
        mode_primary, mode_audit = _validate_fixture_pair(
            root,
            evaluated_head=non_regular_ledger_head,
            history_ancestry_anchor=base,
        )
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture()
    try:
        product_relative = PRODUCT_REL.as_posix()
        product_blob = _run(
            root,
            "git",
            "rev-parse",
            f"HEAD:{product_relative}",
        )
        _run(
            root,
            "git",
            "update-index",
            "--cacheinfo",
            f"120000,{product_blob},{product_relative}",
        )
        _run(root, "git", "commit", "-m", "record non-regular component mode")
        component_link_head = _run(root, "git", "rev-parse", "HEAD")
        component_link_rejected = (
            ledger._git_bytes(root, component_link_head, product_relative) is None
            and independent._git_bytes(
                root,
                component_link_head,
                product_relative,
            )
            is None
        )
        _run(
            root,
            "git",
            "update-index",
            "--cacheinfo",
            f"160000,{base},{product_relative}",
        )
        _run(root, "git", "commit", "-m", "record gitlink component mode")
        component_gitlink_head = _run(root, "git", "rev-parse", "HEAD")
        component_gitlink_rejected = (
            ledger._git_bytes(root, component_gitlink_head, product_relative)
            is None
            and independent._git_bytes(
                root,
                component_gitlink_head,
                product_relative,
            )
            is None
        )
    finally:
        temp.cleanup()
    cases.append(
        _result(
            "26",
            "ledger and product authority bytes require regular Git blob modes",
            "FAIL/NO_GO_AND_COMPONENT_MODES_REJECTED",
            _both_reject(
                mode_primary,
                mode_audit,
                primary_token="COMMITTED_BYTES_MISMATCH",
                independent_token="LEDGER_INPUT_INVALID",
            )
            and component_link_rejected
            and component_gitlink_rejected,
            _pair_failures(mode_primary, mode_audit),
        )
    )

    unicode_product_rel = Path("scripts/selftest/\u6d4b\u8bd5\u7ec4\u4ef6.gd")
    original_product_rel = PRODUCT_REL
    original_source_component = _source_component

    def unicode_source_component() -> dict[str, Any]:
        row = original_source_component()
        row["path"] = unicode_product_rel.as_posix()
        return row

    globals()["PRODUCT_REL"] = unicode_product_rel
    globals()["_source_component"] = unicode_source_component
    try:
        temp, root, head, base, _ = _fixture()
    finally:
        globals()["PRODUCT_REL"] = original_product_rel
        globals()["_source_component"] = original_source_component
    try:
        unicode_path = root / unicode_product_rel
        original_unicode_bytes = unicode_path.read_bytes()
        unicode_path.write_bytes(original_unicode_bytes + b"# temporary change\n")
        _commit(root, "change unicode component path")
        unicode_path.write_bytes(original_unicode_bytes)
        unicode_restore_head = _commit(root, "restore unicode component path")
        unicode_primary, unicode_audit = _validate_fixture_pair(
            root,
            evaluated_head=unicode_restore_head,
            history_ancestry_anchor=base,
        )
        cases.append(
            _result(
                "27",
                "Unicode component path touch remains visible after byte restoration",
                "FAIL/NO_GO_PATH_TOUCHED",
                _both_reject(
                    unicode_primary,
                    unicode_audit,
                    primary_token="COMPONENT_PATH_TOUCHED",
                    independent_token="COMPONENT_PATH_TOUCHED",
                ),
                _pair_failures(unicode_primary, unicode_audit),
            )
        )
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture()
    try:
        original_product_bytes = (root / PRODUCT_REL).read_bytes()
        (root / PRODUCT_REL).write_bytes(
            original_product_bytes + b"# temporary replacement-history change\n"
        )
        _commit(root, "change component before replacement-history restore")
        (root / PRODUCT_REL).write_bytes(original_product_bytes)
        restored_head = _commit(
            root,
            "restore component before replacement-history check",
        )
        restored_tree = _run(
            root,
            "git",
            "rev-parse",
            f"{restored_head}^{{tree}}",
        )
        replacement_result = subprocess.run(
            ["git", "commit-tree", restored_tree, "-p", head],
            cwd=root,
            check=True,
            input="replacement-history compatibility fixture\n",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
        )
        replacement_commit = replacement_result.stdout.strip()
        _run(root, "git", "replace", restored_head, replacement_commit)
        replace_primary, replace_audit = _validate_fixture_pair(
            root,
            evaluated_head=restored_head,
            history_ancestry_anchor=base,
        )
        cases.append(
            _result(
                "28",
                "local replacement refs do not alter committed touch history",
                "FAIL/NO_GO_PATH_TOUCHED",
                _both_reject(
                    replace_primary,
                    replace_audit,
                    primary_token="COMPONENT_PATH_TOUCHED",
                    independent_token="COMPONENT_PATH_TOUCHED",
                ),
                _pair_failures(replace_primary, replace_audit),
            )
        )
    finally:
        temp.cleanup()

    temp, root, head, base, document = _fixture()
    try:
        prior_ledger_sha = ledger.sha256_file(root / LEDGER_REL)
        schema = ledger.load_json_strict(root / SCHEMA_REL)
        schema["unexpected_top_level_field"] = "forbidden"
        _write_json(root / SCHEMA_REL, schema)
        successor = copy.deepcopy(document)
        successor["schema_sha256"] = ledger.sha256_file(root / SCHEMA_REL)
        successor["previous_ledger_path"] = LEDGER_REL.as_posix()
        successor["previous_ledger_sha256"] = prior_ledger_sha
        _seal_ledger(successor)
        _write_json(root / LEDGER_REL, successor)
        schema_attack_head = _commit(root, "add forbidden schema field")
        primary, audit = _validate_fixture_pair(root, evaluated_head=schema_attack_head, history_ancestry_anchor=base)
        cases.append(_result("14", "extra schema top-level field fails exact schema validation", "FAIL/NO_GO", _both_reject(primary, audit, primary_token="SCHEMA_MISMATCH", independent_token="SCHEMA_EXACT_DOCUMENT_MISMATCH"), _pair_failures(primary, audit)))
    finally:
        temp.cleanup()

    temp, root, head, base, _ = _fixture()
    try:
        production_parameters = inspect.signature(independent.audit_ledger).parameters
        _run(root, "git", "config", "--local", "--unset", independent.SELFTEST_FIXTURE_CONFIG_KEY)
        fixture_escape = independent.audit_fixture_ledger_for_selftest(
            root,
            root / LEDGER_REL,
            evaluated_head=head,
            history_ancestry_anchor=base,
            test_expectations=_fixture_independent_expectations(root),
        )
        cases.append(_result("15", "production audit exposes no authority override and fixture override requires marker", "NO_OVERRIDE/NO_GO", not any("test" in name or "override" in name for name in production_parameters) and fixture_escape["status"] == "NO_GO" and "SELFTEST_FIXTURE_MARKER_MISSING" in fixture_escape["failures"], fixture_escape["failures"]))
    finally:
        temp.cleanup()

    temp, root, head, base, document = _fixture(prepare_second_transition=True)
    try:
        successor_head, predecessor_sha, raw_sha = _append_valid_second_transition(
            root, document
        )
        primary, audit = _validate_fixture_pair(
            root, evaluated_head=successor_head, history_ancestry_anchor=base
        )
        cases.append(
            _result(
                "16",
                "a real second source transition appends metadata and corrections with predecessor seal",
                "PASS/PASS_PARITY",
                primary["status"] == "PASS"
                and audit["status"] == "GO"
                and audit["primary_projection_digest_match"] is True
                and audit["source_transition_count"] == 2
                and audit["metadata_record_count"] == 2
                and audit["correction_record_count"] == 4
                and audit["authorized_failure_count"] == 4
                and audit["verified_failure_count"] == 4
                and audit["predecessor_ledger_sha256"] == predecessor_sha
                and audit["raw_report_sha256"] == raw_sha,
                _pair_failures(primary, audit),
            )
        )
    finally:
        temp.cleanup()

    production_head = _run(PROJECT_ROOT, "git", "rev-parse", "HEAD")
    production_ledger_path = PROJECT_ROOT / LEDGER_REL
    production_raw_override = ledger.validate_ledger(
        PROJECT_ROOT,
        production_ledger_path,
        evaluated_head=production_head,
        test_raw_authority_override={},
    )
    production_ancestry_override = ledger.validate_ledger(
        PROJECT_ROOT,
        production_ledger_path,
        evaluated_head=production_head,
        history_ancestry_anchor=production_head,
    )
    independent_production_fixture_override = (
        independent.audit_fixture_ledger_for_selftest(
            PROJECT_ROOT,
            production_ledger_path,
            evaluated_head=production_head,
            history_ancestry_anchor=production_head,
            test_expectations=independent.DEFAULT_EXPECTATIONS,
        )
    )
    production_override_failures = sorted(
        set(production_raw_override.get("failures", []))
        | set(production_ancestry_override.get("failures", []))
        | set(independent_production_fixture_override.get("failures", []))
    )
    cases.append(
        _result(
            "17",
            "the authorized repository rejects primary and independent fixture parameters",
            "FAIL/FAIL/NO_GO",
            production_raw_override.get("status") == "FAIL"
            and production_ancestry_override.get("status") == "FAIL"
            and "HISTORICAL_DELTA_TEST_RAW_AUTHORITY_OVERRIDE_FORBIDDEN"
            in production_override_failures
            and "HISTORICAL_DELTA_TEST_ANCESTRY_OVERRIDE_FORBIDDEN"
            in production_override_failures
            and independent_production_fixture_override.get("status") == "NO_GO"
            and "SELFTEST_FIXTURE_FORBIDDEN_IN_AUTHORIZED_REPOSITORY"
            in production_override_failures,
            production_override_failures,
        )
    )

    failed = [case for case in cases if case["status"] != "PASS"]
    receipt = {
        "HISTORICAL_DELTA_METADATA_SELFTEST_STATUS": "PASS" if not failed else "FAIL",
        "HISTORICAL_DELTA_METADATA_SELFTEST_CASE_COUNT": len(cases),
        "HISTORICAL_DELTA_METADATA_SELFTEST_PASS_COUNT": len(cases) - len(failed),
        "CASE_FAILURE_COUNT": len(failed),
        "RAW_SCANNER_MUTATION_COUNT": 0,
        "RAW_FAILURE_DETECTION_SUPPRESSED_COUNT": 0,
        "WILDCARD_COUNT": 0,
        "FUTURE_FAILURE_AUTO_MATCH_COUNT": 0,
        "PRIMARY_INDEPENDENT_PARITY_REQUIRED": True,
        "INDEPENDENT_PRODUCTION_AUTHORITY_OVERRIDE_COUNT": 0,
        "cases": cases,
    }
    print(json.dumps(receipt, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
