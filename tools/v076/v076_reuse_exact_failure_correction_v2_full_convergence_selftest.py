#!/usr/bin/env python3
"""Focused negative/compatibility tests for the V2 full-convergence epoch."""

from __future__ import annotations

import argparse
import contextlib
import copy
import hashlib
import io
import json
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

import v076_reuse_exact_failure_correction_v2_full_convergence as convergence
import v076_reuse_correction_v2_independent_audit as independent_audit
import v076_reuse_exact_failure_correction_v2 as legacy_resolver
import v076_reuse_full_convergence_descendant_supplement_builder as successor_builder
import v076_historical_delta_metadata_successor_v2 as hdm_successor_v2
import v076_historical_delta_metadata_successor_v2_independent_audit as hdm_successor_v2_independent


REAL_DESCENDANT_RAW_REL = (
    convergence.EPOCH_ROOT_REL / "descendant_history_raw_570d6e3c.json"
)
REAL_DESCENDANT_SUPPLEMENT_REL = (
    convergence.EPOCH_ROOT_REL / "descendant_history_supplement_570d6e3c.json"
)


@dataclass(frozen=True)
class Case:
    case_id: str
    description: str
    run: Callable[[], None]


def _expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def _expect_failure(failures: list[str], prefix: str) -> None:
    _expect(any(value.startswith(prefix) for value in failures), f"missing {prefix}: {failures}")


def _fingerprint(index: int) -> str:
    return "V2F-" + f"{index:064x}"


def _touch_policy() -> dict[str, bool]:
    return {
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


def _component_inventory_row(
    *,
    component_id: str,
    path: str,
    domain_id: str = "domain.sample",
    role: str = "OWNER",
    owner_component_id: str | None = None,
    owner_path: str | None = None,
    production_reachable: bool = True,
    superseded_by: list[str] | None = None,
    supersedes: list[str] | None = None,
    **overrides: Any,
) -> dict[str, Any]:
    """Return one closed, projection-tagged component-inventory authority row."""

    is_owner = role == "OWNER"
    owner_component_id = owner_component_id or (
        component_id if is_owner else "component.current.owner"
    )
    owner_path = owner_path or (
        path if is_owner else "scripts/current/owner.gd"
    )
    row: dict[str, Any] = {
        "authority_source_kind": "component_inventory",
        "change_class": "DOMAIN_CORE",
        "class_name": "Selftest" + "".join(
            part.title() for part in component_id.split(".")
        ),
        "component_id": component_id,
        "component_role": role,
        "domain_id": domain_id,
        "focused_test_ids": ["v076_full_convergence_selftest"],
        "golden_scenario_steps": [],
        "new_component_justification": "Exact self-test authority fixture.",
        "owner_component_id": owner_component_id,
        "owner_path": owner_path,
        "owns_identity": is_owner,
        "owns_presentation": False,
        "owns_replay": False,
        "owns_rng": False,
        "owns_save": False,
        "owns_tick": False,
        "path": path,
        "production_reachable": production_reachable,
        "reads_authority": True,
        "reuse_candidates_considered": ["reuse.selftest.existing"],
        "reuse_disposition": (
            "ADOPT_AS_OWNER" if is_owner else "ADAPT_AS_CONSUMER"
        ),
        "reuse_source_ids": ["reuse.selftest.existing"],
        "superseded_by": sorted(superseded_by or []),
        "supersedes": sorted(supersedes or []),
        "writes_authority": is_owner,
    }
    row.update(overrides)
    return row


def _historical_backfill_row(
    *,
    component_id: str = "component.history.sample",
    source_commit: str = "3" * 40,
    source_blob: str = "1" * 64,
    historical_role: str = "CONSUMER",
    current_disposition: str = "HISTORICAL_SUPERSEDED_NONREACHABLE",
    production_reachability: str = "NONREACHABLE",
    supersession: list[str] | None = None,
    **overrides: Any,
) -> dict[str, Any]:
    """Return the exact minimal historical-identity backfill contract."""

    row: dict[str, Any] = {
        "authority_source_kind": "historical_identity_backfill",
        "component_id": component_id,
        "current_disposition": current_disposition,
        "historical_role": historical_role,
        "production_reachability": production_reachability,
        "source_blob": source_blob,
        "source_commit": source_commit,
        "supersession": sorted(supersession or []),
    }
    row.update(overrides)
    return row


def _raw_authority_row(row: dict[str, Any]) -> dict[str, Any]:
    """Remove the projection-only source tag before writing an authority file."""

    result = copy.deepcopy(row)
    result.pop("authority_source_kind", None)
    return result


def _identity_binding() -> dict[str, Any]:
    selector = {
        "component_ids": [
            "component.current.owner",
            "component.history.sample",
        ],
        "dynamic_reference_ids": [],
        "paths": [
            "scripts/current/owner.gd",
            "scripts/history/sample.gd",
        ],
        "retirement_ids": [],
        "supersession_ids": ["supersession.sample"],
    }
    projection = {
        "dynamic_reference_rows": [],
        "owner_map_lines": [],
        "registry_rows": [
            _component_inventory_row(
                component_id="component.current.owner",
                path="scripts/current/owner.gd",
                supersedes=["component.history.sample"],
            ),
            _historical_backfill_row(
                supersession=["component.current.owner"],
            ),
        ],
        "supersession_rows": [{
            "domain_id": "domain.sample",
            "dual_write_count": 0,
            "fallback_count": 0,
            "old_owner_production_reachability": 0,
            "supersession_id": "supersession.sample",
            "old_component_id": "component.history.sample",
            "new_component_id": "component.current.owner",
        }],
    }
    return {
        "authority_selectors": selector,
        "current_blob_sha256": "2" * 64,
        "current_component_id": "component.current.owner",
        "domain_id": "domain.sample",
        "current_owner_id": "component.current.owner",
        "current_path": "scripts/current/owner.gd",
        "current_production_reachability": "PRODUCTION_REACHABLE",
        "current_role": "OWNER",
        "diagnostic_only_status": "NOT_DIAGNOSTIC_ONLY",
        "documentation_only_status": "NOT_DOCUMENTATION_ONLY",
        "dynamic_reference_status": "NOT_DYNAMIC_REFERENCE",
        "duplicate_identity_sha256": "",
        "duplicate_of_failure_fingerprint": "",
        "duplicate_reason": "",
        "generated_evidence_status": "NOT_GENERATED_EVIDENCE",
        "first_seen_commit": "3" * 40,
        "historical_blob_sha256": "1" * 64,
        "historical_component_id": "component.history.sample",
        "historical_owner_id": "component.current.owner",
        "historical_path": "scripts/history/sample.gd",
        "historical_production_reachability": "NONREACHABLE",
        "historical_role": "CONSUMER",
        "invalidation_policy": _touch_policy(),
        "recommended_disposition": "HISTORICAL_SUPERSEDED_NONREACHABLE",
        "retired_status": "SUPERSEDED_NONREACHABLE",
        "subject_projection": projection,
        "subject_projection_sha256": convergence.sha256_bytes(convergence.canonical_bytes(projection)),
        "source_commit": "3" * 40,
        "superseded_by": ["component.current.owner"],
        "supersedes": ["component.history.sample"],
        "test_only_status": "NOT_TEST_ONLY",
        "last_seen_commit": "3" * 40,
    }


def _record(fingerprints: list[str] | None = None) -> dict[str, Any]:
    fingerprints = sorted(fingerprints or [_fingerprint(1)])
    binding = _identity_binding()
    record = {
        "allowed_from_state": "HISTORICAL_FAILURE_PRESENT_CLASSIFIED",
        "allowed_rule_ids": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "allowed_to_state": "CORRECTED_HISTORICAL_DEBT",
        "authority_source_sha256": {
            path: "a" * 64 for path in convergence.AUTHORITY_SOURCE_PATHS
        },
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "backlog_item_ids": ["reuse.full-convergence.sample"],
        "baseline_failure_set_sha256": convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,
        "baseline_report_sha256": convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
        "batch_classification_sha256": "b" * 64,
        "batch_id": "batch-001",
        "batch_inventory_sha256": "c" * 64,
        "batch_negative_checks_sha256": "d" * 64,
        "batch_review_a_sha256": "e" * 64,
        "batch_review_b_sha256": "f" * 64,
        "binding_head_sha": "1" * 40,
        "binding_tree_sha": "2" * 40,
        "correction_id": "V2-FC-selftest",
        "correction_reason": "Exact classified historical debt.",
        "component_ids": ["component.current.owner", "component.history.sample"],
        "component_set_sha256": convergence._line_set_sha([
            "component.current.owner", "component.history.sample",
        ]),
        "created_at": "2026-08-27T00:00:00Z",
        "creator": "V076ReuseExactFailureCorrectionV2FullConvergence",
        "descendant_history_supplement_sha256": "9" * 64,
        "domain_ids": ["domain.sample"],
        "domain_set_sha256": convergence._line_set_sha(["domain.sample"]),
        "dynamic_reference_ids": [],
        "dynamic_reference_set_sha256": convergence._line_set_sha([]),
        "failure_classes": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "failure_count": len(fingerprints),
        "failure_fingerprint_set_sha256": convergence._line_set_sha(fingerprints),
        "failure_fingerprints": fingerprints,
        "from_state": "HISTORICAL_FAILURE_PRESENT_CLASSIFIED",
        "future_failure_policy": {
            "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
            "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
        },
        "identity_binding_by_failure": {
            fingerprint: copy.deepcopy(binding) for fingerprint in fingerprints
        },
        "negative_examples": ["CURRENT_DELTA_FAILURE", "WILDCARD"],
        "owner_ids": ["component.current.owner"],
        "owner_set_sha256": convergence._line_set_sha([
            "component.current.owner",
        ]),
        "path_set_sha256": convergence._line_set_sha([
            "scripts/current/owner.gd", "scripts/history/sample.gd",
        ]),
        "paths": ["scripts/current/owner.gd", "scripts/history/sample.gd"],
        "previous_correction_chain_sha256": convergence.LEGACY_RECORD_CHAIN_TERMINAL_SHA256,
        "record_kind": "CORRECTION_RECORD",
        "required_untouched_state": True,
        "retirement_ids": [],
        "retirement_set_sha256": convergence._line_set_sha([]),
        "revocation_policy": {
            "OLD_RECORD_MUTATION_FORBIDDEN": True,
            "REVOCATION_APPEND_ONLY": True,
        },
        "rule_ids": ["HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"],
        "schema_version": convergence.SCHEMA_VERSION,
        "source_commit_set": ["3" * 40],
        "source_commit_set_sha256": convergence._line_set_sha(["3" * 40]),
        "supersession_ids": ["supersession.sample"],
        "supersession_set_sha256": convergence._line_set_sha(["supersession.sample"]),
        "to_effective_disposition": "CORRECTED_HISTORICAL_DEBT",
        "touch_invalidation_policy": _touch_policy(),
        "transition_class_id": "HISTORICAL_CLASSIFIED_COMPONENT_DEBT",
        "untouched_in_current_delta": True,
    }
    record["record_payload_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(convergence._record_payload(record))
    )
    return record


def _batch(count: int = 25, *, terminal: bool = False) -> dict[str, Any]:
    fingerprints = [_fingerprint(index) for index in range(1, count + 1)]
    record = _record(fingerprints)
    binding = {
        "correction_id": record["correction_id"],
        "failure_fingerprints": fingerprints,
        "path": (
            "docs/architecture/reuse_corrections/v2/records/"
            "full_convergence_20260827/batch-001/component.json"
        ),
        "previous_correction_chain_sha256": convergence.LEGACY_RECORD_CHAIN_TERMINAL_SHA256,
        "record_payload_sha256": record["record_payload_sha256"],
        "record_sha256": "9" * 64,
    }
    return {
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "baseline_failure_set_sha256": convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,
        "baseline_report_sha256": convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
        "batch_classification_sha256": "1" * 64,
        "batch_id": "batch-001",
        "batch_inventory_sha256": "2" * 64,
        "batch_negative_checks_sha256": "3" * 64,
        "batch_review_a_sha256": "4" * 64,
        "batch_review_a_status": "GO",
        "batch_review_b_sha256": "5" * 64,
        "batch_review_b_status": "GO",
        "batch_size_target": "25_TO_50_FAILURE_FINGERPRINTS",
        "batch_unknown_count": 0,
        "batch_wildcard_count": 0,
        "binding_head_sha": "6" * 40,
        "binding_tree_sha": "7" * 40,
        "current_failure_false_accept_count": 0,
        "descendant_history_supplement_sha256": "9" * 64,
        "failure_count": len(fingerprints),
        "failure_fingerprint_set_sha256": convergence._line_set_sha(fingerprints),
        "failure_fingerprints": fingerprints,
        "identity_coverage_percent": 100,
        "previous_batch_append_sha256": "",
        "record_bindings": [binding],
        "record_chain_start_sha256": convergence.LEGACY_RECORD_CHAIN_TERMINAL_SHA256,
        "record_chain_terminal_sha256": record["record_payload_sha256"],
        "schema_version": convergence.BATCH_MANIFEST_SCHEMA_VERSION,
        "terminal_remainder_batch": terminal,
    }


def _git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
    )
    return result.stdout.strip()


def _projection_invalidation_case() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-projection-") as temporary:
        root = Path(temporary)
        _git(root, "init", "--quiet")
        _git(root, "config", "user.email", "selftest@example.invalid")
        _git(root, "config", "user.name", "V076 Selftest")
        docs = root / "docs/architecture"
        docs.mkdir(parents=True)
        registry = docs / "V076_HISTORICAL_REUSE_REGISTRY.json"
        supersession = docs / "V076_SUPERSESSION_MAP.json"
        owner = docs / "V076_OWNER_REUSE_MAP.md"
        registry.write_text(json.dumps({
            "component_inventory": [
                _raw_authority_row(_component_inventory_row(
                    component_id="component.history.sample",
                    path="scripts/history/sample.gd",
                    role="CONSUMER",
                    owner_component_id="component.current.owner",
                    owner_path="scripts/current/owner.gd",
                    production_reachable=False,
                    superseded_by=["component.current.owner"],
                )),
                _raw_authority_row(_component_inventory_row(
                    component_id="component.current.owner",
                    path="scripts/current/owner.gd",
                    supersedes=["component.history.sample"],
                )),
            ],
            "historical_identity_backfill": [],
        }), encoding="utf-8")
        dynamic = docs / "V076_DYNAMIC_REFERENCE_MANIFEST.json"
        dynamic.write_text(json.dumps({"entries": []}), encoding="utf-8")
        supersession.write_text(json.dumps({"entries": [{
            "supersession_id": "supersession.sample",
            "old_component_id": "component.history.sample",
            "new_component_id": "component.current.owner",
            "domain_id": "domain.sample",
            "dual_write_count": 0,
            "fallback_count": 0,
            "old_owner_production_reachability": 0,
        }]}), encoding="utf-8")
        owner.write_text("owner map\n", encoding="utf-8")
        _git(root, "add", "docs/architecture")
        _git(root, "commit", "--quiet", "-m", "base")
        base = _git(root, "rev-parse", "HEAD")
        selector = _identity_binding()["authority_selectors"]
        projection = convergence.subject_projection(root, base, selector)
        payload = json.loads(registry.read_text(encoding="utf-8"))
        payload["component_inventory"].append({
            "component_id": "component.unrelated",
            "path": "scripts/unrelated.gd",
        })
        registry.write_text(json.dumps(payload), encoding="utf-8")
        _git(root, "add", registry.relative_to(root).as_posix())
        _git(root, "commit", "--quiet", "-m", "unrelated")
        unrelated = _git(root, "rev-parse", "HEAD")
        _expect(
            convergence.subject_projection(root, unrelated, selector) == projection,
            "unrelated authority append changed subject projection",
        )
        payload["component_inventory"][0]["owner_component_id"] = "component.changed.owner"
        registry.write_text(json.dumps(payload), encoding="utf-8")
        _git(root, "add", registry.relative_to(root).as_posix())
        _git(root, "commit", "--quiet", "-m", "matched change")
        changed = _git(root, "rev-parse", "HEAD")
        _expect(
            convergence.subject_projection(root, changed, selector) != projection,
            "matched owner change did not invalidate subject projection",
        )


def _write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(convergence.canonical_bytes(payload))


def _write_batch_artifacts(
    directory: Path,
    manifest: dict[str, Any],
    identities: dict[str, dict[str, str]],
) -> None:
    fingerprints = [str(value) for value in manifest["failure_fingerprints"]]
    documents = {
        "inventory": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_inventory_sha256"][1],
            "batch_id": manifest["batch_id"],
            "failure_fingerprints": fingerprints,
            "failure_count": len(fingerprints),
            "identity_coverage_percent": 100,
            "unknown_count": 0,
            "rows": {
                fingerprint: {
                    "failure_fingerprint": fingerprint,
                    "raw_failure": identities[fingerprint]["raw_failure"],
                    "rule_id": identities[fingerprint]["rule_id"],
                }
                for fingerprint in fingerprints
            },
        },
        "classification": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_classification_sha256"][1],
            "batch_id": manifest["batch_id"],
            "failure_fingerprints": fingerprints,
            "failure_count": len(fingerprints),
            "unknown_count": 0,
            "wildcard_count": 0,
            "classifications": {
                fingerprint: {
                    "failure_fingerprint": fingerprint,
                    "status": "CLASSIFIED",
                    "recommended_disposition": "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
                }
                for fingerprint in fingerprints
            },
        },
        "negative_checks": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_negative_checks_sha256"][1],
            "batch_id": manifest["batch_id"],
            "failure_fingerprints": fingerprints,
            "failure_count": len(fingerprints),
            "status": "PASS",
            "current_failure_false_accept_count": 0,
            "future_failure_auto_correction_count": 0,
            "wildcard_count": 0,
            "checks": {"baseline_membership": True, "wildcard_rejection": True},
        },
        "review_a": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_review_a_sha256"][1],
            "batch_id": manifest["batch_id"],
            "failure_fingerprints": fingerprints,
            "failure_count": len(fingerprints),
            "review_id": "A",
            "status": "GO",
            "p0_count": 0,
            "p1_count": 0,
            "findings": [],
        },
        "review_b": {
            "schema_version": convergence.BATCH_ARTIFACT_SPECS["batch_review_b_sha256"][1],
            "batch_id": manifest["batch_id"],
            "failure_fingerprints": fingerprints,
            "failure_count": len(fingerprints),
            "review_id": "B",
            "status": "GO",
            "p0_count": 0,
            "p1_count": 0,
            "findings": [],
        },
    }
    for hash_field, (filename, _, kind) in convergence.BATCH_ARTIFACT_SPECS.items():
        path = directory / filename
        _write_json(path, documents[kind])
        manifest[hash_field] = convergence.sha256_file(path)


def _legacy_overlap_case(root: Path) -> None:
    legacy = convergence.verify_legacy_anchor(root)
    _expect(legacy["status"] == "PASS", str(legacy))
    manifest = _batch()
    legacy_fingerprint = legacy["legacy_corrected_fingerprints"][0]
    manifest["failure_fingerprints"][0] = legacy_fingerprint
    manifest["failure_fingerprints"] = sorted(manifest["failure_fingerprints"])
    manifest["failure_fingerprint_set_sha256"] = convergence._line_set_sha(
        manifest["failure_fingerprints"]
    )
    manifest["record_bindings"][0]["failure_fingerprints"] = list(
        manifest["failure_fingerprints"]
    )
    with tempfile.TemporaryDirectory(prefix="v076-fc-legacy-overlap-") as temporary:
        manifest_path = Path(temporary) / "batch_manifest.json"
        _write_json(manifest_path, manifest)
        result = convergence.validate_batch_manifest_against_repo(
            root,
            manifest_path,
            evaluated_head=_git(root, "rev-parse", "HEAD"),
            baseline_report_path=root / convergence.BASELINE_REPORT_REL,
        )
    _expect_failure(result["failures"], "BATCH_LEGACY_FINGERPRINT_REUSE")


def _baseline_membership_case(root: Path) -> None:
    report = convergence.load_json_strict(root / convergence.BASELINE_REPORT_REL)
    authorized = convergence.authorized_failure_fingerprint_sets(report)
    historical = sorted(authorized["historical"])
    current = sorted(authorized["current"])
    _expect(len(historical) == 510 and len(current) == 56, "authorized set count drift")

    def result_for(fingerprints: list[str]) -> dict[str, Any]:
        manifest = _batch()
        manifest["failure_fingerprints"] = sorted(fingerprints)
        manifest["failure_count"] = len(fingerprints)
        manifest["failure_fingerprint_set_sha256"] = convergence._line_set_sha(fingerprints)
        manifest["record_bindings"][0]["failure_fingerprints"] = sorted(fingerprints)
        with tempfile.TemporaryDirectory(prefix="v076-fc-membership-") as temporary:
            manifest_path = Path(temporary) / "batch_manifest.json"
            _write_json(manifest_path, manifest)
            return convergence.validate_batch_manifest_against_repo(
                root,
                manifest_path,
                evaluated_head=_git(root, "rev-parse", "HEAD"),
                baseline_report_path=root / convergence.BASELINE_REPORT_REL,
            )

    current_result = result_for(historical[:24] + [current[0]])
    _expect_failure(
        current_result["failures"],
        "BATCH_CURRENT_FAILURE_CORRECTION_FALSE_ACCEPT",
    )
    unknown_result = result_for(historical[:24] + [_fingerprint(0)])
    _expect_failure(
        unknown_result["failures"],
        "BATCH_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL",
    )


def _authorized_baseline_epoch_case(root: Path) -> None:
    expected = Path(
        "reports/reuse/correction_v2/epochs/full_convergence_20260827/"
        "baseline_raw_failure_report.json"
    )
    _expect(convergence.BASELINE_REPORT_REL == expected, str(convergence.BASELINE_REPORT_REL))
    _expect(
        independent_audit.FULL_CONVERGENCE_BASELINE_REPORT == expected,
        str(independent_audit.FULL_CONVERGENCE_BASELINE_REPORT),
    )
    result = convergence.validate_authorized_baseline(root / expected)
    _expect(result["status"] == "PASS", json.dumps(result, sort_keys=True))
    _expect(
        result["baseline_report_sha256"]
        == convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
        result["baseline_report_sha256"],
    )
    _expect(
        result["baseline_failure_set_sha256"]
        == convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,
        result["baseline_failure_set_sha256"],
    )
    _expect(
        (
            result["authorization_base_head_sha"],
            result["failure_count"],
            result["historical_failure_count"],
            result["current_failure_count"],
        )
        == (
            convergence.AUTHORIZATION_BASE_HEAD_SHA,
            convergence.AUTHORIZED_BASELINE_FAILURE_COUNT,
            convergence.AUTHORIZED_BASELINE_HISTORICAL_COUNT,
            convergence.AUTHORIZED_BASELINE_CURRENT_COUNT,
        ),
        json.dumps(result, sort_keys=True),
    )


def _legacy_baseline_rejected_by_new_epoch_case(root: Path) -> None:
    legacy = root / "reports/reuse/correction_v2/baseline_raw_failure_report.json"
    result = convergence.validate_authorized_baseline(legacy)
    _expect(result["status"] == "FAIL", json.dumps(result, sort_keys=True))
    _expect_failure(result["failures"], "BASELINE_SHA256_MISMATCH")
    _expect_failure(result["failures"], "BASELINE_HEAD_MISMATCH")


def _previous_batch_link_case() -> None:
    predecessor = _batch()
    current = _batch()
    current["batch_id"] = "batch-002"
    current_fingerprints = [_fingerprint(index) for index in range(26, 51)]
    current["failure_fingerprints"] = current_fingerprints
    current["failure_count"] = len(current_fingerprints)
    current["failure_fingerprint_set_sha256"] = convergence._line_set_sha(
        current_fingerprints
    )
    current["record_bindings"][0]["failure_fingerprints"] = current_fingerprints
    current["record_chain_start_sha256"] = predecessor["record_chain_terminal_sha256"]
    current["record_bindings"][0]["previous_correction_chain_sha256"] = predecessor[
        "record_chain_terminal_sha256"
    ]
    with tempfile.TemporaryDirectory(prefix="v076-fc-previous-") as temporary:
        predecessor_path = Path(temporary) / "batch-001.json"
        _write_json(predecessor_path, predecessor)
        current["previous_batch_append_sha256"] = convergence.sha256_file(predecessor_path)
        failures = convergence.validate_previous_batch_link(current, predecessor_path)
        _expect(not failures, str(failures))
        current["previous_batch_append_sha256"] = "0" * 64
        _expect_failure(
            convergence.validate_previous_batch_link(current, predecessor_path),
            "BATCH_PREVIOUS_MANIFEST_SHA256_MISMATCH",
        )


def _explicit_previous_manifest_required_case() -> None:
    manifest = _batch()
    manifest["previous_batch_append_sha256"] = "a" * 64
    _expect_failure(
        convergence.validate_previous_batch_link(manifest, None),
        "BATCH_PREVIOUS_MANIFEST_REQUIRED",
    )


def _previous_fingerprint_reuse_case() -> None:
    predecessor = _batch()
    current = _batch()
    current["batch_id"] = "batch-002"
    current["record_chain_start_sha256"] = predecessor["record_chain_terminal_sha256"]
    with tempfile.TemporaryDirectory(prefix="v076-fc-previous-overlap-") as temporary:
        predecessor_path = Path(temporary) / "batch-001.json"
        _write_json(predecessor_path, predecessor)
        current["previous_batch_append_sha256"] = convergence.sha256_file(predecessor_path)
        _expect_failure(
            convergence.validate_previous_batch_link(current, predecessor_path),
            "BATCH_PREVIOUS_MANIFEST_FINGERPRINT_REUSE",
        )


def _retarget_batch(
    manifest: dict[str, Any],
    batch_id: str,
    fingerprints: list[str],
    predecessor: dict[str, Any] | None = None,
) -> None:
    manifest["batch_id"] = batch_id
    manifest["failure_fingerprints"] = sorted(fingerprints)
    manifest["failure_count"] = len(fingerprints)
    manifest["failure_fingerprint_set_sha256"] = convergence._line_set_sha(fingerprints)
    manifest["record_bindings"][0]["failure_fingerprints"] = sorted(fingerprints)
    manifest["record_bindings"][0]["path"] = manifest["record_bindings"][0]["path"].replace(
        "batch-001", batch_id
    )
    if predecessor is not None:
        terminal = predecessor["record_chain_terminal_sha256"]
        manifest["record_chain_start_sha256"] = terminal
        manifest["record_bindings"][0]["previous_correction_chain_sha256"] = terminal


def _nonadjacent_fingerprint_reuse_case() -> None:
    batch_001 = _batch()
    batch_002 = _batch()
    batch_003 = _batch()
    _retarget_batch(batch_002, "batch-002", [_fingerprint(index) for index in range(26, 51)], batch_001)
    _retarget_batch(batch_003, "batch-003", [_fingerprint(index) for index in range(1, 26)], batch_002)
    with tempfile.TemporaryDirectory(prefix="v076-fc-global-overlap-") as temporary:
        root = Path(temporary)
        batch_001_path = root / "batch-001.json"
        batch_002_path = root / "batch-002.json"
        _write_json(batch_001_path, batch_001)
        batch_002["previous_batch_append_sha256"] = convergence.sha256_file(batch_001_path)
        _write_json(batch_002_path, batch_002)
        batch_003["previous_batch_append_sha256"] = convergence.sha256_file(batch_002_path)
        _expect_failure(
            convergence.validate_previous_batch_link(batch_003, batch_002_path),
            "BATCH_PRIOR_MANIFEST_FINGERPRINT_REUSE",
        )


def _canonical_previous_batch_chain_case() -> None:
    batch_001 = _batch()
    batch_002 = _batch()
    batch_003 = _batch()
    _retarget_batch(
        batch_002,
        "batch-002",
        [_fingerprint(index) for index in range(26, 51)],
        batch_001,
    )
    _retarget_batch(
        batch_003,
        "batch-003",
        [_fingerprint(index) for index in range(51, 76)],
        batch_002,
    )
    with tempfile.TemporaryDirectory(prefix="v076-fc-canonical-chain-") as temporary:
        root = Path(temporary)
        batch_001_path = root / "batch-001" / "batch-001-manifest.json"
        batch_002_path = root / "batch-002" / "batch-002-manifest.json"
        _write_json(batch_001_path, batch_001)
        batch_002["previous_batch_append_sha256"] = convergence.sha256_file(
            batch_001_path
        )
        _write_json(batch_002_path, batch_002)
        batch_003["previous_batch_append_sha256"] = convergence.sha256_file(
            batch_002_path
        )
        failures = convergence.validate_previous_batch_link(
            batch_003,
            batch_002_path,
        )
        _expect(not failures, str(failures))


def _post_touch_ancestor_batch_routing_case() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-post-touch-route-") as temporary:
        root = Path(temporary)
        batch_root = (
            root
            / "docs/architecture/reuse_corrections/v2/batches"
            / "full_convergence_20260827"
        )
        predecessor_path = batch_root / "batch-004/batch-004-manifest.json"
        current_path = batch_root / "batch-005/batch-005-manifest.json"
        sidecar_path = (
            root
            / "docs/architecture/reuse_corrections/v2/revalidations"
            / "post-touch-selftest.json"
        )
        predecessor = {"batch_id": "batch-004"}
        current = {"batch_id": "batch-005"}
        _write_json(predecessor_path, predecessor)
        _write_json(current_path, current)
        _write_json(sidecar_path, {
            "current_batch_manifest_path": predecessor_path.relative_to(root).as_posix(),
        })
        explicit_chain = [
            (predecessor_path, predecessor),
            (current_path, current),
        ]
        failures, selected = convergence._resolve_post_touch_batch_manifest_path(
            root,
            sidecar_path,
            explicit_chain,
        )
        _expect(not failures, str(failures))
        _expect(
            selected == predecessor_path.resolve(),
            f"ancestor route mismatch: {selected}",
        )
        findings, independently_selected = (
            independent_audit._resolve_post_touch_batch_manifest_path(
                root,
                sidecar_path,
                explicit_chain,
            )
        )
        _expect(not findings, str(findings))
        _expect(
            independently_selected == predecessor_path.resolve(),
            f"independent ancestor route mismatch: {independently_selected}",
        )


def _post_touch_nonchain_batch_routing_case() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-post-touch-nonchain-") as temporary:
        root = Path(temporary)
        batch_root = (
            root
            / "docs/architecture/reuse_corrections/v2/batches"
            / "full_convergence_20260827"
        )
        current_path = batch_root / "batch-005/batch-005-manifest.json"
        unrelated_path = batch_root / "batch-999/batch-999-manifest.json"
        sidecar_path = (
            root
            / "docs/architecture/reuse_corrections/v2/revalidations"
            / "post-touch-selftest.json"
        )
        current = {"batch_id": "batch-005"}
        _write_json(current_path, current)
        _write_json(unrelated_path, {"batch_id": "batch-999"})
        _write_json(sidecar_path, {
            "current_batch_manifest_path": unrelated_path.relative_to(root).as_posix(),
        })
        explicit_chain = [(current_path, current)]
        failures, selected = convergence._resolve_post_touch_batch_manifest_path(
            root,
            sidecar_path,
            explicit_chain,
        )
        _expect_failure(
            failures,
            "POST_TOUCH_CURRENT_BATCH_MANIFEST_NOT_IN_EXPLICIT_CHAIN",
        )
        _expect(selected is None, f"nonchain route trusted: {selected}")
        findings, independently_selected = (
            independent_audit._resolve_post_touch_batch_manifest_path(
                root,
                sidecar_path,
                explicit_chain,
            )
        )
        _expect(
            any(
                finding.get("code")
                == "FULL_CONVERGENCE_POST_TOUCH_BATCH_NOT_IN_EXPLICIT_CHAIN"
                for finding in findings
            ),
            str(findings),
        )
        _expect(
            independently_selected is None,
            f"independent nonchain route trusted: {independently_selected}",
        )


def _post_touch_malformed_sidecar_routing_case() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-post-touch-malformed-") as temporary:
        root = Path(temporary)
        sidecar_path = root / "post-touch-selftest.json"
        sidecar_path.write_text('{"current_batch_manifest_path":', encoding="utf-8")
        failures, selected = convergence._resolve_post_touch_batch_manifest_path(
            root,
            sidecar_path,
            [],
        )
        _expect_failure(failures, "POST_TOUCH_SIDECAR_MANIFEST_JSON_INVALID")
        _expect(selected is None, f"malformed sidecar route trusted: {selected}")
        findings, independently_selected = (
            independent_audit._resolve_post_touch_batch_manifest_path(
                root,
                sidecar_path,
                [],
            )
        )
        _expect(
            any(
                finding.get("code")
                == "FULL_CONVERGENCE_POST_TOUCH_SIDECAR_UNREADABLE"
                for finding in findings
            ),
            str(findings),
        )
        _expect(
            independently_selected is None,
            f"independent malformed route trusted: {independently_selected}",
        )


def _post_touch_invalid_chain_never_trusts_case() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-post-touch-broken-chain-") as temporary:
        root = Path(temporary)
        batch_path = (
            root
            / "docs/architecture/reuse_corrections/v2/batches"
            / "full_convergence_20260827/batch-005/batch-005-manifest.json"
        )
        sidecar_path = root / "post-touch-selftest.json"
        batch = {"batch_id": "batch-005"}
        _write_json(batch_path, batch)
        _write_json(sidecar_path, {
            "current_batch_manifest_path": batch_path.relative_to(root).as_posix(),
        })
        failures, selected = convergence._resolve_post_touch_batch_manifest_path(
            root,
            sidecar_path,
            [(batch_path, batch)],
            explicit_batch_chain_valid=False,
        )
        _expect_failure(failures, "POST_TOUCH_EXPLICIT_BATCH_CHAIN_INVALID")
        _expect(selected is None, f"broken primary chain route trusted: {selected}")

        original_validator = independent_audit._post_touch.validate_manifest_and_records
        fingerprint = _fingerprint(999)

        def unexpected_pass(*_args: Any, **_kwargs: Any) -> dict[str, Any]:
            raise AssertionError(
                f"invalid chain reached post-touch trust validator for {fingerprint}"
            )

        independent_audit._post_touch.validate_manifest_and_records = unexpected_pass
        try:
            findings, trusted, summary = independent_audit._post_touch_sidecar_findings(
                root,
                sidecar_path,
                [(batch_path, batch)],
                "1" * 40,
                explicit_batch_chain_valid=False,
            )
        finally:
            independent_audit._post_touch.validate_manifest_and_records = original_validator
        _expect(
            any(
                finding.get("code")
                == "FULL_CONVERGENCE_POST_TOUCH_EXPLICIT_CHAIN_INVALID"
                for finding in findings
            ),
            str(findings),
        )
        _expect(not trusted, f"broken independent chain exposed trust: {trusted}")
        _expect(summary.get("status") == "FAIL", str(summary))
        _expect(
            summary.get("trusted_fingerprint_count") == 0,
            str(summary),
        )


def _post_touch_path_aliases_never_route_case() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-post-touch-alias-") as temporary:
        root = Path(temporary)
        batch_path = (
            root
            / "docs/architecture/reuse_corrections/v2/batches"
            / "full_convergence_20260827/batch-004/batch-004-manifest.json"
        )
        sidecar_path = root / "post-touch-selftest.json"
        batch = {"batch_id": "batch-004"}
        _write_json(batch_path, batch)
        canonical = batch_path.relative_to(root).as_posix()
        aliases = [
            "res://" + canonical,
            canonical.replace("/", "\\"),
            "./" + canonical,
            "../" + canonical,
            canonical.replace("/", "//", 1),
            " " + canonical,
            canonical + " ",
            canonical.replace("batch-004", "batch-*", 1),
            "C:/outside/batch-004-manifest.json",
        ]
        original_validator = independent_audit._post_touch.validate_manifest_and_records

        def unexpected_call(*_args: Any, **_kwargs: Any) -> dict[str, Any]:
            raise AssertionError("noncanonical sidecar path reached trust validator")

        independent_audit._post_touch.validate_manifest_and_records = unexpected_call
        try:
            for alias in aliases:
                _write_json(sidecar_path, {"current_batch_manifest_path": alias})
                failures, selected = (
                    convergence._resolve_post_touch_batch_manifest_path(
                        root,
                        sidecar_path,
                        [(batch_path, batch)],
                    )
                )
                _expect(failures, f"primary accepted alias: {alias}")
                _expect(selected is None, f"primary routed alias: {alias}")
                findings, independently_selected = (
                    independent_audit._resolve_post_touch_batch_manifest_path(
                        root,
                        sidecar_path,
                        [(batch_path, batch)],
                    )
                )
                _expect(findings, f"independent audit accepted alias: {alias}")
                _expect(
                    independently_selected is None,
                    f"independent audit routed alias: {alias}",
                )
                wrapper_findings, trusted, summary = (
                    independent_audit._post_touch_sidecar_findings(
                        root,
                        sidecar_path,
                        [(batch_path, batch)],
                        "1" * 40,
                    )
                )
                _expect(wrapper_findings, f"wrapper accepted alias: {alias}")
                _expect(not trusted, f"wrapper trusted alias: {alias}")
                _expect(summary.get("status") == "FAIL", str(summary))
                _expect(
                    summary.get("trusted_fingerprint_count") == 0,
                    str(summary),
                )
        finally:
            independent_audit._post_touch.validate_manifest_and_records = original_validator


