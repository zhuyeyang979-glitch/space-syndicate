# Alpha 0.1 Product Art Proof — provenance and use status

This directory records provenance for the six-image Alpha 0.1 product-art proof batch.

## Source status

- Provider: OpenAI built-in image generation.
- Model recorded by the generation workflow: `gpt-image-2`.
- Generated: 2026-07-22.
- Input reference images: none.
- Third-party game art or named intellectual property: none.
- Output status: OpenAI-generated original proof art.
- License declaration: **not CC0** and not attributed to any third-party open-art pack.
- Intended use: internal project proof and later reviewed integration, subject to the applicable OpenAI terms and the project's release review.

This record is provenance evidence, not a legal opinion. Commercial release still requires the project's normal art and rights review.

## Processing record

Each source was generated on a single flat chroma background, processed with the installed Codex image-generation chroma-key helper, and resized from `1254×1254` to `512×512` with Lanczos resampling. Raw generation outputs are not committed. Their SHA-256 values and stable generation IDs are pinned in `data/art/alpha01_product_art_manifest.json` and `prompts.json`.

The committed PNGs are the only runtime-ready proof files. They are deliberately not connected to a production UI or gameplay owner in this branch.

## Review boundary

Before production integration, the integration owner must:

1. review the six images at target UI sizes;
2. accept or replace each proof independently;
3. preserve the manifest's stable product-ID mapping;
4. keep missing products on the existing fallback path;
5. avoid making this art manifest a gameplay authority.
