#!/usr/bin/env python3
"""Focused parent/child, exact-member, and reducer regression tests."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

try:
    from . import v076_post_touch_revalidation_successor_v2 as primary
    from . import v076_post_touch_revalidation_successor_v2_independent_audit as independent
except ImportError:  # pragma: no cover
    import v076_post_touch_revalidation_successor_v2 as primary
    import v076_post_touch_revalidation_successor_v2_independent_audit as independent


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=root, text=True).strip()


def run(root: Path) -> dict[str, object]:
    cases: list[tuple[str, bool]] = []
    artifact = git(root, "rev-parse", "HEAD")
    tree = git(root, "rev-parse", primary.BINDING_HEAD + "^{tree}")
    cases.append(("binding tree is exact", tree == primary.BINDING_TREE))
    cases.append(("artifact commit is a child and not the binding commit", artifact != primary.BINDING_HEAD and subprocess.run(["git", "merge-base", "--is-ancestor", primary.BINDING_HEAD, artifact], cwd=root, check=False).returncode == 0))
    cases.append(("new manifest is absent at the binding commit", primary._blob(root, primary.BINDING_HEAD, primary.MANIFEST_PATH) is None))
    cases.append(("new manifest is committed at the artifact commit", primary._blob(root, artifact, primary.MANIFEST_PATH) == (root / primary.MANIFEST_PATH).read_bytes()))
    records = primary.derive_records(root)
    manifest = primary.derive_manifest(records)
    cases.append(("target membership is the exact two fingerprints", manifest["failure_fingerprints"] == list(primary.TARGET_FINGERPRINTS) and manifest["record_count"] == 2))
    cases.append(("wildcard and future auto trust remain zero", manifest["wildcard_count"] == 0 and manifest["future_failure_auto_revalidation_count"] == 0))
    cases.append(("both projections are revalidated as registry-row changes", all(record["changed_projection_sections"] == ["registry_rows"] for record in records)))
    cases.append(("runtime owner is the sole later product touch", records[0]["product_path_transitions"]["scripts/v075_runtime/v075_runtime_owner.gd"]["touch_count"] == 1 and records[0]["product_path_transitions"]["scripts/presentation/v076_presentation_animation_director.gd"]["touch_count"] == 0))
    primary_result = primary.validate(root, artifact_head=artifact, evaluated_binding_head=primary.BINDING_HEAD)
    cases.append(("primary committed audit passes with separated heads", primary_result["status"] == "PASS" and primary_result["artifact_head"] == artifact and primary_result["evaluated_binding_head"] == primary.BINDING_HEAD and primary_result["trusted_fingerprint_count"] == 2))
    independent_result = independent.audit(root, artifact_head=artifact, evaluated_binding_head=primary.BINDING_HEAD)
    cases.append(("independent committed audit passes with separated heads", independent_result["status"] == "PASS" and independent_result["artifact_head"] == artifact and independent_result["evaluated_binding_head"] == primary.BINDING_HEAD and independent_result["trusted_fingerprint_count"] == 2))
    wrong_artifact = primary.validate(root, artifact_head=primary.BINDING_HEAD, evaluated_binding_head=primary.BINDING_HEAD)
    cases.append(("binding commit cannot masquerade as artifact commit", wrong_artifact["status"] == "FAIL" and any("COMMITTED_MANIFEST_BLOB_MISSING" in failure for failure in wrong_artifact["failures"])))
    wrong_binding = primary.validate(root, artifact_head=artifact, evaluated_binding_head=artifact)
    cases.append(("artifact commit cannot masquerade as evaluated binding", wrong_binding["status"] == "FAIL" and "PTS2_EVALUATED_BINDING_HEAD_INVALID" in wrong_binding["failures"]))
    independent_wrong_binding = independent.audit(root, artifact_head=artifact, evaluated_binding_head=artifact)
    cases.append(("independent audit rejects artifact-as-binding", independent_wrong_binding["status"] == "FAIL" and "PTS2I_EVALUATED_BINDING_INVALID" in independent_wrong_binding["failures"]))
    fp = primary.TARGET_FINGERPRINTS[0]
    row = primary_result["trusted_by_fingerprint"][fp]
    allowed = row["allowed_invalidations"][0]
    cases.append(("reducer accepts only exact code and predecessor path", primary.allows_invalidation(primary_result["trusted_by_fingerprint"], fingerprint=fp, invalidation_code=allowed, prior_record_path=row["prior_record_path"])))
    cases.append(("reducer rejects an unknown invalidation", not primary.allows_invalidation(primary_result["trusted_by_fingerprint"], fingerprint=fp, invalidation_code="FUTURE_FAILURE", prior_record_path=row["prior_record_path"])))
    cases.append(("reducer rejects a substituted predecessor path", not primary.allows_invalidation(primary_result["trusted_by_fingerprint"], fingerprint=fp, invalidation_code=allowed, prior_record_path="docs/architecture/reuse_corrections/v2/records/substituted.json")))
    old_paths = [primary.PREDECESSOR_MANIFEST_PATH] + [str(binding["path"]) for binding in json.loads((root / primary.PREDECESSOR_MANIFEST_PATH).read_text(encoding="utf-8"))["record_bindings"]]
    old_diff = git(root, "diff", "--name-only", primary.BINDING_HEAD, artifact, "--", *old_paths)
    cases.append(("predecessor manifest and records have zero diff", old_diff == ""))
    failures = [name for name, passed in cases if not passed]
    return {"status": "PASS" if not failures else "FAIL", "passed": len(cases) - len(failures), "total": len(cases), "failures": failures, "artifact_head": artifact, "evaluated_binding_head": primary.BINDING_HEAD}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    args = parser.parse_args(argv)
    result = run(args.project.resolve())
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