def _supplement_prebase_source_ancestry_case(root: Path) -> None:
    source_commit = "62ceba063d685871ee3869707862598da00ba649"
    supplement_head = convergence.DESCENDANT_HISTORY_V3_RAW_HEAD
    evaluated_head = _git(root, "rev-parse", "HEAD")
    _expect(
        not convergence._is_ancestor(
            root,
            convergence.AUTHORIZATION_BASE_HEAD_SHA,
            source_commit,
        ),
        "fixture source no longer predates the authorization base",
    )
    _expect(
        convergence._supplement_source_commit_is_authorized(
            root,
            source_commit,
            supplement_head,
        ),
        "exact pre-base source ancestor was rejected",
    )
    _expect(
        not convergence._supplement_source_commit_is_authorized(
            root,
            evaluated_head,
            supplement_head,
        ),
        "post-report source commit was accepted",
    )
    _expect(
        not convergence._supplement_source_commit_is_authorized(
            root,
            source_commit,
            "not-a-commit",
        ),
        "invalid supplement head was accepted",
    )


def _batch_artifact_binding_case() -> None:
    manifest = _batch()
    identities = {
        fingerprint: {
            "raw_failure": f"HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:000000000000->111111111111:scripts/{index}.gd",
            "rule_id": "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
        }
        for index, fingerprint in enumerate(manifest["failure_fingerprints"])
    }
    with tempfile.TemporaryDirectory(prefix="v076-fc-artifacts-") as temporary:
        directory = Path(temporary)
        _write_batch_artifacts(directory, manifest, identities)
        failures = convergence.validate_batch_artifacts(
            directory / "batch_manifest.json",
            manifest,
            authorized_identities=identities,
        )
        _expect(not failures, str(failures))
        review = directory / "batch_review_A.json"
        document = convergence.load_json_strict(review)
        document["status"] = "NO_GO"
        _write_json(review, document)
        _expect_failure(
            convergence.validate_batch_artifacts(
                directory / "batch_manifest.json",
                manifest,
                authorized_identities=identities,
            ),
            "BATCH_ARTIFACT_SHA256_MISMATCH:batch_review_A.json",
        )
        manifest["batch_review_a_sha256"] = convergence.sha256_file(review)
        _expect_failure(
            convergence.validate_batch_artifacts(
                directory / "batch_manifest.json",
                manifest,
                authorized_identities=identities,
            ),
            "BATCH_ARTIFACT_REVIEW_A_STATUS_INVALID",
        )


def _baseline_raw_identity_binding_case(root: Path) -> None:
    report = convergence.load_json_strict(root / convergence.BASELINE_REPORT_REL)
    identities = convergence.authorized_failure_identity_by_fingerprint(report)
    fingerprint, identity = next(
        (fingerprint, identity)
        for fingerprint, identity in identities.items()
        if identity.get("bucket") == "HISTORICAL" and identity.get("subject_kind") == "path"
    )
    binding = _identity_binding()
    failures = convergence._authorized_identity_binding_failures(
        root,
        fingerprint,
        binding,
        identity,
        record_rule_ids=[identity["rule_id"]],
    )
    _expect_failure(failures, "IDENTITY_BASELINE_HISTORICAL_PATH_MISMATCH")
    _expect_failure(failures, "IDENTITY_BASELINE_SOURCE_COMMIT_MISMATCH")


def _record_manifest_binding_case(root: Path) -> None:
    manifest = _batch()
    record = _record(manifest["failure_fingerprints"])
    record["failure_fingerprints"] = record["failure_fingerprints"][1:]
    record["failure_count"] = len(record["failure_fingerprints"])
    record["failure_fingerprint_set_sha256"] = convergence._line_set_sha(record["failure_fingerprints"])
    record["identity_binding_by_failure"].pop(manifest["failure_fingerprints"][0])
    record["record_payload_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(convergence._record_payload(record))
    )
    with tempfile.TemporaryDirectory(prefix="v076-fc-record-binding-") as temporary:
        fixture = Path(temporary)
        _git(fixture, "init", "--quiet")
        _git(fixture, "config", "user.email", "selftest@example.invalid")
        _git(fixture, "config", "user.name", "V076 Selftest")
        for relative in convergence.AUTHORITY_SOURCE_PATHS:
            path = fixture / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("{}" if path.suffix == ".json" else "owner\n", encoding="utf-8")
        _git(fixture, "add", ".")
        _git(fixture, "commit", "--quiet", "-m", "fixture")
        head = _git(fixture, "rev-parse", "HEAD")
        record["binding_head_sha"] = head
        record["binding_tree_sha"] = _git(fixture, "rev-parse", "HEAD^{tree}")
        record["record_payload_sha256"] = convergence.sha256_bytes(
            convergence.canonical_bytes(convergence._record_payload(record))
        )
        record_path = fixture / convergence.RECORD_ROOT_REL / "batch-001" / "component.json"
        _write_json(record_path, record)
        manifest["binding_head_sha"] = head
        manifest["binding_tree_sha"] = record["binding_tree_sha"]
        manifest["record_bindings"][0]["record_payload_sha256"] = record["record_payload_sha256"]
        manifest["record_bindings"][0]["record_sha256"] = convergence.sha256_file(record_path)
        manifest["record_chain_terminal_sha256"] = record["record_payload_sha256"]
        failures, _ = convergence._validate_manifest_records_against_repo(
            fixture,
            manifest,
            evaluated_head=head,
            authorized_fingerprints={"historical": set(manifest["failure_fingerprints"]), "current": set()},
            authorized_identities={},
            legacy_fingerprints=set(),
        )
        _expect_failure(failures, "BATCH_RECORD_FINGERPRINT_BINDING_MISMATCH")
        _expect_failure(failures, "BATCH_RECORD_ACTUAL_FINGERPRINT_COVERAGE_MISMATCH")


def _actual_record_chain_case(root: Path) -> None:
    manifest = _batch()
    record = _record(manifest["failure_fingerprints"])
    record["previous_correction_chain_sha256"] = "8" * 64
    record["record_payload_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(convergence._record_payload(record))
    )
    with tempfile.TemporaryDirectory(prefix="v076-fc-record-chain-") as temporary:
        fixture = Path(temporary)
        _git(fixture, "init", "--quiet")
        _git(fixture, "config", "user.email", "selftest@example.invalid")
        _git(fixture, "config", "user.name", "V076 Selftest")
        for relative in convergence.AUTHORITY_SOURCE_PATHS:
            path = fixture / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("{}" if path.suffix == ".json" else "owner\n", encoding="utf-8")
        _git(fixture, "add", ".")
        _git(fixture, "commit", "--quiet", "-m", "fixture")
        head = _git(fixture, "rev-parse", "HEAD")
        record["binding_head_sha"] = head
        record["binding_tree_sha"] = _git(fixture, "rev-parse", "HEAD^{tree}")
        record["record_payload_sha256"] = convergence.sha256_bytes(
            convergence.canonical_bytes(convergence._record_payload(record))
        )
        record_path = fixture / convergence.RECORD_ROOT_REL / "batch-001" / "component.json"
        _write_json(record_path, record)
        manifest["binding_head_sha"] = head
        manifest["binding_tree_sha"] = record["binding_tree_sha"]
        manifest["record_bindings"][0]["record_payload_sha256"] = record["record_payload_sha256"]
        manifest["record_bindings"][0]["record_sha256"] = convergence.sha256_file(record_path)
        manifest["record_chain_terminal_sha256"] = record["record_payload_sha256"]
        failures, _ = convergence._validate_manifest_records_against_repo(
            fixture,
            manifest,
            evaluated_head=head,
            authorized_fingerprints={"historical": set(manifest["failure_fingerprints"]), "current": set()},
            authorized_identities={},
            legacy_fingerprints=set(),
        )
        _expect_failure(failures, "BATCH_RECORD_ACTUAL_CHAIN_BREAK")


def _copy_locked(root: Path, fixture: Path, relative: str) -> None:
    destination = fixture / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / relative, destination)


def _write_descendant_history_supplement_fixture(
    fixture: Path,
    baseline_report: dict[str, Any],
) -> dict[str, Any]:
    """Create one explicit sealed descendant-history edge in a temp clone."""

    _git(fixture, "config", "user.email", "selftest@example.invalid")
    _git(fixture, "config", "user.name", "V076 Selftest")
    old_commit = _git(fixture, "rev-parse", "HEAD")
    source_relative = "tools/v076/descendant_history_selftest_subject.txt"
    source_path = fixture / source_relative
    source_path.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_text("sealed descendant history source\n", encoding="utf-8")
    _git(fixture, "add", "--", source_relative)
    _git(fixture, "commit", "--quiet", "-m", "selftest descendant history edge")
    report_head = _git(fixture, "rev-parse", "HEAD")
    report_tree = _git(fixture, "rev-parse", "HEAD^{tree}")
    raw_failure = (
        "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:"
        f"{old_commit[:12]}->{report_head[:12]}:{source_relative}"
    )
    frozen_raw = [
        str(value)
        for value in baseline_report["failures"]
        if str(value).startswith("HISTORY_")
    ]
    final_report = copy.deepcopy(baseline_report)
    final_report.update({
        "status": "FAIL",
        "head_sha": report_head,
        "include_worktree": False,
        "evaluated_source": "COMMITTED_HEAD",
        "merge_base_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "failures": sorted(frozen_raw + [raw_failure]),
    })
    raw_report_relative = (
        convergence.EPOCH_ROOT_REL / "descendant_history_final_raw_report.json"
    )
    raw_report_path = fixture / raw_report_relative
    _write_json(raw_report_path, final_report)
    final_identities = convergence.authorized_failure_identity_by_fingerprint(
        final_report
    )
    descendant_fingerprint = next(
        fingerprint
        for fingerprint, identity in final_identities.items()
        if identity["raw_failure"] == raw_failure
    )
    frozen_sets = convergence.authorized_failure_fingerprint_sets(baseline_report)
    repaired = sorted(frozen_sets["current"])
    live_frozen = sorted(frozen_sets["historical"])
    baseline_scanner_bytes = convergence._git_bytes(
        fixture,
        convergence.AUTHORIZATION_BASE_HEAD_SHA,
        convergence.DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
    )
    _expect(baseline_scanner_bytes is not None, "baseline scanner missing")
    source_bytes = convergence._git_bytes(
        fixture, report_head, source_relative
    )
    _expect(source_bytes is not None, "descendant source blob missing")
    scanner_path = fixture / convergence.DESCENDANT_HISTORY_SCANNER_REL
    supplement = {
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "baseline_failure_set_sha256": convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,
        "baseline_historical_membership_policy": "LIVE_RAW_OR_EXACT_APPEND_ONLY_DISPOSITION",
        "baseline_report_sha256": convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
        "baseline_scanner_tool_sha256": convergence.sha256_bytes(
            baseline_scanner_bytes
        ),
        "committed_only": True,
        "correction_membership_scope": "LIVE_HISTORICAL_ONLY",
        "descendant_history_failure_count": 1,
        "descendant_history_fingerprint_set_sha256": convergence._line_set_sha([
            descendant_fingerprint
        ]),
        "descendant_history_fingerprints": [descendant_fingerprint],
        "directory_discovery_allowed": False,
        "disposition_wildcard_count": 0,
        "frozen_identity_disposition_by_failure": {},
        "future_failure_auto_membership_allowed": False,
        "identity_binding_by_failure": {
            descendant_fingerprint: {
                "failure_fingerprint": descendant_fingerprint,
                "raw_failure": raw_failure,
                "repaired_frozen_current_fingerprints": repaired,
                "rule_id": "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
                "source_blob_sha256": convergence.sha256_bytes(source_bytes),
                "source_commit_sha": report_head,
                "source_component_id": "",
                "source_path": source_relative,
                "transition_new_sha": report_head,
                "transition_old_sha": old_commit,
            }
        },
        "live_frozen_historical_failure_count": len(live_frozen),
        "live_frozen_historical_fingerprint_set_sha256": convergence._line_set_sha(
            live_frozen
        ),
        "live_frozen_historical_fingerprints": live_frozen,
        "missing_frozen_historical_failure_count": 0,
        "missing_frozen_historical_fingerprint_set_sha256": convergence._line_set_sha([]),
        "missing_frozen_historical_fingerprints": [],
        "raw_current_delta_failure_count": 0,
        "raw_failure_detection_suppressed_count": 0,
        "raw_failure_count": len(final_report["failures"]),
        "raw_historical_failure_count": len(final_report["failures"]),
        "raw_report_head_sha": report_head,
        "raw_report_path": raw_report_relative.as_posix(),
        "raw_report_sha256": convergence.sha256_file(raw_report_path),
        "raw_report_tree_sha": report_tree,
        "repaired_frozen_current_failure_count": len(repaired),
        "repaired_frozen_current_fingerprint_set_sha256": convergence._line_set_sha(
            repaired
        ),
        "repaired_frozen_current_fingerprints": repaired,
        "scanner_tool_path": convergence.DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
        "scanner_tool_sha256": convergence.sha256_file(scanner_path),
        "schema_version": convergence.DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION,
        "supplement_id": convergence.DESCENDANT_HISTORY_SUPPLEMENT_ID,
        "wildcard_membership_allowed": False,
    }
    supplement_relative = (
        convergence.EPOCH_ROOT_REL / "descendant_history_supplement.json"
    )
    supplement_path = fixture / supplement_relative
    _write_json(supplement_path, supplement)
    return {
        "descendant_fingerprint": descendant_fingerprint,
        "raw_report_path": raw_report_path,
        "report_head": report_head,
        "report_tree": report_tree,
        "scanner_path": scanner_path,
        "supplement": supplement,
        "supplement_path": supplement_path,
        "supplement_sha256": convergence.sha256_file(supplement_path),
    }


def _new_descendant_fixture(
    root: Path,
    fixture: Path,
) -> tuple[dict[str, Any], dict[str, Any]]:
    clone = subprocess.run(
        ["git", "clone", "--quiet", "--no-hardlinks", str(root), str(fixture)],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    _expect(clone.returncode == 0, clone.stderr)
    _copy_locked(root, fixture, convergence.SCHEMA_REL.as_posix())
    _copy_locked(root, fixture, convergence.BASELINE_REPORT_REL.as_posix())
    baseline_report = convergence.load_json_strict(
        fixture / convergence.BASELINE_REPORT_REL
    )
    supplement_fixture = _write_descendant_history_supplement_fixture(
        fixture, baseline_report
    )
    return baseline_report, supplement_fixture


def _descendant_supplement_primary_positive_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-descendant-positive-") as temporary:
        fixture = Path(temporary)
        _, sealed = _new_descendant_fixture(root, fixture)
        result = convergence.validate_descendant_history_supplement(
            fixture,
            sealed["supplement_path"],
            sealed["raw_report_path"],
            sealed["scanner_path"],
            evaluated_head=sealed["report_head"],
            baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
        )
        _expect(result["status"] == "PASS", str(result["failures"]))
        _expect(
            sealed["descendant_fingerprint"]
            in result["authorized_historical_fingerprints"],
            "exact descendant membership not included in live authority",
        )
        _expect(
            len(result["authorized_historical_fingerprints"])
            == convergence.AUTHORIZED_BASELINE_HISTORICAL_COUNT + 1,
            "live historical correction authority count drifted",
        )
        _expect(
            not result["dispositioned_historical_fingerprints"],
            "fixture without missing frozen identities produced a disposition",
        )


def _descendant_supplement_current_and_future_negative_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-descendant-current-") as temporary:
        fixture = Path(temporary)
        baseline_report, sealed = _new_descendant_fixture(root, fixture)
        raw_report = convergence.load_json_strict(sealed["raw_report_path"])
        frozen_current_raw = next(
            str(value)
            for value in baseline_report["failures"]
            if not str(value).startswith("HISTORY_")
        )
        raw_report["failures"] = sorted(raw_report["failures"] + [frozen_current_raw])
        _write_json(sealed["raw_report_path"], raw_report)
        supplement = copy.deepcopy(sealed["supplement"])
        supplement["raw_report_sha256"] = convergence.sha256_file(
            sealed["raw_report_path"]
        )
        supplement["raw_failure_count"] += 1
        supplement["raw_current_delta_failure_count"] = 1
        _write_json(sealed["supplement_path"], supplement)
        result = convergence.validate_descendant_history_supplement(
            fixture,
            sealed["supplement_path"],
            sealed["raw_report_path"],
            sealed["scanner_path"],
            evaluated_head=sealed["report_head"],
            baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
        )
        _expect_failure(
            result["failures"],
            "DESCENDANT_HISTORY_FINAL_CURRENT_FAILURE_COUNT_NOT_ZERO",
        )
        # A later raw HISTORY row is not inherited automatically from the
        # earlier seal, even if it resembles the same rule and transition.
        raw_report["failures"] = [
            value for value in raw_report["failures"] if value != frozen_current_raw
        ]
        raw_report["failures"].append(
            "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:"
            f"{sealed['supplement']['identity_binding_by_failure'][sealed['descendant_fingerprint']]['transition_old_sha'][:12]}"
            f"->{sealed['report_head'][:12]}:tools/v076/unsealed_future_subject.txt"
        )
        raw_report["failures"] = sorted(raw_report["failures"])
        _write_json(sealed["raw_report_path"], raw_report)
        supplement = copy.deepcopy(sealed["supplement"])
        supplement["raw_report_sha256"] = convergence.sha256_file(
            sealed["raw_report_path"]
        )
        supplement["raw_failure_count"] += 1
        supplement["raw_historical_failure_count"] += 1
        _write_json(sealed["supplement_path"], supplement)
        result = convergence.validate_descendant_history_supplement(
            fixture,
            sealed["supplement_path"],
            sealed["raw_report_path"],
            sealed["scanner_path"],
            evaluated_head=sealed["report_head"],
            baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
        )
        _expect_failure(
            result["failures"],
            "DESCENDANT_HISTORY_FINGERPRINT_MEMBERSHIP_MISMATCH",
        )


def _descendant_supplement_binding_negative_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-descendant-binding-") as temporary:
        fixture = Path(temporary)
        baseline_report, sealed = _new_descendant_fixture(root, fixture)
        missing = convergence.validate_descendant_history_supplement(
            fixture,
            None,
            None,
            None,
            evaluated_head=sealed["report_head"],
            baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
        )
        _expect_failure(missing["failures"], "DESCENDANT_HISTORY_SUPPLEMENT_REQUIRED")
        supplement = copy.deepcopy(sealed["supplement"])
        supplement["identity_binding_by_failure"][sealed["descendant_fingerprint"]][
            "source_blob_sha256"
        ] = "0" * 64
        _write_json(sealed["supplement_path"], supplement)
        primary = convergence.validate_descendant_history_supplement(
            fixture,
            sealed["supplement_path"],
            sealed["raw_report_path"],
            sealed["scanner_path"],
            evaluated_head=sealed["report_head"],
            baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
        )
        _expect_failure(
            primary["failures"],
            "DESCENDANT_HISTORY_SOURCE_BLOB_MISMATCH",
        )
        baseline_sets = convergence.authorized_failure_fingerprint_sets(
            baseline_report
        )
        independent_findings, _, _, _, _, _ = (
            independent_audit._descendant_history_supplement_findings(
                fixture,
                supplement_path=sealed["supplement_path"],
                raw_report_path=sealed["raw_report_path"],
                scanner_path=sealed["scanner_path"],
                evaluated_head=sealed["report_head"],
                baseline_report=baseline_report,
                baseline_sets=baseline_sets,
            )
        )
        _expect(
            any(
                item["code"]
                == "FULL_CONVERGENCE_DESCENDANT_HISTORY_SOURCE_BLOB_MISMATCH"
                for item in independent_findings
            ),
            json.dumps(independent_findings, sort_keys=True),
        )


def _independent_audit_fixture_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-independent-") as temporary:
        fixture = Path(temporary)
        clone = subprocess.run(
            ["git", "clone", "--quiet", "--no-hardlinks", str(root), str(fixture)],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        _expect(clone.returncode == 0, clone.stderr)
        # The epoch schema/baseline may intentionally still be task-owned;
        # copy only these explicitly named byte-locked authority artifacts.
        _copy_locked(root, fixture, convergence.SCHEMA_REL.as_posix())
        _copy_locked(root, fixture, convergence.BASELINE_REPORT_REL.as_posix())
        baseline_report = convergence.load_json_strict(root / convergence.BASELINE_REPORT_REL)
        supplement_fixture = _write_descendant_history_supplement_fixture(
            fixture, baseline_report
        )
        head = supplement_fixture["report_head"]
        tree = supplement_fixture["report_tree"]
        baseline_identities = convergence.authorized_failure_identity_by_fingerprint(
            baseline_report
        )
        registry_bytes = convergence._git_bytes(
            fixture,
            head,
            convergence.AUTHORITY_SOURCE_PATHS[0],
        )
        _expect(registry_bytes is not None, "fixture Registry is missing")
        registry_payload = json.loads(registry_bytes.decode("utf-8-sig"))
        registry_rows = [
            row
            for key in ("component_inventory", "historical_identity_backfill")
            for row in (
                registry_payload.get(key, [])
                if isinstance(registry_payload.get(key, []), list)
                else []
            )
            if isinstance(row, dict)
        ]
        candidates: dict[str, tuple[dict[str, Any], dict[str, Any]]] = {}
        selected_component_ids: set[str] = set()
        for fingerprint, identity in sorted(baseline_identities.items()):
            if (
                identity.get("bucket") != "HISTORICAL"
                or identity.get("rule_id") != "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
                or identity.get("subject_kind") != "path"
            ):
                continue
            source_commit = convergence._resolve_commit_prefix(
                fixture, identity.get("transition_new_prefix", "")
            )
            old_commit = convergence._resolve_commit_prefix(
                fixture, identity.get("transition_old_prefix", "")
            )
            subject_path = convergence.normalize_path(identity.get("subject_value", ""))
            component_rows = [
                row
                for row in registry_rows
                if convergence.normalize_path(str(row.get("path", "")))
                == subject_path
            ]
            if len(component_rows) != 1:
                continue
            component_row = component_rows[0]
            component_id = str(component_row.get("component_id", ""))
            owner_id = str(component_row.get("owner_component_id", ""))
            owner_rows = [
                row
                for row in registry_rows
                if str(row.get("component_id", "")) == owner_id
                and row.get("component_role") == "OWNER"
                and row.get("owner_component_id") == owner_id
                and row.get("domain_id") == component_row.get("domain_id")
            ]
            if (
                not source_commit
                or not old_commit
                or _git(fixture, "rev-parse", f"{source_commit}^1") != old_commit
                or convergence._git_bytes(fixture, source_commit, subject_path) is None
                or convergence._git_bytes(fixture, head, subject_path) is None
                or not component_id
                or component_id in selected_component_ids
                or component_row.get("production_reachable") is not True
                or len(owner_rows) != 1
            ):
                continue
            candidates[fingerprint] = (component_row, owner_rows[0])
            selected_component_ids.add(component_id)
            if len(candidates) == 25:
                break
        _expect(len(candidates) == 25, f"only {len(candidates)} exact fixture identities")
        fingerprints = sorted(candidates)
        fixture_baseline_sha = convergence.sha256_file(
            fixture / convergence.BASELINE_REPORT_REL
        )
        record = _record(fingerprints)
        record["binding_head_sha"] = head
        record["binding_tree_sha"] = tree
        record["baseline_report_sha256"] = fixture_baseline_sha
        record["descendant_history_supplement_sha256"] = supplement_fixture[
            "supplement_sha256"
        ]
        manifest = _batch()
        manifest["binding_head_sha"] = head
        manifest["binding_tree_sha"] = tree
        manifest["baseline_report_sha256"] = fixture_baseline_sha
        manifest["descendant_history_supplement_sha256"] = supplement_fixture[
            "supplement_sha256"
        ]
        manifest["failure_fingerprints"] = fingerprints
        manifest["failure_count"] = len(fingerprints)
        manifest["failure_fingerprint_set_sha256"] = convergence._line_set_sha(
            fingerprints
        )
        manifest_path = fixture / "batch-001-manifest.json"
        _write_batch_artifacts(
            manifest_path.parent,
            manifest,
            baseline_identities,
        )
        identity_bindings: dict[str, dict[str, Any]] = {}
        for fingerprint in fingerprints:
            identity = baseline_identities[fingerprint]
            component_row, owner_row = candidates[fingerprint]
            source_commit = convergence._resolve_commit_prefix(
                fixture, identity["transition_new_prefix"]
            )
            subject_path = convergence.normalize_path(identity["subject_value"])
            component_id = str(component_row["component_id"])
            owner_id = str(component_row["owner_component_id"])
            domain_id = str(component_row["domain_id"])
            component_role = str(component_row["component_role"])
            historical_bytes = convergence._git_bytes(
                fixture, source_commit, subject_path
            )
            current_bytes = convergence._git_bytes(fixture, head, subject_path)
            _expect(historical_bytes is not None, f"missing source blob {subject_path}")
            _expect(current_bytes is not None, f"missing current blob {subject_path}")
            selector = {
                "component_ids": sorted({component_id, owner_id}),
                "dynamic_reference_ids": [],
                "paths": [subject_path],
                "retirement_ids": [],
                "supersession_ids": [],
            }
            projection = independent_audit._subject_projection(
                fixture, head, selector
            )
            _expect(isinstance(projection, dict), "fixture subject projection unresolved")
            identity_bindings[fingerprint] = {
                "authority_selectors": selector,
                "current_blob_sha256": convergence.sha256_bytes(current_bytes),
                "current_component_id": component_id,
                "domain_id": domain_id,
                "current_owner_id": owner_id,
                "current_path": subject_path,
                "current_production_reachability": "PRODUCTION_REACHABLE",
                "current_role": component_role,
                "diagnostic_only_status": "NOT_DIAGNOSTIC_ONLY",
                "documentation_only_status": "NOT_DOCUMENTATION_ONLY",
                "dynamic_reference_status": "NOT_DYNAMIC_REFERENCE",
                "duplicate_identity_sha256": "",
                "duplicate_of_failure_fingerprint": "",
                "duplicate_reason": "",
                "generated_evidence_status": "NOT_GENERATED_EVIDENCE",
                "first_seen_commit": source_commit,
                "historical_blob_sha256": convergence.sha256_bytes(historical_bytes),
                "historical_component_id": component_id,
                "historical_owner_id": owner_id,
                "historical_path": subject_path,
                "historical_production_reachability": "PRODUCTION_REACHABLE",
                "historical_role": component_role,
                "invalidation_policy": _touch_policy(),
                "recommended_disposition": "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
                "retired_status": "ACTIVE_LINEAGE",
                "subject_projection": projection,
                "subject_projection_sha256": convergence.sha256_bytes(
                    convergence.canonical_bytes(projection)
                ),
                "source_commit": source_commit,
                "superseded_by": list(component_row.get("superseded_by", [])),
                "supersedes": list(component_row.get("supersedes", [])),
                "test_only_status": "NOT_TEST_ONLY",
                "last_seen_commit": convergence.AUTHORIZATION_BASE_HEAD_SHA,
            }
        record["identity_binding_by_failure"] = identity_bindings
        record["paths"] = sorted({
            value
            for binding in identity_bindings.values()
            for value in (binding["historical_path"], binding["current_path"])
            if value
        })
        record["path_set_sha256"] = convergence._line_set_sha(record["paths"])
        record["component_ids"] = sorted({
            binding["current_component_id"] for binding in identity_bindings.values()
        })
        record["component_set_sha256"] = convergence._line_set_sha(
            record["component_ids"]
        )
        record["domain_ids"] = sorted({
            binding["domain_id"] for binding in identity_bindings.values()
        })
        record["domain_set_sha256"] = convergence._line_set_sha(record["domain_ids"])
        record["dynamic_reference_ids"] = []
        record["dynamic_reference_set_sha256"] = convergence._line_set_sha([])
        record["owner_ids"] = sorted({
            binding["current_owner_id"] for binding in identity_bindings.values()
        })
        record["owner_set_sha256"] = convergence._line_set_sha(record["owner_ids"])
        record["supersession_ids"] = []
        record["supersession_set_sha256"] = convergence._line_set_sha([])
        record["retirement_ids"] = []
        record["retirement_set_sha256"] = convergence._line_set_sha([])
        record["source_commit_set"] = sorted({
            binding["source_commit"] for binding in identity_bindings.values()
        })
        record["source_commit_set_sha256"] = convergence._line_set_sha(
            record["source_commit_set"]
        )
        record["authority_source_sha256"] = {
            relative: convergence.sha256_bytes(
                convergence._git_bytes(fixture, head, relative) or b""
            )
            for relative in convergence.AUTHORITY_SOURCE_PATHS
        }
        for hash_field in convergence.BATCH_ARTIFACT_SPECS:
            record[hash_field] = manifest[hash_field]
        record["record_payload_sha256"] = convergence.sha256_bytes(
            convergence.canonical_bytes(convergence._record_payload(record))
        )
        record_path = (
            fixture
            / convergence.RECORD_ROOT_REL
            / "batch-001"
            / "component.json"
        )
        _write_json(record_path, record)
        manifest["record_bindings"][0].update({
            "failure_fingerprints": fingerprints,
            "record_payload_sha256": record["record_payload_sha256"],
            "record_sha256": convergence.sha256_file(record_path),
        })
        manifest["record_chain_terminal_sha256"] = record["record_payload_sha256"]
        _write_json(manifest_path, manifest)
        original_baseline_sha = independent_audit.FULL_CONVERGENCE_BASELINE_SHA
        independent_audit.FULL_CONVERGENCE_BASELINE_SHA = fixture_baseline_sha
        try:
            report = independent_audit.audit_full_convergence_batch(
                fixture,
                manifest_path,
                evaluated_head=head,
                baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
                descendant_history_supplement_path=supplement_fixture[
                    "supplement_path"
                ],
                descendant_history_raw_report_path=supplement_fixture[
                    "raw_report_path"
                ],
                descendant_history_scanner_path=supplement_fixture[
                    "scanner_path"
                ],
            )
            _expect(report["status"] == "GO", json.dumps(report, sort_keys=True))

            # Rehash every byte/chain binding after injecting extra authority
            # and schema fields.  Only exact closed-contract checks should
            # reject this otherwise internally consistent mutation.
            record["schema_version"] = (
                convergence.SCHEMA_VERSION + ".unexpected"
            )
            record["unexpected_selector"] = {"paths": ["*"]}
            record["record_payload_sha256"] = convergence.sha256_bytes(
                convergence.canonical_bytes(convergence._record_payload(record))
            )
            _write_json(record_path, record)
            manifest["record_bindings"][0].update({
                "record_payload_sha256": record["record_payload_sha256"],
                "record_sha256": convergence.sha256_file(record_path),
            })
            manifest["record_chain_terminal_sha256"] = record[
                "record_payload_sha256"
            ]
            manifest["schema_version"] = (
                convergence.BATCH_MANIFEST_SCHEMA_VERSION + ".unexpected"
            )
            manifest["unexpected_future_policy"] = {
                "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 1
            }
            _write_json(manifest_path, manifest)
            negative_report = independent_audit.audit_full_convergence_batch(
                fixture,
                manifest_path,
                evaluated_head=head,
                baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
                descendant_history_supplement_path=supplement_fixture[
                    "supplement_path"
                ],
                descendant_history_raw_report_path=supplement_fixture[
                    "raw_report_path"
                ],
                descendant_history_scanner_path=supplement_fixture[
                    "scanner_path"
                ],
            )
            negative_codes = {
                item["code"]
                for bucket in ("p0", "p1")
                for item in negative_report.get(bucket, [])
            }
            _expect(negative_report["status"] == "NO_GO", json.dumps(
                negative_report, sort_keys=True
            ))
            for expected_code in (
                "FULL_CONVERGENCE_BATCH_MANIFEST_FIELD_SET_INVALID",
                "FULL_CONVERGENCE_BATCH_MANIFEST_SCHEMA_VERSION_INVALID",
                "FULL_CONVERGENCE_RECORD_FIELD_SET_INVALID",
                "FULL_CONVERGENCE_RECORD_SCHEMA_VERSION_INVALID",
            ):
                _expect(
                    expected_code in negative_codes,
                    json.dumps(negative_report, sort_keys=True),
                )
        finally:
            independent_audit.FULL_CONVERGENCE_BASELINE_SHA = original_baseline_sha


def _non_object_documents_fail_closed_case(root: Path) -> None:
    _expect_failure(
        convergence.validate_extension_record_against_repo(
            root,
            [],
            evaluated_head=_git(root, "rev-parse", "HEAD"),
        ),
        "EXTENSION_RECORD_NOT_OBJECT",
    )
    manifest = _batch()
    manifest["previous_batch_append_sha256"] = "a" * 64
    with tempfile.TemporaryDirectory(prefix="v076-fc-non-object-") as temporary:
        non_object_path = Path(temporary) / "non-object.json"
        _write_json(non_object_path, [])
        _expect_failure(
            convergence.validate_previous_batch_link(manifest, non_object_path),
            "BATCH_PREVIOUS_MANIFEST_NOT_OBJECT",
        )
        result = convergence.validate_batch_manifest_against_repo(
            root,
            non_object_path,
            evaluated_head=_git(root, "rev-parse", "HEAD"),
            baseline_report_path=root / convergence.BASELINE_REPORT_REL,
        )
        _expect_failure(result["failures"], "BATCH_MANIFEST_NOT_OBJECT")


def _effective_all_or_none_case(root: Path) -> None:
    try:
        legacy_resolver.validate_records(
            root,
            root,
            current_head=_git(root, "rev-parse", "HEAD"),
            full_convergence_baseline_report_path=(
                root / convergence.BASELINE_REPORT_REL
            ),
        )
    except ValueError as exc:
        _expect(
            str(exc) == "FULL_CONVERGENCE_EXPLICIT_INPUT_SET_INCOMPLETE",
            str(exc),
        )
        return
    raise AssertionError("partial full-convergence input set was accepted")


def _effective_terminal_coverage_case() -> None:
    authorized = {"h1", "h2", "h3"}
    legacy = {"h1"}
    _expect(
        not legacy_resolver._full_convergence_terminal_coverage_failures(
            authorized_historical=authorized,
            legacy_exact=legacy,
            full_fingerprints={"h2", "h3"},
            terminal=True,
        ),
        "exact terminal coverage was rejected",
    )
    nonterminal = legacy_resolver._full_convergence_terminal_coverage_failures(
        authorized_historical=authorized,
        legacy_exact=legacy,
        full_fingerprints={"h2", "h3"},
        terminal=False,
    )
    _expect_failure(nonterminal, "EFFECTIVE_TERMINAL_BATCH_FLAG_REQUIRED")
    partial = legacy_resolver._full_convergence_terminal_coverage_failures(
        authorized_historical=authorized,
        legacy_exact=legacy,
        full_fingerprints={"h2"},
        terminal=True,
    )
    _expect_failure(partial, "EFFECTIVE_FULL_CONVERGENCE_COVERAGE_MISSING:1")


def _historical_delta_metadata_input_coupling_case(root: Path) -> None:
    parsed = legacy_resolver._parser().parse_args([
        "resolve",
        "--historical-delta-metadata-ledger",
        "explicit-ledger.json",
    ])
    _expect(
        parsed.historical_delta_metadata_ledger == Path("explicit-ledger.json"),
        str(parsed),
    )
    try:
        legacy_resolver.validate_records(
            root,
            root,
            current_head=_git(root, "rev-parse", "HEAD"),
            historical_delta_metadata_ledger_path=(
                root / "docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json"
            ),
        )
    except ValueError as exc:
        _expect(
            str(exc)
            == "HISTORICAL_DELTA_METADATA_LEDGER_REQUIRES_FULL_CONVERGENCE_INPUT_SET",
            str(exc),
        )
        return
    raise AssertionError("standalone historical Delta metadata ledger was accepted")


def _subject_projection_cli_and_input_coupling_case(root: Path) -> None:
    sidecar = Path("subject-projection-revalidation.json")
    successor = Path("subject-projection-revalidation-successor-v2.json")
    ledger = Path("historical-delta-metadata-ledger.json")
    parsed = legacy_resolver._parser().parse_args([
        "resolve",
        "--subject-projection-revalidation",
        str(sidecar),
        "--subject-projection-revalidation-successor-v2",
        str(successor),
        "--historical-delta-metadata-ledger",
        str(ledger),
    ])
    _expect(parsed.subject_projection_revalidation == sidecar, str(parsed))
    _expect(
        parsed.subject_projection_revalidation_successor_v2 == successor,
        str(parsed),
    )
    _expect(parsed.historical_delta_metadata_ledger == ledger, str(parsed))

    current_head = _git(root, "rev-parse", "HEAD")
    for lone_kwargs in (
        {"subject_projection_revalidation_path": root / sidecar},
        {
            "subject_projection_revalidation_successor_v2_path": (
                root / successor
            )
        },
    ):
        try:
            legacy_resolver.validate_records(
                root,
                root,
                current_head=current_head,
                **lone_kwargs,
            )
        except ValueError as exc:
            _expect(
                str(exc)
                == "SUBJECT_PROJECTION_REVALIDATION_EPOCH_PAIR_REQUIRED",
                str(exc),
            )
        else:
            raise AssertionError("one-sided subject-projection epoch was accepted")

    for lone_cli in (
        ["--subject-projection-revalidation", str(root / sidecar)],
        [
            "--subject-projection-revalidation-successor-v2",
            str(root / successor),
        ],
    ):
        try:
            legacy_resolver.main([
                "resolve",
                "--project", str(root),
                "--head-ref", "HEAD",
                *lone_cli,
            ])
        except SystemExit as exc:
            _expect(
                str(exc) == (
                    "--subject-projection-revalidation and "
                    "--subject-projection-revalidation-successor-v2 must be "
                    "supplied together"
                ),
                str(exc),
            )
        else:
            raise AssertionError("resolver CLI accepted a one-sided epoch")

    try:
        legacy_resolver.validate_records(
            root,
            root,
            current_head=current_head,
            subject_projection_revalidation_path=root / sidecar,
            subject_projection_revalidation_successor_v2_path=root / successor,
        )
    except ValueError as exc:
        _expect(
            str(exc)
            == "SUBJECT_PROJECTION_REVALIDATION_REQUIRES_FULL_CONVERGENCE_INPUT_SET",
            str(exc),
        )
    else:
        raise AssertionError("standalone subject-projection sidecar was accepted")

    complete_full_convergence_inputs = {
        "full_convergence_baseline_report_path": root / "baseline.json",
        "full_convergence_batch_manifest_path": root / "batch.json",
        "full_convergence_previous_batch_manifest_path": root / "previous.json",
        "descendant_history_supplement_path": root / "supplement.json",
        "descendant_history_raw_report_path": root / "descendant-raw.json",
        "descendant_history_scanner_path": root / "scanner.py",
    }
    try:
        legacy_resolver.validate_records(
            root,
            root,
            current_head=current_head,
            subject_projection_revalidation_path=root / sidecar,
            subject_projection_revalidation_successor_v2_path=root / successor,
            **complete_full_convergence_inputs,
        )
    except ValueError as exc:
        _expect(
            str(exc)
            == "SUBJECT_PROJECTION_REVALIDATION_REQUIRES_HISTORICAL_DELTA_METADATA_LEDGER",
            str(exc),
        )
    else:
        raise AssertionError("subject-projection sidecar without HDM ledger was accepted")

    verify_args = [
        "verify-full-convergence-batch",
        "--project", str(root),
        "--head-ref", "HEAD",
        "--full-convergence-baseline-report", "baseline.json",
        "--batch-manifest", "batch.json",
        "--previous-batch-manifest", "previous.json",
        "--descendant-history-supplement", "supplement.json",
        "--descendant-history-raw-report", "descendant-raw.json",
        "--descendant-history-scanner", "scanner.py",
        "--subject-projection-revalidation", str(root / sidecar),
        "--subject-projection-revalidation-successor-v2", str(root / successor),
    ]
    try:
        legacy_resolver.main(verify_args)
    except SystemExit as exc:
        _expect(
            str(exc)
            == (
                "verify-full-convergence-batch with "
                "--subject-projection-revalidation requires "
                "--historical-delta-metadata-ledger"
            ),
            str(exc),
        )
    else:
        raise AssertionError("verify CLI accepted subject-projection sidecar without ledger")

    original_batch_validator = convergence.validate_batch_manifest_against_repo
    captured_verify: dict[str, Any] = {}

    def batch_validator_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
        captured_verify.update(kwargs)
        return {"status": "PASS", "failures": []}

    convergence.validate_batch_manifest_against_repo = batch_validator_stub
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            exit_code = legacy_resolver.main(
                verify_args
                + ["--historical-delta-metadata-ledger", str(root / ledger)]
            )
    finally:
        convergence.validate_batch_manifest_against_repo = original_batch_validator
    _expect(exit_code == 0, f"verify CLI exit={exit_code}")
    _expect(
        captured_verify.get("subject_projection_revalidation_path")
        == (root / sidecar).resolve(),
        str(captured_verify),
    )
    _expect(
        captured_verify.get(
            "subject_projection_revalidation_successor_v2_path"
        ) == (root / successor).resolve(),
        str(captured_verify),
    )
    _expect(
        captured_verify.get("historical_delta_metadata_ledger_path")
        == (root / ledger).resolve(),
        str(captured_verify),
    )

    original_resolve_command = legacy_resolver.resolve_command
    captured_resolve: dict[str, Any] = {}

    def resolve_stub(*args: Any, **kwargs: Any) -> int:
        captured_resolve.update(kwargs)
        return 0

    legacy_resolver.resolve_command = resolve_stub
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            exit_code = legacy_resolver.main([
                "resolve",
                "--project", str(root),
                "--head-ref", "HEAD",
                "--raw-report", "live-raw.json",
                "--full-convergence-baseline-report", "baseline.json",
                "--batch-manifest", "batch.json",
                "--previous-batch-manifest", "previous.json",
                "--descendant-history-supplement", "supplement.json",
                "--descendant-history-raw-report", "descendant-raw.json",
                "--descendant-history-scanner", "scanner.py",
                "--subject-projection-revalidation", str(root / sidecar),
                "--subject-projection-revalidation-successor-v2",
                str(root / successor),
                "--historical-delta-metadata-ledger", str(root / ledger),
            ])
    finally:
        legacy_resolver.resolve_command = original_resolve_command
    _expect(exit_code == 0, f"resolve CLI exit={exit_code}")
    _expect(
        captured_resolve.get("subject_projection_revalidation_path")
        == (root / sidecar).resolve(),
        str(captured_resolve),
    )
    _expect(
        captured_resolve.get(
            "subject_projection_revalidation_successor_v2_path"
        ) == (root / successor).resolve(),
        str(captured_resolve),
    )
    _expect(
        captured_resolve.get("historical_delta_metadata_ledger_path")
        == (root / ledger).resolve(),
        str(captured_resolve),
    )


def _full_convergence_pr_body_input_coupling_case(root: Path) -> None:
    parsed = legacy_resolver._parser().parse_args([
        "resolve", "--full-convergence-pr-body-file", "pr-body.md",
    ])
    _expect(
        parsed.full_convergence_pr_body_file == Path("pr-body.md"),
        str(parsed),
    )
    try:
        legacy_resolver.validate_records(
            root,
            root,
            current_head=_git(root, "rev-parse", "HEAD"),
            full_convergence_pr_body_file_path=root / "pr-body.md",
        )
    except ValueError as exc:
        _expect(
            str(exc)
            == "FULL_CONVERGENCE_PR_BODY_FILE_REQUIRES_FULL_CONVERGENCE_INPUT_SET",
            str(exc),
        )
        return
    raise AssertionError("standalone full-convergence PR body was ignored")


def _historical_delta_metadata_dual_gate_case(root: Path) -> None:
    import v076_historical_delta_metadata_independent_audit as ledger_independent
    import v076_historical_delta_metadata_ledger as ledger_primary

    fingerprints = [_fingerprint(1000 + index) for index in range(86)]
    identities = {
        fingerprint: {
            "failure_fingerprint": fingerprint,
            "raw_failure": f"LEDGER_SELFTEST_RAW:{index}",
            "rule_id": "NEW_COMPONENT_CANNOT_CLAIM_INHERITED",
            "component_id": f"component.ledger.selftest.{index % 82:03d}",
        }
        for index, fingerprint in enumerate(fingerprints)
    }
    evaluated_head = _git(root, "rev-parse", "HEAD")
    primary_projection: dict[str, Any] = {
        "status": "PASS",
        "failures": [],
        "ledger_path": (
            "docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json"
        ),
        "ledger_sha256": "1" * 64,
        "raw_report_sha256": "2" * 64,
        "raw_report_head_sha": evaluated_head,
        "raw_failure_count": 590,
        "semantic_historical_failure_count": 587,
        "true_current_failure_count": 3,
        "metadata_record_count": 3,
        "correction_record_count": 4,
        "authorized_historical_fingerprints": fingerprints,
        "authorized_identity_by_fingerprint": identities,
        "verified_historical_fingerprints": fingerprints,
        "record_summaries": [
            {
                "correction_id": "ledger-correction-001",
                "path": (
                    "docs/architecture/reuse_corrections/v2/records/"
                    "historical_delta_metadata/ledger-correction-001.json"
                ),
                "failure_fingerprints": fingerprints[:43],
            },
            {
                "correction_id": "ledger-correction-002",
                "path": (
                    "docs/architecture/reuse_corrections/v2/records/"
                    "historical_delta_metadata/ledger-correction-002.json"
                ),
                "failure_fingerprints": fingerprints[43:],
            },
        ],
    }
    mode = {"primary": "PASS", "independent": "GO"}
    original_primary = ledger_primary.validate_ledger
    original_independent = ledger_independent.audit_ledger
    original_independent_projection = (
        convergence._independent_historical_delta_metadata_authority_projection
    )

    def primary_stub(
        stub_root: Path,
        stub_path: Path,
        **kwargs: Any,
    ) -> dict[str, Any]:
        _expect(stub_root == root, str(stub_root))
        _expect(stub_path.name == "explicit-ledger.json", str(stub_path))
        _expect(set(kwargs) == {"evaluated_head"}, str(kwargs))
        result = copy.deepcopy(primary_projection)
        if mode["primary"] != "PASS":
            result["status"] = "FAIL"
            result["failures"] = ["PRIMARY_SELFTEST_FAILURE"]
        return result

    def independent_stub(
        stub_root: Path,
        stub_path: Path,
        **kwargs: Any,
    ) -> dict[str, Any]:
        _expect(stub_root == root, str(stub_root))
        _expect(stub_path.name == "explicit-ledger.json", str(stub_path))
        _expect(
            set(kwargs) == {"evaluated_head", "primary_projection"},
            str(kwargs),
        )
        return {
            "status": mode["independent"],
            "failures": (
                [] if mode["independent"] == "GO"
                else ["INDEPENDENT_SELFTEST_FAILURE"]
            ),
            "primary_projection_digest_match": mode["independent"] == "GO",
            "authorized_failure_count": 86,
            "verified_failure_count": 86,
            "component_count": 82,
        }

    ledger_primary.validate_ledger = primary_stub
    ledger_independent.audit_ledger = independent_stub
    convergence._independent_historical_delta_metadata_authority_projection = (
        lambda *args, **kwargs: (
            convergence._primary_historical_delta_metadata_authority_projection(
                root,
                primary_projection,
                evaluated_head=evaluated_head,
            )
        )
    )
    ledger_path = root / "explicit-ledger.json"
    try:
        not_provided = (
            convergence.validate_historical_delta_metadata_ledger_authority(
                root,
                None,
                evaluated_head=evaluated_head,
            )
        )
        _expect(not_provided["status"] == "NOT_PROVIDED", str(not_provided))
        _expect(not_provided["authorized_historical_fingerprints"] == [], str(not_provided))

        accepted = convergence.validate_historical_delta_metadata_ledger_authority(
            root,
            ledger_path,
            evaluated_head=evaluated_head,
        )
        _expect(accepted["status"] == "PASS", json.dumps(accepted, sort_keys=True))
        _expect(accepted["authorized_failure_count"] == 86, str(accepted))
        _expect(accepted["verified_failure_count"] == 86, str(accepted))
        _expect(accepted["metadata_record_count"] == 3, str(accepted))
        _expect(accepted["correction_record_count"] == 4, str(accepted))
        _expect(accepted["component_count"] == 82, str(accepted))
        _expect(set(accepted["authorized_identity_by_fingerprint"]) == set(fingerprints), str(accepted))

        mode["primary"] = "FAIL"
        primary_failed = convergence.validate_historical_delta_metadata_ledger_authority(
            root,
            ledger_path,
            evaluated_head=evaluated_head,
        )
        _expect(primary_failed["status"] == "FAIL", str(primary_failed))
        _expect(primary_failed["authorized_historical_fingerprints"] == [], str(primary_failed))
        _expect(primary_failed["authorized_identity_by_fingerprint"] == {}, str(primary_failed))

        mode["primary"] = "PASS"
        mode["independent"] = "NO_GO"
        independent_failed = (
            convergence.validate_historical_delta_metadata_ledger_authority(
                root,
                ledger_path,
                evaluated_head=evaluated_head,
            )
        )
        _expect(independent_failed["status"] == "FAIL", str(independent_failed))
        _expect(independent_failed["verified_historical_fingerprints"] == [], str(independent_failed))
        _expect(independent_failed["record_summaries"] == [], str(independent_failed))
    finally:
        ledger_primary.validate_ledger = original_primary
        ledger_independent.audit_ledger = original_independent
        convergence._independent_historical_delta_metadata_authority_projection = (
            original_independent_projection
        )


def _historical_delta_metadata_collision_case() -> None:
    legacy_fingerprint = _fingerprint(2000)
    batch_fingerprint = _fingerprint(2001)
    legacy_id = "legacy-correction-id"
    batch_id = "batch-correction-id"
    legacy_path = "docs/architecture/reuse_corrections/v2/records/legacy.json"
    batch_path = (
        "docs/architecture/reuse_corrections/v2/records/"
        "full_convergence_20260827/batch-001/batch.json"
    )
    authority = {
        "status": "PASS",
        "authorized_historical_fingerprints": [
            legacy_fingerprint,
            batch_fingerprint,
        ],
        "record_summaries": [
            {
                "correction_id": legacy_id,
                "path": legacy_path,
                "failure_fingerprints": [legacy_fingerprint],
            },
            {
                "correction_id": batch_id,
                "path": batch_path,
                "failure_fingerprints": [batch_fingerprint],
            },
        ],
    }
    legacy = {
        "legacy_corrected_fingerprints": [legacy_fingerprint],
        "legacy_correction_ids": [legacy_id],
        "legacy_record_paths": [legacy_path],
    }
    batch = {
        "failure_fingerprints": [batch_fingerprint],
        "record_bindings": [
            {"correction_id": batch_id, "path": batch_path}
        ],
    }
    failures = convergence._historical_delta_metadata_ledger_collision_failures(
        authority,
        legacy=legacy,
        batch_chain=[(Path(batch_path), batch)],
    )
    for prefix in (
        "HISTORICAL_DELTA_METADATA_LEDGER_LEGACY_FINGERPRINT_COLLISION",
        "HISTORICAL_DELTA_METADATA_LEDGER_BATCH_FINGERPRINT_COLLISION",
        "HISTORICAL_DELTA_METADATA_LEDGER_LEGACY_CORRECTION_ID_COLLISION",
        "HISTORICAL_DELTA_METADATA_LEDGER_BATCH_CORRECTION_ID_COLLISION",
        "HISTORICAL_DELTA_METADATA_LEDGER_LEGACY_RECORD_PATH_COLLISION",
        "HISTORICAL_DELTA_METADATA_LEDGER_BATCH_RECORD_PATH_COLLISION",
    ):
        _expect_failure(failures, prefix)


def _historical_delta_metadata_set_algebra_and_raw_case() -> None:
    supplement_fingerprints = {
        _fingerprint(3000 + index) for index in range(501)
    }
    legacy_fingerprints = set(sorted(supplement_fingerprints)[:12])
    ledger_fingerprints = {
        _fingerprint(4000 + index) for index in range(86)
    }
    authorized_historical = supplement_fingerprints | ledger_fingerprints
    batch_fingerprints = supplement_fingerprints - legacy_fingerprints
    _expect(len(authorized_historical) == 587, str(len(authorized_historical)))
    _expect(len(batch_fingerprints) == 489, str(len(batch_fingerprints)))
    coverage = legacy_resolver._full_convergence_terminal_coverage_failures(
        authorized_historical=authorized_historical,
        legacy_exact=legacy_fingerprints,
        full_fingerprints=batch_fingerprints,
        terminal=True,
        historical_delta_metadata_exact=ledger_fingerprints,
    )
    _expect(not coverage, str(coverage))

    identities: dict[str, dict[str, Any]] = {}
    for index, fingerprint in enumerate(sorted(authorized_historical)):
        identities[fingerprint] = {
            "raw_failure": f"HISTORICAL_LEDGER_INTEGRATION_SELFTEST:{index:03d}"
        }
    exact_current_blockers = [
        "EVIDENCE_SUBJECT_PRODUCT_TREE_DRIFT",
        "PR93_DESCRIPTION_STAGE3_STALE",
        "STALE_PR_STATUS_BLOCK:MISMATCH",
    ]
    head = "b" * 40
    with tempfile.TemporaryDirectory(prefix="v076-ledger-live-raw-") as temporary:
        path = Path(temporary) / "live.json"
        historical_raw = [
            str(identity["raw_failure"]) for identity in identities.values()
        ]
        _write_json(path, {
            "status": "FAIL",
            "head_sha": head,
            "include_worktree": False,
            "evaluated_source": "COMMITTED_HEAD",
            "failures": sorted(historical_raw + exact_current_blockers),
        })
        report = legacy_resolver._classify_full_convergence_live_raw(
            path,
            current_head=head,
            authorized_identity_by_fingerprint=identities,
        )
        _expect(report["raw_failure_count"] == 590, str(report))
        _expect(report["raw_historical_failure_count"] == 587, str(report))
        _expect(report["raw_current_delta_failure_count"] == 3, str(report))
        _expect(
            set(report["active_raw_by_fingerprint"].values())
            == set(exact_current_blockers),
            str(report),
        )

        future_raw = "HISTORY_FUTURE_UNMATCHED:bbbbbbbbbbbb->cccccccccccc:future.gd"
        _write_json(path, {
            "status": "FAIL",
            "head_sha": head,
            "include_worktree": False,
            "evaluated_source": "COMMITTED_HEAD",
            "failures": sorted(historical_raw + exact_current_blockers + [future_raw]),
        })
        future = legacy_resolver._classify_full_convergence_live_raw(
            path,
            current_head=head,
            authorized_identity_by_fingerprint=identities,
        )
        _expect(future["raw_current_delta_failure_count"] == 4, str(future))
        _expect(future_raw in set(future["active_raw_by_fingerprint"].values()), str(future))


def _historical_delta_metadata_effective_report_case(root: Path) -> None:
    supplement = {_fingerprint(5000 + index) for index in range(501)}
    legacy = set(sorted(supplement)[:12])
    ledger = {_fingerprint(6000 + index) for index in range(86)}
    batch = supplement - legacy
    authorized = supplement | ledger
    active_raw = {
        "active-1": "EVIDENCE_SUBJECT_PRODUCT_TREE_DRIFT",
        "active-2": "PR93_DESCRIPTION_STAGE3_STALE",
        "active-3": "STALE_PR_STATUS_BLOCK:MISMATCH",
    }
    original_legacy = legacy_resolver.validate_legacy_epoch_effectiveness
    original_authority = legacy_resolver._verified_full_convergence_authority
    original_live = legacy_resolver._classify_full_convergence_live_raw
    original_binding = legacy_resolver._validate_full_convergence_live_raw_binding

    def legacy_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            "status": "PASS",
            "failures": [],
            "legacy_record_count": 6,
            "verified_corrected_historical_fingerprints": sorted(legacy),
            "records": [],
        }

    def authority_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            "status": "PASS",
            "failures": [],
            "authorization_id": convergence.AUTHORIZATION_ID,
            "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
            "terminal_remainder_batch": True,
            "coverage_missing_fingerprints": [],
            "coverage_extra_fingerprints": [],
            "authorized_historical_fingerprints": sorted(authorized),
            "registered_historical_fingerprints": sorted(authorized),
            "dispositioned_historical_fingerprints": [],
            "exact_legacy_corrected_fingerprints": sorted(legacy),
            "verified_historical_fingerprints": sorted(batch),
            "exact_historical_delta_metadata_corrected_fingerprints": sorted(ledger),
            "full_convergence_record_count": 20,
            "historical_delta_metadata_record_count": 3,
            "historical_delta_metadata_correction_record_count": 4,
            "historical_delta_metadata_component_count": 82,
            "historical_delta_metadata_authorized_failure_count": 86,
            "historical_delta_metadata_verified_failure_count": 86,
            "record_summaries": [],
            "historical_delta_metadata_record_summaries": [],
            "historical_delta_metadata_ledger": {"status": "PASS"},
            "subject_projection_revalidation": {
                "status": "PASS",
                "record_count": 82,
                "trusted_fingerprint_count": 82,
            },
        }

    def live_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            "status": "PASS",
            "failures": [],
            "raw_report": {"head_sha": "c" * 40},
            "raw_failure_count": 590,
            "raw_historical_failure_count": 587,
            "raw_current_delta_failure_count": 3,
            "historical_fingerprints": sorted(authorized),
            "active_fingerprints": sorted(active_raw),
            "active_raw_by_fingerprint": active_raw,
            "missing_authorized_historical_raw_failures": [],
            "reappeared_dispositioned_historical_raw_failures": [],
        }

    legacy_resolver.validate_legacy_epoch_effectiveness = legacy_stub
    legacy_resolver._verified_full_convergence_authority = authority_stub
    legacy_resolver._classify_full_convergence_live_raw = live_stub
    legacy_resolver._validate_full_convergence_live_raw_binding = (
        lambda *args, **kwargs: {"status": "PASS", "failures": [], "mode": "SELFTEST"}
    )
    try:
        report = legacy_resolver.validate_full_convergence_records(
            root,
            root,
            current_head="c" * 40,
            live_raw_report_path=root / "live.json",
            baseline_report_path=root / "baseline.json",
            batch_manifest_path=root / "batch.json",
            previous_batch_manifest_path=root / "previous.json",
            descendant_history_supplement_path=root / "supplement.json",
            descendant_history_raw_report_path=root / "descendant.json",
            descendant_history_scanner_path=root / "scanner.py",
            historical_delta_metadata_ledger_path=root / "ledger.json",
        )
    finally:
        legacy_resolver.validate_legacy_epoch_effectiveness = original_legacy
        legacy_resolver._verified_full_convergence_authority = original_authority
        legacy_resolver._classify_full_convergence_live_raw = original_live
        legacy_resolver._validate_full_convergence_live_raw_binding = original_binding

    _expect(report["raw_failure_count"] == 590, str(report))
    _expect(report["raw_historical_failure_count"] == 587, str(report))
    _expect(report["raw_current_delta_failure_count"] == 3, str(report))
    _expect(report["corrected_historical_failure_count"] == 587, str(report))
    _expect(report["unresolved_historical_failure_count"] == 0, str(report))
    _expect(report["true_active_violation_count"] == 3, str(report))
    _expect(report["effective_blocking_failure_count"] == 3, str(report))
    _expect(report["new_correction_record_count"] == 20, str(report))
    _expect(report["total_new_correction_record_count"] == 24, str(report))
    _expect(report["historical_delta_metadata_record_count"] == 3, str(report))
    _expect(report["historical_delta_metadata_correction_record_count"] == 4, str(report))
    _expect(report["historical_delta_metadata_component_count"] == 82, str(report))
    _expect(report["historical_delta_metadata_verified_failure_count"] == 86, str(report))
    _expect(
        report["subject_projection_revalidation"]["record_count"] == 82,
        str(report),
    )
    _expect(report["new_correction_record_count"] == 20, str(report))
    _expect(report["total_new_correction_record_count"] == 24, str(report))
    _expect(report["status"] == "FAIL", str(report))
    _expect(set(report["true_active_violation_raw_by_fingerprint"].values()) == set(active_raw.values()), str(report))


