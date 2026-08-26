#!/usr/bin/env python3
"""Focused negative/compatibility tests for the V2 full-convergence epoch."""

from __future__ import annotations

import argparse
import copy
import json
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

import v076_reuse_exact_failure_correction_v2_full_convergence as convergence
import v076_reuse_correction_v2_independent_audit as independent_audit


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


def _identity_binding() -> dict[str, Any]:
    selector = {
        "component_ids": ["component.history.sample"],
        "paths": ["scripts/history/sample.gd"],
        "retirement_ids": [],
        "supersession_ids": ["supersession.sample"],
    }
    projection = {
        "registry_rows": [{
            "component_id": "component.history.sample",
            "path": "scripts/history/sample.gd",
            "owner_component_id": "component.current.owner",
        }],
        "supersession_rows": [{
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
        "current_role": "CONSUMER",
        "diagnostic_only_status": "NOT_DIAGNOSTIC_ONLY",
        "documentation_only_status": "NOT_DOCUMENTATION_ONLY",
        "dynamic_reference_status": "NOT_DYNAMIC_REFERENCE",
        "generated_evidence_status": "NOT_GENERATED_EVIDENCE",
        "first_seen_commit": "3" * 40,
        "historical_blob_sha256": "1" * 64,
        "historical_component_id": "component.history.sample",
        "historical_owner_id": "component.history.sample",
        "historical_path": "scripts/history/sample.gd",
        "historical_production_reachability": "NONREACHABLE",
        "historical_role": "HISTORICAL_OWNER",
        "invalidation_policy": _touch_policy(),
        "recommended_disposition": "HISTORICAL_SUPERSEDED_NONREACHABLE",
        "retired_status": "SUPERSEDED_NONREACHABLE",
        "subject_projection": projection,
        "subject_projection_sha256": convergence.sha256_bytes(convergence.canonical_bytes(projection)),
        "source_commit": "3" * 40,
        "superseded_by": ["component.current.owner"],
        "supersedes": [],
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
        "domain_ids": ["domain.sample"],
        "domain_set_sha256": convergence._line_set_sha(["domain.sample"]),
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
        "owner_ids": ["component.current.owner", "component.history.sample"],
        "owner_set_sha256": convergence._line_set_sha([
            "component.current.owner", "component.history.sample",
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
        registry.write_text(json.dumps({"component_inventory": [{
            "component_id": "component.history.sample",
            "path": "scripts/history/sample.gd",
            "owner_component_id": "component.current.owner",
        }]}), encoding="utf-8")
        supersession.write_text(json.dumps({"supersessions": [{
            "supersession_id": "supersession.sample",
            "old_component_id": "component.history.sample",
            "new_component_id": "component.current.owner",
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


def _copy_locked(root: Path, fixture: Path, relative: str) -> None:
    destination = fixture / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / relative, destination)


def _independent_audit_fixture_case(root: Path) -> None:
    with tempfile.TemporaryDirectory(prefix="v076-fc-independent-") as temporary:
        fixture = Path(temporary)
        _git(fixture, "init", "--quiet")
        _git(fixture, "config", "user.email", "selftest@example.invalid")
        _git(fixture, "config", "user.name", "V076 Selftest")
        for relative in (
            convergence.SCHEMA_REL.as_posix(),
            convergence.BASELINE_REPORT_REL.as_posix(),
            convergence.LEGACY_SEAL_MANIFEST_REL.as_posix(),
            *(binding["path"] for binding in convergence.LEGACY_RECORD_BINDINGS),
        ):
            _copy_locked(root, fixture, relative)
        docs = fixture / "docs/architecture"
        registry = docs / "V076_HISTORICAL_REUSE_REGISTRY.json"
        supersession = docs / "V076_SUPERSESSION_MAP.json"
        owner_map = docs / "V076_OWNER_REUSE_MAP.md"
        _write_json(registry, {"component_inventory": [{
            "component_id": "component.history.sample",
            "path": "scripts/history/sample.gd",
            "owner_component_id": "component.current.owner",
        }]})
        _write_json(supersession, {"supersessions": [{
            "supersession_id": "supersession.sample",
            "old_component_id": "component.history.sample",
            "new_component_id": "component.current.owner",
        }]})
        owner_map.write_text(
            "component.history.sample -> component.current.owner\n",
            encoding="utf-8",
        )
        for relative, contents in (
            ("scripts/history/sample.gd", "extends RefCounted\n"),
            ("scripts/current/owner.gd", "extends RefCounted\n"),
        ):
            path = fixture / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents, encoding="utf-8")
        _git(fixture, "add", ".")
        _git(fixture, "commit", "--quiet", "-m", "fixture authority")
        head = _git(fixture, "rev-parse", "HEAD")
        tree = _git(fixture, "rev-parse", "HEAD^{tree}")
        baseline_report = convergence.load_json_strict(root / convergence.BASELINE_REPORT_REL)
        fingerprints = sorted(
            convergence.authorized_failure_fingerprint_sets(baseline_report)["historical"]
        )[:25]
        fixture_baseline_sha = convergence.sha256_file(
            fixture / convergence.BASELINE_REPORT_REL
        )
        record = _record(fingerprints)
        record["binding_head_sha"] = head
        record["binding_tree_sha"] = tree
        record["baseline_report_sha256"] = fixture_baseline_sha
        projection = independent_audit._subject_projection(
            fixture,
            head,
            _identity_binding()["authority_selectors"],
        )
        _expect(isinstance(projection, dict), "fixture subject projection unresolved")
        for binding in record["identity_binding_by_failure"].values():
            binding["subject_projection"] = copy.deepcopy(projection)
            binding["subject_projection_sha256"] = convergence.sha256_bytes(
                convergence.canonical_bytes(projection)
            )
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
        manifest = _batch()
        manifest["binding_head_sha"] = head
        manifest["binding_tree_sha"] = tree
        manifest["baseline_report_sha256"] = fixture_baseline_sha
        manifest["failure_fingerprints"] = fingerprints
        manifest["failure_count"] = len(fingerprints)
        manifest["failure_fingerprint_set_sha256"] = convergence._line_set_sha(
            fingerprints
        )
        manifest["record_bindings"][0].update({
            "failure_fingerprints": fingerprints,
            "record_payload_sha256": record["record_payload_sha256"],
            "record_sha256": convergence.sha256_file(record_path),
        })
        manifest["record_chain_terminal_sha256"] = record["record_payload_sha256"]
        manifest_path = fixture / "batch-001-manifest.json"
        _write_json(manifest_path, manifest)
        original_baseline_sha = independent_audit.FULL_CONVERGENCE_BASELINE_SHA
        independent_audit.FULL_CONVERGENCE_BASELINE_SHA = fixture_baseline_sha
        try:
            report = independent_audit.audit_full_convergence_batch(
                fixture,
                manifest_path,
                evaluated_head=head,
                baseline_report_path=fixture / convergence.BASELINE_REPORT_REL,
            )
        finally:
            independent_audit.FULL_CONVERGENCE_BASELINE_SHA = original_baseline_sha
        _expect(report["status"] == "GO", json.dumps(report, sort_keys=True))


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


def build_cases(root: Path) -> list[Case]:
    cases: list[Case] = []
    cases.append(Case("01", "new schema is exact and authorized", lambda: _expect(not convergence.validate_schema(root), str(convergence.validate_schema(root)))))
    cases.append(Case("02", "six legacy records and predecessor seal remain byte locked", lambda: _expect(convergence.verify_legacy_anchor(root)["status"] == "PASS", str(convergence.verify_legacy_anchor(root)))))
    cases.append(Case("03", "valid extension record passes pure contract", lambda: _expect(not convergence.validate_extension_record_document(_record()), str(convergence.validate_extension_record_document(_record())))))
    cases.append(Case("04", "new record cannot reuse the legacy authorization", lambda: (lambda record: (_expect_failure(convergence.validate_extension_record_document(record), "EXTENSION_RECORD_AUTHORIZATION_ID_MISMATCH")))(dict(_record(), authorization_id=convergence.LEGACY_AUTHORIZATION_ID))))
    cases.append(Case("05", "current rule cannot receive historical correction", lambda: (lambda record: (_expect_failure(convergence.validate_extension_record_document(record), "EXTENSION_RECORD_RULE_CLASS_INVALID")))(dict(_record(), rule_ids=["UNCLASSIFIED_NEW_COMPONENT"], failure_classes=["UNCLASSIFIED_NEW_COMPONENT"], allowed_rule_ids=["UNCLASSIFIED_NEW_COMPONENT"]))))
    cases.append(Case("06", "future automatic correction remains forbidden", lambda: (lambda record: (_expect_failure(convergence.validate_extension_record_document(record), "EXTENSION_RECORD_FUTURE_AUTO_CORRECTION_ENABLED")))(dict(_record(), future_failure_policy={"NEW_FAILURE_REQUIRES_NEW_RECORD": False}))))
    cases.append(Case("07", "subject projection digest is mandatory", lambda: (lambda record: (record["identity_binding_by_failure"][_fingerprint(1)].update({"subject_projection_sha256": "0" * 64}), record.update({"record_payload_sha256": "0" * 64}), _expect_failure(convergence.validate_extension_record_document(record), "IDENTITY_BINDING_PROJECTION_HASH_MISMATCH")))(_record())))
    cases.append(Case("08", "wildcard subject selector is rejected", lambda: (lambda selector: _expect_failure(convergence._selector_failures(selector), "SUBJECT_SELECTOR_NOT_EXACT"))({"component_ids": [], "paths": ["scripts/*"], "retirement_ids": [], "supersession_ids": []})))
    cases.append(Case("09", "valid 25-fingerprint first batch continues legacy terminal", lambda: _expect(not convergence.validate_batch_manifest_document(_batch()), str(convergence.validate_batch_manifest_document(_batch())))))
    cases.append(Case("10", "first batch cannot restart its correction chain", lambda: (lambda manifest: (_expect_failure(convergence.validate_batch_manifest_document(manifest), "BATCH_MANIFEST_FIRST_BATCH_LEGACY_CHAIN_ANCHOR_MISMATCH")))(dict(_batch(), record_chain_start_sha256="8" * 64))))
    cases.append(Case("11", "batch above fifty fingerprints is rejected", lambda: _expect_failure(convergence.validate_batch_manifest_document(_batch(51)), "BATCH_MANIFEST_SIZE_OUT_OF_RANGE")))
    cases.append(Case("12", "nonterminal batch below target is rejected", lambda: _expect_failure(convergence.validate_batch_manifest_document(_batch(24)), "BATCH_MANIFEST_NONTERMINAL_BELOW_TARGET")))
    cases.append(Case("13", "terminal remainder below target is accepted", lambda: _expect(not convergence.validate_batch_manifest_document(_batch(24, terminal=True)), str(convergence.validate_batch_manifest_document(_batch(24, terminal=True))))))
    cases.append(Case("14", "record paths cannot escape the explicit epoch root", lambda: (lambda manifest: (manifest["record_bindings"][0].update({"path": "docs/architecture/reuse_corrections/v2/records/other.json"}), _expect_failure(convergence.validate_batch_manifest_document(manifest), "BATCH_MANIFEST_RECORD_PATH_INVALID")))(_batch())))
    cases.append(Case("15", "batch review cannot be bypassed", lambda: (lambda manifest: (manifest.update({"batch_review_a_status": "NO_GO"}), _expect_failure(convergence.validate_batch_manifest_document(manifest), "BATCH_MANIFEST_BATCH_REVIEW_A_STATUS_MISMATCH")))(_batch())))
    cases.append(Case("16", "subject projection ignores unrelated append and changes on matched owner mutation", _projection_invalidation_case))
    cases.append(Case("17", "duplicate JSON keys are rejected", lambda: (lambda path: (_expect_failure(_duplicate_key_result(path), "DUPLICATE_JSON_KEY")))(root / "unused")))
    cases.append(Case("18", "d701 and legacy raw reports share the exact failure identity set", lambda: (lambda report: _expect(convergence.failure_set_sha(report) == convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256, convergence.failure_set_sha(report)))(json.loads((root / "reports/reuse/correction_v2/baseline_raw_failure_report.json").read_text(encoding="utf-8-sig")))))
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
