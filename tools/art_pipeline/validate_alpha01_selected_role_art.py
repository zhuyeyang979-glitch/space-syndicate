#!/usr/bin/env python3
"""Validate the four missing Alpha 0.1 selected-role portrait pairs."""

from __future__ import annotations

import hashlib
import json
import sys
from itertools import combinations
from pathlib import Path

from PIL import Image


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "assets/art/role_portraits/temporary/manifest.json"
CONTRACT_PATH = ROOT / "docs/art_qa/role_portraits/alpha01/art_contract.json"
REPORT_PATH = ROOT / "docs/art_qa/role_portraits/alpha01/validation_report.json"
ROLE_SLUGS = {
    "深海菌毯使团": "deepsea_mycelium_delegation",
    "离子军购局": "ion_procurement_bureau",
    "孪星兽栏同盟": "binary_star_stable_alliance",
    "蜂巢防务议会": "hive_defense_council",
}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _dhash(image: Image.Image, alpha_only: bool) -> int:
    rgba = image.convert("RGBA")
    if alpha_only:
        channel = rgba.getchannel("A")
    else:
        background = Image.new("RGBA", rgba.size, (20, 25, 35, 255))
        background.alpha_composite(rgba)
        channel = background.convert("L")
    reduced = channel.resize((17, 16), Image.Resampling.LANCZOS)
    pixels = list(reduced.get_flattened_data())
    result = 0
    for y in range(16):
        for x in range(16):
            result = (result << 1) | int(
                pixels[y * 17 + x] > pixels[y * 17 + x + 1]
            )
    return result


def _threshold_bbox(alpha: Image.Image, threshold: int = 16) -> tuple[int, int, int, int] | None:
    return alpha.point(lambda value: 255 if value > threshold else 0).getbbox()


