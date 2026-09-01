#!/usr/bin/env python3
"""Focused positive and fail-closed checks for exact SPR successor-v6."""
from __future__ import annotations

import shutil
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator

try:
    from . import v076_subject_projection_revalidation_successor_v6 as primary
    from . import v076_subject_projection_revalidation_successor_v6_independent_audit as independent
except ImportError:  # pragma: no cover - direct execution
    import v076_subject_projection_revalidation_successor_v6 as primary
    import v076_subject_projection_revalidation_successor_v6_independent_audit as independent

try:
    from . import v076_reuse_exact_failure_correction_v2 as resolver
    from . import v076_reuse_exact_failure_correction_v2_full_convergence as convergence
    from . import v076_reuse_correction_v2_independent_audit as correction_audit
except ImportError:  # pragma: no cover - direct execution
    import v076_reuse_exact_failure_correction_v2 as resolver
    import v076_reuse_exact_failure_correction_v2_full_convergence as convergence
    import v076_reuse_correction_v2_independent_audit as correction_audit


class Checks:
    def __init__(self) -> None:
        self.total = 0

    def true(self, value: bool, message: str) -> None:
        self.total += 1
        if not value:
            raise AssertionError(message)


def _document(path: Path) -> dict[str, Any]:
    value = primary.strict(path.read_bytes())
    if not isinstance(value, dict):
        raise AssertionError(f"not an object: {path}")
    return value


def _copy_stage(source: Path, target: Path) -> None:
    (target / "records").mkdir(parents=True)
    shutil.copy2(source / "manifest.json", target / "manifest.json")
    for record in (source / "records").glob("*.json"):
        shutil.copy2(record, target / "records" / record.name)


