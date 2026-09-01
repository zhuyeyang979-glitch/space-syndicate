#!/usr/bin/env python3
"""Read-only fixture tests for the commercial asset registry gate."""

from __future__ import annotations

import ast
import fnmatch
import hashlib
import json
import re
import sys
import tempfile
from pathlib import Path


if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_asset_reference_registry import (  # noqa: E402
    SOURCE_MANIFEST,
    combined_blob_identity,
    exact_source_identity,
)
from validate_asset_registry import (  # noqa: E402
    declared_local_blob_hash_failures,
    exact_source_identity_is_sealed,
)


ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/space-syndicate-asset-registry-license-gate.yml"
REQUIRED_WORKFLOW_PATHS = {
    "docs/third_party/selected_commercial_asset_manifest.json",
    "tools/art_pipeline/source_pack_registry.json",
    "docs/product/SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json",
    "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_REGISTRY.json",
    "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_REGISTRY.md",
    "docs/product/SPACE_SYNDICATE_ASSET_REFERENCE_GALLERY.md",
    "THIRD_PARTY_NOTICES.generated.md",
    "scenes/main.tscn",
    "scenes/ui/v075/V075SampleGameScreen.tscn",
    "scenes/ui/v075/V075NewGameLoadingOverlay.tscn",
    "resources/cards/runtime/card_runtime_catalog_v06.tres",
    "scripts/v075/cards/v075_card_definition_registry.gd",
    "scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd",
    "scripts/ui/map/planet_city_marker.gd",
    "scripts/v07_semantic/v07_unified_card_track_core.gd",
    "scripts/ui/v074/v074_sample_game_screen.gd",
    "scripts/ui/v075/v075_sample_game_screen.gd",
    "scripts/v076/simulation/v076_deterministic_kernel.gd",
    "scripts/v076/direct_action/v076_private_direct_action_input_owner_v1.gd",
    "scripts/v07_semantic/v07_solar_victory_core.gd",
    "scripts/ui/v075/v075_new_game_loading_overlay.gd",
    "data/art/alpha01_product_art_manifest.json",
    "data/art/card_illustration_manifest_v06.json",
    "data/art/monster_body_art_manifest.json",
    "tools/assets/**",
}


def check(
    failures: list[str],
    name: str,
    condition: bool,
) -> None:
    if not condition:
        failures.append(name)


