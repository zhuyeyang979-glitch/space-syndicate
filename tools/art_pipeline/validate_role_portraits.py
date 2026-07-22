#!/usr/bin/env python3
"""Validate stable role bindings and completed transparent portrait outputs."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "assets/art/role_portraits/temporary/manifest.json"
INDEX_PATH = ROOT / "tools/art_pipeline/source_asset_index.json"
EXPECTED_SIZE = (512, 768)
REQUIRED_ACTUAL_ROLES = {
    "环港走私议会",
    "重力矿联董事会",
    "光合修复会",
    "幽幕播报社",
}
GENERATED_SOURCE_KIND = "openai_generated"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args()
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    index = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
    indexed = {record["asset_id"]: record for record in index["records"]}
    roles = manifest["roles"]
    names = [entry["role_name"] for entry in roles]
    if len(roles) != 24 or len(set(names)) != 24:
        raise ValueError("manifest must contain 24 unique Chinese role-name keys")

    completed = 0
    completed_names: set[str] = set()
    for entry in roles:
        if entry["status"] != "rendered":
            if args.require_complete:
                raise ValueError(f"portrait is not rendered: {entry['role_name']}")
            continue
        if entry.get("source_kind") == GENERATED_SOURCE_KIND:
            if entry.get("provider") != "OpenAI" or entry.get("model") != "imagegen_tool_unspecified":
                raise ValueError(f"{entry['role_name']}: generated provider/model mismatch")
            generation_ids = entry.get("source_generation_ids", {})
            source_hashes = entry.get("source_sha256_by_view", {})
            for view_kind in ("front", "side_inward"):
                if not str(generation_ids.get(view_kind, "")).startswith("imagegen-"):
                    raise ValueError(f"{entry['role_name']}: generated id missing for {view_kind}")
                source_hash = str(source_hashes.get(view_kind, ""))
                if len(source_hash) != 64 or any(char not in "0123456789abcdef" for char in source_hash):
                    raise ValueError(f"{entry['role_name']}: source hash invalid for {view_kind}")
            prompt_record_path = ROOT / str(entry.get("prompt_record_path", ""))
            license_path = ROOT / str(entry.get("license_path", ""))
            if not prompt_record_path.is_file() or sha256(prompt_record_path) != entry.get("prompt_record_sha256"):
                raise ValueError(f"{entry['role_name']}: generated prompt record hash mismatch")
            if not license_path.is_file() or sha256(license_path) != entry.get("license_sha256"):
                raise ValueError(f"{entry['role_name']}: generated provenance hash mismatch")
        else:
            if not entry.get("source_path") or not entry.get("source_sha256"):
                raise ValueError(f"rendered role lacks source provenance: {entry['role_name']}")
            asset_id = entry.get("asset_id")
            if asset_id not in indexed:
                raise ValueError(f"rendered role references unknown asset_id: {entry['role_name']}")
            source_record = indexed[asset_id]
            for key in ("source_path", "source_sha256", "license_path", "license_sha256"):
                if entry.get(key) != source_record.get(key):
                    raise ValueError(f"{entry['role_name']}: manifest/index mismatch for {key}")
            source_path = ROOT / entry["source_path"]
            license_path = ROOT / entry["license_path"]
            if not source_path.is_file() or sha256(source_path) != entry["source_sha256"]:
                raise ValueError(f"{entry['role_name']}: source model hash mismatch")
            if not license_path.is_file() or sha256(license_path) != entry["license_sha256"]:
                raise ValueError(f"{entry['role_name']}: license hash mismatch")
        for key in ("front_path", "side_inward_path"):
            path = ROOT / entry[key]
            if not path.is_file():
                raise FileNotFoundError(path)
            hash_key = "front_sha256" if key == "front_path" else "side_inward_sha256"
            if sha256(path) != entry.get(hash_key):
                raise ValueError(f"{path}: derived PNG hash mismatch")
            with Image.open(path) as image:
                if image.size != EXPECTED_SIZE or image.mode != "RGBA":
                    raise ValueError(
                        f"{path}: expected {EXPECTED_SIZE} RGBA, got {image.size} {image.mode}"
                    )
                alpha = image.getchannel("A")
                if alpha.getextrema() == (255, 255):
                    raise ValueError(f"{path}: no transparent pixels")
                if any(
                    alpha.getpixel(corner) != 0
                    for corner in ((0, 0), (511, 0), (0, 767), (511, 767))
                ):
                    raise ValueError(f"{path}: all four corners must be fully transparent")
                bbox = alpha.getbbox()
                if bbox is None:
                    raise ValueError(f"{path}: portrait is blank")
                bbox_width = bbox[2] - bbox[0]
                bbox_height = bbox[3] - bbox[1]
                if bbox_width >= 510 and bbox_height >= 766:
                    raise ValueError(f"{path}: alpha forms a near-full rectangular card")
                if bbox_height < int(EXPECTED_SIZE[1] * 0.60):
                    raise ValueError(f"{path}: character silhouette is too small")
        completed += 1
        completed_names.add(entry["role_name"])

    missing_actual = sorted(REQUIRED_ACTUAL_ROLES - completed_names)
    if missing_actual:
        raise ValueError(f"required actual role portraits are missing: {missing_actual}")

    print(f"role manifest valid: 24 unique roles; rendered={completed}; pending={24-completed}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
