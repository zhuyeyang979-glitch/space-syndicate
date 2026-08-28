#!/usr/bin/env python3
"""Focused non-generating tests for subject-projection revalidation primary."""

from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

import v076_subject_projection_revalidation as subject


def expect(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    head = str(subject._git(root, "rev-parse", "HEAD"))
    cases = 0

    failures = subject.validate_schema_file(root)
    expect(not failures, f"schema rejected: {failures}"); cases += 1
    schema = subject.strict_json_file(root / subject.SCHEMA_PATH)
    expect(subject.sha256_bytes((root / subject.SCHEMA_PATH).read_bytes()) == subject.SCHEMA_SHA256, "schema byte seal drift"); cases += 1
    mutated = copy.deepcopy(schema); mutated["record_count"] = 81
    expect("SPR_SCHEMA_VALUE_INVALID:record_count" in subject.validate_schema_document(mutated), "schema cardinality mutation accepted"); cases += 1
    mutated = copy.deepcopy(schema); mutated["projection_sections"] = ["registry_rows"]
    expect(bool(subject.validate_schema_document(mutated)), "projection narrowing accepted"); cases += 1

    try:
        subject.strict_json_bytes(b'{"a":1,"a":2}')
        raise AssertionError("duplicate JSON key accepted")
    except subject.DuplicateJsonKeyError:
        cases += 1
    try:
        subject.strict_json_bytes(b'{"a":NaN}')
        raise AssertionError("non-finite JSON accepted")
    except ValueError:
        cases += 1

    good = {"component_ids":["component.current.x"],"paths":["scripts/x.gd"],"dynamic_reference_ids":[],"supersession_ids":[],"retirement_ids":[]}
    expect(not subject.selector_failures(good), "exact selector rejected"); cases += 1
    bad = copy.deepcopy(good); bad["paths"] = ["scripts/*"]
    expect(bool(subject.selector_failures(bad)), "wildcard selector accepted"); cases += 1
    bad = copy.deepcopy(good); bad["paths"] = ["scripts/../x.gd"]
    expect(bool(subject.selector_failures(bad)), "dot segment accepted"); cases += 1

    transition, failures = subject.audit_authority_transition(root, evaluated_head=head)
    expect(not failures, f"real transition rejected: {failures}"); cases += 1
    expect(len(transition["change_class_only"]) == 78, "78 change_class-only rows not proven"); cases += 1
    expect(transition["change_class_reuse_scan"] == set(subject.REUSE_COMPONENTS), "four reuse-scan rows not proven"); cases += 1

    hdm, failures = subject.validate_hdm_authority(root, head)
    expect(not failures, f"HDM authority rejected: {failures}"); cases += 1
    expect(len(hdm["identity_by_component"]) == 82 and len(hdm["identity_fingerprints"]) == 82, "identity HDM cardinality invalid"); cases += 1
    expect(set(hdm["reuse_by_component"]) == set(subject.REUSE_COMPONENTS), "reuse HDM mapping invalid"); cases += 1
    sample = hdm["identity_by_component"]["component.current.card_player_state_port_v06"]
    expect(sample["rule_id"] == subject.IDENTITY_RULE and sample["authority_kind"] == "HISTORICAL_COMPONENT_IDENTITY_METADATA_BACKFILL", "identity authority kind/rule not exact"); cases += 1
    reuse = hdm["reuse_by_component"]["component.current.card_player_state_port_v06"]
    expect(reuse["rule_id"] == subject.REUSE_RULE and reuse["authority_kind"] == "HISTORICAL_AUTHORITY_REUSE_SCAN_METADATA_BACKFILL", "reuse authority kind/rule not exact"); cases += 1

    batch_paths = [root / subject.FULL_BATCH_ROOT / f"batch-{number:03d}" / f"batch-{number:03d}-manifest.json" for number in range(1, 8)]
    chain, failures = subject.validate_explicit_batch_chain(root, head, batch_paths)
    expect(not failures and len(chain) == 7, f"explicit batch chain rejected: {failures}"); cases += 1
    authorized = set(transition["change_class_only"]) | set(transition["change_class_reuse_scan"])
    targets, failures = subject.derive_revalidation_targets(
        root, head, chain, subject.CURRENT_BATCH_PATH, authorized
    )
    expect(not failures and len(targets) == 82, f"exact prior invalidation set rejected: {failures}"); cases += 1
    expect(
        {row["component_id"] for row in targets.values()} == authorized,
        "prior invalidations are not a component bijection",
    ); cases += 1
    expect(
        set(targets).isdisjoint(hdm["identity_fingerprints"]),
        "old correction fingerprints were conflated with HDM authority fingerprints",
    ); cases += 1
    _, failures = subject.validate_explicit_batch_chain(root, head, batch_paths[1:])
    expect("SPR_BATCH_CHAIN_NOT_CONTIGUOUS_FROM_001" in failures, "orphan chain accepted"); cases += 1

    batch4 = subject.strict_json_file(batch_paths[3])
    binding = batch4["record_bindings"][0]
    prior = subject.strict_json_file(root / binding["path"])
    fp = binding["failure_fingerprints"][0]
    identity = prior["identity_binding_by_failure"][fp]
    selector = identity["authority_selectors"]
    old = subject.subject_projection(root, prior["binding_head_sha"], selector)
    expect(old == identity["subject_projection"], "prior projection was not rebuilt exactly"); cases += 1
    rebound = subject.subject_projection(root, subject.CHANGE_COMMIT, selector)
    changed, _ = subject._changed_component(old, rebound)
    expect(changed == {identity["current_component_id"]}, "projection changed more than exact component"); cases += 1
    expect(subject.projection_changing_commits(root, prior["binding_head_sha"], head, selector) == [subject.CHANGE_COMMIT], "projection-changing commit not unique"); cases += 1

    trusted = {fp:{"allowed_invalidations":[subject.ALLOWED_INVALIDATION],"prior_record_path":binding["path"]}}
    expect(subject.allows_invalidation(trusted, fingerprint=fp, invalidation_code=subject.ALLOWED_INVALIDATION, prior_record_path=binding["path"]), "exact subject invalidation rejected"); cases += 1
    expect(not subject.allows_invalidation(trusted, fingerprint=fp, invalidation_code="BLOB_CHANGED_CORRECTION_INVALID", prior_record_path=binding["path"]), "BLOB invalidation accepted"); cases += 1
    expect(not subject.allows_invalidation(trusted, fingerprint=fp, invalidation_code="TOUCHED_CORRECTION_INVALID", prior_record_path=binding["path"]), "TOUCHED invalidation accepted"); cases += 1
    expect(not subject.allows_invalidation(trusted, fingerprint=fp, invalidation_code=subject.ALLOWED_INVALIDATION, prior_record_path="other.json"), "wrong prior path accepted"); cases += 1

    print(json.dumps({"status":"PASS","case_count":cases,"change_class_only_count":78,"change_class_reuse_scan_count":4,"identity_hdm_count":82,"formal_record_generation_count":0}, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
