#!/usr/bin/env python3
"""Append-only successor for the original 82-record SPR epoch.

This successor is intentionally narrow.  It revalidates only the 48 records
whose selector projection changed in the Batch-009 registry transition and
explicitly seals the remaining 34 predecessor records as preserved.  The
original v1 records and manifest are never rewritten.
"""
from __future__ import annotations

import argparse, hashlib, json, re, subprocess
from pathlib import Path
from typing import Any

try:
    from . import v076_subject_projection_revalidation_successor_v3 as v3
except ImportError:  # pragma: no cover
    import v076_subject_projection_revalidation_successor_v3 as v3

AUTHORIZATION_ID = v3.AUTHORIZATION_ID
AUTHORIZATION_BASE_HEAD = v3.AUTHORIZATION_BASE_HEAD
PRIOR_EPOCH_ID = v3.PRIOR_EPOCH_ID
SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v4_schema.v1"
MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v4_manifest.v1"
RECORD_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.subject_projection_revalidation_successor_v4_record.v1"
MANIFEST_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V4_MANIFEST"
RECORD_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V4_RECORD"
MANIFEST_ID = "V076-SUBJECT-PROJECTION-REVALIDATION-SUCCESSOR-V4-20260830"
SCHEMA_PATH = "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v4_20260830.json"
SUCCESSOR_ROOT = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v4/"
RECORD_ROOT = SUCCESSOR_ROOT + "records/"
PREDECESSOR_MANIFEST_PATH = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation/manifest.json"
PREDECESSOR_MANIFEST_SHA256 = "dff148179980c4e49f277a516bf7f1d0670f4d8b02a40e0f95b077ed92e0967e"
PREDECESSOR_BINDING_HEAD = "e73e033f915ad420d8d15d78c5bf5dab68b2e5cc"
TRANSITION_PARENT = "9926d3955da7c14a292259e270f2ac2ff7559dcd"
TRANSITION_COMMIT = "6209465da4a9ca0c1cb6f0db0cd8a088bd63e793"
REGISTRY_PATH = v3.REGISTRY_PATH
SUPERSESSION_PATH = v3.SUPERSESSION_PATH
OWNER_MAP_PATH = v3.OWNER_MAP_PATH
DYNAMIC_REFERENCE_PATH = v3.DYNAMIC_REFERENCE_PATH
AUTHORITY_PATHS = (REGISTRY_PATH, SUPERSESSION_PATH)
ALLOWED_INVALIDATION = "SUBJECT_PROJECTION_CHANGED_INVALID"
FUTURE_POLICY = {"FUTURE_FAILURE_AUTO_REVALIDATION_COUNT": 0, "NEW_FAILURE_REQUIRES_NEW_RECORD": True}
PROJECTION_FIELDS = ("dynamic_reference_rows", "owner_map_lines", "registry_rows", "supersession_rows")

MANIFEST_FIELDS = frozenset("""schema_version manifest_kind manifest_id artifact_root_kind authorization_id authorization_base_head_sha prior_epoch_id schema_path schema_sha256 predecessor_manifest_path predecessor_manifest_sha256 predecessor_record_count predecessor_record_chain_terminal_sha256 predecessor_failure_fingerprint_set_sha256 authority_transition_parent_sha authority_transition_commit_sha authority_source_paths authority_source_before_blob_sha256_by_path authority_source_after_blob_sha256_by_path authority_source_diff_sha256_by_path revalidation_binding_head_sha revalidation_binding_tree_sha record_count failure_fingerprints failure_fingerprint_set_sha256 preserved_failure_fingerprints preserved_failure_fingerprint_set_sha256 preserved_record_count record_chain_start_sha256 record_chain_terminal_sha256 allowed_invalidation future_failure_auto_revalidation wildcard_count created_at creator record_bindings""".split())
RECORD_FIELDS = frozenset("""schema_version record_kind revalidation_id authorization_id authorization_base_head_sha prior_epoch_id failure_fingerprints failure_fingerprint_set_sha256 prior_invalidations prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id prior_batch_manifest_path prior_batch_manifest_sha256 predecessor_revalidation_record_path predecessor_revalidation_record_sha256 predecessor_revalidation_record_payload_sha256 predecessor_revalidation_id previous_revalidation_chain_sha256 revalidation_binding_head_sha revalidation_binding_tree_sha authority_selectors component_id prior_identity_binding prior_subject_projection prior_subject_projection_sha256 pre_change_subject_projection pre_change_subject_projection_sha256 rebound_subject_projection rebound_subject_projection_sha256 live_subject_projection live_subject_projection_sha256 changed_projection_sections changed_projection_component_ids authority_transition_proof bound_product_blob_sha256_by_path future_failure_policy wildcard_count new_effective_status revalidation_reason created_at creator record_payload_sha256""".split())
BINDING_FIELDS = frozenset("""path record_sha256 record_payload_sha256 revalidation_id failure_fingerprints prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id predecessor_revalidation_record_path predecessor_revalidation_record_sha256 predecessor_revalidation_record_payload_sha256 predecessor_revalidation_id previous_revalidation_chain_sha256""".split())

