#!/usr/bin/env python3
"""Focused contract tests for :mod:`v076_full_history_scan_cache`.

The fixtures are disposable and synthetic.  They exercise the fail-closed
properties of the ordinary tooling without touching a product worktree,
registry, report, or correction-evidence path.
"""

from __future__ import annotations

import copy
import json
import tempfile
from pathlib import Path

import v076_full_history_scan_cache as cache


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def synthetic_plan() -> dict:
    scanner_sha = "a" * 64
    rule_sha = "b" * 64
    commits = [f"{number:040x}" for number in range(1, 7)]
    rows = [
        cache._commit_input(commit, f"{number + 100:040x}", scanner_sha, rule_sha)
        for number, commit in enumerate(commits, 1)
    ]
    shards = []
    for index in range(0, len(rows), 3):
        part = rows[index : index + 3]
        values = [row["commit_sha"] for row in part]
        keys = [row["cache_key"] for row in part]
        shards.append(
            {
                "shard_id": f"shard-{len(shards) + 1:04d}",
                "commit_start": values[0],
                "commit_end": values[-1],
                "commit_count": len(values),
                "commits": values,
                "commit_rows": part,
                "commit_set_sha256": cache.line_set_sha256(values),
                "cache_key_set_sha256": cache.line_set_sha256(keys),
                "scanner_sha256": scanner_sha,
                "rule_manifest_sha256": rule_sha,
                "result_sha256": "",
                "failure_fingerprints": [],
                "failure_fingerprint_set_sha256": cache.line_set_sha256(()),
                "completed": False,
            }
        )
    return {
        "schema_version": cache.SCHEMA_VERSION,
        "manifest_kind": cache.MANIFEST_KIND,
        "revision": "HEAD",
        "head_sha": commits[-1],
        "scanner_path": "scanner",
        "scanner_sha256": scanner_sha,
        "rule_manifest_path": "rules",
        "rule_manifest_sha256": rule_sha,
        "shard_size": 3,
        "full_history": True,
        "commit_count": len(commits),
        "commits": commits,
        "commit_set_sha256": cache.line_set_sha256(commits),
        "planned_shard_count": len(shards),
        "completed_shard_count": 0,
        "failure_fingerprints": [],
        "failure_fingerprint_set_sha256": cache.line_set_sha256(()),
        "shards": shards,
        "status": "PLANNED",
    }


def complete_plan(plan: dict) -> dict:
    result = plan
    for index, shard in enumerate(list(result["shards"])):
        result = cache.attach_result(
            result,
            shard["shard_id"],
            {
                "schema_version": cache.RESULT_SCHEMA_VERSION,
                "failure_fingerprints": [f"V2F-{index:064x}"],
            },
        )
    return result


def parity_report(fingerprints: list[str], *, count: int | None = None) -> dict:
    rows = [
        {"failure_fingerprint": value, "failure_class": "HISTORICAL"}
        for value in fingerprints
    ]
    return {
        "failures": rows,
        "failure_count": len(fingerprints) if count is None else count,
        "historical_failure_count": len(fingerprints) if count is None else count,
        "current_delta_failure_count": 0,
        "scanner_rule_ast_sha256": "c" * 64,
        "scanner_scope_sha256": "d" * 64,
        "scanner_severity_sha256": "e" * 64,
    }


