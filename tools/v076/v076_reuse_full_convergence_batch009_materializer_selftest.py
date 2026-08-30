"""Focused self-test for the exact-only Batch-009 materializer."""

from __future__ import annotations

import json
import contextlib
import io
import os
import shutil
import tempfile
from pathlib import Path

import v076_reuse_full_convergence_batch009_materializer as materializer
import v076_reuse_full_convergence_batch_builder as membership_builder


REAL_MEMBERSHIP_STAGE = Path(
    r"D:\SpaceSyndicateTemp\v076-batch009-stage-46d10dc6b94446db9dfa8b6255b21b51"
)


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def expect_error(callable_value, prefix: str) -> str:
    try:
        callable_value()
    except materializer.MaterializerError as exc:
        rendered = str(exc)
        expect(
            rendered.startswith(prefix),
            f"expected {prefix!r}, got {rendered!r}",
        )
        return rendered
    raise AssertionError(f"expected MaterializerError starting with {prefix!r}")


def expect_builder_error(callable_value, prefix: str) -> str:
    try:
        callable_value()
    except membership_builder.BuilderError as exc:
        rendered = str(exc)
        expect(
            rendered.startswith(prefix),
            f"expected {prefix!r}, got {rendered!r}",
        )
        return rendered
    raise AssertionError(f"expected BuilderError starting with {prefix!r}")


def payload_hash(value: dict, field: str) -> None:
    payload = dict(value)
    payload.pop(field, None)
    value[field] = materializer.sha(materializer.canonical(payload))


def test_canonical_and_exact_constants() -> None:
    expect(
        materializer.canonical({"b": 1, "a": "星"})
        == b'{"a":"\xe6\x98\x9f","b":1}\n',
        "canonical JSON drifted",
    )
    expect(
        materializer.line_set(["b", "a"])
        == materializer.sha(b"a\nb\n"),
        "line-set hash drifted",
    )
    expect(materializer.BATCH_ID == "batch-009", "batch id drifted")
    expect(len(materializer.OUTPUT_ALLOWLIST) == 10, "output allowlist drifted")


def test_real_membership_stage_is_exact() -> None:
    expect(REAL_MEMBERSHIP_STAGE.is_dir(), "sealed membership stage is missing")
    result = materializer.validate_membership_stage(Path.cwd(), REAL_MEMBERSHIP_STAGE)
    candidate = result["candidate"]
    expect(candidate["failure_count"] == 50, "membership count drifted")
    expect(
        candidate["failure_fingerprint_set_sha256"]
        == materializer.SEALED_MEMBERSHIP_SET_SHA256,
        "membership set drifted",
    )
    expect(
        result["seal"]["seal_payload_sha256"]
        == materializer.SEALED_MEMBERSHIP_SEAL_PAYLOAD_SHA256,
        "membership seal drifted",
    )


def test_frozen_reconstruction_uses_committed_blobs_only() -> None:
    result = materializer.validate_membership_stage(Path.cwd(), REAL_MEMBERSHIP_STAGE)
    candidate = result["candidate"]
    plan = membership_builder.derive_plan_from_committed_head(
        Path.cwd(), materializer.SEALED_MEMBERSHIP_HEAD_SHA
    )
    expect(plan["plan_sha256"] == candidate["plan_sha256"], "frozen plan drifted")
    rows = membership_builder.expected_membership_rows_from_committed_head(
        Path.cwd(),
        materializer.SEALED_MEMBERSHIP_HEAD_SHA,
        list(candidate["failure_fingerprints"]),
    )
    expect(rows == candidate["rows"], "frozen membership rows drifted")


