#!/usr/bin/env python3
"""Stable machine query entry point for the commercial asset registry."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_REGISTRY.json"
SAFE_COMPATIBILITY = {
    "DIRECT_COMMERCIAL_USE_VERIFIED",
    "COMMERCIAL_USE_WITH_ATTRIBUTION",
    "CODE_ADAPTATION_ALLOWED",
}


def load_registry() -> dict[str, Any]:
    return json.loads(REGISTRY.read_text(encoding="utf-8"))


def matches(row: dict[str, Any], args: argparse.Namespace) -> bool:
    if args.asset_id and row["asset_id"] != args.asset_id:
        return False
    if args.feature and args.feature not in row["feature_tags"] and args.feature not in row["target_components"]:
        return False
    if args.status and row["current_status"] != args.status:
        return False
    if args.license and row["license_name"].upper() != args.license.upper():
        return False
    if args.commercial_safe and (
        row["commercial_compatibility"] not in SAFE_COMPATIBILITY
        or not row["license_verified"]
        or row["reference_only"]
    ):
        return False
    if args.unused_compatible and (
        row["commercial_compatibility"] not in SAFE_COMPATIBILITY
        or not row["license_verified"]
        or row["reference_only"]
        or row["used_in_production_paths"]
    ):
        return False
    return True


def projection(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "asset_id": row["asset_id"],
        "title": row["title"],
        "feature_tags": row["feature_tags"],
        "local_paths": row["local_paths"],
        "license_name": row["license_name"],
        "license_verified": row["license_verified"],
        "commercial_compatibility": row["commercial_compatibility"],
        "reference_only": row["reference_only"],
        "direct_asset_use_allowed": row["direct_asset_use_allowed"],
        "direct_code_use_allowed": row["direct_code_use_allowed"],
        "used_in_production_paths": row["used_in_production_paths"],
        "used_in_test_paths": row["used_in_test_paths"],
        "rejected_reason": row["rejected_reason"],
        "risk": (
            "none" if row["license_verified"] and row["commercial_compatibility"] in SAFE_COMPATIBILITY and not row["reference_only"]
            else "reference-only or license review required"
        ),
    }


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--feature")
    result.add_argument("--commercial-safe", action="store_true")
    result.add_argument("--status")
    result.add_argument("--license")
    result.add_argument("--unused-compatible", action="store_true")
    result.add_argument("--asset-id")
    result.add_argument("--selftest", action="store_true")
    return result


def run_selftest(registry: dict[str, Any]) -> dict[str, Any]:
    rows = registry["assets"]
    unknown = [row for row in rows if row["asset_id"] == "asset.__unknown__"]
    safe = [row for row in rows if matches(row, argparse.Namespace(asset_id=None, feature=None, status=None, license=None, commercial_safe=True, unused_compatible=False))]
    failures: list[str] = []
    if unknown:
        failures.append("unknown sentinel unexpectedly registered")
    if not safe:
        failures.append("no commercial-safe candidates")
    if any(row["reference_only"] for row in safe):
        failures.append("reference-only row passed commercial-safe filter")
    return {
        "status": "PASS" if not failures else "FAIL",
        "unknown_asset_query_false_accept_count": len(unknown),
        "license_unverified_commercial_result_count": sum(1 for row in safe if not row["license_verified"]),
        "commercial_safe_candidate_count": len(safe),
        "failures": failures,
    }


def main() -> int:
    args = parser().parse_args()
    registry = load_registry()
    if args.selftest:
        result = run_selftest(registry)
        print("ASSET_REGISTRY_QUERY_SELFTEST|" + json.dumps(result, ensure_ascii=False, sort_keys=True))
        return 0 if result["status"] == "PASS" else 1
    rows = [projection(row) for row in registry["assets"] if matches(row, args)]
    output = {
        "registry_id": registry["registry_id"],
        "query": {
            "feature": args.feature,
            "commercial_safe": args.commercial_safe,
            "status": args.status,
            "license": args.license,
            "unused_compatible": args.unused_compatible,
            "asset_id": args.asset_id,
        },
        "candidate_count": len(rows),
        "candidates": rows,
    }
    print(json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
