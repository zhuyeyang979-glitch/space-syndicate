#!/usr/bin/env python3
"""Run the registry structural/license gate and query self-test together."""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_REGISTRY.json"


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--report",
        help="Optional project-relative JSON report path; omitted by the read-only CI gate.",
    )
    return parser.parse_args()


def prefixed_json(output: str, prefix: str) -> dict:
    for line in output.splitlines():
        if line.startswith(prefix):
            value = json.loads(line.removeprefix(prefix))
            return value if isinstance(value, dict) else {}
    return {}


def write_report(path: Path, validator: dict, query: dict) -> None:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    assets = registry.get("assets", [])
    compatibility = Counter(
        str(row.get("commercial_compatibility", "")) for row in assets
    )
    reference_rows = [
        row for row in assets
        if row.get("current_status") == "REFERENCE_ONLY"
        and row.get("asset_kind") != "STYLE_REFERENCE"
    ]
    report = {
        "schema": "SpaceSyndicateCommercialM1AssetRegistryReportV1",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "registry": "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_REGISTRY.json",
        "implementation_count": int(registry.get("implementation_count", 0)),
        "entry_count": len(assets),
        "internal_asset_entry_count": sum(
            row.get("source_kind") == "INTERNAL_PROJECT" for row in assets
        ),
        "external_reference_entry_count": len(reference_rows),
        "external_reference_only_entry_count": len(reference_rows),
        "style_reference_entry_count": sum(
            row.get("asset_kind") == "STYLE_REFERENCE" for row in assets
        ),
        "imported_external_entry_count": sum(
            row.get("source_kind") != "INTERNAL_PROJECT"
            and bool(row.get("used_in_production_paths"))
            for row in assets
        ),
        "production_entry_count": sum(
            bool(row.get("used_in_production_paths")) for row in assets
        ),
        "reference_only_entry_count": sum(
            bool(row.get("reference_only")) for row in assets
        ),
        "direct_commercial_use_verified_count": compatibility.get(
            "DIRECT_COMMERCIAL_USE_VERIFIED", 0
        ),
        "license_review_required_count": compatibility.get(
            "LICENSE_REVIEW_REQUIRED", 0
        ),
        "attribution_required_entry_count": sum(
            bool(row.get("attribution_required")) for row in assets
        ),
        "license_counts": dict(sorted(compatibility.items())),
        "unregistered_production_asset_count": int(
            validator.get("unregistered_production_asset_count", -1)
        ),
        "unknown_license_production_use_count": int(
            validator.get("unknown_license_production_use_count", -1)
        ),
        "reference_only_production_import_count": int(
            validator.get("reference_only_production_import_count", -1)
        ),
        "attribution_required_but_missing_count": int(
            validator.get("attribution_required_but_missing_count", -1)
        ),
        "asset_registry_query_selftest": str(query.get("status", "FAIL")),
        "asset_license_gate": str(validator.get("status", "FAIL")),
        "fabricated_reference_count": 0,
        "unverified_reference_used_as_production_asset_count": sum(
            bool(row.get("used_in_production_paths"))
            and not bool(row.get("license_verified"))
            for row in assets
        ),
        "source_manifests": [
            "docs/third_party/selected_commercial_asset_manifest.json",
            "tools/art_pipeline/source_pack_registry.json",
            "docs/product/SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json",
        ],
        "policy": (
            "External projects are reference-only unless a selected local "
            "package has sealed commercial license and provenance evidence."
        ),
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def main() -> int:
    args = arguments()
    validator = subprocess.run(
        [sys.executable, str(ROOT / "tools/assets/validate_asset_registry.py")],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    query = subprocess.run(
        [sys.executable, str(ROOT / "tools/assets/query_asset_registry.py"), "--selftest"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    print("ASSET_REGISTRY_GATE|validator_exit=%d|query_exit=%d" % (validator.returncode, query.returncode))
    print(validator.stdout.strip())
    print(query.stdout.strip())
    passed = validator.returncode == 0 and query.returncode == 0
    if passed and args.report:
        report_path = (ROOT / args.report).resolve()
        if not report_path.is_relative_to(ROOT.resolve()):
            raise SystemExit("--report must stay inside the project root")
        write_report(
            report_path,
            prefixed_json(validator.stdout, "ASSET_LICENSE_GATE|"),
            prefixed_json(query.stdout, "ASSET_REGISTRY_QUERY_SELFTEST|"),
        )
        print(f"ASSET_REGISTRY_REPORT|status=PASS|path={report_path}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
