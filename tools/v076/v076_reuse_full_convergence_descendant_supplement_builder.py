#!/usr/bin/env python3
"""Build one explicit append-only V076 descendant-history successor v3.

The builder performs no directory discovery.  Every authority input and the
output path are explicit CLI arguments.  Frozen identities that disappeared
from the live Raw are preserved only through an exact successor fingerprint or
an exact dynamic-reference false-component retirement.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any

import v076_reuse_exact_failure_correction_v2_full_convergence as convergence


def _git_head(root: Path) -> str:
    return convergence._git(root, "rev-parse", "HEAD")


def _resolved_transition(root: Path, identity: dict[str, Any]) -> tuple[str, str]:
    old_commit = convergence._resolve_commit_prefix(
        root, str(identity.get("transition_old_prefix", ""))
    )
    new_commit = convergence._resolve_commit_prefix(
        root, str(identity.get("transition_new_prefix", ""))
    )
    if (
        not old_commit
        or not new_commit
        or convergence._git(root, "rev-parse", f"{new_commit}^1") != old_commit
    ):
        raise ValueError(f"TRANSITION_NOT_DIRECT_PARENT:{identity.get('raw_failure', '')}")
    return old_commit, new_commit


def _dynamic_reference_target_ids(
    root: Path,
    *,
    report_head: str,
) -> tuple[str, dict[str, list[str]]]:
    manifest_bytes = convergence._git_bytes(
        root,
        report_head,
        convergence.DYNAMIC_REFERENCE_MANIFEST_REL.as_posix(),
    )
    if manifest_bytes is None:
        raise ValueError("DYNAMIC_REFERENCE_MANIFEST_MISSING_AT_REPORT_HEAD")
    document = json.loads(
        manifest_bytes.decode("utf-8-sig"),
        object_pairs_hook=convergence._strict_object,
    )
    if not isinstance(document, dict) or not isinstance(document.get("entries"), list):
        raise ValueError("DYNAMIC_REFERENCE_MANIFEST_INVALID")
    target_to_ids: dict[str, list[str]] = {}
    for entry in document["entries"]:
        if not isinstance(entry, dict):
            continue
        reference_id = str(entry.get("dynamic_reference_id", ""))
        targets = entry.get("resolved_targets", [])
        if not reference_id or not isinstance(targets, list):
            continue
        for target in targets:
            normalized = convergence.normalize_path(str(target))
            if normalized:
                target_to_ids.setdefault(normalized, []).append(reference_id)
    return (
        convergence.sha256_bytes(manifest_bytes),
        {key: sorted(set(values)) for key, values in target_to_ids.items()},
    )


def build_supplement(
    root: Path,
    *,
    baseline_report_path: Path,
    raw_report_path: Path,
    scanner_path: Path,
    previous_supplement_path: Path,
) -> dict[str, Any]:
    baseline_report = convergence.load_json_strict(baseline_report_path)
    live_report = convergence.load_json_strict(raw_report_path)
    baseline_sets = convergence.authorized_failure_fingerprint_sets(baseline_report)
    live_sets = convergence.authorized_failure_fingerprint_sets(live_report)
    baseline_identities = convergence.authorized_failure_identity_by_fingerprint(
        baseline_report
    )
    live_identities = convergence.authorized_failure_identity_by_fingerprint(live_report)
    previous = convergence.load_json_strict(previous_supplement_path)
    if (
        baseline_report_path.resolve() != (root / convergence.BASELINE_REPORT_REL).resolve()
        or convergence.sha256_file(baseline_report_path)
        != convergence.AUTHORIZED_BASELINE_REPORT_SHA256
    ):
        raise ValueError("BASELINE_REPORT_SEAL_MISMATCH")
    if (
        previous_supplement_path.resolve()
        != (root / convergence.PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_REL).resolve()
        or convergence.sha256_file(previous_supplement_path)
        != convergence.PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA256
    ):
        raise ValueError("PREVIOUS_SUPPLEMENT_SEAL_MISMATCH")
    if live_sets["current"]:
        raise ValueError("LIVE_RAW_CURRENT_FAILURE_COUNT_NOT_ZERO")
    live_frozen = sorted(baseline_sets["historical"] & live_sets["historical"])
    missing_frozen = sorted(baseline_sets["historical"] - live_sets["historical"])
    descendants = sorted(live_sets["historical"] - baseline_sets["historical"])
    if not descendants:
        raise ValueError("DESCENDANT_HISTORY_SET_EMPTY")
    report_head = str(live_report.get("head_sha", ""))
    report_tree = convergence._git(root, "rev-parse", f"{report_head}^{{tree}}")
    raw_report_sha = convergence.sha256_file(raw_report_path)
    scanner_sha = convergence.sha256_file(scanner_path)
    if (
        raw_report_path.resolve() != (root / convergence.DESCENDANT_HISTORY_V3_RAW_REL).resolve()
        or raw_report_sha != convergence.DESCENDANT_HISTORY_V3_RAW_SHA256
        or report_head != convergence.DESCENDANT_HISTORY_V3_RAW_HEAD
        or report_tree != convergence.DESCENDANT_HISTORY_V3_RAW_TREE
        or scanner_sha != convergence.DESCENDANT_HISTORY_V3_SCANNER_SHA256
        or len(live_report.get("failures", []))
        != convergence.DESCENDANT_HISTORY_V3_RAW_FAILURE_COUNT
        or len(live_sets["historical"])
        != convergence.DESCENDANT_HISTORY_V3_RAW_HISTORICAL_COUNT
        or len(live_sets["current"])
        != convergence.DESCENDANT_HISTORY_V3_RAW_CURRENT_COUNT
    ):
        raise ValueError("SEALED_DA48_RAW_AUTHORITY_MISMATCH")
    scanner_at_report = convergence._git_bytes(
        root, report_head, convergence.DESCENDANT_HISTORY_SCANNER_REL.as_posix()
    )
    if scanner_at_report is None or convergence.sha256_bytes(scanner_at_report) != scanner_sha:
        raise ValueError("LIVE_SCANNER_NOT_EXACT_REPORT_HEAD_BYTES")
    baseline_scanner = convergence._git_bytes(
        root,
        convergence.AUTHORIZATION_BASE_HEAD_SHA,
        convergence.DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
    )
    if baseline_scanner is None:
        raise ValueError("BASELINE_SCANNER_MISSING")
    baseline_scanner_sha = convergence.sha256_bytes(baseline_scanner)
    repaired_current = sorted(baseline_sets["current"])
    previous_descendants = {
        str(value) for value in previous.get("descendant_history_fingerprints", [])
    }
    if not previous_descendants.issubset(set(descendants)):
        raise ValueError("PREVIOUS_DESCENDANT_IDENTITY_DROPPED")
    scanner_change_commits = [
        value
        for value in convergence._git(
            root,
            "rev-list",
            "--reverse",
            f"{convergence.PREVIOUS_DESCENDANT_HISTORY_RAW_HEAD}..{report_head}",
            "--",
            convergence.DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
        ).splitlines()
        if value
    ]
    if not scanner_change_commits:
        raise ValueError("SCANNER_EVOLUTION_EMPTY")

    identity_binding_by_failure: dict[str, dict[str, Any]] = {}
    for fingerprint in descendants:
        identity = live_identities[fingerprint]
        old_commit, new_commit = _resolved_transition(root, identity)
        source_path = convergence.normalize_path(str(identity.get("subject_value", "")))
        if identity.get("subject_kind") != "path" or not source_path:
            raise ValueError(f"DESCENDANT_SUBJECT_NOT_PATH:{fingerprint}")
        source_bytes = convergence._git_bytes(root, new_commit, source_path)
        if source_bytes is None:
            raise ValueError(f"DESCENDANT_SOURCE_MISSING:{fingerprint}")
        identity_binding_by_failure[fingerprint] = {
            "failure_fingerprint": fingerprint,
            "raw_failure": identity["raw_failure"],
            "repaired_frozen_current_fingerprints": repaired_current,
            "rule_id": identity["rule_id"],
            "source_blob_sha256": convergence.sha256_bytes(source_bytes),
            "source_commit_sha": new_commit,
            "source_component_id": "",
            "source_path": source_path,
            "transition_new_sha": new_commit,
            "transition_old_sha": old_commit,
        }

    manifest_sha, target_to_ids = _dynamic_reference_target_ids(
        root, report_head=report_head
    )
    disposition_by_failure: dict[str, dict[str, Any]] = {}
    used_successors: set[str] = set()
    for fingerprint in missing_frozen:
        identity = baseline_identities[fingerprint]
        old_commit, new_commit = _resolved_transition(root, identity)
        subject = convergence.normalize_path(str(identity.get("subject_value", "")))
        successor_candidates = [
            candidate
            for candidate in descendants
            if live_identities[candidate].get("rule_id") == identity.get("rule_id")
            and live_identities[candidate].get("subject_kind") == identity.get("subject_kind")
            and live_identities[candidate].get("subject_value") == identity.get("subject_value")
        ]
        common = {
            "baseline_scanner_tool_sha256": baseline_scanner_sha,
            "failure_fingerprint": fingerprint,
            "live_scanner_tool_sha256": scanner_sha,
            "raw_failure": identity["raw_failure"],
            "rule_id": identity["rule_id"],
            "subject_kind": identity["subject_kind"],
            "subject_value": identity["subject_value"],
            "transition_new_sha": new_commit,
            "transition_old_sha": old_commit,
            "wildcard_count": 0,
        }
        if len(successor_candidates) == 1:
            successor = successor_candidates[0]
            if successor in used_successors:
                raise ValueError(f"SUCCESSOR_REUSED:{successor}")
            used_successors.add(successor)
            successor_identity = live_identities[successor]
            successor_old, successor_new = _resolved_transition(root, successor_identity)
            disposition_by_failure[fingerprint] = {
                **common,
                "disposition": convergence.EXACT_SUCCESSOR_FINGERPRINT_MAPPING,
                "successor_failure_fingerprint": successor,
                "evidence": {
                    "baseline_raw_report_sha256": convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
                    "evidence_kind": "EXACT_LIVE_RAW_SUCCESSOR_IDENTITY",
                    "live_raw_report_sha256": raw_report_sha,
                    "successor_raw_failure": successor_identity["raw_failure"],
                    "successor_rule_id": successor_identity["rule_id"],
                    "successor_subject_kind": successor_identity["subject_kind"],
                    "successor_subject_value": successor_identity["subject_value"],
                    "successor_transition_new_sha": successor_new,
                    "successor_transition_old_sha": successor_old,
                },
            }
            continue
        if successor_candidates:
            raise ValueError(f"SUCCESSOR_NOT_UNIQUE:{fingerprint}")
        dynamic_ids = target_to_ids.get(subject, [])
        changed_paths = {
            convergence.normalize_path(value)
            for value in convergence._git(
                root, "diff", "--name-only", old_commit, new_commit
            ).splitlines()
            if value.strip()
        }
        if (
            identity.get("rule_id") != "HISTORY_UNCLASSIFIED_PRODUCT_COMPONENT"
            or identity.get("subject_kind") != "path"
            or subject in changed_paths
            or not dynamic_ids
        ):
            raise ValueError(f"NO_EXACT_FROZEN_DISPOSITION:{fingerprint}")
        disposition_by_failure[fingerprint] = {
            **common,
            "disposition": convergence.EXACT_SCANNER_FALSE_COMPONENT_RETIREMENT,
            "successor_failure_fingerprint": "",
            "evidence": {
                "baseline_raw_report_sha256": convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
                "dynamic_reference_ids": dynamic_ids,
                "dynamic_reference_manifest_blob_sha256": manifest_sha,
                "dynamic_reference_manifest_path": convergence.DYNAMIC_REFERENCE_MANIFEST_REL.as_posix(),
                "evidence_kind": "EXACT_DYNAMIC_REFERENCE_TARGET_NOT_DIRECT_TRANSITION_CHANGE",
                "live_raw_report_sha256": raw_report_sha,
                "resolved_target": f"res://{subject}",
                "subject_directly_changed": False,
            },
        }

    return {
        "authorization_base_head_sha": convergence.AUTHORIZATION_BASE_HEAD_SHA,
        "authorization_id": convergence.AUTHORIZATION_ID,
        "baseline_failure_set_sha256": convergence.AUTHORIZED_BASELINE_FAILURE_SET_SHA256,
        "baseline_historical_membership_policy": "LIVE_RAW_OR_EXACT_APPEND_ONLY_DISPOSITION",
        "baseline_report_sha256": convergence.AUTHORIZED_BASELINE_REPORT_SHA256,
        "baseline_scanner_tool_sha256": baseline_scanner_sha,
        "committed_only": True,
        "correction_membership_scope": "LIVE_HISTORICAL_ONLY",
        "descendant_history_failure_count": len(descendants),
        "descendant_history_fingerprint_set_sha256": convergence._line_set_sha(descendants),
        "descendant_history_fingerprints": descendants,
        "directory_discovery_allowed": False,
        "disposition_wildcard_count": 0,
        "frozen_identity_disposition_by_failure": disposition_by_failure,
        "future_failure_auto_membership_allowed": False,
        "identity_binding_by_failure": identity_binding_by_failure,
        "live_frozen_historical_failure_count": len(live_frozen),
        "live_frozen_historical_fingerprint_set_sha256": convergence._line_set_sha(live_frozen),
        "live_frozen_historical_fingerprints": live_frozen,
        "missing_frozen_historical_failure_count": len(missing_frozen),
        "missing_frozen_historical_fingerprint_set_sha256": convergence._line_set_sha(missing_frozen),
        "missing_frozen_historical_fingerprints": missing_frozen,
        "raw_current_delta_failure_count": 0,
        "raw_failure_count": len(live_report["failures"]),
        "raw_failure_detection_suppressed_count": 0,
        "raw_historical_failure_count": len(live_sets["historical"]),
        "raw_report_head_sha": report_head,
        "raw_report_path": raw_report_path.resolve().relative_to(root.resolve()).as_posix(),
        "raw_report_sha256": raw_report_sha,
        "raw_report_tree_sha": report_tree,
        "repaired_frozen_current_failure_count": len(repaired_current),
        "repaired_frozen_current_fingerprint_set_sha256": convergence._line_set_sha(
            repaired_current
        ),
        "repaired_frozen_current_fingerprints": repaired_current,
        "scanner_tool_path": convergence.DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
        "previous_supplement_path": convergence.PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_REL.as_posix(),
        "previous_supplement_sha256": convergence.PREVIOUS_DESCENDANT_HISTORY_SUPPLEMENT_SHA256,
        "scanner_evolution": {
            "evolution_kind": "FAIL_CLOSED_VALIDATION_STRENGTHENING",
            "from_raw_report_head_sha": convergence.PREVIOUS_DESCENDANT_HISTORY_RAW_HEAD,
            "from_raw_report_tree_sha": convergence.PREVIOUS_DESCENDANT_HISTORY_RAW_TREE,
            "from_scanner_tool_sha256": convergence.PREVIOUS_DESCENDANT_HISTORY_SCANNER_SHA256,
            "removed_rule_count": 0,
            "scanner_change_commit_count": len(scanner_change_commits),
            "scanner_change_commit_sequence_sha256": convergence.sha256_bytes(
                ("\n".join(scanner_change_commits) + "\n").encode("utf-8")
            ),
            "scanner_change_commit_shas": scanner_change_commits,
            "scanner_history_depth_reduction_count": 0,
            "scanner_scope_reduction_count": 0,
            "scanner_severity_downgrade_count": 0,
            "scanner_tool_path": convergence.DESCENDANT_HISTORY_SCANNER_REL.as_posix(),
            "to_raw_report_head_sha": report_head,
            "to_raw_report_tree_sha": report_tree,
            "to_scanner_tool_sha256": scanner_sha,
            "weakening_allowed": False,
        },
        "scanner_tool_sha256": scanner_sha,
        "schema_version": convergence.DESCENDANT_HISTORY_SUPPLEMENT_V3_SCHEMA_VERSION,
        "supplement_id": convergence.DESCENDANT_HISTORY_SUPPLEMENT_V3_ID,
        "wildcard_membership_allowed": False,
    }


def _publish_exclusive(payload: bytes, output: Path) -> None:
    """Publish bytes without overwriting either a temp or final path."""

    temporary = output.with_suffix(output.suffix + ".tmp")
    with temporary.open("xb") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())
    try:
        os.link(temporary, output)
    finally:
        temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--baseline-report", type=Path, required=True)
    parser.add_argument("--raw-report", type=Path, required=True)
    parser.add_argument("--scanner", type=Path, required=True)
    parser.add_argument("--previous-supplement", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.project.resolve()
    baseline_report = args.baseline_report.resolve()
    raw_report = args.raw_report.resolve()
    scanner = args.scanner.resolve()
    previous_supplement = args.previous_supplement.resolve()
    output = args.output.resolve()
    if output.exists():
        raise SystemExit(f"OUTPUT_ALREADY_EXISTS:{output}")
    if not output.parent.is_dir():
        raise SystemExit(f"OUTPUT_PARENT_MISSING:{output.parent}")
    document = build_supplement(
        root,
        baseline_report_path=baseline_report,
        raw_report_path=raw_report,
        scanner_path=scanner,
        previous_supplement_path=previous_supplement,
    )
    if output != (root / convergence.DESCENDANT_HISTORY_V3_SUPPLEMENT_REL).resolve():
        raise SystemExit(f"OUTPUT_PATH_MISMATCH:{output}")
    _publish_exclusive(convergence.canonical_bytes(document), output)
    try:
        final_validation = convergence.validate_descendant_history_supplement(
            root,
            output,
            raw_report,
            scanner,
            evaluated_head=_git_head(root),
            baseline_report_path=baseline_report,
        )
    except Exception:
        output.unlink(missing_ok=True)
        raise
    report = {
        "status": final_validation.get("status"),
        "failures": final_validation.get("failures", []),
        "output": output.resolve().relative_to(root).as_posix(),
        "output_sha256": convergence.sha256_file(output),
        "registered_historical_identity_count": len(
            final_validation.get("registered_historical_fingerprints", set())
        ),
        "live_historical_identity_count": len(
            final_validation.get("authorized_historical_fingerprints", set())
        ),
        "dispositioned_historical_identity_count": len(
            final_validation.get("dispositioned_historical_fingerprints", set())
        ),
    }
    if final_validation.get("status") != "PASS":
        output.unlink(missing_ok=True)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
