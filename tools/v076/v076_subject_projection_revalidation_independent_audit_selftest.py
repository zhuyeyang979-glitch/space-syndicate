#!/usr/bin/env python3
"""Focused tests for the independent subject-projection revalidation audit."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import v076_subject_projection_revalidation_independent_audit as audit
import v076_reuse_correction_v2_independent_audit as integration


def expect(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    head = str(audit._git(root, "rev-parse", "HEAD"))
    groups, failures = audit.audit_authority_change(root, authority_head=head)
    expect(not failures, f"real authority transition rejected: {failures}")
    expect(len(groups["change_class_only"]) == 78, "78 change_class-only rows not proven")
    expect(groups["change_class_reuse_scan"] == set(audit.REUSE_SCAN_COMPONENTS), "4 reuse_scan rows not proven")

    try:
        audit.strict_json_bytes(b'{"a":1,"a":2}')
        raise AssertionError("duplicate JSON key accepted")
    except audit.DuplicateKeyError:
        pass

    good = {"component_ids": ["component.current.x"], "paths": ["scripts/x.gd"],
            "dynamic_reference_ids": [], "supersession_ids": [], "retirement_ids": []}
    expect(audit._exact_selector(good), "exact selector rejected")
    bad = dict(good); bad["paths"] = ["scripts/*"]
    expect(not audit._exact_selector(bad), "wildcard selector accepted")
    bad = dict(good); bad["paths"] = ["scripts/../x.gd"]
    expect(not audit._exact_selector(bad), "dot-segment selector accepted")
    prior_identity = {"authority_selectors": good}
    expect(audit._selector_matches_prior(good, prior_identity), "prior selector equality rejected")
    borrowed = dict(good); borrowed["component_ids"] = ["component.current.other"]
    expect(not audit._selector_matches_prior(borrowed, prior_identity), "borrowed selector accepted")

    formal_path = root / "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/batch-002/v075_production_combat_candidate.json"
    formal = audit.strict_json_file(formal_path)
    formal_fp = "V2F-340fc56e2438e2d8f6d6397c5d6ddc1ae68a9318f2efb49bef8d218d42f7f8d1"
    formal_identity = formal["identity_binding_by_failure"][formal_fp]
    rebuilt = audit._projection(root, formal["binding_head_sha"], formal_identity["authority_selectors"])
    expect(rebuilt == formal_identity["subject_projection"], "independent full projection differs from formal record")
    expect(bool(rebuilt["owner_map_lines"]), "formal owner-map surface was not rebuilt")
    drift = dict(rebuilt); drift["owner_map_lines"] = rebuilt["owner_map_lines"] + ["forged"]
    expect(not audit._nonregistry_surfaces_unchanged(rebuilt, drift), "owner surface drift accepted")
    drift = dict(rebuilt); drift["supersession_rows"] = [{"supersession_id": "forged"}]
    expect(not audit._nonregistry_surfaces_unchanged(rebuilt, drift), "supersession surface drift accepted")

    schema = audit.strict_json_file(root / audit.SCHEMA_PATH)
    schema_raw = (root / audit.SCHEMA_PATH).read_bytes()
    expect(not audit._schema_contract_failures(schema, schema_raw), "complete schema contract drifted")
    expect(audit.sha256_bytes(schema_raw) == audit.SCHEMA_SHA256, "schema byte seal drifted")
    expect(set(schema["manifest_required_fields"]) == set(audit.MANIFEST_FIELDS), "manifest closed fields drifted")
    expect(set(schema["record_required_fields"]) == set(audit.RECORD_FIELDS), "record closed fields drifted")
    expect(set(schema["manifest_required_fields"][:-1]) != set(audit.MANIFEST_FIELDS), "manifest field deletion accepted")
    expect(set(schema["record_required_fields"] + ["forged"]) != set(audit.RECORD_FIELDS), "record field addition accepted")
    authorized = groups["change_class_only"] | groups["change_class_reuse_scan"]
    coverage = sorted(authorized)
    expect(audit._bijective_component_coverage(coverage, authorized), "valid component bijection rejected")
    duplicate = coverage[:-1] + [coverage[0]]
    expect(not audit._bijective_component_coverage(duplicate, authorized), "duplicate component accepted")

    hdm, hdm_failures = audit._ledger_hdm_authority(root, head)
    expect(not hdm_failures, f"exact ledger-to-HDM authority rejected: {hdm_failures}")
    expect(len(hdm["identity_by_component"]) == 82, "HDM identity component mapping is not exact")
    explicit = [
        audit.FULL_BATCH_ROOT + f"batch-{number:03d}/batch-{number:03d}-manifest.json"
        for number in range(1, 8)
    ]
    targets, target_failures = audit._derive_revalidation_targets(
        root, head, explicit, audit.CURRENT_BATCH_PATH, authorized
    )
    expect(not target_failures and len(targets) == 82, f"prior target derivation failed: {target_failures}")
    expect(set(targets).isdisjoint(hdm["identity_fingerprints"]), "prior and HDM fingerprints were conflated")

    trusted = {"V2F-" + "a" * 64: {"allowed_invalidations": [audit.ALLOWED_INVALIDATION], "prior_record_path": "x.json"}}
    fp = "V2F-" + "a" * 64
    expect(audit.allows_invalidation(trusted, fingerprint=fp, invalidation_code=audit.ALLOWED_INVALIDATION, prior_record_path="x.json"), "exact projection invalidation rejected")
    expect(not audit.allows_invalidation(trusted, fingerprint=fp, invalidation_code="TOUCHED_CORRECTION_INVALID", prior_record_path="x.json"), "TOUCHED suppression accepted")
    expect(not audit.allows_invalidation(trusted, fingerprint=fp, invalidation_code="BLOB_CHANGED_CORRECTION_INVALID", prior_record_path="x.json"), "BLOB suppression accepted")
    expect(not audit.allows_invalidation(trusted, fingerprint=fp, invalidation_code=audit.ALLOWED_INVALIDATION, prior_record_path="other.json"), "wrong prior record accepted")

    subject_finding = integration._finding("FULL_CONVERGENCE_SUBJECT_PROJECTION_CHANGED", "P0", "changed", fingerprint=fp, path="x.json")
    blob_finding = integration._finding("FULL_CONVERGENCE_CURRENT_BLOB_CHANGED", "P0", "blob", fingerprint=fp, path="x.json")
    touched_finding = integration._finding("FULL_CONVERGENCE_TOUCHED_CORRECTION_INVALID", "P0", "touch", fingerprint=fp, path="x.json")
    kept = integration._suppress_subject_projection_revalidation_findings([subject_finding, blob_finding, touched_finding], trusted)
    expect(subject_finding not in kept, "exact subject-projection finding not suppressed")
    expect(blob_finding in kept, "blob finding was widened into suppression")
    expect(touched_finding in kept, "touched finding was widened into suppression")
    wrong_path = integration._finding("FULL_CONVERGENCE_SUBJECT_PROJECTION_CHANGED", "P0", "changed", fingerprint=fp, path="other.json")
    expect(wrong_path in integration._suppress_subject_projection_revalidation_findings([wrong_path], trusted), "wrong-path subject finding suppressed")

    wrapper_trusted = {
        "V2F-" + f"{number:064x}": {
            "allowed_invalidations": [audit.ALLOWED_INVALIDATION],
            "prior_record_path": f"{audit.FULL_RECORD_ROOT}wrapper-{number}.json",
            "revalidation_id": f"SPR-{number}",
            "record_path": f"{audit.REVALIDATION_RECORD_ROOT}wrapper-{number}.json",
            "revalidation_binding_head_sha": "b" * 40,
        }
        for number in range(82)
    }
    valid_result = {
        "status": "GO",
        "findings": [],
        "trusted_by_fingerprint": wrapper_trusted,
        "trusted_fingerprint_count": 82,
        "record_count": 82,
        "fingerprints": sorted(wrapper_trusted),
    }
    class StatusSubclass(str):
        pass

    class ListSubclass(list):
        pass

    first_fingerprint = next(iter(wrapper_trusted))
    first_row = wrapper_trusted[first_fingerprint]
    subclass_key_row = {
        (StatusSubclass(key) if key == "allowed_invalidations" else key): value
        for key, value in first_row.items()
    }

    original_validator = integration._subject_projection_revalidation.audit_manifest_and_records
    try:
        integration._subject_projection_revalidation.audit_manifest_and_records = lambda *args, **kwargs: valid_result
        findings, routed, summary = integration._subject_projection_revalidation_sidecar_findings(root, root / "sidecar.json", [(root / "batch.json", {})], head, explicit_batch_chain_valid=True)
        expect(not findings and routed == wrapper_trusted and summary["status"] == "PASS", "valid independent route rejected")

        attacks = [
            None,
            "",
            True,
            [],
            {**valid_result, "trusted_by_fingerprint": dict(list(wrapper_trusted.items())[:-1]), "trusted_fingerprint_count": 81, "fingerprints": sorted(wrapper_trusted)[:-1]},
            {**valid_result, "findings": None},
            {**valid_result, "findings": [None]},
            {**valid_result, "trusted_by_fingerprint": None},
            {**valid_result, "trusted_fingerprint_count": True},
            {**valid_result, "record_count": True},
            {**valid_result, "fingerprints": list(reversed(sorted(wrapper_trusted)))},
            {**valid_result, "trusted_by_fingerprint": {**wrapper_trusted, 7: wrapper_trusted[next(iter(wrapper_trusted))]}},
            {**valid_result, "status": StatusSubclass("GO")},
            {**valid_result, "status": True},
            {**valid_result, "status": None},
            {**valid_result, "trusted_by_fingerprint": {**wrapper_trusted, first_fingerprint: {**first_row, "allowed_invalidations": ListSubclass([audit.ALLOWED_INVALIDATION])}}},
            {**valid_result, "trusted_by_fingerprint": {**wrapper_trusted, first_fingerprint: {**first_row, "allowed_invalidations": [StatusSubclass(audit.ALLOWED_INVALIDATION)]}}},
            {**valid_result, "trusted_by_fingerprint": {**wrapper_trusted, first_fingerprint: subclass_key_row}},
            {
                **valid_result,
                "trusted_by_fingerprint": {
                    **wrapper_trusted,
                    next(iter(wrapper_trusted)): {
                        **wrapper_trusted[next(iter(wrapper_trusted))],
                        "prior_record_path": "docs/outside-authority.json",
                    },
                },
            },
        ]
        for attack in attacks:
            integration._subject_projection_revalidation.audit_manifest_and_records = lambda *args, _attack=attack, **kwargs: _attack
            findings, routed, summary = integration._subject_projection_revalidation_sidecar_findings(root, root / "sidecar.json", [(root / "batch.json", {})], head, explicit_batch_chain_valid=True)
            expect(bool(findings) and findings[0]["severity"] == "P0" and not routed and summary["status"] == "FAIL", f"wrapper attack accepted: {attack!r}")

        def raise_attack(*args, **kwargs):
            raise RuntimeError("validator attack")
        integration._subject_projection_revalidation.audit_manifest_and_records = raise_attack
        findings, routed, summary = integration._subject_projection_revalidation_sidecar_findings(root, root / "sidecar.json", [(root / "batch.json", {})], head, explicit_batch_chain_valid=True)
        expect(bool(findings) and not routed and summary["status"] == "FAIL", "validator exception escaped fail-closed wrapper")

        findings, routed, summary = integration._subject_projection_revalidation_sidecar_findings(root, root / "sidecar.json", [(root / "batch.json", {})], head, explicit_batch_chain_valid=False)
        expect(bool(findings) and not routed and summary["status"] == "FAIL", "invalid explicit chain did not fail closed")
    finally:
        integration._subject_projection_revalidation.audit_manifest_and_records = original_validator

    print(json.dumps({"status": "PASS", "case_count": 56,
                      "change_class_only_count": 78, "change_class_reuse_scan_count": 4}, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
