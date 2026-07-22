# Alpha 0.1 selected role portraits — provenance and use status

This directory records provenance for four original Alpha 0.1 role-portrait pairs:

- 深海菌毯使团 / Deep-Sea Mycelium Delegation
- 离子军购局 / Ion Procurement Bureau
- 孪星兽栏同盟 / Binary-Star Stable Alliance
- 蜂巢防务议会 / Hive Defense Council

## Source status

- Provider: OpenAI built-in image generation.
- Model identifier: not exposed by the built-in image-generation tool; recorded
  as `imagegen_tool_unspecified` rather than guessed.
- Generated: 2026-07-22.
- The `side_inward` image for each role used only that role's newly generated
  `front` image as an identity reference.
- Third-party game art, named intellectual property, and repository character
  models were not used as image references.
- Output status: OpenAI-generated original Alpha 0.1 proof art.
- License declaration: **not CC0** and not attributed to a third-party art pack.
- Intended use: project Alpha testing, subject to the applicable OpenAI terms
  and the project's normal release-rights review.

This record is provenance evidence, not a legal opinion.

## Processing record

Each source was generated on a flat chroma background. The installed Codex
image-generation chroma-key helper removed that background, after which the
result was deterministically downsampled from `1024x1536` to the runtime
contract of `512x768` with Lanczos resampling. No script drew, repainted,
composited, or substituted any character content. Raw chroma generations are
not committed; their generation filenames and SHA-256 values are pinned in
`prompts.json` and the role manifest.

The committed runtime PNGs live under:

`res://assets/art/role_portraits/temporary/<role_slug>/`

The `temporary` directory name is an existing runtime catalog boundary; these
four entries are marked `alpha01_generated_original`, not as third-party model
renders.
