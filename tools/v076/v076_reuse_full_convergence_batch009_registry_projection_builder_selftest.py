#!/usr/bin/env python3
"""Fail-closed self-test for the exact Batch-009 Registry projection builder."""

from __future__ import annotations

import copy
import json
import tempfile
from pathlib import Path

import v076_reuse_full_convergence_batch009_materializer as materializer
import v076_reuse_full_convergence_batch009_registry_projection_builder as builder


REAL_MEMBERSHIP_STAGE = Path(
    r"D:\SpaceSyndicateTemp\v076-batch009-stage-46d10dc6b94446db9dfa8b6255b21b51"
)
PASS_COUNT = 0


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def expect_error(callable_value, prefix: str) -> str:
    try:
        callable_value()
    except (
        builder.ProjectionError,
        materializer.MaterializerError,
        ValueError,
    ) as exc:
        rendered = str(exc)
        expect(rendered.startswith(prefix), f"expected {prefix}, got {rendered}")
        return rendered
    raise AssertionError(f"expected failure {prefix}")


def passed(name: str) -> None:
    global PASS_COUNT
    PASS_COUNT += 1
    print(f"PASS {PASS_COUNT:02d}: {name}")


def test_constants_and_exact_membership(root: Path, membership: dict) -> None:
    builder._validate_specs(membership)
    paths = [row[0] for row in builder.COMPONENT_SPECS]
    components = [row[1] for row in builder.COMPONENT_SPECS]
    classes = [row[2] for row in builder.COMPONENT_SPECS]
    expect(len(paths) == len(set(paths)) == 50, "path cardinality")
    expect(len(components) == len(set(components)) == 50, "component cardinality")
    expect(len(classes) == len(set(classes)) == 50, "class cardinality")
    expect(set(paths) == set(builder._membership_paths(membership).values()), "membership")
    expect(builder._classification_counts() == {
        "HISTORICAL_TEST_ONLY": 46,
        "HISTORICAL_ACTIVE_LINEAGE_REGISTERED": 3,
        "HISTORICAL_SUPERSEDED_NONREACHABLE": 1,
        "UNKNOWN": 0,
    }, "classification counts")
    expect(builder.SOURCE_COMMIT == "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3", "source")
    passed("sealed 50-path membership and exact classification counts")


def test_source_current_blob_and_declared_class_parity(
    root: Path, head: str, membership: dict
) -> None:
    rows, drift = builder._component_rows(root, head, membership)
    expect(drift == 0 and len(rows) == 50, "blob parity")
    source_commit = materializer.committed

    def drifted(project: Path, commit: str, relative):
        payload = source_commit(project, commit, relative)
        if commit == head and str(relative).replace("\\", "/") == builder.MILITARY_PATH:
            return payload + b"\n"
        return payload

    materializer.committed = drifted
    try:
        expect_error(
            lambda: builder._component_rows(root, head, membership),
            "SOURCE_CURRENT_BLOB_DRIFT:1",
        )
    finally:
        materializer.committed = source_commit
    passed("source/current blob drift and declared class parity fail closed")


def test_unknown_waiver_wildcard_and_military_false_classification(
    membership: dict,
) -> None:
    original = builder.COMPONENT_SPECS
    try:
        bad = list(original)
        bad[0] = ("scenes/ui/*",) + bad[0][1:]
        builder.COMPONENT_SPECS = tuple(bad)
        expect_error(lambda: builder._validate_specs(membership), "SPEC_PATH_SET_INVALID")

        bad = list(original)
        military_index = next(
            index for index, row in enumerate(bad) if row[0] == builder.MILITARY_PATH
        )
        military = list(bad[military_index])
        military[3] = "TEST_ONLY"
        bad[military_index] = tuple(military)
        builder.COMPONENT_SPECS = tuple(bad)
        expect_error(
            lambda: builder._validate_specs(membership),
            "SPEC_DISPOSITION_SET_INVALID",
        )

        bad = list(original)
        first = list(bad[0])
        first[1] = "component.current.unknown_accepted"
        bad[0] = tuple(first)
        builder.COMPONENT_SPECS = tuple(bad)
        expect_error(
            lambda: builder._validate_specs(membership),
            "SPEC_FORBIDDEN_CLASSIFICATION",
        )
    finally:
        builder.COMPONENT_SPECS = original
    passed("unknown, waiver/wildcard, and Military TEST_ONLY substitutions rejected")


