#!/usr/bin/env python3
"""Primary-free dual audit for the exact retired-source successor-v6."""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


AUTH = "USER_AUTHORIZATION_V076_CURRENT_SUBJECT_CONVERGENCE_AND_COMMERCIAL_RESUME_20260830"
BASE = "7b2bd08a9916a3a517f2d418765c544cce0261cc"
KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V6_MANIFEST"
RKIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V6_RECORD"
ROOT = "docs/architecture/reuse_corrections/v2/subject_projection_revalidation_successor_v6/"
SCHEMA = "docs/architecture/reuse_corrections/v2/schema_subject_projection_revalidation_successor_v6_20260831.json"
PRE = "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827/batch-010/batch-010-manifest.json"
PRE_SHA = "8ccd4e51ef005251ebc8d635c7e3203bfe0adf9b4f7e7e8ab6a2b95b75eb602a"
PRE_CHAIN = "eaa4865ef43e08c30170ce751c4d2387fe236b5be4bc7c312a72f5f04c4dbc1c"
REG = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
PRODUCT = "scripts/v076/direct_action/v076_private_direct_action_input_owner_v1.gd"
RECEIPT = "reports/reuse/full_convergence/private_direct_action_retired_source_detachment_20260831.json"
RECEIPT_SHA = "4e1910b575cd95eb359892bfa709e3984de3203dd37d363985135cbe2bee299f"
COMPONENT = "component.v076.private_direct_action_input"
REUSE = "reuse.current.military_runtime_owner"
SUCCESSOR = "reuse.v075.production_military_direct_action.current"
RULE = "RETIRED_REUSE_SOURCE_STILL_PRODUCTION_REFERENCED"
POLICY = {
    "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
    "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
}
SPECS = {
    "V2F-a88142e7ce7b8d0dde0efc0af6fd94725bafed5a4bfb917d0bf5fecc3778a463": (
        "RETIRED_REUSE_SOURCE_STILL_PRODUCTION_REFERENCED:9926d3955da7->6209465da4a9:component.v076.private_direct_action_input:reuse.current.military_runtime_owner",
        "9926d3955da7c14a292259e270f2ac2ff7559dcd",
        "6209465da4a9ca0c1cb6f0db0cd8a088bd63e793",
    ),
    "V2F-ac41659739d9d7e62cfd32661e8011cd5471a6b5102f8227a3ded10691853631": (
        "RETIRED_REUSE_SOURCE_STILL_PRODUCTION_REFERENCED:ee716a80b6a3->32e0800c5b1d:component.v076.private_direct_action_input:reuse.current.military_runtime_owner",
        "ee716a80b6a3306dde700b1e822419f6f3053cc2",
        "32e0800c5b1d521f4167049867d445aaabe9d8ac",
    ),
}
RECORD_FIELDS = frozenset(
    """schema_version record_kind correction_id authorization_id
    authorization_base_head_sha failure_fingerprint raw_failure rule_id failure_bucket
    transition_parent_sha transition_commit_sha transition_label component_id
    component_path retired_reuse_id active_successor_reuse_id authority_transition_proof
    historical_state current_resolution revalidation_binding_head_sha
    revalidation_binding_tree_sha previous_correction_chain_sha256 future_failure_policy
    wildcard_count new_effective_status correction_reason created_at creator
    record_payload_sha256""".split()
)
BINDING_FIELDS = frozenset(
    """path record_sha256 record_payload_sha256 correction_id failure_fingerprint
    raw_failure rule_id transition_parent_sha transition_commit_sha
    previous_correction_chain_sha256""".split()
)


def canonical(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)
        + "\n"
    ).encode("utf-8")


def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def set_sha(values: list[str]) -> str:
    return sha(("\n".join(sorted(values)) + "\n").encode("utf-8"))


