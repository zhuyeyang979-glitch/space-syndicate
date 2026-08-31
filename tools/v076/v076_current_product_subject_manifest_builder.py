#!/usr/bin/env python3
"""Build one append-only current-product-subject manifest from a committed Head.

The manifest binds registry-derived production paths and the explicit runtime
composition boundary to immutable Git bytes.  It never reads product bytes from
the worktree and refuses to overwrite an existing receipt.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
BRANCH = "codex/v076-continuous-playable-vertical-slice-770d741f"
POINT_INERTIA_BASE = "f6fe547e1e1db57a8bb3a12eab1d9225d4abdca5"
MASTER_TASK_ID = (
    "V076_CURRENT_SUBJECT_MCP_REVALIDATION_REUSE_FULL_CONVERGENCE_"
    "AND_DECK_PRESENTATION_RESUME_V2"
)
AUTHORIZATION_ID = (
    "USER_AUTHORIZATION_V076_CURRENT_SUBJECT_CONVERGENCE_"
    "AND_COMMERCIAL_RESUME_20260830"
)
RUNTIME_BOUNDARY_PATHS = (
    "project.godot",
    "scenes/main.tscn",
    "scenes/runtime/V075RuntimeComposition.tscn",
    "scenes/ui/v075/V075SampleGameScreen.tscn",
    "scripts/v075_runtime/v075_runtime_owner.gd",
    "scripts/v075_runtime/v075_application_bootstrap.gd",
)
PRODUCT_SUFFIXES = (
    ".gd",
    ".tscn",
    ".tres",
    ".res",
    ".gdshader",
    ".gdshaderinc",
    ".shader",
    ".theme",
)
NON_PRODUCT_PREFIXES = (
    ".github/",
    "docs/",
    "reports/",
    "tests/",
    "tools/",
    "scripts/tools/",
)


def _git(repo: Path, *args: str, text: bool = True) -> str | bytes:
    return subprocess.check_output(
        ["git", *args], cwd=repo, text=text, encoding="utf-8" if text else None
    )


def _canonical_json_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, indent=2).encode("utf-8") + b"\n"
    )


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _commit_bytes(repo: Path, head: str, path: str) -> bytes:
    return _git(repo, "show", f"{head}:{path}", text=False)  # type: ignore[return-value]


def _blob_oid(repo: Path, head: str, path: str) -> str:
    return str(_git(repo, "rev-parse", f"{head}:{path}")).strip()


def _binding(repo: Path, head: str, path: str) -> dict[str, Any]:
    data = _commit_bytes(repo, head, path)
    return {
        "path": path,
        "sha256": _sha256(data),
        "git_blob_sha1": _blob_oid(repo, head, path),
        "size_bytes": len(data),
    }


def _is_ancestor(repo: Path, ancestor: str, descendant: str) -> bool:
    return (
        subprocess.run(
            ["git", "merge-base", "--is-ancestor", ancestor, descendant],
            cwd=repo,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def _path_exists(repo: Path, head: str, path: str) -> bool:
    return (
        subprocess.run(
            ["git", "cat-file", "-e", f"{head}:{path}"],
            cwd=repo,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def _changed_paths(repo: Path, before: str, after: str) -> list[str]:
    raw = _git(
        repo,
        "diff",
        "--name-only",
        "--no-renames",
        "-z",
        before,
        after,
        text=False,
    )
    assert isinstance(raw, bytes)
    return sorted(
        item.decode("utf-8", errors="surrogateescape").replace("\\", "/")
        for item in raw.split(b"\0")
        if item
    )


def _commits(repo: Path, before: str, after: str) -> list[str]:
    value = str(_git(repo, "rev-list", "--reverse", f"{before}..{after}"))
    return [line for line in value.splitlines() if line]


def _is_product_path(path: str) -> bool:
    normalized = path.replace("\\", "/")
    lowered = normalized.lower()
    if lowered == "project.godot":
        return True
    if any(lowered.startswith(prefix) for prefix in NON_PRODUCT_PREFIXES):
        return False
    if lowered.endswith(PRODUCT_SUFFIXES):
        return True
    return (
        lowered.endswith(".json")
        and (lowered.startswith("data/") or lowered.startswith("resources/"))
    )


def _sequence_sha256(values: list[str]) -> str:
    return _sha256("".join(f"{value}\n" for value in values).encode("utf-8"))


def _transition(repo: Path, before: str, after: str) -> dict[str, Any]:
    commits = _commits(repo, before, after)
    paths = _changed_paths(repo, before, after)
    product_paths = [path for path in paths if _is_product_path(path)]
    return {
        "commit_count": len(commits),
        "commit_set_sha256": _sequence_sha256(commits),
        "commits": commits,
        "changed_path_count": len(paths),
        "changed_path_set_sha256": _sequence_sha256(paths),
        "product_delta_path_count": len(product_paths),
        "product_delta_paths": product_paths,
        "non_product_delta_path_count": len(paths) - len(product_paths),
    }


def _first_mismatch(actual: Any, expected: Any, path: str = "$" ) -> str | None:
    if type(actual) is not type(expected):
        return f"{path}:TYPE:{type(actual).__name__}!={type(expected).__name__}"
    if isinstance(expected, dict):
        actual_keys = set(actual)
        expected_keys = set(expected)
        if actual_keys != expected_keys:
            return (
                f"{path}:KEYS:missing={sorted(expected_keys - actual_keys)}:"
                f"extra={sorted(actual_keys - expected_keys)}"
            )
        for key in expected:
            mismatch = _first_mismatch(actual[key], expected[key], f"{path}.{key}")
            if mismatch:
                return mismatch
        return None
    if isinstance(expected, list):
        if len(actual) != len(expected):
            return f"{path}:LENGTH:{len(actual)}!={len(expected)}"
        for index, value in enumerate(expected):
            mismatch = _first_mismatch(actual[index], value, f"{path}[{index}]")
            if mismatch:
                return mismatch
        return None
    if actual != expected:
        return f"{path}:VALUE:{actual!r}!={expected!r}"
    return None


def _registered_product_paths(registry: dict[str, Any]) -> list[str]:
    paths: set[str] = set()
    for row in registry.get("component_inventory", []):
        if not isinstance(row, dict) or row.get("production_reachable") is not True:
            continue
        for field in ("path", "owner_path"):
            value = row.get(field)
            if isinstance(value, str) and value:
                paths.add(value.replace("\\", "/"))
    for row in registry.get("unique_owner_domains", []):
        if not isinstance(row, dict):
            continue
        for field in ("owner_path", "root_resource", "source_json"):
            value = row.get(field)
            if isinstance(value, str) and value:
                paths.add(value.replace("\\", "/"))
    return sorted(paths)


def build_manifest(
    repo: Path,
    subject_head: str,
    previous_head: str,
    previous_tree: str,
    recorded_at_utc: str,
    evaluated_head: str | None = None,
) -> dict[str, Any]:
    subject_head = str(_git(repo, "rev-parse", subject_head)).strip()
    subject_tree = str(_git(repo, "rev-parse", f"{subject_head}^{{tree}}")).strip()
    previous_head = str(_git(repo, "rev-parse", previous_head)).strip()
    actual_previous_tree = str(
        _git(repo, "rev-parse", f"{previous_head}^{{tree}}")
    ).strip()
    if actual_previous_tree != previous_tree:
        raise SystemExit(
            f"PREVIOUS_TREE_MISMATCH:{previous_tree}:{actual_previous_tree}"
        )
    evaluated_head = str(_git(repo, "rev-parse", evaluated_head or subject_head)).strip()
    evaluated_tree = str(
        _git(repo, "rev-parse", f"{evaluated_head}^{{tree}}")
    ).strip()
    if not _is_ancestor(repo, previous_head, subject_head):
        raise SystemExit("PREVIOUS_SUBJECT_NOT_ANCESTOR")
    if not _is_ancestor(repo, subject_head, evaluated_head):
        raise SystemExit("SUBJECT_NOT_ANCESTOR_OF_EVALUATED_HEAD")
    if not _is_ancestor(repo, POINT_INERTIA_BASE, subject_head):
        raise SystemExit("SUBJECT_NOT_DESCENDANT_OF_POINT_INERTIA_BASE")

    subject_registry_bytes = _commit_bytes(repo, subject_head, REGISTRY_PATH)
    evaluated_registry_bytes = _commit_bytes(repo, evaluated_head, REGISTRY_PATH)
    subject_registry = json.loads(subject_registry_bytes.decode("utf-8"))
    evaluated_registry = json.loads(evaluated_registry_bytes.decode("utf-8"))
    product_paths = _registered_product_paths(subject_registry)
    evaluated_product_paths = _registered_product_paths(evaluated_registry)
    if evaluated_product_paths != product_paths:
        raise SystemExit("REGISTRY_PRODUCT_PATH_SET_DRIFT_AFTER_SUBJECT")

    previous_to_subject = _transition(repo, previous_head, subject_head)
    subject_to_evaluated = _transition(repo, subject_head, evaluated_head)
    if subject_to_evaluated["product_delta_path_count"]:
        raise SystemExit(
            "PRODUCT_BYTES_CHANGED_AFTER_SUBJECT:"
            + ",".join(subject_to_evaluated["product_delta_paths"])
        )

    covered_paths = set(product_paths) | set(RUNTIME_BOUNDARY_PATHS)
    observed_product_paths = sorted(
        set(previous_to_subject["product_delta_paths"])
        | set(subject_to_evaluated["product_delta_paths"])
    )
    unknown_product_paths = [
        path for path in observed_product_paths if path not in covered_paths
    ]
    if unknown_product_paths:
        raise SystemExit(
            "UNKNOWN_PRODUCT_PATHS:" + ",".join(unknown_product_paths)
        )

    subject_missing_paths = [
        path for path in product_paths if not _path_exists(repo, subject_head, path)
    ]
    evaluated_missing_paths = [
        path for path in product_paths if not _path_exists(repo, evaluated_head, path)
    ]
    if subject_missing_paths:
        raise SystemExit(
            "SUBJECT_REGISTERED_PRODUCT_PATHS_MISSING:"
            + ",".join(subject_missing_paths)
        )
    if evaluated_missing_paths:
        raise SystemExit(
            "EVALUATED_REGISTERED_PRODUCT_PATHS_MISSING:"
            + ",".join(evaluated_missing_paths)
        )

    bindings = [_binding(repo, subject_head, path) for path in product_paths]
    evaluated_bindings = {
        path: _binding(repo, evaluated_head, path) for path in product_paths
    }
    registered_drift_paths = [
        row["path"]
        for row in bindings
        if row["sha256"] != evaluated_bindings[row["path"]]["sha256"]
        or row["git_blob_sha1"]
        != evaluated_bindings[row["path"]]["git_blob_sha1"]
        or row["size_bytes"] != evaluated_bindings[row["path"]]["size_bytes"]
    ]
    if registered_drift_paths:
        raise SystemExit(
            "REGISTERED_PRODUCT_BLOB_DRIFT_AFTER_SUBJECT:"
            + ",".join(registered_drift_paths)
        )

    runtime_bindings = []
    for path in RUNTIME_BOUNDARY_PATHS:
        row = _binding(repo, subject_head, path)
        evaluated_row = _binding(repo, evaluated_head, path)
        row["evaluated_head_drift"] = any(
            row[key] != evaluated_row[key]
            for key in ("sha256", "git_blob_sha1", "size_bytes")
        )
        if row["evaluated_head_drift"]:
            raise SystemExit(f"RUNTIME_BOUNDARY_DRIFT_AFTER_SUBJECT:{path}")
        runtime_bindings.append(row)

    path_set_payload = "".join(f"{path}\n" for path in product_paths).encode("utf-8")
    sha_map_payload = "".join(
        f"{row['path']}|{row['sha256']}\n" for row in bindings
    ).encode("utf-8")
    blob_map_payload = "".join(
        f"{row['path']}|{row['git_blob_sha1']}\n" for row in bindings
    ).encode("utf-8")
    short = subject_head[:8]
    receipt_root = f"reports/reuse/full_convergence/current_subject/{short}"
    observed_product_count = len(observed_product_paths)
    covered_product_count = observed_product_count - len(unknown_product_paths)
    coverage_percent = (
        100
        if observed_product_count == 0
        else (covered_product_count * 100) // observed_product_count
    )

    return {
        "schema_version": "space_syndicate.v076.candidate_subject_manifest.v3",
        "manifest_id": f"v076-candidate-subject-{short}",
        "master_task_id": MASTER_TASK_ID,
        "authorization_id": AUTHORIZATION_ID,
        "recorded_at_utc": recorded_at_utc,
        "status": "EXACT_SUBJECT_REGISTERED_PRODUCTION_REVALIDATION_PENDING",
        "subject": {
            "head_sha": subject_head,
            "tree_sha": subject_tree,
            "branch": BRANCH,
            "is_head_ancestor_of_evaluated_governance_head": _is_ancestor(
                repo, subject_head, evaluated_head
            ),
            "is_descendant_of_point_inertia_base": _is_ancestor(
                repo, POINT_INERTIA_BASE, subject_head
            ),
        },
        "previous_subject": {
            "head_sha": previous_head,
            "tree_sha": previous_tree,
            "transition_kind": "APPEND_ONLY_SUBJECT_ADVANCE",
        },
        "evaluated_governance_head": {
            "head_sha": evaluated_head,
            "tree_sha": evaluated_tree,
            "branch": BRANCH,
            "manifest_landing_head": "PENDING_SUCCESSOR_COMMIT",
            "raw_report_status": "PENDING_CURRENT_EVALUATED_HEAD_SCAN",
            "raw_report_path": None,
            "raw_report_sha256": None,
        },
        "previous_subject_to_subject": {
            **previous_to_subject,
            "product_delta_definition": (
                "Godot product scripts/scenes/resources/shaders/project.godot outside "
                "tests, tooling, docs, reports, and CI, plus runtime data/resources JSON."
            ),
            "covered_product_delta_path_count": covered_product_count,
            "unknown_product_delta_paths": unknown_product_paths,
        },
        "subject_to_evaluated_governance_head": {
            **subject_to_evaluated,
            "product_delta_definition": (
                "Godot product scripts/scenes/resources/shaders/project.godot outside "
                "tests, tooling, docs, reports, and CI, plus runtime data/resources JSON."
            ),
            "product_bytes_changed_after_subject": (
                subject_to_evaluated["product_delta_path_count"] != 0
            ),
            "tree_binding_is_distinct_from_subject_tree": evaluated_tree != subject_tree,
            "allowed_non_product_delta_classes": [
                "GOVERNANCE_REGISTRY",
                "GOVERNANCE_SCHEMA",
                "EVIDENCE_MANIFEST",
                "EVIDENCE_RECEIPT",
                "MCP_RECEIPT",
                "MCP_EVIDENCE",
                "REPORT",
                "TOOLING",
                "CI_WORKFLOW",
            ],
        },
        "product_path_coverage": {
            "registry_path": REGISTRY_PATH,
            "registry_sha256_at_subject_head": _sha256(subject_registry_bytes),
            "registry_sha256_at_evaluated_head": _sha256(evaluated_registry_bytes),
            "derivation": {
                "component_inventory_selector": "production_reachable === true",
                "component_inventory_fields": ["path", "owner_path"],
                "unique_owner_domain_fields": [
                    "owner_path",
                    "root_resource",
                    "source_json",
                ],
                "empty_values_dropped": True,
                "path_separator_normalization": "BACKSLASH_TO_FORWARD_SLASH",
                "dedupe": "CASE_SENSITIVE_EXACT",
                "sort": "ORDINAL_ASCENDING",
                "encoding": "UTF8_NO_BOM",
                "record_separator": "LF",
                "terminal_lf": True,
                "product_delta_classifier": {
                    "suffixes": list(PRODUCT_SUFFIXES),
                    "non_product_prefixes": list(NON_PRODUCT_PREFIXES),
                    "runtime_json_prefixes": ["data/", "resources/"],
                },
            },
            "registered_path_count": len(product_paths),
            "registered_path_set_sha256": _sha256(path_set_payload),
            "registered_path_set_payload": "path + LF",
            "subject_path_sha256_map_sha256": _sha256(sha_map_payload),
            "subject_path_sha256_map_payload": (
                "path + ASCII_PIPE + lowercase_content_sha256 + LF"
            ),
            "subject_path_blob_map_sha256": _sha256(blob_map_payload),
            "subject_path_blob_map_payload": (
                "path + ASCII_PIPE + lowercase_git_blob_sha1 + LF"
            ),
            "subject_missing_path_count": len(subject_missing_paths),
            "subject_missing_paths": subject_missing_paths,
            "evaluated_head_missing_path_count": len(evaluated_missing_paths),
            "evaluated_head_missing_paths": evaluated_missing_paths,
            "registered_path_blob_drift_count": len(registered_drift_paths),
            "registered_path_blob_drift_paths": registered_drift_paths,
            "observed_product_delta_path_count": observed_product_count,
            "observed_product_delta_paths": observed_product_paths,
            "covered_product_delta_path_count": covered_product_count,
            "unknown_product_path_count": len(unknown_product_paths),
            "unknown_product_paths": unknown_product_paths,
            "coverage_percent": coverage_percent,
        },
        "runtime_boundary_bindings": runtime_bindings,
        "product_path_bindings": bindings,
        "required_current_subject_receipts": [
            {"path": f"{receipt_root}/step09_receipt.json", "status": "PENDING"},
            {"path": f"{receipt_root}/step11_receipt.json", "status": "PENDING"},
            {"path": f"{receipt_root}/step12_receipt.json", "status": "PENDING"},
        ],
        "claims": {
            "current_subject_production_revalidation_complete": False,
            "production_cutover_authorized": False,
            "production_green": False,
            "human_green": False,
            "human_retest_deferred": True,
            "step09_status": "REGRESSED_WITH_EVIDENCE",
            "step11_status": "REGRESSED_WITH_EVIDENCE",
            "step12_status": "REGRESSED_WITH_EVIDENCE",
            "step13_status": "PENDING",
            "step14_status": "PENDING",
            "step15_status": "PENDING",
        },
        "immutability": {
            "historical_receipts_overwritten": False,
            "historical_receipts_deleted": False,
            "append_only": True,
            "self_reference_count": 0,
        },
    }


def validate_manifest(
    repo: Path,
    manifest: dict[str, Any],
    manifest_path: str | None = None,
) -> dict[str, Any]:
    required_objects = ("subject", "previous_subject", "evaluated_governance_head")
    for key in required_objects:
        if not isinstance(manifest.get(key), dict):
            raise SystemExit(f"MANIFEST_REQUIRED_OBJECT_MISSING:{key}")
    subject = manifest["subject"]
    previous = manifest["previous_subject"]
    evaluated = manifest["evaluated_governance_head"]
    recorded_at = manifest.get("recorded_at_utc")
    if not isinstance(recorded_at, str) or not recorded_at:
        raise SystemExit("MANIFEST_RECORDED_AT_INVALID")
    if manifest_path and _path_exists(
        repo, str(evaluated.get("head_sha", "")), manifest_path
    ):
        raise SystemExit("MANIFEST_SELF_REFERENCE_PRESENT_IN_EVALUATED_HEAD")
    expected = build_manifest(
        repo,
        str(subject.get("head_sha", "")),
        str(previous.get("head_sha", "")),
        str(previous.get("tree_sha", "")),
        recorded_at,
        str(evaluated.get("head_sha", "")),
    )
    mismatch = _first_mismatch(manifest, expected)
    if mismatch:
        raise SystemExit(f"MANIFEST_RECOMPUTE_MISMATCH:{mismatch}")
    return expected


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--subject-head", required=True)
    parser.add_argument("--previous-head", required=True)
    parser.add_argument("--previous-tree", required=True)
    parser.add_argument("--evaluated-head")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--recorded-at-utc")
    args = parser.parse_args()

    repo = args.repo.resolve()
    output = args.output if args.output.is_absolute() else repo / args.output
    if output.exists():
        raise SystemExit(f"APPEND_ONLY_OUTPUT_EXISTS:{output}")
    recorded_at = args.recorded_at_utc or datetime.now(timezone.utc).isoformat(
        timespec="milliseconds"
    ).replace("+00:00", "Z")
    manifest = build_manifest(
        repo,
        args.subject_head,
        args.previous_head,
        args.previous_tree,
        recorded_at,
        args.evaluated_head,
    )
    validate_manifest(repo, manifest)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(_canonical_json_bytes(manifest))
    print(f"CURRENT_PRODUCT_SUBJECT_MANIFEST={output}")
    print(f"CURRENT_PRODUCT_SUBJECT_HEAD={manifest['subject']['head_sha']}")
    print(f"CURRENT_PRODUCT_SUBJECT_TREE={manifest['subject']['tree_sha']}")
    print(
        "CURRENT_PRODUCT_SUBJECT_PATH_COVERAGE="
        f"{manifest['product_path_coverage']['coverage_percent']}_PERCENT"
    )
    print(
        "CURRENT_PRODUCT_SUBJECT_UNKNOWN_PATH_COUNT="
        f"{manifest['product_path_coverage']['unknown_product_path_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
