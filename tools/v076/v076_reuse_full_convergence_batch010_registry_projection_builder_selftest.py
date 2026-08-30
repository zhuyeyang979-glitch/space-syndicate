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
        try:
            builder.build_candidate(root, stage)
        except ValueError as exc:
            expect(str(exc) == "REGISTRY_PATH_COLLISION", "applied Registry was not fail-closed")
        else:
            raise AssertionError("projection unexpectedly rebuilt after Registry apply")
        expect(not stage.exists(), "failed projection left a stage")
        expect((root / builder.REGISTRY_REL).read_bytes() == registry_before, "registry mutated")
        expect((root / builder.SUPERSESSION_REL).read_bytes() == map_before, "map mutated")


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
    print("V076_BATCH010_REGISTRY_PROJECTION_BUILDER_SELFTEST_PASS cases=3 applied_state=REGISTRY_PATH_COLLISION rows=50 official_registry_write_count=0 official_map_write_count=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