def _terminal_historical_delta_metadata_ledger_omission_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-terminal-ledger-required-") as temporary:
        manifest_path = Path(temporary) / "terminal.json"
        _write_json(manifest_path, _batch(25, terminal=True))
        report = convergence.validate_batch_manifest_against_repo(
            root,
            manifest_path,
            evaluated_head=_git(root, "rev-parse", "HEAD"),
            baseline_report_path=root / convergence.BASELINE_REPORT_REL,
        )
    _expect_failure(
        report["failures"],
        "BATCH_TERMINAL_HISTORICAL_DELTA_METADATA_LEDGER_REQUIRED",
    )
    ledger = report["historical_delta_metadata_ledger"]
    _expect(ledger["status"] == "FAIL", str(ledger))
    _expect(ledger["authorized_historical_fingerprints"] == [], str(ledger))
    _expect(ledger["record_summaries"] == [], str(ledger))


def _independent_terminal_partition_fixture() -> tuple[
    set[str], set[str], set[str], set[str], dict[str, Any]
]:
    primary = {_fingerprint(10000 + index) for index in range(501)}
    hdm = {_fingerprint(20000 + index) for index in range(86)}
    legacy = set(sorted(primary)[:12])
    chain = primary - legacy
    authority = {
        "status": "PASS",
        "authorized_historical_fingerprints": sorted(hdm),
    }
    return primary, hdm, legacy, chain, authority


def _independent_terminal_exact_partition_case() -> None:
    primary, hdm, legacy, chain, authority = (
        _independent_terminal_partition_fixture()
    )
    findings, receipt = independent_audit._terminal_coverage_projection(
        batch_id="batch-013",
        terminal_remainder_batch=True,
        terminal_batch_failure_count=11,
        validated_batch_count=13,
        primary_historical=primary,
        historical_delta_metadata_authority=authority,
        legacy_fingerprints=legacy,
        chain_fingerprints=chain,
    )
    _expect(findings == [], str(findings))
    _expect(receipt["status"] == "PASS", str(receipt))
    _expect(receipt["primary_historical_count"] == 501, str(receipt))
    _expect(receipt["historical_delta_metadata_count"] == 86, str(receipt))
    _expect(receipt["combined_historical_count"] == 587, str(receipt))
    _expect(receipt["legacy_corrected_count"] == 12, str(receipt))
    _expect(receipt["expected_chain_count"] == 489, str(receipt))
    _expect(receipt["validated_chain_count"] == 489, str(receipt))
    _expect(receipt["coverage_missing_count"] == 0, str(receipt))
    _expect(receipt["coverage_extra_count"] == 0, str(receipt))
    empty_sha = hashlib.sha256(b"").hexdigest()
    _expect(receipt["coverage_missing_set_sha256"] == empty_sha, str(receipt))
    _expect(receipt["coverage_extra_set_sha256"] == empty_sha, str(receipt))
    _expect(receipt["legacy_hdm_overlap_set_sha256"] == empty_sha, str(receipt))
    _expect(
        receipt["combined_historical_set_sha256"]
        == independent_audit._exact_fingerprint_set_sha(primary | hdm),
        str(receipt),
    )


def _independent_terminal_ledger_omission_case() -> None:
    primary, _, legacy, chain, _ = _independent_terminal_partition_fixture()
    findings, receipt = independent_audit._terminal_coverage_projection(
        batch_id="batch-013",
        terminal_remainder_batch=True,
        terminal_batch_failure_count=11,
        validated_batch_count=13,
        primary_historical=primary,
        historical_delta_metadata_authority={"status": "NOT_PROVIDED"},
        legacy_fingerprints=legacy,
        chain_fingerprints=chain,
    )
    codes = {finding["code"] for finding in findings}
    _expect(
        "FULL_CONVERGENCE_TERMINAL_HISTORICAL_DELTA_METADATA_LEDGER_REQUIRED"
        in codes,
        str(findings),
    )
    _expect(
        "FULL_CONVERGENCE_TERMINAL_HDM_COUNT_MISMATCH" in codes,
        str(findings),
    )
    _expect(receipt["status"] == "FAIL", str(receipt))
    _expect(receipt["historical_delta_metadata_count"] == 0, str(receipt))
    _expect(receipt["combined_historical_count"] == 501, str(receipt))


def _independent_terminal_equal_cardinality_tamper_case() -> None:
    primary, _, legacy, chain, authority = (
        _independent_terminal_partition_fixture()
    )
    missing = min(chain)
    extra = _fingerprint(30000)
    tampered = (chain - {missing}) | {extra}
    findings, receipt = independent_audit._terminal_coverage_projection(
        batch_id="batch-013",
        terminal_remainder_batch=True,
        terminal_batch_failure_count=11,
        validated_batch_count=13,
        primary_historical=primary,
        historical_delta_metadata_authority=authority,
        legacy_fingerprints=legacy,
        chain_fingerprints=tampered,
    )
    codes = {finding["code"] for finding in findings}
    _expect(
        "FULL_CONVERGENCE_TERMINAL_COVERAGE_MISSING" in codes,
        str(findings),
    )
    _expect(
        "FULL_CONVERGENCE_TERMINAL_COVERAGE_EXTRA" in codes,
        str(findings),
    )
    _expect(receipt["validated_chain_count"] == 489, str(receipt))
    _expect(receipt["coverage_missing_fingerprints"] == [missing], str(receipt))
    _expect(receipt["coverage_extra_fingerprints"] == [extra], str(receipt))
    _expect(
        receipt["expected_chain_set_sha256"]
        != receipt["validated_chain_set_sha256"],
        str(receipt),
    )


def _independent_terminal_partition_overlap_case() -> None:
    primary, hdm, legacy, chain, _ = _independent_terminal_partition_fixture()
    shared = min(legacy)
    overlapping_hdm = (hdm - {min(hdm)}) | {shared}
    authority = {
        "status": "PASS",
        "authorized_historical_fingerprints": sorted(overlapping_hdm),
    }
    findings, receipt = independent_audit._terminal_coverage_projection(
        batch_id="batch-013",
        terminal_remainder_batch=True,
        terminal_batch_failure_count=11,
        validated_batch_count=13,
        primary_historical=primary,
        historical_delta_metadata_authority=authority,
        legacy_fingerprints=legacy,
        chain_fingerprints=chain,
    )
    codes = {finding["code"] for finding in findings}
    _expect(
        "FULL_CONVERGENCE_TERMINAL_PRIMARY_HDM_OVERLAP" in codes,
        str(findings),
    )
    _expect(
        "FULL_CONVERGENCE_TERMINAL_LEGACY_HDM_OVERLAP" in codes,
        str(findings),
    )
    _expect(
        "FULL_CONVERGENCE_TERMINAL_COMBINED_COUNT_MISMATCH" in codes,
        str(findings),
    )
    _expect(receipt["primary_hdm_overlap_fingerprints"] == [shared], str(receipt))
    _expect(receipt["legacy_hdm_overlap_fingerprints"] == [shared], str(receipt))
    _expect(receipt["combined_historical_count"] == 586, str(receipt))


def _independent_hdm_cli_coupling_case(root: Path) -> None:
    stderr = io.StringIO()
    with contextlib.redirect_stderr(stderr):
        try:
            independent_audit.main([
                "--project",
                str(root),
                "--historical-delta-metadata-ledger",
                "explicit-ledger.json",
            ])
        except SystemExit as exc:
            _expect(exc.code == 2, str(exc))
        else:
            raise AssertionError("standalone HDM input was accepted without FC inputs")
    _expect(
        "--historical-delta-metadata-ledger requires" in stderr.getvalue(),
        stderr.getvalue(),
    )


def _independent_real_hdm_authority_case(root: Path) -> None:
    manifest_path = root / (
        "docs/architecture/reuse_corrections/v2/"
        "historical_delta_metadata_successor_v2/manifest.json"
    )
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    primary = hdm_successor_v2.validate_manifest(
        root,
        manifest_path,
        evaluated_head=manifest["current_binding_head_sha"],
    )
    independent = hdm_successor_v2_independent.audit(root, manifest_path)
    expected_sha = "91373b8883708f835052cbebe1da8b53e33f4ef608d97b17f5ab45161cd0a8d9"
    _expect(primary["status"] == "PASS", str(primary))
    _expect(independent["status"] == "PASS", str(independent))
    _expect(primary["failures"] == [], str(primary))
    _expect(independent["failures"] == [], str(independent))
    _expect(primary["identity_count"] == 86, str(primary))
    _expect(independent["identity_count"] == 86, str(independent))
    _expect(primary["record_count"] == 4, str(primary))
    _expect(independent["record_count"] == 4, str(independent))
    _expect(primary["rebound_count"] == 52, str(primary))
    _expect(independent["rebound_count"] == 52, str(independent))
    _expect(primary["preserved_count"] == 34, str(primary))
    _expect(independent["preserved_count"] == 34, str(independent))
    _expect(
        primary["authority_projection_sha256"]
        == independent["authority_projection_sha256"],
        f"primary={primary}; independent={independent}",
    )
    _expect(manifest["identity_count"] == 86, str(manifest))
    _expect(manifest["identity_fingerprint_set_sha256"] == expected_sha, str(manifest))
    _expect(len(manifest["identity_fingerprints"]) == 86, str(manifest))
    _expect(len(set(manifest["identity_fingerprints"])) == 86, str(manifest))
    _expect(manifest["wildcard_count"] == 0, str(manifest))
    _expect(manifest["selector_policy"]["wildcard_allowed"] is False, str(manifest))
    _expect(manifest["selector_policy"]["future_failure_auto_match"] is False, str(manifest))
    _expect(manifest["future_failure_policy"]["automatic_match"] is False, str(manifest))
    _expect(manifest["future_failure_policy"]["new_failure_requires_new_record"] is True, str(manifest))


def _broken_composite_clears_ledger_authority_case(root: Path) -> None:
    supplement_fingerprints = {
        _fingerprint(7000 + index) for index in range(501)
    }
    legacy_fingerprints = set(sorted(supplement_fingerprints)[:12])
    batch_fingerprints = supplement_fingerprints - legacy_fingerprints
    ledger_fingerprints = {
        _fingerprint(8000 + index) for index in range(86)
    }
    supplement_identities = {
        fingerprint: {"raw_failure": f"SUPPLEMENT_RAW:{index:03d}"}
        for index, fingerprint in enumerate(sorted(supplement_fingerprints))
    }
    ledger_identities = {
        fingerprint: {"raw_failure": f"LEDGER_RAW:{index:03d}"}
        for index, fingerprint in enumerate(sorted(ledger_fingerprints))
    }
    ledger_projection = {
        "status": "PASS",
        "failures": [],
        "primary_status": "PASS",
        "independent_status": "GO",
        "primary_projection_digest_match": True,
        "metadata_record_count": 3,
        "correction_record_count": 4,
        "component_count": 82,
        "authorized_historical_fingerprints": sorted(ledger_fingerprints),
        "authorized_identity_by_fingerprint": ledger_identities,
        "verified_historical_fingerprints": sorted(ledger_fingerprints),
        "record_summaries": [{
            "correction_id": "ledger-otherwise-pass",
            "path": "docs/architecture/reuse_corrections/v2/records/ledger.json",
            "failure_fingerprints": sorted(ledger_fingerprints),
        }],
    }
    original_primary = convergence.validate_batch_manifest_against_repo
    original_baseline = convergence.validate_authorized_baseline
    original_supplement = convergence.validate_descendant_history_supplement
    original_legacy_anchor = convergence.verify_legacy_anchor
    original_chain = convergence._load_previous_batch_chain
    mode = {"value": "BROKEN_BATCH"}

    def primary_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
        if mode["value"] == "BROKEN_BATCH":
            return {
                "status": "FAIL",
                "failures": ["BROKEN_BATCH"],
                "historical_delta_metadata_ledger": copy.deepcopy(
                    ledger_projection
                ),
            }
        return {
            "status": "PASS",
            "failures": [],
            "historical_delta_metadata_ledger": (
                convergence._empty_historical_delta_metadata_ledger_authority(
                    status="NOT_PROVIDED"
                )
            ),
        }

    def supplement_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            "status": "PASS",
            "failures": [],
            "supplement_sha256": "1" * 64,
            "raw_report_head_sha": "d" * 40,
            "authorized_identity_by_fingerprint": supplement_identities,
            "registered_identity_by_fingerprint": supplement_identities,
            "frozen_identity_disposition_by_failure": {},
        }

    def legacy_anchor_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            "status": "PASS",
            "failures": [],
            "legacy_corrected_fingerprints": sorted(legacy_fingerprints),
        }

    convergence.validate_batch_manifest_against_repo = primary_stub
    convergence.validate_authorized_baseline = lambda *args, **kwargs: {
        "status": "PASS", "failures": []
    }
    convergence.validate_descendant_history_supplement = supplement_stub
    convergence.verify_legacy_anchor = legacy_anchor_stub
    convergence._load_previous_batch_chain = lambda *args, **kwargs: ([], [])
    try:
        with tempfile.TemporaryDirectory(prefix="v076-composite-ledger-") as temporary:
            temporary_root = Path(temporary)
            baseline_path = temporary_root / "baseline.json"
            manifest_path = temporary_root / "terminal.json"
            _write_json(baseline_path, {})
            _write_json(manifest_path, {
                "batch_id": "terminal",
                "terminal_remainder_batch": True,
                "failure_fingerprints": sorted(batch_fingerprints),
                "record_bindings": [],
            })
            broken = legacy_resolver._verified_full_convergence_authority(
                root,
                current_head=_git(root, "rev-parse", "HEAD"),
                baseline_report_path=baseline_path,
                batch_manifest_path=manifest_path,
                previous_batch_manifest_path=temporary_root / "previous.json",
                descendant_history_supplement_path=temporary_root / "supplement.json",
                descendant_history_raw_report_path=temporary_root / "raw.json",
                descendant_history_scanner_path=temporary_root / "scanner.py",
                historical_delta_metadata_ledger_path=temporary_root / "ledger.json",
            )
            _expect(broken["status"] == "FAIL", str(broken))
            _expect_failure(broken["failures"], "BROKEN_BATCH")
            nested = broken["historical_delta_metadata_ledger"]
            _expect(nested["status"] == "FAIL", str(nested))
            _expect(nested["authorized_historical_fingerprints"] == [], str(nested))
            _expect(nested["record_summaries"] == [], str(nested))
            _expect(broken["exact_historical_delta_metadata_corrected_fingerprints"] == [], str(broken))
            _expect(broken["historical_delta_metadata_record_summaries"] == [], str(broken))
            _expect(broken["historical_delta_metadata_record_count"] == 0, str(broken))
            _expect(broken["historical_delta_metadata_correction_record_count"] == 0, str(broken))
            _expect(broken["historical_delta_metadata_authorized_failure_count"] == 0, str(broken))
            _expect(broken["historical_delta_metadata_verified_failure_count"] == 0, str(broken))
            for field in (
                "authorized_historical_fingerprints",
                "registered_historical_fingerprints",
                "dispositioned_historical_fingerprints",
                "exact_legacy_corrected_fingerprints",
                "exact_historical_delta_metadata_corrected_fingerprints",
                "expected_full_convergence_fingerprints",
                "verified_historical_fingerprints",
                "coverage_missing_fingerprints",
                "coverage_extra_fingerprints",
                "record_summaries",
                "historical_delta_metadata_record_summaries",
            ):
                _expect(broken[field] == [], f"{field}:{broken[field]}")
            for field in (
                "authorized_historical_raw_identity_by_fingerprint",
                "registered_historical_raw_identity_by_fingerprint",
                "frozen_identity_disposition_by_failure",
                "verified_raw_identity_by_fingerprint",
            ):
                _expect(broken[field] == {}, f"{field}:{broken[field]}")
            _expect(broken["terminal_remainder_batch"] is False, str(broken))
            _expect(broken["validated_batch_count"] == 0, str(broken))
            _expect(broken["full_convergence_record_count"] == 0, str(broken))
            _expect(broken["supplement_authorized_historical_failure_count"] == 0, str(broken))
            _expect(broken["terminal_batch_id"] == "", str(broken))
            _expect(broken["terminal_batch_manifest_path"] == "", str(broken))
            _expect(broken["terminal_batch_manifest_sha256"] == "", str(broken))
            _expect(
                set(broken["diagnostic_authorized_historical_fingerprints"])
                == supplement_fingerprints | ledger_fingerprints,
                str(broken),
            )

            mode["value"] = "OMITTED_LEDGER"
            omitted = legacy_resolver._verified_full_convergence_authority(
                root,
                current_head=_git(root, "rev-parse", "HEAD"),
                baseline_report_path=baseline_path,
                batch_manifest_path=manifest_path,
                previous_batch_manifest_path=temporary_root / "previous.json",
                descendant_history_supplement_path=temporary_root / "supplement.json",
                descendant_history_raw_report_path=temporary_root / "raw.json",
                descendant_history_scanner_path=temporary_root / "scanner.py",
                historical_delta_metadata_ledger_path=None,
            )
            _expect(omitted["status"] == "FAIL", str(omitted))
            _expect_failure(
                omitted["failures"],
                "EFFECTIVE_TERMINAL_HISTORICAL_DELTA_METADATA_LEDGER_REQUIRED",
            )
    finally:
        convergence.validate_batch_manifest_against_repo = original_primary
        convergence.validate_authorized_baseline = original_baseline
        convergence.validate_descendant_history_supplement = original_supplement
        convergence.verify_legacy_anchor = original_legacy_anchor
        convergence._load_previous_batch_chain = original_chain

    original_effective_legacy = legacy_resolver.validate_legacy_epoch_effectiveness
    original_effective_authority = legacy_resolver._verified_full_convergence_authority
    original_effective_live = legacy_resolver._classify_full_convergence_live_raw
    original_effective_binding = legacy_resolver._validate_full_convergence_live_raw_binding
    malicious_fail = dict(broken)
    malicious_fail["status"] = "FAIL"
    malicious_fail["verified_historical_fingerprints"] = sorted(batch_fingerprints)
    malicious_fail["exact_historical_delta_metadata_corrected_fingerprints"] = sorted(
        ledger_fingerprints
    )
    legacy_resolver.validate_legacy_epoch_effectiveness = lambda *args, **kwargs: {
        "status": "PASS",
        "failures": [],
        "legacy_record_count": 6,
        "verified_corrected_historical_fingerprints": sorted(legacy_fingerprints),
        "records": [],
    }
    legacy_resolver._verified_full_convergence_authority = lambda *args, **kwargs: malicious_fail
    legacy_resolver._classify_full_convergence_live_raw = lambda *args, **kwargs: {
        "status": "PASS",
        "failures": [],
        "raw_report": {"head_sha": "d" * 40},
        "raw_failure_count": 504,
        "raw_historical_failure_count": 501,
        "raw_current_delta_failure_count": 3,
        "active_fingerprints": ["active-1", "active-2", "active-3"],
        "active_raw_by_fingerprint": {},
        "missing_authorized_historical_raw_failures": [],
        "reappeared_dispositioned_historical_raw_failures": [],
    }
    legacy_resolver._validate_full_convergence_live_raw_binding = (
        lambda *args, **kwargs: {"status": "PASS", "failures": [], "mode": "SELFTEST"}
    )
    try:
        downstream = legacy_resolver.validate_full_convergence_records(
            root,
            root,
            current_head="d" * 40,
            live_raw_report_path=root / "live.json",
            baseline_report_path=root / "baseline.json",
            batch_manifest_path=root / "batch.json",
            previous_batch_manifest_path=root / "previous.json",
            descendant_history_supplement_path=root / "supplement.json",
            descendant_history_raw_report_path=root / "raw.json",
            descendant_history_scanner_path=root / "scanner.py",
            historical_delta_metadata_ledger_path=root / "ledger.json",
        )
    finally:
        legacy_resolver.validate_legacy_epoch_effectiveness = original_effective_legacy
        legacy_resolver._verified_full_convergence_authority = original_effective_authority
        legacy_resolver._classify_full_convergence_live_raw = original_effective_live
        legacy_resolver._validate_full_convergence_live_raw_binding = original_effective_binding
    _expect(downstream["full_convergence_corrected_historical_failure_count"] == 0, str(downstream))
    _expect(downstream["historical_delta_metadata_corrected_historical_failure_count"] == 0, str(downstream))
    _expect(downstream["corrected_historical_failure_count"] == 0, str(downstream))


