#!/usr/bin/env python3
"""Independent-audit agreement and fail-closed negative tests."""

from __future__ import annotations

import ast
import copy
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable

try:
    from . import v076_subject_projection_revalidation_successor_v2 as primary
    from . import v076_subject_projection_revalidation_successor_v2_builder as builder
    from . import v076_subject_projection_revalidation_successor_v2_independent_audit as audit
except ImportError:  # pragma: no cover - direct script execution
    import v076_subject_projection_revalidation_successor_v2 as primary
    import v076_subject_projection_revalidation_successor_v2_builder as builder
    import v076_subject_projection_revalidation_successor_v2_independent_audit as audit


FIXED_TIME = "2026-08-29T00:00:00Z"


class Checks:
    def __init__(self) -> None:
        self.total = 0

    def true(self, value: bool, message: str) -> None:
        self.total += 1
        if not value:
            raise AssertionError(message)


def _read(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise AssertionError(path)
    return value


def _write(path: Path, value: dict[str, Any]) -> None:
    path.write_bytes(audit._canonical(value))


def _record(stage: Path, manifest: dict[str, Any], index: int = 0) -> Path:
    relative = manifest["record_bindings"][index]["path"]
    return stage / relative[len(audit.SUCCESSOR_ROOT) :]


def _audit(root: Path, stage: Path, head: str) -> dict[str, Any]:
    return audit.audit_manifest_and_records(
        root,
        stage / "manifest.json",
        evaluated_head=head,
        current_batch_manifest_path=root / audit.CURRENT_BATCH_PATH,
        explicit_batch_manifest_paths=audit.default_explicit_batch_paths(root),
        stage_dir=stage,
    )


def _mutant(
    parent: Path,
    clean: Path,
    root: Path,
    head: str,
    name: str,
    mutate: Callable[[Path, dict[str, Any]], None],
) -> dict[str, Any]:
    target = parent / name
    shutil.copytree(clean, target)
    manifest = _read(target / "manifest.json")
    mutate(target, manifest)
    result = _audit(root, target, head)
    if result.get("status") != "NO_GO" or result.get("trusted_by_fingerprint") or result.get("review_trusted_by_fingerprint"):
        raise AssertionError(f"independent audit did not fail closed: {name}: {result}")
    return result


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    head = str(audit._git(root, "rev-parse", "HEAD"))
    checks = Checks()

    source_path = Path(audit.__file__).resolve()
    tree = ast.parse(source_path.read_text(encoding="utf-8"))
    imported_names: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported_names.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.module:
            imported_names.add(node.module)
    checks.true("v076_subject_projection_revalidation_successor_v2" not in imported_names, "independent module imports primary")
    checks.true("v076_subject_projection_revalidation_successor_v2_builder" not in imported_names, "independent module imports builder")

    with tempfile.TemporaryDirectory(prefix="v076-spr2-audit-selftest-") as temporary:
        parent = Path(temporary).resolve()
        clean = parent / "clean"
        built = builder.build_stage(root, clean, binding_head=head, created_at=FIXED_TIME)
        primary_result = built["validation"]
        audit_result = _audit(root, clean, head)
        checks.true(audit_result["status"] == "GO" and audit_result["findings"] == [], "independent valid stage did not GO")
        checks.true(audit.agrees_with_primary(primary_result, audit_result), "primary/independent valid results disagree")
        checks.true(audit_result["trusted_by_fingerprint"] == {}, "stage entered independent committed trust")
        checks.true(set(audit_result["review_trusted_by_fingerprint"]) == set(audit.TARGET_FINGERPRINTS), "independent review coverage invalid")
        checks.true(all(set(row) == audit.TRUST_ROW_FIELDS for row in audit_result["review_trusted_by_fingerprint"].values()), "independent trust row shape drift")

        first_fp = audit.TARGET_FINGERPRINTS[0]
        first_row = audit_result["review_trusted_by_fingerprint"][first_fp]
        checks.true(audit.allows_invalidation(audit_result["review_trusted_by_fingerprint"], fingerprint=first_fp, invalidation_code=audit.ALLOWED_INVALIDATION, prior_record_path=first_row["prior_record_path"]), "independent exact invalidation rejected")
        checks.true(not audit.allows_invalidation(audit_result["review_trusted_by_fingerprint"], fingerprint=first_fp, invalidation_code="OTHER", prior_record_path=first_row["prior_record_path"]), "independent accepted other invalidation")

        disagreement = copy.deepcopy(audit_result)
        disagreement["review_trusted_by_fingerprint"][first_fp]["revalidation_id"] = "MISMATCH"
        checks.true(not audit.agrees_with_primary(primary_result, disagreement), "primary/independent trust disagreement accepted")
        no_go = copy.deepcopy(audit_result)
        no_go["status"] = "NO_GO"
        checks.true(not audit.agrees_with_primary(primary_result, no_go), "independent NO_GO agreed with primary PASS")

        def mutate_record(stage: Path, manifest: dict[str, Any], change: Callable[[dict[str, Any]], None], index: int = 0) -> None:
            path = _record(stage, manifest, index)
            record = _read(path)
            change(record)
            _write(path, record)

        checks.true(_mutant(parent, clean, root, head, "fingerprint", lambda s, m: mutate_record(s, m, lambda r: r.__setitem__("failure_fingerprints", ["V2F-" + "f" * 64])))["status"] == "NO_GO", "audit accepted fingerprint tamper")

        def path_tamper(stage: Path, manifest: dict[str, Any]) -> None:
            manifest["record_bindings"][0]["path"] = audit.RECORD_ROOT + "missing.json"
            _write(stage / "manifest.json", manifest)
        checks.true(_mutant(parent, clean, root, head, "path", path_tamper)["status"] == "NO_GO", "audit accepted path tamper")

        checks.true(_mutant(parent, clean, root, head, "prior-membership", lambda s, m: mutate_record(s, m, lambda r: r.__setitem__("prior_record_payload_sha256", "0" * 64)))["status"] == "NO_GO", "audit accepted prior membership tamper")
        checks.true(_mutant(parent, clean, root, head, "false-parent", lambda s, m: mutate_record(s, m, lambda r: r["authority_transition_proof"].__setitem__("parent_sha", audit.BASELINE_HEAD)))["status"] == "NO_GO", "audit accepted false parent")
        checks.true(_mutant(parent, clean, root, head, "baseline-drift", lambda s, m: mutate_record(s, m, lambda r: r["authority_transition_proof"].__setitem__("baseline_parent_authority_bytes_equal", False)))["status"] == "NO_GO", "audit accepted baseline drift")
        checks.true(_mutant(parent, clean, root, head, "registry-hash", lambda s, m: mutate_record(s, m, lambda r: r["authority_transition_proof"]["after_sha256_by_path"].__setitem__(audit.REGISTRY_PATH, "0" * 64)))["status"] == "NO_GO", "audit accepted registry hash tamper")
        checks.true(_mutant(parent, clean, root, head, "supersession-diff", lambda s, m: mutate_record(s, m, lambda r: r["authority_transition_proof"]["diff_sha256_by_path"].__setitem__(audit.SUPERSESSION_PATH, "0" * 64)))["status"] == "NO_GO", "audit accepted supersession diff tamper")
        checks.true(_mutant(parent, clean, root, head, "product", lambda s, m: mutate_record(s, m, lambda r: r["bound_product_blob_sha256_by_path"].__setitem__(audit.PRODUCT_PATH, "0" * 64)))["status"] == "NO_GO", "audit accepted product blob tamper")
        checks.true(_mutant(parent, clean, root, head, "wildcard", lambda s, m: mutate_record(s, m, lambda r: r["authority_selectors"].__setitem__("paths", ["*"])))["status"] == "NO_GO", "audit accepted wildcard")

        def future(stage: Path, manifest: dict[str, Any]) -> None:
            manifest["failure_fingerprints"].append("V2F-" + "f" * 64)
            manifest["failure_fingerprints"].sort()
            _write(stage / "manifest.json", manifest)
        checks.true(_mutant(parent, clean, root, head, "future", future)["status"] == "NO_GO", "audit accepted future fingerprint")

        def duplicate(stage: Path, _manifest: dict[str, Any]) -> None:
            path = stage / "manifest.json"
            raw = path.read_text(encoding="utf-8")
            path.write_text(raw[:-2] + ',"wildcard_count":0}\n', encoding="utf-8")
        checks.true(_mutant(parent, clean, root, head, "duplicate", duplicate)["status"] == "NO_GO", "audit accepted duplicate JSON key")

        link = parent / "stage-junction"
        if os.name == "nt":
            proc = subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(clean)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            linked = proc.returncode == 0
        else:
            try:
                link.symlink_to(clean, target_is_directory=True)
                linked = True
            except OSError:
                linked = False
        checks.true(linked, "could not create independent stage reparse fixture")
        linked_result = audit.audit_manifest_and_records(
            root,
            link / "manifest.json",
            evaluated_head=head,
            current_batch_manifest_path=root / audit.CURRENT_BATCH_PATH,
            explicit_batch_manifest_paths=audit.default_explicit_batch_paths(root),
            stage_dir=link,
        )
        checks.true(linked_result["status"] == "NO_GO" and linked_result["trusted_by_fingerprint"] == {} and linked_result["review_trusted_by_fingerprint"] == {}, "independent audit accepted stage reparse")
        if linked:
            os.rmdir(link)

    print("V076_SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V2_INDEPENDENT_AUDIT_SELFTEST=PASS")
    print(f"CHECKS={checks.total}/{checks.total}")
    print("PRIMARY_INDEPENDENT_VALID_TRUST_AGREEMENT=true")
    print("PRIMARY_INDEPENDENT_DISAGREEMENT_FAIL_CLOSED=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