def test_projection_semantics_and_collision_guards(
    root: Path,
    head: str,
    membership: dict,
    candidate: dict,
) -> None:
    targets = builder._decode_targets(candidate)
    before_registry = builder._strict_document(
        materializer.committed(root, head, builder.REGISTRY), "BEFORE_REGISTRY"
    )
    after_registry = builder._strict_document(
        targets[builder.REGISTRY.as_posix()], "AFTER_REGISTRY"
    )
    before_map = builder._strict_document(
        materializer.committed(root, head, builder.SUPERSESSION), "BEFORE_MAP"
    )
    after_map = builder._strict_document(
        targets[builder.SUPERSESSION.as_posix()], "AFTER_MAP"
    )
    rows = after_registry["component_inventory"][
        len(before_registry["component_inventory"]) :
    ]
    builder._validate_projection(
        before_registry, after_registry, before_map, after_map, rows, root
    )
    expect(len(rows) == 50, "direct row count")
    expect(
        [row["path"] for row in rows] == [spec[0] for spec in builder.COMPONENT_SPECS],
        "exact row order",
    )

    collision_before = copy.deepcopy(before_registry)
    collision_before["component_inventory"].append(copy.deepcopy(rows[0]))
    expect_error(
        lambda: builder._validate_component_rows(
            collision_before, after_registry, rows
        ),
        "COMPONENT_PATH_COLLISION",
    )

    reciprocal_broken = copy.deepcopy(after_registry)
    owner = builder._one(
        reciprocal_broken["component_inventory"],
        "component_id",
        builder.CURRENT_OWNER_ID,
        "OWNER",
    )
    owner["supersedes"].remove(builder.MILITARY_COMPONENT_ID)
    expect_error(
        lambda: builder._validate_projection(
            before_registry,
            reciprocal_broken,
            before_map,
            after_map,
            rows,
            root,
        ),
        "CURRENT_OWNER_MUTATION_NOT_EXACT",
    )
    passed("50 exact Registry rows, collisions, and reciprocal supersession guarded")


def test_military_stale_entry_and_supersession_contract(
    root: Path, head: str, candidate: dict
) -> None:
    targets = builder._decode_targets(candidate)
    registry = builder._strict_document(
        targets[builder.REGISTRY.as_posix()], "REGISTRY"
    )
    supersession = builder._strict_document(
        targets[builder.SUPERSESSION.as_posix()], "SUPERSESSION"
    )
    military = builder._one(
        registry["component_inventory"],
        "component_id",
        builder.MILITARY_COMPONENT_ID,
        "MILITARY",
    )
    stale = builder._one(
        registry["reuse_entries"],
        "reuse_id",
        builder.MILITARY_REUSE_ID,
        "MILITARY_REUSE",
    )
    relation = builder._one(
        supersession["entries"],
        "supersession_id",
        builder.MILITARY_SUPERSESSION_ID,
        "MILITARY_RELATION",
    )
    expect(military["component_role"] == "OWNER", "historical owner role")
    expect(military["production_reachable"] is False, "old nonreachable")
    expect(military["writes_authority"] is False, "old no write")
    expect(stale["disposition"] == "RETIRED", "stale entry retired")
    expect(relation["kind"] == builder.MILITARY_SUPERSESSION_KIND, "owner kind")
    expect(relation["cutover_commit"] == builder.CUTOVER_COMMIT, "cutover")
    expect(relation["dual_write_count"] == relation["fallback_count"] == 0, "zero")
    expect(relation["old_owner_production_reachability"] == 0, "reachability")
    expect(relation["new_owner_production_owner_count"] == 1, "new owner")
    expect(
        relation["old_source_blob_sha256"]
        == builder._source_blob(root, builder.SOURCE_COMMIT, builder.MILITARY_PATH),
        "source blob",
    )
    passed("Military stale-current claim replaced by exact Owner-to-Owner cutover")