def _authority_projection_tamper_case(*, mutate_summary: bool) -> None:
    import v076_historical_delta_metadata_independent_audit as ledger_independent
    import v076_historical_delta_metadata_ledger as ledger_primary

    fingerprint = _fingerprint(9001)
    identity = {"failure_fingerprint": fingerprint, "raw_failure": "RAW:original", "component_id": "component.one"}
    pristine = {"identities": {fingerprint: identity}, "summaries": [{"correction_id": "c1", "path": "records/c1.json", "failure_fingerprints": [fingerprint]}]}
    primary_projection = copy.deepcopy(pristine)
    if mutate_summary:
        primary_projection["summaries"] = []
    else:
        primary_projection["identities"][fingerprint]["raw_failure"] = "RAW:forged"
    original_primary = ledger_primary.validate_ledger
    original_independent = ledger_independent.audit_ledger
    original_primary_projection = convergence._primary_historical_delta_metadata_authority_projection
    original_independent_projection = convergence._independent_historical_delta_metadata_authority_projection
    ledger_primary.validate_ledger = lambda *args, **kwargs: {
        "status": "PASS", "failures": [], "authorized_historical_fingerprints": [fingerprint],
        "authorized_identity_by_fingerprint": {fingerprint: identity}, "verified_historical_fingerprints": [fingerprint],
        "record_summaries": pristine["summaries"],
    }
    ledger_independent.audit_ledger = lambda *args, **kwargs: {
        "status": "GO", "failures": [], "primary_projection_digest_match": True,
        "authorized_failure_count": 1, "verified_failure_count": 1, "component_count": 1,
    }
    convergence._primary_historical_delta_metadata_authority_projection = lambda *args, **kwargs: copy.deepcopy(primary_projection)
    convergence._independent_historical_delta_metadata_authority_projection = lambda *args, **kwargs: copy.deepcopy(pristine)
    try:
        report = convergence.validate_historical_delta_metadata_ledger_authority(
            Path.cwd(), Path("explicit-ledger.json"), evaluated_head="a" * 40
        )
    finally:
        ledger_primary.validate_ledger = original_primary
        ledger_independent.audit_ledger = original_independent
        convergence._primary_historical_delta_metadata_authority_projection = original_primary_projection
        convergence._independent_historical_delta_metadata_authority_projection = original_independent_projection
    _expect(report["status"] == "FAIL", str(report))
    _expect_failure(report["failures"], "HISTORICAL_DELTA_METADATA_PRIMARY_PROJECTION_DIGEST_MISMATCH")
    _expect(report["authorized_identity_by_fingerprint"] == {}, str(report))


def _live_raw_binding_cases(root: Path, mode: str) -> None:
    head = _git(root, "rev-parse", "HEAD")
    scanner = root / "tools/v076/v076_reuse_point_inertia_gate.py"
    scanner_sha = hashlib.sha256(scanner.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="v076-live-binding-selftest-") as temporary:
        temporary_root = Path(temporary)
        live_path = temporary_root / "live.json"
        pr_body = temporary_root / "pr-body.md"
        pr_body.write_text("selftest PR body\n", encoding="utf-8")
        if mode == "FROZEN_FORGED":
            original = {"status": "FAIL", "head_sha": head, "include_worktree": False, "evaluated_source": "COMMITTED_HEAD", "failures": ["A", "B", "C"]}
            _write_json(live_path, original)
            expected_sha = hashlib.sha256(live_path.read_bytes()).hexdigest()
            forged = dict(original)
            forged["failures"] = []
            forged["status"] = "PASS"
            _write_json(live_path, forged)
            authority = {"status": "PASS", "historical_delta_metadata_ledger": {"status": "PASS", "raw_report_head_sha": head, "raw_report_sha256": expected_sha, "scanner_sha256": scanner_sha}}
            report = legacy_resolver._validate_full_convergence_live_raw_binding(root, live_path, current_head=head, authority=authority, pr_body_file_path=None)
            _expect_failure(report["failures"], "LIVE_RAW_FROZEN_LEDGER_BYTE_IDENTITY_MISMATCH")
            return

        raw_head = _git(root, "rev-parse", "HEAD^")
        payload = {"status": "FAIL", "head_sha": head, "include_worktree": False, "evaluated_source": "COMMITTED_HEAD", "failures": ["CURRENT_BLOCKER"], "self_reported_attestation": "FORGED"}
        _write_json(live_path, payload)
        authority = {"status": "PASS", "historical_delta_metadata_ledger": {"status": "PASS", "raw_report_head_sha": raw_head, "raw_report_sha256": "0" * 64, "scanner_sha256": scanner_sha}}
        original_run = legacy_resolver._run_full_convergence_scanner

        def run_stub(argv: list[str], *, cwd: Path) -> subprocess.CompletedProcess[bytes]:
            output = Path(argv[argv.index("--report-json") + 1])
            if mode == "DESCENDANT_PASS":
                output.write_bytes(live_path.read_bytes())
            else:
                different = dict(payload)
                different["failures"] = ["DIFFERENT_BLOCKER"]
                _write_json(output, different)
            return subprocess.CompletedProcess(argv, 1, stdout=b"scanner stdout", stderr=b"")

        legacy_resolver._run_full_convergence_scanner = run_stub
        try:
            report = legacy_resolver._validate_full_convergence_live_raw_binding(root, live_path, current_head=head, authority=authority, pr_body_file_path=pr_body)
        finally:
            legacy_resolver._run_full_convergence_scanner = original_run
        if mode == "DESCENDANT_PASS":
            _expect(report["status"] == "PASS", str(report))
            _expect(report["exact_byte_match"] is True, str(report))
        else:
            _expect(report["status"] == "FAIL", str(report))
            _expect_failure(report["failures"], "LIVE_RAW_REEXECUTION_EXACT_OUTPUT_MISMATCH")


def _single_live_raw_snapshot_case(root: Path) -> None:
    head = "c" * 40
    first = legacy_resolver._canonical_bytes({
        "status": "FAIL", "head_sha": head, "include_worktree": False,
        "evaluated_source": "COMMITTED_HEAD", "failures": ["FIRST"],
    })
    second = legacy_resolver._canonical_bytes({
        "status": "PASS", "head_sha": head, "include_worktree": False,
        "evaluated_source": "COMMITTED_HEAD", "failures": [],
    })

    class ChangingPath:
        name = "changing-live.json"

        def __init__(self, values: list[bytes]) -> None:
            self.values = values
            self.read_count = 0

        def read_bytes(self) -> bytes:
            value = self.values[min(self.read_count, len(self.values) - 1)]
            self.read_count += 1
            return value

    live_path = ChangingPath([first, second])
    pr_path = ChangingPath([b"first pr body", b"second pr body"])
    captured: dict[str, Any] = {}
    original_legacy = legacy_resolver.validate_legacy_epoch_effectiveness
    original_authority = legacy_resolver._verified_full_convergence_authority
    original_classifier = legacy_resolver._classify_full_convergence_live_raw
    original_binding = legacy_resolver._validate_full_convergence_live_raw_binding
    legacy_resolver.validate_legacy_epoch_effectiveness = lambda *args, **kwargs: {
        "status": "PASS", "failures": [], "verified_corrected_historical_fingerprints": [],
    }
    legacy_resolver._verified_full_convergence_authority = lambda *args, **kwargs: {
        "status": "PASS", "failures": [], "terminal_remainder_batch": True,
        "coverage_missing_fingerprints": [], "coverage_extra_fingerprints": [],
        "authorized_historical_fingerprints": [], "registered_historical_fingerprints": [],
        "historical_delta_metadata_ledger": {"status": "PASS"},
    }

    def classifier_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
        captured["classifier_report"] = kwargs["snapshot_report"]
        return {
            "status": "PASS", "failures": [], "raw_report": kwargs["snapshot_report"],
            "raw_failure_count": 1, "raw_historical_failure_count": 0,
            "raw_current_delta_failure_count": 1, "active_fingerprints": ["active"],
            "active_raw_by_fingerprint": {"active": "FIRST"},
            "missing_authorized_historical_raw_failures": [],
            "reappeared_dispositioned_historical_raw_failures": [],
        }

    def binding_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
        captured["binding_bytes"] = kwargs["live_raw_bytes"]
        captured["pr_body_bytes"] = kwargs["pr_body_bytes"]
        return {"status": "PASS", "failures": [], "mode": "SELFTEST"}

    legacy_resolver._classify_full_convergence_live_raw = classifier_stub
    legacy_resolver._validate_full_convergence_live_raw_binding = binding_stub
    try:
        legacy_resolver.validate_full_convergence_records(
            root, root, current_head=head, live_raw_report_path=live_path,
            baseline_report_path=root / "baseline.json", batch_manifest_path=root / "batch.json",
            previous_batch_manifest_path=root / "previous.json",
            descendant_history_supplement_path=root / "supplement.json",
            descendant_history_raw_report_path=root / "raw.json",
            descendant_history_scanner_path=root / "scanner.py",
            full_convergence_pr_body_file_path=pr_path,
        )
    finally:
        legacy_resolver.validate_legacy_epoch_effectiveness = original_legacy
        legacy_resolver._verified_full_convergence_authority = original_authority
        legacy_resolver._classify_full_convergence_live_raw = original_classifier
        legacy_resolver._validate_full_convergence_live_raw_binding = original_binding
    _expect(live_path.read_count == 1, str(live_path.read_count))
    _expect(pr_path.read_count == 1, str(pr_path.read_count))
    _expect(captured["binding_bytes"] == first, str(captured))
    _expect(captured["classifier_report"]["failures"] == ["FIRST"], str(captured))
    _expect(captured["pr_body_bytes"] == b"first pr body", str(captured))


def _effective_novel_history_is_active_case() -> None:
    historical_raw = "HISTORY_SAMPLE:aaaaaaaaaaaa->bbbbbbbbbbbb:scripts/known.gd"
    novel_raw = "HISTORY_FUTURE:bbbbbbbbbbbb->cccccccccccc:scripts/future.gd"
    head = "a" * 40
    with tempfile.TemporaryDirectory(prefix="v076-fc-live-raw-") as temporary:
        path = Path(temporary) / "live.json"
        _write_json(path, {
            "status": "FAIL",
            "head_sha": head,
            "include_worktree": False,
            "evaluated_source": "COMMITTED_HEAD",
            "failures": [historical_raw, novel_raw],
        })
        report = legacy_resolver._classify_full_convergence_live_raw(
            path,
            current_head=head,
            authorized_identity_by_fingerprint={
                "V2F-" + "1" * 64: {"raw_failure": historical_raw},
            },
        )
    _expect(report["status"] == "PASS", str(report))
    _expect(report["raw_historical_failure_count"] == 1, str(report))
    _expect(report["raw_current_delta_failure_count"] == 1, str(report))
    active_raw = set(report["active_raw_by_fingerprint"].values())
    _expect(active_raw == {novel_raw}, str(active_raw))


def _effective_missing_history_fails_closed_case() -> None:
    historical_raw = "HISTORY_SAMPLE:aaaaaaaaaaaa->bbbbbbbbbbbb:scripts/known.gd"
    head = "b" * 40
    with tempfile.TemporaryDirectory(prefix="v076-fc-live-missing-") as temporary:
        path = Path(temporary) / "live.json"
        _write_json(path, {
            "status": "PASS",
            "head_sha": head,
            "include_worktree": False,
            "evaluated_source": "COMMITTED_HEAD",
            "failures": [],
        })
        report = legacy_resolver._classify_full_convergence_live_raw(
            path,
            current_head=head,
            authorized_identity_by_fingerprint={
                "V2F-" + "2" * 64: {"raw_failure": historical_raw},
            },
        )
    _expect(report["status"] == "FAIL", str(report))
    _expect_failure(
        report["failures"],
        "RAW_AUTHORIZED_HISTORICAL_FAILURE_MISSING:1",
    )


def _legacy_current_binding_revalidation_case(root: Path) -> None:
    report = legacy_resolver.validate_legacy_epoch_effectiveness(
        root,
        root,
        current_head=_git(root, "rev-parse", "HEAD"),
    )
    _expect(report["status"] == "PASS", json.dumps(report, sort_keys=True))
    _expect(
        len(report["verified_corrected_historical_fingerprints"]) == 12,
        json.dumps(report, sort_keys=True),
    )


def _legacy_preflight_failure_clears_verified_set_case(root: Path) -> None:
    report = legacy_resolver.validate_legacy_epoch_effectiveness(
        root,
        root,
        current_head="f" * 40,
    )
    _expect(report["status"] == "FAIL", json.dumps(report, sort_keys=True))
    _expect_failure(
        report["failures"],
        "LEGACY_EVALUATED_HEAD_NOT_AUTHORIZED_DESCENDANT",
    )
    _expect(
        report["verified_corrected_historical_fingerprints"] == [],
        json.dumps(report, sort_keys=True),
    )


