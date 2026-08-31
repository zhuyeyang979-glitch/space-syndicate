#!/usr/bin/env python3
"""Fail-closed checks for the exact ac5 current-product-subject manifest."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
from typing import Any, Callable

import v076_current_product_subject_manifest_builder as manifest_builder


MANIFEST_PATH = (
    "reports/reuse/full_convergence/candidate_subject_manifest_ac5efcc5.json"
)


class Checks:
    def __init__(self) -> None:
        self.count = 0
        self.failures: list[str] = []

    def true(self, condition: bool, label: str) -> None:
        self.count += 1
        if not condition:
            self.failures.append(label)


def _mutated(source: dict[str, Any], mutate: Callable[[dict[str, Any]], None]) -> dict[str, Any]:
    value = copy.deepcopy(source)
    mutate(value)
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    args = parser.parse_args()
    repo = args.repo.resolve()
    manifest = json.loads((repo / MANIFEST_PATH).read_text(encoding="utf-8"))
    checks = Checks()

    expected = manifest_builder.validate_manifest(repo, manifest, MANIFEST_PATH)
    checks.true(expected == manifest, "real Git recomputation does not match artifact")
    checks.true(
        manifest["previous_subject_to_subject"]["product_delta_paths"]
        == ["scripts/v075_runtime/v075_runtime_owner.gd"],
        "exact previous-to-subject product delta is not one covered Owner path",
    )
    checks.true(
        manifest["subject_to_evaluated_governance_head"][
            "product_delta_path_count"
        ]
        == 0,
        "product bytes changed after registered subject",
    )
    checks.true(
        manifest["product_path_coverage"]["registered_path_count"] == 213,
        "registered product binding count drifted",
    )
    checks.true(
        len(manifest["runtime_boundary_bindings"]) == 6,
        "runtime boundary binding count drifted",
    )
    checks.true(
        manifest["product_path_coverage"]["unknown_product_path_count"] == 0,
        "unknown product path was accepted",
    )

    real_builder = manifest_builder.build_manifest
    manifest_builder.build_manifest = lambda *unused_args, **unused_kwargs: copy.deepcopy(expected)

    def rejects(value: dict[str, Any]) -> bool:
        try:
            manifest_builder.validate_manifest(repo, value)
        except SystemExit:
            return True
        return False

    try:
        checks.true(
            rejects(
                _mutated(
                    manifest,
                    lambda value: value["product_path_bindings"].pop(),
                )
            ),
            "missing product binding was accepted",
        )
        checks.true(
            rejects(
                _mutated(
                    manifest,
                    lambda value: value["product_path_bindings"][0].__setitem__(
                        "sha256", "0" * 64
                    ),
                )
            ),
            "tampered product sha256 was accepted",
        )
        checks.true(
            rejects(
                _mutated(
                    manifest,
                    lambda value: value["runtime_boundary_bindings"].pop(),
                )
            ),
            "missing runtime binding was accepted",
        )
        checks.true(
            rejects(
                _mutated(
                    manifest,
                    lambda value: value["product_path_coverage"].__setitem__(
                        "registered_path_set_sha256", "0" * 64
                    ),
                )
            ),
            "tampered aggregate path-set hash was accepted",
        )
        checks.true(
            rejects(
                _mutated(
                    manifest,
                    lambda value: value["product_path_coverage"].__setitem__(
                        "coverage_percent", 99
                    ),
                )
            ),
            "tampered coverage scalar was accepted",
        )
        checks.true(
            rejects(
                _mutated(
                    manifest,
                    lambda value: value["claims"].__setitem__(
                        "production_green", True
                    ),
                )
            ),
            "false production-green claim was accepted",
        )
        checks.true(
            rejects(
                _mutated(
                    manifest,
                    lambda value: value["immutability"].__setitem__(
                        "append_only", False
                    ),
                )
            ),
            "non-append-only mutation was accepted",
        )
        checks.true(
            rejects(
                _mutated(
                    manifest,
                    lambda value: value["immutability"].__setitem__(
                        "self_reference_count", 1
                    ),
                )
            ),
            "self-reference mutation was accepted",
        )
    finally:
        manifest_builder.build_manifest = real_builder

    status = "PASS" if not checks.failures else "FAIL"
    print(
        "V076_CURRENT_PRODUCT_SUBJECT_MANIFEST_SELFTEST|"
        f"status={status}|checks={checks.count}|failures={len(checks.failures)}"
    )
    for failure in checks.failures:
        print(f"FAIL:{failure}")
    return 0 if not checks.failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