def main() -> int:
    cases: list[dict[str, str]] = []

    def run(name: str, operation) -> None:
        try:
            operation()
        except Exception as exc:  # noqa: BLE001 - selftest records the failure
            cases.append({"name": name, "status": "FAIL", "error": str(exc)})
        else:
            cases.append({"name": name, "status": "PASS"})

    run(
        "cache key binds commit tree scanner and rule hashes",
        lambda: expect(
            cache.make_cache_key("1" * 40, "2" * 40, "3" * 64, "4" * 64)
            != cache.make_cache_key("1" * 40, "9" * 40, "3" * 64, "4" * 64),
            "tree was not bound",
        ),
    )

    run(
        "planned shards fail closed while incomplete",
        lambda: expect(cache.verify_manifest(synthetic_plan())["status"] == "FAIL", "incomplete plan passed"),
    )

    complete = complete_plan(synthetic_plan())
    run(
        "completed shard plan verifies",
        lambda: expect(cache.verify_manifest(complete)["status"] == "PASS", "completed plan failed"),
    )

    def duplicate_commit() -> None:
        attacked = complete_plan(synthetic_plan())
        attacked["shards"][1]["commits"][0] = attacked["shards"][0]["commits"][0]
        result = cache.verify_manifest(attacked)
        expect(result["status"] == "FAIL" and "DUPLICATE_COMMIT_ACROSS_SHARDS" in result["findings"], str(result))

    run("duplicate commits fail closed", duplicate_commit)

    def missing_commit() -> None:
        attacked = complete_plan(synthetic_plan())
        attacked["commits"] = attacked["commits"][:-1]
        attacked["commit_count"] -= 1
        attacked["commit_set_sha256"] = cache.line_set_sha256(attacked["commits"])
        result = cache.verify_manifest(attacked)
        expect(result["status"] == "FAIL" and "MISSING_OR_EXTRA_COMMIT_ACROSS_SHARDS" in result["findings"], str(result))

    run("missing commit fails closed", missing_commit)

    def duplicate_fingerprint() -> None:
        attacked = complete_plan(synthetic_plan())
        duplicate = attacked["shards"][0]["failure_fingerprints"][0]
        payload = {"schema_version": cache.RESULT_SCHEMA_VERSION, "failure_fingerprints": [duplicate]}
        attacked["shards"][1]["result"] = payload
        attacked["shards"][1]["result_sha256"] = cache.sha256_bytes(cache.canonical_bytes(payload))
        attacked["shards"][1]["failure_fingerprints"] = [duplicate]
        attacked["shards"][1]["failure_fingerprint_set_sha256"] = cache.line_set_sha256([duplicate])
        attacked["failure_fingerprints"] = [duplicate]
        attacked["failure_fingerprint_set_sha256"] = cache.line_set_sha256([duplicate])
        result = cache.verify_manifest(attacked)
        expect(result["status"] == "FAIL" and "DUPLICATE_FAILURE_FINGERPRINT_ACROSS_SHARDS" in result["findings"], str(result))

    run("duplicate failure fingerprints fail closed", duplicate_fingerprint)

    def explicit_failure() -> None:
        attacked = complete_plan(synthetic_plan())
        attacked["shards"][0]["status"] = "CANCELLED"
        result = cache.verify_manifest(attacked)
        expect(result["status"] == "FAIL" and any("EXPLICIT_FAILURE" in item for item in result["findings"]), str(result))

    run("explicit failed shard never passes", explicit_failure)

    def explicit_result_failure() -> None:
        attacked = complete_plan(synthetic_plan())
        payload = copy.deepcopy(attacked["shards"][0]["result"])
        payload["status"] = "FAIL"
        attacked["shards"][0]["result"] = payload
        attacked["shards"][0]["result_sha256"] = cache.sha256_bytes(cache.canonical_bytes(payload))
        result = cache.verify_manifest(attacked)
        expect(result["status"] == "FAIL" and any("RESULT_EXPLICIT_FAILURE" in item for item in result["findings"]), str(result))

    run("explicit failed result never passes", explicit_result_failure)

    def cache_key_tamper() -> None:
        attacked = complete_plan(synthetic_plan())
        attacked["shards"][0]["commit_rows"][0]["cache_key"] = "0" * 64
        result = cache.verify_manifest(attacked)
        expect(result["status"] == "FAIL" and any("CACHE_KEY_BINDING_MISMATCH" in item for item in result["findings"]), str(result))

    run("cache key mutation is detected", cache_key_tamper)

    fps = ["V2F-" + "a" * 64, "V2F-" + "b" * 64]
    run(
        "raw failure and scanner parity passes",
        lambda: expect(cache.compare_raw_failure_fingerprint_parity(parity_report(fps), parity_report(fps))["status"] == "PASS", "parity failed"),
    )

    def parity_missing_metadata() -> None:
        left, right = parity_report(fps), parity_report(fps)
        del right["scanner_scope_sha256"]
        result = cache.compare_raw_failure_fingerprint_parity(left, right)
        expect(result["status"] == "FAIL" and not result["SCANNER_SCOPE_PARITY"], str(result))

    run("missing scanner parity metadata fails closed", parity_missing_metadata)

    def parity_extra_fp() -> None:
        result = cache.compare_raw_failure_fingerprint_parity(parity_report(fps), parity_report(fps + ["V2F-" + "c" * 64]))
        expect(result["status"] == "FAIL" and result["extra_failure_fingerprints"], str(result))

    run("extra failure fingerprint breaks parity", parity_extra_fp)

    def cache_file_verification() -> None:
        plan = synthetic_plan()
        with tempfile.TemporaryDirectory(prefix="v076_scan_cache_") as directory:
            cache_dir = Path(directory)
            for index, shard in enumerate(plan["shards"]):
                payload = {"failure_fingerprints": [f"V2F-{index:064x}"]}
                (cache_dir / f"{shard['shard_id']}.json").write_bytes(cache.canonical_bytes(payload))
                shard["result_sha256"] = cache.sha256_bytes(cache.canonical_bytes(payload))
                shard["failure_fingerprints"] = payload["failure_fingerprints"]
                shard["failure_fingerprint_set_sha256"] = cache.line_set_sha256(payload["failure_fingerprints"])
                shard["completed"] = True
            plan["completed_shard_count"] = len(plan["shards"])
            plan["failure_fingerprints"] = [f"V2F-{index:064x}" for index in range(len(plan["shards"]))]
            plan["failure_fingerprint_set_sha256"] = cache.line_set_sha256(plan["failure_fingerprints"])
            plan["status"] = "COMPLETE"
            result = cache.verify_manifest(plan, cache_dir=cache_dir)
            expect(result["status"] == "PASS", str(result))

    run("cache directory result files are verified", cache_file_verification)

    passed = sum(case["status"] == "PASS" for case in cases)
    report = {
        "schema_version": "space_syndicate.v076.full_history_scan_cache_selftest.v1",
        "status": "PASS" if passed == len(cases) else "FAIL",
        "case_count": len(cases),
        "pass_count": passed,
        "cases": cases,
    }
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0 if passed == len(cases) else 1


if __name__ == "__main__":
    raise SystemExit(main())
