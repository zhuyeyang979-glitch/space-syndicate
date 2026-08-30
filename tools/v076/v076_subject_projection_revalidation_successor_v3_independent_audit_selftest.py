#!/usr/bin/env python3
"""Focused independent-audit checks for the Batch-007 successor-v3 layer."""

from __future__ import annotations

import ast
import copy
import json
import tempfile
from pathlib import Path

try:
    from . import v076_subject_projection_revalidation_successor_v3_independent_audit as audit
except ImportError:  # pragma: no cover
    import v076_subject_projection_revalidation_successor_v3_independent_audit as audit


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    manifest_path = root / audit.ROOT / "manifest.json"
    checks = 0
    failures: list[str] = []

    def check(value: bool, message: str) -> None:
        nonlocal checks
        checks += 1
        if not value:
            failures.append(message)

    tree = ast.parse(Path(audit.__file__).read_text(encoding="utf-8"))
    imports = {alias.name for node in ast.walk(tree) if isinstance(node, ast.Import) for alias in node.names}
    imports.update(node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom) and node.module)
    check("v076_subject_projection_revalidation_successor_v3" not in imports, "independent audit imports primary")
    check("v076_subject_projection_revalidation_successor_v3_builder" not in imports, "independent audit imports builder")

    head = str(audit.git(root, "rev-parse", "HEAD"))
    valid = audit.audit(root, manifest_path, head)
    check(valid.get("status") == "PASS", "valid successor-v3 audit did not PASS")
    check(valid.get("record_count") == 25, "valid successor-v3 trust count is not 25")
    check(len(valid.get("trusted_by_fingerprint", {})) == 25, "valid successor-v3 trust coverage incomplete")
    check(valid.get("independent") is True, "audit did not attest independent mode")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(prefix="v076-spr3-independent-audit-selftest-") as temporary:
        mutant_path = Path(temporary) / "manifest.json"
        mutant = copy.deepcopy(manifest)
        mutant["failure_fingerprints"] = sorted(mutant["failure_fingerprints"] + ["V2F-" + "f" * 64])
        mutant_path.write_bytes(audit.cb(mutant))
        rejected = audit.audit(root, mutant_path, head)
        check(rejected.get("status") == "FAIL" and not rejected.get("trusted_by_fingerprint"), "audit accepted future fingerprint")
        mutant = copy.deepcopy(manifest)
        mutant["predecessor_manifest_sha256"] = "0" * 64
        mutant_path.write_bytes(audit.cb(mutant))
        rejected = audit.audit(root, mutant_path, head)
        check(rejected.get("status") == "FAIL" and not rejected.get("trusted_by_fingerprint"), "audit accepted predecessor hash tamper")

    result = {"status": "PASS" if not failures else "FAIL", "checks": checks - len(failures), "check_count": checks, "failures": failures, "primary_independent_valid_trust_agreement": valid.get("status") == "PASS" and valid.get("record_count") == 25}
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
