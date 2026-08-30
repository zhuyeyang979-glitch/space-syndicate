#!/usr/bin/env python3
"""Fail-closed validator for the append-only HDM successor layer.

The frozen predecessor ledger contains 86 corrections created under its own
Raw authority epoch.  This successor never rewrites that ledger or assumes a
single Raw SHA for it: every predecessor correction must retain the exact Raw
``(path, sha256, head_sha, tree_sha)`` tuple recorded when it entered the
ledger.  A new successor correction may bind only one explicitly supplied
fresh Raw tuple.  There is no wildcard, prefix, or future auto-match mode.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, Iterable

SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.historical_delta_metadata_successor_schema.v1"
MANIFEST_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.historical_delta_metadata_successor_manifest.v1"
RECORD_SCHEMA_VERSION = "space_syndicate.v076.reuse_exact_failure_correction.v2.historical_delta_metadata_successor_record.v1"
MANIFEST_KIND = "HISTORICAL_DELTA_METADATA_SUCCESSOR_MANIFEST"
RECORD_KIND = "HISTORICAL_DELTA_METADATA_SUCCESSOR_RECORD"
SCHEMA_PATH = "docs/architecture/reuse_corrections/v2/schema_historical_delta_metadata_successor_20260830.json"
LEDGER_PATH = "docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json"
REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
SUCCESSOR_ROOT = "docs/architecture/reuse_corrections/v2/historical_delta_metadata_successor/"
RECORD_ROOT = SUCCESSOR_ROOT + "records/"
AUTHORIZATION_ID = "USER_AUTHORIZATION_V076_CURRENT_SUBJECT_CONVERGENCE_AND_COMMERCIAL_RESUME_20260830"
AUTHORIZATION_BASE_HEAD = "d701a81dce693b584d52fbfca3e0e78b521ad775"
CHANGE_PARENT = "d4720d34b5dd99541c20907cb5231b1a780d1cf7"
CHANGE_COMMIT = "a483684e2309a38c92c913584b097bda5c7cd6c7"
TARGET_RULE = "NEW_COMPONENT_CANNOT_CLAIM_INHERITED"
TARGET_TRANSITION = f"{CHANGE_PARENT[:12]}->{CHANGE_COMMIT[:12]}"
EXPECTED_SUCCESSOR_FAILURE_COUNT = 25
SELECTOR_POLICY = {
    "match_mode": "EXACT_FAILURE_FINGERPRINTS_ONLY",
    "wildcard_allowed": False,
    "regex_allowed": False,
    "path_prefix_allowed": False,
    "branch_selector_allowed": False,
    "date_selector_allowed": False,
    "future_failure_auto_match": False,
}
FUTURE_POLICY = {"automatic_match": False, "new_failure_requires_new_record": True}
TRANSITION_CLASS = "HISTORICAL_COMPONENT_IDENTITY_METADATA_BACKFILL"


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def payload_sha256(document: dict[str, Any], field: str = "record_payload_sha256") -> str:
    payload = dict(document)
    payload.pop(field, None)
    return sha256_bytes(canonical_bytes(payload))


def line_set_sha(values: Iterable[str]) -> str:
    rows = sorted(set(str(value) for value in values))
    return sha256_bytes(("\n".join(rows) + "\n" if rows else "").encode())


def failure_fingerprint(raw_failure: str, rule_id: str) -> str:
    return "V2F-" + sha256_bytes(f"V076_RAW_FAILURE_V2\nHISTORICAL\n{rule_id}\n{raw_failure}\n".encode())


def strict_json_bytes(raw: bytes) -> Any:
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in items:
            if key in result:
                raise ValueError(f"DUPLICATE_JSON_KEY:{key}")
            result[key] = value
        return result
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=pairs, parse_constant=lambda value: (_ for _ in ()).throw(ValueError(f"NONFINITE_JSON:{value}")))


def strict_json_file(path: Path) -> Any:
    return strict_json_bytes(path.read_bytes())


def _git(root: Path, *args: str, binary: bool = False) -> str | bytes:
    result = subprocess.run(["git", *args], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, text=not binary)
    if result.returncode:
        raise ValueError((result.stderr.decode(errors="replace") if binary else result.stderr).strip() or "GIT_COMMAND_FAILED")
    return result.stdout


def _blob(root: Path, commit: str, path: str) -> bytes | None:
    result = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    return result.stdout if result.returncode == 0 else None


def _sha(value: Any) -> bool:
    return isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{64}", value))


def _oid(value: Any) -> bool:
    return isinstance(value, str) and bool(re.fullmatch(r"[0-9a-f]{40}", value))


def _raw_tuple_shape(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["HDMS_RAW_TUPLE_NOT_OBJECT"]
    required = {"path", "sha256", "head_sha", "tree_sha"}
    failures = []
    if set(value) - required - {"correction_paths"} or not required.issubset(value):
        failures.append("HDMS_RAW_TUPLE_FIELD_SET_INVALID")
    if not isinstance(value.get("path"), str) or not value.get("path") or value.get("path", "").startswith("/"):
        failures.append("HDMS_RAW_TUPLE_PATH_INVALID")
    if not _sha(value.get("sha256")):
        failures.append("HDMS_RAW_TUPLE_SHA_INVALID")
    if not _oid(value.get("head_sha")) or not _oid(value.get("tree_sha")):
        failures.append("HDMS_RAW_TUPLE_OID_INVALID")
    if "correction_paths" in value and (not isinstance(value.get("correction_paths"), list) or any(not isinstance(path, str) for path in value.get("correction_paths", []))):
        failures.append("HDMS_RAW_TUPLE_CORRECTION_PATHS_INVALID")
    return failures


def _load_committed_json(root: Path, commit: str, path: str) -> tuple[Any, bytes]:
    raw = _blob(root, commit, path)
    if raw is None:
        raise ValueError(f"HDMS_COMMITTED_BLOB_MISSING:{commit}:{path}")
    return strict_json_bytes(raw), raw


def _predecessor_raw_authorities(ledger: dict[str, Any], root: Path | None = None, predecessor_head: str | None = None) -> list[dict[str, Any]]:
    """Derive immutable Raw tuples from each correction's activation record.

    The ledger-level tuple is only a legacy convenience.  A successor must
    preserve mixed epochs, so when Git context is supplied we read every
    committed correction record and group by its own raw tuple.
    """
    rows: dict[tuple[str, str, str, str], dict[str, Any]] = {}
    for binding in ledger.get("correction_record_bindings", []):
        if not isinstance(binding, dict):
            continue
        record: dict[str, Any] = {}
        if root is not None and predecessor_head and isinstance(binding.get("path"), str):
            raw = _blob(root, predecessor_head, binding["path"])
            if raw is not None:
                try:
                    loaded = strict_json_bytes(raw)
                    if isinstance(loaded, dict):
                        record = loaded
                except Exception:
                    record = {}
        record_head = str(record.get("raw_report_head_sha", ledger.get("raw_report_head_sha", "")))
        record_tree = str(record.get("raw_report_tree_sha", ""))
        if not record_tree and root is not None and _oid(record_head):
            try:
                record_tree = str(_git(root, "rev-parse", f"{record_head}^{{tree}}")).strip()
            except ValueError:
                record_tree = ""
        key = (
            str(record.get("raw_report_path", ledger.get("raw_report_path", ""))),
            str(record.get("raw_report_sha256", ledger.get("raw_report_sha256", ""))),
            record_head,
            record_tree,
        )
        rows.setdefault(key, {"path": key[0], "sha256": key[1], "head_sha": key[2], "tree_sha": key[3], "correction_paths": []})["correction_paths"].append(binding.get("path"))
    return list(rows.values())


def _transition_failures(root: Path, manifest: dict[str, Any], evaluated_head: str) -> list[str]:
    failures: list[str] = []
    transition = manifest.get("authority_transition")
    if not isinstance(transition, dict):
        return ["HDMS_TRANSITION_NOT_OBJECT"]
    required = {"parent_sha", "commit_sha", "parent_tree_sha", "commit_tree_sha", "path", "before_blob_sha256", "after_blob_sha256", "diff_sha256"}
    if set(transition) != required:
        failures.append("HDMS_TRANSITION_FIELD_SET_INVALID")
        return failures
    if transition["parent_sha"] != CHANGE_PARENT or transition["commit_sha"] != CHANGE_COMMIT:
        failures.append("HDMS_TRANSITION_IDENTITY_INVALID")
    try:
        if str(_git(root, "rev-parse", f"{CHANGE_COMMIT}^{{commit}}")).strip() != CHANGE_PARENT:
            failures.append("HDMS_TRANSITION_PARENT_INVALID")
        changed = str(_git(root, "diff", "--name-only", CHANGE_PARENT, CHANGE_COMMIT)).splitlines()
        if changed != [REGISTRY_PATH]:
            failures.append("HDMS_TRANSITION_PATH_SET_INVALID")
        for key, commit in (("parent_tree_sha", CHANGE_PARENT), ("commit_tree_sha", CHANGE_COMMIT)):
            if str(_git(root, "rev-parse", f"{commit}^{{tree}}")).strip() != transition[key]:
                failures.append("HDMS_TRANSITION_TREE_INVALID")
        before = _blob(root, CHANGE_PARENT, REGISTRY_PATH); after = _blob(root, CHANGE_COMMIT, REGISTRY_PATH)
        if before is None or after is None:
            failures.append("HDMS_TRANSITION_REGISTRY_BLOB_MISSING")
        else:
            if sha256_bytes(before) != transition["before_blob_sha256"] or sha256_bytes(after) != transition["after_blob_sha256"]:
                failures.append("HDMS_TRANSITION_BLOB_HASH_INVALID")
            diff = _git(root, "diff", "--binary", "--no-ext-diff", CHANGE_PARENT, CHANGE_COMMIT, "--", REGISTRY_PATH, binary=True)
            if sha256_bytes(diff) != transition["diff_sha256"]:
                failures.append("HDMS_TRANSITION_DIFF_HASH_INVALID")
    except ValueError as error:
        failures.append(str(error))
    return failures


def validate_manifest(root: Path, manifest_path: Path, *, evaluated_head: str = "HEAD") -> dict[str, Any]:
    failures: list[str] = []
    try:
        manifest = strict_json_file(manifest_path)
    except Exception as error:
        return {"status": "FAIL", "failures": [str(error)], "trusted_by_fingerprint": {}}
    if not isinstance(manifest, dict):
        return {"status": "FAIL", "failures": ["HDMS_MANIFEST_NOT_OBJECT"], "trusted_by_fingerprint": {}}
    required = {"schema_version", "manifest_kind", "manifest_id", "authorization_id", "authorization_base_head_sha", "predecessor_ledger_path", "predecessor_ledger_head_sha", "predecessor_ledger_sha256", "predecessor_record_count", "predecessor_failure_count", "predecessor_failure_fingerprint_set_sha256", "predecessor_raw_authorities", "new_raw_authority", "authority_transition", "selector_policy", "future_failure_policy", "successor_record_count", "successor_failure_count", "successor_failure_fingerprints", "successor_failure_fingerprint_set_sha256", "record_chain_start_sha256", "record_chain_terminal_sha256", "wildcard_count", "record_bindings", "created_at", "creator"}
    if set(manifest) != required:
        failures.append("HDMS_MANIFEST_FIELD_SET_INVALID")
    if manifest.get("schema_version") != MANIFEST_SCHEMA_VERSION or manifest.get("manifest_kind") != MANIFEST_KIND:
        failures.append("HDMS_MANIFEST_KIND_INVALID")
    if manifest.get("authorization_id") != AUTHORIZATION_ID or manifest.get("authorization_base_head_sha") != AUTHORIZATION_BASE_HEAD:
        failures.append("HDMS_AUTHORIZATION_INVALID")
    if manifest.get("predecessor_ledger_path") != LEDGER_PATH or not _oid(manifest.get("predecessor_ledger_head_sha")) or not _sha(manifest.get("predecessor_ledger_sha256")):
        failures.append("HDMS_PREDECESSOR_BINDING_INVALID")
    if manifest.get("selector_policy") != SELECTOR_POLICY or manifest.get("future_failure_policy") != FUTURE_POLICY or manifest.get("wildcard_count") != 0:
        failures.append("HDMS_POLICY_INVALID")
    try:
        ledger, ledger_raw = _load_committed_json(root, manifest.get("predecessor_ledger_head_sha", ""), LEDGER_PATH)
        if sha256_bytes(ledger_raw) != manifest.get("predecessor_ledger_sha256"):
            failures.append("HDMS_PREDECESSOR_LEDGER_HASH_INVALID")
    except ValueError as error:
        ledger = {}; failures.append(str(error))
    if isinstance(ledger, dict):
        if manifest.get("predecessor_record_count") != ledger.get("correction_record_count") or manifest.get("predecessor_failure_count") != ledger.get("corrected_failure_count"):
            failures.append("HDMS_PREDECESSOR_COUNT_INVALID")
        if manifest.get("predecessor_failure_fingerprint_set_sha256") != ledger.get("failure_fingerprint_set_sha256"):
            failures.append("HDMS_PREDECESSOR_FINGERPRINT_SET_INVALID")
        expected_raw = _predecessor_raw_authorities(ledger, root, manifest.get("predecessor_ledger_head_sha"))
        listed_raw = manifest.get("predecessor_raw_authorities")
        if not isinstance(listed_raw, list) or len(listed_raw) != len(expected_raw):
            failures.append("HDMS_PREDECESSOR_RAW_AUTHORITY_COUNT_INVALID")
        else:
            for item in listed_raw:
                failures.extend(_raw_tuple_shape(item))
            expected_keys = {(x["path"], x["sha256"], x["head_sha"], x["tree_sha"]) for x in expected_raw}
            listed_keys = {(x.get("path"), x.get("sha256"), x.get("head_sha"), x.get("tree_sha")) for x in listed_raw if isinstance(x, dict)}
            if expected_keys != listed_keys:
                failures.append("HDMS_PREDECESSOR_RAW_AUTHORITY_PROVENANCE_INVALID")
            expected_by_key = {(x["path"], x["sha256"], x["head_sha"], x["tree_sha"]): sorted(x.get("correction_paths", [])) for x in expected_raw}
            listed_by_key = {(x.get("path"), x.get("sha256"), x.get("head_sha"), x.get("tree_sha")): sorted(x.get("correction_paths", [])) for x in listed_raw if isinstance(x, dict)}
            if expected_by_key != listed_by_key:
                failures.append("HDMS_PREDECESSOR_RAW_AUTHORITY_CORRECTION_MEMBERSHIP_INVALID")
            bindings = ledger.get("correction_record_bindings", [])
            for binding in bindings if isinstance(bindings, list) else []:
                if not isinstance(binding, dict):
                    failures.append("HDMS_PREDECESSOR_CORRECTION_BINDING_INVALID"); continue
                path = binding.get("path"); raw = _blob(root, manifest.get("predecessor_ledger_head_sha", ""), str(path)) if isinstance(path, str) else None
                if raw is None or sha256_bytes(raw) != binding.get("file_sha256"):
                    failures.append("HDMS_PREDECESSOR_CORRECTION_BYTES_INVALID:" + str(path)); continue
                try: record = strict_json_bytes(raw)
                except Exception as error: failures.append(str(error)); continue
                if not isinstance(record, dict):
                    failures.append("HDMS_PREDECESSOR_RECORD_NOT_OBJECT:" + str(path)); continue
                record_head = str(record.get("raw_report_head_sha", ""))
                record_tree = str(record.get("raw_report_tree_sha", ""))
                if not record_tree and _oid(record_head):
                    try: record_tree = str(_git(root, "rev-parse", f"{record_head}^{{tree}}")).strip()
                    except ValueError: record_tree = ""
                record_key = (str(record.get("raw_report_path", "")), str(record.get("raw_report_sha256", "")), record_head, record_tree)
                listed_keys = {(item.get("path"), item.get("sha256"), item.get("head_sha"), item.get("tree_sha")) for item in manifest.get("predecessor_raw_authorities", []) if isinstance(item, dict)}
                if record_key not in listed_keys:
                    failures.append("HDMS_PREDECESSOR_RECORD_RAW_TUPLE_DRIFT:" + str(path))
                else:
                    raw_report = _blob(root, record_head, str(record.get("raw_report_path", "")))
                    if raw_report is None or sha256_bytes(raw_report) != record.get("raw_report_sha256"):
                        failures.append("HDMS_PREDECESSOR_RECORD_RAW_BYTES_INVALID:" + str(path))
                if isinstance(record, dict) and record.get("record_payload_sha256") != binding.get("record_payload_sha256"):
                    failures.append("HDMS_PREDECESSOR_RECORD_PAYLOAD_DRIFT:" + str(path))
    failures.extend(_raw_tuple_shape(manifest.get("new_raw_authority")))
    new_raw = manifest.get("new_raw_authority") if isinstance(manifest.get("new_raw_authority"), dict) else {}
    if isinstance(new_raw, dict):
        local_path = root / str(new_raw.get("path", ""))
        raw = local_path.read_bytes() if local_path.is_file() else _blob(root, str(new_raw.get("head_sha", "")), str(new_raw.get("path", "")))
        if raw is None or sha256_bytes(raw) != new_raw.get("sha256"):
            failures.append("HDMS_NEW_RAW_BYTES_INVALID")
        else:
            try:
                report = strict_json_bytes(raw)
                if report.get("include_worktree") is not False or report.get("evaluated_source") != "COMMITTED_HEAD":
                    failures.append("HDMS_NEW_RAW_NOT_COMMITTED_HEAD")
                fps = [failure_fingerprint(str(item), TARGET_RULE) for item in report.get("failures", []) if TARGET_RULE in str(item) and CHANGE_PARENT[:12] in str(item) and CHANGE_COMMIT[:12] in str(item)]
                if len(fps) != EXPECTED_SUCCESSOR_FAILURE_COUNT or len(set(fps)) != len(fps) or sorted(fps) != manifest.get("successor_failure_fingerprints"):
                    failures.append("HDMS_NEW_RAW_FAILURE_SET_INVALID")
            except Exception as error: failures.append("HDMS_NEW_RAW_JSON_INVALID:" + str(error))
    failures.extend(_transition_failures(root, manifest, evaluated_head))
    trusted: dict[str, Any] = {}
    bindings = manifest.get("record_bindings")
    if not isinstance(bindings, list) or len(bindings) != manifest.get("successor_record_count"):
        failures.append("HDMS_RECORD_BINDING_COUNT_INVALID")
    else:
        previous = manifest.get("record_chain_start_sha256")
        for binding in bindings:
            if not isinstance(binding, dict) or set(binding) != {"path", "record_sha256", "record_payload_sha256", "failure_fingerprints", "previous_correction_payload_sha256"}:
                failures.append("HDMS_RECORD_BINDING_SHAPE_INVALID"); continue
            path = binding.get("path")
            local_path = root / str(path) if isinstance(path, str) else None
            raw = local_path.read_bytes() if local_path is not None and local_path.is_file() else (_blob(root, str(manifest.get("predecessor_ledger_head_sha", "")), str(path)) if isinstance(path, str) else None)
            if raw is None or sha256_bytes(raw) != binding.get("record_sha256"):
                failures.append("HDMS_SUCCESSOR_RECORD_BYTES_INVALID:" + str(path)); continue
            try: record = strict_json_bytes(raw)
            except Exception as error: failures.append(str(error)); continue
            if not isinstance(record, dict) or record.get("schema_version") != RECORD_SCHEMA_VERSION or record.get("record_kind") != RECORD_KIND or record.get("record_payload_sha256") != binding.get("record_payload_sha256") or record.get("previous_correction_payload_sha256") != previous:
                failures.append("HDMS_SUCCESSOR_RECORD_CHAIN_INVALID:" + str(path)); continue
            if record.get("raw_report_sha256") != new_raw.get("sha256") or record.get("raw_report_head_sha") != new_raw.get("head_sha") or record.get("raw_report_tree_sha") != new_raw.get("tree_sha") or record.get("failure_fingerprints") != manifest.get("successor_failure_fingerprints") or record.get("selector_policy") != SELECTOR_POLICY or record.get("future_failure_policy") != FUTURE_POLICY:
                failures.append("HDMS_SUCCESSOR_RECORD_BINDING_INVALID:" + str(path))
            previous = record.get("record_payload_sha256")
            for fp in binding.get("failure_fingerprints", []): trusted[str(fp)] = {"record_path": path, "record_payload_sha256": previous}
        if previous != manifest.get("record_chain_terminal_sha256"):
            failures.append("HDMS_RECORD_CHAIN_TERMINAL_INVALID")
    if manifest.get("successor_failure_fingerprint_set_sha256") != line_set_sha(manifest.get("successor_failure_fingerprints", [])):
        failures.append("HDMS_SUCCESSOR_FINGERPRINT_SET_INVALID")
    return {"status": "PASS" if not failures else "FAIL", "failures": sorted(set(failures)), "trusted_by_fingerprint": trusted if not failures else {}, "predecessor_raw_authority_count": len(manifest.get("predecessor_raw_authorities", [])) if isinstance(manifest.get("predecessor_raw_authorities"), list) else 0, "successor_failure_count": len(manifest.get("successor_failure_fingerprints", [])) if isinstance(manifest.get("successor_failure_fingerprints"), list) else 0}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--evaluated-head", default="HEAD")
    args = parser.parse_args(argv)
    result = validate_manifest(args.project.resolve(), args.manifest.resolve(), evaluated_head=args.evaluated_head)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
