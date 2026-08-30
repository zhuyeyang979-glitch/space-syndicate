#!/usr/bin/env python3
"""Primary-free audit for the exact two-record SPR successor-v5."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


AUTH = "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
BASE = "d701a81dce693b584d52fbfca3e0e78b521ad775"
EPOCH = "FULL_CONVERGENCE_20260827"
KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V5_MANIFEST"
RKIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V5_RECORD"
PRE_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V2_MANIFEST"
PRE_RKIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V2_RECORD"
ROOT = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v5/"
PRE = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v2/manifest.json"
PRE_SHA = "3c5a6171a4faa6f297569470b4a5bccd52a7e07cdd72241579ef01123cc89db4"
PRE_HEAD = "f7404bb7b3670d72214541acc6f277ad363b4279"
PRE_CHAIN = "ab5ec81bf2ca6c4a4a061fa31e104f682d678e15499e88359e40b9dddacca80e"
PRE_SET = "3a734ff7c57373b215dd7cb4dd6eb16206def7f4c7e5fc1f26a4a6b09b0a51d3"
PARENT = "9926d3955da7c14a292259e270f2ac2ff7559dcd"
CHANGE = "6209465da4a9ca0c1cb6f0db0cd8a088bd63e793"
REG = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
SUP = "docs/architecture/V076_SUPERSESSION_MAP.json"
DYN = "docs/architecture/V076_DYNAMIC_REFERENCE_MANIFEST.json"
OWNER = "docs/architecture/V076_OWNER_REUSE_MAP.md"
SCHEMA = "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v5_20260830.json"
INVALIDATION = "SUBJECT_PROJECTION_CHANGED_INVALID"
POLICY = {
    "FUTURE_FAILURE_AUTO_REVALIDATION_COUNT": 0,
    "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
}
CHANGED_COMPONENTS = ["component.current.v075_runtime_owner"]

RECORD_FIELDS = frozenset(
    """schema_version record_kind revalidation_id authorization_id authorization_base_head_sha prior_epoch_id failure_fingerprints failure_fingerprint_set_sha256 prior_invalidations prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id prior_batch_manifest_path prior_batch_manifest_sha256 predecessor_revalidation_record_path predecessor_revalidation_record_sha256 predecessor_revalidation_record_payload_sha256 predecessor_revalidation_id previous_revalidation_chain_sha256 revalidation_binding_head_sha revalidation_binding_tree_sha authority_selectors component_id prior_identity_binding prior_subject_projection prior_subject_projection_sha256 pre_change_subject_projection pre_change_subject_projection_sha256 rebound_subject_projection rebound_subject_projection_sha256 live_subject_projection live_subject_projection_sha256 changed_projection_sections changed_projection_component_ids authority_transition_proof bound_product_blob_sha256_by_path future_failure_policy wildcard_count new_effective_status revalidation_reason created_at creator record_payload_sha256""".split()
)
BINDING_FIELDS = frozenset(
    """path record_sha256 record_payload_sha256 revalidation_id failure_fingerprints prior_record_path prior_record_sha256 prior_record_payload_sha256 prior_correction_id predecessor_revalidation_record_path predecessor_revalidation_record_sha256 predecessor_revalidation_record_payload_sha256 predecessor_revalidation_id previous_revalidation_chain_sha256""".split()
)


def canonical(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
        + "\n"
    ).encode()


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def set_sha(values: list[str]) -> str:
    return sha(("\n".join(sorted(values)) + "\n").encode())


def pairs(rows: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in rows:
        if key in result:
            raise ValueError("DUPLICATE_JSON_KEY")
        result[key] = value
    return result


def strict(raw: bytes) -> Any:
    return json.loads(
        raw.decode("utf-8-sig"),
        object_pairs_hook=pairs,
        parse_constant=lambda _: (_ for _ in ()).throw(ValueError("NONFINITE_JSON")),
    )


def git(root: Path, *args: str, binary: bool = False) -> str | bytes:
    process = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode:
        raise ValueError("GIT_FAILURE:" + process.stderr.decode("utf-8", "replace").strip())
    return process.stdout if binary else process.stdout.decode().strip()


def blob(root: Path, ref: str, path: str) -> bytes:
    return git(root, "cat-file", "blob", f"{ref}:{path}", binary=True)


def doc(root: Path, ref: str, path: str) -> tuple[dict[str, Any], bytes]:
    raw = blob(root, ref, path)
    value = strict(raw)
    if not isinstance(value, dict):
        raise ValueError("NOT_OBJECT:" + path)
    return value, raw


def projection(root: Path, ref: str, selector: dict[str, Any]) -> dict[str, Any]:
    registry = strict(blob(root, ref, REG))
    supersession = strict(blob(root, ref, SUP))
    dynamic = strict(blob(root, ref, DYN))
    owner = blob(root, ref, OWNER).decode("utf-8-sig", "replace")
    component_ids = set(selector["component_ids"])
    paths = set(selector["paths"])
    registry_rows: list[dict[str, Any]] = []
    for kind in ("component_inventory", "historical_identity_backfill"):
        for row in registry.get(kind, []):
            if isinstance(row, dict) and (
                row.get("component_id") in component_ids or row.get("path") in paths
            ):
                copied = dict(row)
                copied["authority_source_kind"] = kind
                registry_rows.append(copied)
    supersession_rows: list[dict[str, Any]] = []
    supersession_ids = set(selector["supersession_ids"])
    retirement_ids = set(selector["retirement_ids"])
    for kind in ("entries", "retirement_entries"):
        for row in supersession.get(kind, []):
            if isinstance(row, dict) and (
                row.get("supersession_id") in supersession_ids
                or row.get("retirement_id") in retirement_ids
            ):
                supersession_rows.append(row)
    dynamic_ids = set(selector["dynamic_reference_ids"])
    dynamic_rows = [
        row
        for row in dynamic.get("entries", [])
        if isinstance(row, dict) and row.get("dynamic_reference_id") in dynamic_ids
    ]
    needles = sorted(
        {str(value) for values in selector.values() for value in values if value}
    )
    owner_lines = sorted(
        {line.rstrip() for line in owner.splitlines() if any(value in line for value in needles)}
    )
    return {
        "dynamic_reference_rows": sorted(dynamic_rows, key=canonical),
        "owner_map_lines": owner_lines,
        "registry_rows": sorted(registry_rows, key=canonical),
        "supersession_rows": sorted(supersession_rows, key=canonical),
    }


def record_path(fingerprint: str) -> str:
    return ROOT + "records/spr5-" + fingerprint[4:] + ".json"


def expected_id(fingerprint: str) -> str:
    return "V076-SPR5-" + fingerprint[4:20].upper()


def changed_components(before: dict[str, Any], after: dict[str, Any]) -> list[str]:
    old = {row.get("component_id"): row for row in before["registry_rows"]}
    new = {row.get("component_id"): row for row in after["registry_rows"]}
    return sorted(key for key in set(old) | set(new) if old.get(key) != new.get(key))


def transition(root: Path) -> dict[str, Any]:
    if git(root, "rev-parse", f"{CHANGE}^1") != PARENT:
        raise ValueError("SPR5I_TRANSITION_PARENT_INVALID")
    if git(root, "diff", "--name-only", PARENT, CHANGE).splitlines() != sorted([REG, SUP]):
        raise ValueError("SPR5I_TRANSITION_PATH_SET_INVALID")
    before: dict[str, str] = {}
    after: dict[str, str] = {}
    diffs: dict[str, str] = {}
    for path in (REG, SUP):
        before[path] = sha(blob(root, PARENT, path))
        after[path] = sha(blob(root, CHANGE, path))
        diffs[path] = sha(
            git(
                root,
                "diff",
                "--binary",
                "--no-ext-diff",
                PARENT,
                CHANGE,
                "--",
                path,
                binary=True,
            )
        )
    return {
        "commit_sha": CHANGE,
        "parent_sha": PARENT,
        "before_sha256_by_path": before,
        "after_sha256_by_path": after,
        "diff_sha256_by_path": diffs,
    }


def empty(mode: str, failure: str, artifact: str = "", evaluated: str = "") -> dict[str, Any]:
    return {
        "status": "FAIL",
        "mode": mode,
        "failures": [failure],
        "trusted_by_fingerprint": {},
        "review_trusted_by_fingerprint": {},
        "record_count": 0,
        "independent": True,
        "artifact_head_sha": artifact,
        "evaluated_head_sha": evaluated,
    }


def audit(
    root: Path,
    manifest_path: Path,
    evaluated_head: str,
    stage_dir: Path | None = None,
    artifact_head: str | None = None,
) -> dict[str, Any]:
    failures: list[str] = []
    trusted: dict[str, dict[str, Any]] = {}
    mode = "COMMITTED" if stage_dir is None else "STAGE_REVIEW"
    artifact_ref = ""
    try:
        evaluated_ref = str(git(root, "rev-parse", f"{evaluated_head}^{{commit}}"))
        evaluated_tree = str(git(root, "rev-parse", f"{evaluated_ref}^{{tree}}"))
        if stage_dir is None:
            artifact_ref = str(git(root, "rev-parse", f"{artifact_head or 'HEAD'}^{{commit}}"))
            relative = str(manifest_path.resolve().relative_to(root.resolve())).replace("\\", "/")
            if relative != ROOT + "manifest.json":
                raise ValueError("SPR5I_MANIFEST_PATH_INVALID")
            manifest, _ = doc(root, artifact_ref, ROOT + "manifest.json")
            schema_raw = blob(root, artifact_ref, SCHEMA)
        else:
            manifest = strict(manifest_path.read_bytes())
            schema_raw = (root / SCHEMA).read_bytes()
        if not isinstance(manifest, dict):
            raise ValueError("SPR5I_MANIFEST_NOT_OBJECT")
    except Exception as error:
        return empty(mode, str(error), artifact_ref)
    if (
        manifest.get("revalidation_binding_head_sha") != evaluated_ref
        or manifest.get("revalidation_binding_tree_sha") != evaluated_tree
    ):
        return empty(mode, "SPR5I_BINDING_INVALID", artifact_ref, evaluated_ref)
    try:
        predecessor, predecessor_raw = doc(root, evaluated_ref, PRE)
        proof = transition(root)
    except Exception as error:
        return empty(mode, str(error), artifact_ref, evaluated_ref)
    if (
        sha(predecessor_raw) != PRE_SHA
        or predecessor.get("manifest_kind") != PRE_KIND
        or predecessor.get("record_count") != 2
        or predecessor.get("record_chain_terminal_sha256") != PRE_CHAIN
        or predecessor.get("failure_fingerprint_set_sha256") != PRE_SET
        or predecessor.get("revalidation_binding_head_sha") != PRE_HEAD
    ):
        failures.append("SPR5I_PREDECESSOR_SEAL_INVALID")
    if (
        manifest.get("manifest_kind") != KIND
        or manifest.get("authorization_id") != AUTH
        or manifest.get("authorization_base_head_sha") != BASE
        or manifest.get("prior_epoch_id") != EPOCH
        or manifest.get("schema_sha256") != sha(schema_raw)
        or manifest.get("predecessor_manifest_path") != PRE
        or manifest.get("predecessor_manifest_sha256") != PRE_SHA
    ):
        failures.append("SPR5I_MANIFEST_IDENTITY_INVALID")
    if (
        manifest.get("authority_transition_parent_sha") != PARENT
        or manifest.get("authority_transition_commit_sha") != CHANGE
        or manifest.get("authority_source_paths") != [REG, SUP]
        or manifest.get("authority_source_before_blob_sha256_by_path")
        != proof["before_sha256_by_path"]
        or manifest.get("authority_source_after_blob_sha256_by_path")
        != proof["after_sha256_by_path"]
        or manifest.get("authority_source_diff_sha256_by_path")
        != proof["diff_sha256_by_path"]
    ):
        failures.append("SPR5I_TRANSITION_INVALID")
    if (
        manifest.get("wildcard_count") != 0
        or manifest.get("future_failure_auto_revalidation") is not False
        or manifest.get("allowed_invalidation") != INVALIDATION
    ):
        failures.append("SPR5I_FAIL_CLOSED_POLICY_INVALID")

    source: dict[str, tuple[dict[str, Any], dict[str, Any]]] = {}
    fingerprints = list(predecessor.get("failure_fingerprints", []))
    for binding in predecessor.get("record_bindings", []):
        binding_fingerprints = binding.get("failure_fingerprints", [])
        if not isinstance(binding_fingerprints, list) or len(binding_fingerprints) != 1:
            failures.append("SPR5I_PREDECESSOR_BINDING_NOT_EXACT")
            continue
        fingerprint = str(binding_fingerprints[0])
        try:
            record, raw = doc(root, evaluated_ref, str(binding.get("path", "")))
            payload = dict(record)
            payload_hash = payload.pop("record_payload_sha256", None)
            selector = record["authority_selectors"]
            prior = projection(root, PRE_HEAD, selector)
            before = projection(root, PARENT, selector)
            rebound = projection(root, CHANGE, selector)
            live = projection(root, evaluated_ref, selector)
        except Exception:
            failures.append("SPR5I_PREDECESSOR_RECORD_UNREADABLE:" + fingerprint)
            continue
        if (
            fingerprint in source
            or sha(raw) != binding.get("record_sha256")
            or payload_hash != binding.get("record_payload_sha256")
            or payload_hash != sha(canonical(payload))
            or record.get("record_kind") != PRE_RKIND
            or record.get("failure_fingerprints") != [fingerprint]
        ):
            failures.append("SPR5I_PREDECESSOR_RECORD_SEAL:" + fingerprint)
        if (
            prior != record.get("live_subject_projection")
            or before != prior
            or rebound != live
            or before == rebound
            or [key for key in ("dynamic_reference_rows", "owner_map_lines", "registry_rows", "supersession_rows") if before[key] != rebound[key]]
            != ["registry_rows"]
            or changed_components(before, rebound) != CHANGED_COMPONENTS
        ):
            failures.append("SPR5I_TARGET_PROJECTION:" + fingerprint)
        source[fingerprint] = (record, binding)
    fingerprints.sort()
    if len(fingerprints) != 2 or set(source) != set(fingerprints):
        failures.append("SPR5I_TARGET_COVERAGE_INVALID")
    if (
        manifest.get("failure_fingerprints") != fingerprints
        or manifest.get("record_count") != 2
        or manifest.get("failure_fingerprint_set_sha256") != set_sha(fingerprints)
        or manifest.get("record_chain_start_sha256") != PRE_CHAIN
    ):
        failures.append("SPR5I_MANIFEST_TARGET_INVALID")

    manifest_bindings = manifest.get("record_bindings", [])
    previous = PRE_CHAIN
    if not isinstance(manifest_bindings, list) or len(manifest_bindings) != 2:
        failures.append("SPR5I_BINDING_COUNT_INVALID")
        manifest_bindings = []
    for index, fingerprint in enumerate(fingerprints):
        try:
            if stage_dir is None:
                record, raw = doc(root, artifact_ref, record_path(fingerprint))
            else:
                raw = (stage_dir / "records" / Path(record_path(fingerprint)).name).read_bytes()
                record = strict(raw)
            predecessor_record, predecessor_binding = source[fingerprint]
            selector = predecessor_record["authority_selectors"]
            prior = projection(root, PRE_HEAD, selector)
            before = projection(root, PARENT, selector)
            rebound = projection(root, CHANGE, selector)
            live = projection(root, evaluated_ref, selector)
            product_blobs = {
                str(path): sha(blob(root, PRE_HEAD, str(path)))
                for path in selector.get("paths", [])
            }
        except Exception:
            failures.append("SPR5I_RECORD_UNREADABLE:" + fingerprint)
            continue
        local: list[str] = []
        payload = dict(record)
        payload_hash = payload.pop("record_payload_sha256", None)
        if set(record) != RECORD_FIELDS or payload_hash != sha(canonical(payload)):
            local.append("PAYLOAD_FIELDS")
        if (
            record.get("record_kind") != RKIND
            or record.get("failure_fingerprints") != [fingerprint]
            or record.get("failure_fingerprint_set_sha256") != set_sha([fingerprint])
            or record.get("revalidation_id") != expected_id(fingerprint)
            or record.get("previous_revalidation_chain_sha256") != previous
            or record.get("revalidation_binding_head_sha") != evaluated_ref
            or record.get("revalidation_binding_tree_sha") != evaluated_tree
        ):
            local.append("IDENTITY_CHAIN")
        if (
            record.get("predecessor_revalidation_record_path")
            != predecessor_binding.get("path")
            or record.get("predecessor_revalidation_record_sha256")
            != predecessor_binding.get("record_sha256")
            or record.get("predecessor_revalidation_record_payload_sha256")
            != predecessor_binding.get("record_payload_sha256")
            or record.get("predecessor_revalidation_id")
            != predecessor_record.get("revalidation_id")
            or record.get("prior_record_path") != predecessor_record.get("prior_record_path")
            or record.get("prior_record_sha256") != predecessor_record.get("prior_record_sha256")
            or record.get("prior_record_payload_sha256")
            != predecessor_record.get("prior_record_payload_sha256")
        ):
            local.append("PREDECESSOR")
        if (
            record.get("authority_selectors") != selector
            or record.get("prior_subject_projection") != prior
            or record.get("pre_change_subject_projection") != before
            or record.get("rebound_subject_projection") != rebound
            or record.get("live_subject_projection") != live
            or record.get("changed_projection_sections") != ["registry_rows"]
            or record.get("changed_projection_component_ids") != CHANGED_COMPONENTS
            or record.get("authority_transition_proof") != proof
            or record.get("bound_product_blob_sha256_by_path") != product_blobs
        ):
            local.append("PROJECTION")
        if (
            record.get("prior_invalidations") != [INVALIDATION]
            or record.get("future_failure_policy") != POLICY
            or record.get("wildcard_count") != 0
        ):
            local.append("FAIL_CLOSED_POLICY")
        if index >= len(manifest_bindings):
            local.append("BINDING")
        else:
            binding = manifest_bindings[index]
            if (
                set(binding) != BINDING_FIELDS
                or binding.get("path") != record_path(fingerprint)
                or binding.get("record_sha256") != sha(raw)
                or binding.get("record_payload_sha256") != payload_hash
                or binding.get("previous_revalidation_chain_sha256") != previous
                or binding.get("predecessor_revalidation_record_path")
                != predecessor_binding.get("path")
                or binding.get("predecessor_revalidation_record_sha256")
                != predecessor_binding.get("record_sha256")
            ):
                local.append("BINDING")
        if local:
            failures.extend("SPR5I_" + item + ":" + fingerprint for item in local)
        else:
            trusted[fingerprint] = {
                "allowed_invalidations": [INVALIDATION],
                "prior_record_path": record.get("prior_record_path", ""),
                "revalidation_id": record.get("revalidation_id", ""),
                "record_path": record_path(fingerprint),
                "revalidation_binding_head_sha": evaluated_ref,
            }
        previous = str(payload_hash or previous)
    if previous != manifest.get("record_chain_terminal_sha256"):
        failures.append("SPR5I_CHAIN_TERMINAL_INVALID")
    if failures:
        trusted = {}
    committed = trusted if stage_dir is None else {}
    review = trusted if stage_dir is not None else {}
    return {
        "status": "PASS" if not failures else "FAIL",
        "mode": mode,
        "failures": sorted(set(failures)),
        "trusted_by_fingerprint": committed,
        "review_trusted_by_fingerprint": review,
        "record_count": len(trusted),
        "replacement_record_count": 2,
        "wildcard_count": 0,
        "future_failure_auto_revalidation_count": 0,
        "independent": True,
        "artifact_head_sha": artifact_ref,
        "evaluated_head_sha": evaluated_ref,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--evaluated-head", required=True)
    parser.add_argument("--artifact-head", default="HEAD")
    parser.add_argument("--stage-dir", type=Path)
    args = parser.parse_args(argv)
    result = audit(
        args.project.resolve(),
        args.manifest.resolve(),
        args.evaluated_head,
        args.stage_dir.resolve() if args.stage_dir else None,
        args.artifact_head,
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