def main() -> int:
    failures: list[str] = []
    case_count = 0

    source_hash = "a" * 64
    case_count += 1
    check(
        failures,
        "commit_preferred_over_version",
        exact_source_identity({
            "asset_id": "fixture.commit",
            "source_commit": "b" * 40,
            "version": "1.2.3",
            "original_sha256": source_hash,
        }) == "commit:" + ("b" * 40),
    )
    case_count += 1
    check(
        failures,
        "version_preferred_over_hash",
        exact_source_identity({
            "asset_id": "fixture.version",
            "source_version": "1.2.3",
            "original_sha256": source_hash,
        }) == "version:1.2.3",
    )
    case_count += 1
    check(
        failures,
        "source_hash_fallback",
        exact_source_identity({
            "asset_id": "fixture.hash",
            "original_sha256": source_hash,
            "downloaded_at": "2026-08-26T01:00:00Z",
        }) == "sha256:" + source_hash,
    )

    case_count += 1
    try:
        exact_source_identity({
            "asset_id": "fixture.timestamp_only",
            "downloaded_at": "2026-08-26T01:00:00Z",
        })
        failures.append("timestamp_only_must_fail_closed")
    except ValueError:
        pass

    accepted_identities = [
        "c" * 40,
        "commit:" + ("d" * 40),
        "version:1.2.3",
        "tag:v1.2.3",
        "revision:r42",
        "sha256:" + ("e" * 64),
    ]
    for identity in accepted_identities:
        case_count += 1
        check(
            failures,
            f"sealed_identity:{identity.split(':', 1)[0]}",
            exact_source_identity_is_sealed(identity),
        )
    for identity in ["", "UNVERIFIED", "2026-08-26T01:00:00Z", "sha256:bad"]:
        case_count += 1
        check(
            failures,
            f"rejected_identity:{identity or 'empty'}",
            not exact_source_identity_is_sealed(identity),
        )

    with tempfile.TemporaryDirectory(prefix="asset-registry-selftest-") as temporary:
        fixture_root = Path(temporary)
        fixture_path = fixture_root / "fixtures" / "internal.txt"
        fixture_path.parent.mkdir(parents=True, exist_ok=True)
        fixture_path.write_text("sealed internal fixture\n", encoding="utf-8")
        fixture_hash = hashlib.sha256(fixture_path.read_bytes()).hexdigest()
        row = {
            "asset_id": "fixture.internal",
            "source_kind": "INTERNAL_PROJECT",
            "local_paths": ["res://fixtures/internal.txt"],
            "local_blob_sha256": [fixture_hash],
        }

        case_count += 1
        check(
            failures,
            "internal_hash_match",
            declared_local_blob_hash_failures(row, fixture_root) == [],
        )
        mismatched = dict(row)
        mismatched["local_blob_sha256"] = ["0" * 64]
        mismatch_failures = declared_local_blob_hash_failures(
            mismatched,
            fixture_root,
        )
        case_count += 1
        check(
            failures,
            "internal_hash_mismatch_detected",
            len(mismatch_failures) == 1
            and mismatch_failures[0].get("code") == "LOCAL_BLOB_HASH_MISMATCH",
        )
        missing_hash = dict(row)
        missing_hash["local_blob_sha256"] = []
        cardinality_failures = declared_local_blob_hash_failures(
            missing_hash,
            fixture_root,
        )
        case_count += 1
        check(
            failures,
            "internal_hash_cardinality_detected",
            len(cardinality_failures) == 1
            and cardinality_failures[0].get("code")
            == "LOCAL_BLOB_HASH_CARDINALITY_MISMATCH",
        )

        case_count += 1
        combined_identity = combined_blob_identity(
            ["res://fixtures/internal.txt"],
            fixture_root,
        )
        check(
            failures,
            "internal_combined_identity_is_content_sealed",
            exact_source_identity_is_sealed(combined_identity)
            and combined_identity.startswith("sha256:")
            and "2026" not in combined_identity,
        )

    manifest = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
    identities = [exact_source_identity(row) for row in manifest.get("assets", [])]
    case_count += 1
    check(
        failures,
        "manifest_all_rows_have_exact_identity",
        len(identities) == 30 and all(value.startswith("sha256:") for value in identities),
    )

    workflow_text = WORKFLOW.read_text(encoding="utf-8")
    for path in sorted(REQUIRED_WORKFLOW_PATHS):
        case_count += 1
        check(
            failures,
            f"workflow_path:{path}",
            f'      - "{path}"' in workflow_text,
        )
    workflow_filters = set(
        re.findall(r'^\s+- "([^"]+)"\s*$', workflow_text, flags=re.MULTILINE)
    )
    builder_tree = ast.parse(
        Path(__file__).with_name("build_asset_reference_registry.py").read_text(
            encoding="utf-8"
        )
    )
    builder_resource_paths = sorted({
        node.value.removeprefix("res://")
        for node in ast.walk(builder_tree)
        if isinstance(node, ast.Constant)
        and isinstance(node.value, str)
        and node.value.startswith("res://")
        and len(node.value) > len("res://")
    })
    for path in builder_resource_paths:
        case_count += 1
        check(
            failures,
            f"builder_input_workflow_path:{path}",
            any(fnmatch.fnmatchcase(path, pattern) for pattern in workflow_filters),
        )

    status = "PASS" if not failures else "FAIL"
    print(
        "ASSET_REGISTRY_GATE_SELFTEST|"
        + json.dumps(
            {
                "status": status,
                "case_count": case_count,
                "manifest_identity_count": len(identities),
                "failures": failures,
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
