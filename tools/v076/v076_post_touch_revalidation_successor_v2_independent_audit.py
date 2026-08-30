#!/usr/bin/env python3
"""Independent committed-byte audit of post-touch successor-v2."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any

try:
    from . import v076_reuse_exact_failure_correction_v2_full_convergence as convergence
except ImportError:  # pragma: no cover
    import v076_reuse_exact_failure_correction_v2_full_convergence as convergence


BINDING_HEAD = "7e87c564fc2c092a0fb00519c15711d19f99305f"
BINDING_TREE = "ab8d71ef783710b348eb299dc7c9d5ba58172a1b"
PREDECESSOR_BINDING_HEAD = "5af52a5bfe4f7734b0a01aeb9b63dd5e2d606acb"
PREDECESSOR_BINDING_TREE = "6e1df65d9945e3a46a4dd979f3af65f9971958a6"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_CURRENT_SUBJECT_CONVERGENCE_AND_COMMERCIAL_RESUME_20260830"
AUTHORIZATION_BASE_HEAD = "7b2bd08a9916a3a517f2d418765c544cce0261cc"
PREDECESSOR_AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
PREDECESSOR_AUTHORIZATION_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.post_touch_revalidation_successor_v2_schema.v1"
MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.post_touch_revalidation_successor_v2_manifest.v1"
RECORD_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.post_touch_revalidation_successor_v2_record.v1"
MANIFEST_KIND = "POST_TOUCH_REVALIDATION_SUCCESSOR_V2_MANIFEST"
RECORD_KIND = "POST_TOUCH_REVALIDATION_SUCCESSOR_V2_RECORD"
MANIFEST_ID = "V076-POST-TOUCH-REVALIDATION-SUCCESSOR-V2-20260830"
SCHEMA_PATH = "docs/architecture/reuse_corrections/v2/schema_post_touch_revalidation_successor_v2_20260830.json"
SCHEMA_SHA256 = "5fc638c163c10463a71d289ac052febc41b8ec083462cc9f57e59ee6ea75033c"
SUCCESSOR_ROOT = "docs/architecture/reuse_corrections/v2/post_touch_revalidation_successor_v2"
MANIFEST_PATH = SUCCESSOR_ROOT + "/manifest.json"
RECORD_ROOT = SUCCESSOR_ROOT + "/records"
PREDECESSOR_MANIFEST_PATH = "docs/architecture/reuse_corrections/v2/post_touch_revalidation/full_convergence_batch004_20260828_manifest.json"
PREDECESSOR_MANIFEST_SHA256 = "95b8f25cda3f42fd2b7cff4a611f1b860d58d5c5187a0b1f34bbd27cedd09ee2"
PREDECESSOR_CHAIN_TERMINAL_SHA256 = "6aa50705a471a94dc0af71484564a777a0ec6fc325ce68eb6592d1ba3d8427dc"
TARGETS = (
    "V2F-2a1119496ba5fe9ab1d523118e7f325946ad8c01fbd9d9e3c575c7d7dd4dac2b",
    "V2F-6a4c0788f95300f0ef3c63df2b8f838824d5f4a4aa552c032b908cab9090d618",
)
PRODUCT_PATHS = (
    "scripts/presentation/v076_presentation_animation_director.gd",
    "scripts/v075_runtime/v075_runtime_owner.gd",
)
AUTHORITY_PATHS = (
    "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json",
    "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json",
    "docs/architecture/V076_OWNER_REUSE_MAP.md",
    "docs/architecture/V076_SUPERSESSION_MAP.json",
)
PROJECTION_FIELDS = {"dynamic_reference_rows", "owner_map_lines", "registry_rows", "supersession_rows"}
FUTURE_POLICY = {"FUTURE_FAILURE_AUTO_REVALIDATION_COUNT": 0, "NEW_FAILURE_REQUIRES_NEW_RECORD": True}
CREATED_AT = "2026-08-30T00:00:00Z"
CREATOR = "v076_post_touch_revalidation_successor_v2_builder.py"
MANIFEST_FIELDS = set("""schema_version manifest_kind manifest_id authorization_id authorization_base_head_sha predecessor_authorization_id predecessor_authorization_base_head_sha schema_path schema_sha256 predecessor_manifest_path predecessor_manifest_sha256 predecessor_record_count predecessor_failure_fingerprint_set_sha256 predecessor_record_chain_terminal_sha256 revalidation_binding_head_sha revalidation_binding_tree_sha record_count failure_fingerprints failure_fingerprint_set_sha256 record_chain_start_sha256 record_chain_terminal_sha256 record_bindings product_paths authority_source_paths current_projection_sha256_by_failure wildcard_count future_failure_auto_revalidation_count committed_only_bytes created_at creator""".split())
RECORD_FIELDS = set("""schema_version record_kind revalidation_id authorization_id authorization_base_head_sha predecessor_authorization_id predecessor_authorization_base_head_sha failure_fingerprints failure_fingerprint_set_sha256 predecessor_manifest_path predecessor_manifest_sha256 predecessor_record_chain_terminal_sha256 predecessor_record_path predecessor_record_sha256 predecessor_record_payload_sha256 predecessor_revalidation_id original_correction_record_path original_correction_record_sha256 original_correction_record_payload_sha256 original_correction_id predecessor_binding_head_sha predecessor_binding_tree_sha revalidation_binding_head_sha revalidation_binding_tree_sha authority_selectors authority_selector_sha256 predecessor_touch_proof predecessor_touch_proof_sha256 prior_invalidations predecessor_subject_projection predecessor_subject_projection_sha256 current_subject_projection current_subject_projection_sha256 changed_projection_sections product_path_transitions authority_path_transitions current_product_blob_sha256_by_path future_failure_policy wildcard_count new_effective_status previous_revalidation_chain_sha256 created_at creator revalidation_reason record_payload_sha256""".split())
BINDING_FIELDS = set("""path record_sha256 record_payload_sha256 revalidation_id failure_fingerprints previous_revalidation_chain_sha256 predecessor_record_path predecessor_record_sha256 predecessor_record_payload_sha256 predecessor_revalidation_id""".split())


def canonical(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def line_sha(values: tuple[str, ...] | list[str]) -> str:
    return sha(("\n".join(sorted(values)) + "\n").encode())


def strict(raw: bytes) -> Any:
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in items:
            if key in result:
                raise ValueError("DUPLICATE_KEY:" + key)
            result[key] = value
        return result
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=pairs, parse_constant=lambda x: (_ for _ in ()).throw(ValueError("NONFINITE:" + x)))


def git(root: Path, *args: str, binary: bool = False) -> str | bytes:
    return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.STDOUT, text=not binary)


def blob(root: Path, commit: str, path: str) -> bytes | None:
    result = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    return result.stdout if result.returncode == 0 else None


def ancestor(root: Path, old: str, new: str) -> bool:
    return subprocess.run(["git", "merge-base", "--is-ancestor", old, new], cwd=root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0


def commits(root: Path, start: str, end: str, path: str) -> list[str]:
    output = str(git(root, "log", "--format=%H", "--reverse", f"{start}..{end}", "--", path))
    return [line.strip() for line in output.splitlines() if line.strip()]


def diff_sha(root: Path, parent: str, commit: str, path: str) -> str:
    raw = git(root, "diff", "--binary", "--no-ext-diff", parent, commit, "--", path, binary=True)
    assert isinstance(raw, bytes)
    return sha(raw)


def transition(root: Path, start: str, end: str, path: str) -> dict[str, Any]:
    before = blob(root, start, path); after = blob(root, end, path)
    if before is None or after is None:
        raise ValueError("TRANSITION_BLOB_MISSING:" + path)
    touch_rows: list[dict[str, Any]] = []
    for commit in commits(root, start, end, path):
        parent = str(git(root, "rev-parse", commit + "^1")).strip()
        old = blob(root, parent, path); new = blob(root, commit, path)
        if old is None or new is None:
            raise ValueError("TOUCH_BLOB_MISSING:" + path)
        touch_rows.append({"commit_sha": commit, "parent_sha": parent, "before_blob_sha256": sha(old), "after_blob_sha256": sha(new), "diff_sha256": diff_sha(root, parent, commit, path)})
    return {"path": path, "before_blob_sha256": sha(before), "after_blob_sha256": sha(after), "touch_count": len(touch_rows), "touch_commits": touch_rows}


def record_path(fp: str) -> str:
    return RECORD_ROOT + "/pts2-" + fp[4:] + ".json"


def record_id(fp: str) -> str:
    return "V076-POST-TOUCH-SUCCESSOR-V2-" + fp[4:20].upper()


def audit(
    root: Path,
    manifest_path: Path | None = None,
    *,
    artifact_head: str = "HEAD",
    evaluated_binding_head: str = BINDING_HEAD,
) -> dict[str, Any]:
    failures: list[str] = []
    trusted: dict[str, dict[str, Any]] = {}
    artifact = str(git(root, "rev-parse", artifact_head)).strip()
    evaluated = str(git(root, "rev-parse", evaluated_binding_head)).strip()
    if evaluated != BINDING_HEAD:
        failures.append("PTS2I_EVALUATED_BINDING_INVALID")
    if str(git(root, "rev-parse", BINDING_HEAD + "^{tree}")).strip() != BINDING_TREE:
        failures.append("PTS2I_BINDING_TREE_INVALID")
    if not ancestor(root, AUTHORIZATION_BASE_HEAD, BINDING_HEAD) or not ancestor(root, BINDING_HEAD, artifact):
        failures.append("PTS2I_ANCESTRY_INVALID")
    canonical_manifest = (root / MANIFEST_PATH).resolve()
    if manifest_path is not None and manifest_path.resolve() != canonical_manifest:
        failures.append("PTS2I_MANIFEST_PATH_NOT_CANONICAL")
    try:
        manifest_raw = blob(root, artifact, MANIFEST_PATH)
        if manifest_raw is None:
            raise ValueError("COMMITTED_MANIFEST_BLOB_MISSING")
        manifest = strict(manifest_raw)
    except Exception as error:
        return {"status": "FAIL", "failures": ["PTS2I_MANIFEST_UNREADABLE:" + str(error)], "trusted_by_fingerprint": {}}
    if blob(root, BINDING_HEAD, MANIFEST_PATH) is not None or blob(root, BINDING_HEAD, SCHEMA_PATH) is not None:
        failures.append("PTS2I_NOT_APPEND_ONLY")
    schema_raw = blob(root, artifact, SCHEMA_PATH)
    if schema_raw is None:
        return {"status": "FAIL", "failures": ["PTS2I_COMMITTED_SCHEMA_BLOB_MISSING"], "trusted_by_fingerprint": {}}
    schema = strict(schema_raw)
    if sha(schema_raw) != SCHEMA_SHA256:
        failures.append("PTS2I_SCHEMA_SEAL_INVALID")
    if not isinstance(schema, dict) or schema.get("schema_version") != SCHEMA_VERSION or schema.get("target_fingerprints") != list(TARGETS) or schema.get("wildcard_count") != 0 or schema.get("future_failure_auto_revalidation_count") != 0 or schema.get("committed_only_bytes") is not True:
        failures.append("PTS2I_SCHEMA_POLICY_INVALID")
    if not isinstance(manifest, dict) or set(manifest) != MANIFEST_FIELDS:
        failures.append("PTS2I_MANIFEST_FIELD_SET_INVALID")
        bindings: list[Any] = []
    else:
        bindings = manifest.get("record_bindings") if isinstance(manifest.get("record_bindings"), list) else []
        expected_manifest_values = {
            "schema_version": MANIFEST_SCHEMA_VERSION, "manifest_kind": MANIFEST_KIND,
            "manifest_id": MANIFEST_ID, "authorization_id": AUTHORIZATION_ID,
            "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
            "predecessor_authorization_id": PREDECESSOR_AUTHORIZATION_ID,
            "predecessor_authorization_base_head_sha": PREDECESSOR_AUTHORIZATION_BASE_HEAD,
            "schema_path": SCHEMA_PATH, "schema_sha256": SCHEMA_SHA256,
            "predecessor_manifest_path": PREDECESSOR_MANIFEST_PATH,
            "predecessor_manifest_sha256": PREDECESSOR_MANIFEST_SHA256,
            "predecessor_record_count": 2,
            "predecessor_failure_fingerprint_set_sha256": line_sha(TARGETS),
            "predecessor_record_chain_terminal_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
            "revalidation_binding_head_sha": BINDING_HEAD, "revalidation_binding_tree_sha": BINDING_TREE,
            "record_count": 2, "failure_fingerprints": list(TARGETS),
            "failure_fingerprint_set_sha256": line_sha(TARGETS),
            "record_chain_start_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
            "product_paths": list(PRODUCT_PATHS), "authority_source_paths": list(AUTHORITY_PATHS),
            "wildcard_count": 0, "future_failure_auto_revalidation_count": 0,
            "committed_only_bytes": True, "created_at": CREATED_AT, "creator": CREATOR,
        }
        for key, value in expected_manifest_values.items():
            if manifest.get(key) != value:
                failures.append("PTS2I_MANIFEST_VALUE_INVALID:" + key)
        if len(bindings) != 2:
            failures.append("PTS2I_BINDING_COUNT_INVALID")
    predecessor_raw = blob(root, BINDING_HEAD, PREDECESSOR_MANIFEST_PATH)
    if predecessor_raw is None or sha(predecessor_raw) != PREDECESSOR_MANIFEST_SHA256:
        failures.append("PTS2I_PREDECESSOR_MANIFEST_SEAL_INVALID")
        predecessor = {}
    else:
        predecessor = strict(predecessor_raw)
    if blob(root, artifact, PREDECESSOR_MANIFEST_PATH) != predecessor_raw:
        failures.append("PTS2I_PREDECESSOR_COMMITTED_BYTES_DRIFT")
    if not isinstance(predecessor, dict) or predecessor.get("failure_fingerprints") != list(TARGETS) or predecessor.get("record_chain_terminal_sha256") != PREDECESSOR_CHAIN_TERMINAL_SHA256:
        failures.append("PTS2I_PREDECESSOR_IDENTITY_INVALID")
    previous = PREDECESSOR_CHAIN_TERMINAL_SHA256
    projection_digests: dict[str, str] = {}
    for index, fp in enumerate(TARGETS):
        relative = record_path(fp)
        raw = blob(root, artifact, relative)
        if raw is None:
            failures.append("PTS2I_COMMITTED_RECORD_BLOB_MISSING:" + fp)
            previous = "INVALID"
            continue
        if raw != canonical(strict(raw)):
            failures.append("PTS2I_RECORD_COMMITTED_BYTES_INVALID:" + fp)
        record = strict(raw)
        if not isinstance(record, dict) or set(record) != RECORD_FIELDS:
            failures.append("PTS2I_RECORD_FIELD_SET_INVALID:" + fp)
            previous = "INVALID"
            continue
        payload = dict(record); payload.pop("record_payload_sha256", None)
        if record.get("record_payload_sha256") != sha(canonical(payload)):
            failures.append("PTS2I_RECORD_PAYLOAD_INVALID:" + fp)
        fixed = {
            "schema_version": RECORD_SCHEMA_VERSION, "record_kind": RECORD_KIND,
            "revalidation_id": record_id(fp), "authorization_id": AUTHORIZATION_ID,
            "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
            "predecessor_authorization_id": PREDECESSOR_AUTHORIZATION_ID,
            "predecessor_authorization_base_head_sha": PREDECESSOR_AUTHORIZATION_BASE_HEAD,
            "failure_fingerprints": [fp], "failure_fingerprint_set_sha256": line_sha([fp]),
            "predecessor_manifest_path": PREDECESSOR_MANIFEST_PATH,
            "predecessor_manifest_sha256": PREDECESSOR_MANIFEST_SHA256,
            "predecessor_record_chain_terminal_sha256": PREDECESSOR_CHAIN_TERMINAL_SHA256,
            "predecessor_binding_head_sha": PREDECESSOR_BINDING_HEAD,
            "predecessor_binding_tree_sha": PREDECESSOR_BINDING_TREE,
            "revalidation_binding_head_sha": BINDING_HEAD, "revalidation_binding_tree_sha": BINDING_TREE,
            "future_failure_policy": FUTURE_POLICY, "wildcard_count": 0,
            "new_effective_status": "HISTORICAL_DEBT_REVALIDATED_AT_CURRENT_BINDING",
            "previous_revalidation_chain_sha256": previous,
            "created_at": CREATED_AT, "creator": CREATOR,
            "revalidation_reason": "EXACT_POST_TOUCH_CURRENT_BYTES_AND_PROJECTION_SUCCESSOR_V2",
        }
        for key, value in fixed.items():
            if record.get(key) != value:
                failures.append("PTS2I_RECORD_VALUE_INVALID:" + fp + ":" + key)
        pred_bindings = predecessor.get("record_bindings", []) if isinstance(predecessor, dict) else []
        matches = [item for item in pred_bindings if isinstance(item, dict) and item.get("failure_fingerprints") == [fp]]
        if len(matches) != 1:
            failures.append("PTS2I_PREDECESSOR_RECORD_CARDINALITY:" + fp)
            previous = str(record.get("record_payload_sha256", "INVALID")); continue
        pred_path = str(matches[0].get("path", "")); pred_raw = blob(root, BINDING_HEAD, pred_path)
        if pred_raw is None or sha(pred_raw) != matches[0].get("record_sha256") or blob(root, artifact, pred_path) != pred_raw:
            failures.append("PTS2I_PREDECESSOR_RECORD_SEAL_INVALID:" + fp)
            previous = str(record.get("record_payload_sha256", "INVALID")); continue
        pred = strict(pred_raw)
        for key, value in (("predecessor_record_path", pred_path), ("predecessor_record_sha256", sha(pred_raw)), ("predecessor_record_payload_sha256", pred.get("record_payload_sha256")), ("predecessor_revalidation_id", pred.get("revalidation_id"))):
            if record.get(key) != value:
                failures.append("PTS2I_PREDECESSOR_BINDING_INVALID:" + fp + ":" + key)
        original_path = str(pred.get("prior_record_path", "")); original_raw = blob(root, BINDING_HEAD, original_path)
        if original_raw is None or sha(original_raw) != pred.get("prior_record_sha256") or blob(root, artifact, original_path) != original_raw:
            failures.append("PTS2I_ORIGINAL_RECORD_SEAL_INVALID:" + fp)
            previous = str(record.get("record_payload_sha256", "INVALID")); continue
        original = strict(original_raw)
        for key, value in (("original_correction_record_path", original_path), ("original_correction_record_sha256", sha(original_raw)), ("original_correction_record_payload_sha256", original.get("record_payload_sha256")), ("original_correction_id", original.get("correction_id"))):
            if record.get(key) != value:
                failures.append("PTS2I_ORIGINAL_BINDING_INVALID:" + fp + ":" + key)
        identities = original.get("identity_binding_by_failure", {})
        identity = identities.get(fp) if isinstance(identities, dict) else None
        selector = identity.get("authority_selectors") if isinstance(identity, dict) else None
        if not isinstance(selector, dict) or record.get("authority_selectors") != selector or record.get("authority_selector_sha256") != sha(canonical(selector)):
            failures.append("PTS2I_SELECTOR_INVALID:" + fp)
            previous = str(record.get("record_payload_sha256", "INVALID")); continue
        old_projection = convergence.subject_projection(root, PREDECESSOR_BINDING_HEAD, selector)
        current_projection = convergence.subject_projection(root, BINDING_HEAD, selector)
        evaluated_projection = convergence.subject_projection(root, evaluated, selector)
        old_sha = sha(canonical(old_projection)); current_sha = sha(canonical(current_projection))
        if old_projection != pred.get("rebound_subject_projection_by_failure", {}).get(fp) or old_sha != pred.get("rebound_subject_projection_sha256_by_failure", {}).get(fp):
            failures.append("PTS2I_PREDECESSOR_PROJECTION_INVALID:" + fp)
        if record.get("predecessor_subject_projection") != old_projection or record.get("predecessor_subject_projection_sha256") != old_sha:
            failures.append("PTS2I_STORED_PREDECESSOR_PROJECTION_INVALID:" + fp)
        if record.get("current_subject_projection") != current_projection or record.get("current_subject_projection_sha256") != current_sha or evaluated_projection != current_projection:
            failures.append("PTS2I_CURRENT_PROJECTION_INVALID:" + fp)
        changed_sections = sorted(field for field in PROJECTION_FIELDS if old_projection.get(field) != current_projection.get(field))
        if record.get("changed_projection_sections") != changed_sections:
            failures.append("PTS2I_PROJECTION_CHANGE_SET_INVALID:" + fp)
        projection_digests[fp] = current_sha
        derived_product_paths = sorted({
            value for row in current_projection.get("registry_rows", []) if isinstance(row, dict)
            for key in ("path", "owner_path") for value in [row.get(key)]
            if isinstance(value, str) and value and blob(root, BINDING_HEAD, value) is not None
        } | {str(identity.get("current_path", ""))})
        if derived_product_paths != list(PRODUCT_PATHS):
            failures.append("PTS2I_PRODUCT_PATH_SET_INVALID:" + fp)
        expected_product = {path: transition(root, PREDECESSOR_BINDING_HEAD, BINDING_HEAD, path) for path in PRODUCT_PATHS}
        expected_authority = {path: transition(root, PREDECESSOR_BINDING_HEAD, BINDING_HEAD, path) for path in AUTHORITY_PATHS}
        if record.get("product_path_transitions") != expected_product or record.get("authority_path_transitions") != expected_authority:
            failures.append("PTS2I_TRANSITION_PROOF_INVALID:" + fp)
        current_blobs = {path: expected_product[path]["after_blob_sha256"] for path in PRODUCT_PATHS}
        if record.get("current_product_blob_sha256_by_path") != current_blobs:
            failures.append("PTS2I_CURRENT_PRODUCT_BYTES_INVALID:" + fp)
        touch = pred.get("touch_proof", {}); touch_path = str(touch.get("path", "")); touch_commit = str(touch.get("commit_sha", ""))
        touch_parent = str(git(root, "rev-parse", touch_commit + "^1")).strip()
        old = blob(root, touch_parent, touch_path); new = blob(root, touch_commit, touch_path)
        recomputed_touch = {"commit_sha": touch_commit, "parent_sha": touch_parent, "path": touch_path, "before_blob_sha256": sha(old) if old else "MISSING", "after_blob_sha256": sha(new) if new else "MISSING", "diff_sha256": diff_sha(root, touch_parent, touch_commit, touch_path)}
        if commits(root, str(pred.get("prior_binding_head_sha", "")), PREDECESSOR_BINDING_HEAD, touch_path) != [touch_commit] or touch != recomputed_touch or record.get("predecessor_touch_proof") != touch or record.get("predecessor_touch_proof_sha256") != sha(canonical(touch)):
            failures.append("PTS2I_PREDECESSOR_TOUCH_PROOF_INVALID:" + fp)
        binding = bindings[index] if index < len(bindings) and isinstance(bindings[index], dict) else {}
        expected_binding = {"path": relative, "record_sha256": sha(raw), "record_payload_sha256": record.get("record_payload_sha256"), "revalidation_id": record_id(fp), "failure_fingerprints": [fp], "previous_revalidation_chain_sha256": previous, "predecessor_record_path": pred_path, "predecessor_record_sha256": sha(pred_raw), "predecessor_record_payload_sha256": pred.get("record_payload_sha256"), "predecessor_revalidation_id": pred.get("revalidation_id")}
        if set(binding) != BINDING_FIELDS or binding != expected_binding:
            failures.append("PTS2I_MANIFEST_RECORD_BINDING_INVALID:" + fp)
        previous = str(record.get("record_payload_sha256", "INVALID"))
        trusted[fp] = {"allowed_invalidations": record.get("prior_invalidations"), "prior_record_path": original_path, "predecessor_record_path": pred_path, "revalidation_id": record_id(fp), "record_path": relative, "record_payload_sha256": previous, "revalidation_binding_head_sha": BINDING_HEAD, "current_subject_projection_sha256": current_sha}
    listed = str(git(root, "ls-tree", "-r", "--name-only", artifact, "--", RECORD_ROOT))
    actual_members = sorted(line.strip() for line in listed.splitlines() if line.strip())
    if actual_members != sorted(record_path(fp) for fp in TARGETS):
        failures.append("PTS2I_RECORD_MEMBER_SET_INVALID")
    if isinstance(manifest, dict):
        if manifest.get("record_chain_terminal_sha256") != previous or manifest.get("current_projection_sha256_by_failure") != projection_digests:
            failures.append("PTS2I_MANIFEST_AGGREGATE_INVALID")
    for path in PRODUCT_PATHS + AUTHORITY_PATHS:
        if commits(root, BINDING_HEAD, artifact, path):
            failures.append("PTS2I_POST_BINDING_TOUCH:" + path)
        if blob(root, evaluated, path) != blob(root, BINDING_HEAD, path):
            failures.append("PTS2I_EVALUATED_BINDING_BYTES_DRIFT:" + path)
    failures = sorted(set(failures))
    if failures:
        trusted = {}
    return {"status": "PASS" if not failures else "FAIL", "failures": failures, "trusted_by_fingerprint": trusted, "trusted_fingerprint_count": len(trusted), "record_count": 2, "failure_fingerprints": list(TARGETS), "wildcard_count": 0, "future_failure_auto_revalidation_count": 0, "artifact_head": artifact, "evaluated_binding_head": evaluated, "committed_only_bytes": True}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, default=None)
    parser.add_argument("--artifact-head", default="HEAD")
    parser.add_argument("--evaluated-binding-head", default=BINDING_HEAD)
    args = parser.parse_args(argv)
    result = audit(args.project.resolve(), args.manifest.resolve() if args.manifest else None, artifact_head=args.artifact_head, evaluated_binding_head=args.evaluated_binding_head)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
