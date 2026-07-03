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

- `scripts/card_art_view.gd` theme `multi-source-open-card-illustrations-v2` uses these sprites as one of several central card illustration source families.
- `scripts/monster_art_view.gd` theme `multi-source-open-monster-sprites-v2` may use the Moth Kaijuice kaiju body art for exactly one current monster family. The art identity gate rejects broad reuse of the MOS/Moth kaiju body across the roster.
- Current roster assignment is intentionally narrow: `焰环幼星` is the only monster allowed to use the MOS/Moth Kaijuice kaiju body. Other monsters must use a different body sprite family from another open-source pack or a clearly authored/procedural replacement.
- The sprites are combined with card-specific `visual_source_id`, sprite cells, composition variants, color variants, effects, and procedural motifs so the art gate can require one visual identity per card.

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

- `scripts/monster_art_view.gd` uses these sprites as distinct current monster body-art families, with one body family per assigned monster. Current assignments include the rocky land bruiser and crystal heavy-armor body families.
- `scripts/card_art_view.gd` uses selected Monster Battler sprites as route-specific temporary card illustrations, especially monster-pressure and creature-linked card faces.
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

- `scripts/monster_art_view.gd` uses these sprites as distinct monster body-art families for alien and orbital/flying silhouettes.
- `scripts/card_art_view.gd` uses selected Kenney sprites as route-specific temporary card illustrations for ocean, alien, and orbital/air cards.
- The Kenney assets are CC0 placeholders; keep source attribution in this document for traceability even though attribution is not required by the license.

## PixelMob CC0 sprite reference pack

Source: <https://github.com/rakkarage/PixelMob>

License observed from upstream `LICENSE-ART.txt`: CC0 1.0 Universal.

Imported for the current prototype:

- `assets/third_party/pixelmob_cc0/LICENSE-ART.txt`
- `assets/third_party/pixelmob_cc0/README.md`
- `assets/third_party/pixelmob_cc0/sprites/SlimeA.png`
- `assets/third_party/pixelmob_cc0/sprites/SlimeSquareA.png`

Current player-facing use:

- `scripts/monster_art_view.gd` uses the square slime strip as the current distinct body-art family for `绿洲修复体`.
- `scripts/card_art_view.gd` uses the same PixelMob body sprite for the matching rank-I monster card face, preserving the body/card identity gate.
- `scripts/map_view.gd` can render the same frame-selected PixelMob body on runtime map monster tokens.
- This source was added specifically to avoid overusing the MOS/Moth kaiju sheet or a single fantasy monster pack. It is a temporary CC0 prototype anchor and should later be replaced or overpainted into owned sci-fi kaiju art without losing the distinct body-family contract.

## Superpowers Asset Packs CC0 monster reference

Source: <https://github.com/sparklinlabs/superpowers-asset-packs>

License observed from upstream `LICENSE.txt`: CC0 1.0 Universal.

Imported for the current prototype:

- `assets/third_party/superpowers_cc0/LICENSE.txt`
- `assets/third_party/superpowers_cc0/medieval-fantasy/monsters/dragon.png`
- `assets/third_party/superpowers_cc0/medieval-fantasy/monsters/cyclop.png`
- `assets/third_party/superpowers_cc0/medieval-fantasy/monsters/snake.png`
- `assets/third_party/superpowers_cc0/medieval-fantasy/monsters/slim.png`

Current player-facing use:

- `scripts/monster_art_view.gd` uses these sprites as distinct monster body-art families for the miasma dragon and blade-serpent profiles.
- `scripts/card_art_view.gd` uses the same dragon/snake body sprites for the matching rank-I monster card faces, so those monster cards no longer drift into unrelated temporary creature art.
- This pack is intentionally used to reduce visual dependence on the MOS/Moth kaiju sheet, but it may not become the new default body source. The art identity gate now requires at least five upstream monster body-art packs and rejects any one pack supplying more than 35% of the current roster.
- These CC0 sprites are temporary prototype anchors. Later owned art should preserve the same per-monster silhouette/source-family diversity.

## Monster body source-diversity manifest

Authoritative manifest: `data/art/monster_body_art_manifest.json`

Current production rule:

- `焰环幼星` is the only active monster allowed to use the MOS/Moth Kaijuice kaiju body.
- Every active monster body is listed one by one with upstream source, visual family, sprite key, asset path, license, and silhouette intent.
- The manifest also keeps a ready non-MOS candidate bank for the next monster pass, currently including imported but unused salamander, turtle, rodent, fish, slime, amoeba, cyclops, and thin-slime body families.
- These candidates are not “automatic new monsters”; they are approved body starting points that still need authored mechanics, action profiles, card faces, map-token review, and human visual QA before entering the roster.
- The art identity gate reads this manifest and fails if MOS/Moth Kaijuice leaks into the candidate bank or if the candidate bank stops providing enough distinct non-MOS body families.

## Game-icons card semantic SVG subset

Source: <https://github.com/game-icons/icons>

License observed from upstream `license.txt`: Creative Commons 3.0 BY, with some icons CC0 where individually noted. The imported subset must keep attribution.

Imported for the current prototype:

- `assets/third_party/game_icons_ccby/license.txt`
- `assets/third_party/game_icons_ccby/README.md`
- `assets/third_party/game_icons_ccby/bank.svg`
- `assets/third_party/game_icons_ccby/profit.svg`
- `assets/third_party/game_icons_ccby/fall_down.svg`
- `assets/third_party/game_icons_ccby/contract.svg`
- `assets/third_party/game_icons_ccby/breaking_chain.svg`
- `assets/third_party/game_icons_ccby/robber_hand.svg`
- `assets/third_party/game_icons_ccby/cancel.svg`
- `assets/third_party/game_icons_ccby/warehouse.svg`
- `assets/third_party/game_icons_ccby/shaking_hands.svg`
- `assets/third_party/game_icons_ccby/coins_pile.svg`

Current player-facing use:

- `scripts/card_art_view.gd` uses these SVGs as semantic card illustration anchors for finance, GDP derivatives, contracts, warehouse stockpile, direct player interaction, and counter/nullification cards.
- This subset was imported specifically to stop high-frequency economic cards from all reading as "Moth building plus text." The first-run review gate now expects these card families to use distinct `game_icon_*` sprite keys.
- Commercial builds must either keep complete CC BY attribution in credits or replace these SVGs with owned artwork.

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
