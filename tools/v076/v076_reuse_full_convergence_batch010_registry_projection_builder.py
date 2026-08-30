#!/usr/bin/env python3
"""Build a non-authoritative, Batch-010-only Registry projection candidate.

The candidate is an external staging artifact.  It does not apply Registry or
Supersession Map writes and has no command capable of doing so.  Batch-010's
frozen 50-member tuple is imported from the successor materializer; no
Batch-009 stage, constants, or output paths are accepted.
"""

from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import json
import os
import re
import stat
import subprocess
from pathlib import Path
from typing import Any

import v076_reuse_full_convergence_batch010_materializer as materializer
import v076_reuse_exact_failure_correction_v2_full_convergence as convergence


BATCH_ID = "batch-010"
REGISTRY_REL = Path("docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json")
SUPERSESSION_REL = Path("docs/architecture/V076_SUPERSESSION_MAP.json")
CURRENT_OWNER_ID = "component.current.v075_runtime_owner"
CURRENT_OWNER_PATH = "scripts/v075_runtime/v075_runtime_owner.gd"
DOMAIN_ID = "current.v075_production_combat_candidate"
SOURCE_COMMITS = {
    "46b33bba77b3": "46b33bba77b3",  # resolved below to full object id
    "d701a81dce69": "d701a81dce693b584d52fbfca3e0e78b521ad775",
    "8208001e7be8": "8208001e7be8",  # resolved below to full object id
}
SOURCE_COMMIT_BY_PREFIX = {
    "46b33bba77b3": "e584cd4d8b0cd8afca7ff508cffcb05d1ba801a3",
    "d701a81dce69": "0d2a2b798f328624cc9aaee65be4187609b142a2",
    "8208001e7be8": "62ceba063d685871ee3869707862598da00ba649",
}
SCHEMA = (
    "space_syndicate.v076.reuse_full_convergence."
    "batch010_registry_projection_candidate.v1"
)
KIND = "NON_AUTHORITATIVE_EXACT_BATCH010_REGISTRY_PROJECTION"
OUTPUT_NAME = "batch010_registry_projection_candidate.json"


def canonical(value: Any) -> bytes:
    return convergence.canonical_bytes(value)


def sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def line_set(values: list[str]) -> str:
    return sha(("\n".join(sorted(values)) + "\n").encode("utf-8"))


