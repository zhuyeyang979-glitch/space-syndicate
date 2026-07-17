#!/usr/bin/env python3
"""Enumerate real approved source models and produce their provenance index."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = ROOT / "tools/art_pipeline/source_pack_registry.json"
OUTPUT_PATH = ROOT / "tools/art_pipeline/source_asset_index.json"
MODEL_EXTENSIONS = {".blend", ".fbx", ".gltf", ".glb", ".obj"}

TAG_RULES = {
    "bee": ("bee", "wasp", "armabee"),
    "plant": ("plant", "cactus", "cactoro", "tribal"),
    "mushroom": ("mush", "fung", "spore"),
    "cyclops": ("cyclop", "singleeye", "oneeye"),
    "tentacle": ("tentacle", "squid", "squidle"),
    "bird": ("bird", "birb", "pigeon", "chicken", "penguin"),
    "ghost": ("ghost", "spirit"),
    "dragon": ("dragon", "lizard", "dino"),
    "robot": ("robot", "mech", "enemy"),
    "astronaut": ("astronaut",),
    "fish": ("fish",),
    "whale": ("whale",),
    "dolphin": ("dolphin",),
    "shark": ("shark",),
    "manta": ("manta", "ray"),
    "base_character": ("regular", "teen", "superhero", "basecharacter"),
}

PACK_PREVIEW_TRANSFORMS = {
    "animated_fish": {
        "rotation_degrees": [90.0, 90.0, 0.0],
        "position": [0.0, 0.0, 0.0],
        "scale": 1.0,
    },
}


def _preview_transform(pack_id: str, model_stem: str) -> dict | None:
    transform = PACK_PREVIEW_TRANSFORMS.get(pack_id)
    if transform is None:
        return None
    result = dict(transform)
    if pack_id == "animated_fish" and model_stem.lower() == "manta ray":
        result["rotation_degrees"] = [0.0, 0.0, 0.0]
    return result


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _slug(value: str) -> str:
    result = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return result or "asset"


def _tags(relative_path: str) -> list[str]:
    normalized = re.sub(r"[^a-z0-9]+", "", relative_path.lower())
    found = [
        tag
        for tag, needles in TAG_RULES.items()
        if any(needle in normalized for needle in needles)
    ]
    return sorted(found)


def main() -> int:
    registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    allowed_markers = tuple(registry["allowed_license_markers"])
    records: list[dict] = []
    pack_results: list[dict] = []

    for pack in registry["packs"]:
        license_path = ROOT / pack["license_path"]
        if not license_path.is_file():
            raise FileNotFoundError(
                f"{pack['pack_id']} license is absent: {pack['license_path']}"
            )
        license_hash = _sha256(license_path)
        if license_hash != pack["license_sha256"]:
            raise ValueError(
                f"{pack['pack_id']} license hash mismatch: {license_hash}"
            )
        license_text = license_path.read_text(encoding="utf-8", errors="replace")
        if not any(marker.lower() in license_text.lower() for marker in allowed_markers):
            raise ValueError(f"{pack['pack_id']} license has no approved CC0 marker")

        source_root = ROOT / pack["unpacked_root"]
        model_paths = (
            sorted(
                path
                for path in source_root.rglob("*")
                if path.is_file() and path.suffix.lower() in MODEL_EXTENSIONS
            )
            if source_root.is_dir()
            else []
        )
        pack_results.append(
            {
                "pack_id": pack["pack_id"],
                "source_status": (
                    "indexed" if model_paths else pack["source_status"]
                ),
                "model_count": len(model_paths),
                "license_path": pack["license_path"],
                "license_sha256": license_hash,
            }
        )

        for model_path in model_paths:
            relative = model_path.relative_to(ROOT).as_posix()
            model_hash = _sha256(model_path)
            asset_id = (
                f"{pack['pack_id']}--{_slug(model_path.stem)}--{model_hash[:10]}"
            )
            record = {
                "asset_id": asset_id,
                "pack_id": pack["pack_id"],
                "source_path": relative,
                "model_name": model_path.stem,
                "format": model_path.suffix.lower().lstrip("."),
                "source_sha256": model_hash,
                "license_path": pack["license_path"],
                "license_sha256": license_hash,
                "candidate_tags": _tags(relative),
                "preview_path": (
                    "docs/art_qa/source_candidates/previews/"
                    f"{asset_id}.png"
                ),
            }
            preview_transform = _preview_transform(
                pack["pack_id"], model_path.stem
            )
            if preview_transform:
                record["preview_transform"] = preview_transform
            records.append(record)

    output = {
        "schema_version": 1,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "generator": "tools/art_pipeline/build_source_asset_index.py",
        "model_extensions": sorted(MODEL_EXTENSIONS),
        "packs": pack_results,
        "records": records,
    }
    OUTPUT_PATH.write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"indexed {len(records)} real model files -> {OUTPUT_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
