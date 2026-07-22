#!/usr/bin/env python3
"""Generate the deterministic contact sheet for the Alpha product-art proof."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


REPO_ROOT = Path(__file__).resolve().parents[3]
MANIFEST_PATH = REPO_ROOT / "data/art/alpha01_product_art_manifest.json"
OUTPUT_DIR = REPO_ROOT / "docs/art_qa/products/alpha01"
OUTPUT_PATH = OUTPUT_DIR / "contact_sheet.png"
METRICS_PATH = OUTPUT_DIR / "contact_sheet_metrics.json"

INDUSTRY_COLORS = {
    "life": "#3DBA73",
    "energy": "#F59E42",
    "industry": "#9AA3B2",
    "technology": "#4BA3F2",
    "commerce": "#B978E8",
    "shipping": "#28C7D9",
}


def _font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("DejaVuSans.ttf", size)
    except OSError:
        return ImageFont.load_default()


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    entries = manifest["entries"]
    width, height = 1800, 1120
    sheet = Image.new("RGB", (width, height), "#111620")
    draw = ImageDraw.Draw(sheet)
    draw.rounded_rectangle((32, 28, width - 32, height - 28), radius=30, fill="#171D29", outline="#344055", width=2)
    draw.text((68, 54), "ALPHA 0.1 / SIX-INDUSTRY PRODUCT ART PROOF", font=_font(34), fill="#F4F7FF")
    draw.text((68, 100), "Original generated proof assets - not connected to production UI", font=_font(20), fill="#AEB9CC")

    card_w, card_h = 520, 425
    gap_x, gap_y = 52, 54
    start_x, start_y = 68, 160
    for index, entry in enumerate(entries):
        row, column = divmod(index, 3)
        x = start_x + column * (card_w + gap_x)
        y = start_y + row * (card_h + gap_y)
        industry_id = entry["industry_id"]
        accent = INDUSTRY_COLORS[industry_id]
        draw.rounded_rectangle((x, y, x + card_w, y + card_h), radius=24, fill="#222A38", outline=accent, width=4)
        draw.rectangle((x + 22, y + 22, x + 34, y + card_h - 22), fill=accent)
        asset_path = REPO_ROOT / entry["asset_path"].removeprefix("res://")
        image = Image.open(asset_path).convert("RGBA")
        image.thumbnail((300, 300), Image.Resampling.LANCZOS)
        image_x = x + (card_w - image.width) // 2 + 32
        image_y = y + 24
        sheet.paste(image, (image_x, image_y), image)
        draw.text((x + 54, y + 328), entry["slug"].replace("_", " ").upper(), font=_font(22), fill="#F5F7FB")
        draw.text((x + 54, y + 362), industry_id.upper(), font=_font(18), fill=accent)
        draw.text((x + 54, y + 390), entry["sha256"][:16], font=_font(14), fill="#8E9AAF")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT_PATH, format="PNG", optimize=True)
    metrics = {
        "schema_version": "alpha01.product_art_contact_sheet.v1",
        "source_manifest": "res://data/art/alpha01_product_art_manifest.json",
        "output_path": "res://docs/art_qa/products/alpha01/contact_sheet.png",
        "width": width,
        "height": height,
        "entry_count": len(entries),
        "sha256": hashlib.sha256(OUTPUT_PATH.read_bytes()).hexdigest(),
    }
    METRICS_PATH.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(metrics, sort_keys=True))


if __name__ == "__main__":
    main()