def git(root: Path, *args: str) -> str:
    process = subprocess.run(
        ["git", *args], cwd=root, text=True, encoding="utf-8",
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if process.returncode:
        raise ValueError(f"GIT_FAILED:{' '.join(args)}:{process.stderr.strip()}")
    return process.stdout.strip()


def committed(root: Path, commit: str, relative: str) -> bytes:
    if re.fullmatch(r"[0-9a-f]{40}", commit) is None:
        raise ValueError("COMMIT_INVALID")
    if not relative or relative.startswith(("/", "../")) or ".." in Path(relative).parts:
        raise ValueError("PATH_INVALID")
    process = subprocess.run(
        ["git", "cat-file", "blob", "--", f"{commit}:{relative}"],
        cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if process.returncode:
        raise ValueError(f"MISSING_COMMITTED_INPUT:{relative}")
    return process.stdout


def _stage(root: Path, path: Path) -> Path:
    if not path.is_absolute():
        raise ValueError("STAGE_PATH_NOT_ABSOLUTE")
    resolved = Path(os.path.abspath(os.fspath(path)))
    if resolved.exists():
        raise ValueError("OUTPUT_STAGE_MUST_BE_FRESH_NONEXISTENT")
    try:
        resolved.relative_to(root.resolve())
    except ValueError:
        pass
    else:
        raise ValueError("OUTPUT_STAGE_MUST_BE_OUTSIDE_PROJECT")
    for parent in [resolved, *resolved.parents]:
        if (parent / ".git").exists() or os.path.islink(parent):
            raise ValueError("OUTPUT_STAGE_REPARSE_OR_GIT_ANCESTOR")
    return resolved


def _write_external(root: Path, output_stage: Path, document: dict[str, Any]) -> Path:
    stage = _stage(root, output_stage)
    stage.mkdir(parents=True, exist_ok=False)
    path = stage / OUTPUT_NAME
    with path.open("xb") as handle:
        handle.write(canonical(document))
        handle.flush()
        os.fsync(handle.fileno())
    return path


def _extract_identity(root: Path, source_commit: str, path: str) -> dict[str, Any]:
    return materializer.source_identity(root, source_commit, path)


def _class_name(identity: dict[str, Any], path: str) -> str:
    kind = identity["identity_kind"]
    if kind == "GDSCRIPT":
        return identity["declared_class_name"] or f"ANONYMOUS_PATH_BOUND:{path}"
    if kind == "GODOT_RESOURCE":
        script_class = identity["resource_script_class"]
        return f"{script_class}ResourceInstance" if script_class else f"ANONYMOUS_PATH_BOUND:{path}"
    if kind == "DOCUMENTATION":
        return {
            "docs/rules/v06_mechanic_status_registry.json": "V06MechanicStatusRegistryDocumentation",
            "docs/tabletop_rulebook_v06.md": "V06TabletopRulebookDocumentation",
        }[path]
    raise ValueError(f"IDENTITY_KIND_UNSUPPORTED:{path}")


def _component_id(path: str) -> str:
    stem = re.sub(r"[^a-z0-9]+", "_", Path(path).stem.lower()).strip("_")
    return f"component.current.{stem}"


def _component_row(root: Path, fingerprint: str, path: str, old: str, new: str) -> dict[str, Any]:
    source_commit = SOURCE_COMMIT_BY_PREFIX[old]
    identity = _extract_identity(root, source_commit, path)
    documentation = identity["identity_kind"] == "DOCUMENTATION"
    active = path == "resources/content/product_industry_catalog_v05.tres"
    component_id = _component_id(path)
    role = "DOCUMENTATION_ONLY" if documentation else ("PORT" if active else "TEST_SUPPORT")
    owner_id = CURRENT_OWNER_ID
    owner_path = CURRENT_OWNER_PATH
    return {
        "authority_source_kind": "component_inventory",
        "component_id": component_id,
        "class_name": _class_name(identity, path),
        "path": path,
        "domain_id": DOMAIN_ID,
        "component_role": role,
        "production_reachable": active,
        "writes_authority": False,
        "reads_authority": True,
        "owns_rng": False,
        "owns_tick": False,
        "owns_save": False,
        "owns_replay": False,
        "owns_identity": False,
        "owns_presentation": False,
        "owner_component_id": owner_id,
        "owner_path": owner_path,
        "reuse_disposition": "ADAPT_AS_CONSUMER" if active else "REFERENCE_ONLY" if documentation else "REUSE_AS_TEST",
        "reuse_source_ids": ["reuse.v075.combat_candidate"],
        "reuse_candidates_considered": ["reuse.v075.combat_candidate"],
        "new_component_justification": (
            "Batch-010 historical identity only; no new authority is introduced. "
            + ("The product catalog remains an existing Alpha01 input port." if active else "The historical path is detached from the current production composition.")
        ),
        "supersedes": [],
        "superseded_by": [],
        "change_class": "HISTORICAL_IDENTITY_BACKFILL",
        "focused_test_ids": ["v076_reuse_point_inertia_gate_selftest"],
        "golden_scenario_steps": [],
        "source_commit": source_commit,
        "source_blob_sha256": sha(committed(root, source_commit, path)),
        "transition_old_prefix": old,
        "transition_new_prefix": new,
        "failure_fingerprint": fingerprint,
    }


def _registry_target(root: Path, head: str, rows: list[dict[str, Any]]) -> tuple[dict[str, Any], bytes, bytes]:
    source = committed(root, head, REGISTRY_REL.as_posix())
    before = json.loads(source.decode("utf-8"))
    if not isinstance(before.get("component_inventory"), list):
        raise ValueError("REGISTRY_COMPONENT_INVENTORY_INVALID")
    existing_paths = {str(row.get("path", "")) for row in before["component_inventory"] if isinstance(row, dict)}
    existing_ids = {str(row.get("component_id", "")) for row in before["component_inventory"] if isinstance(row, dict)}
    if any(row["path"] in existing_paths for row in rows):
        raise ValueError("REGISTRY_PATH_COLLISION")
    if any(row["component_id"] in existing_ids for row in rows):
        raise ValueError("REGISTRY_COMPONENT_ID_COLLISION")
    if len({row["path"] for row in rows}) != len(rows) or len({row["component_id"] for row in rows}) != len(rows):
        raise ValueError("PROJECTION_PRIMARY_KEY_COLLISION")
    registry_fields = {
        "authority_source_kind", "component_id", "class_name", "path",
        "domain_id", "component_role", "production_reachable",
        "writes_authority", "reads_authority", "owns_rng", "owns_tick",
        "owns_save", "owns_replay", "owns_identity", "owns_presentation",
        "owner_component_id", "owner_path", "reuse_disposition",
        "reuse_source_ids", "reuse_candidates_considered",
        "new_component_justification", "supersedes", "superseded_by",
        "change_class", "focused_test_ids", "golden_scenario_steps",
    }
    registry_rows = [
        {key: value for key, value in row.items() if key in registry_fields}
        for row in rows
    ]
    after = copy.deepcopy(before)
    after["component_inventory"].extend(registry_rows)
    target = canonical(after)
    return after, source, target


def build_candidate(root: Path, output_stage: Path, head_ref: str = "HEAD") -> dict[str, Any]:
    root = root.resolve()
    head = git(root, "rev-parse", f"{head_ref}^{{commit}}")
    tree = git(root, "rev-parse", f"{head}^{{tree}}")
    frozen = materializer.validate_frozen_membership(root)
    rows: list[dict[str, Any]] = []
    source_current_blob_drift_count = 0
    for fingerprint, path, old, new in materializer.FROZEN_MEMBERSHIP_SPECS:
        source_payload = committed(root, SOURCE_COMMIT_BY_PREFIX[old], path)
        current_payload = committed(root, head, path)
        if source_payload != current_payload:
            source_current_blob_drift_count += 1
        rows.append(_component_row(root, fingerprint, path, old, new))
    if len(rows) != 50:
        raise ValueError("BATCH010_ROW_COUNT_INVALID")
    if source_current_blob_drift_count:
        raise ValueError(f"SOURCE_CURRENT_BLOB_DRIFT:{source_current_blob_drift_count}")
    if sum(row["component_role"] == "DOCUMENTATION_ONLY" for row in rows) != 2:
        raise ValueError("BATCH010_DOCUMENTATION_CLASSIFICATION_INVALID")
    active_count = sum(row["production_reachable"] is True for row in rows)
    if active_count != 1:
        raise ValueError(f"BATCH010_ACTIVE_COUNT_INVALID:{active_count}")
    target_doc, source_bytes, target_bytes = _registry_target(root, head, rows)
    mutation = {
        "target_path": REGISTRY_REL.as_posix(),
        "operation": "APPEND_EXACT_BATCH010_COMPONENT_INVENTORY_ROWS",
        "locator": f"batch_id={BATCH_ID};count=50;failure_set_sha256={materializer.SEALED_MEMBERSHIP_SET_SHA256}",
        "before_canonical_sha256": sha(source_bytes),
        "after_canonical_sha256": sha(target_bytes),
    }
    candidate = {
        "schema_version": SCHEMA,
        "candidate_kind": KIND,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "batch_id": BATCH_ID,
        "evaluated_head_sha": head,
        "evaluated_tree_sha": tree,
        "frozen_membership_head_sha": materializer.SEALED_MEMBERSHIP_HEAD_SHA,
        "frozen_membership_tree_sha": materializer.SEALED_MEMBERSHIP_TREE_SHA,
        "frozen_membership_plan_sha256": materializer.SEALED_MEMBERSHIP_PLAN_SHA256,
        "failure_count": 50,
        "failure_fingerprint_set_sha256": materializer.SEALED_MEMBERSHIP_SET_SHA256,
        "path_set_sha256": line_set([row["path"] for row in rows]),
        "component_id_set_sha256": line_set([row["component_id"] for row in rows]),
        "classification_counts": {
            "HISTORICAL_TEST_ONLY": 48,
            "HISTORICAL_ACTIVE_LINEAGE_REGISTERED": 1,
            "HISTORICAL_DOCUMENTATION_ONLY": 2,
            "UNKNOWN": 0,
        },
        "source_commit_set": sorted({row["source_commit"] for row in rows}),
        "source_current_blob_drift_count": source_current_blob_drift_count,
        "rows": rows,
        "target_registry": {
            "path": REGISTRY_REL.as_posix(),
            "source_bytes_sha256": sha(source_bytes),
            "target_bytes_base64": base64.b64encode(target_bytes).decode("ascii"),
            "target_bytes_sha256": sha(target_bytes),
            "target_byte_count": len(target_bytes),
        },
        "mutation_inventory": [mutation],
        "mutation_inventory_sha256": sha(canonical([mutation])),
        "required_review_ids": ["PRIMARY", "INDEPENDENT"],
        "review_status": "PENDING",
        "go_claim": False,
        "official_registry_write_count": 0,
        "official_map_write_count": 0,
        "next_phase": "OBTAIN_TWO_DISTINCT_EXACT_TARGET_REVIEWS",
    }
    candidate["candidate_payload_sha256"] = sha(canonical(candidate))
    path = _write_external(root, output_stage, candidate)
    candidate["staging_path"] = path.as_posix()
    return candidate


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--output-stage", type=Path, required=True)
    parser.add_argument("--head-ref", default="HEAD")
    args = parser.parse_args(argv)
    try:
        result = build_candidate(args.root, args.output_stage, args.head_ref)
    except (ValueError, materializer.MaterializerError) as exc:
        print(json.dumps({"status": "FAIL", "batch_id": BATCH_ID, "error": str(exc), "official_registry_write_count": 0, "official_map_write_count": 0}, sort_keys=True))
        return 2
    print(json.dumps({"status": "PASS", "batch_id": BATCH_ID, "candidate_payload_sha256": result["candidate_payload_sha256"], "row_count": result["failure_count"], "official_registry_write_count": 0, "official_map_write_count": 0}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