def _copy_real_reconciliation_fixture(root: Path, fixture: Path) -> None:
    clone = subprocess.run(
        ["git", "clone", "--quiet", "--no-hardlinks", str(root), str(fixture)],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    _expect(clone.returncode == 0, clone.stderr)
    for relative in (
        convergence.SCHEMA_REL,
        convergence.SUCCESSOR_SCHEMA_REL,
        convergence.BASELINE_REPORT_REL,
        REAL_DESCENDANT_RAW_REL,
        REAL_DESCENDANT_SUPPLEMENT_REL,
    ):
        _copy_locked(root, fixture, relative.as_posix())


def _write_v3_successor_fixture(root: Path, fixture: Path) -> dict[str, Any]:
    _copy_real_reconciliation_fixture(root, fixture)
    _git(fixture, "config", "user.email", "selftest@example.invalid")
    _git(fixture, "config", "user.name", "V076 Selftest")
    successor_path = fixture / convergence.SUCCESSOR_SCHEMA_REL
    successor_bytes = convergence._git_bytes(
        root,
        _git(root, "rev-parse", "HEAD^{commit}"),
        convergence.SUCCESSOR_SCHEMA_REL.as_posix(),
    )
    _expect(successor_bytes is not None, "successor schema is not committed")
    _expect(
        convergence.sha256_bytes(successor_bytes) == convergence.SUCCESSOR_SCHEMA_SHA256,
        "committed successor schema seal mismatch",
    )
    successor_path.write_bytes(successor_bytes)
    stale_successor = convergence.load_json_strict(successor_path)
    stale_successor["active_registered_identity_count"] = (
        int(stale_successor["active_registered_identity_count"]) + 1
    )
    _write_json(successor_path, stale_successor)
    _git(fixture, "add", "--", convergence.SUCCESSOR_SCHEMA_REL.as_posix())
    _git(fixture, "commit", "--quiet", "-m", "commit stale successor schema predecessor")
    successor_path.write_bytes(successor_bytes)
    _git(
        fixture,
        "add",
        "--",
        convergence.PREDECESSOR_SCHEMA_REL.as_posix(),
        convergence.SUCCESSOR_SCHEMA_REL.as_posix(),
        convergence.BASELINE_REPORT_REL.as_posix(),
    )
    if _git(fixture, "diff", "--cached", "--name-only"):
        _git(fixture, "commit", "--quiet", "-m", "commit sealed schema fixture")
    head = _git(fixture, "rev-parse", "HEAD")
    tree = _git(fixture, "rev-parse", "HEAD^{tree}")
    scanner_path = fixture / convergence.DESCENDANT_HISTORY_SCANNER_REL
    scanner_sha = convergence.sha256_file(scanner_path)
    raw = convergence.load_json_strict(fixture / REAL_DESCENDANT_RAW_REL)
    raw.update({
        "head_ref": head,
        "head_sha": head,
        "include_worktree": False,
        "evaluated_source": "COMMITTED_HEAD",
        "merge_base_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
    })
    raw_rel = convergence.DESCENDANT_HISTORY_V3_RAW_REL
    raw_path = fixture / raw_rel
    _write_json(raw_path, raw)
    raw_sha = convergence.sha256_file(raw_path)
    supplement = convergence.load_json_strict(fixture / REAL_DESCENDANT_SUPPLEMENT_REL)
    supplement.update({
        "previous_supplement_path": convergence.PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_REL.as_posix(),
        "previous_supplement_sha256": convergence.PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA256,
        "raw_report_head_sha": head,
        "raw_report_path": raw_rel.as_posix(),
        "raw_report_sha256": raw_sha,
        "raw_report_tree_sha": tree,
        "scanner_tool_sha256": scanner_sha,
        "schema_version": convergence.DESCENDANT_HISTORY_SUPPLEMENT_V3_SCHEMA_VERSION,
        "supplement_id": convergence.DESCENDANT_HISTORY_SUPPLEMENT_V3_ID,
    })
    for row in supplement["frozen_identity_disposition_by_failure"].values():
        row["live_scanner_tool_sha256"] = scanner_sha
        row["evidence"]["live_raw_report_sha256"] = raw_sha
    commits = [
        value
        for value in _git(
            fixture,
            "rev-list",
            "--reverse",
            f"{convergence.PREVIOUS_DESCENDANT_HISTORY_RAW_HEAD}..{head}",
            "--",
            convergence.DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
        ).splitlines()
        if value
    ]
    supplement["scanner_evolution"] = {
        "evolution_kind": "FAIL_CLOSED_VALIDATION_STRENGTHENING",
        "from_raw_report_head_sha": convergence.PREVIOUS_DESCENDANT_HISTORY_RAW_HEAD,
        "from_raw_report_tree_sha": convergence.PREVIOUS_DESCENDANT_HISTORY_RAW_TREE,
        "from_scanner_tool_sha256": convergence.PREVIOUS_DESCENDANT_HISTORY_SCANNER_SHA256,
        "removed_rule_count": 0,
        "scanner_change_commit_count": len(commits),
        "scanner_change_commit_sequence_sha256": convergence.sha256_bytes(
            ("\n".join(commits) + "\n").encode("utf-8")
        ),
        "scanner_change_commit_shas": commits,
        "scanner_history_depth_reduction_count": 0,
        "scanner_scope_reduction_count": 0,
        "scanner_severity_downgrade_count": 0,
        "scanner_tool_path": convergence.DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
        "to_raw_report_head_sha": head,
        "to_raw_report_tree_sha": tree,
        "to_scanner_tool_sha256": scanner_sha,
        "weakening_allowed": False,
    }
    supplement_rel = convergence.DESCENDANT_HISTORY_V3_SUPPLEMENT_REL
    supplement_path = fixture / supplement_rel
    _write_json(supplement_path, supplement)
    return {
        "raw_path": raw_path,
        "scanner_path": scanner_path,
        "supplement": supplement,
        "supplement_path": supplement_path,
        "head": head,
        "tree": tree,
        "raw_sha": raw_sha,
        "scanner_sha": scanner_sha,
    }


def _v3_successor_positive_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-v3-positive-") as temporary:
        fixture = Path(temporary)
        sealed = _write_v3_successor_fixture(root, fixture)
        result = convergence._validate_descendant_history_supplement_v3(
            fixture,
            sealed["supplement_path"],
            sealed["raw_path"],
            sealed["scanner_path"],
            evaluated_head=sealed["head"],
            baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
            expected_raw_head=sealed["head"],
            expected_raw_tree=sealed["tree"],
            expected_raw_sha256=sealed["raw_sha"],
            expected_scanner_sha256=sealed["scanner_sha"],
        )
        _expect(result["status"] == "PASS", json.dumps(result["failures"]))
        baseline = independent_audit._json(fixture / convergence.BASELINE_REPORT_REL)
        findings = independent_audit._descendant_history_supplement_findings(
            fixture,
            supplement_path=sealed["supplement_path"],
            raw_report_path=sealed["raw_path"],
            scanner_path=sealed["scanner_path"],
            evaluated_head=sealed["head"],
            baseline_report=baseline,
            baseline_sets=independent_audit._authorized_failure_fingerprint_sets(baseline),
            expected_v3_raw_head=sealed["head"],
            expected_v3_raw_tree=sealed["tree"],
            expected_v3_raw_sha=sealed["raw_sha"],
            expected_v3_scanner_sha=sealed["scanner_sha"],
        )[0]
        _expect(not findings, json.dumps(findings, sort_keys=True))


def _v3_successor_negative_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-v3-negative-") as temporary:
        fixture = Path(temporary)
        sealed = _write_v3_successor_fixture(root, fixture)
        baseline = independent_audit._json(fixture / convergence.BASELINE_REPORT_REL)
        baseline_sets = independent_audit._authorized_failure_fingerprint_sets(baseline)
        attacks = []
        reused_id = copy.deepcopy(sealed["supplement"])
        reused_id["supplement_id"] = convergence.DESCENDANT_HISTORY_SUPPLEMENT_ID
        attacks.append((reused_id, "DESCENDANT_HISTORY_SUPPLEMENT_SUPPLEMENT_ID_MISMATCH"))
        predecessor_drift = copy.deepcopy(sealed["supplement"])
        predecessor_drift["previous_supplement_sha256"] = "0" * 64
        attacks.append((predecessor_drift, "DESCENDANT_HISTORY_V3_PREVIOUS_SUPPLEMENT_SHA256_MISMATCH"))
        dropped = copy.deepcopy(sealed["supplement"])
        dropped_fingerprint = dropped["descendant_history_fingerprints"].pop()
        dropped["descendant_history_failure_count"] -= 1
        dropped["descendant_history_fingerprint_set_sha256"] = convergence._line_set_sha(
            dropped["descendant_history_fingerprints"]
        )
        dropped["identity_binding_by_failure"].pop(dropped_fingerprint)
        attacks.append((dropped, "DESCENDANT_HISTORY_V3_PREVIOUS_DESCENDANT_IDENTITY_DROPPED"))
        bool_count = copy.deepcopy(sealed["supplement"])
        bool_count["scanner_evolution"]["removed_rule_count"] = False
        attacks.append((bool_count, "DESCENDANT_HISTORY_V3_REMOVED_RULE_COUNT_TYPE_INVALID"))
        sequence = copy.deepcopy(sealed["supplement"])
        sequence["scanner_evolution"]["scanner_change_commit_shas"] = []
        attacks.append((sequence, "DESCENDANT_HISTORY_V3_SCANNER_CHANGE_COMMIT_SEQUENCE_MISMATCH"))
        for document, expected in attacks:
            _write_json(sealed["supplement_path"], document)
            result = convergence._validate_descendant_history_supplement_v3(
                fixture,
                sealed["supplement_path"],
                sealed["raw_path"],
                sealed["scanner_path"],
                evaluated_head=sealed["head"],
                baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
                expected_raw_head=sealed["head"],
                expected_raw_tree=sealed["tree"],
                expected_raw_sha256=sealed["raw_sha"],
                expected_scanner_sha256=sealed["scanner_sha"],
            )
            _expect_failure(result["failures"], expected)
            independent = independent_audit._descendant_history_supplement_findings(
                fixture,
                supplement_path=sealed["supplement_path"],
                raw_report_path=sealed["raw_path"],
                scanner_path=sealed["scanner_path"],
                evaluated_head=sealed["head"],
                baseline_report=baseline,
                baseline_sets=baseline_sets,
                expected_v3_raw_head=sealed["head"],
                expected_v3_raw_tree=sealed["tree"],
                expected_v3_raw_sha=sealed["raw_sha"],
                expected_v3_scanner_sha=sealed["scanner_sha"],
            )[0]
            _expect(independent, f"independent accepted {expected}")
        downgrade = convergence.load_json_strict(fixture / REAL_DESCENDANT_SUPPLEMENT_REL)
        _write_json(sealed["supplement_path"], downgrade)
        downgraded = convergence.validate_descendant_history_supplement(
            fixture,
            sealed["supplement_path"],
            sealed["raw_path"],
            sealed["scanner_path"],
            evaluated_head=sealed["head"],
            baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
        )
        _expect_failure(
            downgraded["failures"],
            "DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION_MISMATCH",
        )
        _write_json(sealed["supplement_path"], sealed["supplement"])
        schema_path = fixture / convergence.SUCCESSOR_SCHEMA_REL
        schema = convergence.load_json_strict(schema_path)
        schema["active_descendant_history_supplement_id"] = convergence.DESCENDANT_HISTORY_SUPPLEMENT_ID
        _write_json(schema_path, schema)
        result = convergence._validate_descendant_history_supplement_v3(
            fixture,
            sealed["supplement_path"],
            sealed["raw_path"],
            sealed["scanner_path"],
            evaluated_head=sealed["head"],
            baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
            expected_raw_head=sealed["head"],
            expected_raw_tree=sealed["tree"],
            expected_raw_sha256=sealed["raw_sha"],
            expected_scanner_sha256=sealed["scanner_sha"],
        )
        _expect_failure(result["failures"], "DESCENDANT_HISTORY_V3_SCHEMA_SHA256_MISMATCH")


def _v3_builder_append_only_negative_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-v3-builder-") as temporary:
        fixture = Path(temporary)
        output = fixture / "already-exists.json"
        output.write_text("sentinel\n", encoding="utf-8")
        command = [
            sys.executable,
            str(root / "tools/v076/v076_reuse_full_convergence_descendant_supplement_builder.py"),
            "--project", str(root),
            "--baseline-report", str(root / convergence.BASELINE_REPORT_REL),
            "--raw-report", str(root / REAL_DESCENDANT_RAW_REL),
            "--scanner", str(root / convergence.DESCENDANT_HISTORY_SCANNER_REL),
            "--previous-supplement", str(root / REAL_DESCENDANT_SUPPLEMENT_REL),
            "--output", str(output),
        ]
        completed = subprocess.run(command, check=False, capture_output=True, text=True)
        _expect(completed.returncode != 0, "builder overwrote an existing output")
        _expect("OUTPUT_ALREADY_EXISTS" in completed.stderr, completed.stderr)
        _expect(output.read_text(encoding="utf-8") == "sentinel\n", "existing output drifted")
        atomic_output = fixture / "atomic.json"
        atomic_temp = atomic_output.with_suffix(".json.tmp")
        atomic_temp.write_bytes(b"owned-temp")
        try:
            successor_builder._publish_exclusive(b"new", atomic_output)
            raise AssertionError("builder overwrote an existing temp")
        except FileExistsError:
            pass
        _expect(atomic_temp.read_bytes() == b"owned-temp", "preexisting temp drifted")
        atomic_temp.unlink()
        atomic_output.write_bytes(b"owned-output")
        try:
            successor_builder._publish_exclusive(b"new", atomic_output)
            raise AssertionError("builder overwrote an output race")
        except FileExistsError:
            pass
        _expect(atomic_output.read_bytes() == b"owned-output", "racing output drifted")
        _expect(not atomic_temp.exists(), "builder leaked its temporary file")
        atomic_output.unlink()
        successor_builder._publish_exclusive(b"published", atomic_output)
        _expect(atomic_output.read_bytes() == b"published", "exclusive publish failed")
        _expect(not atomic_temp.exists(), "successful publish leaked temp")


def _schema_blob_fixture(root: Path, fixture: Path) -> tuple[Path, str, bytes]:
    """Commit the real LF predecessor blob into a minimal isolated repo."""

    _git(fixture, "init", "--quiet")
    _git(fixture, "config", "user.email", "selftest@example.invalid")
    _git(fixture, "config", "user.name", "V076 Selftest")
    relative = convergence.PREDECESSOR_SCHEMA_REL.as_posix()
    source_head = _git(root, "rev-parse", "HEAD")
    committed = convergence._git_bytes(root, source_head, relative)
    _expect(committed is not None, "real predecessor schema blob is missing")
    _expect(
        convergence.sha256_bytes(committed) == convergence.PREDECESSOR_SCHEMA_SHA256,
        "real predecessor schema blob digest drifted",
    )
    path = fixture / convergence.PREDECESSOR_SCHEMA_REL
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(committed)
    _git(fixture, "add", "--", relative)
    _git(fixture, "commit", "--quiet", "-m", "sealed predecessor schema")
    return path, _git(fixture, "rev-parse", "HEAD"), committed


def _schema_blob_lf_crlf_portability_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-schema-eol-") as temporary:
        fixture = Path(temporary)
        path, head, committed = _schema_blob_fixture(root, fixture)

        def assert_accepted(label: str) -> None:
            primary = convergence._committed_blob_seal_failures(
                fixture,
                path,
                convergence.PREDECESSOR_SCHEMA_SHA256,
                evaluated_head=head,
                code_prefix="SELFTEST_SCHEMA",
            )
            _expect(not primary, f"primary rejected {label}: {primary}")
            independent = independent_audit._sealed_tree_blob_finding(
                fixture,
                path,
                evaluated_head=head,
                expected_sha=independent_audit.FULL_CONVERGENCE_SCHEMA_SHA,
                code="SELFTEST_SCHEMA_DRIFT",
                message="schema drift",
            )
            _expect(independent is None, f"independent rejected {label}: {independent}")

        path.write_bytes(committed)
        assert_accepted("LF")
        path.write_bytes(committed.replace(b"\n", b"\r\n"))
        assert_accepted("CRLF")

        path.write_bytes(committed.replace(b"wildcard_allowed", b"wildcard_changed", 1))
        primary = convergence._committed_blob_seal_failures(
            fixture,
            path,
            convergence.PREDECESSOR_SCHEMA_SHA256,
            evaluated_head=head,
            code_prefix="SELFTEST_SCHEMA",
        )
        _expect_failure(primary, "SELFTEST_SCHEMA_WORKTREE_CONTENT_DRIFT")
        independent = independent_audit._sealed_tree_blob_finding(
            fixture,
            path,
            evaluated_head=head,
            expected_sha=independent_audit.FULL_CONVERGENCE_SCHEMA_SHA,
            code="SELFTEST_SCHEMA_DRIFT",
            message="schema drift",
        )
        _expect(independent is not None, "independent accepted real worktree drift")


def _schema_committed_predecessor_drift_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-schema-commit-drift-") as temporary:
        fixture = Path(temporary)
        path, _, committed = _schema_blob_fixture(root, fixture)
        path.write_bytes(committed.replace(b"wildcard_allowed", b"wildcard_changed", 1))
        _git(fixture, "add", "--", convergence.PREDECESSOR_SCHEMA_REL.as_posix())
        _git(fixture, "commit", "--quiet", "-m", "drift predecessor schema")
        drift_head = _git(fixture, "rev-parse", "HEAD")
        primary = convergence._committed_blob_seal_failures(
            fixture,
            path,
            convergence.PREDECESSOR_SCHEMA_SHA256,
            evaluated_head=drift_head,
            code_prefix="SELFTEST_SCHEMA",
        )
        _expect_failure(primary, "SELFTEST_SCHEMA_COMMITTED_BLOB_SHA256_MISMATCH")
        independent = independent_audit._sealed_tree_blob_finding(
            fixture,
            path,
            evaluated_head=drift_head,
            expected_sha=independent_audit.FULL_CONVERGENCE_SCHEMA_SHA,
            code="SELFTEST_SCHEMA_DRIFT",
            message="schema drift",
        )
        _expect(independent is not None, "independent accepted committed predecessor drift")


def _v3_schema_committed_binding_negative_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-v3-schema-binding-") as temporary:
        fixture = Path(temporary)
        sealed = _write_v3_successor_fixture(root, fixture)
        good_head = sealed["head"]
        previous_head = _git(fixture, "rev-parse", f"{good_head}^1")

        primary = convergence.validate_descendant_history_successor_schema(
            fixture,
            evaluated_head=previous_head,
        )
        _expect_failure(
            primary,
            "DESCENDANT_HISTORY_V3_SCHEMA_COMMITTED_BLOB_SHA256_MISMATCH",
        )
        baseline = independent_audit._json(fixture / convergence.BASELINE_REPORT_REL)
        findings = independent_audit._descendant_history_successor_v3_findings(
            fixture,
            supplement_path=sealed["supplement_path"],
            raw_report_path=sealed["raw_path"],
            scanner_path=sealed["scanner_path"],
            evaluated_head=previous_head,
            baseline_report=baseline,
            baseline_sets=independent_audit._authorized_failure_fingerprint_sets(baseline),
            expected_raw_head=sealed["head"],
            expected_raw_tree=sealed["tree"],
            expected_raw_sha=sealed["raw_sha"],
            expected_scanner_sha=sealed["scanner_sha"],
        )
        _expect(
            any(row["code"] == "FULL_CONVERGENCE_DESCENDANT_V3_SCHEMA_INVALID" for row in findings),
            "independent accepted a successor from the wrong evaluated Head",
        )

        schema_path = fixture / convergence.SUCCESSOR_SCHEMA_REL
        original = convergence.load_json_strict(schema_path)
        attacks = []
        stale_previous = copy.deepcopy(original)
        stale_previous["previous_schema_sha256"] = "0" * 64
        attacks.append(stale_previous)
        closed_field_drift = copy.deepcopy(original)
        closed_field_drift["unexpected_authority"] = True
        attacks.append(closed_field_drift)
        for attack in attacks:
            _write_json(schema_path, attack)
            primary = convergence.validate_descendant_history_successor_schema(
                fixture,
                evaluated_head=good_head,
            )
            _expect(primary, "primary accepted successor schema worktree drift")
            independent = independent_audit._sealed_tree_blob_finding(
                fixture,
                schema_path,
                evaluated_head=good_head,
                expected_sha=independent_audit.FULL_CONVERGENCE_SUCCESSOR_SCHEMA_SHA,
                code="SELFTEST_SUCCESSOR_SCHEMA_DRIFT",
                message="successor schema drift",
            )
            _expect(independent is not None, "independent accepted successor schema drift")


def _validate_real_reconciliation(root: Path) -> dict[str, Any]:
    return convergence.validate_frozen_descendant_history_predecessor(
        root,
        evaluated_head=_git(root, "rev-parse", "HEAD"),
        baseline_report_path=root / convergence.BASELINE_REPORT_REL,
    )


def _real_missing19_novel10_positive_case(root: Path) -> None:
    result = _validate_real_reconciliation(root)
    _expect(result["status"] == "PASS", json.dumps(result["failures"]))
    _expect(len(result["authorized_historical_fingerprints"]) == 501, "live != 501")
    _expect(len(result["registered_historical_fingerprints"]) == 520, "registered != 520")
    _expect(len(result["dispositioned_historical_fingerprints"]) == 19, "dispositioned != 19")
    dispositions = result["frozen_identity_disposition_by_failure"].values()
    _expect(
        sum(
            row.get("disposition")
            == convergence.EXACT_SUCCESSOR_FINGERPRINT_MAPPING
            for row in dispositions
        )
        == 3,
        "exact successor disposition count != 3",
    )
    _expect(
        sum(
            row.get("disposition")
            == convergence.EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT
            for row in dispositions
        )
        == 16,
        "exact false-component retirement count != 16",
    )
    baseline = independent_audit._json(root / convergence.BASELINE_REPORT_REL)
    independent = independent_audit._descendant_history_supplement_findings(
        root,
        supplement_path=root / REAL_DESCENDANT_SUPPLEMENT_REL,
        raw_report_path=root / REAL_DESCENDANT_RAW_REL,
        scanner_path=root / convergence.DESCENDANT_HISTORY_SCANNER_REL,
        evaluated_head=_git(root, "rev-parse", "HEAD"),
        baseline_report=baseline,
        baseline_sets=independent_audit._authorized_failure_fingerprint_sets(
            baseline
        ),
        require_live_scanner_bytes=False,
    )
    _expect(not independent[0], json.dumps(independent[0], sort_keys=True))
    _expect(len(independent[1]) == 10, "independent novel != 10")
    _expect(len(independent[2]) == 501, "independent live != 501")
    _expect(len(independent[3]) == 19, "independent dispositioned != 19")


def _real_disposition_negative_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-real-disposition-negative-") as temporary:
        fixture = Path(temporary)
        _copy_real_reconciliation_fixture(root, fixture)
        supplement_path = fixture / REAL_DESCENDANT_SUPPLEMENT_REL
        original = convergence.load_json_strict(supplement_path)

        missing_one = copy.deepcopy(original)
        removed = next(iter(sorted(missing_one["frozen_identity_disposition_by_failure"])))
        missing_one["frozen_identity_disposition_by_failure"].pop(removed)
        _write_json(supplement_path, missing_one)
        result = _validate_real_reconciliation(fixture)
        _expect_failure(
            result["failures"],
            "DESCENDANT_HISTORY_FROZEN_DISPOSITION_SET_MISMATCH",
        )

        successor_drift = copy.deepcopy(original)
        successor_key = next(
            key
            for key, row in successor_drift[
                "frozen_identity_disposition_by_failure"
            ].items()
            if row["disposition"]
            == convergence.EXACT_SUCCESSOR_FINGERPRINT_MAPPING
        )
        successor_drift["frozen_identity_disposition_by_failure"][successor_key][
            "evidence"
        ]["successor_subject_value"] = "scripts/not-the-successor.gd"
        _write_json(supplement_path, successor_drift)
        result = _validate_real_reconciliation(fixture)
        _expect_failure(
            result["failures"],
            "DESCENDANT_HISTORY_SUCCESSOR_EVIDENCE_SUCCESSOR_SUBJECT_VALUE_MISMATCH",
        )

        false_target_drift = copy.deepcopy(original)
        false_key = next(
            key
            for key, row in false_target_drift[
                "frozen_identity_disposition_by_failure"
            ].items()
            if row["disposition"]
            == convergence.EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT
        )
        false_target_drift["frozen_identity_disposition_by_failure"][false_key][
            "evidence"
        ]["dynamic_reference_ids"] = []
        _write_json(supplement_path, false_target_drift)
        result = _validate_real_reconciliation(fixture)
        _expect_failure(
            result["failures"],
            "DESCENDANT_HISTORY_FALSE_COMPONENT_DYNAMIC_TARGET_INVALID",
        )


def _disposed_identity_reappearance_fails_case(root: Path) -> None:
    authority = _validate_real_reconciliation(root)
    _expect(authority["status"] == "PASS", json.dumps(authority["failures"]))
    disposed_fingerprint = sorted(
        authority["dispositioned_historical_fingerprints"]
    )[0]
    disposed_raw = authority["registered_identity_by_fingerprint"][
        disposed_fingerprint
    ]["raw_failure"]
    with tempfile.TemporaryDirectory(prefix="v076-fc-disposed-reappears-") as temporary:
        live_path = Path(temporary) / "live.json"
        live = convergence.load_json_strict(root / REAL_DESCENDANT_RAW_REL)
        live["failures"] = sorted([*live["failures"], disposed_raw])
        _write_json(live_path, live)
        report = legacy_resolver._classify_full_convergence_live_raw(
            live_path,
            current_head=_git(root, "rev-parse", "HEAD"),
            authorized_identity_by_fingerprint=authority[
                "authorized_identity_by_fingerprint"
            ],
            registered_identity_by_fingerprint=authority[
                "registered_identity_by_fingerprint"
            ],
            disposition_by_failure=authority[
                "frozen_identity_disposition_by_failure"
            ],
        )
    _expect(report["status"] == "FAIL", json.dumps(report, sort_keys=True))
    _expect_failure(
        report["failures"],
        "RAW_DISPOSITIONED_HISTORICAL_FAILURE_REAPPEARED:1",
    )


def _real_live_terminal_coverage_case(root: Path) -> None:
    authority = _validate_real_reconciliation(root)
    live = set(authority["authorized_historical_fingerprints"])
    disposed = set(authority["dispositioned_historical_fingerprints"])
    legacy = set(
        convergence.verify_legacy_anchor(root)["legacy_corrected_fingerprints"]
    )
    full = live - legacy
    _expect(len(live) == 501 and len(legacy) == 12 and len(full) == 489, "501-12 coverage drift")
    _expect(
        not legacy_resolver._full_convergence_terminal_coverage_failures(
            authorized_historical=live,
            legacy_exact=legacy,
            full_fingerprints=full,
            terminal=True,
        ),
        "exact live terminal coverage rejected",
    )
    disposed_extra = next(iter(disposed))
    failures = legacy_resolver._full_convergence_terminal_coverage_failures(
        authorized_historical=live,
        legacy_exact=legacy,
        full_fingerprints=full | {disposed_extra},
        terminal=True,
    )
    _expect_failure(failures, "EFFECTIVE_FULL_CONVERGENCE_COVERAGE_EXTRA:1")


def _independent_record_contract_parity_case(root: Path) -> None:
    fingerprint = _fingerprint(1)

    nested_extra = _record()
    nested_extra["identity_binding_by_failure"][fingerprint][
        "unexpected_wildcard"
    ] = "*"
    nested_extra["record_payload_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(convergence._record_payload(nested_extra))
    )
    nested_findings = independent_audit._full_convergence_record_contract_findings(
        nested_extra,
        path="fixture-record.json",
    )
    _expect(
        any(
            item["code"]
            == "FULL_CONVERGENCE_IDENTITY_BINDING_FIELD_SET_INVALID"
            for item in nested_findings
        ),
        json.dumps(nested_findings, sort_keys=True),
    )
    _expect_failure(
        convergence.validate_extension_record_document(nested_extra),
        "IDENTITY_BINDING_FIELD_SET_MISMATCH",
    )

    selector_extra = _record()
    selector_extra["identity_binding_by_failure"][fingerprint][
        "authority_selectors"
    ]["glob"] = "*"
    selector_extra["record_payload_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(convergence._record_payload(selector_extra))
    )
    selector_findings = independent_audit._full_convergence_record_contract_findings(
        selector_extra,
        path="fixture-record.json",
    )
    _expect(
        any(
            item["code"]
            == "FULL_CONVERGENCE_SUBJECT_SELECTOR_FIELD_SET_INVALID"
            for item in selector_findings
        ),
        json.dumps(selector_findings, sort_keys=True),
    )
    _expect_failure(
        convergence.validate_extension_record_document(selector_extra),
        "SUBJECT_SELECTOR_FIELD_SET_MISMATCH",
    )

    semantic = _record()
    binding = semantic["identity_binding_by_failure"][fingerprint]
    binding["recommended_disposition"] = "HISTORICAL_WILDCARD_WAIVER"
    semantic["to_effective_disposition"] = "WAIVED"
    semantic["allowed_to_state"] = "WAIVED"
    semantic["required_untouched_state"] = False
    semantic["touch_invalidation_policy"] = dict(_touch_policy())
    semantic["touch_invalidation_policy"]["TOUCH_INVALIDATES_CORRECTION"] = False
    semantic["revocation_policy"] = {
        "OLD_RECORD_MUTATION_FORBIDDEN": False,
        "REVOCATION_APPEND_ONLY": False,
    }
    semantic["path_set_sha256"] = "0" * 64
    semantic["record_payload_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(convergence._record_payload(semantic))
    )
    semantic_findings = independent_audit._full_convergence_record_contract_findings(
        semantic,
        path="fixture-record.json",
    )
    semantic_codes = {item["code"] for item in semantic_findings}
    for expected_code in (
        "FULL_CONVERGENCE_IDENTITY_DISPOSITION_INVALID",
        "FULL_CONVERGENCE_RECORD_AGGREGATE_SET_INVALID",
        "FULL_CONVERGENCE_RECORD_REVOCATION_POLICY_INVALID",
        "FULL_CONVERGENCE_RECORD_TO_STATE_INVALID",
        "FULL_CONVERGENCE_RECORD_TOUCH_POLICY_INVALID",
        "FULL_CONVERGENCE_RECORD_UNTOUCHED_ATTESTATION_INVALID",
    ):
        _expect(
            expected_code in semantic_codes,
            json.dumps(semantic_findings, sort_keys=True),
        )
    primary_failures = convergence.validate_extension_record_document(semantic)
    for expected_failure in (
        "EXTENSION_RECORD_PATH_SET_SHA256_MISMATCH",
        "EXTENSION_RECORD_REVOCATION_POLICY_INVALID",
        "EXTENSION_RECORD_TO_STATE_INVALID",
        "EXTENSION_RECORD_TOUCH_POLICY_INVALID",
        "EXTENSION_RECORD_UNTOUCHED_ATTESTATION_INVALID",
        "IDENTITY_BINDING_DISPOSITION_INVALID",
    ):
        _expect_failure(primary_failures, expected_failure)

    authority = _record()
    authority_head = _git(root, "rev-parse", "HEAD")
    authority["binding_head_sha"] = authority_head
    authority["binding_tree_sha"] = _git(
        root,
        "rev-parse",
        f"{authority_head}^{{tree}}",
    )
    authority["authority_source_sha256"] = {
        relative: convergence.sha256_bytes(
            convergence._git_bytes(root, authority_head, relative) or b""
        )
        for relative in independent_audit.FULL_CONVERGENCE_AUTHORITY_SOURCE_PATHS
    }
    authority["record_payload_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(convergence._record_payload(authority))
    )
    authority_findings = independent_audit._full_convergence_record_contract_findings(
        authority,
        path="fixture-record.json",
        root=root,
    )
    _expect(
        not any(
            item["code"]
            == "FULL_CONVERGENCE_RECORD_AUTHORITY_SOURCE_HASH_MISMATCH"
            for item in authority_findings
        ),
        json.dumps(authority_findings, sort_keys=True),
    )
    tampered_authority_path = (
        independent_audit.FULL_CONVERGENCE_AUTHORITY_SOURCE_PATHS[0]
    )
    authority["authority_source_sha256"][tampered_authority_path] = "0" * 64
    authority["record_payload_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(convergence._record_payload(authority))
    )
    authority_findings = independent_audit._full_convergence_record_contract_findings(
        authority,
        path="fixture-record.json",
        root=root,
    )
    _expect(
        any(
            item["code"]
            == "FULL_CONVERGENCE_RECORD_AUTHORITY_SOURCE_HASH_MISMATCH"
            for item in authority_findings
        ),
        json.dumps(authority_findings, sort_keys=True),
    )


def _independent_current_manifest_binding_parity_case(root: Path) -> None:
    manifest = _batch()
    unauthorized_head = _git(
        root,
        "rev-parse",
        f"{convergence.AUTHORIZATION_BASE_HEAD_SHA}^{{commit}}^",
    )
    manifest["binding_head_sha"] = unauthorized_head
    manifest["binding_tree_sha"] = _git(
        root,
        "rev-parse",
        f"{unauthorized_head}^{{tree}}",
    )
    manifest["batch_id"] = "batch-wildcard"
    manifest["batch_size_target"] = "ANY_SIZE"
    manifest["terminal_remainder_batch"] = "false"
    manifest["descendant_history_supplement_sha256"] = "8" * 64
    findings = independent_audit._manifest_contract_findings(
        root,
        root / "unused-batch-manifest.json",
        manifest,
        evaluated_head=_git(root, "rev-parse", "HEAD"),
        baseline_identities={},
        descendant_supplement_sha="9" * 64,
    )
    codes = {item["code"] for item in findings}
    for expected_code in (
        "FULL_CONVERGENCE_BATCH_AUTHORITY_MISMATCH",
        "FULL_CONVERGENCE_BATCH_ID_INVALID",
        "FULL_CONVERGENCE_DESCENDANT_HISTORY_MANIFEST_HASH_MISMATCH",
        "FULL_CONVERGENCE_MANIFEST_BINDING_HEAD_NOT_AUTHORIZED_DESCENDANT",
        "FULL_CONVERGENCE_TERMINAL_REMAINDER_FLAG_INVALID",
    ):
        _expect(expected_code in codes, json.dumps(findings, sort_keys=True))
    primary_failures = convergence.validate_batch_manifest_document(manifest)
    for expected_failure in (
        "BATCH_MANIFEST_BATCH_ID_INVALID",
        "BATCH_MANIFEST_BATCH_SIZE_TARGET_MISMATCH",
        "BATCH_MANIFEST_TERMINAL_REMAINDER_FLAG_INVALID",
    ):
        _expect_failure(primary_failures, expected_failure)


def _projection_contract_results(
    binding: dict[str, Any],
    *,
    rule_id: str = "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
    raw_failure: str = "",
    fingerprint: str = _fingerprint(1),
) -> tuple[list[str], list[dict[str, Any]]]:
    return (
        convergence._identity_projection_failures(
            binding,
            rule_id=rule_id,
            raw_failure=raw_failure,
            fingerprint=fingerprint,
        ),
        independent_audit._identity_projection_findings(
            binding,
            path="fixture-record.json",
            fingerprint=fingerprint,
            rule_id=rule_id,
            raw_failure=raw_failure,
        ),
    )


def _expect_projection_rejected_by_both(
    binding: dict[str, Any],
    *,
    primary_prefix: str,
    independent_code: str,
    rule_id: str = "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
    raw_failure: str = "",
    fingerprint: str = _fingerprint(1),
) -> None:
    primary, independent = _projection_contract_results(
        binding,
        rule_id=rule_id,
        raw_failure=raw_failure,
        fingerprint=fingerprint,
    )
    _expect_failure(primary, primary_prefix)
    codes = {str(item.get("code", "")) for item in independent}
    _expect(
        independent_code in codes,
        f"missing {independent_code}: {json.dumps(independent, sort_keys=True)}",
    )


def _expect_registry_row_rejected_by_both(
    row: dict[str, Any],
    *,
    primary_prefixes: tuple[str, ...],
    independent_codes: tuple[str, ...],
) -> None:
    primary = convergence._registry_row_failures(row)
    independent = independent_audit._full_convergence_registry_row_findings(
        row,
        path="fixture-record.json",
        fingerprint=_fingerprint(1),
    )
    _expect(
        any(
            any(value.startswith(prefix) for value in primary)
            for prefix in primary_prefixes
        ),
        f"Primary accepted malicious Registry row: {primary}",
    )
    codes = {str(item.get("code", "")) for item in independent}
    _expect(
        any(code in codes for code in independent_codes),
        "Independent accepted malicious Registry row: "
        + json.dumps(independent, sort_keys=True),
    )


def _minimal_historical_backfill_positive_case() -> None:
    binding = _identity_binding()
    backfills = [
        row
        for row in binding["subject_projection"]["registry_rows"]
        if row.get("authority_source_kind") == "historical_identity_backfill"
    ]
    _expect(len(backfills) == 1, f"minimal backfill count drifted: {backfills}")
    _expect(
        set(backfills[0]) == convergence.REGISTRY_HISTORICAL_BACKFILL_FIELDS,
        f"minimal backfill fields drifted: {sorted(backfills[0])}",
    )
    _expect(
        not convergence._registry_row_failures(backfills[0]),
        str(convergence._registry_row_failures(backfills[0])),
    )
    independent_row_findings = (
        independent_audit._full_convergence_registry_row_findings(
            backfills[0],
            path="fixture-record.json",
            fingerprint=_fingerprint(1),
        )
    )
    _expect(
        not independent_row_findings,
        json.dumps(independent_row_findings, sort_keys=True),
    )
    primary, independent = _projection_contract_results(binding)
    _expect(not primary, str(primary))
    _expect(not independent, json.dumps(independent, sort_keys=True))


def _historical_backfill_field_expansion_attack_case() -> None:
    row = _historical_backfill_row(
        supersession=["component.current.owner"],
        owns_tick=True,
    )
    _expect_registry_row_rejected_by_both(
        row,
        primary_prefixes=("IDENTITY_BINDING_BACKFILL_FIELD_SET_INVALID",),
        independent_codes=(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_BACKFILL_FIELD_SET_INVALID",
        ),
    )


def _registry_role_matrix_attack_case() -> None:
    fake_role = _component_inventory_row(
        component_id="component.fake.role",
        path="scripts/fake/role.gd",
        role="FORGED_OWNER",
        owner_component_id="component.current.owner",
        owner_path="scripts/current/owner.gd",
    )
    _expect_registry_row_rejected_by_both(
        fake_role,
        primary_prefixes=("IDENTITY_BINDING_REGISTRY_ROLE_INVALID",),
        independent_codes=(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_ROLE_INVALID",
        ),
    )

    consumer_authority = _component_inventory_row(
        component_id="component.fake.consumer",
        path="scripts/fake/consumer.gd",
        role="CONSUMER",
        owner_component_id="component.current.owner",
        owner_path="scripts/current/owner.gd",
        writes_authority=True,
        owns_tick=True,
    )
    _expect_registry_row_rejected_by_both(
        consumer_authority,
        primary_prefixes=(
            "IDENTITY_BINDING_REGISTRY_NONOWNER_OWNERSHIP_INVALID",
            "IDENTITY_BINDING_REGISTRY_NONOWNER_WRITE_INVALID",
        ),
        independent_codes=(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONOWNER_OWNERSHIP_INVALID",
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONOWNER_WRITE_INVALID",
        ),
    )


def _lineage_substitution_binding(disposition: str) -> dict[str, Any]:
    binding = _identity_binding()
    binding["recommended_disposition"] = disposition
    binding["superseded_by"] = []
    binding["supersedes"] = []
    binding["authority_selectors"]["supersession_ids"] = []
    binding["subject_projection"]["supersession_rows"] = []
    inventory = next(
        row
        for row in binding["subject_projection"]["registry_rows"]
        if row.get("authority_source_kind") == "component_inventory"
    )
    backfill = next(
        row
        for row in binding["subject_projection"]["registry_rows"]
        if row.get("authority_source_kind") == "historical_identity_backfill"
    )
    inventory["supersedes"] = []
    backfill["current_disposition"] = disposition
    backfill["supersession"] = []
    if disposition == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED":
        binding["historical_production_reachability"] = "PRODUCTION_REACHABLE"
        binding["retired_status"] = "ACTIVE_LINEAGE"
        backfill["production_reachability"] = "PRODUCTION_REACHABLE"
    elif disposition == "HISTORICAL_RETIRED_NONREACHABLE":
        binding["current_production_reachability"] = "NONREACHABLE"
        binding["current_role"] = "RETIRED"
        binding["historical_production_reachability"] = "NONREACHABLE"
        binding["historical_role"] = "RETIRED"
        binding["retired_status"] = "RETIRED_NONREACHABLE"
        inventory.update({
            "component_role": "RETIRED",
            "owns_identity": False,
            "production_reachable": False,
            "reuse_disposition": "REFERENCE_ONLY",
            "writes_authority": False,
        })
        backfill["historical_role"] = "RETIRED"
        backfill["production_reachability"] = "NONREACHABLE"
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    return binding


def _alpha01_active_backfill_path_link_binding(root: Path) -> dict[str, Any]:
    selector = {
        "component_ids": sorted([
            convergence.ALPHA01_COMPONENT_ID,
            convergence.ALPHA01_OWNER_COMPONENT_ID,
        ]),
        "dynamic_reference_ids": [],
        "paths": sorted([
            convergence.ALPHA01_SCRIPT_PATH,
            convergence.ALPHA01_RESOURCE_PATH,
        ]),
        "retirement_ids": [],
        "supersession_ids": [],
    }
    head = _git(root, "rev-parse", "HEAD")
    projection = convergence.subject_projection(root, head, selector)
    return {
        "authority_selectors": selector,
        "current_blob_sha256": convergence.ALPHA01_RESOURCE_SHA256,
        "current_component_id": convergence.ALPHA01_COMPONENT_ID,
        "current_owner_id": convergence.ALPHA01_OWNER_COMPONENT_ID,
        "current_path": convergence.ALPHA01_RESOURCE_PATH,
        "current_production_reachability": "PRODUCTION_REACHABLE",
        "current_role": "PORT",
        "diagnostic_only_status": "NOT_DIAGNOSTIC_ONLY",
        "documentation_only_status": "NOT_DOCUMENTATION_ONLY",
        "domain_id": convergence.ALPHA01_DOMAIN_ID,
        "duplicate_identity_sha256": "",
        "duplicate_of_failure_fingerprint": "",
        "duplicate_reason": "",
        "dynamic_reference_status": "NOT_DYNAMIC_REFERENCE",
        "first_seen_commit": convergence.ALPHA01_TRANSITION_NEW_SHA,
        "generated_evidence_status": "NOT_GENERATED_EVIDENCE",
        "historical_blob_sha256": convergence.ALPHA01_SCRIPT_SHA256,
        "historical_component_id": convergence.ALPHA01_COMPONENT_ID,
        "historical_owner_id": convergence.ALPHA01_OWNER_COMPONENT_ID,
        "historical_path": convergence.ALPHA01_SCRIPT_PATH,
        "historical_production_reachability": "PRODUCTION_REACHABLE",
        "historical_role": "PORT",
        "invalidation_policy": _touch_policy(),
        "last_seen_commit": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "recommended_disposition": "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
        "retired_status": "ACTIVE_LINEAGE",
        "source_commit": convergence.ALPHA01_TRANSITION_NEW_SHA,
        "subject_projection": projection,
        "subject_projection_sha256": convergence.sha256_bytes(
            convergence.canonical_bytes(projection)
        ),
        "superseded_by": [],
        "supersedes": [],
        "test_only_status": "NOT_TEST_ONLY",
    }


def _alpha01_projection_row(
    binding: dict[str, Any],
    *,
    source_kind: str,
    component_id: str,
) -> dict[str, Any]:
    rows = [
        row
        for row in binding["subject_projection"]["registry_rows"]
        if row.get("authority_source_kind") == source_kind
        and row.get("component_id") == component_id
    ]
    _expect(
        len(rows) == 1,
        f"Alpha01 projection row cardinality drifted: {source_kind}:{component_id}",
    )
    return rows[0]


def _refresh_projection_hash(binding: dict[str, Any]) -> None:
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )


def _alpha01_active_backfill_path_link_positive_case(root: Path) -> None:
    binding_result = convergence.validate_implementation_binding_v4(
        root,
        evaluated_head=_git(root, "rev-parse", "HEAD"),
    )
    _expect(binding_result.get("status") == "PASS", str(binding_result))
    independent_binding_findings, _ = (
        independent_audit._alpha01_successor_v4_findings(
            root,
            _git(root, "rev-parse", "HEAD"),
        )
    )
    _expect(
        not independent_binding_findings,
        json.dumps(independent_binding_findings, sort_keys=True),
    )
    binding = _alpha01_active_backfill_path_link_binding(root)
    disposition_failures = convergence._identity_disposition_failures(
        binding,
        rule_id="HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
    )
    _expect(not disposition_failures, str(disposition_failures))
    primary, independent = _projection_contract_results(
        binding,
        fingerprint=convergence.ALPHA01_ACTIVE_BACKFILL_FINGERPRINT,
    )
    _expect(not primary, str(primary))
    _expect(not independent, json.dumps(independent, sort_keys=True))


def _alpha01_active_backfill_path_link_mutation_case(root: Path) -> None:
    exact_fingerprint = convergence.ALPHA01_ACTIVE_BACKFILL_FINGERPRINT

    def mutate_row(
        binding: dict[str, Any],
        source_kind: str,
        component_id: str,
        field: str,
        value: Any,
    ) -> None:
        _alpha01_projection_row(
            binding,
            source_kind=source_kind,
            component_id=component_id,
        )[field] = value

    def append_row(
        binding: dict[str, Any],
        source_kind: str,
        component_id: str,
        **updates: Any,
    ) -> None:
        row = copy.deepcopy(_alpha01_projection_row(
            binding,
            source_kind=source_kind,
            component_id=component_id,
        ))
        row.update(updates)
        binding["subject_projection"]["registry_rows"].append(row)

    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("source_commit", lambda b: b.update({"source_commit": "4" * 40})),
        (
            "historical_blob",
            lambda b: b.update({"historical_blob_sha256": "4" * 64}),
        ),
        ("current_blob", lambda b: b.update({"current_blob_sha256": "5" * 64})),
        (
            "historical_path",
            lambda b: b.update({"historical_path": "resources/content/alpha01/other.gd"}),
        ),
        (
            "current_path",
            lambda b: b.update({"current_path": "resources/content/alpha01/other.tres"}),
        ),
        (
            "historical_component",
            lambda b: b.update({"historical_component_id": "component.other"}),
        ),
        (
            "current_component",
            lambda b: b.update({"current_component_id": "component.other"}),
        ),
        ("historical_role", lambda b: b.update({"historical_role": "CONSUMER"})),
        ("current_role", lambda b: b.update({"current_role": "CONSUMER"})),
        (
            "historical_owner",
            lambda b: b.update({"historical_owner_id": "component.other.owner"}),
        ),
        (
            "current_owner",
            lambda b: b.update({"current_owner_id": "component.other.owner"}),
        ),
        ("domain", lambda b: b.update({"domain_id": "domain.other"})),
        (
            "historical_reachability",
            lambda b: b.update({"historical_production_reachability": "NONREACHABLE"}),
        ),
        (
            "current_reachability",
            lambda b: b.update({"current_production_reachability": "NONREACHABLE"}),
        ),
        (
            "selector_path_expansion",
            lambda b: b["authority_selectors"]["paths"].append("resources/content/alpha01/extra.res"),
        ),
        ("supersedes", lambda b: b.update({"supersedes": ["component.other"]})),
        (
            "superseded_by",
            lambda b: b.update({"superseded_by": ["component.other"]}),
        ),
        (
            "backfill_disposition",
            lambda b: mutate_row(
                b,
                "historical_identity_backfill",
                convergence.ALPHA01_COMPONENT_ID,
                "current_disposition",
                "HISTORICAL_TEST_ONLY",
            ),
        ),
        (
            "backfill_source_commit",
            lambda b: mutate_row(
                b,
                "historical_identity_backfill",
                convergence.ALPHA01_COMPONENT_ID,
                "source_commit",
                "4" * 40,
            ),
        ),
        (
            "backfill_source_blob",
            lambda b: mutate_row(
                b,
                "historical_identity_backfill",
                convergence.ALPHA01_COMPONENT_ID,
                "source_blob",
                "4" * 64,
            ),
        ),
        (
            "backfill_supersession",
            lambda b: mutate_row(
                b,
                "historical_identity_backfill",
                convergence.ALPHA01_COMPONENT_ID,
                "supersession",
                ["component.other"],
            ),
        ),
        (
            "extra_historical_backfill",
            lambda b: append_row(
                b,
                "historical_identity_backfill",
                convergence.ALPHA01_COMPONENT_ID,
                source_commit="4" * 40,
            ),
        ),
        (
            "duplicate_current_inventory",
            lambda b: append_row(
                b,
                "component_inventory",
                convergence.ALPHA01_COMPONENT_ID,
            ),
        ),
        (
            "current_registry_path",
            lambda b: mutate_row(
                b,
                "component_inventory",
                convergence.ALPHA01_COMPONENT_ID,
                "path",
                "resources/content/alpha01/other.tres",
            ),
        ),
        (
            "current_registry_role",
            lambda b: mutate_row(
                b,
                "component_inventory",
                convergence.ALPHA01_COMPONENT_ID,
                "component_role",
                "CONSUMER",
            ),
        ),
        (
            "current_registry_owner",
            lambda b: mutate_row(
                b,
                "component_inventory",
                convergence.ALPHA01_COMPONENT_ID,
                "owner_component_id",
                "component.other.owner",
            ),
        ),
        (
            "current_registry_domain",
            lambda b: mutate_row(
                b,
                "component_inventory",
                convergence.ALPHA01_COMPONENT_ID,
                "domain_id",
                "domain.other",
            ),
        ),
        (
            "current_registry_reachability",
            lambda b: mutate_row(
                b,
                "component_inventory",
                convergence.ALPHA01_COMPONENT_ID,
                "production_reachable",
                False,
            ),
        ),
        (
            "implementation_registry_row",
            lambda b: mutate_row(
                b,
                "component_inventory",
                convergence.ALPHA01_COMPONENT_ID,
                "class_name",
                "ForgedAlpha01ContentManifestResource",
            ),
        ),
        (
            "owner_path",
            lambda b: mutate_row(
                b,
                "component_inventory",
                convergence.ALPHA01_OWNER_COMPONENT_ID,
                "path",
                "scripts/other_owner.gd",
            ),
        ),
    ]

    for label, mutate in mutations:
        candidate = _alpha01_active_backfill_path_link_binding(root)
        mutate(candidate)
        _refresh_projection_hash(candidate)
        try:
            _expect_projection_rejected_by_both(
                candidate,
                primary_prefix="IDENTITY_BINDING_UNAUTHORIZED_LINEAGE_SUBSTITUTION",
                independent_code=(
                    "FULL_CONVERGENCE_IDENTITY_UNAUTHORIZED_LINEAGE_SUBSTITUTION"
                ),
                fingerprint=exact_fingerprint,
            )
        except AssertionError as exc:
            raise AssertionError(f"Alpha01 mutation {label} was not closed: {exc}") from exc

    for label, fingerprint, rule_id in (
        ("fingerprint", _fingerprint(2), "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"),
        ("rule", exact_fingerprint, "HISTORY_GOLDEN_FALSE_GREEN"),
    ):
        candidate = _alpha01_active_backfill_path_link_binding(root)
        try:
            _expect_projection_rejected_by_both(
                candidate,
                primary_prefix="IDENTITY_BINDING_UNAUTHORIZED_LINEAGE_SUBSTITUTION",
                independent_code=(
                    "FULL_CONVERGENCE_IDENTITY_UNAUTHORIZED_LINEAGE_SUBSTITUTION"
                ),
                fingerprint=fingerprint,
                rule_id=rule_id,
            )
        except AssertionError as exc:
            raise AssertionError(f"Alpha01 mutation {label} was not closed: {exc}") from exc

    def break_unique_script_link(document: dict[str, Any]) -> None:
        document["script_link"]["unique_script_link"] = False

    primary_binding_result = _v4_json_attack(
        root,
        convergence.ALPHA01_IMPLEMENTATION_BINDING_REL,
        break_unique_script_link,
    )
    _expect(primary_binding_result.get("status") == "FAIL", str(primary_binding_result))
    _expect_failure(
        primary_binding_result["failures"],
        "SUCCESSOR_V4_SCRIPT_LINK_CONTENT_INVALID",
    )

    original_json = independent_audit._json
    target = (root / independent_audit.ALPHA01_BINDING).resolve()

    def attacked_json(path: Path) -> Any:
        value = original_json(path)
        if path.resolve() == target:
            value = copy.deepcopy(value)
            break_unique_script_link(value)
        return value

    independent_audit._json = attacked_json
    try:
        independent_findings, _ = independent_audit._alpha01_successor_v4_findings(
            root,
            _git(root, "rev-parse", "HEAD"),
        )
    finally:
        independent_audit._json = original_json
    independent_codes = {
        str(item.get("code", "")) for item in independent_findings
    }
    _expect(
        "FULL_CONVERGENCE_ALPHA01_SCRIPT_LINK" in independent_codes,
        json.dumps(independent_findings, sort_keys=True),
    )


def _unrelated_active_path_drift_still_rejected_case(root: Path) -> None:
    binding = _alpha01_active_backfill_path_link_binding(root)
    historical_alias = "resources/content/alpha01/unrelated_alias.gd"
    current_alias = "resources/content/alpha01/unrelated_alias.tres"
    binding["historical_path"] = historical_alias
    binding["current_path"] = current_alias
    binding["authority_selectors"]["paths"] = sorted([
        historical_alias,
        current_alias,
    ])
    _alpha01_projection_row(
        binding,
        source_kind="component_inventory",
        component_id=convergence.ALPHA01_COMPONENT_ID,
    )["path"] = current_alias
    _refresh_projection_hash(binding)
    _expect_projection_rejected_by_both(
        binding,
        primary_prefix="IDENTITY_BINDING_UNAUTHORIZED_LINEAGE_SUBSTITUTION",
        independent_code=(
            "FULL_CONVERGENCE_IDENTITY_UNAUTHORIZED_LINEAGE_SUBSTITUTION"
        ),
        fingerprint=convergence.ALPHA01_ACTIVE_BACKFILL_FINGERPRINT,
    )


def _unrelated_lineage_substitution_attack_case() -> None:
    for disposition in (
        "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
        "HISTORICAL_RETIRED_NONREACHABLE",
    ):
        binding = _lineage_substitution_binding(disposition)
        _expect_projection_rejected_by_both(
            binding,
            primary_prefix="IDENTITY_BINDING_UNAUTHORIZED_LINEAGE_SUBSTITUTION",
            independent_code=(
                "FULL_CONVERGENCE_IDENTITY_UNAUTHORIZED_LINEAGE_SUBSTITUTION"
            ),
        )


def _active_plus_test_only_attack_case() -> None:
    binding = _lineage_substitution_binding(
        "HISTORICAL_ACTIVE_LINEAGE_REGISTERED"
    )
    binding["test_only_status"] = "TEST_ONLY"
    primary = convergence._identity_disposition_failures(
        binding,
        rule_id="HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
    )
    _expect_failure(primary, "IDENTITY_BINDING_DISPOSITION_STATE_MATRIX_INVALID")
    record = _record()
    record["identity_binding_by_failure"][_fingerprint(1)] = binding
    record["record_payload_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(convergence._record_payload(record))
    )
    findings = independent_audit._full_convergence_record_contract_findings(
        record,
        path="fixture-record.json",
    )
    codes = {str(item.get("code", "")) for item in findings}
    _expect(
        "FULL_CONVERGENCE_IDENTITY_DISPOSITION_STATE_MATRIX_INVALID" in codes,
        json.dumps(findings, sort_keys=True),
    )


def _authority_primary_key_attack_case(kind: str) -> None:
    binding = _identity_binding()
    if kind == "registry":
        row = copy.deepcopy(binding["subject_projection"]["registry_rows"][0])
        row["path"] = "scripts/current/malicious_duplicate_owner.gd"
        binding["subject_projection"]["registry_rows"].append(row)
        primary_prefix = "IDENTITY_BINDING_REGISTRY_PRIMARY_KEY_NOT_UNIQUE"
        independent_code = (
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_PRIMARY_KEY_NOT_UNIQUE"
        )
    elif kind == "dynamic":
        binding["authority_selectors"]["dynamic_reference_ids"] = [
            "dynamic.sample"
        ]
        binding["subject_projection"]["dynamic_reference_rows"] = [
            {"dynamic_reference_id": "dynamic.sample"},
            {"dynamic_reference_id": "dynamic.sample"},
        ]
        primary_prefix = (
            "IDENTITY_BINDING_DYNAMIC_REFERENCE_PRIMARY_KEY_NOT_UNIQUE"
        )
        independent_code = (
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_PRIMARY_KEY_NOT_UNIQUE"
        )
    elif kind == "supersession":
        binding["subject_projection"]["supersession_rows"].append(
            copy.deepcopy(binding["subject_projection"]["supersession_rows"][0])
        )
        primary_prefix = (
            "IDENTITY_BINDING_SUPERSESSION_PRIMARY_KEY_NOT_UNIQUE"
        )
        independent_code = (
            "FULL_CONVERGENCE_IDENTITY_SUPERSESSION_PRIMARY_KEY_NOT_UNIQUE"
        )
    elif kind == "retirement":
        binding["authority_selectors"]["retirement_ids"] = [
            "retirement.sample"
        ]
        retirement = {
            "component_id": "component.history.sample",
            "domain_id": "domain.sample",
            "dual_write_count": 0,
            "fallback_count": 0,
            "production_reachable": False,
            "retired_status": "RETIRED_NONREACHABLE",
            "retirement_id": "retirement.sample",
        }
        binding["subject_projection"]["supersession_rows"].extend([
            retirement,
            copy.deepcopy(retirement),
        ])
        primary_prefix = "IDENTITY_BINDING_RETIREMENT_PRIMARY_KEY_NOT_UNIQUE"
        independent_code = (
            "FULL_CONVERGENCE_IDENTITY_RETIREMENT_PRIMARY_KEY_NOT_UNIQUE"
        )
    else:
        raise AssertionError(f"unknown authority kind: {kind}")
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    _expect_projection_rejected_by_both(
        binding,
        primary_prefix=primary_prefix,
        independent_code=independent_code,
    )