def test_frozen_blob_tamper_and_missing_are_fail_closed() -> None:
    original = membership_builder._committed_bytes

    def tamper(root, head, relative):
        payload = original(root, head, relative)
        if relative == membership_builder.SCANNER:
            return payload + b"\n"
        return payload

    membership_builder._committed_bytes = tamper
    try:
        try:
            materializer.validate_membership_stage(Path.cwd(), REAL_MEMBERSHIP_STAGE)
        except materializer.MaterializerError as exc:
            expect(
                str(exc)
                in {
                    "MEMBERSHIP_FROZEN_PARITY_INVALID:plan_sha256",
                    "MEMBERSHIP_FROZEN_PARITY_INVALID:authority_inputs",
                },
                f"unexpected tamper error: {exc}",
            )
        else:
            raise AssertionError("tampered frozen blob was accepted")
    finally:
        membership_builder._committed_bytes = original

    def missing(root, head, relative):
        if relative == membership_builder.SCANNER:
            raise membership_builder.BuilderError(
                "AUTHORITY_NOT_COMMITTED:tools/v076/v076_reuse_point_inertia_gate.py"
            )
        return original(root, head, relative)

    membership_builder._committed_bytes = missing
    try:
        expect_error(
            lambda: materializer.validate_membership_stage(
                Path.cwd(), REAL_MEMBERSHIP_STAGE
            ),
            "MEMBERSHIP_FROZEN_RECONSTRUCTION_FAILED:AUTHORITY_NOT_COMMITTED:",
        )
    finally:
        membership_builder._committed_bytes = original


def test_builder_error_is_structured_at_materializer_boundary() -> None:
    original = membership_builder.derive_plan_from_committed_head

    def fail(root, head):
        raise membership_builder.BuilderError("SYNTHETIC_FROZEN_READ_FAILURE")

    membership_builder.derive_plan_from_committed_head = fail
    output = io.StringIO()
    try:
        with contextlib.redirect_stdout(output):
            code = materializer.main(
                [
                    "--root",
                    str(Path.cwd()),
                    "preflight",
                    "--membership-stage",
                    str(REAL_MEMBERSHIP_STAGE),
                ]
            )
    finally:
        membership_builder.derive_plan_from_committed_head = original
    expect(code == 2, "BuilderError boundary returned unexpected code")
    lines = output.getvalue().splitlines()
    expect(len(lines) == 1, "BuilderError boundary emitted traceback or extra output")
    payload = json.loads(lines[0])
    expect(payload["status"] == "FAIL", "structured failure status drifted")
    expect(
        payload["error"]
        == "MEMBERSHIP_FROZEN_RECONSTRUCTION_FAILED:SYNTHETIC_FROZEN_READ_FAILURE",
        "structured failure error drifted",
    )
    expect(payload["official_batch_write_count"] == 0, "official batch write drifted")
    expect(payload["official_record_write_count"] == 0, "official record write drifted")


def test_frozen_api_rejects_symbolic_or_invalid_refs() -> None:
    root = Path.cwd()
    for value in ("HEAD", "main", "D1F48B52966D50627126F7E0E1ACC B6011BEC1DE".replace(" ", ""), "0" * 40):
        expect_builder_error(
            lambda value=value: membership_builder.derive_plan_from_committed_head(
                root, value
            ),
            "FROZEN_HEAD_",
        )


def test_current_head_fails_closed_on_all_fifty_registry_rows() -> None:
    registry_path = Path.cwd() / materializer.REGISTRY_REL
    before = registry_path.read_bytes()
    error = expect_error(
        lambda: materializer.preflight(Path.cwd(), REAL_MEMBERSHIP_STAGE),
        "MISSING_EXACT_REGISTRY_ROWS:50:",
    )
    missing = error.split(":", 2)[2].split("|")
    expect(len(missing) == 50, f"missing path diagnostic drifted: {len(missing)}")
    expect(missing == sorted(missing), "missing path diagnostic is not sorted")
    expect(len(set(missing)) == 50, "missing path diagnostic contains duplicates")
    expect(registry_path.read_bytes() == before, "preflight mutated Registry")


def test_materialize_checks_registry_before_proposal_or_output() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-b9-materialize-negative-") as temp:
        base = Path(temp)
        output = base / "never-created"
        error = expect_error(
            lambda: materializer.materialize(
                Path.cwd(),
                REAL_MEMBERSHIP_STAGE,
                base / "missing-proposal.json",
                base / "missing-review-a.json",
                base / "missing-review-b.json",
                output,
            ),
            "MISSING_EXACT_REGISTRY_ROWS:50:",
        )
        expect("scripts/runtime/runtime_loop.gd" in error, "exact blocker lost a path")
        expect(not output.exists(), "fail-closed materialize created an output stage")


