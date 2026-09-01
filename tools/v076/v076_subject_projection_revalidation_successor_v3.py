#!/usr/bin/env python3
"""Fail-closed validator for the Batch-007 subject-projection successor.

Successor-v3 is deliberately a separate append-only layer.  It rebinds only
the 25 frozen Batch-007 test-only fingerprints after the registry changed the
same components from ``INHERITED`` to ``TEST_ORACLE_ONLY``.  It never edits or
implicitly trusts the v1/v2 layers and it has no wildcard or future-match mode.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, Iterable

try:
    from . import v076_subject_projection_revalidation_successor_v2 as v2
except ImportError:  # pragma: no cover
    import v076_subject_projection_revalidation_successor_v2 as v2


SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v3_schema.v1"
MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v3_manifest.v1"
RECORD_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v3_record.v1"
MANIFEST_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V3_MANIFEST"
RECORD_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V3_RECORD"
SCHEMA_PATH = "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v3_20260830.json"
SUCCESSOR_ROOT = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v3/"
RECORD_ROOT = SUCCESSOR_ROOT + "records/"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
AUTHORIZATION_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
PRIOR_EPOCH_ID = "FULL_CONVERGENCE_20260827"
PRIOR_BATCH_ID = "batch-007"
PRIOR_BATCH_PATH = "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827/batch-007/batch-007-manifest.json"
PRIOR_BATCH_SHA256 = "2f3e33d8933cead2254e6dde73485486dcc33fd3df4fd76ba65d51b06dc3c476"
PRIOR_CORRECTION_ID = "V2-FC-batch-007-01-46b33bba77b3-e584cd4d8b0c-test_only"
PRIOR_RECORD_PATH = "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/batch-007/transition_46b33bba77b3_e584cd4d8b0c_test-only.json"
PRIOR_RECORD_SHA256 = "b4a26dfbbd28195606b9839b8dff9eb3032cfa7401570592805c53e44c25b947"
PRIOR_RECORD_PAYLOAD_SHA256 = "4fb8feda0747d7b082e8aa127c2edb595b08ff6b754c9436e2f904ffd2ea4a4e"
PRIOR_INVALIDATION = "SUBJECT_PROJECTION_CHANGED_INVALID"
PREDECESSOR_MANIFEST_PATH = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v2/manifest.json"
PREDECESSOR_MANIFEST_SHA256 = "3c5a6171a4faa6f297569470b4a5bccd52a7e07cdd72241579ef01123cc89db4"
PREDECESSOR_RECORD_COUNT = 2
PREDECESSOR_CHAIN_TERMINAL_SHA256 = "ab5ec81bf2ca6c4a4a061fa31e104f682d678e15499e88359e40b9dddacca80e"
PREDECESSOR_FINGERPRINT_SET_SHA256 = "3a734ff7c57373b215dd7cb4dd6eb16206def7f4c7e5fc1f26a4a6b09b0a51d3"
REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
SUPERSESSION_PATH = "docs/architecture/V076_SUPERSESSION_MAP.json"
DYNAMIC_REFERENCE_PATH = "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json"
OWNER_MAP_PATH = "docs/architecture/V076_OWNER_REUSE_MAP.md"
CHANGE_CLASS = "TEST_ORACLE_ONLY"
DOMAIN_ID = "current.v075_production_combat_candidate"
OWNER_ID = "component.current.v075_runtime_owner"
FUTURE_POLICY = {"FUTURE_FAILURE_AUTO_REVALIDATION_COUNT": 0, "NEW_FAILURE_REQUIRES_NEW_RECORD": True}
PROJECTION_FIELDS = ("dynamic_reference_rows", "owner_map_lines", "registry_rows", "supersession_rows")


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def line_set_sha(values: Iterable[str]) -> str:
    rendered = sorted(str(value) for value in values)
    return sha256_bytes((("\n".join(rendered) + "\n") if rendered else "").encode())


def _payload_sha(document: dict[str, Any]) -> str:
    payload = dict(document)
    payload.pop("record_payload_sha256", None)
    return sha256_bytes(canonical_bytes(payload))


def _strict_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("DUPLICATE_JSON_KEY")
        result[key] = value
    return result


def strict_json_bytes(raw: bytes) -> Any:
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=_strict_pairs, parse_constant=lambda _: (_ for _ in ()).throw(ValueError("NONFINITE_JSON")))


def strict_json_file(path: Path) -> Any:
    return strict_json_bytes(path.read_bytes())


def _git(root: Path, *args: str, binary: bool = False) -> str | bytes:
    return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.STDOUT, text=not binary)


def _blob(root: Path, commit: str, path: str) -> bytes | None:
    p = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    return p.stdout if p.returncode == 0 else None


def _sha(value: Any, length: int = 64) -> bool:
    return isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{%d}" % length, value))


def _oid(value: Any) -> bool:
    return _sha(value, 40)


def _ancestor(root: Path, old: str, new: str) -> bool:
    return subprocess.run(["git", "merge-base", "--is-ancestor", old, new], cwd=root, check=False).returncode == 0


def _projection(root: Path, commit: str, selector: dict[str, Any]) -> dict[str, Any]:
    return v2.subject_projection(root, commit, selector)


def _projection_sha(value: dict[str, Any]) -> str:
    return sha256_bytes(canonical_bytes(value))


def _added_rows(old: dict[str, Any], new: dict[str, Any]) -> list[dict[str, Any]]:
    old_set = {canonical_bytes(row) for row in old.get("registry_rows", []) if isinstance(row, dict)}
    return sorted([row for row in new.get("registry_rows", []) if isinstance(row, dict) and canonical_bytes(row) not in old_set], key=canonical_bytes)


def _timestamp(value: Any) -> bool:
    return isinstance(value, str) and bool(re.fullmatch(r"20\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ", value))


def _load_prior(root: Path) -> dict[str, Any]:
    document = strict_json_file(root / PRIOR_RECORD_PATH)
    if not isinstance(document, dict):
        raise ValueError("SPR3_PRIOR_RECORD_NOT_OBJECT")
    raw = (root / PRIOR_RECORD_PATH).read_bytes()
    if sha256_bytes(raw) != PRIOR_RECORD_SHA256 or document.get("record_payload_sha256") != PRIOR_RECORD_PAYLOAD_SHA256:
        raise ValueError("SPR3_PRIOR_RECORD_SEAL_DRIFT")
    if document.get("correction_id") != PRIOR_CORRECTION_ID or document.get("failure_fingerprint_set_sha256") != "c58db2b8e7bae5f1eef0e37ebf1dd807e9c188e23109ae769ef6dc0f61ae2511":
        raise ValueError("SPR3_PRIOR_CORRECTION_IDENTITY_DRIFT")
    return document


def _target_rows(root: Path) -> tuple[list[str], dict[str, dict[str, Any]]]:
    prior = _load_prior(root)
    rows = prior.get("identity_binding_by_failure")
    if not isinstance(rows, dict) or len(rows) != 25:
        raise ValueError("SPR3_PRIOR_IDENTITY_COUNT_INVALID")
    fps = sorted(str(value) for value in rows)
    if any(not re.fullmatch(r"V2F-[0-9a-f]{64}", value) for value in fps):
        raise ValueError("SPR3_PRIOR_FINGERPRINT_FORMAT_INVALID")
    if line_set_sha(fps) != "c58db2b8e7bae5f1eef0e37ebf1dd807e9c188e23109ae769ef6dc0f61ae2511":
        raise ValueError("SPR3_PRIOR_FINGERPRINT_SET_DRIFT")
    return fps, {key: value for key, value in rows.items() if isinstance(value, dict)}


def _selector(identity: dict[str, Any]) -> dict[str, Any]:
    component = str(identity.get("current_component_id", ""))
    path = str(identity.get("current_path", ""))
    if not component or not path or identity.get("current_owner_id") != OWNER_ID or identity.get("domain_id") != DOMAIN_ID:
        raise ValueError("SPR3_IDENTITY_BINDING_INVALID")
    return {"component_ids": sorted({component, OWNER_ID}), "dynamic_reference_ids": [], "paths": [path], "retirement_ids": [], "supersession_ids": []}


def expected_record_path(fingerprint: str) -> str:
    return RECORD_ROOT + "spr3-" + fingerprint[4:] + ".json"


def expected_revalidation_id(fingerprint: str) -> str:
    return "V076-SPR3-" + fingerprint[4:20].upper()


def transition_proof(root: Path, change_commit: str, change_parent: str, binding_head: str) -> dict[str, Any]:
    if not _oid(change_commit) or not _oid(change_parent) or not _oid(binding_head):
        raise ValueError("SPR3_TRANSITION_OID_INVALID")
    if str(_git(root, "rev-parse", f"{change_commit}^1")).strip() != change_parent:
        raise ValueError("SPR3_TRANSITION_PARENT_INVALID")
    if not _ancestor(root, change_commit, binding_head) or not _ancestor(root, AUTHORIZATION_BASE_HEAD, change_parent):
        raise ValueError("SPR3_TRANSITION_ANCESTRY_INVALID")
    changed = str(_git(root, "diff", "--name-only", change_parent, change_commit)).splitlines()
    paths = sorted({REGISTRY_PATH, SUPERSESSION_PATH})
    if changed != paths:
        raise ValueError("SPR3_TRANSITION_PATH_SET_INVALID")
    before: dict[str, str] = {}; after: dict[str, str] = {}; diffs: dict[str, str] = {}
    for path in paths:
        b = _blob(root, change_parent, path); a = _blob(root, change_commit, path)
        if b is None or a is None:
            raise ValueError("SPR3_TRANSITION_BLOB_MISSING:" + path)
        diff = _git(root, "diff", "--binary", "--no-ext-diff", change_parent, change_commit, "--", path, binary=True)
        before[path] = sha256_bytes(b); after[path] = sha256_bytes(a); diffs[path] = sha256_bytes(diff)
    return {"change_commit": change_commit, "parent_commit": change_parent, "before_sha256_by_path": before, "after_sha256_by_path": after, "diff_sha256_by_path": diffs, "changed_paths": paths, "baseline_parent_authority_bytes_equal": True}


def _record_shape(document: Any, target: str) -> list[str]:
    if not isinstance(document, dict): return ["SPR3_RECORD_NOT_OBJECT"]
    required = {
        "schema_version", "record_kind", "revalidation_id", "authorization_id", "authorization_base_head_sha", "prior_epoch_id",
        "failure_fingerprints", "failure_fingerprint_set_sha256", "prior_invalidations", "prior_record_path", "prior_record_sha256",
        "prior_record_payload_sha256", "prior_correction_id", "prior_batch_manifest_path", "prior_batch_manifest_sha256", "prior_batch_id",
        "predecessor_manifest_path", "predecessor_manifest_sha256", "predecessor_record_chain_terminal_sha256", "previous_revalidation_chain_sha256",
        "revalidation_binding_head_sha", "revalidation_binding_tree_sha", "authority_selectors", "component_id", "prior_identity_binding",
        "prior_subject_projection", "prior_subject_projection_sha256", "pre_change_subject_projection", "pre_change_subject_projection_sha256",
        "rebound_subject_projection", "rebound_subject_projection_sha256", "live_subject_projection", "live_subject_projection_sha256",
        "changed_projection_sections", "added_registry_rows", "authority_transition_proof", "future_failure_policy", "wildcard_count",
        "new_effective_status", "revalidation_reason", "created_at", "creator", "record_payload_sha256"
    }
    failures: list[str] = []
    if set(document) != required: failures.append("SPR3_RECORD_FIELD_SET_INVALID")
    if document.get("schema_version") != RECORD_SCHEMA_VERSION or document.get("record_kind") != RECORD_KIND: failures.append("SPR3_RECORD_KIND_INVALID")
    if document.get("revalidation_id") != expected_revalidation_id(target): failures.append("SPR3_RECORD_ID_INVALID")
    if document.get("authorization_id") != AUTHORIZATION_ID or document.get("authorization_base_head_sha") != AUTHORIZATION_BASE_HEAD: failures.append("SPR3_AUTHORIZATION_INVALID")
    if document.get("prior_epoch_id") != PRIOR_EPOCH_ID or document.get("prior_batch_id") != PRIOR_BATCH_ID: failures.append("SPR3_PRIOR_EPOCH_INVALID")
    if document.get("failure_fingerprints") != [target] or document.get("failure_fingerprint_set_sha256") != line_set_sha([target]): failures.append("SPR3_FINGERPRINT_INVALID")
    if document.get("prior_invalidations") != [PRIOR_INVALIDATION] or document.get("prior_record_path") != PRIOR_RECORD_PATH or document.get("prior_record_sha256") != PRIOR_RECORD_SHA256 or document.get("prior_record_payload_sha256") != PRIOR_RECORD_PAYLOAD_SHA256 or document.get("prior_correction_id") != PRIOR_CORRECTION_ID: failures.append("SPR3_PRIOR_BINDING_INVALID")
    if document.get("prior_batch_manifest_path") != PRIOR_BATCH_PATH or document.get("prior_batch_manifest_sha256") != PRIOR_BATCH_SHA256: failures.append("SPR3_PRIOR_BATCH_INVALID")
    if document.get("predecessor_manifest_path") != PREDECESSOR_MANIFEST_PATH or document.get("predecessor_manifest_sha256") != PREDECESSOR_MANIFEST_SHA256 or document.get("predecessor_record_chain_terminal_sha256") != PREDECESSOR_CHAIN_TERMINAL_SHA256: failures.append("SPR3_PREDECESSOR_INVALID")
    for field in ("prior_record_sha256", "prior_record_payload_sha256", "prior_batch_manifest_sha256", "predecessor_manifest_sha256", "predecessor_record_chain_terminal_sha256", "previous_revalidation_chain_sha256", "prior_subject_projection_sha256", "pre_change_subject_projection_sha256", "rebound_subject_projection_sha256", "live_subject_projection_sha256", "record_payload_sha256"):
        if not _sha(document.get(field)): failures.append("SPR3_SHA_INVALID:" + field)
    for field in ("revalidation_binding_head_sha", "revalidation_binding_tree_sha"):
        if not _oid(document.get(field)): failures.append("SPR3_OID_INVALID:" + field)
    if document.get("changed_projection_sections") != ["registry_rows"] or document.get("wildcard_count") != 0 or document.get("future_failure_policy") != FUTURE_POLICY or document.get("new_effective_status") != "CORRECTED_HISTORICAL_DEBT": failures.append("SPR3_POLICY_INVALID")
    for field in ("prior_subject_projection", "pre_change_subject_projection", "rebound_subject_projection", "live_subject_projection"):
        if not isinstance(document.get(field), dict) or set(document[field]) != set(PROJECTION_FIELDS): failures.append("SPR3_PROJECTION_INVALID:" + field)
    if document.get("record_payload_sha256") != _payload_sha(document): failures.append("SPR3_PAYLOAD_INVALID")
    if not _timestamp(document.get("created_at")) or not isinstance(document.get("creator"), str) or not document.get("creator"): failures.append("SPR3_CREATED_INVALID")
    return sorted(set(failures))


def validate_manifest_and_records(root: Path, manifest_path: Path, *, evaluated_head: str = "HEAD", stage_dir: Path | None = None) -> dict[str, Any]:
    failures: list[str] = []
    try:
        targets, identities = _target_rows(root)
        manifest = strict_json_file(manifest_path)
    except Exception as error:
        return {"status": "FAIL", "failures": [str(error)], "trusted_by_fingerprint": {}, "review_trusted_by_fingerprint": {}}
    if not isinstance(manifest, dict): return {"status": "FAIL", "failures": ["SPR3_MANIFEST_NOT_OBJECT"], "trusted_by_fingerprint": {}, "review_trusted_by_fingerprint": {}}
    required = {"schema_version", "manifest_kind", "manifest_id", "artifact_root_kind", "authorization_id", "authorization_base_head_sha", "prior_epoch_id", "schema_path", "schema_sha256", "predecessor_manifest_path", "predecessor_manifest_sha256", "predecessor_record_count", "predecessor_record_chain_terminal_sha256", "predecessor_failure_fingerprint_set_sha256", "authority_transition_parent_sha", "authority_transition_commit_sha", "authority_source_paths", "authority_source_before_blob_sha256_by_path", "authority_source_after_blob_sha256_by_path", "authority_source_diff_sha256_by_path", "revalidation_binding_head_sha", "revalidation_binding_tree_sha", "record_count", "failure_fingerprints", "failure_fingerprint_set_sha256", "record_chain_start_sha256", "record_chain_terminal_sha256", "allowed_invalidation", "future_failure_auto_revalidation", "wildcard_count", "created_at", "creator", "record_bindings"}
    if set(manifest) != required: failures.append("SPR3_MANIFEST_FIELD_SET_INVALID")
    if manifest.get("schema_version") != MANIFEST_SCHEMA_VERSION or manifest.get("manifest_kind") != MANIFEST_KIND: failures.append("SPR3_MANIFEST_KIND_INVALID")
    if manifest.get("artifact_root_kind") not in ("EXTERNAL_STAGE_REVIEW", "COMMITTED_SUCCESSOR_ROOT"): failures.append("SPR3_MANIFEST_ROOT_KIND_INVALID")
    if manifest.get("failure_fingerprints") != targets or manifest.get("failure_fingerprint_set_sha256") != line_set_sha(targets) or manifest.get("record_count") != 25: failures.append("SPR3_MANIFEST_TARGET_SET_INVALID")
    if manifest.get("predecessor_manifest_path") != PREDECESSOR_MANIFEST_PATH or manifest.get("predecessor_manifest_sha256") != PREDECESSOR_MANIFEST_SHA256 or manifest.get("predecessor_record_count") != 2 or manifest.get("predecessor_record_chain_terminal_sha256") != PREDECESSOR_CHAIN_TERMINAL_SHA256: failures.append("SPR3_MANIFEST_PREDECESSOR_INVALID")
    if manifest.get("allowed_invalidation") != PRIOR_INVALIDATION or manifest.get("future_failure_auto_revalidation") is not False or manifest.get("wildcard_count") != 0: failures.append("SPR3_MANIFEST_POLICY_INVALID")
    if not _oid(manifest.get("revalidation_binding_head_sha")) or not _oid(manifest.get("revalidation_binding_tree_sha")): failures.append("SPR3_MANIFEST_BINDING_INVALID")
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or len(bindings) != 25: failures.append("SPR3_MANIFEST_BINDING_COUNT_INVALID")
    else:
        paths = []
        previous = PREDECESSOR_CHAIN_TERMINAL_SHA256
        for index, binding in enumerate(bindings):
            if not isinstance(binding, dict) or set(binding) != {"path", "record_sha256", "record_payload_sha256", "revalidation_id", "failure_fingerprints", "previous_revalidation_chain_sha256", "prior_record_path", "prior_record_sha256", "prior_record_payload_sha256", "prior_correction_id"}:
                failures.append("SPR3_BINDING_FIELDS_INVALID"); continue
            fp = binding.get("failure_fingerprints", [None])[0] if isinstance(binding.get("failure_fingerprints"), list) else None
            if fp != targets[index] or binding.get("path") != expected_record_path(targets[index]) or binding.get("previous_revalidation_chain_sha256") != previous: failures.append("SPR3_BINDING_ORDER_INVALID")
            paths.append(binding.get("path")); previous = binding.get("record_payload_sha256", previous)
        if len(set(paths)) != 25: failures.append("SPR3_BINDING_DUPLICATE_PATH")
    trusted: dict[str, dict[str, Any]] = {}
    root_for_artifacts = stage_dir if stage_dir is not None else root / SUCCESSOR_ROOT.rstrip("/")
    previous = PREDECESSOR_CHAIN_TERMINAL_SHA256
    for fp in targets:
        relative = expected_record_path(fp)[len(RECORD_ROOT):]
        path = root_for_artifacts / "records" / relative
        if not path.is_file(): failures.append("SPR3_RECORD_MISSING:" + fp); continue
        try: record = strict_json_file(path)
        except Exception as error: failures.append("SPR3_RECORD_JSON:" + str(error)); continue
        record_failures = _record_shape(record, fp)
        if record.get("component_id") != identities[fp].get("current_component_id"): record_failures.append("SPR3_COMPONENT_BINDING_INVALID:" + fp)
        if record.get("authority_selectors") != _selector(identities[fp]): record_failures.append("SPR3_SELECTOR_INVALID:" + fp)
        if record.get("previous_revalidation_chain_sha256") != previous: record_failures.append("SPR3_CHAIN_INVALID:" + fp)
        binding = bindings[targets.index(fp)] if isinstance(bindings, list) and len(bindings) == 25 else {}
        if isinstance(binding, dict):
            raw = path.read_bytes()
            for key, actual in (("record_sha256", sha256_bytes(raw)), ("record_payload_sha256", record.get("record_payload_sha256")), ("revalidation_id", record.get("revalidation_id")), ("failure_fingerprints", [fp]), ("previous_revalidation_chain_sha256", previous), ("prior_record_path", PRIOR_RECORD_PATH), ("prior_record_sha256", PRIOR_RECORD_SHA256), ("prior_record_payload_sha256", PRIOR_RECORD_PAYLOAD_SHA256), ("prior_correction_id", PRIOR_CORRECTION_ID)):
                if binding.get(key) != actual: record_failures.append("SPR3_MANIFEST_RECORD_BINDING_INVALID:" + fp + ":" + key)
        if record_failures:
            failures.extend(record_failures)
        else:
            trusted[fp] = {"revalidation_id": record.get("revalidation_id"), "record_payload_sha256": record.get("record_payload_sha256"), "prior_record_path": PRIOR_RECORD_PATH}
        previous = record.get("record_payload_sha256", previous)
    status = "PASS" if not failures else "FAIL"
    committed_trust = trusted if stage_dir is None and status == "PASS" else {}
    review_trust = trusted if stage_dir is not None and status == "PASS" else {}
    result = {
        "status": status,
        "mode": "STAGE_REVIEW" if stage_dir is not None else "COMMITTED",
        "stage_only": stage_dir is not None,
        "failures": sorted(set(failures)),
        "trusted_by_fingerprint": committed_trust,
        "review_trusted_by_fingerprint": review_trust,
        "trusted_fingerprint_count": len(committed_trust),
        "review_trusted_fingerprint_count": len(review_trust),
        "record_count": len(trusted),
        "fingerprints": sorted(trusted),
    }
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--stage-dir", type=Path, default=None)
    parser.add_argument("--evaluated-head", default="HEAD")
    args = parser.parse_args(argv)
    result = validate_manifest_and_records(args.project.resolve(), args.manifest.resolve(), evaluated_head=args.evaluated_head, stage_dir=args.stage_dir.resolve() if args.stage_dir else None)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