def _supersedes_wildcard_attack_case() -> None:
    binding = _identity_binding()
    inventory = next(
        row
        for row in binding["subject_projection"]["registry_rows"]
        if row.get("authority_source_kind") == "component_inventory"
    )
    inventory["supersedes"] = ["*"]
    binding["supersedes"] = ["*"]
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    _expect_projection_rejected_by_both(
        binding,
        primary_prefix="IDENTITY_BINDING_REGISTRY_RELATION_SET_INVALID:supersedes",
        independent_code=(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_RELATION_SET_INVALID"
        ),
    )


def _historical_backfill_exact_identity_attack_case() -> None:
    binding = _identity_binding()
    backfill = next(
        row
        for row in binding["subject_projection"]["registry_rows"]
        if row.get("authority_source_kind") == "historical_identity_backfill"
    )
    backfill["source_blob"] = "4" * 64
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    _expect_projection_rejected_by_both(
        binding,
        primary_prefix="IDENTITY_BINDING_HISTORICAL_BACKFILL_ROW_NOT_UNIQUE",
        independent_code=(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_ROW_NOT_UNIQUE"
        ),
    )


def _dynamic_reference_fixture_row(source_bytes: bytes) -> dict[str, Any]:
    targets = ["res://targets/a.tscn"]
    return {
        "callsite_contract": {
            "allowed_argument_constants": ["TARGET_A"],
            "external_or_unknown_invocation_count": 0,
            "helper_function": "_load_optional",
            "required_invocation_count": 1,
            "required_loader_sites": [{
                "column": 9,
                "line": 7,
                "loader": "load",
                "reference_expression": "path",
            }],
        },
        "dynamic_reference_id": "dynamic.selftest.optional_load",
        "failure_policy": {
            "future_site_auto_resolution_count": 0,
            "source_blob_change_invalidates": True,
            "source_location_change_invalidates": True,
            "target_set_change_invalidates": True,
            "unknown_callsite_fails_closed": True,
            "wildcard_count": 0,
        },
        "loader": "load",
        "production_reachable": True,
        "reference_expression": "path",
        "resolution_method": "EXACT_CONSTANT_CALL_GRAPH_MANIFEST",
        "resolved_targets": targets,
        "runtime_probe": {
            "expected_target_count": 1,
            "probe_id": "dynamic_probe_test",
            "required_before_production_claim": True,
            "test_path": "tests/dynamic_probe_test.gd",
        },
        "source_blob_sha256": convergence.sha256_bytes(source_bytes),
        "source_line_or_ast_location": {
            "column": 9,
            "containing_function": "_load_optional",
            "line": 7,
        },
        "source_path": "scripts/dynamic_source.gd",
        "target_set_sha256": convergence._dynamic_target_set_sha256(targets),
    }


def _dynamic_reference_repo_forgery_attack_case() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-dynamic-forgery-") as temporary:
        root = Path(temporary)
        _git(root, "init", "--quiet")
        _git(root, "config", "user.email", "selftest@example.invalid")
        _git(root, "config", "user.name", "V076 Selftest")
        source = (
            'const TARGET_A := "res://targets/a.tscn"\n'
            "\n"
            "func _ready():\n"
            "    _load_optional(TARGET_A)\n"
            "\n"
            "func _load_optional(path):\n"
            "        load(path)\n"
        ).encode("utf-8")
        source_path = root / "scripts/dynamic_source.gd"
        source_path.parent.mkdir(parents=True)
        source_path.write_bytes(source)
        target_path = root / "targets/a.tscn"
        target_path.parent.mkdir(parents=True)
        target_path.write_text("[gd_scene format=3]\n", encoding="utf-8")
        test_path = root / "tests/dynamic_probe_test.gd"
        test_path.parent.mkdir(parents=True)
        test_path.write_text("extends SceneTree\n", encoding="utf-8")
        _git(root, "add", "scripts", "targets", "tests")
        _git(root, "commit", "--quiet", "-m", "dynamic fixture")
        head = _git(root, "rev-parse", "HEAD")
        valid_projection = {
            "dynamic_reference_rows": [_dynamic_reference_fixture_row(source)]
        }
        primary_valid = convergence._dynamic_projection_repo_failures(
            root,
            head,
            valid_projection,
            source_commit=head,
        )
        independent_valid = independent_audit._dynamic_projection_repo_findings(
            root,
            head,
            valid_projection,
            source_commit=head,
            path="fixture-record.json",
            fingerprint=_fingerprint(1),
        )
        _expect(not primary_valid, str(primary_valid))
        _expect(
            not independent_valid,
            json.dumps(independent_valid, sort_keys=True),
        )

        attacks = []
        wrong_location = copy.deepcopy(valid_projection)
        wrong_location["dynamic_reference_rows"][0][
            "source_line_or_ast_location"
        ]["line"] = 6
        attacks.append((
            wrong_location,
            "DYNAMIC_REFERENCE_SOURCE_LOCATION_MISMATCH",
            "FULL_CONVERGENCE_DYNAMIC_REFERENCE_SOURCE_LOCATION_MISMATCH",
        ))
        wrong_constant = copy.deepcopy(valid_projection)
        wrong_constant["dynamic_reference_rows"][0]["callsite_contract"][
            "allowed_argument_constants"
        ] = ["FORGED_TARGET"]
        attacks.append((
            wrong_constant,
            "DYNAMIC_REFERENCE_CALLSITE_TARGET_BINDING_MISMATCH",
            "FULL_CONVERGENCE_DYNAMIC_REFERENCE_CALLSITE_TARGET_BINDING_MISMATCH",
        ))
        wrong_target = copy.deepcopy(valid_projection)
        wrong_target["dynamic_reference_rows"][0]["resolved_targets"] = [
            "res://targets/missing.tscn"
        ]
        wrong_target["dynamic_reference_rows"][0]["target_set_sha256"] = (
            convergence._dynamic_target_set_sha256([
                "res://targets/missing.tscn"
            ])
        )
        attacks.append((
            wrong_target,
            "DYNAMIC_REFERENCE_TARGET_MISSING",
            "FULL_CONVERGENCE_DYNAMIC_REFERENCE_TARGET_MISSING",
        ))
        for projection, primary_prefix, independent_code in attacks:
            primary = convergence._dynamic_projection_repo_failures(
                root,
                head,
                projection,
                source_commit=head,
            )
            independent = independent_audit._dynamic_projection_repo_findings(
                root,
                head,
                projection,
                source_commit=head,
                path="fixture-record.json",
                fingerprint=_fingerprint(1),
            )
            _expect_failure(primary, primary_prefix)
            codes = {str(item.get("code", "")) for item in independent}
            _expect(
                independent_code in codes,
                f"missing {independent_code}: "
                + json.dumps(independent, sort_keys=True),
            )


def _duplicate_evidence_forgery_attack_case(root: Path) -> None:
    canonical_fingerprint = _fingerprint(1)
    duplicate_fingerprint = _fingerprint(2)
    identities = {
        canonical_fingerprint: {
            "bucket": "HISTORICAL",
            "raw_failure": "HISTORY_SAMPLE:path:scripts/history/sample.gd:1111111:2222222",
            "rule_id": "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
            "subject_kind": "path",
            "subject_value": "scripts/history/sample.gd",
            "transition_new_prefix": "1111111",
            "transition_old_prefix": "2222222",
        },
        duplicate_fingerprint: {
            "bucket": "HISTORICAL",
            "raw_failure": "HISTORY_SAMPLE:path:scripts/history/sample.gd:3333333:4444444",
            "rule_id": "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
            "subject_kind": "path",
            "subject_value": "scripts/history/sample.gd",
            "transition_new_prefix": "3333333",
            "transition_old_prefix": "4444444",
        },
    }
    binding = _lineage_substitution_binding(
        "HISTORICAL_ACTIVE_LINEAGE_REGISTERED"
    )
    binding["recommended_disposition"] = "HISTORICAL_DUPLICATE_OBSERVATION"
    backfill = next(
        row
        for row in binding["subject_projection"]["registry_rows"]
        if row.get("authority_source_kind") == "historical_identity_backfill"
    )
    backfill["current_disposition"] = "HISTORICAL_DUPLICATE_OBSERVATION"
    binding["duplicate_of_failure_fingerprint"] = canonical_fingerprint
    binding["duplicate_identity_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(
            convergence._duplicate_identity_payload(
                identities[canonical_fingerprint]
            )
        )
    )
    binding["duplicate_reason"] = (
        "SAME_RULE_AND_SUBJECT_DISTINCT_TRANSITION_OBSERVATION"
    )
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    head = _git(root, "rev-parse", "HEAD")

    attacks = (
        (
            "target",
            {"duplicate_of_failure_fingerprint": _fingerprint(3)},
            "IDENTITY_DUPLICATE_OBSERVATION_AUTHORITY_MISMATCH",
        ),
        (
            "digest",
            {"duplicate_identity_sha256": "0" * 64},
            "IDENTITY_DUPLICATE_OBSERVATION_AUTHORITY_MISMATCH",
        ),
        (
            "reason",
            {"duplicate_reason": "FORGED_DUPLICATE_REASON"},
            "IDENTITY_BINDING_DUPLICATE_EVIDENCE_INVALID",
        ),
    )
    for label, mutation, primary_prefix in attacks:
        attacked_binding = copy.deepcopy(binding)
        attacked_binding.update(mutation)
        record = _record([duplicate_fingerprint])
        record["identity_binding_by_failure"] = {
            duplicate_fingerprint: attacked_binding
        }
        record["binding_head_sha"] = head
        record["binding_tree_sha"] = _git(root, "rev-parse", f"{head}^{{tree}}")
        record["authority_source_sha256"] = {
            relative: convergence.sha256_bytes(
                convergence._git_bytes(root, head, relative) or b""
            )
            for relative in convergence.AUTHORITY_SOURCE_PATHS
        }
        record["record_payload_sha256"] = convergence.sha256_bytes(
            convergence.canonical_bytes(convergence._record_payload(record))
        )
        primary = convergence.validate_extension_record_against_repo(
            root,
            record,
            evaluated_head=head,
            authorized_identities=identities,
        )
        _expect_failure(primary, primary_prefix)
        independent = independent_audit._duplicate_observation_findings(
            duplicate_fingerprint,
            attacked_binding,
            identities,
            path="fixture-record.json",
        )
        codes = {str(item.get("code", "")) for item in independent}
        _expect(
            "FULL_CONVERGENCE_IDENTITY_DUPLICATE_OBSERVATION_AUTHORITY_MISMATCH"
            in codes,
            f"Independent accepted forged duplicate {label}: "
            + json.dumps(independent, sort_keys=True),
        )


def _expect_both_codes(
    primary: list[str],
    independent: list[dict[str, Any]],
    *,
    primary_prefixes: tuple[str, ...],
    independent_codes: tuple[str, ...],
) -> None:
    for prefix in primary_prefixes:
        _expect_failure(primary, prefix)
    codes = {str(item.get("code", "")) for item in independent}
    for code in independent_codes:
        _expect(
            code in codes,
            f"missing {code}: {json.dumps(independent, sort_keys=True)}",
        )


def _dynamic_identity_binding() -> dict[str, Any]:
    source = (
        'const TARGET_A := "res://targets/a.tscn"\n'
        "\n"
        "func _ready():\n"
        "    _load_optional(TARGET_A)\n"
        "\n"
        "func _load_optional(path):\n"
        "        load(path)\n"
    ).encode("utf-8")
    binding = _identity_binding()
    binding["recommended_disposition"] = (
        "HISTORICAL_DYNAMIC_REFERENCE_SUPERSEDED"
    )
    binding["dynamic_reference_status"] = "SUPERSEDED"
    binding["authority_selectors"]["dynamic_reference_ids"] = [
        "dynamic.selftest.optional_load"
    ]
    dynamic_row = _dynamic_reference_fixture_row(source)
    dynamic_row["source_path"] = "scripts/history/sample.gd"
    binding["subject_projection"]["dynamic_reference_rows"] = [dynamic_row]
    backfill = next(
        row
        for row in binding["subject_projection"]["registry_rows"]
        if row.get("authority_source_kind") == "historical_identity_backfill"
    )
    backfill["current_disposition"] = (
        "HISTORICAL_DYNAMIC_REFERENCE_SUPERSEDED"
    )
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    return binding


def _bool_supersession_count_attack_case() -> None:
    binding = _identity_binding()
    binding["subject_projection"]["supersession_rows"][0][
        "dual_write_count"
    ] = False
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    _expect_projection_rejected_by_both(
        binding,
        primary_prefix="IDENTITY_BINDING_SUPERSESSION_AUTHORITY_MISMATCH",
        independent_code=(
            "FULL_CONVERGENCE_IDENTITY_SUPERSESSION_AUTHORITY_MISMATCH"
        ),
    )


def _bool_dynamic_count_attack_case() -> None:
    binding = _dynamic_identity_binding()
    row = binding["subject_projection"]["dynamic_reference_rows"][0]
    row["callsite_contract"]["required_invocation_count"] = True
    row["callsite_contract"]["external_or_unknown_invocation_count"] = False
    row["runtime_probe"]["expected_target_count"] = True
    row["failure_policy"]["future_site_auto_resolution_count"] = False
    row["failure_policy"]["wildcard_count"] = False
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    primary, independent = _projection_contract_results(
        binding,
        rule_id="HISTORY_DYNAMIC_REFERENCE_UNRESOLVED",
    )
    _expect_both_codes(
        primary,
        independent,
        primary_prefixes=(
            "IDENTITY_BINDING_DYNAMIC_REFERENCE_CALLSITE_CONTRACT_INVALID",
            "IDENTITY_BINDING_DYNAMIC_REFERENCE_RUNTIME_PROBE_INVALID",
            "IDENTITY_BINDING_DYNAMIC_REFERENCE_FAILURE_POLICY_INVALID",
        ),
        independent_codes=(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_CALLSITE_CONTRACT_INVALID",
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_RUNTIME_PROBE_INVALID",
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_FAILURE_POLICY_INVALID",
        ),
    )


def _bool_dynamic_location_attack_case() -> None:
    binding = _dynamic_identity_binding()
    row = binding["subject_projection"]["dynamic_reference_rows"][0]
    row["source_line_or_ast_location"]["line"] = True
    row["source_line_or_ast_location"]["column"] = True
    loader_site = row["callsite_contract"]["required_loader_sites"][0]
    loader_site["line"] = True
    loader_site["column"] = True
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    primary, independent = _projection_contract_results(
        binding,
        rule_id="HISTORY_DYNAMIC_REFERENCE_UNRESOLVED",
    )
    _expect_both_codes(
        primary,
        independent,
        primary_prefixes=(
            "IDENTITY_BINDING_DYNAMIC_REFERENCE_METADATA_INVALID",
            "IDENTITY_BINDING_DYNAMIC_REFERENCE_LOADER_SITE_INVALID",
        ),
        independent_codes=(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_METADATA_INVALID",
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_LOADER_SITE_INVALID",
        ),
    )


def _bool_record_failure_count_attack_case() -> None:
    record = _record()
    record["failure_count"] = True
    record["record_payload_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(convergence._record_payload(record))
    )
    primary = convergence.validate_extension_record_document(record)
    independent = independent_audit._full_convergence_record_contract_findings(
        record,
        path="fixture-record.json",
    )
    _expect_both_codes(
        primary,
        independent,
        primary_prefixes=("EXTENSION_RECORD_FINGERPRINT_COUNT_MISMATCH",),
        independent_codes=(
            "FULL_CONVERGENCE_RECORD_FINGERPRINT_DIGEST_INVALID",
        ),
    )


def _bool_batch_count_attack_case(root: Path) -> None:
    manifest = _batch(1, terminal=True)
    manifest["failure_count"] = True
    manifest["batch_unknown_count"] = False
    manifest["batch_wildcard_count"] = False
    manifest["current_failure_false_accept_count"] = False
    head = _git(root, "rev-parse", "HEAD")
    manifest["binding_head_sha"] = head
    manifest["binding_tree_sha"] = _git(root, "rev-parse", f"{head}^{{tree}}")
    primary = convergence.validate_batch_manifest_document(manifest)
    independent = independent_audit._manifest_contract_findings(
        root,
        root / "unused-bool-batch-manifest.json",
        manifest,
        evaluated_head=head,
        baseline_identities={},
        descendant_supplement_sha=manifest[
            "descendant_history_supplement_sha256"
        ],
    )
    _expect_failure(primary, "BATCH_MANIFEST_FINGERPRINT_COUNT_MISMATCH")
    for field in (
        "batch_unknown_count",
        "batch_wildcard_count",
        "current_failure_false_accept_count",
    ):
        _expect_failure(
            primary,
            f"BATCH_MANIFEST_{field.upper()}_MISMATCH",
        )
    independent_codes = {
        str(item.get("code", "")) for item in independent
    }
    _expect(
        "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_COUNT_MISMATCH"
        in independent_codes,
        json.dumps(independent, sort_keys=True),
    )
    authority_fields = {
        str(item.get("evidence", {}).get("field", ""))
        for item in independent
        if item.get("code") == "FULL_CONVERGENCE_BATCH_AUTHORITY_MISMATCH"
        and isinstance(item.get("evidence"), dict)
    }
    _expect(
        {
            "batch_unknown_count",
            "batch_wildcard_count",
            "current_failure_false_accept_count",
        }.issubset(authority_fields),
        json.dumps(independent, sort_keys=True),
    )


def _bool_supplement_zero_count_attack_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(
        prefix="v076-fc-bool-supplement-counts-"
    ) as temporary:
        fixture = Path(temporary)
        _copy_real_reconciliation_fixture(root, fixture)
        supplement_path = fixture / REAL_DESCENDANT_SUPPLEMENT_REL
        supplement = convergence.load_json_strict(supplement_path)
        fields = (
            "disposition_wildcard_count",
            "raw_current_delta_failure_count",
            "raw_failure_detection_suppressed_count",
        )
        for field in fields:
            supplement[field] = False
        _write_json(supplement_path, supplement)
        primary = _validate_real_reconciliation(fixture)
        for field in fields:
            _expect_failure(
                primary["failures"],
                f"DESCENDANT_HISTORY_SUPPLEMENT_{field.upper()}_TYPE_INVALID",
            )
        baseline = independent_audit._json(
            fixture / convergence.BASELINE_REPORT_REL
        )
        independent = independent_audit._descendant_history_supplement_findings(
            fixture,
            supplement_path=supplement_path,
            raw_report_path=fixture / REAL_DESCENDANT_RAW_REL,
            scanner_path=fixture / convergence.DESCENDANT_HISTORY_SCANNER_REL,
            evaluated_head=_git(fixture, "rev-parse", "HEAD"),
            baseline_report=baseline,
            baseline_sets=(
                independent_audit._authorized_failure_fingerprint_sets(
                    baseline
                )
            ),
        )[0]
        authority_fields = {
            str(item.get("evidence", {}).get("field", ""))
            for item in independent
            if item.get("code")
            == "FULL_CONVERGENCE_DESCENDANT_HISTORY_AUTHORITY_MISMATCH"
            and isinstance(item.get("evidence"), dict)
        }
        _expect(
            set(fields).issubset(authority_fields),
            json.dumps(independent, sort_keys=True),
        )


def _diagnostic_only_active_lineage_attack_case() -> None:
    binding = _identity_binding()
    binding.update({
        "current_component_id": "component.diagonly",
        "current_owner_id": "component.current.owner",
        "current_path": "tools/diagonly.gd",
        "current_production_reachability": "PRODUCTION_REACHABLE",
        "current_role": "DIAGNOSTIC_ONLY",
        "historical_component_id": "component.diagonly",
        "historical_owner_id": "component.current.owner",
        "historical_path": "tools/diagonly.gd",
        "historical_production_reachability": "PRODUCTION_REACHABLE",
        "historical_role": "DIAGNOSTIC_ONLY",
        "recommended_disposition": "HISTORICAL_ACTIVE_LINEAGE_REGISTERED",
        "retired_status": "ACTIVE_LINEAGE",
        "superseded_by": [],
        "supersedes": [],
    })
    binding["authority_selectors"] = {
        "component_ids": ["component.current.owner", "component.diagonly"],
        "dynamic_reference_ids": [],
        "paths": ["tools/diagonly.gd"],
        "retirement_ids": [],
        "supersession_ids": [],
    }
    binding["subject_projection"] = {
        "dynamic_reference_rows": [],
        "owner_map_lines": [],
        "registry_rows": [
            _component_inventory_row(
                component_id="component.current.owner",
                path="scripts/current/owner.gd",
            ),
            _component_inventory_row(
                component_id="component.diagonly",
                path="tools/diagonly.gd",
                role="DIAGNOSTIC_ONLY",
                owner_component_id="component.current.owner",
                owner_path="scripts/current/owner.gd",
                production_reachable=True,
            ),
        ],
        "supersession_rows": [],
    }
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    _expect_projection_rejected_by_both(
        binding,
        primary_prefix=(
            "IDENTITY_BINDING_REGISTRY_NONPRODUCTION_ROLE_REACHABLE"
        ),
        independent_code=(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONPRODUCTION_ROLE_REACHABLE"
        ),
    )


def _historical_backfill_missing_field_attack_case() -> None:
    complete = _historical_backfill_row(
        supersession=["component.current.owner"]
    )
    for field in sorted(complete):
        row = copy.deepcopy(complete)
        row.pop(field)
        primary = convergence._registry_row_failures(row)
        independent = (
            independent_audit._full_convergence_registry_row_findings(
                row,
                path="fixture-record.json",
                fingerprint=_fingerprint(1),
            )
        )
        if field == "authority_source_kind":
            _expect_both_codes(
                primary,
                independent,
                primary_prefixes=(
                    "IDENTITY_BINDING_REGISTRY_SOURCE_KIND_INVALID",
                ),
                independent_codes=(
                    "FULL_CONVERGENCE_IDENTITY_REGISTRY_SOURCE_KIND_INVALID",
                ),
            )
        else:
            _expect_both_codes(
                primary,
                independent,
                primary_prefixes=(
                    "IDENTITY_BINDING_BACKFILL_FIELD_SET_INVALID",
                ),
                independent_codes=(
                    "FULL_CONVERGENCE_IDENTITY_REGISTRY_BACKFILL_FIELD_SET_INVALID",
                ),
            )


def _historical_backfill_no_inventory_fallback_attack_case() -> None:
    binding = _identity_binding()
    backfill = next(
        row
        for row in binding["subject_projection"]["registry_rows"]
        if row.get("authority_source_kind") == "historical_identity_backfill"
    )
    backfill["source_blob"] = "4" * 64
    binding["subject_projection"]["registry_rows"].append(
        _component_inventory_row(
            component_id="component.history.sample",
            path="scripts/history/sample.gd",
            role="CONSUMER",
            owner_component_id="component.current.owner",
            owner_path="scripts/current/owner.gd",
            production_reachable=False,
            superseded_by=["component.current.owner"],
        )
    )
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    _expect_projection_rejected_by_both(
        binding,
        primary_prefix="IDENTITY_BINDING_HISTORICAL_BACKFILL_ROW_NOT_UNIQUE",
        independent_code="FULL_CONVERGENCE_IDENTITY_REGISTRY_ROW_NOT_UNIQUE",
    )


def _historical_backfill_composite_key_attack_case() -> None:
    binding = _identity_binding()
    backfill = next(
        row
        for row in binding["subject_projection"]["registry_rows"]
        if row.get("authority_source_kind") == "historical_identity_backfill"
    )
    binding["subject_projection"]["registry_rows"].append(
        copy.deepcopy(backfill)
    )
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    _expect_projection_rejected_by_both(
        binding,
        primary_prefix="IDENTITY_BINDING_BACKFILL_PRIMARY_KEY_NOT_UNIQUE",
        independent_code=(
            "FULL_CONVERGENCE_IDENTITY_REGISTRY_BACKFILL_PRIMARY_KEY_NOT_UNIQUE"
        ),
    )


def _registry_closed_role_matrix_case() -> None:
    valid_rows = (
        _component_inventory_row(
            component_id="component.role.owner",
            path="scripts/roles/owner.gd",
        ),
        _component_inventory_row(
            component_id="component.role.reducer",
            path="scripts/roles/reducer.gd",
            role="REDUCER",
            owner_component_id="component.current.owner",
            owner_path="scripts/current/owner.gd",
            writes_authority=True,
        ),
        _component_inventory_row(
            component_id="component.role.consumer",
            path="scripts/roles/consumer.gd",
            role="CONSUMER",
            owner_component_id="component.current.owner",
            owner_path="scripts/current/owner.gd",
        ),
        _component_inventory_row(
            component_id="component.role.diagnostic",
            path="tools/roles/diagnostic.gd",
            role="DIAGNOSTIC_BENCH",
            owner_component_id="component.current.owner",
            owner_path="scripts/current/owner.gd",
            production_reachable=False,
            owns_presentation=True,
            reuse_disposition="REUSE_AS_TEST",
        ),
        _component_inventory_row(
            component_id="component.role.test_support",
            path="tests/roles/test_support.gd",
            role="TEST_SUPPORT",
            owner_component_id="component.current.owner",
            owner_path="scripts/current/owner.gd",
            production_reachable=False,
            reuse_disposition="REUSE_AS_TEST",
        ),
    )
    for row in valid_rows:
        primary = convergence._registry_row_failures(row)
        independent = (
            independent_audit._full_convergence_registry_row_findings(
                row,
                path="fixture-record.json",
                fingerprint=_fingerprint(1),
            )
        )
        _expect(not primary, str(primary))
        _expect(not independent, json.dumps(independent, sort_keys=True))

    attacks = (
        (
            _component_inventory_row(
                component_id="component.role.bad_owner",
                path="scripts/roles/bad_owner.gd",
                writes_authority=False,
            ),
            ("IDENTITY_BINDING_REGISTRY_OWNER_AUTHORITY_INVALID",),
            ("FULL_CONVERGENCE_IDENTITY_REGISTRY_OWNER_AUTHORITY_INVALID",),
        ),
        (
            _component_inventory_row(
                component_id="component.role.bad_reducer",
                path="scripts/roles/bad_reducer.gd",
                role="REDUCER",
                owner_component_id="component.current.owner",
                owner_path="scripts/current/owner.gd",
                writes_authority=True,
                owns_rng=True,
            ),
            ("IDENTITY_BINDING_REGISTRY_NONOWNER_OWNERSHIP_INVALID",),
            (
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONOWNER_OWNERSHIP_INVALID",
            ),
        ),
        (
            _component_inventory_row(
                component_id="component.role.bad_consumer",
                path="scripts/roles/bad_consumer.gd",
                role="CONSUMER",
                owner_component_id="component.current.owner",
                owner_path="scripts/current/owner.gd",
                writes_authority=True,
            ),
            ("IDENTITY_BINDING_REGISTRY_NONOWNER_WRITE_INVALID",),
            ("FULL_CONVERGENCE_IDENTITY_REGISTRY_NONOWNER_WRITE_INVALID",),
        ),
        (
            _component_inventory_row(
                component_id="component.role.bad_diagnostic",
                path="tools/roles/bad_diagnostic.gd",
                role="DIAGNOSTIC_BENCH",
                owner_component_id="component.current.owner",
                owner_path="scripts/current/owner.gd",
                production_reachable=True,
                owns_rng=True,
                reuse_disposition="REUSE_AS_TEST",
            ),
            (
                "IDENTITY_BINDING_REGISTRY_DIAGNOSTIC_OWNERSHIP_INVALID",
                "IDENTITY_BINDING_REGISTRY_NONPRODUCTION_ROLE_REACHABLE",
            ),
            (
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_DIAGNOSTIC_OWNERSHIP_INVALID",
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONPRODUCTION_ROLE_REACHABLE",
            ),
        ),
        (
            _component_inventory_row(
                component_id="component.role.bad_test_support",
                path="tests/roles/bad_test_support.gd",
                role="TEST_SUPPORT",
                owner_component_id="component.current.owner",
                owner_path="scripts/current/owner.gd",
                production_reachable=True,
                reuse_disposition="ADAPT_AS_CONSUMER",
            ),
            (
                "IDENTITY_BINDING_REGISTRY_NONPRODUCTION_ROLE_REACHABLE",
                "IDENTITY_BINDING_REGISTRY_TEST_DISPOSITION_INVALID",
            ),
            (
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_NONPRODUCTION_ROLE_REACHABLE",
                "FULL_CONVERGENCE_IDENTITY_REGISTRY_TEST_DISPOSITION_INVALID",
            ),
        ),
    )
    for row, primary_prefixes, independent_codes in attacks:
        _expect_both_codes(
            convergence._registry_row_failures(row),
            independent_audit._full_convergence_registry_row_findings(
                row,
                path="fixture-record.json",
                fingerprint=_fingerprint(1),
            ),
            primary_prefixes=primary_prefixes,
            independent_codes=independent_codes,
        )


def _dynamic_target_digest_attack_case() -> None:
    binding = _dynamic_identity_binding()
    binding["subject_projection"]["dynamic_reference_rows"][0][
        "target_set_sha256"
    ] = "0" * 64
    binding["subject_projection_sha256"] = convergence.sha256_bytes(
        convergence.canonical_bytes(binding["subject_projection"])
    )
    _expect_projection_rejected_by_both(
        binding,
        primary_prefix="IDENTITY_BINDING_DYNAMIC_REFERENCE_TARGET_SET_INVALID",
        independent_code=(
            "FULL_CONVERGENCE_IDENTITY_DYNAMIC_REFERENCE_TARGET_SET_INVALID"
        ),
        rule_id="HISTORY_DYNAMIC_REFERENCE_UNRESOLVED",
    )


def _subject_projection_trust_fixture() -> dict[str, dict[str, Any]]:
    return {
        _fingerprint(index): {
            "allowed_invalidations": ["SUBJECT_PROJECTION_CHANGED_INVALID"],
            "prior_record_path": (
                "docs/architecture/reuse_corrections/v2/records/"
                f"full_convergence_20260827/batch-006/fixture-{index:03d}.json"
            ),
            "revalidation_id": f"SPR-SELFTEST-{index:03d}",
            "record_path": (
                "docs/architecture/reuse_corrections/v2/"
                f"subject_projection_revalidation/records/fixture-{index:03d}.json"
            ),
            "revalidation_binding_head_sha": "a" * 40,
        }
        for index in range(1, 83)
    }


def _subject_projection_successor_v2_trust_fixture() -> dict[str, dict[str, Any]]:
    validator = convergence._subject_projection_revalidation_successor_v2
    return {
        fingerprint: {
            "allowed_invalidations": ["SUBJECT_PROJECTION_CHANGED_INVALID"],
            "prior_record_path": validator.PRIOR_RECORD_PATHS[fingerprint],
            "revalidation_id": f"SPR2-SELFTEST-{index}",
            "record_path": validator.EXPECTED_RECORD_PATHS[fingerprint],
            "revalidation_binding_head_sha": "a" * 40,
        }
        for index, fingerprint in enumerate(validator.TARGET_FINGERPRINTS, 1)
    }


def _subject_projection_dual_gate_and_parity_case() -> None:
    """No one-sided, miscounted, or nonidentical trust can escape the composite."""

    with tempfile.TemporaryDirectory(prefix="v076-spr-composite-") as temporary:
        root = Path(temporary).resolve()
        sidecar_path = root / "subject-projection-revalidation.json"
        current_batch_rel = (
            convergence._subject_projection_revalidation.CURRENT_BATCH_PATH
        )
        current_batch_path = root / current_batch_rel
        _write_json(
            sidecar_path,
            {"current_batch_manifest_path": current_batch_rel},
        )
        chain = [(current_batch_path, {"batch_id": "batch-007"})]
        pristine_trust = _subject_projection_trust_fixture()

        class DictSubclass(dict):
            pass

        class ListSubclass(list):
            pass

        class StringSubclass(str):
            pass

        def primary_result() -> dict[str, Any]:
            return {
                "status": "PASS",
                "failures": [],
                "trusted_by_fingerprint": copy.deepcopy(pristine_trust),
                "trusted_fingerprint_count": 82,
                "record_count": 82,
                "fingerprints": sorted(pristine_trust),
            }

        def independent_result() -> dict[str, Any]:
            return {
                "status": "GO",
                "findings": [],
                "trusted_by_fingerprint": copy.deepcopy(pristine_trust),
                "trusted_fingerprint_count": 82,
                "record_count": 82,
                "fingerprints": sorted(pristine_trust),
            }

        state = {
            "primary": primary_result(),
            "independent": independent_result(),
        }
        original_primary = (
            convergence._subject_projection_revalidation
            .validate_manifest_and_records
        )
        original_independent = (
            convergence._subject_projection_revalidation_independent
            .audit_manifest_and_records
        )

        def primary_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
            return copy.deepcopy(state["primary"])

        def independent_stub(*args: Any, **kwargs: Any) -> dict[str, Any]:
            return copy.deepcopy(state["independent"])

        convergence._subject_projection_revalidation.validate_manifest_and_records = (
            primary_stub
        )
        convergence._subject_projection_revalidation_independent.audit_manifest_and_records = (
            independent_stub
        )

        def evaluate(*, ledger_status: str = "PASS") -> dict[str, Any]:
            return convergence._subject_projection_revalidation_composite(
                root,
                sidecar_path,
                chain,
                evaluated_head="b" * 40,
                explicit_batch_chain_valid=True,
                historical_delta_metadata_ledger_status=ledger_status,
            )

        def reset() -> None:
            state["primary"] = primary_result()
            state["independent"] = independent_result()

        def expect_rejected(result: dict[str, Any], prefix: str) -> None:
            _expect(result["status"] == "FAIL", str(result))
            _expect(result["trusted_by_fingerprint"] == {}, str(result))
            _expect(result["trusted_fingerprint_count"] == 0, str(result))
            _expect_failure(result["failures"], prefix)

        try:
            accepted = evaluate()
            _expect(accepted["status"] == "PASS", str(accepted))
            _expect(
                accepted["trusted_by_fingerprint"] == pristine_trust,
                str(accepted),
            )

            reset()
            state["primary"]["failures"] = ""
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_FAILURES_NOT_STRING_LIST",
            )

            reset()
            state["independent"]["findings"] = None
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_INDEPENDENT_FINDINGS_NOT_STRING_LIST",
            )

            reset()
            state["primary"] = []
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_RESULT_NOT_OBJECT",
            )

            reset()
            state["primary"] = DictSubclass(state["primary"])
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_RESULT_NOT_OBJECT",
            )

            reset()
            state["independent"] = []
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_INDEPENDENT_RESULT_NOT_OBJECT",
            )

            reset()
            state["primary"]["status"] = StringSubclass("PASS")
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_STATUS_NOT_STRING",
            )

            reset()
            state["primary"]["failures"] = ListSubclass()
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_FAILURES_NOT_STRING_LIST",
            )

            reset()
            state["primary"]["trusted_by_fingerprint"] = []
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_TRUST_NOT_OBJECT",
            )

            reset()
            state["primary"]["trusted_by_fingerprint"] = DictSubclass(
                state["primary"]["trusted_by_fingerprint"]
            )
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_TRUST_NOT_OBJECT",
            )

            reset()
            state["primary"]["trusted_fingerprint_count"] = True
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_COUNT_INVALID",
            )

            reset()
            state["independent"]["record_count"] = True
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_INDEPENDENT_COUNT_INVALID",
            )

            reset()
            state["primary"]["fingerprints"] = ""
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_FINGERPRINT_SET_INVALID",
            )

            reset()
            state["primary"]["fingerprints"] = ListSubclass(
                state["primary"]["fingerprints"]
            )
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_FINGERPRINT_SET_INVALID",
            )

            reset()
            state["independent"]["fingerprints"] = sorted(pristine_trust)[:-1]
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_INDEPENDENT_FINGERPRINT_SET_INVALID",
            )

            reset()
            for label in ("primary", "independent"):
                state[label]["trusted_by_fingerprint"].pop(_fingerprint(1))
                state[label]["trusted_fingerprint_count"] = 81
                state[label]["record_count"] = 81
                state[label]["fingerprints"] = sorted(
                    state[label]["trusted_by_fingerprint"]
                )
            partial = evaluate()
            expect_rejected(
                partial,
                "SUBJECT_PROJECTION_PRIMARY_COUNT_INVALID",
            )
            _expect_failure(
                partial["failures"],
                "SUBJECT_PROJECTION_INDEPENDENT_COUNT_INVALID",
            )

            reset()
            state["primary"]["trusted_by_fingerprint"][_fingerprint(1)] = (
                DictSubclass(
                    state["primary"]["trusted_by_fingerprint"][_fingerprint(1)]
                )
            )
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_TRUST_ROW_SHAPE_INVALID",
            )

            reset()
            state["primary"]["trusted_by_fingerprint"][_fingerprint(1)][
                "allowed_invalidations"
            ] = ListSubclass(["SUBJECT_PROJECTION_CHANGED_INVALID"])
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_TRUST_POLICY_INVALID",
            )

            reset()
            original_row = state["primary"]["trusted_by_fingerprint"][
                _fingerprint(1)
            ]
            state["primary"]["trusted_by_fingerprint"][_fingerprint(1)] = {
                StringSubclass(key): value for key, value in original_row.items()
            }
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_PRIMARY_TRUST_ROW_SHAPE_INVALID",
            )

            reset()
            state["primary"]["status"] = "FAIL"
            state["primary"]["failures"] = ["PRIMARY_SELFTEST_FAILURE"]
            expect_rejected(evaluate(), "SUBJECT_PROJECTION_PRIMARY_REQUIRED_PASS")

            reset()
            state["independent"]["status"] = "NO_GO"
            state["independent"]["findings"] = ["INDEPENDENT_SELFTEST_FAILURE"]
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_INDEPENDENT_REQUIRED_GO",
            )

            reset()
            state["independent"]["trusted_by_fingerprint"].pop(_fingerprint(1))
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_INDEPENDENT_COUNT_INVALID",
            )
            _expect_failure(
                evaluate()["failures"],
                "SUBJECT_PROJECTION_TRUST_SET_PARITY_INVALID",
            )

            reset()
            state["independent"]["trusted_by_fingerprint"][_fingerprint(9000)] = {
                "allowed_invalidations": ["SUBJECT_PROJECTION_CHANGED_INVALID"],
                "prior_record_path": "docs/architecture/reuse_corrections/v2/records/extra.json",
            }
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_INDEPENDENT_TRUST_ROW_SHAPE_INVALID",
            )

            reset()
            state["independent"]["trusted_by_fingerprint"][_fingerprint(1)][
                "prior_record_path"
            ] = "docs/architecture/reuse_corrections/v2/records/wrong-prior.json"
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_TRUST_SET_PARITY_INVALID",
            )

            reset()
            state["independent"]["trusted_fingerprint_count"] = 81
            expect_rejected(
                evaluate(),
                "SUBJECT_PROJECTION_INDEPENDENT_COUNT_INVALID",
            )

            reset()
            expect_rejected(
                evaluate(ledger_status="FAIL"),
                "SUBJECT_PROJECTION_HDM_LEDGER_REQUIRED_PASS",
            )
        finally:
            (
                convergence._subject_projection_revalidation
                .validate_manifest_and_records
            ) = original_primary
            (
                convergence._subject_projection_revalidation_independent
                .audit_manifest_and_records
            ) = original_independent


