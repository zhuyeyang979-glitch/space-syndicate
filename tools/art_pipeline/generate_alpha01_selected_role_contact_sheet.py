#!/usr/bin/env python3
"""Build a review-only contact sheet for the four Alpha 0.1 role pairs."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "assets/art/role_portraits/temporary/manifest.json"
OUTPUT_PATH = ROOT / "docs/art_qa/role_portraits/alpha01/contact_sheet.png"
ROLE_NAMES = ["深海菌毯使团", "离子军购局", "孪星兽栏同盟", "蜂巢防务议会"]
BACKGROUND = (7, 14, 26, 255)
PANEL = (13, 25, 42, 255)
OUTLINE = (49, 92, 122, 255)
TEXT = (220, 236, 246, 255)
MUTED = (111, 196, 225, 255)


def _font(size: int) -> ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.is_file():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def main() -> int:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    entries = {entry["role_name"]: entry for entry in manifest["roles"]}
    width, height = 2240, 760
    canvas = Image.new("RGBA", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    title_font = _font(32)
    label_font = _font(24)
    view_font = _font(19)
    signature_font = _font(13)
    draw.text((40, 24), "Alpha 0.1 Selected Role Portrait Parity", fill=TEXT, font=title_font)
    draw.text((40, 66), "4 identities / 8 transparent runtime PNGs / front + side_inward", fill=MUTED, font=view_font)
    cell_w, cell_h = 270, 580
    start_x, start_y = 32, 130
    for role_index, role_name in enumerate(ROLE_NAMES):
        entry = entries[role_name]
        for view_index, view_kind in enumerate(("front", "side_inward")):
            column = role_index * 2 + view_index
            x = start_x + column * (cell_w + 8)
            y = start_y
            draw.rounded_rectangle((x, y, x + cell_w, y + cell_h), radius=18, fill=PANEL, outline=OUTLINE, width=2)
            source = Image.open(ROOT / entry[f"{view_kind}_path"]).convert("RGBA")
            source.thumbnail((246, 420), Image.Resampling.LANCZOS)
            image_x = x + (cell_w - source.width) // 2
            image_y = y + 24 + (420 - source.height)
            canvas.alpha_composite(source, (image_x, image_y))
            role_text = role_name
            role_box = draw.textbbox((0, 0), role_text, font=label_font)
            draw.text((x + (cell_w - (role_box[2] - role_box[0])) // 2, y + 465), role_text, fill=TEXT, font=label_font)
            view_box = draw.textbbox((0, 0), view_kind, font=view_font)
            draw.text((x + (cell_w - (view_box[2] - view_box[0])) // 2, y + 510), view_kind, fill=MUTED, font=view_font)
            signature = str(entry.get("identity_signature", ""))
            short_signature = signature if len(signature) <= 30 else signature[:27] + "..."
            sig_box = draw.textbbox((0, 0), short_signature, font=signature_font)
            draw.text((x + (cell_w - (sig_box[2] - sig_box[0])) // 2, y + 548), short_signature, fill=(125, 147, 164, 255), font=signature_font)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUTPUT_PATH, quality=95)
    print(f"wrote {OUTPUT_PATH.relative_to(ROOT).as_posix()} {width}x{height}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
