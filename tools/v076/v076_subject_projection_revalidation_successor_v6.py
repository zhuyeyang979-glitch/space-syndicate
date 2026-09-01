#!/usr/bin/env python3
"""Exact append-only correction successor for two retired-source history rows.

The scanner rule remains strict.  This module trusts only the two frozen Raw
rows named below, proves both parallel Batch009 transitions byte-for-byte, and
proves that the current production component no longer references the retired
source while retaining the active successor.  No prefix, regex, or future-row
matching is permitted.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


AUTHORIZATION_ID = (
    "USER_AUTHORIZATION_V076_CURRENT_SUBJECT_CONVERGENCE_AND_COMMERCIAL_RESUME_20260830"
)
AUTHORIZATION_BASE_HEAD = "7b2bd08a9916a3a517f2d418765c544cce0261cc"
SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "subject_projection_revalidation_successor_v6_schema.v1"
)
MANIFEST_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "subject_projection_revalidation_successor_v6_manifest.v1"
)
RECORD_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "subject_projection_revalidation_successor_v6_record.v1"
)
MANIFEST_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V6_MANIFEST"
RECORD_KIND = "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V6_RECORD"
MANIFEST_ID = "V076-SUBJECT-PROJECTION-REVALIDATION-SUCCESSOR-V6-20260831"
SCHEMA_PATH = (
    "docs/architecture/reuse_corrections/v2/"
    "schema_subject_projection_revalidation_successor_v6_20260831.json"
)
SUCCESSOR_ROOT = (
    "docs/architecture/reuse_corrections/v2/"
    "subject_projection_revalidation_successor_v6/"
)
RECORD_ROOT = SUCCESSOR_ROOT + "records/"
PREDECESSOR_MANIFEST_PATH = (
    "docs/architecture/reuse_corrections/v2/batches/full_convergence_20260827/"
    "batch-010/batch-010-manifest.json"
)
PREDECESSOR_MANIFEST_SHA256 = (
    "8ccd4e51ef005251ebc8d635c7e3203bfe0adf9b4f7e7e8ab6a2b95b75eb602a"
)
PREDECESSOR_CHAIN_TERMINAL_SHA256 = (
    "eaa4865ef43e08c30170ce751c4d2387fe236b5be4bc7c312a72f5f04c4dbc1c"
)
REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
COMPONENT_PATH = "scripts/v076/direct_action/v076_private_direct_action_input_owner_v1.gd"
COMPONENT_ID = "component.v076.private_direct_action_input"
REUSE_ID = "reuse.current.military_runtime_owner"
ACTIVE_SUCCESSOR_REUSE_ID = "reuse.v075.production_military_direct_action.current"
RULE_ID = "RETIRED_REUSE_SOURCE_STILL_PRODUCTION_REFERENCED"
DETACHMENT_RECEIPT_PATH = (
    "reports/reuse/full_convergence/"
    "private_direct_action_retired_source_detachment_20260831.json"
)
DETACHMENT_RECEIPT_SHA256 = (
    "4e1910b575cd95eb359892bfa709e3984de3203dd37d363985135cbe2bee299f"
)
FUTURE_POLICY = {
    "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
    "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
}

RAW_SPECS = {
    "V2F-a88142e7ce7b8d0dde0efc0af6fd94725bafed5a4bfb917d0bf5fecc3778a463": {
        "raw_failure": (
            "RETIRED_REUSE_SOURCE_STILL_PRODUCTION_REFERENCED:"
            "9926d3955da7->6209465da4a9:component.v076.private_direct_action_input:"
            "reuse.current.military_runtime_owner"
        ),
        "parent_sha": "9926d3955da7c14a292259e270f2ac2ff7559dcd",
        "commit_sha": "6209465da4a9ca0c1cb6f0db0cd8a088bd63e793",
    },
    "V2F-ac41659739d9d7e62cfd32661e8011cd5471a6b5102f8227a3ded10691853631": {
        "raw_failure": (
            "RETIRED_REUSE_SOURCE_STILL_PRODUCTION_REFERENCED:"
            "ee716a80b6a3->32e0800c5b1d:component.v076.private_direct_action_input:"
            "reuse.current.military_runtime_owner"
        ),
        "parent_sha": "ee716a80b6a3306dde700b1e822419f6f3053cc2",
        "commit_sha": "32e0800c5b1d521f4167049867d445aaabe9d8ac",
    },
}

MANIFEST_FIELDS = frozenset(
    """schema_version manifest_kind manifest_id artifact_root_kind authorization_id
    authorization_base_head_sha schema_path schema_sha256 predecessor_manifest_path
    predecessor_manifest_sha256 predecessor_record_chain_terminal_sha256
    revalidation_binding_head_sha revalidation_binding_tree_sha record_count
    failure_fingerprints failure_fingerprint_set_sha256 raw_failures
    raw_failure_set_sha256 record_chain_start_sha256 record_chain_terminal_sha256
    component_id component_path retired_reuse_id active_successor_reuse_id
    current_registry_sha256 current_product_blob_sha256 detachment_receipt_path
    detachment_receipt_sha256
    future_failure_auto_correction wildcard_count created_at creator record_bindings""".split()
)
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


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def line_set_sha(values: list[str]) -> str:
    return sha256_bytes(("\n".join(sorted(values)) + "\n").encode("utf-8"))


def payload_sha(value: dict[str, Any]) -> str:
    body = dict(value)
    body.pop("record_payload_sha256", None)
    return sha256_bytes(canonical_bytes(body))


def _pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("DUPLICATE_JSON_KEY")
        result[key] = value
    return result


def strict(raw: bytes) -> Any:
    return json.loads(
        raw.decode("utf-8-sig"),
        object_pairs_hook=_pairs,
        parse_constant=lambda _: (_ for _ in ()).throw(ValueError("NONFINITE_JSON")),
    )


def _git(root: Path, *args: str, binary: bool = False) -> str | bytes:
    process = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode:
        raise ValueError("GIT_FAILURE:" + process.stderr.decode("utf-8", "replace").strip())
    return process.stdout if binary else process.stdout.decode().strip()


def blob(root: Path, ref: str, path: str) -> bytes | None:
    process = subprocess.run(
        ["git", "--no-replace-objects", "-C", str(root), "cat-file", "blob", f"{ref}:{path}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    return process.stdout if process.returncode == 0 else None


def document(root: Path, ref: str, path: str) -> tuple[dict[str, Any], bytes]:
    raw = blob(root, ref, path)
    if raw is None:
        raise ValueError("MISSING_BLOB:" + path)
    value = strict(raw)
    if not isinstance(value, dict):
        raise ValueError("DOCUMENT_NOT_OBJECT:" + path)
    return value, raw


def expected_fingerprint(raw: str) -> str:
    payload = f"V076_RAW_FAILURE_V2\nHISTORICAL\n{RULE_ID}\n{raw}\n".encode("utf-8")
    return "V2F-" + sha256_bytes(payload)


def expected_record_path(fingerprint: str) -> str:
    return RECORD_ROOT + "spr6-" + fingerprint[4:] + ".json"


def expected_id(fingerprint: str) -> str:
    return "V076-SPR6-" + fingerprint[4:20].upper()


def _row(document_value: dict[str, Any], key: str, value: str) -> dict[str, Any]:
    rows = document_value.get(key)
    if not isinstance(rows, list):
        raise ValueError("REGISTRY_ROWS_INVALID:" + key)
    matches = [row for row in rows if isinstance(row, dict) and row.get(
        "component_id" if key == "component_inventory" else "reuse_id"
    ) == value]
    if len(matches) != 1:
        raise ValueError("REGISTRY_ROW_CARDINALITY_INVALID:" + value)
    return matches[0]


def _registry_state(root: Path, ref: str) -> dict[str, Any]:
    raw = blob(root, ref, REGISTRY_PATH)
    if raw is None:
        raise ValueError("REGISTRY_BLOB_MISSING:" + ref)
    registry = strict(raw)
    if not isinstance(registry, dict):
        raise ValueError("REGISTRY_NOT_OBJECT:" + ref)
    component = _row(registry, "component_inventory", COMPONENT_ID)
    reuse = _row(registry, "reuse_entries", REUSE_ID)
    source_ids = component.get("reuse_source_ids")
    if not isinstance(source_ids, list):
        raise ValueError("COMPONENT_REUSE_SOURCE_IDS_INVALID:" + ref)
    return {
        "registry_sha256": sha256_bytes(raw),
        "registry_blob_oid": str(_git(root, "rev-parse", f"{ref}:{REGISTRY_PATH}")),
        "component_production_reachable": component.get("production_reachable") is True,
        "component_reuse_source_ids": list(source_ids),
        "retired_source_referenced": REUSE_ID in source_ids,
        "active_successor_referenced": ACTIVE_SUCCESSOR_REUSE_ID in source_ids,
        "reuse_disposition": str(reuse.get("disposition", "")),
    }


def transition_proof(root: Path, fingerprint: str) -> dict[str, Any]:
    spec = RAW_SPECS[fingerprint]
    parent = str(spec["parent_sha"])
    commit = str(spec["commit_sha"])
    if str(_git(root, "rev-parse", f"{commit}^1")) != parent:
        raise ValueError("SPR6_TRANSITION_PARENT_INVALID:" + fingerprint)
    before_raw = blob(root, parent, REGISTRY_PATH)
    after_raw = blob(root, commit, REGISTRY_PATH)
    if before_raw is None or after_raw is None:
        raise ValueError("SPR6_TRANSITION_REGISTRY_MISSING:" + fingerprint)
    before = _registry_state(root, parent)
    after = _registry_state(root, commit)
    if (
        before["reuse_disposition"] != "ADAPT_AS_CONSUMER"
        or before["component_production_reachable"] is not True
        or before["retired_source_referenced"] is not True
        or after["reuse_disposition"] != "RETIRED"
        or after["component_production_reachable"] is not True
        or after["retired_source_referenced"] is not True
    ):
        raise ValueError("SPR6_HISTORICAL_STATE_INVALID:" + fingerprint)
    diff = _git(
        root,
        "diff",
        "--binary",
        "--no-ext-diff",
        parent,
        commit,
        "--",
        REGISTRY_PATH,
        binary=True,
    )
    return {
        "parent_sha": parent,
        "commit_sha": commit,
        "before_registry_sha256": sha256_bytes(before_raw),
        "after_registry_sha256": sha256_bytes(after_raw),
        "before_registry_blob_oid": before["registry_blob_oid"],
        "after_registry_blob_oid": after["registry_blob_oid"],
        "registry_diff_sha256": sha256_bytes(diff),
    }


def current_resolution(root: Path, binding_head: str) -> dict[str, Any]:
    state = _registry_state(root, binding_head)
    product_raw = blob(root, binding_head, COMPONENT_PATH)
    if product_raw is None:
        raise ValueError("SPR6_CURRENT_PRODUCT_BLOB_MISSING")
    if (
        state["reuse_disposition"] != "RETIRED"
        or state["component_production_reachable"] is not True
        or state["retired_source_referenced"] is not False
        or state["active_successor_referenced"] is not True
    ):
        raise ValueError("SPR6_CURRENT_RESOLUTION_INVALID")
    receipt_raw = blob(root, binding_head, DETACHMENT_RECEIPT_PATH)
    if receipt_raw is None or sha256_bytes(receipt_raw) != DETACHMENT_RECEIPT_SHA256:
        raise ValueError("SPR6_DETACHMENT_RECEIPT_SHA_INVALID")
    receipt = strict(receipt_raw)
    if (
        not isinstance(receipt, dict)
        or receipt.get("status") != "PASS"
        or receipt.get("source_head_sha")
        != "846810513887e8a32c4345df0e14129a35764e09"
        or receipt.get("source_tree_sha")
        != "7202f4d8cd3f5e177891f3305ae5e8418de54779"
        or receipt.get("target_path") != REGISTRY_PATH
        or receipt.get("after_registry_sha256") != state["registry_sha256"]
        or receipt.get("component_id") != COMPONENT_ID
        or receipt.get("detached_reuse_source_id") != REUSE_ID
        or receipt.get("retained_active_successor_source_id")
        != ACTIVE_SUCCESSOR_REUSE_ID
        or receipt.get("current_failure_correction_count") != 0
        or receipt.get("waiver_count") != 0
        or receipt.get("product_file_mutation_count") != 0
    ):
        raise ValueError("SPR6_DETACHMENT_RECEIPT_CONTRACT_INVALID")
    return {
        **state,
        "component_path": COMPONENT_PATH,
        "component_blob_sha256": sha256_bytes(product_raw),
        "detachment_receipt_path": DETACHMENT_RECEIPT_PATH,
        "detachment_receipt_sha256": DETACHMENT_RECEIPT_SHA256,
    }


def make_record(
    root: Path,
    fingerprint: str,
    previous: str,
    binding_head: str,
    binding_tree: str,
    created_at: str,
) -> dict[str, Any]:
    spec = RAW_SPECS[fingerprint]
    raw = str(spec["raw_failure"])
    if expected_fingerprint(raw) != fingerprint:
        raise ValueError("SPR6_FINGERPRINT_MISMATCH:" + fingerprint)
    proof = transition_proof(root, fingerprint)
    current = current_resolution(root, binding_head)
    record: dict[str, Any] = {
        "schema_version": RECORD_SCHEMA_VERSION,
        "record_kind": RECORD_KIND,
        "correction_id": expected_id(fingerprint),
        "authorization_id": AUTHORIZATION_ID,
        "authorization_base_head_sha": AUTHORIZATION_BASE_HEAD,
        "failure_fingerprint": fingerprint,
        "raw_failure": raw,
        "rule_id": RULE_ID,
        "failure_bucket": "HISTORICAL",
        "transition_parent_sha": spec["parent_sha"],
        "transition_commit_sha": spec["commit_sha"],
        "transition_label": f"{str(spec['parent_sha'])[:12]}->{str(spec['commit_sha'])[:12]}",
        "component_id": COMPONENT_ID,
        "component_path": COMPONENT_PATH,
        "retired_reuse_id": REUSE_ID,
        "active_successor_reuse_id": ACTIVE_SUCCESSOR_REUSE_ID,
        "authority_transition_proof": proof,
        "historical_state": {
            "before_disposition": "ADAPT_AS_CONSUMER",
            "after_disposition": "RETIRED",
            "production_reachable": True,
            "retired_source_referenced_after_transition": True,
        },
        "current_resolution": current,
        "revalidation_binding_head_sha": binding_head,
        "revalidation_binding_tree_sha": binding_tree,
        "previous_correction_chain_sha256": previous,
        "future_failure_policy": FUTURE_POLICY,
        "wildcard_count": 0,
        "new_effective_status": "CORRECTED_HISTORICAL_DEBT",
        "correction_reason": "EXACT_RETIRED_SOURCE_REFERENCE_DETACHED_AT_CURRENT_BINDING",
        "created_at": created_at,
        "creator": "v076_subject_projection_revalidation_successor_v6_builder.py",
    }
    record["record_payload_sha256"] = payload_sha(record)
    return record


def _empty(mode: str, failure: str, artifact: str = "", evaluated: str = "") -> dict[str, Any]:
    return {
        "status": "FAIL",
        "mode": mode,
        "failures": [failure],
        "trusted_by_fingerprint": {},
        "review_trusted_by_fingerprint": {},
        "authorized_identity_by_fingerprint": {},
        "record_count": 0,
        "artifact_head_sha": artifact,
        "evaluated_head_sha": evaluated,
    }


def validate(
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
        evaluated = str(_git(root, "rev-parse", f"{evaluated_head}^{{commit}}"))
        evaluated_tree = str(_git(root, "rev-parse", f"{evaluated}^{{tree}}"))
        relative = str(manifest_path.resolve().relative_to(root.resolve())).replace("\\", "/")
        if relative != SUCCESSOR_ROOT + "manifest.json":
            raise ValueError("SPR6_MANIFEST_PATH_INVALID")
        if stage_dir is None:
            artifact = str(_git(root, "rev-parse", f"{artifact_head or 'HEAD'}^{{commit}}"))
            manifest, manifest_raw = document(root, artifact, relative)
            schema_raw = blob(root, artifact, SCHEMA_PATH)
            if schema_raw is None:
                raise ValueError("SPR6_SCHEMA_BLOB_MISSING")
            if artifact == evaluated:
                raise ValueError("SPR6_ARTIFACT_NOT_DISTINCT_FROM_BINDING")
            if subprocess.run(
                ["git", "-C", str(root), "merge-base", "--is-ancestor", evaluated, artifact],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode != 0:
                raise ValueError("SPR6_BINDING_NOT_ARTIFACT_ANCESTOR")
        else:
            manifest_raw = manifest_path.read_bytes()
            manifest = strict(manifest_raw)
            schema_raw = (root / SCHEMA_PATH).read_bytes()
        if not isinstance(manifest, dict):
            raise ValueError("SPR6_MANIFEST_NOT_OBJECT")
        predecessor, predecessor_raw = document(root, evaluated, PREDECESSOR_MANIFEST_PATH)
    except Exception as error:
        return _empty(mode, str(error), artifact)
    if (
        manifest.get("revalidation_binding_head_sha") != evaluated
        or manifest.get("revalidation_binding_tree_sha") != evaluated_tree
    ):
        return _empty(mode, "SPR6_BINDING_INVALID", artifact, evaluated)
    if set(manifest) != MANIFEST_FIELDS:
        failures.append("SPR6_MANIFEST_FIELD_SET_INVALID")
    if (
        manifest.get("schema_version") != MANIFEST_SCHEMA_VERSION
        or manifest.get("manifest_kind") != MANIFEST_KIND
        or manifest.get("manifest_id") != MANIFEST_ID
        or manifest.get("authorization_id") != AUTHORIZATION_ID
        or manifest.get("authorization_base_head_sha") != AUTHORIZATION_BASE_HEAD
        or manifest.get("schema_path") != SCHEMA_PATH
        or manifest.get("schema_sha256") != sha256_bytes(schema_raw)
    ):
        failures.append("SPR6_MANIFEST_IDENTITY_INVALID")
    if (
        sha256_bytes(predecessor_raw) != PREDECESSOR_MANIFEST_SHA256
        or predecessor.get("record_chain_terminal_sha256")
        != PREDECESSOR_CHAIN_TERMINAL_SHA256
        or manifest.get("predecessor_manifest_path") != PREDECESSOR_MANIFEST_PATH
        or manifest.get("predecessor_manifest_sha256") != PREDECESSOR_MANIFEST_SHA256
        or manifest.get("predecessor_record_chain_terminal_sha256")
        != PREDECESSOR_CHAIN_TERMINAL_SHA256
        or manifest.get("record_chain_start_sha256")
        != PREDECESSOR_CHAIN_TERMINAL_SHA256
    ):
        failures.append("SPR6_PREDECESSOR_INVALID")
    fingerprints = sorted(RAW_SPECS)
    raws = sorted(str(RAW_SPECS[value]["raw_failure"]) for value in fingerprints)
    if (
        manifest.get("record_count") != 2
        or manifest.get("failure_fingerprints") != fingerprints
        or manifest.get("failure_fingerprint_set_sha256") != line_set_sha(fingerprints)
        or manifest.get("raw_failures") != raws
        or manifest.get("raw_failure_set_sha256") != line_set_sha(raws)
        or manifest.get("component_id") != COMPONENT_ID
        or manifest.get("component_path") != COMPONENT_PATH
        or manifest.get("retired_reuse_id") != REUSE_ID
        or manifest.get("active_successor_reuse_id") != ACTIVE_SUCCESSOR_REUSE_ID
        or manifest.get("detachment_receipt_path") != DETACHMENT_RECEIPT_PATH
        or manifest.get("detachment_receipt_sha256") != DETACHMENT_RECEIPT_SHA256
        or manifest.get("future_failure_auto_correction") is not False
        or manifest.get("wildcard_count") != 0
    ):
        failures.append("SPR6_TARGET_OR_POLICY_INVALID")
    try:
        current = current_resolution(root, evaluated)
    except Exception as error:
        current = {}
        failures.append(str(error))
    if (
        manifest.get("current_registry_sha256") != current.get("registry_sha256")
        or manifest.get("current_product_blob_sha256")
        != current.get("component_blob_sha256")
    ):
        failures.append("SPR6_CURRENT_BINDING_INVALID")
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or len(bindings) != 2:
        failures.append("SPR6_BINDING_COUNT_INVALID")
        bindings = []
    previous = PREDECESSOR_CHAIN_TERMINAL_SHA256
    for index, fingerprint in enumerate(fingerprints):
        try:
            if stage_dir is None:
                record, raw = document(root, artifact, expected_record_path(fingerprint))
            else:
                raw = (stage_dir / "records" / Path(expected_record_path(fingerprint)).name).read_bytes()
                record = strict(raw)
            if not isinstance(record, dict):
                raise ValueError("NOT_OBJECT")
            expected_proof = transition_proof(root, fingerprint)
        except Exception:
            failures.append("SPR6_RECORD_UNREADABLE:" + fingerprint)
            continue
        local: list[str] = []
        spec = RAW_SPECS[fingerprint]
        if set(record) != RECORD_FIELDS:
            local.append("FIELD_SET")
        if (
            record.get("schema_version") != RECORD_SCHEMA_VERSION
            or record.get("record_kind") != RECORD_KIND
            or record.get("correction_id") != expected_id(fingerprint)
            or record.get("failure_fingerprint") != fingerprint
            or record.get("raw_failure") != spec["raw_failure"]
            or expected_fingerprint(str(record.get("raw_failure", ""))) != fingerprint
            or record.get("rule_id") != RULE_ID
            or record.get("failure_bucket") != "HISTORICAL"
        ):
            local.append("IDENTITY")
        if (
            record.get("transition_parent_sha") != spec["parent_sha"]
            or record.get("transition_commit_sha") != spec["commit_sha"]
            or record.get("authority_transition_proof") != expected_proof
            or record.get("historical_state")
            != {
                "before_disposition": "ADAPT_AS_CONSUMER",
                "after_disposition": "RETIRED",
                "production_reachable": True,
                "retired_source_referenced_after_transition": True,
            }
        ):
            local.append("TRANSITION")
        if (
            record.get("component_id") != COMPONENT_ID
            or record.get("component_path") != COMPONENT_PATH
            or record.get("retired_reuse_id") != REUSE_ID
            or record.get("active_successor_reuse_id") != ACTIVE_SUCCESSOR_REUSE_ID
            or record.get("current_resolution") != current
            or record.get("revalidation_binding_head_sha") != evaluated
            or record.get("revalidation_binding_tree_sha") != evaluated_tree
        ):
            local.append("CURRENT_RESOLUTION")
        if (
            record.get("previous_correction_chain_sha256") != previous
            or record.get("record_payload_sha256") != payload_sha(record)
        ):
            local.append("CHAIN_PAYLOAD")
        if (
            record.get("future_failure_policy") != FUTURE_POLICY
            or record.get("wildcard_count") != 0
            or record.get("new_effective_status") != "CORRECTED_HISTORICAL_DEBT"
        ):
            local.append("FAIL_CLOSED_POLICY")
        if index >= len(bindings):
            local.append("MANIFEST_BINDING")
        else:
            binding = bindings[index]
            if (
                not isinstance(binding, dict)
                or set(binding) != BINDING_FIELDS
                or binding.get("path") != expected_record_path(fingerprint)
                or binding.get("record_sha256") != sha256_bytes(raw)
                or binding.get("record_payload_sha256")
                != record.get("record_payload_sha256")
                or binding.get("failure_fingerprint") != fingerprint
                or binding.get("raw_failure") != spec["raw_failure"]
                or binding.get("rule_id") != RULE_ID
                or binding.get("transition_parent_sha") != spec["parent_sha"]
                or binding.get("transition_commit_sha") != spec["commit_sha"]
                or binding.get("previous_correction_chain_sha256") != previous
            ):
                local.append("MANIFEST_BINDING")
        if local:
            failures.extend(f"SPR6_{value}:{fingerprint}" for value in local)
        else:
            identity = {
                "authority_origin": "SUBJECT_PROJECTION_REVALIDATION_SUCCESSOR_V6",
                "bucket": "HISTORICAL",
                "failure_fingerprint": fingerprint,
                "raw_failure": str(spec["raw_failure"]),
                "rule_id": RULE_ID,
                "transition_old_prefix": str(spec["parent_sha"])[:12],
                "transition_new_prefix": str(spec["commit_sha"])[:12],
                "subject_kind": "component_id",
                "subject_value": COMPONENT_ID,
                "source_commit_sha": str(spec["commit_sha"]),
                "record_path": expected_record_path(fingerprint),
                "correction_id": expected_id(fingerprint),
            }
            identities[fingerprint] = identity
            trusted[fingerprint] = dict(identity)
        previous = str(record.get("record_payload_sha256", previous))
    if previous != manifest.get("record_chain_terminal_sha256"):
        failures.append("SPR6_CHAIN_TERMINAL_INVALID")
    if failures:
        trusted = {}
        identities = {}
    committed = trusted if stage_dir is None else {}
    review = trusted if stage_dir is not None else {}
    return {
        "status": "PASS" if not failures else "FAIL",
        "mode": mode,
        "failures": sorted(set(failures)),
        "trusted_by_fingerprint": committed,
        "review_trusted_by_fingerprint": review,
        "authorized_identity_by_fingerprint": identities,
        "record_count": len(trusted),
        "wildcard_count": 0,
        "future_failure_auto_correction_count": 0,
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
    result = validate(
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
