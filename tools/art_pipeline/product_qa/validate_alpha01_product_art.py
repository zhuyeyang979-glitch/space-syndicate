#!/usr/bin/env python3
"""Validate the isolated Alpha 0.1 six-industry product-art proof batch."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from itertools import combinations
from pathlib import Path

from PIL import Image


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


REPO_ROOT = Path(__file__).resolve().parents[3]
MANIFEST_PATH = REPO_ROOT / "data/art/alpha01_product_art_manifest.json"
ALPHA_MANIFEST_PATH = REPO_ROOT / "resources/content/alpha01/alpha01_content_manifest.tres"
CATALOG_PATH = REPO_ROOT / "resources/content/product_industry_catalog_v05.tres"


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _repo_path(resource_path: str) -> Path:
    if not resource_path.startswith("res://"):
        raise ValueError(f"not a res:// path: {resource_path}")
    return REPO_ROOT / resource_path.removeprefix("res://")


def _alpha_product_ids() -> set[str]:
    source = ALPHA_MANIFEST_PATH.read_text(encoding="utf-8")
    match = re.search(r"product_ids\s*=\s*PackedStringArray\((.*?)\)\s*$", source, re.MULTILINE)
    if match is None:
        raise ValueError("Alpha product_ids could not be parsed")
    return set(re.findall(r'"([^"]+)"', match.group(1)))


def _catalog_industries() -> dict[str, str]:
    source = CATALOG_PATH.read_text(encoding="utf-8")
    return {
        product_id: industry_id
        for product_id, industry_id in re.findall(
            r'product_id\s*=\s*"([^"]+)"\s*\r?\nindustry_id\s*=\s*"([^"]+)"', source
        )
    }


def _dhash(image: Image.Image, alpha_only: bool) -> int:
    rgba = image.convert("RGBA")
    if alpha_only:
        channel = rgba.getchannel("A")
    else:
        background = Image.new("RGBA", rgba.size, (32, 38, 50, 255))
        background.alpha_composite(rgba)
        channel = background.convert("L")
    reduced = channel.resize((17, 16), Image.Resampling.LANCZOS)
    pixels = list(reduced.get_flattened_data())
    result = 0
    for y in range(16):
        for x in range(16):
            result = (result << 1) | int(pixels[y * 17 + x] > pixels[y * 17 + x + 1])
    return result


def main() -> int:
    failures: list[str] = []
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    contract = manifest.get("hard_contract", {})
    entries = manifest.get("entries", [])
    alpha_ids = _alpha_product_ids()
    catalog = _catalog_industries()
    expected_industries = set(contract.get("industries", []))
    width = int(contract.get("width", 0))
    height = int(contract.get("height", 0))
    minimum_coverage = float(contract.get("minimum_subject_coverage", 0.0))
    maximum_coverage = float(contract.get("maximum_subject_coverage", 1.0))
    minimum_distance = int(contract.get("minimum_pairwise_combined_dhash_distance", 0))

    if manifest.get("schema_version") != "alpha01.product_art_proof.v1":
        failures.append("schema_version_invalid")
    if manifest.get("runtime_policy") != "proof_only_not_connected_to_production_consumers":
        failures.append("runtime_policy_must_remain_proof_only")
    if len(entries) != int(contract.get("entry_count", -1)) or len(entries) != 6:
        failures.append(f"entry_count_invalid:{len(entries)}")

    seen_products: set[str] = set()
    seen_industries: set[str] = set()
    seen_hashes: set[str] = set()
    seen_source_hashes: set[str] = set()
    image_signatures: list[tuple[str, int, int]] = []
    metrics: list[dict[str, object]] = []

    for entry in entries:
        product_id = str(entry.get("product_id", ""))
        industry_id = str(entry.get("industry_id", ""))
        asset_path = str(entry.get("asset_path", ""))
        declared_sha = str(entry.get("sha256", ""))
        source_sha = str(entry.get("source_sha256", ""))
        if product_id in seen_products:
            failures.append(f"duplicate_product:{product_id}")
        seen_products.add(product_id)
        if product_id not in alpha_ids:
            failures.append(f"not_in_alpha:{product_id}")
        if catalog.get(product_id) != industry_id:
            failures.append(f"industry_mismatch:{product_id}:{industry_id}:{catalog.get(product_id, '')}")
        if industry_id in seen_industries:
            failures.append(f"duplicate_industry:{industry_id}")
        seen_industries.add(industry_id)
        if not re.fullmatch(r"[0-9a-f]{64}", declared_sha):
            failures.append(f"asset_sha_invalid:{product_id}")
        if not re.fullmatch(r"[0-9a-f]{64}", source_sha):
            failures.append(f"source_sha_invalid:{product_id}")
        if declared_sha in seen_hashes:
            failures.append(f"duplicate_asset_sha:{product_id}")
        seen_hashes.add(declared_sha)
        if source_sha in seen_source_hashes:
            failures.append(f"duplicate_source_sha:{product_id}")
        seen_source_hashes.add(source_sha)
        if not str(entry.get("source_generation_id", "")).startswith("imagegen-"):
            failures.append(f"generation_id_missing:{product_id}")
        if not str(entry.get("prompt_id", "")):
            failures.append(f"prompt_id_missing:{product_id}")
        if len(str(entry.get("visual_contract", ""))) < 24:
            failures.append(f"visual_contract_missing:{product_id}")

        try:
            path = _repo_path(asset_path)
        except ValueError as exc:
            failures.append(f"asset_path_invalid:{product_id}:{exc}")
            continue
        if path.parent != REPO_ROOT / "assets/art/products/alpha01/proof":
            failures.append(f"asset_outside_owned_directory:{product_id}")
        if not path.is_file():
            failures.append(f"asset_missing:{product_id}")
            continue
        actual_sha = _sha256(path)
        if actual_sha != declared_sha:
            failures.append(f"asset_sha_mismatch:{product_id}")
        with Image.open(path) as image:
            rgba = image.convert("RGBA")
            if image.size != (width, height):
                failures.append(f"dimensions_invalid:{product_id}:{image.size}")
            if image.mode != "RGBA":
                failures.append(f"mode_invalid:{product_id}:{image.mode}")
            alpha = rgba.getchannel("A")
            extrema = alpha.getextrema()
            if extrema != (0, 255):
                failures.append(f"alpha_extrema_invalid:{product_id}:{extrema}")
            histogram = alpha.histogram()
            total = width * height
            coverage = sum(histogram[1:]) / total
            if not minimum_coverage <= coverage <= maximum_coverage:
                failures.append(f"coverage_invalid:{product_id}:{coverage:.4f}")
            color_hash = _dhash(rgba, False)
            alpha_hash = _dhash(rgba, True)
            image_signatures.append((product_id, color_hash, alpha_hash))
            metrics.append({
                "product_id": product_id,
                "industry_id": industry_id,
                "sha256": actual_sha,
                "subject_coverage": round(coverage, 6),
            })

    if seen_industries != expected_industries:
        failures.append(f"industry_coverage_invalid:{sorted(seen_industries)}")

    pairwise: list[dict[str, object]] = []
    for left, right in combinations(image_signatures, 2):
        color_distance = (left[1] ^ right[1]).bit_count()
        alpha_distance = (left[2] ^ right[2]).bit_count()
        combined_distance = color_distance + alpha_distance
        pairwise.append({
            "left": left[0],
            "right": right[0],
            "color_distance": color_distance,
            "alpha_distance": alpha_distance,
            "combined_distance": combined_distance,
        })
        if combined_distance < minimum_distance:
            failures.append(f"perceptual_similarity_too_high:{left[0]}:{right[0]}:{combined_distance}")

    report = {
        "status": "PASS" if not failures else "FAIL",
        "manifest": str(MANIFEST_PATH.relative_to(REPO_ROOT)).replace("\\", "/"),
        "entry_count": len(entries),
        "alpha_membership_count": len(seen_products & alpha_ids),
        "industry_count": len(seen_industries),
        "unique_asset_sha_count": len(seen_hashes),
        "unique_source_sha_count": len(seen_source_hashes),
        "metrics": metrics,
        "pairwise": pairwise,
        "failures": failures,
    }
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
