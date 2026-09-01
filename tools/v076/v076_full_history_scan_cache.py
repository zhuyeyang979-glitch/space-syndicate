#!/usr/bin/env python3
"""Deterministic full-history scan sharding and cache verification.

This is ordinary, non-authoritative tooling.  It does not alter the scanner,
the rule manifest, the correction registry, or any product file.  ``plan``
enumerates the complete immutable commit input and emits a manifest whose
shards can be scanned independently.  ``verify`` is deliberately fail-closed:
an incomplete, cancelled, failed, or unbound shard can never be interpreted
as a successful scan.

The cache identity includes all four inputs which can change scan semantics:
the commit SHA, its tree SHA, the scanner bytes, and the rule-manifest bytes.
The result and failure-set digests are canonical JSON/line-set digests, so an
aggregator can compare old and sharded scans without trusting presentation
ordering.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


SCHEMA_VERSION = "space_syndicate.v076.full_history_scan_shard_manifest.v1"
MANIFEST_KIND = "FULL_HISTORY_SHARD_MANIFEST"
RESULT_SCHEMA_VERSION = "space_syndicate.v076.full_history_scan_shard_result.v1"
HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def canonical_bytes(value: Any) -> bytes:
    """Return stable UTF-8 JSON bytes used by all semantic digests."""

    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def line_set_sha256(values: Iterable[str]) -> str:
    """Digest canonical sorted lines (including a final newline).

    The name is retained for compatibility with the V076 evidence helpers.
    Duplicates are intentionally *not* discarded: a duplicate commit or
    fingerprint must alter the digest and then be reported as a hard finding,
    rather than being silently normalized away.
    """

    normalized = sorted(str(value) for value in values)
    return sha256_bytes(("\n".join(normalized) + "\n").encode("utf-8"))


def _require_sha(value: Any, *, length: int, field: str) -> str:
    rendered = value if isinstance(value, str) else ""
    pattern = HEX40 if length == 40 else HEX64
    if not pattern.fullmatch(rendered):
        raise ValueError(f"{field} must be lowercase hexadecimal SHA-{length * 4}")
    return rendered


def _strict_int(value: Any, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{field} must be an integer")
    return value


def _resolve_repo_path(repo: Path, value: str | Path) -> Path:
    candidate = Path(value)
    if not candidate.is_absolute():
        candidate = repo / candidate
    return candidate


def _git(repo: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        cwd=repo,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if completed.returncode:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise ValueError(f"git {' '.join(args)} failed: {detail}")
    return completed.stdout.strip()


def commit_tree_sha(repo: Path, commit_sha: str) -> str:
    _require_sha(commit_sha, length=40, field="commit_sha")
    return _require_sha(
        _git(repo, "rev-parse", f"{commit_sha}^{{tree}}"),
        length=40,
        field="tree_sha",
    )


def cache_key_material(
    commit_sha: str,
    tree_sha: str,
    scanner_sha256: str,
    rule_manifest_sha256: str,
) -> dict[str, str]:
    """Return the exact fields which define an immutable scanner cache entry."""

    return {
        "commit_sha": _require_sha(commit_sha, length=40, field="commit_sha"),
        "tree_sha": _require_sha(tree_sha, length=40, field="tree_sha"),
        "scanner_sha256": _require_sha(
            scanner_sha256, length=64, field="scanner_sha256"
        ),
        "rule_manifest_sha256": _require_sha(
            rule_manifest_sha256, length=64, field="rule_manifest_sha256"
        ),
    }


def cache_key_sha256(
    commit_sha: str,
    tree_sha: str,
    scanner_sha256: str,
    rule_manifest_sha256: str,
) -> str:
    return sha256_bytes(
        canonical_bytes(
            cache_key_material(
                commit_sha, tree_sha, scanner_sha256, rule_manifest_sha256
            )
        )
    )


def make_cache_key(
    commit_sha: str,
    tree_sha: str,
    scanner_sha256: str,
    rule_manifest_sha256: str,
) -> str:
    """Public alias used by workers when naming cache files."""

    return cache_key_sha256(commit_sha, tree_sha, scanner_sha256, rule_manifest_sha256)


def _commit_input(
    commit_sha: str,
    tree_sha: str,
    scanner_sha256: str,
    rule_manifest_sha256: str,
) -> dict[str, Any]:
    material = cache_key_material(
        commit_sha, tree_sha, scanner_sha256, rule_manifest_sha256
    )
    key = cache_key_sha256(**material)
    return {
        **material,
        "cache_key": key,
        "cache_key_material": material,
    }


def _normalize_commits(values: Iterable[Any]) -> list[str]:
    result: list[str] = []
    for value in values:
        rendered = str(value).strip()
        if not rendered:
            continue
        result.append(_require_sha(rendered, length=40, field="commit_sha"))
    if not result:
        raise ValueError("the full-history commit input is empty")
    if len(set(result)) != len(result):
        raise ValueError("the full-history commit input contains duplicate commits")
    return result


def load_commit_input(repo: Path, commits_file: Path | None, revision: str = "HEAD") -> list[str]:
    """Load an explicit commit list or enumerate the entire reachable history."""

    if commits_file is not None:
        payload = commits_file.read_text(encoding="utf-8")
        try:
            parsed = json.loads(payload)
        except json.JSONDecodeError:
            values = [line.strip() for line in payload.splitlines() if line.strip()]
        else:
            if isinstance(parsed, list):
                values = parsed
            elif isinstance(parsed, dict):
                values = None
                for key in ("commits", "commit_shas", "history", "commit_inventory"):
                    if isinstance(parsed.get(key), list):
                        values = parsed[key]
                        break
                if values is None:
                    raise ValueError("commits file object lacks a commit list")
            else:
                raise ValueError("commits file must be a list, object, or SHA-per-line text")
        return _normalize_commits(values)

    output = _git(repo, "rev-list", "--reverse", "--topo-order", revision)
    return _normalize_commits(output.splitlines())


def build_manifest(
    repo: Path,
    commits: Sequence[str],
    scanner_path: Path,
    rule_manifest_path: Path,
    *,
    shard_size: int = 50,
    revision: str = "HEAD",
) -> dict[str, Any]:
    """Build a deterministic plan without writing any repository files."""

    if isinstance(shard_size, bool) or not isinstance(shard_size, int) or shard_size <= 0:
        raise ValueError("shard_size must be a positive integer")
    normalized_commits = _normalize_commits(commits)
    scanner_sha = sha256_file(scanner_path)
    rule_sha = sha256_file(rule_manifest_path)
    head_sha = _require_sha(_git(repo, "rev-parse", revision), length=40, field="head_sha")
    commit_rows = [
        _commit_input(commit, commit_tree_sha(repo, commit), scanner_sha, rule_sha)
        for commit in normalized_commits
    ]
    shards: list[dict[str, Any]] = []
    for offset in range(0, len(commit_rows), shard_size):
        rows = commit_rows[offset : offset + shard_size]
        shard_index = len(shards) + 1
        commit_values = [row["commit_sha"] for row in rows]
        keys = [row["cache_key"] for row in rows]
        shards.append(
            {
                "shard_id": f"shard-{shard_index:04d}",
                "commit_start": commit_values[0],
                "commit_end": commit_values[-1],
                "commit_count": len(commit_values),
                "commits": commit_values,
                "commit_rows": rows,
                "commit_set_sha256": line_set_sha256(commit_values),
                "cache_key_set_sha256": line_set_sha256(keys),
                "scanner_sha256": scanner_sha,
                "rule_manifest_sha256": rule_sha,
                "result_sha256": "",
                "failure_fingerprints": [],
                "failure_fingerprint_set_sha256": line_set_sha256(()),
                "completed": False,
            }
        )
    return {
        "schema_version": SCHEMA_VERSION,
        "manifest_kind": MANIFEST_KIND,
        "revision": revision,
        "head_sha": head_sha,
        "scanner_path": scanner_path.as_posix(),
        "scanner_sha256": scanner_sha,
        "rule_manifest_path": rule_manifest_path.as_posix(),
        "rule_manifest_sha256": rule_sha,
        "shard_size": shard_size,
        "full_history": True,
        "commit_count": len(commit_rows),
        "commits": normalized_commits,
        "commit_set_sha256": line_set_sha256(normalized_commits),
        "planned_shard_count": len(shards),
        "completed_shard_count": 0,
        "failure_fingerprints": [],
        "failure_fingerprint_set_sha256": line_set_sha256(()),
        "shards": shards,
        "status": "PLANNED",
    }


def write_manifest(path: Path, manifest: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_bytes(dict(manifest)))


def attach_result(
    manifest: Mapping[str, Any], shard_id: str, result: Mapping[str, Any], *, completed: bool = True
) -> dict[str, Any]:
    """Return a copy of a plan with one canonical inline shard result attached."""

    output = json.loads(json.dumps(manifest))
    matches = [shard for shard in output.get("shards", []) if shard.get("shard_id") == shard_id]
    if len(matches) != 1:
        raise ValueError(f"unknown or duplicate shard_id: {shard_id}")
    shard = matches[0]
    payload = dict(result)
    fingerprints = _fingerprints_from_result(payload)
    shard["result"] = payload
    shard["result_sha256"] = sha256_bytes(canonical_bytes(payload))
    shard["failure_fingerprints"] = sorted(set(fingerprints))
    shard["failure_fingerprint_set_sha256"] = line_set_sha256(fingerprints)
    shard["completed"] = completed
    output["completed_shard_count"] = sum(item.get("completed") is True for item in output["shards"])
    all_fingerprints = [
        fp
        for item in output["shards"]
        for fp in item.get("failure_fingerprints", [])
    ]
    output["failure_fingerprints"] = sorted(set(all_fingerprints))
    output["failure_fingerprint_set_sha256"] = line_set_sha256(all_fingerprints)
    output["status"] = "COMPLETE" if output["completed_shard_count"] == output["planned_shard_count"] else "IN_PROGRESS"
    return output


def _fingerprints_from_result(result: Any) -> list[str]:
    if isinstance(result, Mapping):
        direct = result.get("failure_fingerprints")
        if isinstance(direct, list):
            return [str(value) for value in direct]
        direct = result.get("failures")
        if isinstance(direct, list):
            return [
                str(item.get("failure_fingerprint"))
                for item in direct
                if isinstance(item, Mapping) and isinstance(item.get("failure_fingerprint"), str)
            ]
    if isinstance(result, list):
        return [
            str(item.get("failure_fingerprint"))
            for item in result
            if isinstance(item, Mapping) and isinstance(item.get("failure_fingerprint"), str)
        ]
    return []


def _load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"unable to load JSON {path}: {exc}") from exc


def _result_for_shard(shard: Mapping[str, Any], cache_dir: Path | None) -> tuple[Any | None, str]:
    inline = shard.get("result", shard.get("result_payload"))
    if inline is not None:
        return inline, "inline"
    if cache_dir is None:
        return None, "missing"
    candidates: list[Path] = []
    result_path = shard.get("result_path")
    if isinstance(result_path, str) and result_path:
        candidates.append(cache_dir / result_path)
    key = shard.get("cache_key")
    if isinstance(key, str) and key:
        candidates.append(cache_dir / f"{key}.json")
    candidates.append(cache_dir / f"{shard.get('shard_id', '')}.json")
    for candidate in candidates:
        if candidate.is_file():
            return _load_json(candidate), str(candidate)
    return None, "missing"


def _result_fingerprint_list(result: Any, shard: Mapping[str, Any]) -> list[str]:
    values = _fingerprints_from_result(result)
    if not values:
        direct = shard.get("failure_fingerprints")
        if isinstance(direct, list):
            values = [str(value) for value in direct]
    return values


def _failure_rows(report: Any) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[int] = set()

    def visit(value: Any) -> None:
        if isinstance(value, Mapping):
            identity = id(value)
            if identity in seen:
                return
            seen.add(identity)
            fingerprint = value.get("failure_fingerprint")
            if isinstance(fingerprint, str) and fingerprint:
                rows.append(dict(value))
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    visit(report)
    if isinstance(report, Mapping):
        direct = report.get("failure_fingerprints")
        if isinstance(direct, list):
            known = {row["failure_fingerprint"] for row in rows}
            for value in direct:
                if isinstance(value, str) and value not in known:
                    rows.append({"failure_fingerprint": value})
    return rows


def _report_count(report: Any, keys: Sequence[str], fallback: int) -> int:
    if isinstance(report, Mapping):
        for key in keys:
            value = report.get(key)
            if isinstance(value, int) and not isinstance(value, bool):
                return value
    return fallback


def _report_metadata(report: Any, keys: Sequence[str]) -> Any:
    if not isinstance(report, Mapping):
        return None
    for key in keys:
        if key in report:
            return report[key]
    metadata = report.get("scanner_metadata")
    if isinstance(metadata, Mapping):
        for key in keys:
            if key in metadata:
                return metadata[key]
    return None


def compare_raw_failure_fingerprint_parity(old_report: Any, new_report: Any) -> dict[str, Any]:
    """Compare old single-process and new shard aggregate reports.

    Missing scanner parity metadata is a failure, not an implicit pass.  This
    prevents a result-only comparison from accidentally claiming that scanner
    scope, severity, or AST rules were unchanged.
    """

    old_rows = _failure_rows(old_report)
    new_rows = _failure_rows(new_report)
    old_values = [row["failure_fingerprint"] for row in old_rows]
    new_values = [row["failure_fingerprint"] for row in new_rows]
    old_set, new_set = set(old_values), set(new_values)
    old_hist = {
        row["failure_fingerprint"]
        for row in old_rows
        if any(token in str(row.get(key, "")).upper() for key in ("failure_class", "scope", "category") for token in ("HISTORICAL",))
    }
    new_hist = {
        row["failure_fingerprint"]
        for row in new_rows
        if any(token in str(row.get(key, "")).upper() for key in ("failure_class", "scope", "category") for token in ("HISTORICAL",))
    }
    old_current = old_set - old_hist
    new_current = new_set - new_hist
    old_count = _report_count(old_report, ("failure_count", "raw_failure_count", "total_failure_count"), len(old_values))
    new_count = _report_count(new_report, ("failure_count", "raw_failure_count", "total_failure_count"), len(new_values))
    old_hist_count = _report_count(old_report, ("historical_failure_count", "raw_historical_failure_count", "historical_count"), len(old_hist))
    new_hist_count = _report_count(new_report, ("historical_failure_count", "raw_historical_failure_count", "historical_count"), len(new_hist))
    old_current_count = _report_count(old_report, ("current_delta_failure_count", "raw_current_delta_failure_count", "current_failure_count"), len(old_current))
    new_current_count = _report_count(new_report, ("current_delta_failure_count", "raw_current_delta_failure_count", "current_failure_count"), len(new_current))

    def metadata_equal(keys: Sequence[str]) -> bool:
        left, right = _report_metadata(old_report, keys), _report_metadata(new_report, keys)
        return left is not None and right is not None and canonical_bytes(left) == canonical_bytes(right)

    checks = {
        "RAW_FAILURE_FINGERPRINT_SET_PARITY": old_set == new_set,
        "RAW_FAILURE_COUNT_PARITY": old_count == new_count,
        "RAW_HISTORICAL_FAILURE_COUNT_PARITY": old_hist_count == new_hist_count,
        "RAW_CURRENT_DELTA_FAILURE_COUNT_PARITY": old_current_count == new_current_count,
        "SCANNER_RULE_AST_PARITY": metadata_equal(("scanner_rule_ast_sha256", "scanner_rule_ast_hash", "rule_ast_sha256")),
        "SCANNER_SCOPE_PARITY": metadata_equal(("scanner_scope_sha256", "scanner_scope_hash", "scope_sha256")),
        "SCANNER_SEVERITY_PARITY": metadata_equal(("scanner_severity_sha256", "scanner_severity_hash", "severity_sha256")),
    }
    return {
        "status": "PASS" if all(checks.values()) else "FAIL",
        **checks,
        "old_failure_count": old_count,
        "new_failure_count": new_count,
        "old_historical_failure_count": old_hist_count,
        "new_historical_failure_count": new_hist_count,
        "old_current_delta_failure_count": old_current_count,
        "new_current_delta_failure_count": new_current_count,
        "old_failure_fingerprints": sorted(old_set),
        "new_failure_fingerprints": sorted(new_set),
        "missing_failure_fingerprints": sorted(old_set - new_set),
        "extra_failure_fingerprints": sorted(new_set - old_set),
    }


def verify_manifest(
    manifest: Mapping[str, Any] | Path,
    *,
    repo: Path | None = None,
    cache_dir: Path | None = None,
    old_raw: Path | None = None,
    new_raw: Path | None = None,
) -> dict[str, Any]:
    """Verify shard completeness, cache bindings, aggregate coverage, and parity."""

    document = _load_json(manifest) if isinstance(manifest, Path) else dict(manifest)
    findings: list[str] = []
    checks: dict[str, bool] = {}
    if document.get("schema_version") != SCHEMA_VERSION:
        findings.append("MANIFEST_SCHEMA_INVALID")
    if document.get("manifest_kind") != MANIFEST_KIND:
        findings.append("MANIFEST_KIND_INVALID")
    manifest_status = document.get("status")
    if isinstance(manifest_status, str) and manifest_status.upper() in {
        "FAIL", "FAILED", "ERROR", "CANCELLED", "TIMEOUT"
    }:
        findings.append(f"MANIFEST_EXPLICIT_FAILURE:{manifest_status}")
    try:
        scanner_sha = _require_sha(document.get("scanner_sha256"), length=64, field="scanner_sha256")
        rule_sha = _require_sha(document.get("rule_manifest_sha256"), length=64, field="rule_manifest_sha256")
    except ValueError:
        scanner_sha = rule_sha = ""
        findings.append("MANIFEST_SCANNER_OR_RULE_HASH_INVALID")
    if repo is not None:
        for path_field, digest, finding in (
            ("scanner_path", scanner_sha, "LIVE_SCANNER_HASH_MISMATCH"),
            ("rule_manifest_path", rule_sha, "LIVE_RULE_MANIFEST_HASH_MISMATCH"),
        ):
            value = document.get(path_field)
            if not isinstance(value, str) or not value:
                findings.append(f"{path_field.upper()}_MISSING")
                continue
            live_path = _resolve_repo_path(repo, value)
            if not live_path.is_file() or sha256_file(live_path) != digest:
                findings.append(finding)
    expected_commits = document.get("commits")
    if not isinstance(expected_commits, list):
        expected_commits = []
        findings.append("MANIFEST_COMMIT_LIST_MISSING")
    try:
        expected_commits = _normalize_commits(expected_commits)
    except ValueError:
        expected_commits = []
        findings.append("MANIFEST_COMMIT_LIST_INVALID")
    if document.get("commit_set_sha256") != line_set_sha256(expected_commits):
        findings.append("MANIFEST_COMMIT_SET_HASH_MISMATCH")
    shards = document.get("shards")
    if not isinstance(shards, list):
        shards = []
        findings.append("MANIFEST_SHARDS_MISSING")
    try:
        planned = _strict_int(document.get("planned_shard_count"), "planned_shard_count")
    except ValueError:
        planned = -1
        findings.append("PLANNED_SHARD_COUNT_INVALID")
    if planned != len(shards):
        findings.append("PLANNED_SHARD_COUNT_MISMATCH")
    actual_completed = sum(shard.get("completed") is True for shard in shards if isinstance(shard, Mapping))
    if document.get("completed_shard_count") != actual_completed:
        findings.append("COMPLETED_SHARD_COUNT_MISMATCH")
    if actual_completed != planned:
        findings.append("INCOMPLETE_SHARD_COUNT")

    observed_commits: list[str] = []
    observed_fingerprints: list[str] = []
    seen_shard_ids: set[str] = set()
    for shard in shards:
        if not isinstance(shard, Mapping):
            findings.append("SHARD_ROW_INVALID")
            continue
        shard_id = shard.get("shard_id")
        if not isinstance(shard_id, str) or not shard_id or shard_id in seen_shard_ids:
            findings.append("SHARD_ID_DUPLICATE_OR_INVALID")
        else:
            seen_shard_ids.add(shard_id)
        try:
            shard_scanner = _require_sha(shard.get("scanner_sha256"), length=64, field="shard.scanner_sha256")
            shard_rule = _require_sha(shard.get("rule_manifest_sha256"), length=64, field="shard.rule_manifest_sha256")
            if shard_scanner != scanner_sha or shard_rule != rule_sha:
                findings.append(f"SHARD_SCANNER_RULE_DRIFT:{shard_id}")
        except ValueError:
            findings.append(f"SHARD_SCANNER_RULE_INVALID:{shard_id}")
        values = shard.get("commits")
        if not isinstance(values, list):
            values = []
            findings.append(f"SHARD_COMMIT_LIST_MISSING:{shard_id}")
        try:
            normalized_values = [_require_sha(v, length=40, field="shard.commit") for v in values]
        except ValueError:
            normalized_values = []
            findings.append(f"SHARD_COMMIT_INVALID:{shard_id}")
        if len(normalized_values) != len(set(normalized_values)):
            findings.append(f"SHARD_DUPLICATE_COMMIT:{shard_id}")
        if shard.get("commit_count") != len(normalized_values):
            findings.append(f"SHARD_COMMIT_COUNT_MISMATCH:{shard_id}")
        if normalized_values:
            if shard.get("commit_start") != normalized_values[0]:
                findings.append(f"SHARD_COMMIT_START_MISMATCH:{shard_id}")
            if shard.get("commit_end") != normalized_values[-1]:
                findings.append(f"SHARD_COMMIT_END_MISMATCH:{shard_id}")
        observed_commits.extend(normalized_values)
        if shard.get("commit_set_sha256") != line_set_sha256(normalized_values):
            findings.append(f"SHARD_COMMIT_SET_HASH_MISMATCH:{shard_id}")
        rows = shard.get("commit_rows")
        if not isinstance(rows, list) or len(rows) != len(normalized_values):
            findings.append(f"SHARD_COMMIT_ROWS_MISSING:{shard_id}")
            rows = []
        row_by_commit = {}
        for row in rows:
            if not isinstance(row, Mapping):
                findings.append(f"SHARD_COMMIT_ROW_INVALID:{shard_id}")
                continue
            commit = row.get("commit_sha")
            row_by_commit[commit] = row
            try:
                tree = _require_sha(row.get("tree_sha"), length=40, field="tree_sha")
                key = cache_key_sha256(commit, tree, scanner_sha, rule_sha)
                if row.get("cache_key") != key or row.get("cache_key_material") != cache_key_material(commit, tree, scanner_sha, rule_sha):
                    findings.append(f"CACHE_KEY_BINDING_MISMATCH:{shard_id}:{commit}")
            except ValueError:
                findings.append(f"CACHE_KEY_INPUT_INVALID:{shard_id}:{commit}")
            if repo is not None:
                try:
                    live_tree = commit_tree_sha(repo, commit)
                    if live_tree != tree:
                        findings.append(f"COMMIT_TREE_DRIFT:{commit}")
                except ValueError:
                    findings.append(f"COMMIT_NOT_IN_REPOSITORY:{commit}")
        if set(row_by_commit) != set(normalized_values):
            findings.append(f"SHARD_COMMIT_ROW_COVERAGE_MISMATCH:{shard_id}")
        expected_keys = [row.get("cache_key") for row in rows if isinstance(row, Mapping)]
        if shard.get("cache_key_set_sha256") != line_set_sha256(expected_keys):
            findings.append(f"SHARD_CACHE_KEY_SET_HASH_MISMATCH:{shard_id}")

        result, result_source = _result_for_shard(shard, cache_dir)
        completed = shard.get("completed")
        if completed is not True:
            findings.append(f"SHARD_NOT_COMPLETED:{shard_id}")
        status = shard.get("status")
        if isinstance(status, str) and status.upper() in {"FAIL", "FAILED", "ERROR", "CANCELLED", "TIMEOUT"}:
            findings.append(f"SHARD_EXPLICIT_FAILURE:{shard_id}:{status}")
        if completed is True:
            if result is None:
                findings.append(f"SHARD_RESULT_MISSING:{shard_id}")
            else:
                if isinstance(result, Mapping):
                    result_status = result.get("status")
                    if isinstance(result_status, str) and result_status.upper() in {
                        "FAIL", "FAILED", "ERROR", "CANCELLED", "TIMEOUT"
                    }:
                        findings.append(f"SHARD_RESULT_EXPLICIT_FAILURE:{shard_id}:{result_status}")
                expected_result = shard.get("result_sha256")
                actual_result = sha256_bytes(canonical_bytes(result))
                if not isinstance(expected_result, str) or not HEX64.fullmatch(expected_result) or expected_result != actual_result:
                    findings.append(f"SHARD_RESULT_HASH_MISMATCH:{shard_id}")
                fps = _result_fingerprint_list(result, shard)
                if len(fps) != len(set(fps)):
                    findings.append(f"SHARD_DUPLICATE_FAILURE_FINGERPRINT:{shard_id}")
                if shard.get("failure_fingerprints") != sorted(set(fps)):
                    findings.append(f"SHARD_FAILURE_FINGERPRINT_LIST_MISMATCH:{shard_id}")
                if shard.get("failure_fingerprint_set_sha256") != line_set_sha256(fps):
                    findings.append(f"SHARD_FAILURE_FINGERPRINT_HASH_MISMATCH:{shard_id}")
                observed_fingerprints.extend(fps)
        elif result_source != "missing":
            findings.append(f"INCOMPLETE_SHARD_RESULT_PRESENT:{shard_id}")

    expected_set, observed_set = set(expected_commits), set(observed_commits)
    if len(observed_commits) != len(observed_set):
        findings.append("DUPLICATE_COMMIT_ACROSS_SHARDS")
    if observed_set != expected_set:
        findings.append("MISSING_OR_EXTRA_COMMIT_ACROSS_SHARDS")
    if document.get("commit_count") != len(expected_commits):
        findings.append("MANIFEST_COMMIT_COUNT_MISMATCH")
    if len(observed_fingerprints) != len(set(observed_fingerprints)):
        findings.append("DUPLICATE_FAILURE_FINGERPRINT_ACROSS_SHARDS")
    root_fps = document.get("failure_fingerprints")
    if isinstance(root_fps, list):
        root_fps = [str(value) for value in root_fps]
        if len(root_fps) != len(set(root_fps)):
            findings.append("DUPLICATE_ROOT_FAILURE_FINGERPRINT")
        if set(root_fps) != set(observed_fingerprints):
            findings.append("MISSING_OR_EXTRA_FAILURE_FINGERPRINT_ACROSS_SHARDS")
        if document.get("failure_fingerprint_set_sha256") != line_set_sha256(root_fps):
            findings.append("ROOT_FAILURE_FINGERPRINT_HASH_MISMATCH")
    elif actual_completed == planned:
        findings.append("ROOT_FAILURE_FINGERPRINT_LIST_MISSING")
    parity: dict[str, Any] = {"status": "NOT_REQUESTED"}
    if old_raw is not None or new_raw is not None:
        if old_raw is None or new_raw is None:
            findings.append("RAW_PARITY_REQUIRES_TWO_REPORTS")
        else:
            parity = compare_raw_failure_fingerprint_parity(_load_json(old_raw), _load_json(new_raw))
            if parity.get("status") != "PASS":
                findings.append("RAW_FAILURE_PARITY_FAILED")
    checks.update(
        {
            "planned_shard_count_matches": planned == len(shards),
            "completed_shard_count_matches": actual_completed == planned,
            "commit_coverage_exact": observed_set == expected_set and len(observed_commits) == len(observed_set),
            "failure_fingerprint_coverage_exact": not any("FAILURE_FINGERPRINT" in item for item in findings),
            "all_cache_keys_bound": not any("CACHE_KEY" in item for item in findings),
            "raw_failure_fingerprint_set_parity": parity.get("RAW_FAILURE_FINGERPRINT_SET_PARITY") if parity.get("status") != "NOT_REQUESTED" else None,
        }
    )
    return {
        "schema_version": "space_syndicate.v076.full_history_scan_cache_verification.v1",
        "status": "PASS" if not findings else "FAIL",
        "findings": sorted(set(findings)),
        "planned_shard_count": planned,
        "completed_shard_count": actual_completed,
        "commit_count": len(expected_commits),
        "observed_commit_count": len(observed_commits),
        "failure_fingerprint_count": len(set(observed_fingerprints)),
        "checks": checks,
        "parity": parity,
    }


def _plan_cli(args: argparse.Namespace) -> int:
    repo = Path(args.repo).resolve()
    scanner = _resolve_repo_path(repo, args.scanner)
    rule_manifest = _resolve_repo_path(repo, args.rule_manifest)
    commits_file = Path(args.commits_file).resolve() if args.commits_file else None
    manifest = build_manifest(
        repo,
        load_commit_input(repo, commits_file, args.revision),
        scanner,
        rule_manifest,
        shard_size=args.shard_size,
        revision=args.revision,
    )
    write_manifest(Path(args.output).resolve(), manifest)
    print(json.dumps({"status": "PASS", "manifest": str(Path(args.output).resolve()), "planned_shard_count": manifest["planned_shard_count"], "commit_count": manifest["commit_count"]}, sort_keys=True))
    return 0


def _verify_cli(args: argparse.Namespace) -> int:
    result = verify_manifest(
        Path(args.manifest).resolve(),
        repo=Path(args.repo).resolve() if args.repo else None,
        cache_dir=Path(args.cache_dir).resolve() if args.cache_dir else None,
        old_raw=Path(args.old_raw).resolve() if args.old_raw else None,
        new_raw=Path(args.new_raw).resolve() if args.new_raw else None,
    )
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    plan = subparsers.add_parser("plan", help="enumerate all history commits into immutable shards")
    plan.add_argument("--repo", default=".")
    plan.add_argument("--revision", default="HEAD")
    plan.add_argument("--commits-file")
    plan.add_argument("--scanner", required=True)
    plan.add_argument("--rule-manifest", required=True)
    plan.add_argument("--shard-size", type=int, default=50)
    plan.add_argument("--output", required=True)
    plan.set_defaults(handler=_plan_cli)
    verify = subparsers.add_parser("verify", help="fail-closed shard/cache and raw parity verification")
    verify.add_argument("--manifest", required=True)
    verify.add_argument("--repo")
    verify.add_argument("--cache-dir")
    verify.add_argument("--old-raw")
    verify.add_argument("--new-raw")
    verify.set_defaults(handler=_verify_cli)
    parity = subparsers.add_parser("parity", help="compare two raw reports only")
    parity.add_argument("--old-raw", required=True)
    parity.add_argument("--new-raw", required=True)
    parity.set_defaults(handler=lambda args: _parity_cli(args))
    return parser


def _parity_cli(args: argparse.Namespace) -> int:
    result = compare_raw_failure_fingerprint_parity(_load_json(Path(args.old_raw)), _load_json(Path(args.new_raw)))
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return int(args.handler(args))
    except (OSError, ValueError) as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}, ensure_ascii=False, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
