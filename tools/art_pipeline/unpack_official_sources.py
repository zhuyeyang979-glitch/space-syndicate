#!/usr/bin/env python3
"""Safely unpack only registry-approved Quaternius source archives."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = ROOT / "tools/art_pipeline/source_pack_registry.json"


def _registry() -> dict:
    return json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))


def _safe_extract(archive: Path, destination: Path) -> int:
    destination_resolved = destination.resolve()
    extracted = 0
    with zipfile.ZipFile(archive) as handle:
        for item in handle.infolist():
            output = (destination / item.filename).resolve()
            if output != destination_resolved and destination_resolved not in output.parents:
                raise ValueError(f"archive path escapes destination: {item.filename}")
            if item.is_dir():
                output.mkdir(parents=True, exist_ok=True)
                continue
            if output.exists():
                raise FileExistsError(f"refusing to overwrite: {output}")
            output.parent.mkdir(parents=True, exist_ok=True)
            with handle.open(item) as source, output.open("wb") as target:
                shutil.copyfileobj(source, target)
            extracted += 1
    return extracted


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pack", help="Approved pack_id for a Drive-generated ZIP.")
    parser.add_argument("--source", type=Path, help="Specific official ZIP to unpack.")
    args = parser.parse_args()

    registry = _registry()
    packs = {entry["pack_id"]: entry for entry in registry["packs"]}
    inbox = ROOT / "art_sources/inbox"
    jobs: list[tuple[dict, Path]] = []

    if args.source:
        source = args.source.resolve()
        if not source.is_file() or source.suffix.lower() != ".zip":
            raise FileNotFoundError(f"ZIP not found: {source}")
        if not args.pack or args.pack not in packs:
            raise ValueError("--source requires an approved --pack")
        jobs.append((packs[args.pack], source))
    else:
        for pack in packs.values():
            for archive_name in pack.get("expected_archive_names", []):
                candidate = inbox / archive_name
                if candidate.is_file():
                    jobs.append((pack, candidate))

    if not jobs:
        print(
            "No official archives found. Follow art_sources/inbox/README.md; "
            "for a Drive-generated ZIP use --pack PACK_ID --source PATH."
        )
        return 2

    for pack, archive in jobs:
        destination = ROOT / pack["unpacked_root"]
        existing = [path for path in destination.rglob("*") if path.is_file()]
        if existing:
            raise FileExistsError(
                f"refusing to merge into non-empty pack root: {destination}"
            )
        destination.mkdir(parents=True, exist_ok=True)
        count = _safe_extract(archive, destination)
        print(f"unpacked {pack['pack_id']}: {count} files from {archive.name}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # concise CLI failure, never partial overwrite
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
