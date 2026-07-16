#!/usr/bin/env python3
"""Build source or role contact sheets from real rendered PNGs only."""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
ACTUAL_ROLE_NAMES = (
    "环港走私议会",
    "重力矿联董事会",
    "光合修复会",
    "幽幕播报社",
)


def _font(size: int) -> ImageFont.ImageFont:
    candidates = (
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/arial.ttf"),
    )
    for candidate in candidates:
        if candidate.is_file():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def _source_items() -> tuple[list[dict], Path]:
    index = json.loads(
        (ROOT / "tools/art_pipeline/source_asset_index.json").read_text(
            encoding="utf-8"
        )
    )
    items = []
    for record in index["records"]:
        path = ROOT / record["preview_path"]
        if path.is_file():
            items.append(
                {
                    "image": path,
                    "title": record["asset_id"],
                    "subtitle": f"{record['pack_id']} / {record['model_name']}",
                }
            )
    return items, ROOT / "docs/art_qa/source_candidates/contact_sheet.png"


def _role_items() -> tuple[list[dict], Path]:
    manifest = json.loads(
        (ROOT / "assets/art/role_portraits/temporary/manifest.json").read_text(
            encoding="utf-8"
        )
    )
    items = []
    for entry in manifest["roles"]:
        for view_key in ("front_path", "side_inward_path"):
            value = entry.get(view_key)
            if value and (ROOT / value).is_file():
                items.append(
                    {
                        "image": ROOT / value,
                        "title": entry["role_name"],
                        "subtitle": view_key.removesuffix("_path"),
                    }
                )
    return items, ROOT / "docs/art_qa/role_portraits/contact_sheet.png"


def _actual_role_items() -> tuple[list[dict], Path]:
    manifest = json.loads(
        (ROOT / "assets/art/role_portraits/temporary/manifest.json").read_text(
            encoding="utf-8"
        )
    )
    by_name = {entry["role_name"]: entry for entry in manifest["roles"]}
    items = []
    for role_name in ACTUAL_ROLE_NAMES:
        entry = by_name.get(role_name)
        if not entry or entry.get("status") != "rendered":
            raise ValueError(f"actual role is not rendered: {role_name}")
        front = ROOT / entry["front_path"]
        side = ROOT / entry["side_inward_path"]
        if not front.is_file() or not side.is_file():
            raise FileNotFoundError(f"missing actual portrait pair: {role_name}")
        items.append(
            {
                "role_name": role_name,
                "front": front,
                "side": side,
                "source_model": entry["source_path"],
                "is_placeholder": False,
            }
        )
    return items, ROOT / "docs/art_qa/actual_portraits_contact_sheet.png"


def _render_actual_roles(items: list[dict], output: Path) -> None:
    cell_width, cell_height = 760, 560
    sheet = Image.new("RGBA", (cell_width * 2, cell_height * 2), (6, 12, 23, 255))
    draw = ImageDraw.Draw(sheet)
    title_font = _font(24)
    detail_font = _font(14)
    marker_font = _font(15)
    for index, item in enumerate(items):
        x = (index % 2) * cell_width
        y = (index // 2) * cell_height
        draw.rounded_rectangle(
            (x + 10, y + 10, x + cell_width - 10, y + cell_height - 10),
            radius=24,
            fill=(13, 27, 46, 255),
            outline=(49, 111, 140, 255),
            width=2,
        )
        for view_index, key in enumerate(("front", "side")):
            image = Image.open(item[key]).convert("RGBA")
            image.thumbnail((270, 405), Image.Resampling.LANCZOS)
            px = x + 60 + view_index * 340 + (270 - image.width) // 2
            py = y + 54 + (405 - image.height) // 2
            sheet.alpha_composite(image, (px, py))
            draw.text(
                (x + 145 + view_index * 340, y + 462),
                "front" if key == "front" else "side_inward",
                font=detail_font,
                anchor="mm",
                fill=(142, 211, 229, 255),
            )
        draw.text(
            (x + 28, y + 22),
            item["role_name"],
            font=title_font,
            fill=(230, 241, 250, 255),
        )
        draw.text(
            (x + 28, y + 492),
            f"source_model: {item['source_model']}",
            font=detail_font,
            fill=(150, 174, 194, 255),
        )
        draw.text(
            (x + 28, y + 522),
            "is_placeholder = false",
            font=marker_font,
            fill=(104, 224, 166, 255),
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output, quality=95)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("source", "roles", "actual_roles"))
    args = parser.parse_args()
    if args.mode == "source":
        items, output = _source_items()
    elif args.mode == "roles":
        items, output = _role_items()
    else:
        items, output = _actual_role_items()
    if not items:
        print("No real rendered PNGs found; refusing to create a placeholder sheet.")
        return 2
    if args.mode == "actual_roles":
        _render_actual_roles(items, output)
        print(f"wrote {len(items)} actual roles -> {output.relative_to(ROOT)}")
        return 0

    columns = 4
    cell_width, cell_height = 340, 460
    rows = math.ceil(len(items) / columns)
    sheet = Image.new("RGBA", (columns * cell_width, rows * cell_height), (8, 14, 25, 255))
    draw = ImageDraw.Draw(sheet)
    title_font = _font(18)
    detail_font = _font(13)
    for index, item in enumerate(items):
        x = (index % columns) * cell_width
        y = (index // columns) * cell_height
        image = Image.open(item["image"]).convert("RGBA")
        image.thumbnail((300, 370), Image.Resampling.LANCZOS)
        px = x + (cell_width - image.width) // 2
        py = y + 16
        sheet.alpha_composite(image, (px, py))
        draw.text((x + 14, y + 394), item["title"], font=title_font, fill=(226, 236, 247, 255))
        draw.text((x + 14, y + 423), item["subtitle"], font=detail_font, fill=(123, 196, 217, 255))

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output, quality=94)
    print(f"wrote {len(items)} entries -> {output.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
