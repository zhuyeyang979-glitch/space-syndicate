#!/usr/bin/env python3
"""Primary-validator-free audit of the HDM mixed-raw successor manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

LEDGER_PATH = "docs/architecture/V076_HISTORICAL_DELTA_METADATA_LEDGER.json"
REGISTRY_PATH = "docs/architecture/V076_HISTORICAL_REUSE_REGISTRY.json"
CHANGE_PARENT = "d4720d34b5dd99541c20907cb5231b1a780d1cf7"
CHANGE_COMMIT = "a483684e2309a38c92c913584b097bda5c7cd6c7"
TARGET_RULE = "NEW_COMPONENT_CANNOT_CLAIM_INHERITED"
EXPECTED_COUNT = 25
SELECTOR = {"match_mode": "EXACT_FAILURE_FINGERPRINTS_ONLY", "wildcard_allowed": False, "regex_allowed": False, "path_prefix_allowed": False, "branch_selector_allowed": False, "date_selector_allowed": False, "future_failure_auto_match": False}
FUTURE = {"automatic_match": False, "new_failure_requires_new_record": True}


def canonical(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def strict(raw: bytes) -> Any:
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in items:
            if key in result:
                raise ValueError("DUPLICATE_JSON_KEY:" + key)
            result[key] = value
        return result
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=pairs, parse_constant=lambda value: (_ for _ in ()).throw(ValueError("NONFINITE_JSON:" + value)))


def blob(root: Path, commit: str, path: str) -> bytes | None:
    result = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    return result.stdout if result.returncode == 0 else None


def fingerprint(value: str) -> str:
    return "V2F-" + sha(f"V076_RAW_FAILURE_V2\nHISTORICAL\n{TARGET_RULE}\n{value}\n".encode())


def tuple_ok(item: Any) -> bool:
    return isinstance(item, dict) and set(item).issubset({"path", "sha256", "head_sha", "tree_sha", "correction_paths"}) and all(isinstance(item.get(k), str) and bool(item.get(k)) for k in ("path", "sha256", "head_sha", "tree_sha")) and bool(re.fullmatch(r"[0-9a-f]{64}", item["sha256"])) and bool(re.fullmatch(r"[0-9a-f]{40}", item["head_sha"])) and bool(re.fullmatch(r"[0-9a-f]{40}", item["tree_sha"]))


def audit(root: Path, manifest_path: Path) -> dict[str, Any]:
    failures: list[str] = []
    try:
        manifest_raw = manifest_path.read_bytes(); manifest = strict(manifest_raw)
    except Exception as error:
        return {"status": "NO_GO", "failures": [str(error)]}
    if not isinstance(manifest, dict):
        return {"status": "NO_GO", "failures": ["HDMS_MANIFEST_NOT_OBJECT"]}
    if manifest.get("predecessor_ledger_path") != LEDGER_PATH or manifest.get("selector_policy") != SELECTOR or manifest.get("future_failure_policy") != FUTURE or manifest.get("wildcard_count") != 0:
        failures.append("HDMS_POLICY_OR_PREDECESSOR_INVALID")
    if not isinstance(manifest.get("predecessor_raw_authorities"), list) or not all(tuple_ok(item) for item in manifest["predecessor_raw_authorities"]):
        failures.append("HDMS_PREDECESSOR_RAW_TUPLES_INVALID")
    if not tuple_ok(manifest.get("new_raw_authority")):
        failures.append("HDMS_NEW_RAW_TUPLE_INVALID")
    else:
        new = manifest["new_raw_authority"]
        raw = blob(root, new["head_sha"], new["path"])
        if raw is None or sha(raw) != new["sha256"]:
            failures.append("HDMS_NEW_RAW_COMMITTED_BYTES_INVALID")
        else:
            try:
                report = strict(raw)
                if report.get("include_worktree") is not False or report.get("evaluated_source") != "COMMITTED_HEAD":
                    failures.append("HDMS_NEW_RAW_NOT_COMMITTED_HEAD")
                actual = sorted(fingerprint(str(value)) for value in report.get("failures", []) if TARGET_RULE in str(value) and CHANGE_PARENT[:12] in str(value) and CHANGE_COMMIT[:12] in str(value))
                if actual != manifest.get("successor_failure_fingerprints") or len(actual) != EXPECTED_COUNT or len(set(actual)) != EXPECTED_COUNT:
                    failures.append("HDMS_NEW_RAW_FAILURE_SET_INVALID")
            except Exception as error:
                failures.append("HDMS_NEW_RAW_JSON_INVALID:" + str(error))
    try:
        predecessor_head = manifest.get("predecessor_ledger_head_sha", "")
        ledger_raw = blob(root, predecessor_head, LEDGER_PATH)
        if ledger_raw is None or sha(ledger_raw) != manifest.get("predecessor_ledger_sha256"):
            failures.append("HDMS_PREDECESSOR_LEDGER_BYTES_INVALID")
        else:
            ledger = strict(ledger_raw)
            if manifest.get("predecessor_failure_count") != ledger.get("corrected_failure_count") or manifest.get("predecessor_failure_fingerprint_set_sha256") != ledger.get("failure_fingerprint_set_sha256"):
                failures.append("HDMS_PREDECESSOR_LEDGER_SUMMARY_INVALID")
            tuples: set[tuple[str, str, str, str]] = set()
            for binding in ledger.get("correction_record_bindings", []):
                path = binding.get("path") if isinstance(binding, dict) else None
                record_raw = blob(root, predecessor_head, str(path)) if isinstance(path, str) else None
                if record_raw is None:
                    failures.append("HDMS_PREDECESSOR_RECORD_MISSING:" + str(path)); continue
                record = strict(record_raw)
                if not isinstance(record, dict):
                    failures.append("HDMS_PREDECESSOR_RECORD_NOT_OBJECT:" + str(path)); continue
                head = str(record.get("raw_report_head_sha", "")); tree = str(record.get("raw_report_tree_sha", ""))
                if not tree and re.fullmatch(r"[0-9a-f]{40}", head):
                    result = subprocess.run(["git", "rev-parse", f"{head}^{{tree}}"], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
                    tree = result.stdout.strip() if result.returncode == 0 else ""
                tuples.add((str(record.get("raw_report_path", "")), str(record.get("raw_report_sha256", "")), head, tree))
            listed = {(item.get("path"), item.get("sha256"), item.get("head_sha"), item.get("tree_sha")) for item in manifest.get("predecessor_raw_authorities", []) if isinstance(item, dict)}
            if tuples != listed:
                failures.append("HDMS_PREDECESSOR_RAW_PROVENANCE_SET_INVALID")
    except Exception as error:
        failures.append("HDMS_PREDECESSOR_AUDIT_ERROR:" + str(error))
    return {"status": "PASS" if not failures else "NO_GO", "failures": sorted(set(failures)), "predecessor_raw_authority_count": len(manifest.get("predecessor_raw_authorities", [])) if isinstance(manifest.get("predecessor_raw_authorities"), list) else 0, "successor_failure_count": len(manifest.get("successor_failure_fingerprints", [])) if isinstance(manifest.get("successor_failure_fingerprints"), list) else 0}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args(argv)
    result = audit(args.project.resolve(), args.manifest.resolve())
    print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
