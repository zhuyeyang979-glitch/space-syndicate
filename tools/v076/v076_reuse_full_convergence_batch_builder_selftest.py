"""Focused self-test for the append-only full-convergence batch planner."""

from __future__ import annotations

import json
import tempfile
from pathlib import Path

import v076_reuse_full_convergence_batch_builder as builder


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    cases: list[dict[str, str]] = []

    def run(name: str, fn) -> None:
        try:
            fn(); cases.append({"name": name, "status": "PASS"})
        except Exception as exc:
            cases.append({"name": name, "status": "FAIL", "failure": f"{type(exc).__name__}: {exc}"})

    plan_holder: dict[str, object] = {}

    def plan_case() -> None:
        first = builder.derive_plan(root)
        second = builder.derive_plan(root)
        expect(builder.canonical(first) == builder.canonical(second), "plan is not byte deterministic")
        expect(first["primary_authority_count"] == 501, str(first))
        expect(first["legacy_count"] == 12, str(first))
        expect(first["frozen_batch_001_007_count"] == 239, str(first))
        expect(first["remaining_count"] == 250, str(first))
        expect(first["component_remaining_count"] == 239, str(first))
        expect(first["dynamic_remaining_count"] == 11, str(first))
        expect([first["batches"][f"batch-{n:03d}"]["failure_count"] for n in range(8, 14)] == [50, 50, 50, 50, 39, 11], str(first))
        expect(first["batches"]["batch-013"]["terminal_remainder_batch"] is True, str(first))
        plan_holder["plan"] = first

    run("frozen 501-12-239 partition yields exact 250 plan", plan_case)

    def transition_case() -> None:
        plan = plan_holder["plan"]
        expected = {
            "batch-008": {"46b33bba77b3->e584cd4d8b0c": 50},
            "batch-009": {"46b33bba77b3->e584cd4d8b0c": 50},
            "batch-010": {"46b33bba77b3->e584cd4d8b0c": 48, "8208001e7be8->62ceba063d68": 1, "d701a81dce69->0d2a2b798f32": 1},
            "batch-011": {"46b33bba77b3->e584cd4d8b0c": 50},
            "batch-012": {"46b33bba77b3->e584cd4d8b0c": 39},
            "batch-013": {"46b33bba77b3->e584cd4d8b0c": 7, "8208001e7be8->62ceba063d68": 4},
        }
        for batch_id, counts in expected.items():
            expect(plan["batches"][batch_id]["transition_counts"] == counts, batch_id)

    run("transition partitions are exact and multi-transition aware", transition_case)

    with tempfile.TemporaryDirectory(prefix="v076-builder-selftest-") as temp_name:
        temp = Path(temp_name)

        def candidate_case() -> None:
            path = temp / "candidate.json"
            candidate = builder.build_candidate(root, "batch-008", temp, path)
            expect(path.is_file(), "candidate missing")
            expect(candidate["go_claim"] is False, str(candidate))
            expect(candidate["review_status"] == "PENDING", str(candidate))
            expect(candidate["official_batch_write_count"] == 0, str(candidate))
            try:
                builder.build_candidate(root, "batch-008", temp, path)
            except builder.BuilderError as exc:
                expect(str(exc) == "APPEND_ONLY_OUTPUT_ALREADY_EXISTS", str(exc))
            else:
                raise AssertionError("append-only overwrite was accepted")

        run("candidate is non-authoritative and append-only", candidate_case)

        def forbidden_case() -> None:
            forbidden = root / builder.BATCH_ROOT / "batch-008" / "candidate.json"
            try:
                builder._assert_output_safe(root, temp, forbidden)
            except builder.BuilderError as exc:
                expect(str(exc) == "OUTPUT_OUTSIDE_EXPLICIT_STAGING_ROOT", str(exc))
            else:
                raise AssertionError("authority-root candidate output accepted")
            try:
                builder._assert_output_safe(root, root / ".candidate-stage", root / ".candidate-stage" / "x.json")
            except builder.BuilderError as exc:
                expect(str(exc) == "STAGING_ROOT_MUST_BE_OUTSIDE_PROJECT", str(exc))
            else:
                raise AssertionError("project-local staging root accepted")

        run("candidate requires explicit external staging root", forbidden_case)

        def review_case() -> None:
            candidate_path = temp / "review-candidate.json"
            candidate = builder.build_candidate(root, "batch-008", temp, candidate_path)
            receipts = []
            for review_id in ("PRIMARY", "INDEPENDENT"):
                path = temp / f"{review_id}.json"
                review = {
                    "schema_version": builder.REVIEW_SCHEMA,
                    "review_id": review_id,
                    "reviewer_authority_id": builder.TRUSTED_REVIEWER_AUTHORITIES[review_id],
                    "candidate_payload_sha256": candidate["candidate_payload_sha256"],
                    "batch_id": "batch-008",
                    "evaluated_head_sha": candidate["evaluated_head_sha"],
                    "plan_sha256": candidate["plan_sha256"],
                    "failure_fingerprint_set_sha256": candidate["failure_fingerprint_set_sha256"],
                    "status": "GO",
                    "p0_count": 0,
                    "p1_count": 0,
                    "findings": [],
                }
                review["receipt_payload_sha256"] = builder.sha(builder.canonical(review))
                path.write_bytes(builder.canonical(review))
                receipts.append(path)
            seal_path = temp / "seal.json"
            result = builder.seal_candidate(root, candidate_path, receipts, temp, seal_path)
            expect(result["review_status"] == "DUAL_REVIEW_PASS", str(result))
            expect(result["official_batch_write_count"] == 0, str(result))
            bad = temp / "bad.json"
            bad.write_bytes(receipts[0].read_bytes())
            try:
                builder.seal_candidate(root, candidate_path, [receipts[0], bad], temp, temp / "bad-seal.json")
            except builder.BuilderError as exc:
                expect(str(exc) == "REVIEWER_SET_INVALID", str(exc))
            else:
                raise AssertionError("duplicate reviewer set accepted")
            bool_receipt = temp / "bool-count.json"
            bad_review = json.loads(receipts[1].read_text(encoding="utf-8"))
            bad_review["p0_count"] = False
            bad_review.pop("receipt_payload_sha256")
            bad_review["receipt_payload_sha256"] = builder.sha(builder.canonical(bad_review))
            bool_receipt.write_bytes(builder.canonical(bad_review))
            try:
                builder.seal_candidate(root, candidate_path, [receipts[0], bool_receipt], temp, temp / "bool-seal.json")
            except builder.BuilderError as exc:
                expect(str(exc).startswith("REVIEW_NOT_ACCEPTABLE:"), str(exc))
            else:
                raise AssertionError("boolean review count accepted as exact integer")
            wrong_authority = temp / "wrong-authority.json"
            bad_review = json.loads(receipts[1].read_text(encoding="utf-8"))
            bad_review["reviewer_authority_id"] = builder.TRUSTED_REVIEWER_AUTHORITIES["PRIMARY"]
            bad_review.pop("receipt_payload_sha256")
            bad_review["receipt_payload_sha256"] = builder.sha(builder.canonical(bad_review))
            wrong_authority.write_bytes(builder.canonical(bad_review))
            try:
                builder.seal_candidate(root, candidate_path, [receipts[0], wrong_authority], temp, temp / "authority-seal.json")
            except builder.BuilderError as exc:
                expect(str(exc).startswith("REVIEW_NOT_ACCEPTABLE:"), str(exc))
            else:
                raise AssertionError("cross-wired reviewer authority accepted")
            extra_field_candidate = temp / "extra-field-candidate.json"
            bad_candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
            bad_candidate["unexpected"] = "field"
            bad_candidate.pop("candidate_payload_sha256")
            bad_candidate["candidate_payload_sha256"] = builder.sha(builder.canonical(bad_candidate))
            extra_field_candidate.write_bytes(builder.canonical(bad_candidate))
            try:
                builder.seal_candidate(root, extra_field_candidate, receipts, temp, temp / "extra-field-seal.json")
            except builder.BuilderError as exc:
                expect(str(exc) == "CANDIDATE_CONTRACT_INVALID", str(exc))
            else:
                raise AssertionError("candidate with an unknown field was accepted")

        run("seal requires two distinct exact candidate-bound reviews", review_case)

    passed = sum(row["status"] == "PASS" for row in cases)
    report = {
        "schema_version": "space_syndicate.v076.reuse_full_convergence.batch_builder_selftest.v1",
        "status": "PASS" if passed == len(cases) else "FAIL",
        "case_count": len(cases),
        "pass_count": passed,
        "cases": cases,
    }
    print(json.dumps(report, sort_keys=True))
    return 0 if passed == len(cases) else 1


if __name__ == "__main__":
    raise SystemExit(main())
