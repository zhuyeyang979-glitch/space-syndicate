#!/usr/bin/env python3
"""Self-test for the non-authoritative Batch-010 projection candidate."""

from __future__ import annotations

import base64
import json
import tempfile
from pathlib import Path

import v076_reuse_full_convergence_batch010_materializer as materializer
import v076_reuse_full_convergence_batch010_registry_projection_builder as builder


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def test_frozen_membership_is_exact(root: Path) -> None:
    result = materializer.validate_frozen_membership(root)
    candidate = result["candidate"]
    expect(candidate["batch_id"] == "batch-010", "batch id drift")
    expect(candidate["failure_count"] == 50, "membership count drift")
    expect(
        candidate["failure_fingerprint_set_sha256"]
        == "121ee606175934acfebcb7bf729b9c49ad469ead0ca2e58afacc41163ff7ba69",
        "membership set drift",
    )
    expect(
        len(builder.materializer.FROZEN_MEMBERSHIP_SPECS) == 50,
        "frozen tuple cardinality drift",
    )


def test_candidate_is_external_and_append_only(root: Path) -> None:
    registry_before = (root / builder.REGISTRY_REL).read_bytes()
    map_before = (root / builder.SUPERSESSION_REL).read_bytes()
    with tempfile.TemporaryDirectory(prefix="v076-batch010-projection-") as temp:
        stage = Path(temp) / "candidate-stage"
        result = builder.build_candidate(root, stage)
        path = stage / builder.OUTPUT_NAME
        expect(path.is_file(), "candidate was not written")
        payload = path.read_bytes()
        candidate = json.loads(payload.decode("utf-8"))
        expect(payload == builder.canonical(candidate), "candidate not canonical")
        expect(candidate["batch_id"] == "batch-010", "candidate batch drift")
        expect(candidate["failure_count"] == 50, "candidate count drift")
        expect(candidate["official_registry_write_count"] == 0, "registry write claim")
        expect(candidate["official_map_write_count"] == 0, "map write claim")
        expect(len(candidate["rows"]) == 50, "candidate row count drift")
        rows = candidate["rows"]
        expect(len({row["path"] for row in rows}) == 50, "path collision")
        expect(len({row["component_id"] for row in rows}) == 50, "component collision")
        expect(sum(row["component_role"] == "DOCUMENTATION_ONLY" for row in rows) == 2, "documentation split drift")
        expect(sum(row["production_reachable"] is True for row in rows) == 1, "active split drift")
        expect(candidate["classification_counts"] == {
            "HISTORICAL_ACTIVE_LINEAGE_REGISTERED": 1,
            "HISTORICAL_DOCUMENTATION_ONLY": 2,
            "HISTORICAL_TEST_ONLY": 48,
            "UNKNOWN": 0,
        }, "classification counts drift")
        target = base64.b64decode(candidate["target_registry"]["target_bytes_base64"], validate=True)
        target_doc = json.loads(target.decode("utf-8"))
        before_doc = json.loads(registry_before.decode("utf-8"))
        inventory = target_doc["component_inventory"]
        prior = before_doc["component_inventory"]
        expect(inventory[: len(prior)] == prior, "preexisting registry rows mutated")
        appended = inventory[len(prior):]
        allowed = {
            "component_id", "class_name", "path",
            "domain_id", "component_role", "production_reachable",
            "writes_authority", "reads_authority", "owns_rng", "owns_tick",
            "owns_save", "owns_replay", "owns_identity", "owns_presentation",
            "owner_component_id", "owner_path", "reuse_disposition",
            "reuse_source_ids", "reuse_candidates_considered",
            "new_component_justification", "supersedes", "superseded_by",
            "change_class", "focused_test_ids", "golden_scenario_steps",
        }
        expect(len(appended) == 50, "registry target append count drift")
        expect(all(set(row) == allowed for row in appended), "registry row schema drift")
        expect(candidate["target_registry"]["target_bytes_sha256"] == builder.sha(target), "target hash drift")
        expect(candidate["mutation_inventory"] and len(candidate["mutation_inventory"]) == 1, "mutation inventory drift")
        expect(not (stage / "V076_SUPERSESSION_MAP.json").exists(), "map write leaked into stage")
        expect((root / builder.REGISTRY_REL).read_bytes() == registry_before, "registry mutated")
        expect((root / builder.SUPERSESSION_REL).read_bytes() == map_before, "map mutated")
        try:
            builder.build_candidate(root, stage)
        except ValueError as exc:
            expect(str(exc) == "OUTPUT_STAGE_MUST_BE_FRESH_NONEXISTENT", "repeat stage was not rejected")
        else:
            raise AssertionError("repeat stage unexpectedly succeeded")


def test_source_transition_partition_is_exact() -> None:
    specs = builder.materializer.FROZEN_MEMBERSHIP_SPECS
    transitions = {(old, new) for _fp, _path, old, new in specs}
    expect(transitions == {
        ("46b33bba77b3", "e584cd4d8b0c"),
        ("d701a81dce69", "0d2a2b798f32"),
        ("8208001e7be8", "62ceba063d68"),
    }, "transition partition drift")
    expect(sum(old == "46b33bba77b3" for _fp, _p, old, _n in specs) == 48, "primary transition count drift")
    expect(sum(old == "d701a81dce69" for _fp, _p, old, _n in specs) == 1, "mechanic documentation count drift")
    expect(sum(old == "8208001e7be8" for _fp, _p, old, _n in specs) == 1, "rulebook documentation count drift")


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    test_frozen_membership_is_exact(root)
    test_candidate_is_external_and_append_only(root)
    test_source_transition_partition_is_exact()
    print("V076_BATCH010_REGISTRY_PROJECTION_BUILDER_SELFTEST_PASS cases=3 rows=50 official_registry_write_count=0 official_map_write_count=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
