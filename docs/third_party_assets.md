# Third-party prototype assets

## Night Patrol reference pack

Source: <https://github.com/op7418/Night-Patrol>

Imported for the current non-commercial prototype:

- `assets/third_party/night_patrol/audio/bgm/bronze-snare-crown.mp3`
- `assets/third_party/night_patrol/audio/sfx/fire-burst.mp3`
- `assets/third_party/night_patrol/audio/sfx/impact-body.wav`
- `assets/third_party/night_patrol/audio/sfx/lightning-hit.mp3`
- `assets/third_party/night_patrol/ui/card-sigil.svg`
- `assets/third_party/night_patrol/ui/panel-talisman.png`
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

Current player-facing use:

- `scripts/card_art_view.gd` theme `night-patrol-frame-panel-sigil-v2` draws the Night Patrol talisman panel as a card backplate.
- The same component overlays Night Patrol frame variants, red/blue button strips, and the sigil over procedural sci-fi motifs.
- Because `CardArtView` is shared by hand cards, district supply cards, card-codex thumbnails, and detail cards, this is the current prototype-wide temporary card-art skin.

## Moth Kaijuice sprite reference pack

Source: <https://github.com/Moth-Fried-Games/moth-kaijuice>

License observed from GitHub API / upstream `LICENSE`: MIT.

Imported for the current prototype:

- `assets/third_party/moth_kaijuice/LICENSE`
- `assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc.png`
- `assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc_atfield.png`
- `assets/third_party/moth_kaijuice/city/kaiju/mothkaiju_pc_laser.png`
- `assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_mech.png`
- `assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_tank.png`
- `assets/third_party/moth_kaijuice/city/npcs/mothkaiju_npc_soldier.png`
- `assets/third_party/moth_kaijuice/city/buildings/mothkaiju_bldg_m.png`
- `assets/third_party/moth_kaijuice/city/buildings/mothkaiju_bldg_s.png`

Current player-facing use:

- `scripts/card_art_view.gd` theme `moth-kaijuice-mit-sprite-illustrations-v1` uses these sprites as the central card illustration layer.
- `scripts/monster_art_view.gd` theme `multi-source-open-monster-sprites-v2` may use the Moth Kaijuice kaiju body art for exactly one current monster family. The art identity gate rejects broad reuse of the MOS/Moth kaiju body across the roster.
- The sprites are combined with card-specific sprite cells, composition variants, color variants, effects, and procedural motifs so the art gate can require one visual identity per card.

Implementation note:

- These textures are loaded as optional Godot resources with an `Image.load()` fallback, so freshly copied PNG files work before Godot has generated `.import` metadata.
- The imported sprites are prototype placeholders and a visual benchmark. Keep the upstream MIT license with any redistributed prototype build that includes them.

## Monster Battler sprite reference pack

Source: <https://github.com/victrolaface/monster_battler>

License observed from upstream `LICENSE`: CC0 1.0 Universal.

Imported for the current prototype:

- `assets/third_party/monster_battler/LICENSE`
- `assets/third_party/monster_battler/monsters/dino.png`
- `assets/third_party/monster_battler/monsters/rock.png`
- `assets/third_party/monster_battler/monsters/rodent.png`
- `assets/third_party/monster_battler/monsters/salamander.png`
- `assets/third_party/monster_battler/monsters/turtle.png`

Current player-facing use:

- `scripts/monster_art_view.gd` uses these sprites as distinct current monster body-art families, with one body family per assigned monster.
- These CC0 sprites are temporary prototype monster anchors; later passes should replace them with owned or more coherent sci-fi kaiju art while preserving the one-monster-one-body-family gate.

## Kenney CC0 sprite reference pack

Source: <https://github.com/iwenzhou/kenney>

License observed from upstream `LICENSE.md`: CC0 1.0 Universal.

Imported for the current prototype:

- `assets/third_party/kenney_cc0/LICENSE.md`
- `assets/third_party/kenney_cc0/platformer/enemies/fishSwim1.png`
- `assets/third_party/kenney_cc0/platformer/enemies/slimeWalk1.png`
- `assets/third_party/kenney_cc0/hexagon/alienBlue.png`
- `assets/third_party/kenney_cc0/space/enemyUFO.png`

Current player-facing use:

- `scripts/monster_art_view.gd` uses these sprites as distinct monster body-art families for ocean, alien, ooze/support, and orbital/flying silhouettes.
- The Kenney assets are CC0 placeholders; keep source attribution in this document for traceability even though attribution is not required by the license.

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
