#!/usr/bin/env python3
"""Deterministically materialize the post-touch successor-v2 artifacts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from . import v076_post_touch_revalidation_successor_v2 as successor
except ImportError:  # pragma: no cover
    import v076_post_touch_revalidation_successor_v2 as successor


def expected_artifacts(root: Path) -> dict[str, bytes]:
    schema_raw = (root / successor.SCHEMA_PATH).read_bytes()
    if successor.sha256_bytes(schema_raw) != successor.SCHEMA_SHA256:
        raise ValueError("PTS2_BUILDER_SCHEMA_SHA256_INVALID")
    records = successor.derive_records(root)
    manifest = successor.derive_manifest(records)
    artifacts = {successor.MANIFEST_PATH: successor.canonical_bytes(manifest)}
    for fingerprint, record in zip(successor.TARGET_FINGERPRINTS, records, strict=True):
        artifacts[successor.expected_record_path(fingerprint)] = successor.canonical_bytes(record)
    return artifacts


def build(root: Path, *, check: bool = False) -> dict[str, object]:
    artifacts = expected_artifacts(root)
    failures: list[str] = []
    for relative, expected in sorted(artifacts.items()):
        path = root / relative
        if check:
            if not path.is_file() or path.read_bytes() != expected:
                failures.append("PTS2_BUILDER_ARTIFACT_DRIFT:" + relative)
        else:
            if path.exists():
                raise ValueError("PTS2_BUILDER_REFUSES_OVERWRITE:" + relative)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected)
    expected_names = sorted(
        Path(successor.expected_record_path(fp)).name
        for fp in successor.TARGET_FINGERPRINTS
    )
    records_dir = root / successor.RECORD_ROOT
    actual_names = sorted(path.name for path in records_dir.glob("*.json")) if records_dir.is_dir() else []
    if actual_names != expected_names:
        failures.append("PTS2_BUILDER_RECORD_MEMBER_SET_INVALID")
    return {
        "status": "PASS" if not failures else "FAIL",
        "mode": "CHECK" if check else "BUILD",
        "failures": failures,
        "artifact_count": len(artifacts),
        "record_count": len(successor.TARGET_FINGERPRINTS),
        "failure_fingerprints": list(successor.TARGET_FINGERPRINTS),
        "manifest_path": successor.MANIFEST_PATH,
        "binding_head": successor.BINDING_HEAD,
        "binding_tree": successor.BINDING_TREE,
        "wildcard_count": 0,
        "future_failure_auto_revalidation_count": 0,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    try:
        result = build(args.project.resolve(), check=args.check)
    except Exception as error:
        result = {"status": "FAIL", "failures": [str(error)]}
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
