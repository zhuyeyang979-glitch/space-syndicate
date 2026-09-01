"""Focused fail-closed checks for successor-v3."""
from __future__ import annotations
import json
import shutil
import tempfile
from pathlib import Path
try:
    from . import v076_subject_projection_revalidation_successor_v3 as v3
    from . import v076_subject_projection_revalidation_successor_v3_builder as builder
except ImportError:  # pragma: no cover
    import v076_subject_projection_revalidation_successor_v3 as v3
    import v076_subject_projection_revalidation_successor_v3_builder as builder


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    head = str(v3._git(root, "rev-parse", "HEAD")).strip()
    change = "dd16731c26ca78efc2dd630b11d4d65ca966117f"
    parent = "546893234190716a4486870676fd402f89edbe0f"
    with tempfile.TemporaryDirectory(prefix="v076-spr3-selftest-") as td:
        stage = Path(td) / "stage"
        built = builder.build(root, stage, binding_head=head, change_commit=change, change_parent=parent, created_at="2026-08-30T00:00:00Z")
        result = built["validation"]
        assert result["status"] == "PASS" and result["review_trusted_fingerprint_count"] == 25
        manifest = json.loads((stage / "manifest.json").read_text(encoding="utf-8"))
        assert manifest["record_count"] == 25
        assert v3.line_set_sha(manifest["failure_fingerprints"]) == "c58db2b8e7bae5f1eef0e37ebf1dd807e9c188e23109ae769ef6dc0f61ae2511"
        first = stage / "records" / Path(manifest["record_bindings"][0]["path"]).name
        doc = json.loads(first.read_text(encoding="utf-8"))
        doc["wildcard_count"] = 1
        first.write_bytes(v3.canonical_bytes(doc))
        rejected = v3.validate_manifest_and_records(root, stage / "manifest.json", evaluated_head=head, stage_dir=stage)
        assert rejected["status"] == "FAIL" and not rejected["review_trusted_by_fingerprint"]
    print("V076_SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V3_SELFTEST=PASS")
    print("CHECKS=3/3")
    print("PREDECESSOR_V1_V2_V3_UNION_COUNT=109")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