def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()

def sha256_bytes(value: bytes) -> str: return hashlib.sha256(value).hexdigest()
def line_set_sha(values: list[str]) -> str: return sha256_bytes(("\n".join(sorted(values)) + "\n").encode())
def payload_sha(value: dict[str, Any]) -> str:
    body = dict(value); body.pop("record_payload_sha256", None); return sha256_bytes(canonical_bytes(body))
def strict(raw: bytes) -> Any: return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=_pairs, parse_constant=lambda _: (_ for _ in ()).throw(ValueError("NONFINITE_JSON")))
def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for k, v in pairs:
        if k in out: raise ValueError("DUPLICATE_JSON_KEY")
        out[k] = v
    return out
def _git(root: Path, *args: str, binary: bool = False) -> str | bytes:
    p = subprocess.run(["git", "--no-replace-objects", "-C", str(root), *args], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if p.returncode: raise ValueError(p.stderr.decode("utf-8", "replace").strip())
    return p.stdout if binary else p.stdout.decode().strip()
def blob(root: Path, ref: str, path: str) -> bytes | None:
    p = subprocess.run(["git", "--no-replace-objects", "-C", str(root), "cat-file", "blob", f"{ref}:{path}"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    return p.stdout if p.returncode == 0 else None
def document(root: Path, ref: str, path: str) -> tuple[dict[str, Any], bytes]:
    raw = blob(root, ref, path)
    if raw is None: raise ValueError("MISSING_BLOB:" + path)
    value = strict(raw)
    if not isinstance(value, dict): raise ValueError("DOCUMENT_NOT_OBJECT:" + path)
    return value, raw
def projection(root: Path, ref: str, selector: dict[str, Any]) -> dict[str, Any]:
    return v3._projection(root, ref, selector)
def expected_record_path(fp: str) -> str: return RECORD_ROOT + "spr4-" + fp[4:] + ".json"
def expected_id(fp: str) -> str: return "V076-SPR4-" + fp[4:20].upper()

def transition_proof(root: Path) -> dict[str, Any]:
    if str(_git(root, "rev-parse", f"{TRANSITION_COMMIT}^1")) != TRANSITION_PARENT:
        raise ValueError("SPR4_TRANSITION_PARENT_INVALID")
    changed = str(_git(root, "diff", "--name-only", TRANSITION_PARENT, TRANSITION_COMMIT)).splitlines()
    if changed != sorted(AUTHORITY_PATHS): raise ValueError("SPR4_TRANSITION_PATH_SET_INVALID")
    before: dict[str, str] = {}; after: dict[str, str] = {}; diffs: dict[str, str] = {}
    for path in AUTHORITY_PATHS:
        b = blob(root, TRANSITION_PARENT, path); a = blob(root, TRANSITION_COMMIT, path)
        if b is None or a is None: raise ValueError("SPR4_TRANSITION_BLOB_MISSING:" + path)
        before[path] = sha256_bytes(b); after[path] = sha256_bytes(a)
        diffs[path] = sha256_bytes(_git(root, "diff", "--binary", "--no-ext-diff", TRANSITION_PARENT, TRANSITION_COMMIT, "--", path, binary=True))
    return {"commit_sha": TRANSITION_COMMIT, "parent_sha": TRANSITION_PARENT, "before_sha256_by_path": before, "after_sha256_by_path": after, "diff_sha256_by_path": diffs}

def target_sets(root: Path, evaluated_head: str) -> tuple[list[str], list[str], dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    pred, raw = document(root, evaluated_head, PREDECESSOR_MANIFEST_PATH)
    if sha256_bytes(raw) != PREDECESSOR_MANIFEST_SHA256: raise ValueError("SPR4_PREDECESSOR_MANIFEST_SHA_INVALID")
    fps = list(pred.get("failure_fingerprints", [])); rows: dict[str, dict[str, Any]] = {}
    for binding in pred.get("record_bindings", []):
        if not isinstance(binding, dict): continue
        fp = binding.get("failure_fingerprints", [None])[0]
        if isinstance(fp, str):
            rec, raw = document(root, evaluated_head, str(binding.get("path")))
            if sha256_bytes(raw) != binding.get("record_sha256") or rec.get("record_payload_sha256") != binding.get("record_payload_sha256"):
                raise ValueError("SPR4_PREDECESSOR_RECORD_SEAL_INVALID:" + fp)
            rec = dict(rec)
            rec["_v4_predecessor_path"] = binding.get("path")
            rec["_v4_predecessor_sha256"] = binding.get("record_sha256")
            rec["_v4_predecessor_payload_sha256"] = binding.get("record_payload_sha256")
            rows[fp] = rec
    drift: list[str] = []; preserved: list[str] = []
    for fp in sorted(fps):
        rec = rows[fp]; sel = rec["authority_selectors"]
        pre = projection(root, TRANSITION_PARENT, sel); reb = projection(root, TRANSITION_COMMIT, sel); live = projection(root, evaluated_head, sel)
        if reb != live: raise ValueError("SPR4_LIVE_PROJECTION_DRIFT:" + fp)
        (drift if pre != reb else preserved).append(fp)
    if len(drift) != 48 or len(preserved) != 34: raise ValueError(f"SPR4_TARGET_CARDINALITY:{len(drift)}:{len(preserved)}")
    return drift, preserved, rows, pred

def _record(root: Path, fp: str, prior: dict[str, Any], previous: str, head: str, tree: str, proof: dict[str, Any], created_at: str) -> dict[str, Any]:
    sel = prior["authority_selectors"]; pre = projection(root, TRANSITION_PARENT, sel); reb = projection(root, TRANSITION_COMMIT, sel); live = projection(root, head, sel)
    if reb != live: raise ValueError("SPR4_REBOUND_LIVE_PROJECTION_DRIFT:" + fp)
    changed = [k for k in PROJECTION_FIELDS if pre[k] != reb[k]]
    if changed != ["registry_rows"]: raise ValueError("SPR4_CHANGE_SCOPE_INVALID:" + fp)
    comp = str(prior["component_id"]); old_rows = {r.get("component_id"): r for r in pre["registry_rows"]}; new_rows = {r.get("component_id"): r for r in reb["registry_rows"]}
    changed_components = sorted(k for k in set(old_rows)|set(new_rows) if old_rows.get(k) != new_rows.get(k))
    if changed_components != ["component.current.v075_runtime_owner"]: raise ValueError("SPR4_COMPONENT_CHANGE_INVALID:" + fp)
    path = str(prior["authority_selectors"]["paths"][0]); old_blob = blob(root, PREDECESSOR_BINDING_HEAD, path)
    if old_blob is None: raise ValueError("SPR4_PRODUCT_BLOB_MISSING:" + fp)
    bound = {path: sha256_bytes(old_blob)}
    identity = {"component_id": comp, "authority_selectors": sel, "source_correction_record_path": prior.get("prior_record_path", ""), "source_correction_id": prior.get("prior_correction_id", "")}
    out: dict[str, Any] = {"schema_version": RECORD_SCHEMA_VERSION, "record_kind": RECORD_KIND, "revalidation_id": expected_id(fp), "authorization_id": AUTHORIZATION_ID, "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD, "prior_epoch_id": PRIOR_EPOCH_ID, "failure_fingerprints": [fp], "failure_fingerprint_set_sha256": line_set_sha([fp]), "prior_invalidations": [ALLOWED_INVALIDATION], "prior_record_path": prior.get("prior_record_path", ""), "prior_record_sha256": prior.get("prior_record_sha256", ""), "prior_record_payload_sha256": prior.get("prior_record_payload_sha256", ""), "prior_correction_id": prior.get("prior_correction_id", ""), "prior_batch_manifest_path": prior.get("correction_batch_manifest_path", ""), "prior_batch_manifest_sha256": prior.get("correction_batch_manifest_sha256", ""), "predecessor_revalidation_record_path": prior["_v4_predecessor_path"], "predecessor_revalidation_record_sha256": prior["_v4_predecessor_sha256"], "predecessor_revalidation_record_payload_sha256": prior["_v4_predecessor_payload_sha256"], "predecessor_revalidation_id": prior.get("revalidation_id", ""), "previous_revalidation_chain_sha256": previous, "revalidation_binding_head_sha": head, "revalidation_binding_tree_sha": tree, "authority_selectors": sel, "component_id": comp, "prior_identity_binding": identity, "prior_subject_projection": projection(root, PREDECESSOR_BINDING_HEAD, sel), "prior_subject_projection_sha256": sha256_bytes(canonical_bytes(projection(root, PREDECESSOR_BINDING_HEAD, sel))), "pre_change_subject_projection": pre, "pre_change_subject_projection_sha256": sha256_bytes(canonical_bytes(pre)), "rebound_subject_projection": reb, "rebound_subject_projection_sha256": sha256_bytes(canonical_bytes(reb)), "live_subject_projection": live, "live_subject_projection_sha256": sha256_bytes(canonical_bytes(live)), "changed_projection_sections": changed, "changed_projection_component_ids": changed_components, "authority_transition_proof": proof, "bound_product_blob_sha256_by_path": bound, "future_failure_policy": FUTURE_POLICY, "wildcard_count": 0, "new_effective_status": "CORRECTED_HISTORICAL_DEBT", "revalidation_reason": "REGISTRY_AUTHORITY_SOURCE_METADATA_ONLY_SUCCESSOR_V4", "created_at": created_at, "creator": "v076_subject_projection_revalidation_successor_v4_builder.py"}
    out["record_payload_sha256"] = payload_sha(out); return out

def validate(root: Path, manifest_path: Path, evaluated_head: str, stage_dir: Path | None = None) -> dict[str, Any]:
    failures: list[str] = []; trusted: dict[str, dict[str, Any]] = {}
    try:
        if stage_dir is None:
            m, mraw = document(root, evaluated_head, str(manifest_path.resolve().relative_to(root.resolve())).replace("\\", "/"))
        else:
            mraw = manifest_path.read_bytes(); m = strict(mraw)
        drift, preserved, rows, pred = target_sets(root, evaluated_head)
    except Exception as e: return {"status": "FAIL", "failures": [str(e)], "trusted_by_fingerprint": {}, "record_count": 0}
    if set(m) != MANIFEST_FIELDS: failures.append("SPR4_MANIFEST_FIELD_SET_INVALID")
    if m.get("manifest_kind") != MANIFEST_KIND or m.get("schema_version") != MANIFEST_SCHEMA_VERSION: failures.append("SPR4_MANIFEST_KIND_INVALID")
    if m.get("predecessor_manifest_path") != PREDECESSOR_MANIFEST_PATH or m.get("predecessor_manifest_sha256") != PREDECESSOR_MANIFEST_SHA256: failures.append("SPR4_PREDECESSOR_INVALID")
    if m.get("failure_fingerprints") != drift or m.get("preserved_failure_fingerprints") != preserved or m.get("record_count") != 48 or m.get("preserved_record_count") != 34: failures.append("SPR4_TARGET_SET_INVALID")
    if m.get("failure_fingerprint_set_sha256") != line_set_sha(drift) or m.get("preserved_failure_fingerprint_set_sha256") != line_set_sha(preserved): failures.append("SPR4_TARGET_HASH_INVALID")
    if m.get("authority_transition_parent_sha") != TRANSITION_PARENT or m.get("authority_transition_commit_sha") != TRANSITION_COMMIT: failures.append("SPR4_TRANSITION_INVALID")
    if m.get("revalidation_binding_head_sha") != evaluated_head or m.get("revalidation_binding_tree_sha") != str(_git(root, "rev-parse", f"{evaluated_head}^{{tree}}")): failures.append("SPR4_BINDING_INVALID")
    if m.get("schema_sha256") != sha256_bytes((root / SCHEMA_PATH).read_bytes()): failures.append("SPR4_SCHEMA_SHA_INVALID")
    previous = str(m.get("record_chain_start_sha256", "")); bindings = m.get("record_bindings", [])
    if not isinstance(bindings, list) or len(bindings) != 48: failures.append("SPR4_BINDING_COUNT_INVALID"); bindings = []
    for i, fp in enumerate(drift):
        try:
            if stage_dir is None: rec, raw = document(root, evaluated_head, expected_record_path(fp))
            else:
                raw = (stage_dir / "records" / Path(expected_record_path(fp)).name).read_bytes(); rec = strict(raw)
            sel = rec["authority_selectors"]; pre = projection(root, TRANSITION_PARENT, sel); reb = projection(root, TRANSITION_COMMIT, sel); live = projection(root, evaluated_head, sel)
        except Exception as e: failures.append("SPR4_RECORD_UNREADABLE:" + fp); continue
        local: list[str] = []
        if set(rec) != RECORD_FIELDS: local.append("RECORD_FIELD_SET")
        if rec.get("failure_fingerprints") != [fp] or rec.get("record_kind") != RECORD_KIND or rec.get("revalidation_id") != expected_id(fp): local.append("RECORD_IDENTITY")
        if rec.get("previous_revalidation_chain_sha256") != previous: local.append("RECORD_CHAIN")
        if rec.get("record_payload_sha256") != payload_sha(rec): local.append("RECORD_PAYLOAD")
        if rec.get("pre_change_subject_projection") != pre or rec.get("rebound_subject_projection") != reb or rec.get("live_subject_projection") != live or reb != live: local.append("RECORD_PROJECTION")
        if rec.get("changed_projection_sections") != ["registry_rows"] or rec.get("changed_projection_component_ids") != ["component.current.v075_runtime_owner"]: local.append("RECORD_CHANGE_SCOPE")
        if i < len(bindings):
            b = bindings[i]
            if set(b) != BINDING_FIELDS or b.get("path") != expected_record_path(fp) or b.get("record_sha256") != sha256_bytes(raw) or b.get("record_payload_sha256") != rec.get("record_payload_sha256") or b.get("previous_revalidation_chain_sha256") != previous: local.append("MANIFEST_BINDING")
        if local: failures.extend(x + ":" + fp for x in local)
        else: trusted[fp] = {"allowed_invalidations": [ALLOWED_INVALIDATION], "prior_record_path": rec.get("prior_record_path", ""), "revalidation_id": rec.get("revalidation_id", ""), "record_path": expected_record_path(fp), "revalidation_binding_head_sha": evaluated_head}
        previous = str(rec.get("record_payload_sha256", previous))
    # Preserved rows are rechecked, but no duplicate successor record is emitted.
    for fp in preserved:
        rec = rows[fp]; sel = rec["authority_selectors"]
        if projection(root, TRANSITION_PARENT, sel) != projection(root, evaluated_head, sel): failures.append("SPR4_PRESERVED_PROJECTION_DRIFT:" + fp)
        else: trusted[fp] = {"allowed_invalidations": [ALLOWED_INVALIDATION], "prior_record_path": rec.get("prior_record_path", ""), "revalidation_id": rec.get("revalidation_id", ""), "record_path": "", "revalidation_binding_head_sha": evaluated_head}
    if previous != m.get("record_chain_terminal_sha256"): failures.append("SPR4_CHAIN_TERMINAL_INVALID")
    if m.get("record_chain_start_sha256") != pred.get("record_chain_terminal_sha256"): failures.append("SPR4_CHAIN_START_INVALID")
    if failures: trusted = {}
    committed = trusted if stage_dir is None else {}
    review = trusted if stage_dir is not None else {}
    return {"status": "PASS" if not failures else "FAIL", "mode": "COMMITTED" if stage_dir is None else "STAGE_REVIEW", "failures": sorted(set(failures)), "trusted_by_fingerprint": committed, "review_trusted_by_fingerprint": review, "record_count": len(trusted), "drift_record_count": 48, "preserved_record_count": 34}

def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(); p.add_argument("--project", type=Path, default=Path.cwd()); p.add_argument("--manifest", type=Path, required=True); p.add_argument("--evaluated-head", required=True); p.add_argument("--stage-dir", type=Path); a = p.parse_args(argv); result = validate(a.project.resolve(), a.manifest.resolve(), a.evaluated_head, a.stage_dir.resolve() if a.stage_dir else None); print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2)); return 0 if result["status"] == "PASS" else 1
if __name__ == "__main__": raise SystemExit(main())
