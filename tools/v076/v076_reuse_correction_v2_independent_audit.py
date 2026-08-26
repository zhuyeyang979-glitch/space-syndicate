#!/usr/bin/env python3
"""Independent read-only Audit A/B for the V076 correction V2 contract.

This module intentionally does not import or execute the correction resolver or
its self-test.  It reads the frozen report, inventory, immutable records and
the authorised Git tree, then emits two append-only audit projections.  The
script is safe to rerun after a record regeneration; it never writes source
files or records and only replaces the two explicitly requested audit outputs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


AUTHORIZED_HEAD = "1e24cea73fc23e69e575fcea09df57238156af67"
AUTHORIZED_BASELINE_SHA = "b1097750f23007ba75d83f646fefe70a3bb5012540d38475a536fc5eee81e435"
AUTHORIZED_SCANNER_SHA = "d76cef3b028bd602d14250011e72484704f09f906da008da43890c7ac344ca65"
AUTHORIZED_V1_SHA = "5a3cd6ce9e218792b008cd22d120e80c2baa586ae2a53e52ce4b784c2c95909d"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_REUSE_CORRECTION_V2_20260826"
RECORD_DIR = Path("docs/architecture/reuse_corrections/v2/records")
OUT_DIR = Path("reports/reuse/correction_v2")
SCANNER_PATHS = {
    "tools/v076/v076_reuse_point_inertia_gate.py",
    "tools/v076/v076_reuse_point_inertia_gate_selftest.py",
    "tools/rules/check_v06_mechanic_authority.py",
}
HISTORY_PREFIX = "HISTORY_"

FULL_CONVERGENCE_AUTHORIZATION_ID = (
    "USER_AUTHORIZATION_V076_REUSE_FULL_CONVERGENCE_AND_MCP_ONLY_20260827"
)
FULL_CONVERGENCE_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
FULL_CONVERGENCE_BASELINE_SHA = "cfb84c08abacb294ea54ffc975f691869b33ac47a5d6a9f28377c54534f19166"
FULL_CONVERGENCE_FAILURE_SET_SHA = "dd3b9f88319ba008dafa0de8be14d4e7427a3cb02d7b3e11ed6d50e2c80893ef"
FULL_CONVERGENCE_SCHEMA_SHA = "474c4864fd72ad1761fbbaae90f31791e9c6ee7d9dcb0e4de53ef47240cb1b12"
FULL_CONVERGENCE_SCHEMA = Path(
    "docs/architecture/reuse_corrections/v2/schema_full_convergence_20260827.json"
)
FULL_CONVERGENCE_BASELINE_REPORT = Path(
    "reports/reuse/correction_v2/epochs/full_convergence_20260827/"
    "baseline_raw_failure_report.json"
)
FULL_CONVERGENCE_RECORD_ROOT = (
    "docs/architecture/reuse_corrections/v2/records/full_convergence_20260827/"
)
DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION = (
    "space_syndicate.v076.reuse_exact_failure_correction.v2."
    "descendant_history_supplement.v1"
)
DESCENDANT_HISTORY_SUPPLEMENT_ID = "FULL_CONVERGENCE_DESCENDANT_HISTORY_20260827_001"
DESCENDANT_HISTORY_SCANNER = Path("tools/v076/v076_reuse_point_inertia_gate.py")
LEGACY_CHAIN_TERMINAL_SHA = "99f051cd23c250e0282db1708e49e2625d0e82279753a846a00a713614fed67d"
LEGACY_SEAL_PATH = Path(
    "reports/reuse/correction_v2/seals/ci_portability_v2/correction_authorization_manifest.json"
)
LEGACY_SEAL_SHA = "0731778c0b62f19bd15f7b6629ff82a67c11ec8ff9e6ca2923f4374eb170f948"
LEGACY_RECORD_SHA_BY_PATH = {
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_affected_domain_debt.json": "5d9ec47eed02e21cd19e36f9df2f402367e9498a717da07e2e2b1e1fe68aad6d",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_affected_owner_debt.json": "78160390f497b1d1b05078667c67dfafd928047e2118ef5f9cf98c518331fa33",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_change_class_debt.json": "144ad88f1b1f65ea973d8dbab4fb744a4eb71c4c8fde51bc7f50550aeae9c469",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_dynamic_reference_debt.json": "d66d75d42761fd1f6274ca9ea61b1af703d68816738f1d485ab50afacf4bb2db",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_focused_test_scope_debt.json": "654f021e14be59b690033d7667f9c3bd6324b85f8a3c3ba824785d18361ef042",
    "docs/architecture/reuse_corrections/v2/records/historical_untouched_reuse_scan_debt.json": "2e1c7ee76aff7dec57f1634be3a1913334ee282e2019ba09e97ae2b0396cac20",
}
BATCH_ARTIFACT_SPECS = {
    "batch_inventory_sha256": (
        "batch_inventory.json",
        "space_syndicate.v076.reuse_full_convergence.batch_inventory.v1",
        "inventory",
    ),
    "batch_classification_sha256": (
        "batch_classification.json",
        "space_syndicate.v076.reuse_full_convergence.batch_classification.v1",
        "classification",
    ),
    "batch_negative_checks_sha256": (
        "batch_negative_checks.json",
        "space_syndicate.v076.reuse_full_convergence.batch_negative_checks.v1",
        "negative_checks",
    ),
    "batch_review_a_sha256": (
        "batch_review_A.json",
        "space_syndicate.v076.reuse_full_convergence.batch_review.v1",
        "review_a",
    ),
    "batch_review_b_sha256": (
        "batch_review_B.json",
        "space_syndicate.v076.reuse_full_convergence.batch_review.v1",
        "review_b",
    ),
}

DESCENDANT_HISTORY_IDENTITY_FIELDS = {
    "failure_fingerprint",
    "raw_failure",
    "repaired_frozen_current_fingerprints",
    "rule_id",
    "source_blob_sha256",
    "source_commit_sha",
    "source_component_id",
    "source_path",
    "transition_new_sha",
    "transition_old_sha",
}

DESCENDANT_HISTORY_SUPPLEMENT_FIELDS = {
    "authorization_base_head_sha",
    "authorization_id",
    "baseline_failure_set_sha256",
    "baseline_report_sha256",
    "committed_only",
    "descendant_history_failure_count",
    "descendant_history_fingerprint_set_sha256",
    "descendant_history_fingerprints",
    "directory_discovery_allowed",
    "future_failure_auto_membership_allowed",
    "identity_binding_by_failure",
    "raw_current_delta_failure_count",
    "raw_failure_count",
    "raw_historical_failure_count",
    "raw_report_head_sha",
    "raw_report_path",
    "raw_report_sha256",
    "raw_report_tree_sha",
    "repaired_frozen_current_failure_count",
    "repaired_frozen_current_fingerprint_set_sha256",
    "repaired_frozen_current_fingerprints",
    "scanner_tool_path",
    "scanner_tool_sha256",
    "schema_version",
    "supplement_id",
    "wildcard_membership_allowed",
}


def _sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha_file(path: Path) -> str:
    return _sha_bytes(path.read_bytes())


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _json(path: Path) -> Any:
    return json.loads(
        path.read_text(encoding="utf-8-sig"),
        object_pairs_hook=_strict_object,
    )


def _git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def _git_bytes(root: Path, commit: str, relative: str) -> bytes | None:
    result = subprocess.run(
        ["git", "-C", str(root), "show", f"{commit}:{relative}"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return bytes(result.stdout) if result.returncode == 0 else None


def _is_sha256(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def _is_commit(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def _normalize_path(value: str) -> str:
    return value.removeprefix("res://").replace("\\", "/")


def _is_ancestor(root: Path, ancestor: str, descendant: str) -> bool:
    if not _is_commit(ancestor) or not _is_commit(descendant):
        return False
    result = subprocess.run(
        ["git", "-C", str(root), "merge-base", "--is-ancestor", ancestor, descendant],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def _resolve_commit_prefix(root: Path, prefix: str) -> str:
    if re.fullmatch(r"[0-9a-f]{12}", prefix) is None:
        return ""
    resolved = _git(root, "rev-parse", f"{prefix}^{{commit}}")
    return resolved if _is_commit(resolved) and resolved.startswith(prefix) else ""


def _walk_dicts(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_dicts(child)


def _subject_projection(root: Path, commit: str, selector: dict[str, Any]) -> dict[str, Any] | None:
    registry_bytes = _git_bytes(
        root, commit, "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
    )
    supersession_bytes = _git_bytes(
        root, commit, "docs/architecture/V076_SUPERSESSION_MAP.json"
    )
    owner_bytes = _git_bytes(
        root, commit, "docs/architecture/V076_OWNER_REUSE_MAP.md"
    )
    if registry_bytes is None or supersession_bytes is None or owner_bytes is None:
        return None
    try:
        registry = json.loads(
            registry_bytes.decode("utf-8-sig"), object_pairs_hook=_strict_object
        )
        supersession = json.loads(
            supersession_bytes.decode("utf-8-sig"), object_pairs_hook=_strict_object
        )
    except (UnicodeDecodeError, ValueError):
        return None
    component_ids = {str(value) for value in selector.get("component_ids", [])}
    paths = {str(value).removeprefix("res://").replace("\\", "/") for value in selector.get("paths", [])}
    record_ids = {
        str(value)
        for key in ("supersession_ids", "retirement_ids")
        for value in selector.get(key, [])
    }

    def matches(row: dict[str, Any]) -> bool:
        components = {
            str(row.get(key, ""))
            for key in (
                "component_id", "historical_component_id", "current_component_id",
                "owner_component_id", "old_component_id", "new_component_id",
            )
        }
        row_paths = {
            str(row.get(key, "")).removeprefix("res://").replace("\\", "/")
            for key in (
                "path", "historical_path", "current_path", "owner_path",
                "old_owner_path", "new_owner_path",
            )
        }
        ids = {
            str(row.get(key, ""))
            for key in ("supersession_id", "retirement_id", "record_id")
        }
        return bool(component_ids & components or paths & row_paths or record_ids & ids)

    registry_rows = sorted(
        [row for row in _walk_dicts(registry) if matches(row)],
        key=_canonical,
    )
    supersession_rows = sorted(
        [row for row in _walk_dicts(supersession) if matches(row)],
        key=_canonical,
    )
    needles = sorted(component_ids | paths | record_ids)
    owner_lines = sorted({
        line.rstrip()
        for line in owner_bytes.decode("utf-8-sig", errors="replace").splitlines()
        if any(needle in line for needle in needles)
    })
    return {
        "owner_map_lines": owner_lines,
        "registry_rows": registry_rows,
        "supersession_rows": supersession_rows,
    }


def _canonical(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _line_set_sha(values: list[str]) -> str:
    return _sha_bytes(("\n".join(sorted(values)) + "\n").encode("utf-8"))


def _authorized_failure_fingerprint_sets(report: dict[str, Any]) -> dict[str, set[str]]:
    result = {"historical": set(), "current": set()}
    if not isinstance(report, dict):
        return result
    values = report.get("failures")
    if not isinstance(values, list):
        return result
    for value in values:
        raw = str(value)
        rule_id = raw.split(":", 1)[0]
        historical = rule_id.startswith(HISTORY_PREFIX)
        bucket = "HISTORICAL" if historical else "CURRENT_DELTA_FAILURE"
        payload = f"V076_RAW_FAILURE_V2\n{bucket}\n{rule_id}\n{raw}\n".encode("utf-8")
        result["historical" if historical else "current"].add(
            "V2F-" + _sha_bytes(payload)
        )
    return result


def _authorized_failure_identity_by_fingerprint(
    report: dict[str, Any],
) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    values = report.get("failures") if isinstance(report, dict) else None
    if not isinstance(values, list):
        return result
    metadata_rules = {
        "HISTORY_COMPONENT_CHANGE_CLASS_NOT_DECLARED",
        "HISTORY_PRODUCT_AFFECTED_DOMAIN_MISSING",
        "HISTORY_PRODUCT_AFFECTED_OWNER_MISSING",
        "HISTORY_PRODUCT_FOCUSED_TESTS_MISSING",
        "HISTORY_PRODUCT_REUSE_SCAN_INVALID",
    }
    for value in values:
        raw = str(value)
        rule_id = raw.split(":", 1)[0]
        historical = rule_id.startswith(HISTORY_PREFIX)
        bucket = "HISTORICAL" if historical else "CURRENT_DELTA_FAILURE"
        payload = f"V076_RAW_FAILURE_V2\n{bucket}\n{rule_id}\n{raw}\n".encode("utf-8")
        fingerprint = "V2F-" + _sha_bytes(payload)
        parts = raw.split(":")
        transition_index = next(
            (
                index
                for index, token in enumerate(parts)
                if re.fullmatch(r"[0-9a-f]{12}->[0-9a-f]{12}", token)
            ),
            -1,
        )
        old_prefix = ""
        new_prefix = ""
        subject_kind = ""
        subject_value = ""
        if historical and transition_index >= 0:
            old_prefix, new_prefix = parts[transition_index].split("->", 1)
            if transition_index + 1 < len(parts):
                subject_kind = "component_id" if rule_id in metadata_rules else "path"
                subject_value = parts[transition_index + 1].removeprefix("res://").replace("\\", "/")
        result[fingerprint] = {
            "bucket": bucket,
            "failure_fingerprint": fingerprint,
            "raw_failure": raw,
            "rule_id": rule_id,
            "transition_old_prefix": old_prefix,
            "transition_new_prefix": new_prefix,
            "subject_kind": subject_kind,
            "subject_value": subject_value,
        }
    return result


def _exact_repo_relative(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return ""


def _descendant_history_supplement_findings(
    root: Path,
    *,
    supplement_path: Path | None,
    raw_report_path: Path | None,
    scanner_path: Path | None,
    evaluated_head: str,
    baseline_report: dict[str, Any],
    baseline_sets: dict[str, set[str]],
) -> tuple[
    list[dict[str, Any]],
    set[str],
    dict[str, dict[str, str]],
    str,
    str,
]:
    """Independently duplicate the one-shot descendant HISTORY seal checks."""

    findings: list[dict[str, Any]] = []

    def add(code: str, message: str, **evidence: Any) -> None:
        findings.append(_finding(code, "P0", message, **evidence))

    if supplement_path is None or raw_report_path is None or scanner_path is None:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_EXPLICIT_INPUT_REQUIRED",
            "supplement, raw report, and scanner paths must all be supplied explicitly",
        )
        return findings, set(), {}, "", ""
    supplement_relative = _exact_repo_relative(root, supplement_path)
    raw_report_relative = _exact_repo_relative(root, raw_report_path)
    scanner_relative = _exact_repo_relative(root, scanner_path)
    epoch_prefix = FULL_CONVERGENCE_BASELINE_REPORT.parent.as_posix() + "/"
    if not supplement_relative.startswith(epoch_prefix):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_SUPPLEMENT_PATH_INVALID",
            "supplement path is outside the explicit full-convergence epoch",
        )
    if not raw_report_relative.startswith(epoch_prefix):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_REPORT_PATH_INVALID",
            "raw report path is outside the explicit full-convergence epoch",
        )
    if scanner_relative != DESCENDANT_HISTORY_SCANNER.as_posix():
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_SCANNER_PATH_INVALID",
            "scanner path is not the one exact V076 gate implementation",
        )
    try:
        supplement = _json(supplement_path)
        supplement_sha = _sha_file(supplement_path)
    except (OSError, ValueError):
        supplement = None
        supplement_sha = ""
    if not isinstance(supplement, dict):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_SUPPLEMENT_INVALID",
            "supplement is not one strict JSON object",
        )
        return findings, set(), {}, supplement_sha, ""
    if set(supplement) != DESCENDANT_HISTORY_SUPPLEMENT_FIELDS:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_SUPPLEMENT_FIELD_SET_INVALID",
            "supplement field set differs from the closed contract",
        )
    for field, expected in (
        ("schema_version", DESCENDANT_HISTORY_SUPPLEMENT_SCHEMA_VERSION),
        ("supplement_id", DESCENDANT_HISTORY_SUPPLEMENT_ID),
        ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
        ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
        ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
        ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
        ("committed_only", True),
        ("directory_discovery_allowed", False),
        ("wildcard_membership_allowed", False),
        ("future_failure_auto_membership_allowed", False),
        ("raw_current_delta_failure_count", 0),
        ("raw_report_path", raw_report_relative),
        ("scanner_tool_path", DESCENDANT_HISTORY_SCANNER.as_posix()),
    ):
        if supplement.get(field) != expected:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_AUTHORITY_MISMATCH",
                "supplement authority or fail-closed policy differs from the contract",
                field=field,
                expected=expected,
                actual=supplement.get(field),
            )
    try:
        raw_report = _json(raw_report_path)
        raw_report_sha = _sha_file(raw_report_path)
    except (OSError, ValueError):
        raw_report = None
        raw_report_sha = ""
    if not isinstance(raw_report, dict):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_REPORT_INVALID",
            "the explicit final raw report is not one strict JSON object",
        )
        return findings, set(), {}, supplement_sha, ""
    if supplement.get("raw_report_sha256") != raw_report_sha:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_REPORT_HASH_MISMATCH",
            "final raw report bytes differ from the supplement digest",
        )
    raw_values = raw_report.get("failures")
    raw_rendered = [str(value) for value in raw_values] if isinstance(raw_values, list) else []
    if not isinstance(raw_values, list) or len(raw_rendered) != len(set(raw_rendered)):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_FAILURE_SET_INVALID",
            "final raw report failures are missing or duplicated",
        )
    final_sets = _authorized_failure_fingerprint_sets(raw_report)
    final_identities = _authorized_failure_identity_by_fingerprint(raw_report)
    if final_sets["current"]:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_FINAL_CURRENT_NOT_ZERO",
            "the sealed final raw report still contains current failures",
            current_failure_count=len(final_sets["current"]),
        )
    if not baseline_sets["historical"].issubset(final_sets["historical"]):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_FROZEN_HISTORY_HIDDEN",
            "the final raw report omits one or more frozen historical failures",
        )
    descendants = final_sets["historical"] - baseline_sets["historical"]
    declared = supplement.get("descendant_history_fingerprints")
    rendered_declared = [str(value) for value in declared] if isinstance(declared, list) else []
    if (
        not descendants
        or rendered_declared != sorted(rendered_declared)
        or len(rendered_declared) != len(set(rendered_declared))
        or set(rendered_declared) != descendants
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_MEMBERSHIP_MISMATCH",
            "declared membership is not the exact nonempty final-minus-d701 historical set",
        )
    if (
        supplement.get("descendant_history_failure_count") != len(descendants)
        or supplement.get("descendant_history_fingerprint_set_sha256")
        != _line_set_sha(rendered_declared)
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_MEMBERSHIP_DIGEST_MISMATCH",
            "descendant membership count or digest is not canonical",
        )
    if (
        supplement.get("raw_failure_count") != len(raw_rendered)
        or supplement.get("raw_historical_failure_count") != len(final_sets["historical"])
        or supplement.get("raw_current_delta_failure_count") != len(final_sets["current"])
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_COUNTS_MISMATCH",
            "supplement raw counts differ from the parsed final report",
        )
    report_head = str(raw_report.get("head_sha", ""))
    report_tree = _git(root, "rev-parse", f"{report_head}^{{tree}}")
    if (
        supplement.get("raw_report_head_sha") != report_head
        or not _is_commit(report_head)
        or supplement.get("raw_report_tree_sha") != report_tree
        or not _is_commit(report_tree)
        or raw_report.get("include_worktree") is not False
        or raw_report.get("evaluated_source") != "COMMITTED_HEAD"
        or raw_report.get("merge_base_sha") != FULL_CONVERGENCE_BASE_HEAD
        or not _is_ancestor(root, FULL_CONVERGENCE_BASE_HEAD, report_head)
        or not _is_ancestor(root, report_head, evaluated_head)
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_COMMITTED_HEAD_BINDING_INVALID",
            "raw report is not bound to one authorized committed Head and tree",
        )
    try:
        scanner_sha = _sha_file(scanner_path)
    except OSError:
        scanner_sha = ""
    scanner_at_head = _git_bytes(root, report_head, DESCENDANT_HISTORY_SCANNER.as_posix())
    scanner_at_head_sha = _sha_bytes(scanner_at_head) if scanner_at_head is not None else ""
    if (
        supplement.get("scanner_tool_sha256") != scanner_sha
        or scanner_sha != scanner_at_head_sha
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_SCANNER_HASH_MISMATCH",
            "scanner bytes differ from the exact tool committed at the report Head",
        )
    repaired = supplement.get("repaired_frozen_current_fingerprints")
    rendered_repaired = [str(value) for value in repaired] if isinstance(repaired, list) else []
    if (
        rendered_repaired != sorted(rendered_repaired)
        or len(rendered_repaired) != len(set(rendered_repaired))
        or set(rendered_repaired) != baseline_sets["current"]
        or supplement.get("repaired_frozen_current_failure_count") != len(baseline_sets["current"])
        or supplement.get("repaired_frozen_current_fingerprint_set_sha256")
        != _line_set_sha(rendered_repaired)
    ):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_REPAIRED_CURRENT_SET_INVALID",
            "repaired current set is not the exact frozen 56-fingerprint set",
        )
    bindings = supplement.get("identity_binding_by_failure")
    if not isinstance(bindings, dict) or set(bindings) != descendants:
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_IDENTITY_SET_INVALID",
            "supplement does not bind one exact identity for every descendant fingerprint",
        )
        bindings = bindings if isinstance(bindings, dict) else {}
    mapped_current: set[str] = set()
    authorized_identities: dict[str, dict[str, str]] = {}
    for fingerprint in sorted(descendants):
        binding = bindings.get(fingerprint)
        raw_identity = final_identities.get(fingerprint)
        if not isinstance(binding, dict) or set(binding) != DESCENDANT_HISTORY_IDENTITY_FIELDS:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_IDENTITY_FIELDS_INVALID",
                "one descendant identity field set differs from the closed contract",
                fingerprint=fingerprint,
            )
            continue
        if not isinstance(raw_identity, dict):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_IDENTITY_UNRESOLVED",
                "one descendant fingerprint has no exact final raw identity",
                fingerprint=fingerprint,
            )
            continue
        if (
            binding.get("failure_fingerprint") != fingerprint
            or binding.get("raw_failure") != raw_identity.get("raw_failure")
            or binding.get("rule_id") != raw_identity.get("rule_id")
        ):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_IDENTITY_MISMATCH",
                "identity raw text, rule, or fingerprint differs from the final report",
                fingerprint=fingerprint,
            )
        old_commit = _resolve_commit_prefix(root, str(raw_identity.get("transition_old_prefix", "")))
        new_commit = _resolve_commit_prefix(root, str(raw_identity.get("transition_new_prefix", "")))
        if (
            not old_commit
            or not new_commit
            or _git(root, "rev-parse", f"{new_commit}^1") != old_commit
            or binding.get("transition_old_sha") != old_commit
            or binding.get("transition_new_sha") != new_commit
            or binding.get("source_commit_sha") != new_commit
            or not _is_ancestor(root, FULL_CONVERGENCE_BASE_HEAD, new_commit)
            or not _is_ancestor(root, new_commit, report_head)
        ):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_TRANSITION_BINDING_INVALID",
                "descendant transition is not one exact direct authorized parent edge",
                fingerprint=fingerprint,
            )
        source_path = _normalize_path(str(binding.get("source_path", "")))
        source_path_exact = (
            source_path
            and source_path == binding.get("source_path")
            and not source_path.startswith(("/", "../"))
            and not source_path.endswith("/")
            and "/../" not in source_path
            and not any(char in source_path for char in "*?[]")
        )
        subject_kind = str(raw_identity.get("subject_kind", ""))
        subject_value = _normalize_path(str(raw_identity.get("subject_value", "")))
        if not source_path_exact:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_SOURCE_PATH_INVALID",
                "descendant source path is not exact and wildcard-free",
                fingerprint=fingerprint,
            )
        if subject_kind == "path":
            if source_path != subject_value or binding.get("source_component_id") != "":
                add(
                    "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_SUBJECT_MISMATCH",
                    "source path/component differs from the exact raw path subject",
                    fingerprint=fingerprint,
                )
        elif subject_kind == "component_id":
            changed_paths = {
                _normalize_path(value)
                for value in _git(root, "diff", "--name-only", old_commit, new_commit).splitlines()
                if value.strip()
            }
            if (
                binding.get("source_component_id") != subject_value
                or source_path not in changed_paths
            ):
                add(
                    "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_SUBJECT_MISMATCH",
                    "component subject or its exact touched source path is not bound",
                    fingerprint=fingerprint,
                )
        else:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_RAW_SUBJECT_UNRESOLVED",
                "descendant raw row has no exact path or component subject",
                fingerprint=fingerprint,
            )
        source_bytes = _git_bytes(root, new_commit, source_path) if new_commit else None
        source_sha = _sha_bytes(source_bytes) if source_bytes is not None else ""
        if source_bytes is None or binding.get("source_blob_sha256") != source_sha:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_SOURCE_BLOB_MISMATCH",
                "descendant source blob differs from the exact new commit",
                fingerprint=fingerprint,
            )
        mapped = binding.get("repaired_frozen_current_fingerprints")
        rendered_mapped = [str(value) for value in mapped] if isinstance(mapped, list) else []
        if (
            not rendered_mapped
            or rendered_mapped != sorted(rendered_mapped)
            or len(rendered_mapped) != len(set(rendered_mapped))
            or not set(rendered_mapped).issubset(baseline_sets["current"])
        ):
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_REPAIR_BINDING_INVALID",
                "descendant identity lacks a nonempty exact frozen-current repair binding",
                fingerprint=fingerprint,
            )
        mapped_current.update(rendered_mapped)
        identity = dict(raw_identity)
        identity.update({
            "authority_origin": "DESCENDANT_HISTORY_SUPPLEMENT",
            "source_path": source_path,
            "supplement_raw_report_head_sha": report_head,
        })
        authorized_identities[fingerprint] = identity
    if mapped_current != baseline_sets["current"] or mapped_current != set(rendered_repaired):
        add(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_REPAIR_COVERAGE_INVALID",
            "per-descendant repair bindings do not cover the exact frozen current set",
        )
    return findings, descendants, authorized_identities, supplement_sha, report_head


def _selector_is_exact(selector: Any) -> bool:
    expected_fields = {
        "component_ids", "paths", "retirement_ids", "supersession_ids",
    }
    if not isinstance(selector, dict) or set(selector) != expected_fields:
        return False
    total = 0
    disallowed = {
        "glob", "regex", "prefix", "directory", "legacy", "misc", "other",
        "unknown", "ignore", "waive", "grandfather",
    }
    for field in sorted(expected_fields):
        values = selector.get(field)
        if not isinstance(values, list):
            return False
        rendered = [str(value) for value in values]
        total += len(rendered)
        if rendered != sorted(rendered) or len(rendered) != len(set(rendered)):
            return False
        for value in rendered:
            tokens = set(re.findall(r"[a-z0-9_]+", value.casefold()))
            if not value or any(char in value for char in "*?[]") or tokens & disallowed:
                return False
            if field == "paths":
                normalized = value.removeprefix("res://").replace("\\", "/")
                if (
                    normalized != value
                    or value.startswith(("/", "../"))
                    or value.endswith("/")
                    or "/../" in value
                ):
                    return False
    return total > 0


def _raw_identity_findings(
    root: Path,
    *,
    fingerprint: str,
    subject: dict[str, Any],
    identity: dict[str, str] | None,
    record_rule_ids: list[str],
    path: str,
) -> list[dict[str, Any]]:
    """Bind a correction subject back to its one exact frozen raw row."""

    findings: list[dict[str, Any]] = []

    def add(code: str, message: str, **evidence: Any) -> None:
        findings.append(_finding(
            code,
            "P0",
            message,
            path=path,
            fingerprint=fingerprint,
            **evidence,
        ))

    if not isinstance(identity, dict) or identity.get("bucket") != "HISTORICAL":
        add(
            "FULL_CONVERGENCE_BASELINE_RAW_IDENTITY_UNRESOLVED",
            "the record fingerprint does not resolve to one frozen historical raw row",
        )
        return findings
    rule_id = str(identity.get("rule_id", ""))
    if record_rule_ids != [rule_id]:
        add(
            "FULL_CONVERGENCE_BASELINE_RAW_RULE_MISMATCH",
            "the record rule differs from the exact frozen raw rule",
            expected_rule_id=rule_id,
        )
    old_commit = _resolve_commit_prefix(
        root, str(identity.get("transition_old_prefix", ""))
    )
    source_commit = _resolve_commit_prefix(
        root, str(identity.get("transition_new_prefix", ""))
    )
    if not old_commit or not source_commit:
        add(
            "FULL_CONVERGENCE_BASELINE_RAW_TRANSITION_UNRESOLVED",
            "the frozen raw transition cannot be resolved to exact commits",
        )
    else:
        if _git(root, "rev-parse", f"{source_commit}^1") != old_commit:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_TRANSITION_NOT_DIRECT_PARENT",
                "the frozen raw transition is not a direct parent transition",
                old_commit=old_commit,
                source_commit=source_commit,
            )
        if subject.get("source_commit") != source_commit:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_SOURCE_COMMIT_MISMATCH",
                "the identity binding source commit differs from the raw transition",
                expected_source_commit=source_commit,
            )
        if subject.get("first_seen_commit") != source_commit:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_FIRST_SEEN_MISMATCH",
                "the identity binding first-seen commit differs from the raw transition",
                expected_first_seen_commit=source_commit,
            )
        last_seen = str(subject.get("last_seen_commit", ""))
        if identity.get("authority_origin") == "DESCENDANT_HISTORY_SUPPLEMENT":
            supplement_head = str(identity.get("supplement_raw_report_head_sha", ""))
            last_seen_invalid = (
                not _is_commit(last_seen)
                or not _is_ancestor(root, source_commit, last_seen)
                or not _is_ancestor(root, last_seen, supplement_head)
            )
        else:
            last_seen_invalid = (
                not _is_commit(last_seen)
                or not _is_ancestor(root, source_commit, last_seen)
                or not _is_ancestor(root, last_seen, FULL_CONVERGENCE_BASE_HEAD)
            )
        if last_seen_invalid:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_LAST_SEEN_INVALID",
                "last_seen_commit is outside its exact authorized history interval",
            )
    selector = subject.get("authority_selectors")
    selector_paths = {
        _normalize_path(str(value))
        for value in selector.get("paths", [])
    } if isinstance(selector, dict) else set()
    selector_components = {
        str(value) for value in selector.get("component_ids", [])
    } if isinstance(selector, dict) else set()
    subject_kind = str(identity.get("subject_kind", ""))
    subject_value = _normalize_path(str(identity.get("subject_value", "")))
    if subject_kind == "path":
        if _normalize_path(str(subject.get("historical_path", ""))) != subject_value:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_HISTORICAL_PATH_MISMATCH",
                "historical_path differs from the frozen raw path",
                expected_historical_path=subject_value,
            )
        if subject_value not in selector_paths:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_PATH_SELECTOR_MISSING",
                "the exact frozen raw path is absent from the authority selector",
                expected_path=subject_value,
            )
    elif subject_kind == "component_id":
        bound_components = {
            str(subject.get("historical_component_id", "")),
            str(subject.get("current_component_id", "")),
        }
        if subject_value not in bound_components:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_COMPONENT_MISMATCH",
                "the frozen raw component id is absent from the identity binding",
                expected_component_id=subject_value,
            )
        if subject_value not in selector_components:
            add(
                "FULL_CONVERGENCE_BASELINE_RAW_COMPONENT_SELECTOR_MISSING",
                "the exact frozen raw component id is absent from the authority selector",
                expected_component_id=subject_value,
            )
    else:
        add(
            "FULL_CONVERGENCE_BASELINE_RAW_SUBJECT_UNRESOLVED",
            "the frozen raw row does not expose an exact path or component subject",
        )
    if identity.get("authority_origin") == "DESCENDANT_HISTORY_SUPPLEMENT":
        supplement_source_path = _normalize_path(str(identity.get("source_path", "")))
        if _normalize_path(str(subject.get("historical_path", ""))) != supplement_source_path:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_RECORD_SOURCE_PATH_MISMATCH",
                "record historical path differs from the sealed descendant source path",
            )
        if supplement_source_path not in selector_paths:
            add(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_RECORD_SOURCE_SELECTOR_MISSING",
                "sealed descendant source path is absent from the record selector",
            )
    binding_paths = {
        _normalize_path(str(subject.get(field, "")))
        for field in ("historical_path", "current_path")
        if subject.get(field)
    }
    binding_components = {
        str(subject.get(field, ""))
        for field in ("historical_component_id", "current_component_id")
        if subject.get(field)
    }
    if not binding_paths.issubset(selector_paths):
        add(
            "FULL_CONVERGENCE_IDENTITY_PATH_SELECTOR_COVERAGE_MISMATCH",
            "not every bound path is covered by the exact authority selector",
        )
    if not binding_components.issubset(selector_components):
        add(
            "FULL_CONVERGENCE_IDENTITY_COMPONENT_SELECTOR_COVERAGE_MISMATCH",
            "not every bound component is covered by the exact authority selector",
        )
    current_path = _normalize_path(str(subject.get("current_path", "")))
    if not current_path:
        if subject.get("current_blob_sha256") != "MISSING":
            add(
                "FULL_CONVERGENCE_IDENTITY_MISSING_CURRENT_PATH_BLOB_NOT_MISSING",
                "an empty current path must bind the exact MISSING blob state",
            )
        if subject.get("recommended_disposition") == "HISTORICAL_ACTIVE_LINEAGE_REGISTERED":
            add(
                "FULL_CONVERGENCE_IDENTITY_ACTIVE_LINEAGE_CURRENT_PATH_MISSING",
                "an active lineage disposition requires an exact current path",
            )
    return findings


def _record_payload(record: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in record.items() if k != "record_payload_sha256"}


def _sidecar(path: Path) -> tuple[str, str | None]:
    sidecar = path.with_suffix(".sha256")
    if not path.is_file() or not sidecar.is_file():
        return "", "missing artifact or sidecar"
    parts = sidecar.read_text(encoding="ascii").splitlines()[0].split(maxsplit=1)
    if len(parts) != 2 or not re.fullmatch(r"[0-9a-f]{64}", parts[0]):
        return "", "invalid sidecar"
    actual = _sha_file(path)
    if actual != parts[0]:
        return actual, "sidecar digest mismatch"
    return actual, None


def _read_registry(root: Path) -> tuple[dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    path = root / "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
    try:
        payload = _json(path)
    except (OSError, ValueError):
        return {}, {}
    by_path: dict[str, dict[str, Any]] = {}
    by_id: dict[str, dict[str, Any]] = {}
    for row in payload.get("component_inventory", []):
        if not isinstance(row, dict):
            continue
        component_id = str(row.get("component_id", ""))
        path_value = str(row.get("path", "")).removeprefix("res://").replace("\\", "/")
        if component_id:
            by_id[component_id] = row
        if path_value:
            by_path[path_value] = row
    return by_path, by_id


def _tree_blob_map(root: Path) -> dict[str, str]:
    """Return path -> Git blob id from the authorised committed tree."""
    output = _git(root, "ls-tree", "-r", AUTHORIZED_HEAD)
    result: dict[str, str] = {}
    for line in output.splitlines():
        fields = line.split("\t", 1)
        if len(fields) != 2:
            continue
        identity, path = fields
        id_fields = identity.split()
        if len(id_fields) >= 3:
            result[path.replace("\\", "/")] = id_fields[2]
    return result


def _git_blob_sha256(root: Path, blob_id: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "cat-file", "blob", blob_id],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return _sha_bytes(result.stdout) if result.returncode == 0 else "MISSING"


def _record_paths(root: Path) -> list[Path]:
    directory = root / RECORD_DIR
    return sorted(path for path in directory.glob("*.json") if path.is_file())


def _finding(code: str, severity: str, message: str, **evidence: Any) -> dict[str, Any]:
    return {"code": code, "severity": severity, "message": message, "evidence": evidence}


def _batch_artifact_findings(
    manifest_path: Path,
    manifest: dict[str, Any],
    identities: dict[str, dict[str, str]],
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    expected_fingerprints = [str(value) for value in manifest.get("failure_fingerprints", [])]
    for hash_field, (filename, schema_version, kind) in BATCH_ARTIFACT_SPECS.items():
        path = manifest_path.parent / filename
        if not path.is_file():
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_ARTIFACT_MISSING",
                "P0",
                "a required batch evidence artifact is missing",
                artifact=filename,
            ))
            continue
        if _sha_file(path) != manifest.get(hash_field):
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_ARTIFACT_HASH_MISMATCH",
                "P0",
                "batch evidence bytes differ from the manifest digest",
                artifact=filename,
            ))
            continue
        try:
            document = _json(path)
        except (OSError, ValueError):
            document = None
        if not isinstance(document, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_ARTIFACT_INVALID",
                "P0",
                "a required batch evidence artifact is not a strict JSON object",
                artifact=filename,
            ))
            continue
        common_valid = (
            document.get("schema_version") == schema_version
            and document.get("batch_id") == manifest.get("batch_id")
            and [str(value) for value in document.get("failure_fingerprints", [])]
            == expected_fingerprints
            and document.get("failure_count") == len(expected_fingerprints)
        )
        if not common_valid:
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_ARTIFACT_SCHEMA_MISMATCH",
                "P0",
                "batch evidence schema, batch id, or fingerprint coverage is not exact",
                artifact=filename,
            ))
            continue
        if kind == "inventory":
            rows = document.get("rows")
            if (
                document.get("identity_coverage_percent") != 100
                or document.get("unknown_count") != 0
                or not isinstance(rows, dict)
                or set(rows) != set(expected_fingerprints)
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_BATCH_INVENTORY_COVERAGE_INVALID",
                    "P0",
                    "inventory does not bind every fingerprint with zero unknowns",
                    artifact=filename,
                ))
            elif any(
                not isinstance(row, dict)
                or row.get("failure_fingerprint") != fingerprint
                or row.get("raw_failure") != identities.get(fingerprint, {}).get("raw_failure")
                or row.get("rule_id") != identities.get(fingerprint, {}).get("rule_id")
                for fingerprint, row in rows.items()
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_BATCH_INVENTORY_RAW_IDENTITY_MISMATCH",
                    "P0",
                    "inventory rows do not match their frozen raw identities",
                    artifact=filename,
                ))
        elif kind == "classification":
            rows = document.get("classifications")
            if (
                document.get("unknown_count") != 0
                or document.get("wildcard_count") != 0
                or not isinstance(rows, dict)
                or set(rows) != set(expected_fingerprints)
                or any(
                    not isinstance(row, dict)
                    or row.get("failure_fingerprint") != fingerprint
                    or row.get("status") != "CLASSIFIED"
                    or not str(row.get("recommended_disposition", "")).startswith("HISTORICAL_")
                    for fingerprint, row in (rows.items() if isinstance(rows, dict) else [])
                )
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_BATCH_CLASSIFICATION_INVALID",
                    "P0",
                    "classification does not cover every fingerprint with exact closed status",
                    artifact=filename,
                ))
        elif kind == "negative_checks":
            checks = document.get("checks")
            if (
                document.get("status") != "PASS"
                or document.get("current_failure_false_accept_count") != 0
                or document.get("future_failure_auto_correction_count") != 0
                or document.get("wildcard_count") != 0
                or not isinstance(checks, dict)
                or not checks
                or any(value is not True for value in checks.values())
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_BATCH_NEGATIVE_CHECKS_INVALID",
                    "P0",
                    "negative checks are not an actual all-pass zero-waiver document",
                    artifact=filename,
                ))
        else:
            review_id = "A" if kind == "review_a" else "B"
            if (
                document.get("review_id") != review_id
                or document.get("status") != "GO"
                or document.get("p0_count") != 0
                or document.get("p1_count") != 0
                or document.get("findings") != []
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_BATCH_REVIEW_INVALID",
                    "P0",
                    "review GO is not supported by a zero-P0/P1 review document",
                    artifact=filename,
                ))
    return findings


def _manifest_record_findings(
    root: Path,
    manifest: dict[str, Any],
    *,
    evaluated_head: str,
    baseline_identities: dict[str, dict[str, str]],
) -> tuple[list[dict[str, Any]], set[str], set[str], int]:
    """Revalidate the exact records named by one manifest.

    This is intentionally used for every predecessor as well as the current
    manifest.  Merely re-reading predecessor manifest bindings is not enough:
    their record bytes, payloads, chain, fingerprints, frozen raw identities,
    blobs, and projections must still be valid at the evaluated Head.
    """

    findings: list[dict[str, Any]] = []
    seen: set[str] = set()
    correction_ids: set[str] = set()
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or not bindings:
        findings.append(_finding(
            "FULL_CONVERGENCE_RECORD_BINDINGS_MISSING",
            "P0",
            "the batch does not enumerate an explicit record set",
            batch_id=manifest.get("batch_id"),
        ))
        return findings, seen, correction_ids, 0
    expected_previous = str(manifest.get("record_chain_start_sha256", ""))
    for index, binding in enumerate(bindings):
        if not isinstance(binding, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_INVALID",
                "P0",
                "record binding is not an object",
                batch_id=manifest.get("batch_id"),
                index=index,
            ))
            continue
        relative = _normalize_path(str(binding.get("path", "")))
        expected_prefix = (
            FULL_CONVERGENCE_RECORD_ROOT
            + str(manifest.get("batch_id", ""))
            + "/"
        )
        if (
            not relative.startswith(expected_prefix)
            or any(char in relative for char in "*?[]")
            or relative.endswith("/")
            or relative.startswith("/")
            or "/../" in relative
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PATH_NOT_EXACT",
                "P0",
                "record path is outside its exact batch root or contains selector syntax",
                path=relative,
                index=index,
            ))
            continue
        if binding.get("previous_correction_chain_sha256") != expected_previous:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CHAIN_BREAK",
                "P0",
                "manifest record predecessor does not match the prior payload",
                path=relative,
            ))
        path = root / relative
        if not path.is_file() or _sha_file(path) != binding.get("record_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BYTE_DRIFT",
                "P0",
                "record bytes do not match the explicit binding",
                path=relative,
            ))
            continue
        try:
            record = _json(path)
        except (OSError, ValueError):
            record = None
        if not isinstance(record, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_UNREADABLE",
                "P0",
                "record is not one strict JSON object",
                path=relative,
            ))
            continue
        for field, expected in (
            ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
            ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
            ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
            ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
            ("batch_id", manifest.get("batch_id")),
            ("binding_head_sha", manifest.get("binding_head_sha")),
            ("binding_tree_sha", manifest.get("binding_tree_sha")),
        ):
            if record.get(field) != expected:
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_AUTHORITY_MISMATCH",
                    "P0",
                    "record authority or batch binding differs from its manifest",
                    path=relative,
                    field=field,
                    expected=expected,
                    actual=record.get(field),
                ))
        for hash_field in BATCH_ARTIFACT_SPECS:
            if record.get(hash_field) != manifest.get(hash_field):
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_ARTIFACT_BINDING_MISMATCH",
                    "P0",
                    "record evidence digest differs from its manifest",
                    path=relative,
                    field=hash_field,
                ))
        if (
            record.get("descendant_history_supplement_sha256")
            != manifest.get("descendant_history_supplement_sha256")
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_DESCENDANT_SUPPLEMENT_BINDING_MISMATCH",
                "P0",
                "record descendant-history seal differs from its manifest",
                path=relative,
            ))
        expected_payload_sha = _sha_bytes(_canonical(_record_payload(record)))
        if record.get("record_payload_sha256") != expected_payload_sha:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PAYLOAD_HASH_MISMATCH",
                "P0",
                "record payload digest does not bind its canonical content",
                path=relative,
            ))
        if record.get("record_payload_sha256") != binding.get("record_payload_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PAYLOAD_BINDING_MISMATCH",
                "P0",
                "record payload digest differs from the manifest binding",
                path=relative,
            ))
        if record.get("previous_correction_chain_sha256") != expected_previous:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PREDECESSOR_BINDING_MISMATCH",
                "P0",
                "actual record predecessor does not continue the manifest chain",
                path=relative,
            ))
        if record.get("correction_id") != binding.get("correction_id"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_ID_BINDING_MISMATCH",
                "P0",
                "record correction id differs from the manifest binding",
                path=relative,
            ))
        correction_id = str(record.get("correction_id", ""))
        if correction_id in correction_ids:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CORRECTION_ID_REUSE",
                "P0",
                "one manifest repeats a correction id",
                path=relative,
                correction_id=correction_id,
            ))
        correction_ids.add(correction_id)
        if record.get("future_failure_policy") != {
            "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
            "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
        }:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FUTURE_AUTO_CORRECTION_ENABLED",
                "P0",
                "record future-failure policy is not exact and fail-closed",
                path=relative,
            ))
        rules = record.get("rule_ids")
        rendered_rules = [str(value) for value in rules] if isinstance(rules, list) else []
        if len(rendered_rules) != 1 or not rendered_rules[0].startswith(HISTORY_PREFIX):
            findings.append(_finding(
                "FULL_CONVERGENCE_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a new record is not restricted to one historical rule",
                path=relative,
            ))
        binding_fingerprints = [
            str(value) for value in binding.get("failure_fingerprints", [])
        ] if isinstance(binding.get("failure_fingerprints"), list) else []
        record_fingerprints = [
            str(value) for value in record.get("failure_fingerprints", [])
        ] if isinstance(record.get("failure_fingerprints"), list) else []
        if record_fingerprints != binding_fingerprints:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FINGERPRINT_BINDING_MISMATCH",
                "P0",
                "actual record fingerprints differ from the manifest binding",
                path=relative,
            ))
        subjects = record.get("identity_binding_by_failure")
        if not isinstance(subjects, dict) or set(subjects) != set(record_fingerprints):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_IDENTITY_BINDING_SET_MISMATCH",
                "P0",
                "record must bind one exact identity projection per fingerprint",
                path=relative,
            ))
            subjects = subjects if isinstance(subjects, dict) else {}
        binding_head = str(record.get("binding_head_sha", ""))
        for fingerprint in record_fingerprints:
            if fingerprint in seen:
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_FINGERPRINT_DUPLICATE",
                    "P0",
                    "one manifest repeats a record fingerprint",
                    path=relative,
                    fingerprint=fingerprint,
                ))
            seen.add(fingerprint)
            subject = subjects.get(fingerprint)
            if not isinstance(subject, dict):
                continue
            findings.extend(_raw_identity_findings(
                root,
                fingerprint=fingerprint,
                subject=subject,
                identity=baseline_identities.get(fingerprint),
                record_rule_ids=rendered_rules,
                path=relative,
            ))
            selector = subject.get("authority_selectors")
            projection = subject.get("subject_projection")
            if (
                not isinstance(projection, dict)
                or subject.get("subject_projection_sha256") != _sha_bytes(_canonical(projection))
            ):
                findings.append(_finding(
                    "FULL_CONVERGENCE_SUBJECT_PROJECTION_HASH_MISMATCH",
                    "P0",
                    "subject projection is not bound by its canonical digest",
                    path=relative,
                    fingerprint=fingerprint,
                ))
                continue
            if not _selector_is_exact(selector):
                findings.append(_finding(
                    "FULL_CONVERGENCE_SUBJECT_SELECTOR_NOT_EXACT",
                    "P0",
                    "subject projection lacks an exact wildcard-free selector",
                    path=relative,
                    fingerprint=fingerprint,
                ))
                continue
            source_commit = str(subject.get("source_commit", ""))
            historical_path = _normalize_path(str(subject.get("historical_path", "")))
            current_path = _normalize_path(str(subject.get("current_path", "")))
            if historical_path and _is_commit(source_commit):
                historical_bytes = _git_bytes(root, source_commit, historical_path)
                historical_sha = _sha_bytes(historical_bytes) if historical_bytes is not None else "MISSING"
                if historical_sha != subject.get("historical_blob_sha256"):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_HISTORICAL_BLOB_BINDING_MISMATCH",
                        "P0",
                        "historical blob differs from the exact source commit",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
            if current_path:
                binding_bytes = _git_bytes(root, binding_head, current_path)
                evaluated_bytes = _git_bytes(root, evaluated_head, current_path)
                binding_sha = _sha_bytes(binding_bytes) if binding_bytes is not None else "MISSING"
                evaluated_sha = _sha_bytes(evaluated_bytes) if evaluated_bytes is not None else "MISSING"
                if binding_sha != subject.get("current_blob_sha256"):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_CURRENT_BLOB_BINDING_MISMATCH",
                        "P0",
                        "current blob differs from the record binding Head",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                if evaluated_sha != subject.get("current_blob_sha256"):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_CURRENT_BLOB_CHANGED",
                        "P0",
                        "current blob changed after correction binding",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
            binding_projection = _subject_projection(root, binding_head, selector)
            current_projection = _subject_projection(root, evaluated_head, selector)
            if binding_projection != projection:
                findings.append(_finding(
                    "FULL_CONVERGENCE_SUBJECT_BINDING_MISMATCH",
                    "P0",
                    "subject projection differs from its binding Head",
                    path=relative,
                    fingerprint=fingerprint,
                ))
            if current_projection != projection:
                findings.append(_finding(
                    "FULL_CONVERGENCE_SUBJECT_PROJECTION_CHANGED",
                    "P0",
                    "subject projection changed at the evaluated Head",
                    path=relative,
                    fingerprint=fingerprint,
                ))
        expected_previous = str(record.get("record_payload_sha256", ""))
    if expected_previous != manifest.get("record_chain_terminal_sha256"):
        findings.append(_finding(
            "FULL_CONVERGENCE_CHAIN_TERMINAL_MISMATCH",
            "P0",
            "batch terminal does not equal the final actual record payload",
            batch_id=manifest.get("batch_id"),
        ))
    manifest_fingerprints = {
        str(value) for value in manifest.get("failure_fingerprints", [])
    }
    if seen != manifest_fingerprints:
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_COVERAGE_MISMATCH",
            "P0",
            "actual records do not cover each manifest fingerprint exactly once",
            batch_id=manifest.get("batch_id"),
        ))
    return findings, seen, correction_ids, len(bindings)


def _derive_prior_manifest_path(
    current_path: Path,
    current_batch_id: str,
    prior_batch_id: str,
) -> Path | None:
    if current_path.parent.name == current_batch_id:
        return current_path.parent.parent / prior_batch_id / current_path.name
    if current_batch_id in current_path.name:
        return current_path.with_name(current_path.name.replace(current_batch_id, prior_batch_id, 1))
    return None


def _manifest_contract_findings(
    root: Path,
    manifest_path: Path,
    manifest: dict[str, Any],
    *,
    evaluated_head: str,
    baseline_identities: dict[str, dict[str, str]],
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    fingerprints = [
        str(value) for value in manifest.get("failure_fingerprints", [])
    ] if isinstance(manifest.get("failure_fingerprints"), list) else []
    if (
        fingerprints != sorted(fingerprints)
        or len(fingerprints) != len(set(fingerprints))
        or any(re.fullmatch(r"V2F-[0-9a-f]{64}", value) is None for value in fingerprints)
    ):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_SET_INVALID",
            "P0",
            "manifest fingerprints must be unique sorted exact V2 identities",
            manifest_path=str(manifest_path),
        ))
    if manifest.get("failure_count") != len(fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_COUNT_MISMATCH",
            "P0",
            "manifest failure_count differs from its explicit fingerprint list",
            manifest_path=str(manifest_path),
        ))
    if manifest.get("failure_fingerprint_set_sha256") != _line_set_sha(fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_HASH_MISMATCH",
            "P0",
            "manifest fingerprint set digest is not canonical",
            manifest_path=str(manifest_path),
        ))
    if not 1 <= len(fingerprints) <= 50:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BATCH_SIZE_INVALID",
            "P0",
            "a batch must contain between one and fifty exact fingerprints",
            manifest_path=str(manifest_path),
        ))
    if len(fingerprints) < 25 and manifest.get("terminal_remainder_batch") is not True:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_NONTERMINAL_BELOW_TARGET",
            "P0",
            "a nonterminal batch cannot contain fewer than twenty-five fingerprints",
            manifest_path=str(manifest_path),
        ))
    for field, expected in (
        ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
        ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
        ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
        ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
        ("batch_review_a_status", "GO"),
        ("batch_review_b_status", "GO"),
        ("identity_coverage_percent", 100),
        ("batch_unknown_count", 0),
        ("batch_wildcard_count", 0),
        ("current_failure_false_accept_count", 0),
    ):
        if manifest.get(field) != expected:
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_AUTHORITY_MISMATCH",
                "P0",
                "batch authority or review assertion differs from the closed contract",
                manifest_path=str(manifest_path),
                field=field,
                expected=expected,
                actual=manifest.get(field),
            ))
    binding_head = str(manifest.get("binding_head_sha", ""))
    binding_tree = _git(root, "rev-parse", f"{binding_head}^{{tree}}")
    if not _is_commit(binding_head) or not binding_tree:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BINDING_HEAD_UNRESOLVED",
            "P0",
            "manifest binding Head is not a resolvable commit",
            manifest_path=str(manifest_path),
        ))
    else:
        if manifest.get("binding_tree_sha") != binding_tree:
            findings.append(_finding(
                "FULL_CONVERGENCE_MANIFEST_BINDING_TREE_MISMATCH",
                "P0",
                "manifest binding tree differs from its exact Git Head",
                manifest_path=str(manifest_path),
            ))
        if not _is_ancestor(root, FULL_CONVERGENCE_BASE_HEAD, binding_head):
            findings.append(_finding(
                "FULL_CONVERGENCE_MANIFEST_BINDING_HEAD_NOT_AUTHORIZED_DESCENDANT",
                "P0",
                "manifest binding Head is not a descendant of d701",
                manifest_path=str(manifest_path),
            ))
        if not _is_ancestor(root, binding_head, evaluated_head):
            findings.append(_finding(
                "FULL_CONVERGENCE_MANIFEST_EVALUATED_HEAD_NOT_DESCENDANT",
                "P0",
                "evaluated Head does not descend from the manifest binding Head",
                manifest_path=str(manifest_path),
            ))
    bindings = manifest.get("record_bindings")
    chain = str(manifest.get("record_chain_start_sha256", ""))
    covered: list[str] = []
    if not isinstance(bindings, list) or not bindings:
        findings.append(_finding(
            "FULL_CONVERGENCE_RECORD_BINDINGS_MISSING",
            "P0",
            "the batch does not enumerate an explicit record set",
            manifest_path=str(manifest_path),
        ))
        bindings = []
    for index, binding in enumerate(bindings):
        if not isinstance(binding, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_INVALID",
                "P0",
                "record binding is not an object",
                manifest_path=str(manifest_path),
                index=index,
            ))
            continue
        if binding.get("previous_correction_chain_sha256") != chain:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CHAIN_BREAK",
                "P0",
                "manifest record chain is discontinuous",
                manifest_path=str(manifest_path),
                index=index,
            ))
        payload_sha = binding.get("record_payload_sha256")
        if not _is_sha256(payload_sha) or not _is_sha256(binding.get("record_sha256")):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_HASH_INVALID",
                "P0",
                "manifest record binding lacks exact byte and payload hashes",
                manifest_path=str(manifest_path),
                index=index,
            ))
        chain = str(payload_sha)
        values = binding.get("failure_fingerprints")
        if isinstance(values, list):
            covered.extend(str(value) for value in values)
    if chain != manifest.get("record_chain_terminal_sha256"):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_CHAIN_TERMINAL_MISMATCH",
            "P0",
            "manifest terminal differs from its final record binding payload",
            manifest_path=str(manifest_path),
        ))
    if sorted(covered) != fingerprints or len(covered) != len(set(covered)):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_COVERAGE_MISMATCH",
            "P0",
            "manifest bindings do not cover each fingerprint exactly once",
            manifest_path=str(manifest_path),
        ))
    findings.extend(_batch_artifact_findings(
        manifest_path,
        manifest,
        baseline_identities,
    ))
    if manifest.get("descendant_history_supplement_sha256") != descendant_supplement_sha:
        findings.append(_finding(
            "FULL_CONVERGENCE_DESCENDANT_HISTORY_MANIFEST_HASH_MISMATCH",
            "P0",
            "current manifest does not bind the exact explicit supplement bytes",
            manifest_path=str(manifest_path),
        ))
    return findings


def _predecessor_chain_findings(
    root: Path,
    current_manifest: dict[str, Any],
    immediate_path: Path | None,
    *,
    evaluated_head: str,
    baseline_identities: dict[str, dict[str, str]],
) -> tuple[list[dict[str, Any]], list[tuple[Path, dict[str, Any]]]]:
    """Load the whole sequence-bound predecessor chain without discovery."""

    findings: list[dict[str, Any]] = []
    chain: list[tuple[Path, dict[str, Any]]] = []
    expected_sha = current_manifest.get("previous_batch_append_sha256")
    if not expected_sha:
        if immediate_path is not None:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_UNEXPECTED",
                "P0",
                "an initial batch supplied a predecessor path",
            ))
        return findings, chain
    if immediate_path is None:
        findings.append(_finding(
            "FULL_CONVERGENCE_PREVIOUS_MANIFEST_REQUIRED",
            "P0",
            "a non-initial batch did not supply its explicit immediate predecessor manifest",
        ))
        return findings, chain
    current = current_manifest
    path = immediate_path
    seen_fingerprints = {
        str(value) for value in current_manifest.get("failure_fingerprints", [])
    }
    for depth in range(1, 512):
        try:
            previous = _json(path)
        except (OSError, ValueError):
            previous = None
        if not isinstance(previous, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_UNREADABLE",
                "P0",
                "the sequence-bound predecessor is not one strict JSON object",
                manifest_path=str(path),
            ))
            break
        if _sha_file(path) != expected_sha:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_SHA_MISMATCH",
                "P0",
                "predecessor bytes do not match previous_batch_append_sha256",
                manifest_path=str(path),
            ))
        findings.extend(_manifest_contract_findings(
            root,
            path,
            previous,
            evaluated_head=evaluated_head,
            baseline_identities=baseline_identities,
        ))
        if current.get("record_chain_start_sha256") != previous.get("record_chain_terminal_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_TERMINAL_MISMATCH",
                "P0",
                "the current batch does not continue its predecessor record terminal",
                manifest_path=str(path),
            ))
        current_match = re.fullmatch(r"batch-([0-9]{3})", str(current.get("batch_id", "")))
        previous_match = re.fullmatch(r"batch-([0-9]{3})", str(previous.get("batch_id", "")))
        if (
            current_match is None
            or previous_match is None
            or int(current_match.group(1)) != int(previous_match.group(1)) + 1
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_SEQUENCE_MISMATCH",
                "P0",
                "batch ids are not an exact descending sequence",
                manifest_path=str(path),
            ))
        if previous.get("terminal_remainder_batch") is True:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_ALREADY_TERMINAL",
                "P0",
                "a batch follows a declared terminal remainder",
                manifest_path=str(path),
            ))
        previous_fingerprints = {
            str(value) for value in previous.get("failure_fingerprints", [])
        }
        for fingerprint in sorted(seen_fingerprints & previous_fingerprints):
            findings.append(_finding(
                "FULL_CONVERGENCE_PRIOR_MANIFEST_FINGERPRINT_REUSE",
                "P0",
                "a fingerprint is reused anywhere in the predecessor chain",
                fingerprint=fingerprint,
                manifest_path=str(path),
            ))
        seen_fingerprints.update(previous_fingerprints)
        chain.append((path, previous))
        prior_sha = previous.get("previous_batch_append_sha256")
        if not prior_sha:
            if previous.get("batch_id") != "batch-001":
                findings.append(_finding(
                    "FULL_CONVERGENCE_PREVIOUS_CHAIN_DID_NOT_REACH_BATCH_001",
                    "P0",
                    "predecessor chain ended before batch-001",
                    manifest_path=str(path),
                ))
            if previous.get("record_chain_start_sha256") != LEGACY_CHAIN_TERMINAL_SHA:
                findings.append(_finding(
                    "FULL_CONVERGENCE_LEGACY_CHAIN_NOT_CONTINUED",
                    "P0",
                    "batch-001 does not continue the frozen six-record terminal",
                    manifest_path=str(path),
                ))
            break
        previous_id = str(previous.get("batch_id", ""))
        if previous_match is None or int(previous_match.group(1)) <= 1:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_SEQUENCE_MISMATCH",
                "P0",
                "predecessor link underflows batch-001",
                manifest_path=str(path),
            ))
            break
        prior_id = f"batch-{int(previous_match.group(1)) - 1:03d}"
        prior_path = _derive_prior_manifest_path(path, previous_id, prior_id)
        if prior_path is None:
            findings.append(_finding(
                "FULL_CONVERGENCE_PREVIOUS_MANIFEST_PATH_NOT_SEQUENCE_BOUND",
                "P0",
                "older predecessor path cannot be derived from the explicit immediate path",
                manifest_path=str(path),
            ))
            break
        current = previous
        path = prior_path
        expected_sha = prior_sha
    else:
        findings.append(_finding(
            "FULL_CONVERGENCE_PREVIOUS_MANIFEST_CHAIN_DEPTH_EXCEEDED",
            "P0",
            "predecessor chain exceeded its frozen historical upper bound",
        ))
    return findings, chain


def _common_context(root: Path) -> dict[str, Any]:
    base = root / OUT_DIR
    baseline = base / "baseline_raw_failure_report.json"
    scanner = base / "baseline_scanner_file_manifest.json"
    v1 = base / "baseline_existing_corrections_manifest.json"
    raw_sha, raw_error = _sidecar(baseline)
    scanner_sha, scanner_error = _sidecar(scanner)
    v1_sha, v1_error = _sidecar(v1)
    return {
        "auditor_script_sha256": _sha_file(Path(__file__)),
        "evaluated_authorized_head_sha": AUTHORIZED_HEAD,
        "evaluated_authorized_tree_sha": _git(
            root, "rev-parse", f"{AUTHORIZED_HEAD}^{{tree}}"
        ),
        "authorization_id": AUTHORIZATION_ID,
        "authorized_head_sha": AUTHORIZED_HEAD,
        "baseline_report_sha256": raw_sha,
        "baseline_report_error": raw_error,
        "scanner_manifest_sha256": scanner_sha,
        "scanner_manifest_error": scanner_error,
        "existing_corrections_manifest_sha256": v1_sha,
        "existing_corrections_manifest_error": v1_error,
        "authorized_baseline_sha256_match": raw_sha == AUTHORIZED_BASELINE_SHA,
        "authorized_scanner_sha256_match": scanner_sha == AUTHORIZED_SCANNER_SHA,
        "authorized_v1_sha256_match": v1_sha == AUTHORIZED_V1_SHA,
    }


def audit_a(root: Path) -> dict[str, Any]:
    base = root / OUT_DIR
    findings: list[dict[str, Any]] = []
    context = _common_context(root)
    baseline = _json(base / "baseline_raw_failure_report.json")
    failure_inventory = _json(base / "exact_failure_inventory.json")
    scanner = _json(base / "baseline_scanner_file_manifest.json")
    records = []
    for path in _record_paths(root):
        try:
            records.append((path, _json(path)))
        except (OSError, ValueError):
            findings.append(_finding("CORRECTION_RECORD_UNREADABLE", "P0", "record is not valid JSON", path=str(path)))

    if not context["authorized_baseline_sha256_match"]:
        findings.append(_finding("BASELINE_HASH_NOT_AUTHORIZED", "P0", "frozen raw report hash differs from authorization", actual=context["baseline_report_sha256"], expected=AUTHORIZED_BASELINE_SHA))
    if not context["authorized_scanner_sha256_match"]:
        findings.append(_finding("SCANNER_MANIFEST_HASH_NOT_AUTHORIZED", "P0", "scanner manifest hash differs from authorization", actual=context["scanner_manifest_sha256"], expected=AUTHORIZED_SCANNER_SHA))
    if not context["authorized_v1_sha256_match"]:
        findings.append(_finding("V1_MANIFEST_HASH_NOT_AUTHORIZED", "P0", "V1 manifest hash differs from authorization", actual=context["existing_corrections_manifest_sha256"], expected=AUTHORIZED_V1_SHA))

    if scanner.get("scanner_rule_removal_count", 0) != 0 or scanner.get("scanner_scope_reduction_count", 0) != 0 or scanner.get("scanner_severity_downgrade_count", 0) != 0 or scanner.get("scanner_history_depth_reduction_count", 0) != 0:
        findings.append(_finding("SCANNER_WEAKENING", "P0", "scanner manifest attests a weakening", scanner= scanner))
    listed_scanner = {str(row.get("path", "")) for row in scanner.get("files", []) if isinstance(row, dict)}
    if listed_scanner != SCANNER_PATHS:
        findings.append(_finding("SCANNER_CORE_FILE_SET_DRIFT", "P0", "scanner core file set differs from frozen allowlist", actual=sorted(listed_scanner), expected=sorted(SCANNER_PATHS)))

    inventory_path = base / "correction_record_inventory.json"
    try:
        inventory = _json(inventory_path)
    except (OSError, ValueError):
        inventory = {}
        findings.append(_finding("RECORD_INVENTORY_UNREADABLE", "P0", "record inventory is missing or invalid"))
    expected_paths = {str(row.get("path", "")).replace("\\", "/") for row in inventory.get("records", []) if isinstance(row, dict)}
    actual_paths = {path.relative_to(root).as_posix() for path, _ in records}
    if expected_paths != actual_paths:
        findings.append(_finding("RECORD_INVENTORY_SET_DRIFT", "P0", "record inventory does not exactly enumerate records", missing=sorted(expected_paths - actual_paths), extra=sorted(actual_paths - expected_paths)))
    all_fingerprints: list[str] = []
    previous_chain = ""
    for path, record in records:
        name = path.name
        fingerprints = record.get("failure_fingerprints", [])
        all_fingerprints.extend(str(x) for x in fingerprints if isinstance(x, str))
        if not isinstance(fingerprints, list) or not fingerprints:
            findings.append(_finding("EXPLICIT_FINGERPRINT_MISSING", "P0", "record has no explicit fingerprint list", path=name))
        if any(not isinstance(x, str) or not re.fullmatch(r"V2F-[0-9a-f]{64}", x) for x in fingerprints):
            findings.append(_finding("FINGERPRINT_FORMAT_INVALID", "P0", "record contains a non-exact V2 fingerprint", path=name))
        if record.get("previous_correction_chain_sha256", "") != previous_chain:
            findings.append(_finding("CORRECTION_CHAIN_BREAK", "P0", "record predecessor hash does not match prior record", path=name))
        previous_chain = str(record.get("record_payload_sha256", ""))
        if record.get("record_payload_sha256") != _sha_bytes(_canonical(_record_payload(record))):
            findings.append(_finding("RECORD_PAYLOAD_HASH_MISMATCH", "P0", "record payload hash is not immutable", path=name))
        for key in ("paths", "current_blob_sha256_by_path", "rule_ids", "failure_classes", "transition_class_id", "backlog_item_ids", "future_failure_policy", "touch_invalidation_policy", "revocation_policy", "raw_failures", "failure_bindings"):
            if key not in record:
                findings.append(_finding("RECORD_CONTRACT_FIELD_MISSING", "P0", "record lacks mandatory contract field", path=name, field=key))
        blob_map = record.get("current_blob_sha256_by_path")
        if not isinstance(blob_map, dict):
            findings.append(_finding("CURRENT_BLOB_BINDING_MISSING", "P0", "record has no current blob map", path=name))
        else:
            for key, value in blob_map.items():
                if value != "MISSING" and (not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value)):
                    findings.append(_finding("CURRENT_BLOB_BINDING_INVALID", "P0", "current blob binding is not SHA-256", path=name, subject=key, value=value))
        if record.get("future_failure_policy", {}).get("NEW_FAILURE_REQUIRES_NEW_RECORD") is not True:
            findings.append(_finding("FUTURE_AUTO_CORRECTION", "P0", "future failures could be auto-corrected", path=name))
        # Inspect only selector/class fields and use lexical tokens.  Concrete
        # paths such as ``global_supply_demand_*`` and prose/evidence are not
        # selectors and must not create a false P0.
        selector_values = []
        for key in ("scope", "path_scope", "component_scope", "domain_scope", "selector", "selectors", "pattern", "patterns", "match", "matches", "filter", "filters", "wildcard", "wildcards", "regex", "regular_expression", "rule_ids", "failure_classes", "transition_class_id"):
            value = record.get(key)
            selector_values.extend(value if isinstance(value, list) else [value])
        selector_text = " ".join(str(value).casefold() for value in selector_values)
        selector_tokens = set(re.findall(r"[a-z0-9_]+", selector_text))
        if any(token in selector_tokens for token in ("regex", "glob", "prefix", "directory", "legacy", "unknown", "unknown_accepted", "misc", "other")) or any(char in selector_text for char in ("*", "?", "[", "]")):
            findings.append(_finding("BROAD_CORRECTION_SELECTOR", "P0", "record contains a broad selector or waiver token", path=name))
        attestation = record.get("production_reachability_attestation", {})
        if any(attestation.get(key, 0) != 0 for key in ("active_owner_violation_count", "parallel_owner_count", "dual_write_count", "fallback_count")):
            findings.append(_finding("ACTIVE_OWNER_CORRECTION", "P0", "record attests an active owner, parallel owner, dual-write or fallback", path=name, attestation=attestation))
    duplicates = len(all_fingerprints) - len(set(all_fingerprints))
    if duplicates:
        findings.append(_finding("DUPLICATE_CORRECTION_FINGERPRINT", "P0", "same failure fingerprint is corrected more than once", duplicate_count=duplicates))
    historical = {str(x) for x in baseline.get("failures", []) if str(x).startswith(HISTORY_PREFIX)}
    current = {str(x) for x in baseline.get("failures", []) if not str(x).startswith(HISTORY_PREFIX)}
    current_fingerprints = {
        str(row.get("failure_fingerprint", ""))
        for row in failure_inventory.get("rows", [])
        if isinstance(row, dict) and not str(row.get("rule_id", "")).startswith(HISTORY_PREFIX)
    }
    corrected = set(all_fingerprints)
    inventory_by_fp = {
        str(row.get("failure_fingerprint", "")): row
        for row in failure_inventory.get("rows", [])
        if isinstance(row, dict)
    }
    v1_overlap = sorted(
        fingerprint
        for fingerprint in corrected
        if inventory_by_fp.get(fingerprint, {}).get("existing_correction_id")
    )
    if v1_overlap:
        findings.append(_finding("V1_V2_DUPLICATE_CORRECTION_AUTHORITY", "P0", "a V2 correction fingerprint is already owned by the read-only V1 authority", overlap=v1_overlap))
    if corrected & current_fingerprints:
        findings.append(_finding("CURRENT_FAILURE_CORRECTION_OVERLAP", "P0", "a current baseline failure fingerprint is corrected", overlap=sorted(corrected & current_fingerprints)))
    if inventory.get("corrected_failure_fingerprint_count") != len(all_fingerprints):
        findings.append(_finding("RECORD_INVENTORY_CARDINALITY_DRIFT", "P1", "record inventory fingerprint count is inaccurate", listed=inventory.get("corrected_failure_fingerprint_count"), actual=len(all_fingerprints)))
    return {
        "schema_version": "space_syndicate.v076.reuse_correction_v2.audit_a.v2",
        **context,
        "raw_failure_count": len(baseline.get("failures", [])),
        "raw_historical_failure_count": len(historical),
        "raw_current_delta_failure_count": len(current),
        "record_count": len(records),
        "corrected_fingerprint_count": len(all_fingerprints),
        "p0": [x for x in findings if x["severity"] == "P0"],
        "p1": [x for x in findings if x["severity"] == "P1"],
        "status": "GO" if not any(x["severity"] in {"P0", "P1"} for x in findings) else "NO_GO",
    }


def audit_b(root: Path) -> dict[str, Any]:
    base = root / OUT_DIR
    findings: list[dict[str, Any]] = []
    context = _common_context(root)
    baseline = _json(base / "baseline_raw_failure_report.json")
    inventory = _json(base / "exact_failure_inventory.json")
    rows = [row for row in inventory.get("rows", []) if isinstance(row, dict)]
    by_fp = {str(row.get("failure_fingerprint")): row for row in rows}
    by_raw = {str(row.get("raw_failure")): row for row in rows}
    registry_path, registry_id = _read_registry(root)
    tree_blobs = _tree_blob_map(root)
    records = []
    for path in _record_paths(root):
        try:
            records.append((path, _json(path)))
        except (OSError, ValueError):
            continue
    corrected: set[str] = set()
    for path, record in records:
        rule_ids = {str(x) for x in record.get("rule_ids", [])}
        classes = {str(x) for x in record.get("failure_classes", [])}
        for fingerprint in record.get("failure_fingerprints", []):
            fingerprint = str(fingerprint)
            corrected.add(fingerprint)
            row = by_fp.get(fingerprint)
            if row is None:
                findings.append(_finding("FINGERPRINT_NOT_IN_BASELINE", "P0", "correction fingerprint is absent from frozen inventory", path=path.name, fingerprint=fingerprint))
                continue
            eligibility = row.get("transition_eligibility")
            if not isinstance(eligibility, dict) or eligibility.get("eligible_for_correction") is not True:
                findings.append(_finding("TRANSITION_CLASS_NOT_ELIGIBLE", "P0", "record covers a row without independently verified historical transition eligibility", path=path.name, fingerprint=fingerprint, reasons=(eligibility or {}).get("ineligibility_reasons", [])))
            if not str(record.get("transition_class_id", "")):
                findings.append(_finding("TRANSITION_CLASS_MISSING", "P0", "record has no explicit transition class", path=path.name, fingerprint=fingerprint))
            if str(row.get("raw_failure")) not in by_raw:
                findings.append(_finding("RAW_FAILURE_IDENTITY_MISSING", "P0", "inventory row cannot be tied to raw failure", fingerprint=fingerprint))
            row_rule = str(row.get("rule_id", ""))
            if row_rule not in rule_ids or row_rule not in classes:
                findings.append(_finding("RULE_CLASS_MISMATCH", "P0", "record class does not match exact inventory row", path=path.name, fingerprint=fingerprint, row_rule=row_rule, record_rules=sorted(rule_ids), record_classes=sorted(classes)))
            if not row_rule.startswith(HISTORY_PREFIX):
                findings.append(_finding("CURRENT_DELTA_CORRECTION", "P0", "record covers a current-delta fingerprint", path=path.name, fingerprint=fingerprint, rule=row_rule))
            row_path = str(row.get("path", "")).replace("\\", "/")
            blob_map = record.get("current_blob_sha256_by_path", {})
            if row_path:
                expected = str(row.get("current_blob_sha256", ""))
                declared = blob_map.get(row_path) if isinstance(blob_map, dict) else None
                if declared != expected:
                    findings.append(_finding("CURRENT_BLOB_BINDING_MISMATCH", "P0", "record blob map differs from inventory", path=path.name, fingerprint=fingerprint, expected=expected, declared=declared))
                git_blob = tree_blobs.get(row_path)
                live_sha = _git_blob_sha256(root, git_blob) if git_blob else "MISSING"
                if live_sha != expected:
                    findings.append(_finding("CURRENT_BLOB_NOT_LIVE", "P0", "record blob binding does not match authorized tree", path=path.name, fingerprint=fingerprint, subject=row_path, expected=expected, actual=live_sha))
            else:
                findings.append(_finding("NO_CONCRETE_BLOB_SUBJECT", "P1", "corrected row has no concrete path and therefore no verifiable current blob binding", path=path.name, fingerprint=fingerprint, component_id=row.get("component_id", ""), domain_id=row.get("domain_id", "")))
            component_id = str(row.get("component_id", ""))
            subject = registry_path.get(row_path) if row_path else registry_id.get(component_id)
            if subject is None:
                findings.append(_finding("REACHABILITY_UNRESOLVED", "P1", "component/path is absent from authoritative registry; non-production reachability is unproven", path=path.name, fingerprint=fingerprint, subject=row_path or component_id))
            elif subject.get("production_reachable") is True and record.get("production_reachability_attestation", {}).get("states") == ["non_production_or_unresolved"]:
                findings.append(_finding("REACHABILITY_ATTESTATION_MISMATCH", "P0", "record says non-production/unresolved but registry says production reachable", path=path.name, fingerprint=fingerprint, subject=row_path or component_id))
    raw_values = {str(value) for value in baseline.get("failures", [])}
    if len(rows) != len(raw_values):
        findings.append(_finding("INVENTORY_COVERAGE_OR_DUPLICATE", "P0", "inventory does not cover each unique raw failure exactly once", raw_count=len(raw_values), inventory_count=len(rows)))
    if set(str(row.get("raw_failure")) for row in rows) != raw_values:
        findings.append(_finding("INVENTORY_RAW_SET_MISMATCH", "P0", "inventory raw failure set differs from frozen report"))
    current_rows = [row for row in rows if not str(row.get("rule_id", "")).startswith(HISTORY_PREFIX)]
    if not current_rows:
        findings.append(_finding("CURRENT_DELTA_NOT_RETAINED", "P0", "inventory has no independently classified current-delta failures"))
    historical_rows = [row for row in rows if str(row.get("rule_id", "")).startswith(HISTORY_PREFIX)]
    if len(corrected & {str(row.get("failure_fingerprint")) for row in current_rows}):
        findings.append(_finding("CURRENT_FINGERPRINT_CORRECTED", "P0", "at least one current-delta inventory fingerprint is corrected"))
    # Missing registry identities are retained as explicit P1 findings above;
    # this aggregate makes the audit decision easy to consume.
    unresolved_rows = [row for row in historical_rows if not ((str(row.get("path", "")) and str(row.get("path", "")).replace("\\", "/") in registry_path) or (str(row.get("component_id", "")) and str(row.get("component_id", "")) in registry_id))]
    unresolved = len(unresolved_rows)
    no_blob_rows = [row for row in historical_rows if not row.get("path")]
    no_blob = len(no_blob_rows)
    return {
        "schema_version": "space_syndicate.v076.reuse_correction_v2.audit_b.v2",
        **context,
        "raw_failure_count": len(raw_values),
        "raw_historical_failure_count": len(historical_rows),
        "raw_current_delta_failure_count": len(current_rows),
        "corrected_fingerprint_count": len(corrected),
        "registry_unresolved_historical_row_count": unresolved,
        "registry_unresolved_historical_fingerprints": sorted(str(row.get("failure_fingerprint", "")) for row in unresolved_rows),
        "historical_rows_without_concrete_path_count": no_blob,
        "historical_rows_without_concrete_path_fingerprints": sorted(str(row.get("failure_fingerprint", "")) for row in no_blob_rows),
        "p0": [x for x in findings if x["severity"] == "P0"],
        "p1": [x for x in findings if x["severity"] == "P1"],
        "status": "GO" if not any(x["severity"] in {"P0", "P1"} for x in findings) else "NO_GO",
    }


def audit_full_convergence_batch(
    root: Path,
    manifest_path: Path,
    *,
    evaluated_head: str,
    baseline_report_path: Path | None = None,
    previous_batch_manifest_path: Path | None = None,
    descendant_history_supplement_path: Path | None = None,
    descendant_history_raw_report_path: Path | None = None,
    descendant_history_scanner_path: Path | None = None,
) -> dict[str, Any]:
    """Independently verify one explicit new-epoch batch and its legacy anchor.

    This intentionally duplicates the security-critical checks instead of
    importing the resolver extension.  Directory discovery is not authority:
    only record paths enumerated by ``manifest_path`` are evaluated.
    """
    findings: list[dict[str, Any]] = []
    baseline_fingerprints = {"historical": set(), "current": set()}
    baseline_identities: dict[str, dict[str, str]] = {}
    baseline_report: dict[str, Any] = {}
    if baseline_report_path is None:
        findings.append(_finding(
            "FULL_CONVERGENCE_BASELINE_REQUIRED",
            "P0",
            "the full-convergence batch audit requires the explicit authorized raw report",
        ))
    elif not baseline_report_path.is_file() or _sha_file(baseline_report_path) != FULL_CONVERGENCE_BASELINE_SHA:
        findings.append(_finding(
            "FULL_CONVERGENCE_BASELINE_DRIFT",
            "P0",
            "the d701 raw failure report differs from the authorized digest",
        ))
    else:
        try:
            baseline_report = _json(baseline_report_path)
        except (OSError, ValueError):
            baseline_report = {}
            findings.append(_finding(
                "FULL_CONVERGENCE_BASELINE_UNREADABLE",
                "P0",
                "the authorized raw failure report is not valid JSON",
            ))
        baseline_fingerprints = _authorized_failure_fingerprint_sets(baseline_report)
        baseline_identities = _authorized_failure_identity_by_fingerprint(
            baseline_report
        )
        if (
            len(baseline_fingerprints["historical"]) != 510
            or len(baseline_fingerprints["current"]) != 56
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_BASELINE_FINGERPRINT_SET_INVALID",
                "P0",
                "the frozen report does not derive the exact 510 historical and 56 current fingerprints",
            ))
    (
        supplement_findings,
        descendant_fingerprints,
        descendant_identities,
        descendant_supplement_sha,
        descendant_report_head,
    ) = _descendant_history_supplement_findings(
        root,
        supplement_path=descendant_history_supplement_path,
        raw_report_path=descendant_history_raw_report_path,
        scanner_path=descendant_history_scanner_path,
        evaluated_head=evaluated_head,
        baseline_report=baseline_report,
        baseline_sets=baseline_fingerprints,
    )
    findings.extend(supplement_findings)
    baseline_fingerprints["historical"].update(descendant_fingerprints)
    baseline_identities.update(descendant_identities)
    schema_path = root / FULL_CONVERGENCE_SCHEMA
    if not schema_path.is_file() or _sha_file(schema_path) != FULL_CONVERGENCE_SCHEMA_SHA:
        findings.append(_finding(
            "FULL_CONVERGENCE_SCHEMA_DRIFT",
            "P0",
            "full-convergence schema bytes differ from the authorized digest",
        ))
    seal_path = root / LEGACY_SEAL_PATH
    if not seal_path.is_file() or _sha_file(seal_path) != LEGACY_SEAL_SHA:
        findings.append(_finding(
            "LEGACY_SEAL_BYTE_DRIFT",
            "P0",
            "the CI_PORTABILITY_V2 predecessor seal changed",
        ))
    legacy_fingerprints: set[str] = set()
    for relative, expected in LEGACY_RECORD_SHA_BY_PATH.items():
        path = root / relative
        if not path.is_file() or _sha_file(path) != expected:
            findings.append(_finding(
                "LEGACY_RECORD_BYTE_DRIFT",
                "P0",
                "one of the exact six legacy records changed",
                path=relative,
            ))
            continue
        try:
            legacy_record = _json(path)
        except (OSError, ValueError):
            findings.append(_finding(
                "LEGACY_RECORD_UNREADABLE",
                "P0",
                "one of the byte-locked legacy records is not valid JSON",
                path=relative,
            ))
            continue
        values = legacy_record.get("failure_fingerprints")
        if not isinstance(values, list):
            findings.append(_finding(
                "LEGACY_RECORD_FINGERPRINT_SET_INVALID",
                "P0",
                "one of the byte-locked legacy records lacks its fingerprint set",
                path=relative,
            ))
            continue
        for value in values:
            rendered = str(value)
            if rendered in legacy_fingerprints:
                findings.append(_finding(
                    "LEGACY_RECORD_FINGERPRINT_DUPLICATE",
                    "P0",
                    "legacy records contain a duplicate corrected fingerprint",
                    path=relative,
                    fingerprint=rendered,
                ))
            legacy_fingerprints.add(rendered)
    try:
        manifest = _json(manifest_path)
    except (OSError, ValueError):
        manifest = {}
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_MANIFEST_UNREADABLE",
            "P0",
            "the explicit batch manifest is missing or invalid JSON",
        ))
    if not isinstance(manifest, dict):
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_MANIFEST_NOT_OBJECT",
            "P0",
            "the explicit batch manifest must be a JSON object",
        ))
        manifest = {}
    manifest_fingerprints = [
        str(value) for value in manifest.get("failure_fingerprints", [])
    ]
    if (
        manifest_fingerprints != sorted(manifest_fingerprints)
        or len(manifest_fingerprints) != len(set(manifest_fingerprints))
        or any(not re.fullmatch(r"V2F-[0-9a-f]{64}", value) for value in manifest_fingerprints)
    ):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_SET_INVALID",
            "P0",
            "manifest fingerprints must be unique sorted exact V2 identities",
        ))
    if manifest.get("failure_count") != len(manifest_fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_COUNT_MISMATCH",
            "P0",
            "manifest failure_count differs from its explicit fingerprint list",
        ))
    if manifest.get("failure_fingerprint_set_sha256") != _line_set_sha(manifest_fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_FINGERPRINT_HASH_MISMATCH",
            "P0",
            "manifest fingerprint set digest is not canonical",
        ))
    if not 1 <= len(manifest_fingerprints) <= 50:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BATCH_SIZE_INVALID",
            "P0",
            "a batch must contain between one and fifty exact fingerprints",
        ))
    if len(manifest_fingerprints) < 25 and manifest.get("terminal_remainder_batch") is not True:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_NONTERMINAL_BELOW_TARGET",
            "P0",
            "a nonterminal batch cannot contain fewer than twenty-five fingerprints",
        ))
    manifest_binding_head = str(manifest.get("binding_head_sha", ""))
    manifest_binding_tree = _git(root, "rev-parse", f"{manifest_binding_head}^{{tree}}")
    if not re.fullmatch(r"[0-9a-f]{40}", manifest_binding_head) or not manifest_binding_tree:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BINDING_HEAD_UNRESOLVED",
            "P0",
            "manifest binding Head is not a resolvable commit",
        ))
    elif manifest.get("binding_tree_sha") != manifest_binding_tree:
        findings.append(_finding(
            "FULL_CONVERGENCE_MANIFEST_BINDING_TREE_MISMATCH",
            "P0",
            "manifest binding tree differs from its exact Git Head",
        ))
    for field, expected in (
        ("authorization_id", FULL_CONVERGENCE_AUTHORIZATION_ID),
        ("authorization_base_head_sha", FULL_CONVERGENCE_BASE_HEAD),
        ("baseline_report_sha256", FULL_CONVERGENCE_BASELINE_SHA),
        ("baseline_failure_set_sha256", FULL_CONVERGENCE_FAILURE_SET_SHA),
        ("batch_review_a_status", "GO"),
        ("batch_review_b_status", "GO"),
        ("identity_coverage_percent", 100),
        ("batch_unknown_count", 0),
        ("batch_wildcard_count", 0),
        ("current_failure_false_accept_count", 0),
    ):
        if manifest.get(field) != expected:
            findings.append(_finding(
                "FULL_CONVERGENCE_BATCH_AUTHORITY_MISMATCH",
                "P0",
                "batch authority or review assertion differs from the closed contract",
                field=field,
                expected=expected,
                actual=manifest.get(field),
            ))
    findings.extend(_batch_artifact_findings(
        manifest_path,
        manifest,
        baseline_identities,
    ))
    chain_findings, predecessor_chain = _predecessor_chain_findings(
        root,
        manifest,
        previous_batch_manifest_path,
        evaluated_head=evaluated_head,
        baseline_identities=baseline_identities,
    )
    findings.extend(chain_findings)
    predecessor_fingerprints: set[str] = set()
    predecessor_correction_ids: set[str] = set()
    predecessor_record_count = 0
    for predecessor_path, predecessor_manifest in reversed(predecessor_chain):
        if (
            predecessor_manifest.get("descendant_history_supplement_sha256")
            != descendant_supplement_sha
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_DESCENDANT_HISTORY_MANIFEST_HASH_MISMATCH",
                "P0",
                "predecessor manifest does not bind the same explicit supplement bytes",
                manifest_path=str(predecessor_path),
            ))
        record_findings, record_fingerprints, correction_ids, record_count = (
            _manifest_record_findings(
                root,
                predecessor_manifest,
                evaluated_head=evaluated_head,
                baseline_identities=baseline_identities,
            )
        )
        findings.extend(record_findings)
        for fingerprint in sorted(record_fingerprints):
            if fingerprint in baseline_fingerprints["current"]:
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_CURRENT_FAILURE_CORRECTION",
                    "P0",
                    "a predecessor record fingerprint belongs to the frozen current set",
                    manifest_path=str(predecessor_path),
                    fingerprint=fingerprint,
                ))
            elif fingerprint not in baseline_fingerprints["historical"]:
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL",
                    "P0",
                    "a predecessor record fingerprint is absent from the frozen historical set",
                    manifest_path=str(predecessor_path),
                    fingerprint=fingerprint,
                ))
            if fingerprint in legacy_fingerprints:
                findings.append(_finding(
                    "FULL_CONVERGENCE_LEGACY_FINGERPRINT_REUSE",
                    "P0",
                    "a predecessor record repeats a frozen legacy correction fingerprint",
                    manifest_path=str(predecessor_path),
                    fingerprint=fingerprint,
                ))
        for fingerprint in sorted(predecessor_fingerprints & record_fingerprints):
            findings.append(_finding(
                "FULL_CONVERGENCE_PRIOR_RECORD_FINGERPRINT_REUSE",
                "P0",
                "actual predecessor records reuse a nonadjacent fingerprint",
                manifest_path=str(predecessor_path),
                fingerprint=fingerprint,
            ))
        predecessor_fingerprints.update(record_fingerprints)
        for correction_id in sorted(predecessor_correction_ids & correction_ids):
            findings.append(_finding(
                "FULL_CONVERGENCE_PRIOR_RECORD_CORRECTION_ID_REUSE",
                "P0",
                "actual predecessor records reuse a correction id",
                manifest_path=str(predecessor_path),
                correction_id=correction_id,
            ))
        predecessor_correction_ids.update(correction_ids)
        predecessor_record_count += record_count
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or not bindings:
        findings.append(_finding(
            "FULL_CONVERGENCE_RECORD_BINDINGS_MISSING",
            "P0",
            "the batch does not enumerate an explicit record set",
        ))
        bindings = []
    previous = str(manifest.get("record_chain_start_sha256", ""))
    if not manifest.get("previous_batch_append_sha256") and previous != LEGACY_CHAIN_TERMINAL_SHA:
        findings.append(_finding(
            "FULL_CONVERGENCE_LEGACY_CHAIN_NOT_CONTINUED",
            "P0",
            "the first full-convergence batch does not continue the six-record terminal",
            expected=LEGACY_CHAIN_TERMINAL_SHA,
            actual=previous,
        ))
    all_fingerprints: list[str] = []
    for index, binding in enumerate(bindings):
        if not isinstance(binding, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_INVALID",
                "P0",
                "record binding is not an object",
                index=index,
            ))
            continue
        relative = str(binding.get("path", "")).replace("\\", "/")
        if (
            not relative.startswith(FULL_CONVERGENCE_RECORD_ROOT)
            or any(char in relative for char in "*?[]")
            or relative.endswith("/")
            or "/../" in relative
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PATH_NOT_EXACT",
                "P0",
                "record path is outside the explicit epoch root or contains selector syntax",
                path=relative,
            ))
            continue
        if binding.get("previous_correction_chain_sha256") != previous:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CHAIN_BREAK",
                "P0",
                "record predecessor does not match the prior payload",
                path=relative,
            ))
        previous = str(binding.get("record_payload_sha256", ""))
        path = root / relative
        if not path.is_file() or _sha_file(path) != binding.get("record_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BYTE_DRIFT",
                "P0",
                "record bytes do not match the explicit binding",
                path=relative,
            ))
            continue
        try:
            record = _json(path)
        except (OSError, ValueError):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_UNREADABLE",
                "P0",
                "record is not valid JSON",
                path=relative,
            ))
            continue
        if not isinstance(record, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_NOT_OBJECT",
                "P0",
                "a new record must be a JSON object",
                path=relative,
            ))
            continue
        if record.get("authorization_id") != FULL_CONVERGENCE_AUTHORIZATION_ID:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_AUTHORIZATION_MISMATCH",
                "P0",
                "a new record does not use the new epoch authorization",
                path=relative,
            ))
        if record.get("authorization_base_head_sha") != FULL_CONVERGENCE_BASE_HEAD:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BASE_HEAD_MISMATCH",
                "P0",
                "a new record is not rooted at d701",
                path=relative,
            ))
        if record.get("baseline_report_sha256") != FULL_CONVERGENCE_BASELINE_SHA:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BASELINE_MISMATCH",
                "P0",
                "a new record is not bound to the d701 raw report",
                path=relative,
            ))
        if record.get("binding_head_sha") != manifest.get("binding_head_sha"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_HEAD_MISMATCH",
                "P0",
                "record and batch manifest bind different Heads",
                path=relative,
            ))
        if record.get("binding_tree_sha") != manifest.get("binding_tree_sha"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_BINDING_TREE_MISMATCH",
                "P0",
                "record and batch manifest bind different trees",
                path=relative,
            ))
        for hash_field in BATCH_ARTIFACT_SPECS:
            if record.get(hash_field) != manifest.get(hash_field):
                findings.append(_finding(
                    "FULL_CONVERGENCE_RECORD_ARTIFACT_BINDING_MISMATCH",
                    "P0",
                    "record evidence digest differs from its manifest",
                    path=relative,
                    field=hash_field,
                ))
        if (
            record.get("descendant_history_supplement_sha256")
            != manifest.get("descendant_history_supplement_sha256")
        ):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_DESCENDANT_SUPPLEMENT_BINDING_MISMATCH",
                "P0",
                "record descendant-history seal differs from its manifest",
                path=relative,
            ))
        expected_payload_sha = _sha_bytes(_canonical(_record_payload(record)))
        if record.get("record_payload_sha256") != expected_payload_sha:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PAYLOAD_HASH_MISMATCH",
                "P0",
                "record payload digest does not bind its canonical content",
                path=relative,
            ))
        if record.get("record_payload_sha256") != binding.get("record_payload_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PAYLOAD_BINDING_MISMATCH",
                "P0",
                "record payload digest differs from the explicit manifest binding",
                path=relative,
            ))
        if record.get("previous_correction_chain_sha256") != binding.get("previous_correction_chain_sha256"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_PREDECESSOR_BINDING_MISMATCH",
                "P0",
                "record predecessor differs from the explicit manifest chain",
                path=relative,
            ))
        if record.get("correction_id") != binding.get("correction_id"):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_ID_BINDING_MISMATCH",
                "P0",
                "record correction id differs from the explicit manifest binding",
                path=relative,
            ))
        if record.get("future_failure_policy") != {
            "FUTURE_FAILURE_AUTO_CORRECTION_COUNT": 0,
            "NEW_FAILURE_REQUIRES_NEW_RECORD": True,
        }:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FUTURE_AUTO_CORRECTION_ENABLED",
                "P0",
                "record future-failure policy is not exact and fail-closed",
                path=relative,
            ))
        rules = record.get("rule_ids", [])
        if not isinstance(rules, list) or len(rules) != 1 or not str(rules[0]).startswith(HISTORY_PREFIX):
            findings.append(_finding(
                "FULL_CONVERGENCE_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a new record is not restricted to one historical rule",
                path=relative,
            ))
        subjects = record.get("identity_binding_by_failure")
        if not isinstance(subjects, dict):
            findings.append(_finding(
                "FULL_CONVERGENCE_SUBJECT_PROJECTION_MISSING",
                "P0",
                "record lacks per-fingerprint subject projections",
                path=relative,
            ))
        else:
            for fingerprint, subject in subjects.items():
                if not isinstance(subject, dict):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_PROJECTION_INVALID",
                        "P0",
                        "subject projection is not an object",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                    continue
                findings.extend(_raw_identity_findings(
                    root,
                    fingerprint=str(fingerprint),
                    subject=subject,
                    identity=baseline_identities.get(str(fingerprint)),
                    record_rule_ids=(
                        [str(value) for value in rules]
                        if isinstance(rules, list)
                        else []
                    ),
                    path=relative,
                ))
                projection = subject.get("subject_projection")
                if (
                    not isinstance(projection, dict)
                    or subject.get("subject_projection_sha256") != _sha_bytes(_canonical(projection))
                ):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_PROJECTION_HASH_MISMATCH",
                        "P0",
                        "subject projection is not bound by its canonical digest",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                    continue
                selector = subject.get("authority_selectors")
                binding_head = str(record.get("binding_head_sha", ""))
                if not _selector_is_exact(selector):
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_SELECTOR_NOT_EXACT",
                        "P0",
                        "subject projection lacks an exact wildcard-free selector",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                    continue
                binding_projection = _subject_projection(root, binding_head, selector)
                current_projection = _subject_projection(root, evaluated_head, selector)
                if binding_projection != projection:
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_BINDING_MISMATCH",
                        "P0",
                        "subject projection differs from its binding Head",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
                if current_projection != projection:
                    findings.append(_finding(
                        "FULL_CONVERGENCE_SUBJECT_PROJECTION_CHANGED",
                        "P0",
                        "subject projection changed at the evaluated Head",
                        path=relative,
                        fingerprint=fingerprint,
                    ))
        record_fingerprints = [str(value) for value in record.get("failure_fingerprints", [])]
        if record_fingerprints != list(binding.get("failure_fingerprints", [])):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FINGERPRINT_BINDING_MISMATCH",
                "P0",
                "record fingerprint set differs from the batch manifest",
                path=relative,
            ))
        if not isinstance(subjects, dict) or set(subjects) != set(record_fingerprints):
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_IDENTITY_BINDING_SET_MISMATCH",
                "P0",
                "record must bind one exact identity projection per fingerprint",
                path=relative,
            ))
        all_fingerprints.extend(record_fingerprints)
    if previous != manifest.get("record_chain_terminal_sha256"):
        findings.append(_finding(
            "FULL_CONVERGENCE_CHAIN_TERMINAL_MISMATCH",
            "P0",
            "batch terminal does not equal the final record payload",
        ))
    if sorted(all_fingerprints) != manifest_fingerprints or len(all_fingerprints) != len(set(all_fingerprints)):
        findings.append(_finding(
            "FULL_CONVERGENCE_BATCH_COVERAGE_MISMATCH",
            "P0",
            "record bindings do not cover each manifest fingerprint exactly once",
        ))
    for fingerprint in sorted(set(all_fingerprints) & predecessor_fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_PRIOR_RECORD_FINGERPRINT_REUSE",
            "P0",
            "the current actual records reuse a fingerprint from any predecessor",
            fingerprint=fingerprint,
        ))
    current_correction_ids = {
        str(binding.get("correction_id", ""))
        for binding in bindings
        if isinstance(binding, dict)
    }
    for correction_id in sorted(current_correction_ids & predecessor_correction_ids):
        findings.append(_finding(
            "FULL_CONVERGENCE_PRIOR_RECORD_CORRECTION_ID_REUSE",
            "P0",
            "the current batch reuses a correction id from a predecessor",
            correction_id=correction_id,
        ))
    for fingerprint in sorted(set(manifest_fingerprints)):
        if fingerprint in baseline_fingerprints["current"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a manifest fingerprint belongs to the frozen current-failure set",
                fingerprint=fingerprint,
            ))
        elif fingerprint not in baseline_fingerprints["historical"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL",
                "P0",
                "a manifest fingerprint is absent from the frozen historical-failure set",
                fingerprint=fingerprint,
            ))
    for fingerprint in sorted(set(manifest_fingerprints) & legacy_fingerprints):
        findings.append(_finding(
            "FULL_CONVERGENCE_LEGACY_FINGERPRINT_REUSE",
            "P0",
            "a new-epoch batch repeats a fingerprint already corrected by the frozen legacy epoch",
            fingerprint=fingerprint,
        ))
    for fingerprint in sorted(set(all_fingerprints)):
        if fingerprint in baseline_fingerprints["current"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_CURRENT_FAILURE_CORRECTION",
                "P0",
                "a record fingerprint belongs to the frozen current-failure set",
                fingerprint=fingerprint,
            ))
        elif fingerprint not in baseline_fingerprints["historical"]:
            findings.append(_finding(
                "FULL_CONVERGENCE_RECORD_FINGERPRINT_NOT_AUTHORIZED_HISTORICAL",
                "P0",
                "a record fingerprint is absent from the frozen historical-failure set",
                fingerprint=fingerprint,
            ))
    return {
        "schema_version": "space_syndicate.v076.reuse_correction_v2.full_convergence_independent_audit.v1",
        "authorization_id": FULL_CONVERGENCE_AUTHORIZATION_ID,
        "authorization_base_head_sha": FULL_CONVERGENCE_BASE_HEAD,
        "authorized_head_sha": FULL_CONVERGENCE_BASE_HEAD,
        "evaluated_head_sha": evaluated_head,
        "raw_failure_count": 566,
        "raw_historical_failure_count": 510,
        "raw_current_delta_failure_count": 56,
        "manifest_path": str(manifest_path),
        "legacy_record_count": len(LEGACY_RECORD_SHA_BY_PATH),
        "new_record_count": predecessor_record_count + len(bindings),
        "new_fingerprint_count": len(predecessor_fingerprints | set(all_fingerprints)),
        "validated_batch_count": len(predecessor_chain) + 1,
        "descendant_history_supplement_sha256": descendant_supplement_sha,
        "descendant_history_raw_report_head_sha": descendant_report_head,
        "descendant_history_authorized_fingerprint_count": len(descendant_fingerprints),
        "p0": [item for item in findings if item["severity"] == "P0"],
        "p1": [item for item in findings if item["severity"] == "P1"],
        "status": "GO" if not findings else "NO_GO",
    }


def _markdown(title: str, report: dict[str, Any]) -> str:
    lines = [f"# {title}", "", f"- Status: `{report['status']}`", f"- P0: `{len(report['p0'])}`", f"- P1: `{len(report['p1'])}`", f"- Authorized head: `{report['authorized_head_sha']}`", f"- Raw failures: `{report['raw_failure_count']}`", f"- Raw historical: `{report['raw_historical_failure_count']}`", f"- Raw current delta: `{report['raw_current_delta_failure_count']}`", ""]
    if "registry_unresolved_historical_row_count" in report:
        lines.extend([
            f"- Registry-unresolved historical rows retained as blocking: `{report['registry_unresolved_historical_row_count']}`",
            f"- Historical rows without concrete path/blob subject: `{report.get('historical_rows_without_concrete_path_count', 0)}`",
            "",
            "Unresolved fingerprints are retained in `registry_unresolved_historical_fingerprints` in the JSON report; none are treated as corrected.",
            "",
        ])
    for label in ("P0", "P1"):
        entries = report[label.casefold()]
        lines.extend([f"## {label}", ""])
        if not entries:
            lines.append("None.")
        else:
            for item in entries:
                evidence = ", ".join(f"{k}={v}" for k, v in item.get("evidence", {}).items())
                lines.append(f"- `{item['code']}` — {item['message']} ({evidence})")
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument(
        "--output-root",
        type=Path,
        default=None,
        help="write audit reports beneath this root while reading only --project inputs",
    )
    parser.add_argument(
        "--full-convergence-batch-manifest",
        type=Path,
        default=None,
        help="independently audit only the explicitly enumerated new-epoch batch",
    )
    parser.add_argument(
        "--previous-batch-manifest",
        type=Path,
        default=None,
        help="explicit immediate predecessor manifest for a non-initial full-convergence batch",
    )
    parser.add_argument(
        "--full-convergence-baseline-report",
        type=Path,
        default=None,
        help="explicit d701 raw report bound by the full-convergence authorization",
    )
    parser.add_argument(
        "--descendant-history-supplement",
        type=Path,
        default=None,
        help="explicit one-shot byte-sealed descendant HISTORY membership manifest",
    )
    parser.add_argument(
        "--descendant-history-raw-report",
        type=Path,
        default=None,
        help="explicit committed-only final raw report with current failure count zero",
    )
    parser.add_argument(
        "--descendant-history-scanner",
        type=Path,
        default=None,
        help="explicit scanner file whose bytes must match the report Head",
    )
    parser.add_argument(
        "--evaluated-head-ref",
        default="HEAD",
        help="Head used for subject-projection invalidation in full-convergence mode",
    )
    args = parser.parse_args(argv)
    root = args.project.resolve()
    output_root = (args.output_root or root).resolve()
    out = output_root / OUT_DIR
    out.mkdir(parents=True, exist_ok=True)
    if args.full_convergence_batch_manifest is not None:
        if (
            args.full_convergence_baseline_report is None
            or args.descendant_history_supplement is None
            or args.descendant_history_raw_report is None
            or args.descendant_history_scanner is None
        ):
            raise SystemExit(
                "--full-convergence-batch-manifest requires "
                "--full-convergence-baseline-report, "
                "--descendant-history-supplement, "
                "--descendant-history-raw-report, and "
                "--descendant-history-scanner"
            )
        report = audit_full_convergence_batch(
            root,
            args.full_convergence_batch_manifest.resolve(),
            evaluated_head=_git(root, "rev-parse", f"{args.evaluated_head_ref}^{{commit}}"),
            baseline_report_path=args.full_convergence_baseline_report.resolve(),
            previous_batch_manifest_path=(
                args.previous_batch_manifest.resolve()
                if args.previous_batch_manifest is not None
                else None
            ),
            descendant_history_supplement_path=(
                args.descendant_history_supplement.resolve()
            ),
            descendant_history_raw_report_path=(
                args.descendant_history_raw_report.resolve()
            ),
            descendant_history_scanner_path=(
                args.descendant_history_scanner.resolve()
            ),
        )
        (out / "audit_full_convergence_batch.json").write_bytes(_canonical(report))
        (out / "audit_full_convergence_batch.md").write_text(
            _markdown("Independent Audit — Full-convergence V2 batch", report),
            encoding="utf-8",
        )
        print(json.dumps({"full_convergence_batch": report}, ensure_ascii=False, indent=2))
        return 0 if report["status"] == "GO" else 1
    report_a = audit_a(root)
    report_b = audit_b(root)
    (out / "audit_a_mechanism_safety.json").write_bytes(_canonical(report_a))
    (out / "audit_a_mechanism_safety.md").write_text(_markdown("Audit A — Correction mechanism safety", report_a), encoding="utf-8")
    (out / "audit_b_failure_classification.json").write_bytes(_canonical(report_b))
    (out / "audit_b_failure_classification.md").write_text(_markdown("Audit B — Failure classification accuracy", report_b), encoding="utf-8")
    print(json.dumps({"audit_a": report_a, "audit_b": report_b}, ensure_ascii=False, indent=2))
    return 0 if report_a["status"] == "GO" and report_b["status"] == "GO" else 1


if __name__ == "__main__":
    raise SystemExit(main())
