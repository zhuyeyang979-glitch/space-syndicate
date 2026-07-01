# Third-party prototype assets

## Night Patrol reference pack

Source: <https://github.com/op7418/Night-Patrol>

Imported for the current non-commercial prototype:

- `assets/third_party/night_patrol/audio/bgm/bronze-snare-crown.mp3`
- `assets/third_party/night_patrol/audio/sfx/fire-burst.mp3`
- `assets/third_party/night_patrol/audio/sfx/impact-body.wav`
- `assets/third_party/night_patrol/audio/sfx/lightning-hit.mp3`
- `assets/third_party/night_patrol/ui/card-sigil.svg`
- selected UI frame/button reference files under `assets/third_party/night_patrol/ui/`

Required attribution:

```text
Night Patrol: Abandoned Temple, created by Guizang x Codex.
《夜巡录：荒庙篇》，由歸藏 × Codex 联合开发。
```

License boundary:

- The upstream project is licensed as CC BY-NC 4.0 unless otherwise noted.
- These files may be used as non-commercial prototype/reference assets.
- Before commercial release, paid distribution, store publishing, advertising-driven redistribution, or public commercial demo usage, replace these assets with fully owned assets or obtain explicit written permission.
- Do not remove the upstream `LICENSE`, `NOTICE.md`, or vendor README files from `assets/third_party/night_patrol/`.

Implementation note:

The game code treats these assets as optional. If the files are removed or replaced, the prototype falls back to procedural card art and silent audio instead of failing to load.

## Terraforming Mars open-source reference

Source: <https://github.com/terraforming-mars/terraforming-mars>

License observed from GitHub API / upstream `LICENSE`: GPL-3.0.

Usage boundary:

- Use as an interaction and layout benchmark: central board, player resource board, compact card areas, collapsible played-card/hand sections, and focused modal/decision components.
- Do not copy GPL source code, stylesheets, or artwork into this project unless the whole downstream licensing impact is explicitly accepted.
- Current implementation uses independently written Godot UI code inspired by its information hierarchy, especially the “board + player resource cubes + cards + focused action panels” structure.

## Gaia Project open-source reference

Source: <https://github.com/boardgamers/gaia-project>

Observed repository note:

- The GitHub repository default branch is `master`.
- No clear license file was detected during the current development pass.

Usage boundary:

- Use as a development-time UI/interaction benchmark only: central space map, hex/region representation, player board, command/action area, and compact resource displays.
- Do not copy source code, stylesheets, assets, or text into this project until the license status is clarified.
- Current implementation remains independently written Godot code; Gaia Project is treated as a structural reference for future map/action-board ergonomics.