def test_candidate_external_allowlist_and_no_authority_write(
    root: Path,
    before_hashes: dict[str, str],
    candidate: dict,
) -> None:
    expect(
        [row["path"] for row in candidate["target_files"]]
        == list(builder.OUTPUT_ALLOWLIST),
        "target allowlist",
    )
    expect(
        {row["target_path"] for row in candidate["mutation_inventory"]}
        == set(builder.OUTPUT_ALLOWLIST),
        "mutation allowlist",
    )
    expect(candidate["official_write_count"] == 0, "no official write")
    for rendered, before_hash in before_hashes.items():
        expect(
            builder.sha((root / rendered).read_bytes()) == before_hash,
            f"authority source mutated: {rendered}",
        )
    expect_error(
        lambda: builder.shared._assert_output_safe(
            root, root, root / "candidate.json"
        ),
        "STAGING_ROOT_MUST_BE_OUTSIDE_PROJECT",
    )
    passed("external stage and exact two-file output allowlist enforced")


def test_dual_review_seal_and_exact_binding(
    root: Path,
    stage: Path,
    candidate_path: Path,
    candidate: dict,
) -> tuple[Path, dict]:
    primary_path = stage / "primary-review.json"
    independent_path = stage / "independent-review.json"
    builder.build_review(root, candidate_path, "PRIMARY", primary_path)
    builder.build_review(root, candidate_path, "INDEPENDENT", independent_path)
    seal_path = stage / "seal.json"
    seal = builder.seal_candidate(
        root,
        candidate_path,
        [primary_path, independent_path],
        stage,
        seal_path,
    )
    preflight = builder.preflight_apply(root, candidate_path, seal_path)
    expect(preflight["status"] == "PASS", "preflight")
    expect(preflight["target_file_count"] == 2, "target count")
    expect(seal["review_status"] == "DUAL_REVIEW_PASS", "dual review")

    tampered = json.loads(primary_path.read_text(encoding="utf-8"))
    tampered["p1_count"] = 1
    tampered.pop("receipt_payload_sha256")
    tampered["receipt_payload_sha256"] = builder.sha(builder.canonical(tampered))
    tampered_path = stage / "tampered-review.json"
    tampered_path.write_bytes(builder.canonical(tampered))
    expect_error(
        lambda: builder._validate_review(
            root, stage, candidate, tampered_path
        ),
        "REVIEW_INVALID",
    )
    passed("dual review, seal, exact byte binding, and apply preflight verified")
    return seal_path, seal


def test_materializer_preflight_still_fails_before_apply(root: Path) -> None:
    expect_error(
        lambda: materializer.preflight(root, REAL_MEMBERSHIP_STAGE),
        "MISSING_EXACT_REGISTRY_ROWS:50",
    )
    passed("materializer remains fail-closed before the reviewed projection is applied")


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    membership = materializer.validate_membership_stage(root, REAL_MEMBERSHIP_STAGE)
    head, _tree = builder._full_head(root)
    before_hashes = {
        rendered: builder.sha((root / rendered).read_bytes())
        for rendered in builder.OUTPUT_ALLOWLIST
    }
    test_constants_and_exact_membership(root, membership)
    test_source_current_blob_and_declared_class_parity(root, head, membership)
    test_unknown_waiver_wildcard_and_military_false_classification(membership)
    with tempfile.TemporaryDirectory(prefix="v076-batch009-registry-selftest-") as temp:
        stage = Path(temp)
        candidate_path = stage / "candidate.json"
        candidate = builder.build_candidate(
            root, REAL_MEMBERSHIP_STAGE, stage, candidate_path
        )
        test_projection_semantics_and_collision_guards(
            root, head, membership, candidate
        )
        test_military_stale_entry_and_supersession_contract(root, head, candidate)
        test_candidate_external_allowlist_and_no_authority_write(
            root, before_hashes, candidate
        )
        test_dual_review_seal_and_exact_binding(
            root, stage, candidate_path, candidate
        )
    test_materializer_preflight_still_fails_before_apply(root)
    for rendered, before_hash in before_hashes.items():
        expect(
            builder.sha((root / rendered).read_bytes()) == before_hash,
            f"final source mutation: {rendered}",
        )
    print(f"RESULT: {PASS_COUNT}/{PASS_COUNT} PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
