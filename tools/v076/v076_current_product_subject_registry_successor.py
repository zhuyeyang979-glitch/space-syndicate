#!/usr/bin/env python3
"""Advance the three current-subject pointers with append-only evidence.

This is a narrow governance successor.  It does not edit product files or old
subject evidence and refuses to run unless every predecessor identity is exact.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any

import v076_current_product_subject_manifest_builder as manifest_builder


OLD_HEAD = "2ce2ce212e8252ddd554a03da8408a9cb11cba57"
OLD_TREE = "97cbe5aab1a5489d402b1a03ce02f307d00bbe1c"
NEW_HEAD = "ac5efcc5a5119b8022b573333f707b3a73bff590"
NEW_TREE = "9757eef0e73118f89356b0c09833a44c2c76f8ee"
MANIFEST_PATH = (
    "reports/reuse/full_convergence/candidate_subject_manifest_ac5efcc5.json"
)
STAGE_ID = "V076_REUSE_GATE_CURRENT_PRODUCT_SUBJECT_REGISTRATION_AC5EFCC5"


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise SystemExit(f"JSON_ROOT_NOT_OBJECT:{path}")
    return value


def _expect(condition: bool, failure: str) -> None:
    if not condition:
        raise SystemExit(failure)


def _pretty(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def _canonical(value: dict[str, Any]) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def _head_bytes(repo: Path, relative_path: str) -> bytes:
    return subprocess.check_output(
        ["git", "show", f"HEAD:{relative_path}"], cwd=repo
    )


def _replace_once(text: str, old: str, new: str, failure: str) -> str:
    if text.count(old) != 1:
        raise SystemExit(f"{failure}:COUNT={text.count(old)}")
    return text.replace(old, new, 1)


def _replace_json_value_once(
    text: str, field: str, old_value: Any, new_value: Any, failure: str
) -> str:
    old = f'{json.dumps(field)}: {json.dumps(old_value, ensure_ascii=False)}'
    new = f'{json.dumps(field)}: {json.dumps(new_value, ensure_ascii=False)}'
    return _replace_once(text, old, new, failure)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    args = parser.parse_args()
    repo = args.repo.resolve()

    registry_path = repo / "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
    inherited_path = repo / "docs/architecture/V076_INHERITED_GREEN_LEDGER.json"
    golden_path = repo / "docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json"
    manifest_path = repo / MANIFEST_PATH

    registry_base = _head_bytes(
        repo, "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
    )
    inherited_base = _head_bytes(
        repo, "docs/architecture/V076_INHERITED_GREEN_LEDGER.json"
    )
    golden_base = _head_bytes(
        repo, "docs/architecture/V076_ALPHA07_GOLDEN_PLAYTEST_SCENARIO.json"
    )
    registry = json.loads(registry_base.decode("utf-8"))
    inherited = json.loads(inherited_base.decode("utf-8"))
    golden = json.loads(golden_base.decode("utf-8"))
    manifest = _load(manifest_path)

    manifest_builder.validate_manifest(repo, manifest, MANIFEST_PATH)

    _expect(registry.get("candidate_head_sha") == OLD_HEAD, "REGISTRY_PREDECESSOR_HEAD_MISMATCH")
    _expect(registry.get("candidate_tree_sha") == OLD_TREE, "REGISTRY_PREDECESSOR_TREE_MISMATCH")
    _expect(golden.get("candidate_head_sha") == OLD_HEAD, "GOLDEN_PREDECESSOR_HEAD_MISMATCH")
    _expect(golden.get("candidate_tree_sha") == OLD_TREE, "GOLDEN_PREDECESSOR_TREE_MISMATCH")
    candidate = inherited.get("candidate")
    _expect(isinstance(candidate, dict), "INHERITED_CANDIDATE_MISSING")
    _expect(candidate.get("head_sha") == OLD_HEAD, "INHERITED_PREDECESSOR_HEAD_MISMATCH")
    _expect(candidate.get("tree_sha") == OLD_TREE, "INHERITED_PREDECESSOR_TREE_MISMATCH")
    _expect(manifest.get("subject", {}).get("head_sha") == NEW_HEAD, "MANIFEST_SUBJECT_HEAD_MISMATCH")
    _expect(manifest.get("subject", {}).get("tree_sha") == NEW_TREE, "MANIFEST_SUBJECT_TREE_MISMATCH")
    _expect(manifest.get("previous_subject", {}).get("head_sha") == OLD_HEAD, "MANIFEST_PREDECESSOR_HEAD_MISMATCH")
    _expect(manifest.get("previous_subject", {}).get("tree_sha") == OLD_TREE, "MANIFEST_PREDECESSOR_TREE_MISMATCH")
    coverage = manifest.get("product_path_coverage", {})
    _expect(coverage.get("coverage_percent") == 100, "MANIFEST_PRODUCT_COVERAGE_INVALID")
    _expect(coverage.get("unknown_product_path_count") == 0, "MANIFEST_UNKNOWN_PRODUCT_PATH")
    _expect(coverage.get("registered_path_blob_drift_count") == 0, "MANIFEST_PRODUCT_BLOB_DRIFT")
    _expect(
        manifest.get("previous_subject_to_subject", {}).get("product_delta_paths")
        == ["scripts/v075_runtime/v075_runtime_owner.gd"],
        "MANIFEST_PREVIOUS_TO_SUBJECT_PRODUCT_DELTA_MISMATCH",
    )
    _expect(
        manifest.get("subject_to_evaluated_governance_head", {}).get(
            "product_delta_path_count"
        )
        == 0,
        "MANIFEST_SUBJECT_TO_EVALUATED_PRODUCT_DRIFT",
    )

    stages = inherited.get("stages")
    _expect(isinstance(stages, list), "INHERITED_STAGES_MISSING")
    _expect(
        not any(isinstance(row, dict) and row.get("stage_id") == STAGE_ID for row in stages),
        "APPEND_ONLY_STAGE_ALREADY_EXISTS",
    )
    canonical_status = inherited.get("canonical_pr_status")
    _expect(isinstance(canonical_status, dict), "CANONICAL_STATUS_MISSING")
    _expect(
        canonical_status.get("latest_completed_stage")
        == "V076_REUSE_GATE_CURRENT_PRODUCT_SUBJECT_REGISTRATION_2CE2CE21",
        "CANONICAL_PREDECESSOR_STAGE_MISMATCH",
    )

    manifest_sha256 = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    stage = {
            "stage_id": STAGE_ID,
            "ledger_status": "SUBJECT_REGISTERED_PENDING_GATE",
            "head_sha": NEW_HEAD,
            "tree_sha": NEW_TREE,
            "change_class": "CROSS_DOMAIN_INTEGRATION",
            "stage_kind": "INFRASTRUCTURE",
            "infrastructure_justification": (
                "Append-only registration of the exact ac5efcc5 product subject after "
                "2ce2ce21. The product change adds current-subject STEP11/STEP12 witness "
                "plumbing through the existing V075 Runtime Owner and creates no new "
                "gameplay, asset, map, card-catalog, tick, RNG, or presentation Owner. "
                "STEP09, STEP11, and STEP12 remain pending exact-subject production "
                "revalidation; no production-green or human-green claim is made."
            ),
            "golden_step_ids": [],
            "current_owner": "V075RuntimeOwner",
            "reused_owners": [
                "V075RuntimeOwner",
                "V076Kernel",
                "V076SharedHalfEdgePartition",
                "V076PresentationAnimationDirector",
            ],
            "evidence": [
                {
                    "evidence_id": "v076-current-product-subject-manifest-ac5efcc5",
                    "result": "PASS",
                    "receipt_path": MANIFEST_PATH,
                    "receipt_sha256": manifest_sha256,
                    "subject_head_sha": NEW_HEAD,
                    "subject_tree_sha": NEW_TREE,
                    "product_delta_path_count_to_evaluated_head": manifest[
                        "subject_to_evaluated_governance_head"
                    ]["product_delta_path_count"],
                    "product_path_coverage_percent": coverage["coverage_percent"],
                    "unknown_product_path_count": coverage[
                        "unknown_product_path_count"
                    ],
                }
            ],
            "not_claimed": [
                "step09_current_subject_production_green",
                "step11_current_subject_production_green",
                "step12_current_subject_production_green",
                "production_cutover",
                "human_playtest_pass",
                "full_alpha07_production_green",
                "full_repository_reproof",
            ],
        }

    docs_claim = inherited.get("docs_only_inheritance")
    _expect(isinstance(docs_claim, dict), "DOCS_ONLY_INHERITANCE_MISSING")
    new_current_claim = (
        "The exact current product subject is ac5efcc5a5119b8022b573333f707b3a73bff590 "
        "/ 9757eef0e73118f89356b0c09833a44c2c76f8ee. STEP09, STEP11, and STEP12 "
        "remain REGRESSED_WITH_EVIDENCE pending new exact-subject production revalidation. "
        "The 2ce2ce21 receipts remain immutable historical evidence and are not current "
        "production claims. Production cutover is not authorized or claimed. STEP13 remains "
        "PENDING; Human Green, STEP13-STEP15, and full-product production green remain false "
        "or pending."
    )
    old_current_claim = docs_claim.get("current_claim")

    scope = inherited.get("canonical_change_scope")
    _expect(isinstance(scope, dict), "CANONICAL_CHANGE_SCOPE_MISSING")
    old_scope_reason = scope.get("why_focused_tests_are_sufficient")
    new_scope_reason = (
        "The current product delta advances only scripts/v075_runtime/v075_runtime_owner.gd "
        "through the existing V075 Runtime Owner to expose exact STEP11/STEP12 production "
        "witnesses. It creates no new gameplay, presentation, tutorial, clock, tick, RNG, "
        "card-catalog, asset, map, hand, track, save, replay, or receipt Owner. The scoped "
        "MCP landing receipt and focused current-subject tests cover the changed Owner byte; "
        "the inherited Kernel, Half-Edge sphere, military, Monster, card lifecycle, AI/privacy, "
        "application, UI, and presentation sentinels remain required. STEP09, STEP11, and "
        "STEP12 remain REGRESSED_WITH_EVIDENCE pending exact-subject production revalidation; "
        "production cutover, Human Green, STEP13-STEP15, and full-world reproof remain false "
        "or pending."
    )

    registry_text = registry_base.decode("utf-8")
    registry_text = _replace_once(
        registry_text,
        f'"candidate_head_sha":"{OLD_HEAD}","candidate_tree_sha":"{OLD_TREE}"',
        f'"candidate_head_sha":"{NEW_HEAD}","candidate_tree_sha":"{NEW_TREE}"',
        "REGISTRY_CANDIDATE_TEXT_MISMATCH",
    )

    golden_text = golden_base.decode("utf-8")
    golden_text = _replace_json_value_once(
        golden_text,
        "candidate_head_sha",
        OLD_HEAD,
        NEW_HEAD,
        "GOLDEN_HEAD_TEXT_MISMATCH",
    )
    golden_text = _replace_json_value_once(
        golden_text,
        "candidate_tree_sha",
        OLD_TREE,
        NEW_TREE,
        "GOLDEN_TREE_TEXT_MISMATCH",
    )

    inherited_text = inherited_base.decode("utf-8")
    candidate_block = (
        '  "candidate": {\n'
        f'    "branch": "codex/v076-continuous-playable-vertical-slice-770d741f",\n'
        f'    "head_sha": "{OLD_HEAD}",\n'
        f'    "tree_sha": "{OLD_TREE}",'
    )
    successor_candidate_block = (
        '  "candidate": {\n'
        f'    "branch": "codex/v076-continuous-playable-vertical-slice-770d741f",\n'
        f'    "head_sha": "{NEW_HEAD}",\n'
        f'    "tree_sha": "{NEW_TREE}",'
    )
    inherited_text = _replace_once(
        inherited_text,
        candidate_block,
        successor_candidate_block,
        "INHERITED_CANDIDATE_BLOCK_MISMATCH",
    )
    stage_text = json.dumps(stage, ensure_ascii=False, indent=2)
    stage_text = "\n".join("    " + line for line in stage_text.splitlines())
    stage_boundary = '    }\n  ],\n  "docs_only_inheritance": {'
    inherited_text = _replace_once(
        inherited_text,
        stage_boundary,
        f'    }},\n{stage_text}\n  ],\n  "docs_only_inheritance": {{',
        "INHERITED_STAGE_BOUNDARY_MISMATCH",
    )
    inherited_text = _replace_json_value_once(
        inherited_text,
        "current_claim",
        old_current_claim,
        new_current_claim,
        "INHERITED_CURRENT_CLAIM_TEXT_MISMATCH",
    )
    inherited_text = _replace_json_value_once(
        inherited_text,
        "latest_completed_stage",
        "V076_REUSE_GATE_CURRENT_PRODUCT_SUBJECT_REGISTRATION_2CE2CE21",
        STAGE_ID,
        "INHERITED_LATEST_STAGE_TEXT_MISMATCH",
    )
    inherited_text = _replace_json_value_once(
        inherited_text,
        "latest_completed_stage_head_sha",
        OLD_HEAD,
        NEW_HEAD,
        "INHERITED_LATEST_HEAD_TEXT_MISMATCH",
    )
    inherited_text = _replace_json_value_once(
        inherited_text,
        "latest_completed_stage_tree_sha",
        OLD_TREE,
        NEW_TREE,
        "INHERITED_LATEST_TREE_TEXT_MISMATCH",
    )
    inherited_text = _replace_json_value_once(
        inherited_text,
        "next_stage",
        "V076_CURRENT_SUBJECT_PRODUCTION_REPAIR",
        "V076_CURRENT_SUBJECT_PRODUCTION_REVALIDATION",
        "INHERITED_NEXT_STAGE_TEXT_MISMATCH",
    )
    inherited_text = _replace_json_value_once(
        inherited_text,
        "why_focused_tests_are_sufficient",
        old_scope_reason,
        new_scope_reason,
        "INHERITED_SCOPE_REASON_TEXT_MISMATCH",
    )

    outputs = {
        registry_path: registry_text.encode("utf-8"),
        golden_path: golden_text.encode("utf-8"),
        inherited_path: inherited_text.encode("utf-8"),
    }
    predecessor_bytes = {
        registry_path: registry_base,
        golden_path: golden_base,
        inherited_path: inherited_base,
    }
    for path, data in outputs.items():
        json.loads(data.decode("utf-8"))
        current = path.read_bytes()
        if current not in (predecessor_bytes[path], data):
            raise SystemExit(f"CONCURRENT_OR_UNKNOWN_WORKTREE_MUTATION:{path}")
        path.write_bytes(data)

    print(f"CURRENT_PRODUCT_SUBJECT_HEAD={NEW_HEAD}")
    print(f"CURRENT_PRODUCT_SUBJECT_TREE={NEW_TREE}")
    print(f"CURRENT_PRODUCT_SUBJECT_MANIFEST_SHA256={manifest_sha256}")
    print("CURRENT_PRODUCT_SUBJECT_REGISTRY_ADVANCE=PASS")
    print("GODOT_PRODUCT_FILE_CHANGE_COUNT=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