def _subject_projection_four_gate_successor_case() -> None:
    """Committed successor trust is usable only as a disjoint 82 + 2 union."""

    with tempfile.TemporaryDirectory(prefix="v076-spr-four-gate-") as temporary:
        root = Path(temporary).resolve()
        v1_path = root / "subject-projection-revalidation.json"
        successor_path = root / "subject-projection-revalidation-successor-v2.json"
        v1_current = convergence._subject_projection_revalidation.CURRENT_BATCH_PATH
        successor_current = (
            convergence._subject_projection_revalidation_successor_v2
            .CURRENT_BATCH_PATH
        )
        _write_json(v1_path, {"current_batch_manifest_path": v1_current})
        _write_json(successor_path, {})
        chain = [
            (root / v1_current, {"batch_id": "batch-007"}),
            (root / successor_current, {"batch_id": "batch-008"}),
        ]
        v1_trust = _subject_projection_trust_fixture()
        successor_trust = _subject_projection_successor_v2_trust_fixture()

        def v1_primary(*args: Any, **kwargs: Any) -> dict[str, Any]:
            return {
                "status": "PASS", "failures": [],
                "trusted_by_fingerprint": copy.deepcopy(v1_trust),
                "trusted_fingerprint_count": 82, "record_count": 82,
                "fingerprints": sorted(v1_trust),
            }

        def v1_independent(*args: Any, **kwargs: Any) -> dict[str, Any]:
            return {
                "status": "GO", "findings": [],
                "trusted_by_fingerprint": copy.deepcopy(v1_trust),
                "trusted_fingerprint_count": 82, "record_count": 82,
                "fingerprints": sorted(v1_trust),
            }

        successor_state: dict[str, dict[str, Any]] = {}

        def reset_successor() -> None:
            common = {
                "mode": "COMMITTED", "trusted_by_fingerprint": (
                    copy.deepcopy(successor_trust)
                ),
                "review_trusted_by_fingerprint": copy.deepcopy(successor_trust),
                "trusted_fingerprint_count": 2,
                "review_trusted_fingerprint_count": 2,
                "record_count": 2,
                "fingerprints": sorted(successor_trust),
                "stage_only": False,
            }
            successor_state["primary"] = {
                **copy.deepcopy(common), "status": "PASS", "failures": [],
            }
            successor_state["independent"] = {
                **copy.deepcopy(common), "status": "GO", "findings": [],
            }

        reset_successor()
        original_v1_primary = (
            convergence._subject_projection_revalidation
            .validate_manifest_and_records
        )
        original_v1_independent = (
            convergence._subject_projection_revalidation_independent
            .audit_manifest_and_records
        )
        original_successor_primary = (
            convergence._subject_projection_revalidation_successor_v2
            .validate_manifest_and_records
        )
        original_successor_independent = (
            convergence._subject_projection_revalidation_successor_v2_independent
            .audit_manifest_and_records
        )
        convergence._subject_projection_revalidation.validate_manifest_and_records = (
            v1_primary
        )
        convergence._subject_projection_revalidation_independent.audit_manifest_and_records = (
            v1_independent
        )
        convergence._subject_projection_revalidation_successor_v2.validate_manifest_and_records = (
            lambda *args, **kwargs: copy.deepcopy(successor_state["primary"])
        )
        convergence._subject_projection_revalidation_successor_v2_independent.audit_manifest_and_records = (
            lambda *args, **kwargs: copy.deepcopy(successor_state["independent"])
        )

        def evaluate() -> dict[str, Any]:
            return convergence._subject_projection_revalidation_four_gate_composite(
                root,
                v1_path,
                successor_path,
                chain,
                evaluated_head="b" * 40,
                explicit_batch_chain_valid=True,
                historical_delta_metadata_ledger_status="PASS",
            )

        try:
            accepted = evaluate()
            _expect(accepted["status"] == "PASS", str(accepted))
            _expect(accepted["four_gate_complete"] is True, str(accepted))
            _expect(accepted["trusted_fingerprint_count"] == 84, str(accepted))
            _expect(accepted["union_fingerprint_count"] == 84, str(accepted))
            _expect(accepted["cross_epoch_overlap_count"] == 0, str(accepted))
            _expect(
                set(accepted["trusted_by_fingerprint"])
                == set(v1_trust) | set(successor_trust),
                str(accepted),
            )

            reset_successor()
            successor_state["primary"]["mode"] = "STAGE_REVIEW"
            rejected = evaluate()
            _expect(rejected["status"] == "FAIL", str(rejected))
            _expect(rejected["trusted_by_fingerprint"] == {}, str(rejected))
            _expect(rejected["v1_trusted_by_fingerprint"] == {}, str(rejected))
            _expect(
                rejected["successor_v2_trusted_by_fingerprint"] == {},
                str(rejected),
            )
            _expect_failure(
                rejected["failures"],
                "SUBJECT_PROJECTION_SUCCESSOR_V2_GATE:"
                "SUBJECT_PROJECTION_SUCCESSOR_V2_PRIMARY_COMMITTED_MODE_REQUIRED",
            )

            reset_successor()
            successor_state["primary"]["record_count"] = "two"
            rejected = evaluate()
            _expect(rejected["status"] == "FAIL", str(rejected))
            _expect(rejected["record_count"] == 82, str(rejected))
            _expect(rejected["trusted_by_fingerprint"] == {}, str(rejected))
            _expect(rejected["v1_trusted_by_fingerprint"] == {}, str(rejected))
            _expect(
                rejected["successor_v2_trusted_by_fingerprint"] == {},
                str(rejected),
            )
            _expect_failure(
                rejected["failures"],
                "SUBJECT_PROJECTION_SUCCESSOR_V2_RECORD_COUNT_INVALID",
            )

            reset_successor()
            unknown = _fingerprint(9900)
            replaced = next(iter(successor_trust))
            for label in ("primary", "independent"):
                row = successor_state[label]["trusted_by_fingerprint"].pop(
                    replaced
                )
                successor_state[label]["trusted_by_fingerprint"][unknown] = row
                review_row = successor_state[label][
                    "review_trusted_by_fingerprint"
                ].pop(replaced)
                successor_state[label]["review_trusted_by_fingerprint"][
                    unknown
                ] = review_row
                successor_state[label]["fingerprints"] = sorted(
                    successor_state[label]["trusted_by_fingerprint"]
                )
            rejected = evaluate()
            _expect(rejected["status"] == "FAIL", str(rejected))
            _expect(rejected["trusted_by_fingerprint"] == {}, str(rejected))
            _expect_failure(
                rejected["failures"],
                "SUBJECT_PROJECTION_SUCCESSOR_V2_GATE:"
                "SUBJECT_PROJECTION_SUCCESSOR_V2_PRIMARY_"
                "TRUST_FINGERPRINT_INVALID",
            )
        finally:
            convergence._subject_projection_revalidation.validate_manifest_and_records = (
                original_v1_primary
            )
            convergence._subject_projection_revalidation_independent.audit_manifest_and_records = (
                original_v1_independent
            )
            convergence._subject_projection_revalidation_successor_v2.validate_manifest_and_records = (
                original_successor_primary
            )
            convergence._subject_projection_revalidation_successor_v2_independent.audit_manifest_and_records = (
                original_successor_independent
            )

        original_v1_composite = (
            convergence._subject_projection_revalidation_composite
        )
        original_successor_composite = (
            convergence._subject_projection_revalidation_successor_v2_composite
        )
        overlap_trust = {
            next(iter(v1_trust)): next(iter(successor_trust.values())),
            next(iter(successor_trust)): next(iter(successor_trust.values())),
        }
        convergence._subject_projection_revalidation_composite = (
            lambda *args, **kwargs: {
                "status": "PASS", "failures": [], "record_count": 82,
                "primary_status": "PASS", "independent_status": "GO",
                "trust_set_parity": True,
                "trusted_by_fingerprint": v1_trust,
            }
        )
        convergence._subject_projection_revalidation_successor_v2_composite = (
            lambda *args, **kwargs: {
                "status": "PASS", "failures": [], "record_count": 2,
                "primary_status": "PASS", "independent_status": "GO",
                "trust_set_parity": True,
                "trusted_by_fingerprint": overlap_trust,
            }
        )
        try:
            rejected = evaluate()
        finally:
            convergence._subject_projection_revalidation_composite = (
                original_v1_composite
            )
            convergence._subject_projection_revalidation_successor_v2_composite = (
                original_successor_composite
            )
        _expect(rejected["status"] == "FAIL", str(rejected))
        _expect(rejected["trusted_by_fingerprint"] == {}, str(rejected))
        _expect_failure(
            rejected["failures"],
            "SUBJECT_PROJECTION_CROSS_EPOCH_TRUST_OVERLAP:1",
        )
        _expect_failure(
            rejected["failures"],
            "SUBJECT_PROJECTION_CROSS_EPOCH_TRUST_UNION_INVALID:83",
        )


def _subject_projection_routing_fail_closed_case() -> None:
    """Broken chains and every noncanonical/nonexplicit route stop before audit."""

    with tempfile.TemporaryDirectory(prefix="v076-spr-routing-") as temporary:
        root = Path(temporary).resolve()
        sidecar_path = root / "subject-projection-revalidation.json"
        current_batch_rel = (
            convergence._subject_projection_revalidation.CURRENT_BATCH_PATH
        )
        current_batch_path = root / current_batch_rel
        chain = [(current_batch_path, {"batch_id": "batch-007"})]

        _write_json(
            sidecar_path,
            {"current_batch_manifest_path": current_batch_rel},
        )
        failures, selected = (
            convergence._resolve_subject_projection_batch_manifest_path(
                root,
                sidecar_path,
                chain,
                explicit_batch_chain_valid=False,
            )
        )
        _expect_failure(
            failures,
            "SUBJECT_PROJECTION_EXPLICIT_BATCH_CHAIN_INVALID",
        )
        _expect(selected is None, f"broken chain routed to {selected}")

        calls = {"primary": 0, "independent": 0}
        original_primary = (
            convergence._subject_projection_revalidation
            .validate_manifest_and_records
        )
        original_independent = (
            convergence._subject_projection_revalidation_independent
            .audit_manifest_and_records
        )

        def unexpected_primary(*args: Any, **kwargs: Any) -> dict[str, Any]:
            calls["primary"] += 1
            raise AssertionError("broken chain reached primary SPR validator")

        def unexpected_independent(*args: Any, **kwargs: Any) -> dict[str, Any]:
            calls["independent"] += 1
            raise AssertionError("broken chain reached independent SPR validator")

        convergence._subject_projection_revalidation.validate_manifest_and_records = (
            unexpected_primary
        )
        convergence._subject_projection_revalidation_independent.audit_manifest_and_records = (
            unexpected_independent
        )
        try:
            broken = convergence._subject_projection_revalidation_composite(
                root,
                sidecar_path,
                [
                    (root / current_batch_rel.replace("batch-007", "batch-001"), {}),
                    (current_batch_path, {}),
                ],
                evaluated_head="b" * 40,
                explicit_batch_chain_valid=False,
                historical_delta_metadata_ledger_status="PASS",
            )
        finally:
            (
                convergence._subject_projection_revalidation
                .validate_manifest_and_records
            ) = original_primary
            (
                convergence._subject_projection_revalidation_independent
                .audit_manifest_and_records
            ) = original_independent
        _expect(broken["status"] == "FAIL", str(broken))
        _expect(broken["trusted_by_fingerprint"] == {}, str(broken))
        _expect(calls == {"primary": 0, "independent": 0}, str(calls))

        nonexplicit = current_batch_rel.replace("batch-007", "batch-999")
        _write_json(
            sidecar_path,
            {"current_batch_manifest_path": nonexplicit},
        )
        failures, selected = (
            convergence._resolve_subject_projection_batch_manifest_path(
                root,
                sidecar_path,
                chain,
            )
        )
        _expect_failure(
            failures,
            "SUBJECT_PROJECTION_CURRENT_BATCH_MANIFEST_NOT_IN_EXPLICIT_CHAIN",
        )
        _expect(selected is None, f"nonexplicit batch routed to {selected}")

        aliases = [
            f" {current_batch_rel}",
            current_batch_rel.replace("/", "\\"),
            f"res://{current_batch_rel}",
            current_batch_rel.replace("/", "//", 1),
            f"./{current_batch_rel}",
            f"../{current_batch_rel}",
            str((root / current_batch_rel).resolve()),
        ]
        for alias in aliases:
            _write_json(
                sidecar_path,
                {"current_batch_manifest_path": alias},
            )
            failures, selected = (
                convergence._resolve_subject_projection_batch_manifest_path(
                    root,
                    sidecar_path,
                    chain,
                )
            )
            _expect(failures, f"subject-projection alias accepted: {alias}")
            _expect(selected is None, f"subject-projection alias routed: {alias}")

        _write_json(
            sidecar_path,
            {"current_batch_manifest_path": current_batch_rel},
        )
        outside_path = root.parent / "outside" / "batch-007-manifest.json"
        failures, selected = (
            convergence._resolve_subject_projection_batch_manifest_path(
                root,
                sidecar_path,
                [(outside_path, {})],
            )
        )
        _expect_failure(
            failures,
            "SUBJECT_PROJECTION_EXPLICIT_BATCH_CHAIN_PATH_OUTSIDE_ROOT",
        )
        _expect(selected is None, f"outside-root chain routed to {selected}")


def _independent_subject_projection_epoch_pair_case() -> None:
    """The standalone audit independently requires committed disjoint 82 + 2."""

    _expect(
        independent_audit._subject_projection_revalidation_successor_v2
        .__name__.endswith("_independent_audit"),
        independent_audit._subject_projection_revalidation_successor_v2.__name__,
    )
    with tempfile.TemporaryDirectory(prefix="v076-spr-independent-pair-") as temporary:
        root = Path(temporary).resolve()
        v1_path = root / "subject-projection-revalidation.json"
        successor_path = root / "subject-projection-revalidation-successor-v2.json"
        v1_current = independent_audit._subject_projection_revalidation.CURRENT_BATCH_PATH
        successor_current = (
            independent_audit._subject_projection_revalidation_successor_v2
            .CURRENT_BATCH_PATH
        )
        _write_json(v1_path, {"current_batch_manifest_path": v1_current})
        _write_json(successor_path, {})
        chain = [
            (root / v1_current, {"batch_id": "batch-007"}),
            (root / successor_current, {"batch_id": "batch-008"}),
        ]
        v1_trust = _subject_projection_trust_fixture()
        successor_trust = _subject_projection_successor_v2_trust_fixture()
        v1_result = {
            "status": "GO", "findings": [],
            "trusted_by_fingerprint": copy.deepcopy(v1_trust),
            "trusted_fingerprint_count": 82, "record_count": 82,
            "fingerprints": sorted(v1_trust),
        }
        successor_result = {
            "status": "GO", "mode": "COMMITTED", "findings": [],
            "trusted_by_fingerprint": copy.deepcopy(successor_trust),
            "review_trusted_by_fingerprint": copy.deepcopy(successor_trust),
            "trusted_fingerprint_count": 2,
            "review_trusted_fingerprint_count": 2,
            "record_count": 2, "fingerprints": sorted(successor_trust),
            "stage_only": False,
        }
        original_v1 = (
            independent_audit._subject_projection_revalidation
            .audit_manifest_and_records
        )
        original_successor = (
            independent_audit._subject_projection_revalidation_successor_v2
            .audit_manifest_and_records
        )
        independent_audit._subject_projection_revalidation.audit_manifest_and_records = (
            lambda *args, **kwargs: copy.deepcopy(v1_result)
        )
        independent_audit._subject_projection_revalidation_successor_v2.audit_manifest_and_records = (
            lambda *args, **kwargs: copy.deepcopy(successor_result)
        )
        try:
            findings, exposed_v1, exposed_successor, summary = (
                independent_audit
                ._subject_projection_revalidation_epoch_pair_findings(
                    root,
                    v1_path,
                    successor_path,
                    chain,
                    "b" * 40,
                    explicit_batch_chain_valid=True,
                )
            )
            _expect(not findings, str(findings))
            _expect(set(exposed_v1) == set(v1_trust), str(summary))
            _expect(set(exposed_successor) == set(successor_trust), str(summary))
            _expect(summary["status"] == "PASS", str(summary))
            _expect(summary["trusted_fingerprint_count"] == 84, str(summary))
            _expect(summary["union_fingerprint_count"] == 84, str(summary))
            _expect(summary["cross_epoch_overlap_count"] == 0, str(summary))

            successor_result["mode"] = "STAGE_REVIEW"
            findings, exposed_v1, exposed_successor, summary = (
                independent_audit
                ._subject_projection_revalidation_epoch_pair_findings(
                    root,
                    v1_path,
                    successor_path,
                    chain,
                    "b" * 40,
                    explicit_batch_chain_valid=True,
                )
            )
            _expect(findings, str(summary))
            _expect(exposed_v1 == {}, str(summary))
            _expect(exposed_successor == {}, str(summary))
            _expect(summary["status"] == "FAIL", str(summary))

            findings, exposed_v1, exposed_successor, summary = (
                independent_audit
                ._subject_projection_revalidation_epoch_pair_findings(
                    root,
                    v1_path,
                    None,
                    chain,
                    "b" * 40,
                    explicit_batch_chain_valid=True,
                )
            )
            _expect(findings, str(summary))
            _expect(exposed_v1 == {} and exposed_successor == {}, str(summary))
            _expect(
                summary["failures"]
                == ["SUBJECT_PROJECTION_REVALIDATION_EPOCH_PAIR_REQUIRED"],
                str(summary),
            )
        finally:
            independent_audit._subject_projection_revalidation.audit_manifest_and_records = (
                original_v1
            )
            independent_audit._subject_projection_revalidation_successor_v2.audit_manifest_and_records = (
                original_successor
            )


def _subject_projection_suppression_scope_and_v1_compatibility_case() -> None:
    """SPR suppresses only projection drift while Post-Touch V1 keeps its scope."""

    fingerprint = _fingerprint(7000)
    prior_path = (
        "docs/architecture/reuse_corrections/v2/records/"
        "full_convergence_20260827/batch-001/suppression-selftest.json"
    )
    subject_trust = {
        fingerprint: {
            "allowed_invalidations": ["SUBJECT_PROJECTION_CHANGED_INVALID"],
            "prior_record_path": prior_path,
        }
    }
    for validator in (
        convergence._subject_projection_revalidation,
        independent_audit._subject_projection_revalidation,
    ):
        _expect(
            validator.allows_invalidation(
                subject_trust,
                fingerprint=fingerprint,
                invalidation_code="SUBJECT_PROJECTION_CHANGED_INVALID",
                prior_record_path=prior_path,
            ),
            f"{validator.__name__} rejected exact subject invalidation",
        )
        for forbidden_code in (
            "BLOB_CHANGED_CORRECTION_INVALID",
            "TOUCHED_CORRECTION_INVALID",
        ):
            _expect(
                not validator.allows_invalidation(
                    subject_trust,
                    fingerprint=fingerprint,
                    invalidation_code=forbidden_code,
                    prior_record_path=prior_path,
                ),
                f"{validator.__name__} suppressed {forbidden_code}",
            )
        _expect(
            not validator.allows_invalidation(
                subject_trust,
                fingerprint=_fingerprint(7001),
                invalidation_code="SUBJECT_PROJECTION_CHANGED_INVALID",
                prior_record_path=prior_path,
            ),
            f"{validator.__name__} accepted wrong fingerprint",
        )
        _expect(
            not validator.allows_invalidation(
                subject_trust,
                fingerprint=fingerprint,
                invalidation_code="SUBJECT_PROJECTION_CHANGED_INVALID",
                prior_record_path=f"{prior_path}.wrong",
            ),
            f"{validator.__name__} accepted wrong prior path",
        )

    independent_findings = [
        {
            "code": code,
            "evidence": {"fingerprint": fingerprint, "path": prior_path},
        }
        for code in (
            "FULL_CONVERGENCE_SUBJECT_PROJECTION_CHANGED",
            "FULL_CONVERGENCE_CURRENT_BLOB_CHANGED",
            "FULL_CONVERGENCE_TOUCHED_CORRECTION_INVALID",
        )
    ]
    kept = independent_audit._suppress_subject_projection_revalidation_findings(
        independent_findings,
        subject_trust,
    )
    _expect(
        [value["code"] for value in kept]
        == [
            "FULL_CONVERGENCE_CURRENT_BLOB_CHANGED",
            "FULL_CONVERGENCE_TOUCHED_CORRECTION_INVALID",
        ],
        str(kept),
    )
    original_independent_v1_allows = (
        independent_audit._subject_projection_revalidation.allows_invalidation
    )
    original_independent_successor_allows = (
        independent_audit._subject_projection_revalidation_successor_v2
        .allows_invalidation
    )

    def unexpected_unknown_allows(*args: Any, **kwargs: Any) -> bool:
        raise AssertionError("unknown fingerprint reached an allows helper")

    independent_audit._subject_projection_revalidation.allows_invalidation = (
        unexpected_unknown_allows
    )
    independent_audit._subject_projection_revalidation_successor_v2.allows_invalidation = (
        unexpected_unknown_allows
    )
    unknown_finding = {
        "code": "FULL_CONVERGENCE_SUBJECT_PROJECTION_CHANGED",
        "evidence": {
            "fingerprint": _fingerprint(7001),
            "path": prior_path,
        },
    }
    try:
        kept_unknown = (
            independent_audit
            ._suppress_subject_projection_revalidation_findings(
                [unknown_finding],
                subject_trust,
                _subject_projection_successor_v2_trust_fixture(),
            )
        )
    finally:
        independent_audit._subject_projection_revalidation.allows_invalidation = (
            original_independent_v1_allows
        )
        independent_audit._subject_projection_revalidation_successor_v2.allows_invalidation = (
            original_independent_successor_allows
        )
    _expect(kept_unknown == [unknown_finding], str(kept_unknown))

    with tempfile.TemporaryDirectory(prefix="v076-spr-suppression-") as temporary:
        root = Path(temporary).resolve()
        record_path = root / prior_path
        payload_sha = "7" * 64
        chain_start = "8" * 64
        correction_id = "V2-FC-SPR-SUPPRESSION-SELFTEST"
        record = {
            "batch_id": "batch-selftest",
            "binding_head_sha": "9" * 40,
            "binding_tree_sha": "a" * 40,
            "correction_id": correction_id,
            "record_payload_sha256": payload_sha,
            "previous_correction_chain_sha256": chain_start,
            "failure_fingerprints": [fingerprint],
        }
        _write_json(record_path, record)
        manifest = {
            "batch_id": "batch-selftest",
            "binding_head_sha": record["binding_head_sha"],
            "binding_tree_sha": record["binding_tree_sha"],
            "record_chain_start_sha256": chain_start,
            "record_chain_terminal_sha256": payload_sha,
            "failure_fingerprints": [fingerprint],
            "record_bindings": [
                {
                    "path": prior_path,
                    "record_sha256": convergence.sha256_file(record_path),
                    "record_payload_sha256": payload_sha,
                    "correction_id": correction_id,
                    "previous_correction_chain_sha256": chain_start,
                    "failure_fingerprints": [fingerprint],
                }
            ],
        }
        original_validator = convergence.validate_extension_record_against_repo
        original_subject_allows = (
            convergence._subject_projection_revalidation.allows_invalidation
        )
        subject_codes: list[str] = []

        def overbroad_subject_allows(
            *args: Any,
            invalidation_code: str,
            **kwargs: Any,
        ) -> bool:
            subject_codes.append(invalidation_code)
            return True

        convergence.validate_extension_record_against_repo = (
            lambda *args, **kwargs: [
                f"SUBJECT_PROJECTION_CHANGED_INVALID:{fingerprint}",
                f"BLOB_CHANGED_CORRECTION_INVALID:{fingerprint}",
                f"TOUCHED_CORRECTION_INVALID:{fingerprint}",
            ]
        )
        convergence._subject_projection_revalidation.allows_invalidation = (
            overbroad_subject_allows
        )
        try:
            failures, _ = convergence._validate_manifest_records_against_repo(
                root,
                manifest,
                evaluated_head="b" * 40,
                authorized_fingerprints={
                    "current": set(),
                    "historical": {fingerprint},
                },
                authorized_identities={},
                legacy_fingerprints=set(),
                subject_projection_revalidation_trusted=subject_trust,
            )
        finally:
            convergence.validate_extension_record_against_repo = original_validator
            convergence._subject_projection_revalidation.allows_invalidation = (
                original_subject_allows
            )
        _expect(
            subject_codes == ["SUBJECT_PROJECTION_CHANGED_INVALID"],
            f"subject-projection caller exposed codes: {subject_codes}",
        )
        _expect(
            f"SUBJECT_PROJECTION_CHANGED_INVALID:{fingerprint}" not in failures,
            str(failures),
        )
        _expect(
            f"BLOB_CHANGED_CORRECTION_INVALID:{fingerprint}" in failures,
            str(failures),
        )
        _expect(
            f"TOUCHED_CORRECTION_INVALID:{fingerprint}" in failures,
            str(failures),
        )

        unknown = _fingerprint(7001)
        original_validator = convergence.validate_extension_record_against_repo
        original_subject_allows = (
            convergence._subject_projection_revalidation.allows_invalidation
        )
        original_successor_allows = (
            convergence._subject_projection_revalidation_successor_v2
            .allows_invalidation
        )
        convergence.validate_extension_record_against_repo = (
            lambda *args, **kwargs: [
                f"SUBJECT_PROJECTION_CHANGED_INVALID:{unknown}"
            ]
        )
        convergence._subject_projection_revalidation.allows_invalidation = (
            unexpected_unknown_allows
        )
        convergence._subject_projection_revalidation_successor_v2.allows_invalidation = (
            unexpected_unknown_allows
        )
        try:
            unknown_failures, _ = (
                convergence._validate_manifest_records_against_repo(
                    root,
                    manifest,
                    evaluated_head="b" * 40,
                    authorized_fingerprints={
                        "current": set(),
                        "historical": {fingerprint},
                    },
                    authorized_identities={},
                    legacy_fingerprints=set(),
                    subject_projection_revalidation_trusted=subject_trust,
                    subject_projection_revalidation_successor_v2_trusted=(
                        _subject_projection_successor_v2_trust_fixture()
                    ),
                )
            )
        finally:
            convergence.validate_extension_record_against_repo = original_validator
            convergence._subject_projection_revalidation.allows_invalidation = (
                original_subject_allows
            )
            convergence._subject_projection_revalidation_successor_v2.allows_invalidation = (
                original_successor_allows
            )
        _expect(
            f"SUBJECT_PROJECTION_CHANGED_INVALID:{unknown}" in unknown_failures,
            str(unknown_failures),
        )

    v1_trust = {
        fingerprint: {
            "allowed_invalidations": sorted(
                convergence._post_touch.ALLOWED_INVALIDATIONS
            ),
            "prior_record_path": prior_path,
        }
    }
    for invalidation_code in sorted(convergence._post_touch.ALLOWED_INVALIDATIONS):
        _expect(
            convergence._post_touch.allows_invalidation(
                v1_trust,
                fingerprint=fingerprint,
                invalidation_code=invalidation_code,
                prior_record_path=prior_path,
            ),
            f"Post-Touch V1 regressed for {invalidation_code}",
        )
    _expect(
        not independent_audit._suppress_post_touch_findings(
            independent_findings,
            v1_trust,
        ),
        "Post-Touch V1 no longer suppresses its exact three invalidations",
    )


def _v4_head(root: Path) -> str:
    return convergence._git(root, "rev-parse", "HEAD")


def _v4_json_attack(
    root: Path,
    relative: Path,
    mutate: Callable[[dict[str, Any]], None],
) -> dict[str, Any]:
    original = convergence.load_json_strict
    target = (root / relative).resolve()

    def attacked(path: Path) -> Any:
        value = original(path)
        if path.resolve() == target:
            value = copy.deepcopy(value)
            mutate(value)
        return value

    convergence.load_json_strict = attacked
    try:
        return convergence.validate_implementation_binding_v4(
            root,
            evaluated_head=_v4_head(root),
        )
    finally:
        convergence.load_json_strict = original


def _v4_expect_json_attack(
    root: Path,
    relative: Path,
    mutate: Callable[[dict[str, Any]], None],
    prefix: str,
) -> None:
    result = _v4_json_attack(root, relative, mutate)
    _expect(result.get("status") == "FAIL", str(result))
    _expect_failure(result["failures"], prefix)
    _expect(not result.get("trusted_by_fingerprint"), str(result))


def _successor_v4_positive_case(root: Path) -> None:
    result = convergence.validate_implementation_binding_v4(
        root,
        evaluated_head=_v4_head(root),
    )
    _expect(result.get("status") == "PASS", str(result))
    _expect(result.get("fingerprint_count") == 5, str(result))
    _expect(
        set(result.get("trusted_by_fingerprint", {}))
        == set(convergence.ALPHA01_DYNAMIC_FINGERPRINTS),
        str(result),
    )
    wrong_head = convergence.validate_implementation_binding_v4(
        root,
        evaluated_head=convergence.AUTHORIZATION_BASE_HEAD_SHA,
    )
    _expect(wrong_head.get("status") == "FAIL", str(wrong_head))
    _expect_failure(
        wrong_head["failures"],
        "SUCCESSOR_V4_BINDING_HEAD_NOT_AUTHORIZED_DESCENDANT",
    )
    head = _v4_head(root)
    tree = convergence._git(root, "rev-parse", f"{head}^{{tree}}")
    unrelated_head = convergence._git(
        root,
        "commit-tree",
        tree,
        "-p",
        head,
        "-m",
        "v4 unrelated-delta selftest",
    )
    unrelated = convergence.validate_implementation_binding_v4(
        root,
        evaluated_head=unrelated_head,
    )
    _expect(unrelated.get("status") == "PASS", str(unrelated))
    _expect(unrelated.get("fingerprint_count") == 5, str(unrelated))


def _successor_v4_predecessor_sha_negative_case(root: Path) -> None:
    original = convergence.SUCCESSOR_SCHEMA_SHA256
    convergence.SUCCESSOR_SCHEMA_SHA256 = "0" * 64
    try:
        result = convergence.validate_implementation_binding_v4(
            root,
            evaluated_head=_v4_head(root),
        )
    finally:
        convergence.SUCCESSOR_SCHEMA_SHA256 = original
    _expect_failure(
        result["failures"],
        "SUCCESSOR_V4_PREDECESSOR_SCHEMA_COMMITTED_BLOB_SHA256_MISMATCH",
    )
    _v4_expect_json_attack(
        root,
        convergence.SUCCESSOR_V4_SCHEMA_REL,
        lambda schema: schema.update({"unauthorized_extra": True}),
        "SUCCESSOR_V4_SCHEMA_FIELD_SET_INVALID",
    )
    _v4_expect_json_attack(
        root,
        convergence.SUCCESSOR_V4_SCHEMA_REL,
        lambda schema: schema.update({"implementation_binding_count": True}),
        "SUCCESSOR_V4_SCHEMA_IMPLEMENTATION_BINDING_COUNT_MISMATCH",
    )
    original = convergence.load_json_strict

    def duplicate_schema(path: Path) -> Any:
        if path.resolve() == (root / convergence.SUCCESSOR_V4_SCHEMA_REL).resolve():
            raise convergence.DuplicateJsonKeyError("duplicate selftest key")
        return original(path)

    convergence.load_json_strict = duplicate_schema
    try:
        duplicate = convergence.validate_implementation_binding_v4(
            root,
            evaluated_head=_v4_head(root),
        )
    finally:
        convergence.load_json_strict = original
    _expect_failure(duplicate["failures"], "SUCCESSOR_V4_SCHEMA_JSON_INVALID")
    original_object_id = convergence._git_object_id

    def dirty_worktree(repo: Path, *args: str) -> str:
        if args and args[0] == "hash-object":
            return "0" * 40
        return original_object_id(repo, *args)

    convergence._git_object_id = dirty_worktree
    try:
        dirty = convergence.validate_implementation_binding_v4(
            root,
            evaluated_head=_v4_head(root),
        )
    finally:
        convergence._git_object_id = original_object_id
    _expect_failure(
        dirty["failures"],
        "SUCCESSOR_V4_SCHEMA_WORKTREE_CONTENT_DRIFT",
    )
    original_committed = convergence._committed_blob_bytes

    def forged_committed(
        repo: Path,
        relative: str,
        *,
        evaluated_head: str | None,
    ) -> bytes | None:
        if relative == convergence.SUCCESSOR_V4_SCHEMA_REL.as_posix():
            return b"forged successor-v4 schema"
        return original_committed(
            repo,
            relative,
            evaluated_head=evaluated_head,
        )

    convergence._committed_blob_bytes = forged_committed
    try:
        forged = convergence.validate_implementation_binding_v4(
            root,
            evaluated_head=_v4_head(root),
        )
    finally:
        convergence._committed_blob_bytes = original_committed
    _expect_failure(
        forged["failures"],
        "SUCCESSOR_V4_SCHEMA_COMMITTED_BLOB_SHA256_MISMATCH",
    )


def _successor_v4_fingerprint_set_negative_case(root: Path) -> None:
    original = convergence.ALPHA01_DYNAMIC_FINGERPRINT_SET_SHA256
    convergence.ALPHA01_DYNAMIC_FINGERPRINT_SET_SHA256 = "0" * 64
    try:
        result = convergence.validate_implementation_binding_v4(
            root,
            evaluated_head=_v4_head(root),
        )
    finally:
        convergence.ALPHA01_DYNAMIC_FINGERPRINT_SET_SHA256 = original
    _expect_failure(
        result["failures"],
        "SUCCESSOR_V4_SCHEMA_IMPLEMENTATION_BOUND_FAILURE_FINGERPRINT_SET_SHA256_MISMATCH",
    )
    binding_path = convergence.ALPHA01_IMPLEMENTATION_BINDING_REL
    future = _fingerprint(9999)
    mutations: list[Callable[[dict[str, Any]], None]] = [
        lambda binding: binding["failure_fingerprints"].pop(),
        lambda binding: binding["failure_fingerprints"].append(future),
        lambda binding: binding["failure_fingerprints"].__setitem__(0, future),
    ]
    for mutate in mutations:
        _v4_expect_json_attack(
            root,
            binding_path,
            mutate,
            "SUCCESSOR_V4_BINDING_FINGERPRINT_SET_MISMATCH",
        )
    first = sorted(convergence.ALPHA01_DYNAMIC_FINGERPRINTS)[0]
    _v4_expect_json_attack(
        root,
        binding_path,
        lambda binding: binding["failure_identity_by_fingerprint"][first].update(
            {"raw_failure": "HISTORY_DYNAMIC_REFERENCE_UNRESOLVED:forged"}
        ),
        "SUCCESSOR_V4_IDENTITY_RAW_FAILURE_INVALID",
    )
    _v4_expect_json_attack(
        root,
        binding_path,
        lambda binding: binding.update({"failure_count": True}),
        "SUCCESSOR_V4_BINDING_FAILURE_COUNT_MISMATCH",
    )
    for field in (
        "future_failure_auto_membership_allowed",
        "wildcard_membership_allowed",
    ):
        _v4_expect_json_attack(
            root,
            binding_path,
            lambda binding, field=field: binding["future_failure_policy"].update(
                {field: True}
            ),
            "SUCCESSOR_V4_FUTURE_POLICY_CONTENT_INVALID",
        )