def pairs(values: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in values:
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


def fingerprint(raw: str) -> str:
    payload = f"V076_RAW_FAILURE_V2\nHISTORICAL\n{RULE}\n{raw}\n".encode("utf-8")
    return "V2F-" + sha(payload)


def record_path(fp: str) -> str:
    return ROOT + "records/spr6-" + fp[4:] + ".json"


def correction_id(fp: str) -> str:
    return "V076-SPR6-" + fp[4:20].upper()


def registry_state(root: Path, ref: str) -> dict[str, Any]:
    raw = blob(root, ref, REG)
    value = strict(raw)
    if not isinstance(value, dict):
        raise ValueError("REGISTRY_NOT_OBJECT")
    components = [
        row for row in value.get("component_inventory", [])
        if isinstance(row, dict) and row.get("component_id") == COMPONENT
    ]
    reuse_rows = [
        row for row in value.get("reuse_entries", [])
        if isinstance(row, dict) and row.get("reuse_id") == REUSE
    ]
    if len(components) != 1 or len(reuse_rows) != 1:
        raise ValueError("REGISTRY_TARGET_CARDINALITY")
    sources = components[0].get("reuse_source_ids")
    if not isinstance(sources, list):
        raise ValueError("REGISTRY_SOURCE_LIST_INVALID")
    return {
        "registry_sha256": sha(raw),
        "registry_blob_oid": git(root, "rev-parse", f"{ref}:{REG}"),
        "component_production_reachable": components[0].get("production_reachable") is True,
        "component_reuse_source_ids": list(sources),
        "retired_source_referenced": REUSE in sources,
        "active_successor_referenced": SUCCESSOR in sources,
        "reuse_disposition": str(reuse_rows[0].get("disposition", "")),
    }


def transition(root: Path, fp: str) -> dict[str, Any]:
    _raw, parent, commit = SPECS[fp]
    if git(root, "rev-parse", f"{commit}^1") != parent:
        raise ValueError("SPR6I_TRANSITION_PARENT_INVALID:" + fp)
    before = registry_state(root, parent)
    after = registry_state(root, commit)
    if not (
        before["reuse_disposition"] == "ADAPT_AS_CONSUMER"
        and before["component_production_reachable"] is True
        and before["retired_source_referenced"] is True
        and after["reuse_disposition"] == "RETIRED"
        and after["component_production_reachable"] is True
        and after["retired_source_referenced"] is True
    ):
        raise ValueError("SPR6I_TRANSITION_STATE_INVALID:" + fp)
    diff = git(
        root, "diff", "--binary", "--no-ext-diff", parent, commit, "--", REG,
        binary=True,
    )
    return {
        "parent_sha": parent,
        "commit_sha": commit,
        "before_registry_sha256": before["registry_sha256"],
        "after_registry_sha256": after["registry_sha256"],
        "before_registry_blob_oid": before["registry_blob_oid"],
        "after_registry_blob_oid": after["registry_blob_oid"],
        "registry_diff_sha256": sha(diff),
    }


def current(root: Path, ref: str) -> dict[str, Any]:
    state = registry_state(root, ref)
    product = blob(root, ref, PRODUCT)
    receipt_raw = blob(root, ref, RECEIPT)
    receipt = strict(receipt_raw)
    if not (
        state["reuse_disposition"] == "RETIRED"
        and state["component_production_reachable"] is True
        and state["retired_source_referenced"] is False
        and state["active_successor_referenced"] is True
        and sha(receipt_raw) == RECEIPT_SHA
        and isinstance(receipt, dict)
        and receipt.get("status") == "PASS"
        and receipt.get("source_head_sha") == "846810513887e8a32c4345df0e14129a35764e09"
        and receipt.get("source_tree_sha") == "7202f4d8cd3f5e177891f3305ae5e8418de54779"
        and receipt.get("target_path") == REG
        and receipt.get("after_registry_sha256") == state["registry_sha256"]
        and receipt.get("component_id") == COMPONENT
        and receipt.get("detached_reuse_source_id") == REUSE
        and receipt.get("retained_active_successor_source_id") == SUCCESSOR
        and receipt.get("current_failure_correction_count") == 0
        and receipt.get("waiver_count") == 0
        and receipt.get("product_file_mutation_count") == 0
    ):
        raise ValueError("SPR6I_CURRENT_RESOLUTION_INVALID")
    return {
        **state,
        "component_path": PRODUCT,
        "component_blob_sha256": sha(product),
        "detachment_receipt_path": RECEIPT,
        "detachment_receipt_sha256": RECEIPT_SHA,
    }


def empty(mode: str, failure: str, artifact: str = "", evaluated: str = "") -> dict[str, Any]:
    return {
        "status": "FAIL",
        "mode": mode,
        "failures": [failure],
        "trusted_by_fingerprint": {},
        "review_trusted_by_fingerprint": {},
        "authorized_identity_by_fingerprint": {},
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
    identities: dict[str, dict[str, Any]] = {}
    mode = "COMMITTED" if stage_dir is None else "STAGE_REVIEW"
    artifact = ""
    try:
        evaluated = str(git(root, "rev-parse", f"{evaluated_head}^{{commit}}"))
        tree = str(git(root, "rev-parse", f"{evaluated}^{{tree}}"))
        relative = str(manifest_path.resolve().relative_to(root.resolve())).replace("\\", "/")
        if relative != ROOT + "manifest.json":
            raise ValueError("SPR6I_MANIFEST_PATH_INVALID")
        if stage_dir is None:
            artifact = str(git(root, "rev-parse", f"{artifact_head or 'HEAD'}^{{commit}}"))
            manifest, _ = doc(root, artifact, relative)
            schema_raw = blob(root, artifact, SCHEMA)
            if artifact == evaluated:
                raise ValueError("SPR6I_ARTIFACT_NOT_DISTINCT_FROM_BINDING")
            if subprocess.run(
                ["git", "-C", str(root), "merge-base", "--is-ancestor", evaluated, artifact],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode != 0:
                raise ValueError("SPR6I_BINDING_NOT_ARTIFACT_ANCESTOR")
        else:
            manifest = strict(manifest_path.read_bytes())
            schema_raw = (root / SCHEMA).read_bytes()
        predecessor, predecessor_raw = doc(root, evaluated, PRE)
        now = current(root, evaluated)
    except Exception as error:
        return empty(mode, str(error), artifact)
    if not isinstance(manifest, dict):
        return empty(mode, "SPR6I_MANIFEST_NOT_OBJECT", artifact, evaluated)
    if (
        manifest.get("revalidation_binding_head_sha") != evaluated
        or manifest.get("revalidation_binding_tree_sha") != tree
    ):
        return empty(mode, "SPR6I_BINDING_INVALID", artifact, evaluated)
    if (
        manifest.get("manifest_kind") != KIND
        or manifest.get("authorization_id") != AUTH
        or manifest.get("authorization_base_head_sha") != BASE
        or manifest.get("schema_path") != SCHEMA
        or manifest.get("schema_sha256") != sha(schema_raw)
        or manifest.get("predecessor_manifest_path") != PRE
        or manifest.get("predecessor_manifest_sha256") != PRE_SHA
        or sha(predecessor_raw) != PRE_SHA
        or predecessor.get("record_chain_terminal_sha256") != PRE_CHAIN
        or manifest.get("predecessor_record_chain_terminal_sha256") != PRE_CHAIN
        or manifest.get("record_chain_start_sha256") != PRE_CHAIN
    ):
        failures.append("SPR6I_MANIFEST_OR_PREDECESSOR_INVALID")
    fps = sorted(SPECS)
    raws = sorted(SPECS[value][0] for value in fps)
    if (
        manifest.get("record_count") != 2
        or manifest.get("failure_fingerprints") != fps
        or manifest.get("failure_fingerprint_set_sha256") != set_sha(fps)
        or manifest.get("raw_failures") != raws
        or manifest.get("raw_failure_set_sha256") != set_sha(raws)
        or manifest.get("component_id") != COMPONENT
        or manifest.get("component_path") != PRODUCT
        or manifest.get("retired_reuse_id") != REUSE
        or manifest.get("active_successor_reuse_id") != SUCCESSOR
        or manifest.get("current_registry_sha256") != now["registry_sha256"]
        or manifest.get("current_product_blob_sha256") != now["component_blob_sha256"]
        or manifest.get("detachment_receipt_path") != RECEIPT
        or manifest.get("detachment_receipt_sha256") != RECEIPT_SHA
        or manifest.get("future_failure_auto_correction") is not False
        or manifest.get("wildcard_count") != 0
    ):
        failures.append("SPR6I_TARGET_OR_POLICY_INVALID")
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or len(bindings) != 2:
        failures.append("SPR6I_BINDING_COUNT_INVALID")
        bindings = []
    previous = PRE_CHAIN
    for index, fp in enumerate(fps):
        raw_failure, parent, commit = SPECS[fp]
        try:
            if stage_dir is None:
                record, raw = doc(root, artifact, record_path(fp))
            else:
                raw = (stage_dir / "records" / Path(record_path(fp)).name).read_bytes()
                record = strict(raw)
            proof = transition(root, fp)
        except Exception:
            failures.append("SPR6I_RECORD_UNREADABLE:" + fp)
            continue
        local: list[str] = []
        payload = dict(record) if isinstance(record, dict) else {}
        payload_hash = payload.pop("record_payload_sha256", None)
        if not isinstance(record, dict) or set(record) != RECORD_FIELDS or payload_hash != sha(canonical(payload)):
            local.append("PAYLOAD_FIELDS")
        if (
            record.get("record_kind") != RKIND
            or record.get("correction_id") != correction_id(fp)
            or record.get("failure_fingerprint") != fp
            or record.get("raw_failure") != raw_failure
            or fingerprint(raw_failure) != fp
            or record.get("rule_id") != RULE
            or record.get("failure_bucket") != "HISTORICAL"
            or record.get("transition_parent_sha") != parent
            or record.get("transition_commit_sha") != commit
        ):
            local.append("IDENTITY_TRANSITION")
        if (
            record.get("component_id") != COMPONENT
            or record.get("component_path") != PRODUCT
            or record.get("retired_reuse_id") != REUSE
            or record.get("active_successor_reuse_id") != SUCCESSOR
            or record.get("authority_transition_proof") != proof
            or record.get("current_resolution") != now
            or record.get("revalidation_binding_head_sha") != evaluated
            or record.get("revalidation_binding_tree_sha") != tree
        ):
            local.append("AUTHORITY_PROOF")
        if (
            record.get("previous_correction_chain_sha256") != previous
            or record.get("future_failure_policy") != POLICY
            or record.get("wildcard_count") != 0
            or record.get("new_effective_status") != "CORRECTED_HISTORICAL_DEBT"
        ):
            local.append("CHAIN_POLICY")
        if index >= len(bindings):
            local.append("MANIFEST_BINDING")
        else:
            binding = bindings[index]
            if (
                not isinstance(binding, dict)
                or set(binding) != BINDING_FIELDS
                or binding.get("path") != record_path(fp)
                or binding.get("record_sha256") != sha(raw)
                or binding.get("record_payload_sha256") != payload_hash
                or binding.get("correction_id") != correction_id(fp)
                or binding.get("failure_fingerprint") != fp
                or binding.get("raw_failure") != raw_failure
                or binding.get("rule_id") != RULE
                or binding.get("transition_parent_sha") != parent
                or binding.get("transition_commit_sha") != commit
                or binding.get("previous_correction_chain_sha256") != previous
            ):
                local.append("MANIFEST_BINDING")
        if local:
            failures.extend(f"SPR6I_{value}:{fp}" for value in local)
        else:
            identity = {
                "authority_origin": "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V6",
                "bucket": "HISTORICAL",
                "failure_fingerprint": fp,
                "raw_failure": raw_failure,
                "rule_id": RULE,
                "transition_old_prefix": parent[:12],
                "transition_new_prefix": commit[:12],
                "subject_kind": "component_id",
                "subject_value": COMPONENT,
                "source_commit_sha": commit,
                "record_path": record_path(fp),
                "correction_id": correction_id(fp),
            }
            trusted[fp] = dict(identity)
            identities[fp] = identity
        previous = str(record.get("record_payload_sha256", previous))
    if previous != manifest.get("record_chain_terminal_sha256"):
        failures.append("SPR6I_CHAIN_TERMINAL_INVALID")
    if failures:
        trusted = {}
        identities = {}
    return {
        "status": "PASS" if not failures else "FAIL",
        "mode": mode,
        "failures": sorted(set(failures)),
        "trusted_by_fingerprint": trusted if stage_dir is None else {},
        "review_trusted_by_fingerprint": trusted if stage_dir is not None else {},
        "authorized_identity_by_fingerprint": identities,
        "record_count": len(trusted),
        "wildcard_count": 0,
        "future_failure_auto_correction_count": 0,
        "independent": True,
        "artifact_head_sha": artifact,
        "evaluated_head_sha": evaluated,
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