def test_membership_tamper_and_file_alias_rejected() -> None:
    with tempfile.TemporaryDirectory(prefix="v076-b9-membership-tamper-") as temp:
        stage = Path(temp) / "stage"
        stage.mkdir()
        for source in REAL_MEMBERSHIP_STAGE.iterdir():
            shutil.copyfile(source, stage / source.name)
        candidate_path = stage / "candidate.json"
        candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
        candidate["failure_count"] = 49
        candidate_path.write_bytes(materializer.canonical(candidate))
        expect_error(
            lambda: materializer.validate_membership_stage(Path.cwd(), stage),
            "MEMBERSHIP_CANDIDATE_CONTRACT_INVALID",
        )

    with tempfile.TemporaryDirectory(prefix="v076-b9-hardlink-") as temp:
        base = Path(temp)
        first = base / "first.json"
        alias = base / "alias.json"
        first.write_bytes(b"{}\n")
        try:
            os.link(first, alias)
        except OSError:
            return
        expect_error(
            lambda: materializer._require_plain_external_file(
                Path.cwd(), first, label="HARDLINK_TEST"
            ),
            "HARDLINK_TEST_HARDLINK_FORBIDDEN",
        )


def test_registry_missing_duplicate_and_collision_guards() -> None:
    paths = {"fp-a": "scripts/a.gd", "fp-b": "scripts/b.gd"}
    missing_registry = {"component_inventory": []}
    expect_error(
        lambda: materializer._registry_exact_rows(missing_registry, paths),
        "MISSING_EXACT_REGISTRY_ROWS:2:scripts/a.gd|scripts/b.gd",
    )
    duplicate_registry = {
        "component_inventory": [
            {"path": "scripts/a.gd", "component_id": "a1", "class_name": "A1"},
            {"path": "scripts/a.gd", "component_id": "a2", "class_name": "A2"},
            {"path": "scripts/b.gd", "component_id": "b", "class_name": "B"},
        ]
    }
    expect_error(
        lambda: materializer._registry_exact_rows(duplicate_registry, paths),
        "DUPLICATE_EXACT_REGISTRY_ROWS:1:scripts/a.gd",
    )
    component_collision = {
        "component_inventory": [
            {"path": "scripts/a.gd", "component_id": "same", "class_name": "A"},
            {"path": "scripts/b.gd", "component_id": "same", "class_name": "B"},
        ]
    }
    expect_error(
        lambda: materializer._registry_exact_rows(component_collision, paths),
        "BATCH009_COMPONENT_ID_SET_NOT_UNIQUE",
    )
    class_collision = {
        "component_inventory": [
            {"path": "scripts/a.gd", "component_id": "a", "class_name": "Same"},
            {"path": "scripts/b.gd", "component_id": "b", "class_name": "Same"},
        ]
    }
    expect_error(
        lambda: materializer._registry_exact_rows(class_collision, paths),
        "BATCH009_CLASS_NAME_SET_NOT_UNIQUE",
    )


def test_exact_source_identity_extraction() -> None:
    root = Path.cwd()
    source = "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3"
    military = materializer.source_identity(
        root, source, "scripts/runtime/military_runtime_controller.gd"
    )
    expect(military["identity_kind"] == "GDSCRIPT", "script identity kind drifted")
    expect(
        military["declared_class_name"] == "MilitaryRuntimeController",
        "script class identity drifted",
    )
    anonymous = materializer.source_identity(
        root, source, "scripts/balance/runtime_balance_model.gd"
    )
    expect(anonymous["declared_class_name"] == "", "anonymous script invented a class")
    expect(anonymous["extends_type"] == "RefCounted", "anonymous extends drifted")
    scene = materializer.source_identity(root, source, "scenes/CardUI.tscn")
    expect(scene["root_node_name"] == "CardUI", "scene root name drifted")
    expect(scene["root_node_type"] == "Control", "scene root type drifted")
    expect(scene["script_path"] == "scripts/CardUI.gd", "scene script link drifted")
    resource = materializer.source_identity(
        root, source, "resources/weather/gravity_tide.tres"
    )
    expect(resource["resource_type"] == "Resource", "resource type drifted")
    expect(
        resource["resource_script_class"] == "WeatherDefinition",
        "resource script class drifted",
    )
    expect(
        resource["script_path"] == "scripts/runtime/weather_definition.gd",
        "resource script path drifted",
    )