def _audit_pair(
    root: Path,
    manifest_path: Path,
    stage_dir: Path,
    binding_head: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    return (
        primary.validate(
            root,
            manifest_path,
            evaluated_head=binding_head,
            stage_dir=stage_dir,
        ),
        independent.audit(
            root,
            manifest_path,
            evaluated_head=binding_head,
            stage_dir=stage_dir,
        ),
    )


def _mutated_record_pair(
    root: Path,
    source: Path,
    manifest_path: Path,
    binding_head: str,
    mutate: Callable[[dict[str, Any]], None],
) -> tuple[dict[str, Any], dict[str, Any]]:
    with tempfile.TemporaryDirectory(prefix="v076-spr6-") as temporary:
        stage = Path(temporary)
        _copy_stage(source, stage)
        target = sorted((stage / "records").glob("*.json"))[0]
        record = _document(target)
        mutate(record)
        target.write_bytes(primary.canonical_bytes(record))
        return _audit_pair(root, manifest_path, stage, binding_head)


@contextmanager
def _mutated_receipt_blob(module: Any) -> Iterator[None]:
    original = module.blob

    def replacement(root: Path, ref: str, path: str) -> bytes | None:
        raw = original(root, ref, path)
        if path == primary.DETACHMENT_RECEIPT_PATH and raw is not None:
            return raw + b"\n"
        return raw

    module.blob = replacement
    try:
        yield
    finally:
        module.blob = original


def _both_fail_closed(pair: tuple[dict[str, Any], dict[str, Any]]) -> bool:
    return all(
        result.get("status") == "FAIL"
        and result.get("trusted_by_fingerprint") == {}
        and result.get("review_trusted_by_fingerprint") == {}
        and result.get("authorized_identity_by_fingerprint") == {}
        for result in pair
    )


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    stage = root / primary.SUCCESSOR_ROOT
    manifest_path = stage / "manifest.json"
    manifest = _document(manifest_path)
    binding_head = str(manifest["revalidation_binding_head_sha"])
    checks = Checks()

    expected = set(primary.RAW_SPECS)
    checks.true(
        len(expected) == 2
        and manifest["record_count"] == 2
        and set(manifest["failure_fingerprints"]) == expected,
        "successor-v6 is not an exact two-record authority",
    )
    for fingerprint, spec in primary.RAW_SPECS.items():
        checks.true(
            primary.expected_fingerprint(str(spec["raw_failure"])) == fingerprint,
            f"exact Raw/fingerprint mismatch: {fingerprint}",
        )

    primary_stage, independent_stage = _audit_pair(
        root, manifest_path, stage, binding_head
    )
    checks.true(
        primary_stage.get("status") == "PASS"
        and independent_stage.get("status") == "PASS"
        and primary_stage.get("mode") == "STAGE_REVIEW"
        and independent_stage.get("mode") == "STAGE_REVIEW"
        and primary_stage.get("trusted_by_fingerprint") == {}
        and independent_stage.get("trusted_by_fingerprint") == {}
        and set(primary_stage.get("review_trusted_by_fingerprint", {})) == expected
        and set(independent_stage.get("review_trusted_by_fingerprint", {})) == expected,
        "dual stage review did not expose exactly two review-only identities",
    )
    checks.true(
        primary_stage.get("authorized_identity_by_fingerprint")
        == independent_stage.get("authorized_identity_by_fingerprint"),
        "primary/independent identity parity failed",
    )

    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("wildcard", lambda value: value.__setitem__("wildcard_count", 1)),
        (
            "future-auto",
            lambda value: value["future_failure_policy"].__setitem__(
                "FUTURE_FAILURE_AUTO_CORRECTION_COUNT", 1
            ),
        ),
        ("raw", lambda value: value.__setitem__("raw_failure", value["raw_failure"] + ":FUTURE")),
        ("fingerprint", lambda value: value.__setitem__("failure_fingerprint", "V2F-" + "0" * 64)),
        ("transition", lambda value: value.__setitem__("transition_commit_sha", "0" * 40)),
        (
            "current-resolution",
            lambda value: value["current_resolution"].__setitem__(
                "retired_source_referenced", True
            ),
        ),
        (
            "chain",
            lambda value: value.__setitem__(
                "previous_correction_chain_sha256", "0" * 64
            ),
        ),
    ]
    for label, mutate in mutations:
        pair = _mutated_record_pair(
            root, stage, manifest_path, binding_head, mutate
        )
        checks.true(_both_fail_closed(pair), f"{label} mutation did not fail closed")

    with _mutated_receipt_blob(primary), _mutated_receipt_blob(independent):
        receipt_pair = _audit_pair(root, manifest_path, stage, binding_head)
    checks.true(
        _both_fail_closed(receipt_pair),
        "detachment receipt mutation did not fail closed in both audits",
    )

    future_raw = (
        primary.RULE_ID
        + ":111111111111->222222222222:"
        + primary.COMPONENT_ID
        + ":"
        + primary.REUSE_ID
    )
    checks.true(
        future_raw not in {str(value["raw_failure"]) for value in primary.RAW_SPECS.values()}
        and primary.expected_fingerprint(future_raw) not in expected,
        "a future same-rule Raw row was implicitly admitted",
    )
    exact_raws = {
        str(value["raw_failure"]) for value in primary.RAW_SPECS.values()
    }
    for module in (resolver, convergence, correction_audit):
        checks.true(
            all(module._is_historical_raw_failure(raw) for raw in exact_raws)
            and not module._is_historical_raw_failure(future_raw),
            f"exact non-prefix history boundary drifted in {module.__name__}",
        )
        sets = (
            module.authorized_failure_fingerprint_sets(
                {"failures": [*sorted(exact_raws), future_raw]}
            )
            if module is convergence
            else module._authorized_failure_fingerprint_sets(
                {"failures": [*sorted(exact_raws), future_raw]}
            )
            if module is correction_audit
            else None
        )
        if sets is not None:
            checks.true(
                set(sets["historical"]) == expected
                and len(sets["current"]) == 1,
                f"exact historical/current fingerprint partition drifted in {module.__name__}",
            )
    checks.true(
        manifest.get("wildcard_count") == 0
        and manifest.get("future_failure_auto_correction") is False
        and primary_stage.get("wildcard_count") == 0
        and primary_stage.get("future_failure_auto_correction_count") == 0
        and independent_stage.get("wildcard_count") == 0
        and independent_stage.get("future_failure_auto_correction_count") == 0,
        "fail-closed policy counters drifted",
    )

    print(f"V076_SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V6_SELFTEST_PASS={checks.total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
