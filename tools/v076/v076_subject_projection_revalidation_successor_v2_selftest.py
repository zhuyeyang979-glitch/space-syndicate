#!/usr/bin/env python3
"""Focused fail-closed tests for the successor-v2 primary validator/builder."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path
from typing import Any, Callable

try:
    from . import v076_subject_projection_revalidation_successor_v2 as successor
    from . import v076_subject_projection_revalidation_successor_v2_builder as builder
except ImportError:  # pragma: no cover - direct script execution
    import v076_subject_projection_revalidation_successor_v2 as successor
    import v076_subject_projection_revalidation_successor_v2_builder as builder


FIXED_TIME = "2026-08-29T00:00:00Z"


class Checks:
    def __init__(self) -> None:
        self.total = 0

    def true(self, value: bool, message: str) -> None:
        self.total += 1
        if not value:
            raise AssertionError(message)


def _read(path: Path) -> dict[str, Any]:
    document = successor.strict_json_file(path)
    if not isinstance(document, dict):
        raise AssertionError(f"not object: {path}")
    return document


def _write(path: Path, document: dict[str, Any]) -> None:
    path.write_bytes(successor.canonical_bytes(document))


def _record_path(stage: Path, manifest: dict[str, Any], index: int = 0) -> Path:
    relative = manifest["record_bindings"][index]["path"]
    return stage / relative[len(successor.SUCCESSOR_ROOT) :]


def _validate(root: Path, stage: Path, head: str) -> dict[str, Any]:
    return successor.validate_manifest_and_records(
        root,
        stage / "manifest.json",
        evaluated_head=head,
        current_batch_manifest_path=root / successor.CURRENT_BATCH_PATH,
        explicit_batch_manifest_paths=successor.default_explicit_batch_paths(root),
        stage_dir=stage,
    )


def _mutant(
    parent: Path,
    clean_stage: Path,
    root: Path,
    head: str,
    name: str,
    mutate: Callable[[Path, dict[str, Any]], None],
) -> dict[str, Any]:
    target = parent / name
    shutil.copytree(clean_stage, target)
    manifest = _read(target / "manifest.json")
    mutate(target, manifest)
    result = _validate(root, target, head)
    if result.get("status") != "FAIL" or result.get("trusted_by_fingerprint") or result.get("review_trusted_by_fingerprint"):
        raise AssertionError(f"mutant did not fail closed: {name}: {result}")
    return result


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    head = str(successor._git(root, "rev-parse", "HEAD"))
    checks = Checks()
    with tempfile.TemporaryDirectory(prefix="v076-spr2-selftest-") as temporary:
        parent = Path(temporary).resolve()
        clean_stage = parent / "clean"
        built = builder.build_stage(root, clean_stage, binding_head=head, created_at=FIXED_TIME)
        valid = built["validation"]
        checks.true(valid["status"] == "PASS", "valid stage did not pass")
        checks.true(valid["mode"] == "STAGE_REVIEW" and valid["stage_only"] is True, "stage mode missing")
        checks.true(valid["trusted_by_fingerprint"] == {}, "stage entered committed trust")
        checks.true(set(valid["review_trusted_by_fingerprint"]) == set(successor.TARGET_FINGERPRINTS), "review trust coverage invalid")
        checks.true(all(set(row) == successor.TRUST_ROW_FIELDS for row in valid["review_trusted_by_fingerprint"].values()), "trust row shape drift")

        predecessor, predecessor_failures = successor._load_predecessor(root, head)
        predecessor_fps = predecessor.get("fingerprints", [])
        checks.true(predecessor_failures == [], "predecessor invalid")
        checks.true(len(predecessor_fps) == 82, "frozen predecessor count drift")
        checks.true(set(predecessor_fps) & set(successor.TARGET_FINGERPRINTS) == set(), "v1/successor overlap not empty")
        checks.true(successor.trust_sets_disjoint(predecessor_fps, successor.TARGET_FINGERPRINTS), "disjoint helper rejected valid union")
        checks.true(len(set(predecessor_fps) | set(successor.TARGET_FINGERPRINTS)) == 84, "v1 82 + successor 2 union is not 84")
        checks.true(not successor.trust_sets_disjoint(predecessor_fps, [predecessor_fps[0]]), "overlap was accepted")

        first_fp = successor.TARGET_FINGERPRINTS[0]
        first_row = valid["review_trusted_by_fingerprint"][first_fp]
        checks.true(successor.allows_invalidation(valid["review_trusted_by_fingerprint"], fingerprint=first_fp, invalidation_code=successor.ALLOWED_INVALIDATION, prior_record_path=first_row["prior_record_path"]), "exact invalidation rejected")
        checks.true(not successor.allows_invalidation(valid["review_trusted_by_fingerprint"], fingerprint=first_fp, invalidation_code="ANY_OTHER_INVALIDATION", prior_record_path=first_row["prior_record_path"]), "non-subject invalidation accepted")
        checks.true(not successor.allows_invalidation(valid["review_trusted_by_fingerprint"], fingerprint="V2F-" + "f" * 64, invalidation_code=successor.ALLOWED_INVALIDATION, prior_record_path=first_row["prior_record_path"]), "future fingerprint accepted")

        def mutate_record(stage: Path, manifest: dict[str, Any], change: Callable[[dict[str, Any]], None], index: int = 0) -> None:
            path = _record_path(stage, manifest, index)
            record = _read(path)
            change(record)
            _write(path, record)

        result = _mutant(parent, clean_stage, root, head, "fingerprint", lambda s, m: mutate_record(s, m, lambda r: r.__setitem__("failure_fingerprints", ["V2F-" + "f" * 64])))
        checks.true(any("FINGERPRINT" in code or "NOT_TARGET" in code for code in result["failures"]), "fingerprint tamper not classified")

        def path_tamper(_stage: Path, manifest: dict[str, Any]) -> None:
            manifest["record_bindings"][0]["path"] = successor.RECORD_ROOT + "spr2-missing.json"
            _write(_stage / "manifest.json", manifest)
        checks.true(_mutant(parent, clean_stage, root, head, "path", path_tamper)["status"] == "FAIL", "path tamper accepted")

        checks.true(_mutant(parent, clean_stage, root, head, "prior-membership", lambda s, m: mutate_record(s, m, lambda r: r.__setitem__("prior_record_path", successor.PRIOR_RECORD_PATHS[successor.TARGET_FINGERPRINTS[1]])))["status"] == "FAIL", "prior membership tamper accepted")
        checks.true(_mutant(parent, clean_stage, root, head, "false-parent", lambda s, m: mutate_record(s, m, lambda r: r["authority_transition_proof"].__setitem__("parent_sha", successor.BASELINE_HEAD)))["status"] == "FAIL", "false parent accepted")
        checks.true(_mutant(parent, clean_stage, root, head, "baseline-drift", lambda s, m: mutate_record(s, m, lambda r: r["authority_transition_proof"].__setitem__("baseline_parent_authority_bytes_equal", False)))["status"] == "FAIL", "baseline drift accepted")
        checks.true(_mutant(parent, clean_stage, root, head, "registry-hash", lambda s, m: mutate_record(s, m, lambda r: r["authority_transition_proof"]["before_sha256_by_path"].__setitem__(successor.REGISTRY_PATH, "0" * 64)))["status"] == "FAIL", "registry hash tamper accepted")
        checks.true(_mutant(parent, clean_stage, root, head, "supersession-diff", lambda s, m: mutate_record(s, m, lambda r: r["authority_transition_proof"]["diff_sha256_by_path"].__setitem__(successor.SUPERSESSION_PATH, "0" * 64)))["status"] == "FAIL", "supersession diff tamper accepted")
        checks.true(_mutant(parent, clean_stage, root, head, "product-blob", lambda s, m: mutate_record(s, m, lambda r: r["bound_product_blob_sha256_by_path"].__setitem__(successor.PRODUCT_PATH, "0" * 64)))["status"] == "FAIL", "product blob tamper accepted")

        def third_fingerprint(stage: Path, manifest: dict[str, Any]) -> None:
            manifest["failure_fingerprints"].append("V2F-" + "f" * 64)
            manifest["failure_fingerprints"].sort()
            _write(stage / "manifest.json", manifest)
        checks.true(_mutant(parent, clean_stage, root, head, "third-fingerprint", third_fingerprint)["status"] == "FAIL", "third/future fingerprint accepted")
        checks.true(_mutant(parent, clean_stage, root, head, "wildcard", lambda s, m: mutate_record(s, m, lambda r: r["authority_selectors"].__setitem__("paths", ["*"])))["status"] == "FAIL", "wildcard accepted")

        def duplicate_key(stage: Path, _manifest: dict[str, Any]) -> None:
            path = stage / "manifest.json"
            raw = path.read_text(encoding="utf-8")
            path.write_text(raw[:-2] + ',"wildcard_count":0}\n', encoding="utf-8")
        checks.true(_mutant(parent, clean_stage, root, head, "duplicate-key", duplicate_key)["status"] == "FAIL", "duplicate JSON key accepted")

        def nonfinite(stage: Path, _manifest: dict[str, Any]) -> None:
            path = stage / "manifest.json"
            raw = path.read_text(encoding="utf-8")
            path.write_text(raw.replace('"wildcard_count":0', '"wildcard_count":NaN'), encoding="utf-8")
        checks.true(_mutant(parent, clean_stage, root, head, "nonfinite", nonfinite)["status"] == "FAIL", "NaN JSON accepted")

        inside = root / (".v076-spr2-selftest-rejected-" + uuid.uuid4().hex)
        try:
            builder.build_stage(root, inside, binding_head=head, created_at=FIXED_TIME)
            raise AssertionError("inside-repository stage accepted")
        except ValueError as error:
            checks.true("STAGE_INSIDE_REPOSITORY" in str(error), "inside stage wrong failure")
        checks.true(not os.path.lexists(inside), "rejected inside stage was created")

        existing = parent / "existing"
        existing.mkdir()
        try:
            builder.build_stage(root, existing, binding_head=head, created_at=FIXED_TIME)
            raise AssertionError("existing stage accepted")
        except ValueError as error:
            checks.true("TARGET_ALREADY_EXISTS" in str(error), "existing stage wrong failure")

        committed_attempt = successor.validate_manifest_and_records(
            root,
            clean_stage / "manifest.json",
            evaluated_head=head,
            current_batch_manifest_path=root / successor.CURRENT_BATCH_PATH,
            explicit_batch_manifest_paths=successor.default_explicit_batch_paths(root),
            stage_dir=None,
        )
        checks.true(committed_attempt["status"] == "FAIL" and committed_attempt["trusted_by_fingerprint"] == {}, "stage became committed trust")

        link = parent / "stage-junction"
        link_created = False
        if os.name == "nt":
            proc = subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(clean_stage)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            link_created = proc.returncode == 0
        else:
            try:
                link.symlink_to(clean_stage, target_is_directory=True)
                link_created = True
            except OSError:
                link_created = False
        checks.true(link_created, "could not create stage symlink/reparse selftest fixture")
        linked = successor.validate_manifest_and_records(
            root,
            link / "manifest.json",
            evaluated_head=head,
            current_batch_manifest_path=root / successor.CURRENT_BATCH_PATH,
            explicit_batch_manifest_paths=successor.default_explicit_batch_paths(root),
            stage_dir=link,
        )
        checks.true(linked["status"] == "FAIL" and linked["trusted_by_fingerprint"] == {} and linked["review_trusted_by_fingerprint"] == {}, "stage reparse point accepted")
        if link_created:
            os.rmdir(link)

    print(f"V076_SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V2_SELFTEST=PASS")
    print(f"CHECKS={checks.total}/{checks.total}")
    print("PREDECESSOR_SUCCESSOR_OVERLAP=[]")
    print("PREDECESSOR_SUCCESSOR_DISJOINT_UNION_COUNT=84")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