def test_source_commit_option_injection_rejected_before_git() -> None:
    root = Path.cwd()
    marker = root / "source-commit-option-injection-marker"
    expect(not marker.exists(), "source-commit marker pre-exists")
    original_run = materializer.subprocess.run
    calls = []

    def forbidden_run(*args, **kwargs):
        calls.append((args, kwargs))
        raise AssertionError("Git/process spawn occurred before commit validation")

    materializer.subprocess.run = forbidden_run
    try:
        expect_error(
            lambda: materializer.source_identity(
                root,
                f"--output={marker.as_posix()}",
                "scripts/runtime/runtime_loop.gd",
            ),
            "SOURCE_IDENTITY_COMMIT_INVALID",
        )
        expect_error(
            lambda: materializer.committed(
                root,
                "--output=outside-marker",
                "scripts/runtime/runtime_loop.gd",
            ),
            "COMMITTED_OBJECT_COMMIT_INVALID",
        )
    finally:
        materializer.subprocess.run = original_run
    expect(calls == [], "malicious source commit reached a process spawn")
    expect(not marker.exists(), "malicious source commit created a project file")


def test_membership_and_output_stages_must_be_bidirectionally_disjoint() -> None:
    root = Path.cwd()
    nested_output = REAL_MEMBERSHIP_STAGE / "forbidden-output-child"
    expect(not nested_output.exists(), "nested output test path pre-exists")
    expect_error(
        lambda: materializer._require_disjoint_stages(
            root, REAL_MEMBERSHIP_STAGE, nested_output
        ),
        "OUTPUT_MEMBERSHIP_STAGE_INTERSECTION_FORBIDDEN",
    )
    expect_error(
        lambda: materializer._require_disjoint_stages(
            root, REAL_MEMBERSHIP_STAGE, REAL_MEMBERSHIP_STAGE.parent
        ),
        "OUTPUT_MEMBERSHIP_STAGE_INTERSECTION_FORBIDDEN",
    )
    expect_error(
        lambda: materializer._require_disjoint_stages(
            root, REAL_MEMBERSHIP_STAGE, REAL_MEMBERSHIP_STAGE
        ),
        "OUTPUT_MEMBERSHIP_STAGE_INTERSECTION_FORBIDDEN",
    )
    expect_error(
        lambda: materializer.materialize(
            root,
            REAL_MEMBERSHIP_STAGE,
            REAL_MEMBERSHIP_STAGE.parent / "missing-proposal.json",
            REAL_MEMBERSHIP_STAGE.parent / "missing-review-a.json",
            REAL_MEMBERSHIP_STAGE.parent / "missing-review-b.json",
            nested_output,
        ),
        "OUTPUT_MEMBERSHIP_STAGE_INTERSECTION_FORBIDDEN",
    )
    expect(not nested_output.exists(), "intersection rejection created output")


def make_proposal_stub() -> dict:
    head = materializer.git(Path.cwd(), "rev-parse", "HEAD^{commit}")
    tree = materializer.git(Path.cwd(), "rev-parse", f"{head}^{{tree}}")
    value = {
        "schema_version": materializer.PROPOSAL_SCHEMA,
        "candidate_kind": materializer.PROPOSAL_KIND,
        "batch_id": materializer.BATCH_ID,
        "membership_candidate_payload_sha256": materializer.SEALED_MEMBERSHIP_CANDIDATE_PAYLOAD_SHA256,
        "membership_seal_payload_sha256": materializer.SEALED_MEMBERSHIP_SEAL_PAYLOAD_SHA256,
        "evaluated_head_sha": head,
        "evaluated_tree_sha": tree,
        "authority_source_sha256": {},
        "failure_count": 50,
        "failure_fingerprints": [],
        "failure_fingerprint_set_sha256": materializer.SEALED_MEMBERSHIP_SET_SHA256,
        "rows": {},
        "required_review_ids": ["A", "B"],
        "review_status": "PENDING",
        "go_claim": False,
        "official_batch_write_count": 0,
        "official_record_write_count": 0,
    }
    payload_hash(value, "proposal_payload_sha256")
    return value


def make_review(proposal: dict, review_id: str) -> dict:
    value = {
        "schema_version": materializer.PROPOSAL_REVIEW_SCHEMA,
        "batch_id": materializer.BATCH_ID,
        "proposal_payload_sha256": proposal["proposal_payload_sha256"],
        "evaluated_head_sha": proposal["evaluated_head_sha"],
        "evaluated_tree_sha": proposal["evaluated_tree_sha"],
        "failure_fingerprint_set_sha256": materializer.SEALED_MEMBERSHIP_SET_SHA256,
        "review_id": review_id,
        "reviewer_authority_id": materializer.TRUSTED_PROPOSAL_REVIEWERS[review_id],
        "findings": [],
        "p0_count": 0,
        "p1_count": 0,
        "status": "GO",
    }
    payload_hash(value, "receipt_payload_sha256")
    return value