def main() -> int:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    entries = {row["role_name"]: row for row in manifest.get("roles", [])}
    failures: list[str] = []
    metrics: list[dict[str, object]] = []
    signatures: list[tuple[str, str, int, int]] = []
    file_hashes: set[str] = set()
    source_hashes: set[str] = set()
    identities: set[str] = set()
    width = int(contract["width"])
    height = int(contract["height"])
    generated_count = 0

    for role_name, slug in ROLE_SLUGS.items():
        entry = entries.get(role_name, {})
        if not entry:
            failures.append(f"manifest_role_missing:{role_name}")
            continue
        if entry.get("slug") != slug:
            failures.append(f"slug_mismatch:{role_name}")
        if entry.get("status") != "rendered":
            failures.append(f"role_not_rendered:{role_name}")
        if entry.get("quality_tier") != "alpha01_generated_original":
            failures.append(f"quality_tier_invalid:{role_name}")
        if entry.get("source_kind") != "openai_generated":
            failures.append(f"source_kind_invalid:{role_name}")
        if entry.get("provider") != "OpenAI" or entry.get("model") != "imagegen_tool_unspecified":
            failures.append(f"provider_model_invalid:{role_name}")
        if entry.get("front_direction") != contract["required_front_direction"]:
            failures.append(f"front_direction_invalid:{role_name}")
        if entry.get("side_inward_direction") != contract["required_side_direction"]:
            failures.append(f"side_direction_invalid:{role_name}")
        identity = str(entry.get("identity_signature", ""))
        if not identity or identity in identities:
            failures.append(f"identity_signature_invalid:{role_name}")
        identities.add(identity)
        generation_ids = entry.get("source_generation_ids", {})
        source_by_view = entry.get("source_sha256_by_view", {})
        for view_kind in contract["required_views"]:
            if not str(generation_ids.get(view_kind, "")).startswith("imagegen-"):
                failures.append(f"generation_id_missing:{role_name}:{view_kind}")
            source_sha = str(source_by_view.get(view_kind, ""))
            if len(source_sha) != 64 or source_sha in source_hashes:
                failures.append(f"source_sha_invalid_or_duplicate:{role_name}:{view_kind}")
            source_hashes.add(source_sha)
            path_key = f"{view_kind}_path"
            hash_key = f"{view_kind}_sha256"
            relative_path = str(entry.get(path_key, ""))
            expected_relative = f"assets/art/role_portraits/temporary/{slug}/{view_kind}.png"
            if relative_path != expected_relative:
                failures.append(f"asset_path_invalid:{role_name}:{view_kind}")
                continue
            path = ROOT / relative_path
            if not path.is_file():
                failures.append(f"asset_missing:{role_name}:{view_kind}")
                continue
            actual_sha = _sha256(path)
            if actual_sha != entry.get(hash_key):
                failures.append(f"asset_sha_mismatch:{role_name}:{view_kind}")
            if actual_sha in file_hashes:
                failures.append(f"duplicate_asset_sha:{role_name}:{view_kind}")
            file_hashes.add(actual_sha)
            with Image.open(path) as opened:
                if opened.size != (width, height):
                    failures.append(f"dimensions_invalid:{role_name}:{view_kind}:{opened.size}")
                if opened.mode != contract["mode"]:
                    failures.append(f"mode_invalid:{role_name}:{view_kind}:{opened.mode}")
                rgba = opened.convert("RGBA")
                alpha = rgba.getchannel("A")
                corners = ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1))
                if any(alpha.getpixel(point) != 0 for point in corners):
                    failures.append(f"corner_alpha_invalid:{role_name}:{view_kind}")
                histogram = alpha.histogram()
                coverage = sum(histogram[1:]) / (width * height)
                if not contract["minimum_subject_coverage"] <= coverage <= contract["maximum_subject_coverage"]:
                    failures.append(f"coverage_invalid:{role_name}:{view_kind}:{coverage:.6f}")
                bbox = _threshold_bbox(alpha)
                if bbox is None:
                    failures.append(f"blank_asset:{role_name}:{view_kind}")
                    continue
                subject_height_ratio = (bbox[3] - bbox[1]) / height
                bottom_pivot_ratio = bbox[3] / height
                if subject_height_ratio < contract["minimum_subject_height_ratio"]:
                    failures.append(f"subject_too_small:{role_name}:{view_kind}:{subject_height_ratio:.6f}")
                if bottom_pivot_ratio < contract["minimum_bottom_pivot_ratio"]:
                    failures.append(f"bottom_pivot_too_high:{role_name}:{view_kind}:{bottom_pivot_ratio:.6f}")
                color_hash = _dhash(rgba, False)
                alpha_hash = _dhash(rgba, True)
                signatures.append((role_name, view_kind, color_hash, alpha_hash))
                metrics.append({
                    "role_name": role_name,
                    "slug": slug,
                    "view": view_kind,
                    "sha256": actual_sha,
                    "coverage": round(coverage, 6),
                    "subject_height_ratio": round(subject_height_ratio, 6),
                    "bottom_pivot_ratio": round(bottom_pivot_ratio, 6),
                    "bbox": list(bbox),
                })
        generated_count += 1

    pairwise: list[dict[str, object]] = []
    for left, right in combinations(signatures, 2):
        distance = (left[2] ^ right[2]).bit_count() + (left[3] ^ right[3]).bit_count()
        same_role = left[0] == right[0]
        threshold = (
            int(contract["minimum_front_side_combined_dhash_distance"])
            if same_role
            else int(contract["minimum_cross_role_combined_dhash_distance"])
        )
        pairwise.append({
            "left": f"{left[0]}:{left[1]}",
            "right": f"{right[0]}:{right[1]}",
            "combined_dhash_distance": distance,
            "threshold": threshold,
        })
        if distance < threshold:
            failures.append(f"perceptual_similarity_too_high:{left[0]}:{left[1]}:{right[0]}:{right[1]}:{distance}")

    if generated_count != int(contract["role_count"]):
        failures.append(f"role_count_invalid:{generated_count}")
    if len(metrics) != int(contract["image_count"]):
        failures.append(f"image_count_invalid:{len(metrics)}")
    if len(file_hashes) != int(contract["image_count"]):
        failures.append(f"unique_asset_hash_count_invalid:{len(file_hashes)}")
    if len(source_hashes) != int(contract["image_count"]):
        failures.append(f"unique_source_hash_count_invalid:{len(source_hashes)}")
    if len(identities) != int(contract["role_count"]):
        failures.append(f"identity_count_invalid:{len(identities)}")

    report = {
        "status": "PASS" if not failures else "FAIL",
        "role_count": generated_count,
        "image_count": len(metrics),
        "unique_asset_hash_count": len(file_hashes),
        "unique_source_hash_count": len(source_hashes),
        "identity_count": len(identities),
        "metrics": metrics,
        "pairwise": pairwise,
        "failures": failures,
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
