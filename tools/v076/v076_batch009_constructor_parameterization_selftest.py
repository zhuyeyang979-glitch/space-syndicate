"""Byte-parity checks for the Batch009 pure-constructor parameters."""
from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import types
from pathlib import Path

import v076_reuse_full_convergence_batch009_materializer as current


def _old_module(root: Path) -> types.ModuleType:
    source = subprocess.run(
        ["git", "show", "HEAD:tools/v076/v076_reuse_full_convergence_batch009_materializer.py"],
        cwd=root,
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    module = types.ModuleType("v076_batch009_before_parameterization")
    module.__file__ = str(root / "tools/v076/v076_reuse_full_convergence_batch009_materializer.py")
    exec(compile(source, module.__file__, "exec"), module.__dict__)
    return module


def _fixtures() -> tuple[list[str], dict, dict, dict]:
    fingerprints = ["V2F-" + "1" * 64, "V2F-" + "2" * 64]
    bindings = {}
    identities = {}
    for index, fingerprint in enumerate(fingerprints, 1):
        path = f"tests/fixture_{index}.gd"
        bindings[fingerprint] = {
            "current_production_reachability": "TEST_ONLY",
            "current_role": "TEST_SUPPORT",
            "current_component_id": f"component.current.fixture_{index}",
            "current_path": path,
            "domain_id": "fixture.domain",
            "historical_component_id": f"component.current.fixture_{index}",
            "historical_path": path,
            "current_owner_id": "component.current.owner",
            "historical_owner_id": "component.current.owner",
            "recommended_disposition": "HISTORICAL_TEST_ONLY",
            "source_commit": "a" * 40,
            "authority_selectors": {
                "dynamic_reference_ids": [],
                "supersession_ids": [],
                "retirement_ids": [],
            },
        }
        identities[fingerprint] = {
            "authority_origin": "FROZEN_FULL_CONVERGENCE_BASELINE",
            "raw_failure": "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT:old->new:" + path,
            "rule_id": "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT",
            "transition_new_prefix": "new",
            "transition_old_prefix": "old",
        }
    reviews = {
        "A": {"status": "GO", "p0_count": 0, "p1_count": 0, "findings": []},
        "B": {"status": "GO", "p0_count": 0, "p1_count": 0, "findings": []},
    }
    return fingerprints, bindings, identities, reviews


def run(root: Path) -> dict:
    old = _old_module(root)
    fingerprints, bindings, identities, reviews = _fixtures()
    inputs_before = copy.deepcopy((fingerprints, bindings, identities, reviews))
    old_artifacts = old._artifact_documents(fingerprints, bindings, identities, reviews)
    default_artifacts = current._artifact_documents(fingerprints, bindings, identities, reviews)
    explicit_artifacts = current._artifact_documents(
        fingerprints, bindings, identities, reviews, batch_id=current.BATCH_ID
    )
    artifact_bytes = current.canonical(old_artifacts)
    record_args = {
        "index": 1,
        "disposition": "HISTORICAL_TEST_ONLY",
        "suffix": "TEST_ONLY",
        "fingerprints": fingerprints,
        "bindings": bindings,
        "artifact_hashes": {
            "batch_inventory_sha256": "1" * 64,
            "batch_classification_sha256": "2" * 64,
            "batch_negative_checks_sha256": "3" * 64,
            "batch_review_a_sha256": "4" * 64,
            "batch_review_b_sha256": "5" * 64,
        },
        "authority_hashes": {"authority": "6" * 64},
        "head": "7" * 40,
        "tree": "8" * 40,
        "previous_chain": "9" * 64,
        "supplement_sha256": "a" * 64,
    }
    record_args_before = copy.deepcopy(record_args)
    old_record = old._record_document(**record_args)
    default_record = current._record_document(**record_args)
    explicit_record = current._record_document(
        **record_args,
        batch_id=current.BATCH_ID,
        created_at=current.CREATED_AT,
        creator="V076ReuseFullConvergenceBatch009Materializer",
    )
    record_bytes = current.canonical(old_record)
    cases = {
        "artifact_default_bytes_unchanged": artifact_bytes == current.canonical(default_artifacts),
        "artifact_explicit_default_bytes_unchanged": artifact_bytes == current.canonical(explicit_artifacts),
        "record_default_bytes_unchanged": record_bytes == current.canonical(default_record),
        "record_explicit_default_bytes_unchanged": record_bytes == current.canonical(explicit_record),
        "record_payload_sha_unchanged": old_record["record_payload_sha256"] == default_record["record_payload_sha256"] == explicit_record["record_payload_sha256"],
        "artifact_inputs_unchanged": inputs_before == (fingerprints, bindings, identities, reviews),
        "record_inputs_unchanged": record_args_before == record_args,
        "explicit_batch_id_projects_only_batch_fields": current._artifact_documents(fingerprints, bindings, identities, reviews, batch_id="batch-011")["inventory"]["batch_id"] == "batch-011",
        "explicit_creator_and_time_project_only_requested_fields": (
            current._record_document(**record_args, batch_id="batch-011", created_at="2026-09-05T00:00:00Z", creator="V076ReuseFullConvergenceBatch011Materializer")["creator"]
            == "V076ReuseFullConvergenceBatch011Materializer"
        ),
    }
    return {
        "schema_version": "space_syndicate.v076.batch009_constructor_parameterization_selftest.v1",
        "status": "PASS" if all(cases.values()) else "FAIL",
        "pass_count": sum(cases.values()),
        "case_count": len(cases),
        "cases": cases,
        "old_artifact_sha256": hashlib.sha256(artifact_bytes).hexdigest(),
        "new_artifact_sha256": hashlib.sha256(current.canonical(default_artifacts)).hexdigest(),
        "old_record_sha256": hashlib.sha256(record_bytes).hexdigest(),
        "new_record_sha256": hashlib.sha256(current.canonical(default_record)).hexdigest(),
        "repository_mutation_count": 0,
        "godot_execution_count": 0,
    }


if __name__ == "__main__":
    receipt = run(Path(__file__).resolve().parents[2])
    print(json.dumps(receipt, indent=2, sort_keys=True))
    raise SystemExit(0 if receipt["status"] == "PASS" else 1)