def test_proposal_review_exact_byte_binding() -> None:
    proposal = make_proposal_stub()
    with tempfile.TemporaryDirectory(prefix="v076-b9-proposal-review-") as temp:
        path = Path(temp) / "review-a.json"
        review = make_review(proposal, "A")
        path.write_bytes(materializer.canonical(review))
        validated, resolved, digest = materializer._validate_proposal_review(
            Path.cwd(), path, proposal, label="TEST_REVIEW"
        )
        expect(validated == review, "proposal review changed during validation")
        expect(resolved == path.resolve(), "proposal review path drifted")
        expect(digest == materializer.sha(path.read_bytes()), "review hash drifted")
        review["proposal_payload_sha256"] = "0" * 64
        payload_hash(review, "receipt_payload_sha256")
        path.write_bytes(materializer.canonical(review))
        expect_error(
            lambda: materializer._validate_proposal_review(
                Path.cwd(), path, proposal, label="TEST_REVIEW"
            ),
            "TEST_REVIEW_INVALID",
        )


def test_projection_registry_canonical_normalization() -> None:
    projection = {
        "registry_rows": [
            {
                "authority_source_kind": "component_inventory",
                "component_id": "b",
                "path": "scripts/b.gd",
            },
            {
                "authority_source_kind": "component_inventory",
                "component_id": "a",
                "path": "scripts/a.gd",
            },
        ]
    }
    normalized = materializer._canonical_registry_rows(projection)
    expect(
        normalized
        == [
            {"component_id": "a", "path": "scripts/a.gd"},
            {"component_id": "b", "path": "scripts/b.gd"},
        ],
        "Registry projection canonical normalization drifted",
    )


def test_zero_superseded_partition_is_valid_and_exact() -> None:
    fingerprints = [f"V2F-{'%064x' % index}" for index in range(50)]
    bindings = {
        fingerprint: {
            "recommended_disposition": (
                "HISTORICAL_ACTIVE_LINEAGE_REGISTERED"
                if index < 2
                else "HISTORICAL_TEST_ONLY"
            )
        }
        for index, fingerprint in enumerate(fingerprints)
    }
    groups = materializer._partition_supported_dispositions(
        fingerprints, bindings
    )
    expect(
        len(groups["HISTORICAL_ACTIVE_LINEAGE_REGISTERED"]) == 2,
        "active disposition count drifted",
    )
    expect(
        len(groups["HISTORICAL_TEST_ONLY"]) == 48,
        "test-only disposition count drifted",
    )
    expect(
        groups["HISTORICAL_SUPERSEDED_NONREACHABLE"] == [],
        "zero superseded classification was not preserved",
    )
    expect(sum(len(values) for values in groups.values()) == 50, "total drifted")

    bad = dict(bindings)
    bad[fingerprints[-1]] = {"recommended_disposition": "HISTORICAL_RETIRED_NONREACHABLE"}
    expect_error(
        lambda: materializer._partition_supported_dispositions(fingerprints, bad),
        f"BATCH009_UNSUPPORTED_DISPOSITION:{fingerprints[-1]}:",
    )
    missing = dict(bindings)
    missing.pop(fingerprints[-1])
    expect_error(
        lambda: materializer._partition_supported_dispositions(fingerprints, missing),
        "BATCH009_DISPOSITION_COVERAGE_INVALID",
    )