def _successor_v4_binding_sha_negative_case(root: Path) -> None:
    original = convergence.ALPHA01_IMPLEMENTATION_BINDING_SHA256
    convergence.ALPHA01_IMPLEMENTATION_BINDING_SHA256 = "0" * 64
    try:
        result = convergence.validate_implementation_binding_v4(
            root,
            evaluated_head=_v4_head(root),
        )
    finally:
        convergence.ALPHA01_IMPLEMENTATION_BINDING_SHA256 = original
    _expect_failure(
        result["failures"],
        "SUCCESSOR_V4_SCHEMA_IMPLEMENTATION_BINDING_SHA256_MISMATCH",
    )
    binding_path = convergence.ALPHA01_IMPLEMENTATION_BINDING_REL
    attacks = (
        (
            lambda binding: binding["resource_authority"].update(
                {"sha256": "0" * 64}
            ),
            "SUCCESSOR_V4_RESOURCE_AUTHORITY_CONTENT_INVALID",
        ),
        (
            lambda binding: binding["script_authority"].update(
                {"git_blob_oid": "0" * 40}
            ),
            "SUCCESSOR_V4_SCRIPT_AUTHORITY_CONTENT_INVALID",
        ),
        (
            lambda binding: binding["registry_authority"].update(
                {"owner_component_id": "component.future.owner"}
            ),
            "SUCCESSOR_V4_REGISTRY_AUTHORITY_CONTENT_INVALID",
        ),
        (
            lambda binding: binding["script_link"].update(
                {"script_assignment_count": 2}
            ),
            "SUCCESSOR_V4_SCRIPT_LINK_CONTENT_INVALID",
        ),
        (
            lambda binding: binding["historical_transition"].update(
                {"transition_old_sha": "0" * 40}
            ),
            "SUCCESSOR_V4_HISTORICAL_TRANSITION_CONTENT_INVALID",
        ),
    )
    for mutate, prefix in attacks:
        _v4_expect_json_attack(root, binding_path, mutate, prefix)
    _v4_expect_json_attack(
        root,
        binding_path,
        lambda binding: binding.update({"unauthorized_extra": True}),
        "SUCCESSOR_V4_BINDING_FIELD_SET_INVALID",
    )
    original_oid = convergence._v4_git_object_id

    def resource_oid_drift(repo: Path, *args: str) -> str:
        if args and args[-1].endswith(f":{convergence.ALPHA01_RESOURCE_PATH}"):
            return "0" * 40
        return original_oid(repo, *args)

    convergence._v4_git_object_id = resource_oid_drift
    try:
        oid_drift = convergence.validate_implementation_binding_v4(
            root,
            evaluated_head=_v4_head(root),
        )
    finally:
        convergence._v4_git_object_id = original_oid
    _expect_failure(
        oid_drift["failures"],
        "SUCCESSOR_V4_RESOURCE_AUTHORITY_BLOB_DRIFT",
    )
    original_json_at = convergence._v4_json_at

    def registry_owner_drift(repo: Path, commit: str, relative: str) -> Any:
        document = original_json_at(repo, commit, relative)
        if relative != "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json":
            return document
        document = copy.deepcopy(document)
        for row in document.get("component_inventory", []):
            if row.get("component_id") == convergence.ALPHA01_COMPONENT_ID:
                row["owner_component_id"] = "component.future.owner"
        return document

    convergence._v4_json_at = registry_owner_drift
    try:
        registry_drift = convergence.validate_implementation_binding_v4(
            root,
            evaluated_head=_v4_head(root),
        )
    finally:
        convergence._v4_json_at = original_json_at
    _expect_failure(
        registry_drift["failures"],
        "SUCCESSOR_V4_BINDING_REGISTRY_OWNER_COMPONENT_ID_MISMATCH",
    )


def _successor_v4_target_drift_negative_case(root: Path) -> None:
    original = convergence._v4_git_bytes
    target = next(
        iter(convergence.ALPHA01_EXPECTED_TARGETS_BY_FINGERPRINT.values())
    )[0]

    def missing_one(repo: Path, commit: str, relative: str) -> bytes | None:
        if relative == target[6:]:
            return None
        return original(repo, commit, relative)

    convergence._v4_git_bytes = missing_one
    try:
        result = convergence.validate_implementation_binding_v4(
            root,
            evaluated_head=_v4_head(root),
        )
    finally:
        convergence._v4_git_bytes = original
    _expect_failure(result["failures"], "SUCCESSOR_V4_IDENTITY_TARGET_MISSING:")
    binding_path = convergence.ALPHA01_IMPLEMENTATION_BINDING_REL
    first = sorted(convergence.ALPHA01_DYNAMIC_FINGERPRINTS)[0]
    attacks = (
        (
            lambda binding: binding["failure_identity_by_fingerprint"][first][
                "callsite_locations"
            ][0].update({"line": 1}),
            "SUCCESSOR_V4_IDENTITY_CALLSITE_SOURCE_MISMATCH:",
        ),
        (
            lambda binding: binding["failure_identity_by_fingerprint"][first].update(
                {"resolved_targets": ["res://future/not-authorized.gd"]}
            ),
            "SUCCESSOR_V4_IDENTITY_TARGET_SET_INVALID:",
        ),
        (
            lambda binding: binding["failure_identity_by_fingerprint"][first][
                "runtime_probe"
            ].update({"expected_target_count": True}),
            "SUCCESSOR_V4_IDENTITY_PROBE_CONTENT_INVALID:",
        ),
    )
    for mutate, prefix in attacks:
        _v4_expect_json_attack(root, binding_path, mutate, prefix)

    dynamic = _dynamic_identity_binding()
    ordinary = convergence._identity_projection_failures(
        dynamic,
        rule_id="HISTORY_DYNAMIC_REFERENCE_UNRESOLVED",
        fingerprint=_fingerprint(4000),
    )
    _expect(
        not any(value.startswith("IDENTITY_BINDING_DYNAMIC_REFERENCE_ROW_NOT_UNIQUE") for value in ordinary),
        str(ordinary),
    )
    empty_dynamic = _identity_binding()
    authorized = first
    trusted = {
        "component_id": convergence.ALPHA01_COMPONENT_ID,
        "implementation_path": convergence.ALPHA01_SCRIPT_PATH,
    }
    future_failures = convergence._identity_projection_failures(
        empty_dynamic,
        rule_id="HISTORY_DYNAMIC_REFERENCE_UNRESOLVED",
        fingerprint=_fingerprint(4001),
        implementation_trusted=trusted,
    )
    _expect_failure(
        future_failures,
        "IDENTITY_BINDING_DYNAMIC_REFERENCE_ROW_NOT_UNIQUE",
    )
    exact_failures = convergence._identity_projection_failures(
        empty_dynamic,
        rule_id="HISTORY_DYNAMIC_REFERENCE_UNRESOLVED",
        fingerprint=authorized,
        implementation_trusted=trusted,
    )
    _expect(
        not any(value.startswith("IDENTITY_BINDING_DYNAMIC_REFERENCE_ROW_NOT_UNIQUE") for value in exact_failures),
        str(exact_failures),
    )
    dual = _dynamic_identity_binding()
    dual_failures = convergence._identity_projection_failures(
        dual,
        rule_id="HISTORY_DYNAMIC_REFERENCE_UNRESOLVED",
        fingerprint=authorized,
        implementation_trusted=trusted,
    )
    _expect_failure(
        dual_failures,
        "IDENTITY_BINDING_V4_DYNAMIC_SELECTOR_NOT_EMPTY",
    )


def _terminal_subject_projection_replacement_case() -> None:
    """Only v4/v5/v3 form the terminal 109-set and every mismatch clears trust."""

    def trust(start: int, count: int) -> dict[str, dict[str, Any]]:
        return {
            _fingerprint(start + index): {
                "allowed_invalidations": ["SUBJECT_PROJECTION_CHANGED_INVALID"],
                "prior_record_path": f"records/{start + index}.json",
            }
            for index in range(count)
        }

    v4_trust = trust(10000, 82)
    v5_trust = trust(20000, 2)
    v3_trust = trust(30000, 25)
    state = {"v4": v4_trust, "v5": v5_trust, "v3": v3_trust}
    original_epoch = convergence._subject_projection_replacement_epoch_composite
    original_v3 = convergence._subject_projection_revalidation_successor_v3_composite

    def epoch(*args: Any, label: str, expected_count: int, **kwargs: Any) -> dict[str, Any]:
        selected = state["v4" if label.endswith("V4") else "v5"]
        return {
            "status": "PASS",
            "failures": [],
            "trusted_by_fingerprint": copy.deepcopy(selected),
            "trusted_fingerprint_count": len(selected),
            "replacement_overlap_count": expected_count,
            "trust_set_parity": True,
        }

    def v3(*args: Any, **kwargs: Any) -> dict[str, Any]:
        return {
            "status": "PASS",
            "failures": [],
            "trusted_by_fingerprint": copy.deepcopy(state["v3"]),
            "trusted_fingerprint_count": len(state["v3"]),
            "trust_set_parity": True,
        }

    convergence._subject_projection_replacement_epoch_composite = epoch
    convergence._subject_projection_revalidation_successor_v3_composite = v3

    def evaluate() -> dict[str, Any]:
        paths = [Path(f"sidecar-{index}.json") for index in range(5)]
        return convergence._subject_projection_terminal_replacement_composite(
            Path.cwd(),
            *paths,
            [],
            artifact_head="a" * 40,
            explicit_batch_chain_valid=True,
        )

    try:
        accepted = evaluate()
        _expect(accepted["status"] == "PASS", str(accepted))
        _expect(accepted["terminal_replacement_complete"] is True, str(accepted))
        _expect(accepted["union_fingerprint_count"] == 109, str(accepted))
        _expect(accepted["cross_epoch_overlap_count"] == 0, str(accepted))
        _expect(accepted["v1_trusted_by_fingerprint"] == {}, str(accepted))
        _expect(
            accepted["successor_v2_trusted_by_fingerprint"] == {},
            str(accepted),
        )
        _expect(
            len(accepted["successor_v4_trusted_by_fingerprint"]) == 82
            and len(accepted["successor_v5_trusted_by_fingerprint"]) == 2
            and len(accepted["successor_v3_trusted_by_fingerprint"]) == 25,
            str(accepted),
        )

        duplicate = next(iter(v4_trust))
        state["v5"] = {
            duplicate: next(iter(v5_trust.values())),
            next(iter(v5_trust)): next(iter(v5_trust.values())),
        }
        rejected = evaluate()
        _expect(rejected["status"] == "FAIL", str(rejected))
        _expect(rejected["trusted_by_fingerprint"] == {}, str(rejected))
        _expect_failure(
            rejected["failures"],
            "SUBJECT_PROJECTION_EFFECTIVE_TRUST_OVERLAP:1",
        )

        state["v5"] = v5_trust

        def parity_failure(*args: Any, label: str, **kwargs: Any) -> dict[str, Any]:
            if label.endswith("V4"):
                return {
                    "status": "FAIL",
                    "failures": ["TRUST_SET_PARITY_INVALID"],
                    "trusted_by_fingerprint": {},
                    "trusted_fingerprint_count": 0,
                    "replacement_overlap_count": 0,
                    "trust_set_parity": False,
                }
            return epoch(*args, label=label, **kwargs)

        convergence._subject_projection_replacement_epoch_composite = parity_failure
        rejected = evaluate()
        _expect(rejected["status"] == "FAIL", str(rejected))
        _expect(rejected["trusted_by_fingerprint"] == {}, str(rejected))
        _expect_failure(
            rejected["failures"],
            "SUBJECT_PROJECTION_SUCCESSOR_V4_GATE:TRUST_SET_PARITY_INVALID",
        )
    finally:
        convergence._subject_projection_replacement_epoch_composite = original_epoch
        convergence._subject_projection_revalidation_successor_v3_composite = original_v3


def _post_touch_successor_v2_effective_owner_case() -> None:
    """The successor replaces rather than doubles the exact two post-touch owners."""

    root = Path.cwd()
    predecessor = root / convergence._post_touch_successor_v2.PREDECESSOR_MANIFEST_PATH
    successor = root / convergence._post_touch_successor_v2.MANIFEST_PATH
    targets = tuple(convergence._post_touch_successor_v2.TARGET_FINGERPRINTS)
    trust = {
        fingerprint: {
            "allowed_invalidations": [
                "BLOB_CHANGED_CORRECTION_INVALID",
                "TOUCHED_CORRECTION_INVALID",
            ],
            "prior_record_path": f"records/{fingerprint}.json",
        }
        for fingerprint in targets
    }
    artifact = "a" * 40
    binding = "b" * 40
    primary = {
        "status": "PASS",
        "mode": "COMMITTED",
        "failures": [],
        "trusted_by_fingerprint": copy.deepcopy(trust),
        "trusted_fingerprint_count": 2,
        "record_count": 2,
        "artifact_head": artifact,
        "evaluated_binding_head": binding,
        "wildcard_count": 0,
        "future_failure_auto_revalidation_count": 0,
    }
    independent = copy.deepcopy(primary)
    original_manifest = convergence._committed_successor_manifest
    original_primary = convergence._post_touch_successor_v2.validate
    original_independent = convergence._post_touch_successor_v2_independent.audit
    convergence._committed_successor_manifest = lambda *args, **kwargs: (
        {
            "predecessor_manifest_path": (
                convergence._post_touch_successor_v2.PREDECESSOR_MANIFEST_PATH
            )
        },
        artifact,
        binding,
    )
    convergence._post_touch_successor_v2.validate = (
        lambda *args, **kwargs: copy.deepcopy(primary)
    )
    convergence._post_touch_successor_v2_independent.audit = (
        lambda *args, **kwargs: copy.deepcopy(independent)
    )
    try:
        accepted = convergence._post_touch_revalidation_successor_v2_composite(
            root,
            predecessor,
            successor,
            artifact_head=artifact,
        )
        _expect(accepted["status"] == "PASS", str(accepted))
        _expect(accepted["effective_trusted_fingerprint_count"] == 2, str(accepted))
        _expect(accepted["predecessor_trusted_by_fingerprint"] == {}, str(accepted))
        _expect(
            len(accepted["successor_v2_trusted_by_fingerprint"]) == 2,
            str(accepted),
        )

        changed = next(iter(targets))
        independent["trusted_by_fingerprint"][changed]["prior_record_path"] = (
            "records/mismatch.json"
        )
        rejected = convergence._post_touch_revalidation_successor_v2_composite(
            root,
            predecessor,
            successor,
            artifact_head=artifact,
        )
        _expect(rejected["status"] == "FAIL", str(rejected))
        _expect(rejected["trusted_by_fingerprint"] == {}, str(rejected))
        _expect_failure(
            rejected["failures"],
            "POST_TOUCH_SUCCESSOR_V2_TRUST_SET_PARITY_INVALID",
        )
    finally:
        convergence._committed_successor_manifest = original_manifest
        convergence._post_touch_successor_v2.validate = original_primary
        convergence._post_touch_successor_v2_independent.audit = original_independent


def _optional_v5_import_fails_only_on_replacement_case() -> None:
    """A missing v5 module leaves imports usable and fails only an explicit v5 epoch."""

    _expect(callable(convergence.validate_batch_manifest_against_repo), "module import failed")
    if convergence._subject_projection_revalidation_successor_v5 is not None:
        return
    result = convergence._subject_projection_replacement_epoch_composite(
        Path.cwd(),
        Path("missing-v5/manifest.json"),
        Path("missing-v2/manifest.json"),
        artifact_head="a" * 40,
        label="SUBJECT_PROJECTION_SUCCESSOR_V5",
        primary_module=None,
        independent_module=None,
        expected_count=2,
        expected_drift_count=2,
        expected_preserved_count=0,
    )
    _expect(result["status"] == "FAIL", str(result))
    _expect(result["trusted_by_fingerprint"] == {}, str(result))
    _expect_failure(
        result["failures"],
        "SUBJECT_PROJECTION_SUCCESSOR_V5_MODULE_NOT_AVAILABLE",
    )


def build_cases(root: Path) -> list[Case]:
    cases: list[Case] = []
    cases.append(Case("01", "new schema is exact and authorized", lambda: _expect(not convergence.validate_schema(root), str(convergence.validate_schema(root)))))
    cases.append(Case("02", "six legacy records and predecessor seal remain byte locked", lambda: _expect(convergence.verify_legacy_anchor(root)["status"] == "PASS", str(convergence.verify_legacy_anchor(root)))))
    cases.append(Case("03", "valid extension record passes pure contract", lambda: _expect(not convergence.validate_extension_record_document(_record()), str(convergence.validate_extension_record_document(_record())))))
    cases.append(Case("04", "new record cannot reuse the legacy authorization", lambda: (lambda record: (_expect_failure(convergence.validate_extension_record_document(record), "EXTENSION_RECORD_AUTHORIZATION_ID_MISMATCH")))(dict(_record(), authorization_id=convergence.LEGACY_AUTHORIZATION_ID))))
    cases.append(Case("05", "current rule cannot receive historical correction", lambda: (lambda record: (_expect_failure(convergence.validate_extension_record_document(record), "EXTENSION_RECORD_RULE_CLASS_INVALID")))(dict(_record(), rule_ids=["UNCLASSIFIED_NEW_COMPONENT"], failure_classes=["UNCLASSIFIED_NEW_COMPONENT"], allowed_rule_ids=["UNCLASSIFIED_NEW_COMPONENT"]))))
    cases.append(Case("06", "future automatic correction remains forbidden", lambda: (lambda record: (_expect_failure(convergence.validate_extension_record_document(record), "EXTENSION_RECORD_FUTURE_AUTO_CORRECTION_ENABLED")))(dict(_record(), future_failure_policy={"NEW_FAILURE_REQUIRES_NEW_RECORD": False}))))
    cases.append(Case("07", "subject projection digest is mandatory", lambda: (lambda record: (record["identity_binding_by_failure"][_fingerprint(1)].update({"subject_projection_sha256": "0" * 64}), record.update({"record_payload_sha256": "0" * 64}), _expect_failure(convergence.validate_extension_record_document(record), "IDENTITY_BINDING_PROJECTION_HASH_MISMATCH")))(_record())))
    cases.append(Case("08", "wildcard subject selector is rejected", lambda: (lambda selector: _expect_failure(convergence._selector_failures(selector), "SUBJECT_SELECTOR_NOT_EXACT"))({"component_ids": [], "dynamic_reference_ids": [], "paths": ["scripts/*"], "retirement_ids": [], "supersession_ids": []})))
    cases.append(Case("09", "valid 25-fingerprint first batch continues legacy terminal", lambda: _expect(not convergence.validate_batch_manifest_document(_batch()), str(convergence.validate_batch_manifest_document(_batch())))))
    cases.append(Case("10", "first batch cannot restart its correction chain", lambda: (lambda manifest: (_expect_failure(convergence.validate_batch_manifest_document(manifest), "BATCH_MANIFEST_FIRST_BATCH_LEGACY_CHAIN_ANCHOR_MISMATCH")))(dict(_batch(), record_chain_start_sha256="8" * 64))))
    cases.append(Case("11", "batch above fifty fingerprints is rejected", lambda: _expect_failure(convergence.validate_batch_manifest_document(_batch(51)), "BATCH_MANIFEST_SIZE_OUT_OF_RANGE")))
    cases.append(Case("12", "nonterminal batch below target is rejected", lambda: _expect_failure(convergence.validate_batch_manifest_document(_batch(24)), "BATCH_MANIFEST_NONTERMINAL_BELOW_TARGET")))
    cases.append(Case("13", "terminal remainder below target is accepted", lambda: _expect(not convergence.validate_batch_manifest_document(_batch(24, terminal=True)), str(convergence.validate_batch_manifest_document(_batch(24, terminal=True))))))
    cases.append(Case("14", "record paths cannot escape the explicit epoch root", lambda: (lambda manifest: (manifest["record_bindings"][0].update({"path": "docs/architecture/reuse_corrections/v2/records/other.json"}), _expect_failure(convergence.validate_batch_manifest_document(manifest), "BATCH_MANIFEST_RECORD_PATH_INVALID")))(_batch())))
    cases.append(Case("15", "batch review cannot be bypassed", lambda: (lambda manifest: (manifest.update({"batch_review_a_status": "NO_GO"}), _expect_failure(convergence.validate_batch_manifest_document(manifest), "BATCH_MANIFEST_BATCH_REVIEW_A_STATUS_MISMATCH")))(_batch())))
    cases.append(Case("16", "subject projection ignores unrelated append and changes on matched owner mutation", _projection_invalidation_case))
    cases.append(Case("17", "duplicate JSON keys are rejected", lambda: (lambda path: (_expect_failure(_duplicate_key_result(path), "DUPLICATE_JSON_KEY")))(root / "unused")))
    cases.append(Case("18", "d701 baseline is byte, Head, count, failure-set, and epoch-path locked", lambda: _authorized_baseline_epoch_case(root)))
    cases.append(Case("19", "aggregate owner set cannot drift from per-fingerprint identities", lambda: (lambda record: (record.update({"owner_ids": []}), _expect_failure(convergence.validate_extension_record_document(record), "EXTENSION_RECORD_OWNER_IDS_MISMATCH")))(_record())))
    cases.append(Case("20", "historical source commit binding is mandatory", lambda: (lambda record: (record["identity_binding_by_failure"][_fingerprint(1)].update({"source_commit": "bad"}), _expect_failure(convergence.validate_extension_record_document(record), "IDENTITY_BINDING_COMMIT_INVALID:source_commit")))(_record())))
    cases.append(Case("21", "current blob identity must be an exact SHA-256 or MISSING", lambda: (lambda record: (record["identity_binding_by_failure"][_fingerprint(1)].update({"current_blob_sha256": "bad"}), _expect_failure(convergence.validate_extension_record_document(record), "IDENTITY_BINDING_BLOB_INVALID:current_blob_sha256")))(_record())))
    cases.append(Case("22", "authority source set cannot omit Owner Map evidence", lambda: (lambda record: (record["authority_source_sha256"].pop(convergence.AUTHORITY_SOURCE_PATHS[2]), _expect_failure(convergence.validate_extension_record_document(record), "EXTENSION_RECORD_AUTHORITY_SOURCE_SET_INVALID")))(_record())))
    cases.append(Case("23", "new epoch rejects every legacy-corrected fingerprint", lambda: _legacy_overlap_case(root)))
    cases.append(Case("24", "non-initial batch requires an explicit predecessor manifest", _explicit_previous_manifest_required_case))
    cases.append(Case("25", "explicit predecessor bytes and terminal link validate exactly", _previous_batch_link_case))
    cases.append(Case("26", "adjacent batches cannot reuse a fingerprint", _previous_fingerprint_reuse_case))
    cases.append(Case("27", "independent full-convergence audit runs against a real Git fixture", lambda: _independent_audit_fixture_case(root)))
    cases.append(Case("28", "only frozen historical fingerprints can enter a new correction batch", lambda: _baseline_membership_case(root)))
    cases.append(Case("29", "non-object JSON documents fail closed without an exception", lambda: _non_object_documents_fail_closed_case(root)))
    cases.append(Case("30", "the legacy V2 baseline is rejected by the new epoch", lambda: _legacy_baseline_rejected_by_new_epoch_case(root)))
    cases.append(Case("31", "a batch cannot reuse any nonadjacent predecessor fingerprint", _nonadjacent_fingerprint_reuse_case))
    cases.append(Case("32", "batch artifacts are byte-bound and their review status is parsed", _batch_artifact_binding_case))
    cases.append(Case("33", "each fingerprint binds its own frozen raw path and source transition", lambda: _baseline_raw_identity_binding_case(root)))
    cases.append(Case("34", "actual record fingerprints must equal their manifest binding", lambda: _record_manifest_binding_case(root)))
    cases.append(Case("35", "the actual record predecessor must continue the manifest chain", lambda: _actual_record_chain_case(root)))
    cases.append(Case("36", "an exact committed-only descendant HISTORY supplement is accepted", lambda: _descendant_supplement_primary_positive_case(root)))
    cases.append(Case("37", "current failures and unsealed future HISTORY rows cannot enter the supplement", lambda: _descendant_supplement_current_and_future_negative_case(root)))
    cases.append(Case("38", "primary and independent audits reject missing inputs and source blob drift", lambda: _descendant_supplement_binding_negative_case(root)))
    cases.append(Case("39", "batch and record schemas require the exact supplement byte digest", lambda: (lambda record, manifest: (record.pop("descendant_history_supplement_sha256"), manifest.pop("descendant_history_supplement_sha256"), _expect_failure(convergence.validate_extension_record_document(record), "EXTENSION_RECORD_FIELD_SET_MISMATCH"), _expect_failure(convergence.validate_batch_manifest_document(manifest), "BATCH_MANIFEST_FIELD_SET_MISMATCH")))(_record(), _batch())))
    cases.append(Case("40", "effective resolver requires the complete explicit full-convergence input set", lambda: _effective_all_or_none_case(root)))
    cases.append(Case("41", "effective resolver requires exact terminal historical coverage", _effective_terminal_coverage_case))
    cases.append(Case("42", "unregistered future HISTORY rows remain active current failures", _effective_novel_history_is_active_case))
    cases.append(Case("43", "missing authorized historical Raw rows fail closed as suppression", _effective_missing_history_fails_closed_case))
    cases.append(Case("44", "legacy corrections remain exact and valid on the current descendant Head", lambda: _legacy_current_binding_revalidation_case(root)))
    cases.append(Case("45", "legacy preflight failure clears the entire verified correction set", lambda: _legacy_preflight_failure_clears_verified_set_case(root)))
    cases.append(Case("46", "the real 510-to-501 reconciliation preserves 19 exact dispositions and 10 novel identities", lambda: _real_missing19_novel10_positive_case(root)))
    cases.append(Case("47", "missing, successor-drifted, and false-target dispositions fail closed", lambda: _real_disposition_negative_case(root)))
    cases.append(Case("48", "a dispositioned frozen raw identity cannot silently reappear", lambda: _disposed_identity_reappearance_fails_case(root)))
    cases.append(Case("49", "terminal coverage is exactly 489 live records and excludes all 19 dispositions", lambda: _real_live_terminal_coverage_case(root)))
    cases.append(Case("50", "independent record audit duplicates closed fields, dispositions, state, invalidation, revocation, aggregate digests, and authority bytes", lambda: _independent_record_contract_parity_case(root)))
    cases.append(Case("51", "independent current-manifest audit binds authorized ancestry and the explicit supplement digest", lambda: _independent_current_manifest_binding_parity_case(root)))
    cases.append(Case("52", "minimal historical identity backfill is accepted by both auditors", _minimal_historical_backfill_positive_case))
    cases.append(Case("53", "historical backfill cannot expand into Owner authority fields", _historical_backfill_field_expansion_attack_case))
    cases.append(Case("54", "Registry fake roles and Consumer authority claims fail both auditors", _registry_role_matrix_attack_case))
    cases.append(Case("55", "ACTIVE and RETIRED identities cannot substitute unrelated current components", _unrelated_lineage_substitution_attack_case))
    cases.append(Case("56", "ACTIVE plus TEST_ONLY is rejected by the closed state matrix", _active_plus_test_only_attack_case))
    cases.append(Case("57", "Registry component primary key is exact-cardinality", lambda: _authority_primary_key_attack_case("registry")))
    cases.append(Case("58", "dynamic-reference primary key is exact-cardinality", lambda: _authority_primary_key_attack_case("dynamic")))
    cases.append(Case("59", "supersession primary key is exact-cardinality", lambda: _authority_primary_key_attack_case("supersession")))
    cases.append(Case("60", "retirement primary key is exact-cardinality", lambda: _authority_primary_key_attack_case("retirement")))
    cases.append(Case("61", "supersedes relations reject wildcard authority", _supersedes_wildcard_attack_case))
    cases.append(Case("62", "historical backfill cannot drift from its exact source commit and blob", _historical_backfill_exact_identity_attack_case))
    cases.append(Case("63", "dynamic locations, constants, and targets are rechecked against Git bytes", _dynamic_reference_repo_forgery_attack_case))
    cases.append(Case("64", "duplicate target, digest, and reason forgeries fail both auditors", lambda: _duplicate_evidence_forgery_attack_case(root)))
    cases.append(Case("65", "boolean supersession counts fail both auditors", _bool_supersession_count_attack_case))
    cases.append(Case("66", "boolean dynamic-reference counts fail both auditors", _bool_dynamic_count_attack_case))
    cases.append(Case("67", "boolean dynamic-reference locations fail both auditors", _bool_dynamic_location_attack_case))
    cases.append(Case("68", "boolean record failure_count fails both auditors", _bool_record_failure_count_attack_case))
    cases.append(Case("69", "boolean batch counts fail both auditors", lambda: _bool_batch_count_attack_case(root)))
    cases.append(Case("70", "boolean descendant supplement zero counts fail both auditors", lambda: _bool_supplement_zero_count_attack_case(root)))
    cases.append(Case("71", "production-reachable DIAGNOSTIC_ONLY active lineage fails both auditors", _diagnostic_only_active_lineage_attack_case))
    cases.append(Case("72", "historical backfill requires every closed field", _historical_backfill_missing_field_attack_case))
    cases.append(Case("73", "component inventory cannot backfill a missing historical identity", _historical_backfill_no_inventory_fallback_attack_case))
    cases.append(Case("74", "historical backfill composite keys are unique", _historical_backfill_composite_key_attack_case))
    cases.append(Case("75", "registry roles obey the closed ownership matrix", _registry_closed_role_matrix_case))
    cases.append(Case("76", "dynamic-reference target digests fail both auditors", _dynamic_target_digest_attack_case))
    cases.append(Case("77", "v3 successor preserves the exact v2 seal and scanner lineage", lambda: _v3_successor_positive_case(root)))
    cases.append(Case("78", "v3 rejects ID reuse, predecessor drift, identity drop, bool counts, and sequence drift", lambda: _v3_successor_negative_case(root)))
    cases.append(Case("79", "v3 builder refuses to overwrite an existing append-only output", lambda: _v3_builder_append_only_negative_case(root)))
    cases.append(Case("80", "committed schema seals accept LF and CRLF only and reject worktree content drift", lambda: _schema_blob_lf_crlf_portability_case(root)))
    cases.append(Case("81", "committed predecessor schema drift fails both auditors", lambda: _schema_committed_predecessor_drift_case(root)))
    cases.append(Case("82", "successor schema is committed at the evaluated Head and rejects stale or open authority", lambda: _v3_schema_committed_binding_negative_case(root)))
    cases.append(Case("83", "canonical predecessor filenames remain sequence-bound across three batches", _canonical_previous_batch_chain_case))
    cases.append(Case("84", "supplement authority accepts exact pre-base history but rejects post-report sources", lambda: _supplement_prebase_source_ancestry_case(root)))
    cases.append(Case("85", "a post-touch sidecar can route only to an exact ancestor batch in the explicit current chain", _post_touch_ancestor_batch_routing_case))
    cases.append(Case("86", "an unrelated valid batch path cannot acquire post-touch trust", _post_touch_nonchain_batch_routing_case))
    cases.append(Case("87", "malformed post-touch sidecars fail closed in both auditors", _post_touch_malformed_sidecar_routing_case))
    cases.append(Case("88", "an invalid explicit batch chain cannot expose post-touch trust", _post_touch_invalid_chain_never_trusts_case))
    cases.append(Case("89", "post-touch path aliases selectors and escapes never route or expose trust", _post_touch_path_aliases_never_route_case))
    cases.append(Case("90", "the explicit historical Delta metadata ledger is CLI-routed only with a complete full-convergence set", lambda: _historical_delta_metadata_input_coupling_case(root)))
    cases.append(Case("91", "historical Delta metadata authority requires primary PASS independent GO and exact projection parity", lambda: _historical_delta_metadata_dual_gate_case(root)))
    cases.append(Case("92", "ledger fingerprints correction IDs and record paths cannot collide with legacy or batch authority", _historical_delta_metadata_collision_case))
    cases.append(Case("93", "terminal coverage is 587 minus legacy 12 minus ledger 86 while Raw 590 preserves three exact current blockers", _historical_delta_metadata_set_algebra_and_raw_case))
    cases.append(Case("94", "effective reporting keeps batch record count separate and remains FAIL on the exact three current blockers", lambda: _historical_delta_metadata_effective_report_case(root)))
    cases.append(Case("95", "a terminal batch requires an explicit PASS historical Delta metadata ledger", lambda: _terminal_historical_delta_metadata_ledger_omission_case(root)))
    cases.append(Case("96", "BROKEN_BATCH clears every ledger projection and downstream refuses failed composite corrections", lambda: _broken_composite_clears_ledger_authority_case(root)))
    cases.append(Case("97", "primary-only authorized raw identity mutation cannot survive independent canonical projection parity", lambda: _authority_projection_tamper_case(mutate_summary=False)))
    cases.append(Case("98", "primary-only record summary removal cannot survive independent canonical projection parity", lambda: _authority_projection_tamper_case(mutate_summary=True)))
    cases.append(Case("99", "a frozen Raw report cannot remove blockers while retaining self-reported validity", lambda: _live_raw_binding_cases(root, "FROZEN_FORGED")))
    cases.append(Case("100", "a descendant externally self-attested Raw report is rejected without exact internal scanner output", lambda: _live_raw_binding_cases(root, "DESCENDANT_FORGED")))
    cases.append(Case("101", "a descendant Raw report passes only when internal scanner re-execution emits exact bytes", lambda: _live_raw_binding_cases(root, "DESCENDANT_PASS")))
    cases.append(Case("102", "classifier binding and scanner consume one immutable Live Raw and PR-body snapshot", lambda: _single_live_raw_snapshot_case(root)))
    cases.append(Case("103", "an explicit full-convergence PR body cannot be supplied without the complete FC input set", lambda: _full_convergence_pr_body_input_coupling_case(root)))
    cases.append(Case("104", "subject-projection v1 and successor-v2 CLI routing is both-or-none and requires the complete FC set plus HDM", lambda: _subject_projection_cli_and_input_coupling_case(root)))
    cases.append(Case("105", "frozen subject-projection v1 trust still requires primary PASS independent GO exact 82-map parity and PASS HDM", _subject_projection_dual_gate_and_parity_case))
    cases.append(Case("106", "broken nonexplicit aliased and outside-root subject-projection routes never reach trust validators", _subject_projection_routing_fail_closed_case))
    cases.append(Case("107", "subject-projection suppresses only projection drift while Post-Touch V1 keeps its exact scope", _subject_projection_suppression_scope_and_v1_compatibility_case))
    cases.append(Case("108", "standalone terminal receipt proves exact 501 plus 86 equals 587 and thirteen-batch 489 coverage", _independent_terminal_exact_partition_case))
    cases.append(Case("109", "standalone terminal receipt fails closed when the explicit HDM ledger is omitted", _independent_terminal_ledger_omission_case))
    cases.append(Case("110", "equal-cardinality terminal substitution exposes one exact missing and extra fingerprint", _independent_terminal_equal_cardinality_tamper_case))
    cases.append(Case("111", "primary HDM and legacy HDM overlaps invalidate the terminal partition", _independent_terminal_partition_overlap_case))
    cases.append(Case("112", "standalone HDM CLI input is coupled to the complete full-convergence input set", lambda: _independent_hdm_cli_coupling_case(root)))
    cases.append(Case("113", "real committed HDM successor v2 resolves exact 86-set primary and independent parity", lambda: _independent_real_hdm_authority_case(root)))
    cases.append(Case("114", "successor-v4 implementation binding passes with exactly five trusted fingerprints", lambda: _successor_v4_positive_case(root)))
    cases.append(Case("115", "successor-v4 predecessor schema SHA drift fails closed", lambda: _successor_v4_predecessor_sha_negative_case(root)))
    cases.append(Case("116", "successor-v4 fingerprint-set digest drift fails closed", lambda: _successor_v4_fingerprint_set_negative_case(root)))
    cases.append(Case("117", "successor-v4 implementation-binding SHA drift fails closed", lambda: _successor_v4_binding_sha_negative_case(root)))
    cases.append(Case("118", "successor-v4 res-path target disappearance fails closed", lambda: _successor_v4_target_drift_negative_case(root)))
    cases.append(Case("119", "exact Alpha01 historical script links to its current Resource in both auditors", lambda: _alpha01_active_backfill_path_link_positive_case(root)))
    cases.append(Case("120", "Alpha01 active-backfill path link rejects every identity and authority mutation in both auditors", lambda: _alpha01_active_backfill_path_link_mutation_case(root)))
    cases.append(Case("121", "unrelated same-component active path drift remains rejected", lambda: _unrelated_active_path_drift_still_rejected_case(root)))
    cases.append(Case("122", "full convergence exposes subject-projection trust only after committed four-gate disjoint 82 plus 2", _subject_projection_four_gate_successor_case))
    cases.append(Case("123", "standalone independent audit imports only successor independent and clears both epochs on pair failure", _independent_subject_projection_epoch_pair_case))
    cases.append(Case("124", "terminal subject-projection replacement activates only disjoint v4 v5 v3 union 109", _terminal_subject_projection_replacement_case))
    cases.append(Case("125", "post-touch successor-v2 replaces the old owner at an effective exact count of two", _post_touch_successor_v2_effective_owner_case))
    cases.append(Case("126", "optional successor-v5 import fails closed only when its replacement path is requested", _optional_v5_import_fails_only_on_replacement_case))
    return cases


def _duplicate_key_result(_: Path) -> list[str]:
    try:
        json.loads('{"a":1,"a":2}', object_pairs_hook=convergence._strict_object)
    except convergence.DuplicateJsonKeyError:
        return ["DUPLICATE_JSON_KEY"]
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    root = args.project.resolve()
    results = []
    for case in build_cases(root):
        try:
            case.run()
            results.append({"case_id": case.case_id, "description": case.description, "status": "PASS", "failures": []})
        except Exception as exc:
            results.append({"case_id": case.case_id, "description": case.description, "status": "FAIL", "failures": [f"{type(exc).__name__}: {exc}"]})
    passed = sum(1 for row in results if row["status"] == "PASS")
    report = {
        "schema_version": "space_syndicate.v076.reuse_exact_failure_correction_v2.full_convergence_selftest.v1",
        "authorization_id": convergence.AUTHORIZATION_ID,
        "FULL_CONVERGENCE_SELFTEST_STATUS": "PASS" if passed == len(results) else "FAIL",
        "FULL_CONVERGENCE_SELFTEST_CASE_COUNT": len(results),
        "FULL_CONVERGENCE_SELFTEST_PASS_COUNT": passed,
        "legacy_record_mutation_count": 0,
        "legacy_seal_mutation_count": 0,
        "generated_correction_record_count": 0,
        "cases": results,
    }
    print(json.dumps(report, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