def test_external_ten_file_allowlist_and_append_only() -> None:
    documents = {
        relative: {"relative": relative}
        for relative in materializer.OUTPUT_ALLOWLIST
    }
    fingerprints = [f"V2F-{'%064x' % index}" for index in range(50)]
    documents["batch-009/batch_classification.json"] = {
        "classifications": {
            fingerprint: {
                "recommended_disposition": (
                    "HISTORICAL_ACTIVE_LINEAGE_REGISTERED"
                    if index == 0
                    else "HISTORICAL_SUPERSEDED_NONREACHABLE"
                    if index == 1
                    else "HISTORICAL_TEST_ONLY"
                )
            }
            for index, fingerprint in enumerate(fingerprints)
        }
    }
    with tempfile.TemporaryDirectory(prefix="v076-b9-output-") as temp:
        stage = Path(temp) / "stage"
        result = materializer.write_stage(Path.cwd(), stage, documents)
        files = sorted(
            item.relative_to(result).as_posix()
            for item in result.rglob("*")
            if item.is_file()
        )
        expect(set(files) == materializer.OUTPUT_ALLOWLIST, "output file set drifted")
        expect(len(files) == 10, "output file count drifted")
        expect_error(
            lambda: materializer.write_stage(Path.cwd(), stage, documents),
            "OUTPUT_STAGE_MUST_BE_FRESH_NONEXISTENT",
        )
        narrowed = dict(documents)
        narrowed.pop("batch-009/batch-009-manifest.json")
        expect_error(
            lambda: materializer.write_stage(
                Path.cwd(), Path(temp) / "narrowed", narrowed
            ),
            "OUTPUT_DOCUMENT_BASE_SET_MISMATCH",
        )

        without_superseded = dict(documents)
        without_superseded.pop(
            materializer.RECORD_OUTPUT_BY_DISPOSITION[
                "HISTORICAL_SUPERSEDED_NONREACHABLE"
            ]
        )
        without_superseded["batch-009/batch_classification.json"] = {
            "classifications": {
                fingerprint: {
                    "recommended_disposition": (
                        "HISTORICAL_ACTIVE_LINEAGE_REGISTERED"
                        if index < 2
                        else "HISTORICAL_TEST_ONLY"
                    )
                }
                for index, fingerprint in enumerate(fingerprints)
            }
        }
        two_group_stage = materializer.write_stage(
            Path.cwd(), Path(temp) / "two-groups", without_superseded
        )
        two_group_files = {
            item.relative_to(two_group_stage).as_posix()
            for item in two_group_stage.rglob("*")
            if item.is_file()
        }
        expect(len(two_group_files) == 9, "two-group output count drifted")
        expect(
            materializer.RECORD_OUTPUT_BY_DISPOSITION[
                "HISTORICAL_SUPERSEDED_NONREACHABLE"
            ]
            not in two_group_files,
            "empty superseded record was fabricated",
        )


def test_no_registry_or_official_evidence_writes() -> None:
    root = Path.cwd()
    status = materializer.git(root, "status", "--short")
    changed = {
        line[3:].replace("\\", "/")
        for line in status.splitlines()
        if len(line) > 3
    }
    forbidden = {
        materializer.REGISTRY_REL.as_posix(),
        materializer.SUPERSESSION_REL.as_posix(),
    }
    expect(not (changed & forbidden), f"authority file changed: {changed & forbidden}")
    expect(
        not any(
            path.startswith(materializer.BATCH_ROOT.as_posix() + "/batch-009/")
            or path.startswith(materializer.RECORD_ROOT.as_posix() + "/batch-009/")
            for path in changed
        ),
        "official Batch-009 evidence was written",
    )


def main() -> int:
    tests = [
        test_canonical_and_exact_constants,
        test_real_membership_stage_is_exact,
        test_frozen_reconstruction_uses_committed_blobs_only,
        test_frozen_blob_tamper_and_missing_are_fail_closed,
        test_builder_error_is_structured_at_materializer_boundary,
        test_frozen_api_rejects_symbolic_or_invalid_refs,
        test_current_head_fails_closed_on_all_fifty_registry_rows,
        test_materialize_checks_registry_before_proposal_or_output,
        test_membership_tamper_and_file_alias_rejected,
        test_registry_missing_duplicate_and_collision_guards,
        test_exact_source_identity_extraction,
        test_source_commit_option_injection_rejected_before_git,
        test_membership_and_output_stages_must_be_bidirectionally_disjoint,
        test_proposal_review_exact_byte_binding,
        test_projection_registry_canonical_normalization,
        test_zero_superseded_partition_is_valid_and_exact,
        test_external_ten_file_allowlist_and_append_only,
        test_no_registry_or_official_evidence_writes,
    ]
    for test in tests:
        test()
    print(
        "V076_BATCH009_MATERIALIZER_SELFTEST_PASS "
        f"cases={len(tests)} current_head_gate=MISSING_EXACT_REGISTRY_ROWS:50 "
        "registry_write_count=0 official_evidence_write_count=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
